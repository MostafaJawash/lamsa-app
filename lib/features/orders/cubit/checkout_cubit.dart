import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/errors/error_messages.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/cart_errors.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/orders/data/checkout_attempt.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';

enum CheckoutStatus { loading, ready, unavailable }

/// Why the checkout screen refreshed itself (shown as a notice).
enum CheckoutNotice { price, method, address, location }

/// The customer must go back to the cart (it shows what to fix).
final class CartRedirect extends Equatable {
  const CartRedirect({this.message});

  /// Optional toast ("لم يتبقَّ سوى N").
  final String? message;

  @override
  List<Object?> get props => [message];
}

const checkoutNoteMax = 500;

final class CheckoutState extends Equatable {
  const CheckoutState({
    this.status = CheckoutStatus.loading,
    this.cart = Cart.empty,
    this.addresses = const [],
    this.governorates = const [],
    this.addressId,
    this.methodCode,
    this.notes = '',
    this.gift = '',
    this.placing = false,
    this.notice,
    this.error,
    this.attemptId = '',
    this.placed,
    this.redirect,
  });

  final CheckoutStatus status;
  final Cart cart;
  final List<Address> addresses;
  final List<Governorate> governorates;
  final int? addressId;
  final String? methodCode;
  final String notes;
  final String gift;
  final bool placing;
  final CheckoutNotice? notice;

  /// The backend's message under the form (notes are kept).
  final String? error;

  /// The id of this checkout attempt (see [idempotencyKey]).
  final String attemptId;

  /// Set once the order exists (created now or replayed).
  final OrderDetail? placed;

  /// Set when the customer has to go back to the cart.
  final CartRedirect? redirect;

  Address? get address =>
      addresses.where((a) => a.id == addressId).firstOrNull;

  /// The methods the backend says are valid for the selected address. Without
  /// an address nothing is offered.
  List<DeliveryQuote> get quotes =>
      address == null ? const [] : cart.deliveryQuotes;

  DeliveryQuote? get quote =>
      quotes.where((q) => q.code == methodCode).firstOrNull;

  /// The totals the customer is looking at: the quote's, else the subtotals.
  List<CurrencyAmount> get totals => quote?.totals ?? cart.subtotals;

  bool get canPlace => address != null && quote != null && !placing;

  CheckoutState copyWith({
    CheckoutStatus? status,
    Cart? cart,
    List<Address>? addresses,
    List<Governorate>? governorates,
    Object? addressId = _keep,
    Object? methodCode = _keep,
    String? notes,
    String? gift,
    bool? placing,
    Object? notice = _keep,
    Object? error = _keep,
    String? attemptId,
    Object? placed = _keep,
    Object? redirect = _keep,
  }) =>
      CheckoutState(
        status: status ?? this.status,
        cart: cart ?? this.cart,
        addresses: addresses ?? this.addresses,
        governorates: governorates ?? this.governorates,
        addressId: identical(addressId, _keep) ? this.addressId : addressId as int?,
        methodCode:
            identical(methodCode, _keep) ? this.methodCode : methodCode as String?,
        notes: notes ?? this.notes,
        gift: gift ?? this.gift,
        placing: placing ?? this.placing,
        notice: identical(notice, _keep) ? this.notice : notice as CheckoutNotice?,
        error: identical(error, _keep) ? this.error : error as String?,
        attemptId: attemptId ?? this.attemptId,
        placed: identical(placed, _keep) ? this.placed : placed as OrderDetail?,
        redirect:
            identical(redirect, _keep) ? this.redirect : redirect as CartRedirect?,
      );

  @override
  List<Object?> get props => [
        status,
        cart,
        addresses,
        governorates,
        addressId,
        methodCode,
        notes,
        gift,
        placing,
        notice,
        error,
        attemptId,
        placed,
        redirect,
      ];
}

const _keep = Object();

/// Checkout (real order placement), mirroring lamsa-web's rules:
///
/// - the backend decides which delivery methods are valid for the selected
///   address (`delivery_quotes`, filtered by governorate) and what each one
///   adds to which currency; nothing about Damascus or the provinces is
///   decided here;
/// - money is never computed: the order carries the totals the customer saw
///   (`expected_totals`, from the selected quote) and the backend compares
///   them with its own;
/// - the Idempotency-Key comes from this attempt's id and the confirmed
///   inputs ([idempotencyKey]): a double tap or a retry cannot create a second
///   order, and a changed input or a refreshed checkout always gets a new key;
/// - after a busy server, a timeout or a network error the request is retried
///   once with the SAME key (the backend returns the order if the first try
///   went through);
/// - backend failures follow its codes: see [_onFailure].
final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit({
    required this._cartApi,
    required this._orders,
    required this._addresses,
    required this._cart,
    Future<void> Function(Duration)? delay,
    String Function()? newAttempt,
  })  : _delay = delay ?? _realDelay,
        _newAttempt = newAttempt ?? newAttemptId,
        super(const CheckoutState());

  final CartApi _cartApi;
  final OrdersApi _orders;
  final AddressesRepository _addresses;
  final CartCubit _cart;
  final Future<void> Function(Duration) _delay;
  final String Function() _newAttempt;

  static Future<void> _realDelay(Duration d) => Future<void>.delayed(d);

  static const _retryWait = Duration(seconds: 1);
  static const _retryWaitMax = Duration(seconds: 5);

  // ---- loading ----

  /// Loads addresses, governorates and the cart for the selected address.
  /// [addressId] / [methodCode] are a wished selection (kept if still valid).
  /// Every load starts a new checkout attempt.
  Future<void> load({
    int? addressId,
    String? methodCode,
    CheckoutNotice? notice,
    bool keepError = false,
  }) async {
    emit(
      state.copyWith(
        status: state.cart.lines.isEmpty ? CheckoutStatus.loading : state.status,
        notice: notice,
        error: keepError ? state.error : null,
        attemptId: _newAttempt(),
        placing: false,
      ),
    );
    try {
      final results = await Future.wait([
        _addresses.list(),
        _addresses.governorates().then<List<Governorate>?>((g) => g).onError<Object>((_, _) => null),
      ]);
      final addresses = results[0]! as List<Address>;
      final governorates = (results[1] as List<Governorate>?) ?? state.governorates;
      final address = pickAddress(addresses, addressId ?? state.addressId);
      final cart = await _cartApi.cart(governorate: address?.governorate);
      if (isClosed) return;
      if (cart.lines.isEmpty || !cart.canCheckout) {
        emit(state.copyWith(redirect: const CartRedirect()));
        return;
      }
      // Without an address there is nothing to deliver to yet.
      final quotes = address == null ? const <DeliveryQuote>[] : cart.deliveryQuotes;
      emit(
        state.copyWith(
          status: CheckoutStatus.ready,
          cart: cart,
          addresses: addresses,
          governorates: governorates,
          addressId: address?.id,
          methodCode: pickQuote(quotes, methodCode ?? state.methodCode)?.code,
        ),
      );
    } on Object catch (e) {
      if (isClosed) return;
      if (state.cart.lines.isEmpty) {
        emit(state.copyWith(status: CheckoutStatus.unavailable, error: messageOf(e)));
      } else {
        emit(state.copyWith(error: messageOf(e)));
      }
    }
  }

  /// The wished address if it exists, else the default one, else the first.
  static Address? pickAddress(List<Address> addresses, int? wanted) =>
      addresses.where((a) => a.id == wanted).firstOrNull ??
      addresses.where((a) => a.isDefault).firstOrNull ??
      addresses.firstOrNull;

  /// The wished method if it is valid for the address, else the only valid
  /// one, else null (the customer must choose).
  static DeliveryQuote? pickQuote(List<DeliveryQuote> quotes, String? wanted) =>
      quotes.where((q) => q.code == wanted).firstOrNull ??
      (quotes.length == 1 ? quotes.first : null);

  // ---- selection ----

  /// Another address: the methods and totals come from the backend again.
  Future<void> selectAddress(int id) {
    if (id == state.addressId) return Future.value();
    return load(addressId: id, methodCode: state.methodCode);
  }

  void selectMethod(String code) {
    if (code == state.methodCode) return;
    emit(state.copyWith(methodCode: code, error: null, notice: null));
  }

  void setNotes(String value) => emit(state.copyWith(notes: value));

  void setGift(String value) => emit(state.copyWith(gift: value));

  /// A new address was saved from the checkout: select it.
  Future<void> addressAdded(Address address) =>
      load(addressId: address.id, methodCode: state.methodCode);

  /// The redirect was handled by the screen.
  void redirectHandled() => emit(state.copyWith(redirect: null));

  // ---- placing the order ----

  /// The key the next request would carry (for tests and diagnostics).
  String? get currentKey {
    final s = _snapshot();
    return s == null ? null : idempotencyKey(state.attemptId, s);
  }

  AttemptSnapshot? _snapshot() {
    final a = state.address;
    final q = state.quote;
    if (a == null || q == null) return null;
    return AttemptSnapshot(
      addressId: a.id,
      method: q.code,
      notes: state.notes,
      gift: state.gift,
      totals: totalsToMap(q.totals),
    );
  }

  /// "تأكيد الطلب".
  Future<void> place() async {
    if (state.placing) return;
    final address = state.address;
    final quote = state.quote;
    if (address == null) {
      emit(state.copyWith(error: ErrorMessages.forCode('ADDRESS_REQUIRED')));
      return;
    }
    if (quote == null || quote.totals.isEmpty) {
      emit(state.copyWith(error: Strings.checkoutNeedMethod));
      return;
    }
    if (state.notes.trim().runes.length > checkoutNoteMax ||
        state.gift.trim().runes.length > checkoutNoteMax) {
      emit(state.copyWith(error: Strings.checkoutNotesTooLong(checkoutNoteMax)));
      return;
    }
    final snapshot = _snapshot()!;
    final key = idempotencyKey(state.attemptId, snapshot);
    final request = OrderRequest(
      deliveryMethodCode: quote.code,
      addressId: address.id,
      expectedTotals: snapshot.totals,
      customerNotes: state.notes.trim().isEmpty ? null : state.notes.trim(),
      giftMessage: state.gift.trim().isEmpty ? null : state.gift.trim(),
    );
    emit(state.copyWith(placing: true, error: null, notice: null));
    try {
      final placed = await _send(request, key);
      if (isClosed) return;
      // The order consumed the cart: refresh it (and the badge).
      emit(state.copyWith(placing: false, placed: placed.order));
      await _cart.load(refresh: true);
    } on Object catch (e) {
      if (isClosed) return;
      await _onFailure(e);
    }
  }

  /// POST /orders; a transient failure (busy, timeout, unreachable) is
  /// retried once with the same key.
  Future<PlacedOrder> _send(OrderRequest request, String key) async {
    try {
      return await _orders.place(request, idempotencyKey: key);
    } on ApiError catch (e) {
      if (!_isTransient(e)) rethrow;
      final hinted = e.retryAfter ?? _retryWait;
      await _delay(hinted > _retryWaitMax ? _retryWaitMax : hinted);
      return _orders.place(request, idempotencyKey: key);
    }
  }

  static bool _isTransient(ApiError e) =>
      e.code == 'SERVICE_BUSY' ||
      e.code == ApiError.timeoutCode ||
      e.code == ApiError.networkCode;

  /// Backend failure to the customer's next step (lamsa-web's `handleFailure`):
  ///
  /// - empty cart, cart issues, not enough stock: back to the cart, which
  ///   shows what to fix;
  /// - changed totals or prices: stay here with fresh totals, a notice and a
  ///   NEW attempt (a new key), so the customer confirms again;
  /// - a delivery method that no longer fits the address: fresh methods;
  /// - a missing or invalid address / location: a notice (the address form is
  ///   right here);
  /// - anything else: the backend's own Arabic message under the form.
  Future<void> _onFailure(Object error) async {
    emit(state.copyWith(placing: false));
    final e = error is ApiError ? error : null;
    switch (e?.code) {
      case 'CART_EMPTY':
      case 'CART_HAS_ISSUES':
        await _cart.load(refresh: true);
        emit(state.copyWith(redirect: const CartRedirect()));
      case 'INSUFFICIENT_STOCK':
        final available = CartError.from(e!).available;
        await _cart.load(refresh: true);
        emit(
          state.copyWith(
            redirect: CartRedirect(
              message: available == null ? null : Strings.toastLow(available),
            ),
          ),
        );
      case 'PRICE_CHANGED':
        await load(
          addressId: state.addressId,
          methodCode: state.methodCode,
          notice: CheckoutNotice.price,
        );
      case 'DELIVERY_METHOD_NOT_AVAILABLE':
      case 'DELIVERY_METHOD_NOT_FOUND':
        await load(
          addressId: state.addressId,
          notice: CheckoutNotice.method,
        );
        emit(state.copyWith(methodCode: null));
      case 'ADDRESS_REQUIRED':
      case 'ADDRESS_NOT_FOUND':
        emit(state.copyWith(addressId: null, methodCode: null));
        await load(notice: CheckoutNotice.address);
      case 'INVALID_LOCATION':
        emit(state.copyWith(addressId: null, methodCode: null));
        await load(notice: CheckoutNotice.location);
        emit(state.copyWith(error: e!.userMessage));
      default:
        emit(state.copyWith(error: messageOf(error)));
    }
  }
}

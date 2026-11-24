import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/cart_errors.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/guest_merge.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

enum CartLoad { idle, loading, ready, failed }

final class CartState extends Equatable {
  const CartState({
    this.status = CartLoad.idle,
    this.cart = Cart.empty,
    this.count = 0,
    this.lineErrors = const {},
    this.error,
    this.connection = false,
  });

  final CartLoad status;

  /// The last cart the backend computed (the stored cart, or the preview of
  /// the guest cart). Totals are never calculated on the device.
  final Cart cart;

  /// The badge: items in the cart. Guests: the local quantity sum (no
  /// network); signed in: `items_count` of the stored cart.
  final int count;

  /// Per-line error shown under a line after a failed change, by line ref.
  final Map<String, String> lineErrors;

  final String? error;

  /// The last load failed because the backend could not be reached.
  final bool connection;

  CartState copyWith({
    CartLoad? status,
    Cart? cart,
    int? count,
    Map<String, String>? lineErrors,
    Object? error = _keep,
    bool? connection,
  }) =>
      CartState(
        status: status ?? this.status,
        cart: cart ?? this.cart,
        count: count ?? this.count,
        lineErrors: lineErrors ?? this.lineErrors,
        error: identical(error, _keep) ? this.error : error as String?,
        connection: connection ?? this.connection,
      );

  @override
  List<Object?> get props =>
      [status, cart, count, lineErrors, error, connection];
}

const _keep = Object();

/// The cart, app-wide. Two modes, switched by the session:
///
/// - **guest**: the cart is only "what's in it" on the device ([GuestStore]);
///   every view and change is validated by `POST /cart/preview`, so prices,
///   stock and issues always come from the backend. An add or increase is
///   saved only if the preview of the cart WITH the change has no issue on
///   that line; decreasing and removing are always allowed;
/// - **signed in**: the real `/cart/*` endpoints; every call returns the whole
///   cart.
///
/// Changes are serialized (one at a time, in order), so the last answer is the
/// newest state.
final class CartCubit extends Cubit<CartState> {
  CartCubit({
    required this._api,
    required this._store,
    required this._session,
    this._merge,
    this._onMerged,
  }) : super(const CartState()) {
    _status = _session.state.status;
    _sub = _session.stream.listen(_onSession);
  }

  final CartApi _api;
  final GuestStore _store;
  final SessionCubit _session;
  final GuestMergeService? _merge;
  final void Function(MergeOutcome outcome)? _onMerged;

  late SessionStatus _status;
  StreamSubscription<SessionState>? _sub;
  Future<void> _tail = Future<void>.value();

  bool get _userMode => _session.state.isAuthenticated;

  void _onSession(SessionState s) {
    if (s.status == _status) return;
    _status = s.status;
    // The mode changed: forget the other mode's cart. Signed in: the merger
    // reloads once the guest data is merged. Guest: show the local cart.
    emit(const CartState());
    if (s.status == SessionStatus.unauthenticated) unawaited(load());
  }

  // ---- reads ----

  /// Loads the cart for the current mode. Signed in, a pending guest merge
  /// (a failed earlier attempt) is retried first.
  Future<void> load({bool refresh = false}) async {
    if (_session.state.status == SessionStatus.unknown) return;
    if (!refresh || state.status != CartLoad.ready) {
      emit(state.copyWith(status: CartLoad.loading, error: null));
    }
    try {
      if (_userMode) {
        await _retryPendingMerge();
        final cart = await _api.cart();
        _setServerCart(cart);
      } else {
        final items = await _store.readCart();
        if (items.isEmpty) {
          emit(
            state.copyWith(
              status: CartLoad.ready,
              cart: Cart.empty,
              count: 0,
              lineErrors: const {},
              error: null,
            ),
          );
        } else {
          final cart = await _api.preview(items);
          emit(
            state.copyWith(
              status: CartLoad.ready,
              cart: cart,
              count: cartQuantity(items),
              lineErrors: const {},
              error: null,
            ),
          );
        }
      }
    } on Object catch (e) {
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CartLoad.failed,
          error: CartError.from(e).message,
          connection: isConnectionFailure(e),
        ),
      );
    }
  }

  Future<void> _retryPendingMerge() async {
    final merge = _merge;
    if (merge == null) return;
    try {
      final outcome = await merge.mergeIfAny();
      if (outcome != null) _onMerged?.call(outcome);
    } on Object {
      // Still pending: the stored cart is shown and the merge is retried
      // on the next load.
    }
  }

  /// A cart the backend just returned for the signed-in user (also used by
  /// the merger and "move to cart").
  void setServerCart(Cart cart) => _setServerCart(cart);

  void _setServerCart(Cart cart) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: CartLoad.ready,
        cart: cart,
        count: cart.itemsCount,
        lineErrors: const {},
        error: null,
      ),
    );
  }

  // ---- changes ----

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _tail.then((_) => action());
    _tail = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  /// Adds [quantity] of a product (and variant). Returns the error, or null.
  Future<CartError?> add({
    required int productId,
    required int quantity,
    int? variantId,
    String slug = '',
  }) =>
      _serial(() async {
        try {
          if (_userMode) {
            _setServerCart(
              await _api.addItem(
                productId: productId,
                variantId: variantId,
                quantity: quantity,
              ),
            );
            return null;
          }
          final items = await _store.readCart();
          final item = GuestCartItem(
            productId: productId,
            variantId: variantId,
            quantity: quantity,
            slug: slug,
          );
          final existing = items.where((i) => i.key == item.key).firstOrNull;
          if (existing == null && items.length >= GuestLimits.cartLines) {
            return CartError.local(
              'CART_LIMIT_REACHED',
              max: GuestLimits.cartLines,
            );
          }
          final next = setCartQuantity(
            items,
            item,
            (existing?.quantity ?? 0) + quantity,
          );
          final cart = await _api.preview(next);
          final error = guestLineError(
            cart,
            item.key,
            variantGiven: variantId != null,
          );
          if (error != null) return error;
          if (!await _store.writeCart(next)) {
            return CartError.local(
              'CART_LIMIT_REACHED',
              max: items.length,
            );
          }
          _setGuestCart(cart, next);
          return null;
        } on Object catch (e) {
          return CartError.from(e);
        }
      });

  /// A new quantity for one line (`ref`: the stored line's id or the preview
  /// key). Optimistic; an error reverts that line and is shown under it.
  Future<CartError?> setQuantity(String ref, int quantity) {
    final q = quantity.clamp(1, GuestLimits.maxQuantity);
    return _serial(() async {
      final before = state.cart;
      final line = before.lines.where((l) => l.ref == ref).firstOrNull;
      if (line == null) return CartError.local('CART_ITEM_NOT_FOUND');
      emit(
        state.copyWith(
          cart: before.copyWith(
            lines: [
              for (final l in before.lines) l.ref == ref ? l.withQuantity(q) : l,
            ],
          ),
          lineErrors: _without(state.lineErrors, ref),
        ),
      );
      try {
        if (_userMode) {
          final id = int.tryParse(ref);
          if (id == null) throw CartError.local('CART_ITEM_NOT_FOUND');
          _setServerCart(await _api.updateItem(id, quantity: q));
          return null;
        }
        final items = await _store.readCart();
        final current = items.where((i) => i.key == ref).firstOrNull;
        if (current == null) throw CartError.local('CART_ITEM_NOT_FOUND');
        final next = setCartQuantity(items, current, q);
        final cart = await _api.preview(next);
        // Going down is always allowed (it may fix an issue); up must be valid.
        if (q > current.quantity) {
          final error = guestLineError(
            cart,
            ref,
            variantGiven: current.variantId != null,
          );
          if (error != null) throw error;
        }
        await _store.writeCart(next);
        _setGuestCart(cart, next);
        return null;
      } on Object catch (e) {
        final error = e is CartError ? e : CartError.from(e);
        if (!isClosed) {
          emit(
            state.copyWith(
              cart: before,
              lineErrors: {...state.lineErrors, ref: error.text},
            ),
          );
        }
        return error;
      }
    });
  }

  Future<CartError?> remove(String ref) => _serial(() async {
        final before = state.cart;
        emit(
          state.copyWith(
            cart: before.copyWith(
              lines: [for (final l in before.lines) if (l.ref != ref) l],
            ),
            lineErrors: _without(state.lineErrors, ref),
          ),
        );
        try {
          if (_userMode) {
            final id = int.tryParse(ref);
            if (id == null) throw CartError.local('CART_ITEM_NOT_FOUND');
            _setServerCart(await _api.removeItem(id));
            return null;
          }
          final next = removeCartLine(await _store.readCart(), ref);
          await _store.writeCart(next);
          emit(state.copyWith(count: cartQuantity(next)));
          _setGuestCart(await _previewOrEmpty(next), next);
          return null;
        } on Object catch (e) {
          // The removal may still have happened (guest: written already).
          if (!isClosed && _userMode) emit(state.copyWith(cart: before));
          return e is CartError ? e : CartError.from(e);
        }
      });

  /// "إفراغ السلة".
  Future<CartError?> clear() => _serial(() async {
        try {
          if (_userMode) {
            _setServerCart(await _api.clear());
          } else {
            await _store.writeCart(const []);
            _setGuestCart(Cart.empty, const []);
          }
          return null;
        } on Object catch (e) {
          return CartError.from(e);
        }
      });

  /// "تحديث السلة": removes unavailable lines and caps quantities. Signed in:
  /// `POST /cart/resolve-issues`; guest: the same fixes applied to the local
  /// cart, read from the preview's issues. Returns the toast text (or the
  /// error).
  Future<({CartError? error, String? toast})> resolveIssues() =>
      _serial(() async {
        try {
          if (_userMode) {
            final cart = await _api.resolveIssues();
            _setServerCart(cart);
            return (
              error: null,
              toast: noticesToast([
                for (final n in cart.notices) n.code,
              ]),
            );
          }
          final items = await _store.readCart();
          final fixes = guestFixes(await _api.preview(items));
          final next = applyGuestFixes(items, fixes);
          await _store.writeCart(next);
          _setGuestCart(await _previewOrEmpty(next), next);
          return (error: null, toast: noticesToast(fixes.notices));
        } on Object catch (e) {
          return (error: CartError.from(e), toast: null);
        }
      });

  Future<Cart> _previewOrEmpty(List<GuestCartItem> items) =>
      items.isEmpty ? Future.value(Cart.empty) : _api.preview(items);

  void _setGuestCart(Cart cart, List<GuestCartItem> items) {
    if (isClosed) return;
    emit(
      state.copyWith(
        status: CartLoad.ready,
        cart: cart,
        count: cartQuantity(items),
        lineErrors: const {},
        error: null,
      ),
    );
  }

  static Map<String, String> _without(Map<String, String> m, String key) =>
      {...m}..remove(key);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

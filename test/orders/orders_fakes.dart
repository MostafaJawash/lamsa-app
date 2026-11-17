import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/account/data/addresses_api.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';

import '../auth/auth_fakes.dart';
import '../cart/cart_fakes.dart';

ApiError err(String code, int status, {Object? details, String? message, Duration? retryAfter}) =>
    ApiError(
      code: code,
      backendMessage: message,
      status: status,
      details: details,
      retryAfter: retryAfter,
    );

const damascus = Governorate(code: 'damascus', name: 'دمشق');
const aleppo = Governorate(code: 'aleppo', name: 'حلب');
const homs = Governorate(code: 'homs', name: 'حمص');
const allGovernorates = [damascus, aleppo, homs];

Address addr(
  int id, {
  String governorate = 'damascus',
  bool isDefault = false,
  String? label,
  String details = 'شارع الثورة، بناء 5، الطابق 2',
  String? latitude,
  String? longitude,
}) =>
    Address(
      id: id,
      governorate: governorate,
      details: details,
      label: label,
      isDefault: isDefault,
      latitude: latitude,
      longitude: longitude,
    );

/// A Damascus courier and a province shipping method, as the backend quotes
/// them: the courier's fee is in SYP, the shipping fee is paid to the carrier.
const courierQuote = DeliveryQuote(
  code: 'damascus_courier',
  name: 'توصيل دمشق',
  currency: 'SYP',
  fee: '15000.00',
  totals: [
    CurrencyAmount(currency: 'SYP', amount: '115000.00'),
    CurrencyAmount(currency: 'USD', amount: '8.50'),
  ],
);

const shippingQuote = DeliveryQuote(
  code: 'province_shipping',
  name: 'شحن إلى المحافظات',
  currency: 'SYP',
  feePaidToCarrier: true,
  totals: [
    CurrencyAmount(currency: 'SYP', amount: '100000.00'),
    CurrencyAmount(currency: 'USD', amount: '8.50'),
  ],
);

CartLine cartLine({int id = 1, int qty = 2, String name = 'كريم الوجه'}) => CartLine(
      id: id,
      quantity: qty,
      product: CartProduct(id: id, slug: 'p$id', name: name),
      currency: 'SYP',
      unitPrice: '50000.00',
      regularPrice: '50000.00',
      lineTotal: '100000.00',
    );

/// The cart the backend returns for a governorate: Damascus offers the
/// courier, every other governorate offers province shipping, none offers
/// nothing.
Cart checkoutCart({String? governorate, bool canCheckout = true, int qty = 2}) {
  final quotes = switch (governorate) {
    null => const <DeliveryQuote>[],
    'damascus' => const [courierQuote],
    _ => const [shippingQuote],
  };
  return Cart(
    lines: [cartLine(qty: qty)],
    itemsCount: qty,
    linesCount: 1,
    subtotals: const [
      CurrencyAmount(currency: 'SYP', amount: '100000.00'),
      CurrencyAmount(currency: 'USD', amount: '8.50'),
    ],
    totals: const [
      CurrencyAmount(currency: 'SYP', amount: '100000.00'),
      CurrencyAmount(currency: 'USD', amount: '8.50'),
    ],
    canCheckout: canCheckout,
    deliveryQuotes: quotes,
  );
}

OrderDetail orderDetail({
  int id = 7,
  String status = 'pending',
  String statusLabel = 'قيد المراجعة',
  bool canCancel = true,
  String? cancelReason,
  Map<String, dynamic>? shippingAddress,
}) =>
    OrderDetail(
      id: id,
      createdAt: DateTime.utc(2026, 11, 17, 9, 5),
      status: status,
      statusLabel: statusLabel,
      canCancel: canCancel,
      cancelReason: cancelReason,
      delivery: const OrderDelivery(code: 'damascus_courier', name: 'توصيل دمشق'),
      shippingAddress: shippingAddress ??
          const {
            'label': 'البيت',
            'governorate': 'damascus',
            'area': 'المزة',
            'details': 'شارع الثورة، بناء 5، الطابق 2',
            'latitude': '33.5138',
            'longitude': '36.2765',
          },
      items: const [
        OrderItem(
          name: 'كريم الوجه',
          currency: 'SYP',
          unitPrice: '50000.00',
          quantity: 2,
          lineTotal: '100000.00',
          productSlug: 'p1',
        ),
      ],
      totals: const [
        OrderTotal(
          currency: 'SYP',
          subtotal: '100000.00',
          shippingFee: '15000.00',
          total: '115000.00',
        ),
        OrderTotal(
          currency: 'USD',
          subtotal: '8.50',
          shippingFee: '0.00',
          total: '8.50',
        ),
      ],
      timeline: [
        TimelineStep(
          status: 'pending',
          label: 'قيد المراجعة',
          reachedAt: DateTime.utc(2026, 11, 17, 9, 5),
          isCurrent: status == 'pending',
        ),
        const TimelineStep(status: 'preparing', label: 'قيد التجهيز'),
      ],
    );

OrderSummary orderSummary(int id, {String status = 'pending', String label = 'قيد المراجعة'}) =>
    OrderSummary(
      id: id,
      createdAt: DateTime.utc(2026, 11, 17, 9, 5),
      status: status,
      statusLabel: label,
      itemsCount: 2,
      deliveryMethodName: 'توصيل دمشق',
      totals: const [
        OrderTotal(
          currency: 'SYP',
          subtotal: '100000.00',
          shippingFee: '15000.00',
          total: '115000.00',
        ),
        OrderTotal(
          currency: 'USD',
          subtotal: '8.50',
          shippingFee: '0.00',
          total: '8.50',
        ),
      ],
    );

class FakeAddressesApi implements AddressesApi {
  FakeAddressesApi({List<Address>? addresses, List<Governorate>? govs})
      : addresses = addresses ?? [],
        govs = govs ?? allGovernorates;

  final List<Address> addresses;
  final List<Governorate> govs;
  final calls = <String>[];
  final drafts = <AddressDraft>[];
  Object? governoratesError;
  Object? saveError;
  int _next = 100;

  @override
  Future<List<Governorate>> governorates() async {
    calls.add('governorates');
    if (governoratesError != null) throw governoratesError!;
    return govs;
  }

  @override
  Future<List<Address>> list() async {
    calls.add('list');
    return List.of(addresses);
  }

  @override
  Future<Address> create(AddressDraft draft) async {
    calls.add('create');
    drafts.add(draft);
    if (saveError != null) throw saveError!;
    final a = Address(
      id: _next++,
      governorate: draft.governorate,
      details: draft.details,
      label: draft.label.isEmpty ? null : draft.label,
      area: draft.area.isEmpty ? null : draft.area,
      latitude: draft.latitude.isEmpty ? null : draft.latitude,
      longitude: draft.longitude.isEmpty ? null : draft.longitude,
      isDefault: addresses.isEmpty || draft.isDefault,
    );
    addresses.add(a);
    return a;
  }

  @override
  Future<Address> update(int id, AddressDraft draft) async {
    calls.add('update');
    drafts.add(draft);
    if (saveError != null) throw saveError!;
    final i = addresses.indexWhere((a) => a.id == id);
    final a = Address(
      id: id,
      governorate: draft.governorate,
      details: draft.details,
      label: draft.label.isEmpty ? null : draft.label,
      area: draft.area.isEmpty ? null : draft.area,
      latitude: draft.latitude.isEmpty ? null : draft.latitude,
      longitude: draft.longitude.isEmpty ? null : draft.longitude,
      isDefault: draft.isDefault || addresses[i].isDefault,
    );
    addresses[i] = a;
    return a;
  }

  @override
  Future<void> delete(int id) async {
    calls.add('delete');
    final gone = addresses.firstWhere((a) => a.id == id);
    addresses.removeWhere((a) => a.id == id);
    // The backend gives the default to the newest address.
    if (gone.isDefault && addresses.isNotEmpty) {
      final last = addresses.length - 1;
      final n = addresses[last];
      addresses[last] = Address(
        id: n.id,
        governorate: n.governorate,
        details: n.details,
        label: n.label,
        isDefault: true,
      );
    }
  }

  @override
  Future<Address> setDefault(int id) async {
    calls.add('setDefault');
    for (var i = 0; i < addresses.length; i++) {
      final a = addresses[i];
      addresses[i] = Address(
        id: a.id,
        governorate: a.governorate,
        details: a.details,
        label: a.label,
        isDefault: a.id == id,
      );
    }
    return addresses.firstWhere((a) => a.id == id);
  }
}

class FakeOrdersApi implements OrdersApi {
  final calls = <String>[];
  final keys = <String>[];
  final requests = <OrderRequest>[];

  /// What each `place` call does, in order (the last one repeats): an
  /// [OrderDetail] (created), a [PlacedOrder], or an error to throw.
  final placeScript = <Object>[];
  int _placeCalls = 0;
  int get placeCalls => _placeCalls;

  List<OrderSummary> all = [];
  final detailsById = <int, OrderDetail>{};
  Object? listError;
  final listQueries = <({String? group, int page})>[];
  Object? cancelError;
  OrderDetail? cancelled;
  CartMergeResult? reorderResult;
  Object? reorderError;
  final reordered = <int>[];
  final cancelReasons = <String?>[];

  @override
  Future<PlacedOrder> place(
    OrderRequest request, {
    required String idempotencyKey,
  }) async {
    calls.add('place');
    keys.add(idempotencyKey);
    requests.add(request);
    final step = placeScript[_placeCalls < placeScript.length ? _placeCalls : placeScript.length - 1];
    _placeCalls++;
    if (step is PlacedOrder) return step;
    if (step is OrderDetail) return PlacedOrder(step, created: true);
    throw step;
  }

  @override
  Future<OrderPage> list({String? statusGroup, int page = 1, int pageSize = 20}) async {
    calls.add('list');
    listQueries.add((group: statusGroup, page: page));
    if (listError != null) throw listError!;
    final matching = [
      for (final o in all)
        if (statusGroup == null ||
            switch (statusGroup) {
              'active' => const ['pending', 'preparing', 'shipped', 'ready_for_pickup'].contains(o.status),
              'completed' => o.status == 'delivered',
              _ => o.status == 'cancelled',
            })
          o,
    ];
    final from = (page - 1) * pageSize;
    final items = from >= matching.length
        ? <OrderSummary>[]
        : matching.sublist(from, (from + pageSize).clamp(0, matching.length));
    return OrderPage(items: items, page: page, pageSize: pageSize, total: matching.length);
  }

  @override
  Future<OrderDetail> detail(int id) async {
    calls.add('detail');
    final d = detailsById[id];
    if (d == null) throw err('ORDER_NOT_FOUND', 404);
    return d;
  }

  @override
  Future<OrderDetail> cancel(int id, {String? reason}) async {
    calls.add('cancel');
    cancelReasons.add(reason);
    if (cancelError != null) throw cancelError!;
    final done = cancelled ??
        orderDetail(id: id, status: 'cancelled', statusLabel: 'ملغي', canCancel: false, cancelReason: reason);
    detailsById[id] = done;
    return done;
  }

  @override
  Future<CartMergeResult> reorder(int id) async {
    calls.add('reorder');
    reordered.add(id);
    if (reorderError != null) throw reorderError!;
    return reorderResult ?? CartMergeResult(cart: checkoutCart(), report: const []);
  }
}

/// A cart API that serves the checkout rules: the quotes depend on the
/// governorate the app asks for.
class CheckoutCartApi extends FakeCartApi {
  CheckoutCartApi({this.canCheckout = true}) : super(FakeShop([]));

  bool canCheckout;
  final asked = <String?>[];
  Object? Function(int call)? failure;
  int _calls = 0;

  /// Replaces the answer for a governorate (e.g. changed prices).
  Cart Function(String? governorate)? build;

  @override
  Future<Cart> cart({String? governorate, String? deliveryMethodCode}) async {
    asked.add(governorate);
    final f = failure?.call(_calls++);
    if (f != null) throw f;
    return (build ?? (g) => checkoutCart(governorate: g, canCheckout: canCheckout))(governorate);
  }
}

/// A cart cubit over [api] for a signed-out shopper (checkout only refreshes
/// it after an order).
CartCubit makeCart(CartApi api) =>
    CartCubit(api: api, store: MemoryGuestStore(), session: makeSession());

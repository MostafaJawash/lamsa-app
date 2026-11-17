import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/network/interceptors.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:lamsa_app/features/account/data/addresses_api.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/orders/cubit/checkout_cubit.dart';
import 'package:lamsa_app/features/orders/data/checkout_attempt.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/order_format.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';

import 'orders_fakes.dart';

/// Records the request and answers with a fixed status and body.
class Adapter implements HttpClientAdapter {
  Adapter(this.body, [this.status = 200]);

  final Object? body;
  final int status;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(Adapter a) => Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
  ..httpClientAdapter = a
  ..interceptors.add(ErrorMappingInterceptor());

final _orderJson = {
  'id': 7,
  'created_at': '2026-11-17T09:05:00',
  'status': 'pending',
  'status_label': 'قيد المراجعة',
  'payment_method': 'cod',
  'payment_status': 'pending',
  'delivery': {'code': 'damascus_courier', 'name': 'توصيل دمشق', 'currency': 'SYP', 'fee_paid_to_carrier': false},
  'shipping_address': {'governorate': 'damascus', 'details': 'x'},
  'customer_notes': null,
  'gift_message': null,
  'items': <Object>[],
  'totals': [
    {'currency': 'SYP', 'subtotal': '100000.00', 'discount': '0.00', 'shipping_fee': '15000.00', 'total': '115000.00', 'is_legacy': false},
    {'currency': 'USD', 'subtotal': '8.50', 'discount': '0.00', 'shipping_fee': '0.00', 'total': '8.50', 'is_legacy': false},
  ],
  'timeline': [
    {'status': 'pending', 'label': 'قيد المراجعة', 'reached_at': '2026-11-17T09:05:00+00:00', 'is_current': true},
    {'status': 'preparing', 'label': 'قيد التجهيز', 'reached_at': null, 'is_current': false},
  ],
  'cancel_reason': null,
  'can_cancel': true,
};

void main() {
  group('order models', () {
    test('parse the backend shape; totals stay per currency', () {
      final o = OrderDetail.fromJson(_orderJson);
      expect(o.id, 7);
      expect(o.canCancel, isTrue);
      expect(o.createdAt, DateTime.utc(2026, 11, 17, 9, 5)); // no zone = UTC
      expect(o.timeline.first.reachedAt, DateTime.utc(2026, 11, 17, 9, 5));
      expect(o.timeline.last.reachedAt, isNull);
      expect(o.totals.map((t) => (t.currency, t.total)), [('SYP', '115000.00'), ('USD', '8.50')]);
    });

    test('dates show in Damascus time (UTC+3)', () {
      expect(formatOrderDate(DateTime.utc(2026, 11, 17, 9, 5)), '17 نوفمبر 2026');
      expect(formatOrderDate(DateTime.utc(2026, 11, 17, 9, 5), time: true), '17 نوفمبر 2026، 12:05 م');
      // Past 21:00 UTC it is already the next day in Damascus.
      expect(formatOrderDate(DateTime.utc(2026, 11, 17, 22)), '18 نوفمبر 2026');
    });

    test('the order request carries the quote totals exactly, per currency', () {
      final map = totalsToMap(courierQuote.totals);
      expect(map, {'SYP': '115000.00', 'USD': '8.50'});
      final json = OrderRequest(
        deliveryMethodCode: 'damascus_courier',
        addressId: 3,
        expectedTotals: map,
        customerNotes: 'اتصل قبل الوصول',
      ).toJson();
      expect(json['expected_totals'], {'SYP': '115000.00', 'USD': '8.50'});
      expect(json['address_id'], 3);
      expect(json['gift_message'], isNull);
    });

    test('an address snapshot is read in the new and the legacy shape', () {
      final fresh = describeAddressSnapshot(
        {'label': 'البيت', 'governorate': 'aleppo', 'area': 'الفرقان', 'details': 'شارع 5', 'latitude': 36.2, 'longitude': '37.1'},
        (c) => governorateName(allGovernorates, c),
      )!;
      expect(fresh.lines, ['البيت', 'حلب، الفرقان', 'شارع 5']);
      expect(fresh.location, (lat: '36.2', lng: '37.1'));
      final old = describeAddressSnapshot(
        {'city': 'دمشق', 'street': 'الثورة', 'building': '5'},
        (c) => c,
      )!;
      expect(old.lines, ['دمشق', 'الثورة', '5']);
      expect(old.location, isNull);
      expect(describeAddressSnapshot(null, (c) => c), isNull);
    });
  });

  group('idempotency key', () {
    const base = AttemptSnapshot(
      addressId: 3,
      method: 'damascus_courier',
      notes: '',
      gift: '',
      totals: {'SYP': '115000.00', 'USD': '8.50'},
    );

    test('attempt ids are UUID v4s and differ', () {
      final a = newAttemptId();
      expect(isAttemptId(a), isTrue);
      expect(newAttemptId(), isNot(a));
    });

    test('the same attempt and inputs give the same key (a retry replays)', () {
      final k = idempotencyKey('a1', base);
      expect(idempotencyKey('a1', base), k);
      expect(k.length, 43);
      expect(RegExp(r'^[A-Za-z0-9_-]{1,64}$').hasMatch(k), isTrue);
      // Surrounding blanks do not matter (the backend trims too).
      expect(
        idempotencyKey('a1', const AttemptSnapshot(addressId: 3, method: 'damascus_courier', notes: '  ', gift: '', totals: {'USD': '8.50', 'SYP': '115000.00'})),
        k,
      );
    });

    test('any changed input or a new attempt gives another key', () {
      final k = idempotencyKey('a1', base);
      expect(idempotencyKey('a2', base), isNot(k));
      AttemptSnapshot with_({int? address, String? method, String? notes, String? gift, Map<String, String>? totals}) =>
          AttemptSnapshot(
            addressId: address ?? base.addressId,
            method: method ?? base.method,
            notes: notes ?? base.notes,
            gift: gift ?? base.gift,
            totals: totals ?? base.totals,
          );
      expect(idempotencyKey('a1', with_(address: 4)), isNot(k));
      expect(idempotencyKey('a1', with_(method: 'province_shipping')), isNot(k));
      expect(idempotencyKey('a1', with_(notes: 'x')), isNot(k));
      expect(idempotencyKey('a1', with_(gift: 'x')), isNot(k));
      expect(idempotencyKey('a1', with_(totals: {'SYP': '115001.00', 'USD': '8.50'})), isNot(k));
    });
  });

  group('delivery availability follows the governorate', () {
    test('only the quotes the backend returned are offered; one is preselected', () {
      expect(CheckoutCubit.pickQuote(const [], null), isNull);
      expect(CheckoutCubit.pickQuote(const [courierQuote], null), courierQuote);
      expect(CheckoutCubit.pickQuote(const [courierQuote, shippingQuote], null), isNull);
      expect(CheckoutCubit.pickQuote(const [courierQuote, shippingQuote], 'province_shipping'), shippingQuote);
      // A wished method that is not valid here is dropped.
      expect(CheckoutCubit.pickQuote(const [shippingQuote, courierQuote], 'pickup'), isNull);
    });

    test('the default address wins, else the first', () {
      final list = [addr(1), addr(2, isDefault: true), addr(3)];
      expect(CheckoutCubit.pickAddress(list, null)!.id, 2);
      expect(CheckoutCubit.pickAddress(list, 3)!.id, 3);
      expect(CheckoutCubit.pickAddress(list, 99)!.id, 2);
      expect(CheckoutCubit.pickAddress([addr(5), addr(6)], null)!.id, 5);
      expect(CheckoutCubit.pickAddress(const [], null), isNull);
    });
  });

  group('API calls', () {
    test('place sends the key and the body; 201 is created, 200 is a replay', () async {
      final created = Adapter(_orderJson, 201);
      final r = await OrdersApi(dioWith(created)).place(
        const OrderRequest(
          deliveryMethodCode: 'damascus_courier',
          addressId: 3,
          expectedTotals: {'SYP': '115000.00'},
        ),
        idempotencyKey: 'key-1',
      );
      expect(r.created, isTrue);
      expect(r.order.id, 7);
      expect(created.last!.method, 'POST');
      expect(created.last!.path, '/orders');
      expect(created.last!.headers['Idempotency-Key'], 'key-1');
      expect((created.last!.data as Map)['expected_totals'], {'SYP': '115000.00'});

      final replay = await OrdersApi(dioWith(Adapter(_orderJson))).place(
        const OrderRequest(deliveryMethodCode: 'c', addressId: 1, expectedTotals: {}),
        idempotencyKey: 'key-1',
      );
      expect(replay.created, isFalse);
    });

    test('failures surface as ApiError with the backend code', () async {
      final api = OrdersApi(dioWith(Adapter({
        'error': {'code': 'PRICE_CHANGED', 'message': 'تغيّرت الأسعار', 'details': null},
      }, 409)));
      await expectLater(
        api.place(const OrderRequest(deliveryMethodCode: 'c', addressId: 1, expectedTotals: {}), idempotencyKey: 'k'),
        throwsA(isA<ApiError>().having((e) => e.code, 'code', 'PRICE_CHANGED')),
      );
    });

    test('list, detail, cancel and reorder hit the right endpoints', () async {
      final list = Adapter({'items': <Object>[], 'page': 2, 'page_size': 20, 'total': 0});
      await OrdersApi(dioWith(list)).list(statusGroup: 'active', page: 2);
      expect(list.last!.path, '/orders');
      expect(list.last!.queryParameters, {'status_group': 'active', 'page': 2, 'page_size': 20});

      final all = Adapter({'items': <Object>[], 'page': 1, 'page_size': 20, 'total': 0});
      await OrdersApi(dioWith(all)).list();
      expect(all.last!.queryParameters.containsKey('status_group'), isFalse);

      final detail = Adapter(_orderJson);
      await OrdersApi(dioWith(detail)).detail(7);
      expect(detail.last!.path, '/orders/7');

      final cancel = Adapter(_orderJson);
      await OrdersApi(dioWith(cancel)).cancel(7, reason: 'غيّرت رأيي');
      expect(cancel.last!.method, 'POST');
      expect(cancel.last!.path, '/orders/7/cancel');
      expect((cancel.last!.data as Map)['reason'], 'غيّرت رأيي');

      final reorder = Adapter({
        'lines': <Object>[],
        'merge_report': <Object>[
          {'index': 0, 'product_id': 1, 'variant_id': null, 'status': 'added', 'reason': null, 'quantity': 2},
          {'index': 1, 'product_id': 2, 'variant_id': null, 'status': 'skipped', 'reason': 'UNAVAILABLE', 'quantity': 0},
        ],
      });
      final r = await OrdersApi(dioWith(reorder)).reorder(7);
      expect(reorder.last!.path, '/orders/7/reorder');
      expect(r.restored, 1);
      expect(r.adjusted, isTrue);
    });

    test('addresses: blanks are sent as null (they clear), default only when asked', () async {
      const draft = AddressDraft(governorate: 'homs', details: 'شارع الحمراء بناء 3');
      final create = Adapter({'id': 5, 'governorate': 'homs', 'details': 'شارع الحمراء بناء 3', 'is_default': true});
      final a = await AddressesApi(dioWith(create)).create(draft);
      expect(a.id, 5);
      expect(create.last!.path, '/users/me/addresses');
      final body = create.last!.data as Map;
      expect(body['label'], isNull);
      expect(body['latitude'], isNull);
      expect(body['governorate'], 'homs');
      expect(body['is_default'], isFalse);

      final update = Adapter({'id': 5, 'governorate': 'homs', 'details': 'x'});
      await AddressesApi(dioWith(update)).update(5, draft);
      expect(update.last!.method, 'PATCH');
      expect((update.last!.data as Map).containsKey('is_default'), isFalse);
      await AddressesApi(dioWith(update)).update(5, const AddressDraft(governorate: 'homs', details: 'شارع الحمراء بناء 3', isDefault: true));
      expect((update.last!.data as Map)['is_default'], isTrue);
    });

    test('profile and phone calls send only what they need', () async {
      final user = {
        'id': 1,
        'name': 'ليلى',
        'phone': '+963933123456',
        'role': 'customer',
        'auth_provider': 'phone',
        'must_change_password': false,
      };
      final patch = Adapter(user);
      await AuthApi(dioWith(patch)).updateProfile(name: 'سارة');
      expect(patch.last!.method, 'PATCH');
      expect(patch.last!.data, {'name': 'سارة'});
      await AuthApi(dioWith(patch)).updateProfile(email: '');
      expect(patch.last!.data, {'email': null}); // a blank email clears it

      final phone = Adapter(user);
      await AuthApi(dioWith(phone)).changePhone(phone: '+963944000111', currentPassword: 'Abc12345');
      expect(phone.last!.path, '/users/me/phone');
      expect(phone.last!.data, {'phone': '+963944000111', 'current_password': 'Abc12345'});
      await AuthApi(dioWith(phone)).changePhone(phone: '+963944000111');
      expect(phone.last!.data, {'phone': '+963944000111'}); // Google account
    });
  });

  group('address rules', () {
    test('the web limits and the optional pin', () {
      const ok = AddressDraft(governorate: 'damascus', details: 'شارع الثورة، بناء 5');
      expect(validateAddress(ok), isEmpty); // the pin is optional
      expect(validateAddress(const AddressDraft(details: 'شارع الثورة، بناء 5'))[AddressField.governorate], Strings.afErrGovernorateRequired);
      expect(validateAddress(const AddressDraft(governorate: 'damascus', details: 'قصير'))[AddressField.details], Strings.afErrDetailsShort(10));
      expect(validateAddress(const AddressDraft(governorate: 'damascus'))[AddressField.details], Strings.afErrDetailsRequired);
      expect(
        validateAddress(const AddressDraft(governorate: 'mars', details: 'شارع الثورة، بناء 5'), governorateCodes: ['damascus'])[AddressField.governorate],
        Strings.afErrGovernorateUnknown,
      );
      // A pin must be a pair inside Syria.
      expect(validateAddress(const AddressDraft(governorate: 'damascus', details: 'شارع الثورة، بناء 5', latitude: '33.5'))[AddressField.location], isNotNull);
      expect(validateAddress(const AddressDraft(governorate: 'damascus', details: 'شارع الثورة، بناء 5', latitude: '48.8', longitude: '2.3'))[AddressField.location], isNotNull);
      expect(validateAddress(const AddressDraft(governorate: 'damascus', details: 'شارع الثورة، بناء 5', latitude: '33.5', longitude: '36.3')), isEmpty);
    });

    test('backend address errors show the backend message', () {
      final e = mapAddressError(err('INVALID_LOCATION', 422, message: 'الموقع خارج سوريا'));
      expect(e[AddressField.location], 'الموقع خارج سوريا');
      expect(mapAddressError(err('ADDRESS_LIMIT_REACHED', 409, message: 'وصلت إلى الحد الأقصى'))[AddressField.form], 'وصلت إلى الحد الأقصى');
    });
  });

  group('CheckoutCubit', () {
    late CheckoutCartApi cartApi;
    late FakeOrdersApi orders;
    late FakeAddressesApi addresses;
    var attempt = 0;

    CheckoutCubit make({List<Address>? list}) {
      attempt = 0;
      cartApi = CheckoutCartApi();
      orders = FakeOrdersApi();
      addresses = FakeAddressesApi(addresses: list ?? [addr(1, isDefault: true), addr(2, governorate: 'aleppo')]);
      return CheckoutCubit(
        cartApi: cartApi,
        orders: orders,
        addresses: AddressesRepository(addresses),
        cart: makeCart(cartApi),
        delay: (_) async {},
        newAttempt: () => 'attempt-${attempt++}',
      );
    }

    test('loads the default address and its quotes (Damascus: the courier)', () async {
      final c = make();
      await c.load();
      expect(c.state.status, CheckoutStatus.ready);
      expect(c.state.addressId, 1);
      expect(cartApi.asked.last, 'damascus');
      expect(c.state.quotes.map((q) => q.code).toList(), ['damascus_courier']);
      expect(c.state.methodCode, 'damascus_courier'); // the only valid one
      expect(c.state.canPlace, isTrue);
      await c.close();
    });

    test('another governorate asks the backend again: province shipping, paid to the carrier', () async {
      final c = make();
      await c.load();
      await c.selectAddress(2);
      expect(cartApi.asked.last, 'aleppo');
      expect(c.state.quotes.map((q) => q.code), ['province_shipping']);
      expect(c.state.quote!.feePaidToCarrier, isTrue);
      // The totals the customer sees are the selected quote's, per currency.
      expect(c.state.totals.map((t) => (t.currency, t.amount)), [('SYP', '100000.00'), ('USD', '8.50')]);
      await c.close();
    });

    test('no address: nothing to deliver to and the order cannot be placed', () async {
      final c = make(list: []);
      await c.load();
      expect(c.state.addressId, isNull);
      expect(c.state.quotes, isEmpty);
      expect(c.state.canPlace, isFalse);
      await c.place();
      expect(orders.placeCalls, 0);
      expect(c.state.error, isNotNull);
      await c.close();
    });

    test('placing sends the exact quote totals and the derived key', () async {
      final c = make();
      orders.placeScript.add(orderDetail());
      await c.load();
      c.setNotes('اتصل قبل الوصول');
      final key = c.currentKey!;
      await c.place();
      expect(orders.placeCalls, 1);
      expect(orders.keys.single, key);
      expect(orders.keys.single, idempotencyKey('attempt-0', const AttemptSnapshot(
        addressId: 1,
        method: 'damascus_courier',
        notes: 'اتصل قبل الوصول',
        gift: '',
        totals: {'SYP': '115000.00', 'USD': '8.50'},
      )));
      final r = orders.requests.single;
      expect(r.deliveryMethodCode, 'damascus_courier');
      expect(r.addressId, 1);
      expect(r.expectedTotals, {'SYP': '115000.00', 'USD': '8.50'}); // no sums, no mixing
      expect(r.customerNotes, 'اتصل قبل الوصول');
      expect(c.state.placed!.id, 7);
      await c.close();
    });

    test('a double tap does not send twice', () async {
      final c = make();
      orders.placeScript.add(orderDetail());
      await c.load();
      await Future.wait([c.place(), c.place()]);
      expect(orders.placeCalls, 1);
      await c.close();
    });

    test('a network error is retried once with the SAME key and the order exists once', () async {
      final c = make();
      orders.placeScript.addAll([err(ApiError.networkCode, 0), PlacedOrder(orderDetail(), created: false)]);
      await c.load();
      await c.place();
      expect(orders.placeCalls, 2);
      expect(orders.keys[0], orders.keys[1]);
      expect(c.state.placed!.id, 7); // the backend replays: 200, same order
      expect(c.state.error, isNull);
      await c.close();
    });

    test('a busy server twice shows the message and keeps the notes and the key', () async {
      final c = make();
      orders.placeScript.add(err('SERVICE_BUSY', 503, message: 'الخدمة مشغولة', retryAfter: const Duration(seconds: 2)));
      await c.load();
      c.setNotes('ملاحظة');
      await c.place();
      expect(orders.placeCalls, 2);
      expect(orders.keys[0], orders.keys[1]);
      expect(c.state.placed, isNull);
      expect(c.state.error, 'الخدمة مشغولة');
      expect(c.state.notes, 'ملاحظة');
      // Tapping again is the same attempt: still the same key.
      await c.place();
      expect(orders.keys.toSet().length, 1);
      await c.close();
    });

    test('changed notes make a new key; a reload makes a new attempt', () async {
      final c = make();
      orders.placeScript.add(err('SOMETHING', 500, message: 'خطأ'));
      await c.load();
      final k1 = c.currentKey;
      c.setNotes('x');
      final k2 = c.currentKey;
      expect(k2, isNot(k1));
      await c.load();
      expect(c.currentKey, isNot(k2));
      await c.close();
    });

    test('PRICE_CHANGED stays, refreshes the totals with a notice and a new key', () async {
      final c = make();
      orders.placeScript.add(err('PRICE_CHANGED', 409));
      await c.load();
      final before = c.currentKey;
      cartApi.build = (g) => Cart(
            lines: [cartLine()],
            canCheckout: true,
            subtotals: const [CurrencyAmount(currency: 'SYP', amount: '120000.00')],
            totals: const [CurrencyAmount(currency: 'SYP', amount: '120000.00')],
            deliveryQuotes: const [
              DeliveryQuote(
                code: 'damascus_courier',
                name: 'توصيل دمشق',
                currency: 'SYP',
                totals: [CurrencyAmount(currency: 'SYP', amount: '135000.00')],
              ),
            ],
          );
      await c.place();
      expect(c.state.notice, CheckoutNotice.price);
      expect(c.state.placed, isNull);
      expect(c.state.redirect, isNull);
      expect(c.state.totals.single.amount, '135000.00');
      expect(c.currentKey, isNot(before)); // the customer confirms anew
      await c.close();
    });

    test('CART_HAS_ISSUES and CART_EMPTY send the customer back to the cart', () async {
      for (final code in ['CART_HAS_ISSUES', 'CART_EMPTY']) {
        final c = make();
        orders.placeScript.add(err(code, 409));
        await c.load();
        await c.place();
        expect(c.state.redirect, isNotNull, reason: code);
        expect(c.state.redirect!.message, isNull);
        expect(c.state.placed, isNull);
        await c.close();
      }
    });

    test('INSUFFICIENT_STOCK goes back to the cart with how many are left', () async {
      final c = make();
      orders.placeScript.add(err('INSUFFICIENT_STOCK', 409, details: {'available': 3}));
      await c.load();
      await c.place();
      expect(c.state.redirect!.message, Strings.toastLow(3));
      await c.close();
    });

    test('DELIVERY_METHOD_NOT_AVAILABLE refreshes the methods and clears the choice', () async {
      final c = make();
      orders.placeScript.add(err('DELIVERY_METHOD_NOT_AVAILABLE', 409));
      await c.load();
      await c.place();
      expect(c.state.notice, CheckoutNotice.method);
      expect(c.state.methodCode, isNull);
      expect(c.state.canPlace, isFalse);
      expect(c.state.redirect, isNull);
      await c.close();
    });

    test('any other backend error shows its message under the form', () async {
      final c = make();
      orders.placeScript.add(err('SOMETHING_ELSE', 422, message: 'رسالة الخادم'));
      await c.load();
      await c.place();
      expect(c.state.error, 'رسالة الخادم');
      expect(c.state.placing, isFalse);
      await c.close();
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/core/network/interceptors.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

/// Shapes copied from the live backend (`POST /cart/preview`).
const _previewJson = {
  'lines': [
    {
      'quantity': 2,
      'product': {
        'id': 22,
        'slug': 'ee',
        'name': 'ee',
        'type': 'bundle',
        'brand': {'name': 'بيلا', 'slug': 'demo-bella'},
      },
      'variant': null,
      'image': {'thumb': 't', 'medium': 'm', 'large': 'l'},
      'currency': 'SYP',
      'unit_price': '23.00',
      'regular_price': '23.00',
      'compare_at_price': null,
      'discount_percent': null,
      'line_total': '0.00',
      'stock_status': 'low',
      'stock_left': 1,
      'items': [
        {'name': 'قلم', 'variant_label': 'بني', 'quantity': 1},
      ],
      'issue': {
        'code': 'INSUFFICIENT_STOCK',
        'message': 'الكمية المتوفرة أقل من المطلوب.',
        'available': 1,
        'max': null,
      },
      'key': '22:0',
    },
    {
      'quantity': 1,
      'product': {'id': 999999, 'slug': '', 'name': '', 'type': 'simple', 'brand': null},
      'variant': null,
      'image': null,
      'currency': 'SYP',
      'unit_price': '0.00',
      'regular_price': '0.00',
      'compare_at_price': null,
      'discount_percent': null,
      'line_total': '0.00',
      'stock_status': 'out',
      'stock_left': null,
      'items': <Object>[],
      'issue': {'code': 'UNAVAILABLE', 'message': 'x', 'available': null, 'max': null},
      'key': '999999:0',
    },
  ],
  'items_count': 0,
  'lines_count': 2,
  'subtotals': [
    {'currency': 'SYP', 'amount': '100.00'},
    {'currency': 'USD', 'amount': '8.50'},
  ],
  'savings': <Object>[],
  'totals': [
    {'currency': 'SYP', 'amount': '100.00'},
    {'currency': 'USD', 'amount': '8.50'},
  ],
  'delivery_fees': <Object>[],
  'delivery_quotes': <Object>[],
  'can_checkout': false,
  'issues_count': 2,
  'notices': [
    {'code': 'LINE_REMOVED', 'message': 'm', 'item_id': 3, 'from_quantity': 2},
  ],
  'selected_delivery_method_code': null,
};

class _Adapter implements HttpClientAdapter {
  _Adapter(this.body, [this.status = 200]);

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

CartApi apiWith(HttpClientAdapter adapter) => CartApi(
      Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorMappingInterceptor()),
    );

void main() {
  group('models parse the live shapes', () {
    test('a preview: lines by key, issues, bundle items, per-currency totals', () {
      final cart = Cart.fromJson(_previewJson);
      expect(cart.lines.length, 2);
      final first = cart.lines.first;
      expect(first.ref, '22:0'); // addressed by the preview key
      expect(first.id, isNull);
      expect(first.issue!.code, 'INSUFFICIENT_STOCK');
      expect(first.issue!.available, 1);
      expect(first.items.single.variantLabel, 'بني');
      expect(first.product.brand!.name, 'بيلا');
      expect(cart.lines.last.product.slug, ''); // an unknown product
      expect(cart.subtotals.map((a) => a.currency), ['SYP', 'USD']);
      expect(cart.totals.last.amount, '8.50');
      expect(cart.canCheckout, isFalse);
      expect(cart.issuesCount, 2);
      expect(cart.notices.single.code, 'LINE_REMOVED');
    });

    test('a stored line is addressed by its id', () {
      final line = CartLine.fromJson({
        ...(_previewJson['lines']! as List<Object>).first as Map<String, Object?>,
        'id': 17,
        'key': null,
      });
      expect(line.ref, '17');
      expect(line.withQuantity(5).quantity, 5);
      expect(line.withQuantity(5).ref, '17');
    });

    test('the merge response is a cart plus a report', () {
      final result = CartMergeResult.fromJson({
        ..._previewJson,
        'merge_report': [
          {'index': 0, 'product_id': 1, 'variant_id': null, 'status': 'added', 'reason': null, 'quantity': 2},
          {'index': 1, 'product_id': 2, 'variant_id': null, 'status': 'capped', 'reason': 'INSUFFICIENT_STOCK', 'quantity': 1},
          {'index': 2, 'product_id': 3, 'variant_id': null, 'status': 'skipped', 'reason': 'OUT_OF_STOCK', 'quantity': 0},
        ],
      });
      expect(result.cart.lines.length, 2);
      expect(result.report.length, 3);
      expect(result.restored, 2);
      expect(result.adjusted, isTrue);
      expect(
        const CartMergeResult(cart: Cart.empty, report: []).adjusted,
        isFalse,
      );
    });

    test('the favorites merge result tolerates a list or a count for added', () {
      expect(FavoritesMergeResult.fromJson({'added': [1, 2], 'skipped': <Object>[]}).added, 2);
      expect(FavoritesMergeResult.fromJson({'added': 3, 'skipped': <Object>[]}).added, 3);
      final r = FavoritesMergeResult.fromJson({
        'added': <Object>[],
        'skipped': [
          {'product_id': 5, 'reason': 'PRODUCT_NOT_FOUND'},
        ],
      });
      expect(r.skipped.single.productId, 5);
    });

    test('models round-trip through JSON', () {
      final cart = Cart.fromJson(_previewJson);
      expect(Cart.fromJson(cart.toJson()), cart);
    });
  });

  group('requests', () {
    const items = [
      GuestCartItem(productId: 1, quantity: 2),
      GuestCartItem(productId: 3, variantId: 9, quantity: 1),
    ];

    test('preview is public and sends product, variant (or null) and quantity', () async {
      final adapter = _Adapter(_previewJson);
      final cart = await apiWith(adapter).preview(items);
      final req = adapter.last!;
      expect(req.method, 'POST');
      expect(req.path, '/cart/preview');
      expect(req.extra[AuthExtra.noAuth], isTrue); // never carries a token
      expect(req.data, {
        'items': [
          {'product_id': 1, 'variant_id': null, 'quantity': 2},
          {'product_id': 3, 'variant_id': 9, 'quantity': 1},
        ],
      });
      expect(cart.lines.length, 2);
    });

    test('stored-cart endpoints are authenticated and use the right methods', () async {
      final adapter = _Adapter(_previewJson);
      final api = apiWith(adapter);
      await api.cart();
      expect((adapter.last!.method, adapter.last!.path), ('GET', '/cart'));
      expect(adapter.last!.extra[AuthExtra.noAuth], isNot(true));

      await api.addItem(productId: 1, quantity: 2);
      expect(adapter.last!.data, {'product_id': 1, 'quantity': 2}); // no variant_id key
      await api.addItem(productId: 1, variantId: 4);
      expect(adapter.last!.data, {'product_id': 1, 'variant_id': 4, 'quantity': 1});

      await api.updateItem(7, quantity: 3);
      expect((adapter.last!.method, adapter.last!.path), ('PATCH', '/cart/items/7'));
      expect(adapter.last!.data, {'quantity': 3});

      await api.removeItem(7);
      expect((adapter.last!.method, adapter.last!.path), ('DELETE', '/cart/items/7'));
      await api.clear();
      expect((adapter.last!.method, adapter.last!.path), ('DELETE', '/cart'));
      await api.resolveIssues();
      expect((adapter.last!.method, adapter.last!.path), ('POST', '/cart/resolve-issues'));
    });

    test('count reads items_count', () async {
      final api = apiWith(_Adapter({'items_count': 6, 'lines_count': 2}));
      expect(await api.count(), 6);
    });

    test('merge bodies', () async {
      final adapter = _Adapter({..._previewJson, 'merge_report': <Object>[]});
      final api = apiWith(adapter);
      await api.mergeCart(items);
      expect(adapter.last!.path, '/cart/merge');
      expect(adapter.last!.data, {
        'items': [
          {'product_id': 1, 'variant_id': null, 'quantity': 2},
          {'product_id': 3, 'variant_id': 9, 'quantity': 1},
        ],
      });
      final fav = _Adapter({'added': [1], 'skipped': <Object>[]});
      await apiWith(fav).mergeFavorites([1, 5]);
      expect(fav.last!.path, '/favorites/merge');
      expect(fav.last!.data, {'product_ids': [1, 5]});
    });

    test('favorites endpoints', () async {
      final ids = _Adapter({'product_ids': [3, 1]});
      expect(await apiWith(ids).favoriteIds(), [3, 1]);
      expect(ids.last!.path, '/favorites/ids');

      final page = _Adapter({'items': <Object>[], 'page': 2, 'page_size': 24, 'total': 30});
      final p = await apiWith(page).favorites(page: 2);
      expect(page.last!.queryParameters, {'page': 2, 'page_size': 24});
      expect(p.total, 30);

      final put = _Adapter(null, 204);
      final api = apiWith(put);
      await api.addFavorite(4);
      expect((put.last!.method, put.last!.path), ('PUT', '/favorites/4'));
      await api.removeFavorite(4);
      expect((put.last!.method, put.last!.path), ('DELETE', '/favorites/4'));

      final move = _Adapter(_previewJson);
      await apiWith(move).moveToCart(4);
      expect(move.last!.path, '/favorites/4/move-to-cart');
      expect(move.last!.data, {'quantity': 1}); // no variant: the backend picks one
    });

    test('errors become ApiError with their details', () async {
      final adapter = _Adapter({
        'error': {
          'code': 'INSUFFICIENT_STOCK',
          'message': 'x',
          'details': {'product_id': 1, 'variant_id': null, 'available': 2},
        },
      }, 409);
      await expectLater(
        apiWith(adapter).addItem(productId: 1, quantity: 9),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'INSUFFICIENT_STOCK')
              .having((e) => (e.details! as Map<String, dynamic>)['available'], 'available', 2),
        ),
      );
    });
  });
}

import 'package:dio/dio.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Typed client for the cart and favorites endpoints. Everything needs the
/// signed-in user's token except [preview] (public: it validates a cart held
/// on the device and stores nothing). Failures surface as [ApiError].
class CartApi {
  CartApi(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthExtra.noAuth: true});

  // ---- guest cart (public) ----

  /// The cart `GET /cart` would return for [items], computed by the backend
  /// (at most 50 items, quantity 1..99). Nothing is stored.
  Future<Cart> preview(List<GuestCartItem> items) async => Cart.fromJson(
        await _send(
          'POST',
          '/cart/preview',
          data: {'items': [for (final i in items) _item(i)]},
          options: _public,
        ),
      );

  // ---- stored cart (signed in) ----

  /// With a [governorate] the cart carries only the delivery methods valid
  /// there (`delivery_quotes`); with [deliveryMethodCode] the selected quote's
  /// totals are the ones the customer confirms at checkout.
  Future<Cart> cart({String? governorate, String? deliveryMethodCode}) async =>
      Cart.fromJson(
        await _send(
          'GET',
          '/cart',
          query: {
            'governorate': ?governorate,
            'delivery_method_code': ?deliveryMethodCode,
          },
        ),
      );

  Future<int> count() async {
    final json = await _send('GET', '/cart/count');
    return (json['items_count'] as num).toInt();
  }

  Future<Cart> addItem({
    required int productId,
    int? variantId,
    int quantity = 1,
  }) async =>
      Cart.fromJson(
        await _send(
          'POST',
          '/cart/items',
          data: {
            'product_id': productId,
            'variant_id': ?variantId,
            'quantity': quantity,
          },
        ),
      );

  Future<Cart> updateItem(int itemId, {required int quantity}) async =>
      Cart.fromJson(
        await _send('PATCH', '/cart/items/$itemId', data: {'quantity': quantity}),
      );

  Future<Cart> removeItem(int itemId) async =>
      Cart.fromJson(await _send('DELETE', '/cart/items/$itemId'));

  Future<Cart> clear() async => Cart.fromJson(await _send('DELETE', '/cart'));

  /// "تحديث السلة": removes unavailable lines and caps quantities.
  Future<Cart> resolveIssues() async =>
      Cart.fromJson(await _send('POST', '/cart/resolve-issues'));

  /// Sends the guest cart right after sign-in (at most 100 items).
  Future<CartMergeResult> mergeCart(List<GuestCartItem> items) async =>
      CartMergeResult.fromJson(
        await _send(
          'POST',
          '/cart/merge',
          data: {'items': [for (final i in items) _item(i)]},
        ),
      );

  // ---- favorites (signed in) ----

  /// Ids of the visible favorites, newest first (fills the hearts).
  Future<List<int>> favoriteIds() async {
    final json = await _send('GET', '/favorites/ids');
    return [for (final id in json['product_ids'] as List<dynamic>) (id as num).toInt()];
  }

  /// Favorites as normal product cards, newest first.
  Future<ProductPage> favorites({int page = 1, int pageSize = 24}) async =>
      ProductPage.fromJson(
        await _send(
          'GET',
          '/favorites',
          query: {'page': page, 'page_size': pageSize},
        ),
      );

  /// Idempotent; `404` when the product is not visible.
  Future<void> addFavorite(int productId) =>
      _send('PUT', '/favorites/$productId');

  /// Idempotent, never `404`.
  Future<void> removeFavorite(int productId) =>
      _send('DELETE', '/favorites/$productId');

  Future<FavoritesMergeResult> mergeFavorites(List<int> productIds) async =>
      FavoritesMergeResult.fromJson(
        await _send(
          'POST',
          '/favorites/merge',
          data: {'product_ids': productIds},
        ),
      );

  /// Adds to the cart (same rules as [addItem]) and removes the favorite in
  /// one step. Without [variantId] the first active variant in stock is used;
  /// if the add fails the favorite stays.
  Future<Cart> moveToCart(
    int productId, {
    int? variantId,
    int quantity = 1,
  }) async =>
      Cart.fromJson(
        await _send(
          'POST',
          '/favorites/$productId/move-to-cart',
          data: {'variant_id': ?variantId, 'quantity': quantity},
        ),
      );

  static Map<String, Object?> _item(GuestCartItem i) => {
        'product_id': i.productId,
        'variant_id': i.variantId,
        'quantity': i.quantity,
      };

  /// Always returns a map (empty for `204`). Errors become [ApiError].
  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? data,
    Map<String, Object?>? query,
    Options? options,
  }) async {
    try {
      final r = await _dio.request<Object?>(
        path,
        data: data,
        queryParameters: query,
        options: (options ?? Options()).copyWith(method: method),
      );
      final body = r.data;
      return body is Map<String, dynamic> ? body : const {};
    } on DioException catch (e) {
      final error = e.error;
      throw error is ApiError ? error : ApiError.fromDio(e);
    }
  }
}

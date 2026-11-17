import 'package:dio/dio.dart';
import 'package:lamsa_app/core/network/api_call.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';

/// Result of `POST /orders`: [created] is true for `201` (a new order) and
/// false for `200` (the same Idempotency-Key was used before: this is that
/// order and nothing new happened).
final class PlacedOrder {
  const PlacedOrder(this.order, {required this.created});

  final OrderDetail order;
  final bool created;
}

/// Typed client for the customer order endpoints (all need a signed-in user).
class OrdersApi {
  OrdersApi(this._dio);

  final Dio _dio;

  /// Places the order. [idempotencyKey] is generated once per checkout attempt
  /// and reused when the same attempt is retried (see `CheckoutAttempt`).
  Future<PlacedOrder> place(
    OrderRequest request, {
    required String idempotencyKey,
  }) async {
    final r = await sendJson(
      _dio,
      'POST',
      '/orders',
      data: request.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return PlacedOrder(OrderDetail.fromJson(r.map), created: r.status == 201);
  }

  /// Newest first. [statusGroup]: `active`, `completed` or `cancelled`.
  Future<OrderPage> list({
    String? statusGroup,
    int page = 1,
    int pageSize = 20,
  }) async =>
      OrderPage.fromJson(
        (await sendJson(
          _dio,
          'GET',
          '/orders',
          query: {
            'status_group': ?statusGroup,
            'page': page,
            'page_size': pageSize,
          },
        ))
            .map,
      );

  Future<OrderDetail> detail(int id) async =>
      OrderDetail.fromJson((await sendJson(_dio, 'GET', '/orders/$id')).map);

  /// Only while `pending` (`can_cancel`); the stock goes back.
  Future<OrderDetail> cancel(int id, {String? reason}) async =>
      OrderDetail.fromJson(
        (await sendJson(
          _dio,
          'POST',
          '/orders/$id/cancel',
          data: {'reason': reason},
        ))
            .map,
      );

  /// Puts the order's items back into the cart with the cart-merge rules and
  /// returns the cart plus the report (deleted or unavailable items are
  /// `skipped`).
  Future<CartMergeResult> reorder(int id) async => CartMergeResult.fromJson(
        (await sendJson(_dio, 'POST', '/orders/$id/reorder')).map,
      );
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/order_format.dart';
import 'package:lamsa_app/features/orders/data/orders_api.dart';

enum OrdersLoad { loading, ready, failed }

/// Orders per page (infinite scroll).
const ordersPageSize = 20;

final class OrdersState extends Equatable {
  const OrdersState({
    this.status = OrdersLoad.loading,
    this.filter = OrderFilter.all,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.loadingMore = false,
    this.error,
    this.connection = false,
  });

  final OrdersLoad status;
  final OrderFilter filter;
  final List<OrderSummary> items;
  final int total;
  final int page;
  final bool loadingMore;
  final String? error;
  final bool connection;

  bool get hasMore => items.length < total;

  OrdersState copyWith({
    OrdersLoad? status,
    OrderFilter? filter,
    List<OrderSummary>? items,
    int? total,
    int? page,
    bool? loadingMore,
    String? error,
    bool? connection,
  }) =>
      OrdersState(
        status: status ?? this.status,
        filter: filter ?? this.filter,
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
        connection: connection ?? this.connection,
      );

  @override
  List<Object?> get props =>
      [status, filter, items, total, page, loadingMore, error, connection];
}

/// Order history, newest first, with the backend's own `status_group` filter
/// (active / completed / cancelled) and infinite scroll.
final class OrdersCubit extends Cubit<OrdersState> {
  OrdersCubit(this._api) : super(const OrdersState());

  final OrdersApi _api;
  int _token = 0;

  Future<void> load({OrderFilter? filter, bool refresh = false}) async {
    final f = filter ?? state.filter;
    final token = ++_token;
    if (!refresh || filter != null || state.status != OrdersLoad.ready) {
      emit(OrdersState(filter: f));
    }
    try {
      final page = await _api.list(statusGroup: f.group);
      if (token != _token || isClosed) return;
      emit(
        OrdersState(
          status: OrdersLoad.ready,
          filter: f,
          items: page.items,
          total: page.total,
          page: page.page,
        ),
      );
    } on Object catch (e) {
      if (token != _token || isClosed) return;
      emit(
        state.copyWith(
          status: OrdersLoad.failed,
          error: messageOf(e),
          connection: isConnectionFailure(e),
        ),
      );
    }
  }

  Future<void> loadMore() async {
    if (state.status != OrdersLoad.ready || state.loadingMore || !state.hasMore) {
      return;
    }
    final token = _token;
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _api.list(
        statusGroup: state.filter.group,
        page: state.page + 1,
      );
      if (token != _token || isClosed) return;
      final known = {for (final o in state.items) o.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final o in page.items) if (!known.contains(o.id)) o,
          ],
          total: page.total,
          page: page.page,
          loadingMore: false,
        ),
      );
    } on Object {
      if (token == _token && !isClosed) emit(state.copyWith(loadingMore: false));
    }
  }
}

enum OrderLoad { loading, ready, failed, notFound }

final class OrderDetailState extends Equatable {
  const OrderDetailState({
    this.status = OrderLoad.loading,
    this.order,
    this.busy = false,
    this.error,
    this.connection = false,
  });

  final OrderLoad status;
  final OrderDetail? order;

  /// A cancel or reorder is in flight.
  final bool busy;
  final String? error;
  final bool connection;

  OrderDetailState copyWith({
    OrderLoad? status,
    OrderDetail? order,
    bool? busy,
    String? error,
    bool? connection,
  }) =>
      OrderDetailState(
        status: status ?? this.status,
        order: order ?? this.order,
        busy: busy ?? this.busy,
        error: error,
        connection: connection ?? this.connection,
      );

  @override
  List<Object?> get props => [status, order, busy, error, connection];
}

/// What a reorder did, for the toast.
final class ReorderOutcome extends Equatable {
  const ReorderOutcome({this.restored = 0, this.adjusted = false, this.error});

  /// Lines that reached the cart (added, merged or capped).
  final int restored;
  final bool adjusted;

  /// The backend's message when the call failed.
  final String? error;

  @override
  List<Object?> get props => [restored, adjusted, error];
}

/// One order: the detail, cancel (only while the backend says `can_cancel`)
/// and reorder (the backend's own `POST /orders/{id}/reorder`).
final class OrderDetailCubit extends Cubit<OrderDetailState> {
  OrderDetailCubit(this._api, this.orderId, this._cart)
      : super(const OrderDetailState());

  final OrdersApi _api;
  final int orderId;
  final CartCubit _cart;

  /// Use an order that is already known (just placed), then refresh.
  void seed(OrderDetail order) =>
      emit(OrderDetailState(status: OrderLoad.ready, order: order));

  Future<void> load({bool refresh = false}) async {
    if (!refresh || state.order == null) emit(const OrderDetailState());
    try {
      final order = await _api.detail(orderId);
      if (!isClosed) emit(OrderDetailState(status: OrderLoad.ready, order: order));
    } on Object catch (e) {
      if (isClosed) return;
      final notFound = e is ApiError && e.status == 404;
      emit(
        state.order != null && refresh
            ? state.copyWith(error: messageOf(e))
            : OrderDetailState(
                status: notFound ? OrderLoad.notFound : OrderLoad.failed,
                error: messageOf(e),
                connection: isConnectionFailure(e),
              ),
      );
    }
  }

  /// Cancels a pending order. Returns the backend's message on failure (the
  /// order is refreshed from the backend then: e.g. the store already moved
  /// it on, `ORDER_NOT_CANCELLABLE`).
  Future<String?> cancel({String? reason}) async {
    final trimmed = reason?.trim();
    emit(state.copyWith(busy: true));
    try {
      final order = await _api.cancel(
        orderId,
        reason: trimmed == null || trimmed.isEmpty ? null : trimmed,
      );
      if (!isClosed) emit(OrderDetailState(status: OrderLoad.ready, order: order));
      return null;
    } on Object catch (e) {
      if (!isClosed) emit(state.copyWith(busy: false));
      await load(refresh: true);
      return messageOf(e);
    }
  }

  Future<ReorderOutcome> reorder() async {
    emit(state.copyWith(busy: true));
    try {
      final result = await _api.reorder(orderId);
      _cart.setServerCart(result.cart);
      if (!isClosed) emit(state.copyWith(busy: false));
      return ReorderOutcome(restored: result.restored, adjusted: result.adjusted);
    } on Object catch (e) {
      if (!isClosed) emit(state.copyWith(busy: false));
      return ReorderOutcome(error: messageOf(e));
    }
  }
}

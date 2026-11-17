import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/cart_errors.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';

enum FavoritesLoad { loading, ready, failed }

final class FavoritesListState extends Equatable {
  const FavoritesListState({
    this.status = FavoritesLoad.loading,
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.loadingMore = false,
    this.error,
  });

  final FavoritesLoad status;
  final List<ProductCard> items;
  final int total;
  final int page;
  final bool loadingMore;
  final String? error;

  bool get hasMore => items.length < total;

  FavoritesListState copyWith({
    FavoritesLoad? status,
    List<ProductCard>? items,
    int? total,
    int? page,
    bool? loadingMore,
    String? error,
  }) =>
      FavoritesListState(
        status: status ?? this.status,
        items: items ?? this.items,
        total: total ?? this.total,
        page: page ?? this.page,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error,
      );

  @override
  List<Object?> get props => [status, items, total, page, loadingMore, error];
}

/// The favorites tab's list, newest favorite first. Signed in: `GET
/// /favorites`, 24 per page with infinite scroll. Guest: every favorite on the
/// device, looked up with `GET /products?ids=` (out-of-stock ones included).
///
/// Stays in step with the shared hearts: an item whose heart is turned off
/// elsewhere disappears, and a favorite added elsewhere reloads the list.
final class FavoritesListCubit extends Cubit<FavoritesListState> {
  FavoritesListCubit({
    required this._api,
    required this._store,
    required this._session,
    required this._favorites,
    required this._lookup,
  }) : super(const FavoritesListState()) {
    _version = _favorites.state.version;
    _sub = _favorites.stream.listen(_onFavorites);
  }

  final CartApi _api;
  final GuestStore _store;
  final SessionCubit _session;
  final FavoritesCubit _favorites;
  final Future<List<ProductCard>> Function(List<int> ids) _lookup;

  late int _version;
  StreamSubscription<FavoritesState>? _sub;

  Future<void> load({bool refresh = false}) async {
    if (!refresh || state.status != FavoritesLoad.ready) {
      emit(state.copyWith(status: FavoritesLoad.loading));
    }
    try {
      if (_session.state.isAuthenticated) {
        final page = await _api.favorites();
        emit(
          FavoritesListState(
            status: FavoritesLoad.ready,
            items: page.items,
            total: page.total,
            page: page.page,
          ),
        );
      } else {
        final ids = [
          for (final f in (await _store.readFavorites()).reversed) f.productId,
        ];
        final items = await _lookupAll(ids);
        emit(
          FavoritesListState(
            status: FavoritesLoad.ready,
            items: items,
            total: items.length,
          ),
        );
      }
      _version = _favorites.state.version;
    } on Object catch (e) {
      if (!isClosed) {
        emit(state.copyWith(status: FavoritesLoad.failed, error: CartError.from(e).message));
      }
    }
  }

  /// `GET /products?ids=` takes at most 100 ids: one request per 100, in order.
  Future<List<ProductCard>> _lookupAll(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final chunks = [
      for (var i = 0; i < ids.length; i += 100)
        ids.sublist(i, i + 100 > ids.length ? ids.length : i + 100),
    ];
    final pages = await Future.wait(chunks.map(_lookup));
    return [for (final p in pages) ...p];
  }

  Future<void> loadMore() async {
    if (state.status != FavoritesLoad.ready ||
        state.loadingMore ||
        !state.hasMore ||
        !_session.state.isAuthenticated) {
      return;
    }
    emit(state.copyWith(loadingMore: true));
    try {
      final page = await _api.favorites(page: state.page + 1);
      final known = {for (final p in state.items) p.id};
      emit(
        state.copyWith(
          items: [
            ...state.items,
            for (final p in page.items) if (!known.contains(p.id)) p,
          ],
          total: page.total,
          page: page.page,
          loadingMore: false,
        ),
      );
    } on Object {
      if (!isClosed) emit(state.copyWith(loadingMore: false));
    }
  }

  void _onFavorites(FavoritesState f) {
    if (state.status != FavoritesLoad.ready) return;
    if (f.version != _version) {
      // A favorite was added somewhere else: this list is out of date.
      _version = f.version;
      unawaited(load(refresh: true));
      return;
    }
    if (!f.ready) return;
    final kept = [for (final p in state.items) if (f.ids.contains(p.id)) p];
    if (kept.length != state.items.length) {
      emit(
        state.copyWith(
          items: kept,
          total: state.total - (state.items.length - kept.length),
        ),
      );
    }
  }

  /// Removes a favorite (turns its heart off); the list follows. If the
  /// call fails the heart is restored, so the list is reloaded.
  Future<FavoriteResult> remove(ProductCard product) async {
    final r = await _favorites.toggle(product.id, slug: product.slug);
    if (!r.ok && r.error != null) unawaited(load(refresh: true));
    return r;
  }

  Future<FavoriteResult> moveToCart(ProductCard product) =>
      _favorites.moveToCart(product);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

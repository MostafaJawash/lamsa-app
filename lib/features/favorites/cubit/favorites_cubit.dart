import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/cart/data/cart_api.dart';
import 'package:lamsa_app/features/cart/data/cart_errors.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/guest_store.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

final class FavoritesState extends Equatable {
  const FavoritesState({this.ids = const {}, this.ready = false, this.version = 0});

  /// Product ids that are favorites: the one source of truth for every heart
  /// (home rails, lists, search, detail, the favorites tab). Not read from
  /// the cards' `is_favorite`, so catalog calls stay anonymous and cacheable.
  final Set<int> ids;
  final bool ready;

  /// Bumps whenever a favorite is ADDED, so an open favorites list knows it
  /// is out of date.
  final int version;

  @override
  List<Object?> get props => [ids, ready, version];
}

/// Result of a heart tap or "move to cart".
final class FavoriteResult extends Equatable {
  const FavoriteResult({required this.ok, this.on = false, this.error});

  /// Nothing happened (a tap on the same product was still in flight).
  static const ignored = FavoriteResult(ok: false);

  final bool ok;

  /// The state after the action (when [ok]).
  final bool on;
  final CartError? error;

  @override
  List<Object?> get props => [ok, on, error];
}

/// Favorites, app-wide, in two modes switched by the session:
///
/// - **guest**: ids kept on the device. Adding checks the product is visible
///   with one `GET /products?ids=` call, like lamsa-web;
/// - **signed in**: `PUT`/`DELETE /favorites/{id}`; hearts are filled from
///   `GET /favorites/ids`.
///
/// Taps are optimistic and roll back on failure.
final class FavoritesCubit extends Cubit<FavoritesState> {
  FavoritesCubit({
    required this._api,
    required this._store,
    required this._session,
    required this._cart,
    required this._lookup,
    required this._detail,
  }) : super(const FavoritesState()) {
    _status = _session.state.status;
    _sub = _session.stream.listen(_onSession);
  }

  final CartApi _api;
  final GuestStore _store;
  final SessionCubit _session;
  final CartCubit _cart;

  /// Visible products among the ids (out-of-stock included): `GET /products?ids=`.
  final Future<List<ProductCard>> Function(List<int> ids) _lookup;

  /// Product detail by slug (for the first variant in stock).
  final Future<ProductDetail> Function(String slug) _detail;

  late SessionStatus _status;
  StreamSubscription<SessionState>? _sub;
  final _pending = <int>{};

  /// Bumps on every heart change, so a slow `load()` that started before a
  /// tap never overwrites it with older data.
  int _epoch = 0;
  bool _reloadWhenIdle = false;

  bool get _userMode => _session.state.isAuthenticated;

  void _onSession(SessionState s) {
    if (s.status == _status) return;
    _status = s.status;
    emit(FavoritesState(version: state.version + 1));
    if (s.status == SessionStatus.unauthenticated) unawaited(load());
  }

  bool isFavorite(int productId) => state.ids.contains(productId);

  /// Reads the ids for the current mode (a failure leaves the hearts empty).
  Future<void> load() async {
    if (_session.state.status == SessionStatus.unknown) return;
    final epoch = _epoch;
    try {
      final ids = _userMode
          ? await _api.favoriteIds()
          : [for (final f in await _store.readFavorites()) f.productId];
      if (isClosed) return;
      if (epoch != _epoch || _pending.isNotEmpty) {
        // A heart changed while this was loading: the tap is newer than
        // this answer. Load again once the taps settle.
        _reloadWhenIdle = true;
        return;
      }
      emit(FavoritesState(ids: ids.toSet(), ready: true, version: state.version));
    } on Object {
      // Hearts stay as they are; the next screen load tries again.
    }
  }

  /// Toggles a heart. Optimistic, rolled back on failure.
  Future<FavoriteResult> toggle(int productId, {String slug = ''}) async {
    if (!_pending.add(productId)) return FavoriteResult.ignored;
    _epoch++;
    final on = !state.ids.contains(productId);
    _emitIds(on ? {...state.ids, productId} : ({...state.ids}..remove(productId)));
    try {
      if (_userMode) {
        if (on) {
          await _api.addFavorite(productId);
        } else {
          await _api.removeFavorite(productId);
        }
      } else {
        await _toggleGuest(productId, on, slug);
      }
      // The add is persisted now: an open favorites list is out of date.
      if (on) _emitIds(state.ids, bumpVersion: true);
      return FavoriteResult(ok: true, on: on);
    } on Object catch (e) {
      // Roll back to the state before the tap.
      _emitIds(on ? ({...state.ids}..remove(productId)) : {...state.ids, productId});
      return FavoriteResult(ok: false, on: !on, error: e is CartError ? e : CartError.from(e));
    } finally {
      _pending.remove(productId);
      _settle();
    }
  }

  void _settle() {
    if (_pending.isEmpty && _reloadWhenIdle && !isClosed) {
      _reloadWhenIdle = false;
      unawaited(load());
    }
  }

  Future<void> _toggleGuest(int productId, bool on, String slugHint) async {
    final items = await _store.readFavorites();
    if (!on) {
      await _store.writeFavorites([
        for (final f in items) if (f.productId != productId) f,
      ]);
      return;
    }
    if (items.any((f) => f.productId == productId)) return;
    if (items.length >= GuestLimits.favorites) {
      throw CartError.local('FAVORITES_LIMIT_REACHED', max: GuestLimits.favorites);
    }
    // The product must be visible (hidden ones are 404 for everyone).
    final cards = await _lookup([productId]);
    if (cards.isEmpty) throw CartError.local('PRODUCT_NOT_FOUND');
    final saved = await _store.writeFavorites([
      ...items,
      GuestFavorite(productId: productId, slug: cards.first.slug),
    ]);
    if (!saved) {
      throw CartError.local('FAVORITES_LIMIT_REACHED', max: items.length);
    }
  }

  /// "انقل إلى السلة": signed in, `POST /favorites/{id}/move-to-cart` (adds with
  /// the cart's rules and removes the favorite; if the add fails the favorite
  /// stays). Guest: add to the guest cart (variable products: the first
  /// variant in stock), then leave the favorites.
  Future<FavoriteResult> moveToCart(ProductCard card) async {
    if (!_pending.add(card.id)) return FavoriteResult.ignored;
    _epoch++;
    try {
      if (_userMode) {
        final cart = await _api.moveToCart(card.id);
        _cart.setServerCart(cart);
      } else {
        if (!card.inStock) throw CartError.local('OUT_OF_STOCK');
        int? variantId;
        if (card.type == ProductType.variable) {
          final detail = await _detail(card.slug);
          variantId = detail.variants
              .where((v) => v.stockStatus != StockStatus.out)
              .firstOrNull
              ?.id;
          if (variantId == null) throw CartError.local('OUT_OF_STOCK');
        }
        final error = await _cart.add(
          productId: card.id,
          variantId: variantId,
          quantity: 1,
          slug: card.slug,
        );
        if (error != null) throw error;
        final items = await _store.readFavorites();
        await _store.writeFavorites([
          for (final f in items) if (f.productId != card.id) f,
        ]);
      }
      _emitIds({...state.ids}..remove(card.id));
      return const FavoriteResult(ok: true);
    } on Object catch (e) {
      return FavoriteResult(ok: false, error: e is CartError ? e : CartError.from(e));
    } finally {
      _pending.remove(card.id);
      _settle();
    }
  }

  void _emitIds(Set<int> ids, {bool bumpVersion = false}) {
    if (isClosed) return;
    emit(
      FavoritesState(
        ids: ids,
        ready: true,
        version: bumpVersion ? state.version + 1 : state.version,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}

import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Rail length on the home screen (same as lamsa-web).
const railSize = 12;

/// A top-level category with a cover: its own image, else the first product's.
final class CategoryTile extends Equatable {
  const CategoryTile({
    required this.id,
    required this.name,
    required this.slug,
    this.image,
  });

  final int id;
  final String name;
  final String slug;
  final ImageUrls? image;

  @override
  List<Object?> get props => [id, name, slug, image];
}

/// A page of products plus the filters that were really applied: a
/// parameter the backend rejects (`INVALID_FILTER`) is dropped and the
/// request retried, so a stale filter never leaves a screen empty.
final class ProductListResult extends Equatable {
  const ProductListResult({
    required this.page,
    required this.applied,
    this.ignored = const [],
  });

  final ProductPage page;
  final ListFilters applied;
  final List<String> ignored;

  @override
  List<Object?> get props => [page, applied, ignored];
}

final class FacetsResult extends Equatable {
  const FacetsResult({required this.facets, required this.applied});

  final Facets facets;
  final ListFilters applied;

  @override
  List<Object?> get props => [facets, applied];
}

final class _Entry {
  _Entry(this.value, this.expires);

  final Object? value;
  final DateTime expires;
}

/// In-memory read-through cache over [CatalogApi], scoped to the app session.
///
/// - TTLs follow the backend's own cache lifetimes (products 45 s, product
///   detail 120 s, categories/brands 300 s), so a cached answer is never
///   older than what the server itself would serve.
/// - Identical concurrent requests share one in-flight call.
/// - Failures are never cached.
/// - `refresh: true` (pull-to-refresh, retry) skips the read but refreshes
///   the entry.
///
/// There is deliberately no disk persistence and no ETag revalidation yet.
class CatalogRepository {
  CatalogRepository(this._api, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  static const productsTtl = Duration(seconds: 45);
  static const detailTtl = Duration(seconds: 120);
  static const taxonomyTtl = Duration(seconds: 300);
  static const bannersTtl = Duration(seconds: 120);

  static const _maxFilterRetries = 3;

  final CatalogApi _api;
  final DateTime Function() _now;
  final _cache = <String, _Entry>{};
  final _inflight = <String, Future<Object?>>{};

  Future<T> _cached<T>(
    String key,
    Duration ttl,
    Future<T> Function() load, {
    required bool refresh,
  }) {
    if (!refresh) {
      final hit = _cache[key];
      if (hit != null && hit.expires.isAfter(_now())) {
        return Future<T>.value(hit.value as T);
      }
      final pending = _inflight[key];
      if (pending != null) return pending.then((v) => v as T);
    }
    final future = load().then<Object?>((value) {
      _cache[key] = _Entry(value, _now().add(ttl));
      return value;
    });
    _inflight[key] = future;
    // `whenComplete` returns a new future whose error would be unhandled.
    future.then<void>((_) {}, onError: (_) {}).whenComplete(() {
      if (identical(_inflight[key], future)) _inflight.remove(key);
    });
    return future.then((v) => v as T);
  }

  /// Drops everything (e.g. after sign-in changes what a card shows).
  void clear() {
    _cache.clear();
    _inflight.clear();
  }

  Future<List<HomeBanner>> banners({bool refresh = false}) =>
      _cached('banners', bannersTtl, _api.banners, refresh: refresh);

  Future<List<CategoryNode>> categories({bool refresh = false}) =>
      _cached('categories', taxonomyTtl, _api.categories, refresh: refresh);

  /// Top-level categories that have products, each with a cover. A failed
  /// cover lookup only loses the picture.
  Future<List<CategoryTile>> categoryTiles({bool refresh = false}) async {
    final tree = await categories(refresh: refresh);
    final visible = tree.where((c) => c.productCount > 0);
    return Future.wait([
      for (final c in visible)
        () async {
          var image = c.image;
          if (image == null) {
            try {
              final page = await products(
                CategoryScope(c.slug),
                ListFilters.empty,
                pageSize: 1,
              );
              image = page.page.items.firstOrNull?.image;
            } on Object {
              image = null;
            }
          }
          return CategoryTile(id: c.id, name: c.name, slug: c.slug, image: image);
        }(),
    ]);
  }

  Future<CategoryDetail> category(String slug, {bool refresh = false}) =>
      _cached(
        'category:$slug',
        taxonomyTtl,
        () => _api.category(slug),
        refresh: refresh,
      );

  Future<List<Brand>> brands({bool refresh = false}) =>
      _cached('brands', taxonomyTtl, _api.brands, refresh: refresh);

  Future<Brand> brand(String slug, {bool refresh = false}) => _cached(
        'brand:$slug',
        taxonomyTtl,
        () => _api.brand(slug),
        refresh: refresh,
      );

  Future<ProductListResult> products(
    ListScope scope,
    ListFilters filters, {
    int page = 1,
    int pageSize = productPageSize,
    bool refresh = false,
  }) =>
      _cached(
        'products:${_scopeKey(scope)}|${filters.cacheKey}|$page|$pageSize',
        productsTtl,
        () async {
          final (value, applied, ignored) = await _withFilterRetry(
            filters,
            (f) => _api.products(
              CatalogQuery.products(scope, f, page: page, pageSize: pageSize),
            ),
          );
          return ProductListResult(
            page: value,
            applied: applied,
            ignored: ignored,
          );
        },
        refresh: refresh,
      );

  Future<FacetsResult> facets(
    ListScope scope,
    ListFilters filters, {
    bool refresh = false,
  }) =>
      _cached(
        'facets:${_scopeKey(scope)}|${filters.cacheKey}',
        productsTtl,
        () async {
          final (value, applied, _) = await _withFilterRetry(
            filters,
            (f) => _api.facets(CatalogQuery.facets(scope, f)),
          );
          return FacetsResult(facets: value, applied: applied);
        },
        refresh: refresh,
      );

  Future<ProductDetail> product(String slug, {bool refresh = false}) =>
      _cached(
        'product:$slug',
        detailTtl,
        () => _api.product(slug),
        refresh: refresh,
      );

  Future<List<ProductCard>> related(String slug, {bool refresh = false}) =>
      _cached(
        'related:$slug',
        detailTtl,
        () => _api.related(slug),
        refresh: refresh,
      );

  static String _scopeKey(ListScope scope) => switch (scope) {
        CategoryScope(:final slug) => 'category:$slug',
        BrandScope(:final slug) => 'brand:$slug',
        NewScope() => 'new',
        SaleScope() => 'sale',
        SearchScope() => 'search',
      };

  /// Runs [request]; on `422 INVALID_FILTER` drops the rejected parameter
  /// and retries (at most [_maxFilterRetries] times).
  static Future<(T, ListFilters, List<String>)> _withFilterRetry<T>(
    ListFilters filters,
    Future<T> Function(ListFilters) request,
  ) async {
    var current = filters;
    final ignored = <String>[];
    for (var attempt = 0;; attempt++) {
      try {
        return (await request(current), current, ignored);
      } on ApiError catch (e) {
        final param = invalidParam(e);
        if (param == null || attempt >= _maxFilterRetries) rethrow;
        ignored.add(param);
        current = current.dropParam(param);
      }
    }
  }

  /// The rejected parameter of an `INVALID_FILTER` error, if that is the error.
  static String? invalidParam(ApiError e) {
    if (e.code != 'INVALID_FILTER') return null;
    final d = e.details;
    if (d is Map<String, dynamic>) {
      final p = d['param'];
      if (p is String && p.isNotEmpty) return p;
    }
    return null;
  }
}

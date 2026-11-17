import 'package:dio/dio.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Typed client for the public catalog endpoints. Every call is anonymous
/// (no token): a guest always gets `is_favorite: false`, and a stale token
/// can never turn a browse into a 401.
///
/// Failures surface as [ApiError] (never a raw `DioException`).
class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  static final _public = Options(extra: {AuthExtra.noAuth: true});

  Future<List<HomeBanner>> banners() async => [
        for (final j in await _list('/banners')) HomeBanner.fromJson(j),
      ];

  Future<List<CategoryNode>> categories() async => [
        for (final j in await _list('/categories')) CategoryNode.fromJson(j),
      ];

  Future<CategoryDetail> category(String slug) async =>
      CategoryDetail.fromJson(await _map('/categories/${_seg(slug)}'));

  Future<List<Brand>> brands() async => [
        for (final j in await _list('/brands')) Brand.fromJson(j),
      ];

  Future<Brand> brand(String slug) async =>
      Brand.fromJson(await _map('/brands/${_seg(slug)}'));

  /// [query] comes from `CatalogQuery.products`.
  Future<ProductPage> products(List<(String, String)> query) async =>
      ProductPage.fromJson(await _map('/products', query));

  /// The visible products among [ids] (at most 100), out-of-stock ones
  /// included, in the order given. Bad ids are a `422`.
  Future<List<ProductCard>> productsByIds(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final page = await products([('ids', ids.join(',')), ('page_size', '100')]);
    return page.items;
  }

  /// [query] comes from `CatalogQuery.facets`.
  Future<Facets> facets(List<(String, String)> query) async =>
      Facets.fromJson(await _map('/products/facets', query));

  Future<ProductDetail> product(String slug) async =>
      ProductDetail.fromJson(await _map('/products/${_seg(slug)}'));

  Future<List<ProductCard>> related(String slug, {int limit = 12}) async => [
        for (final j in await _list(
          '/products/${_seg(slug)}/related',
          [('limit', '$limit')],
        ))
          ProductCard.fromJson(j),
      ];

  static String _seg(String slug) => Uri.encodeComponent(slug);

  Future<Map<String, dynamic>> _map(
    String path, [
    List<(String, String)> query = const [],
  ]) async =>
      (await _get<Map<String, dynamic>>(path, query))!;

  Future<List<Map<String, dynamic>>> _list(
    String path, [
    List<(String, String)> query = const [],
  ]) async {
    final data = await _get<List<dynamic>>(path, query);
    return [for (final e in data!) e as Map<String, dynamic>];
  }

  Future<T?> _get<T>(String path, List<(String, String)> query) async {
    // Built by hand so repeated names (`brand=a&brand=b`) stay repeated.
    final qs = CatalogQuery.encode(query);
    try {
      final r = await _dio.get<T>(
        qs.isEmpty ? path : '$path?$qs',
        options: _public,
      );
      return r.data;
    } on DioException catch (e) {
      final error = e.error;
      throw error is ApiError ? error : ApiError.fromDio(e);
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

ProductCard card(
  int id, {
  String? name,
  String price = '15000.00',
  String? compareAt,
  int? discount,
  String currency = 'SYP',
  bool isNew = false,
  bool inStock = true,
  BrandRef? brand = const BrandRef(id: 1, name: 'لمى', slug: 'luma'),
  List<Swatch> swatches = const [],
}) =>
    ProductCard(
      id: id,
      slug: 'p$id',
      name: name ?? 'منتج $id',
      type: ProductType.simple,
      currency: currency,
      price: price,
      compareAtPrice: compareAt,
      discountPercent: discount,
      isNew: isNew,
      isOnSale: compareAt != null,
      inStock: inStock,
      brand: brand,
      category: const CategoryRef(id: 1, name: 'مكياج', slug: 'makeup'),
      swatches: swatches,
    );

ProductPage page(List<ProductCard> items, {int? total, int page = 1}) =>
    ProductPage(
      items: items,
      page: page,
      pageSize: productPageSize,
      total: total ?? items.length,
    );

/// Hand-written fake of the catalog API: serves configured data and records
/// every call so tests can assert what was (not) fetched.
class FakeCatalogApi implements CatalogApi {
  List<HomeBanner> bannersData = const [];
  List<CategoryNode> categoriesData = const [];
  List<Brand> brandsData = const [];
  ProductPage Function(List<(String, String)> query) productsHandler =
      (_) => page(const []);
  Facets facetsData = const Facets();
  ProductDetail? detail;
  List<ProductCard> relatedData = const [];
  CategoryDetail? categoryData;
  Brand? brandData;

  /// Endpoints that throw (by name: banners, products, ...).
  final Set<String> failing = {};
  Object? Function(String endpoint, List<(String, String)> query)? errorFor;

  final calls = <String>[];
  final productQueries = <List<(String, String)>>[];
  final facetQueries = <List<(String, String)>>[];

  int count(String name) => calls.where((c) => c == name).length;

  Future<T> _run<T>(
    String name,
    T Function() data, [
    List<(String, String)> query = const [],
  ]) async {
    calls.add(name);
    final custom = errorFor?.call(name, query);
    if (custom != null) throw custom;
    if (failing.contains(name)) throw StateError('boom $name');
    return data();
  }

  @override
  Future<List<HomeBanner>> banners() => _run('banners', () => bannersData);

  @override
  Future<List<CategoryNode>> categories() =>
      _run('categories', () => categoriesData);

  @override
  Future<CategoryDetail> category(String slug) =>
      _run('category', () => categoryData!);

  @override
  Future<List<Brand>> brands() => _run('brands', () => brandsData);

  @override
  Future<Brand> brand(String slug) => _run('brand', () => brandData!);

  @override
  Future<ProductPage> products(List<(String, String)> query) {
    productQueries.add(query);
    return _run('products', () => productsHandler(query), query);
  }

  @override
  Future<Facets> facets(List<(String, String)> query) {
    facetQueries.add(query);
    return _run('facets', () => facetsData, query);
  }

  @override
  Future<ProductDetail> product(String slug) =>
      _run('product', () => detail!);

  @override
  Future<List<ProductCard>> related(String slug, {int limit = 12}) =>
      _run('related', () => relatedData);
}

/// Value of the first `name` pair in a recorded query, if any.
String? queryValue(List<(String, String)> query, String name) {
  for (final p in query) {
    if (p.$1 == name) return p.$2;
  }
  return null;
}

/// Pumps [child] in a themed Arabic/RTL app with the repository provided.
Future<void> pumpCatalog(
  WidgetTester tester,
  Widget child,
  CatalogRepository repo,
) async {
  await tester.pumpWidget(
    RepositoryProvider<CatalogRepository>.value(
      value: repo,
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        builder: (context, c) =>
            Directionality(textDirection: TextDirection.rtl, child: c!),
        home: child,
      ),
    ),
  );
}

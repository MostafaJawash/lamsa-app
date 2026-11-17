import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/images/image_urls.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/core/network/interceptors.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

import 'catalog_fakes.dart';

class _Adapter implements HttpClientAdapter {
  _Adapter(this.respond);

  final ResponseBody Function(RequestOptions) respond;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

void main() {
  group('CatalogApi', () {
    test('sends the assembled query, anonymously, with repeats and Arabic', () async {
      final adapter = _Adapter((_) => _json({'items': <Object>[], 'page': 1, 'page_size': 24, 'total': 0}));
      final dio = Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
        ..httpClientAdapter = adapter;
      final api = CatalogApi(dio);

      await api.products(
        CatalogQuery.products(
          const CategoryScope('care'),
          ListFilters.of(
            [
              ('attr.skin_type', 'جافة'),
              ('attr.skin_type', 'حساسة'),
              ('min_price', '5000'),
              ('price_currency', 'SYP'),
              ('sort', 'price_asc'),
            ],
            const CategoryScope('care'),
          ),
          page: 2,
        ),
      );

      final req = adapter.requests.single;
      expect(req.path, startsWith('/products?'));
      expect(req.path, contains('category=care'));
      expect(req.path, contains('page=2'));
      expect(req.path, contains('page_size=24'));
      expect(req.path, contains('sort=price_asc'));
      expect(req.path, contains('price_currency=SYP'));
      expect('attr.skin_type='.allMatches(req.path).length, 2);
      expect(req.path, contains(Uri.encodeQueryComponent('جافة')));
      // Guests never carry a token (and a stale one can't cause a 401).
      expect(req.extra[AuthExtra.noAuth], isTrue);
    });

    test('slugs are path-encoded', () async {
      final adapter = _Adapter((_) => _json(<Object>[]));
      final api = CatalogApi(
        Dio(BaseOptions(baseUrl: 'http://x/api/v1'))..httpClientAdapter = adapter,
      );
      await api.related('عطر ورد');
      expect(adapter.requests.single.path, startsWith('/products/'));
      expect(adapter.requests.single.path, contains('%D8%B9'));
      expect(adapter.requests.single.path, contains('limit=12'));
    });

    test('failures surface as ApiError with the backend envelope', () async {
      final adapter = _Adapter(
        (_) => _json({
          'error': {
            'code': 'INVALID_FILTER',
            'message': 'bad',
            'details': {'param': 'attr.x'},
          },
        }, 422),
      );
      final dio = Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
        ..httpClientAdapter = adapter
        ..interceptors.add(ErrorMappingInterceptor());
      final api = CatalogApi(dio);
      await expectLater(
        api.facets(const []),
        throwsA(
          isA<ApiError>()
              .having((e) => e.code, 'code', 'INVALID_FILTER')
              .having((e) => e.status, 'status', 422),
        ),
      );
    });
  });

  group('CatalogRepository cache', () {
    late FakeCatalogApi api;
    late DateTime now;
    late CatalogRepository repo;

    setUp(() {
      api = FakeCatalogApi()
        ..brandsData = const [
          Brand(id: 1, name: 'لمى', slug: 'luma', productCount: 2),
        ];
      now = DateTime(2026);
      repo = CatalogRepository(api, now: () => now);
    });

    test('a second read inside the TTL does not hit the network', () async {
      await repo.brands();
      await repo.brands();
      expect(api.count('brands'), 1);
    });

    test('an entry expires after its TTL', () async {
      await repo.brands();
      now = now.add(CatalogRepository.taxonomyTtl + const Duration(seconds: 1));
      await repo.brands();
      expect(api.count('brands'), 2);
    });

    test('products live shorter than brands (45 s vs 300 s)', () async {
      await repo.products(const NewScope(), ListFilters.empty);
      await repo.brands();
      now = now.add(const Duration(seconds: 60));
      await repo.products(const NewScope(), ListFilters.empty);
      await repo.brands();
      expect(api.count('products'), 2);
      expect(api.count('brands'), 1);
    });

    test('refresh bypasses the cache and re-caches', () async {
      await repo.brands();
      await repo.brands(refresh: true);
      await repo.brands();
      expect(api.count('brands'), 2);
    });

    test('concurrent identical requests share one call', () async {
      await Future.wait([repo.brands(), repo.brands(), repo.brands()]);
      expect(api.count('brands'), 1);
    });

    test('different filters or pages are different entries', () async {
      const scope = CategoryScope('care');
      await repo.products(scope, ListFilters.empty);
      await repo.products(scope, ListFilters.empty, page: 2);
      await repo.products(scope, ListFilters.of([('brand', 'a')], scope));
      await repo.products(scope, ListFilters.empty);
      expect(api.count('products'), 3);
    });

    test('failures are not cached', () async {
      api.failing.add('brands');
      await expectLater(repo.brands(), throwsStateError);
      api.failing.clear();
      expect(await repo.brands(), isNotEmpty);
      expect(api.count('brands'), 2);
    });

    test('clear drops everything', () async {
      await repo.brands();
      repo.clear();
      await repo.brands();
      expect(api.count('brands'), 2);
    });

    test('INVALID_FILTER drops the rejected param and retries', () async {
      const scope = CategoryScope('care');
      api.productsHandler = (q) => page([card(1)]);
      api.errorFor = (String endpoint, List<(String, String)> query) {
        if (endpoint == 'products' && queryValue(query, 'attr.bad') != null) {
          return const ApiError(
            code: 'INVALID_FILTER',
            backendMessage: null,
            status: 422,
            details: {'param': 'attr.bad'},
          );
        }
        return null;
      };
      final result = await repo.products(
        scope,
        ListFilters.of([('attr.bad', 'x'), ('brand', 'luma')], scope),
      );
      expect(result.ignored, ['attr.bad']);
      expect(result.applied.pairs, [('brand', 'luma')]);
      expect(api.count('products'), 2);
      expect(queryValue(api.productQueries.last, 'attr.bad'), isNull);
    });

    test('other errors are not retried', () async {
      api.errorFor = (e, q) => const ApiError(
            code: 'SERVER_ERROR',
            backendMessage: null,
            status: 500,
          );
      await expectLater(
        repo.products(const NewScope(), ListFilters.empty),
        throwsA(isA<ApiError>()),
      );
      expect(api.count('products'), 1);
    });

    test('category tiles use the category image, else the first product image', () async {
      const image = ImageUrls(thumb: 't', medium: 'm', large: 'l');
      api
        ..categoriesData = const [
          CategoryNode(id: 1, name: 'مكياج', slug: 'makeup', productCount: 3),
          CategoryNode(id: 2, name: 'فارغ', slug: 'empty', productCount: 0),
          CategoryNode(
            id: 3,
            name: 'شعر',
            slug: 'hair',
            productCount: 2,
            image: image,
          ),
        ]
        ..productsHandler = (q) => page([
              const ProductCard(
                id: 1,
                slug: 'a',
                name: 'a',
                type: ProductType.simple,
                currency: 'SYP',
                price: '1.00',
                image: image,
              ),
            ]);
      final tiles = await repo.categoryTiles();
      expect(tiles.map((t) => t.slug), ['makeup', 'hair']); // empty hidden
      expect(tiles.first.image, image); // from the first product
      expect(api.count('products'), 1); // hair had its own image
    });

    test('a failed cover lookup only loses the picture', () async {
      api
        ..categoriesData = const [
          CategoryNode(id: 1, name: 'مكياج', slug: 'makeup', productCount: 3),
        ]
        ..failing.add('products');
      final tiles = await repo.categoryTiles();
      expect(tiles.single.image, isNull);
    });
  });
}

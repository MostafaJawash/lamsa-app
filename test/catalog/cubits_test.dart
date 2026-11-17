import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/catalog/cubit/product_list_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

import 'catalog_fakes.dart';

void main() {
  late FakeCatalogApi api;
  late CatalogRepository repo;

  setUp(() {
    api = FakeCatalogApi();
    repo = CatalogRepository(api);
  });

  test('loads page 1, then infinite scroll appends page 2 without repeats', () async {
    final all = [for (var i = 1; i <= 30; i++) card(i)];
    api.productsHandler = (q) {
      final p = int.parse(queryValue(q, 'page') ?? '1');
      final items = p == 1 ? all.sublist(0, 24) : all.sublist(24);
      return page(items, total: 30, page: p);
    };
    final cubit = ProductListCubit(repo, const NewScope());
    addTearDown(cubit.close);

    await cubit.load();
    expect(cubit.state.status, ListStatus.loaded);
    expect(cubit.state.items.length, 24);
    expect(cubit.state.hasMore, isTrue);

    await cubit.loadMore();
    expect(cubit.state.items.length, 30);
    expect(cubit.state.hasMore, isFalse);
    expect(queryValue(api.productQueries.last, 'page'), '2');

    // Nothing left: no further request.
    final calls = api.count('products');
    await cubit.loadMore();
    expect(api.count('products'), calls);
  });

  test('concurrent loadMore calls fetch the page once', () async {
    api.productsHandler = (q) => page([card(1)], total: 50);
    final cubit = ProductListCubit(repo, const NewScope());
    addTearDown(cubit.close);
    await cubit.load();
    final before = api.count('products');
    await Future.wait([cubit.loadMore(), cubit.loadMore(), cubit.loadMore()]);
    expect(api.count('products') - before, 1);
  });

  test('a failed next page keeps the items and can be retried', () async {
    api.productsHandler = (q) => page([card(1)], total: 50);
    final cubit = ProductListCubit(repo, const NewScope());
    addTearDown(cubit.close);
    await cubit.load();

    api.failing.add('products');
    await cubit.loadMore();
    expect(cubit.state.loadMoreFailed, isTrue);
    expect(cubit.state.items.length, 1);
    expect(cubit.state.status, ListStatus.loaded);

    api.failing.clear();
    api.productsHandler = (q) => page([card(2)], total: 50, page: 2);
    await cubit.loadMore();
    expect(cubit.state.loadMoreFailed, isFalse);
    expect(cubit.state.items.length, 2);
  });

  test('changing filters restarts from page 1', () async {
    api.productsHandler = (q) => page(
          [card(queryValue(q, 'brand') == 'luma' ? 9 : 1)],
          total: 80,
          page: int.parse(queryValue(q, 'page') ?? '1'),
        );
    const scope = CategoryScope('care');
    final cubit = ProductListCubit(repo, scope);
    addTearDown(cubit.close);
    await cubit.load();
    await cubit.loadMore();
    expect(cubit.state.page, 2);

    await cubit.setFilters(cubit.state.filters.toggle('brand', 'luma', scope));
    expect(cubit.state.page, 1);
    expect(cubit.state.items.single.id, 9);
    expect(queryValue(api.productQueries.last, 'page'), isNull);
  });

  test('a slow superseded response never overwrites the newer one', () async {
    final slowApi = _SlowApi()
      ..productsHandler = (q) => page([card(queryValue(q, 'brand') == 'a' ? 1 : 2)]);
    const scope = CategoryScope('care');
    final cubit = ProductListCubit(CatalogRepository(slowApi), scope);
    addTearDown(cubit.close);

    // "a" is held back; "b" completes first, then "a" finally answers.
    final first = cubit.setFilters(ListFilters.of([('brand', 'a')], scope));
    final second = cubit.setFilters(ListFilters.of([('brand', 'b')], scope));
    await second;
    slowApi.gate.complete();
    await first;

    expect(cubit.state.items.single.id, 2);
    expect(cubit.state.filters.has('brand', 'b'), isTrue);
  });

  test('search stays idle without a query and sends the raw text', () async {
    api.productsHandler = (q) => page([card(1)]);
    final cubit = ProductListCubit(repo, const SearchScope());
    addTearDown(cubit.close);
    expect(cubit.state.status, ListStatus.idle);
    await cubit.load();
    expect(api.productQueries, isEmpty);

    await cubit.search('  عطر ورد ');
    expect(queryValue(api.productQueries.single, 'q'), 'عطر ورد');
    expect(cubit.state.status, ListStatus.loaded);

    await cubit.search('   ');
    expect(cubit.state.status, ListStatus.idle);
  });

  test('a 404 category or brand becomes notFound', () async {
    api.errorFor = (e, q) => e == 'category'
        ? const ApiError(
            code: 'CATEGORY_NOT_FOUND',
            backendMessage: null,
            status: 404,
          )
        : null;
    final cubit = ProductListCubit(repo, const CategoryScope('nope'));
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, ListStatus.notFound);
  });

  test('facet failures never block the list', () async {
    api.productsHandler = (q) => page([card(1)]);
    api.failing.add('facets');
    final cubit = ProductListCubit(repo, const NewScope());
    addTearDown(cubit.close);
    await cubit.load();
    expect(cubit.state.status, ListStatus.loaded);
    expect(cubit.state.facets, isNull);
    expect(cubit.state.facetsFailed, isTrue);
  });
}

/// Holds back the answer for `brand=a` until [gate] completes.
class _SlowApi extends FakeCatalogApi {
  final gate = Completer<void>();

  @override
  Future<ProductPage> products(List<(String, String)> query) async {
    if (queryValue(query, 'brand') == 'a') await gate.future;
    return super.products(query);
  }
}

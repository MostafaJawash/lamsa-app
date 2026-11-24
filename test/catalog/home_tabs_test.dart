import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/features/catalog/cubit/home_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/home_screen.dart';

import 'catalog_fakes.dart';

const _gifts = CategoryDetail(
  id: 5,
  name: 'علبة هدايا',
  slug: giftsCategorySlug,
  productCount: 1,
);

const _serverError =
    ApiError(code: 'INTERNAL_ERROR', backendMessage: null, status: 500);
const _notFound = ApiError(code: 'NOT_FOUND', backendMessage: null, status: 404);

bool _isGifts(List<(String, String)> q) =>
    queryValue(q, 'category') == giftsCategorySlug;

void main() {
  late FakeCatalogApi api;
  late CatalogRepository repo;

  setUp(() {
    api = FakeCatalogApi();
    repo = CatalogRepository(api);
  });

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpCatalog(tester, const HomeScreen(), repo);
    await tester.pumpAndSettle();
  }

  testWidgets('three tabs; the gifts label is the category own name',
      (tester) async {
    api.categoryData = _gifts;
    await pumpHome(tester);
    expect(find.text(Strings.homeTabMain), findsOneWidget);
    expect(find.text('علبة هدايا'), findsOneWidget);
    expect(find.text(Strings.homeTabAll), findsOneWidget);
  });

  testWidgets('gifts tab scopes to the real category slug', (tester) async {
    api
      ..categoryData = _gifts
      ..productsHandler = (q) => _isGifts(q)
          ? page([card(7, name: 'علبة الورد')])
          : page([card(1, name: 'منتج عادي')]);
    await pumpHome(tester);

    await tester.tap(find.text('علبة هدايا'));
    await tester.pumpAndSettle();

    expect(giftsCategorySlug, 'demo-gifts');
    expect(find.text('علبة الورد'), findsOneWidget);
    expect(api.productQueries.any(_isGifts), isTrue);
  });

  testWidgets('all-products tab sends no scope or filter params',
      (tester) async {
    api.productsHandler = (q) => page([card(3, name: 'منتج الكل')]);
    await pumpHome(tester);
    api.productQueries.clear();

    await tester.tap(find.text(Strings.homeTabAll));
    await tester.pumpAndSettle();

    expect(find.text('منتج الكل'), findsOneWidget);
    expect(api.productQueries, isNotEmpty);
    for (final q in api.productQueries) {
      for (final key in ['category', 'brand', 'is_new', 'on_sale', 'q']) {
        expect(queryValue(q, key), isNull, reason: key);
      }
    }
  });

  testWidgets('a failing tab does not break the others', (tester) async {
    api.categoryData = _gifts;
    api.productsHandler = (q) => page([card(3, name: 'منتج الكل')]);
    api.errorFor =
        (name, q) => name == 'products' && _isGifts(q) ? _serverError : null;
    await pumpHome(tester);

    await tester.tap(find.text('علبة هدايا'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.retry), findsOneWidget);

    await tester.tap(find.text(Strings.homeTabAll));
    await tester.pumpAndSettle();
    expect(find.text('منتج الكل'), findsOneWidget);
    expect(find.text(Strings.retry), findsNothing);

    await tester.tap(find.text(Strings.homeTabMain));
    await tester.pumpAndSettle();
    expect(find.text(Strings.homeNewArrivals), findsWidgets);
  });

  testWidgets('a missing gifts category is an empty state, not a crash',
      (tester) async {
    api.errorFor = (name, q) =>
        name == 'category' || (name == 'products' && _isGifts(q))
            ? _notFound
            : null;
    await pumpHome(tester);
    expect(find.text(Strings.homeTabGifts), findsOneWidget); // fallback label

    await tester.tap(find.text(Strings.homeTabGifts));
    await tester.pumpAndSettle();
    expect(find.text(Strings.giftsUnavailable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty gifts category shows the empty state', (tester) async {
    api.categoryData = _gifts;
    await pumpHome(tester);
    await tester.tap(find.text('علبة هدايا'));
    await tester.pumpAndSettle();
    expect(find.text(Strings.giftsUnavailable), findsOneWidget);
  });

  testWidgets('home tab shows the connection state when everything is offline',
      (tester) async {
    final saved = connectivityProbe;
    connectivityProbe = () async => false;
    addTearDown(() => connectivityProbe = saved);
    api.errorFor = (name, _) => name == 'banners'
        ? null
        : const ApiError(code: ApiError.networkCode, backendMessage: null);
    await pumpHome(tester);
    expect(find.text(Strings.noInternetTitle), findsOneWidget);
  });

  testWidgets('main tab no longer has the chip row; new/sale/brands stay reachable',
      (tester) async {
    api
      ..brandsData = const [
        Brand(id: 7, name: 'بيلا', slug: 'bella', productCount: 3),
      ]
      ..productsHandler = (q) => page([card(1, name: 'سيروم')]);
    await pumpHome(tester);

    // The three pills under the search bar are gone.
    expect(find.byType(ActionChip), findsNothing);

    // Entry points that remain on the main tab: "see all" for the new and
    // sale rails, and the brands row's "all brands".
    expect(find.text(Strings.seeAll), findsNWidgets(2));
    expect(find.text(Strings.allBrands), findsOneWidget);
  });

  testWidgets('categories tab keeps its chip row', (tester) async {
    tester.view.physicalSize = const Size(420, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    api.categoriesData = const [
      CategoryNode(id: 1, name: 'مكياج', slug: 'makeup', productCount: 4),
    ];
    await pumpCatalog(tester, const CategoriesScreen(), repo);
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(3));
  });
}

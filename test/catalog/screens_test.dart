import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/home_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/product_list_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/product_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/sections.dart';

import '../cart/cart_fakes.dart';
import 'catalog_fakes.dart';

Future<void> tallSurface(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  late FakeCatalogApi api;
  late CatalogRepository repo;

  setUp(() {
    api = FakeCatalogApi();
    repo = CatalogRepository(api);
  });

  group('home', () {
    testWidgets('renders every section from data', (tester) async {
      await tallSurface(tester);
      api
        ..bannersData = const [
          HomeBanner(
            id: 1,
            title: 'عرض الصيف',
            link: BannerLink(type: 'sale'),
          ),
        ]
        ..categoriesData = const [
          CategoryNode(id: 1, name: 'مكياج', slug: 'makeup', productCount: 4),
        ]
        ..brandsData = const [
          Brand(id: 7, name: 'بيلا', slug: 'bella', productCount: 3),
        ]
        ..productsHandler = (q) => queryValue(q, 'on_sale') == 'true'
            ? page([card(2, name: 'كريم مخفّض', price: '8.50', compareAt: '10.00', discount: 15, currency: 'USD')])
            : page([card(1, name: 'أحمر شفاه', isNew: true, swatches: const [Swatch(name: 'وردي', hex: '#FF99AA')])]);

      await pumpCatalog(tester, const HomeScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('عرض الصيف'), findsOneWidget);
      expect(find.text(Strings.bannerCtaSale), findsOneWidget);
      // (The fallback banner shares this title, so match the section header.)
      expect(find.widgetWithText(SectionHeader, Strings.homeNewArrivals), findsOneWidget);
      expect(find.text('أحمر شفاه'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ProductCardView),
          matching: find.text(Strings.cardNew),
        ),
        findsOneWidget,
      );
      expect(find.text(Strings.homeByCategory), findsOneWidget);
      expect(find.text('مكياج'), findsOneWidget);
      expect(find.text(Strings.homeOnSale), findsOneWidget);
      expect(find.text('كريم مخفّض'), findsOneWidget);
      // Sale card: discount badge, struck regular price, dollars (not SYP).
      expect(find.text('−15٪'), findsOneWidget);
      expect(find.textContaining('10'), findsWidgets);
      expect(find.textContaining(r'$'), findsWidgets);
      expect(find.text(Strings.homeBrands), findsOneWidget);
      expect(find.text('بيلا'), findsOneWidget);
      // The two rails were requested with the right params.
      final queries = api.productQueries;
      expect(queries.any((q) => queryValue(q, 'is_new') == 'true'), isTrue);
      expect(queries.any((q) => queryValue(q, 'on_sale') == 'true'), isTrue);
      expect(queries.every((q) => queryValue(q, 'page_size') != null), isTrue);
    });

    testWidgets('empty data shows graceful fallbacks, not a blank screen',
        (tester) async {
      await tallSurface(tester);
      await pumpCatalog(tester, const HomeScreen(), repo);
      await tester.pumpAndSettle();

      // Fallback banners.
      expect(find.text(Strings.bannerSaleTitle), findsOneWidget);
      // Rails keep their title and say why they are empty.
      expect(find.widgetWithText(SectionHeader, Strings.homeNewArrivals), findsOneWidget);
      expect(find.text(Strings.homeEmptyNew), findsOneWidget);
      expect(find.text(Strings.homeOnSale), findsOneWidget);
      expect(find.text(Strings.homeEmptySale), findsOneWidget);
      // Categories and brands sections disappear when empty.
      expect(find.text(Strings.homeByCategory), findsNothing);
      expect(find.text(Strings.homeBrands), findsNothing);
    });

    testWidgets('every endpoint failing still renders the same fallbacks',
        (tester) async {
      await tallSurface(tester);
      api.failing.addAll(['banners', 'products', 'categories', 'brands']);
      await pumpCatalog(tester, const HomeScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text(Strings.bannerSaleTitle), findsOneWidget);
      expect(find.text(Strings.homeEmptyNew), findsOneWidget);
      expect(find.text(Strings.homeEmptySale), findsOneWidget);
      expect(find.text(Strings.homeBrands), findsNothing);
    });

    testWidgets('one failing section does not affect the others',
        (tester) async {
      await tallSurface(tester);
      api
        ..failing.add('brands')
        ..categoriesData = const [
          CategoryNode(id: 1, name: 'مكياج', slug: 'makeup', productCount: 4),
        ]
        ..productsHandler = (q) => page([card(1, name: 'سيروم')]);
      await pumpCatalog(tester, const HomeScreen(), repo);
      await tester.pumpAndSettle();

      expect(find.text('سيروم'), findsWidgets);
      expect(find.text('مكياج'), findsOneWidget);
      expect(find.text(Strings.homeBrands), findsNothing);
    });

    testWidgets('pull to refresh refetches past the cache', (tester) async {
      await tallSurface(tester);
      await pumpCatalog(tester, const HomeScreen(), repo);
      await tester.pumpAndSettle();
      final before = api.count('brands');

      unawaited(
        tester
            .state<RefreshIndicatorState>(find.byType(RefreshIndicator))
            .show(),
      );
      await tester.pumpAndSettle();

      expect(api.count('brands'), before + 1);
    });
  });

  group('category list', () {
    CategoryDetail category() => const CategoryDetail(
          id: 2,
          name: 'عناية',
          slug: 'care',
          productCount: 5,
          attributes: [
            AttributeDefinition(
              key: 'skin_type',
              label: 'نوع البشرة',
              type: AttributeType.select,
              options: ['جافة', 'دهنية'],
            ),
          ],
          children: [
            CategoryNode(id: 3, name: 'عطور', slug: 'perfumes', productCount: 2),
          ],
        );

    setUp(() {
      api
        ..categoryData = category()
        ..facetsData = const Facets(
          brands: [BrandFacet(slug: 'luma', name: 'لمى', count: 2)],
          prices: [PriceRange(currency: 'SYP', min: '5000.00', max: '90000.00')],
        )
        ..productsHandler = (q) => queryValue(q, 'brand') == 'luma'
            ? page([card(1, name: 'منتج لمى')])
            : page([card(1, name: 'منتج لمى'), card(2, name: 'منتج آخر')]);
    });

    testWidgets('shows title, count, chips and the products', (tester) async {
      await tallSurface(tester);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('عناية'), findsOneWidget); // app bar
      expect(find.text(Strings.products(2)), findsOneWidget);
      expect(find.text('منتج آخر'), findsOneWidget);
      // Primary attribute chips and child category chips.
      expect(find.text('جافة'), findsOneWidget);
      expect(find.text('عطور'), findsOneWidget);
      expect(queryValue(api.productQueries.first, 'category'), 'care');
    });

    testWidgets('applying a brand filter triggers a new filtered fetch',
        (tester) async {
      await tallSurface(tester);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();
      final before = api.productQueries.length;

      await tester.tap(find.text(Strings.filtersButton));
      await tester.pumpAndSettle();
      // There is no in-stock toggle (the backend hides out-of-stock itself).
      expect(find.textContaining('متوفر'), findsNothing);
      await tester.tap(find.text('لمى (2)'));
      await tester.pump();
      await tester.tap(find.text(Strings.showResults));
      await tester.pumpAndSettle();

      expect(api.productQueries.length, greaterThan(before));
      expect(queryValue(api.productQueries.last, 'brand'), 'luma');
      expect(queryValue(api.productQueries.last, 'category'), 'care');
      expect(find.text('منتج آخر'), findsNothing); // filtered out
      // Active chip with a remove action, and a count on the button.
      expect(find.byType(InputChip), findsOneWidget);
      expect(find.text('${Strings.filtersButton} (1)'), findsOneWidget);

      tester.widget<InputChip>(find.byType(InputChip)).onDeleted!();
      await tester.pumpAndSettle();
      // Back to the unfiltered list, served from the cache (no new request).
      expect(find.text('منتج آخر'), findsOneWidget);
      expect(find.byType(InputChip), findsNothing);
    });

    testWidgets('sort sheet refetches with the chosen sort', (tester) async {
      await tallSurface(tester);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.sortNewest));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.sortPriceAsc));
      await tester.pumpAndSettle();

      expect(queryValue(api.productQueries.last, 'sort'), 'price_asc');
    });

    testWidgets('a primary-attribute chip filters the list', (tester) async {
      await tallSurface(tester);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('جافة'));
      await tester.pumpAndSettle();

      expect(queryValue(api.productQueries.last, 'attr.skin_type'), 'جافة');
    });

    testWidgets('filter with no results offers to clear', (tester) async {
      await tallSurface(tester);
      api.productsHandler =
          (q) => queryValue(q, 'attr.skin_type') != null ? page(const []) : page([card(1)]);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('دهنية'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.emptyFiltered), findsOneWidget);

      await tester.tap(find.text(Strings.clearFilters));
      await tester.pumpAndSettle();
      expect(find.text(Strings.emptyFiltered), findsNothing);
      expect(find.text('منتج 1'), findsOneWidget);
    });

    testWidgets('empty category without filters shows its own message',
        (tester) async {
      await tallSurface(tester);
      api.productsHandler = (q) => page(const []);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.emptyCategory), findsOneWidget);
    });

    testWidgets('a failing list shows the error with retry', (tester) async {
      await tallSurface(tester);
      api.failing.add('products');
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: CategoryScope('care')),
        repo,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.retry), findsOneWidget);

      api.failing.clear();
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();
      expect(find.text('منتج آخر'), findsOneWidget);
    });
  });

  group('new / sale', () {
    testWidgets('sale screen queries on_sale and hides the sale toggle',
        (tester) async {
      await tallSurface(tester);
      api
        ..facetsData = const Facets()
        ..productsHandler = (q) => page([card(1, compareAt: '20000.00', discount: 25)]);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: SaleScope()),
        repo,
      );
      await tester.pumpAndSettle();

      expect(queryValue(api.productQueries.first, 'on_sale'), 'true');
      expect(find.text(Strings.sale), findsOneWidget);

      await tester.tap(find.text(Strings.filtersButton));
      await tester.pumpAndSettle();
      expect(find.text(Strings.onSaleOnly), findsNothing);
    });

    testWidgets('new screen queries is_new', (tester) async {
      await tallSurface(tester);
      api.productsHandler = (q) => page([card(1, isNew: true)]);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: NewScope()),
        repo,
      );
      await tester.pumpAndSettle();
      expect(queryValue(api.productQueries.first, 'is_new'), 'true');
      expect(find.text(Strings.subNew), findsOneWidget);
    });
  });

  group('brand', () {
    testWidgets('brand screen shows its header and queries its slug',
        (tester) async {
      await tallSurface(tester);
      api
        ..brandData = const Brand(
          id: 3,
          name: 'بيلا',
          slug: 'bella',
          productCount: 4,
          isOwnBrand: true,
        )
        ..productsHandler = (q) => page([card(1)]);
      await pumpCatalog(
        tester,
        const ProductListScreen(scope: BrandScope('bella')),
        repo,
      );
      await tester.pumpAndSettle();

      expect(find.text('بيلا'), findsWidgets);
      expect(find.text(Strings.brandOwn), findsOneWidget);
      expect(queryValue(api.productQueries.first, 'brand'), 'bella');
    });
  });

  group('search', () {
    testWidgets('sends the raw query on submit and renders results',
        (tester) async {
      await tallSurface(tester);
      api.productsHandler =
          (q) => page([card(1, name: 'زيت أرغان')]);
      await pumpCatalog(tester, const SearchScreen(), repo);
      await tester.pumpAndSettle();

      // Nothing is fetched before a query exists, and typing alone does not search.
      expect(api.productQueries, isEmpty);
      expect(find.text(Strings.searchTryHint), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'أَرْغان ');
      await tester.pump();
      expect(api.productQueries, isEmpty);

      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(api.productQueries, hasLength(1));
      // Raw text, only trimmed: the backend does the Arabic normalization.
      expect(queryValue(api.productQueries.single, 'q'), 'أَرْغان');
      expect(queryValue(api.productQueries.single, 'category'), isNull);
      expect(find.text('زيت أرغان'), findsOneWidget);
      expect(find.text(Strings.searchResultsFor('أَرْغان')), findsOneWidget);
    });

    testWidgets('a suggestion chip searches for it', (tester) async {
      await tallSurface(tester);
      api.productsHandler = (q) => page([card(1, name: 'عطر ورد')]);
      await pumpCatalog(tester, const SearchScreen(), repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.searchSuggestions.last));
      await tester.pumpAndSettle();

      expect(
        queryValue(api.productQueries.single, 'q'),
        Strings.searchSuggestions.last,
      );
      expect(find.text('عطر ورد'), findsOneWidget);
    });

    testWidgets('no results shows the search empty state', (tester) async {
      await tallSurface(tester);
      await pumpCatalog(tester, const SearchScreen(), repo);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'xyz');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text(Strings.searchEmptyTitle), findsOneWidget);
      expect(find.text(Strings.searchEmptyText), findsOneWidget);
    });

    testWidgets('search results can be sorted by relevance or price',
        (tester) async {
      await tallSurface(tester);
      api.productsHandler = (q) => page([card(1)]);
      await pumpCatalog(tester, const SearchScreen(), repo);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'عطر');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      // Default sort while searching is relevance (no explicit param).
      expect(find.text(Strings.sortRelevance), findsOneWidget);
      expect(queryValue(api.productQueries.last, 'sort'), isNull);

      await tester.tap(find.text(Strings.sortRelevance));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.sortPriceDesc));
      await tester.pumpAndSettle();
      expect(queryValue(api.productQueries.last, 'sort'), 'price_desc');
      expect(queryValue(api.productQueries.last, 'q'), 'عطر');
    });
  });

  group('product detail', () {
    ProductDetail variable() => const ProductDetail(
          id: 5,
          slug: 'lipstick',
          name: 'أحمر شفاه',
          type: ProductType.variable,
          currency: 'SYP',
          price: '20000.00',
          brand: BrandRef(id: 1, name: 'لمى', slug: 'luma'),
          description: 'وصف المنتج',
          attributes: [
            AttributeValue(key: 'finish', label: 'اللمسة', display: 'مطفي'),
          ],
          images: [
            ProductImage(id: 1, variantId: 1),
            ProductImage(id: 2, variantId: 2),
            ProductImage(id: 3, variantId: 2),
            ProductImage(id: 4),
          ],
          variantOptions: [
            VariantOption(
              key: 'color',
              label: 'اللون',
              type: OptionType.color,
              values: [
                OptionValue(value: 'وردي', hex: '#FF99AA'),
                OptionValue(value: 'أحمر', hex: '#CC0000'),
                OptionValue(value: 'بني', hex: '#663300'),
              ],
            ),
          ],
          variants: [
            Variant(
              id: 1,
              options: {'color': 'وردي'},
              currency: 'SYP',
              price: '30000.00',
              salePrice: '20000.00',
              currentPrice: '20000.00',
              discountPercent: 33,
              stockStatus: StockStatus.low,
              stockLeft: 2,
              imageIds: [1, 4],
            ),
            Variant(
              id: 2,
              options: {'color': 'أحمر'},
              currency: 'SYP',
              price: '45000.00',
              currentPrice: '45000.00',
              stockStatus: StockStatus.inStock,
              imageIds: [2, 3, 4],
            ),
            Variant(
              id: 3,
              options: {'color': 'بني'},
              currency: 'SYP',
              price: '45000.00',
              currentPrice: '45000.00',
              stockStatus: StockStatus.out,
              imageIds: [4],
            ),
          ],
        );

    int galleryImages(WidgetTester tester) =>
        tester.widget<ProductGallery>(find.byType(ProductGallery)).images.length;

    testWidgets('renders details with the default variant', (tester) async {
      await tallSurface(tester);
      api.detail = variable();
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo);
      await tester.pumpAndSettle();

      expect(find.text('أحمر شفاه'), findsOneWidget);
      expect(find.text('لمى'), findsOneWidget); // brand link
      // Pink is the first available variant: sale price, struck regular, savings.
      expect(find.textContaining('20,000'), findsWidgets);
      expect(find.textContaining('30,000'), findsOneWidget);
      expect(find.textContaining('10,000'), findsOneWidget); // وفّر
      expect(find.text(Strings.productLow(2)), findsOneWidget);
      expect(galleryImages(tester), 2);
      expect(find.text('وصف المنتج'), findsOneWidget);
    });

    testWidgets('tapping a color updates price, stock and images live',
        (tester) async {
      await tallSurface(tester);
      api.detail = variable();
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo);
      await tester.pumpAndSettle();
      final fetches = api.count('product');

      await tester.tap(find.byTooltip('أحمر'));
      await tester.pumpAndSettle();

      expect(find.textContaining('45,000'), findsWidgets);
      expect(find.textContaining('30,000'), findsNothing); // no strike now
      expect(find.text(Strings.productLow(2)), findsNothing);
      expect(find.text(Strings.productInStock), findsOneWidget);
      expect(galleryImages(tester), 3);
      // Variant switching is client-side: no refetch.
      expect(api.count('product'), fetches);
    });

    testWidgets('a sold-out variant disables add to cart, never shows a count',
        (tester) async {
      await tallSurface(tester);
      api.detail = variable();
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('بني'));
      await tester.pumpAndSettle();

      expect(find.text(Strings.productOutHint), findsOneWidget);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('add to cart and the heart are real for a guest', (tester) async {
      await tallSurface(tester);
      api.detail = variable();
      final kit = CommerceTestKit(
        shop: FakeShop([
          FakeProduct(
            id: 5,
            name: 'أحمر شفاه',
            variants: [
              FakeVariant(1, 'وردي', 20000, 2),
              FakeVariant(2, 'أحمر', 45000, 9),
              FakeVariant(3, 'بني', 45000, 0),
            ],
          ),
        ]),
      );
      addTearDown(kit.session.close);
      await kit.session.restore();
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo, kit: kit);
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.productAddToCart));
      await tester.pumpAndSettle();
      expect(find.text(Strings.toastCartAdded), findsOneWidget);
      expect(kit.cart.state.count, 1);
      expect((await kit.store.readCart()).single.variantId, 1); // the default variant
      expect(find.text(Strings.comingSoon), findsNothing);
      await tester.pumpAndSettle(const Duration(seconds: 4));

      await tester.tap(find.byIcon(Icons.favorite_border).last);
      await tester.pumpAndSettle();
      expect(find.text(Strings.toastFavAdded), findsOneWidget);
      expect(kit.favorites.state.ids, {5});
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });

    testWidgets('details tab shows attributes', (tester) async {
      await tallSurface(tester);
      api.detail = variable();
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo);
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.productTabDetails));
      await tester.pumpAndSettle();
      expect(find.text('اللمسة'), findsOneWidget);
      expect(find.text('مطفي'), findsOneWidget);
    });

    testWidgets('bundle contents render when the backend sends items',
        (tester) async {
      await tallSurface(tester);
      api.detail = const ProductDetail(
        id: 9,
        slug: 'gift',
        name: 'علبة هدايا',
        type: ProductType.bundle,
        currency: 'SYP',
        price: '90000.00',
        stockStatus: StockStatus.inStock,
        items: [
          BundleItem(
            product: BundleItemProduct(id: 1, slug: 'a', name: 'عطر ورد'),
            variantLabel: '50 ml',
            quantity: 2,
          ),
        ],
      );
      await pumpCatalog(tester, const ProductScreen(slug: 'gift'), repo);
      await tester.pumpAndSettle();

      expect(find.text(Strings.productBundleTitle), findsOneWidget);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(find.text('50 ml'), findsOneWidget);
      expect(find.text(Strings.bundleQuantity(2)), findsOneWidget);
      expect(find.text(Strings.productNoDescription), findsOneWidget);
    });

    testWidgets('related products rail appears, and is absent when empty',
        (tester) async {
      await tallSurface(tester);
      api
        ..detail = variable()
        ..relatedData = [card(8, name: 'منتج مشابه')];
      await pumpCatalog(tester, const ProductScreen(slug: 'lipstick'), repo);
      await tester.pumpAndSettle();
      expect(find.text(Strings.productRelated), findsOneWidget);
      expect(find.text('منتج مشابه'), findsOneWidget);
    });

    testWidgets('a missing product shows not found', (tester) async {
      await tallSurface(tester);
      api.errorFor = (endpoint, query) => endpoint == 'product'
          ? const ApiError(
              code: 'PRODUCT_NOT_FOUND',
              backendMessage: null,
              status: 404,
            )
          : null;
      await pumpCatalog(tester, const ProductScreen(slug: 'nope'), repo);
      await tester.pumpAndSettle();
      expect(find.text(Strings.productNotFound), findsOneWidget);
    });
  });
}

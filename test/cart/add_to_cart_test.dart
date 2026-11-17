import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/product_screen.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'cart_fakes.dart';

late CommerceTestKit kit;
late FakeCatalogApi catalog;

/// Variable product 5. What the page shows (the detail) can differ from the
/// live shop stock, which is what the add-to-cart answer is checked against.
ProductDetail detail({
  StockStatus pink = StockStatus.low,
  int pinkLeft = 3,
}) =>
    ProductDetail(
      id: 5,
      slug: 'lipstick',
      name: 'أحمر شفاه',
      type: ProductType.variable,
      currency: 'SYP',
      price: '20000.00',
      variantOptions: const [
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
          options: const {'color': 'وردي'},
          currency: 'SYP',
          price: '20000.00',
          currentPrice: '20000.00',
          stockStatus: pink,
          stockLeft: pinkLeft,
        ),
        const Variant(
          id: 2,
          options: {'color': 'أحمر'},
          currency: 'SYP',
          price: '45000.00',
          currentPrice: '45000.00',
          stockStatus: StockStatus.inStock,
        ),
        const Variant(
          id: 3,
          options: {'color': 'بني'},
          currency: 'SYP',
          price: '45000.00',
          currentPrice: '45000.00',
          stockStatus: StockStatus.out,
        ),
      ],
    );

FakeShop shop() => FakeShop([
      FakeProduct(
        id: 5,
        name: 'أحمر شفاه',
        variants: [
          FakeVariant(1, 'وردي', 20000, 3),
          FakeVariant(2, 'أحمر', 45000, 50),
          FakeVariant(3, 'بني', 45000, 0),
        ],
      ),
    ]);

Future<void> open(WidgetTester tester, {bool signedIn = false}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (signedIn) {
    await kit.session.signIn(testPair());
  } else {
    await kit.session.restore();
  }
  await pumpCatalog(
    tester,
    const ProductScreen(slug: 'lipstick'),
    CatalogRepository(catalog),
    kit: kit,
  );
  await tester.pumpAndSettle();
}

Finder get addButton => find.widgetWithText(FilledButton, Strings.productAddToCart);

Future<void> tapMore(WidgetTester tester) async {
  await tester.tap(find.byTooltip(Strings.quantityMore));
  await tester.pump();
}

/// Builds the kit INSIDE the test: cubits created in `setUp` live outside the
/// widget test's fake-async zone, so their async work would never run.
void testKit(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    kit = CommerceTestKit(shop: shop());
    catalog = FakeCatalogApi()..detail = detail();
    addTearDown(() async {
      await kit.cart.close();
      await kit.favorites.close();
      await kit.session.close();
    });
    await body(tester);
  });
}

void main() {


  group('add to cart (guest)', () {
    testKit('adds the selected variant with the chosen quantity and confirms', (tester) async {
      await open(tester);
      await tapMore(tester);
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text(Strings.toastCartAdded), findsOneWidget);
      expect(find.text(Strings.comingSoon), findsNothing);
      final saved = await kit.store.readCart();
      expect(saved.single.variantId, 1);
      expect(saved.single.quantity, 2);
      expect(kit.cart.state.count, 2);
      expect(kit.api.bodies['preview'], isNotNull); // validated by the backend
    });

    testKit('the stepper never goes past the low-stock count', (tester) async {
      await open(tester); // pink: low, 3 left
      for (var i = 0; i < 6; i++) {
        await tapMore(tester);
      }
      expect(find.text('3'), findsOneWidget);
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed,
        isNull,
      );
    });

    testKit('a variant without a count allows up to 10', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('أحمر'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 15; i++) {
        await tapMore(tester);
      }
      expect(find.text('10'), findsOneWidget);
    });

    testKit('switching variant resets the quantity', (tester) async {
      await open(tester);
      await tapMore(tester);
      await tapMore(tester);
      expect(find.text('3'), findsOneWidget);
      await tester.tap(find.byTooltip('أحمر'));
      await tester.pumpAndSettle();
      expect(find.text('1'), findsOneWidget);
    });

    testKit('a sold-out variant disables the button for real', (tester) async {
      await open(tester);
      await tester.tap(find.byTooltip('بني'));
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.productOut));
      expect(button.onPressed, isNull);
      expect(
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed,
        isNull,
      );
      expect(await kit.store.readCart(), isEmpty);
    });

    testKit('the backend says there is less than the page showed: clamp and explain', (tester) async {
      await open(tester); // the page says 3 left
      kit.shop.products[5]!.variants.first.stock = 1; // sold in the meantime
      await tapMore(tester);
      await tapMore(tester); // quantity 3
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text(Strings.toastLow(1)), findsOneWidget);
      expect(find.text('1'), findsOneWidget); // clamped to what is left
      expect(await kit.store.readCart(), isEmpty); // nothing was added

      // Adding that amount now works.
      await tester.pumpAndSettle(const Duration(seconds: 4));
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text(Strings.toastCartAdded), findsOneWidget);
      expect((await kit.store.readCart()).single.quantity, 1);
    });

    testKit('it turned out to be sold out: the button becomes disabled', (tester) async {
      await open(tester);
      kit.shop.products[5]!.variants.first.stock = 0;
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text(Strings.productOut), findsWidgets);
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.productOut)).onPressed,
        isNull,
      );
    });

    testKit('a network failure is reported and nothing is added', (tester) async {
      await open(tester);
      kit.api.failing.add('preview');
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text(Strings.errorNetwork), findsOneWidget);
      expect(await kit.store.readCart(), isEmpty);
    });
  });

  group('add to cart (signed in)', () {
    testKit('goes to the backend cart', (tester) async {
      await open(tester, signedIn: true);
      await tapMore(tester);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text(Strings.toastCartAdded), findsOneWidget);
      expect(kit.api.bodies['addItem'], {'product_id': 5, 'variant_id': 1, 'quantity': 2});
      expect(kit.api.storedLines.single.quantity, 2);
      expect(await kit.store.readCart(), isEmpty);
      expect(kit.cart.state.count, 2);
    });

    testKit('the backend\'s stock answer is shown the same way', (tester) async {
      await open(tester, signedIn: true);
      kit.shop.products[5]!.variants.first.stock = 1;
      await tapMore(tester);
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text(Strings.toastLow(1)), findsOneWidget);
      expect(kit.api.storedLines, isEmpty);
    });
  });

  group('the heart on the product page', () {
    testKit('is real and agrees with the favorites store', (tester) async {
      await open(tester);
      await tester.tap(find.byIcon(Icons.favorite_border).last);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(kit.favorites.state.ids, {5});
      expect(find.text(Strings.toastFavAdded), findsOneWidget);
    });
  });
}

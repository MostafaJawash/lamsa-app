import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'cart_fakes.dart';

late CommerceTestKit kit;

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم الوجه', stock: 5),
      FakeProduct(id: 2, name: 'عطر ورد', stock: 3),
      FakeProduct(id: 3, name: 'مخفي', visible: false),
    ]);

/// Two screens' worth of cards for the same products: a rail and a grid.
Widget cards(List<int> ids) => Scaffold(
      body: SingleChildScrollView(
        child: Wrap(
          children: [
            for (final id in ids)
              SizedBox(
                height: 330,
                width: 170,
                child: ProductCardView(product: kit.shop.products[id]!.card(), onTap: () {}),
              ),
          ],
        ),
      ),
    );

Future<void> pump(WidgetTester tester, Widget child, {bool signedIn = false}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (signedIn) {
    await kit.session.signIn(testPair());
  } else {
    await kit.session.restore();
  }
  await pumpCatalog(tester, child, CatalogRepository(FakeCatalogApi()), kit: kit);
  await tester.pumpAndSettle();
}

/// Builds the kit INSIDE the test: cubits created in `setUp` live outside the
/// widget test's fake-async zone, so their async work would never run.
void testKit(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    kit = CommerceTestKit(shop: shop());
    addTearDown(() async {
      await kit.cart.close();
      await kit.favorites.close();
      await kit.session.close();
    });
    await body(tester);
  });
}

void main() {


  group('hearts (guest)', () {
    testKit('a tap fills the heart, saves it on the device and says so', (tester) async {
      await pump(tester, cards([1]));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.text(Strings.toastFavAdded), findsOneWidget);
      expect(find.text(Strings.comingSoon), findsNothing);
      expect((await kit.store.readFavorites()).single.productId, 1);
      expect(kit.api.calls, isEmpty); // the backend is not involved for a guest
    });

    testKit('a second tap removes it', (tester) async {
      await pump(tester, cards([1]));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text(Strings.toastFavRemoved), findsOneWidget);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    testKit('the update is optimistic: filled before the validation answers', (tester) async {
      kit.lookupGate = Completer<void>();
      await pump(tester, cards([1]));
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump(); // the lookup is still pending
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(await kit.store.readFavorites(), isEmpty); // not saved yet

      kit.lookupGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect((await kit.store.readFavorites()).single.productId, 1);
    });

    testKit('a rejected add rolls the heart back and shows the reason', (tester) async {
      await pump(tester, cards([3])); // hidden: the validation finds nothing
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsNothing);
      expect(find.text('المنتج غير موجود.'), findsOneWidget);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    testKit('every heart of the same product agrees', (tester) async {
      await pump(tester, cards([1, 1, 2]));
      expect(find.byIcon(Icons.favorite_border), findsNWidgets(3));
      await tester.tap(find.byIcon(Icons.favorite_border).first);
      await tester.pumpAndSettle();
      // Both cards of product 1 are filled; product 2 is not.
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });

    testKit('hearts already on the device are filled from the start', (tester) async {
      await kit.session.restore();
      await tester.pump();
      await kit.favorites.toggle(2);
      await pump(tester, cards([1, 2]));
      expect(find.byIcon(Icons.favorite), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
    });
  });

  group('hearts (signed in)', () {
    testKit('are filled from /favorites/ids and toggled through the backend', (tester) async {
      kit.api.seedFavorite(2);
      await pump(tester, cards([1, 2]), signedIn: true);
      await kit.favorites.load();
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget); // product 2

      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(kit.api.favoriteIdsNow, containsAll([1, 2]));
      expect(find.byIcon(Icons.favorite), findsNWidgets(2));
      expect(kit.lookups, 0); // the backend validates
    });

    testKit('a failing call rolls back with the error message', (tester) async {
      await pump(tester, cards([1]), signedIn: true);
      kit.api.failing.add('addFavorite');
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.text(Strings.errorNetwork), findsOneWidget);
    });

    testKit('a failing removal brings the heart back', (tester) async {
      kit.api.seedFavorite(1);
      await pump(tester, cards([1]), signedIn: true);
      await kit.favorites.load();
      await tester.pumpAndSettle();
      kit.api.failing.add('removeFavorite');
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.favorite), findsOneWidget);
    });
  });
}

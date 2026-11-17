import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';
import 'package:lamsa_app/features/favorites/presentation/favorites_screen.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'cart_fakes.dart';

late CommerceTestKit kit;

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم الوجه', stock: 5),
      FakeProduct(id: 2, name: 'عطر ورد', currency: 'USD', price: 850, stock: 3),
      FakeProduct(id: 4, name: 'منتج نافد', stock: 0),
      for (var i = 10; i < 40; i++) FakeProduct(id: i, name: 'منتج $i', stock: 5),
    ]);

Future<void> openFavorites(WidgetTester tester, {bool signedIn = false}) async {
  tester.view.physicalSize = const Size(420, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (signedIn) {
    await kit.session.signIn(testPair());
  } else {
    await kit.session.restore();
  }
  await pumpCatalog(tester, const FavoritesScreen(), CatalogRepository(FakeCatalogApi()), kit: kit);
  await tester.pumpAndSettle();
}

Finder moveButton(int productId) => find.descendant(
      of: find.byKey(ValueKey('fav-$productId')),
      matching: find.text(Strings.favoritesMoveToCart),
    );

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


  group('guest', () {
    testKit('lists the favorites on the device, newest first, with their actions', (tester) async {
      await kit.store.writeFavorites(const [
        GuestFavorite(productId: 1, slug: 'p1'), // oldest
        GuestFavorite(productId: 2, slug: 'p2'),
        GuestFavorite(productId: 4, slug: 'p4'), // newest
      ]);
      await openFavorites(tester);

      expect(find.text(Strings.products(3)), findsOneWidget);
      expect(find.text(Strings.favoritesSub), findsOneWidget);
      final names = tester
          .widgetList<ProductCardView>(find.byType(ProductCardView))
          .map((c) => c.product.name)
          .toList();
      expect(names, ['منتج نافد', 'عطر ورد', 'كريم الوجه']); // newest first
      // Out-of-stock favorites stay listed, with a genuinely disabled move.
      final soldOut = tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.productOut));
      expect(soldOut.onPressed, isNull);
      expect(find.widgetWithText(FilledButton, Strings.favoritesMoveToCart), findsNWidgets(2));
      // Hearts are filled.
      expect(find.byIcon(Icons.favorite), findsNWidgets(3));
      expect(kit.api.calls, isEmpty); // all on the device (+ a product lookup)
    });

    testKit('an empty list shows the empty state with a way to browse', (tester) async {
      await openFavorites(tester);
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
      expect(find.text(Strings.favoritesEmptyText), findsOneWidget);
      expect(find.widgetWithText(FilledButton, Strings.favoritesBrowseNew), findsOneWidget);
    });

    testKit('removing a favorite takes it off the list and the device', (tester) async {
      await kit.store.writeFavorites(const [
        GuestFavorite(productId: 1, slug: 'p1'),
        GuestFavorite(productId: 2, slug: 'p2'),
      ]);
      await openFavorites(tester);

      await tester.tap(find.byTooltip('${Strings.favoritesRemove}: كريم الوجه'));
      await tester.pumpAndSettle();

      expect(find.text('كريم الوجه'), findsNothing);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(find.text(Strings.products(1)), findsOneWidget);
      expect((await kit.store.readFavorites()).single.productId, 2);
      expect(kit.favorites.state.ids, {2});
    });

    testKit('removing the last one shows the empty state', (tester) async {
      await kit.store.writeFavorites(const [GuestFavorite(productId: 1, slug: 'p1')]);
      await openFavorites(tester);
      await tester.tap(find.byTooltip('${Strings.favoritesRemove}: كريم الوجه'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
    });

    testKit('the card heart removes it too', (tester) async {
      await kit.store.writeFavorites(const [GuestFavorite(productId: 1, slug: 'p1')]);
      await openFavorites(tester);
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pumpAndSettle();
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
      expect(find.text(Strings.toastFavRemoved), findsOneWidget);
    });

    testKit('"انقل إلى السلة" moves it to the guest cart', (tester) async {
      await kit.store.writeFavorites(const [
        GuestFavorite(productId: 1, slug: 'p1'),
        GuestFavorite(productId: 2, slug: 'p2'),
      ]);
      await openFavorites(tester);

      await tester.tap(moveButton(1));
      await tester.pumpAndSettle();

      expect(find.text(Strings.toastMoved), findsOneWidget);
      expect(find.text('كريم الوجه'), findsNothing);
      expect((await kit.store.readCart()).single.productId, 1);
      expect(kit.cart.state.count, 1);
      expect((await kit.store.readFavorites()).single.productId, 2);
    });

    testKit('a move the cart refuses keeps the favorite and says why', (tester) async {
      await kit.store.writeFavorites(const [GuestFavorite(productId: 1, slug: 'p1')]);
      await openFavorites(tester);
      kit.shop.products[1]!.stock = 0; // sold out meanwhile (the list still says in stock)
      await tester.tap(moveButton(1));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(find.textContaining('غير متوفر'), findsWidgets);
      expect(await kit.store.readCart(), isEmpty);
    });

    testKit('a favorite added elsewhere shows up (the list refreshes)', (tester) async {
      await openFavorites(tester);
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
      await kit.favorites.toggle(2); // e.g. a heart on a product page
      await tester.pumpAndSettle();
      expect(find.text('عطر ورد'), findsOneWidget);
    });

    testKit('a failing lookup shows the error with retry', (tester) async {
      await kit.store.writeFavorites(const [GuestFavorite(productId: 1, slug: 'p1')]);
      // A lookup that fails once.
      var fail = true;
      kit.favoritesDepsOverride = FavoritesDeps(
        api: kit.api,
        store: kit.store,
        lookup: (ids) async {
          if (fail) throw StateError('offline');
          return kit.lookup(ids);
        },
      );
      tester.view.physicalSize = const Size(420, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await kit.session.restore();
      await pumpCatalog(
        tester,
        const FavoritesScreen(),
        CatalogRepository(FakeCatalogApi()),
        kit: kit,
      );
      await tester.pumpAndSettle();
      expect(find.text(Strings.favoritesUnavailable), findsOneWidget);
      fail = false;
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);
    });
  });

  group('signed in', () {
    testKit('lists /favorites and removes through the backend', (tester) async {
      kit.api.seedFavorite(1);
      kit.api.seedFavorite(2);
      await openFavorites(tester, signedIn: true);
      expect(kit.api.calls, contains('favorites'));
      expect(find.text('عطر ورد'), findsOneWidget);

      await tester.tap(find.byTooltip('${Strings.favoritesRemove}: عطر ورد'));
      await tester.pumpAndSettle();
      expect(kit.api.favoriteIdsNow, [1]);
      expect(find.text('عطر ورد'), findsNothing);
      expect(await kit.store.readFavorites(), isEmpty);
    });

    testKit('move to cart uses the real endpoint', (tester) async {
      kit.api.seedFavorite(1);
      await openFavorites(tester, signedIn: true);
      await tester.tap(moveButton(1));
      await tester.pumpAndSettle();
      expect(kit.api.calls, contains('moveToCart'));
      expect(kit.cart.state.count, 1);
      expect(kit.api.favoriteIdsNow, isEmpty);
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
    });

    testKit('infinite scroll loads the next page', (tester) async {
      for (var id = 10; id < 40; id++) {
        kit.api.seedFavorite(id);
      }
      await openFavorites(tester, signedIn: true);
      expect(kit.api.bodies['favorites'], 1);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -4000));
      await tester.pumpAndSettle();
      expect(kit.api.bodies['favorites'], 2);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -8000));
      await tester.pumpAndSettle();
      expect(find.text('منتج 10'), findsOneWidget); // the oldest, on page 2
    });
  });
}

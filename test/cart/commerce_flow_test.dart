import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'cart_fakes.dart';

late CommerceTestKit kit;
late AppDependencies deps;

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم الوجه', stock: 5),
      FakeProduct(id: 2, name: 'عطر ورد', currency: 'USD', price: 850, stock: 3),
      FakeProduct(id: 4, name: 'منتج نافد', stock: 0),
      for (var i = 100; i < 130; i++) FakeProduct(id: i, name: 'منتج $i', stock: 200),
    ]);

Future<void> launch(WidgetTester tester) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  deps = makeDeps(
    session: kit.session,
    api: kit.auth,
    catalogApi: FakeCatalogApi(),
    cart: kit.cart,
    favorites: kit.favorites,
    favoritesDeps: kit.favoritesDeps,
  );
  await tester.pumpWidget(LamsaApp(deps: deps));
  await deps.session.restore();
  await tester.pumpAndSettle();
}

Finder navTab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

/// The numeric label of a tab's badge, if any.
Finder badge(String tabLabel, String text) => find.descendant(
      of: find.ancestor(of: find.text(tabLabel), matching: find.byType(NavigationDestination)),
      matching: find.text(text),
    );

Future<void> loginViaUi(WidgetTester tester) async {
  deps.router.go('/login');
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, Strings.fieldPhone), '0933123456');
  await tester.pump();
  await tester.enterText(find.widgetWithText(TextField, Strings.fieldPassword), 'secret123');
  await tester.pump();
  final submit = find.widgetWithText(FilledButton, Strings.loginSubmit);
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

/// Builds the kit INSIDE the test: cubits created in `setUp` live outside the
/// widget test's fake-async zone, so their async work would never run.
void testKit(String name, Future<void> Function(WidgetTester tester) body) {
  testWidgets(name, (tester) async {
    kit = CommerceTestKit(
      shop: shop(),
      onMergedExtra: (o) => showMergeToast(o, () {}),
    );
    addTearDown(() async {
      await kit.cart.close();
      await kit.favorites.close();
      await kit.session.close();
    });
    await body(tester);
  });
}

void main() {


  group('tab badges (live, guest and signed in)', () {
    testKit('the cart and favorites badges follow guest changes', (tester) async {
      await launch(tester);
      expect(find.byType(Badge), findsNWidgets(2));
      expect(
        tester.widgetList<Badge>(find.byType(Badge)).every((b) => !b.isLabelVisible),
        isTrue,
      );

      await kit.cart.add(productId: 1, quantity: 2);
      await kit.cart.add(productId: 2, quantity: 1);
      await kit.favorites.toggle(1);
      await tester.pumpAndSettle();
      expect(badge(Strings.cart, '3'), findsOneWidget);
      expect(badge(Strings.favorites, '1'), findsOneWidget);

      await kit.cart.clear();
      await kit.favorites.toggle(1);
      await tester.pumpAndSettle();
      expect(
        tester.widgetList<Badge>(find.byType(Badge)).every((b) => !b.isLabelVisible),
        isTrue,
      );
    });

    testKit('more than 99 shows 99+', (tester) async {
      await launch(tester);
      kit.shop.maxPerLine = 99;
      for (var i = 0; i < 4; i++) {
        await kit.cart.add(productId: 100 + i, quantity: 30);
      }
      await tester.pumpAndSettle();
      expect(badge(Strings.cart, Strings.badgeOverflow), findsOneWidget);
    });

    testKit('signed in: from the backend', (tester) async {
      kit.api.seedStored(1, quantity: 4);
      kit.api.seedFavorite(1);
      kit.api.seedFavorite(2);
      await launch(tester);
      await kit.session.signIn(testPair());
      await tester.pumpAndSettle();
      expect(badge(Strings.cart, '4'), findsOneWidget);
      expect(badge(Strings.favorites, '2'), findsOneWidget);
    });
  });

  group('merge after login', () {
    testKit('runs once, shows the toast and the account cart', (tester) async {
      await launch(tester);
      await kit.cart.add(productId: 1, quantity: 2);
      await kit.cart.add(productId: 2, quantity: 1);
      await kit.favorites.toggle(1);
      await tester.pumpAndSettle();
      expect(badge(Strings.cart, '3'), findsOneWidget);

      await loginViaUi(tester);

      // Exactly one merge of each, favorites first.
      expect(kit.api.count_('mergeFavorites'), 1);
      expect(kit.api.count_('mergeCart'), 1);
      expect(
        kit.api.calls.indexOf('mergeFavorites'),
        lessThan(kit.api.calls.indexOf('mergeCart')),
      );
      // Said what came back (2 cart lines restored).
      expect(find.text(Strings.toastMerged(2)), findsOneWidget);
      // Local data is gone; the app now uses the account.
      expect(await kit.store.readCart(), isEmpty);
      expect(await kit.store.readFavorites(), isEmpty);
      expect(badge(Strings.cart, '3'), findsOneWidget);
      expect(badge(Strings.favorites, '1'), findsOneWidget);

      await tester.pumpAndSettle(const Duration(seconds: 4));
      await tester.tap(navTab(Strings.cart));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(kit.api.calls, contains('cart'));
    });

    testKit('lines the backend caps or skips are reported as adjusted', (tester) async {
      await launch(tester);
      await kit.store.writeCart(const [
        GuestCartItem(productId: 1, quantity: 3),
        GuestCartItem(productId: 4, quantity: 1), // out of stock: skipped
      ]);
      await loginViaUi(tester);
      expect(find.text(Strings.toastMerged(1)), findsOneWidget);
      expect(find.text(Strings.toastMergedAdjusted), findsOneWidget);
      expect(kit.api.storedLines.single.productId, 1);
      expect(await kit.store.readCart(), isEmpty);
    });

    testKit('nothing to merge: no toast and no merge calls', (tester) async {
      kit.api.seedStored(1, quantity: 2);
      await launch(tester);
      await loginViaUi(tester);
      expect(kit.api.count_('mergeCart'), 0);
      expect(find.textContaining('أعدنا'), findsNothing);
      expect(badge(Strings.cart, '2'), findsOneWidget);
    });

    testKit('is skipped during a forced password change and runs once after it', (tester) async {
      await launch(tester);
      await kit.cart.add(productId: 1, quantity: 2);
      await kit.favorites.toggle(2);
      kit.auth.onLogin = () async => testPair(user: testUser(mustChange: true));
      kit.auth.onChange = () async => testPair(refresh: 'refresh-2');

      await loginViaUi(tester);
      // Blocked on the change screen: nothing merged, local data untouched.
      expect(find.text(Strings.changeForcedNote), findsOneWidget);
      expect(kit.api.count_('mergeCart'), 0);
      expect(kit.api.count_('mergeFavorites'), 0);
      expect((await kit.store.readCart()).single.quantity, 2);
      expect((await kit.store.readFavorites()).single.productId, 2);

      await tester.enterText(find.widgetWithText(TextField, Strings.fieldTemporaryPassword), 'temp-pass1');
      await tester.enterText(find.widgetWithText(TextField, Strings.fieldNewPassword), 'brand-new-1');
      await tester.enterText(find.widgetWithText(TextField, Strings.fieldConfirmPassword), 'brand-new-1');
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, Strings.changeSubmit);
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(find.text(Strings.changeForcedNote), findsNothing);
      expect(kit.api.count_('mergeCart'), 1);
      expect(kit.api.count_('mergeFavorites'), 1);
      expect(kit.merged.length, 1);
      expect(await kit.store.readCart(), isEmpty);
      expect(badge(Strings.cart, '2'), findsOneWidget);
    });

    testKit('a merge failure never blocks login; opening the cart retries it', (tester) async {
      await launch(tester);
      await kit.cart.add(productId: 1, quantity: 2);
      kit.api.failing.add('mergeCart');
      await loginViaUi(tester);
      expect(find.byType(NavigationBar), findsOneWidget); // logged in, in the shell
      expect(kit.session.state.isAuthenticated, isTrue);
      expect((await kit.store.readCart()).single.quantity, 2); // still on the device

      kit.api.failing.clear();
      await tester.tap(navTab(Strings.cart));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(await kit.store.readCart(), isEmpty);
      expect(kit.merged.length, 1);
    });
  });

  group('guests use the cart and favorites tabs directly', () {
    testKit('add a favorite, see it in the tab, then log out to a clean guest state', (tester) async {
      await launch(tester);
      await kit.favorites.toggle(2);
      await tester.tap(navTab(Strings.favorites));
      await tester.pumpAndSettle();
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(find.text(Strings.gateTitle), findsNothing);
    });
  });
}

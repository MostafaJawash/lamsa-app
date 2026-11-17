import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/presentation/cart_screen.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'cart_fakes.dart';

late CommerceTestKit kit;

FakeShop shop() => FakeShop([
      FakeProduct(id: 1, name: 'كريم الوجه', stock: 5),
      FakeProduct(id: 2, name: 'عطر ورد', currency: 'USD', price: 850, compareAt: 1000, stock: 3),
      FakeProduct(
        id: 3,
        name: 'أحمر شفاه',
        variants: [FakeVariant(31, 'وردي', 20000, 4)],
      ),
      FakeProduct(id: 4, name: 'منتج نافد', stock: 0),
    ]);

Future<void> openCart(
  WidgetTester tester, {
  bool signedIn = false,
}) async {
  tester.view.physicalSize = const Size(420, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  if (signedIn) {
    await kit.session.signIn(testPair());
  } else {
    await kit.session.restore();
  }
  await pumpCatalog(tester, const CartScreen(), CatalogRepository(FakeCatalogApi()), kit: kit);
  await tester.pumpAndSettle();
}

String m(String amount, String currency) => formatAmount(amount, currency);

Finder line(String name) => find.ancestor(
      of: find.text(name),
      matching: find.byType(CartLineTile),
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


  group('rendering', () {
    testKit('a guest cart: lines, per-line prices, totals per currency, disabled checkout', (tester) async {
      await kit.store.writeCart(const [
        GuestCartItem(productId: 1, quantity: 2, slug: 'p1'),
        GuestCartItem(productId: 2, quantity: 3, slug: 'p2'),
        GuestCartItem(productId: 3, variantId: 31, quantity: 1, slug: 'p3'),
      ]);
      await openCart(tester);

      // Lines: name, brand + variant label, unit price, quantity, line total.
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(find.text('لمى، وردي'), findsOneWidget);
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text(m('100.00', 'SYP'))), findsOneWidget); // unit
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text(m('200.00', 'SYP'))), findsOneWidget); // line total
      // The USD line: its own currency, sale price with the struck regular price.
      expect(find.descendant(of: line('عطر ورد'), matching: find.text(m('8.50', 'USD'))), findsOneWidget);
      expect(find.descendant(of: line('عطر ورد'), matching: find.text(m('10.00', 'USD'))), findsOneWidget);
      expect(find.descendant(of: line('عطر ورد'), matching: find.text(m('25.50', 'USD'))), findsOneWidget);
      expect(find.text(Strings.items(6)), findsOneWidget);

      // Summary: ONE row per currency, never a combined figure.
      expect(find.text(m('400.00', 'SYP')), findsNWidgets(2)); // subtotal + total (SYP: 200 + 200)
      expect(find.text(m('25.50', 'USD')), findsNWidgets(3)); // line total + subtotal + total
      expect(find.text(m('4.50', 'USD')), findsOneWidget); // savings, USD only
      expect(find.textContaining('425'), findsNothing);
      expect(find.textContaining('425.50'), findsNothing);

      // A cart without issues can go to checkout.
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, Strings.checkoutTitle),
      );
      expect(button.onPressed, isNotNull);
      expect(find.text(Strings.cartCheckoutHint), findsOneWidget);
      expect(find.text(Strings.cartIssuesNotice), findsNothing);
    });

    testKit('an empty cart', (tester) async {
      await openCart(tester);
      expect(find.text(Strings.cartEmptyTitle), findsOneWidget);
      expect(find.text(Strings.cartEmptyText), findsOneWidget);
      expect(find.widgetWithText(FilledButton, Strings.cartStartShopping), findsOneWidget);
      expect(find.text(Strings.checkoutTitle), findsNothing);
      expect(kit.api.calls, isEmpty); // no network for an empty guest cart
    });

    testKit('a failing load shows the error with retry', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 1)]);
      kit.api.failing.add('preview');
      await openCart(tester);
      expect(find.text(Strings.cartUnavailable), findsOneWidget);
      kit.api.failing.clear();
      await tester.tap(find.text(Strings.retry));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);
    });

    testKit('a line whose product is gone shows its issue and no link or total', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 999, quantity: 1)]);
      await openCart(tester);
      expect(find.text(Strings.cartUnknownProduct), findsOneWidget);
      expect(find.text(Strings.issueUnavailable), findsOneWidget);
      expect(find.text(m('0.00', 'SYP')), findsNothing);
    });
  });

  group('stock and availability conflicts (the backend\'s issues, not ours)', () {
    Future<void> openWithIssues(WidgetTester tester) async {
      await kit.store.writeCart(const [
        GuestCartItem(productId: 1, quantity: 5),
        GuestCartItem(productId: 4, quantity: 1),
        GuestCartItem(productId: 2, quantity: 1),
      ]);
      kit.shop.products[1]!.stock = 2; // INSUFFICIENT_STOCK (available 2)
      await openCart(tester);
    }

    testKit('lines show the backend reason, the notice and a blocked checkout', (tester) async {
      await openWithIssues(tester);
      expect(find.text(Strings.issueInsufficientStock(2)), findsOneWidget);
      expect(find.text(Strings.issueOutOfStock), findsOneWidget);
      expect(find.text(Strings.cartIssuesNotice), findsOneWidget);
      expect(find.text(Strings.cartFixFirst), findsOneWidget);
      // Lines with an issue are not counted and show no total.
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text(m('500.00', 'SYP'))), findsNothing);
      expect(find.text(Strings.items(1)), findsOneWidget); // only the USD perfume counts
      expect(
        tester.widget<FilledButton>(find.widgetWithText(FilledButton, Strings.checkoutTitle)).onPressed,
        isNull,
      );
    });

    testKit('"تحديث السلة" removes unavailable lines, caps quantities and says so', (tester) async {
      await openWithIssues(tester);
      await tester.tap(find.text(Strings.cartResolve));
      await tester.pumpAndSettle();

      expect(find.text('منتج نافد'), findsNothing); // removed
      expect(find.text(Strings.cartIssuesNotice), findsNothing);
      expect(find.text(Strings.cartFixFirst), findsNothing);
      expect(find.text(Strings.cartCheckoutHint), findsOneWidget);
      // Capped to what is left (2), now with its total.
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text(m('200.00', 'SYP'))), findsWidgets);
      expect((await kit.store.readCart()).map((i) => (i.productId, i.quantity)).toList(), [(1, 2), (2, 1)]);
      // The toast tells what changed.
      expect(find.textContaining(Strings.noticeLineRemoved), findsOneWidget);
    });

    testKit('signed in: resolve uses the backend endpoint', (tester) async {
      kit.api.seedStored(1, quantity: 5);
      kit.api.seedStored(4);
      kit.shop.products[1]!.stock = 2;
      await openCart(tester, signedIn: true);
      expect(find.text(Strings.cartIssuesNotice), findsOneWidget);
      await tester.tap(find.text(Strings.cartResolve));
      await tester.pumpAndSettle();
      expect(kit.api.calls, contains('resolveIssues'));
      expect(find.text(Strings.cartIssuesNotice), findsNothing);
      expect(kit.api.storedLines.single.quantity, 2);
    });
  });

  group('changing the cart', () {
    testKit('the quantity stepper is debounced and the backend recomputes the totals', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 2, slug: 'p1')]);
      await openCart(tester);
      final before = kit.api.count_('preview');

      await tester.tap(find.byTooltip(Strings.quantityMore));
      await tester.tap(find.byTooltip(Strings.quantityMore));
      await tester.pump();
      // Optimistic: the draft quantity is shown at once.
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text('4')), findsOneWidget);
      expect(kit.api.count_('preview'), before); // not sent yet

      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(kit.api.count_('preview'), before + 1); // ONE call for both taps
      expect((await kit.store.readCart()).single.quantity, 4);
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text(m('400.00', 'SYP'))), findsOneWidget);
    });

    testKit('"−" at quantity 1 removes the line', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 1)]);
      await openCart(tester);
      await tester.tap(find.byTooltip(Strings.quantityLess));
      await tester.pumpAndSettle();
      expect(find.text(Strings.cartEmptyTitle), findsOneWidget);
      expect(await kit.store.readCart(), isEmpty);
    });

    testKit('going past the stock reverts the line and explains', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 5)]);
      await openCart(tester);
      await tester.tap(find.byTooltip(Strings.quantityMore));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.descendant(of: line('كريم الوجه'), matching: find.text('5')), findsOneWidget); // reverted
      expect(find.text(Strings.toastLow(5)), findsWidgets); // under the line and in the toast
      expect((await kit.store.readCart()).single.quantity, 5);
    });

    testKit('the remove button', (tester) async {
      await kit.store.writeCart(const [
        GuestCartItem(productId: 1, quantity: 1),
        GuestCartItem(productId: 2, quantity: 1),
      ]);
      await openCart(tester);
      await tester.tap(find.byTooltip('${Strings.cartRemove}: كريم الوجه'));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsNothing);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect((await kit.store.readCart()).single.productId, 2);
    });

    testKit('clearing the cart asks first', (tester) async {
      await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 1)]);
      await openCart(tester);
      await tester.tap(find.text(Strings.cartClear));
      await tester.pumpAndSettle();
      expect(find.text(Strings.cartClearTitle), findsOneWidget);
      await tester.tap(find.text(Strings.cancel));
      await tester.pumpAndSettle();
      expect(find.text('كريم الوجه'), findsOneWidget);

      await tester.tap(find.text(Strings.cartClear));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.cartClearConfirm));
      await tester.pumpAndSettle();
      expect(find.text(Strings.cartEmptyTitle), findsOneWidget);
      expect(await kit.store.readCart(), isEmpty);
    });
  });

  group('signed in', () {
    testKit('shows the backend cart and edits it through the real endpoints', (tester) async {
      kit.api.seedStored(1, quantity: 2);
      kit.api.seedStored(2);
      await openCart(tester, signedIn: true);
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(find.text('عطر ورد'), findsOneWidget);
      expect(kit.api.calls, contains('cart'));
      expect(kit.api.calls, isNot(contains('preview')));

      await tester.tap(find.byTooltip(Strings.quantityMore).first);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(kit.api.count_('updateItem'), 1);
      expect(kit.api.storedLines.first.quantity, 3);

      await tester.tap(find.byTooltip('${Strings.cartRemove}: عطر ورد'));
      await tester.pumpAndSettle();
      expect(kit.api.count_('removeItem'), 1);
      expect(find.text('عطر ورد'), findsNothing);
    });

    testKit('pull to refresh reloads from the backend', (tester) async {
      kit.api.seedStored(1);
      await openCart(tester, signedIn: true);
      final before = kit.api.count_('cart');
      kit.api.seedStored(2); // changed elsewhere
      unawaited(
        tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show(),
      );
      await tester.pumpAndSettle();
      expect(kit.api.count_('cart'), greaterThan(before));
      expect(find.text('عطر ورد'), findsOneWidget);
    });
  });
}

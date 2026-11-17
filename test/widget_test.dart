import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/sections.dart';

import 'auth/auth_fakes.dart';

void main() {
  late AppDependencies deps;

  setUp(() {
    final api = FakeAuthApi();
    deps = makeDeps(session: makeSession(api: api), api: api);
  });

  testWidgets('boots to the RTL Arabic home with the bottom nav', (
    tester,
  ) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    // Home sections (empty data: graceful fallbacks, not a blank screen).
    expect(
      find.widgetWithText(SectionHeader, Strings.homeNewArrivals),
      findsOneWidget,
    );
    expect(find.text(Strings.homeEmptyNew), findsOneWidget);
    expect(find.text(Strings.bannerSaleTitle), findsOneWidget);

    // Five tabs in the agreed order.
    for (final label in [
      Strings.home,
      Strings.categories,
      Strings.favorites,
      Strings.cart,
      Strings.account,
    ]) {
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
      );
    }

    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('ar'));
  });

  testWidgets('guests: Account is gated inline, Cart and Favorites are usable', (
    tester,
  ) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    Finder tab(String label) => find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text(label),
        );

    await tester.tap(tab(Strings.account));
    await tester.pumpAndSettle();
    expect(find.text(Strings.gateTitle), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    // Still inside the shell: no login screen was opened.
    expect(find.text(Strings.loginLead), findsNothing);

    await tester.tap(tab(Strings.cart));
    await tester.pumpAndSettle();
    expect(find.text(Strings.gateTitle), findsNothing);
    expect(find.text(Strings.cartEmptyTitle), findsOneWidget);

    await tester.tap(tab(Strings.favorites));
    await tester.pumpAndSettle();
    expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
  });

  testWidgets(
    'other protected routes still redirect to login when signed out',
    (tester) async {
      await tester.pumpWidget(LamsaApp(deps: deps));
      await deps.session.restore();
      await tester.pumpAndSettle();

      deps.router.go('/orders');
      await tester.pumpAndSettle();

      expect(
        find.text(Strings.loginLead),
        findsOneWidget,
      ); // the real login screen
      expect(find.text(Strings.orders), findsNothing);
    },
  );
}

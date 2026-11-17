import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/sections.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:mocktail/mocktail.dart';

import 'catalog/catalog_fakes.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockDevicesApi extends Mock implements DevicesApi {}

class _MockGoogle extends Mock implements GoogleAuthService {}

class _EmptyStorage implements TokenStorage {
  @override
  Future<StoredTokens?> read() async => null;

  @override
  Future<void> write(StoredTokens tokens) async {}

  @override
  Future<void> clear() async {}
}

void main() {
  late AppDependencies deps;

  setUp(() {
    final authApi = _MockAuthApi();
    final devices = _MockDevicesApi();
    final push = PushService(devices);
    deps = AppDependencies(
      session: SessionCubit(
        api: authApi,
        storage: _EmptyStorage(),
        push: push,
      ),
      authApi: authApi,
      catalog: CatalogRepository(FakeCatalogApi()),
      devicesApi: devices,
      push: push,
      google: _MockGoogle(),
    );
  });

  testWidgets('boots to the RTL Arabic home with the bottom nav',
      (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    // Home sections (empty data: graceful fallbacks, not a blank screen).
    expect(find.widgetWithText(SectionHeader, Strings.homeNewArrivals), findsOneWidget);
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

  testWidgets('guest tabs show "coming soon" inside the shell, no login bounce',
      (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(Strings.cart),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.comingSoon), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text(Strings.login), findsNothing);
  });

  testWidgets('other protected routes still redirect to login when signed out',
      (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    deps.router.go('/orders');
    await tester.pumpAndSettle();

    expect(find.text(Strings.login), findsWidgets);
    expect(find.text(Strings.orders), findsNothing);
  });
}

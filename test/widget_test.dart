import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockAuthApi extends Mock implements AuthApi {}

class _MockCatalogApi extends Mock implements CatalogApi {}

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
    final catalog = _MockCatalogApi();
    when(catalog.ping).thenAnswer((_) async {});
    final devices = _MockDevicesApi();
    final push = PushService(devices);
    deps = AppDependencies(
      session: SessionCubit(
        api: authApi,
        storage: _EmptyStorage(),
        push: push,
      ),
      authApi: authApi,
      catalogApi: catalog,
      devicesApi: devices,
      push: push,
      google: _MockGoogle(),
    );
  });

  testWidgets('boots to the RTL Arabic home placeholder', (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    expect(find.text(Strings.home), findsWidgets);
    expect(find.text(Strings.serverReachable), findsOneWidget);

    final context = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(context), TextDirection.rtl);
    expect(Localizations.localeOf(context), const Locale('ar'));
  });

  testWidgets('protected route redirects to login when signed out',
      (tester) async {
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();

    deps.router.go('/cart');
    await tester.pumpAndSettle();

    expect(find.text(Strings.login), findsWidgets);
    expect(find.text(Strings.cart), findsNothing);
  });
}

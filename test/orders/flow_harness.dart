import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/features/account/data/addresses_repository.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/account/presentation/location_picker.dart';

import '../auth/auth_fakes.dart';
import '../catalog/catalog_fakes.dart';
import 'orders_fakes.dart';

/// The whole app over fakes, signed in with a stored session.
class AppFlow {
  AppFlow._(this.deps, this.auth, this.orders, this.addresses, this.cartApi, this.storage);

  final AppDependencies deps;
  final FakeAuthApi auth;
  final FakeOrdersApi orders;
  final FakeAddressesApi addresses;
  final CheckoutCartApi cartApi;
  final MemoryTokenStorage storage;

  static Future<AppFlow> launch(
    WidgetTester tester, {
    List<Address>? addressList,
    FakeAuthApi? auth,
    FakeOrdersApi? orders,
    CheckoutCartApi? cartApi,
    bool signedIn = true,
    FakeAddressesApi? addressesApi,
  }) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final theAuth = auth ?? FakeAuthApi();
    final theOrders = orders ?? FakeOrdersApi();
    final theAddresses = addressesApi ??
        FakeAddressesApi(addresses: addressList ?? [addr(1, isDefault: true)]);
    final theCart = cartApi ?? CheckoutCartApi();
    final storage = MemoryTokenStorage(signedIn ? storedTokens() : null);
    final session = makeSession(api: theAuth, storage: storage);
    final deps = makeDeps(
      session: session,
      api: theAuth,
      catalogApi: FakeCatalogApi(),
      ordersApi: theOrders,
      addresses: AddressesRepository(theAddresses),
      cartApi: theCart,
    );
    await tester.pumpWidget(LamsaApp(deps: deps));
    await deps.session.restore();
    await tester.pumpAndSettle();
    return AppFlow._(deps, theAuth, theOrders, theAddresses, theCart, storage);
  }

  /// Goes to [location] and lets the screen load.
  Future<void> open(WidgetTester tester, String location) async {
    deps.router.go(location);
    await tester.pumpAndSettle();
  }

  Future<void> push(WidgetTester tester, String location) async {
    // ignore: unawaited_futures
    deps.router.push<Object?>(location);
    await tester.pumpAndSettle();
  }
}

Finder tapTarget(String text) => find.widgetWithText(FilledButton, text);

Future<void> tapText(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> typeInto(WidgetTester tester, String label, String text) async {
  final f = find.widgetWithText(TextField, label);
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

/// A locator that answers with a fixed result.
class FixedLocator implements CurrentLocator {
  FixedLocator(this.result);

  final LocateResult result;
  int calls = 0;

  @override
  Future<LocateResult> locate() async {
    calls++;
    return result;
  }
}

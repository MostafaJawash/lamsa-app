import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/presentation/cart_screen.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/presentation/product_screen.dart';

import '../cart/cart_fakes.dart';
import '../catalog/catalog_fakes.dart';
import '../orders/flow_harness.dart';
import '../orders/orders_fakes.dart';

void main() {
  late ConnectivityProbe saved;
  setUp(() {
    saved = connectivityProbe;
    connectivityProbe = () async => false;
  });
  tearDown(() => connectivityProbe = saved);

  testWidgets('cart: a connection failure shows the shared state',
      (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final kit = CommerceTestKit(shop: FakeShop([FakeProduct(id: 1, name: 'كريم الوجه', stock: 5)]));
    addTearDown(() async {
      await kit.cart.close();
      await kit.favorites.close();
      await kit.session.close();
    });
    await kit.store.writeCart(const [GuestCartItem(productId: 1, quantity: 1)]);
    kit.api.failing.add('preview');
    await kit.session.restore();
    await pumpCatalog(
      tester,
      const CartScreen(),
      CatalogRepository(FakeCatalogApi()),
      kit: kit,
    );
    await tester.pumpAndSettle();

    expect(find.text(Strings.noInternetTitle), findsOneWidget);
    expect(find.text(Strings.cartUnavailable), findsNothing);
  });

  testWidgets('orders: a connection failure shows the shared state, retry reloads',
      (tester) async {
    final f = await AppFlow.launch(tester);
    f.orders.listError = err('NETWORK_ERROR', 0);
    f.orders.all = [orderSummary(3)];
    await f.open(tester, Routes.orders);
    expect(find.byType(ConnectionErrorView), findsOneWidget);
    expect(find.text(Strings.ordersUnavailable), findsNothing);

    f.orders.listError = null;
    await tapText(tester, find.text(Strings.retry));
    expect(find.text(Strings.orderNumber(3)), findsOneWidget);
  });

  testWidgets('orders: a server error keeps the generic error', (tester) async {
    final f = await AppFlow.launch(tester);
    f.orders.listError = err('INTERNAL_ERROR', 500);
    await f.open(tester, Routes.orders);
    expect(find.byType(ConnectionErrorView), findsNothing);
    expect(find.text(Strings.retry), findsOneWidget);
  });

  testWidgets('product detail: a connection failure shows the shared state',
      (tester) async {
    final api = FakeCatalogApi();
    api.errorFor = (name, _) => name == 'product'
        ? const ApiError(code: ApiError.networkCode, backendMessage: null)
        : null;
    await pumpCatalog(
      tester,
      const ProductScreen(slug: 'x'),
      CatalogRepository(api),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ConnectionErrorView), findsOneWidget);
  });
}

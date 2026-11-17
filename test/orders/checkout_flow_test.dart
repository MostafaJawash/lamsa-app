import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/account/data/models/address_models.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

import 'flow_harness.dart';
import 'orders_fakes.dart';

Finder money(String amount, String currency) => find.text(formatAmount(amount, currency));

Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

void main() {
  group('checkout', () {
    testWidgets('the cart button opens checkout: address, the backend quote, COD, totals per currency', (tester) async {
      final f = await AppFlow.launch(tester);
      await tester.tap(navTab(Strings.cart));
      await tester.pumpAndSettle();
      await tapText(tester, tapTarget(Strings.checkoutTitle));

      expect(find.text(Strings.checkoutAddress), findsOneWidget);
      expect(find.text('دمشق'), findsWidgets); // the default address
      expect(find.text('توصيل دمشق'), findsOneWidget); // the only valid method
      expect(find.text(Strings.checkoutCod), findsOneWidget);
      // Totals are the quote's, one line per currency, never combined.
      expect(money('115000.00', 'SYP'), findsWidgets);
      expect(money('8.50', 'USD'), findsWidgets);
      expect(find.textContaining('115008'), findsNothing);
      expect(f.cartApi.asked.last, 'damascus');
      expect(tester.widget<FilledButton>(tapTarget(Strings.checkoutConfirm)).onPressed, isNotNull);
    });

    testWidgets('happy path: one order with the derived key, then the confirmation and the order', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(orderDetail());
      f.orders.detailsById[7] = orderDetail();
      await f.open(tester, Routes.checkout);
      await typeInto(tester, Strings.checkoutNotes, 'اتصل قبل الوصول');

      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(f.orders.placeCalls, 1);
      final r = f.orders.requests.single;
      expect(r.deliveryMethodCode, 'damascus_courier');
      expect(r.addressId, 1);
      expect(r.expectedTotals, {'SYP': '115000.00', 'USD': '8.50'});
      expect(r.customerNotes, 'اتصل قبل الوصول');
      expect(f.orders.keys.single.length, 43);

      expect(find.text(Strings.successTitle), findsWidgets); // bar and body
      expect(find.textContaining('#7'), findsOneWidget);
      await tapText(tester, tapTarget(Strings.successTrack));
      expect(find.text(Strings.orderNumber(7)), findsOneWidget); // the order screen
    });

    testWidgets('a province address shows province shipping with the paid-to-carrier note', (tester) async {
      final f = await AppFlow.launch(tester, addressList: [addr(1, governorate: 'aleppo', isDefault: true)]);
      await f.open(tester, Routes.checkout);
      expect(f.cartApi.asked.last, 'aleppo');
      expect(find.text('شحن إلى المحافظات'), findsOneWidget);
      expect(find.text('توصيل دمشق'), findsNothing);
      expect(find.text(Strings.checkoutCarrierPaid), findsOneWidget);
      expect(find.text(Strings.checkoutPaidToCarrier), findsWidgets);
    });

    testWidgets('choosing another address filters the methods by its governorate', (tester) async {
      final f = await AppFlow.launch(
        tester,
        addressList: [addr(1, isDefault: true, label: 'البيت'), addr(2, governorate: 'aleppo', label: 'العمل')],
      );
      await f.open(tester, Routes.checkout);
      expect(find.text('توصيل دمشق'), findsOneWidget);
      expect(find.text('شحن إلى المحافظات'), findsNothing);

      await tapText(tester, find.text('العمل'));
      expect(f.cartApi.asked.last, 'aleppo');
      expect(find.text('شحن إلى المحافظات'), findsOneWidget);
      expect(find.text('توصيل دمشق'), findsNothing);
      // The totals follow the selected quote.
      expect(money('100000.00', 'SYP'), findsWidgets);
    });

    testWidgets('without an address no method is offered and the order cannot be confirmed', (tester) async {
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.checkout);
      expect(find.text(Strings.checkoutNoAddress), findsOneWidget);
      expect(find.text(Strings.checkoutDeliveryNeedsAddress), findsOneWidget);
      expect(tester.widget<FilledButton>(tapTarget(Strings.checkoutConfirm)).onPressed, isNull);
      expect(f.orders.placeCalls, 0);
    });

    testWidgets('a guest is sent to login, not to checkout', (tester) async {
      final f = await AppFlow.launch(tester, signedIn: false);
      await f.open(tester, Routes.checkout);
      expect(find.text(Strings.loginLead), findsOneWidget);
      expect(find.text(Strings.checkoutConfirm), findsNothing);
    });

    testWidgets('CART_HAS_ISSUES sends the customer back to the cart', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(err('CART_HAS_ISSUES', 409));
      await f.open(tester, Routes.checkout);
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(find.text(Strings.checkoutConfirm), findsNothing);
      expect(find.text(Strings.cartSummary), findsOneWidget); // the cart screen
    });

    testWidgets('INSUFFICIENT_STOCK goes back to the cart and says how many are left', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(err('INSUFFICIENT_STOCK', 409, details: {'available': 3}));
      await f.open(tester, Routes.checkout);
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(find.text(Strings.cartSummary), findsOneWidget);
      expect(find.text(Strings.toastLow(3)), findsOneWidget);
    });

    testWidgets('PRICE_CHANGED keeps the customer here with the new totals and a notice', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(err('PRICE_CHANGED', 409));
      await f.open(tester, Routes.checkout);
      f.cartApi.build = (g) => Cart(
            lines: [cartLine()],
            canCheckout: true,
            subtotals: const [CurrencyAmount(currency: 'SYP', amount: '120000.00')],
            totals: const [CurrencyAmount(currency: 'SYP', amount: '120000.00')],
            deliveryQuotes: const [
              DeliveryQuote(
                code: 'damascus_courier',
                name: 'توصيل دمشق',
                currency: 'SYP',
                fee: '15000.00',
                totals: [CurrencyAmount(currency: 'SYP', amount: '135000.00')],
              ),
            ],
          );
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(find.text(Strings.checkoutPriceChanged), findsOneWidget);
      expect(money('135000.00', 'SYP'), findsWidgets);
      expect(find.text(Strings.successTitle), findsNothing);
      // Confirming again is a new attempt with new totals, so a new key.
      f.orders.placeScript.add(orderDetail());
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(f.orders.keys.length, 2);
      expect(f.orders.keys[0], isNot(f.orders.keys[1]));
      expect(f.orders.requests.last.expectedTotals, {'SYP': '135000.00'});
      expect(find.text(Strings.successTitle), findsWidgets);
    });

    testWidgets('DELIVERY_METHOD_NOT_AVAILABLE refreshes the methods with a notice', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(err('DELIVERY_METHOD_NOT_AVAILABLE', 409));
      await f.open(tester, Routes.checkout);
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(find.text(Strings.checkoutMethodChanged), findsOneWidget);
      expect(tester.widget<FilledButton>(tapTarget(Strings.checkoutConfirm)).onPressed, isNull);
      // Choosing the method again makes the order possible.
      await tapText(tester, find.text('توصيل دمشق'));
      expect(tester.widget<FilledButton>(tapTarget(Strings.checkoutConfirm)).onPressed, isNotNull);
    });

    testWidgets('an unknown failure shows the backend message and keeps the form', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.placeScript.add(err('SOMETHING', 422, message: 'رسالة من الخادم'));
      await f.open(tester, Routes.checkout);
      await typeInto(tester, Strings.checkoutNotes, 'ملاحظتي');
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      expect(find.text('رسالة من الخادم'), findsOneWidget);
      expect(find.text('ملاحظتي'), findsOneWidget);
    });

    testWidgets('a new address added right at checkout is selected and drives the methods', (tester) async {
      final f = await AppFlow.launch(tester, addressList: [addr(1, isDefault: true, label: 'البيت')]);
      await f.open(tester, Routes.checkout);
      await tapText(tester, find.widgetWithText(OutlinedButton, Strings.checkoutAddAddress));
      expect(find.text(Strings.addressesNewTitle), findsOneWidget);

      await tapText(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, find.text('حلب').last);
      await typeInto(tester, Strings.afLabel, 'المحل');
      await typeInto(tester, Strings.afDetails, 'شارع الفرقان، بناء 12، الطابق الأول');
      await tapText(tester, tapTarget(Strings.afSave));

      expect(f.addresses.drafts.single.governorate, 'aleppo');
      expect(f.addresses.drafts.single.latitude, ''); // the pin is optional
      // Back at checkout with the new address selected: province shipping.
      expect(find.text(Strings.checkoutTitle), findsWidgets);
      expect(f.cartApi.asked.last, 'aleppo');
      expect(find.text('شحن إلى المحافظات'), findsOneWidget);
      expect(find.text('المحل'), findsOneWidget);
    });
  });

  test('addresses used by the harness are typed', () {
    expect(addr(1), isA<Address>());
  });
}

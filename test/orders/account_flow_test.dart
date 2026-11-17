import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/account/data/address_rules.dart';
import 'package:lamsa_app/features/account/presentation/location_picker.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

import '../auth/auth_fakes.dart';
import 'flow_harness.dart';
import 'orders_fakes.dart';

Finder money(String amount, String currency) => find.text(formatAmount(amount, currency));

Finder inDialog(Finder f) => find.descendant(of: find.byType(AlertDialog), matching: f);

Finder tapTargetAny(String text) => find.widgetWithText(OutlinedButton, text);

void main() {
  final originalLocator = DeviceLocation.locator;
  tearDown(() => DeviceLocation.locator = originalLocator);

  group('address book and form', () {
    testWidgets('empty book offers the first address', (tester) async {
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.addresses);
      expect(find.text(Strings.addressesEmptyTitle), findsOneWidget);
      expect(find.widgetWithText(FilledButton, Strings.addressesAddFirst), findsOneWidget);
    });

    testWidgets('lists addresses with the default marked; set default and delete', (tester) async {
      final f = await AppFlow.launch(
        tester,
        addressList: [
          addr(1, isDefault: true, label: 'البيت'),
          addr(2, governorate: 'aleppo', label: 'العمل', latitude: '36.2', longitude: '37.1'),
        ],
      );
      await f.open(tester, Routes.addresses);
      expect(find.text('البيت'), findsOneWidget);
      expect(find.text(Strings.addressesDefault), findsOneWidget);
      expect(find.text(Strings.addressesHasLocation), findsOneWidget);

      await tapText(tester, find.widgetWithText(TextButton, Strings.addressesSetDefault));
      expect(f.addresses.calls, contains('setDefault'));
      expect(f.addresses.addresses.firstWhere((a) => a.id == 2).isDefault, isTrue);
      expect(find.text(Strings.toastAddressDefault), findsOneWidget);

      // Deleting asks first.
      await tapText(tester, find.widgetWithText(TextButton, Strings.addressesDelete).first);
      expect(find.text(Strings.addressesDeleteTitle), findsOneWidget);
      await tapText(tester, inDialog(find.text(Strings.cancel)));
      expect(f.addresses.calls, isNot(contains('delete')));
      await tapText(tester, find.widgetWithText(TextButton, Strings.addressesDelete).first);
      await tapText(tester, inDialog(find.text(Strings.addressesDelete)));
      expect(f.addresses.calls, contains('delete'));
      expect(f.addresses.addresses.length, 1);
    });

    testWidgets('the form validates before sending and shows field errors', (tester) async {
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.addresses);
      await tapText(tester, find.widgetWithText(FilledButton, Strings.addressesAddFirst));
      await tapText(tester, tapTarget(Strings.afSave));
      expect(find.text(Strings.afErrGovernorateRequired), findsOneWidget);
      expect(find.text(Strings.afErrDetailsRequired), findsOneWidget);
      expect(f.addresses.calls, isNot(contains('create')));

      await typeInto(tester, Strings.afDetails, 'قصير');
      await tapText(tester, tapTarget(Strings.afSave));
      expect(find.text(Strings.afErrDetailsShort(10)), findsOneWidget);
      // Typing in a field clears its error.
      await typeInto(tester, Strings.afDetails, 'شارع الثورة، بناء 5');
      await tester.pumpAndSettle(); // the error fades out
      expect(find.text(Strings.afErrDetailsShort(10)), findsNothing);
      expect(f.addresses.calls, isNot(contains('create')));
    });

    testWidgets('the map pin is optional: saves without it, with the 14 governorates from the backend', (tester) async {
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.addresses);
      await tapText(tester, find.widgetWithText(FilledButton, Strings.addressesAddFirst));
      await tapText(tester, find.byType(DropdownButtonFormField<String>));
      for (final g in allGovernorates) {
        expect(find.text(g.name), findsWidgets);
      }
      await tapText(tester, find.text('حمص').last);
      await typeInto(tester, Strings.afDetails, 'شارع الحمراء، بناء 3، الطابق 2');
      await tapText(tester, tapTarget(Strings.afSave));
      final d = f.addresses.drafts.single;
      expect(d.governorate, 'homs');
      expect(d.latitude, '');
      expect(d.longitude, '');
      // Back at the book, with the new address listed and a toast.
      expect(find.text(Strings.addressesNewTitle), findsNothing);
      expect(find.text(Strings.toastAddressSaved), findsOneWidget);
      expect(f.addresses.addresses.length, 1);
    });

    testWidgets('"use my location" places the pin; remove clears it; it is sent with the address', (tester) async {
      DeviceLocation.locator = FixedLocator(const LocateResult.found(LatLngPoint(33.5138, 36.2765)));
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.addresses);
      await tapText(tester, find.widgetWithText(FilledButton, Strings.addressesAddFirst));
      await tapText(tester, tapTargetAny(Strings.mapUseMyLocation));
      expect(find.text('33.5138, 36.2765'), findsOneWidget);
      expect(find.text(Strings.mapLocated), findsOneWidget);

      await tapText(tester, tapTargetAny(Strings.mapRemoveLocation));
      expect(find.text('33.5138, 36.2765'), findsNothing);
      await tapText(tester, tapTargetAny(Strings.mapUseMyLocation));

      await tapText(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, find.text('دمشق').last);
      await typeInto(tester, Strings.afDetails, 'شارع الثورة، بناء 5، الطابق 2');
      await tapText(tester, tapTarget(Strings.afSave));
      expect(f.addresses.drafts.single.latitude, '33.5138');
      expect(f.addresses.drafts.single.longitude, '36.2765');
    });

    testWidgets('a position outside Syria is refused and a denied permission explains itself', (tester) async {
      final outside = FixedLocator(const LocateResult.found(LatLngPoint(48.85, 2.35)));
      DeviceLocation.locator = outside;
      final f = await AppFlow.launch(tester, addressList: []);
      await f.open(tester, Routes.addresses);
      await tapText(tester, find.widgetWithText(FilledButton, Strings.addressesAddFirst));
      await tapText(tester, tapTargetAny(Strings.mapUseMyLocation));
      expect(find.text(Strings.mapOutside), findsOneWidget);
      expect(find.textContaining('48.85'), findsNothing);

      DeviceLocation.locator = FixedLocator(const LocateResult.failed(LocateFailure.denied));
      await tapText(tester, tapTargetAny(Strings.mapUseMyLocation));
      expect(find.text(Strings.mapDenied), findsOneWidget);
    });

    testWidgets('a backend rejection of the location shows its message at the map', (tester) async {
      DeviceLocation.locator = FixedLocator(const LocateResult.found(LatLngPoint(33.5138, 36.2765)));
      final api = FakeAddressesApi(addresses: [])
        ..saveError = err('INVALID_LOCATION', 422, message: 'الموقع المحدد خارج سوريا.');
      final f = await AppFlow.launch(tester, addressesApi: api);
      await f.open(tester, Routes.addresses);
      await tapText(tester, find.widgetWithText(FilledButton, Strings.addressesAddFirst));
      await tapText(tester, tapTargetAny(Strings.mapUseMyLocation));
      await tapText(tester, find.byType(DropdownButtonFormField<String>));
      await tapText(tester, find.text('دمشق').last);
      await typeInto(tester, Strings.afDetails, 'شارع الثورة، بناء 5، الطابق 2');
      await tapText(tester, tapTarget(Strings.afSave));
      expect(find.text('الموقع المحدد خارج سوريا.'), findsOneWidget);
      expect(f.addresses.addresses, isEmpty);
    });
  });

  group('orders', () {
    testWidgets('history: newest first, one line per currency, filters use the backend groups', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.all = [
        orderSummary(3),
        orderSummary(2, status: 'delivered', label: 'تم التسليم'),
        orderSummary(1, status: 'cancelled', label: 'ملغي'),
      ];
      await f.open(tester, Routes.orders);
      expect(find.text(Strings.orderNumber(3)), findsOneWidget);
      expect(find.text(Strings.orderNumber(2)), findsOneWidget);
      expect(money('115000.00', 'SYP'), findsWidgets);
      expect(money('8.50', 'USD'), findsWidgets);
      expect(find.textContaining('115008'), findsNothing);
      expect(find.text('تم التسليم'), findsOneWidget);

      await tapText(tester, find.text(Strings.ordersFilterCancelled));
      expect(f.orders.listQueries.last.group, 'cancelled');
      expect(find.text(Strings.orderNumber(1)), findsOneWidget);
      expect(find.text(Strings.orderNumber(3)), findsNothing);
      await tapText(tester, find.text(Strings.ordersFilterActive));
      expect(f.orders.listQueries.last.group, 'active');
      expect(find.text(Strings.orderNumber(3)), findsOneWidget);
      await tapText(tester, find.text(Strings.ordersFilterCompleted));
      expect(f.orders.listQueries.last.group, 'completed');
      expect(find.text(Strings.orderNumber(2)), findsOneWidget);
    });

    testWidgets('empty history and an empty filter', (tester) async {
      final f = await AppFlow.launch(tester);
      await f.open(tester, Routes.orders);
      expect(find.text(Strings.ordersEmptyTitle), findsOneWidget);
      expect(find.text(Strings.ordersStartShopping), findsOneWidget);
      await tapText(tester, find.text(Strings.ordersFilterActive));
      expect(find.text(Strings.ordersEmptyFiltered), findsOneWidget);
    });

    testWidgets('infinite scroll loads the next page', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.all = [for (var i = 30; i >= 1; i--) orderSummary(i)];
      await f.open(tester, Routes.orders);
      expect(f.orders.listQueries.map((q) => q.page), [1]);
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(f.orders.listQueries.map((q) => q.page), [1, 2]);
      await tester.drag(find.byType(ListView).last, const Offset(0, -6000));
      await tester.pumpAndSettle();
      expect(find.text(Strings.orderNumber(1)), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.listError = err('NETWORK_ERROR', 0);
      f.orders.all = [orderSummary(3)];
      await f.open(tester, Routes.orders);
      expect(find.text(Strings.retry), findsOneWidget);
      f.orders.listError = null;
      await tapText(tester, find.text(Strings.retry));
      expect(find.text(Strings.orderNumber(3)), findsOneWidget);
    });

    testWidgets('a pending order shows the timeline, the items, per-currency totals and cancel', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[7] = orderDetail();
      await f.open(tester, Routes.orderPath(7));
      expect(find.text(Strings.orderNumber(7)), findsWidgets);
      expect(find.text('قيد المراجعة'), findsWidgets); // status and first step
      expect(find.text('قيد التجهيز'), findsOneWidget); // a step not reached yet
      expect(find.text('كريم الوجه'), findsOneWidget);
      expect(money('115000.00', 'SYP'), findsOneWidget);
      expect(money('8.50', 'USD'), findsWidgets);
      expect(find.text(Strings.odCancel), findsOneWidget);
      expect(find.text(Strings.odReorder), findsOneWidget);
      expect(find.text(Strings.odViewOnMap), findsOneWidget); // the order has a pin
    });

    testWidgets('cancel asks, sends the reason, and the order becomes cancelled', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[7] = orderDetail();
      await f.open(tester, Routes.orderPath(7));
      await tapText(tester, find.widgetWithText(OutlinedButton, Strings.odCancel));
      expect(find.text(Strings.odCancelTitle), findsOneWidget);
      // Keeping the order sends nothing.
      await tapText(tester, inDialog(find.text(Strings.odKeep)));
      expect(f.orders.calls, isNot(contains('cancel')));

      await tapText(tester, find.widgetWithText(OutlinedButton, Strings.odCancel));
      await tester.enterText(inDialog(find.byType(TextField)), 'غيّرت رأيي');
      await tapText(tester, inDialog(find.text(Strings.odCancelConfirm)));
      expect(f.orders.cancelReasons, ['غيّرت رأيي']);
      expect(find.text(Strings.toastOrderCancelled), findsOneWidget);
      expect(find.text(Strings.odCancel), findsNothing); // cancelled: no more cancel
      expect(find.text('ملغي'), findsWidgets);
      expect(find.text(Strings.odCancelReasonShown('غيّرت رأيي')), findsOneWidget);
    });

    testWidgets('the store moved it on: cancel fails with the backend message and the order refreshes', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[7] = orderDetail();
      f.orders.cancelError = err('ORDER_NOT_CANCELLABLE', 409, message: 'لا يمكن إلغاء هذا الطلب الآن.');
      await f.open(tester, Routes.orderPath(7));
      f.orders.detailsById[7] = orderDetail(status: 'preparing', statusLabel: 'قيد التجهيز', canCancel: false);
      await tapText(tester, find.widgetWithText(OutlinedButton, Strings.odCancel));
      await tapText(tester, inDialog(find.text(Strings.odCancelConfirm)));
      expect(find.text('لا يمكن إلغاء هذا الطلب الآن.'), findsOneWidget);
      expect(find.text(Strings.odCancel), findsNothing); // refreshed: not cancellable now
    });

    testWidgets('cancel is not offered unless the backend says can_cancel', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[8] = orderDetail(id: 8, status: 'shipped', statusLabel: 'تم الشحن', canCancel: false);
      f.orders.detailsById[9] = orderDetail(id: 9, status: 'delivered', statusLabel: 'تم التسليم', canCancel: false);
      for (final id in [8, 9]) {
        await f.open(tester, Routes.orderPath(id));
        expect(find.text(Strings.orderNumber(id)), findsWidgets);
        expect(find.text(Strings.odCancel), findsNothing);
        expect(find.text(Strings.odReorder), findsOneWidget); // reorder stays available
      }
    });

    testWidgets('reorder uses the backend and opens the cart with a toast', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[9] = orderDetail(id: 9, status: 'delivered', statusLabel: 'تم التسليم', canCancel: false);
      f.orders.reorderResult = CartMergeResult(
        cart: checkoutCart(),
        report: const [
          MergeReportItem(index: 0, status: 'added', quantity: 2, productId: 1),
          MergeReportItem(index: 1, status: 'skipped', quantity: 0, productId: 2, reason: 'UNAVAILABLE'),
        ],
      );
      await f.open(tester, Routes.orderPath(9));
      await tapText(tester, find.widgetWithText(FilledButton, Strings.odReorder));
      expect(f.orders.reordered, [9]);
      expect(find.text(Strings.cartSummary), findsOneWidget); // the cart
      expect(find.text(Strings.toastMerged(1)), findsOneWidget);
      expect(find.text(Strings.toastMergedAdjusted), findsOneWidget);
    });

    testWidgets('a reorder that restores nothing says so and stays', (tester) async {
      final f = await AppFlow.launch(tester);
      f.orders.detailsById[9] = orderDetail(id: 9, status: 'delivered', statusLabel: 'تم التسليم', canCancel: false);
      f.orders.reorderResult = CartMergeResult(
        cart: checkoutCart(),
        report: const [MergeReportItem(index: 0, status: 'skipped', quantity: 0, reason: 'UNAVAILABLE')],
      );
      await f.open(tester, Routes.orderPath(9));
      await tapText(tester, find.widgetWithText(FilledButton, Strings.odReorder));
      expect(find.text(Strings.odReorderNothing), findsOneWidget);
      expect(find.text(Strings.orderNumber(9)), findsWidgets);
    });

    testWidgets('an unknown order shows the error without a retry', (tester) async {
      final f = await AppFlow.launch(tester);
      await f.open(tester, Routes.orderPath(404));
      expect(find.text(Strings.odCancel), findsNothing);
      expect(find.text(Strings.retry), findsNothing);
    });

    testWidgets('orders need a signed-in user', (tester) async {
      final f = await AppFlow.launch(tester, signedIn: false);
      await f.open(tester, Routes.orders);
      expect(find.text(Strings.loginLead), findsOneWidget);
    });
  });

  group('account', () {
    testWidgets('the account menu leads to orders, addresses, profile, phone and password', (tester) async {
      final f = await AppFlow.launch(tester);
      await f.open(tester, Routes.account);
      expect(find.text('ليلى'), findsOneWidget); // the basic profile card stays
      for (final entry in {
        Strings.accountOrders: Strings.orders,
        Strings.accountAddresses: Strings.addresses,
        Strings.accountProfile: Strings.profileSave,
        Strings.accountPhone: Strings.phoneSave,
        Strings.accountPassword: Strings.changeSubmit,
      }.entries) {
        await tapText(tester, find.widgetWithText(ListTile, entry.key));
        expect(find.text(entry.value), findsWidgets, reason: entry.key);
        f.deps.router.pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('profile: validates, sends only what changed, refreshes the profile', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      auth.onUpdateProfile = () async => testUser(name: 'سارة');
      await f.open(tester, Routes.account);
      await tapText(tester, find.widgetWithText(ListTile, Strings.accountProfile));

      await typeInto(tester, Strings.fieldName, '');
      await tapText(tester, tapTarget(Strings.profileSave));
      expect(auth.count('updateProfile'), 0); // client validation first
      expect(find.byType(TextField), findsNWidgets(2));

      await typeInto(tester, Strings.fieldName, 'سارة');
      await tapText(tester, tapTarget(Strings.profileSave));
      expect(auth.count('updateProfile'), 1);
      expect(auth.bodies['updateProfile'], {'name': 'سارة', 'email': null});
      expect(find.text('سارة'), findsOneWidget); // back on the account tab
      expect(find.text(Strings.toastProfileSaved), findsOneWidget);
      expect(f.deps.session.state.user!.name, 'سارة');
    });

    testWidgets('profile: a bad email is caught on the device', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.profile);
      await typeInto(tester, Strings.profileEmail, 'not-an-email');
      await tapText(tester, tapTarget(Strings.profileSave));
      expect(find.text(Strings.errEmailInvalid), findsOneWidget);
      expect(auth.count('updateProfile'), 0);
    });

    testWidgets('profile: a backend failure shows its message', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      auth.onUpdateProfile = () async => throw err('SOMETHING', 422, message: 'تعذّر حفظ البيانات.');
      await f.open(tester, Routes.profile);
      await typeInto(tester, Strings.fieldName, 'اسم جديد');
      await tapText(tester, tapTarget(Strings.profileSave));
      expect(find.text('تعذّر حفظ البيانات.'), findsOneWidget);
    });

    testWidgets('phone: needs the current password, no SMS, maps backend errors to fields', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.phone);
      expect(find.text(Strings.phoneHintPhone), findsOneWidget);
      await tapText(tester, tapTarget(Strings.phoneSave));
      expect(auth.count('changePhone'), 0); // empty phone and password

      await typeInto(tester, Strings.fieldPhone, '944000111');
      await typeInto(tester, Strings.fieldCurrentPassword, 'Wrong123');
      auth.onChangePhone = () async => throw err('INVALID_CREDENTIALS', 401, message: 'كلمة المرور غير صحيحة.');
      await tapText(tester, tapTarget(Strings.phoneSave));
      expect(find.text('كلمة المرور غير صحيحة.'), findsOneWidget);

      auth.onChangePhone = () async => throw err('PHONE_TAKEN', 409, message: 'هذا الرقم مستخدم.');
      await tapText(tester, tapTarget(Strings.phoneSave));
      expect(find.text('هذا الرقم مستخدم.'), findsOneWidget);

      auth.onChangePhone = () async => testUser(phone: '+963944000111');
      await typeInto(tester, Strings.fieldCurrentPassword, 'Right1234');
      await tapText(tester, tapTarget(Strings.phoneSave));
      expect(auth.bodies['changePhone'], {'phone': '+963944000111', 'current_password': 'Right1234'});
      expect(f.deps.session.state.user!.phone, '+963944000111');
      expect(find.text(Strings.toastPhoneChanged), findsOneWidget);
    });

    testWidgets('phone: a Google account has no password field', (tester) async {
      final auth = FakeAuthApi()..onMe = () async => testUser(provider: 'google');
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.phone);
      expect(find.text(Strings.phoneHintGoogle), findsOneWidget);
      expect(find.widgetWithText(TextField, Strings.fieldCurrentPassword), findsNothing);
      await typeInto(tester, Strings.fieldPhone, '944000111');
      await tapText(tester, tapTarget(Strings.phoneSave));
      expect(auth.bodies['changePhone'], {'phone': '+963944000111', 'current_password': null});
    });

    testWidgets('password: a voluntary change validates, maps the error and goes back with a toast', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.account);
      await tapText(tester, find.widgetWithText(ListTile, Strings.accountPassword));
      expect(find.text(Strings.passwordHint), findsOneWidget);

      await typeInto(tester, Strings.fieldCurrentPassword, 'OldPass123');
      await typeInto(tester, Strings.fieldNewPassword, 'short');
      await typeInto(tester, Strings.fieldConfirmPassword, 'short');
      await tapText(tester, tapTarget(Strings.changeSubmit));
      expect(auth.count('change'), 0); // too weak: stopped on the device

      await typeInto(tester, Strings.fieldNewPassword, 'NewPass1234');
      await typeInto(tester, Strings.fieldConfirmPassword, 'Different1234');
      await tapText(tester, tapTarget(Strings.changeSubmit));
      expect(auth.count('change'), 0);

      await typeInto(tester, Strings.fieldConfirmPassword, 'NewPass1234');
      auth.onChange = () async => throw err('CURRENT_PASSWORD_INCORRECT', 400, message: 'كلمة المرور الحالية غير صحيحة.');
      await tapText(tester, tapTarget(Strings.changeSubmit));
      expect(find.text('كلمة المرور الحالية غير صحيحة.'), findsOneWidget);

      auth.onChange = () async => testPair();
      await tapText(tester, tapTarget(Strings.changeSubmit));
      expect(auth.count('change'), 2);
      expect(find.text(Strings.toastPasswordChanged), findsOneWidget);
      expect(find.text(Strings.accountLogoutAll), findsOneWidget); // back on the account tab
    });

    testWidgets('password: a Google account has no password to change', (tester) async {
      final auth = FakeAuthApi()..onMe = () async => testUser(provider: 'google');
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.password);
      expect(find.text(Strings.passwordGoogleAccount), findsOneWidget);
      expect(find.text(Strings.changeSubmit), findsNothing);
    });

    testWidgets('logout from all devices asks first, then ends every session', (tester) async {
      final auth = FakeAuthApi();
      final f = await AppFlow.launch(tester, auth: auth);
      await f.open(tester, Routes.account);
      await tapText(tester, find.widgetWithText(TextButton, Strings.accountLogoutAll));
      expect(find.text(Strings.logoutAllTitle), findsOneWidget);
      await tapText(tester, inDialog(find.text(Strings.cancel)));
      expect(auth.count('logoutAll'), 0);
      expect(f.deps.session.state.isAuthenticated, isTrue);

      await tapText(tester, find.widgetWithText(TextButton, Strings.accountLogoutAll));
      await tapText(tester, inDialog(find.text(Strings.logoutAllConfirm)));
      expect(auth.count('logoutAll'), 1);
      expect(f.deps.session.state.status, SessionStatus.unauthenticated);
      expect(find.text(Strings.loginLead), findsOneWidget);
    });
  });
}

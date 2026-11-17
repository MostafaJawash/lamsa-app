import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';
import 'package:lamsa_app/features/notifications/data/push_messaging.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:lamsa_app/features/notifications/data/push_store.dart';

import '../auth/auth_fakes.dart';
import '../orders/flow_harness.dart';
import '../orders/orders_fakes.dart';
import 'notification_fakes.dart';

Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

/// The unread count on the account tab icon (null when no badge shows).
String? accountBadge(WidgetTester tester) {
  final badges = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byType(Badge),
  );
  for (final e in badges.evaluate()) {
    final b = e.widget as Badge;
    final icon = find.descendant(of: find.byWidget(b), matching: find.byIcon(Icons.person_outline));
    final iconSel = find.descendant(of: find.byWidget(b), matching: find.byIcon(Icons.person));
    if (icon.evaluate().isNotEmpty || iconSel.evaluate().isNotEmpty) {
      if (!b.isLabelVisible) return null;
      return (b.label! as Text).data;
    }
  }
  return null;
}

bool isUnread(WidgetTester tester, int id) =>
    find.byKey(ValueKey('dot-$id-unread')).evaluate().isNotEmpty;

({PushService push, FakePushMessaging fcm, FakeDevicesApi devices, MemoryPushStore store}) makePush({
  bool configured = true,
  PushPermission permission = PushPermission.notDetermined,
}) {
  final fcm = FakePushMessaging()
    ..configured = configured
    ..permissionNow = permission;
  final devices = FakeDevicesApi();
  final store = MemoryPushStore();
  final push = PushService(devices, messaging: fcm, store: store, platform: 'android');
  return (push: push, fcm: fcm, devices: devices, store: store);
}

void main() {
  group('inbox', () {
    testWidgets('lists notifications newest first, with read and unread state and relative times', (tester) async {
      final api = FakeNotificationsApi([
        notif(3, sentAt: DateTime.now().subtract(const Duration(minutes: 5))),
        notif(2, read: true, title: 'عرض جديد', type: 'marketing', link: const NotificationLink(type: 'sale'), orderId: null),
        notif(1, read: true),
      ]);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      expect(find.text('تم شحن طلبك #3'), findsOneWidget);
      expect(find.text('عرض جديد #2'), findsOneWidget);
      expect(find.text('قبل 5 دقائق'), findsOneWidget);
      expect(isUnread(tester, 3), isTrue);
      expect(isUnread(tester, 2), isFalse);
      expect(find.byKey(const ValueKey('dot-2-read')), findsOneWidget);
      expect(find.text(Strings.notifMarkAll), findsOneWidget); // something is unread
    });

    testWidgets('an empty inbox says so', (tester) async {
      final f = await AppFlow.launch(tester);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.notifEmptyTitle), findsOneWidget);
      expect(find.text(Strings.notifMarkAll), findsNothing);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final api = FakeNotificationsApi([notif(1)])..listError = notifError('NETWORK_ERROR', 0);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.retry), findsOneWidget);
      api.listError = null;
      await tapText(tester, find.text(Strings.retry));
      expect(find.text('تم شحن طلبك #1'), findsOneWidget);
    });

    testWidgets('infinite scroll loads the next page', (tester) async {
      final api = FakeNotificationsApi([for (var i = 30; i >= 1; i--) notif(i, read: true)]);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      // A phone-sized screen: the first page must be taller than the screen.
      tester.view.physicalSize = const Size(420, 800);
      await tester.pumpAndSettle();
      expect(api.listPages, [1]);
      await tester.drag(find.byType(ListView).last, const Offset(0, -8000));
      await tester.pumpAndSettle();
      expect(api.listPages, [1, 2]);
    });

    testWidgets('tapping a notification marks it read, updates the badge and opens its order', (tester) async {
      final api = FakeNotificationsApi([notif(2), notif(1)]);
      final f = await AppFlow.launch(tester, notifications: api);
      f.orders.detailsById[45] = orderDetail(id: 45);
      expect(accountBadge(tester), '2');
      await f.open(tester, Routes.notifications);
      expect(isUnread(tester, 2), isTrue);

      await tapText(tester, find.text('تم شحن طلبك #2'));
      expect(api.calls, contains('markRead:2'));
      expect(find.text(Strings.orderNumber(45)), findsWidgets); // the order screen
      f.deps.router.pop();
      await tester.pumpAndSettle();
      expect(isUnread(tester, 2), isFalse);
      expect(isUnread(tester, 1), isTrue);
      await f.open(tester, Routes.home); // the shell (and its tab bar) again
      expect(accountBadge(tester), '1');
    });

    testWidgets('a notification without a destination only marks itself read', (tester) async {
      final api = FakeNotificationsApi([
        notif(1, type: 'marketing', title: 'خصم', link: const NotificationLink(), orderId: null),
      ]);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.text('خصم #1'));
      expect(api.calls, contains('markRead:1'));
      expect(isUnread(tester, 1), isFalse);
      expect(find.text(Strings.notifications), findsWidgets); // still the inbox
    });

    testWidgets('a sale notification opens the sale list', (tester) async {
      final api = FakeNotificationsApi([
        notif(1, type: 'marketing', title: 'عروض', link: const NotificationLink(type: 'sale'), orderId: null),
      ]);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.text('عروض #1'));
      expect(find.text(Strings.notifications), findsNothing); // left the inbox
    });

    testWidgets('mark all as read clears the dots, the button and the badge', (tester) async {
      final api = FakeNotificationsApi([notif(3), notif(2), notif(1, read: true)]);
      final f = await AppFlow.launch(tester, notifications: api);
      expect(accountBadge(tester), '2');
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.text(Strings.notifMarkAll));
      expect(api.calls, contains('markAllRead'));
      expect(isUnread(tester, 3), isFalse);
      expect(isUnread(tester, 2), isFalse);
      expect(find.text(Strings.notifMarkAll), findsNothing);
      await f.open(tester, Routes.home);
      expect(accountBadge(tester), isNull);
    });

    testWidgets('a failed mark-all goes back and says why', (tester) async {
      final api = FakeNotificationsApi([notif(2), notif(1)])
        ..markError = notifError('SERVICE_BUSY', 503, message: 'الخدمة مشغولة');
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.text(Strings.notifMarkAll));
      expect(isUnread(tester, 2), isTrue);
      expect(find.text('الخدمة مشغولة'), findsOneWidget);
      await f.open(tester, Routes.home);
      expect(accountBadge(tester), '2');
    });

    testWidgets('a failed mark-read puts the dot back', (tester) async {
      final api = FakeNotificationsApi([
        notif(1, type: 'marketing', title: 'خصم', link: const NotificationLink(), orderId: null),
      ])..markError = notifError('NETWORK_ERROR', 0);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.text('خصم #1'));
      expect(isUnread(tester, 1), isTrue);
    });

    testWidgets('the inbox needs a signed-in user', (tester) async {
      final f = await AppFlow.launch(tester, signedIn: false);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.loginLead), findsOneWidget);
    });
  });

  group('badge', () {
    testWidgets('shows the unread count on the account tab, 99+ above 99, nothing at 0', (tester) async {
      final api = FakeNotificationsApi([for (var i = 1; i <= 120; i++) notif(i)]);
      final f = await AppFlow.launch(tester, notifications: api);
      expect(accountBadge(tester), Strings.badgeOverflow);
      api.all = [];
      await f.deps.unread.refresh();
      await tester.pumpAndSettle();
      expect(accountBadge(tester), isNull);
    });

    testWidgets('a push that arrives in the foreground raises it at once', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      final api = FakeNotificationsApi([notif(1)]);
      await AppFlow.launch(tester, notifications: api, push: p.push);
      expect(accountBadge(tester), '1');
      api.all = [notif(2), ...api.all];
      p.fcm.messageController.add(pushOf(id: '2'));
      await tester.pump();
      await tester.pump();
      expect(accountBadge(tester), '2');
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('the badge goes away when the customer signs out', (tester) async {
      final api = FakeNotificationsApi([notif(1)]);
      final f = await AppFlow.launch(tester, notifications: api);
      expect(accountBadge(tester), '1');
      await f.deps.session.signOut();
      await tester.pumpAndSettle();
      expect(accountBadge(tester), isNull);
    });

    testWidgets('the account menu has the inbox with its badge and the preferences', (tester) async {
      final api = FakeNotificationsApi([notif(2), notif(1)]);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.account);
      final row = find.widgetWithText(ListTile, Strings.notifications);
      expect(row, findsOneWidget);
      expect(find.descendant(of: row, matching: find.byType(Badge)), findsOneWidget);
      await tapText(tester, find.widgetWithText(ListTile, Strings.prefsTitle));
      expect(find.text(Strings.prefsLead), findsOneWidget);
      f.deps.router.pop();
      await tester.pumpAndSettle();
      await tapText(tester, row);
      expect(find.text('تم شحن طلبك #2'), findsOneWidget);
    });
  });

  group('foreground banner', () {
    testWidgets('a push while the app is open is drawn as a banner that opens its order', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      final api = FakeNotificationsApi([notif(123), notif(1, read: true)]);
      final f = await AppFlow.launch(tester, notifications: api, push: p.push);
      f.orders.detailsById[45] = orderDetail(id: 45);
      p.fcm.messageController.add(pushOf(body: 'في الطريق إليك'));
      await tester.pump();
      await tester.pump();
      expect(find.text('تم شحن طلبك #45'), findsOneWidget);
      expect(find.text('في الطريق إليك'), findsOneWidget);

      await tester.tap(find.text('في الطريق إليك'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.orderNumber(45)), findsWidgets);
      expect(api.calls, contains('markRead:123'));
      expect(find.text('في الطريق إليك'), findsNothing); // the banner left
    });

    testWidgets('the banner goes away by itself and can be closed', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      await AppFlow.launch(tester, push: p.push);
      p.fcm.messageController.add(pushOf(id: '1', body: 'الأولى'));
      await tester.pump();
      await tester.pump();
      expect(find.text('الأولى'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      expect(find.text('الأولى'), findsNothing);

      p.fcm.messageController.add(pushOf(id: '2', body: 'الثانية'));
      await tester.pump();
      await tester.pump();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();
      expect(find.text('الثانية'), findsNothing);
    });

    testWidgets('a push delivered twice draws one banner', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      await AppFlow.launch(tester, push: p.push);
      p.fcm.messageController
        ..add(pushOf(id: '5', body: 'مكررة'))
        ..add(pushOf(id: '5', body: 'مكررة'));
      await tester.pump();
      await tester.pump();
      expect(find.text('مكررة'), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
    });

    testWidgets('a push tapped from the background opens its screen', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      final f = await AppFlow.launch(tester, push: p.push);
      f.orders.detailsById[45] = orderDetail(id: 45);
      p.fcm.openedController.add(pushOf(id: '9'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.orderNumber(45)), findsWidgets);
    });

    testWidgets('an admin or unknown link tap does nothing and stays put', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      final f = await AppFlow.launch(tester, push: p.push);
      p.fcm.openedController
        ..add(pushOf(id: '10', linkType: 'admin_order', linkValue: '5'))
        ..add(pushOf(id: '11', linkType: 'mystery'));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget); // still on the shell
      expect(f.notifications.calls.where((c) => c.startsWith('markRead')), isEmpty);
    });

    testWidgets('a guest who taps an order push is asked to sign in first', (tester) async {
      final p = makePush(permission: PushPermission.granted);
      await p.push.init();
      await AppFlow.launch(tester, signedIn: false, push: p.push);
      p.fcm.openedController.add(pushOf(id: '12'));
      await tester.pumpAndSettle();
      expect(find.text(Strings.loginLead), findsOneWidget);
    });
  });

  group('preferences', () {
    testWidgets('three switches from the backend, and order updates is a note, not a switch', (tester) async {
      final api = FakeNotificationsApi()..prefs = const NotificationPrefs(favorites: false);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notificationSettings);
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches.length, 3);
      expect(switches.map((s) => s.value), [true, false, true]); // marketing, favorites, cart
      expect(find.text(Strings.prefsOrderUpdates), findsOneWidget);
      expect(find.text(Strings.prefsAlwaysOn), findsOneWidget);
      expect(find.text(Strings.prefsOrderUpdatesHint), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, Strings.prefsOrderUpdates), findsNothing);
      expect(find.text(Strings.prefsStoreMessages), findsOneWidget);
    });

    testWidgets('toggling saves only that switch', (tester) async {
      final api = FakeNotificationsApi();
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notificationSettings);
      await tapText(tester, find.widgetWithText(SwitchListTile, Strings.prefsMarketing));
      expect(api.updates, [
        {'notify_marketing': false},
      ]);
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, Strings.prefsMarketing)).value, isFalse);
      await tapText(tester, find.widgetWithText(SwitchListTile, Strings.prefsCartReminders));
      expect(api.updates.last, {'notify_cart_reminders': false});
      expect(api.prefs.marketing, isFalse);
      expect(api.prefs.cartReminders, isFalse);
      expect(api.prefs.favorites, isTrue);
    });

    testWidgets('a refused save goes back and shows the reason', (tester) async {
      final api = FakeNotificationsApi()..updateError = notifError('SERVICE_BUSY', 503, message: 'الخدمة مشغولة');
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notificationSettings);
      await tapText(tester, find.widgetWithText(SwitchListTile, Strings.prefsFavorites));
      expect(tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, Strings.prefsFavorites)).value, isTrue);
      expect(find.text('الخدمة مشغولة'), findsOneWidget);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final api = FakeNotificationsApi()..prefsError = notifError('NETWORK_ERROR', 0);
      final f = await AppFlow.launch(tester, notifications: api);
      await f.open(tester, Routes.notificationSettings);
      expect(find.text(Strings.retry), findsOneWidget);
      api.prefsError = null;
      await tapText(tester, find.text(Strings.retry));
      expect(find.byType(Switch), findsNWidgets(3));
    });

    testWidgets('the inbox links to the preferences', (tester) async {
      final f = await AppFlow.launch(tester);
      await f.open(tester, Routes.notifications);
      await tapText(tester, find.byTooltip(Strings.prefsTitle));
      expect(find.text(Strings.prefsLead), findsOneWidget);
    });
  });

  group('asking for the permission', () {
    testWidgets('the inbox offers it while it was never asked, and registers once granted', (tester) async {
      final p = makePush();
      await p.push.init();
      final f = await AppFlow.launch(tester, push: p.push);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.pushAskTitle), findsOneWidget);
      expect(p.fcm.requestCalls, 0); // never on launch or on opening
      await tapText(tester, find.widgetWithText(FilledButton, Strings.pushAskAction));
      expect(p.fcm.requestCalls, 1);
      expect(find.text(Strings.pushAskTitle), findsNothing);
      expect(p.devices.registered.length, 1);
    });

    testWidgets('after a refusal it explains how to enable it, without a button', (tester) async {
      final p = makePush(permission: PushPermission.denied);
      await p.push.init();
      final f = await AppFlow.launch(tester, push: p.push);
      await f.open(tester, Routes.notificationSettings);
      expect(find.text(Strings.pushDeniedText), findsOneWidget);
      expect(find.text(Strings.pushAskAction), findsNothing);
    });

    testWidgets('nothing is shown when granted or when push is unavailable', (tester) async {
      final granted = makePush(permission: PushPermission.granted);
      await granted.push.init();
      final f = await AppFlow.launch(tester, push: granted.push);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.pushAskTitle), findsNothing);
      expect(find.text(Strings.pushDeniedText), findsNothing);
    });

    testWidgets('without Firebase config no prompt shows anywhere', (tester) async {
      final p = makePush(configured: false);
      await p.push.init();
      final f = await AppFlow.launch(tester, push: p.push);
      await f.open(tester, Routes.notifications);
      expect(find.text(Strings.pushAskTitle), findsNothing);
      expect(find.text(Strings.pushDeniedText), findsNothing);
    });

    Future<AppFlow> placeOrder(WidgetTester tester, PushService push) async {
      final f = await AppFlow.launch(tester, push: push);
      f.orders.placeScript.add(orderDetail());
      await f.open(tester, Routes.checkout);
      await tapText(tester, tapTarget(Strings.checkoutConfirm));
      return f;
    }

    testWidgets('the order confirmation explains first, then asks', (tester) async {
      final p = makePush();
      await p.push.init();
      await placeOrder(tester, p.push);
      expect(find.text(Strings.successTitle), findsWidgets);
      expect(find.text(Strings.pushExplainTitle), findsOneWidget);
      expect(p.fcm.requestCalls, 0); // the explainer comes before the system prompt
      await tapText(tester, find.text(Strings.pushExplainAllow));
      expect(p.fcm.requestCalls, 1);
      expect(p.devices.registered.length, 1);
      expect(await p.push.explained, isTrue);
    });

    testWidgets('"not now" does not ask the system, and the explainer is not repeated', (tester) async {
      final p = makePush();
      await p.push.init();
      await placeOrder(tester, p.push);
      await tapText(tester, find.text(Strings.pushExplainLater));
      expect(p.fcm.requestCalls, 0);
      expect(find.text(Strings.pushExplainTitle), findsNothing);
    });

    testWidgets('no explainer when it was already asked or push is unavailable', (tester) async {
      final asked = makePush(permission: PushPermission.denied);
      await asked.push.init();
      await placeOrder(tester, asked.push);
      expect(find.text(Strings.pushExplainTitle), findsNothing);
    });

    testWidgets('no explainer without Firebase config', (tester) async {
      final p = makePush(configured: false);
      await p.push.init();
      await placeOrder(tester, p.push);
      expect(find.text(Strings.successTitle), findsWidgets);
      expect(find.text(Strings.pushExplainTitle), findsNothing);
    });
  });

  group('session and the device token', () {
    test('sign-in registers the token, restore does too, sign-out unregisters first', () async {
      final fcm = FakePushMessaging()..permissionNow = PushPermission.granted;
      final devices = FakeDevicesApi();
      final push = PushService(devices, messaging: fcm, store: MemoryPushStore(), platform: 'android');
      await push.init();
      final api = FakeAuthApi();
      final session = makeSession(api: api, push: push);
      await session.signIn(testPair());
      expect(devices.registered.length, 1);
      await session.signIn(testPair()); // another account on the same device
      expect(devices.registered.length, 2); // forced: the backend moves the token
      await session.signOut();
      expect(devices.unregistered, ['fcm-token-1']);
      expect(api.count('logout'), 1);
      await fcm.close();
    });

    test('a restored session registers the token', () async {
      final fcm = FakePushMessaging();
      final devices = FakeDevicesApi();
      final push = PushService(devices, messaging: fcm, store: MemoryPushStore(), platform: 'android');
      await push.init();
      final session = makeSession(storage: MemoryTokenStorage(storedTokens()), push: push);
      await session.restore();
      expect(devices.registered.length, 1);
      expect(fcm.requestCalls, 0); // no permission prompt at login or launch
      await fcm.close();
    });
  });
}

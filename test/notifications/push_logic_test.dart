import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/network/interceptors.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/notification_format.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';
import 'package:lamsa_app/features/notifications/data/notification_target.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';
import 'package:lamsa_app/features/notifications/data/push_coordinator.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';
import 'package:lamsa_app/features/notifications/data/push_messaging.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:lamsa_app/features/notifications/data/push_store.dart';

import '../auth/auth_fakes.dart';
import 'notification_fakes.dart';

class Adapter implements HttpClientAdapter {
  Adapter(this.body, [this.status = 200]);

  final Object? body;
  final int status;
  RequestOptions? last;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    last = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio dioWith(Adapter a) => Dio(BaseOptions(baseUrl: 'http://x/api/v1'))
  ..httpClientAdapter = a
  ..interceptors.add(ErrorMappingInterceptor());

NotificationTarget target(
  String type, [
  String? value,
  int? orderId,
  String? kind,
]) =>
    resolveNotificationTarget(
      linkType: type,
      linkValue: value,
      orderId: orderId,
      type: kind,
    );

void main() {
  group('link type to route', () {
    test('customer links go to the routes already built', () {
      expect(target('order', '45'), InternalTarget(Routes.orderPath(45)));
      expect(target('order', ' 45 '), InternalTarget(Routes.orderPath(45)));
      expect(target('product', 'rose-cream'), InternalTarget(Routes.productPath('rose-cream')));
      expect(target('category', 'skin'), InternalTarget(Routes.categoryPath('skin')));
      expect(target('brand', 'luma'), InternalTarget(Routes.brandPath('luma')));
      expect(target('new'), const InternalTarget(Routes.newArrivals));
      expect(target('sale'), const InternalTarget(Routes.sale));
    });

    test('slugs are encoded, blank ones lead nowhere', () {
      expect(target('product', 'كريم الورد'), InternalTarget(Routes.productPath('كريم الورد')));
      expect(target('product', 'a b'), const InternalTarget('/product/a%20b'));
      for (final t in ['product', 'category', 'brand']) {
        expect(target(t), const NoTarget(), reason: t);
        expect(target(t, '  '), const NoTarget(), reason: t);
      }
    });

    test('an order link needs a positive integer id', () {
      for (final bad in [null, '', 'abc', '0', '-3', '4.5', '1234567890', '12/../3']) {
        expect(target('order', bad), const NoTarget(), reason: '$bad');
      }
    });

    test('url links open in the browser only over https', () {
      expect(target('url', 'https://lamsa.example/offer'), ExternalTarget(Uri.parse('https://lamsa.example/offer')));
      expect(target('url', 'HTTPS://lamsa.example'), isA<ExternalTarget>());
      for (final bad in ['http://lamsa.example', 'javascript:alert(1)', 'https://', 'lamsa.example', '', null, 'intent://x']) {
        expect(target('url', bad), const NoTarget(), reason: '$bad');
      }
    });

    test('none: the order, the cart for a cart reminder, else the inbox', () {
      expect(target('none', null, 45), InternalTarget(Routes.orderPath(45)));
      expect(target('none', null, null, 'cart_reminder'), const InternalTarget(Routes.cart, tab: true));
      expect(target('none'), const InternalTarget(Routes.notifications));
      expect(target('', null, null, 'marketing'), const InternalTarget(Routes.notifications));
      expect(target('none', null, 0), const InternalTarget(Routes.notifications));
    });

    test('admin and unknown types are ignored safely', () {
      for (final t in ['admin_order', 'admin_product', 'wat', 'ORDER', 'Order', '../x']) {
        expect(target(t, '45', 45), const NoTarget(), reason: t);
      }
    });

    test('an inbox row with no destination has no target (it only marks itself read)', () {
      expect(inboxTarget(linkType: 'none'), const NoTarget());
      expect(inboxTarget(linkType: 'none', orderId: 45), InternalTarget(Routes.orderPath(45)));
      expect(inboxTarget(linkType: 'sale'), const InternalTarget(Routes.sale));
      expect(inboxTarget(linkType: 'admin_order', linkValue: '1'), const NoTarget());
    });
  });

  group('push data', () {
    test('parses the backend payload (all strings)', () {
      final l = PushLink.fromData(pushOf().data);
      expect(l.notificationId, '123');
      expect(l.type, 'order_update');
      expect(l.linkType, 'order');
      expect(l.linkValue, '45');
      expect(l.orderId, 45);
      expect(l.inboxId, 123);
      expect(l.isTest, isFalse);
      expect(l.hasId, isTrue);
    });

    test('empty values mean not set; a test push has no id', () {
      final l = PushLink.fromData({'notification_id': '', 'link_type': '', 'link_value': '', 'order_id': '', 'test': '1'});
      expect(l.hasId, isFalse);
      expect(l.linkType, 'none');
      expect(l.linkValue, isNull);
      expect(l.orderId, isNull);
      expect(l.inboxId, isNull);
      expect(l.isTest, isTrue);
      expect(PushLink.fromData(const {}).linkType, 'none');
      expect(PushLink.fromData({'order_id': 'x'}).orderId, isNull);
    });
  });

  group('dedup by notification_id', () {
    test('the same id is new once', () async {
      final s = SeenIds(MemoryPushStore(), PushSets.shown);
      expect(await s.firstTime('1'), isTrue);
      expect(await s.firstTime('1'), isFalse);
      expect(await s.firstTime('2'), isTrue);
    });

    test('a push without an id (a test push) is always new and not remembered', () async {
      final store = MemoryPushStore();
      final s = SeenIds(store, PushSets.shown);
      expect(await s.firstTime(''), isTrue);
      expect(await s.firstTime(''), isTrue);
      expect(store.ids[PushSets.shown], isNull);
    });

    test('two arriving together cannot both be first', () async {
      final s = SeenIds(MemoryPushStore(), PushSets.shown);
      expect(await Future.wait([s.firstTime('7'), s.firstTime('7'), s.firstTime('7')]), [true, false, false]);
    });

    test('it survives a restart (a new instance on the same storage)', () async {
      final store = MemoryPushStore();
      expect(await SeenIds(store, PushSets.shown).firstTime('9'), isTrue);
      expect(await SeenIds(store, PushSets.shown).firstTime('9'), isFalse);
    });

    test('only the newest ids are kept', () async {
      final store = MemoryPushStore();
      final s = SeenIds(store, PushSets.shown, capacity: 3);
      for (final id in ['1', '2', '3', '4']) {
        await s.firstTime(id);
      }
      expect(store.ids[PushSets.shown], ['2', '3', '4']);
      expect(await s.firstTime('1'), isTrue); // forgotten
      expect(await s.firstTime('4'), isFalse);
    });

    test('banners shown and pushes opened are separate sets', () async {
      final store = MemoryPushStore();
      final shown = SeenIds(store, PushSets.shown);
      final opened = SeenIds(store, PushSets.opened);
      expect(await shown.firstTime('5'), isTrue);
      expect(await opened.firstTime('5'), isTrue); // tapping a shown banner works
      expect(await opened.firstTime('5'), isFalse);
    });
  });

  group('device registration payloads', () {
    test('register sends the token and the platform', () async {
      final a = Adapter(null, 204);
      await DevicesApi(dioWith(a)).register(fcmToken: 'tok', platform: 'ios');
      expect(a.last!.method, 'POST');
      expect(a.last!.path, '/users/me/devices');
      expect(a.last!.data, {'fcm_token': 'tok', 'platform': 'ios'});
    });

    test('unregister is the backend\'s real endpoint with the token', () async {
      final a = Adapter(null, 204);
      await DevicesApi(dioWith(a)).unregister(fcmToken: 'tok');
      expect(a.last!.method, 'POST');
      expect(a.last!.path, '/users/me/devices/unregister');
      expect(a.last!.data, {'fcm_token': 'tok'});
    });
  });

  group('inbox and preferences API', () {
    final item = {
      'id': 5,
      'type': 'order_update',
      'title': 'تم شحن طلبك #45',
      'body': 'x',
      'link': {'type': 'order', 'value': '45'},
      'order_id': 45,
      'sent_at': '2026-11-17T09:00:00',
      'is_read': false,
      'read_at': null,
    };

    test('list sends the page and parses the items and the unread count', () async {
      final a = Adapter({'items': [item], 'page': 2, 'page_size': 20, 'total': 21, 'unread_count': 3});
      final p = await NotificationsApi(dioWith(a)).list(page: 2);
      expect(a.last!.path, '/notifications');
      expect(a.last!.queryParameters, {'page': 2, 'page_size': 20});
      expect(p.unreadCount, 3);
      expect(p.total, 21);
      final n = p.items.single;
      expect(n.id, 5);
      expect(n.link, const NotificationLink(type: 'order', value: '45'));
      expect(n.orderId, 45);
      expect(n.isRead, isFalse);
      expect(n.sentAt, DateTime.utc(2026, 11, 17, 9));
    });

    test('a missing or odd link is none', () {
      expect(AppNotification.fromJson({...item, 'link': null}).link, const NotificationLink());
      expect(AppNotification.fromJson({...item, 'link': {'type': '', 'value': null}}).link, const NotificationLink());
    });

    test('unread count, mark read and mark all read', () async {
      final unread = Adapter({'unread_count': 4});
      expect(await NotificationsApi(dioWith(unread)).unreadCount(), 4);
      expect(unread.last!.path, '/notifications/unread-count');
      final read = Adapter({'unread_count': 2});
      expect(await NotificationsApi(dioWith(read)).markRead(5), 2);
      expect(read.last!.method, 'POST');
      expect(read.last!.path, '/notifications/5/read');
      final all = Adapter({'unread_count': 0});
      expect(await NotificationsApi(dioWith(all)).markAllRead(), 0);
      expect(all.last!.path, '/notifications/read-all');
    });

    test('preferences: read, and PATCH only the switch that changed', () async {
      final get = Adapter({'notify_marketing': false, 'notify_favorites': true, 'notify_cart_reminders': true, 'order_updates': true});
      final p = await NotificationsApi(dioWith(get)).preferences();
      expect(get.last!.path, '/users/me/notification-preferences');
      expect(p.marketing, isFalse);
      expect(p.favorites, isTrue);
      expect(p.orderUpdates, isTrue); // always on

      final patch = Adapter({'notify_marketing': true, 'notify_favorites': false, 'notify_cart_reminders': true, 'order_updates': true});
      final saved = await NotificationsApi(dioWith(patch)).updatePreferences(favorites: false);
      expect(patch.last!.method, 'PATCH');
      expect(patch.last!.data, {'notify_favorites': false});
      expect(saved.favorites, isFalse);
    });

    test('a refusal surfaces as the backend error', () async {
      final a = Adapter({'error': {'code': 'NOTIFICATION_NOT_FOUND', 'message': 'غير موجود', 'details': null}}, 404);
      await expectLater(
        NotificationsApi(dioWith(a)).markRead(9),
        throwsA(isA<Object>().having((e) => '$e', 'text', contains('NOTIFICATION_NOT_FOUND'))),
      );
    });
  });

  group('relative times', () {
    final now = DateTime.utc(2026, 11, 17, 12);
    test('just now, minutes, hours, then the date', () {
      expect(formatNotificationTime(now, now), Strings.notifJustNow);
      expect(formatNotificationTime(now.subtract(const Duration(seconds: 30)), now), Strings.notifJustNow);
      expect(formatNotificationTime(now.add(const Duration(minutes: 5)), now), Strings.notifJustNow); // clock skew
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 1)), now), 'قبل دقيقة');
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 2)), now), 'قبل دقيقتين');
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 5)), now), 'قبل 5 دقائق');
      expect(formatNotificationTime(now.subtract(const Duration(minutes: 45)), now), 'قبل 45 دقيقة');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 1)), now), 'قبل ساعة');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 2)), now), 'قبل ساعتين');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 5)), now), 'قبل 5 ساعات');
      expect(formatNotificationTime(now.subtract(const Duration(hours: 13)), now), 'قبل 13 ساعة');
      // A day or more: the date and time in Damascus time (UTC+3).
      expect(formatNotificationTime(DateTime.utc(2026, 11, 16, 6, 5), now), '16 نوفمبر 2026، 09:05 ص');
    });
  });

  group('PushService', () {
    late FakePushMessaging fcm;
    late FakeDevicesApi devices;
    late MemoryPushStore store;

    PushService make({String platform = 'android'}) => PushService(
          devices,
          messaging: fcm,
          store: store,
          platform: platform,
        );

    setUp(() {
      fcm = FakePushMessaging();
      devices = FakeDevicesApi();
      store = MemoryPushStore();
    });
    tearDown(() => fcm.close());

    test('without Firebase config everything is inert', () async {
      fcm.configured = false;
      final s = make();
      await s.init();
      expect(s.isAvailable, isFalse);
      await s.registerForUser();
      expect(fcm.tokenCalls, 0);
      expect(devices.registered, isEmpty);
      expect(await s.permission(), PushPermission.denied);
      expect(await s.requestPermission(), PushPermission.denied);
      expect(fcm.requestCalls, 0);
      await s.unregister(); // nothing registered: nothing to do
      expect(devices.unregistered, isEmpty);
    });

    test('registering sends the token and platform and does not ask for permission', () async {
      final s = make(platform: 'ios');
      await s.init();
      await s.registerForUser();
      expect(devices.registered, [(token: 'fcm-token-1', platform: 'ios')]);
      expect(fcm.requestCalls, 0); // the prompt is a separate, contextual step
      expect(store.token, 'fcm-token-1');
    });

    test('the same token is not sent twice, unless forced (a sign-in)', () async {
      final s = make();
      await s.init();
      await s.registerForUser();
      await s.registerForUser(); // e.g. the app resumed
      expect(devices.registered.length, 1);
      await s.registerForUser(force: true); // signed in again: the backend moves the token
      expect(devices.registered.length, 2);
    });

    test('a rotated token is registered again and remembered', () async {
      final s = make();
      await s.init();
      await s.registerForUser();
      fcm.refreshController.add('fcm-token-2');
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered.map((r) => r.token), ['fcm-token-1', 'fcm-token-2']);
      expect(store.token, 'fcm-token-2');
      // ...and the next unregister removes the NEW token.
      await s.unregister();
      expect(devices.unregistered, ['fcm-token-2']);
    });

    test('resuming with a changed token registers it', () async {
      final s = make();
      await s.init();
      await s.registerForUser();
      fcm.tokenValue = 'fcm-token-9';
      await s.registerForUser();
      expect(devices.registered.last.token, 'fcm-token-9');
    });

    test('unregister uses the real endpoint with the token, clears it and stops listening', () async {
      final s = make();
      await s.init();
      await s.registerForUser();
      await s.unregister();
      expect(devices.unregistered, ['fcm-token-1']);
      expect(store.token, isNull);
      fcm.refreshController.add('fcm-token-3'); // after logout: not registered
      await Future<void>.delayed(Duration.zero);
      expect(devices.registered.length, 1);
    });

    test('unregister works after an app restart (the token was kept on the device)', () async {
      final first = make();
      await first.init();
      await first.registerForUser();
      final restarted = make(); // a new run: nothing registered yet
      await restarted.init();
      await restarted.unregister();
      expect(devices.unregistered, ['fcm-token-1']);
    });

    test('failures never throw: registration, refresh and unregister', () async {
      final s = make();
      await s.init();
      devices.registerError = notifError('SERVICE_BUSY', 503);
      await s.registerForUser(); // swallowed
      expect(store.token, isNull);
      devices.registerError = null;
      await s.registerForUser();
      devices.unregisterError = notifError('NETWORK_ERROR', 0);
      await s.unregister(); // sign-out must go on
      expect(store.token, 'fcm-token-1'); // kept, so a later unregister can retry
    });

    test('a missing token registers nothing', () async {
      fcm.tokenValue = null;
      final s = make();
      await s.init();
      await s.registerForUser();
      expect(devices.registered, isEmpty);
    });

    test('permission: asked on request only, the answer is passed on', () async {
      final s = make();
      await s.init();
      expect(await s.permission(), PushPermission.notDetermined);
      expect(fcm.requestCalls, 0);
      fcm.answer = PushPermission.denied;
      expect(await s.requestPermission(), PushPermission.denied);
      expect(await s.permission(), PushPermission.denied);
    });

    test('the explainer is remembered', () async {
      final s = make();
      expect(await s.explained, isFalse);
      await s.markExplained();
      expect(await s.explained, isTrue);
    });

    test('foreground and tapped pushes are forwarded, the launching push too', () async {
      fcm.initial = pushOf(id: '1');
      final s = make();
      final opened = <PushMessage>[];
      final foreground = <PushMessage>[];
      s.opened.listen(opened.add);
      s.foreground.listen(foreground.add);
      await s.init();
      fcm.messageController.add(pushOf(id: '2'));
      fcm.openedController.add(pushOf(id: '3'));
      await Future<void>.delayed(Duration.zero);
      expect(opened.map((m) => m.data['notification_id']), ['1', '3']);
      expect(foreground.map((m) => m.data['notification_id']), ['2']);
    });
  });

  group('UnreadCubit', () {
    test('loads after sign-in and goes to zero at sign-out', () async {
      final api = FakeNotificationsApi([notif(1), notif(2), notif(3, read: true)]);
      final session = makeSession();
      final cubit = UnreadCubit(api, session);
      expect(cubit.state, 0);
      await session.signIn(testPair());
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, 2);
      await session.signOut();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, 0);
      await cubit.close();
    });

    test('a failed refresh keeps the number; set and increment work', () async {
      final api = FakeNotificationsApi([notif(1)]);
      final session = makeSession();
      await session.signIn(testPair());
      final cubit = UnreadCubit(api, session);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, 1);
      cubit.increment();
      expect(cubit.state, 2);
      cubit.set(7);
      expect(cubit.state, 7);
      cubit.set(-1);
      expect(cubit.state, 0);
      cubit.set(4);
      api.listError = null;
      final failing = _FailingUnread();
      final c2 = UnreadCubit(failing, session);
      await Future<void>.delayed(Duration.zero);
      expect(c2.state, 0); // never became an error
      await cubit.close();
      await c2.close();
    });
  });

  group('PushCoordinator', () {
    late FakePushMessaging fcm;
    late FakeDevicesApi devices;
    late MemoryPushStore store;
    late PushService push;
    late FakeNotificationsApi api;
    late SessionCubit session;
    late UnreadCubit unread;
    late PushCoordinator coordinator;
    late List<NotificationTarget> went;
    late Completer<void> ready;

    Future<void> build({bool signedIn = true, List<AppNotification>? items, bool instantReady = true}) async {
      fcm = FakePushMessaging();
      devices = FakeDevicesApi();
      store = MemoryPushStore();
      push = PushService(devices, messaging: fcm, store: store, platform: 'android');
      api = FakeNotificationsApi(items ?? [notif(123), notif(124)]);
      session = makeSession();
      if (signedIn) await session.signIn(testPair());
      unread = UnreadCubit(api, session);
      went = [];
      ready = Completer<void>();
      coordinator = PushCoordinator(
        push: push,
        session: session,
        api: api,
        unread: unread,
        navigate: went.add,
        whenReady: instantReady ? null : () => ready.future,
      );
      await push.init();
      await Future<void>.delayed(Duration.zero);
    }

    tearDown(() async {
      await coordinator.dispose();
      await unread.close();
      await fcm.close();
    });

    test('a push in the foreground becomes a banner and bumps the badge', () async {
      await build();
      expect(unread.state, 2);
      final banners = <ForegroundPush>[];
      coordinator.banners.listen(banners.add);
      api.all = [notif(125), ...api.all];
      fcm.messageController.add(pushOf(id: '125'));
      await Future<void>.delayed(Duration.zero);
      expect(banners.length, 1);
      expect(banners.single.message.title, 'تم شحن طلبك #45');
      await Future<void>.delayed(Duration.zero);
      expect(unread.state, 3); // confirmed by the backend
      expect(api.calls, contains('unreadCount'));
    });

    test('a push delivered twice (at-least-once) is shown once', () async {
      await build();
      final banners = <ForegroundPush>[];
      coordinator.banners.listen(banners.add);
      fcm.messageController
        ..add(pushOf(id: '125'))
        ..add(pushOf(id: '125'))
        ..add(pushOf(id: '126'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(banners.map((b) => b.link.notificationId), ['125', '126']);
      expect(store.ids[PushSets.shown], ['125', '126']);
    });

    test('a test push (no id) is shown every time and does not touch the badge', () async {
      await build();
      final banners = <ForegroundPush>[];
      coordinator.banners.listen(banners.add);
      final before = unread.state;
      final test = pushOf(id: '', linkType: '', linkValue: '', orderId: '', test: true);
      fcm.messageController
        ..add(test)
        ..add(test);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(banners.length, 2);
      expect(unread.state, before);
    });

    test('nothing is shown when signed out', () async {
      await build(signedIn: false);
      final banners = <ForegroundPush>[];
      coordinator.banners.listen(banners.add);
      fcm.messageController.add(pushOf(id: '125'));
      await Future<void>.delayed(Duration.zero);
      expect(banners, isEmpty);
    });

    test('tapping a push opens its screen, marks it read and updates the badge', () async {
      await build();
      expect(unread.state, 2);
      fcm.openedController.add(pushOf());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(went, [InternalTarget(Routes.orderPath(45))]);
      expect(api.calls, contains('markRead:123'));
      expect(unread.state, 1);
    });

    test('a push tapped twice opens once', () async {
      await build();
      fcm.openedController
        ..add(pushOf())
        ..add(pushOf());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(went.length, 1);
      expect(api.calls.where((c) => c == 'markRead:123').length, 1);
    });

    test('a banner that was shown can still be tapped', () async {
      await build();
      fcm.messageController.add(pushOf(id: '124'));
      await Future<void>.delayed(Duration.zero);
      await coordinator.handleTap(pushOf(id: '124'));
      expect(went.length, 1);
    });

    test('admin and unknown links do nothing: no navigation, not marked read', () async {
      await build();
      for (final t in ['admin_order', 'admin_product', 'mystery']) {
        fcm.openedController.add(pushOf(id: '12$t', linkType: t, linkValue: '1'));
      }
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(went, isEmpty);
      expect(api.calls.where((c) => c.startsWith('markRead')), isEmpty);
    });

    test('a push without a destination opens the inbox; cart reminders open the cart', () async {
      await build();
      await coordinator.handleTap(pushOf(id: '1', type: 'marketing', linkType: 'none', linkValue: '', orderId: ''));
      await coordinator.handleTap(pushOf(id: '2', type: 'cart_reminder', linkType: 'none', linkValue: '', orderId: ''));
      expect(went, [const InternalTarget(Routes.notifications), const InternalTarget(Routes.cart, tab: true)]);
    });

    test('a test push tap is never marked read', () async {
      await build();
      await coordinator.handleTap(pushOf(id: '', linkType: 'none', linkValue: '', orderId: '', test: true));
      expect(api.calls.where((c) => c.startsWith('markRead')), isEmpty);
    });

    test('a signed-out tap still navigates (the router asks for login) but marks nothing', () async {
      await build(signedIn: false);
      await coordinator.handleTap(pushOf());
      expect(went, [InternalTarget(Routes.orderPath(45))]);
      expect(api.calls.where((c) => c.startsWith('markRead')), isEmpty);
    });

    test('a failing mark-read does not break the tap; the badge is refreshed', () async {
      await build();
      api.markError = notifError('NETWORK_ERROR', 0);
      await coordinator.handleTap(pushOf());
      expect(went.length, 1);
      expect(api.calls, contains('unreadCount'));
    });

    test('a tap that launched the app waits until the app is ready', () async {
      await build(instantReady: false);
      // The message that launched the app, as the plugin reports it.
      fcm.openedController.add(pushOf());
      await Future<void>.delayed(Duration.zero);
      expect(went, isEmpty); // session / router not ready yet
      ready.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(went, [InternalTarget(Routes.orderPath(45))]);
    });
  });
}

class _FailingUnread extends FakeNotificationsApi {
  @override
  Future<int> unreadCount() async => throw notifError('NETWORK_ERROR', 0);
}

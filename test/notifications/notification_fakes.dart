import 'dart:async';

import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';
import 'package:lamsa_app/features/notifications/data/notifications_api.dart';
import 'package:lamsa_app/features/notifications/data/push_link.dart';
import 'package:lamsa_app/features/notifications/data/push_messaging.dart';

ApiError notifError(String code, int status, {String? message}) =>
    ApiError(code: code, backendMessage: message, status: status);

/// A fake FCM: no Firebase, no platform channel. Tests push messages through
/// the controllers and read what the app asked for.
class FakePushMessaging implements PushMessaging {
  bool configured = true;
  PushPermission permissionNow = PushPermission.notDetermined;

  /// What the system prompt answers.
  PushPermission answer = PushPermission.granted;
  String? tokenValue = 'fcm-token-1';
  PushMessage? initial;
  int initializeCalls = 0;
  int requestCalls = 0;
  int tokenCalls = 0;

  final refreshController = StreamController<String>.broadcast();
  final messageController = StreamController<PushMessage>.broadcast();
  final openedController = StreamController<PushMessage>.broadcast();

  Future<void> close() async {
    await refreshController.close();
    await messageController.close();
    await openedController.close();
  }

  @override
  Future<bool> initialize() async {
    initializeCalls++;
    return configured;
  }

  @override
  Future<PushPermission> permission() async => permissionNow;

  @override
  Future<PushPermission> requestPermission() async {
    requestCalls++;
    permissionNow = answer;
    return answer;
  }

  @override
  Future<String?> token() async {
    tokenCalls++;
    return tokenValue;
  }

  @override
  Stream<String> get tokenRefresh => refreshController.stream;

  @override
  Stream<PushMessage> get onMessage => messageController.stream;

  @override
  Stream<PushMessage> get onOpened => openedController.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;
}

/// Records the device endpoint calls.
class FakeDevicesApi implements DevicesApi {
  final registered = <({String token, String platform})>[];
  final unregistered = <String>[];
  Object? registerError;
  Object? unregisterError;

  @override
  Future<void> register({required String fcmToken, required String platform}) async {
    if (registerError != null) throw registerError!;
    registered.add((token: fcmToken, platform: platform));
  }

  @override
  Future<void> unregister({required String fcmToken}) async {
    if (unregisterError != null) throw unregisterError!;
    unregistered.add(fcmToken);
  }
}

/// The push data as the backend sends it: all strings.
PushMessage pushOf({
  String id = '123',
  String type = 'order_update',
  String linkType = 'order',
  String linkValue = '45',
  String orderId = '45',
  String title = 'تم شحن طلبك #45',
  String body = 'طلبك في الطريق إليك',
  bool test = false,
}) =>
    PushMessage(
      title: title,
      body: body,
      data: {
        'notification_id': id,
        'type': type,
        'link_type': linkType,
        'link_value': linkValue,
        'order_id': orderId,
        if (test) 'test': '1',
      },
    );

AppNotification notif(
  int id, {
  bool read = false,
  String type = 'order_update',
  String title = 'تم شحن طلبك',
  String body = 'طلبك في الطريق إليك',
  NotificationLink link = const NotificationLink(type: 'order', value: '45'),
  int? orderId = 45,
  DateTime? sentAt,
}) =>
    AppNotification(
      id: id,
      type: type,
      title: '$title #$id',
      body: body,
      sentAt: sentAt ?? DateTime.utc(2026, 11, 17, 9),
      link: link,
      orderId: orderId,
      isRead: read,
    );

/// The inbox and the preferences, with the backend's behaviour.
class FakeNotificationsApi implements NotificationsApi {
  FakeNotificationsApi([List<AppNotification>? items]) : all = items ?? [];

  List<AppNotification> all;
  final calls = <String>[];
  final listPages = <int>[];
  Object? listError;
  Object? markError;
  Object? prefsError;
  Object? updateError;
  var prefs = const NotificationPrefs();
  final updates = <Map<String, bool>>[];

  int get unread => all.where((n) => !n.isRead).length;

  @override
  Future<NotificationPage> list({int page = 1, int pageSize = 20}) async {
    calls.add('list');
    listPages.add(page);
    if (listError != null) throw listError!;
    final from = (page - 1) * pageSize;
    final items = from >= all.length
        ? <AppNotification>[]
        : all.sublist(from, (from + pageSize).clamp(0, all.length));
    return NotificationPage(
      items: items,
      page: page,
      total: all.length,
      unreadCount: unread,
    );
  }

  @override
  Future<int> unreadCount() async {
    calls.add('unreadCount');
    return unread;
  }

  @override
  Future<int> markRead(int id) async {
    calls.add('markRead:$id');
    if (markError != null) throw markError!;
    all = [for (final n in all) n.id == id ? n.asRead() : n];
    return unread;
  }

  @override
  Future<int> markAllRead() async {
    calls.add('markAllRead');
    if (markError != null) throw markError!;
    all = [for (final n in all) n.asRead()];
    return 0;
  }

  @override
  Future<NotificationPrefs> preferences() async {
    calls.add('preferences');
    if (prefsError != null) throw prefsError!;
    return prefs;
  }

  @override
  Future<NotificationPrefs> updatePreferences({
    bool? marketing,
    bool? favorites,
    bool? cartReminders,
  }) async {
    calls.add('updatePreferences');
    updates.add({
      'notify_marketing': ?marketing,
      'notify_favorites': ?favorites,
      'notify_cart_reminders': ?cartReminders,
    });
    if (updateError != null) throw updateError!;
    prefs = prefs.copyWith(
      marketing: marketing,
      favorites: favorites,
      cartReminders: cartReminders,
    );
    return prefs;
  }
}

import 'package:dio/dio.dart';
import 'package:lamsa_app/core/network/api_call.dart';
import 'package:lamsa_app/features/notifications/data/notification_models.dart';

/// The inbox and the preference switches (all need a signed-in user).
class NotificationsApi {
  NotificationsApi(this._dio);

  final Dio _dio;

  /// Newest first. `unread_count` comes with every page.
  Future<NotificationPage> list({int page = 1, int pageSize = 20}) async =>
      NotificationPage.fromJson(
        (await sendJson(
          _dio,
          'GET',
          '/notifications',
          query: {'page': page, 'page_size': pageSize},
        ))
            .map,
      );

  Future<int> unreadCount() async => _count(
        (await sendJson(_dio, 'GET', '/notifications/unread-count')).map,
      );

  /// Idempotent. Returns the unread count after this one is read.
  Future<int> markRead(int id) async =>
      _count((await sendJson(_dio, 'POST', '/notifications/$id/read')).map);

  Future<int> markAllRead() async =>
      _count((await sendJson(_dio, 'POST', '/notifications/read-all')).map);

  Future<NotificationPrefs> preferences() async => NotificationPrefs.fromJson(
        (await sendJson(_dio, 'GET', '/users/me/notification-preferences')).map,
      );

  /// Only the given switches are sent (`notify_marketing`, `notify_favorites`,
  /// `notify_cart_reminders`); returns the saved state.
  Future<NotificationPrefs> updatePreferences({
    bool? marketing,
    bool? favorites,
    bool? cartReminders,
  }) async =>
      NotificationPrefs.fromJson(
        (await sendJson(
          _dio,
          'PATCH',
          '/users/me/notification-preferences',
          data: {
            'notify_marketing': ?marketing,
            'notify_favorites': ?favorites,
            'notify_cart_reminders': ?cartReminders,
          },
        ))
            .map,
      );

  static int _count(Map<String, dynamic> json) =>
      (json['unread_count'] as num?)?.toInt() ?? 0;
}

import 'package:dio/dio.dart';

/// Device registration for push (`/users/me/devices`). The FCM token is the
/// unique key on the backend; there is no separate device id.
class DevicesApi {
  DevicesApi(this._dio);

  final Dio _dio;

  /// [platform] is `android`, `ios` or `web`.
  Future<void> register({
    required String fcmToken,
    required String platform,
  }) =>
      _dio.post<void>(
        '/users/me/devices',
        data: {'fcm_token': fcmToken, 'platform': platform},
      );

  /// Call before logout, while the session is still valid.
  Future<void> unregister({required String fcmToken}) => _dio.post<void>(
        '/users/me/devices/unregister',
        data: {'fcm_token': fcmToken},
      );
}

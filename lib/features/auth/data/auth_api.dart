import 'package:dio/dio.dart';
import 'package:lamsa_app/core/network/api_call.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';

/// Typed client for the backend's `/auth` endpoints and `/users/me`.
///
/// Failures surface as `ApiError` (so the form error mapping and the busy
/// retry see the backend's code, details and `Retry-After`), except
/// [refresh], which the auth interceptor calls and inspects as a raw
/// `DioException`.
class AuthApi {
  AuthApi(this._dio, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  static final _public = Options(extra: {AuthExtra.noAuth: true});

  Future<Map<String, dynamic>> _post(
    String path, {
    Object? data,
    Options? options,
  }) async =>
      (await sendJson(_dio, 'POST', path, data: data, options: options)).map;

  Future<TokenPair> register({
    required String name,
    required String phone,
    required String password,
    String? deviceName,
  }) async =>
      TokenPair.fromJson(
        await _post(
          '/auth/register',
          data: {
            'name': name,
            'phone': phone,
            'password': password,
            'device_name': ?deviceName,
          },
          options: _public,
        ),
      );

  Future<TokenPair> login({
    required String phone,
    required String password,
    String? deviceName,
  }) async =>
      TokenPair.fromJson(
        await _post(
          '/auth/login',
          data: {
            'phone': phone,
            'password': password,
            'device_name': ?deviceName,
          },
          options: _public,
        ),
      );

  Future<GoogleAuthResult> loginWithGoogle({
    required String idToken,
    String? deviceName,
  }) async =>
      GoogleAuthResult.fromJson(
        await _post(
          '/auth/google',
          data: {'id_token': idToken, 'device_name': ?deviceName},
          options: _public,
        ),
      );

  Future<TokenPair> completeGoogleSignup({
    required String signupToken,
    required String name,
    required String phone,
    String? deviceName,
  }) async =>
      TokenPair.fromJson(
        await _post(
          '/auth/google/complete',
          data: {
            'signup_token': signupToken,
            'name': name,
            'phone': phone,
            'device_name': ?deviceName,
          },
          options: _public,
        ),
      );

  /// Rotates the pair. Single-use: the caller must store the result at once.
  Future<StoredTokens> refresh(String refreshToken) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': refreshToken},
      options: _public,
    );
    return TokenPair.fromJson(r.data!).toStored(_now());
  }

  Future<void> logout(String refreshToken) async {
    await _post(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
      options: _public,
    );
  }

  /// Ends every session of the user (all devices).
  Future<void> logoutAll() async {
    await _post('/auth/logout-all');
  }

  /// Replaces the password; the backend ends the other sessions and returns
  /// a fresh pair for this one.
  Future<TokenPair> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async =>
      TokenPair.fromJson(
        await _post(
          '/auth/password/change',
          data: {
            'current_password': currentPassword,
            'new_password': newPassword,
          },
        ),
      );

  Future<AuthUser> me() async =>
      AuthUser.fromJson((await sendJson(_dio, 'GET', '/users/me')).map);

  /// `PATCH /users/me`: only the fields given are sent. A blank [email]
  /// (empty string) clears it.
  Future<AuthUser> updateProfile({String? name, String? email}) async =>
      AuthUser.fromJson(
        (await sendJson(
          _dio,
          'PATCH',
          '/users/me',
          data: {
            'name': ?name,
            if (email != null) 'email': email.isEmpty ? null : email,
          },
        ))
            .map,
      );

  /// `POST /users/me/phone`. Phone accounts must confirm with their current
  /// password; Google accounts have none. No SMS or code, and the other
  /// sessions stay.
  Future<AuthUser> changePhone({
    required String phone,
    String? currentPassword,
  }) async =>
      AuthUser.fromJson(
        await _post(
          '/users/me/phone',
          data: {'phone': phone, 'current_password': ?currentPassword},
        ),
      );
}

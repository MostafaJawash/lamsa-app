import 'package:dio/dio.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';

/// Typed client for the backend's `/auth` endpoints and `/users/me`.
class AuthApi {
  AuthApi(this._dio, {DateTime Function()? now}) : _now = now ?? DateTime.now;

  final Dio _dio;
  final DateTime Function() _now;

  static final _public = Options(extra: {AuthExtra.noAuth: true});

  Future<TokenPair> register({
    required String name,
    required String phone,
    required String password,
    String? deviceName,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {
        'name': name,
        'phone': phone,
        'password': password,
        'device_name': ?deviceName,
      },
      options: _public,
    );
    return TokenPair.fromJson(r.data!);
  }

  Future<TokenPair> login({
    required String phone,
    required String password,
    String? deviceName,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'phone': phone,
        'password': password,
        'device_name': ?deviceName,
      },
      options: _public,
    );
    return TokenPair.fromJson(r.data!);
  }

  Future<GoogleAuthResult> loginWithGoogle({
    required String idToken,
    String? deviceName,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/google',
      data: {'id_token': idToken, 'device_name': ?deviceName},
      options: _public,
    );
    return GoogleAuthResult.fromJson(r.data!);
  }

  Future<TokenPair> completeGoogleSignup({
    required String signupToken,
    required String name,
    required String phone,
    String? deviceName,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/google/complete',
      data: {
        'signup_token': signupToken,
        'name': name,
        'phone': phone,
        'device_name': ?deviceName,
      },
      options: _public,
    );
    return TokenPair.fromJson(r.data!);
  }

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
    await _dio.post<void>(
      '/auth/logout',
      data: {'refresh_token': refreshToken},
      options: _public,
    );
  }

  Future<void> logoutAll() => _dio.post<void>('/auth/logout-all');

  Future<TokenPair> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/password/change',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
    return TokenPair.fromJson(r.data!);
  }

  Future<AuthUser> me() async {
    final r = await _dio.get<Map<String, dynamic>>('/users/me');
    return AuthUser.fromJson(r.data!);
  }
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lamsa_app/core/network/app_env.dart';
import 'package:lamsa_app/core/network/auth_interceptor.dart';
import 'package:lamsa_app/core/network/interceptors.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';

/// Builds the shared [Dio]. Interceptor order matters: auth runs first (it
/// may retry), error mapping runs last so every failure is an `ApiError`.
Dio buildDio({
  required TokenStorage storage,
  required TokenRefresher refresh,
  required Future<void> Function() onSessionExpired,
  String? baseUrl,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl ?? AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      storage: storage,
      refresh: refresh,
      onSessionExpired: onSessionExpired,
    ),
  );
  dio.interceptors.add(ErrorMappingInterceptor());
  if (kDebugMode) dio.interceptors.add(DebugLogInterceptor());
  return dio;
}

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:lamsa_app/core/errors/api_error.dart';

/// Wraps every failure into an [ApiError] on `DioException.error`.
final class ErrorMappingInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is ApiError) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: ApiError.fromDio(err)));
  }
}

/// Debug-only one-line request log. Never prints headers or bodies, which
/// carry tokens and passwords.
final class DebugLogInterceptor extends Interceptor {
  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    final r = response.requestOptions;
    debugPrint('[api] ${r.method} ${r.uri.path} -> ${response.statusCode}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final r = err.requestOptions;
    debugPrint('[api] ${r.method} ${r.uri.path} -> '
        '${err.response?.statusCode ?? err.type.name}');
    handler.next(err);
  }
}

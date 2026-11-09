import 'package:dio/dio.dart';
import 'package:lamsa_app/core/errors/error_messages.dart';

/// One field problem inside a `VALIDATION_ERROR`.
final class ValidationDetail {
  const ValidationDetail({required this.field, required this.message});

  final String field;
  final String message;
}

/// Typed form of the backend's `{error: {code, message, details}}` envelope.
final class ApiError implements Exception {
  const ApiError({
    required this.code,
    required this.backendMessage,
    this.status,
    this.details,
    this.retryAfter,
  });

  /// Parses a response; tolerates bodies that are not the standard envelope.
  factory ApiError.fromResponse(Response<dynamic> response) {
    final status = response.statusCode;
    final retryHeader = response.headers.value('retry-after');
    final retryAfter = _parseRetry(retryHeader);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        final code = error['code'];
        final message = error['message'];
        final details = error['details'];
        return ApiError(
          code: code is String ? code : unknownCode,
          backendMessage: message is String ? message : null,
          status: status,
          details: details,
          retryAfter: retryAfter ?? _retryFromDetails(details),
        );
      }
    }
    return ApiError(
      code: unknownCode,
      backendMessage: null,
      status: status,
      retryAfter: retryAfter,
    );
  }

  factory ApiError.fromDio(DioException e) {
    final response = e.response;
    if (response != null) return ApiError.fromResponse(response);
    final timedOut = e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout;
    return ApiError(
      code: timedOut ? timeoutCode : networkCode,
      backendMessage: null,
    );
  }

  /// Client-side codes for failures that never reached the backend.
  static const networkCode = 'NETWORK_ERROR';
  static const timeoutCode = 'TIMEOUT';
  static const unknownCode = 'UNKNOWN_ERROR';

  final String code;
  final String? backendMessage;
  final int? status;
  final Object? details;
  final Duration? retryAfter;

  /// Backend Arabic message first, then local fallback by code, then generic.
  String get userMessage {
    final backend = backendMessage;
    if (backend != null && backend.trim().isNotEmpty) return backend;
    return ErrorMessages.forCode(code);
  }

  /// Field errors of a `VALIDATION_ERROR`, empty otherwise.
  List<ValidationDetail> get validationDetails {
    final d = details;
    if (d is! List<Object?>) return const [];
    return [
      for (final item in d)
        if (item is Map<String, dynamic>)
          ValidationDetail(
            field: '${item['field'] ?? ''}',
            message: '${item['message'] ?? ''}',
          ),
    ];
  }

  static Duration? _parseRetry(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null ? null : Duration(seconds: seconds);
  }

  static Duration? _retryFromDetails(Object? details) {
    if (details is Map<String, dynamic>) {
      final v = details['retry_after'];
      if (v is num) return Duration(seconds: v.toInt());
    }
    return null;
  }

  @override
  String toString() => 'ApiError($status $code)';
}

/// Maps any thrown object to a user-facing Arabic message.
String messageOf(Object error) {
  if (error is ApiError) return error.userMessage;
  if (error is DioException && error.error is ApiError) {
    return (error.error! as ApiError).userMessage;
  }
  return ErrorMessages.forCode(ApiError.unknownCode);
}

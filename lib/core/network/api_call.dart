import 'package:dio/dio.dart';
import 'package:lamsa_app/core/errors/api_error.dart';

/// A response whose status the caller may need (e.g. `201` created versus
/// `200` replayed for an idempotent POST).
final class ApiResponse {
  const ApiResponse(this.status, this.data);

  final int status;

  /// The JSON body: a map, a list, or null (`204`).
  final Object? data;

  Map<String, dynamic> get map =>
      data is Map<String, dynamic> ? data! as Map<String, dynamic> : const {};
}

/// Sends a request and returns its status and body. Every failure surfaces as
/// an [ApiError] (never a raw `DioException`), like the other API classes.
Future<ApiResponse> sendJson(
  Dio dio,
  String method,
  String path, {
  Object? data,
  Map<String, Object?>? query,
  Map<String, Object?>? headers,
  Options? options,
}) async {
  try {
    final base = options ?? Options();
    final r = await dio.request<Object?>(
      path,
      data: data,
      queryParameters: query,
      options: base.copyWith(
        method: method,
        headers: {...?base.headers, ...?headers},
      ),
    );
    return ApiResponse(r.statusCode ?? 200, r.data);
  } on DioException catch (e) {
    final error = e.error;
    throw error is ApiError ? error : ApiError.fromDio(e);
  }
}

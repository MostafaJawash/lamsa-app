import 'package:dio/dio.dart';

/// Public catalog endpoints. Only the connectivity probe exists so far.
class CatalogApi {
  CatalogApi(this._dio);

  final Dio _dio;

  /// Proves networking/DI end to end by hitting a public endpoint
  /// (`GET /api/v1/categories`). Throws on any failure.
  Future<void> ping() async {
    await _dio.get<Object?>('/categories');
  }
}

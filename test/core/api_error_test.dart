import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/errors/error_messages.dart';

Response<dynamic> _resp(
  int status,
  Object? data, [
  Map<String, List<String>>? headers,
]) =>
    Response<dynamic>(
      requestOptions: RequestOptions(),
      statusCode: status,
      data: data,
      headers: Headers.fromMap(headers ?? {}),
    );

void main() {
  test('parses the backend envelope', () {
    final e = ApiError.fromResponse(
      _resp(409, {
        'error': {'code': 'PHONE_TAKEN', 'message': 'مستخدم', 'details': null},
      }),
    );
    expect(e.code, 'PHONE_TAKEN');
    expect(e.status, 409);
    expect(e.userMessage, 'مستخدم');
  });

  test('falls back to the local Arabic map when message is empty', () {
    final e = ApiError.fromResponse(
      _resp(401, {
        'error': {'code': 'TOKEN_EXPIRED', 'message': '', 'details': null},
      }),
    );
    expect(e.userMessage, ErrorMessages.forCode('TOKEN_EXPIRED'));
  });

  test('unknown code and non-envelope bodies use the generic message', () {
    expect(
      ApiError.fromResponse(_resp(500, 'oops')).userMessage,
      ErrorMessages.generic,
    );
    expect(ErrorMessages.forCode('NOPE'), ErrorMessages.generic);
  });

  test('reads validation details and retry-after', () {
    final e = ApiError.fromResponse(
      _resp(
        422,
        {
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'm',
            'details': [
              {'field': 'phone', 'message': 'bad'},
            ],
          },
        },
        {
          'retry-after': ['30'],
        },
      ),
    );
    expect(e.validationDetails.single.field, 'phone');
    expect(e.retryAfter, const Duration(seconds: 30));
  });

  test('network and timeout failures get client codes', () {
    final net = ApiError.fromDio(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      ),
    );
    final timeout = ApiError.fromDio(
      DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.receiveTimeout,
      ),
    );
    expect(net.code, ApiError.networkCode);
    expect(timeout.code, ApiError.timeoutCode);
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/network/api_client.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';

class _MemoryStorage implements TokenStorage {
  StoredTokens? tokens;

  @override
  Future<StoredTokens?> read() async => tokens;

  @override
  Future<void> write(StoredTokens t) async => tokens = t;

  @override
  Future<void> clear() async => tokens = null;
}

/// Server stub: bearer `old` is always rejected as expired, `new` is fine.
class _FakeServer implements HttpClientAdapter {
  final seenAuth = <String?>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    seenAuth.add(auth);
    if (auth == 'Bearer new') return _json(200, {'ok': true});
    return _json(401, {
      'error': {'code': 'TOKEN_EXPIRED', 'message': 'm', 'details': null},
    });
  }

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

StoredTokens _tokens(String access, String refresh) => StoredTokens(
      accessToken: access,
      refreshToken: refresh,
      accessExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );

void main() {
  late _MemoryStorage storage;
  late _FakeServer server;
  late int refreshCalls;
  late int expiredCalls;

  Dio makeDio(Future<StoredTokens> Function(String) refresh) {
    final dio = buildDio(
      storage: storage,
      baseUrl: 'http://test',
      refresh: (t) {
        refreshCalls++;
        return refresh(t);
      },
      onSessionExpired: () async => expiredCalls++,
    );
    dio.httpClientAdapter = server;
    return dio;
  }

  setUp(() {
    storage = _MemoryStorage()..tokens = _tokens('old', 'r1');
    server = _FakeServer();
    refreshCalls = 0;
    expiredCalls = 0;
  });

  test('concurrent 401s share exactly one refresh call (single-flight)',
      () async {
    final dio = makeDio((t) async {
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(t, 'r1');
      return _tokens('new', 'r2');
    });

    final results = await Future.wait([
      dio.get<Object?>('/a'),
      dio.get<Object?>('/b'),
      dio.get<Object?>('/c'),
    ]);

    expect(results.map((r) => r.statusCode), [200, 200, 200]);
    expect(refreshCalls, 1);
    expect(storage.tokens?.refreshToken, 'r2');
    expect(expiredCalls, 0);
  });

  test('unrecoverable refresh failure clears storage and ends the session',
      () async {
    final dio = makeDio((t) async {
      throw DioException(
        requestOptions: RequestOptions(),
        response: Response<dynamic>(
          requestOptions: RequestOptions(),
          statusCode: 401,
        ),
      );
    });

    await expectLater(
      dio.get<Object?>('/a'),
      throwsA(
        isA<DioException>().having(
          (e) => (e.error as ApiError?)?.code,
          'code',
          'TOKEN_EXPIRED',
        ),
      ),
    );
    expect(storage.tokens, isNull);
    expect(expiredCalls, 1);
  });

  test('transient refresh failure keeps the stored session', () async {
    final dio = makeDio((t) async {
      throw DioException(
        requestOptions: RequestOptions(),
        type: DioExceptionType.connectionError,
      );
    });

    await expectLater(dio.get<Object?>('/a'), throwsA(isA<DioException>()));
    expect(storage.tokens?.refreshToken, 'r1');
    expect(expiredCalls, 0);
  });

  test('a token near expiry is refreshed before the request is sent',
      () async {
    storage.tokens = StoredTokens(
      accessToken: 'old',
      refreshToken: 'r1',
      accessExpiresAt: DateTime.now().add(const Duration(seconds: 10)),
    );
    final dio = makeDio((t) async => _tokens('new', 'r2'));

    final r = await dio.get<Object?>('/a');

    expect(r.statusCode, 200);
    expect(server.seenAuth, ['Bearer new']);
    expect(refreshCalls, 1);
  });
}

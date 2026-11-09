import 'package:dio/dio.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';

/// Calls `POST /auth/refresh` and returns the rotated pair (not yet stored).
typedef TokenRefresher = Future<StoredTokens> Function(String refreshToken);

/// Request-option flags understood by [AuthInterceptor].
abstract final class AuthExtra {
  /// Send the request without a bearer token and never refresh on 401.
  static const noAuth = 'lamsa.noAuth';
  static const retried = 'lamsa.retried';
}

/// Attaches the bearer token and silently refreshes it.
///
/// Refresh tokens are single-use and reuse kills the whole session, so every
/// concurrent refresh need shares ONE in-flight call ([_inflight]).
final class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.storage,
    required this.refresh,
    required this.onSessionExpired,
    this.refreshMargin = const Duration(seconds: 60),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final Dio dio;
  final TokenStorage storage;
  final TokenRefresher refresh;
  final Future<void> Function() onSessionExpired;
  final Duration refreshMargin;
  final DateTime Function() _now;

  Future<StoredTokens?>? _inflight;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra[AuthExtra.noAuth] == true) {
      handler.next(options);
      return;
    }
    try {
      final tokens = await storage.read();
      if (tokens != null) {
        var access = tokens.accessToken;
        if (tokens.accessExpiresAt.isBefore(_now().add(refreshMargin))) {
          final fresh = await _refresh();
          access = fresh?.accessToken ?? '';
        }
        if (access.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $access';
        }
      }
      handler.next(options);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    if (response?.statusCode != 401 ||
        options.extra[AuthExtra.noAuth] == true ||
        options.extra[AuthExtra.retried] == true) {
      handler.next(err);
      return;
    }

    final sentHeader = options.headers['Authorization'];
    final code = ApiError.fromResponse(response!).code;

    if (code == 'TOKEN_EXPIRED') {
      final sent = sentHeader is String ? sentHeader.replaceFirst('Bearer ', '') : null;
      final stored = await storage.read();
      if (stored == null) {
        handler.next(err);
        return;
      }
      try {
        // Another request may already have rotated the token meanwhile.
        final fresh =
            stored.accessToken != sent ? stored : await _refresh();
        if (fresh == null) {
          handler.next(err);
          return;
        }
        options.extra[AuthExtra.retried] = true;
        options.headers['Authorization'] = 'Bearer ${fresh.accessToken}';
        handler.resolve(await dio.fetch<dynamic>(options));
      } on DioException catch (e) {
        handler.next(e);
      }
      return;
    }

    if ((code == 'TOKEN_REUSED' || code == 'TOKEN_INVALID') &&
        sentHeader != null) {
      await _endSession();
    }
    handler.next(err);
  }

  /// Single-flight: concurrent callers await the same future. Resolves to
  /// `null` when the session was ended; throws on transient failures (the
  /// stored tokens are kept so a later attempt can still succeed).
  Future<StoredTokens?> _refresh() {
    return _inflight ??= _doRefresh().whenComplete(() => _inflight = null);
  }

  Future<StoredTokens?> _doRefresh() async {
    final current = await storage.read();
    if (current == null) return null;
    try {
      final fresh = await refresh(current.refreshToken);
      // Persist before anyone else can use the old (now spent) token.
      await storage.write(fresh);
      return fresh;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final unrecoverable = status != null &&
          status >= 400 &&
          status < 500 &&
          status != 408 &&
          status != 429;
      if (unrecoverable) {
        await _endSession();
        return null;
      }
      rethrow;
    }
  }

  Future<void> _endSession() async {
    await storage.clear();
    await onSessionExpired();
  }
}

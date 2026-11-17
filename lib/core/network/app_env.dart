import 'dart:io' show Platform;

/// Compile-time config, supplied with `--dart-define-from-file=env/dev.json`.
abstract final class AppEnv {
  /// Server origin without `/api/v1`, e.g. `http://127.0.0.1:8000`.
  static const _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Web OAuth client ID, passed as `serverClientId` so the ID token is
  /// accepted by the backend's `GOOGLE_CLIENT_IDS`. Empty until created.
  static const googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  /// Store contact shown in "forgot password" (no self-service reset).
  /// Empty hides the matching button.
  static const supportPhone = String.fromEnvironment('SUPPORT_PHONE');
  static const supportWhatsapp = String.fromEnvironment('SUPPORT_WHATSAPP');

  static const apiPrefix = '/api/v1';

  /// Default per dev scenario: the Android emulator reaches the host
  /// machine at 10.0.2.2, everything else at 127.0.0.1.
  static String get origin {
    if (_apiBaseUrl.isNotEmpty) {
      return _apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    return Platform.isAndroid
        ? 'http://10.0.2.2:8000'
        : 'http://127.0.0.1:8000';
  }

  static String get apiBaseUrl => '$origin$apiPrefix';

  static String get healthUrl => '$origin/health';

  static bool get googleSignInConfigured => googleServerClientId.isNotEmpty;

  /// The dev backend may emit media URLs on `localhost`/`127.0.0.1` (and its
  /// own port), which an Android emulator or a phone cannot reach, or which
  /// belong to another server on this machine; point them at the configured
  /// origin (host AND port). [origin] is only for tests.
  static String resolveMediaUrl(String url, {String? origin}) {
    final uri = Uri.tryParse(url);
    final base = Uri.parse(origin ?? AppEnv.origin);
    if (uri == null || !uri.hasAuthority) return url;
    const loopback = {'localhost', '127.0.0.1'};
    if (loopback.contains(uri.host) &&
        (uri.host != base.host || uri.port != base.port)) {
      return uri.replace(host: base.host, port: base.port).toString();
    }
    return url;
  }
}

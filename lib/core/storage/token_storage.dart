import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The access/refresh pair plus when the access token expires.
final class StoredTokens {
  const StoredTokens({
    required this.accessToken,
    required this.refreshToken,
    required this.accessExpiresAt,
  });

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;
}

/// Tokens live only in OS-backed secure storage (Keychain / Keystore).
abstract interface class TokenStorage {
  Future<StoredTokens?> read();
  Future<void> write(StoredTokens tokens);
  Future<void> clear();
}

final class SecureTokenStorage implements TokenStorage {
  SecureTokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _accessKey = 'lamsa.access_token';
  static const _refreshKey = 'lamsa.refresh_token';
  static const _expiryKey = 'lamsa.access_expires_at';

  final FlutterSecureStorage _storage;

  @override
  Future<StoredTokens?> read() async {
    final access = await _storage.read(key: _accessKey);
    final refresh = await _storage.read(key: _refreshKey);
    final expiry = await _storage.read(key: _expiryKey);
    if (access == null || refresh == null) return null;
    final expiresAt = DateTime.tryParse(expiry ?? '');
    return StoredTokens(
      accessToken: access,
      refreshToken: refresh,
      // Unknown expiry is treated as already expired, forcing a refresh.
      accessExpiresAt: expiresAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  @override
  Future<void> write(StoredTokens tokens) async {
    await _storage.write(key: _accessKey, value: tokens.accessToken);
    await _storage.write(key: _refreshKey, value: tokens.refreshToken);
    await _storage.write(
      key: _expiryKey,
      value: tokens.accessExpiresAt.toUtc().toIso8601String(),
    );
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _expiryKey);
  }
}

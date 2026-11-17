import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lamsa_app/core/network/app_env.dart';
import 'package:lamsa_app/core/strings.dart';

/// Which Google sign-in the auth screens offer.
enum GoogleAuthKind {
  /// Native Google account picker (needs `GOOGLE_SERVER_CLIENT_ID`).
  real,

  /// Development only: a fake token the backend accepts when it runs with
  /// `GOOGLE_DEV_MODE=true`. See [DevGoogleAuthService].
  dev,

  /// No Google button at all (release build without OAuth client IDs).
  none,
}

/// Source of the ID token for `POST /auth/google`.
abstract interface class GoogleAuthService {
  GoogleAuthKind get kind;

  bool get isConfigured;

  /// Returns the Google ID token, or null if the user cancelled.
  Future<String?> signIn();

  Future<void> signOut();
}

/// Picks the service like lamsa-web's `googleMode()`: real when a client ID
/// is configured, the dev fake in non-release builds without one, nothing in
/// a release build without one.
GoogleAuthService createGoogleAuthService() {
  if (AppEnv.googleSignInConfigured) return GoogleSignInAuthService();
  if (!kReleaseMode) return DevGoogleAuthService();
  return const DisabledGoogleAuthService();
}

/// Native Google sign-in that yields an ID token for `POST /auth/google`.
///
/// Drop-in once OAuth clients exist: set `GOOGLE_SERVER_CLIENT_ID` (the web
/// client ID, which the backend lists in `GOOGLE_CLIENT_IDS`) in env/*.json.
final class GoogleSignInAuthService implements GoogleAuthService {
  bool _initialized = false;

  @override
  GoogleAuthKind get kind => GoogleAuthKind.real;

  @override
  bool get isConfigured => AppEnv.googleSignInConfigured;

  Future<void> _init() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: AppEnv.googleServerClientId,
    );
    _initialized = true;
  }

  @override
  Future<String?> signIn() async {
    if (!isConfigured) return null;
    await _init();
    try {
      final account = await GoogleSignIn.instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (!_initialized) return;
    await GoogleSignIn.instance.signOut();
  }
}

/// Keeps the random dev "subject" between launches.
abstract interface class DevSubStore {
  Future<String?> read();
  Future<void> write(String sub);
}

final class SecureDevSubStore implements DevSubStore {
  SecureDevSubStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'lamsa.dev_google_sub';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String sub) => _storage.write(key: _key, value: sub);
}

/// DEV-ONLY SCAFFOLDING. Do not ship as the real flow.
///
/// There are no OAuth client IDs yet, so this builds the token the backend
/// accepts with `GOOGLE_DEV_MODE=true` (development only):
/// `dev-google|<sub>|<email>|<name>`. The random `sub` is created once and
/// kept, so every tap is the same fake user, like lamsa-web's dev button.
///
/// It disappears by itself once `GOOGLE_SERVER_CLIENT_ID` is set (then
/// [createGoogleAuthService] returns the real service) and is never selected
/// in release builds.
final class DevGoogleAuthService implements GoogleAuthService {
  DevGoogleAuthService({DevSubStore? store, Random? random})
    : _store = store ?? SecureDevSubStore(),
      _random = random ?? Random.secure();

  final DevSubStore _store;
  final Random _random;

  @override
  GoogleAuthKind get kind => GoogleAuthKind.dev;

  @override
  bool get isConfigured => true;

  @override
  Future<String?> signIn() async {
    var sub = await _store.read();
    if (sub == null || !RegExp(r'^[a-f0-9]{16}$').hasMatch(sub)) {
      sub = [
        for (var i = 0; i < 8; i++)
          _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ].join();
      await _store.write(sub);
    }
    return 'dev-google|$sub|dev-$sub@example.test|${Strings.googleDevName}';
  }

  @override
  Future<void> signOut() async {}
}

final class DisabledGoogleAuthService implements GoogleAuthService {
  const DisabledGoogleAuthService();

  @override
  GoogleAuthKind get kind => GoogleAuthKind.none;

  @override
  bool get isConfigured => false;

  @override
  Future<String?> signIn() async => null;

  @override
  Future<void> signOut() async {}
}

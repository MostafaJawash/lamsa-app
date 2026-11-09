import 'package:google_sign_in/google_sign_in.dart';
import 'package:lamsa_app/core/network/app_env.dart';

/// Native Google sign-in that yields an ID token for `POST /auth/google`.
///
/// Drop-in once OAuth clients exist: set `GOOGLE_SERVER_CLIENT_ID` (the web
/// client ID, which the backend lists in `GOOGLE_CLIENT_IDS`) in env/*.json.
abstract interface class GoogleAuthService {
  bool get isConfigured;

  /// Returns the Google ID token, or null if the user cancelled.
  Future<String?> signIn();

  Future<void> signOut();
}

final class GoogleSignInAuthService implements GoogleAuthService {
  bool _initialized = false;

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

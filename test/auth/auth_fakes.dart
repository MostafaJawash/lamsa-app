import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/storage/token_storage.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/auth/data/guest_data_merger.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/data/models/token_pair.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/notifications/data/devices_api.dart';
import 'package:lamsa_app/features/notifications/data/push_service.dart';
import 'package:mocktail/mocktail.dart';

import '../catalog/catalog_fakes.dart';

AuthUser testUser({
  bool mustChange = false,
  String provider = 'phone',
  String name = 'ليلى',
  String phone = '+963933123456',
  String? email,
}) => AuthUser(
  id: 1,
  name: name,
  phone: phone,
  email: email,
  role: 'customer',
  authProvider: provider,
  mustChangePassword: mustChange,
);

TokenPair testPair({
  AuthUser? user,
  String access = 'access-1',
  String refresh = 'refresh-1',
}) => TokenPair(
  accessToken: access,
  refreshToken: refresh,
  tokenType: 'bearer',
  expiresIn: 900,
  refreshExpiresIn: 5184000,
  user: user ?? testUser(),
);

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.tokens]);

  StoredTokens? tokens;

  @override
  Future<StoredTokens?> read() async => tokens;

  @override
  Future<void> write(StoredTokens t) async => tokens = t;

  @override
  Future<void> clear() async => tokens = null;
}

StoredTokens storedTokens() => StoredTokens(
  accessToken: 'a',
  refreshToken: 'r',
  accessExpiresAt: DateTime.now().add(const Duration(minutes: 10)),
);

/// Hand-written fake of the auth API: serves configured answers, records calls.
class FakeAuthApi implements AuthApi {
  final calls = <String>[];
  final bodies = <String, Map<String, Object?>>{};

  Future<TokenPair> Function()? onLogin;
  Future<TokenPair> Function()? onRegister;
  Future<GoogleAuthResult> Function()? onGoogle;
  Future<TokenPair> Function()? onComplete;
  Future<TokenPair> Function()? onChange;
  Future<AuthUser> Function()? onMe;

  void _log(String name, Map<String, Object?> body) {
    calls.add(name);
    bodies[name] = body;
  }

  int count(String name) => calls.where((c) => c == name).length;

  @override
  Future<TokenPair> login({
    required String phone,
    required String password,
    String? deviceName,
  }) async {
    _log('login', {'phone': phone, 'password': password});
    return (onLogin ?? () async => testPair())();
  }

  @override
  Future<TokenPair> register({
    required String name,
    required String phone,
    required String password,
    String? deviceName,
  }) async {
    _log('register', {'name': name, 'phone': phone, 'password': password});
    return (onRegister ?? () async => testPair())();
  }

  @override
  Future<GoogleAuthResult> loginWithGoogle({
    required String idToken,
    String? deviceName,
  }) async {
    _log('google', {'id_token': idToken});
    return (onGoogle ?? () async => GoogleRegistered(testPair()))();
  }

  @override
  Future<TokenPair> completeGoogleSignup({
    required String signupToken,
    required String name,
    required String phone,
    String? deviceName,
  }) async {
    _log('complete', {
      'signup_token': signupToken,
      'name': name,
      'phone': phone,
    });
    return (onComplete ?? () async => testPair())();
  }

  @override
  Future<TokenPair> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _log('change', {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
    return (onChange ?? () async => testPair())();
  }

  @override
  Future<AuthUser> me() async {
    calls.add('me');
    return (onMe ?? () async => testUser())();
  }

  @override
  Future<StoredTokens> refresh(String refreshToken) async => storedTokens();

  @override
  Future<void> logout(String refreshToken) async {
    _log('logout', {'refresh_token': refreshToken});
  }

  @override
  Future<void> logoutAll() async => calls.add('logoutAll');
}

class _MockDevicesApi extends Mock implements DevicesApi {}

class RecordingMerger implements GuestDataMerger {
  int merges = 0;

  @override
  Future<void> merge() async => merges++;
}

class FakeGoogle implements GoogleAuthService {
  FakeGoogle({this.kind = GoogleAuthKind.dev, this.token = 'dev-google|x|e|n'});

  @override
  final GoogleAuthKind kind;
  String? token;
  int signOuts = 0;
  Object? error;

  @override
  bool get isConfigured => kind != GoogleAuthKind.none;

  @override
  Future<String?> signIn() async {
    if (error != null) throw error!;
    return token;
  }

  @override
  Future<void> signOut() async => signOuts++;
}

SessionCubit makeSession({
  FakeAuthApi? api,
  TokenStorage? storage,
  GuestDataMerger? merger,
  Future<void> Function()? onSignedOut,
}) => SessionCubit(
  api: api ?? FakeAuthApi(),
  storage: storage ?? MemoryTokenStorage(),
  push: PushService(_MockDevicesApi()),
  merger: merger ?? const NoopGuestDataMerger(),
  onSignedOut: onSignedOut,
);

/// Whole-app wiring with fakes, for router-level tests.
AppDependencies makeDeps({
  required SessionCubit session,
  required FakeAuthApi api,
  FakeCatalogApi? catalogApi,
  GoogleAuthService? google,
}) => AppDependencies(
  session: session,
  authApi: api,
  catalog: CatalogRepository(catalogApi ?? FakeCatalogApi()),
  devicesApi: _MockDevicesApi(),
  push: PushService(_MockDevicesApi()),
  google: google ?? FakeGoogle(),
);

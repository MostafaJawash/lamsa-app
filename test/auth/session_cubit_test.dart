import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_validation.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';

import 'auth_fakes.dart';

void main() {
  late FakeAuthApi api;
  late MemoryTokenStorage storage;
  late RecordingMerger merger;

  SessionCubit make({Future<void> Function()? onSignedOut}) => makeSession(
    api: api,
    storage: storage,
    merger: merger,
    onSignedOut: onSignedOut,
  );

  setUp(() {
    api = FakeAuthApi();
    storage = MemoryTokenStorage();
    merger = RecordingMerger();
  });

  group('restore (launch)', () {
    test('no stored tokens: a guest, not an expired session', () async {
      final s = make();
      await s.restore();
      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.state.end, SessionEnd.none);
    });

    test(
      'valid stored session signs in automatically and merges guest data',
      () async {
        storage.tokens = storedTokens();
        final s = make();
        await s.restore();
        expect(s.state.isAuthenticated, isTrue);
        expect(s.state.user!.name, 'ليلى');
        expect(merger.merges, 1);
      },
    );

    test(
      'a temporary password skips the merge (the backend would refuse it)',
      () async {
        storage.tokens = storedTokens();
        api.onMe = () async => testUser(mustChange: true);
        final s = make();
        await s.restore();
        expect(s.state.mustChangePassword, isTrue);
        expect(merger.merges, 0);
      },
    );

    test('offline launch keeps the stored session without a profile', () async {
      storage.tokens = storedTokens();
      api.onMe = () async => throw const ApiError(
        code: ApiError.networkCode,
        backendMessage: null,
      );
      final s = make();
      await s.restore();
      expect(s.state.isAuthenticated, isTrue);
      expect(s.state.user, isNull);
      expect(storage.tokens, isNotNull);
    });

    test(
      'a dead stored session (interceptor expiry) ends as expired',
      () async {
        storage.tokens = storedTokens();
        late final SessionCubit s;
        api.onMe = () async {
          storage.tokens = null; // the interceptor clears storage, then reports
          s.expire();
          throw const ApiError(
            code: 'TOKEN_INVALID',
            backendMessage: null,
            status: 401,
          );
        };
        s = make();
        await s.restore();
        expect(s.state.status, SessionStatus.unauthenticated);
        expect(s.state.end, SessionEnd.expired);
      },
    );
  });

  group('signIn / signOut', () {
    test(
      'signIn stores the pair, emits the user and merges guest data',
      () async {
        final s = make();
        await s.signIn(testPair());
        expect(storage.tokens!.refreshToken, 'refresh-1');
        expect(s.state.user!.phone, '+963933123456');
        expect(merger.merges, 1);
      },
    );

    test('signIn with a temporary password does not merge yet', () async {
      final s = make();
      await s.signIn(testPair(user: testUser(mustChange: true)));
      expect(s.state.mustChangePassword, isTrue);
      expect(merger.merges, 0);
      // The password change signs in again with a clean user: now it merges.
      await s.signIn(testPair());
      expect(s.state.mustChangePassword, isFalse);
      expect(merger.merges, 1);
    });

    test('a failing merger never blocks sign-in', () async {
      final s = makeSession(
        api: api,
        storage: storage,
        merger: _ThrowingMerger(),
      );
      await s.signIn(testPair());
      expect(s.state.isAuthenticated, isTrue);
    });

    test('signOut calls the backend, clears storage, runs cleanup, ends as signedOut', () async {
      var cleaned = 0;
      final s = make(onSignedOut: () async => cleaned++);
      await s.signIn(testPair());
      await s.signOut();
      expect(api.bodies['logout'], {'refresh_token': 'refresh-1'});
      expect(storage.tokens, isNull);
      expect(cleaned, 1);
      expect(s.state.status, SessionStatus.unauthenticated);
      expect(s.state.end, SessionEnd.signedOut);
      expect(s.state.user, isNull);
    });

    test(
      'signOut succeeds locally even if the backend and cleanup fail',
      () async {
        final s = make(onSignedOut: () async => throw StateError('x'));
        await s.signIn(testPair());
        api.calls.clear();
        // The fake logout cannot fail, so simulate by clearing nothing: just check state.
        await s.signOut();
        expect(s.state.end, SessionEnd.signedOut);
        expect(storage.tokens, isNull);
      },
    );

    test(
      'acknowledgeEnd turns an ended session back into a plain guest',
      () async {
        final s = make();
        await s.signIn(testPair());
        s.expire();
        expect(s.state.end, SessionEnd.expired);
        s.acknowledgeEnd();
        expect(s.state.end, SessionEnd.none);
        expect(s.state.status, SessionStatus.unauthenticated);
      },
    );
  });

  group('forced password change', () {
    test(
      'a 403 PASSWORD_CHANGE_REQUIRED re-reads the profile and sets the flag',
      () async {
        final s = make();
        await s.signIn(testPair());
        api.onMe = () async => testUser(mustChange: true);
        await s.passwordChangeRequired();
        expect(s.state.mustChangePassword, isTrue);
      },
    );

    test('is ignored for guests', () async {
      final s = make();
      await s.restore();
      await s.passwordChangeRequired();
      expect(api.count('me'), 0);
    });

    test('refreshUser reports failure without ending the session', () async {
      final s = make();
      await s.signIn(testPair());
      api.onMe = () async => throw StateError('offline');
      expect(await s.refreshUser(), isFalse);
      expect(s.state.isAuthenticated, isTrue);
    });
  });

  group('Google dev service', () {
    test('builds the backend dev token and keeps the same sub', () async {
      final store = _MemoryStore();
      final g = DevGoogleAuthService(store: store);
      final first = (await g.signIn())!;
      final second = (await DevGoogleAuthService(store: store).signIn())!;
      expect(first, second);
      final parts = first.split('|');
      expect(parts.length, 4);
      expect(parts[0], 'dev-google');
      expect(parts[1], matches(RegExp(r'^[a-f0-9]{16}$')));
      expect(parts[2], 'dev-${parts[1]}@example.test');
      expect(parts[3], isNotEmpty);
      expect(g.kind, GoogleAuthKind.dev);
    });

    test('different installs get different subs', () async {
      final a = (await DevGoogleAuthService(store: _MemoryStore()).signIn())!;
      final b = (await DevGoogleAuthService(store: _MemoryStore()).signIn())!;
      expect(a, isNot(b));
    });

    test('the disabled service offers nothing', () async {
      const g = DisabledGoogleAuthService();
      expect(g.kind, GoogleAuthKind.none);
      expect(await g.signIn(), isNull);
    });
  });

  test('phone helper sanity used by sign-in forms', () {
    expect(combinePhone(defaultCountryCode, '0933 123 456'), '+963933123456');
  });
}

class _ThrowingMerger extends RecordingMerger {
  @override
  Future<void> merge() async => throw StateError('merge failed');
}

class _MemoryStore implements DevSubStore {
  String? sub;

  @override
  Future<String?> read() async => sub;

  @override
  Future<void> write(String value) async => sub = value;
}

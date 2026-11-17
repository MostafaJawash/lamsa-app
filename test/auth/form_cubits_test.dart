import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/auth_form_cubits.dart';
import 'package:lamsa_app/features/auth/data/auth_errors.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';

import 'auth_fakes.dart';

ApiError api(
  String code, {
  int status = 400,
  Duration? retryAfter,
  Object? details,
}) => ApiError(
  code: code,
  backendMessage: 'خادم: $code',
  status: status,
  retryAfter: retryAfter,
  details: details,
);

void main() {
  late FakeAuthApi fake;
  late MemoryTokenStorage storage;
  late RecordingMerger merger;

  setUp(() {
    fake = FakeAuthApi();
    storage = MemoryTokenStorage();
    merger = RecordingMerger();
  });

  LoginCubit login() {
    final session = makeSession(api: fake, storage: storage, merger: merger);
    final c = LoginCubit(fake, session, delay: (_) async {});
    addTearDown(c.close);
    addTearDown(session.close);
    return c;
  }

  group('login', () {
    test('validates before calling the backend', () async {
      final c = login();
      await c.submit(countryCode: '+963', phone: '', password: '');
      expect(fake.calls, isEmpty);
      expect(c.state.fieldErrors[AuthField.phone], Strings.errPhoneRequired);
      expect(
        c.state.fieldErrors[AuthField.password],
        Strings.errPasswordRequired,
      );
    });

    test('sends the combined E.164 phone and signs the session in', () async {
      final c = login();
      await c.submit(
        countryCode: '+963',
        phone: '0933 123 456',
        password: 'secret123',
      );
      expect(fake.bodies['login'], {
        'phone': '+963933123456',
        'password': 'secret123',
      });
      expect(c.state.done, isTrue);
      expect(c.session.state.isAuthenticated, isTrue);
      expect(storage.tokens, isNotNull);
      expect(merger.merges, 1);
    });

    test('INVALID_CREDENTIALS shows the backend message on the form', () async {
      fake.onLogin = () async => throw api('INVALID_CREDENTIALS', status: 401);
      final c = login();
      await c.submit(
        countryCode: '+963',
        phone: '0933123456',
        password: 'wrong-pass',
      );
      expect(c.state.formError!.message, 'خادم: INVALID_CREDENTIALS');
      expect(c.state.submitting, isFalse);
      expect(c.state.done, isFalse);
      expect(c.session.state.isAuthenticated, isFalse);
    });

    test('editing a field clears its error', () async {
      final c = login();
      await c.submit(countryCode: '+963', phone: '', password: 'x');
      expect(c.state.fieldErrors, contains(AuthField.phone));
      c.clearField(AuthField.phone);
      expect(c.state.fieldErrors, isNot(contains(AuthField.phone)));
    });

    test('SERVICE_BUSY is retried once transparently', () async {
      var n = 0;
      fake.onLogin = () async {
        if (n++ == 0) {
          throw api(
            'SERVICE_BUSY',
            status: 503,
            retryAfter: const Duration(seconds: 1),
          );
        }
        return testPair();
      };
      final c = login();
      await c.submit(
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(fake.count('login'), 2);
      expect(c.state.done, isTrue);
    });

    testWidgets('too many attempts locks the form and counts down', (
      tester,
    ) async {
      fake.onLogin = () async => throw api(
        'TOO_MANY_ATTEMPTS',
        status: 429,
        retryAfter: const Duration(seconds: 3),
      );
      final c = login();
      await c.submit(
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(c.state.formError!.kind, FormErrorKind.rateLimited);
      expect(c.state.lockSeconds, 3);
      expect(c.state.locked, isTrue);

      // Submit does nothing while locked.
      await c.submit(
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(fake.count('login'), 1);

      await tester.pump(const Duration(seconds: 2));
      expect(c.state.lockSeconds, 1);
      await tester.pump(const Duration(seconds: 1));
      expect(c.state.lockSeconds, 0);
      expect(c.state.locked, isFalse);
      expect(c.state.formError, isNull);
    });
  });

  group('register', () {
    RegisterCubit register() {
      final session = makeSession(api: fake, storage: storage, merger: merger);
      final c = RegisterCubit(fake, session, delay: (_) async {});
      addTearDown(c.close);
      addTearDown(session.close);
      return c;
    }

    test('applies the backend password rules client-side', () async {
      final c = register();
      await c.submit(
        name: '',
        countryCode: '+963',
        phone: '12',
        password: '12345678',
      );
      expect(fake.calls, isEmpty);
      expect(c.state.fieldErrors[AuthField.name], Strings.errNameRequired);
      expect(c.state.fieldErrors[AuthField.phone], Strings.errPhoneInvalid);
      expect(
        c.state.fieldErrors[AuthField.password],
        Strings.errPasswordDigits,
      );
    });

    test('a password equal to the phone is rejected', () async {
      final c = register();
      await c.submit(
        name: 'ليلى',
        countryCode: '+963',
        phone: '0933123456',
        password: '0933 123 456',
      );
      expect(c.state.fieldErrors[AuthField.password], Strings.errPasswordPhone);
      expect(fake.calls, isEmpty);
    });

    test('registers with trimmed name and combined phone', () async {
      final c = register();
      await c.submit(
        name: '  ليلى  ',
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(fake.bodies['register'], {
        'name': 'ليلى',
        'phone': '+963933123456',
        'password': 'secret123',
      });
      expect(c.state.done, isTrue);
    });

    test('PHONE_TAKEN lands on the phone field', () async {
      fake.onRegister = () async => throw api('PHONE_TAKEN', status: 409);
      final c = register();
      await c.submit(
        name: 'ليلى',
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(c.state.fieldErrors[AuthField.phone], 'خادم: PHONE_TAKEN');
      expect(c.state.formError, isNull);
    });

    test('backend WEAK_PASSWORD lands on the password field', () async {
      fake.onRegister = () async => throw api('WEAK_PASSWORD', status: 422);
      final c = register();
      await c.submit(
        name: 'ليلى',
        countryCode: '+963',
        phone: '0933123456',
        password: 'secret123',
      );
      expect(c.state.fieldErrors[AuthField.password], 'خادم: WEAK_PASSWORD');
    });
  });

  group('google', () {
    GoogleSignInCubit google(FakeGoogle g) {
      final session = makeSession(api: fake, storage: storage, merger: merger);
      final c = GoogleSignInCubit(fake, g, session, delay: (_) async {});
      addTearDown(c.close);
      addTearDown(session.close);
      return c;
    }

    test('a known account signs straight in with the dev token', () async {
      final g = FakeGoogle(token: 'dev-google|abc|e@x.test|n');
      final c = google(g);
      expect(await c.signIn(), isNull);
      expect(fake.bodies['google'], {'id_token': 'dev-google|abc|e@x.test|n'});
      expect(c.session.state.isAuthenticated, isTrue);
      expect(c.state.done, isTrue);
    });

    test('a new account returns the profile to complete', () async {
      fake.onGoogle = () async => const GoogleNeedsProfile(
        signupToken: 'tok',
        name: 'سارة',
        email: 's@x.test',
      );
      final c = google(FakeGoogle());
      final need = await c.signIn();
      expect(need!.signupToken, 'tok');
      expect(need.name, 'سارة');
      expect(c.session.state.isAuthenticated, isFalse);
    });

    test('cancelling is silent', () async {
      final c = google(FakeGoogle(token: null));
      expect(await c.signIn(), isNull);
      expect(c.state.formError, isNull);
      expect(c.state.submitting, isFalse);
      expect(fake.calls, isEmpty);
    });

    test(
      'backend rejection shows its message; an SDK failure the Google text',
      () async {
        fake.onGoogle = () async =>
            throw api('GOOGLE_TOKEN_INVALID', status: 401);
        final c = google(FakeGoogle());
        await c.signIn();
        expect(c.state.formError!.message, 'خادم: GOOGLE_TOKEN_INVALID');

        final g = FakeGoogle()..error = StateError('sdk');
        final c2 = google(g);
        await c2.signIn();
        expect(c2.state.formError!.message, Strings.googleFailed);
      },
    );

    test('ALREADY_REGISTERED is its own kind', () async {
      fake.onGoogle = () async => throw api('ALREADY_REGISTERED', status: 409);
      final c = google(FakeGoogle());
      await c.signIn();
      expect(c.state.formError!.kind, FormErrorKind.alreadyRegistered);
    });
  });

  group('complete profile', () {
    CompleteProfileCubit complete() {
      final session = makeSession(api: fake, storage: storage, merger: merger);
      final c = CompleteProfileCubit(
        fake,
        'signup-1',
        session,
        delay: (_) async {},
      );
      addTearDown(c.close);
      addTearDown(session.close);
      return c;
    }

    test('sends the signup token with name and phone', () async {
      final c = complete();
      await c.submit(name: 'سارة', countryCode: '+963', phone: '0933123456');
      expect(fake.bodies['complete'], {
        'signup_token': 'signup-1',
        'name': 'سارة',
        'phone': '+963933123456',
      });
      expect(c.state.done, isTrue);
    });

    test('an expired signup token asks to start again', () async {
      fake.onComplete = () async => throw api('TOKEN_EXPIRED', status: 401);
      final c = complete();
      await c.submit(name: 'سارة', countryCode: '+963', phone: '0933123456');
      expect(c.state.formError!.kind, FormErrorKind.signupExpired);
    });

    test('PHONE_TAKEN lands on the phone field', () async {
      fake.onComplete = () async => throw api('PHONE_TAKEN', status: 409);
      final c = complete();
      await c.submit(name: 'سارة', countryCode: '+963', phone: '0933123456');
      expect(c.state.fieldErrors[AuthField.phone], isNotNull);
    });

    test('requires a name and a valid phone', () async {
      final c = complete();
      await c.submit(name: ' ', countryCode: '+963', phone: 'abc');
      expect(fake.calls, isEmpty);
      expect(
        c.state.fieldErrors.keys,
        containsAll([AuthField.name, AuthField.phone]),
      );
    });
  });

  group('change password', () {
    ChangePasswordCubit change() {
      final session = makeSession(api: fake, storage: storage, merger: merger);
      final c = ChangePasswordCubit(fake, session, delay: (_) async {});
      addTearDown(c.close);
      addTearDown(session.close);
      return c;
    }

    test(
      'client rules: strength, confirmation, differs from current',
      () async {
        final c = change();
        await c.submit(
          currentPassword: 'temp-pass1',
          newPassword: 'short',
          confirmPassword: 'other',
        );
        expect(
          c.state.fieldErrors[AuthField.newPassword],
          Strings.errPasswordShort,
        );
        expect(
          c.state.fieldErrors[AuthField.confirmPassword],
          Strings.errConfirmMismatch,
        );

        await c.submit(
          currentPassword: 'temp-pass1',
          newPassword: 'temp-pass1',
          confirmPassword: 'temp-pass1',
        );
        expect(
          c.state.fieldErrors[AuthField.newPassword],
          Strings.errSamePassword,
        );
        expect(fake.calls, isEmpty);
      },
    );

    test(
      'success stores the new pair, which clears the forced-change flag',
      () async {
        final c = change();
        await c.session.signIn(testPair(user: testUser(mustChange: true)));
        expect(c.session.state.mustChangePassword, isTrue);

        fake.onChange = () async =>
            testPair(access: 'access-2', refresh: 'refresh-2');
        await c.submit(
          currentPassword: 'temp-pass1',
          newPassword: 'brand-new-1',
          confirmPassword: 'brand-new-1',
        );

        expect(fake.bodies['change'], {
          'current_password': 'temp-pass1',
          'new_password': 'brand-new-1',
        });
        expect(c.state.done, isTrue);
        expect(c.session.state.mustChangePassword, isFalse);
        expect(storage.tokens!.refreshToken, 'refresh-2');
        expect(merger.merges, 1); // merge runs after the change
      },
    );

    test('a wrong current password shows on that field', () async {
      fake.onChange = () async =>
          throw api('CURRENT_PASSWORD_INCORRECT', status: 401);
      final c = change();
      await c.submit(
        currentPassword: 'nope-nope',
        newPassword: 'brand-new-1',
        confirmPassword: 'brand-new-1',
      );
      expect(
        c.state.fieldErrors[AuthField.currentPassword],
        'خادم: CURRENT_PASSWORD_INCORRECT',
      );
    });

    test(
      'backend SAME_PASSWORD / WEAK_PASSWORD land on the new password',
      () async {
        fake.onChange = () async => throw api('WEAK_PASSWORD', status: 422);
        final c = change();
        await c.submit(
          currentPassword: 'temp-pass1',
          newPassword: 'brand-new-1',
          confirmPassword: 'brand-new-1',
        );
        expect(c.state.fieldErrors.keys, [AuthField.newPassword]);
      },
    );
  });
}

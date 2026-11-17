import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/app_theme.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/auth_api.dart';
import 'package:lamsa_app/features/auth/data/google_auth_service.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/presentation/auth_screens.dart';

import 'auth_fakes.dart';

late FakeAuthApi fake;
late SessionCubit session;
late MemoryTokenStorage storage;

/// Mounts [screen] at "/" in a tiny router; other routes are text markers.
Future<void> pumpAuth(
  WidgetTester tester,
  Widget screen, {
  FakeGoogle? google,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => screen),
      GoRoute(
        path: '/register',
        builder: (_, _) => const Text('MARK-register'),
      ),
      GoRoute(path: '/login', builder: (_, _) => const Text('MARK-login')),
      GoRoute(
        path: '/complete-profile',
        builder: (_, state) => Text(
          'MARK-complete:${(state.extra! as GoogleNeedsProfile).signupToken}',
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AuthApi>.value(value: fake),
        RepositoryProvider<GoogleAuthService>.value(
          value: google ?? FakeGoogle(),
        ),
      ],
      child: BlocProvider<SessionCubit>.value(
        value: session,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light,
          locale: const Locale('ar'),
          builder: (context, c) =>
              Directionality(textDirection: TextDirection.rtl, child: c!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> type(WidgetTester tester, String label, String text) async {
  await tester.enterText(field(label), text);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  // Prefer the button when the text is also a screen title.
  final button = find.widgetWithText(FilledButton, text);
  final f = button.evaluate().isNotEmpty ? button : find.text(text);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

ApiError apiError(String code, {int status = 400, Duration? retryAfter}) =>
    ApiError(
      code: code,
      backendMessage: 'خادم: $code',
      status: status,
      retryAfter: retryAfter,
    );

/// The icon rows of the live password rules, as met flags in rule order.
List<bool> ruleStates(WidgetTester tester) {
  bool met(String label) {
    final row = find
        .ancestor(of: find.text(label), matching: find.byType(Row))
        .first;
    return find
        .descendant(of: row, matching: find.byIcon(Icons.check_circle))
        .evaluate()
        .isNotEmpty;
  }

  return [
    met(Strings.ruleLength),
    met(Strings.ruleNotDigits),
    met(Strings.ruleNotPhone),
  ];
}

void main() {
  setUp(() {
    fake = FakeAuthApi();
    storage = MemoryTokenStorage();
    session = makeSession(api: fake, storage: storage);
  });

  tearDown(() => session.close());

  group('login screen', () {
    testWidgets('empty submit shows field errors and never calls the backend', (
      tester,
    ) async {
      await pumpAuth(tester, const LoginScreen());
      await tapText(tester, Strings.loginSubmit);
      expect(find.text(Strings.errPhoneRequired), findsOneWidget);
      expect(find.text(Strings.errPasswordRequired), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('an invalid phone is explained', (tester) async {
      await pumpAuth(tester, const LoginScreen());
      await type(tester, Strings.fieldPhone, '12');
      await type(tester, Strings.fieldPassword, 'whatever1');
      await tapText(tester, Strings.loginSubmit);
      expect(find.text(Strings.errPhoneInvalid), findsOneWidget);
      expect(fake.calls, isEmpty);
    });

    testWidgets('editing a field clears its error', (tester) async {
      await pumpAuth(tester, const LoginScreen());
      await tapText(tester, Strings.loginSubmit);
      expect(find.text(Strings.errPhoneRequired), findsOneWidget);
      await type(tester, Strings.fieldPhone, '0');
      expect(find.text(Strings.errPhoneRequired), findsNothing);
    });

    testWidgets('submits the E.164 phone and signs the session in', (
      tester,
    ) async {
      await pumpAuth(tester, const LoginScreen());
      await type(tester, Strings.fieldPhone, '0933 123 456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.loginSubmit);
      expect(fake.bodies['login'], {
        'phone': '+963933123456',
        'password': 'secret123',
      });
      expect(session.state.isAuthenticated, isTrue);
      expect(storage.tokens, isNotNull);
    });

    testWidgets('wrong credentials show the backend message', (tester) async {
      fake.onLogin = () async =>
          throw apiError('INVALID_CREDENTIALS', status: 401);
      await pumpAuth(tester, const LoginScreen());
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'wrong-pass');
      await tapText(tester, Strings.loginSubmit);
      expect(find.text('خادم: INVALID_CREDENTIALS'), findsOneWidget);
      expect(session.state.isAuthenticated, isFalse);
    });

    testWidgets('network failure shows the Arabic connection message', (
      tester,
    ) async {
      fake.onLogin = () async => throw const ApiError(
        code: ApiError.networkCode,
        backendMessage: null,
      );
      await pumpAuth(tester, const LoginScreen());
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.loginSubmit);
      expect(find.text(Strings.errorNetwork), findsOneWidget);
    });

    testWidgets('too many attempts disables submit and counts down', (
      tester,
    ) async {
      fake.onLogin = () async => throw apiError(
        'TOO_MANY_ATTEMPTS',
        status: 429,
        retryAfter: const Duration(seconds: 5),
      );
      await pumpAuth(tester, const LoginScreen());
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.loginSubmit);

      expect(find.text(Strings.authRetryIn(5)), findsOneWidget);
      FilledButton submit() =>
          tester.widget<FilledButton>(find.byType(FilledButton));
      expect(submit().onPressed, isNull);

      await tester.pump(const Duration(seconds: 2));
      expect(find.text(Strings.authRetryIn(3)), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      expect(find.text(Strings.authRetryIn(3)), findsNothing);
      expect(submit().onPressed, isNotNull);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await pumpAuth(tester, const LoginScreen());
      bool obscured() =>
          tester.widget<TextField>(field(Strings.fieldPassword)).obscureText;
      expect(obscured(), isTrue);
      await tester.tap(find.byTooltip(Strings.showPassword));
      await tester.pump();
      expect(obscured(), isFalse);
      await tester.tap(find.byTooltip(Strings.hidePassword));
      await tester.pump();
      expect(obscured(), isTrue);
    });

    testWidgets('shows the session-expired notice only when asked', (
      tester,
    ) async {
      await pumpAuth(tester, const LoginScreen(expired: true));
      expect(find.text(Strings.sessionExpired), findsOneWidget);
    });

    testWidgets('no notice on a normal visit; guests can leave and register', (
      tester,
    ) async {
      await pumpAuth(tester, const LoginScreen());
      expect(find.text(Strings.sessionExpired), findsNothing);
      expect(find.text(Strings.loginContinueAsGuest), findsOneWidget);
      await tapText(tester, Strings.loginRegister);
      expect(find.text('MARK-register'), findsOneWidget);
    });

    testWidgets('forgot password explains the store phone flow', (
      tester,
    ) async {
      await pumpAuth(tester, const LoginScreen());
      await tapText(tester, Strings.loginForgot);
      expect(find.text(Strings.forgotBody), findsOneWidget);
      // No SUPPORT_* configured in tests: no contact buttons.
      expect(find.text(Strings.forgotCall), findsNothing);
      expect(find.text(Strings.forgotWhatsapp), findsNothing);
      await tapText(tester, Strings.close);
      expect(find.text(Strings.forgotBody), findsNothing);
    });
  });

  group('google button (dev scaffolding)', () {
    testWidgets('dev service shows the dev-labelled button', (tester) async {
      await pumpAuth(tester, const LoginScreen(), google: FakeGoogle());
      expect(find.text(Strings.googleDev), findsOneWidget);
      expect(find.text(Strings.authOr), findsOneWidget);
    });

    testWidgets('real service shows the normal label', (tester) async {
      await pumpAuth(
        tester,
        const LoginScreen(),
        google: FakeGoogle(kind: GoogleAuthKind.real),
      );
      expect(find.text(Strings.googleContinue), findsOneWidget);
      expect(find.text(Strings.googleDev), findsNothing);
    });

    testWidgets('no Google at all when it is not offered', (tester) async {
      await pumpAuth(
        tester,
        const LoginScreen(),
        google: FakeGoogle(kind: GoogleAuthKind.none),
      );
      expect(find.text(Strings.googleDev), findsNothing);
      expect(find.text(Strings.googleContinue), findsNothing);
      expect(find.text(Strings.authOr), findsNothing);
    });

    testWidgets('a known Google account signs in', (tester) async {
      final g = FakeGoogle(token: 'dev-google|abc|e@x.test|n');
      await pumpAuth(tester, const LoginScreen(), google: g);
      await tapText(tester, Strings.googleDev);
      expect(fake.bodies['google'], {'id_token': 'dev-google|abc|e@x.test|n'});
      expect(session.state.isAuthenticated, isTrue);
    });

    testWidgets(
      'a new Google account goes to complete-profile with its signup token',
      (tester) async {
        fake.onGoogle = () async =>
            const GoogleNeedsProfile(signupToken: 'tok-9', name: 'سارة');
        await pumpAuth(tester, const LoginScreen());
        await tapText(tester, Strings.googleDev);
        expect(find.text('MARK-complete:tok-9'), findsOneWidget);
        expect(session.state.isAuthenticated, isFalse);
      },
    );

    testWidgets('a rejected Google token shows the backend message', (
      tester,
    ) async {
      fake.onGoogle = () async =>
          throw apiError('GOOGLE_TOKEN_INVALID', status: 401);
      await pumpAuth(tester, const LoginScreen());
      await tapText(tester, Strings.googleDev);
      expect(find.text('خادم: GOOGLE_TOKEN_INVALID'), findsOneWidget);
    });
  });

  group('register screen', () {
    testWidgets('live hints follow the backend password rules', (tester) async {
      await pumpAuth(tester, const RegisterScreen());
      expect(ruleStates(tester), [false, false, false]);

      await type(tester, Strings.fieldPassword, 'abc');
      expect(ruleStates(tester), [
        false,
        true,
        true,
      ]); // short, but not digits, not phone

      await type(tester, Strings.fieldPassword, '12345678');
      expect(ruleStates(tester), [
        true,
        false,
        true,
      ]); // long enough, digits only

      await type(tester, Strings.fieldPassword, 'abcd1234');
      expect(ruleStates(tester), [true, true, true]);
    });

    testWidgets('the "not your phone" hint follows the phone field', (
      tester,
    ) async {
      await pumpAuth(tester, const RegisterScreen());
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, '0933123456');
      expect(ruleStates(tester)[2], isFalse);
      await type(tester, Strings.fieldPassword, '0933123456x');
      expect(ruleStates(tester)[2], isTrue);
    });

    testWidgets(
      'invalid input shows every field error and does not call the backend',
      (tester) async {
        await pumpAuth(tester, const RegisterScreen());
        await type(tester, Strings.fieldPhone, '12');
        await type(tester, Strings.fieldPassword, '12345678');
        await tapText(tester, Strings.registerSubmit);
        expect(find.text(Strings.errNameRequired), findsOneWidget);
        expect(find.text(Strings.errPhoneInvalid), findsOneWidget);
        expect(find.text(Strings.errPasswordDigits), findsOneWidget);
        expect(fake.calls, isEmpty);
      },
    );

    testWidgets('registers and signs in', (tester) async {
      await pumpAuth(tester, const RegisterScreen());
      await type(tester, Strings.fieldName, 'ليلى أحمد');
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.registerSubmit);
      expect(fake.bodies['register'], {
        'name': 'ليلى أحمد',
        'phone': '+963933123456',
        'password': 'secret123',
      });
      expect(session.state.isAuthenticated, isTrue);
    });

    testWidgets('a taken phone is shown under the phone field', (tester) async {
      fake.onRegister = () async => throw apiError('PHONE_TAKEN', status: 409);
      await pumpAuth(tester, const RegisterScreen());
      await type(tester, Strings.fieldName, 'ليلى');
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.registerSubmit);
      expect(find.text('خادم: PHONE_TAKEN'), findsOneWidget);
      expect(session.state.isAuthenticated, isFalse);
    });

    testWidgets(
      'a backend weak-password rejection is shown under the password',
      (tester) async {
        fake.onRegister = () async =>
            throw apiError('WEAK_PASSWORD', status: 422);
        await pumpAuth(tester, const RegisterScreen());
        await type(tester, Strings.fieldName, 'ليلى');
        await type(tester, Strings.fieldPhone, '0933123456');
        await type(tester, Strings.fieldPassword, 'secret123');
        await tapText(tester, Strings.registerSubmit);
        expect(find.text('خادم: WEAK_PASSWORD'), findsOneWidget);
      },
    );

    testWidgets('an existing Google account offers to log in instead', (
      tester,
    ) async {
      fake.onRegister = () async =>
          throw apiError('ALREADY_REGISTERED', status: 409);
      await pumpAuth(tester, const RegisterScreen());
      await type(tester, Strings.fieldName, 'ليلى');
      await type(tester, Strings.fieldPhone, '0933123456');
      await type(tester, Strings.fieldPassword, 'secret123');
      await tapText(tester, Strings.registerSubmit);
      // The banner link and the footer link share the same label.
      expect(find.text('خادم: ALREADY_REGISTERED'), findsOneWidget);
      expect(find.text(Strings.loginInstead), findsNWidgets(2));
    });
  });

  group('complete profile', () {
    const profile = GoogleNeedsProfile(
      signupToken: 'signup-1',
      name: 'سارة',
      email: 's@x.test',
    );

    testWidgets('is prefilled from Google and shows the account', (
      tester,
    ) async {
      await pumpAuth(tester, const CompleteProfileScreen(profile: profile));
      expect(
        tester.widget<TextField>(field(Strings.fieldName)).controller!.text,
        'سارة',
      );
      expect(find.textContaining('s@x.test'), findsOneWidget);
    });

    testWidgets('needs a phone, then completes with the signup token', (
      tester,
    ) async {
      await pumpAuth(tester, const CompleteProfileScreen(profile: profile));
      await tapText(tester, Strings.completeSubmit);
      expect(find.text(Strings.errPhoneRequired), findsOneWidget);
      expect(fake.calls, isEmpty);

      await type(tester, Strings.fieldPhone, '0933123456');
      await tapText(tester, Strings.completeSubmit);
      expect(fake.bodies['complete'], {
        'signup_token': 'signup-1',
        'name': 'سارة',
        'phone': '+963933123456',
      });
      expect(session.state.isAuthenticated, isTrue);
    });

    testWidgets('an expired signup token asks to start again', (tester) async {
      fake.onComplete = () async =>
          throw apiError('TOKEN_EXPIRED', status: 401);
      await pumpAuth(tester, const CompleteProfileScreen(profile: profile));
      await type(tester, Strings.fieldPhone, '0933123456');
      await tapText(tester, Strings.completeSubmit);
      expect(find.text(Strings.completeRestart), findsOneWidget);
      await tapText(tester, Strings.completeRestart);
      expect(find.text('MARK-login'), findsOneWidget);
    });
  });

  group('change password screen', () {
    testWidgets('forced: explains, has no back button, offers logout', (
      tester,
    ) async {
      await session.signIn(testPair(user: testUser(mustChange: true)));
      await pumpAuth(tester, const ChangePasswordScreen());
      expect(find.text(Strings.changeForcedNote), findsOneWidget);
      expect(find.text(Strings.fieldTemporaryPassword), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      await tapText(tester, Strings.logout);
      expect(session.state.isAuthenticated, isFalse);
    });

    testWidgets('validates strength, confirmation and difference', (
      tester,
    ) async {
      await session.signIn(testPair(user: testUser(mustChange: true)));
      await pumpAuth(tester, const ChangePasswordScreen());
      await type(tester, Strings.fieldTemporaryPassword, 'temp-pass1');
      await type(tester, Strings.fieldNewPassword, 'abc');
      await type(tester, Strings.fieldConfirmPassword, 'abd');
      await tapText(tester, Strings.changeSubmit);
      expect(find.text(Strings.errPasswordShort), findsOneWidget);
      expect(find.text(Strings.errConfirmMismatch), findsOneWidget);
      expect(fake.calls, isNot(contains('change')));
    });

    testWidgets('changes the password and clears the forced flag', (
      tester,
    ) async {
      await session.signIn(testPair(user: testUser(mustChange: true)));
      fake.onChange = () async => testPair(refresh: 'refresh-2');
      await pumpAuth(tester, const ChangePasswordScreen());
      await type(tester, Strings.fieldTemporaryPassword, 'temp-pass1');
      await type(tester, Strings.fieldNewPassword, 'brand-new-1');
      await type(tester, Strings.fieldConfirmPassword, 'brand-new-1');
      await tapText(tester, Strings.changeSubmit);
      expect(fake.bodies['change'], {
        'current_password': 'temp-pass1',
        'new_password': 'brand-new-1',
      });
      expect(session.state.mustChangePassword, isFalse);
      expect(storage.tokens!.refreshToken, 'refresh-2');
    });

    testWidgets('a wrong temporary password is shown on that field', (
      tester,
    ) async {
      await session.signIn(testPair(user: testUser(mustChange: true)));
      fake.onChange = () async =>
          throw apiError('CURRENT_PASSWORD_INCORRECT', status: 401);
      await pumpAuth(tester, const ChangePasswordScreen());
      await type(tester, Strings.fieldTemporaryPassword, 'nope-nope');
      await type(tester, Strings.fieldNewPassword, 'brand-new-1');
      await type(tester, Strings.fieldConfirmPassword, 'brand-new-1');
      await tapText(tester, Strings.changeSubmit);
      expect(find.text('خادم: CURRENT_PASSWORD_INCORRECT'), findsOneWidget);
      expect(session.state.mustChangePassword, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/app.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';

import '../catalog/catalog_fakes.dart';
import 'auth_fakes.dart';

late FakeAuthApi fake;
late MemoryTokenStorage storage;
late FakeGoogle google;
late AppDependencies deps;
late int signedOutCleanups;

Future<void> launch(
  WidgetTester tester, {
  bool storedSession = false,
  void Function(FakeAuthApi api, SessionCubit session)? setup,
}) async {
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  fake = FakeAuthApi();
  storage = MemoryTokenStorage(storedSession ? storedTokens() : null);
  google = FakeGoogle();
  signedOutCleanups = 0;
  final session = makeSession(
    api: fake,
    storage: storage,
    onSignedOut: () async {
      signedOutCleanups++;
      await google.signOut();
    },
  );
  setup?.call(fake, session);
  deps = makeDeps(
    session: session,
    api: fake,
    catalogApi: FakeCatalogApi(),
    google: google,
  );
  await tester.pumpWidget(LamsaApp(deps: deps));
  await deps.session.restore();
  await tester.pumpAndSettle();
}

Finder navTab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

Future<void> enter(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label), text);
  await tester.pump();
}

Future<void> tapButton(WidgetTester tester, String label) async {
  final f = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  group('launch', () {
    testWidgets(
      'a valid stored session skips straight to the shell (auto-login)',
      (tester) async {
        await launch(tester, storedSession: true);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text(Strings.loginLead), findsNothing);
        expect(deps.session.state.isAuthenticated, isTrue);
        expect(fake.count('me'), 1);

        // The account tab proves the session works: the profile, not a prompt.
        await tester.tap(navTab(Strings.account));
        await tester.pumpAndSettle();
        expect(find.text('ليلى'), findsOneWidget);
        expect(find.text('+963933123456'), findsOneWidget);
        expect(find.text(Strings.gateTitle), findsNothing);
      },
    );

    testWidgets('a first launch with no stored session browses as a guest', (
      tester,
    ) async {
      await launch(tester);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text(Strings.loginLead), findsNothing);
      expect(find.text(Strings.sessionExpired), findsNothing);
      expect(deps.session.state.end, SessionEnd.none);
    });

    testWidgets('a dead stored session lands on login with the expiry notice', (
      tester,
    ) async {
      await launch(
        tester,
        storedSession: true,
        setup: (api, session) {
          api.onMe = () async {
            storage.tokens = null; // what the interceptor does before reporting
            session.expire();
            throw const ApiError(
              code: 'TOKEN_REUSED',
              backendMessage: null,
              status: 401,
            );
          };
        },
      );
      expect(find.text(Strings.loginLead), findsOneWidget);
      expect(find.text(Strings.sessionExpired), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      expect(deps.session.state.isAuthenticated, isFalse);
    });

    testWidgets(
      'after the notice, continuing as a guest is not bounced back to login',
      (tester) async {
        await launch(
          tester,
          storedSession: true,
          setup: (api, session) {
            api.onMe = () async {
              session.expire();
              throw const ApiError(
                code: 'TOKEN_INVALID',
                backendMessage: null,
                status: 401,
              );
            };
          },
        );
        expect(find.text(Strings.sessionExpired), findsOneWidget);
        await tester.tap(find.text(Strings.loginContinueAsGuest));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.text(Strings.loginLead), findsNothing);
      },
    );
  });

  group('login from the app', () {
    testWidgets(
      'a successful login navigates out of the auth flow into the shell',
      (tester) async {
        await launch(tester);
        deps.router.go('/login');
        await tester.pumpAndSettle();
        expect(find.text(Strings.loginLead), findsOneWidget);

        await enter(tester, Strings.fieldPhone, '0933123456');
        await enter(tester, Strings.fieldPassword, 'secret123');
        await tapButton(tester, Strings.loginSubmit);

        expect(find.text(Strings.loginLead), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(deps.session.state.isAuthenticated, isTrue);
      },
    );

    testWidgets('login from the gated Account tab returns to that tab, in place', (
      tester,
    ) async {
      await launch(tester);
      await tester.tap(navTab(Strings.account));
      await tester.pumpAndSettle();
      expect(find.text(Strings.gateTitle), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget); // still in the shell

      await tester.tap(find.widgetWithText(FilledButton, Strings.login));
      await tester.pumpAndSettle();
      expect(find.text(Strings.loginLead), findsOneWidget);

      await enter(tester, Strings.fieldPhone, '0933123456');
      await enter(tester, Strings.fieldPassword, 'secret123');
      await tapButton(tester, Strings.loginSubmit);

      expect(find.text(Strings.loginLead), findsNothing);
      expect(find.text(Strings.gateTitle), findsNothing);
      expect(find.text('ليلى'), findsOneWidget); // the real account tab
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('only the Account tab is gated: Cart and Favorites work for guests', (
      tester,
    ) async {
      await launch(tester);
      await tester.tap(navTab(Strings.account));
      await tester.pumpAndSettle();
      expect(find.text(Strings.gateTitle), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, Strings.register),
        findsOneWidget,
      );
      await tester.tap(navTab(Strings.cart));
      await tester.pumpAndSettle();
      expect(find.text(Strings.gateTitle), findsNothing);
      expect(find.text(Strings.cartEmptyTitle), findsOneWidget);
      await tester.tap(navTab(Strings.favorites));
      await tester.pumpAndSettle();
      expect(find.text(Strings.gateTitle), findsNothing);
      expect(find.text(Strings.favoritesEmptyTitle), findsOneWidget);
    });

    testWidgets(
      'new Google user: dev sign-in, complete profile, then in the shell',
      (tester) async {
        await launch(
          tester,
          setup: (api, _) {
            api.onGoogle = () async => const GoogleNeedsProfile(
              signupToken: 'tok-1',
              name: 'سارة',
              email: 's@x.test',
            );
          },
        );
        deps.router.go('/login');
        await tester.pumpAndSettle();
        await tester.tap(find.text(Strings.googleDev));
        await tester.pumpAndSettle();
        expect(find.text(Strings.completeLead), findsOneWidget);

        await enter(tester, Strings.fieldPhone, '0933123456');
        await tapButton(tester, Strings.completeSubmit);

        expect(fake.bodies['complete']!['signup_token'], 'tok-1');
        expect(find.text(Strings.completeLead), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(deps.session.state.isAuthenticated, isTrue);
      },
    );

    testWidgets('complete-profile without a signup token goes back to login', (
      tester,
    ) async {
      await launch(tester);
      deps.router.go('/complete-profile');
      await tester.pumpAndSettle();
      expect(find.text(Strings.loginLead), findsOneWidget);
      expect(find.text(Strings.completeLead), findsNothing);
    });
  });

  group('forced password change gate', () {
    testWidgets(
      'signing in with a temporary password opens the change screen',
      (tester) async {
        await launch(
          tester,
          setup: (api, _) {
            api.onLogin = () async =>
                testPair(user: testUser(mustChange: true));
          },
        );
        deps.router.go('/login');
        await tester.pumpAndSettle();
        await enter(tester, Strings.fieldPhone, '0933123456');
        await enter(tester, Strings.fieldPassword, 'temp-pass1');
        await tapButton(tester, Strings.loginSubmit);

        expect(find.text(Strings.changeForcedNote), findsOneWidget);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('blocks every other route until the password is changed', (
      tester,
    ) async {
      await launch(
        tester,
        storedSession: true,
        setup: (api, _) {
          api.onMe = () async => testUser(mustChange: true);
        },
      );
      expect(find.text(Strings.changeForcedNote), findsOneWidget);

      for (final route in [
        '/',
        '/search',
        '/categories',
        '/brands',
        '/cart',
        '/account',
        '/orders',
      ]) {
        deps.router.go(route);
        await tester.pumpAndSettle();
        expect(
          find.text(Strings.changeForcedNote),
          findsOneWidget,
          reason: route,
        );
        expect(find.byType(NavigationBar), findsNothing, reason: route);
      }
    });

    testWidgets('a 403 PASSWORD_CHANGE_REQUIRED mid-session opens the gate', (
      tester,
    ) async {
      await launch(tester, storedSession: true);
      expect(find.byType(NavigationBar), findsOneWidget);

      // The interceptor reports the 403; the profile now says the flag is set.
      fake.onMe = () async => testUser(mustChange: true);
      await deps.session.passwordChangeRequired();
      await tester.pumpAndSettle();

      expect(find.text(Strings.changeForcedNote), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets(
      'changing the password releases the gate and returns to the app',
      (tester) async {
        await launch(
          tester,
          storedSession: true,
          setup: (api, _) {
            api.onMe = () async => testUser(mustChange: true);
            api.onChange = () async => testPair(refresh: 'refresh-2');
          },
        );
        await enter(tester, Strings.fieldTemporaryPassword, 'temp-pass1');
        await enter(tester, Strings.fieldNewPassword, 'brand-new-1');
        await enter(tester, Strings.fieldConfirmPassword, 'brand-new-1');
        await tapButton(tester, Strings.changeSubmit);

        expect(find.text(Strings.changeForcedNote), findsNothing);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(deps.session.state.mustChangePassword, isFalse);

        // Navigation works again.
        deps.router.go('/categories');
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
      },
    );

    testWidgets('the gate has its own logout so the user is not trapped', (
      tester,
    ) async {
      await launch(
        tester,
        storedSession: true,
        setup: (api, _) {
          api.onMe = () async => testUser(mustChange: true);
        },
      );
      await tester.tap(find.text(Strings.logout));
      await tester.pumpAndSettle();
      expect(deps.session.state.isAuthenticated, isFalse);
      expect(find.text(Strings.loginLead), findsOneWidget);
      expect(find.text(Strings.changeForcedNote), findsNothing);
    });
  });

  group('logout', () {
    testWidgets(
      'clears storage, tells the backend, cleans up and returns to login',
      (tester) async {
        await launch(tester, storedSession: true);
        await tester.tap(navTab(Strings.account));
        await tester.pumpAndSettle();

        await tester.tap(find.text(Strings.logout));
        await tester.pumpAndSettle();

        expect(storage.tokens, isNull);
        expect(fake.bodies['logout'], {'refresh_token': 'r'});
        expect(signedOutCleanups, 1);
        expect(google.signOuts, 1);
        expect(deps.session.state.status, SessionStatus.unauthenticated);
        // Straight to login, with no "session expired" notice.
        expect(find.text(Strings.loginLead), findsOneWidget);
        expect(find.text(Strings.sessionExpired), findsNothing);
        expect(find.byType(NavigationBar), findsNothing);
      },
    );

    testWidgets('after logging out, guests can still go back to browsing', (
      tester,
    ) async {
      await launch(tester, storedSession: true);
      await tester.tap(navTab(Strings.account));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Strings.logout));
      await tester.pumpAndSettle();

      await tester.tap(find.text(Strings.loginContinueAsGuest));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(navTab(Strings.account));
      await tester.pumpAndSettle();
      expect(find.text(Strings.gateTitle), findsOneWidget);
    });
  });
}

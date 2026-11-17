import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/router/auth_guard.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';

AuthUser _user({bool mustChange = false}) => AuthUser(
      id: 1,
      name: 'ليلى',
      phone: '+963933123456',
      role: 'customer',
      authProvider: 'phone',
      mustChangePassword: mustChange,
    );

String? redirect(SessionState s, String location) =>
    authRedirect(session: s, location: location, uri: Uri.parse(location));

void main() {
  const out = SessionState(SessionStatus.unauthenticated);
  final signedIn = SessionState(SessionStatus.authenticated, _user());

  test('unknown session parks on the splash route', () {
    expect(redirect(const SessionState.unknown(), '/orders'), '/splash');
    expect(redirect(const SessionState.unknown(), '/splash'), isNull);
  });

  test('signed out: protected routes go to login with ?from', () {
    expect(redirect(out, '/orders'), '/login?from=%2Forders');
    expect(redirect(out, '/notifications'), '/login?from=%2Fnotifications');
    expect(redirect(out, '/orders/5'), '/login?from=%2Forders%2F5');
    expect(redirect(out, '/'), isNull);
    expect(redirect(out, '/product/x'), isNull);
    // Catalog phase 1: the placeholder tabs are open to guests for now.
    for (final tab in ['/cart', '/favorites', '/account']) {
      expect(redirect(out, tab), isNull);
    }
    expect(redirect(out, '/splash'), '/');
  });

  test('signed in: auth screens bounce to home or the original target', () {
    expect(redirect(signedIn, '/login'), '/');
    expect(
      authRedirect(
        session: signedIn,
        location: '/login',
        uri: Uri.parse('/login?from=/orders'),
      ),
      '/orders',
    );
    expect(redirect(signedIn, '/orders'), isNull);
  });

  test('must-change-password forces the change-password screen', () {
    final forced = SessionState(
      SessionStatus.authenticated,
      _user(mustChange: true),
    );
    expect(redirect(forced, '/'), '/change-password');
    expect(redirect(forced, '/change-password'), isNull);
  });
}

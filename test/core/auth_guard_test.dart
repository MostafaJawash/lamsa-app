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
    // Any other destination is blocked, and remembered as the return path.
    expect(
      redirect(forced, '/orders/5'),
      '/change-password?from=%2Forders%2F5',
    );
    expect(redirect(forced, '/cart'), '/change-password?from=%2Fcart');
    expect(redirect(forced, '/search'), '/change-password?from=%2Fsearch');
    expect(redirect(forced, '/login'), '/change-password?from=%2Flogin');
  });

  test('after the change the same screen no longer blocks navigation', () {
    expect(redirect(signedIn, '/change-password'), isNull);
    expect(redirect(signedIn, '/orders'), isNull);
  });

  test('a dead stored session lands on login with the expiry notice', () {
    const expired = SessionState(
      SessionStatus.unauthenticated,
      null,
      SessionEnd.expired,
    );
    expect(redirect(expired, '/'), '/login?expired=1');
    expect(redirect(expired, '/splash'), '/login?expired=1');
    expect(redirect(expired, '/product/x'), '/login?expired=1');
    // The auth screens themselves stay reachable.
    expect(redirect(expired, '/login'), isNull);
    expect(redirect(expired, '/register'), isNull);
    expect(redirect(expired, '/complete-profile'), isNull);
  });

  test('a deliberate logout goes to login without a notice', () {
    const gone = SessionState(
      SessionStatus.unauthenticated,
      null,
      SessionEnd.signedOut,
    );
    expect(redirect(gone, '/account'), '/login');
    expect(redirect(gone, '/'), '/login');
    expect(redirect(gone, '/login'), isNull);
  });

  test('a first launch with no session just browses (no login bounce)', () {
    expect(redirect(out, '/splash'), '/');
    expect(redirect(out, '/'), isNull);
    expect(redirect(out, '/account'), isNull); // gated inline, not redirected
  });

  test('return paths are sanitized', () {
    String? signedInAt(String from) => authRedirect(
      session: signedIn,
      location: '/login',
      uri: Uri(path: '/login', queryParameters: {'from': from}),
    );
    expect(signedInAt('/cart'), '/cart');
    expect(signedInAt('//evil.example'), '/');
    expect(signedInAt('https://evil.example'), '/');
    expect(signedInAt(r'/\evil'), '/');
  });
}

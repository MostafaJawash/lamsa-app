import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';

bool _isAuthRoute(String location) =>
    location == Routes.login ||
    location == Routes.register ||
    location == Routes.completeProfile;

/// Pure redirect rules (testable without a router). Returns the location to
/// redirect to, or null to stay.
///
/// - First launch / guest: browse freely (home); protected routes ask for login.
/// - A stored session that died ([SessionEnd.expired]) lands on login with a
///   notice; a deliberate logout ([SessionEnd.signedOut]) lands on login
///   without one.
/// - While a temporary password is pending, everything but the change-password
///   screen redirects there (the backend refuses every other call anyway).
String? authRedirect({
  required SessionState session,
  required String location,
  required Uri uri,
}) {
  if (session.status == SessionStatus.unknown) {
    return location == Routes.splash ? null : Routes.splash;
  }

  if (!session.isAuthenticated) {
    if (!_isAuthRoute(location)) {
      if (session.end == SessionEnd.expired) return '${Routes.login}?expired=1';
      if (session.end == SessionEnd.signedOut) return Routes.login;
    }
    if (location == Routes.splash) return Routes.home;
    if (Routes.isProtected(location) || location == Routes.changePassword) {
      return Uri(
        path: Routes.login,
        queryParameters: {'from': uri.toString()},
      ).toString();
    }
    return null;
  }

  // Signed in from here on.
  if (session.mustChangePassword && location != Routes.changePassword) {
    final back = location == Routes.splash || location == Routes.home
        ? null
        : uri.toString();
    return Routes.withFrom(Routes.changePassword, back);
  }
  if (location == Routes.splash || _isAuthRoute(location)) {
    return safeReturnPath(uri.queryParameters['from']);
  }
  return null;
}

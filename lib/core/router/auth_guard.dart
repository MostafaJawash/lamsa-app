import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';

/// Pure redirect rules (testable without a router). Returns the location to
/// redirect to, or null to stay.
String? authRedirect({
  required SessionState session,
  required String location,
  required Uri uri,
}) {
  if (session.status == SessionStatus.unknown) {
    return location == Routes.splash ? null : Routes.splash;
  }

  if (!session.isAuthenticated) {
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
    return Routes.changePassword;
  }
  if (location == Routes.splash ||
      location == Routes.login ||
      location == Routes.register ||
      location == Routes.completeProfile) {
    final from = uri.queryParameters['from'];
    return from != null && from.startsWith('/') ? from : Routes.home;
  }
  return null;
}

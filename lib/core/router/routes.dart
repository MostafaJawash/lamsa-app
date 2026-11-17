abstract final class Routes {
  static const splash = '/splash';
  static const home = '/';
  static const category = '/category'; // /category/:slug
  static const product = '/product'; // /product/:slug
  static const search = '/search';
  static const brands = '/brands'; // /brands/:slug
  static const categories = '/categories';
  static const newArrivals = '/new';
  static const sale = '/sale';

  static String productPath(String slug) =>
      '$product/${Uri.encodeComponent(slug)}';
  static String categoryPath(String slug) =>
      '$category/${Uri.encodeComponent(slug)}';
  static String brandPath(String slug) =>
      '$brands/${Uri.encodeComponent(slug)}';

  static const login = '/login';
  static const register = '/register';
  static const completeProfile = '/complete-profile';
  static const changePassword = '/change-password';

  // Bottom-nav tabs. They are placeholders for now.
  // Protected (when built): mirror the website's auth gates.
  static const cart = '/cart';
  static const favorites = '/favorites';
  static const orders = '/orders';
  static const account = '/account';
  static const notifications = '/notifications';

  /// Routes that redirect a guest to login (with a `from` return path).
  ///
  /// The cart, favorites and account TABS are intentionally not listed: they
  /// are gated inline by `SessionGate` (a "log in to continue" prompt inside
  /// the tab, keeping the bottom bar), which suits the shell better than a
  /// full-screen redirect.
  static const protectedPrefixes = [orders, notifications];

  /// `path` plus a `?from=` return path (omitted when it is just home).
  static String withFrom(String path, String? from) {
    final target = safeReturnPath(from);
    return target == home ? path : '$path?from=${Uri.encodeComponent(target)}';
  }

  static bool isProtected(String location) =>
      protectedPrefixes.any((p) => location == p || location.startsWith('$p/'));
}

/// A return path from `?from=`: only a same-app absolute path is accepted
/// (starts with "/" but not "//", no backslash or control characters),
/// anything else becomes home. Mirrors lamsa-web's `safeNext`.
String safeReturnPath(String? value) {
  if (value == null || value.isEmpty || value.length > 2048) return Routes.home;
  if (!value.startsWith('/') || value.startsWith('//')) return Routes.home;
  if (value.contains(RegExp(r'[\\\x00-\x1f\x7f]'))) return Routes.home;
  return value;
}

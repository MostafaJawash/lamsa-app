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

  static String productPath(String slug) => '$product/${Uri.encodeComponent(slug)}';
  static String categoryPath(String slug) => '$category/${Uri.encodeComponent(slug)}';
  static String brandPath(String slug) => '$brands/${Uri.encodeComponent(slug)}';

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

  // TODO(catalog phase 1): cart, favorites and account are deliberately NOT
  // protected yet. Their bottom-nav tabs show a "coming soon" placeholder inside
  // the shell instead of bouncing guests to login. When those features are
  // built, restore: [cart, favorites, orders, account, notifications].
  static const protectedPrefixes = [orders, notifications];

  static bool isProtected(String location) => protectedPrefixes.any(
        (p) => location == p || location.startsWith('$p/'),
      );
}

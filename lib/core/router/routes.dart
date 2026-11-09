abstract final class Routes {
  static const splash = '/splash';
  static const home = '/';
  static const category = '/category'; // /category/:slug
  static const product = '/product'; // /product/:slug
  static const search = '/search';
  static const brands = '/brands';

  static const login = '/login';
  static const register = '/register';
  static const completeProfile = '/complete-profile';
  static const changePassword = '/change-password';

  // Protected: mirror the website's auth gates.
  static const cart = '/cart';
  static const favorites = '/favorites';
  static const orders = '/orders';
  static const account = '/account';
  static const notifications = '/notifications';

  static const protectedPrefixes = [cart, favorites, orders, account, notifications];

  static bool isProtected(String location) => protectedPrefixes.any(
        (p) => location == p || location.startsWith('$p/'),
      );
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/auth_guard.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/account/presentation/account_screen.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/presentation/auth_screens.dart';
import 'package:lamsa_app/features/cart/presentation/cart_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/catalog_screens.dart';
import 'package:lamsa_app/features/catalog/presentation/home_screen.dart';
import 'package:lamsa_app/features/favorites/presentation/favorites_screen.dart';
import 'package:lamsa_app/features/notifications/presentation/notifications_screen.dart';
import 'package:lamsa_app/features/orders/presentation/orders_screen.dart';

/// Re-runs the router redirect whenever the session changes.
final class _SessionRefresh extends ChangeNotifier {
  _SessionRefresh(Stream<SessionState> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<SessionState> _sub;

  @override
  void dispose() {
    unawaited(_sub.cancel());
    super.dispose();
  }
}

GoRouter buildRouter(SessionCubit session) {
  return GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: _SessionRefresh(session.stream),
    redirect: (context, state) => authRedirect(
      session: session.state,
      location: state.matchedLocation,
      uri: state.uri,
    ),
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, _) => const Scaffold(body: LoadingView(message: Strings.loading)),
      ),
      GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
      GoRoute(
        path: '${Routes.category}/:slug',
        builder: (_, _) => const CategoryScreen(),
      ),
      GoRoute(
        path: '${Routes.product}/:slug',
        builder: (_, _) => const ProductScreen(),
      ),
      GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: Routes.brands, builder: (_, _) => const BrandsScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(
        path: Routes.completeProfile,
        builder: (_, _) => const CompleteProfileScreen(),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, _) => const ChangePasswordScreen(),
      ),
      GoRoute(path: Routes.cart, builder: (_, _) => const CartScreen()),
      GoRoute(path: Routes.favorites, builder: (_, _) => const FavoritesScreen()),
      GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen()),
      GoRoute(path: Routes.account, builder: (_, _) => const AccountScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
}

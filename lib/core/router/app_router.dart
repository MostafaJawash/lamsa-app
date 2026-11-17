import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/auth_guard.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/presentation/auth_screens.dart';
import 'package:lamsa_app/features/catalog/data/list_filters.dart';
import 'package:lamsa_app/features/catalog/presentation/categories_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/home_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/product_list_screen.dart';
import 'package:lamsa_app/features/catalog/presentation/product_screen.dart';
import 'package:lamsa_app/features/notifications/presentation/notifications_screen.dart';
import 'package:lamsa_app/features/orders/presentation/orders_screen.dart';
import 'package:lamsa_app/features/shell/main_shell.dart';

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
      // Bottom-nav shell: one branch (own stack) per tab.
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.categories,
                builder: (_, _) => const CategoriesScreen(),
              ),
            ],
          ),
          // TODO(catalog phase 1): placeholders until favorites, cart and
          // account are built (see Routes.protectedPrefixes).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.favorites,
                builder: (_, _) => const ComingSoonTab(title: Strings.favorites),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cart,
                builder: (_, _) => const ComingSoonTab(title: Strings.cart),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const ComingSoonTab(title: Strings.account),
              ),
            ],
          ),
        ],
      ),
      // Full-screen catalog routes, pushed above the tabs.
      GoRoute(
        path: '${Routes.category}/:slug',
        builder: (_, state) => ProductListScreen(
          key: ValueKey(state.uri),
          scope: CategoryScope(state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: '${Routes.product}/:slug',
        builder: (_, state) => ProductScreen(
          key: ValueKey(state.uri),
          slug: state.pathParameters['slug']!,
        ),
      ),
      GoRoute(path: Routes.search, builder: (_, _) => const SearchScreen()),
      GoRoute(path: Routes.brands, builder: (_, _) => const BrandsScreen()),
      GoRoute(
        path: '${Routes.brands}/:slug',
        builder: (_, state) => ProductListScreen(
          key: ValueKey(state.uri),
          scope: BrandScope(state.pathParameters['slug']!),
        ),
      ),
      GoRoute(
        path: Routes.newArrivals,
        builder: (_, _) => const ProductListScreen(scope: NewScope()),
      ),
      GoRoute(
        path: Routes.sale,
        builder: (_, _) => const ProductListScreen(scope: SaleScope()),
      ),
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
      GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
}

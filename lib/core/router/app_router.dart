import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/auth_guard.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/account/presentation/account_screen.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/models/google_auth_result.dart';
import 'package:lamsa_app/features/auth/presentation/auth_screens.dart';
import 'package:lamsa_app/features/auth/presentation/session_gate.dart';
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
        builder: (_, _) =>
            const Scaffold(body: LoadingView(message: Strings.loading)),
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
          // Favorites and cart: gated inline for guests; the real screens
          // arrive in a later phase (until then a "coming soon" body).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.favorites,
                builder: (_, _) => const SessionGate(
                  title: Strings.favorites,
                  returnPath: Routes.favorites,
                  child: ComingSoonTab(title: Strings.favorites),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.cart,
                builder: (_, _) => const SessionGate(
                  title: Strings.cart,
                  returnPath: Routes.cart,
                  child: ComingSoonTab(title: Strings.cart),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.account,
                builder: (_, _) => const AccountScreen(),
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
      GoRoute(
        path: Routes.login,
        builder: (_, state) => LoginScreen(
          from: state.uri.queryParameters['from'],
          expired: state.uri.queryParameters['expired'] == '1',
        ),
      ),
      GoRoute(
        path: Routes.register,
        builder: (_, state) =>
            RegisterScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: Routes.completeProfile,
        // The signup token travels in the route; without it (e.g. the app was
        // restarted) there is nothing to complete: start again at login.
        redirect: (_, state) =>
            state.extra is GoogleNeedsProfile ? null : Routes.login,
        builder: (_, state) => CompleteProfileScreen(
          profile: state.extra! as GoogleNeedsProfile,
          from: state.uri.queryParameters['from'],
        ),
      ),
      GoRoute(
        path: Routes.changePassword,
        builder: (_, state) =>
            ChangePasswordScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(path: Routes.orders, builder: (_, _) => const OrdersScreen()),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
    ],
  );
}

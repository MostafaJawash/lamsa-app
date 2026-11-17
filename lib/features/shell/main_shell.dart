import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';

/// App frame with the 5-tab bottom navigation. Each tab keeps its own
/// navigation stack and scroll position (`StatefulShellRoute`).
///
/// Order (RTL, so the first tab sits on the right): الرئيسية، الأقسام،
/// المفضلة، السلة، حسابي.
class MainShell extends StatelessWidget {
  const MainShell({required this.shell, super.key});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        // Tapping the active tab returns to its root.
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Strings.home,
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: Strings.categories,
          ),
          NavigationDestination(
            icon: _FavoritesIcon(selected: false),
            selectedIcon: _FavoritesIcon(selected: true),
            label: Strings.favorites,
          ),
          NavigationDestination(
            icon: _CartIcon(selected: false),
            selectedIcon: _CartIcon(selected: true),
            label: Strings.cart,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Strings.account,
          ),
        ],
      ),
    );
  }
}

/// A count badge on a tab icon: hidden at 0, "99+" above 99. Live for guests
/// (local data) and signed-in users (backend), like lamsa-web's tab bar.
class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      label: Text(count > 99 ? Strings.badgeOverflow : '$count'),
      child: child,
    );
  }
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<CartCubit, CartState, int>(
      selector: (s) => s.count,
      builder: (context, count) => _CountBadge(
        count: count,
        child: Icon(selected ? Icons.shopping_bag : Icons.shopping_bag_outlined),
      ),
    );
  }
}

class _FavoritesIcon extends StatelessWidget {
  const _FavoritesIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FavoritesCubit, FavoritesState, int>(
      selector: (s) => s.ids.length,
      builder: (context, count) => _CountBadge(
        count: count,
        child: Icon(selected ? Icons.favorite : Icons.favorite_border),
      ),
    );
  }
}

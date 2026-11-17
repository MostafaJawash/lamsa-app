import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';

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
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite),
            label: Strings.favorites,
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_bag_outlined),
            selectedIcon: Icon(Icons.shopping_bag),
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

/// Body of the not-yet-built tabs (favorites, cart), shown once signed in.
/// Guests see the inline login prompt of `SessionGate` instead.
///
/// TODO(cart/favorites phases): replace with the real screens.
class ComingSoonTab extends StatelessWidget {
  const ComingSoonTab({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title), automaticallyImplyLeading: false),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.xl),
          child: Text(
            Strings.comingSoon,
            style: Theme.of(context).textTheme.headlineSmall!
                .copyWith(color: context.lamsa.muted),
          ),
        ),
      ),
    );
  }
}

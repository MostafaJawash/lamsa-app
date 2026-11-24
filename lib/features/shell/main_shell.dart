import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/cubit/cart_cubit.dart';
import 'package:lamsa_app/features/favorites/cubit/favorites_cubit.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';

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
        destinations: [
          NavigationDestination(
            icon: NavBounce(
              selected: shell.currentIndex == 0,
              child: Icon(shell.currentIndex == 0 ? Icons.home : Icons.home_outlined),
            ),
            label: Strings.home,
          ),
          NavigationDestination(
            icon: NavBounce(
              selected: shell.currentIndex == 1,
              child: Icon(
                shell.currentIndex == 1
                    ? Icons.grid_view_rounded
                    : Icons.grid_view_outlined,
              ),
            ),
            label: Strings.categories,
          ),
          NavigationDestination(
            icon: NavBounce(
              selected: shell.currentIndex == 2,
              child: _FavoritesIcon(selected: shell.currentIndex == 2),
            ),
            label: Strings.favorites,
          ),
          NavigationDestination(
            icon: NavBounce(
              selected: shell.currentIndex == 3,
              child: _CartIcon(selected: shell.currentIndex == 3),
            ),
            label: Strings.cart,
          ),
          NavigationDestination(
            icon: NavBounce(
              selected: shell.currentIndex == 4,
              child: _AccountIcon(selected: shell.currentIndex == 4),
            ),
            label: Strings.account,
          ),
        ],
      ),
    );
  }
}

/// The tab icon's selection animation: when [selected] turns true the icon
/// pops (scale 0.7 -> 1 with an overshoot, 260 ms). Skipped entirely when the
/// OS asks to reduce motion. Visual only: navigation is untouched.
class NavBounce extends StatefulWidget {
  const NavBounce({required this.selected, required this.child, super.key});

  final bool selected;
  final Widget child;

  static const duration = Duration(milliseconds: 260);

  @override
  State<NavBounce> createState() => _NavBounceState();
}

class _NavBounceState extends State<NavBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: NavBounce.duration,
    value: 1,
  );
  late final Animation<double> _scale = Tween<double>(begin: .7, end: 1).animate(
    CurvedAnimation(parent: _c, curve: Curves.easeOutBack),
  );

  @override
  void didUpdateWidget(NavBounce old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected) {
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _c.value = 1;
      } else {
        _c.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
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

/// The account tab carries the unread-notifications count (the inbox lives in
/// the account menu), like lamsa-web's account navigation.
class _AccountIcon extends StatelessWidget {
  const _AccountIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<UnreadCubit, int, int>(
      selector: (n) => n,
      builder: (context, count) => _CountBadge(
        count: count,
        child: Icon(selected ? Icons.person : Icons.person_outline),
      ),
    );
  }
}

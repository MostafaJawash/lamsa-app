import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/theme/theme_cubit.dart';
import 'package:lamsa_app/core/widgets/app_messenger.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/presentation/session_gate.dart';
import 'package:lamsa_app/features/notifications/cubit/unread_cubit.dart';

/// Account tab: a guest sees the inline login prompt; a signed-in user sees
/// their profile, the menu (orders, addresses, profile, phone, password) and
/// the logout actions.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SessionGate(
      title: Strings.account,
      returnPath: Routes.account,
      child: _AccountView(),
    );
  }
}

class _AccountView extends StatefulWidget {
  const _AccountView();

  @override
  State<_AccountView> createState() => _AccountViewState();
}

class _AccountViewState extends State<_AccountView> {
  bool _failed = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    // An offline launch keeps the session without a profile: fetch it now.
    if (context.read<SessionCubit>().state.user == null) _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final ok = await context.read<SessionCubit>().refreshUser();
    if (mounted && !ok) setState(() => _failed = true);
  }

  Future<void> _logoutAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(Strings.logoutAllTitle),
        content: const Text(Strings.logoutAllText),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(Strings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(Strings.logoutAllConfirm),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _loggingOut = true);
    final session = context.read<SessionCubit>();
    try {
      // The router sends the signed-out user to the login screen.
      await session.signOutEverywhere();
    } on Object catch (e) {
      showToast(messageOf(e));
    }
    if (mounted) setState(() => _loggingOut = false);
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    // The router sends the signed-out user to the login screen.
    await context.read<SessionCubit>().signOut();
    if (mounted) setState(() => _loggingOut = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(Strings.account),
        automaticallyImplyLeading: false,
      ),
      body: BlocBuilder<SessionCubit, SessionState>(
        buildWhen: (a, b) => a.user != b.user,
        builder: (context, state) {
          final user = state.user;
          if (user == null) {
            return _failed
                ? ErrorView(message: Strings.accountUnavailable, onRetry: _load)
                : const LoadingView(message: Strings.loading);
          }
          return RefreshIndicator(
            onRefresh: () => context.read<SessionCubit>().refreshUser(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(Spacing.pageGutter),
              children: [
                _ProfileCard(user: user),
                const SizedBox(height: Spacing.lg),
                const _Menu(
                  items: [
                    (
                      Icons.receipt_long_outlined,
                      Strings.accountOrders,
                      Routes.orders,
                    ),
                    (
                      Icons.notifications_none,
                      Strings.notifications,
                      Routes.notifications,
                    ),
                    (
                      Icons.location_on_outlined,
                      Strings.accountAddresses,
                      Routes.addresses,
                    ),
                    (
                      Icons.person_outline,
                      Strings.accountProfile,
                      Routes.profile,
                    ),
                    (Icons.phone_outlined, Strings.accountPhone, Routes.phone),
                    (
                      Icons.lock_outline,
                      Strings.accountPassword,
                      Routes.password,
                    ),
                    (
                      Icons.tune,
                      Strings.prefsTitle,
                      Routes.notificationSettings,
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.lg),
                Card(
                  margin: EdgeInsets.zero,
                  child: BlocBuilder<ThemeCubit, ThemeMode>(
                    builder: (context, mode) => SwitchListTile(
                      secondary: Icon(
                        Icons.dark_mode_outlined,
                        color: context.lamsa.accent,
                      ),
                      title: const Text(Strings.darkMode),
                      value: mode == ThemeMode.dark,
                      onChanged: context.read<ThemeCubit>().setDark,
                    ),
                  ),
                ),
                const SizedBox(height: Spacing.xl),
                OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text(Strings.logout),
                ),
                const SizedBox(height: Spacing.sm),
                TextButton(
                  onPressed: _loggingOut ? null : _logoutAll,
                  child: const Text(Strings.accountLogoutAll),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu({required this.items});

  final List<(IconData, String, String)> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            ListTile(
              leading: Icon(items[i].$1, color: context.lamsa.accent),
              title: Text(items[i].$2),
              trailing: items[i].$3 == Routes.notifications
                  ? BlocBuilder<UnreadCubit, int>(
                      builder: (context, count) => Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (count > 0)
                            Badge(
                              label: Text(
                                count > 99 ? Strings.badgeOverflow : '$count',
                              ),
                            ),
                          const Icon(Icons.chevron_left),
                        ],
                      ),
                    )
                  : const Icon(Icons.chevron_left),
              onTap: () => context.push(items[i].$3),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final c = context.lamsa;
    final via = user.authProvider == 'google'
        ? Strings.accountViaGoogle
        : Strings.accountViaPhone;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: c.accentSoft,
                  child: Icon(Icons.person, color: c.accent, size: 30),
                ),
                const SizedBox(width: Spacing.md),
                Expanded(child: Text(user.name, style: theme.titleLarge)),
              ],
            ),
            const SizedBox(height: Spacing.lg),
            _Row(
              label: Strings.fieldPhone,
              // Phone numbers always read left-to-right.
              value: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(user.phone, style: theme.bodyLarge),
              ),
            ),
            if (user.email != null)
              _Row(
                label: Strings.accountEmail,
                value: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(user.email!, style: theme.bodyLarge),
                ),
              ),
            _Row(
              label: Strings.accountVia,
              value: Text(via, style: theme.bodyLarge),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!
                  .copyWith(color: context.lamsa.muted),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: value,
            ),
          ),
        ],
      ),
    );
  }
}

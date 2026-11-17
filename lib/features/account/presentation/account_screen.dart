import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';
import 'package:lamsa_app/features/auth/data/models/auth_user.dart';
import 'package:lamsa_app/features/auth/presentation/session_gate.dart';

/// Account tab: a guest sees the inline login prompt; a signed-in user sees
/// their profile and the logout action. (Addresses, orders and settings come
/// in later phases.)
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
                const SizedBox(height: Spacing.xl),
                OutlinedButton.icon(
                  onPressed: _loggingOut ? null : _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text(Strings.logout),
                ),
              ],
            ),
          );
        },
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

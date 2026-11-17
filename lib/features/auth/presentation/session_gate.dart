import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/auth/cubit/session_cubit.dart';

/// Gates a bottom-nav tab: signed in shows [child]; a guest sees an inline
/// "سجّل الدخول لمتابعة التسوق" prompt inside the tab (the bottom bar stays),
/// with buttons that return to [returnPath] after login. The tab swaps to the
/// real content in place the moment the session changes.
class SessionGate extends StatelessWidget {
  const SessionGate({
    required this.title,
    required this.returnPath,
    required this.child,
    super.key,
  });

  final String title;
  final String returnPath;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SessionCubit, SessionState>(
      buildWhen: (a, b) => a.status != b.status,
      builder: (context, state) {
        switch (state.status) {
          case SessionStatus.authenticated:
            return child;
          case SessionStatus.unknown:
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
              ),
              body: const LoadingView(message: Strings.loading),
            );
          case SessionStatus.unauthenticated:
            return Scaffold(
              appBar: AppBar(
                title: Text(title),
                automaticallyImplyLeading: false,
              ),
              body: _LoginPrompt(returnPath: returnPath),
            );
        }
      },
    );
  }
}

class _LoginPrompt extends StatelessWidget {
  const _LoginPrompt({required this.returnPath});

  final String returnPath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Spacing.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.lock_outline, size: 48, color: context.lamsa.muted),
              const SizedBox(height: Spacing.lg),
              Text(
                Strings.gateTitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                Strings.gateText,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium!.copyWith(
                  color: context.lamsa.muted,
                ),
              ),
              const SizedBox(height: Spacing.xl),
              FilledButton(
                onPressed: () =>
                    context.push(Routes.withFrom(Routes.login, returnPath)),
                child: const Text(Strings.login),
              ),
              const SizedBox(height: Spacing.md),
              OutlinedButton(
                onPressed: () =>
                    context.push(Routes.withFrom(Routes.register, returnPath)),
                child: const Text(Strings.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

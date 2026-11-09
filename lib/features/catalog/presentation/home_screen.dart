import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/lamsa_button.dart';
import 'package:lamsa_app/core/widgets/placeholder_screen.dart';
import 'package:lamsa_app/features/catalog/cubit/home_cubit.dart';
import 'package:lamsa_app/features/catalog/data/catalog_api.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _links = <(String, String)>[
    (Strings.category, '${Routes.category}/demo'),
    (Strings.product, '${Routes.product}/demo'),
    (Strings.search, Routes.search),
    (Strings.brands, Routes.brands),
    (Strings.cart, Routes.cart),
    (Strings.favorites, Routes.favorites),
    (Strings.orders, Routes.orders),
    (Strings.account, Routes.account),
    (Strings.notifications, Routes.notifications),
    (Strings.login, Routes.login),
    (Strings.register, Routes.register),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeCubit(context.read<CatalogApi>())..check(),
      child: PlaceholderScreen(
        title: Strings.home,
        children: [
          const SizedBox(height: Spacing.lg),
          const _ServerStatusBanner(),
          const SizedBox(height: Spacing.lg),
          for (final (label, route) in _links)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: LamsaButton(
                label: label,
                secondary: true,
                onPressed: () => context.push(route),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServerStatusBanner extends StatelessWidget {
  const _ServerStatusBanner();

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        final (text, color) = switch (state.status) {
          ServerStatus.checking => (Strings.checkingServer, c.muted),
          ServerStatus.reachable => (Strings.serverReachable, c.ok),
          ServerStatus.unreachable => (Strings.serverUnreachable, c.danger),
        };
        return Container(
          padding: const EdgeInsets.all(Spacing.md),
          decoration: BoxDecoration(
            color: c.surface,
            border: Border.all(color: color),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: color),
          ),
        );
      },
    );
  }
}

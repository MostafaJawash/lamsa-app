import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/widgets/connection_error_view.dart';
import 'package:lamsa_app/core/widgets/state_views.dart';
import 'package:lamsa_app/features/catalog/cubit/load_status.dart';
import 'package:lamsa_app/features/catalog/cubit/taxonomy_cubits.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_bits.dart';

/// A centered message that still scrolls, so pull-to-refresh keeps working.
class ScrollableMessage extends StatelessWidget {
  const ScrollableMessage({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [SizedBox(height: box.maxHeight, child: child)],
      ),
    );
  }
}

/// Categories tab: shortcuts plus the top-level category grid.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          CategoriesCubit(context.read<CatalogRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: Spacing.pageGutter,
          title: const SearchPill(),
        ),
        body: const _CategoriesBody(),
      ),
    );
  }
}

class _CategoriesBody extends StatelessWidget {
  const _CategoriesBody();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<CategoriesCubit>().load(refresh: true),
      child: BlocBuilder<CategoriesCubit, Section<List<CategoryTile>>>(
        builder: (context, section) {
          if (section.isLoading) {
            return const LoadingView(message: Strings.loading);
          }
          if (section.status == LoadStatus.failed) {
            return ScrollableMessage(
              child: section.connection
                  ? ConnectionErrorView(
                      onRetry: () => context.read<CategoriesCubit>().load(),
                    )
                  : ErrorView(
                      message: section.error ?? Strings.errorGeneric,
                      onRetry: () => context.read<CategoriesCubit>().load(),
                    ),
            );
          }
          final tiles = section.data!;
          return CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.only(top: Spacing.md),
                sliver: SliverToBoxAdapter(child: QuickLinks()),
              ),
              if (tiles.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyView(message: Strings.categoriesEmpty),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.all(Spacing.pageGutter),
                  sliver: SliverGrid.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: Spacing.md,
                    crossAxisSpacing: Spacing.md,
                    childAspectRatio: .95,
                    children: [
                      for (final t in tiles) CategoryTileView(tile: t),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// All brands (grid of logo cards).
class BrandsScreen extends StatelessWidget {
  const BrandsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          BrandsCubit(context.read<CatalogRepository>())..load(),
      child: Scaffold(
        appBar: AppBar(title: const Text(Strings.brands)),
        body: const _BrandsBody(),
      ),
    );
  }
}

class _BrandsBody extends StatelessWidget {
  const _BrandsBody();

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => context.read<BrandsCubit>().load(refresh: true),
      child: BlocBuilder<BrandsCubit, Section<List<Brand>>>(
        builder: (context, section) {
          if (section.isLoading) {
            return const LoadingView(message: Strings.loading);
          }
          if (section.status == LoadStatus.failed) {
            return ScrollableMessage(
              child: section.connection
                  ? ConnectionErrorView(
                      onRetry: () => context.read<BrandsCubit>().load(),
                    )
                  : ErrorView(
                      message: section.error ?? Strings.errorGeneric,
                      onRetry: () => context.read<BrandsCubit>().load(),
                    ),
            );
          }
          final brands = section.data!;
          if (brands.isEmpty) {
            return const ScrollableMessage(
              child: EmptyView(message: Strings.brandsEmpty),
            );
          }
          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(Spacing.pageGutter),
            // A fixed height that follows the text scale: a width-based aspect
            // ratio cut the card off whenever the own-brand line or a larger
            // system font made its content taller than the cell.
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: Spacing.md,
              crossAxisSpacing: Spacing.md,
              mainAxisExtent: _brandCardHeight(MediaQuery.textScalerOf(context)),
            ),
            itemCount: brands.length,
            itemBuilder: (context, i) => _BrandCard(brands[i]),
          );
        },
      ),
    );
  }
}

/// Card padding (2x12) + logo (72) + gap (8), plus its three text lines (name,
/// count, optional "own brand") at the user's text scale.
double _brandCardHeight(TextScaler scaler) => 108 + scaler.scale(64);

class _BrandCard extends StatelessWidget {
  const _BrandCard(this.brand);

  final Brand brand;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(Routes.brandPath(brand.slug)),
        child: Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              BrandLogo(
                id: brand.id,
                name: brand.name,
                logo: brand.logo,
                size: 72,
              ),
              const SizedBox(height: Spacing.sm),
              Text(
                brand.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.titleSmall,
              ),
              Text(
                Strings.products(brand.productCount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.bodySmall!.copyWith(color: c.muted),
              ),
              if (brand.isOwnBrand)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    Strings.brandOwn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.labelSmall!.copyWith(color: c.accent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

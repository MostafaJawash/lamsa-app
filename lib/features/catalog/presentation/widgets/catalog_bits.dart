import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/data/catalog_repository.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';

/// Search field look-alike for app bars: tapping opens the search screen.
class SearchPill extends StatelessWidget {
  const SearchPill({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Semantics(
      button: true,
      label: Strings.search,
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.lg),
        onTap: () => context.push(Routes.search),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: Spacing.md),
          decoration: BoxDecoration(
            color: c.surface2,
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: c.muted, size: 20),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  Strings.searchHint,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: c.muted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// جديد / الماركات / التخفيضات shortcuts (the web's mobile chip row).
class QuickLinks extends StatelessWidget {
  const QuickLinks({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    Widget chip(String label, String route, {bool accent = false}) => ActionChip(
          label: Text(label),
          onPressed: () => context.push(route),
          backgroundColor: accent ? c.accentSoft : c.surface,
          labelStyle: Theme.of(context).textTheme.labelMedium!.copyWith(
                color: accent ? c.accent : c.ink,
              ),
          side: BorderSide(color: accent ? c.accent : c.line),
          shape: const StadiumBorder(),
        );
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
        children: [
          chip(Strings.newArrivals, Routes.newArrivals),
          const SizedBox(width: Spacing.sm),
          chip(Strings.brands, Routes.brands),
          const SizedBox(width: Spacing.sm),
          chip(Strings.sale, Routes.sale, accent: true),
        ],
      ),
    );
  }
}

/// Category picture tile with its name underneath.
class CategoryTileView extends StatelessWidget {
  const CategoryTileView({required this.tile, super.key});

  final CategoryTile tile;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(Radii.xl),
      onTap: () => context.push(Routes.categoryPath(tile.slug)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.xl),
              child: CatalogImage(urls: tile.image),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            tile.name,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lamsa_app/core/router/routes.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/product_card_view.dart';

/// Section title with an optional "عرض الكل" action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, this.moreLabel, this.onMore, super.key});

  final String title;
  final String? moreLabel;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Spacing.pageGutter,
        Spacing.xl,
        Spacing.pageGutter,
        Spacing.sm,
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          if (onMore != null && moreLabel != null)
            TextButton(onPressed: onMore, child: Text(moreLabel!)),
        ],
      ),
    );
  }
}

/// Horizontal rail of product cards.
class ProductRail extends StatelessWidget {
  const ProductRail({required this.products, super.key});

  final List<ProductCard> products;

  static const cardWidth = 156.0;
  static const height = 292.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
        itemCount: products.length,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
        itemBuilder: (context, i) => SizedBox(
          width: cardWidth,
          child: ProductCardView(
            product: products[i],
            onTap: () => context.push('${Routes.product}/${Uri.encodeComponent(products[i].slug)}'),
          ),
        ),
      ),
    );
  }
}

/// Placeholder boxes while a rail loads.
class RailSkeleton extends StatelessWidget {
  const RailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ProductRail.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: Spacing.pageGutter),
        itemCount: 4,
        separatorBuilder: (_, _) => const SizedBox(width: Spacing.md),
        itemBuilder: (_, _) => const SizedBox(
          width: ProductRail.cardWidth,
          child: SkeletonBox(radius: Radii.xl),
        ),
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.height, this.width, this.radius = Radii.lg, super.key});

  final double? height;
  final double? width;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: context.lamsa.surface2,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// Muted one-line message used by an empty section.
class SectionMessage extends StatelessWidget {
  const SectionMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.pageGutter,
          vertical: Spacing.lg,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(Spacing.xl),
          decoration: BoxDecoration(
            color: context.lamsa.surface,
            border: Border.all(color: context.lamsa.line),
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: context.lamsa.muted),
          ),
        ),
      );
}

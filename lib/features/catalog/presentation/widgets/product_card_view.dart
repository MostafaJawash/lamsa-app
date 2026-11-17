import 'package:flutter/material.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';
import 'package:lamsa_app/features/catalog/presentation/widgets/catalog_art.dart';
import 'package:lamsa_app/features/favorites/presentation/favorite_button.dart';

/// Price with the struck-through regular price when on sale. Currencies are
/// shown as the backend sent them: nothing is converted or summed.
class PriceText extends StatelessWidget {
  const PriceText({
    required this.price,
    required this.currency,
    this.compareAt,
    this.large = false,
    super.key,
  });

  final String price;
  final String? compareAt;
  final String currency;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final nowStyle = (large ? theme.titleLarge : theme.titleSmall)!.copyWith(
      color: compareAt != null ? c.accent : c.ink,
      fontWeight: FontWeight.w700,
    );
    return Wrap(
      spacing: Spacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (compareAt != null)
          Text(
            formatAmount(compareAt!, currency),
            style: theme.bodySmall!.copyWith(
              color: c.muted,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        Text(formatAmount(price, currency), style: nowStyle),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text, this.background, this.foreground);

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .labelSmall!
            .copyWith(color: foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// "−25٪" badge, isolated so the sign stays in front of the number.
class DiscountBadge extends StatelessWidget {
  const DiscountBadge(this.percent, {super.key});

  final int percent;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: _Badge(Strings.discountBadge(percent), c.danger, c.accentInk),
    );
  }
}

/// Catalog card used by grids and rails. Sold-out products are dimmed with a
/// "نفدت الكمية" badge. The heart is visible but not built yet (snackbar).
class ProductCardView extends StatelessWidget {
  const ProductCardView({required this.product, required this.onTap, super.key});

  final ProductCard product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final theme = Theme.of(context).textTheme;
    final soldOut = !product.inStock;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: soldOut ? .6 : 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CatalogImage(urls: product.image),
                    PositionedDirectional(
                      top: Spacing.sm,
                      start: Spacing.sm,
                      child: Wrap(
                        direction: Axis.vertical,
                        spacing: 4,
                        children: [
                          if (product.isNew)
                            _Badge(Strings.cardNew, c.ink, c.surface),
                          if (product.discountPercent != null &&
                              product.discountPercent! > 0)
                            DiscountBadge(product.discountPercent!),
                          if (soldOut)
                            _Badge(Strings.cardSoldOut, c.muted, c.surface),
                        ],
                      ),
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: FavoriteButton(
                        productId: product.id,
                        slug: product.slug,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(Spacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.brand != null)
                      Text(
                        product.brand!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.labelSmall!.copyWith(color: c.muted),
                      ),
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.bodyMedium!
                          .copyWith(fontWeight: FontWeight.w600, height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    PriceText(
                      price: product.price,
                      compareAt: product.compareAtPrice,
                      currency: product.currency,
                    ),
                    if (product.swatches.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Semantics(
                        label: Strings.cardColors,
                        child: Wrap(
                          spacing: 4,
                          children: [
                            for (final s in product.swatches)
                              Tooltip(
                                message: s.name,
                                child: _Dot(hexColor(s.hex), size: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot(this.color, {required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.lamsa.line),
        ),
      );
}

/// `#RRGGBB` / `#RGB` to a color; neutral grey when malformed.
Color hexColor(String? hex) {
  var h = (hex ?? '').replaceFirst('#', '').trim();
  if (h.length == 3) h = h.split('').map((ch) => '$ch$ch').join();
  final value = h.length == 6 ? int.tryParse(h, radix: 16) : null;
  return value == null ? const Color(0xFFCCCCCC) : Color(0xFF000000 | value);
}

import 'package:lamsa_app/features/catalog/data/models/catalog_models.dart';

/// Pure port of lamsa-web's `variants.ts`: variant selection, price, stock
/// and gallery rules of the product screen.

/// Default selection: the first variant that is not out of stock, else the
/// first one. `null` for products without variants.
int? defaultVariantId(ProductDetail product) {
  if (product.variants.isEmpty) return null;
  final inStock =
      product.variants.where((v) => v.stockStatus != StockStatus.out);
  return (inStock.firstOrNull ?? product.variants.first).id;
}

Variant? findVariant(ProductDetail product, int? id) {
  for (final v in product.variants) {
    if (v.id == id) return v;
  }
  return null;
}

/// The variant to select when the shopper picks [value] for option [key]:
/// the one that keeps the other current choices, else any variant with that
/// value (in stock first), else [current].
Variant? pickVariant(
  ProductDetail product,
  Variant? current,
  String key,
  String value,
) {
  final candidates =
      product.variants.where((v) => v.options[key] == value).toList();
  if (candidates.isEmpty) return current;
  bool keepsOthers(Variant v) => product.variantOptions.every(
        (o) =>
            o.key == key ||
            current == null ||
            v.options[o.key] == current.options[o.key],
      );
  return candidates.where(keepsOthers).firstOrNull ??
      candidates.where((v) => v.stockStatus != StockStatus.out).firstOrNull ??
      candidates.first;
}

/// The variant a value leads to (for its price and availability), or null
/// when no variant has it.
Variant? variantForValue(
  ProductDetail product,
  Variant? current,
  String key,
  String value,
) {
  final picked = pickVariant(product, current, key, value);
  return picked != null && picked.options[key] == value ? picked : null;
}

/// Prices of the selected variant, or of a simple product / bundle.
/// Amounts are the backend's decimal strings; [currency] is theirs.
final class PriceView {
  const PriceView({
    required this.current,
    required this.currency,
    this.regular,
    this.savings,
  });

  final String current;
  final String currency;

  /// The struck-through price when on sale, else null.
  final String? regular;

  /// regular − current ("وفّر"), else null.
  final String? savings;
}

int _cents(String amount) {
  final parts = amount.split('.');
  final whole = int.tryParse(parts.first) ?? 0;
  final fraction =
      int.tryParse((parts.length > 1 ? parts[1] : '').padRight(2, '0').substring(0, 2)) ??
          0;
  return whole * 100 + fraction;
}

String _fromCents(int cents) =>
    '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';

PriceView priceView(ProductDetail product, Variant? variant) {
  final String current;
  final String? regular;
  final String currency;
  if (variant != null) {
    current = variant.currentPrice;
    regular = variant.salePrice != null ? variant.price : null;
    currency = variant.currency;
  } else {
    current = product.currentPrice ?? product.price;
    regular = product.salePrice != null
        ? (product.regularPrice ?? product.compareAtPrice)
        : null;
    currency = product.currency;
  }
  final saved = regular != null && _cents(regular) > _cents(current)
      ? _cents(regular) - _cents(current)
      : null;
  return PriceView(
    current: current,
    currency: currency,
    regular: saved != null ? regular : null,
    savings: saved != null ? _fromCents(saved) : null,
  );
}

final class StockView {
  const StockView(this.status, this.left);

  final StockStatus status;

  /// Only set for [StockStatus.low] (the backend never exposes real stock).
  final int? left;
}

StockView stockView(ProductDetail product, Variant? variant) {
  if (variant != null) return StockView(variant.stockStatus, variant.stockLeft);
  return StockView(
    product.stockStatus ??
        (product.inStock ? StockStatus.inStock : StockStatus.out),
    product.stockLeft,
  );
}

/// Images to show: the variant's `image_ids` in that order; otherwise the
/// general images (not tied to a variant), or every image when there are no
/// general ones.
List<ProductImage> imagesFor(ProductDetail product, Variant? variant) {
  if (variant != null && variant.imageIds.isNotEmpty) {
    final byId = {for (final i in product.images) i.id: i};
    final ordered = [
      for (final id in variant.imageIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (ordered.isNotEmpty) return ordered;
  }
  final general = product.images.where((i) => i.variantId == null).toList();
  return general.isNotEmpty ? general : product.images;
}

/// Largest quantity for the stepper: 1..10, bounded by the stock left (only
/// known for the backend's `low` status). A sold-out item allows 1 (the add
/// button is disabled anyway).
int maxQuantity(StockView stock) {
  if (stock.status == StockStatus.out) return 1;
  final left = stock.left ?? 10;
  return left.clamp(1, 10);
}

import 'dart:convert';

import 'package:equatable/equatable.dart';

/// The guest cart and favorites, kept on the device. Port of lamsa-web's
/// `guest-codec.ts` (same shape and limits), as a small versioned JSON blob.
///
/// - cart: `[[product_id, variant_id or 0, quantity, product_slug], ...]`,
///   at most [GuestLimits.cartLines] lines, quantity 1..[GuestLimits.maxQuantity];
/// - favorites: `[[product_id, product_slug], ...]`, oldest first, at most
///   [GuestLimits.favorites].
///
/// Nothing here is trusted: prices, stock and visibility always come from the
/// backend (`POST /cart/preview`, `GET /products?ids=`). The slug is only a hint
/// for links.
abstract final class GuestLimits {
  static const cartLines = 50;
  static const favorites = 200;
  static const maxQuantity = 99;
}

const guestStoreVersion = 1;

final class GuestCartItem extends Equatable {
  const GuestCartItem({
    required this.productId,
    required this.quantity,
    this.variantId,
    this.slug = '',
  });

  final int productId;
  final int? variantId;
  final int quantity;
  final String slug;

  String get key => cartKey(productId, variantId);

  GuestCartItem withQuantity(int q) => GuestCartItem(
        productId: productId,
        variantId: variantId,
        quantity: q,
        slug: slug,
      );

  @override
  List<Object?> get props => [productId, variantId, quantity, slug];
}

final class GuestFavorite extends Equatable {
  const GuestFavorite({required this.productId, this.slug = ''});

  final int productId;
  final String slug;

  @override
  List<Object?> get props => [productId, slug];
}

/// `<product_id>:<variant_id or 0>`, the backend preview's line key.
String cartKey(int productId, int? variantId) =>
    '$productId:${variantId ?? 0}';

/// `{productId, variantId}` of a line key, or null when it is not one.
({int productId, int? variantId})? parseCartKey(String? key) {
  final m = RegExp(r'^(\d{1,15}):(\d{1,15})$').firstMatch(key ?? '');
  if (m == null) return null;
  final product = int.parse(m.group(1)!);
  final variant = int.parse(m.group(2)!);
  if (product <= 0) return null;
  return (productId: product, variantId: variant == 0 ? null : variant);
}

bool _isId(Object? v) => v is int && v > 0;

String? _cleanSlug(Object? v) {
  if (v is! String || v.length > 200) return null;
  return RegExp(r'[\u0000-\u001f\u007f]').hasMatch(v) ? null : v;
}

List<Object?>? _entries(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic> &&
        json['v'] == guestStoreVersion &&
        json['items'] is List) {
      return json['items'] as List<Object?>;
    }
  } on FormatException {
    return null;
  }
  return null;
}

/// Tolerant: unreadable or invalid entries are dropped, duplicates merge
/// (quantities add up, capped), and the limits are enforced.
List<GuestCartItem> decodeCart(String? raw) {
  final entries = _entries(raw);
  if (entries == null) return const [];
  final byKey = <String, GuestCartItem>{};
  for (final e in entries) {
    if (e is! List || e.length < 3) continue;
    final product = e[0];
    final variant = e[1];
    final quantity = e[2];
    final slug = _cleanSlug(e.length > 3 ? e[3] : '');
    if (!_isId(product) || !(variant == 0 || _isId(variant))) continue;
    if (!_isId(quantity) || slug == null) continue;
    final variantId = variant == 0 ? null : variant as int;
    final key = cartKey(product as int, variantId);
    final total = ((byKey[key]?.quantity ?? 0) + (quantity as int))
        .clamp(1, GuestLimits.maxQuantity);
    byKey[key] = GuestCartItem(
      productId: product,
      variantId: variantId,
      quantity: total,
      slug: slug,
    );
  }
  return byKey.values.take(GuestLimits.cartLines).toList();
}

String encodeCart(List<GuestCartItem> items) => jsonEncode({
      'v': guestStoreVersion,
      'items': [
        for (final i in items) [i.productId, i.variantId ?? 0, i.quantity, i.slug],
      ],
    });

/// Oldest first; over the limit, the newest are kept.
List<GuestFavorite> decodeFavorites(String? raw) {
  final entries = _entries(raw);
  if (entries == null) return const [];
  final byId = <int, GuestFavorite>{};
  for (final e in entries) {
    if (e is! List || e.isEmpty) continue;
    final slug = _cleanSlug(e.length > 1 ? e[1] : '');
    if (!_isId(e[0]) || slug == null || byId.containsKey(e[0])) continue;
    byId[e[0] as int] = GuestFavorite(productId: e[0] as int, slug: slug);
  }
  final all = byId.values.toList();
  return all.length > GuestLimits.favorites
      ? all.sublist(all.length - GuestLimits.favorites)
      : all;
}

String encodeFavorites(List<GuestFavorite> items) => jsonEncode({
      'v': guestStoreVersion,
      'items': [
        for (final i in items) [i.productId, i.slug],
      ],
    });

/// Total quantity in the guest cart (the badge).
int cartQuantity(List<GuestCartItem> items) =>
    items.fold(0, (sum, i) => sum + i.quantity);

/// The cart with (product, variant) set to [quantity] (clamped; appended when new).
List<GuestCartItem> setCartQuantity(
  List<GuestCartItem> items,
  GuestCartItem item,
  int quantity,
) {
  final key = item.key;
  final next = quantity.clamp(1, GuestLimits.maxQuantity);
  if (!items.any((i) => i.key == key)) {
    return [...items, item.withQuantity(next)];
  }
  return [
    for (final i in items)
      if (i.key == key)
        GuestCartItem(
          productId: i.productId,
          variantId: i.variantId,
          quantity: next,
          slug: item.slug.isNotEmpty ? item.slug : i.slug,
        )
      else
        i,
  ];
}

List<GuestCartItem> removeCartLine(List<GuestCartItem> items, String key) =>
    [for (final i in items) if (i.key != key) i];

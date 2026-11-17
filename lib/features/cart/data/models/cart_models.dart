import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:lamsa_app/core/images/image_urls.dart';

part 'cart_models.g.dart';

/// A money amount of one currency. Lists of these are always one entry per
/// currency (SYP first, then USD): they are never added together.
@JsonSerializable(fieldRename: FieldRename.snake)
final class CurrencyAmount extends Equatable {
  const CurrencyAmount({required this.currency, required this.amount});

  factory CurrencyAmount.fromJson(Map<String, dynamic> json) =>
      _$CurrencyAmountFromJson(json);

  final String currency;
  final String amount;

  Map<String, dynamic> toJson() => _$CurrencyAmountToJson(this);

  @override
  List<Object?> get props => [currency, amount];
}

@JsonSerializable(fieldRename: FieldRename.snake)
final class CartBrand extends Equatable {
  const CartBrand({required this.name, required this.slug});

  factory CartBrand.fromJson(Map<String, dynamic> json) =>
      _$CartBrandFromJson(json);

  final String name;
  final String slug;

  Map<String, dynamic> toJson() => _$CartBrandToJson(this);

  @override
  List<Object?> get props => [name, slug];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class CartProduct extends Equatable {
  const CartProduct({
    required this.id,
    required this.slug,
    required this.name,
    this.type = 'simple',
    this.brand,
  });

  factory CartProduct.fromJson(Map<String, dynamic> json) =>
      _$CartProductFromJson(json);

  final int id;

  /// Empty for a product that no longer exists (an `UNAVAILABLE` line).
  final String slug;
  final String name;
  final String type;
  final CartBrand? brand;

  Map<String, dynamic> toJson() => _$CartProductToJson(this);

  @override
  List<Object?> get props => [id, slug, name, type, brand];
}

@JsonSerializable(fieldRename: FieldRename.snake)
final class CartVariant extends Equatable {
  const CartVariant({
    required this.id,
    required this.label,
    this.options = const {},
  });

  factory CartVariant.fromJson(Map<String, dynamic> json) =>
      _$CartVariantFromJson(json);

  final int id;
  final String label;
  final Map<String, String> options;

  Map<String, dynamic> toJson() => _$CartVariantToJson(this);

  @override
  List<Object?> get props => [id, label, options];
}

@JsonSerializable(fieldRename: FieldRename.snake)
final class CartBundleItem extends Equatable {
  const CartBundleItem({
    required this.name,
    required this.quantity,
    this.variantLabel,
  });

  factory CartBundleItem.fromJson(Map<String, dynamic> json) =>
      _$CartBundleItemFromJson(json);

  final String name;
  final String? variantLabel;
  final int quantity;

  Map<String, dynamic> toJson() => _$CartBundleItemToJson(this);

  @override
  List<Object?> get props => [name, variantLabel, quantity];
}

/// Why a line cannot be bought as it is (reported on reads, not an error).
@JsonSerializable(fieldRename: FieldRename.snake)
final class LineIssue extends Equatable {
  const LineIssue({
    required this.code,
    required this.message,
    this.available,
    this.max,
  });

  factory LineIssue.fromJson(Map<String, dynamic> json) =>
      _$LineIssueFromJson(json);

  /// `UNAVAILABLE | VARIANT_UNAVAILABLE | OUT_OF_STOCK | INSUFFICIENT_STOCK |
  /// QUANTITY_LIMIT_EXCEEDED`.
  final String code;
  final String message;
  final int? available;
  final int? max;

  Map<String, dynamic> toJson() => _$LineIssueToJson(this);

  @override
  List<Object?> get props => [code, message, available, max];
}

/// One cart line, from `GET /cart` (has `id`) or `POST /cart/preview` (has
/// `key`). [ref] addresses it for updates either way.
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class CartLine extends Equatable {
  const CartLine({
    required this.quantity,
    required this.product,
    required this.currency,
    required this.unitPrice,
    required this.regularPrice,
    required this.lineTotal,
    this.id,
    this.key,
    this.variant,
    this.image,
    this.compareAtPrice,
    this.discountPercent,
    this.stockStatus = 'in_stock',
    this.stockLeft,
    this.items = const [],
    this.issue,
  });

  factory CartLine.fromJson(Map<String, dynamic> json) =>
      _$CartLineFromJson(json);

  final int? id;
  final String? key;
  final int quantity;
  final CartProduct product;
  final CartVariant? variant;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final String currency;
  final String unitPrice;
  final String regularPrice;
  final String? compareAtPrice;
  final int? discountPercent;

  /// 0.00 for a line with an issue (it is not counted in the subtotal).
  final String lineTotal;
  final String stockStatus;
  final int? stockLeft;
  final List<CartBundleItem> items;
  final LineIssue? issue;

  /// What the line is addressed by: the database id (stored cart) or the
  /// preview key (`<product_id>:<variant_id or 0>`).
  String get ref => id != null ? '$id' : (key ?? '${product.id}:${variant?.id ?? 0}');

  CartLine withQuantity(int q) => CartLine(
        id: id,
        key: key,
        quantity: q,
        product: product,
        variant: variant,
        image: image,
        currency: currency,
        unitPrice: unitPrice,
        regularPrice: regularPrice,
        lineTotal: lineTotal,
        compareAtPrice: compareAtPrice,
        discountPercent: discountPercent,
        stockStatus: stockStatus,
        stockLeft: stockLeft,
        items: items,
        issue: issue,
      );

  Map<String, dynamic> toJson() => _$CartLineToJson(this);

  @override
  List<Object?> get props => [
        id,
        key,
        quantity,
        product,
        variant,
        image,
        currency,
        unitPrice,
        regularPrice,
        compareAtPrice,
        discountPercent,
        lineTotal,
        stockStatus,
        stockLeft,
        items,
        issue,
      ];
}

/// What the request that changed the cart reports (not errors).
@JsonSerializable(fieldRename: FieldRename.snake)
final class CartNotice extends Equatable {
  const CartNotice({
    required this.code,
    required this.message,
    this.itemId,
    this.productId,
    this.fromQuantity,
    this.toQuantity,
    this.reason,
  });

  factory CartNotice.fromJson(Map<String, dynamic> json) =>
      _$CartNoticeFromJson(json);

  /// `QUANTITY_CAPPED | LINES_MERGED | LINE_REMOVED`.
  final String code;
  final String message;
  final int? itemId;
  final int? productId;
  final int? fromQuantity;
  final int? toQuantity;
  final String? reason;

  Map<String, dynamic> toJson() => _$CartNoticeToJson(this);

  @override
  List<Object?> get props =>
      [code, message, itemId, productId, fromQuantity, toQuantity, reason];
}

/// The whole cart, computed by the backend: stored (`CartOut`), a guest
/// preview (`CartPreviewOut`) or the result of a merge. Totals are one amount
/// per currency and are never combined on the device.
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class Cart extends Equatable {
  const Cart({
    this.lines = const [],
    this.itemsCount = 0,
    this.linesCount = 0,
    this.subtotals = const [],
    this.savings = const [],
    this.totals = const [],
    this.canCheckout = false,
    this.issuesCount = 0,
    this.notices = const [],
  });

  factory Cart.fromJson(Map<String, dynamic> json) => _$CartFromJson(json);

  static const empty = Cart();

  final List<CartLine> lines;

  /// Total quantity of lines without an issue.
  final int itemsCount;
  final int linesCount;
  final List<CurrencyAmount> subtotals;
  final List<CurrencyAmount> savings;
  final List<CurrencyAmount> totals;
  final bool canCheckout;
  final int issuesCount;
  final List<CartNotice> notices;

  Cart copyWith({List<CartLine>? lines}) => Cart(
        lines: lines ?? this.lines,
        itemsCount: itemsCount,
        linesCount: lines?.length ?? linesCount,
        subtotals: subtotals,
        savings: savings,
        totals: totals,
        canCheckout: canCheckout,
        issuesCount: issuesCount,
        notices: notices,
      );

  Map<String, dynamic> toJson() => _$CartToJson(this);

  @override
  List<Object?> get props => [
        lines,
        itemsCount,
        linesCount,
        subtotals,
        savings,
        totals,
        canCheckout,
        issuesCount,
        notices,
      ];
}

/// One entry of `merge_report`: what happened to a guest line.
@JsonSerializable(fieldRename: FieldRename.snake)
final class MergeReportItem extends Equatable {
  const MergeReportItem({
    required this.index,
    required this.status,
    required this.quantity,
    this.productId,
    this.variantId,
    this.reason,
  });

  factory MergeReportItem.fromJson(Map<String, dynamic> json) =>
      _$MergeReportItemFromJson(json);

  final int index;
  final int? productId;
  final int? variantId;

  /// `added | merged | capped | skipped`.
  final String status;
  final String? reason;
  final int quantity;

  Map<String, dynamic> toJson() => _$MergeReportItemToJson(this);

  @override
  List<Object?> get props =>
      [index, productId, variantId, status, reason, quantity];
}

/// Response of `POST /cart/merge`: the whole cart plus the report.
final class CartMergeResult extends Equatable {
  const CartMergeResult({required this.cart, required this.report});

  factory CartMergeResult.fromJson(Map<String, dynamic> json) =>
      CartMergeResult(
        cart: Cart.fromJson(json),
        report: [
          for (final r in (json['merge_report'] as List<dynamic>? ?? const []))
            MergeReportItem.fromJson(r as Map<String, dynamic>),
        ],
      );

  final Cart cart;
  final List<MergeReportItem> report;

  /// Lines that ended up in the cart (added, merged or capped).
  int get restored => report.where((r) => r.status != 'skipped').length;

  /// Something was capped or skipped.
  bool get adjusted =>
      report.any((r) => r.status == 'capped' || r.status == 'skipped');

  @override
  List<Object?> get props => [cart, report];
}

@JsonSerializable(fieldRename: FieldRename.snake)
final class SkippedFavorite extends Equatable {
  const SkippedFavorite({required this.productId, required this.reason});

  factory SkippedFavorite.fromJson(Map<String, dynamic> json) =>
      _$SkippedFavoriteFromJson(json);

  final int productId;
  final String reason;

  Map<String, dynamic> toJson() => _$SkippedFavoriteToJson(this);

  @override
  List<Object?> get props => [productId, reason];
}

/// Response of `POST /favorites/merge`.
final class FavoritesMergeResult extends Equatable {
  const FavoritesMergeResult({this.added = 0, this.skipped = const []});

  factory FavoritesMergeResult.fromJson(Map<String, dynamic> json) {
    final added = json['added'];
    return FavoritesMergeResult(
      added: added is List ? added.length : (added is int ? added : 0),
      skipped: [
        for (final s in (json['skipped'] as List<dynamic>? ?? const []))
          SkippedFavorite.fromJson(s as Map<String, dynamic>),
      ],
    );
  }

  final int added;
  final List<SkippedFavorite> skipped;

  @override
  List<Object?> get props => [added, skipped];
}

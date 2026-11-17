// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

CurrencyAmount _$CurrencyAmountFromJson(Map<String, dynamic> json) =>
    CurrencyAmount(
      currency: json['currency'] as String,
      amount: json['amount'] as String,
    );

Map<String, dynamic> _$CurrencyAmountToJson(CurrencyAmount instance) =>
    <String, dynamic>{'currency': instance.currency, 'amount': instance.amount};

CartBrand _$CartBrandFromJson(Map<String, dynamic> json) =>
    CartBrand(name: json['name'] as String, slug: json['slug'] as String);

Map<String, dynamic> _$CartBrandToJson(CartBrand instance) => <String, dynamic>{
  'name': instance.name,
  'slug': instance.slug,
};

CartProduct _$CartProductFromJson(Map<String, dynamic> json) => CartProduct(
  id: (json['id'] as num).toInt(),
  slug: json['slug'] as String,
  name: json['name'] as String,
  type: json['type'] as String? ?? 'simple',
  brand: json['brand'] == null
      ? null
      : CartBrand.fromJson(json['brand'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CartProductToJson(CartProduct instance) =>
    <String, dynamic>{
      'id': instance.id,
      'slug': instance.slug,
      'name': instance.name,
      'type': instance.type,
      'brand': instance.brand?.toJson(),
    };

CartVariant _$CartVariantFromJson(Map<String, dynamic> json) => CartVariant(
  id: (json['id'] as num).toInt(),
  label: json['label'] as String,
  options:
      (json['options'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, e as String),
      ) ??
      const {},
);

Map<String, dynamic> _$CartVariantToJson(CartVariant instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'options': instance.options,
    };

CartBundleItem _$CartBundleItemFromJson(Map<String, dynamic> json) =>
    CartBundleItem(
      name: json['name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      variantLabel: json['variant_label'] as String?,
    );

Map<String, dynamic> _$CartBundleItemToJson(CartBundleItem instance) =>
    <String, dynamic>{
      'name': instance.name,
      'variant_label': instance.variantLabel,
      'quantity': instance.quantity,
    };

LineIssue _$LineIssueFromJson(Map<String, dynamic> json) => LineIssue(
  code: json['code'] as String,
  message: json['message'] as String,
  available: (json['available'] as num?)?.toInt(),
  max: (json['max'] as num?)?.toInt(),
);

Map<String, dynamic> _$LineIssueToJson(LineIssue instance) => <String, dynamic>{
  'code': instance.code,
  'message': instance.message,
  'available': instance.available,
  'max': instance.max,
};

CartLine _$CartLineFromJson(Map<String, dynamic> json) => CartLine(
  quantity: (json['quantity'] as num).toInt(),
  product: CartProduct.fromJson(json['product'] as Map<String, dynamic>),
  currency: json['currency'] as String,
  unitPrice: json['unit_price'] as String,
  regularPrice: json['regular_price'] as String,
  lineTotal: json['line_total'] as String,
  id: (json['id'] as num?)?.toInt(),
  key: json['key'] as String?,
  variant: json['variant'] == null
      ? null
      : CartVariant.fromJson(json['variant'] as Map<String, dynamic>),
  image: ImageUrls.fromJson(json['image']),
  compareAtPrice: json['compare_at_price'] as String?,
  discountPercent: (json['discount_percent'] as num?)?.toInt(),
  stockStatus: json['stock_status'] as String? ?? 'in_stock',
  stockLeft: (json['stock_left'] as num?)?.toInt(),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => CartBundleItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  issue: json['issue'] == null
      ? null
      : LineIssue.fromJson(json['issue'] as Map<String, dynamic>),
);

Map<String, dynamic> _$CartLineToJson(CartLine instance) => <String, dynamic>{
  'id': instance.id,
  'key': instance.key,
  'quantity': instance.quantity,
  'product': instance.product.toJson(),
  'variant': instance.variant?.toJson(),
  'image': instance.image?.toJson(),
  'currency': instance.currency,
  'unit_price': instance.unitPrice,
  'regular_price': instance.regularPrice,
  'compare_at_price': instance.compareAtPrice,
  'discount_percent': instance.discountPercent,
  'line_total': instance.lineTotal,
  'stock_status': instance.stockStatus,
  'stock_left': instance.stockLeft,
  'items': instance.items.map((e) => e.toJson()).toList(),
  'issue': instance.issue?.toJson(),
};

CartNotice _$CartNoticeFromJson(Map<String, dynamic> json) => CartNotice(
  code: json['code'] as String,
  message: json['message'] as String,
  itemId: (json['item_id'] as num?)?.toInt(),
  productId: (json['product_id'] as num?)?.toInt(),
  fromQuantity: (json['from_quantity'] as num?)?.toInt(),
  toQuantity: (json['to_quantity'] as num?)?.toInt(),
  reason: json['reason'] as String?,
);

Map<String, dynamic> _$CartNoticeToJson(CartNotice instance) =>
    <String, dynamic>{
      'code': instance.code,
      'message': instance.message,
      'item_id': instance.itemId,
      'product_id': instance.productId,
      'from_quantity': instance.fromQuantity,
      'to_quantity': instance.toQuantity,
      'reason': instance.reason,
    };

DeliveryQuote _$DeliveryQuoteFromJson(Map<String, dynamic> json) =>
    DeliveryQuote(
      code: json['code'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String,
      description: json['description'] as String?,
      fee: json['fee'] as String? ?? '0.00',
      isFree: json['is_free'] as bool? ?? false,
      freeFrom: json['free_from'] as String?,
      amountToFreeShipping: json['amount_to_free_shipping'] as String?,
      requiresAddress: json['requires_address'] as bool? ?? true,
      feePaidToCarrier: json['fee_paid_to_carrier'] as bool? ?? false,
      totals:
          (json['totals'] as List<dynamic>?)
              ?.map((e) => CurrencyAmount.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );

Map<String, dynamic> _$DeliveryQuoteToJson(DeliveryQuote instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'description': instance.description,
      'currency': instance.currency,
      'fee': instance.fee,
      'is_free': instance.isFree,
      'free_from': instance.freeFrom,
      'amount_to_free_shipping': instance.amountToFreeShipping,
      'requires_address': instance.requiresAddress,
      'fee_paid_to_carrier': instance.feePaidToCarrier,
      'totals': instance.totals.map((e) => e.toJson()).toList(),
    };

Cart _$CartFromJson(Map<String, dynamic> json) => Cart(
  lines:
      (json['lines'] as List<dynamic>?)
          ?.map((e) => CartLine.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
  linesCount: (json['lines_count'] as num?)?.toInt() ?? 0,
  subtotals:
      (json['subtotals'] as List<dynamic>?)
          ?.map((e) => CurrencyAmount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  savings:
      (json['savings'] as List<dynamic>?)
          ?.map((e) => CurrencyAmount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  totals:
      (json['totals'] as List<dynamic>?)
          ?.map((e) => CurrencyAmount.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  canCheckout: json['can_checkout'] as bool? ?? false,
  issuesCount: (json['issues_count'] as num?)?.toInt() ?? 0,
  notices:
      (json['notices'] as List<dynamic>?)
          ?.map((e) => CartNotice.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  deliveryQuotes:
      (json['delivery_quotes'] as List<dynamic>?)
          ?.map((e) => DeliveryQuote.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  selectedDeliveryMethodCode: json['selected_delivery_method_code'] as String?,
);

Map<String, dynamic> _$CartToJson(Cart instance) => <String, dynamic>{
  'lines': instance.lines.map((e) => e.toJson()).toList(),
  'items_count': instance.itemsCount,
  'lines_count': instance.linesCount,
  'subtotals': instance.subtotals.map((e) => e.toJson()).toList(),
  'savings': instance.savings.map((e) => e.toJson()).toList(),
  'totals': instance.totals.map((e) => e.toJson()).toList(),
  'can_checkout': instance.canCheckout,
  'issues_count': instance.issuesCount,
  'notices': instance.notices.map((e) => e.toJson()).toList(),
  'delivery_quotes': instance.deliveryQuotes.map((e) => e.toJson()).toList(),
  'selected_delivery_method_code': instance.selectedDeliveryMethodCode,
};

MergeReportItem _$MergeReportItemFromJson(Map<String, dynamic> json) =>
    MergeReportItem(
      index: (json['index'] as num).toInt(),
      status: json['status'] as String,
      quantity: (json['quantity'] as num).toInt(),
      productId: (json['product_id'] as num?)?.toInt(),
      variantId: (json['variant_id'] as num?)?.toInt(),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$MergeReportItemToJson(MergeReportItem instance) =>
    <String, dynamic>{
      'index': instance.index,
      'product_id': instance.productId,
      'variant_id': instance.variantId,
      'status': instance.status,
      'reason': instance.reason,
      'quantity': instance.quantity,
    };

SkippedFavorite _$SkippedFavoriteFromJson(Map<String, dynamic> json) =>
    SkippedFavorite(
      productId: (json['product_id'] as num).toInt(),
      reason: json['reason'] as String,
    );

Map<String, dynamic> _$SkippedFavoriteToJson(SkippedFavorite instance) =>
    <String, dynamic>{
      'product_id': instance.productId,
      'reason': instance.reason,
    };

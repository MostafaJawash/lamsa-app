// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OrderTotal _$OrderTotalFromJson(Map<String, dynamic> json) => OrderTotal(
  currency: json['currency'] as String,
  subtotal: json['subtotal'] as String,
  shippingFee: json['shipping_fee'] as String,
  total: json['total'] as String,
  discount: json['discount'] as String? ?? '0.00',
  isLegacy: json['is_legacy'] as bool? ?? false,
);

Map<String, dynamic> _$OrderTotalToJson(OrderTotal instance) =>
    <String, dynamic>{
      'currency': instance.currency,
      'subtotal': instance.subtotal,
      'discount': instance.discount,
      'shipping_fee': instance.shippingFee,
      'total': instance.total,
      'is_legacy': instance.isLegacy,
    };

OrderDelivery _$OrderDeliveryFromJson(Map<String, dynamic> json) =>
    OrderDelivery(
      code: json['code'] as String,
      name: json['name'] as String,
      currency: json['currency'] as String? ?? 'SYP',
      feePaidToCarrier: json['fee_paid_to_carrier'] as bool? ?? false,
    );

Map<String, dynamic> _$OrderDeliveryToJson(OrderDelivery instance) =>
    <String, dynamic>{
      'code': instance.code,
      'name': instance.name,
      'currency': instance.currency,
      'fee_paid_to_carrier': instance.feePaidToCarrier,
    };

OrderItem _$OrderItemFromJson(Map<String, dynamic> json) => OrderItem(
  name: json['name'] as String,
  currency: json['currency'] as String,
  unitPrice: json['unit_price'] as String,
  quantity: (json['quantity'] as num).toInt(),
  lineTotal: json['line_total'] as String,
  productId: (json['product_id'] as num?)?.toInt(),
  productSlug: json['product_slug'] as String?,
  variantLabel: json['variant_label'] as String?,
  image: ImageUrls.fromJson(json['image']),
  bundleContents: (json['bundle_contents'] as List<dynamic>?)
      ?.map((e) => e as Map<String, dynamic>)
      .toList(),
);

Map<String, dynamic> _$OrderItemToJson(OrderItem instance) => <String, dynamic>{
  'product_id': instance.productId,
  'product_slug': instance.productSlug,
  'name': instance.name,
  'variant_label': instance.variantLabel,
  'image': instance.image,
  'currency': instance.currency,
  'unit_price': instance.unitPrice,
  'quantity': instance.quantity,
  'line_total': instance.lineTotal,
  'bundle_contents': instance.bundleContents,
};

TimelineStep _$TimelineStepFromJson(Map<String, dynamic> json) => TimelineStep(
  status: json['status'] as String,
  label: json['label'] as String,
  reachedAt: parseBackendDateOrNull(json['reached_at']),
  isCurrent: json['is_current'] as bool? ?? false,
  cancelReason: json['cancel_reason'] as String?,
);

Map<String, dynamic> _$TimelineStepToJson(TimelineStep instance) =>
    <String, dynamic>{
      'status': instance.status,
      'label': instance.label,
      'reached_at': instance.reachedAt?.toIso8601String(),
      'is_current': instance.isCurrent,
      'cancel_reason': instance.cancelReason,
    };

OrderSummary _$OrderSummaryFromJson(Map<String, dynamic> json) => OrderSummary(
  id: (json['id'] as num).toInt(),
  createdAt: parseBackendDate(json['created_at']),
  status: json['status'] as String,
  statusLabel: json['status_label'] as String,
  itemsCount: (json['items_count'] as num?)?.toInt() ?? 0,
  totals:
      (json['totals'] as List<dynamic>?)
          ?.map((e) => OrderTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  image: ImageUrls.fromJson(json['image']),
  deliveryMethodName: json['delivery_method_name'] as String? ?? '',
);

Map<String, dynamic> _$OrderSummaryToJson(OrderSummary instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'status': instance.status,
      'status_label': instance.statusLabel,
      'items_count': instance.itemsCount,
      'totals': instance.totals.map((e) => e.toJson()).toList(),
      'image': instance.image?.toJson(),
      'delivery_method_name': instance.deliveryMethodName,
    };

OrderPage _$OrderPageFromJson(Map<String, dynamic> json) => OrderPage(
  items: (json['items'] as List<dynamic>)
      .map((e) => OrderSummary.fromJson(e as Map<String, dynamic>))
      .toList(),
  page: (json['page'] as num).toInt(),
  pageSize: (json['page_size'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$OrderPageToJson(OrderPage instance) => <String, dynamic>{
  'items': instance.items.map((e) => e.toJson()).toList(),
  'page': instance.page,
  'page_size': instance.pageSize,
  'total': instance.total,
};

OrderDetail _$OrderDetailFromJson(Map<String, dynamic> json) => OrderDetail(
  id: (json['id'] as num).toInt(),
  createdAt: parseBackendDate(json['created_at']),
  status: json['status'] as String,
  statusLabel: json['status_label'] as String,
  delivery: OrderDelivery.fromJson(json['delivery'] as Map<String, dynamic>),
  paymentMethod: json['payment_method'] as String? ?? 'cod',
  paymentStatus: json['payment_status'] as String? ?? 'pending',
  shippingAddress: json['shipping_address'] as Map<String, dynamic>?,
  customerNotes: json['customer_notes'] as String?,
  giftMessage: json['gift_message'] as String?,
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  totals:
      (json['totals'] as List<dynamic>?)
          ?.map((e) => OrderTotal.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  timeline:
      (json['timeline'] as List<dynamic>?)
          ?.map((e) => TimelineStep.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  cancelReason: json['cancel_reason'] as String?,
  canCancel: json['can_cancel'] as bool? ?? false,
);

Map<String, dynamic> _$OrderDetailToJson(OrderDetail instance) =>
    <String, dynamic>{
      'id': instance.id,
      'created_at': instance.createdAt.toIso8601String(),
      'status': instance.status,
      'status_label': instance.statusLabel,
      'payment_method': instance.paymentMethod,
      'payment_status': instance.paymentStatus,
      'delivery': instance.delivery.toJson(),
      'shipping_address': instance.shippingAddress,
      'customer_notes': instance.customerNotes,
      'gift_message': instance.giftMessage,
      'items': instance.items.map((e) => e.toJson()).toList(),
      'totals': instance.totals.map((e) => e.toJson()).toList(),
      'timeline': instance.timeline.map((e) => e.toJson()).toList(),
      'cancel_reason': instance.cancelReason,
      'can_cancel': instance.canCancel,
    };

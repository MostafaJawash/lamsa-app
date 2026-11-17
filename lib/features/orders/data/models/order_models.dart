import 'package:equatable/equatable.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:lamsa_app/core/images/image_urls.dart';

part 'order_models.g.dart';

/// Backend timestamps are UTC; strings without an offset are read as UTC.
DateTime parseBackendDate(Object? value) {
  final text = '$value';
  final hasZone = RegExp(r'([zZ]|[+-]\d{2}:?\d{2})$').hasMatch(text);
  return DateTime.parse(hasZone || !text.contains('T') ? text : '${text}Z');
}

DateTime? parseBackendDateOrNull(Object? value) =>
    value == null ? null : parseBackendDate(value);

/// Per-currency amounts of an order. One entry per currency; never combined.
@JsonSerializable(fieldRename: FieldRename.snake)
final class OrderTotal extends Equatable {
  const OrderTotal({
    required this.currency,
    required this.subtotal,
    required this.shippingFee,
    required this.total,
    this.discount = '0.00',
    this.isLegacy = false,
  });

  factory OrderTotal.fromJson(Map<String, dynamic> json) =>
      _$OrderTotalFromJson(json);

  final String currency;
  final String subtotal;
  final String discount;
  final String shippingFee;
  final String total;

  /// A pre-Syria order (e.g. EUR snapshots): shown as received.
  final bool isLegacy;

  Map<String, dynamic> toJson() => _$OrderTotalToJson(this);

  @override
  List<Object?> get props =>
      [currency, subtotal, discount, shippingFee, total, isLegacy];
}

@JsonSerializable(fieldRename: FieldRename.snake)
final class OrderDelivery extends Equatable {
  const OrderDelivery({
    required this.code,
    required this.name,
    this.currency = 'SYP',
    this.feePaidToCarrier = false,
  });

  factory OrderDelivery.fromJson(Map<String, dynamic> json) =>
      _$OrderDeliveryFromJson(json);

  final String code;
  final String name;
  final String currency;
  final bool feePaidToCarrier;

  Map<String, dynamic> toJson() => _$OrderDeliveryToJson(this);

  @override
  List<Object?> get props => [code, name, currency, feePaidToCarrier];
}

/// A line of an order, as it was when the order was placed.
@JsonSerializable(fieldRename: FieldRename.snake)
final class OrderItem extends Equatable {
  const OrderItem({
    required this.name,
    required this.currency,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.productId,
    this.productSlug,
    this.variantLabel,
    this.image,
    this.bundleContents,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) =>
      _$OrderItemFromJson(json);

  final int? productId;

  /// Set only while the product is still visible (then the line links to it).
  final String? productSlug;
  final String name;
  final String? variantLabel;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final String currency;
  final String unitPrice;
  final int quantity;
  final String lineTotal;

  /// Free-form snapshots of a gift box's components (`name`, `quantity`, ...).
  final List<Map<String, dynamic>>? bundleContents;

  Map<String, dynamic> toJson() => _$OrderItemToJson(this);

  @override
  List<Object?> get props => [
        productId,
        productSlug,
        name,
        variantLabel,
        image,
        currency,
        unitPrice,
        quantity,
        lineTotal,
        bundleContents,
      ];
}

/// One step of the order's workflow (`reached_at` is null until reached).
@JsonSerializable(fieldRename: FieldRename.snake)
final class TimelineStep extends Equatable {
  const TimelineStep({
    required this.status,
    required this.label,
    this.reachedAt,
    this.isCurrent = false,
    this.cancelReason,
  });

  factory TimelineStep.fromJson(Map<String, dynamic> json) =>
      _$TimelineStepFromJson(json);

  final String status;
  final String label;
  @JsonKey(fromJson: parseBackendDateOrNull)
  final DateTime? reachedAt;
  final bool isCurrent;
  final String? cancelReason;

  Map<String, dynamic> toJson() => _$TimelineStepToJson(this);

  @override
  List<Object?> get props => [status, label, reachedAt, isCurrent, cancelReason];
}

/// A row of `GET /orders`.
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class OrderSummary extends Equatable {
  const OrderSummary({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    this.itemsCount = 0,
    this.totals = const [],
    this.image,
    this.deliveryMethodName = '',
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) =>
      _$OrderSummaryFromJson(json);

  final int id;
  @JsonKey(fromJson: parseBackendDate)
  final DateTime createdAt;
  final String status;

  /// Shown as returned (the backend's Arabic wording).
  final String statusLabel;
  final int itemsCount;
  final List<OrderTotal> totals;
  @JsonKey(fromJson: ImageUrls.fromJson)
  final ImageUrls? image;
  final String deliveryMethodName;

  Map<String, dynamic> toJson() => _$OrderSummaryToJson(this);

  @override
  List<Object?> get props => [
        id,
        createdAt,
        status,
        statusLabel,
        itemsCount,
        totals,
        image,
        deliveryMethodName,
      ];
}

@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class OrderPage extends Equatable {
  const OrderPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory OrderPage.fromJson(Map<String, dynamic> json) =>
      _$OrderPageFromJson(json);

  final List<OrderSummary> items;
  final int page;
  final int pageSize;
  final int total;

  Map<String, dynamic> toJson() => _$OrderPageToJson(this);

  @override
  List<Object?> get props => [items, page, pageSize, total];
}

/// `GET /orders/{id}` and the `201`/`200` of `POST /orders`.
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
final class OrderDetail extends Equatable {
  const OrderDetail({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.statusLabel,
    required this.delivery,
    this.paymentMethod = 'cod',
    this.paymentStatus = 'pending',
    this.shippingAddress,
    this.customerNotes,
    this.giftMessage,
    this.items = const [],
    this.totals = const [],
    this.timeline = const [],
    this.cancelReason,
    this.canCancel = false,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) =>
      _$OrderDetailFromJson(json);

  final int id;
  @JsonKey(fromJson: parseBackendDate)
  final DateTime createdAt;
  final String status;
  final String statusLabel;
  final String paymentMethod;
  final String paymentStatus;
  final OrderDelivery delivery;

  /// Free-form snapshot of the address when the order was placed (new shape
  /// or the legacy `{city, street, building}`), or null (old pickup orders).
  final Map<String, dynamic>? shippingAddress;
  final String? customerNotes;
  final String? giftMessage;
  final List<OrderItem> items;
  final List<OrderTotal> totals;
  final List<TimelineStep> timeline;
  final String? cancelReason;

  /// True only while the order is `pending`; afterwards only the store can
  /// cancel it.
  final bool canCancel;

  Map<String, dynamic> toJson() => _$OrderDetailToJson(this);

  @override
  List<Object?> get props => [
        id,
        createdAt,
        status,
        statusLabel,
        paymentMethod,
        paymentStatus,
        delivery,
        shippingAddress,
        customerNotes,
        giftMessage,
        items,
        totals,
        timeline,
        cancelReason,
        canCancel,
      ];
}

/// `OrderCreate`: what `POST /orders` takes. [expectedTotals] is the exact
/// `{currency: amount}` map of the selected quote's totals (no arithmetic).
final class OrderRequest extends Equatable {
  const OrderRequest({
    required this.deliveryMethodCode,
    required this.addressId,
    required this.expectedTotals,
    this.customerNotes,
    this.giftMessage,
  });

  final String deliveryMethodCode;
  final int addressId;
  final Map<String, String> expectedTotals;
  final String? customerNotes;
  final String? giftMessage;

  Map<String, Object?> toJson() => {
        'delivery_method_code': deliveryMethodCode,
        'address_id': addressId,
        'customer_notes': customerNotes,
        'gift_message': giftMessage,
        'expected_totals': expectedTotals,
      };

  @override
  List<Object?> get props => [
        deliveryMethodCode,
        addressId,
        expectedTotals,
        customerNotes,
        giftMessage,
      ];
}

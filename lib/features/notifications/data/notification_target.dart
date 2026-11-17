import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/router/routes.dart';

/// Where a notification leads. One mapping for pushes (foreground banner,
/// background and terminated taps) and for inbox rows, mirroring lamsa-web's
/// `notificationTarget` and the backend's link table.
sealed class NotificationTarget extends Equatable {
  const NotificationTarget();

  @override
  List<Object?> get props => const [];
}

/// A screen of the app; [tab] routes (the cart) replace the stack, the rest
/// are pushed above it.
final class InternalTarget extends NotificationTarget {
  const InternalTarget(this.path, {this.tab = false});

  final String path;
  final bool tab;

  @override
  List<Object?> get props => [path, tab];
}

/// An `https` address for the browser.
final class ExternalTarget extends NotificationTarget {
  const ExternalTarget(this.uri);

  final Uri uri;

  @override
  List<Object?> get props => [uri];
}

/// Nowhere: unknown, malformed or admin-only links. Nothing happens.
final class NoTarget extends NotificationTarget {
  const NoTarget();
}

String? _slug(String? v) {
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}

int? _positiveId(String? v) {
  final t = v?.trim() ?? '';
  if (!RegExp(r'^\d{1,9}$').hasMatch(t)) return null;
  final n = int.parse(t);
  return n > 0 ? n : null;
}

/// [linkType] / [linkValue] come from the push data or the inbox link;
/// [orderId] and [type] (`order_update`, `cart_reminder`...) refine `none`.
///
/// - `order`: the customer's order (a positive integer id, else nowhere);
/// - `product` / `category` / `brand`: that screen (the value is the slug);
/// - `new` / `sale`: the lists; `url`: only `https`;
/// - `none`: the order of an order update, the cart for a cart reminder, else
///   the inbox (what the backend documents);
/// - `admin_order`, `admin_product` and anything unknown: nowhere (they are
///   never sent to a customer, but must never crash or navigate).
NotificationTarget resolveNotificationTarget({
  required String linkType,
  String? linkValue,
  int? orderId,
  String? type,
}) {
  switch (linkType) {
    case 'order':
      final id = _positiveId(linkValue);
      return id == null ? const NoTarget() : InternalTarget(Routes.orderPath(id));
    case 'product':
      final s = _slug(linkValue);
      return s == null ? const NoTarget() : InternalTarget(Routes.productPath(s));
    case 'category':
      final s = _slug(linkValue);
      return s == null ? const NoTarget() : InternalTarget(Routes.categoryPath(s));
    case 'brand':
      final s = _slug(linkValue);
      return s == null ? const NoTarget() : InternalTarget(Routes.brandPath(s));
    case 'new':
      return const InternalTarget(Routes.newArrivals);
    case 'sale':
      return const InternalTarget(Routes.sale);
    case 'url':
      final uri = Uri.tryParse(linkValue?.trim() ?? '');
      return uri != null &&
              uri.scheme.toLowerCase() == 'https' &&
              uri.hasAuthority &&
              uri.host.isNotEmpty
          ? ExternalTarget(uri)
          : const NoTarget();
    case 'none':
    case '':
      if (orderId != null && orderId > 0) {
        return InternalTarget(Routes.orderPath(orderId));
      }
      if (type == 'cart_reminder') {
        return const InternalTarget(Routes.cart, tab: true);
      }
      return const InternalTarget(Routes.notifications);
    default:
      return const NoTarget();
  }
}

/// The target of an inbox row. For a row, "none" means no destination (the
/// row only marks itself read), unlike a push tap, which opens the inbox.
NotificationTarget inboxTarget({
  required String linkType,
  String? linkValue,
  int? orderId,
  String? type,
}) {
  final t = resolveNotificationTarget(
    linkType: linkType,
    linkValue: linkValue,
    orderId: orderId,
    type: type,
  );
  return t is InternalTarget && t.path == Routes.notifications
      ? const NoTarget()
      : t;
}

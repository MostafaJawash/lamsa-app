import 'package:equatable/equatable.dart';

/// Deep-link target carried by a push `data` payload
/// (`link_type` / `link_value` / `notification_id`).
final class PushLink extends Equatable {
  const PushLink({
    required this.notificationId,
    required this.linkType,
    this.linkValue,
  });

  /// Returns null when the payload has no `notification_id`.
  static PushLink? fromData(Map<String, dynamic> data) {
    final id = data['notification_id'];
    if (id == null) return null;
    return PushLink(
      notificationId: '$id',
      linkType: '${data['link_type'] ?? 'none'}',
      linkValue: data['link_value'] as String?,
    );
  }

  final String notificationId;

  /// none, product, category, brand, new, sale, url, order.
  final String linkType;
  final String? linkValue;

  @override
  List<Object?> get props => [notificationId, linkType, linkValue];
}

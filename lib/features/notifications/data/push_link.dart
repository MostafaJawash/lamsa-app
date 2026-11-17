import 'package:equatable/equatable.dart';

/// A push as the app sees it (title and body of the `notification`, plus the
/// string-valued `data`). Independent of firebase_messaging so everything that
/// handles pushes can be tested with plain objects.
final class PushMessage extends Equatable {
  const PushMessage({this.title, this.body, this.data = const {}});

  final String? title;
  final String? body;
  final Map<String, String> data;

  @override
  List<Object?> get props => [title, body, data];
}

/// The `data` of a push: `notification_id`, `type`, `link_type`, `link_value`,
/// `order_id`. All values are strings and empty when not set. Test pushes
/// (`POST /admin/notifications/test`) have an empty id and `test: "1"`.
final class PushLink extends Equatable {
  const PushLink({
    required this.notificationId,
    required this.type,
    required this.linkType,
    this.linkValue,
    this.orderId,
    this.isTest = false,
  });

  factory PushLink.fromData(Map<String, String> data) {
    String clean(String? v) => v?.trim() ?? '';
    final value = clean(data['link_value']);
    final type = clean(data['link_type']);
    final orderRaw = clean(data['order_id']);
    final order = int.tryParse(orderRaw);
    return PushLink(
      notificationId: clean(data['notification_id']),
      type: clean(data['type']),
      linkType: type.isEmpty ? 'none' : type,
      linkValue: value.isEmpty ? null : value,
      orderId: order != null && order > 0 ? order : null,
      isTest: clean(data['test']) == '1',
    );
  }

  /// Empty for a test push (never deduped, never marked read).
  final String notificationId;
  final String type;
  final String linkType;
  final String? linkValue;
  final int? orderId;
  final bool isTest;

  bool get hasId => notificationId.isNotEmpty;

  /// The inbox id, when the push has a numeric one.
  int? get inboxId => int.tryParse(notificationId);

  @override
  List<Object?> get props =>
      [notificationId, type, linkType, linkValue, orderId, isTest];
}

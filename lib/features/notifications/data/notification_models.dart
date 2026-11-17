import 'package:equatable/equatable.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';

/// The `link {type, value}` of an inbox item (the same shape as banners).
final class NotificationLink extends Equatable {
  const NotificationLink({this.type = 'none', this.value});

  factory NotificationLink.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return const NotificationLink();
    final type = json['type'];
    final value = json['value'];
    return NotificationLink(
      type: type is String && type.isNotEmpty ? type : 'none',
      value: value is String ? value : null,
    );
  }

  final String type;
  final String? value;

  @override
  List<Object?> get props => [type, value];
}

/// One row of the inbox (`GET /notifications`).
final class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.sentAt,
    this.link = const NotificationLink(),
    this.orderId,
    this.isRead = false,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id']! as num).toInt(),
        type: '${json['type'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        sentAt: parseBackendDate(json['sent_at']),
        link: NotificationLink.fromJson(json['link']),
        orderId: (json['order_id'] as num?)?.toInt(),
        isRead: json['is_read'] == true,
      );

  final int id;

  /// `order_update`, `marketing`, `message`, `favorite_back_in_stock`,
  /// `favorite_price_drop`, `cart_reminder`.
  final String type;
  final String title;
  final String body;
  final DateTime sentAt;
  final NotificationLink link;
  final int? orderId;
  final bool isRead;

  AppNotification asRead() => isRead
      ? this
      : AppNotification(
          id: id,
          type: type,
          title: title,
          body: body,
          sentAt: sentAt,
          link: link,
          orderId: orderId,
          isRead: true,
        );

  @override
  List<Object?> get props =>
      [id, type, title, body, sentAt, link, orderId, isRead];
}

final class NotificationPage extends Equatable {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.total,
    required this.unreadCount,
  });

  factory NotificationPage.fromJson(Map<String, dynamic> json) =>
      NotificationPage(
        items: [
          for (final e in (json['items'] as List<dynamic>? ?? const []))
            AppNotification.fromJson(e as Map<String, dynamic>),
        ],
        page: (json['page'] as num?)?.toInt() ?? 1,
        total: (json['total'] as num?)?.toInt() ?? 0,
        unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      );

  final List<AppNotification> items;
  final int page;
  final int total;
  final int unreadCount;

  @override
  List<Object?> get props => [items, page, total, unreadCount];
}

/// The preference switches. [orderUpdates] is always true (it cannot be
/// changed); there is no switch for it.
final class NotificationPrefs extends Equatable {
  const NotificationPrefs({
    this.marketing = true,
    this.favorites = true,
    this.cartReminders = true,
  });

  factory NotificationPrefs.fromJson(Map<String, dynamic> json) =>
      NotificationPrefs(
        marketing: json['notify_marketing'] != false,
        favorites: json['notify_favorites'] != false,
        cartReminders: json['notify_cart_reminders'] != false,
      );

  final bool marketing;
  final bool favorites;
  final bool cartReminders;

  /// Order status messages cannot be switched off.
  bool get orderUpdates => true;

  NotificationPrefs copyWith({
    bool? marketing,
    bool? favorites,
    bool? cartReminders,
  }) =>
      NotificationPrefs(
        marketing: marketing ?? this.marketing,
        favorites: favorites ?? this.favorites,
        cartReminders: cartReminders ?? this.cartReminders,
      );

  @override
  List<Object?> get props => [marketing, favorites, cartReminders];
}

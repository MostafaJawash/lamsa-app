import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/orders/data/order_format.dart';

/// "الآن", "قبل 5 دقائق", "قبل ساعتين" within a day; after that the date and
/// time in the store's time (Damascus), like the order screens.
String formatNotificationTime(DateTime sentAt, DateTime now) {
  final age = now.difference(sentAt);
  if (age.isNegative || age.inMinutes < 1) return Strings.notifJustNow;
  if (age.inMinutes < 60) return Strings.notifMinutesAgo(age.inMinutes);
  if (age.inHours < 24) return Strings.notifHoursAgo(age.inHours);
  return formatOrderDate(sentAt, time: true);
}

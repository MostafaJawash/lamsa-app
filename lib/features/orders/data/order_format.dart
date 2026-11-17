/// Order dates are shown in the store's time (Damascus) with Latin digits,
/// like lamsa-web. Syria has been on UTC+3 all year since October 2022, so a
/// fixed offset is enough (no timezone database is needed).
const _damascusOffset = Duration(hours: 3);

const _months = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// `17 نوفمبر 2026`, or with [time]: `17 نوفمبر 2026، 07:05 م`.
String formatOrderDate(DateTime moment, {bool time = false}) {
  final d = moment.toUtc().add(_damascusOffset);
  final date = '${d.day} ${_months[d.month - 1]} ${d.year}';
  if (!time) return date;
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final suffix = d.hour < 12 ? 'ص' : 'م';
  return '$date، ${h12.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')} $suffix';
}

/// The backend's `status_group` query values for the filter chips
/// (`null` for "all").
enum OrderFilter {
  all(null),
  active('active'),
  completed('completed'),
  cancelled('cancelled');

  const OrderFilter(this.group);

  final String? group;
}

/// How a status pill is tinted (the label itself is the backend's).
enum StatusTone { pending, progress, done, cancelled }

StatusTone statusTone(String status) => switch (status) {
      'pending' => StatusTone.pending,
      'preparing' || 'shipped' || 'ready_for_pickup' => StatusTone.progress,
      'delivered' => StatusTone.done,
      _ => StatusTone.cancelled,
    };

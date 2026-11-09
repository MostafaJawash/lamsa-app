import 'package:intl/intl.dart';
import 'package:lamsa_app/core/money/money.dart';

// Latin digits with grouping, independent of the device locale.
final NumberFormat _grouped = NumberFormat('#,##0', 'en');

const _lri = '\u2066';
const _pdi = '\u2069';

/// Formats like the web clients: symbol after the number.
/// SYP `150,000 ل.س` (no decimals), USD `8.5 $` (trailing zeros trimmed),
/// unknown `12.00 CODE`. With [isolate] the number is wrapped in bidi
/// isolates so it keeps its order inside RTL text.
String formatMoney(Money money, {bool isolate = true}) {
  final negative = money.minor < 0;
  final abs = money.minor.abs();
  final String number;
  final String symbol;
  switch (money.currency) {
    case 'SYP':
      number = _grouped.format((abs + 50) ~/ 100);
      symbol = 'ل.س';
    case 'USD':
      number = _withDecimals(abs, trim: true);
      symbol = r'$';
    default:
      number = _withDecimals(abs, trim: false);
      symbol = money.currency;
  }
  final signed = negative ? '-$number' : number;
  final shown = isolate ? '$_lri$signed$_pdi' : signed;
  return '$shown $symbol';
}

String _withDecimals(int absMinor, {required bool trim}) {
  final whole = _grouped.format(absMinor ~/ 100);
  final cents = (absMinor % 100).toString().padLeft(2, '0');
  if (trim) {
    final trimmed = cents.replaceFirst(RegExp(r'0+$'), '');
    return trimmed.isEmpty ? whole : '$whole.$trimmed';
  }
  return '$whole.$cents';
}

/// One formatted line per currency (never a combined total).
List<String> formatTotals(Iterable<Money> amounts, {bool isolate = true}) => [
      for (final m in sumByCurrency(amounts)) formatMoney(m, isolate: isolate),
    ];

import 'package:equatable/equatable.dart';

/// A currency-tagged amount held in integer minor units (2 decimals), never
/// as a double. Amounts of different currencies are never added together:
/// use [sumByCurrency] to aggregate.
final class Money extends Equatable {
  const Money({required this.minor, required this.currency});

  /// Parses the backend's decimal string (e.g. `"150000.00"`, `"8.5"`).
  factory Money.parse(String amount, String currency) {
    final match = _pattern.firstMatch(amount.trim());
    if (match == null) {
      throw FormatException('Invalid money amount', amount);
    }
    final negative = match.group(1) == '-';
    final whole = int.parse(match.group(2)!);
    final fraction = (match.group(3) ?? '').padRight(2, '0');
    final minor = whole * 100 + int.parse(fraction);
    return Money(minor: negative ? -minor : minor, currency: currency);
  }

  static final _pattern = RegExp(r'^(-?)(\d+)(?:\.(\d{1,2}))?$');

  final int minor;
  final String currency;

  Money operator +(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Cannot add $currency and ${other.currency}');
    }
    return Money(minor: minor + other.minor, currency: currency);
  }

  @override
  List<Object?> get props => [minor, currency];
}

/// One bucket per currency, ordered SYP, USD, then others alphabetically.
List<Money> sumByCurrency(Iterable<Money> amounts) {
  final totals = <String, Money>{};
  for (final m in amounts) {
    final existing = totals[m.currency];
    totals[m.currency] = existing == null ? m : existing + m;
  }
  final result = totals.values.toList()
    ..sort((a, b) {
      final ra = _rank(a.currency);
      final rb = _rank(b.currency);
      if (ra != rb) return ra.compareTo(rb);
      return a.currency.compareTo(b.currency);
    });
  return result;
}

int _rank(String currency) => switch (currency) {
      'SYP' => 0,
      'USD' => 1,
      _ => 2,
    };

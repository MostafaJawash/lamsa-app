import 'package:flutter_test/flutter_test.dart';
import 'package:lamsa_app/core/money/money.dart';
import 'package:lamsa_app/core/money/money_format.dart';

Money syp(String a) => Money.parse(a, 'SYP');
Money usd(String a) => Money.parse(a, 'USD');

void main() {
  test('SYP: grouped, no decimals, symbol after', () {
    expect(formatMoney(syp('150000.00'), isolate: false), '150,000 ل.س');
    expect(formatMoney(syp('0.00'), isolate: false), '0 ل.س');
  });

  test('USD: trailing zeros trimmed', () {
    expect(formatMoney(usd('8.50'), isolate: false), r'8.5 $');
    expect(formatMoney(usd('8.00'), isolate: false), r'8 $');
    expect(formatMoney(usd('1234.05'), isolate: false), r'1,234.05 $');
  });

  test('unknown currency keeps two decimals and its code', () {
    expect(
      formatMoney(Money.parse('12', 'EUR'), isolate: false),
      '12.00 EUR',
    );
  });

  test('isolate wraps only the number in bidi isolates', () {
    expect(formatMoney(usd('5.00')), '\u20665\u2069 \$');
  });

  test('rejects malformed amounts', () {
    expect(() => Money.parse('1,5', 'SYP'), throwsFormatException);
    expect(() => Money.parse('abc', 'USD'), throwsFormatException);
  });

  test('adding different currencies throws', () {
    expect(() => syp('1') + usd('1'), throwsArgumentError);
  });

  test('sumByCurrency never mixes currencies and orders SYP, USD, others',
      () {
    final totals = sumByCurrency([
      usd('1.50'),
      Money.parse('3', 'EUR'),
      syp('1000'),
      usd('2.25'),
      syp('500'),
    ]);
    expect(totals, [syp('1500'), usd('3.75'), Money.parse('3', 'EUR')]);
  });
}

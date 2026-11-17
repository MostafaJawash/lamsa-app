import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:equatable/equatable.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

/// The inputs a customer confirms in one checkout attempt (what the
/// Idempotency-Key covers). Port of lamsa-web's `attempt.ts`.
final class AttemptSnapshot extends Equatable {
  const AttemptSnapshot({
    required this.addressId,
    required this.method,
    required this.notes,
    required this.gift,
    required this.totals,
  });

  final int addressId;
  final String method;
  final String notes;
  final String gift;

  /// The per-currency totals the customer is looking at, `{currency: amount}`.
  final Map<String, String> totals;

  @override
  List<Object?> get props => [addressId, method, notes, gift, totals];
}

/// `[{currency, amount}]` as the backend returns it to `{SYP: "...", USD: "..."}`,
/// without any arithmetic: this is the exact `expected_totals` the order
/// request carries.
Map<String, String> totalsToMap(Iterable<CurrencyAmount> totals) => {
      for (final t in totals) t.currency: t.amount,
    };

/// A random UUID v4: the id of one checkout attempt. One attempt starts
/// whenever the checkout screen is built or refreshed.
String newAttemptId([Random? random]) {
  final r = random ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 10
  String hex(int from, int to) => bytes
      .sublist(from, to)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

final _attemptId = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool isAttemptId(String value) => _attemptId.hasMatch(value);

/// The snapshot in one canonical form: trimmed texts (the backend trims them
/// too), currencies in a fixed order.
String _canonical(AttemptSnapshot s) => jsonEncode([
      s.addressId,
      s.method,
      s.notes.trim(),
      s.gift.trim(),
      [
        for (final c in const ['SYP', 'USD']) [c, s.totals[c]],
      ],
    ]);

/// The Idempotency-Key for an attempt and the inputs confirmed with it: 43
/// characters of base64url (the backend accepts 1..64 of letters, digits,
/// `-` and `_`).
///
/// - a genuine retry (double tap, an automatic retry after a busy server or a
///   network error) submits the same attempt id with the same inputs, so it
///   derives the same key and the backend returns the order it already
///   created instead of making a second one;
/// - changing anything material before confirming derives a different key;
/// - a refreshed checkout (after a price change, a new address, ...) has a
///   new attempt id, so the customer always confirms anew with a new key.
String idempotencyKey(String attemptId, AttemptSnapshot snapshot) {
  final input = [...utf8.encode(attemptId), 0, ...utf8.encode(_canonical(snapshot))];
  return base64Url.encode(sha256.convert(input).bytes).replaceAll('=', '');
}

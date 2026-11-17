import 'package:equatable/equatable.dart';
import 'package:lamsa_app/core/errors/api_error.dart';
import 'package:lamsa_app/core/errors/error_messages.dart';
import 'package:lamsa_app/core/strings.dart';
import 'package:lamsa_app/features/cart/data/guest_codec.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';

/// A failed cart or favorites call, in the shape every screen uses. Port of
/// lamsa-web's `CartError`.
final class CartError extends Equatable {
  const CartError(this.code, this.message, {this.available, this.max});

  /// An error built on the device (guest flows) with the local Arabic text.
  factory CartError.local(String code, {int? available, int? max}) => CartError(
        code,
        ErrorMessages.forCode(code),
        available: available,
        max: max,
      );

  factory CartError.from(Object error) {
    if (error is ApiError) {
      final d = error.details;
      int? number(String key) {
        if (d is! Map<String, dynamic>) return null;
        final v = d[key];
        return v is num ? v.toInt() : null;
      }

      return CartError(
        error.code,
        error.userMessage,
        available: number('available'),
        max: number('max'),
      );
    }
    return CartError(ApiError.unknownCode, messageOf(error));
  }

  final String code;
  final String message;

  /// INSUFFICIENT_STOCK: how many are left.
  final int? available;

  /// QUANTITY_LIMIT_EXCEEDED / CART_LIMIT_REACHED / FAVORITES_LIMIT_REACHED.
  final int? max;

  /// What the customer reads for an add/update error: "لم يتبقَّ سوى N",
  /// "الحد الأقصى N", otherwise the backend's message.
  String get text {
    if (code == 'INSUFFICIENT_STOCK' && available != null) {
      return Strings.toastLow(available!);
    }
    if (code == 'QUANTITY_LIMIT_EXCEEDED' && max != null) {
      return Strings.toastMax(max!);
    }
    return message;
  }

  @override
  List<Object?> get props => [code, message, available, max];
}

/// The text under a line with an issue (web `issueText`).
String issueText(LineIssue issue) {
  final n = issue.available ?? issue.max ?? 0;
  return switch (issue.code) {
    'UNAVAILABLE' => Strings.issueUnavailable,
    'VARIANT_UNAVAILABLE' => Strings.issueVariantUnavailable,
    'OUT_OF_STOCK' => Strings.issueOutOfStock,
    'INSUFFICIENT_STOCK' => Strings.issueInsufficientStock(n),
    'QUANTITY_LIMIT_EXCEEDED' => Strings.issueQuantityLimit(n),
    _ => issue.message,
  };
}

String noticeText(CartNotice notice) => switch (notice.code) {
      'QUANTITY_CAPPED' => Strings.noticeQuantityCapped,
      'LINES_MERGED' => Strings.noticeLinesMerged,
      'LINE_REMOVED' => Strings.noticeLineRemoved,
      _ => notice.message,
    };

/// The error for the target line of a guest add or update, read from the
/// preview of the cart WITH the change, exactly as `POST /cart/items` would
/// decide for a stored cart. Null when the line is fine. Port of
/// `guestLineError`.
CartError? guestLineError(Cart cart, String key, {required bool variantGiven}) {
  final line = cart.lines.where((l) => l.ref == key).firstOrNull;
  if (line == null) return CartError.local('PRODUCT_NOT_FOUND');
  final issue = line.issue;
  if (issue == null) return null;
  return switch (issue.code) {
    'UNAVAILABLE' => CartError.local('PRODUCT_NOT_FOUND'),
    'VARIANT_UNAVAILABLE' =>
      CartError.local(variantGiven ? 'VARIANT_NOT_FOUND' : 'VARIANT_REQUIRED'),
    'OUT_OF_STOCK' => CartError.local('OUT_OF_STOCK'),
    'INSUFFICIENT_STOCK' =>
      CartError.local('INSUFFICIENT_STOCK', available: issue.available),
    'QUANTITY_LIMIT_EXCEEDED' =>
      CartError.local('QUANTITY_LIMIT_EXCEEDED', max: issue.max),
    _ => CartError.local(ApiError.unknownCode),
  };
}

/// What "تحديث السلة" does to a guest cart, read from the preview's line
/// issues (the same rules the backend applies to a stored cart in
/// `resolve-issues`): remove unavailable/out-of-stock lines, cap the others.
final class GuestFixes {
  const GuestFixes({
    this.remove = const [],
    this.cap = const {},
    this.notices = const [],
  });

  final List<String> remove;
  final Map<String, int> cap;

  /// Notice codes for the toast (`LINE_REMOVED`, `QUANTITY_CAPPED`).
  final List<String> notices;
}

GuestFixes guestFixes(Cart cart) {
  final remove = <String>[];
  final cap = <String, int>{};
  final notices = <String>[];
  for (final line in cart.lines) {
    final issue = line.issue;
    if (issue == null) continue;
    if (const {'UNAVAILABLE', 'VARIANT_UNAVAILABLE', 'OUT_OF_STOCK'}
        .contains(issue.code)) {
      remove.add(line.ref);
      notices.add('LINE_REMOVED');
      continue;
    }
    final allowed = [issue.available ?? line.quantity, issue.max ?? line.quantity]
        .reduce((a, b) => a < b ? a : b);
    if (allowed <= 0) {
      remove.add(line.ref);
      notices.add('LINE_REMOVED');
    } else {
      cap[line.ref] = allowed;
      notices.add('QUANTITY_CAPPED');
    }
  }
  return GuestFixes(remove: remove, cap: cap, notices: notices);
}

/// Texts for [GuestFixes.notices], de-duplicated, for one toast.
String noticesToast(Iterable<String> codes) => {
      for (final c in codes)
        switch (c) {
          'QUANTITY_CAPPED' => Strings.noticeQuantityCapped,
          'LINES_MERGED' => Strings.noticeLinesMerged,
          'LINE_REMOVED' => Strings.noticeLineRemoved,
          _ => c,
        },
    }.join('، ');

/// Applies [fixes] to a guest cart.
List<GuestCartItem> applyGuestFixes(List<GuestCartItem> items, GuestFixes fixes) =>
    [
      for (final i in items)
        if (!fixes.remove.contains(i.key))
          fixes.cap[i.key] != null ? i.withQuantity(fixes.cap[i.key]!) : i,
    ];

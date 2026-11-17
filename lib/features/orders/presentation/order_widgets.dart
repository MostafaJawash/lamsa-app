import 'package:flutter/material.dart';
import 'package:lamsa_app/core/money/money_format.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/features/cart/data/models/cart_models.dart';
import 'package:lamsa_app/features/orders/data/models/order_models.dart';
import 'package:lamsa_app/features/orders/data/order_format.dart';

/// A label with its amounts, one line per currency. Currencies are never
/// combined.
class AmountRow extends StatelessWidget {
  const AmountRow({
    required this.label,
    required this.amounts,
    this.strong = false,
    this.note,
    super.key,
  });

  final String label;
  final List<({String amount, String currency})> amounts;
  final bool strong;

  /// Shown instead of amounts when there are none (e.g. "to be decided").
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final style = strong
        ? theme.titleMedium!.copyWith(fontWeight: FontWeight.w700)
        : theme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: style)),
          if (amounts.isEmpty && note != null)
            Text(
              note!,
              style: theme.bodySmall!.copyWith(color: context.lamsa.muted),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final a in amounts)
                  Text(formatAmount(a.amount, a.currency), style: style),
              ],
            ),
        ],
      ),
    );
  }
}

List<({String amount, String currency})> fromCart(List<CurrencyAmount> list) => [
      for (final a in list) (amount: a.amount, currency: a.currency),
    ];

/// A status pill tinted by the status group; the text is the backend's label.
class StatusPill extends StatelessWidget {
  const StatusPill({required this.status, required this.label, super.key});

  final String status;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.lamsa;
    final (bg, fg) = switch (statusTone(status)) {
      StatusTone.pending => (c.accentSoft, c.warn),
      StatusTone.progress => (c.accentSoft, c.accent),
      StatusTone.done => (c.surface2, c.ok),
      StatusTone.cancelled => (c.surface2, c.danger),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium!.copyWith(color: fg),
      ),
    );
  }
}

List<({String amount, String currency})> orderTotalsOf(
  List<OrderTotal> totals,
  String Function(OrderTotal) pick,
) =>
    [for (final t in totals) (amount: pick(t), currency: t.currency)];

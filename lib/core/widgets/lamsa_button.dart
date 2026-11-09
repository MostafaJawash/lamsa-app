import 'package:flutter/material.dart';

/// Filled brand button; shows a spinner and ignores taps while [loading].
class LamsaButton extends StatelessWidget {
  const LamsaButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.secondary = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// Outlined style for secondary actions.
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final onTap = loading ? null : onPressed;
    final child = loading
        ? const SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label);
    return secondary
        ? OutlinedButton(onPressed: onTap, child: child)
        : FilledButton(onPressed: onTap, child: child);
  }
}

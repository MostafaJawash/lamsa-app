import 'package:flutter/material.dart';

/// The app-wide [ScaffoldMessenger], so toasts can be shown from anywhere
/// (cubits included, e.g. after a guest-cart merge), not just from a widget.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

/// A short message with an optional action ("عرض السلة"). Replaces any toast
/// currently showing.
void showToast(
  String text, {
  String? sub,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(text),
            if (sub != null)
              Text(sub, style: Theme.of(messenger.context).textTheme.bodySmall),
          ],
        ),
        duration: const Duration(seconds: 3),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(label: actionLabel, onPressed: onAction)
            : null,
      ),
    );
}

import 'package:flutter/material.dart';
import 'package:lamsa_app/core/strings.dart';

/// Feedback for actions whose feature is not built yet (heart, add to cart).
void showComingSoon(BuildContext context) {
  final messenger = ScaffoldMessenger.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(Strings.comingSoon, textAlign: TextAlign.center),
        duration: Duration(seconds: 2),
      ),
    );
}

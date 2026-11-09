import 'package:flutter/material.dart';

/// Labelled text input. Phone numbers are always laid out LTR, like the web.
class LamsaTextField extends StatelessWidget {
  const LamsaTextField({
    required this.label,
    this.controller,
    this.errorText,
    this.obscureText = false,
    this.isPhone = false,
    this.keyboardType,
    this.onChanged,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final String? errorText;
  final bool obscureText;
  final bool isPhone;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      onChanged: onChanged,
      keyboardType: isPhone ? TextInputType.phone : keyboardType,
      textDirection: isPhone ? TextDirection.ltr : null,
      textAlign: isPhone ? TextAlign.right : TextAlign.start,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }
}

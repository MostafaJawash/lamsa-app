import 'package:flutter/material.dart';

/// Body: IBM Plex Sans Arabic. Headings: Reem Kufi (variable font, 600/700).
abstract final class LamsaFonts {
  static const body = 'IBMPlexSansArabic';
  static const display = 'ReemKufi';
}

abstract final class LamsaText {
  static const double _bodyHeight = 1.6;

  static TextStyle display(double size, {double weight = 700}) => TextStyle(
        fontFamily: LamsaFonts.display,
        fontSize: size,
        fontWeight: weight >= 700 ? FontWeight.w700 : FontWeight.w600,
        fontVariations: [FontVariation('wght', weight)],
        height: 1.3,
      );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w400,
  }) =>
      TextStyle(
        fontFamily: LamsaFonts.body,
        fontSize: size,
        fontWeight: weight,
        height: _bodyHeight,
      );

  static TextTheme textTheme(Color ink) => TextTheme(
        displaySmall: display(32).copyWith(color: ink),
        headlineMedium: display(26).copyWith(color: ink),
        headlineSmall: display(22).copyWith(color: ink),
        titleLarge: display(20, weight: 600).copyWith(color: ink),
        titleMedium: body(16, weight: FontWeight.w600).copyWith(color: ink),
        titleSmall: body(14, weight: FontWeight.w600).copyWith(color: ink),
        bodyLarge: body(16).copyWith(color: ink),
        bodyMedium: body(14).copyWith(color: ink),
        bodySmall: body(12).copyWith(color: ink),
        labelLarge: body(15, weight: FontWeight.w600).copyWith(color: ink),
        labelMedium: body(13, weight: FontWeight.w500).copyWith(color: ink),
        labelSmall: body(11, weight: FontWeight.w500).copyWith(color: ink),
      );
}

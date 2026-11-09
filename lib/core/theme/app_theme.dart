import 'package:flutter/material.dart';
import 'package:lamsa_app/core/theme/lamsa_colors.dart';
import 'package:lamsa_app/core/theme/spacing.dart';
import 'package:lamsa_app/core/theme/text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => _build(Brightness.light, LamsaColors.light);
  static ThemeData get dark => _build(Brightness.dark, LamsaColors.dark);

  static ThemeData _build(Brightness brightness, LamsaColors c) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: c.accentInk,
      primaryContainer: c.accentSoft,
      onPrimaryContainer: c.accent,
      secondary: c.gold,
      onSecondary: c.bg,
      error: c.danger,
      onError: c.accentInk,
      surface: c.surface,
      onSurface: c.ink,
      onSurfaceVariant: c.muted,
      surfaceContainerHighest: c.surface2,
      outline: c.line,
      outlineVariant: c.line,
    );
    final textTheme = LamsaText.textTheme(c.ink);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(Radii.lg),
    );
    OutlineInputBorder border(Color color) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.lg),
          borderSide: BorderSide(color: color),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: LamsaFonts.body,
      textTheme: textTheme,
      scaffoldBackgroundColor: c.bg,
      extensions: [c],
      appBarTheme: AppBarTheme(
        backgroundColor: c.surface,
        foregroundColor: c.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.xl),
          side: BorderSide(color: c.line),
        ),
      ),
      dividerTheme: DividerThemeData(color: c.line, space: 1),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(Spacing.controlHeight),
          shape: shape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(Spacing.controlHeight),
          shape: shape,
          side: BorderSide(color: c.line),
          foregroundColor: c.ink,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Spacing.lg,
          vertical: Spacing.md,
        ),
        border: border(c.line),
        enabledBorder: border(c.line),
        focusedBorder: border(c.accent),
        errorBorder: border(c.danger),
        focusedErrorBorder: border(c.danger),
      ),
    );
  }
}

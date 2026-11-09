import 'package:flutter/material.dart';

/// Brand palette ported from lamsa-web/lamsa-admin (`--lamsa-*` tokens).
@immutable
final class LamsaColors extends ThemeExtension<LamsaColors> {
  const LamsaColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.ink,
    required this.muted,
    required this.line,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.gold,
    required this.ok,
    required this.warn,
    required this.danger,
  });

  final Color bg;
  final Color surface;
  final Color surface2;
  final Color ink;
  final Color muted;
  final Color line;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color gold;
  final Color ok;
  final Color warn;
  final Color danger;

  static const light = LamsaColors(
    bg: Color(0xFFF7F0F2),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF1E5EA),
    ink: Color(0xFF2D1B2E),
    muted: Color(0xFF7C6577),
    line: Color(0xFFE6D6DD),
    accent: Color(0xFFB8174E),
    accentInk: Color(0xFFFFFFFF),
    accentSoft: Color(0xFFF7DCE6),
    gold: Color(0xFFB8935A),
    ok: Color(0xFF2F7D5B),
    warn: Color(0xFFB7791F),
    danger: Color(0xFFB42318),
  );

  static const dark = LamsaColors(
    bg: Color(0xFF161015),
    surface: Color(0xFF211820),
    surface2: Color(0xFF2C2029),
    ink: Color(0xFFF4EAF0),
    muted: Color(0xFFB49FAF),
    line: Color(0xFF3B2C38),
    accent: Color(0xFFEE5C8A),
    accentInk: Color(0xFF1A0F16),
    accentSoft: Color(0xFF3D1E2D),
    gold: Color(0xFFD9B98C),
    ok: Color(0xFF5CC08F),
    warn: Color(0xFFE3A84A),
    danger: Color(0xFFF2735F),
  );

  @override
  LamsaColors copyWith({
    Color? bg,
    Color? surface,
    Color? surface2,
    Color? ink,
    Color? muted,
    Color? line,
    Color? accent,
    Color? accentInk,
    Color? accentSoft,
    Color? gold,
    Color? ok,
    Color? warn,
    Color? danger,
  }) {
    return LamsaColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surface2: surface2 ?? this.surface2,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      accentSoft: accentSoft ?? this.accentSoft,
      gold: gold ?? this.gold,
      ok: ok ?? this.ok,
      warn: warn ?? this.warn,
      danger: danger ?? this.danger,
    );
  }

  @override
  LamsaColors lerp(ThemeExtension<LamsaColors>? other, double t) {
    if (other is! LamsaColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return LamsaColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      ink: l(ink, other.ink),
      muted: l(muted, other.muted),
      line: l(line, other.line),
      accent: l(accent, other.accent),
      accentInk: l(accentInk, other.accentInk),
      accentSoft: l(accentSoft, other.accentSoft),
      gold: l(gold, other.gold),
      ok: l(ok, other.ok),
      warn: l(warn, other.warn),
      danger: l(danger, other.danger),
    );
  }
}

extension LamsaColorsContext on BuildContext {
  LamsaColors get lamsa => Theme.of(this).extension<LamsaColors>()!;
}

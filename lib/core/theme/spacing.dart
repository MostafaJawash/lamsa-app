/// Spacing and radius scale. Radii derive from the web's 12px base
/// (`--radius: 0.75rem`: sm = 0.6x, md = 0.8x, lg = 1x, xl = 1.4x).
abstract final class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  static const double pageGutter = 16;
  static const double controlHeight = 46;
}

abstract final class Radii {
  static const double base = 12;
  static const double sm = base * 0.6;
  static const double md = base * 0.8;
  static const double lg = base;
  static const double xl = base * 1.4;
}

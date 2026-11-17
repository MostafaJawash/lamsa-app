import 'dart:ui';

/// Brand colors of the web prototype, used for logo-less brands.
const brandColors = <Color>[
  Color(0xFFB8174E),
  Color(0xFF7A4E9C),
  Color(0xFFC8607F),
  Color(0xFFB88A2E),
  Color(0xFF6B4430),
  Color(0xFF3F7253),
  Color(0xFF2D1B2E),
];

final _diacritics = RegExp('[ً-ْ]');

/// First letter of the name without tashkeel, e.g. "لُمى" → "ل".
String monogram(String name) {
  final clean = name.replaceAll(_diacritics, '').trim();
  return clean.isEmpty ? '' : String.fromCharCode(clean.runes.first);
}

/// Deterministic color for a brand id (Knuth multiplicative hash, same as
/// lamsa-web) so a brand keeps its color everywhere.
Color brandColor(int id) {
  const mask = 0xFFFFFFFF;
  final x = (id ^ 0x5bd1e995) & mask;
  final hash = (x * 2654435761) & mask;
  return brandColors[hash % brandColors.length];
}

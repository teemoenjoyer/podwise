import 'package:flutter/material.dart';

/// The visual themes offered in settings.
///
/// All four are original designs. The brief is explicit that no copyrighted
/// Magic artwork or logos may be used as UI assets, so these are built from
/// colour and type alone.
enum PodWiseTheme {
  darkFantasy('Dark Fantasy', 'Candlelit and gold. The default.'),
  minimal('Minimal', 'Greyscale and quiet. Nothing competes with the numbers.'),
  arcane('Arcane', 'Deep violet with a cold blue edge.'),
  gremlin('Gremlin Mode', 'Loud, green, and slightly unwell.');

  const PodWiseTheme(this.label, this.description);
  final String label;
  final String description;

  static PodWiseTheme fromId(String? id) {
    for (final t in PodWiseTheme.values) {
      if (t.name == id) return t;
    }
    return PodWiseTheme.darkFantasy;
  }
}

/// The colours one theme supplies. Every screen reads from here rather than
/// hard-coding, so adding a theme is a data change rather than a UI change.
@immutable
class PodWisePalette {
  const PodWisePalette({
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceHigh,
    required this.outline,
    required this.accent,
    required this.danger,
    required this.caution,
    required this.healthy,
    required this.seats,
  });

  final Color surface;
  final Color surfaceRaised;
  final Color surfaceHigh;
  final Color outline;
  final Color accent;
  final Color danger;
  final Color caution;
  final Color healthy;

  /// Per-player colours. Deliberately not Magic's colour pie — these identify
  /// people, and reusing WUBRG would imply a deck's colour identity.
  final List<Color> seats;

  static const _darkFantasy = PodWisePalette(
    surface: Color(0xFF0E1013),
    surfaceRaised: Color(0xFF181C22),
    surfaceHigh: Color(0xFF232830),
    outline: Color(0xFF39404B),
    accent: Color(0xFFC9A227),
    danger: Color(0xFFD1495B),
    caution: Color(0xFFE8A33D),
    healthy: Color(0xFF4C9A6A),
    seats: [
      Color(0xFF4A7FB5),
      Color(0xFFB5544A),
      Color(0xFF5A9E6F),
      Color(0xFF9B6BB5),
      Color(0xFFC08A3E),
      Color(0xFF4AA8A8),
    ],
  );

  static const _minimal = PodWisePalette(
    surface: Color(0xFF0B0B0C),
    surfaceRaised: Color(0xFF161719),
    surfaceHigh: Color(0xFF212225),
    outline: Color(0xFF3A3C40),
    accent: Color(0xFFE6E6E8),
    danger: Color(0xFFB56A6A),
    caution: Color(0xFFB59A6A),
    healthy: Color(0xFF6A9B7A),
    seats: [
      Color(0xFF8E9299),
      Color(0xFF6E7278),
      Color(0xFFA8ACB3),
      Color(0xFF585C62),
      Color(0xFFC0C4CB),
      Color(0xFF787C82),
    ],
  );

  static const _arcane = PodWisePalette(
    surface: Color(0xFF0C0A14),
    surfaceRaised: Color(0xFF171326),
    surfaceHigh: Color(0xFF221C36),
    outline: Color(0xFF3C3357),
    accent: Color(0xFF9B7BE0),
    danger: Color(0xFFE05C7B),
    caution: Color(0xFFE0A05C),
    healthy: Color(0xFF5CC0B0),
    seats: [
      Color(0xFF7B6BE0),
      Color(0xFFE05C9B),
      Color(0xFF5CC0B0),
      Color(0xFFB45CE0),
      Color(0xFFE0A05C),
      Color(0xFF5C9BE0),
    ],
  );

  static const _gremlin = PodWisePalette(
    surface: Color(0xFF0A1206),
    surfaceRaised: Color(0xFF13210C),
    surfaceHigh: Color(0xFF1D3113),
    outline: Color(0xFF3F6B28),
    accent: Color(0xFF9BE023),
    danger: Color(0xFFFF4D3D),
    caution: Color(0xFFFFC53D),
    healthy: Color(0xFF6BE023),
    seats: [
      Color(0xFF9BE023),
      Color(0xFFFF6B3D),
      Color(0xFF23E0B0),
      Color(0xFFE023C0),
      Color(0xFFFFC53D),
      Color(0xFF3DB0FF),
    ],
  );

  static PodWisePalette of(PodWiseTheme theme) => switch (theme) {
    PodWiseTheme.darkFantasy => _darkFantasy,
    PodWiseTheme.minimal => _minimal,
    PodWiseTheme.arcane => _arcane,
    PodWiseTheme.gremlin => _gremlin,
  };
}

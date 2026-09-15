import 'package:flutter/material.dart';

import 'themes.dart';

/// The palette currently in force.
///
/// Held as module state rather than threaded through `context`, so the hundred
/// or so existing colour references keep working unchanged. Changing the theme
/// rebuilds the app from `MaterialApp` down, so every widget picks up the new
/// palette on the next frame — but it does mean these colours must be read
/// during build and never captured in a `const`.
PodWisePalette _active = PodWisePalette.of(PodWiseTheme.darkFantasy);

/// Colours for the active theme.
abstract final class PodWiseColors {
  static Color get surface => _active.surface;
  static Color get surfaceRaised => _active.surfaceRaised;
  static Color get surfaceHigh => _active.surfaceHigh;
  static Color get outline => _active.outline;
  static Color get accent => _active.accent;
  static Color get danger => _active.danger;
  static Color get caution => _active.caution;
  static Color get healthy => _active.healthy;
  static List<Color> get seats => _active.seats;
}

/// Life totals are the whole point of the app, so they get a dedicated ramp
/// rather than inheriting body-text styling.
abstract final class PodWiseText {
  static const lifeHuge = TextStyle(
    fontSize: 104,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -4,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const lifeMedium = TextStyle(
    fontSize: 52,
    fontWeight: FontWeight.w300,
    height: 1.0,
    letterSpacing: -1,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  static const pendingDelta = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.0,
    fontFeatures: [FontFeature.tabularFigures()],
  );
}

ThemeData buildPodWiseTheme([PodWiseTheme theme = PodWiseTheme.darkFantasy]) {
  _active = PodWisePalette.of(theme);
  final p = _active;

  final scheme =
      ColorScheme.fromSeed(
        seedColor: p.accent,
        brightness: Brightness.dark,
      ).copyWith(
        surface: p.surface,
        surfaceContainer: p.surfaceRaised,
        surfaceContainerHigh: p.surfaceHigh,
        primary: p.accent,
        outline: p.outline,
        error: p.danger,
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.surface,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: p.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surfaceRaised,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    ),
  );
}

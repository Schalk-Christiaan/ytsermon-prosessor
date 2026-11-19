// @stelsel theme
//   soort: module
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: ontwerpstelsel (kleure, tipe) uit planne/hoofplan.md, lig + donker
//   status: bou
import 'package:flutter/material.dart';

/// Extra token: wood tint for Shorts markers (hoofplan: kanselhout, niks anders nie).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({required this.wood, required this.success});
  final Color wood;
  final Color success;

  @override
  AppTokens copyWith({Color? wood, Color? success}) =>
      AppTokens(wood: wood ?? this.wood, success: success ?? this.success);

  @override
  AppTokens lerp(AppTokens? other, double t) => this;
}

const kOrange = Color(0xFFB34E17);

ColorScheme _scheme(Brightness b) {
  final light = b == Brightness.light;
  return ColorScheme.fromSeed(seedColor: kOrange, brightness: b).copyWith(
    surface: light ? const Color(0xFFF3F4F1) : const Color(0xFF161D1F),
    onSurface: light ? const Color(0xFF1B2629) : const Color(0xFFE6EBEA),
    primary: light ? const Color(0xFFB34E17) : const Color(0xFFF08A4B),
    onPrimary: light ? const Color(0xFFFFFFFF) : const Color(0xFF161D1F),
    secondary: light ? const Color(0xFF2C6A66) : const Color(0xFF7FC4BD),
    onSecondary: light ? const Color(0xFFFFFFFF) : const Color(0xFF161D1F),
    tertiary: light ? const Color(0xFF6B4A32) : const Color(0xFFC9A27E),
    onTertiary: light ? const Color(0xFFFFFFFF) : const Color(0xFF161D1F),
    error: light ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
    onError: light ? const Color(0xFFFFFFFF) : const Color(0xFF161D1F),
  );
}

const _tabular = [FontFeature.tabularFigures()];

/// The app theme for light or dark: Oranje action, river-teal selection, Source Serif/Sans.
ThemeData buildTheme(Brightness b) {
  final cs = _scheme(b);
  final light = b == Brightness.light;
  final base = ThemeData(
    colorScheme: cs,
    useMaterial3: true,
    fontFamily: 'Source Sans 3',
  );
  final t = base.textTheme;
  TextStyle serif(TextStyle? s) =>
      (s ?? const TextStyle()).copyWith(fontFamily: 'Source Serif 4');
  return base.copyWith(
    scaffoldBackgroundColor: cs.surface,
    textTheme: t.copyWith(
      displayLarge: serif(t.displayLarge),
      displayMedium: serif(t.displayMedium),
      displaySmall: serif(t.displaySmall),
      headlineLarge: serif(t.headlineLarge),
      headlineMedium: serif(t.headlineMedium),
      headlineSmall: serif(t.headlineSmall),
      labelMedium: t.labelMedium?.copyWith(fontFeatures: _tabular),
      bodySmall: t.bodySmall?.copyWith(fontFeatures: _tabular),
    ),
    extensions: [
      AppTokens(
        wood: cs.tertiary,
        success: light ? const Color(0xFF2E7D4F) : const Color(0xFF8FD1A6),
      ),
    ],
  );
}

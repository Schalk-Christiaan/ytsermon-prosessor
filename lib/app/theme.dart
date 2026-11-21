// @stelsel theme
//   soort: module
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: ontwerpstelsel (kleure, tipe, panele, seleksie) uit DESIGN.md, lig + donker
//   status: bou
import 'package:flutter/material.dart';

/// Radius of every panel (DESIGN.md: flat panels on the ground, 12 dp apart).
const kPanelRadius = 16.0;

/// Gap between panels in the workspace.
const kPanelGap = 12.0;

/// Extra tokens: wood tint for Shorts markers (kanselhout), success green, and the panel fill
/// (white on limestone in light, one step above slate in dark).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.wood,
    required this.success,
    required this.panel,
  });
  final Color wood;
  final Color success;
  final Color panel;

  @override
  AppTokens copyWith({Color? wood, Color? success, Color? panel}) => AppTokens(
    wood: wood ?? this.wood,
    success: success ?? this.success,
    panel: panel ?? this.panel,
  );

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
    // Selection: river tint with river ink (rail item, chosen tab, chosen row).
    secondaryContainer: light
        ? const Color(0xFFDCEBE9)
        : const Color(0xFF24403E),
    onSecondaryContainer: light
        ? const Color(0xFF17423F)
        : const Color(0xFFCFE8E5),
    // Panels and their steps; `outline` is a 3:1 line (slider track, field border), `outlineVariant` a hairline.
    surfaceContainerLowest: light
        ? const Color(0xFFFFFFFF)
        : const Color(0xFF111719),
    surfaceContainerLow: light
        ? const Color(0xFFF8F9F7)
        : const Color(0xFF1A2224),
    surfaceContainer: light ? const Color(0xFFEEF0ED) : const Color(0xFF1E2729),
    surfaceContainerHigh: light
        ? const Color(0xFFE6E9E5)
        : const Color(0xFF263133),
    outline: light ? const Color(0xFF6D7A7C) : const Color(0xFF8A9799),
    outlineVariant: light ? const Color(0xFFCCD3D1) : const Color(0xFF39464A),
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
  final panel = light ? const Color(0xFFFFFFFF) : const Color(0xFF1E2729);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kPanelRadius),
  );
  return base.copyWith(
    scaffoldBackgroundColor: cs.surface,
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: shape,
    ),
    // Rivier, not orange: orange is the action, the playhead and the sermon handle.
    sliderTheme: SliderThemeData(
      activeTrackColor: cs.secondary,
      inactiveTrackColor: cs.outline,
      thumbColor: cs.secondary,
      overlayColor: cs.secondary.withValues(alpha: 0.12),
      valueIndicatorColor: cs.secondary,
      valueIndicatorTextStyle: TextStyle(
        color: cs.onSecondary,
        fontFeatures: _tabular,
      ),
      trackHeight: 4,
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? cs.secondaryContainer
              : Colors.transparent,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? cs.onSecondaryContainer
              : cs.onSurface,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: cs.outline)),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.secondary : cs.surface,
      ),
      thumbColor: WidgetStateProperty.resolveWith(
        (s) => s.contains(WidgetState.selected) ? cs.onSecondary : cs.outline,
      ),
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (s) =>
            s.contains(WidgetState.selected) ? Colors.transparent : cs.outline,
      ),
    ),
    chipTheme: ChipThemeData(
      selectedColor: cs.secondaryContainer,
      checkmarkColor: cs.onSecondaryContainer,
      labelStyle: TextStyle(color: cs.onSurface),
      side: BorderSide(color: cs.outline),
    ),
    dividerTheme: DividerThemeData(color: cs.outlineVariant, space: 1),
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
        panel: panel,
      ),
    ],
  );
}

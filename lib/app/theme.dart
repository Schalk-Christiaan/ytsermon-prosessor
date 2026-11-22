// @stelsel theme
//   soort: module
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: ontwerpstelsel (Karoo-wit / Karoo-nag kleure, tipe, panele, seleksie), lig + donker
//   status: bou
import 'package:flutter/material.dart';

/// Radius of every panel, button and field (Windows desktop style; dialogs use 8).
const kPanelRadius = 4.0;

/// A flat panel on the ground (DESIGN.md): panel fill, radius 16, content clipped to it.
Widget appPanel(
  BuildContext context,
  Widget child, {
  Key? key,
  double elevation = 0,
}) => Material(
  key: key,
  color: Theme.of(context).extension<AppTokens>()!.panel,
  elevation: elevation,
  clipBehavior: Clip.antiAlias,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kPanelRadius),
  ),
  child: child,
);

/// Motion constants: every animation in the app uses these (exit shorter than entry).
const kMotionFast = Duration(milliseconds: 150);
const kMotionMed = Duration(milliseconds: 250);
const kMotionCurve = Curves.easeOutCubic;

/// [d], or zero when the system asks for reduced motion.
Duration motion(BuildContext c, [Duration d = kMotionMed]) =>
    MediaQuery.disableAnimationsOf(c) ? Duration.zero : d;

/// Gap between panels in the workspace.
const kPanelGap = 12.0;

/// Extra tokens: wood tint for Shorts markers (kanselhout), success green, and the panel fill
/// (lighter than the Karoo-wit ground in light, one step above Karoo-nag in dark).
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
    surface: light ? const Color(0xFFF4F0E8) : const Color(0xFF1C1915),
    onSurface: light ? const Color(0xFF2B2620) : const Color(0xFFEDE6DA),
    primary: light ? const Color(0xFFB34E17) : const Color(0xFFF08A4B),
    onPrimary: light ? const Color(0xFFFFFFFF) : const Color(0xFF1C1915),
    secondary: light ? const Color(0xFF5A6B47) : const Color(0xFFA9BC93),
    onSecondary: light ? const Color(0xFFFFFFFF) : const Color(0xFF1C1915),
    tertiary: light ? const Color(0xFF6B4A32) : const Color(0xFFC9A27E),
    onTertiary: light ? const Color(0xFFFFFFFF) : const Color(0xFF1C1915),
    error: light ? const Color(0xFFB3261E) : const Color(0xFFF2B8B5),
    onError: light ? const Color(0xFFFFFFFF) : const Color(0xFF1C1915),
    // Selection: Karoobos tint with Karoobos ink (rail item, chosen tab, chosen row).
    secondaryContainer: light
        ? const Color(0xFFDDE3D2)
        : const Color(0xFF34402B),
    onSecondaryContainer: light
        ? const Color(0xFF2F3B24)
        : const Color(0xFFDDE8CF),
    // Panels and their steps; `outline` is a 3:1 line (slider track, field border), `outlineVariant` a hairline.
    surfaceContainerLowest: light
        ? const Color(0xFFFBF8F2)
        : const Color(0xFF24201B),
    surfaceContainerLow: light
        ? const Color(0xFFF8F4EC)
        : const Color(0xFF211D18),
    surfaceContainer: light ? const Color(0xFFECE6DA) : const Color(0xFF2B2620),
    surfaceContainerHigh: light
        ? const Color(0xFFE4DCCD)
        : const Color(0xFF332D26),
    outline: light ? const Color(0xFF6E6458) : const Color(0xFF9C9284),
    outlineVariant: light ? const Color(0xFFD6CCBB) : const Color(0xFF3A332B),
  );
}

const _tabular = [FontFeature.tabularFigures()];

/// The app theme for light or dark: Oranje action, Karoobos selection, Source Serif/Sans.
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
  final panel = light ? const Color(0xFFFBF8F2) : const Color(0xFF24201B);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(kPanelRadius),
  );
  // Desktop controls: 32 px high, radius 4, compact padding.
  final button = ButtonStyle(
    visualDensity:
        VisualDensity.standard, // the 32 px minimum already is the dense size
    minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
    padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    shape: WidgetStatePropertyAll(shape),
    textStyle: WidgetStatePropertyAll(t.labelLarge),
    // Pressed: the label shrinks a touch (0.97), then returns.
    foregroundBuilder: (context, states, child) => AnimatedScale(
      scale: states.contains(WidgetState.pressed) ? 0.97 : 1,
      duration: motion(context, kMotionFast),
      child: child,
    ),
  );
  return base.copyWith(
    // Compact sideways, but never below the 32 px control height.
    visualDensity: const VisualDensity(horizontal: -2),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    scaffoldBackgroundColor: cs.surface,
    filledButtonTheme: FilledButtonThemeData(style: button),
    elevatedButtonTheme: ElevatedButtonThemeData(style: button),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      constraints: const BoxConstraints(minHeight: 32),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kPanelRadius),
      ),
    ),
    cardTheme: CardThemeData(
      color: panel,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: shape,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: panel,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    // Karoobos, not orange: orange is the action, the playhead and the sermon handle.
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
    // Secondary actions in Karoobos too: only the filled primary button is orange.
    textButtonTheme: TextButtonThemeData(
      style: button.merge(TextButton.styleFrom(foregroundColor: cs.secondary)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: button.merge(
        OutlinedButton.styleFrom(foregroundColor: cs.secondary),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        visualDensity: VisualDensity.standard,
        minimumSize: const WidgetStatePropertyAll(Size(0, 32)),
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
      labelSmall: t.labelSmall?.copyWith(
        fontSize: 12,
      ), // smallest UI text 12 px
    ),
    extensions: [
      AppTokens(
        wood: cs.tertiary,
        success: light ? const Color(0xFF2A7549) : const Color(0xFF8FD1A6),
        panel: panel,
      ),
    ],
  );
}

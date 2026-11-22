import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/theme.dart';

double _lum(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

void main() {
  // Step 2: the Karoo-wit / Karoo-nag table from planne/desktop-poleer.md.
  test('Karoo palette values', () {
    for (final (b, surf, ink, sec) in [
      (Brightness.light, 0xFFF4F0E8, 0xFF2B2620, 0xFF5A6B47),
      (Brightness.dark, 0xFF1C1915, 0xFFEDE6DA, 0xFFA9BC93),
    ]) {
      final cs = buildTheme(b).colorScheme;
      expect(cs.surface, Color(surf));
      expect(cs.onSurface, Color(ink));
      expect(cs.secondary, Color(sec));
    }
  });

  for (final b in Brightness.values) {
    test('contrast ${b.name}', () {
      final t = buildTheme(b);
      final cs = t.colorScheme;
      final tok = t.extension<AppTokens>()!;
      // text on surface >= 4.5
      for (final c in [
        cs.onSurface,
        cs.primary,
        cs.secondary,
        cs.tertiary,
        cs.error,
        tok.success,
      ]) {
        expect(
          contrast(c, cs.surface),
          greaterThanOrEqualTo(4.5),
          reason: '$c on surface ${b.name}',
        );
      }
      // button fills with their text >= 4.5
      expect(contrast(cs.onPrimary, cs.primary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.onSecondary, cs.secondary), greaterThanOrEqualTo(4.5));
      expect(contrast(cs.onTertiary, cs.tertiary), greaterThanOrEqualTo(4.5));
    });
  }

  for (final b in Brightness.values) {
    test('panel and selection roles ${b.name}', () {
      final t = buildTheme(b);
      final cs = t.colorScheme;
      final tok = t.extension<AppTokens>()!;
      final panel = tok.panel;
      // text on the panel
      for (final c in [
        cs.onSurface,
        cs.primary,
        cs.secondary,
        cs.tertiary,
        cs.error,
        tok.success,
      ]) {
        expect(
          contrast(c, panel),
          greaterThanOrEqualTo(4.5),
          reason: '$c on panel ${b.name}',
        );
      }
      // selection (rail item, chosen tab, chosen row): ink on the river tint, and the tint apart from the ground
      expect(
        contrast(cs.onSecondaryContainer, cs.secondaryContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(contrast(cs.secondaryContainer, cs.surface), greaterThan(1.05));
      // filled button face against the panel and the ground >= 3
      expect(contrast(cs.primary, panel), greaterThanOrEqualTo(3));
      expect(contrast(cs.primary, cs.surface), greaterThanOrEqualTo(3));
      // slider: track and thumb against the panel >= 3
      final sl = t.sliderTheme;
      expect(contrast(sl.activeTrackColor!, panel), greaterThanOrEqualTo(3));
      expect(contrast(sl.inactiveTrackColor!, panel), greaterThanOrEqualTo(3));
      expect(contrast(sl.thumbColor!, panel), greaterThanOrEqualTo(3));
      // switch: the on-track against the panel
      expect(
        contrast(
          t.switchTheme.trackColor!.resolve({WidgetState.selected})!,
          panel,
        ),
        greaterThanOrEqualTo(3),
      );
      // orange is not the slider: it belongs to the action, the playhead and the sermon handle
      expect(sl.activeTrackColor, isNot(cs.primary));
      expect(kPanelRadius, 16);
    });
  }
}

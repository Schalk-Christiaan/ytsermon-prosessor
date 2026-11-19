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
}

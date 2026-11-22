import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/pixel_art.dart';

import 'screen_kit.dart';

void main() {
  test('every sprite is a rectangle of palette characters, frames equal', () {
    expect(allSprites, isNotEmpty);
    for (final s in allSprites) {
      expect(s.frames.length, inInclusiveRange(1, 6), reason: s.name);
      for (final f in s.frames) {
        expect(f.length, s.height, reason: s.name);
        for (final row in f) {
          expect(row.length, s.width, reason: '${s.name}: $row');
          expect(
            row.split('').every((c) => c == '.' || kPixelPalette.contains(c)),
            isTrue,
            reason: '${s.name}: $row',
          );
        }
      }
    }
  });

  Future<void> show(
    WidgetTester t, {
    bool animate = true,
    bool tickers = true,
    bool reduced = false,
    Brightness b = Brightness.light,
  }) async {
    await loadFonts();
    setView(t, 200, 100);
    await t.pumpWidget(const SizedBox()); // a fresh state each time
    await t.pumpWidget(
      appWrap(
        b,
        MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: TickerMode(
            enabled: tickers,
            child: Center(
              child: RepaintBoundary(
                key: const ValueKey('sprite'),
                child: PixelSprite(sheep, scale: 4, animate: animate),
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('animates while visible and busy', (t) async {
    await show(t);
    expect(t.binding.transientCallbackCount, greaterThan(0));
    final size = t.getSize(find.byType(PixelSprite));
    expect(size, Size(sheep.width * 4.0, sheep.height * 4.0));
  });

  testWidgets('no ticker when finished, hidden or reduced motion', (t) async {
    await show(t, animate: false);
    expect(t.binding.transientCallbackCount, 0);
    await show(t, tickers: false);
    await t.pump(const Duration(seconds: 1));
    expect(t.binding.transientCallbackCount, 0);
    await show(t, reduced: true);
    expect(t.binding.transientCallbackCount, 0);
  });

  testWidgets('stops when the job finishes (animate turns off)', (t) async {
    Widget w(bool a) =>
        appWrap(Brightness.light, PixelSprite(sheep, animate: a));
    await t.pumpWidget(w(true));
    expect(t.binding.transientCallbackCount, greaterThan(0));
    await t.pumpWidget(w(false));
    await t.pump(const Duration(milliseconds: 300));
    expect(t.binding.transientCallbackCount, 0);
  });

  for (final b in Brightness.values) {
    testWidgets('sheep golden ${b.name}', (t) async {
      await show(t, animate: false, b: b);
      await expectLater(
        find.byKey(const ValueKey('sprite')),
        matchesGoldenFile('goldens/pixel_sheep_${b.name}.png'),
      );
    });
  }
}

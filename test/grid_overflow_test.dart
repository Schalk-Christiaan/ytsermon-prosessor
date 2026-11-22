// Step 1: the Preke grid cards fit their cell (no RenderFlex overflow) at both desktop widths, themes and text scales.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/settings.dart';

import 'helpers.dart';
import 'screen_kit.dart';

void main() {
  for (final (w, h) in [(1100.0, 720.0), (1600.0, 900.0)]) {
    for (final b in Brightness.values) {
      for (final scale in [1.0, 1.25]) {
        testWidgets('grid fits: ${w.toInt()} $b x$scale', (t) async {
          await loadFonts();
          setView(t, w, h);
          t.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(t.platformDispatcher.clearAllTestValues);
          final tc = testController(seed: false);
          final st = tc.$2
            ..merge([
              const ChannelItem(
                'idlong00001',
                'Die baie lang titel van die preek wat oor twee reëls moet loop en nog verder gaan as dit kan',
                3000,
              ),
              ...sampleItems.take(5),
            ]);
          st.byId('idlong00001')!.scripture = 'Mattheus 12:22-37';
          AppSettings.load(st.root)
            ..sermonGrid = true
            ..save();
          await t.pumpWidget(appWrap(b, prekeScreen(st, tc.$3)));
          await t.pumpAndSettle();
          expect(find.byType(GridView), findsOneWidget);
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}

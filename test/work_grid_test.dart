// Step 23: Werk shares the Preke list/grid choice (sermonGrid); both views fit at both desktop widths, per group.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/features/work/work_screen.dart';

import 'helpers.dart';
import 'screen_kit.dart';

void main() {
  for (final (w, h) in [(1100.0, 1500.0), (1600.0, 1500.0)]) {
    for (final grid in [false, true]) {
      testWidgets('werk fits: ${w.toInt()} grid=$grid', (t) async {
        await loadFonts();
        setView(t, w, h);
        final (st, q) = workQueue(audio: true);
        final s = AppSettings.load(st.root)..sermonGrid = grid;
        await t.pumpWidget(
          appWrap(
            Brightness.light,
            Builder(
              builder: (c) => MediaQuery(
                data: MediaQuery.of(c).copyWith(disableAnimations: true),
                child: Scaffold(
                  body: WorkScreen(
                    store: st,
                    jobs: q,
                    settings: s,
                    onBack: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        // one item per group, in either view
        expect(find.byKey(const ValueKey('ctl.werk.play')), findsNWidgets(3));
        expect(
          find.byKey(const ValueKey('werk.card')),
          grid ? findsNWidgets(3) : findsNothing,
        );
        // the toggle flips the view and the saved choice
        await t.tap(find.text(grid ? 'Lys' : 'Rooster'));
        await t.pumpAndSettle();
        expect(s.sermonGrid, !grid);
        expect(t.takeException(), isNull);
      });
    }
  }
}

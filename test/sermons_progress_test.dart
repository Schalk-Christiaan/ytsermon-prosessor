// Step 26: a sermon that is being processed shows the small progress form (phase, percent, sheep) in its row and card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/pixel_art.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/settings.dart';

import 'screen_kit.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets('busy sermon shows mini progress, grid=$grid', (t) async {
      await loadFonts();
      setView(t, 1280, 900);
      final (st, q) = seededSermons();
      AppSettings.load(st.root)
        ..sermonGrid = grid
        ..save();
      final id = st.sorted.first.id;
      q.current = Job(id, JobKind.plan, status: JobStatus.besig);
      q.phase.value = JobPhase.download;
      q.progress.value = 0.42;
      await t.pumpWidget(appWrap(Brightness.light, prekeScreen(st, q)));
      await t.pump();
      expect(find.byKey(const ValueKey('preke.mini-progress')), findsOneWidget);
      expect(find.textContaining('42%'), findsOneWidget);
      expect(find.byType(PixelSprite), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

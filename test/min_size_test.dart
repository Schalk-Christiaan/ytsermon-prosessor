// Step 16: every screen at the minimum window (1100x720), light and dark, without a RenderFlex overflow.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/features/review/review_screen.dart';
import 'package:preekverwerker/features/settings/system_status.dart';

import 'screen_kit.dart';

void main() {
  instellingsShort();
  for (final b in Brightness.values) {
    // The shell's rail destinations: 0 Preke, 2 Werk, 3 Snitlyste, 6 Biblioteek, 4 Instellings, 5 Opstelling.
    testWidgets('shell screens at 1100x720 ${b.name}', (t) async {
      await loadFonts();
      setView(t, 1100, 720);
      final (st, q) = seededSermons();
      await t.pumpWidget(
        appWrap(
          b,
          Shell(
            store: st,
            jobs: q,
            list: () async => sampleItems,
            settings: AppSettings.load(st.root)..setupDone = true,
          ),
        ),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull, reason: 'Preke');
      for (final i in [2, 3, 6, 4]) {
        await t.tap(find.byKey(ValueKey('ctl.skulp.nav-$i')));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull, reason: 'nav-$i');
      }
    });

    testWidgets('Hersien at 1100x720 ${b.name}: every properties tab', (
      t,
    ) async {
      await loadFonts();
      setView(t, 1100, 720);
      final c = readyController();
      c.meta = FetchedMeta('x', Directory.systemTemp.createTempSync('ms'), {});
      await t.pumpWidget(
        appWrap(b, Scaffold(body: ReviewScreen(controller: c))),
      );
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const ValueKey('ctl.hersien.properties-toggle')));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull, reason: 'properties open');
      for (final tab in ['shorts', 'cuts', 'output', 'transcript']) {
        await t.tap(find.byKey(ValueKey('ctl.hersien.tab-$tab')));
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull, reason: tab);
      }
    });

    testWidgets('Opstelling at 1100x720 ${b.name}', (t) async {
      await loadFonts();
      setView(t, 1100, 720);
      await t.pumpWidget(appWrap(b, setupScreen().$1));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    });
  }
}

/// Step 23: Instellings in a short window: the Stelsel list and "Werk yt-dlp by" must not overlap
/// "Intro en outro"; the page scrolls as one.
void instellingsShort() {
  for (final b in Brightness.values) {
    testWidgets('Instellings at 1100x420 ${b.name}: one scroll, no overlap', (
      t,
    ) async {
      await loadFonts();
      setView(t, 1100, 420);
      final (w, _) = settingsScreen(system: const SystemStatus());
      await t.pumpWidget(appWrap(b, w));
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      final update = find.byKey(const ValueKey('ctl.instellings.update-ytdlp'));
      await t.ensureVisible(update);
      await t.pump();
      final intro = t.getRect(find.text('Intro en outro'));
      expect(t.getRect(update).top, greaterThan(intro.bottom));
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}

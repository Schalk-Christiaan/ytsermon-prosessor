// Step 4: sidebar (icon + word, wide, stripe at the current screen) and the status bar (disk use + free space).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/core/settings.dart';

import 'helpers.dart';
import 'screen_kit.dart';

void main() {
  testWidgets(
    'sidebar is ~200 px with words and a stripe; status bar shows disk',
    (t) async {
      await loadFonts();
      setView(t, 1280, 800);
      final tc = testController(seed: false);
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Shell(
            store: tc.$2,
            jobs: tc.$3,
            list: () async => [],
            settings: AppSettings.load(tc.$2.root)..setupDone = true,
            storage: () async => (10300000000, 312000000000),
          ),
        ),
      );
      await t.pump(const Duration(milliseconds: 10));
      final w = t.getSize(find.byKey(const ValueKey('shell.sidebar'))).width;
      expect(w, inInclusiveRange(180, 220));
      expect(find.byKey(const ValueKey('shell.nav-stripe')), findsOneWidget);
      expect(find.text('Preke op skyf: 10,3 GB · 312 GB vry'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    },
  );
}

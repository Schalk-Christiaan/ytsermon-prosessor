// Step 5: the screen switch fades through, and drops the animation under "reduce motion".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/core/settings.dart';

import 'helpers.dart';
import 'screen_kit.dart';

Widget _shell(dynamic tc, {required bool reduce}) => Builder(
  builder: (c) => MediaQuery(
    data: MediaQuery.of(c).copyWith(disableAnimations: reduce),
    child: Shell(
      store: tc.$2,
      jobs: tc.$3,
      list: () async => [],
      settings: AppSettings.load(tc.$2.root)..setupDone = true,
    ),
  ),
);

void main() {
  for (final reduce in [false, true]) {
    testWidgets('screen switch fade (reduce motion: $reduce)', (t) async {
      await loadFonts();
      setView(t, 1280, 800);
      final tc = testController(seed: false);
      await t.pumpWidget(appWrap(Brightness.light, _shell(tc, reduce: reduce)));
      await t.pump(const Duration(milliseconds: 10));
      final fade = find.byKey(const ValueKey('shell.switch'));
      expect(fade, findsOneWidget);
      expect(t.widget(fade), isA<FadeTransition>());
      double op() => t.widget<FadeTransition>(fade).opacity.value;
      expect(op(), 1);
      await t.tap(find.byKey(const ValueKey('ctl.skulp.nav-2')));
      await t.pump();
      if (reduce) {
        expect(op(), 1, reason: 'no animation');
      } else {
        expect(op(), lessThan(1), reason: 'starts faded out');
        await t.pump(const Duration(milliseconds: 300));
        expect(op(), 1);
      }
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
      await t.pumpWidget(const SizedBox());
    });
  }
}

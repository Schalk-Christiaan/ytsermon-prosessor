import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/app/theme.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/features/review/review_screen.dart';

import 'helpers.dart';
import 'screen_kit.dart';

void main() {
  testWidgets('tearing the Shell down leaves no listener behind', (t) async {
    await loadFonts();
    setView(t, 1100, 720);
    final tc = testController(seed: false);
    await t.pumpWidget(
      appWrap(
        Brightness.light,
        Shell(
          store: tc.$2,
          jobs: tc.$3,
          list: () async => [],
          settings: AppSettings.load(tc.$2.root)..setupDone = true,
        ),
      ),
    );
    await t.pump(const Duration(milliseconds: 10));
    await t.pumpWidget(const SizedBox());
    // a job finishing after the teardown must not reach the shell's disposed parts
    tc.$3.notifyListeners();
    expect(t.takeException(), isNull);
  });

  for (final b in Brightness.values) {
    testWidgets(
      'shell ${b.name}: rail and content are panels, selection in river',
      (t) async {
        await loadFonts();
        setView(t, 1100, 720);
        final tc = testController(seed: false);
        await t.pumpWidget(
          appWrap(
            b,
            Shell(
              store: tc.$2,
              jobs: tc.$3,
              list: () async => [],
              settings: AppSettings.load(tc.$2.root)..setupDone = true,
            ),
          ),
        );
        await t.pump(const Duration(milliseconds: 10));
        final th = buildTheme(b);
        // two panels: the rail and the content
        final panels = t
            .widgetList<Material>(find.byKey(const ValueKey('shell.panel')))
            .toList();
        expect(panels, hasLength(2));
        for (final m in panels) {
          expect(m.color, th.extension<AppTokens>()!.panel);
          expect(
            m.shape,
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(kPanelRadius),
            ),
          );
        }
        // every rail item has icon and word; only the chosen one is in the river tint
        for (final i in [0, 1, 2, 3, 6, 4]) {
          final item = find.byKey(ValueKey('ctl.skulp.nav-$i'));
          expect(
            find.descendant(of: item, matching: find.byType(Icon)),
            findsOneWidget,
          );
          expect(
            find.descendant(of: item, matching: find.byType(Text)),
            findsOneWidget,
          );
        }
        Color? tint(int i) {
          final d = t
              .widget<Ink>(
                find.descendant(
                  of: find.byKey(ValueKey('ctl.skulp.nav-$i')),
                  matching: find.byType(Ink),
                ),
              )
              .decoration;
          return d == null ? null : (d as BoxDecoration).color;
        }

        expect(tint(0), th.colorScheme.secondaryContainer);
        expect(tint(1), isNull);
        await t.tap(find.byKey(const ValueKey('ctl.skulp.nav-1')));
        await t.pump();
        expect(tint(1), th.colorScheme.secondaryContainer);
        expect(tint(0), isNull);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(seconds: 3)),
        );
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('one AppSettings: Preke and Hersien share the shell instance', (
    t,
  ) async {
    await loadFonts();
    setView(t, 1280, 900);
    final tc = testController(seed: false);
    final s = AppSettings.load(tc.$2.root)..setupDone = true;
    await t.pumpWidget(
      appWrap(
        Brightness.light,
        Shell(store: tc.$2, jobs: tc.$3, list: () async => [], settings: s),
      ),
    );
    await t.pump(const Duration(milliseconds: 10));
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ctl.preke.view')),
        matching: find.text('Rooster'),
      ),
    );
    await t.pump(const Duration(milliseconds: 10));
    expect(s.sermonGrid, isTrue);
    expect(
      t
          .widget<ReviewScreen>(find.byType(ReviewScreen, skipOffstage: false))
          .settings,
      same(s),
    );
  });
}

// Step 8: select-all (tri-state), Ctrl+A, Shift/Ctrl-click, on the filtered list, with a status-bar text.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';

import 'screen_kit.dart';

void main() {
  for (final grid in [false, true]) {
    testWidgets('select-all, partial, none, Ctrl+A, ranges (grid: $grid)', (
      t,
    ) async {
      await loadFonts();
      setView(t, 1400, 900);
      final (st, q) = seededSermons();
      String? status;
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Scaffold(
            body: SermonsScreen(
              store: st,
              jobs: q,
              list: () async => sampleItems,
              onOpen: (_) {},
              onSelection: (s) => status = s,
              sizes: (ids) async => {for (final i in ids) i: 1000000},
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      if (grid) {
        await t.tap(
          find.descendant(
            of: find.byKey(const ValueKey('ctl.preke.view')),
            matching: find.text('Rooster'),
          ),
        );
        await t.pumpAndSettle();
      }
      Checkbox all() => t.widget<Checkbox>(
        find.byKey(const ValueKey('ctl.preke.select-all')),
      );
      expect(all().tristate, isTrue);
      expect(all().value, isFalse);
      expect(status, isNull);
      await t.tap(find.byKey(const ValueKey('ctl.preke.select-all')));
      await t.pumpAndSettle();
      expect(all().value, isTrue);
      expect(status, '40 van 40 gekies · 40 MB');
      // one off: partial
      await t.tap(find.byKey(const ValueKey('ctl.preke.select')).first);
      await t.pumpAndSettle();
      expect(all().value, isNull);
      expect(status, '39 van 40 gekies · 39 MB');
      // from partial, the box selects everything again; then clears
      await t.tap(find.byKey(const ValueKey('ctl.preke.select-all')));
      await t.pumpAndSettle();
      expect(all().value, isTrue);
      await t.tap(find.byKey(const ValueKey('ctl.preke.select-all')));
      await t.pumpAndSettle();
      expect(all().value, isFalse);
      // Ctrl+A
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pumpAndSettle();
      expect(all().value, isTrue);
      await t.tap(find.byKey(const ValueKey('ctl.preke.select-all')));
      await t.pumpAndSettle();
      // select-all follows the filter
      await t.tap(find.byKey(const ValueKey('ctl.preke.filter-fout')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('ctl.preke.select-all')));
      await t.pumpAndSettle();
      expect(status, '1 van 1 gekies · 1 MB');
      await t.tap(find.byKey(const ValueKey('ctl.preke.filter-fout')));
      await t.pumpAndSettle();
      expect(all().value, isNull, reason: '1 of 40 selected');
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('Ctrl-click toggles, Shift-click selects a range (table)', (
    t,
  ) async {
    await loadFonts();
    setView(t, 1400, 900);
    final (st, q) = seededSermons();
    String? status;
    final opened = <String>[];
    await t.pumpWidget(
      appWrap(
        Brightness.light,
        Scaffold(
          body: SermonsScreen(
            store: st,
            jobs: q,
            list: () async => sampleItems,
            onOpen: opened.add,
            onSelection: (s) => status = s,
            sizes: (ids) async => {for (final i in ids) i: 1000000},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final rows = find.byKey(const ValueKey('ctl.preke.row'));
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.tap(rows.at(1));
    await t.tap(rows.at(3));
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(opened, isEmpty);
    expect(status, startsWith('2 van 40'));
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.tap(rows.at(6));
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
    expect(opened, isEmpty);
    expect(status, startsWith('5 van 40')); // rows 1, 3 (anchor) .. 6 = 1 + 4
  });
}

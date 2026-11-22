// Step 7: the Preke list is a table with column headers (Titel, Datum, Lengte, Stand, Grootte) that sort on click.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';

import 'screen_kit.dart';

void main() {
  testWidgets('columns, length, size and sorting', (t) async {
    await loadFonts();
    setView(t, 1280, 900);
    final (st, q) = seededSermons();
    await t.pumpWidget(
      appWrap(
        Brightness.light,
        Scaffold(
          body: SermonsScreen(
            store: st,
            jobs: q,
            list: () async => sampleItems,
            onOpen: (_) {},
            // Real file IO does not run inside testWidgets' fake-async zone; storage_test covers sermonSizes.
            sizes: (ids) async => {'id000000001': 3000000},
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final c in ['title', 'date', 'length', 'state', 'size']) {
      expect(
        find.byKey(ValueKey('ctl.preke.sort-$c')),
        findsOneWidget,
        reason: c,
      );
    }
    for (final h in ['Titel', 'Datum', 'Lengte', 'Stand', 'Grootte']) {
      expect(find.text(h), findsOneWidget, reason: h);
    }
    final row1 = find.byKey(const ValueKey('ctl.preke.row')).at(1); // Preek 1
    expect(
      find.descendant(of: row1, matching: find.text('50:01')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row1, matching: find.text('3 MB')),
      findsOneWidget,
    );
    String first() => t
        .widget<Text>(
          find
              .descendant(
                of: find.byKey(const ValueKey('ctl.preke.row')).first,
                matching: find.textContaining('Preek '),
              )
              .first,
        )
        .data!;
    expect(first(), 'Preek 0');
    await t.tap(find.byKey(const ValueKey('ctl.preke.sort-title')));
    await t.pump();
    expect(first(), 'Preek 0');
    await t.tap(find.byKey(const ValueKey('ctl.preke.sort-title')));
    await t.pump();
    expect(first(), 'Preek 9');
    await t.tap(find.byKey(const ValueKey('ctl.preke.sort-length')));
    await t.pump();
    expect(first(), 'Preek 0'); // shortest first
    expect(t.takeException(), isNull);
  });
}

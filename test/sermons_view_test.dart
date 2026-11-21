// Step 7: Preke list/grid choice is remembered; a thumbnail that cannot load falls back to a state icon.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/settings.dart';

import 'screen_kit.dart';

void main() {
  testWidgets('list is the default, Rooster is remembered, thumbs fall back', (
    t,
  ) async {
    await loadFonts();
    setView(t, 1280, 900);
    final (st, q) = seededSermons();
    await t.pumpWidget(appWrap(Brightness.light, prekeScreen(st, q)));
    await t.pumpAndSettle();
    expect(AppSettings.load(st.root).sermonGrid, isFalse);
    expect(find.byType(GridView), findsNothing);
    expect(find.byKey(const ValueKey('preke.thumb-fallback')), findsWidgets);
    await t.tap(
      find.descendant(
        of: find.byKey(const ValueKey('ctl.preke.view')),
        matching: find.text('Rooster'),
      ),
    );
    await t.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(AppSettings.load(st.root).sermonGrid, isTrue);
    // A restart (new screen, same work folder) opens the grid.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(appWrap(Brightness.light, prekeScreen(st, q)));
    await t.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('a filter with no match says so', (t) async {
    await loadFonts();
    setView(t, 1100, 720);
    final (st, q) = seededSermons();
    await t.pumpWidget(appWrap(Brightness.light, prekeScreen(st, q)));
    await t.pumpAndSettle();
    await t.enterText(find.byKey(const ValueKey('ctl.preke.search')), 'zzzzzz');
    await t.pump();
    expect(find.textContaining('Geen preke pas'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/motion.dart';

import 'screen_kit.dart';

Widget wrap(Widget w, {bool reduced = false}) => appWrap(
  Brightness.light,
  Builder(
    builder: (c) => MediaQuery(
      data: MediaQuery.of(c).copyWith(disableAnimations: reduced),
      child: Scaffold(body: Center(child: w)),
    ),
  ),
);

double scaleOf(WidgetTester t, Finder f) => t
    .widget<AnimatedScale>(
      find.ancestor(of: f, matching: find.byType(AnimatedScale)).first,
    )
    .scale;

void main() {
  testWidgets('a pressed button shrinks to 0.97 and returns', (t) async {
    await loadFonts();
    await t.pumpWidget(
      wrap(FilledButton(onPressed: () {}, child: const Text('Ok'))),
    );
    expect(scaleOf(t, find.text('Ok')), 1);
    final g = await t.startGesture(t.getCenter(find.text('Ok')));
    await t.pump();
    expect(scaleOf(t, find.text('Ok')), 0.97);
    await g.up();
    await t.pumpAndSettle();
    expect(scaleOf(t, find.text('Ok')), 1);
  });

  testWidgets('Reveal fades in and slides up; reduced motion shows at once', (
    t,
  ) async {
    await t.pumpWidget(wrap(const Reveal(child: Text('ry'))));
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await t.pump(const Duration(milliseconds: 260));
    expect(t.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(wrap(const Reveal(child: Text('ry')), reduced: true));
    expect(find.byType(Opacity), findsNothing);
  });

  testWidgets('PopIn scales from 0.9 to 1', (t) async {
    await t.pumpWidget(wrap(const PopIn(child: Text('ok'))));
    expect(
      t
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(PopIn),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0],
      closeTo(0.9, 0.001),
    );
    await t.pump(const Duration(milliseconds: 260));
    expect(
      t
          .widget<Transform>(
            find
                .descendant(
                  of: find.byType(PopIn),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform
          .storage[0],
      closeTo(1, 0.001),
    );
  });

  testWidgets('CountText counts up in 150 ms, not at first build', (t) async {
    Widget w(int v) => wrap(CountText(value: v, format: (n) => '$n MB'));
    await t.pumpWidget(w(100));
    expect(find.text('100 MB'), findsOneWidget);
    await t.pumpWidget(w(200));
    await t.pump(const Duration(milliseconds: 75));
    final mid = find.textContaining(' MB');
    final n = int.parse(t.widget<Text>(mid).data!.split(' ').first);
    expect(n, inExclusiveRange(100, 200));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('200 MB'), findsOneWidget);
  });

  testWidgets('CountText with reduced motion jumps', (t) async {
    Widget w(int v) =>
        wrap(CountText(value: v, format: (n) => '$n MB'), reduced: true);
    await t.pumpWidget(w(100));
    await t.pumpWidget(w(200));
    await t.pump();
    expect(find.text('200 MB'), findsOneWidget);
  });
}

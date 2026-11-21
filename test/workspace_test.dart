// Step 6: the editor workspace, its sliders with number fields, zoom, jumps, reset and layout.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/features/review/review_screen.dart';

import 'screen_kit.dart';

Finder k(String id) => find.byKey(ValueKey('ctl.hersien.$id'));

Future<void> open(
  WidgetTester t,
  double w,
  double h, {
  Brightness b = Brightness.light,
}) async {
  await loadFonts();
  setView(t, w, h);
  final c = readyController();
  c.meta = FetchedMeta('x', Directory.systemTemp.createTempSync('ws'), {});
  await t.pumpWidget(appWrap(b, Scaffold(body: ReviewScreen(controller: c))));
  await t.pump(const Duration(seconds: 1));
  expect(t.takeException(), isNull);
}

void main() {
  testWidgets(
    'sermon start: slider drives the field, the field drives the slider',
    (t) async {
      await open(t, 1400, 800);
      expect(
        t.widget<TextField>(k('sermon-start-field')).controller!.text,
        '23:04',
      );
      await t.enterText(k('sermon-start-field'), '25:00');
      await t.testTextInput.receiveAction(TextInputAction.done);
      await t.pump();
      expect(t.widget<Slider>(k('sermon-start')).value, 1500);
      await t.drag(k('sermon-start'), const Offset(-40, 0));
      await t.pump();
      expect(t.widget<Slider>(k('sermon-start')).value, lessThan(1500));
      expect(
        t.widget<TextField>(k('sermon-start-field')).controller!.text,
        isNot('25:00'),
      );
    },
  );

  testWidgets('a bad time shows an error and changes nothing', (t) async {
    await open(t, 1400, 800);
    await t.enterText(k('sermon-start-field'), 'abc');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(find.textContaining('Ongeldig'), findsOneWidget);
    expect(t.widget<Slider>(k('sermon-start')).value, 1384);
  });

  testWidgets('zoom field and slider agree; jumps move the playhead by 5 s', (
    t,
  ) async {
    await open(t, 1400, 800);
    await t.enterText(k('zoom-field'), '4');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(t.widget<Slider>(k('zoom')).value, 4);
    await t.tap(k('forward5'));
    await t.pump();
    await t.tap(k('forward5'));
    await t.tap(k('back5'));
    await t.pump();
    expect(find.textContaining('00:05 / '), findsOneWidget);
  });

  testWidgets('Herstel returns the plan to the proposal', (t) async {
    await open(t, 1400, 800);
    expect(t.widget<OutlinedButton>(k('reset')).onPressed, isNull);
    await t.enterText(k('sermon-start-field'), '25:00');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pump();
    expect(t.widget<OutlinedButton>(k('reset')).onPressed, isNotNull);
    await t.tap(k('reset'));
    await t.pump();
    expect(
      t.widget<TextField>(k('sermon-start-field')).controller!.text,
      '23:04',
    );
  });

  testWidgets('under 1280 the properties are behind a toggle', (t) async {
    await open(t, 1100, 720);
    expect(find.byKey(const ValueKey('review.properties')), findsNothing);
    await t.tap(k('properties-toggle'));
    await t.pump();
    expect(find.byKey(const ValueKey('review.properties')), findsOneWidget);
    expect(k('properties-toggle'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1280.0, 720.0), (1920.0, 1080.0)]) {
      testWidgets('no overflow at $w x $h ${b.name}', (t) async {
        await open(t, w, h, b: b);
        for (final tab in ['shorts', 'cuts', 'output', 'transcript']) {
          if (w >= 1280) {
            await t.tap(k('tab-$tab'));
            await t.pump();
          }
          expect(t.takeException(), isNull, reason: tab);
        }
      });
    }
  }
}

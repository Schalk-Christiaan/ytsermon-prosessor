import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/app/theme.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/features/review/review_controller.dart';
import 'package:preekverwerker/features/review/review_screen.dart';
import 'package:preekverwerker/l10n/app_localizations.dart';

Future<void> _fonts() async {
  for (final (family, file) in [
    ('Source Serif 4', 'serif.ttf'),
    ('Source Sans 3', 'sans.ttf'),
  ]) {
    final l = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
        ),
      );
    await l.load();
  }
}

Widget _app(Brightness b, Widget home) => MaterialApp(
  theme: buildTheme(b),
  localizationsDelegates: const [
    L.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: const [Locale('af')],
  locale: const Locale('af'),
  home: home,
);

void main() {
  final shots = Directory('out/shots')..createSync(recursive: true);

  ReviewController ready() {
    final segs = parseJson3(
      File('test/fixtures/sample.af-orig.json3').readAsStringSync(),
    );
    final c = ReviewController();
    c.debugReady(
      FetchedMeta('x', Directory.systemTemp, {'title': 'Preek'}),
      segs,
      SermonPlan(
        sermonStart: 1384,
        sermonEnd: 3210,
        title: 'Die genade van God in Christus',
        description: 'Skriflesing en preek oor die genade.',
        shorts: [
          Short(start: 1500, end: 1561, title: 'Genade is nie verdien nie'),
          Short(start: 2400, end: 2450, title: 'Die kruis as middelpunt'),
        ],
      ),
      3600,
    );
    return c;
  }

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1920.0, 1080.0)]) {
      testWidgets('hersien ${b.name} ${w.toInt()}', (t) async {
        await _fonts();
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        final key = GlobalKey();
        await t.pumpWidget(
          _app(
            b,
            RepaintBoundary(
              key: key,
              child: Scaffold(body: ReviewScreen(controller: ready())),
            ),
          ),
        );
        await t.pump(const Duration(seconds: 1));
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final r =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await r.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File(p.join(shots.path, 'hersien-${b.name}-${w.toInt()}.png'))
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
    testWidgets('stelsel ${b.name}', (t) async {
      await _fonts();
      t.view.physicalSize = const Size(1100, 720);
      t.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await t.pumpWidget(
        _app(b, RepaintBoundary(key: key, child: const Shell())),
      );
      await t.pump();
      await t.tap(find.text('Instellings'));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      await t.runAsync(() async {
        await Future<void>.delayed(const Duration(seconds: 3));
        await t.pump();
        final r =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final img = await r.toImage();
        final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
        File(p.join(shots.path, 'stelsel-${b.name}.png'))
            .writeAsBytesSync(bytes!.buffer.asUint8List());
      });
    });
  }

  testWidgets('handle moves with keys and drag, plan.json follows', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final dir = Directory.systemTemp.createTempSync('plan');
    final c = ReviewController();
    c.debugReady(
      FetchedMeta('x', dir, {'title': 'Preek'}),
      parseJson3(File('test/fixtures/sample.af-orig.json3').readAsStringSync()),
      SermonPlan(
        sermonStart: 1384,
        sermonEnd: 3210,
        title: 't',
        description: 'd',
        shorts: [],
      ),
      3600,
    );
    await t.pumpWidget(
      _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
    );
    await t.pump(const Duration(seconds: 1));
    final start = find.bySemanticsLabel(RegExp('23:'));
    expect(start, findsWidgets);
    await t.tap(start.first);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(c.plan!.sermonStart, 1389);
    await t.drag(
      find.bySemanticsLabel(RegExp('23:')).first,
      const Offset(60, 0),
    );
    await t.pump();
    expect(c.plan!.sermonStart, greaterThan(1389));
    await t.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final saved = File(p.join(dir.path, 'plan.json')).readAsStringSync();
    expect(saved, contains('sermonStart'));
  });
}

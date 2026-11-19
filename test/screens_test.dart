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
import 'package:preekverwerker/core/cutter.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/youtube.dart';
import 'package:preekverwerker/features/playlists/playlists_screen.dart';
import 'package:preekverwerker/features/settings/settings_screen.dart';
import 'package:preekverwerker/features/setup/setup_screen.dart';
import 'package:preekverwerker/core/tools.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';
import 'package:preekverwerker/features/work/work_screen.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

import 'helpers.dart';

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
  // Material icons from the Flutter SDK, so icons render instead of boxes.
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final f = File(
    p.join(
      p.dirname(p.dirname(p.dirname(Platform.resolvedExecutable))),
      'material_fonts',
      'MaterialIcons-Regular.otf',
    ),
  );
  if (f.existsSync()) {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())))).load();
  }
}

/// Saves the RepaintBoundary under [key] as `out/shots/<name>.png`.
Future<void> _shot(WidgetTester t, GlobalKey key, String name) =>
    t.runAsync(() async {
      final r = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await r.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(p.join('out', 'shots', '$name.png'))
          .writeAsBytesSync(bytes!.buffer.asUint8List());
    });

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
    final c = testController().$1;
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
        cuts: [Span(2050, 2140)],
      ),
      3600,
    );
    c.prayerMarks = [Span(1384, 1500), Span(3100, 3210)];
    return c;
  }

  testWidgets('editor: I/O at the playhead, Ctrl+Z, transcript seeks', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final c = ready();
    final dir = Directory.systemTemp.createTempSync('plan');
    c.meta = FetchedMeta('x', dir, {});
    await t.pumpWidget(
      _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
    );
    await t.pump(const Duration(seconds: 1));
    c.position.value = 1400;
    await t.sendKeyEvent(LogicalKeyboardKey.keyI);
    await t.pump();
    expect(c.plan!.sermonStart, 1400);
    c.position.value = 3000;
    await t.sendKeyEvent(LogicalKeyboardKey.keyO);
    await t.pump();
    expect(c.plan!.sermonEnd, 3000);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(c.plan!.sermonEnd, 3210);
    await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await t.pump();
    expect(c.plan!.sermonEnd, 3000);
    // Typing an "i" in the title is text, not a shortcut.
    await t.enterText(find.byKey(const ValueKey('title')), 'i');
    await t.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(c.plan!.sermonStart, 1400);
    final line = find.byKey(ValueKey('line-${c.segments[2].start}'));
    await t.ensureVisible(line);
    await t.tap(line);
    expect(c.position.value, c.segments[2].start);
    await t.tap(find.text('Uitgeknip (1)'));
    await t.pump();
    expect(find.text('Uitgeknip 1'), findsOneWidget);
    expect(find.text('34:10 – 35:40'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('hersien opname sonder onderskrifte', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final c = testController().$1
      ..debugReady(
        FetchedMeta('opname-20261115-093000', Directory.systemTemp, {}),
        [],
        SermonPlan(
          sermonStart: 0,
          sermonEnd: 4200,
          title: 'Erediens 15 November',
          description: '',
          shorts: [],
        ),
        4200,
      );
    final key = GlobalKey();
    await t.pumpWidget(
      _app(
        Brightness.light,
        RepaintBoundary(
          key: key,
          child: Scaffold(body: ReviewScreen(controller: c)),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(
      find.text('Geen onderskrifte nie, stel die begin en einde self'),
      findsOneWidget,
    );
    await _shot(t, key, 'hersien-opname-light-1100');
  });

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
      final tc = testController();
      await t.pumpWidget(
        _app(
          b,
          RepaintBoundary(
            key: key,
            child: Shell(
              store: tc.$2,
              jobs: tc.$3,
              list: () async => [],
              settings: AppSettings.load(tc.$2.root)..setupDone = true,
            ),
          ),
        ),
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
    final c = testController().$1;
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
    final start = find.bySemanticsLabel(RegExp('Preek begin 23:'));
    expect(start, findsWidgets);
    await t.tap(start.first);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.pump();
    expect(c.plan!.sermonStart, 1385);
    await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await t.pump();
    expect(c.plan!.sermonStart, closeTo(1385.1, 1e-9));
    await t.drag(
      find.bySemanticsLabel(RegExp('Preek begin 23:')).first,
      const Offset(60, 0),
    );
    await t.pump();
    expect(c.plan!.sermonStart, greaterThan(1386));
    await t.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    final saved = File(p.join(dir.path, 'plan.json')).readAsStringSync();
    expect(saved, contains('sermonStart'));
  });

  testWidgets('invalid Short is marked and blocks approval until shortened', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final dir = Directory.systemTemp.createTempSync('plan');
    final c = testController().$1;
    c.debugReady(
      FetchedMeta('x', dir, {'title': 'Preek'}),
      parseJson3(File('test/fixtures/sample.af-orig.json3').readAsStringSync()),
      SermonPlan(
        sermonStart: 1384,
        sermonEnd: 3210,
        title: 't',
        description: 'd',
        shorts: [Short(start: 1500, end: 1592, title: 'lank')],
      ),
      3600,
    );
    await t.pumpWidget(
      _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
    );
    await t.pump(const Duration(seconds: 1));
    FilledButton approve() => t.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Keur goed en sny'),
    );
    expect(find.text('92 s; maks 90 s'), findsOneWidget);
    final key = GlobalKey();
    await t.pumpWidget(
      _app(
        Brightness.light,
        RepaintBoundary(
          key: key,
          child: Scaffold(body: ReviewScreen(controller: c)),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    final bytes = await t.runAsync(() async {
      final img =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage();
      return (await img.toByteData(format: ui.ImageByteFormat.png))!;
    });
    File(p.join(shots.path, 'hersien-short-fout-light.png'))
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(approve().onPressed, isNull);
    await t.drag(find.byType(Slider).first, const Offset(-60, 0));
    await t.pump();
    expect(c.plan!.shorts.single.end - 1500, lessThanOrEqualTo(90));
    expect(find.byIcon(Icons.error_outline_rounded), findsNothing);
    expect(approve().onPressed, isNotNull);
    await t.runAsync(
      () async => await Future<void>.delayed(const Duration(milliseconds: 100)),
    );
  });

  // --- Preke ---
  final items = [
    for (var i = 0; i < 40; i++)
      ChannelItem('id${i.toString().padLeft(9, '0')}', 'Preek $i', 3000.0 + i),
  ];

  (SermonStore, JobQueue) seeded() {
    final tc = testController();
    final store = tc.$2..merge(items);
    store.byId('id000000001')!.state = SermonState.gesny;
    store.byId('id000000001')!.date = '2026-11-15';
    store.byId('id000000001')!.scripture = 'Mattheus 12:22-37';
    store.byId('id000000002')!.state = SermonState.fout;
    return (store, tc.$3);
  }

  Widget preke(
    SermonStore st,
    JobQueue q, {
    Future<List<ChannelItem>> Function()? list,
    void Function(String)? onOpen,
  }) => Scaffold(
    body: SermonsScreen(
      key: UniqueKey(),
      store: st,
      jobs: q,
      list: list ?? () async => items,
      onOpen: onOpen ?? (_) {},
    ),
  );

  testWidgets('preke: lists rows, filters by state, searches', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = seeded();
    await t.pumpWidget(_app(Brightness.light, preke(st, q)));
    await t.pumpAndSettle();
    expect(find.text('Preek 0'), findsOneWidget);
    expect(find.text('Mattheus 12:22-37'), findsOneWidget);
    expect(find.text('2026-11-15'), findsOneWidget);
    await t.tap(find.widgetWithText(FilterChip, 'Fout'));
    await t.pumpAndSettle();
    expect(find.text('Preek 2'), findsOneWidget);
    expect(find.text('Preek 0'), findsNothing);
    await t.tap(find.widgetWithText(FilterChip, 'Fout'));
    await t.enterText(find.byType(TextField), 'Preek 3');
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.text('Preek 3'),
      ),
      findsOneWidget,
    );
    expect(find.text('Preek 0'), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('preke: "Verwerk volgende" queues the oldest nuut; row opens', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = seeded();
    final opened = <String>[];
    await t.pumpWidget(
      _app(Brightness.light, preke(st, q, onOpen: opened.add)),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Verwerk volgende'));
    await t.pump();
    expect(q.jobs.single.sermon, 'id000000039');
    expect(q.jobs.single.kind, JobKind.plan);
    await t.tap(find.text('Preek 0'));
    expect(opened, ['id000000000']);
    await t.pumpAndSettle();
  });

  testWidgets('preke: new services strip, empty and error states', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = seeded();
    final more = [
      const ChannelItem('newnewnew01', 'Nuut A', 1),
      const ChannelItem('newnewnew02', 'Nuut B', 1),
      ...items,
    ];
    await t.pumpWidget(
      _app(Brightness.light, preke(st, q, list: () async => more)),
    );
    await t.pumpAndSettle();
    expect(find.text('2 nuwe dienste'), findsOneWidget);

    final e = testController(seed: false);
    await t.pumpWidget(
      _app(Brightness.light, preke(e.$2, e.$3, list: () async => [])),
    );
    await t.pumpAndSettle();
    expect(find.text('Geen preke gevind nie'), findsOneWidget);

    await t.pumpWidget(
      _app(
        Brightness.light,
        preke(
          e.$2,
          e.$3,
          list: () async => throw StateError('yt-dlp ontbreek'),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Werk yt-dlp by'), findsOneWidget);
    expect(find.text('Probeer weer'), findsOneWidget);
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1920.0, 1080.0)]) {
      testWidgets('preke skermkiekie ${b.name} ${w.toInt()}', (t) async {
        await _fonts();
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        final key = GlobalKey();
        final (st, q) = seeded();
        await t.pumpWidget(
          _app(b, RepaintBoundary(key: key, child: preke(st, q))),
        );
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.runAsync(() async {
          final r =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final img = await r.toImage();
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          File(p.join(shots.path, 'preke-${b.name}-${w.toInt()}.png'))
              .writeAsBytesSync(bytes!.buffer.asUint8List());
        });
      });
    }
  }

  // --- Werk ---
  (SermonStore, JobQueue) workQueue({bool audio = false}) {
    final tc = testController(seed: false);
    final st = tc.$2
      ..merge([
        for (final id in [
          'aaaaaaaaaaa',
          'bbbbbbbbbbb',
          'ccccccccccc',
          'ddddddddddd',
        ])
          ChannelItem(id, 'Preek $id', 100),
      ]);
    st.byId('ccccccccccc')!.outputs = ['/tmp/2026-11-15 Preek.mp4'];
    final q = tc.$3;
    q.jobs.addAll([
      Job('ccccccccccc', JobKind.cut, status: JobStatus.klaar),
      Job(
        'ddddddddddd',
        JobKind.plan,
        status: JobStatus.fout,
        error: 'Ollama het nie geantwoord nie.',
        log: ['Connection refused', 'tweede reël'],
      ),
      Job(
        'aaaaaaaaaaa',
        audio ? JobKind.audio : JobKind.cut,
        status: JobStatus.besig,
      ),
      Job('bbbbbbbbbbb', JobKind.plan),
      if (audio) Job('ccccccccccc', JobKind.audio, status: JobStatus.klaar),
    ]);
    if (audio) {
      st.byId('ccccccccccc')!.outputs.add('/tmp/2026-11-15 Preek.mp3');
    }
    q.current = q.jobs[2];
    q.phase.value = audio ? JobPhase.audio : JobPhase.download;
    q.progress.value = 0.42;
    return (st, q);
  }

  testWidgets('werk: current, waiting, done and failed jobs', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = workQueue();
    final opened = <(String, bool)>[];
    var back = 0;
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: WorkScreen(
            store: st,
            jobs: q,
            onBack: () => back++,
            open: (path, {select = false}) async => opened.add((path, select)),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('Laai video af…'), findsOneWidget);
    expect(find.text('Kanselleer'), findsOneWidget);
    expect(find.text('Plan: Preek bbbbbbbbbbb'), findsOneWidget);
    expect(find.text('Ollama het nie geantwoord nie.'), findsOneWidget);
    expect(find.text('Probeer weer'), findsOneWidget);
    await t.tap(find.text('Speel'));
    await t.tap(find.text('Wys in gids'));
    expect(opened, [
      ('/tmp/2026-11-15 Preek.mp4', false),
      ('/tmp/2026-11-15 Preek.mp4', true),
    ]);
    await t.tap(find.text('Probeer weer'));
    await t.pump();
    expect(
      q.jobs.firstWhere((j) => j.sermon == 'ddddddddddd').status,
      isNot(JobStatus.fout),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    expect(back, 1);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('werk: "Klank vir WhatsApp" queues audio; mp3 shows in folder', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final tc = testController(seed: false);
    final st = tc.$2
      ..merge([
        const ChannelItem('ccccccccccc', 'Preek c', 100),
        const ChannelItem('eeeeeeeeeee', 'Preek e', 100),
      ]);
    st.byId('ccccccccccc')!.outputs = ['/tmp/2026-11-15 Preek.mp4'];
    st.byId('eeeeeeeeeee')!.outputs = [
      '/tmp/2026-11-08 E.mp4',
      '/tmp/2026-11-08 E.mp3',
    ];
    final q = tc.$3;
    q.jobs.addAll([
      Job('eeeeeeeeeee', JobKind.audio, status: JobStatus.klaar),
      Job('ccccccccccc', JobKind.cut, status: JobStatus.klaar),
    ]);
    final opened = <(String, bool)>[];
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: WorkScreen(
            store: st,
            jobs: q,
            onBack: () {},
            open: (path, {select = false}) async => opened.add((path, select)),
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Klank: Preek e'), findsOneWidget);
    await t.tap(find.text('Wys in gids').last);
    expect(opened, [('/tmp/2026-11-08 E.mp3', true)]);
    await t.tap(find.text('Klank vir WhatsApp'));
    await t.pump();
    expect(
      q.jobs.any((j) => j.sermon == 'ccccccccccc' && j.kind == JobKind.audio),
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1920.0, 1080.0)]) {
      for (final audio in [false, true]) {
        final name = audio ? 'werk-klank' : 'werk';
        testWidgets('$name skermkiekie ${b.name} ${w.toInt()}', (t) async {
          await _fonts();
          t.view.physicalSize = Size(w, h);
          t.view.devicePixelRatio = 1;
          final key = GlobalKey();
          final (st, q) = workQueue(audio: audio);
          await t.pumpWidget(
            _app(
              b,
              RepaintBoundary(
                key: key,
                child: Scaffold(
                  body: WorkScreen(store: st, jobs: q, onBack: () {}),
                ),
              ),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
          await t.runAsync(() async {
            final r =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final img = await r.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File(p.join(shots.path, '$name-${b.name}-${w.toInt()}.png'))
                .writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          await t.pumpWidget(const SizedBox());
        });
      }
    }
  }

  testWidgets('shell: rail reaches Hersien (empty hint) and Werk', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final tc = testController(seed: false);
    await t.pumpWidget(
      _app(
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
    await t.tap(find.text('Hersien'));
    await t.pump();
    expect(find.text("Kies 'n preek in Preke."), findsOneWidget);
    await t.tap(find.text('Werk'));
    await t.pump();
    expect(find.text('Niks in die ry nie.'), findsOneWidget);
    // SystemStatus probes the tools at start; let those processes finish.
    await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 3)));
    await t.pumpWidget(const SizedBox());
  });

  SermonStore playlistStore() {
    final st = testController(seed: false).$2
      ..merge([
        for (final (id, sc) in [
          ('aaaaaaaaaaa', 'Romeine 5:1-11'),
          ('bbbbbbbbbbb', 'Romeine 8:1-4'),
          ('ccccccccccc', 'Efesiërs 6:10-20'),
          ('ddddddddddd', null),
        ])
          ChannelItem(id, 'Preek $sc', 100),
      ]);
    for (final (id, sc, d) in [
      ('aaaaaaaaaaa', 'Romeine 5:1-11', '2026-11-15'),
      ('bbbbbbbbbbb', 'Romeine 8:1-4', '2026-11-08'),
      ('ccccccccccc', 'Efesiërs 6:10-20', '2026-11-01'),
      ('ddddddddddd', null, null),
    ]) {
      st.byId(id)!
        ..scripture = sc
        ..date = d;
    }
    return st;
  }

  testWidgets('snitlyste: preview counts per playlist; a rule toggles', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final st = playlistStore();
    final set = AppSettings.load(st.root);
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: PlaylistsScreen(store: st, settings: set),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Romeine'), findsOneWidget);
    expect(find.text('2 preke'), findsOneWidget);
    expect(find.text('Efesiërs'), findsOneWidget);
    expect(find.text('Sonder snitlys'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('rule-book')));
    await t.pump();
    expect(AppSettings.load(st.root).rules, ['year']);
    expect(find.text('Preke 2026'), findsOneWidget);
    expect(find.text('3 preke'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('template')), '{tema}!');
    await t.pump();
    expect(AppSettings.load(st.root).template, '{tema}!');
    expect(find.text('Preek Romeine 5:1-11!'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('instellings: no client file → says so; Koppel signs in', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final root = Directory.systemTemp.createTempSync('set');
    final set = AppSettings.load(root);
    String? token;
    final auth = GoogleAuth(
      File(set.clientFile),
      read: () async => token,
      write: (v) async => token = v,
    );
    var signIns = 0;
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: SettingsScreen(
            settings: set,
            auth: auth,
            signIn: () async {
              signIns++;
              token = 'rt';
            },
            system: const SizedBox(),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Geen kliënt-ID-lêer nie'), findsOneWidget);
    File(set.clientFile).writeAsStringSync('{"installed":{}}');
    await t.enterText(find.byKey(const ValueKey('clientFile')), set.clientFile);
    await t.testTextInput.receiveAction(TextInputAction.done);
    await t.pumpAndSettle();
    expect(find.text('Nie gekoppel nie'), findsOneWidget);
    await t.tap(find.text('Koppel kanaal'));
    await t.pumpAndSettle();
    expect(signIns, 1);
    expect(find.text('Gekoppel'), findsOneWidget);
    await t.tap(find.text('Ongelys'));
    await t.pumpAndSettle();
    expect(AppSettings.load(root).privacy, 'unlisted');
    await t.tap(find.text('Ontkoppel'));
    await t.pumpAndSettle();
    expect(token, isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('instellings: intro is chosen, shows its length, is removed', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final root = Directory.systemTemp.createTempSync('set');
    final set = AppSettings.load(root);
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: SettingsScreen(
            settings: set,
            auth: GoogleAuth(
              File(set.clientFile),
              read: () async => null,
              write: (_) async {},
            ),
            signIn: () async {},
            system: const SizedBox(),
            pickVideo: () async => '/klippies/intro.mp4',
            probe: (_) async => const MediaInfo(1920, 1080, '25/1', 12, true),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Geen'), findsNWidgets(2));
    await t.ensureVisible(find.text('Kies…').last);
    await t.tap(find.text('Kies…').first);
    await t.pumpAndSettle();
    expect(find.textContaining('intro.mp4 (00:12)'), findsOneWidget);
    expect(AppSettings.load(root).intro, '/klippies/intro.mp4');
    await t.tap(find.byTooltip('Verwyder'));
    await t.pumpAndSettle();
    expect(AppSettings.load(root).intro, isNull);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('werk: Laai op queues an upload; quota shows', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = workQueue();
    final quota = UploadQuota(File(p.join(st.root.path, 'quota.json')))
      ..take()
      ..take();
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: WorkScreen(store: st, jobs: q, onBack: () {}, quota: quota),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Oplaaie vandag: 2 van 100'), findsOneWidget);
    await t.tap(find.text('Laai op'));
    await t.pump();
    expect(
      q.jobs.any((j) => j.sermon == 'ccccccccccc' && j.kind == JobKind.upload),
      isTrue,
    );
    await t.pumpWidget(const SizedBox());
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1920.0, 1080.0)]) {
      testWidgets('fase 3 skermkiekies ${b.name} ${w.toInt()}', (t) async {
        await _fonts();
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        final st = playlistStore();
        final set = AppSettings.load(st.root);
        for (final (name, screen) in [
          ('snitlyste', PlaylistsScreen(store: st, settings: set)),
          (
            'instellings',
            SettingsScreen(
              settings: set,
              auth: GoogleAuth(
                File(set.clientFile),
                read: () async => null,
                write: (_) async {},
              ),
              signIn: () async {},
              system: const SizedBox(),
            ),
          ),
        ]) {
          final key = GlobalKey();
          await t.pumpWidget(
            _app(
              b,
              RepaintBoundary(
                key: key,
                child: Scaffold(body: screen),
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await _shot(t, key, '$name-${b.name}-${w.toInt()}');
        }
        await t.pumpWidget(const SizedBox());
      });
    }
  }

  /// A SetupScreen whose four checks the test flips by hand.
  (Widget, AppSettings, List<String>) setup({
    String ollama = 'notRunning',
    bool signedIn = false,
    bool client = true,
  }) {
    final root = Directory.systemTemp.createTempSync('setup');
    final set = AppSettings.load(root)..outDir = p.join(root.path, 'Preke');
    if (client) File(set.clientFile).writeAsStringSync('{"installed":{}}');
    var status = ollama;
    String? token = signedIn ? 'rt' : null;
    final calls = <String>[];
    final w = SetupScreen(
      settings: set,
      auth: GoogleAuth(
        File(set.clientFile),
        read: () async => token,
        write: (v) async => token = v,
      ),
      probe: () async => ToolStatus('ollama', status == 'ok', status),
      startOllama: () async {
        calls.add('start');
        status = 'model:qwen3:8b';
      },
      pull: ({required onProgress}) async {
        calls.add('pull');
        onProgress(0.5);
        status = 'ok';
      },
      signIn: () async {
        calls.add('signIn');
        token = 'rt';
      },
      onSettings: () => calls.add('settings'),
      onDone: () => calls.add('done'),
    );
    return (w, set, calls);
  }

  testWidgets('opstelling: one button per step; Begin werk once all four', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (w, set, calls) = setup();
    await t.pumpWidget(_app(Brightness.light, Scaffold(body: w)));
    await t.pumpAndSettle();
    expect(find.text('Nog nie'), findsNWidgets(4));
    FilledButton begin() =>
        t.widget<FilledButton>(find.widgetWithText(FilledButton, 'Begin werk'));
    expect(begin().onPressed, isNull);
    await t.tap(find.text('Begin Ollama'));
    await t.pumpAndSettle();
    await t.tap(find.text('Laai model af'));
    await t.pumpAndSettle();
    await t.tap(find.text('Koppel kanaal'));
    await t.pumpAndSettle();
    await t.tap(find.text('Maak gids'));
    await t.pumpAndSettle();
    expect(calls, ['start', 'pull', 'signIn']);
    expect(Directory(set.outDir).existsSync(), isTrue);
    expect(find.text('Klaar'), findsNWidgets(4));
    await t.tap(find.text('Begin werk'));
    await t.pumpAndSettle();
    expect(calls.last, 'done');
    expect(AppSettings.load(set.root).setupDone, isTrue);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('opstelling: no client file points to Instellings', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (w, _, calls) = setup(client: false);
    await t.pumpWidget(_app(Brightness.light, Scaffold(body: w)));
    await t.pumpAndSettle();
    expect(
      find.text('Kies eers die kliënt-ID-lêer in Instellings'),
      findsOneWidget,
    );
    await t.tap(find.text('Gaan na Instellings'));
    expect(calls, ['settings']);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('shell: starts on Opstelling until it is done', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final tc = testController();
    await t.pumpWidget(
      _app(
        Brightness.light,
        Shell(store: tc.$2, jobs: tc.$3, list: () async => []),
      ),
    );
    await t.pump();
    expect(find.text('Begin werk'), findsOneWidget);
    await t.pump(const Duration(seconds: 6)); // probe timeout
    await t.pumpWidget(const SizedBox());
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1920.0, 1080.0)]) {
      testWidgets('opstelling skermkiekie ${b.name} ${w.toInt()}', (t) async {
        await _fonts();
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        final (screen, _, _) = setup(ollama: 'model:qwen3:8b');
        final key = GlobalKey();
        await t.pumpWidget(
          _app(
            b,
            RepaintBoundary(
              key: key,
              child: Scaffold(body: screen),
            ),
          ),
        );
        await t.pumpAndSettle();
        await _shot(t, key, 'opstelling-${b.name}-${w.toInt()}');
        await t.pumpWidget(const SizedBox());
      });
    }
  }
}

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
import 'package:preekverwerker/features/library/library_screen.dart';
import 'package:preekverwerker/features/playlists/playlists_screen.dart';
import 'package:preekverwerker/features/settings/settings_screen.dart';
import 'package:preekverwerker/features/setup/setup_screen.dart';
import 'package:preekverwerker/core/tools.dart';
import 'package:preekverwerker/features/settings/system_status.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';
import 'package:preekverwerker/features/work/work_screen.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

import 'helpers.dart';
import 'library_test.dart' show twoServices;

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

/// Where the screenshots go (env SHOTS, e.g. docs/kiekies/nagskof/voor).
final _shotsDir = Platform.environment['SHOTS'] ?? 'out/shots';

/// Saves the RepaintBoundary under [key] as `<_shotsDir>/<name>.png`.
Future<void> _shot(WidgetTester t, GlobalKey key, String name) =>
    t.runAsync(() async {
      final r = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final img = await r.toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File(p.join(_shotsDir, '$name.png'))
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
  final shots = Directory(_shotsDir)..createSync(recursive: true);

  ReviewController ready([Directory? dir]) {
    final segs = parseJson3(
      File('test/fixtures/sample.af-orig.json3').readAsStringSync(),
    );
    final c = testController().$1;
    c.debugReady(
      FetchedMeta('x', dir ?? Directory.systemTemp, {'title': 'Preek'}),
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

  testWidgets('hersien: "Keur goed en sny" offers the way to Werk', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    var work = 0;
    await t.pumpWidget(
      _app(
        Brightness.light,
        Scaffold(
          body: ReviewScreen(controller: ready(), onWork: () => work++),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Keur goed en sny'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await t.tap(find.widgetWithText(SnackBarAction, 'Werk'));
    expect(work, 1);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets(
    'hersien: unsure bounds show the reason and jump to the boundary',
    (t) async {
      await _fonts();
      t.view.physicalSize = const Size(1100, 720);
      t.view.devicePixelRatio = 1;
      final c = ready();
      c.plan!.doubt = BoundsDoubt.noPrayerAfter;
      await t.pumpWidget(
        _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
      );
      await t.pump(const Duration(seconds: 1));
      expect(find.textContaining('Geen gebed ná die preek'), findsOneWidget);
      await t.tap(find.text('Gaan na die grens'));
      await t.pump();
      expect(c.position.value, 3210);
      c.plan!.doubt = null;
      await t.pumpWidget(
        _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
      );
      expect(find.text('Gaan na die grens'), findsNothing);
    },
  );

  testWidgets('hersien: an uploaded sermon offers "Werk op YouTube by"', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final c = ready();
    c.store.save(c.sermon!..state = SermonState.opgelaai);
    final sent = <String>[];
    c.updateYouTube = (id) async {
      sent.add(id);
      return 3;
    };
    await t.pumpWidget(
      _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
    );
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Werk op YouTube by'));
    await t.pump();
    await t.pump();
    expect(sent, ['x']);
    expect(find.text('3 video\'s op YouTube bygewerk'), findsOneWidget);
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('editor: I/O at the playhead, Ctrl+Z, transcript seeks', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1400, 800);
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
    await t.enterText(find.byKey(const ValueKey('ctl.hersien.title')), 'i');
    await t.sendKeyEvent(LogicalKeyboardKey.keyI);
    expect(c.plan!.sermonStart, 1400);
    await t.tap(find.byKey(const ValueKey('ctl.hersien.tab-transcript')));
    await t.pump();
    final line = find.byKey(
      ValueKey('ctl.hersien.transcript-line.${c.segments[2].start}'),
    );
    await t.ensureVisible(line);
    await t.tap(line);
    expect(c.position.value, c.segments[2].start);
    c.selectCut(c.plan!.cuts.first);
    await t.pump();
    expect(find.text('Uitgeknip 1'), findsOneWidget);
    expect(find.text('34:10 – 35:40'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('hersien opname sonder onderskrifte', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1400, 800);
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
    await t.tap(find.byKey(const ValueKey('ctl.hersien.tab-transcript')));
    await t.pump();
    expect(
      find.text('Geen onderskrifte nie, stel die begin en einde self'),
      findsOneWidget,
    );
    await _shot(t, key, 'hersien-opname-light-1100');
  });

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1600.0, 900.0)]) {
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
      // The encoder probe runs two processes in turn; probe in real async so no timer outlives the test.
      await t.runAsync(videoEncoder);
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

  for (final b in Brightness.values) {
    testWidgets('stelsel-rye ${b.name}', (t) async {
      await _fonts();
      t.view.physicalSize = const Size(1100, 420);
      t.view.devicePixelRatio = 1;
      final key = GlobalKey();
      await t.pumpWidget(
        _app(
          b,
          RepaintBoundary(
            key: key,
            child: Scaffold(
              body: SystemStatus(
                probe: () async => const [
                  ToolStatus('yt-dlp', true, '2026.08.19'),
                  ToolStatus('ffmpeg', true, '9.0.2'),
                  ToolStatus('ffprobe', true, '9.0.2'),
                  ToolStatus('ollama', true, '0.12 · qwen3:8b'),
                  ToolStatus('encoder', true, 'h264_nvenc'),
                ],
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      await _shot(t, key, 'stelsel-rye-${b.name}');
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
    t.view.physicalSize = const Size(1400, 800);
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
    c.selectShort(c.plan!.shorts.first);
    await t.pump();
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
    c.selectShort(c.plan!.shorts.first);
    await t.pump();
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
    await t.drag(
      find.byKey(const ValueKey('ctl.hersien.short-length')),
      const Offset(-60, 0),
    );
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
    Future<String?> Function()? pickVideo,
    Future<Sermon> Function(File, String, DateTime)? importFile,
  }) => Scaffold(
    body: SermonsScreen(
      key: UniqueKey(),
      store: st,
      jobs: q,
      list: list ?? () async => items,
      onOpen: onOpen ?? (_) {},
      pickVideo: pickVideo ?? () async => null,
      importFile: importFile,
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

  testWidgets('preke: "Verwerk nuutste diens" plans the newest and opens it', (
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
    await t.tap(find.text('Verwerk nuutste diens'));
    await t.pumpAndSettle();
    final newest = st.sorted.first.id;
    expect(q.jobs.single.sermon, newest);
    expect(opened, [newest]);
    st.byId('id000000003')!.state = SermonState.opgelaai;
    await t.tap(find.widgetWithText(FilterChip, 'Nie opgelaai nie'));
    await t.pumpAndSettle();
    expect(find.text('Preek 3'), findsNothing);
    expect(find.text('Preek 4'), findsOneWidget);
  });

  testWidgets('preke: "Voer opname in" picks, asks title and date, opens', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = seeded();
    final opened = <String>[];
    final got = <String>[];
    await t.pumpWidget(
      _app(
        Brightness.light,
        preke(
          st,
          q,
          onOpen: opened.add,
          pickVideo: () async => p.join('usb', 'Kersdiens.mp4'),
          importFile: (f, title, date) async {
            got.add('${p.basename(f.path)}|$title');
            return Sermon('opname-1', title, 60, state: SermonState.beplan);
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Voer opname in'));
    await t.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Kersdiens'), findsOneWidget);
    await t.enterText(find.widgetWithText(TextField, 'Kersdiens'), 'Kersdag');
    await t.tap(find.text('Voer in'));
    await t.pumpAndSettle();
    expect(got, ['Kersdiens.mp4|Kersdag']);
    expect(opened, ['opname-1']);
  });

  testWidgets('preke: "Verwerk nuutste diens" skips a local recording', (
    t,
  ) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final (st, q) = seeded();
    st.save(Sermon('opname-20261226-090507', 'Opname', 60, order: -5));
    final opened = <String>[];
    await t.pumpWidget(
      _app(Brightness.light, preke(st, q, onOpen: opened.add)),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Verwerk nuutste diens'));
    await t.pumpAndSettle();
    expect(opened, ['id000000000']);
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
    for (final (w, h) in [
      (1100.0, 720.0),
      (1600.0, 900.0),
      if (b == Brightness.light) (750.0, 720.0),
    ]) {
      testWidgets('preke skermkiekie ${b.name} ${w.toInt()}', (t) async {
        await _fonts();
        t.view.physicalSize = Size(w, h);
        t.view.devicePixelRatio = 1;
        final key = GlobalKey();
        final (st, q) = seeded();
        st.byId('id000000000')!
          ..title =
              'Die genade van God wat ons dra deur elke seisoen van die lewe'
          ..scripture = '2 Korinthiërs 12:1-10';
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
    st.byId('ccccccccccc')!.outputs = [
      '/tmp/2026-11-15/Volle preek.mp4',
      '/tmp/2026-11-15/Short 1.mp4',
    ];
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
      st.byId('ccccccccccc')!.outputs.add('/tmp/2026-11-15/Volle preek.mp3');
    }
    q.current = q.jobs[2];
    q.phase.value = audio ? JobPhase.audio : JobPhase.download;
    q.progress.value = 0.42;
    return (st, q);
  }

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1600.0, 900.0)]) {
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

  // Round 2 shots: Werk as cards, Preke with a busy sermon, Hersien with a selected Short (panel after its slide-in).
  testWidgets('werk rooster skermkiekie', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 900);
    t.view.devicePixelRatio = 1;
    final key = GlobalKey();
    final (st, q) = workQueue(audio: true);
    final s = AppSettings.load(st.root)..sermonGrid = true;
    await t.pumpWidget(
      _app(
        Brightness.light,
        RepaintBoundary(
          key: key,
          child: Scaffold(
            body: WorkScreen(store: st, jobs: q, settings: s, onBack: () {}),
          ),
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await _shot(t, key, 'werk-rooster-light-1100');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('preke besig skermkiekie', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 720);
    t.view.devicePixelRatio = 1;
    final key = GlobalKey();
    final (st, q) = seeded();
    q.current = Job(st.sorted.first.id, JobKind.cut, status: JobStatus.besig);
    q.phase.value = JobPhase.cut;
    q.progress.value = 0.6;
    await t.pumpWidget(
      _app(Brightness.light, RepaintBoundary(key: key, child: preke(st, q))),
    );
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
    await _shot(t, key, 'preke-besig-light-1100');
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('hersien keuse skermkiekie', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1400, 800);
    t.view.devicePixelRatio = 1;
    final c = ready();
    c.selectShort(c.plan!.shorts.first);
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
    expect(t.takeException(), isNull);
    await _shot(t, key, 'hersien-keuse-light-1400');
  });

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
    t.view.physicalSize = const Size(1100, 1000);
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
    await t.tap(find.byKey(const ValueKey('ctl.snitlyste.rule-book')));
    await t.pump();
    expect(AppSettings.load(st.root).rules, ['year']);
    expect(find.text('Preke 2026'), findsOneWidget);
    expect(find.text('3 preke'), findsOneWidget);
    await t.enterText(
      find.byKey(const ValueKey('ctl.snitlyste.template')),
      '{tema}!',
    );
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
    await t.enterText(
      find.byKey(const ValueKey('ctl.instellings.client-file')),
      set.clientFile,
    );
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

  for (final b in Brightness.values) {
    for (final (w, h) in [(1100.0, 720.0), (1600.0, 900.0)]) {
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
    for (final (w, h) in [(1100.0, 720.0), (1600.0, 900.0)]) {
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

  testWidgets('hersien: output chips and Aand are remembered', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1280, 800);
    t.view.devicePixelRatio = 1;
    final d = Directory.systemTemp.createTempSync('hers');
    addTearDown(() => d.deleteSync(recursive: true));
    final c = ready(d);
    await t.pumpWidget(
      _app(Brightness.light, Scaffold(body: ReviewScreen(controller: c))),
    );
    await t.pump(const Duration(seconds: 1));
    expect(AppSettings.load(c.store.root).exports, {'full', 'word', 'songs'});
    await t.tap(find.widgetWithText(FilterChip, 'Net die woord'));
    await t.pump();
    expect(AppSettings.load(c.store.root).exports, {'full', 'songs'});
    await t.tap(find.text('Aand'));
    await t.pump();
    expect(c.service.evening, isTrue);
    expect(
      File('${c.meta!.dir.path}/service.json').readAsStringSync(),
      contains('"evening":true'),
    );
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 5));
  });

  testWidgets('snitlyste: WhatsApp template shows a preview', (t) async {
    await _fonts();
    t.view.physicalSize = const Size(1100, 1400);
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
    final field = find.byKey(const ValueKey('ctl.snitlyste.whatsapp'));
    await t.ensureVisible(field);
    await t.enterText(field, 'Tema: {tema}\nFokus: {fokus}');
    await t.pump();
    expect(AppSettings.load(st.root).whatsappTemplate, contains('{fokus}'));
    final shown = t.widget<Text>(find.byKey(const ValueKey('whatsappPreview')));
    expect(shown.data, startsWith('Tema: Preek '));
    expect(shown.data, isNot(contains('Fokus')));
    await t.pumpWidget(const SizedBox());
  });

  for (final b in Brightness.values) {
    for (final sang in [false, true]) {
      testWidgets(
        'biblioteek skermkiekie ${b.name} ${sang ? 'sang' : 'preke'}',
        (t) async {
          await _fonts();
          t.view.physicalSize = const Size(1100, 720);
          t.view.devicePixelRatio = 1;
          final out = twoServices();
          addTearDown(() => out.deleteSync(recursive: true));
          final set = AppSettings.load(
            Directory.systemTemp.createTempSync('ls'),
          )..outDir = out.path;
          final key = GlobalKey();
          await t.pumpWidget(
            _app(
              b,
              RepaintBoundary(
                key: key,
                child: Scaffold(body: LibraryScreen(settings: set)),
              ),
            ),
          );
          if (sang) await t.tap(find.text('Sang'));
          await t.pump();
          expect(t.takeException(), isNull);
          await t.runAsync(() async {
            final r =
                key.currentContext!.findRenderObject() as RenderRepaintBoundary;
            final img = await r.toImage();
            final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
            File(
              p.join(
                shots.path,
                'biblioteek-${sang ? 'sang' : 'preke'}-${b.name}.png',
              ),
            ).writeAsBytesSync(bytes!.buffer.asUint8List());
          });
          await t.pumpWidget(const SizedBox());
        },
      );
    }
  }
}

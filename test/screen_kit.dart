// Shared by controls_test / controls_inventory tests: one builder per screen, in a given state.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/app/theme.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/cutter.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/tools.dart';
import 'package:preekverwerker/core/youtube.dart';
import 'package:preekverwerker/features/library/library_screen.dart';
import 'package:preekverwerker/features/review/review_controller.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';
import 'package:preekverwerker/features/settings/settings_screen.dart';
import 'package:preekverwerker/features/setup/setup_screen.dart';
import 'package:preekverwerker/l10n/app_localizations.dart';

import 'helpers.dart';
import 'library_test.dart' show twoServices;

Future<void> loadFonts() async {
  for (final (family, file) in [
    ('Source Serif 4', 'serif.ttf'),
    ('Source Sans 3', 'sans.ttf'),
  ]) {
    await (FontLoader(family)..addFont(
          Future.value(
            ByteData.sublistView(File('assets/fonts/$file').readAsBytesSync()),
          ),
        ))
        .load();
  }
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

Widget appWrap(Brightness b, Widget home) => MaterialApp(
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

void setView(WidgetTester t, double w, double h) {
  t.view.physicalSize = Size(w, h);
  t.view.devicePixelRatio = 1;
}

/// A ready Hersien controller on the sample captions with a two-Short plan.
ReviewController readyController({
  List<Short>? shorts,
  List<Span>? cuts,
  Stream<Duration>? positions,
}) {
  final segs = parseJson3(
    File('test/fixtures/sample.af-orig.json3').readAsStringSync(),
  );
  final c = testController(positions: positions).$1;
  c.debugReady(
    FetchedMeta('x', Directory.systemTemp, {'title': 'Preek'}),
    segs,
    SermonPlan(
      sermonStart: 1384,
      sermonEnd: 3210,
      title: 'Die genade van God in Christus',
      description: 'Skriflesing en preek oor die genade.',
      shorts:
          shorts ??
          [
            Short(start: 1500, end: 1561, title: 'Genade is nie verdien nie'),
            Short(start: 2400, end: 2450, title: 'Die kruis as middelpunt'),
          ],
      cuts: cuts ?? [Span(2050, 2140)],
    ),
    3600,
  );
  c.prayerMarks = [Span(1384, 1500), Span(3100, 3210)];
  return c;
}

final sampleItems = [
  for (var i = 0; i < 40; i++)
    ChannelItem('id${i.toString().padLeft(9, '0')}', 'Preek $i', 3000.0 + i),
];

(SermonStore, JobQueue) seededSermons() {
  final tc = testController();
  final store = tc.$2..merge(sampleItems);
  store.byId('id000000001')!
    ..state = SermonState.gesny
    ..date = '2026-11-15'
    ..scripture = 'Mattheus 12:22-37';
  store.byId('id000000002')!.state = SermonState.fout;
  return (store, tc.$3);
}

Widget prekeScreen(
  SermonStore st,
  JobQueue q, {
  void Function(String)? onOpen,
  Future<String?> Function()? pickVideo,
  Future<List<ChannelItem>> Function()? list,
}) => Scaffold(
  body: SermonsScreen(
    key: UniqueKey(),
    store: st,
    jobs: q,
    list: list ?? () async => sampleItems,
    onOpen: onOpen ?? (_) {},
    pickVideo: pickVideo ?? () async => null,
  ),
);

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
  if (audio) st.byId('ccccccccccc')!.outputs.add('/tmp/2026-11-15 Preek.mp3');
  q.current = q.jobs[2];
  q.phase.value = audio ? JobPhase.audio : JobPhase.download;
  q.progress.value = 0.42;
  return (st, q);
}

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

/// Instellings on a temp root; [token] non-null means signed in, [client] writes the client file.
(Widget, AppSettings) settingsScreen({
  String? token,
  bool client = true,
  void Function()? onSetup,
  Future<String?> Function()? pickVideo,
  Widget system = const SizedBox(),
  Future<String> Function(String)? validate,
}) {
  final root = Directory.systemTemp.createTempSync('set');
  final set = AppSettings.load(root);
  if (client) File(set.clientFile).writeAsStringSync('{"installed":{}}');
  String? tok = token;
  final w = SettingsScreen(
    settings: set,
    auth: GoogleAuth(
      File(set.clientFile),
      read: () async => tok,
      write: (v) async => tok = v,
    ),
    signIn: () async => tok = 'rt',
    system: system,
    validateChannel: validate ?? (u) async => 'Kerk',
    pickVideo: pickVideo ?? () async => null,
    onSetup: onSetup ?? () {},
    probe: (_) async => const MediaInfo(1920, 1080, '25', 12, true),
  );
  return (Scaffold(body: w), set);
}

(Widget, AppSettings, List<String>) setupScreen({
  String ollama = 'notRunning',
  bool signedIn = false,
  Future<String> Function(String)? validate,
}) {
  final root = Directory.systemTemp.createTempSync('setup');
  final set = AppSettings.load(root)..outDir = p.join(root.path, 'Preke');
  File(set.clientFile).writeAsStringSync('{"installed":{}}');
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
    validateChannel: validate ?? (u) async => 'Kerk',
  );
  return (Scaffold(body: w), set, calls);
}

(Widget, AppSettings, List<(String, bool)>) libraryScreen() {
  final out = twoServices();
  final set = AppSettings.load(Directory.systemTemp.createTempSync('lset'))
    ..outDir = out.path;
  final opened = <(String, bool)>[];
  return (
    Scaffold(
      body: LibraryScreen(
        settings: set,
        open: (path, {select = false}) async => opened.add((path, select)),
      ),
    ),
    set,
    opened,
  );
}

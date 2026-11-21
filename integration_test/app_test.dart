// @stelsel integration_test/app_test
//   soort: toets · wanneer: flutter test integration_test/app_test.dart -d linux
//   groep: toetse | Toetse
//   doel: die regte app (PreekApp, regte speler) deur die hoofvloei: Preke, kies, werkvlak, hakie, speel, zoem, Keur goed en sny, Werk, klaar; lig en donker; geen internet of Ollama (fixtures, ffmpeg maak die video)
//   status: bou
import 'dart:io';

import 'package:flutter/material.dart';

import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/youtube.dart';
import 'package:preekverwerker/main.dart';

Finder key(String id) => find.byKey(ValueKey('ctl.$id'));

Future<void> settle(WidgetTester t, [int ms = 600]) async {
  await t.pump(Duration(milliseconds: ms));
  await t.pump(const Duration(milliseconds: 400));
}

Future<void> tap(WidgetTester t, String id) async {
  await t.ensureVisible(key(id).first);
  await t.tap(key(id).first);
  await settle(t);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final frame = GlobalKey();
  MediaKit.ensureInitialized();
  // SHOTS=<dir> keeps a screenshot per screen.
  final shots = Platform.environment['SHOTS'];

  for (final dark in [false, true]) {
    testWidgets('Preke to cut to done (${dark ? 'dark' : 'light'})', (t) async {
      final root = Directory.systemTemp.createTempSync('iv');
      addTearDown(() => root.deleteSync(recursive: true));
      const id = 'YWz5gf0onjk';
      final dir = Directory(p.join(root.path, id))..createSync();
      File('test/fixtures/sample.af-orig.json3')
          .copySync(p.join(dir.path, '$id.af-orig.json3'));
      File(p.join(dir.path, '$id.info.json')).writeAsStringSync(
        '{"id":"$id","title":"Die genade van God","duration":3600,'
        '"upload_date":"20261115","thumbnail":""}',
      );
      final ff = await Process.run('ffmpeg', [
        '-v',
        'error',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=640x360:rate=10:duration=40',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=40',
        '-shortest',
        '-pix_fmt',
        'yuv420p',
        p.join(dir.path, 'video.mp4'),
      ]);
      expect(ff.exitCode, 0, reason: '${ff.stderr}');
      savePlan(
        dir,
        SermonPlan(
          sermonStart: 1384,
          sermonEnd: 3210,
          title: 'Die genade van God in Christus',
          description: 'Skriflesing en preek oor die genade.',
          shorts: [
            Short(start: 1500, end: 1561, title: 'Genade is nie verdien nie'),
          ],
          cuts: [],
        ),
      );
      final store = SermonStore(root)
        ..load()
        ..merge([const ChannelItem(id, 'Die genade van God', 3600)]);
      final settings = AppSettings.load(root)..setupDone = true;
      final jobs = JobQueue(
        store,
        plan: (_) async {},
        cut: (ctx) async {
          ctx.progress(0.5);
          await Future<void>.delayed(const Duration(milliseconds: 300));
          store.save(
            store.byId(ctx.id)!
              ..state = SermonState.gesny
              ..outputs = [p.join(root.path, 'preek.mp4')],
          );
        },
        audio: (_) async {},
      )..start();
      final auth = GoogleAuth(
        File(settings.clientFile),
        read: () async => null,
        write: (_) async {},
      );

      await t.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => t.binding.setSurfaceSize(null));
      await t.pumpWidget(
        RepaintBoundary(
          key: frame,
          child: PreekApp(
            store: store,
            jobs: jobs,
            settings: settings,
            auth: auth,
            quota: UploadQuota(File(p.join(root.path, 'quota.json'))),
            themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          ),
        ),
      );
      await settle(t);
      Future<void> shot(String n) async {
        if (shots == null) return;
        // takeScreenshot is not implemented on Linux: paint the app's RepaintBoundary.
        final b = t.renderObject(find.byKey(frame)) as RenderRepaintBoundary;
        final img = await t.runAsync(() => b.toImage());
        final png = await t.runAsync(
          () => img!.toByteData(format: ui.ImageByteFormat.png),
        );
        File(p.join(shots, '${dark ? 'donker' : 'lig'}-$n.png'))
            .writeAsBytesSync(png!.buffer.asUint8List());
      }

      // Preke: pick the sermon and open it in the workspace.
      expect(find.text('Die genade van God'), findsWidgets);
      await shot('1-preke');
      await tap(t, 'preke.row');
      await settle(t, 1500);
      expect(key('hersien.timeline'), findsOneWidget);
      await shot('2-werkvlak');

      // Handle, play 2 s, zoom.
      final h = key('hersien.handle-start');
      expect(h, findsOneWidget);
      final before = File(p.join(dir.path, kPlanFile)).readAsStringSync();
      await t.drag(h, const Offset(40, 0));
      await settle(t);
      expect(
        File(p.join(dir.path, kPlanFile)).readAsStringSync(),
        isNot(before),
      );
      await tap(t, 'hersien.play-pause');
      await t.pump(const Duration(seconds: 2));
      await tap(t, 'hersien.play-pause');
      final zoom = key('hersien.zoom');
      expect(zoom, findsOneWidget);
      final r = t.getRect(zoom);
      await t.tapAt(Offset(r.left + r.width * 0.9, r.center.dy));
      await settle(t);
      expect(t.widget<Slider>(zoom).value, greaterThan(8));
      await shot('3-geredigeer');

      // Approve and cut, then Werk shows it and it ends in the done list.
      await tap(t, 'hersien.approve');
      await tap(t, 'skulp.nav-2');
      await settle(t, 1500);
      await shot('4-werk');
      expect(store.byId(id)!.state, SermonState.gesny);
      expect(
        jobs.jobs.any(
          (j) =>
              j.sermon == id &&
              j.kind == JobKind.cut &&
              j.status == JobStatus.klaar,
        ),
        isTrue,
      );
      expect(key('werk.play'), findsWidgets);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}

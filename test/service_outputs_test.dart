import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/bounds.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/cutter.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/service_info.dart';
import 'package:preekverwerker/core/sound.dart';
import 'package:preekverwerker/core/store.dart';

import 'fixture_sermons.dart';

const _sast = Duration(hours: 2);

ServiceInfo _ywz() => ServiceInfo.fromInfo(
  jsonDecode(File('test/fixtures/info/YWz5gf0onjk.json').readAsStringSync())
      as Map<String, dynamic>,
  offset: _sast,
);

void main() {
  test('serviceDir: year / date Aand - theme, illegal characters removed', () {
    expect(
      serviceDir('/uit', _ywz()),
      '/uit/2026/2026-11-15 Aand - Uit die oorvloed van die hart praat die mond',
    );
    final i = ServiceInfo(date: '2026-11-15', theme: 'Wat? A/B');
    expect(serviceDir('/uit', i), '/uit/2026/2026-11-15 Oggend - Wat AB');
    expect(
      serviceDir('/uit', ServiceInfo(date: '2026-11-15')),
      '/uit/2026/2026-11-15 Oggend',
    );
  });

  test('whatsappText of YWz5gf0onjk is the approved text', () {
    expect(
      whatsappText(kWhatsappTemplate, _ywz()),
      '*Aanddiens · Sondag 15 November 2026*\n'
      'Tema: Uit die oorvloed van die hart praat die mond\n'
      'Skriflesing: Mattheus 12:22-37\n'
      'Fokus: Mattheus 12:34,36,37\n'
      'NGB Artikel 37',
    );
  });

  test('whatsappText leaves out a line whose field is empty', () {
    final i = ServiceInfo(date: '2026-11-15', theme: 'Genade');
    expect(
      whatsappText(kWhatsappTemplate, i),
      '*Oggenddiens · Sondag 15 November 2026*\nTema: Genade',
    );
  });

  test('songArgs: part, mp3 and the ID3 title, album and track', () {
    final a = songArgs(
      'v.mp4',
      Span(10, 20.5),
      'o.mp3',
      title: 'Psalm 42',
      album: 'GK Oranjerivier 2026-11-15 Aanddiens',
      track: 2,
    );
    expect(
      a,
      containsAllInOrder(['-ss', '10.000', '-to', '20.500', '-i', 'v.mp4']),
    );
    expect(
      a,
      containsAllInOrder([
        '-metadata',
        'title=Psalm 42',
        '-metadata',
        'album=GK Oranjerivier 2026-11-15 Aanddiens',
        '-metadata',
        'track=2',
      ]),
    );
    expect(a.last, 'o.mp3');
  });

  test('wordParts: no prayers, no music, inside the cut, cuts removed', () {
    ({double start, double end, BlockLabel label}) b(
      double s,
      double e,
      BlockLabel l,
    ) => (start: s, end: e, label: l);
    final labels = [
      b(0, 10, BlockLabel.gebed),
      b(12, 20, BlockLabel.skriflesing),
      b(22, 30, BlockLabel.preek),
      b(40, 50, BlockLabel.preek), // music 31-39 between
      b(52, 60, BlockLabel.gebed),
    ];
    final sound = [TimeBlock(31, 39, SegmentKind.music)];
    final parts = wordParts(labels, sound, [Span(0, 60)]);
    expect(parts.map((s) => (s.start, s.end)), [(12.0, 30.0), (40.0, 50.0)]);
    final cut = wordParts(labels, sound, [Span(0, 25), Span(45, 60)]);
    expect(cut.map((s) => (s.start, s.end)), [(12.0, 25.0), (45.0, 50.0)]);
  });

  final video = File('/tmp/claude-1000/fx/vid/YWz5gf0onjk.mp4');
  test(
    'cutJob on YWz5gf0onjk makes the outputs in the service folder (real ffmpeg, E2E)',
    () async {
      final root = Directory.systemTemp.createTempSync('svc');
      addTearDown(() => root.deleteSync(recursive: true));
      const id = 'YWz5gf0onjk';
      final dir = Directory(p.join(root.path, id))..createSync();
      File('test/fixtures/info/$id.json')
          .copySync(p.join(dir.path, '$id.info.json'));
      File(p.join(dir.path, '$id.af-orig.json3')).writeAsBytesSync(
        gzip.decode(
          File('test/fixtures/$id.af-orig.json3.gz').readAsBytesSync(),
        ),
      );
      Link(p.join(dir.path, 'video.mp4')).createSync(video.path);
      saveAnalysis(dir, await fixtureAnalysis(id));
      saveSound(dir, fixtureSound(id));
      final plan = SermonPlan(
        sermonStart: 886.64,
        sermonEnd: 3361.53,
        title: 'Uit die oorvloed van die hart praat die mond',
        description: '',
        shorts: [],
      );
      savePlan(dir, plan);
      final store = SermonStore(root)
        ..load()
        ..merge([const ChannelItem(id, 'A', 1)]);
      final out = Directory(p.join(root.path, 'uit'));
      final q = JobQueue(store, plan: (_) async {}, out: out);
      q.enqueue(id, JobKind.cut);
      await q.idle;
      expect(
        q.jobs.single.status,
        JobStatus.klaar,
        reason: q.jobs.single.error,
      );
      final d = Directory(
        p.join(
          out.path,
          '2026',
          '2026-11-15 Aand - Uit die oorvloed van die hart praat die mond',
        ),
      );
      Future<double> dur(String f) async =>
          (await probeMedia(File(f))).duration;
      expect(
        await dur(p.join(d.path, 'Volle preek.mp4')),
        closeTo(3361.53 - 886.64, 0.05),
      );
      final parts = wordParts(loadLabels(dir), loadSound(dir), plan.parts());
      expect(
        await dur(p.join(d.path, 'Net die woord.mp4')),
        closeTo(
          parts.fold<double>(0, (a, s) => a + s.end - s.start),
          // each part rounds to a video frame (1/30 s) and an AAC frame (1/48 s)
          0.06 * parts.length,
        ),
      );
      final songs = Directory(
        p.join(d.path, 'Sang'),
      ).listSync().map((f) => p.basename(f.path)).toList()..sort();
      expect(songs, ['01 Psalm 33.mp3', '02 Psalm 42.mp3', '03 Psalm 46.mp3']);
      final r = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format_tags=title,album,track',
        '-of',
        'json',
        p.join(d.path, 'Sang', '02 Psalm 42.mp3'),
      ]);
      expect(
        (jsonDecode(r.stdout as String)['format']['tags'] as Map).values,
        containsAll(['Psalm 42', 'GK Oranjerivier 2026-11-15 Aanddiens', '2']),
      );
      expect(
        File(p.join(d.path, 'WhatsApp.txt')).readAsStringSync(),
        whatsappText(kWhatsappTemplate, _ywz()),
      );
      expect(File(p.join(d.path, 'diens.json')).existsSync(), isTrue);
    },
    skip: Platform.environment['E2E'] != '1' || !video.existsSync()
        ? 'E2E=1 en die video nodig'
        : null,
    timeout: const Timeout(Duration(minutes: 20)),
  );
}

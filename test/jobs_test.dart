import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/playlists.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/youtube.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/tools.dart';

void main() {
  late Directory root;
  late SermonStore store;
  setUp(() {
    root = Directory.systemTemp.createTempSync('jobs');
    store = SermonStore(root)
      ..load()
      ..merge([
        const ChannelItem('aaaaaaaaaaa', 'A', 1),
        const ChannelItem('bbbbbbbbbbb', 'B', 2),
      ]);
  });
  tearDown(() => root.deleteSync(recursive: true));

  JobQueue queue({JobRun? plan, JobRun? cut, JobRun? audio, JobRun? upload}) =>
      JobQueue(
        store,
        plan: plan ?? (_) async {},
        cut: cut ?? (_) async {},
        audio: audio,
        upload: upload,
      );

  test('runs in order, one at a time, sets states', () async {
    final log = <String>[];
    var running = 0;
    final q = queue(
      plan: (c) async {
        expect(++running, 1);
        log.add('plan ${c.id}');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
      },
      cut: (c) async => log.add('cut ${c.id}'),
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.enqueue('bbbbbbbbbbb', JobKind.plan);
    q.enqueue('aaaaaaaaaaa', JobKind.cut);
    q.enqueue('aaaaaaaaaaa', JobKind.cut); // duplicate ignored
    q.start();
    await q.idle;
    expect(log, ['plan aaaaaaaaaaa', 'plan bbbbbbbbbbb', 'cut aaaaaaaaaaa']);
    expect(store.byId('bbbbbbbbbbb')!.state, SermonState.beplan);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
    expect(q.jobs.every((j) => j.status == JobStatus.klaar), isTrue);
  });

  test('a job that was besig at restart runs again', () async {
    final first = queue(plan: (_) => Completer<void>().future);
    first.enqueue('aaaaaaaaaaa', JobKind.plan);
    first.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(first.jobs.single.status, JobStatus.besig);
    // "herbegin": a new queue on the same folder
    final ran = <String>[];
    final second = queue(plan: (c) async => ran.add(c.id));
    expect(second.jobs.single.status, JobStatus.wag);
    second.start();
    await second.idle;
    expect(ran, ['aaaaaaaaaaa']);
    expect(second.jobs.single.status, JobStatus.klaar);
  });

  test('failure marks job and sermon fout; retry runs it again', () async {
    var fail = true;
    final q = queue(
      plan: (_) async {
        if (fail) {
          throw ProcessException('yt-dlp', [], 'ERROR: boom', 1);
        }
      },
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.start();
    await q.idle;
    final s = store.byId('aaaaaaaaaaa')!;
    expect(s.state, SermonState.fout);
    expect(s.error, isNotEmpty);
    expect(q.jobs.single.status, JobStatus.fout);
    expect(q.jobs.single.log.join('\n'), contains('boom'));
    fail = false;
    q.retry(q.jobs.single);
    await q.idle;
    expect(q.jobs.single.status, JobStatus.klaar);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.beplan);
    expect(File(p.join(root.path, 'jobs.json')).existsSync(), isTrue);
    expect(
      jsonDecode(File(p.join(root.path, 'jobs.json')).readAsStringSync()),
      isList,
    );
  });

  test('cancel stops the current job; the next one still runs', () async {
    final q = queue(
      plan: (c) async {
        if (c.id == 'aaaaaaaaaaa') {
          await c.cancel;
          throw JobCancelled();
        }
      },
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.enqueue('bbbbbbbbbbb', JobKind.plan);
    q.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    q.cancel();
    await q.idle;
    expect(q.jobs[0].status, JobStatus.gekanselleer);
    expect(q.jobs[1].status, JobStatus.klaar);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.nuut);
  });

  test(
    'a failing job keeps its logged lines plus the error, max 200',
    () async {
      final q = queue(
        plan: (c) async {
          for (var i = 0; i < 300; i++) {
            c.log('reël $i');
          }
          throw StateError('stuk');
        },
      );
      q.enqueue('aaaaaaaaaaa', JobKind.plan);
      await q.idle;
      final j = q.jobs.single;
      expect(j.status, JobStatus.fout);
      expect(j.log.length, 200);
      expect(j.log, contains('reël 299'));
      expect(j.log.last, contains('stuk'));
    },
  );

  test(
    'a job for a missing sermon fails and the next job still runs',
    () async {
      final ran = <String>[];
      final q = queue(plan: (c) async => ran.add(c.id));
      q.enqueue('zzzzzzzzzzz', JobKind.plan);
      q.enqueue('bbbbbbbbbbb', JobKind.plan);
      await q.idle;
      expect(q.jobs.first.status, JobStatus.fout);
      expect(ran, ['bbbbbbbbbbb']);
      expect(q.jobs.last.status, JobStatus.klaar);
    },
  );

  test('an audio job keeps the sermon state, also when it fails', () async {
    store.save(store.byId('aaaaaaaaaaa')!..state = SermonState.gesny);
    var fail = false;
    final q = queue(
      audio: (_) async {
        if (fail) throw StateError('stuk');
      },
    );
    q.enqueue('aaaaaaaaaaa', JobKind.audio);
    await q.idle;
    expect(q.jobs.single.status, JobStatus.klaar);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
    fail = true;
    q.enqueue('aaaaaaaaaaa', JobKind.audio);
    await q.idle;
    expect(q.jobs.last.status, JobStatus.fout);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
    q.retry(q.jobs.last);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
  });

  test('audioJob without a cut sermon fails in plain language', () async {
    final q = queue(audio: audioJob(store));
    q.enqueue('aaaaaaaaaaa', JobKind.audio);
    await q.idle;
    expect(q.jobs.single.status, JobStatus.fout);
    expect(q.jobs.single.error, 'Sny eers die preek.');
  });

  group('upload', () {
    late FakeYouTube yt;
    late UploadQuota quota;
    late JobQueue q;
    setUp(() {
      final dir = Directory(p.join(root.path, 'aaaaaaaaaaa'));
      File(p.join(dir.path, kPlanFile)).writeAsStringSync(
        jsonEncode({
          'sermonStart': 0,
          'sermonEnd': 1,
          'title': 'Genade',
          'description': 'Oor genade.',
          'shorts': [
            {'start': 0, 'end': 1, 'title': 'Short een'},
          ],
        }),
      );
      final sermon = File(p.join(root.path, 'p.mp4'))..writeAsStringSync('v');
      final short = File(p.join(root.path, 's.mp4'))..writeAsStringSync('s');
      store.save(
        store.byId('aaaaaaaaaaa')!
          ..state = SermonState.gesny
          ..date = '2026-11-15'
          ..scripture = 'Romeine 5:1-11'
          ..outputs = [sermon.path, short.path, '${root.path}/p.mp3'],
      );
      yt = FakeYouTube();
      quota = UploadQuota(File(p.join(root.path, 'quota.json')));
      q = queue(
        upload: uploadJob(
          store,
          yt: yt,
          settings: AppSettings.load(root),
          quota: quota,
        ),
      );
    });

    test(
      'uploads sermon + Shorts privately, sermon into its playlist',
      () async {
        q.enqueue('aaaaaaaaaaa', JobKind.upload);
        await q.idle;
        expect(
          q.jobs.single.status,
          JobStatus.klaar,
          reason: q.jobs.single.error,
        );
        expect(yt.uploaded.map((u) => u.$2), ['Genade', 'Short een']);
        expect(yt.uploaded.every((u) => u.$4 == 'private'), isTrue);
        expect(yt.uploaded.first.$3, contains('Skriflesing: Romeine 5:1-11'));
        expect(yt.made, ['Romeine']);
        expect(yt.added, [('PL-Romeine', 'V1')]);
        final s = store.byId('aaaaaaaaaaa')!;
        expect(s.state, SermonState.opgelaai);
        expect(s.uploads.values, ['V1', 'V2']);
        expect(s.playlist, 'Romeine');
        expect(quota.used, 2);
      },
    );

    test('the sermon also goes into its groups\' playlists', () async {
      final settings = AppSettings.load(root);
      settings.groups
        ..add(PlaylistGroup('1', 'Advent 2026')..sermons.add('aaaaaaaaaaa'))
        ..add(PlaylistGroup('2', 'Mattheus')..sermons.add('aaaaaaaaaaa'))
        ..add(PlaylistGroup('3', 'Ander')..sermons.add('zzz'));
      q = queue(
        upload: uploadJob(store, yt: yt, settings: settings, quota: quota),
      );
      q.enqueue('aaaaaaaaaaa', JobKind.upload);
      await q.idle;
      expect(
        q.jobs.single.status,
        JobStatus.klaar,
        reason: q.jobs.single.error,
      );
      expect(yt.made, ['Romeine', 'Advent 2026']);
      expect(yt.added, [
        ('PL-Romeine', 'V1'),
        ('PL-Advent 2026', 'V1'),
        ('PL1', 'V1'),
      ]);
    });

    test('a retry after a failure does not upload twice', () async {
      yt.failOn = 'Short een';
      q.enqueue('aaaaaaaaaaa', JobKind.upload);
      await q.idle;
      expect(q.jobs.single.status, JobStatus.fout);
      expect(store.byId('aaaaaaaaaaa')!.state, SermonState.fout);
      yt.failOn = null;
      q.retry(q.jobs.single);
      await q.idle;
      expect(q.jobs.single.status, JobStatus.klaar);
      expect(yt.uploaded.map((u) => u.$2), ['Genade', 'Short een']);
      expect(yt.added, hasLength(1));
    });

    test('a full quota fails in plain language before uploading', () async {
      for (var i = 0; i < 100; i++) {
        quota.take();
      }
      q.enqueue('aaaaaaaaaaa', JobKind.upload);
      await q.idle;
      expect(q.jobs.single.error, contains('100 oplaaie'));
      expect(yt.uploaded, isEmpty);
    });

    test('updateOnYouTube sends the edited title and description', () async {
      q.enqueue('aaaaaaaaaaa', JobKind.upload);
      await q.idle;
      final dir = Directory(p.join(root.path, 'aaaaaaaaaaa'));
      final plan = SermonPlan.fromJson(
        jsonDecode(File(p.join(dir.path, kPlanFile)).readAsStringSync()),
      )..title = 'Genade alleen';
      savePlan(dir, plan);
      final n = await updateOnYouTube(
        store,
        'aaaaaaaaaaa',
        yt: yt,
        settings: AppSettings.load(root),
      );
      expect(n, 2);
      expect(yt.updated.map((u) => (u.$1, u.$2)), [
        ('V1', 'Genade alleen'),
        ('V2', 'Short een'),
      ]);
      expect(yt.updated.first.$3, contains('Skriflesing: Romeine 5:1-11'));
    });
  });

  test(
    'cutJob joins the intro from Instellings before the sermon (real ffmpeg)',
    () async {
      final id = 'aaaaaaaaaaa', dir = Directory(p.join(root.path, id));
      File(p.join(dir.path, '$id.info.json')).writeAsStringSync(
        jsonEncode({
          'title': 'A',
          'description': '',
          'upload_date': '20261116',
          'duration': 6,
        }),
      );
      File(p.join(dir.path, '$id.af-orig.json3'))
          .writeAsStringSync('{"events":[]}');
      Future<void> gen(String path, double secs) => Process.run('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'testsrc=size=160x120:rate=25:duration=$secs',
        '-f',
        'lavfi',
        '-i',
        'sine=duration=$secs',
        '-pix_fmt',
        'yuv420p',
        '-shortest',
        path,
      ]);
      await gen(p.join(dir.path, 'video.mp4'), 6);
      final intro = p.join(root.path, 'intro.mp4');
      await gen(intro, 2);
      AppSettings.load(root)
        ..intro = intro
        ..save();
      File(p.join(dir.path, 'plan.json')).writeAsStringSync(
        jsonEncode({
          'sermonStart': 1,
          'sermonEnd': 5,
          'title': 'Tema',
          'description': '',
          'shorts': [],
          'cuts': [
            {'start': 2, 'end': 3},
          ],
        }),
      );
      final out = Directory(p.join(root.path, 'uit'));
      final q = JobQueue(store, plan: (_) async {}, out: out);
      q.enqueue(id, JobKind.cut);
      await q.idle;
      expect(
        q.jobs.single.status,
        JobStatus.klaar,
        reason: q.jobs.single.error,
      );
      final f = File(store.byId(id)!.outputs.single);
      final r = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'format=duration',
        '-of',
        'csv=p=0',
        f.path,
      ]);
      expect(double.parse((r.stdout as String).trim()), closeTo(2 + 3, 0.3));
    },
    skip: findExecutable('ffmpeg') == null ? 'ffmpeg ontbreek' : null,
  );
}

class FakeYouTube implements YouTube {
  final uploaded = <(String, String, String, String)>[];
  final updated = <(String, String, String)>[];

  @override
  Future<void> updateVideo(
    String id, {
    required String title,
    required String description,
  }) async => updated.add((id, title, description));
  final made = <String>[];
  final added = <(String, String)>[];
  String? failOn;

  @override
  Future<String> upload(
    File file, {
    required String title,
    required String description,
    required String privacy,
    required File session,
    void Function(double frac)? onProgress,
    Future<void>? cancel,
  }) async {
    if (title == failOn) throw const HttpException('503');
    uploaded.add((file.path, title, description, privacy));
    return 'V${uploaded.length}';
  }

  @override
  Future<Map<String, String>> playlists() async => {'Mattheus': 'PL1'};

  @override
  Future<String> createPlaylist(String title) async {
    made.add(title);
    return 'PL-$title';
  }

  @override
  Future<void> addToPlaylist(String playlist, String video) async =>
      added.add((playlist, video));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

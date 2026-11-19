import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

import 'helpers.dart';

(ReviewController, SermonStore, JobQueue) _ready(
  Future<File> Function(FetchedMeta, {void Function(double)? onProgress}) dl,
  Stream<Duration>? positions,
) {
  final r = testController(download: dl, positions: positions);
  Directory(p.join(r.$2.root.path, 'x')).createSync(recursive: true);
  r.$1.debugReady(
    FetchedMeta('x', Directory(p.join(r.$2.root.path, 'x')), {}),
    [],
    SermonPlan(
      sermonStart: 0,
      sermonEnd: 100,
      title: 't',
      description: '',
      shorts: [],
    ),
    100,
  );
  return r;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  test('repeated downloads keep one position subscription', () async {
    var listens = 0;
    final positions = Stream<Duration>.multi((_) => listens++);
    final (c, _, _) = _ready(
      (m, {onProgress}) async => File('v.mp4'),
      positions,
    );
    c.setManually();
    await c.downloadFuture;
    c.reset();
    c.debugReady(
      FetchedMeta('x', Directory.systemTemp, {}),
      [],
      c.plan ??
          SermonPlan(
            sermonStart: 0,
            sermonEnd: 100,
            title: 't',
            description: '',
            shorts: [],
          ),
      100,
    );
    c.setManually();
    await c.downloadFuture;
    expect(listens, 1);
  });

  test('a download error leaves no unhandled async error', () async {
    final (c, _, _) = _ready((m, {onProgress}) async => throw 'stuk', null);
    c.setManually();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.error, 'stuk');
    // The failure also reaches anyone awaiting the download.
    await expectLater(c.downloadFuture, throwsA('stuk'));
  });

  test('open(id) loads the saved plan from the store', () {
    final (c, store, _) = testController();
    final dir = Directory(p.join(store.root.path, 'x'))..createSync();
    File(p.join(dir.path, 'x.info.json')).writeAsStringSync(
      '{"title":"T","duration":100,"upload_date":"20261115"}',
    );
    File(p.join(dir.path, 'x.af-orig.json3'))
        .writeAsStringSync('{"events":[]}');
    savePlan(
      dir,
      SermonPlan(
        sermonStart: 1,
        sermonEnd: 90,
        title: 'Plan',
        description: '',
        shorts: [],
      ),
    );
    c.open('x');
    expect(c.state, ReviewState.ready);
    expect(c.plan!.title, 'Plan');
  });

  test('open without plan or job is unplanned; replan queues a plan job', () {
    final (c, store, jobs) = testController();
    c.open('x');
    expect(c.state, ReviewState.unplanned);
    c.replan();
    expect(jobs.jobs.single.kind, JobKind.plan);
    expect(c.state, ReviewState.loading);
  });

  test('approveAndCut marks goedgekeur and queues a cut job; skip marks oorgeslaan', () async {
    final (c, store, jobs) = _ready(
      (m, {onProgress}) async => File('v.mp4'),
      null,
    );
    c.setManually();
    c.approveAndCut();
    expect(
      store.byId('x')!.state,
      anyOf(SermonState.goedgekeur, SermonState.gesny),
    );
    expect(jobs.jobs.single.kind, JobKind.cut);
    await jobs.idle;
    expect(store.byId('x')!.state, SermonState.gesny);
    c.skip();
    expect(store.byId('x')!.state, SermonState.oorgeslaan);
    expect(c.state, ReviewState.empty);
  });

  /// Writes info.json, captions and a plan for sermon [id] in [store].
  void seedPlan(SermonStore store, String id) {
    final dir = Directory(p.join(store.root.path, id))..createSync();
    File(p.join(dir.path, '$id.info.json')).writeAsStringSync(
      '{"title":"T","duration":100,"upload_date":"20261115"}',
    );
    File(p.join(dir.path, '$id.af-orig.json3'))
        .writeAsStringSync('{"events":[]}');
    savePlan(
      dir,
      SermonPlan(
        sermonStart: 1,
        sermonEnd: 90,
        title: 'Plan',
        description: '',
        shorts: [],
      ),
    );
  }

  test('approveAndCut does not wait for the preview download', () async {
    final gate = Completer<File>();
    final (c, store, jobs) = testController(
      download: (m, {onProgress}) => gate.future,
      cut: (_) => Completer<void>().future,
    );
    seedPlan(store, 'x');
    c.open('x');
    c.approveAndCut();
    expect(jobs.jobs.single.kind, JobKind.cut);
    expect(store.byId('x')!.state, SermonState.goedgekeur);
  });

  test('a download that finishes after open(other) is ignored', () async {
    final gate = Completer<File>();
    final opened = <File>[];
    final (_, store, jobs) = testController();
    store.merge([const ChannelItem('y', 'Twee', 100)]);
    seedPlan(store, 'x');
    final c = ReviewController(
      store: store,
      jobs: jobs,
      download: (m, {onProgress}) => gate.future,
      openVideo: (f) async => opened.add(f),
    );
    c.open('x');
    c.open('y');
    gate.complete(File('vorige.mp4'));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(opened, isEmpty);
    expect(c.videoReady, isFalse);
  });

  test('no preview download while a job for the sermon is pending', () async {
    var downloads = 0;
    final (c, store, jobs) = testController(
      download: (m, {onProgress}) async {
        downloads++;
        return File('v.mp4');
      },
      cut: (_) => Completer<void>().future,
    );
    seedPlan(store, 'x');
    jobs.enqueue('x', JobKind.cut);
    c.open('x');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(downloads, 0);
  });
}

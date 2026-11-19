import 'dart:io';

import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

/// A controller on a temp store with stubbed (instant) jobs; sermon `x` exists.
(ReviewController, SermonStore, JobQueue) testController({
  Future<File> Function(FetchedMeta, {void Function(double)? onProgress})?
  download,
  Stream<Duration>? positions,
  JobRun? cut,
}) {
  final store = SermonStore(Directory.systemTemp.createTempSync('work'))
    ..load()
    ..merge([const ChannelItem('x', 'Preek', 100)]);
  final jobs = JobQueue(store, plan: (_) async {}, cut: cut ?? (_) async {});
  final c = ReviewController(
    store: store,
    jobs: jobs,
    download: download ?? (m, {onProgress}) async => File('v.mp4'),
    openVideo: (_) async {},
    positions: positions,
  );
  return (c, store, jobs);
}

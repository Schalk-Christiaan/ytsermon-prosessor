import 'dart:io';

import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/transcribe.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

/// A controller on a temp store with stubbed (instant) jobs; sermon `x` exists.
(ReviewController, SermonStore, JobQueue) testController({
  Future<File> Function(FetchedMeta, {void Function(double)? onProgress})?
  download,
  Stream<Duration>? positions,
  JobRun? cut,
  bool seed = true,
  Future<File> Function(
    File,
    File, {
    required File model,
    String? whisper,
    void Function(double)? onProgress,
  })?
  transcribe,
  File? whisperModel,
}) {
  final store = SermonStore(Directory.systemTemp.createTempSync('work'))
    ..load()
    ..merge([if (seed) const ChannelItem('x', 'Preek', 100)]);
  final jobs = JobQueue(
    store,
    plan: (_) async {},
    cut: cut ?? (_) async {},
    audio: (_) async {},
  );
  final c = ReviewController(
    store: store,
    jobs: jobs,
    download: download ?? (m, {onProgress}) async => File('v.mp4'),
    openVideo: (_) async {},
    positions: positions,
    transcribe: transcribe ?? transcribeLocal,
    whisper: '/bin/true',
    whisperModel: whisperModel,
  );
  return (c, store, jobs);
}

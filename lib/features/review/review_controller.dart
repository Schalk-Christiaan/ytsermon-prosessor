// @stelsel review_controller
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: <app-support>/work/<id>/plan.json | die plan; elke wysiging stoor dadelik
//   doel: laai meta, plan en video vir een preek, hou die plan, sny na out/
//   status: oop
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../core/captions.dart';
import '../../core/channel.dart';
import '../../core/cutter.dart';
import '../../core/models.dart';
import '../../core/paths.dart';
import '../../core/planner.dart';

enum ReviewState { empty, loading, error, ready }

enum LoadStage { meta, plan, cut }

class ReviewController extends ChangeNotifier {
  ReviewController({
    this.work,
    this.out,
    this.font,
    this.download = downloadVideo,
    this.openVideo,
    this.positions,
  });

  /// Test seams: the downloader, and replacements for the media_kit player.
  final Future<File> Function(
    FetchedMeta meta, {
    void Function(double pct)? onProgress,
  })
  download;
  final Future<void> Function(File video)? openVideo;
  final Stream<Duration>? positions;

  /// Overrides for tests: work cache root and output folder.
  final Directory? work;
  final Directory? out;
  final File? font;

  /// Created only once the video is on disk (no libmpv work before that).
  late final player = Player();
  late final video = VideoController(player);
  bool videoReady = false;

  /// Playhead in seconds, from the media_kit position stream (no polling).
  final position = ValueNotifier<double>(0);

  /// Video download progress 0..100 (100 = on disk).
  final downloadPct = ValueNotifier<double>(0);

  ReviewState state = ReviewState.empty;
  LoadStage stage = LoadStage.meta;
  final stopwatch = Stopwatch();
  Object? error;

  /// True when a rejected plan from Ollama can be corrected manually.
  PlanException? get planError =>
      error is PlanException ? error as PlanException : null;

  FetchedMeta? meta;
  List<Segment> segments = [];
  List<TimeBlock> blocks = [];
  SermonPlan? plan;
  double duration = 0;

  /// Bumped when a new plan arrives, so the timeline plays its handle glide.
  int planRevision = 0;
  bool saved = false;
  double cutFraction = 0;
  Completer<File>? _download;
  @visibleForTesting
  Future<File>? get downloadFuture => _download?.future;
  String? _url;
  StreamSubscription<Duration>? _pos;

  Future<void> load(String url) async {
    _url = url;
    error = null;
    plan = null;
    state = ReviewState.loading;
    stage = LoadStage.meta;
    stopwatch
      ..reset()
      ..start();
    notifyListeners();
    try {
      final m = await fetchMeta(url, work ?? await workRoot());
      meta = m;
      duration = m.info.durationSeconds;
      segments = parseJson3(m.captions.readAsStringSync());
      blocks = timeline(segments);
      stage = LoadStage.plan;
      notifyListeners();
      plan = await Planner().loadOrPlan(
        m.dir,
        compactText: compact(segments),
        duration: duration,
        originalDescription: m.info.descriptionText,
      );
      state = ReviewState.ready;
      planRevision++;
      stopwatch.stop();
      notifyListeners();
      _startDownload(m);
    } on Object catch (e) {
      error = e;
      state = ReviewState.error;
      stopwatch.stop();
      notifyListeners();
    }
  }

  void _startDownload(FetchedMeta m) {
    final c = _download = Completer<File>();
    // Errors are shown through `error`; approveAndCut still sees them when it awaits.
    c.future.ignore();
    download(m, onProgress: (v) => downloadPct.value = v).then(
      (f) async {
        _pos ??= (positions ?? player.stream.position).listen(
          (d) => position.value = d.inMilliseconds / 1000,
        );
        await (openVideo?.call(f) ?? player.open(Media(f.path), play: false));
        videoReady = true;
        notifyListeners();
        c.complete(f);
      },
      onError: (Object e) {
        c.completeError(e);
        error = e;
        notifyListeners();
      },
    );
  }

  /// "Stel self in": a plan spanning the whole video (or the rejected one) for manual correction.
  void setManually() {
    final m = meta!;
    plan =
        planError?.plan ??
        SermonPlan(
          sermonStart: 0,
          sermonEnd: duration,
          title: m.info.titleText,
          description: m.info.descriptionText,
          shorts: [],
        );
    error = null;
    state = ReviewState.ready;
    planRevision++;
    _save();
    notifyListeners();
    if (_download == null) _startDownload(m);
  }

  /// Deletes plan.json and asks the model again (the caller has confirmed).
  Future<void> replan() async {
    final f = File(p.join(meta!.dir.path, kPlanFile));
    if (f.existsSync()) f.deleteSync();
    await load(_url!);
  }

  void reset() {
    if (videoReady) player.pause();
    state = ReviewState.empty;
    plan = null;
    meta = null;
    _download = null;
    notifyListeners();
  }

  void _save() {
    savePlan(meta!.dir, plan!);
    saved = true;
  }

  void setSermon(double start, double end, {bool save = true}) {
    plan!
      ..sermonStart = start
      ..sermonEnd = end;
    saved = false;
    if (save) _save();
    notifyListeners();
  }

  void commit() {
    _save();
    notifyListeners();
  }

  void setTitle(String v) {
    plan!.title = v;
    _save();
    notifyListeners();
  }

  void setDescription(String v) {
    plan!.description = v;
    _save();
    notifyListeners();
  }

  void seek(double s) => videoReady
      ? player.seek(Duration(milliseconds: (s * 1000).round()))
      : position.value = s;

  /// New Short at the playhead (60 s, clamped inside the sermon).
  void addShort(String title) {
    final pl = plan!;
    final start = position.value.clamp(pl.sermonStart, pl.sermonEnd - 20);
    pl.shorts.add(
      Short(
        start: start,
        end: (start + 60).clamp(start + 20, pl.sermonEnd),
        title: title,
      ),
    );
    _save();
    notifyListeners();
  }

  /// Moves a Short's end (the length slider); save only when [save].
  void setShortEnd(Short s, double end, {bool save = true}) {
    s.end = end.clamp(s.start + 1, plan!.sermonEnd);
    if (save) _save();
    notifyListeners();
  }

  /// True while a Short is invalid (blocks "Keur goed en sny").
  bool get hasShortFault =>
      plan?.shorts.any((s) => shortFault(s, plan!) != null) ?? false;

  void removeShort(Short s) {
    plan!.shorts.remove(s);
    _save();
    notifyListeners();
  }

  /// Cuts sermon + Shorts into `out/`; returns (sermons, shorts) counts and the out directory.
  Future<(int, int, Directory)> approveAndCut() async {
    final m = meta!;
    final pl = plan!;
    stage = LoadStage.cut;
    cutFraction = 0;
    state = ReviewState.loading;
    stopwatch
      ..reset()
      ..start();
    notifyListeners();
    try {
      final v = await _download!.future;
      final date = m.info.uploadDate;
      final out = this.out ?? outDir();
      final font = this.font ?? bundledFont();
      await cutSermon(v, pl, date, out);
      for (var i = 0; i < pl.shorts.length; i++) {
        await cutShort(
          v,
          i + 1,
          pl.shorts[i],
          segments,
          font,
          date,
          out,
          onProgress: (f) {
            cutFraction = (i + f) / pl.shorts.length;
            notifyListeners();
          },
        );
      }
      state = ReviewState.ready;
      return (1, pl.shorts.length, out.absolute);
    } finally {
      stopwatch.stop();
      if (state == ReviewState.loading) state = ReviewState.ready;
      notifyListeners();
    }
  }

  /// Test hook: jump straight to the reviewed state with a ready plan.
  @visibleForTesting
  void debugReady(FetchedMeta m, List<Segment> segs, SermonPlan p, double dur) {
    meta = m;
    segments = segs;
    blocks = timeline(segs);
    plan = p;
    duration = dur;
    state = ReviewState.ready;
    planRevision++;
    notifyListeners();
  }

  @override
  void dispose() {
    _pos?.cancel();
    if (videoReady) player.dispose();
    super.dispose();
  }
}

// @stelsel review_controller
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: <app-support>/work/<id>/plan.json | die plan; elke wysiging stoor dadelik
//   doel: laai meta en plan van 'n preek uit die stoor, hou die plan; plan en sny loop deur die werkry
//   status: oop
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path/path.dart' as p;

import '../../core/captions.dart';
import '../../core/channel.dart';
import '../../core/jobs.dart';
import '../../core/models.dart';
import '../../core/planner.dart';
import '../../core/store.dart';

enum ReviewState { empty, loading, error, unplanned, ready }

enum LoadStage { meta, plan, cut }

class ReviewController extends ChangeNotifier {
  ReviewController({
    required this.store,
    required this.jobs,
    this.download = downloadVideo,
    this.openVideo,
    this.positions,
  });

  final SermonStore store;
  final JobQueue jobs;

  /// Test seams: the downloader, and replacements for the media_kit player.
  final Future<File> Function(
    FetchedMeta meta, {
    void Function(double pct)? onProgress,
  })
  download;
  final Future<void> Function(File video)? openVideo;
  final Stream<Duration>? positions;

  /// Created only once the video is on disk (no libmpv work before that).
  late final player = Player();
  late final video = VideoController(player);
  bool videoReady = false;

  /// Playhead in seconds, from the media_kit position stream (no polling).
  final position = ValueNotifier<double>(0);

  /// Video download progress 0..100 (100 = on disk).
  final downloadPct = ValueNotifier<double>(0);

  ReviewState state = ReviewState.empty;
  final stopwatch = Stopwatch();
  Object? error;

  /// The sermon being reviewed (null = none chosen in Preke).
  String? id;
  Sermon? get sermon => id == null ? null : store.byId(id!);

  /// Where the queue is for this sermon (drives the loading text).
  LoadStage get stage {
    final cur = jobs.current;
    final kind = cur?.sermon == id
        ? cur!.kind
        : jobs.jobs
              .where((j) => j.sermon == id && j.status == JobStatus.wag)
              .map((j) => j.kind)
              .firstOrNull;
    if (kind == JobKind.cut) return LoadStage.cut;
    return jobs.phase.value == JobPhase.plan ? LoadStage.plan : LoadStage.meta;
  }

  double get cutFraction => jobs.progress.value ?? 0;

  FetchedMeta? meta;
  List<Segment> segments = [];
  List<TimeBlock> blocks = [];
  SermonPlan? plan;
  double duration = 0;

  /// Bumped when a new plan arrives, so the timeline plays its handle glide.
  int planRevision = 0;
  bool saved = false;
  Completer<File>? _download;
  @visibleForTesting
  Future<File>? get downloadFuture => _download?.future;
  StreamSubscription<Duration>? _pos;

  /// Opens sermon [id] from the store: its plan if there is one, else follows the queue.
  void open(String id) {
    if (this.id != id) {
      this.id = id;
      _download = null;
      videoReady = false;
      downloadPct.value = 0;
      jobs.removeListener(_onJobs);
      jobs.addListener(_onJobs);
    }
    _load();
  }

  void _load() {
    final dir = Directory(p.join(store.root.path, id!));
    final info = File(p.join(dir.path, '$id.info.json'));
    final m = FetchedMeta(id!, dir, {});
    error = null;
    plan = null;
    meta = null;
    if (info.existsSync() && m.captions.existsSync()) {
      final j = jsonDecode(info.readAsStringSync()) as Map<String, dynamic>;
      meta = FetchedMeta(id!, dir, j);
      duration = j.durationSeconds;
      segments = parseJson3(m.captions.readAsStringSync());
      blocks = timeline(segments);
    }
    final pf = File(p.join(dir.path, kPlanFile));
    if (meta != null && pf.existsSync()) {
      plan = SermonPlan.fromJson(
        jsonDecode(pf.readAsStringSync()) as Map<String, dynamic>,
      );
      state = _active(JobKind.cut) ? ReviewState.loading : ReviewState.ready;
      planRevision++;
      if (_download == null && !jobs.hasPending(id!)) _startDownload(meta!);
    } else if (_active(JobKind.plan)) {
      state = ReviewState.loading;
    } else if (sermon?.state == SermonState.fout) {
      error = sermon!.error;
      state = ReviewState.error;
    } else {
      state = ReviewState.unplanned;
    }
    if (state == ReviewState.loading && !stopwatch.isRunning) {
      stopwatch
        ..reset()
        ..start();
    } else if (state != ReviewState.loading) {
      stopwatch.stop();
    }
    notifyListeners();
  }

  bool _active(JobKind k) => jobs.hasPending(id!, k);

  /// The queue changed: reload when the job we were waiting for has finished.
  void _onJobs() {
    if (id == null) return;
    if (state == ReviewState.loading &&
        !_active(JobKind.plan) &&
        !_active(JobKind.cut)) {
      _load();
    } else {
      notifyListeners();
    }
  }

  void _startDownload(FetchedMeta m) {
    final c = _download = Completer<File>();
    // A download that finishes after reset()/open(other) must not touch the player.
    bool stale() => _download != c;
    c.future.ignore();
    download(m, onProgress: (v) => downloadPct.value = v).then(
      (f) async {
        if (stale()) return;
        _pos ??= (positions ?? player.stream.position).listen(
          (d) => position.value = d.inMilliseconds / 1000,
        );
        await (openVideo?.call(f) ?? player.open(Media(f.path), play: false));
        if (stale()) return;
        videoReady = true;
        notifyListeners();
        c.complete(f);
      },
      onError: (Object e) {
        if (stale()) return;
        c.completeError(e);
        error = e;
        notifyListeners();
      },
    );
  }

  /// "Stel self in": a plan spanning the whole video for manual correction.
  void setManually() {
    final m = meta!;
    plan = SermonPlan(
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
    final s = sermon;
    if (s != null) store.save(s..state = SermonState.beplan);
    notifyListeners();
    if (_download == null) _startDownload(m);
  }

  /// Deletes plan.json and queues a new plan job (the caller has confirmed).
  void replan() {
    final f = File(p.join(store.root.path, id!, kPlanFile));
    if (f.existsSync()) f.deleteSync();
    final s = sermon!;
    store.save(
      s
        ..state = SermonState.nuut
        ..error = null,
    );
    jobs.enqueue(id!, JobKind.plan);
    _load();
  }

  /// "Slaan oor": marks the sermon skipped and leaves the review.
  void skip() {
    store.save(sermon!..state = SermonState.oorgeslaan);
    reset();
  }

  void reset() {
    if (videoReady) player.pause();
    state = ReviewState.empty;
    plan = null;
    meta = null;
    _download = null;
    id = null;
    jobs.removeListener(_onJobs);
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

  /// Marks the sermon `goedgekeur` and queues the cut job (it downloads the video itself).
  void approveAndCut() {
    _save();
    store.save(sermon!..state = SermonState.goedgekeur);
    jobs.enqueue(id!, JobKind.cut);
    _load();
  }

  /// Test hook: jump straight to the reviewed state with a ready plan.
  @visibleForTesting
  void debugReady(FetchedMeta m, List<Segment> segs, SermonPlan p, double dur) {
    id = m.id;
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
    jobs.removeListener(_onJobs);
    _pos?.cancel();
    if (videoReady) player.dispose();
    super.dispose();
  }
}

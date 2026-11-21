// @stelsel review_controller
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: <app-support>/work/<id>/plan.json | die plan; elke wysiging stoor dadelik
//   doel: laai meta en plan van 'n preek uit die stoor en redigeer dit (hakies, gebedsmerkers uit die etikette (analysis.json), I/O, uitknip, Shorts, ontdoen/herdoen, voorskou van die snit); plan en sny loop deur die werkry
//   status: bou
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
import '../../core/service_info.dart';
import '../../core/sound.dart';
import '../../core/store.dart';

/// What Hersien shows: nothing chosen, loading, an error, no plan yet or the editor.
enum ReviewState { empty, loading, error, unplanned, ready }

/// Which step of loading a sermon is busy: metadata, planning or cutting.
enum LoadStage { meta, plan, cut }

/// State of the sermon editor: the plan, playback, undo/redo and every edit.
class ReviewController extends ChangeNotifier {
  ReviewController({
    required this.store,
    required this.jobs,
    this.download = downloadVideo,
    this.openVideo,
    this.positions,
  }) {
    position.addListener(_skipCuts);
  }

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

  /// "Werk op YouTube by": sends the plan's title and description to the uploaded videos; set by Shell (null = hidden).
  Future<int> Function(String id)? updateYouTube;
  bool updating = false;

  /// "Werk op YouTube by": pushes title and description to the uploaded videos; returns how many.
  Future<int> pushToYouTube() async {
    updating = true;
    notifyListeners();
    try {
      return await updateYouTube!(id!);
    } finally {
      updating = false;
      notifyListeners();
    }
  }

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
  List<TimeBlock> sound = [];

  /// Loudness per second (dB) for the waveform; empty when the service was analysed before levels were kept.
  List<double> levels = [];

  /// Preview volume 0-100 (the player only; the cut is not changed).
  final volume = ValueNotifier<double>(100);

  void setVolume(double v) {
    volume.value = v.clamp(0, 100);
    if (videoReady) player.setVolume(volume.value);
  }

  SermonPlan? plan;
  double duration = 0;

  /// Blocks the AI labelled as prayer, marked on the timeline and in the transcript.
  List<Span> prayerMarks = [];

  /// The songs the AI named (their names go on the timeline's music pieces).
  List<Song> songs = [];

  /// The service's day part and kind as the cut will use them; Schalk may change both.
  ServiceInfo service = ServiceInfo(date: '');

  /// Oggend (false) or Aand (true), remembered for the cut.
  void setEvening(bool v) {
    service.evening = v;
    _saveService();
  }

  /// The service kind (`nagmaal` …) or null for an ordinary service, remembered for the cut.
  void setServiceKind(String? v) {
    service.label = v;
    _saveService();
  }

  void _saveService() {
    saveChoices(meta!.dir, service);
    notifyListeners();
  }

  /// Reads the prayers, songs and service facts of [m] from its work folder (analysis.json, read once).
  void _loadService(FetchedMeta m) {
    final a = loadAnalysis(m.dir);
    prayerMarks = [
      for (final l in a.labels)
        if (l.label == BlockLabel.gebed) Span(l.start, l.end),
    ];
    songs = a.songs;
    service = applyChoices(
      ServiceInfo.fromInfo(m.info)..label = a.service,
      m.dir,
    );
  }

  /// Bumped by undo/redo, so the text fields reload from the plan.
  int edits = 0;

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
      sound = loadSound(dir);
      levels = loadLevels(dir);
      _loadService(meta!);
    }
    final pf = File(p.join(dir.path, kPlanFile));
    if (meta != null && pf.existsSync()) {
      plan = SermonPlan.fromJson(
        jsonDecode(pf.readAsStringSync()) as Map<String, dynamic>,
      );
      state = _active(JobKind.cut) ? ReviewState.loading : ReviewState.ready;
      planRevision++;
      _undo.clear();
      _redo.clear();
      _pinProposal(read: true);
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
        // Older plans have no sound.json yet: analyse the video once (one ffmpeg run) for the timeline.
        if (sound.isEmpty) {
          try {
            final b = await soundBlocks(m.dir, f);
            if (!stale()) {
              sound = b;
              notifyListeners();
            }
          } on Object {
            // no sound analysis: the timeline just stays empty
          }
        }
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
    _undo.clear();
    _redo.clear();
    _pinProposal();
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

  final _undo = <String>[], _redo = <String>[];
  String? _group;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Remembers the plan before an edit; edits in the same [group] (a drag, typing) are one step.
  void _edit([String? group]) {
    if (group != null && group == _group) return;
    _group = group;
    _undo.add(jsonEncode(plan!.toJson()));
    if (_undo.length > 100) _undo.removeAt(0);
    _redo.clear();
  }

  void _swap(List<String> from, List<String> to) {
    if (from.isEmpty) return;
    to.add(jsonEncode(plan!.toJson()));
    plan = SermonPlan.fromJson(
      jsonDecode(from.removeLast()) as Map<String, dynamic>,
    );
    _group = null;
    edits++;
    _save();
    notifyListeners();
  }

  /// The plan as the AI proposed it (JSON), kept apart from the undo stack (capped at 100) and
  /// saved beside the plan so it survives reopening.
  String? _proposal;

  /// Pins the current plan as the proposal; with [read] a saved proposal wins (the plan may be edited).
  void _pinProposal({bool read = false}) {
    final f = File(p.join(meta!.dir.path, kProposalFile));
    if (read && f.existsSync()) {
      _proposal = f.readAsStringSync();
      return;
    }
    _proposal = jsonEncode(plan!.toJson());
    f.writeAsStringSync(_proposal!);
  }

  /// True while the plan differs from the proposal.
  bool get canReset =>
      _proposal != null && jsonEncode(plan!.toJson()) != _proposal;

  /// "Herstel": back to the plan as it was when it opened (the AI proposal), as one undoable step.
  void resetToProposal() {
    if (!canReset) return;
    _edit();
    plan = SermonPlan.fromJson(jsonDecode(_proposal!) as Map<String, dynamic>);
    edits++;
    _save();
    notifyListeners();
  }

  // stap: v4 4 Ontdoen | Ctrl+Z draai die laaste skuif terug, Ctrl+Shift+Z herdoen
  void undo() => _swap(_undo, _redo);
  void redo() => _swap(_redo, _undo);

  // stap: v4 3 Skuif die hakie | sleep, ←/→ 1 s, Shift 0,1 s, of I/O by die speelkop
  /// Moves one bracket by [d] seconds (keys: 1 s, Shift 0.1 s).
  void nudge(bool start, double d) {
    final pl = plan!;
    start
        ? setSermon(
            (pl.sermonStart + d).clamp(0, pl.sermonEnd - 1),
            pl.sermonEnd,
          )
        : setSermon(
            pl.sermonStart,
            (pl.sermonEnd + d).clamp(pl.sermonStart + 1, duration),
          );
  }

  /// I: the sermon starts at the playhead.
  void markIn() =>
      setSermon(position.value.clamp(0, plan!.sermonEnd - 1), plan!.sermonEnd);

  /// O: the sermon ends at the playhead.
  void markOut() => setSermon(
    plan!.sermonStart,
    position.value.clamp(plan!.sermonStart + 1, duration),
  );

  /// Cuts out 30 s from the playhead (a hymn, an announcement); the ends are set after.
  void addCut() {
    final pl = plan!;
    final start = position.value.clamp(pl.sermonStart, pl.sermonEnd - 1);
    _edit();
    pl.cuts.add(Span(start, (start + 30).clamp(start + 1, pl.sermonEnd)));
    _save();
    notifyListeners();
  }

  /// Sets a cut piece's start or end at the playhead.
  void setCutStart(Span c) => _setCut(c, position.value, c.end);
  void setCutEnd(Span c) => _setCut(c, c.start, position.value);

  void _setCut(Span c, double start, double end, {bool save = true}) {
    _edit(save ? null : 'drag');
    c
      ..start = start.clamp(plan!.sermonStart, end - 1)
      ..end = end.clamp(c.start + 1, plan!.sermonEnd);
    if (save) _save();
    notifyListeners();
  }

  void removeCut(Span c) {
    _edit();
    plan!.cuts.remove(c);
    _save();
    notifyListeners();
  }

  /// True while "Voorskou van die snit" plays: cut pieces are skipped.
  bool previewing = false;

  /// Plays the cut sermon from its start, jumping over cut pieces.
  void previewCut() {
    previewing = true;
    seek(plan!.sermonStart);
    if (videoReady) player.play();
    notifyListeners();
  }

  /// Plays from a bracket: the start, or 10 s before the end.
  void playFrom(bool start) {
    final pl = plan!;
    previewing = false;
    seek(
      start
          ? pl.sermonStart
          : (pl.sermonEnd - 10).clamp(pl.sermonStart, pl.sermonEnd),
    );
    if (videoReady) player.play();
    notifyListeners();
  }

  void playPause() {
    if (videoReady) player.playOrPause();
  }

  /// While previewing: inside a cut piece → jump to its end; past the end → stop.
  void _skipCuts() {
    final pl = plan;
    if (!previewing || pl == null) return;
    final t = position.value;
    if (t >= pl.sermonEnd) {
      previewing = false;
      if (videoReady) player.pause();
      notifyListeners();
      return;
    }
    for (final c in pl.cuts) {
      if (t >= c.start && t < c.end) return seek(c.end);
    }
  }

  void setSermon(double start, double end, {bool save = true}) {
    _edit(save ? null : 'drag');
    plan!
      ..sermonStart = start
      ..sermonEnd = end;
    saved = false;
    if (save) _save();
    notifyListeners();
  }

  void commit() {
    _group = null;
    _save();
    notifyListeners();
  }

  void setTitle(String v) {
    _edit('title');
    plan!.title = v;
    _save();
    notifyListeners();
  }

  void setDescription(String v) {
    _edit('description');
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
    _edit();
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
    _edit(save ? null : 'drag');
    s.end = end.clamp(s.start + 1, plan!.sermonEnd);
    if (save) _save();
    notifyListeners();
  }

  /// True while a Short is invalid (blocks "Keur goed en sny").
  bool get hasShortFault =>
      plan?.shorts.any((s) => shortFault(s, plan!) != null) ?? false;

  /// Moves a whole Short by [d] seconds, kept inside the sermon (drag on the timeline).
  void moveShort(Short s, double d, {bool save = true}) {
    final pl = plan!;
    _edit(save ? null : 'drag');
    final dd = d.clamp(pl.sermonStart - s.start, pl.sermonEnd - s.end);
    s
      ..start += dd
      ..end += dd;
    if (save) _save();
    notifyListeners();
  }

  /// Puts a Short's start at the playhead, keeping its length.
  void setShortStart(Short s) => moveShort(s, position.value - s.start);

  void setShortTitle(Short s, String v) {
    _edit('short-title');
    s.title = v;
    _save();
    notifyListeners();
  }

  void removeShort(Short s) {
    _edit();
    plan!.shorts.remove(s);
    _save();
    notifyListeners();
  }

  /// Marks the sermon `goedgekeur` and queues the cut job (it downloads the video itself).
  void approveAndCut() {
    plan!.doubt = null; // approving is the human check the doubt asked for
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
    sound = const [];
    levels = [];
    _loadService(m);
    plan = p;
    duration = dur;
    state = ReviewState.ready;
    planRevision++;
    _undo.clear();
    _redo.clear();
    _proposal = jsonEncode(plan!.toJson());
    notifyListeners();
  }

  @override
  void dispose() {
    position.removeListener(_skipCuts);
    jobs.removeListener(_onJobs);
    _pos?.cancel();
    if (videoReady) player.dispose();
    super.dispose();
  }
}

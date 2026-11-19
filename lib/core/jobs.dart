// @stelsel jobs
//   soort: module
//   wanneer: "Verwerk volgende", "Keur goed en sny", "Beplan weer", "Klank vir WhatsApp", "Laai op" en by begin (hervat)
//   groep: core | Kern
//   skryf: <werkmap>/jobs.json | die ry; sermon.json van die preek wat verwerk word
//   doel: een taak op 'n slag (plan, sny, klank of oplaai), hervat ná herbegin, kanselleer, probeer weer
//   status: oop
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'captions.dart';
import 'channel.dart';
import 'cutter.dart';
import 'models.dart';
import 'paths.dart';
import 'planner.dart';
import 'playlists.dart';
import 'settings.dart';
import 'store.dart';
import 'tools.dart';
import 'youtube.dart';

enum JobKind { plan, cut, audio, upload }

enum JobStatus { wag, besig, klaar, fout, gekanselleer }

/// What a running job is busy with (the Werk-skerm maps it to text).
enum JobPhase { meta, plan, download, cut, audio, upload }

class Job {
  Job(
    this.sermon,
    this.kind, {
    this.status = JobStatus.wag,
    this.error,
    List<String>? log,
  }) : log = log ?? [];
  final String sermon;
  final JobKind kind;
  JobStatus status;

  /// Plain-language message for Schalk (the technical detail is in [log]).
  String? error;

  /// Last 200 lines of technical detail.
  final List<String> log;

  /// Appends [lines], keeping only the last 200.
  void addLog(Iterable<String> lines) {
    log.addAll(lines);
    if (log.length > 200) log.removeRange(0, log.length - 200);
  }

  Map<String, dynamic> toJson() => {
    'sermon': sermon,
    'kind': kind.name,
    'status': status.name,
    'error': error,
    'log': log,
  };

  factory Job.fromJson(Map<String, dynamic> j) => Job(
    j['sermon'] as String,
    JobKind.values.byName(j['kind'] as String),
    status: JobStatus.values.byName(j['status'] as String),
    error: j['error'] as String?,
    log: [...(j['log'] as List).cast<String>()],
  );
}

/// What a runner gets: which sermon, and hooks for progress and cancelling.
class JobCtx {
  JobCtx(this.id, this.cancel, this._queue);
  final String id;

  /// Completes when the user cancels; pass it on to `runTool`.
  final Future<void> cancel;
  final JobQueue _queue;
  void phase(JobPhase p) => _queue.phase.value = p;
  void progress(double? v) => _queue.progress.value = v;
  void log(String line) => _queue.current?.addLog([line]);
}

typedef JobRun = Future<void> Function(JobCtx ctx);

/// Plain-language reason for a failed job.
String friendlyError(Object e) {
  if (e is PlanException) return 'Die plan is nie aanvaar nie: $e';
  if (e is ProcessException) {
    return '${e.executable} het misluk. Kyk die tegniese log.';
  }
  if (e is SocketException || e is HttpException) {
    return 'Ollama het nie geantwoord nie. Maak seker dit loop.';
  }
  if (e is StateError) return e.message;
  return '$e';
}

/// One-at-a-time work queue in a plain async loop (no timers); persisted so a restart resumes it.
class JobQueue extends ChangeNotifier {
  JobQueue(
    this.store, {
    JobRun? plan,
    JobRun? cut,
    JobRun? audio,
    JobRun? upload,
    Directory? out,
    File? font,
  }) : _plan = plan ?? planJob(store),
       _cut = cut ?? cutJob(store, out: out, font: font),
       _audio = audio ?? audioJob(store),
       _upload =
           upload ??
           ((_) async => throw StateError('Oplaai is nie opgestel nie.')) {
    final f = _file;
    if (f.existsSync()) {
      jobs.addAll([
        for (final j in jsonDecode(f.readAsStringSync()) as List)
          Job.fromJson(j as Map<String, dynamic>),
      ]);
      for (final j in jobs) {
        if (j.status == JobStatus.besig) j.status = JobStatus.wag;
      }
    }
  }

  final SermonStore store;
  final JobRun _plan, _cut, _audio, _upload;
  final jobs = <Job>[];

  /// The running job; its fraction (null = unknown) and phase.
  Job? current;
  final progress = ValueNotifier<double?>(null);
  final phase = ValueNotifier<JobPhase?>(null);

  Completer<void>? _cancel;
  Future<void>? _loop;

  File get _file => File(p.join(store.root.path, 'jobs.json'));

  /// Completes when no job is running or waiting.
  Future<void> get idle => _loop ?? Future.value();

  void _persist() {
    writeJson(_file, [for (final j in jobs) j.toJson()]);
    notifyListeners();
  }

  /// True while [sermon] has a waiting or running job (of [kind], if given).
  bool hasPending(String sermon, [JobKind? kind]) => jobs.any(
    (j) =>
        j.sermon == sermon &&
        (kind == null || j.kind == kind) &&
        (j.status == JobStatus.wag || j.status == JobStatus.besig),
  );

  /// Adds a job unless the same one is already waiting or running; call [start] to run.
  void enqueue(String sermon, JobKind kind) {
    if (hasPending(sermon, kind)) return;
    jobs.add(Job(sermon, kind));
    _persist();
    start();
  }

  /// Runs waiting jobs one after another; does nothing if already running.
  void start() => _loop ??= _run();

  Future<void> _run() async {
    // Let the caller store this future in _loop first, and enqueue more jobs.
    await null;
    while (true) {
      final i = jobs.indexWhere((j) => j.status == JobStatus.wag);
      if (i < 0) {
        _loop = null; // in the same step as the check, so no job is stranded
        return;
      }
      final job = jobs[i];
      Sermon? s;
      try {
        current = job;
        job.status = JobStatus.besig;
        progress.value = null;
        phase.value = null;
        _persist();
        final cancel = _cancel = Completer<void>();
        s = store.byId(job.sermon);
        if (s == null)
          throw StateError('Preek ${job.sermon} bestaan nie meer nie.');
        final run = switch (job.kind) {
          JobKind.plan => _plan,
          JobKind.cut => _cut,
          JobKind.audio => _audio,
          JobKind.upload => _upload,
        };
        await run(JobCtx(job.sermon, cancel.future, this));
        job.status = JobStatus.klaar;
        // An audio export leaves the sermon's state (gesny/opgelaai) alone.
        final done = switch (job.kind) {
          JobKind.plan => SermonState.beplan,
          JobKind.cut => SermonState.gesny,
          JobKind.upload => SermonState.opgelaai,
          JobKind.audio => null,
        };
        if (done != null) {
          s
            ..state = done
            ..error = null;
        }
      } on JobCancelled {
        job.status = JobStatus.gekanselleer;
      } on Object catch (e) {
        job.status = JobStatus.fout;
        job.error = friendlyError(e);
        job.addLog('$e'.split('\n'));
        if (job.kind != JobKind.audio) {
          s
            ?..state = SermonState.fout
            ..error = job.error;
        }
      }
      current = null;
      _cancel = null;
      try {
        if (s != null) store.save(s);
        _persist();
      } on Object catch (e) {
        // A full disk must not kill the loop; the job keeps its status in memory.
        job.addLog(['$e']);
      }
    }
  }

  /// Stops the running job (kills yt-dlp/ffmpeg); the next waiting job still runs.
  void cancel() {
    final c = _cancel;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Puts a failed or cancelled job back in the queue.
  void retry(Job job) {
    job.status = JobStatus.wag;
    job.error = null;
    final s = store.byId(job.sermon)!;
    if (s.state == SermonState.fout && job.kind != JobKind.audio) {
      s.state = switch (job.kind) {
        JobKind.plan => SermonState.nuut,
        JobKind.upload => SermonState.gesny,
        _ => SermonState.goedgekeur,
      };
      s.error = null;
      store.save(s);
    }
    _persist();
    start();
  }
}

/// Fetches meta and captions, asks Ollama for a plan; fills the sermon's date.
JobRun planJob(SermonStore store) => (c) async {
  c.phase(JobPhase.meta);
  final m = await fetchMeta(c.id, store.root, cancel: c.cancel, log: c.log);
  final s = store.byId(c.id)!
    ..date = m.info.uploadDate
    ..scripture = scriptureFrom(m.info.descriptionText)
    ..duration = m.info.durationSeconds;
  store.save(s);
  c.phase(JobPhase.plan);
  final segs = parseJson3(m.captions.readAsStringSync());
  // Ollama's HTTP call is not killable: cancelling abandons it.
  await Future.any([
    Planner().loadOrPlan(
      m.dir,
      compactText: compact(segs),
      duration: s.duration,
      originalDescription: m.info.descriptionText,
      cancel: c.cancel,
    ),
    c.cancel.then<SermonPlan>((_) => throw JobCancelled()),
  ]);
};

/// Downloads the video and cuts the sermon and its Shorts from the saved plan.
JobRun cutJob(SermonStore store, {Directory? out, File? font}) => (c) async {
  c.phase(JobPhase.meta);
  final m = await fetchMeta(c.id, store.root, cancel: c.cancel, log: c.log);
  c.phase(JobPhase.download);
  c.progress(0);
  final video = await downloadVideo(
    m,
    onProgress: (v) => c.progress(v / 100),
    cancel: c.cancel,
    log: c.log,
  );
  final plan = _plan(store, c.id);
  final segs = parseJson3(m.captions.readAsStringSync());
  final dest = out ?? Directory(AppSettings.load(store.root).outDir);
  final date = m.info.uploadDate;
  c.phase(JobPhase.cut);
  c.progress(null);
  final files = [
    await cutSermon(video, plan, date, dest, cancel: c.cancel, log: c.log),
  ];
  void saveOutputs() =>
      store.save(store.byId(c.id)!..outputs = [for (final f in files) f.path]);
  saveOutputs();
  for (var i = 0; i < plan.shorts.length; i++) {
    c.progress(i / plan.shorts.length);
    files.add(
      await cutShort(
        video,
        i + 1,
        plan.shorts[i],
        segs,
        font ?? bundledFont(),
        date,
        dest,
        onProgress: (f) => c.progress((i + f) / plan.shorts.length),
        cancel: c.cancel,
        log: c.log,
      ),
    );
    saveOutputs();
  }
};

/// Exports the cut sermon as `JJJJ-MM-DD Tema.mp3` next to it and adds the file to the sermon's outputs.
JobRun audioJob(SermonStore store) => (c) async {
  final s = store.byId(c.id)!;
  final video = s.outputs.where((o) => o.endsWith('.mp4')).firstOrNull;
  if (video == null || !File(video).existsSync()) {
    throw StateError('Sny eers die preek.');
  }
  final plan = _plan(store, c.id);
  c.phase(JobPhase.audio);
  c.progress(0);
  final out = await cutAudio(
    File(video),
    plan.title,
    s.date ?? p.basename(video).substring(0, 10),
    File(video).parent,
    duration: plan.sermonEnd - plan.sermonStart,
    onProgress: c.progress,
    cancel: c.cancel,
    log: c.log,
  );
  final latest = store.byId(c.id)!;
  if (!latest.outputs.contains(out.path)) {
    store.save(latest..outputs = [...latest.outputs, out.path]);
  }
};

SermonPlan _plan(SermonStore store, String id) => SermonPlan.fromJson(
  jsonDecode(File(p.join(store.root.path, id, kPlanFile)).readAsStringSync())
      as Map<String, dynamic>,
);

/// Uploads the cut sermon and its Shorts (privacy from settings), then puts the sermon in its playlist.
JobRun uploadJob(
  SermonStore store, {
  required YouTube yt,
  required AppSettings settings,
  required UploadQuota quota,
}) => (c) async {
  final s = store.byId(c.id)!;
  final videos = s.outputs.where((o) => o.endsWith('.mp4')).toList();
  if (videos.isEmpty) throw StateError('Sny eers die preek.');
  final plan = _plan(store, c.id);
  final description = describe(
    settings.template,
    tema: plan.title,
    scripture: s.scripture,
    date: s.date,
    description: plan.description,
  );
  c.phase(JobPhase.upload);
  for (var i = 0; i < videos.length; i++) {
    final path = videos[i];
    if (store.byId(c.id)!.uploads.containsKey(path)) continue;
    final title = i == 0 || i > plan.shorts.length
        ? plan.title
        : plan.shorts[i - 1].title;
    final session = File(p.join(store.root.path, c.id, 'upload-$i.json'));
    // A resumed session was already counted when it started.
    if (!session.existsSync()) quota.take();
    final id = await yt.upload(
      File(path),
      title: title.length > 100 ? title.substring(0, 100) : title,
      description: description,
      privacy: settings.privacy,
      session: session,
      onProgress: (f) => c.progress((i + f) / videos.length),
      cancel: c.cancel,
    );
    final latest = store.byId(c.id)!;
    store.save(latest..uploads = {...latest.uploads, path: id});
  }
  final name = playlistFor(s, settings.rules);
  final latest = store.byId(c.id)!;
  if (name != null && latest.playlist == null) {
    final pl = (await yt.playlists())[name] ?? await yt.createPlaylist(name);
    await yt.addToPlaylist(pl, latest.uploads[videos.first]!);
    store.save(latest..playlist = name);
  }
};

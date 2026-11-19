// @stelsel jobs
//   soort: module
//   wanneer: "Verwerk volgende", "Keur goed en sny", "Beplan weer" en by begin (hervat)
//   groep: core | Kern
//   skryf: <werkmap>/jobs.json | die ry; sermon.json van die preek wat verwerk word
//   doel: een taak op 'n slag (plan of sny), hervat ná herbegin, kanselleer, probeer weer
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
import 'store.dart';
import 'tools.dart';

enum JobKind { plan, cut }

enum JobStatus { wag, besig, klaar, fout, gekanselleer }

/// What a running job is busy with (the Werk-skerm maps it to text).
enum JobPhase { meta, plan, download, cut }

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
  void log(String line) => _queue.current?.log.add(line);
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
  JobQueue(this.store, {JobRun? plan, JobRun? cut, Directory? out, File? font})
    : _plan = plan ?? planJob(store),
      _cut = cut ?? cutJob(store, out: out, font: font) {
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
  final JobRun _plan, _cut;
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
    final f = _file..parent.createSync(recursive: true);
    final tmp = File('${f.path}.tmp')
      ..writeAsStringSync(jsonEncode([for (final j in jobs) j.toJson()]));
    tmp.renameSync(f.path);
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
  void start() => _loop ??= _run().whenComplete(() => _loop = null);

  Future<void> _run() async {
    while (true) {
      final i = jobs.indexWhere((j) => j.status == JobStatus.wag);
      if (i < 0) return;
      final job = jobs[i];
      current = job;
      job.status = JobStatus.besig;
      progress.value = null;
      phase.value = null;
      _persist();
      final cancel = _cancel = Completer<void>();
      final s = store.byId(job.sermon)!;
      try {
        await (job.kind == JobKind.plan ? _plan : _cut)(
          JobCtx(job.sermon, cancel.future, this),
        );
        job.status = JobStatus.klaar;
        s.state = job.kind == JobKind.plan
            ? SermonState.beplan
            : SermonState.gesny;
        s.error = null;
      } on JobCancelled {
        job.status = JobStatus.gekanselleer;
      } on Object catch (e) {
        job.status = JobStatus.fout;
        job.error = friendlyError(e);
        job.log.addAll('$e'.split('\n'));
        if (job.log.length > 200) job.log.removeRange(0, job.log.length - 200);
        s.state = SermonState.fout;
        s.error = job.error;
      }
      current = null;
      _cancel = null;
      store.save(s);
      _persist();
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
    if (s.state == SermonState.fout) {
      s.state = job.kind == JobKind.plan
          ? SermonState.nuut
          : SermonState.goedgekeur;
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
  final m = await fetchMeta(c.id, store.root, cancel: c.cancel);
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
    ),
    c.cancel.then<SermonPlan>((_) => throw JobCancelled()),
  ]);
};

/// Downloads the video and cuts the sermon and its Shorts from the saved plan.
JobRun cutJob(SermonStore store, {Directory? out, File? font}) => (c) async {
  c.phase(JobPhase.meta);
  final m = await fetchMeta(c.id, store.root, cancel: c.cancel);
  c.phase(JobPhase.download);
  c.progress(0);
  final video = await downloadVideo(
    m,
    onProgress: (v) => c.progress(v / 100),
    cancel: c.cancel,
  );
  final plan = SermonPlan.fromJson(
    jsonDecode(File(p.join(m.dir.path, kPlanFile)).readAsStringSync())
        as Map<String, dynamic>,
  );
  final segs = parseJson3(m.captions.readAsStringSync());
  final dest = out ?? outDir();
  final date = m.info.uploadDate;
  c.phase(JobPhase.cut);
  c.progress(null);
  final files = [await cutSermon(video, plan, date, dest, cancel: c.cancel)];
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
      ),
    );
  }
  store.save(store.byId(c.id)!..outputs = [for (final f in files) f.path]);
};

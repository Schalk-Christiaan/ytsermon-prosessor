// @stelsel jobs
//   soort: module
//   wanneer: "Verwerk volgende", "Keur goed en sny", "Beplan weer", "Klank vir WhatsApp", "Laai op" en by begin (hervat)
//   groep: core | Kern
//   skryf: <werkmap>/jobs.json | die ry; sermon.json van die preek wat verwerk word
//   doel: een taak op 'n slag (plan met grense en stilte-snap, sny, klank of oplaai), hervat ná herbegin, kanselleer, probeer weer
//   status: bou
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'bounds.dart';
import 'captions.dart';
import 'channel.dart';
import 'cutter.dart';
import 'models.dart';
import 'paths.dart';
import 'planner.dart';
import 'service_info.dart';
import 'playlists.dart';
import 'settings.dart';
import 'sound.dart';
import 'store.dart';
import 'tools.dart';
import 'youtube.dart';

/// What a job does: plan the bounds, cut, export audio or upload.
enum JobKind { plan, cut, audio, upload }

/// Where a job is: waiting, running, done, failed or cancelled.
enum JobStatus { wag, besig, klaar, fout, gekanselleer }

/// What a running job is busy with (the Werk-skerm maps it to text).
enum JobPhase { meta, plan, download, cut, audio, upload }

/// One queued piece of work for a sermon, persisted in jobs.json with its log.
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

// stap: v9 1 Gewone-taal fout | internet, Ollama of vol skyf word elk sy eie sin met die regstelling
/// Plain-language reason for a failed job.
String friendlyError(Object e) {
  const disk =
      'Die skyf is vol. Maak plek (ou video\'s in die werkgids) en probeer weer.';
  const net = 'Geen internet nie. Kyk die netwerk en probeer weer.';
  const ollama = 'Ollama het nie geantwoord nie. Maak seker dit loop.';
  if (e is PlanException) return 'Die plan is nie aanvaar nie: $e';
  if (e is FileSystemException &&
      const {28, 112}.contains(e.osError?.errorCode)) {
    return disk; // ENOSPC (Linux), ERROR_DISK_FULL (Windows)
  }
  if (e is ProcessException) {
    final m = e.message;
    if (m.contains('No space left on device')) return disk;
    if (RegExp(
      r'Unable to download|name resolution|getaddrinfo|Failed to resolve|Network is unreachable',
    ).hasMatch(m)) {
      return net;
    }
    return '${e.executable} het misluk. Kyk die tegniese log.';
  }
  if (e is SocketException) {
    return e.port == ollamaBase().port ? ollama : net;
  }
  // A server answered, so the network works: keep its own message.
  if (e is HttpException) {
    return e.message.startsWith('Ollama') ? ollama : e.message;
  }
  if (e is TlsException) return net;
  if (e is StateError) return e.message;
  return '$e';
}

/// One-at-a-time work queue in a plain async loop (no timers); persisted so a restart resumes it.
class JobQueue extends ChangeNotifier {
  // stap: v5 1 Hervat ná 'n onderbreking | jobs.json word gelees; 'n taak wat besig was, wag weer en loop van voor af
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

  // stap: v9 3 Probeer weer | die mislukte taak staan weer in die ry, die werk tot dusver bly
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

// stap: v1 2 Beplan | onderskrifte + video af; Ollama benoem die blokke, kode kies die grense (gebed tot gebed, stilte-snap), Ollama skryf net teks
// tak: Ollama af → "Ollama het nie geantwoord nie" met Probeer weer in Werkry
/// Fetches meta, captions and video (the sound is needed for the blocks and the silence snap), has Ollama
/// label the blocks, lets `findBounds` pick the cut from the labels and asks Ollama for the text; fills the sermon's date. An existing plan.json is kept as it is.
JobRun planJob(SermonStore store) => (c) async {
  c.phase(JobPhase.meta);
  final m = await fetchMeta(c.id, store.root, cancel: c.cancel, log: c.log);
  final s = store.byId(c.id)!
    ..date = m.info.uploadDate
    ..scripture = scriptureFrom(m.info.descriptionText)
    ..duration = m.info.durationSeconds;
  store.save(s);
  if (File(p.join(m.dir.path, kPlanFile)).existsSync()) return;
  final segs = parseJson3(m.captions.readAsStringSync());
  c.phase(JobPhase.download);
  c.progress(0);
  final video = await downloadVideo(
    m,
    onProgress: (v) => c.progress(v / 100),
    cancel: c.cancel,
    log: c.log,
  );
  c.progress(null);
  final sound = await soundBlocks(m.dir, video, cancel: c.cancel);
  c.phase(JobPhase.plan);
  // Ollama's HTTP call is not killable: cancelling abandons it.
  final a = await Future.any([
    Planner().analyse(
      blocks: blocks(segs, sound),
      sound: sound,
      duration: s.duration,
      originalDescription: m.info.descriptionText,
      psalms: ServiceInfo.fromInfo(m.info).psalms,
    ),
    c.cancel.then<Analysis>((_) => throw JobCancelled()),
  ]);
  saveAnalysis(m.dir, a);
  final bounds = await snapBounds(
    video,
    findBounds(a.blocks, sound),
    cancel: c.cancel,
  );
  await Future.any([
    Planner().loadOrPlan(
      m.dir,
      compactText: compact(segs),
      bounds: bounds,
      duration: s.duration,
      originalDescription: m.info.descriptionText,
      cancel: c.cancel,
    ),
    c.cancel.then<SermonPlan>((_) => throw JobCancelled()),
  ]);
};

// stap: v1 4 Sny | herkodeer presies van die eerste woord tot ná die Amen (met intro/outro en uitgeknipte stukke saamgevoeg); uitset in die uitsetgids
// stap: v3 4 Sny sonder YouTube | dieselfde snit; die opname het geen Shorts-onderskrifte nie
// stap: diensindeling 9 Sny die uitvoere | Volle preek, Net die woord en Sang soos in Instellings gekies, in die diensgids; dan WhatsApp.txt en diens.json
/// Downloads the video and makes the chosen outputs (Instellings `exports`) of the service in its [serviceDir]:
/// the sermon with the Shorts, "Net die woord", each song as mp3; then writes `WhatsApp.txt` and `diens.json`.
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
  final settings = AppSettings.load(store.root);
  final info = ServiceInfo.fromInfo(m.info)
    ..theme ??= plan.title
    ..label = loadService(m.dir);
  applyChoices(info, m.dir);
  final dest = Directory(serviceDir(out?.path ?? settings.outDir, info))
    ..createSync(recursive: true);
  File? clip(String? path) => path == null ? null : File(path);
  final word = wordParts(loadLabels(m.dir), loadSound(m.dir), plan.parts());
  final songs = loadSongs(m.dir);
  final files = <File>[];
  void saveOutputs() =>
      store.save(store.byId(c.id)!..outputs = [for (final f in files) f.path]);
  c.phase(JobPhase.cut);
  c.progress(null);
  if (settings.exports.contains('full')) {
    files.add(
      await cutParts(
        video,
        plan.parts(),
        File(p.join(dest.path, '$kFullName.mp4')),
        intro: clip(settings.intro),
        outro: clip(settings.outro),
        onProgress: c.progress,
        cancel: c.cancel,
        log: c.log,
      ),
    );
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
          info.date,
          dest,
          onProgress: (f) => c.progress((i + f) / plan.shorts.length),
          cancel: c.cancel,
          log: c.log,
        ),
      );
      saveOutputs();
    }
  }
  if (settings.exports.contains('word') && word.isNotEmpty) {
    c.progress(null);
    files.add(
      await cutParts(
        video,
        word,
        File(p.join(dest.path, '$kWordName.mp4')),
        intro: clip(settings.intro),
        outro: clip(settings.outro),
        onProgress: c.progress,
        cancel: c.cancel,
        log: c.log,
      ),
    );
    saveOutputs();
  }
  final songFiles = <int, File>{};
  if (settings.exports.contains('songs')) {
    for (final (i, s) in songs.indexed) {
      c.progress(i / songs.length);
      songFiles[s.n] = await cutSong(
        video,
        s,
        info,
        dest,
        cancel: c.cancel,
        log: c.log,
      );
    }
  }
  File(p.join(dest.path, 'WhatsApp.txt'))
      .writeAsStringSync(whatsappText(settings.whatsappTemplate, info));
  File(p.join(dest.path, 'diens.json')).writeAsStringSync(
    jsonEncode({
      'info': info.toJson(),
      'title': plan.title,
      'files': [for (final f in files) p.basename(f.path)],
      'songs': [
        for (final s in songs)
          {
            ...s.toJson(),
            if (songFiles[s.n] != null)
              'file': p.join('Sang', p.basename(songFiles[s.n]!.path)),
          },
      ],
    }),
  );
};

// stap: v7 2 Klank uitvoer | mp3 van Net die woord (of Volle preek as dit nie gesny is nie), langs die gesnyde video
// tak: preek nog nie gesny nie → "Sny eers die preek"
/// Exports "Net die woord" (else the full sermon) as an mp3 next to its mp4 and adds the file to the sermon's outputs.
JobRun audioJob(SermonStore store) => (c) async {
  final s = store.byId(c.id)!;
  final mp4s = s.outputs.where((o) => o.endsWith('.mp4'));
  final video =
      mp4s.where((o) => p.basename(o) == '$kWordName.mp4').firstOrNull ??
      mp4s.firstOrNull;
  if (video == null || !File(video).existsSync()) {
    throw StateError('Sny eers die preek.');
  }
  final plan = _plan(store, c.id);
  c.phase(JobPhase.audio);
  c.progress(0);
  final out = await cutAudio(
    File(video),
    plan.title,
    File(p.setExtension(video, '.mp3')),
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

/// The mp4 outputs that go to YouTube: the sermon and its Shorts, not "Net die woord".
List<String> _uploadable(Sermon s) => [
  for (final o in s.outputs)
    if (o.endsWith('.mp4') && p.basename(o) != '$kWordName.mp4') o,
];

SermonPlan _plan(SermonStore store, String id) => SermonPlan.fromJson(
  jsonDecode(File(p.join(store.root.path, id, kPlanFile)).readAsStringSync())
      as Map<String, dynamic>,
);

/// The YouTube description: the template filled from the plan and the sermon.
String _description(Sermon s, SermonPlan plan, AppSettings settings) =>
    describe(
      settings.template,
      tema: plan.title,
      scripture: s.scripture,
      date: s.date,
      description: plan.description,
    );

/// Output [i]'s YouTube title: 0 = the sermon, then the Shorts; YouTube allows 100 characters.
String _videoTitle(SermonPlan plan, int i) {
  final t = i == 0 || i > plan.shorts.length
      ? plan.title
      : plan.shorts[i - 1].title;
  return t.length > 100 ? t.substring(0, 100) : t;
}

// stap: v8 3 Stuur na elke opgelaaide video | titel en beskrywing uit die plan, per mp4-uitset
/// "Werk op YouTube by": sends the plan's current title and description to every uploaded video; returns how many.
Future<int> updateOnYouTube(
  SermonStore store,
  String id, {
  required YouTube yt,
  required AppSettings settings,
}) async {
  final s = store.byId(id)!;
  final plan = _plan(store, id);
  final description = _description(s, plan, settings);
  final videos = _uploadable(s);
  var n = 0;
  for (var i = 0; i < videos.length; i++) {
    final vid = s.uploads[videos[i]];
    if (vid == null) continue;
    await yt.updateVideo(
      vid,
      title: _videoTitle(plan, i),
      description: description,
    );
    n++;
  }
  return n;
}

// stap: v1 5 Laai op | volle preek en Shorts na YouTube, in die regte snitlys
// tak: kwota op → "probeer môre weer"; geen internet → Probeer weer
/// Uploads the cut sermon and its Shorts (privacy from settings), then puts the sermon in its playlist.
JobRun uploadJob(
  SermonStore store, {
  required YouTube yt,
  required AppSettings settings,
  required UploadQuota quota,
}) => (c) async {
  final s = store.byId(c.id)!;
  final videos = _uploadable(s);
  if (videos.isEmpty) throw StateError('Sny eers die preek.');
  final plan = _plan(store, c.id);
  final description = _description(s, plan, settings);
  c.phase(JobPhase.upload);
  for (var i = 0; i < videos.length; i++) {
    final path = videos[i];
    if (store.byId(c.id)!.uploads.containsKey(path)) continue;
    final title = _videoTitle(plan, i);
    final session = File(p.join(store.root.path, c.id, 'upload-$i.json'));
    // A resumed session was already counted when it started.
    if (!session.existsSync()) quota.take();
    final id = await yt.upload(
      File(path),
      title: title,
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

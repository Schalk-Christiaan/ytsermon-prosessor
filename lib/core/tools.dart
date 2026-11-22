// @stelsel tools
//   soort: module
//   wanneer: by oopmaak van Instellings en voor elke aflaai/KI-oproep
//   groep: core | Kern
//   skryf: —
//   doel: kies video-enkodeerder (videoEncoder: NVENC as dit werk, anders libx264); vind yt-dlp/ffmpeg/ffprobe/ollama (langs die exe, Ollama se gids, PATH), loop eksterne prosesse (runTool), toets Ollama + qwen3:8b, laai die model af, begin Ollama; wys qjs.exe (QuickJS) as JS-looptyd aan yt-dlp as dit langs die exe lê
//   status: bou
//   bewys: 7236634
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const kModel = 'qwen3:8b';

/// The ffmpeg to run; tests point it at a fake script.
String ffmpegTool = 'ffmpeg';

Future<String>? _encoder;

/// The H.264 encoder ffmpeg uses: `h264_nvenc` when it is listed and a 5-frame trial encode works
/// (a listed encoder still fails without an NVIDIA GPU), else `libx264`. Probed once per session.
Future<String> videoEncoder() => _encoder ??= _pickEncoder();

/// Forgets the probe result (tests) or, with [to], forces it (after an NVENC failure mid-job).
void resetVideoEncoder({String? to}) =>
    _encoder = to == null ? null : Future.value(to);

Future<String> _pickEncoder() async {
  final exe =
      findExecutable(ffmpegTool) ??
      (p.isAbsolute(ffmpegTool) ? ffmpegTool : null);
  if (exe == null) return 'libx264';
  try {
    final list = await Process.run(exe, ['-hide_banner', '-encoders']);
    if (!(list.stdout as String).contains('h264_nvenc')) return 'libx264';
    final trial = await Process.run(exe, [
      '-hide_banner',
      '-v',
      'error',
      '-f',
      'lavfi',
      '-i',
      'color=c=black:s=256x256',
      '-frames:v',
      '5',
      '-c:v',
      'h264_nvenc',
      '-f',
      'null',
      '-',
    ]);
    return trial.exitCode == 0 ? 'h264_nvenc' : 'libx264';
  } on ProcessException {
    return 'libx264';
  }
}

/// Base URL of the Ollama server (`OLLAMA_HOST` or the local default).
Uri ollamaBase() {
  var h = Platform.environment['OLLAMA_HOST'] ?? 'http://127.0.0.1:11434';
  if (!h.contains('://')) h = 'http://$h';
  return Uri.parse(h);
}

/// Finds [name] next to the app executable first, then on PATH; null if absent.
String? findExecutable(String name, {String? path, String? exeDir}) {
  final file = Platform.isWindows ? '$name.exe' : name;
  final local = Platform.environment['LOCALAPPDATA'];
  final dirs = [
    exeDir ?? p.dirname(Platform.resolvedExecutable),
    // Ollama's per-user install; its PATH entry is missing until the next login.
    if (path == null && local != null) p.join(local, 'Programs', 'Ollama'),
    ...(path ?? Platform.environment['PATH'] ?? '')
        .split(Platform.isWindows ? ';' : ':')
        .where((d) => d.isNotEmpty),
  ];
  for (final d in dirs) {
    final f = p.join(d, file);
    if (File(f).existsSync()) return f;
  }
  return null;
}

/// Thrown by [runTool] when its `cancel` future completes before the process ends.
class JobCancelled implements Exception {
  @override
  String toString() => 'JobCancelled';
}

/// Runs [exe] (a tool name found via [findExecutable], or an absolute path) with [args];
/// stdout lines go to [onLine], stderr is buffered (and each chunk also goes to [onErr]). Non-zero exit throws [ProcessException]
/// carrying stderr; completing [cancel] kills the process and throws [JobCancelled].
Future<void> runTool(
  String exe,
  List<String> args, {
  void Function(String line)? onLine,
  void Function(String chunk)? onErr,
  String? cwd,
  Future<void>? cancel,
}) async {
  final path = findExecutable(exe) ?? (p.isAbsolute(exe) ? exe : null);
  if (path == null) throw StateError('$exe ontbreek');
  // yt-dlp needs a JS runtime for YouTube; Windows ships none, so the installer puts qjs (QuickJS) next to the exe.
  final qjs = exe == 'yt-dlp' ? findExecutable('qjs') : null;
  final proc = await Process.start(path, [
    if (qjs != null) ...['--js-runtimes', 'quickjs:$qjs'],
    ...args,
  ], workingDirectory: cwd);
  var cancelled = false, finished = false;
  cancel?.then((_) {
    if (finished) return;
    cancelled = true;
    _killTree(proc);
  });
  final err = StringBuffer();
  final errDone = proc.stderr.transform(utf8.decoder).forEach((c) {
    err.write(c);
    onErr?.call(c);
  });
  final done = proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((l) => onLine?.call(l));
  final code = await proc.exitCode;
  finished = true;
  await Future.wait([done, errDone]);
  if (cancelled) throw JobCancelled();
  if (code != 0) throw ProcessException(exe, args, err.toString(), code);
}

/// Kills [proc] and its children (yt-dlp starts ffmpeg): children first, or they are orphaned.
void _killTree(Process proc) {
  if (Platform.isWindows) {
    Process.run('taskkill', ['/T', '/F', '/PID', '${proc.pid}']);
  } else {
    Process.run('pkill', [
      '-TERM',
      '-P',
      '${proc.pid}',
    ]).whenComplete(proc.kill);
  }
}

/// Result of probing one external tool; [ok] false means [detail] says what is missing.
class ToolStatus {
  const ToolStatus(this.name, this.ok, this.detail);
  final String name;
  final bool ok;

  /// Version string when ok; machine-readable reason otherwise (`missing`, `notRunning`, `model:<name>`).
  final String detail;

  bool get notRunning => detail == 'notRunning';

  /// The model that is missing from Ollama, or null.
  String? get missingModel =>
      detail.startsWith('model:') ? detail.substring(6) : null;
}

/// Opens [path] with the system default; with [select] shows the file in its folder
/// (Windows selects it in Explorer, elsewhere the folder opens).
Future<void> openPath(String path, {bool select = false}) async {
  if (Platform.isWindows) {
    await Process.start('explorer', [if (select) '/select,$path' else path]);
  } else {
    final opener = Platform.isMacOS ? 'open' : 'xdg-open';
    await Process.start(opener, [select ? p.dirname(path) : path]);
  }
}

/// `yt-dlp -U`; returns its output. Throws [ProcessException] when it cannot update
/// (e.g. a system package on Linux).
Future<String> updateYtDlp() async {
  final out = StringBuffer();
  await runTool('yt-dlp', ['-U'], onLine: (l) => out.writeln(l));
  return out.toString().trim();
}

Future<ToolStatus> _probe(
  String name,
  List<String> args, {
  String? path,
}) async {
  final exe = findExecutable(name, path: path);
  if (exe == null) return ToolStatus(name, false, 'missing');
  try {
    final r = await Process.run(exe, args);
    final line = (r.stdout as String).split('\n').first.trim();
    final v = RegExp(r'version (\S+)').firstMatch(line)?.group(1);
    return ToolStatus(name, r.exitCode == 0, v ?? line);
  } on ProcessException {
    return ToolStatus(name, false, 'missing');
  }
}

Future<dynamic> _getJson(String endpoint) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 3);
  try {
    final req = await c.getUrl(ollamaBase().resolve(endpoint));
    final res = await req.close().timeout(const Duration(seconds: 5));
    return jsonDecode(await res.transform(utf8.decoder).join());
  } finally {
    c.close(force: true);
  }
}

/// Checks that Ollama answers and has the model pulled.
Future<ToolStatus> probeOllama({String model = kModel}) async {
  try {
    final v = (await _getJson('/api/version'))['version'] as String;
    final tags = await _getJson('/api/tags');
    final has = (tags['models'] as List).any(
      (m) => m['name'] == model || m['model'] == model,
    );
    return has
        ? ToolStatus('ollama', true, '$v · $model')
        : ToolStatus('ollama', false, 'model:$model');
  } on Exception {
    return const ToolStatus('ollama', false, 'notRunning');
  }
}

/// Downloads [model] through Ollama's `/api/pull`; [onProgress] gets 0..1 per layer.
Future<void> pullModel({
  required void Function(double) onProgress,
  String model = kModel,
  Uri? base,
}) async {
  final c = HttpClient();
  try {
    final req = await c.postUrl((base ?? ollamaBase()).resolve('/api/pull'));
    req.headers.contentType = ContentType.json;
    req.write(jsonEncode({'model': model, 'stream': true}));
    final res = await req.close();
    await for (final line
        in res.transform(utf8.decoder).transform(const LineSplitter())) {
      if (line.trim().isEmpty) continue;
      final j = jsonDecode(line) as Map<String, dynamic>;
      if (j['error'] != null) {
        throw HttpException('Model aflaai het misluk: ${j['error']}');
      }
      if (j['status'] == 'success') return;
      final total = j['total'] as num?, done = j['completed'] as num?;
      if (total != null && total > 0 && done != null) onProgress(done / total);
    }
    throw const HttpException('Model aflaai het voortydig gestop.');
  } finally {
    c.close(force: true);
  }
}

/// Starts `ollama serve` detached (it keeps running after the app closes).
Future<void> startOllama() async {
  final exe = findExecutable('ollama');
  if (exe == null) throw StateError('ollama ontbreek');
  await Process.start(exe, ['serve'], mode: ProcessStartMode.detached);
}

/// Probes yt-dlp, ffmpeg, ffprobe and Ollama (with [kModel]); order is the display order.
Future<List<ToolStatus>> probeAll({String? path}) => Future.wait([
  _probe('yt-dlp', ['--version'], path: path),
  _probe('ffmpeg', ['-version'], path: path),
  _probe('ffprobe', ['-version'], path: path),
  probeOllama(),
]);

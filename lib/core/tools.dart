// @stelsel tools
//   soort: module
//   wanneer: by oopmaak van Instellings en voor elke aflaai/KI-oproep
//   groep: core | Kern
//   skryf: —
//   doel: vind yt-dlp/ffmpeg/ffprobe (PATH of langs die exe), loop eksterne prosesse (runTool) en toets Ollama + qwen3:8b
//   status: oop
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

const kModel = 'qwen3:8b';

/// Base URL of the Ollama server (`OLLAMA_HOST` or the local default).
Uri ollamaBase() {
  var h = Platform.environment['OLLAMA_HOST'] ?? 'http://127.0.0.1:11434';
  if (!h.contains('://')) h = 'http://$h';
  return Uri.parse(h);
}

/// Finds [name] next to the app executable first, then on PATH; null if absent.
String? findExecutable(String name, {String? path, String? exeDir}) {
  final file = Platform.isWindows ? '$name.exe' : name;
  final dirs = [
    exeDir ?? p.dirname(Platform.resolvedExecutable),
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
/// stdout lines go to [onLine], stderr is buffered. Non-zero exit throws [ProcessException]
/// carrying stderr; completing [cancel] kills the process and throws [JobCancelled].
Future<void> runTool(
  String exe,
  List<String> args, {
  void Function(String line)? onLine,
  String? cwd,
  Future<void>? cancel,
}) async {
  final path = findExecutable(exe) ?? (p.isAbsolute(exe) ? exe : null);
  if (path == null) throw StateError('$exe ontbreek');
  final proc = await Process.start(path, args, workingDirectory: cwd);
  var cancelled = false;
  cancel?.then((_) {
    cancelled = true;
    proc.kill();
  });
  final err = StringBuffer();
  proc.stderr.transform(utf8.decoder).listen(err.write);
  final done = proc.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .forEach((l) => onLine?.call(l));
  final code = await proc.exitCode;
  await done;
  if (cancelled) throw JobCancelled();
  if (code != 0) throw ProcessException(exe, args, err.toString(), code);
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

/// Opens [d] in the system file manager.
Future<void> openFolder(Directory d) => Process.run(
  Platform.isWindows ? 'explorer' : (Platform.isMacOS ? 'open' : 'xdg-open'),
  [d.path],
);

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

/// Probes yt-dlp, ffmpeg, ffprobe and Ollama (with [kModel]); order is the display order.
Future<List<ToolStatus>> probeAll({String? path}) => Future.wait([
  _probe('yt-dlp', ['--version'], path: path),
  _probe('ffmpeg', ['-version'], path: path),
  _probe('ffprobe', ['-version'], path: path),
  probeOllama(),
]);

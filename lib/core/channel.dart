import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tools.dart';

/// Video ID from a youtu.be / watch?v= / live/ / shorts/ URL or a bare 11-char ID; null if none.
String? videoIdFromUrl(String url) {
  final u = url.trim();
  if (RegExp(r'^[\w-]{11}$').hasMatch(u)) return u;
  final m = RegExp(r'(?:youtu\.be/|[?&]v=|/(?:live|shorts|embed)/)([\w-]{11})')
      .firstMatch(u);
  return m?.group(1);
}

/// Percentage from a yt-dlp `[download]  42.3% of ...` line; null for other lines.
double? parseProgress(String line) {
  final m = RegExp(r'^\[download\]\s+(\d+(?:\.\d+)?)%').firstMatch(line);
  return m == null ? null : double.parse(m.group(1)!);
}

/// What `fetchMeta` leaves in the work directory.
class FetchedMeta {
  FetchedMeta(this.id, this.dir, this.info);
  final String id;
  final Directory dir;
  final Map<String, dynamic> info;

  File get captions => File(p.join(dir.path, '$id.af-orig.json3'));
  File get video => File(p.join(dir.path, 'video.mp4'));
}

String _ytdlp() {
  final exe = findExecutable('yt-dlp');
  if (exe == null) throw StateError('yt-dlp ontbreek');
  return exe;
}

List<String> _ffmpegArgs() {
  final f = findExecutable('ffmpeg');
  return f == null ? [] : ['--ffmpeg-location', f];
}

Future<void> _run(
  List<String> args, {
  void Function(String line)? onLine,
}) async {
  final proc = await Process.start(_ytdlp(), args);
  final err = StringBuffer();
  proc.stderr.transform(utf8.decoder).listen(err.write);
  await for (final line
      in proc.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
    onLine?.call(line);
  }
  final code = await proc.exitCode;
  if (code != 0) throw ProcessException('yt-dlp', args, err.toString(), code);
}

/// Downloads info.json and the af-orig json3 captions to `<root>/<id>/`; skips what already exists.
Future<FetchedMeta> fetchMeta(String url, Directory root) async {
  final id = videoIdFromUrl(url);
  if (id == null) throw ArgumentError('Geen YouTube-skakel nie: $url');
  final dir = Directory(p.join(root.path, id))..createSync(recursive: true);
  final infoFile = File(p.join(dir.path, '$id.info.json'));
  final meta = FetchedMeta(id, dir, {});
  if (!infoFile.existsSync() || !meta.captions.existsSync()) {
    await _run([
      '--write-info-json',
      '--write-auto-subs',
      '--sub-langs',
      'af-orig',
      '--sub-format',
      'json3',
      '--skip-download',
      '-o',
      p.join(dir.path, '%(id)s'),
      'https://www.youtube.com/watch?v=$id',
    ]);
  }
  if (!meta.captions.existsSync()) {
    throw StateError('Geen af-orig-onderskrifte vir $id nie');
  }
  return FetchedMeta(
    id,
    dir,
    jsonDecode(infoFile.readAsStringSync()) as Map<String, dynamic>,
  );
}

/// Downloads the full video (<=1080p, mp4) to `<dir>/video.mp4`; reports 0..100 via [onProgress]. Skips if present.
/// Full download: `--download-sections` is currently broken.
Future<File> downloadVideo(
  FetchedMeta meta, {
  void Function(double pct)? onProgress,
}) async {
  if (meta.video.existsSync()) {
    onProgress?.call(100);
    return meta.video;
  }
  await _run(
    [
      '-f',
      'bv*[height<=1080]+ba/b',
      '--merge-output-format',
      'mp4',
      '--newline',
      ..._ffmpegArgs(),
      '-o',
      p.join(meta.dir.path, 'video.%(ext)s'),
      'https://www.youtube.com/watch?v=${meta.id}',
    ],
    onLine: (l) {
      final v = parseProgress(l);
      if (v != null) onProgress?.call(v);
    },
  );
  return meta.video;
}

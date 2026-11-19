// @stelsel cutter
//   soort: module
//   wanneer: by 'Keur goed en sny' en 'Klank vir WhatsApp'
//   groep: core | Kern
//   skryf: out/
//   doel: sny die preek (stroomkopie), Shorts (9:16 met ingebrande onderskrif) en WhatsApp-klank (mono mp3 64 kbps) met ffmpeg
//   status: oop
import 'dart:io';

import 'package:path/path.dart' as p;

import 'captions.dart';
import 'models.dart';
import 'tools.dart';

String _sec(double s) => s.toStringAsFixed(3);

String _clean(String s) => s.replaceAll(RegExp(r'[<>:"/\\|?*]'), '').trim();

/// `JJJJ-MM-DD Titel.<ext>` with characters illegal on Windows removed.
String sermonFileName(String date, String title, {String ext = 'mp4'}) =>
    '$date ${_clean(title)}.$ext';

/// ffmpeg arguments for a keyframe-accurate-enough stream copy of [start, end].
List<String> sermonArgs(String video, double start, double end, String out) => [
  '-y',
  '-ss',
  _sec(start),
  '-to',
  _sec(end),
  '-i',
  video,
  '-c',
  'copy',
  out,
];

/// ffmpeg arguments for a 1080x1920 Short with burned-in subtitles.
/// Run with cwd = work dir: [srt] and `fonts/` stay relative because a Windows drive letter breaks the filter.
List<String> shortArgs(
  String video,
  String srt,
  double start,
  double end,
  String out,
) => [
  '-y',
  '-ss',
  _sec(start),
  '-to',
  _sec(end),
  '-i',
  video,
  '-vf',
  "crop=ih*9/16:ih,scale=1080:1920,subtitles=$srt:fontsdir=fonts:"
      "force_style='FontName=Source Sans 3,FontSize=14,Alignment=2,MarginV=70'",
  '-c:v',
  'libx264',
  '-crf',
  '20',
  '-pix_fmt',
  'yuv420p',
  '-c:a',
  'aac',
  '-movflags',
  '+faststart',
  '-nostats',
  '-progress',
  'pipe:1',
  out,
];

/// ffmpeg arguments for the WhatsApp audio: mono mp3 at 64 kbps (~20 MB per 40 min) with an ID3 title.
List<String> audioArgs(String input, String out, String title) => [
  '-y',
  '-i',
  input,
  '-vn',
  '-ac',
  '1',
  '-c:a',
  'libmp3lame',
  '-b:a',
  '64k',
  '-id3v2_version',
  '3',
  '-metadata',
  'title=$title',
  '-nostats',
  '-progress',
  'pipe:1',
  out,
];

/// Seconds from an ffmpeg `-progress` line `out_time_us=…`; null for other lines.
double? parseFfmpegProgress(String line) {
  final m = RegExp(r'^out_time_us=(\d+)$').firstMatch(line);
  return m == null ? null : int.parse(m.group(1)!) / 1e6;
}

Future<void> _ffmpeg(
  List<String> args, {
  String? cwd,
  double? duration,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) => runTool(
  'ffmpeg',
  args,
  cwd: cwd,
  cancel: cancel,
  onLine: (l) {
    log?.call(l);
    final t = parseFfmpegProgress(l);
    if (t != null && duration != null && duration > 0) {
      onProgress?.call((t / duration).clamp(0, 1));
    }
  },
);

/// Cuts the sermon (stream copy) into [outDir]; returns the file.
Future<File> cutSermon(
  File video,
  SermonPlan plan,
  String date,
  Directory outDir, {
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  outDir.createSync(recursive: true);
  final out = p.join(outDir.path, sermonFileName(date, plan.title));
  await _ffmpeg(
    sermonArgs(video.path, plan.sermonStart, plan.sermonEnd, out),
    cancel: cancel,
    log: log,
  );
  return File(out);
}

/// Cuts Short number [n] (1-based) with subtitles from [segs]; [fontFile] is copied next to the video
/// so that the filter can use relative paths (cwd = the video's directory).
Future<File> cutShort(
  File video,
  int n,
  Short s,
  List<Segment> segs,
  File fontFile,
  String date,
  Directory outDir, {
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  outDir.createSync(recursive: true);
  final work = video.parent;
  final fonts = Directory(p.join(work.path, 'fonts'))..createSync();
  final font = File(p.join(fonts.path, p.basename(fontFile.path)));
  if (!font.existsSync()) fontFile.copySync(font.path);
  final srt = 'short-$n.srt';
  File(p.join(work.path, srt)).writeAsStringSync(toSrt(segs, s.start, s.end));
  final out = p.join(
    outDir.absolute.path,
    '$date Short $n ${_clean(s.title)}.mp4',
  );
  await _ffmpeg(
    shortArgs(p.basename(video.path), srt, s.start, s.end, out),
    cwd: work.path,
    duration: s.end - s.start,
    onProgress: onProgress,
    cancel: cancel,
    log: log,
  );
  return File(out);
}

/// Exports [sermon] (the cut mp4) as `JJJJ-MM-DD Tema.mp3` in [outDir] for WhatsApp.
Future<File> cutAudio(
  File sermon,
  String title,
  String date,
  Directory outDir, {
  double? duration,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  outDir.createSync(recursive: true);
  final out = p.join(outDir.path, sermonFileName(date, title, ext: 'mp3'));
  await _ffmpeg(
    audioArgs(sermon.path, out, title),
    duration: duration,
    onProgress: onProgress,
    cancel: cancel,
    log: log,
  );
  return File(out);
}

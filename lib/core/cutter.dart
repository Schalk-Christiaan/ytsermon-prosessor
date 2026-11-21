// @stelsel cutter
//   soort: module
//   wanneer: by 'Keur goed en sny' en 'Klank vir WhatsApp'
//   groep: core | Kern
//   skryf: out/
//   doel: sny die preek (herkodeer net die preekstuk, of segmente plus intro/outro saamgevoeg), Shorts (9:16 met ingebrande onderskrif) en WhatsApp-klank (mono mp3 64 kbps) met ffmpeg
//   status: bou
import 'dart:convert';
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

/// ffmpeg arguments that re-encode exactly [start, end] (a stream copy can only start at a keyframe,
/// up to seconds off the prayer); `-ss` before `-i` seeks fast and stays frame-accurate when re-encoding.
List<String> sermonArgs(String video, double start, double end, String out) => [
  '-y',
  '-ss',
  _sec(start),
  '-to',
  _sec(end),
  '-i',
  video,
  '-c:v',
  'libx264',
  '-preset',
  'veryfast',
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

/// ffmpeg arguments that print the silences (below -35 dB for 0.3 s) of the window [from, to] of [video] on stderr;
/// times are relative to [from] (see `parseSilences`).
List<String> silenceArgs(String video, double from, double to) => [
  '-hide_banner',
  '-nostats',
  '-ss',
  _sec(from),
  '-t',
  _sec(to - from),
  '-i',
  video,
  '-vn',
  '-af',
  'silencedetect=noise=-35dB:d=0.3',
  '-f',
  'null',
  '-',
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

/// What ffprobe says about a video file (the join needs size, frame rate and whether there is sound).
class MediaInfo {
  const MediaInfo(
    this.width,
    this.height,
    this.rate,
    this.duration,
    this.hasAudio,
  );
  final int width, height;

  /// ffprobe's `r_frame_rate`, e.g. `30000/1001`.
  final String rate;
  final double duration;
  final bool hasAudio;
}

/// Reads [f] with ffprobe.
Future<MediaInfo> probeMedia(File f) async {
  final out = StringBuffer();
  await runTool('ffprobe', [
    '-v',
    'error',
    '-show_entries',
    'stream=codec_type,width,height,r_frame_rate:format=duration',
    '-of',
    'json',
    f.path,
  ], onLine: out.writeln);
  final j = jsonDecode(out.toString()) as Map<String, dynamic>;
  final streams = (j['streams'] as List).cast<Map<String, dynamic>>();
  final v = streams.firstWhere((s) => s['codec_type'] == 'video');
  return MediaInfo(
    v['width'] as int,
    v['height'] as int,
    v['r_frame_rate'] as String,
    double.parse(j['format']['duration'] as String),
    streams.any((s) => s['codec_type'] == 'audio'),
  );
}

/// One piece of a joined cut: a whole clip (intro/outro) or a [start, end] part of the service video.
typedef JoinPiece = ({String path, MediaInfo info, Span? part});

/// ffmpeg arguments that join [pieces] into one file the size and frame rate of [target]: each piece
/// is scaled and padded (no stretching), a piece without sound gets silence, then `concat`.
List<String> joinArgs(List<JoinPiece> pieces, MediaInfo target, String out) {
  final inputs = <String>[], filters = <String>[], labels = <String>[];
  var n = 0;
  for (final (k, pc) in pieces.indexed) {
    final part = pc.part;
    final secs = part == null ? pc.info.duration : part.end - part.start;
    if (part != null)
      inputs.addAll(['-ss', _sec(part.start), '-to', _sec(part.end)]);
    inputs.addAll(['-i', pc.path]);
    final vi = n++;
    var ai = vi;
    if (!pc.info.hasAudio) {
      inputs.addAll([
        '-f',
        'lavfi',
        '-t',
        _sec(secs),
        '-i',
        'anullsrc=r=48000:cl=stereo',
      ]);
      ai = n++;
    }
    final w = target.width, h = target.height;
    filters.add(
      '[$vi:v]scale=$w:$h:force_original_aspect_ratio=decrease,'
      'pad=$w:$h:(ow-iw)/2:(oh-ih)/2,setsar=1,fps=${target.rate},format=yuv420p[v$k]',
    );
    filters.add('[$ai:a]aresample=48000,aformat=channel_layouts=stereo[a$k]');
    labels.add('[v$k][a$k]');
  }
  filters.add('${labels.join()}concat=n=${pieces.length}:v=1:a=1[v][a]');
  return [
    '-y',
    ...inputs,
    '-filter_complex',
    filters.join(';'),
    '-map',
    '[v]',
    '-map',
    '[a]',
    '-c:v',
    'libx264',
    '-preset',
    'veryfast',
    '-crf',
    '20',
    '-c:a',
    'aac',
    '-b:a',
    '160k',
    '-movflags',
    '+faststart',
    '-nostats',
    '-progress',
    'pipe:1',
    out,
  ];
}

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

/// Cuts the sermon into [outDir]; returns the file. One part and no clips = one re-encode of just that part;
/// cut-out pieces or an [intro]/[outro] re-encode everything into one file via [joinArgs].
Future<File> cutSermon(
  File video,
  SermonPlan plan,
  String date,
  Directory outDir, {
  File? intro,
  File? outro,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  outDir.createSync(recursive: true);
  final out = p.join(outDir.path, sermonFileName(date, plan.title));
  final parts = plan.parts();
  if (parts.length == 1 && intro == null && outro == null) {
    await _ffmpeg(
      sermonArgs(video.path, parts.single.start, parts.single.end, out),
      duration: parts.single.end - parts.single.start,
      onProgress: onProgress,
      cancel: cancel,
      log: log,
    );
    return File(out);
  }
  final main = await probeMedia(video);
  Future<JoinPiece> clip(File f) async =>
      (path: f.path, info: await probeMedia(f), part: null);
  final pieces = <JoinPiece>[
    if (intro != null) await clip(intro),
    for (final s in parts) (path: video.path, info: main, part: s),
    if (outro != null) await clip(outro),
  ];
  await _ffmpeg(
    joinArgs(pieces, main, out),
    duration: pieces.fold<double>(
      0,
      (a, pc) =>
          a +
          (pc.part == null ? pc.info.duration : pc.part!.end - pc.part!.start),
    ),
    onProgress: onProgress,
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

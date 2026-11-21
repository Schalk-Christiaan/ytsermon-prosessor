// @stelsel cutter
//   soort: module
//   wanneer: by 'Keur goed en sny' en 'Klank vir WhatsApp'
//   groep: core | Kern
//   skryf: out/<jaar>/<diens>/ | Volle preek.mp4, Net die woord.mp4, Sang/*.mp3, Shorts
//   doel: gids per diens (serviceDir), sny Volle preek en Net die woord (herkodeer net die stuk, of segmente plus intro/outro saamgevoeg), Shorts (9:16 met ingebrande onderskrif), elke lied as mp3 en WhatsApp-klank (mono mp3 64 kbps) met ffmpeg; skryf die WhatsApp-teks
//   status: klaar
//   bewys: 7236634
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'captions.dart';
import 'models.dart';
import 'service_info.dart';
import 'tools.dart';

/// ffmpeg flags that make progress readable on stdout (see `parseFfmpegProgress`).
const _progress = ['-nostats', '-progress', 'pipe:1'];

/// The video encoder settings of the sermon cut and the join.
const _x264 = ['-c:v', 'libx264', '-preset', 'veryfast', '-crf', '20'];

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
  ..._x264,
  '-pix_fmt',
  'yuv420p',
  '-c:a',
  'aac',
  '-movflags',
  '+faststart',
  ..._progress,
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
  ..._progress,
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
  ..._progress,
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
    ..._x264,
    '-c:a',
    'aac',
    '-b:a',
    '160k',
    '-movflags',
    '+faststart',
    ..._progress,
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

// stap: preekgrense 2 Herkodeer | libx264 presies op die grense (nie -c copy nie, wat net op 'n sleutelraam sny)
/// Cuts [parts] of [video] into [out] (its folder is made); returns it. One part and no clips = one re-encode
/// of just that part; several parts or an [intro]/[outro] re-encode everything into one file via [joinArgs].
Future<File> cutParts(
  File video,
  List<Span> parts,
  File out, {
  File? intro,
  File? outro,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  out.parent.createSync(recursive: true);
  if (parts.length == 1 && intro == null && outro == null) {
    await _ffmpeg(
      sermonArgs(video.path, parts.single.start, parts.single.end, out.path),
      duration: parts.single.end - parts.single.start,
      onProgress: onProgress,
      cancel: cancel,
      log: log,
    );
    return out;
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
    joinArgs(pieces, main, out.path),
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
  return out;
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

/// Exports [video] (a cut mp4) as the mono mp3 [out] with [title] in the ID3 tag, for WhatsApp.
Future<File> cutAudio(
  File video,
  String title,
  File out, {
  double? duration,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  out.parent.createSync(recursive: true);
  await _ffmpeg(
    audioArgs(video.path, out.path, title),
    duration: duration,
    onProgress: onProgress,
    cancel: cancel,
    log: log,
  );
  return out;
}

// stap: diensindeling 9 Uitvoere | `<uitgids>/<jaar>/<datum> <Oggend|Aand> - <tema>/` kry Volle preek.mp4, Net die woord.mp4, Sang/NN <lied>.mp3, WhatsApp.txt en diens.json
/// The folder of one service: `<outDir>/<year>/<date> <Oggend|Aand> - <theme>` (no theme: no ` - …`).
String serviceDir(String outDir, ServiceInfo info) => p.join(
  outDir,
  info.date.substring(0, 4),
  '${info.date} ${info.evening ? 'Aand' : 'Oggend'}'
  '${info.theme == null || _clean(info.theme!).isEmpty ? '' : ' - ${_clean(info.theme!)}'}',
);

/// File names inside a [serviceDir] (without extension).
const kFullName = 'Volle preek', kWordName = 'Net die woord';

/// The text and the data file written beside the outputs of a service.
const kWhatsappFile = 'WhatsApp.txt', kIndexFile = 'diens.json';

/// ffmpeg arguments for one song: the part [s] of [video] as a stereo 128 kbps mp3 with ID3 title, album and track.
List<String> songArgs(
  String video,
  Span s,
  String out, {
  required String title,
  required String album,
  required int track,
}) => [
  '-y',
  '-ss',
  _sec(s.start),
  '-to',
  _sec(s.end),
  '-i',
  video,
  '-vn',
  '-c:a',
  'libmp3lame',
  '-b:a',
  '128k',
  '-id3v2_version',
  '3',
  '-metadata',
  'title=$title',
  '-metadata',
  'album=$album',
  '-metadata',
  'track=$track',
  ..._progress,
  out,
];

/// Cuts [song] into `<dir>/Sang/NN <name>.mp3` (unnamed: `Lied N`); returns the file.
Future<File> cutSong(
  File video,
  Song song,
  ServiceInfo info,
  Directory dir, {
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  final name = song.name ?? 'Lied ${song.n}';
  final out = File(
    p.join(
      dir.path,
      'Sang',
      '${song.n.toString().padLeft(2, '0')} ${_clean(name)}.mp3',
    ),
  )..parent.createSync(recursive: true);
  await _ffmpeg(
    songArgs(
      video.path,
      Span(song.start, song.end),
      out.path,
      title: name,
      album: '$kChurch ${info.date} ${_dienst(info)}',
      track: song.n,
    ),
    cancel: cancel,
    log: log,
  );
  return out;
}

/// The church in the mp3 album tag; output text (like the upload template), not UI, so not in the ARB.
const kChurch = 'GK Oranjerivier';

String _dienst(ServiceInfo i) => i.evening ? 'Aanddiens' : 'Oggenddiens';

/// The default WhatsApp text; `{diens}`, `{datum}`, `{tema}`, `{skriflesing}`, `{fokus}`, `{belydenis}`.
const kWhatsappTemplate =
    '*{diens} · {datum}*\nTema: {tema}\nSkriflesing: {skriflesing}\n'
    'Fokus: {fokus}\n{belydenis}';

const _days = [
  'Maandag',
  'Dinsdag',
  'Woensdag',
  'Donderdag',
  'Vrydag',
  'Saterdag',
  'Sondag',
];
const _months = [
  'Januarie',
  'Februarie',
  'Maart',
  'April',
  'Mei',
  'Junie',
  'Julie',
  'Augustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

/// `2026-11-15` as `Sondag 15 November 2026`.
String longDate(String iso) {
  final d = DateTime.parse(iso);
  return '${_days[d.weekday - 1]} ${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// [template] with the service's facts filled in; a line whose placeholder is empty is left out.
String whatsappText(String template, ServiceInfo info) {
  final v = {
    'diens': _dienst(info),
    'datum': longDate(info.date),
    'tema': info.theme ?? '',
    'skriflesing': info.scripture ?? '',
    'fokus': info.focus ?? '',
    'belydenis': info.creed ?? '',
  };
  final ph = RegExp(r'\{(\w+)\}');
  return [
    for (final line in template.split('\n'))
      if (ph.allMatches(line).every((m) => (v[m.group(1)] ?? '').isNotEmpty))
        line.replaceAllMapped(ph, (m) => v[m.group(1)]!),
  ].join('\n');
}

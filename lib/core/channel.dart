// @stelsel channel
//   soort: module
//   wanneer: as 'n preek-URL gelaai word
//   groep: core | Kern
//   skryf: werkmap/<id>/ (info.json, onderskrifte, video.mp4)
//   doel: lys die kanaal (flat), video-ID uit URL, haal metadata + af-orig-onderskrifte, laai die video een keer af
//   status: oop
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tools.dart';

/// The church channel (see CONTEXT.md, Name).
const kChannelUrl = 'https://www.youtube.com/@gereformeerdekerkoranjeriv5791';

/// One channel entry from the flat list. The flat list carries no upload date, so none here:
/// the date is filled in later by `fetchMeta` (lazy, per sermon).
class ChannelItem {
  const ChannelItem(this.id, this.title, this.duration);
  final String id;
  final String title;
  final double duration;
}

/// Merges yt-dlp flat playlists (`-J` output) on video ID, keeping list order (newest first).
List<ChannelItem> parseChannel(Iterable<dynamic> playlists) {
  final seen = <String>{};
  return [
    for (final pl in playlists)
      for (final e in (pl['entries'] as List? ?? const []))
        if (e is Map && e['id'] is String && seen.add(e['id'] as String))
          ChannelItem(
            e['id'] as String,
            '${e['title'] ?? ''}',
            (e['duration'] as num?)?.toDouble() ?? 0,
          ),
  ];
}

/// Lists the whole channel (`/streams` then `/videos`) with one yt-dlp call per tab.
Future<List<ChannelItem>> listChannel() async {
  final tabs = <dynamic>[];
  for (final tab in ['streams', 'videos']) {
    final out = StringBuffer();
    await runTool('yt-dlp', [
      '--flat-playlist',
      '-J',
      '$kChannelUrl/$tab',
    ], onLine: out.write);
    tabs.add(jsonDecode(out.toString()));
  }
  return parseChannel(tabs);
}

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

List<String> _ffmpegArgs() {
  final f = findExecutable('ffmpeg');
  return f == null ? [] : ['--ffmpeg-location', f];
}

/// Downloads info.json and the af-orig json3 captions to `<root>/<id>/`; skips what already exists.
Future<FetchedMeta> fetchMeta(
  String url,
  Directory root, {
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  // A local recording (`opname-…`) already has its files from importRecording.
  final id = url.startsWith('opname-') ? url : videoIdFromUrl(url);
  if (id == null) throw ArgumentError('Geen YouTube-skakel nie: $url');
  final dir = Directory(p.join(root.path, id))..createSync(recursive: true);
  final infoFile = File(p.join(dir.path, '$id.info.json'));
  final meta = FetchedMeta(id, dir, {});
  if (!infoFile.existsSync() || !meta.captions.existsSync()) {
    await runTool(
      'yt-dlp',
      [
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
      ],
      cancel: cancel,
      onLine: log,
    );
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
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  if (meta.video.existsSync()) {
    onProgress?.call(100);
    return meta.video;
  }
  await runTool(
    'yt-dlp',
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
      log?.call(l);
      final v = parseProgress(l);
      if (v != null) onProgress?.call(v);
    },
    cancel: cancel,
  );
  return meta.video;
}

/// Facts from yt-dlp's info.json that the app needs.
extension InfoFields on Map<String, dynamic> {
  double get durationSeconds => (this['duration'] as num).toDouble();
  String get titleText => '${this['title'] ?? ''}';
  String get descriptionText => '${this['description'] ?? ''}';

  /// Upload date as `JJJJ-MM-DD`.
  String get uploadDate {
    final u = '${this['upload_date'] ?? '00000000'}';
    return '${u.substring(0, 4)}-${u.substring(4, 6)}-${u.substring(6, 8)}';
  }
}

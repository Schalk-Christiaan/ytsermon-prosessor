// @stelsel channel
//   soort: module
//   wanneer: as 'n preek-URL gelaai word
//   groep: core | Kern
//   skryf: werkmap/<id>/ (info.json, onderskrifte, video.mp4)
//   doel: lys die kanaal (flat; URL uit instellings, normaliseer), video-ID uit URL, haal metadata + af-orig-onderskrifte, laai die video een keer af
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'service_info.dart';
import 'storage.dart' show formatBytes;
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

/// One canonical channel URL (`https://www.youtube.com/@name`, `/channel/UC…` or `/c/name`) from what a
/// person types or pastes (`@name`, `youtube.com/@name/videos`, a full link …); null when it is none of those.
String? normalizeChannelUrl(String input) {
  final m = RegExp(
    r'^(?:(?:https?://)?(?:www\.|m\.)?youtube\.com)?/?(@[^\s/?#]+|channel/UC[\w-]{22}|c/[^\s/?#]+)(?:[/?#].*)?$',
    caseSensitive: false,
  ).firstMatch(input.trim());
  return m == null ? null : 'https://www.youtube.com/${m.group(1)}';
}

/// The name of the channel at [url] (one yt-dlp call for its newest video); throws [ProcessException]
/// when there is no such channel.
Future<String> channelName(String url) async {
  final out = StringBuffer();
  await runTool('yt-dlp', [
    '--flat-playlist',
    '-I',
    '1',
    '-J',
    '$url/videos',
  ], onLine: out.write);
  final j = jsonDecode(out.toString()) as Map<String, dynamic>;
  return '${j['channel'] ?? j['uploader'] ?? j['title']}';
}

/// Lists the whole channel at [url] (`/streams` then `/videos`) with one yt-dlp call per tab.
Future<List<ChannelItem>> listChannel([String url = kChannelUrl]) async {
  final tabs = <dynamic>[];
  for (final tab in ['streams', 'videos']) {
    final out = StringBuffer();
    await runTool('yt-dlp', [
      '--flat-playlist',
      '-J',
      '$url/$tab',
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

/// Plain-words progress from a yt-dlp download line ("42 % van 1,2 GB · 5,5 MB/s · nog 01:02"); null for other lines. "Unknown" and "~" are handled.
String? downloadDetail(String line) {
  final m = RegExp(
    r'^\[download\]\s+(\d+(?:\.\d+)?)% of\s+~?\s*([\d.]+)(Ki|Mi|Gi)B(?:\s+at\s+(?:([\d.]+)(Ki|Mi|Gi)B/s|Unknown B/s)\s+ETA\s+(\S+))?',
  ).firstMatch(line);
  if (m == null) return null;
  int bytes(String n, String u) =>
      (double.parse(n) *
              const {'Ki': 1024, 'Mi': 1048576, 'Gi': 1073741824}[u]!)
          .round();
  final parts = [
    '${double.parse(m[1]!).round()} % van ${formatBytes(bytes(m[2]!, m[3]!))}',
  ];
  if (m[4] != null) parts.add('${formatBytes(bytes(m[4]!, m[5]!))}/s');
  if (m[6] != null && m[6] != 'Unknown') parts.add('nog ${m[6]}');
  return parts.join(' \u00b7 ');
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

// stap: v5 2 Aflaai hervat | yt-dlp gaan voort met die halwe .part-lêer; 'n klaar video word oorgeslaan
/// Downloads the full video (<=1080p, mp4) to `<dir>/video.mp4`; reports 0..100 via [onProgress]. Skips if present.
/// Full download: `--download-sections` is currently broken.
Future<File> downloadVideo(
  FetchedMeta meta, {
  void Function(double pct)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
  void Function(String text)? onDetail,
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
      final d = downloadDetail(l);
      if (d != null) onDetail?.call(d);
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

  /// The service day as `JJJJ-MM-DD` (local time of the stream start; `upload_date` is a day late).
  String get uploadDate => ServiceInfo.fromInfo(this).date;
}

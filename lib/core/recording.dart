// @stelsel recording
//   soort: module
//   wanneer: by "Voer opname in" (knoppie of insleep op Preke)
//   groep: core | Kern
//   skryf: werkmap/opname-…/ (video.mp4, info.json, leë onderskrifte, plan.json, sermon.json)
//   doel: 'n eie video-opname (nie op YouTube nie) word 'n preek met 'n plaaslike ID en 'n handmatige plan, sodat Hersien en sny dit soos enige ander preek hanteer
//   status: klaar
//   bewys: 7236634
import 'dart:io';

import 'package:path/path.dart' as p;

import 'channel.dart';
import 'cutter.dart';
import 'models.dart';
import 'planner.dart';
import 'store.dart';

const kRecordingPrefix = 'opname-';

/// Whether [id] is a local recording rather than a YouTube video.
bool isRecording(String id) => id.startsWith(kRecordingPrefix);

// stap: v3 2 Kopieer en beplan | video.mp4, info.json, leë onderskrifte en 'n plan oor die hele lêer
/// Copies [src] into `<root>/opname-JJJJMMDD-HHMMSS/` with empty captions and a whole-file plan; returns the `beplan` sermon.
/// Copied, not referenced, so a removed USB stick does not break the work.
Future<Sermon> importRecording(
  File src,
  String title,
  DateTime date,
  SermonStore store, {
  DateTime? now,
}) async {
  String two(int n) => n.toString().padLeft(2, '0');
  String ymd(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';
  final t = now ?? DateTime.now();
  final id =
      '$kRecordingPrefix${ymd(t)}-${two(t.hour)}${two(t.minute)}${two(t.second)}';
  final dir = Directory(p.join(store.root.path, id))
    ..createSync(recursive: true);
  final meta = FetchedMeta(id, dir, {});
  // ponytail: any container is copied as video.mp4; ffmpeg probes by content. Re-mux if a codec ever refuses mp4.
  await src.copy(meta.video.path);
  final duration = (await probeMedia(meta.video)).duration;
  writeJson(File(p.join(dir.path, '$id.info.json')), {
    'id': id,
    'title': title,
    'duration': duration,
    'upload_date': ymd(date),
    'description': '',
  });
  meta.captions.writeAsStringSync('{"events":[]}');
  savePlan(
    dir,
    SermonPlan(
      sermonStart: 0,
      sermonEnd: duration,
      title: title,
      description: '',
      shorts: [],
    ),
  );
  final s = Sermon(
    id,
    title,
    duration,
    date: '${date.year}-${two(date.month)}-${two(date.day)}',
    state: SermonState.beplan,
    order: -t.millisecondsSinceEpoch ~/ 1000,
  );
  store.save(s);
  return s;
}

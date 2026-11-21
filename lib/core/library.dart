// @stelsel library
//   soort: module
//   wanneer: as die Biblioteek-skerm oopmaak of herlaai
//   groep: core | Kern
//   skryf: —
//   doel: lees elke <uitvoer>/<jaar>/<diens>/diens.json in een lys diens (nuutste eerste) met hul liedere; die blaaier soek daarin
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cutter.dart' show kFullName, whatsappText;
import 'service_info.dart';

/// One song file of a service.
class LibrarySong {
  const LibrarySong(this.n, this.name, this.file);
  final int n;
  final String? name;

  /// Absolute path of the mp3, null when the songs were not exported.
  final String? file;
}

/// One service folder as `diens.json` describes it.
class LibraryService {
  LibraryService(this.dir, this.info, this.title, this.files, this.songs);
  final Directory dir;
  final ServiceInfo info;
  final String? title;

  /// Absolute paths of the videos in the folder.
  final List<String> files;
  final List<LibrarySong> songs;

  /// What "Speel" opens: the full sermon, else the first video.
  String? get video =>
      files.where((f) => p.basename(f) == '$kFullName.mp4').firstOrNull ??
      files.firstOrNull;

  /// The `WhatsApp.txt` of the folder.
  File get whatsappFile => File(p.join(dir.path, 'WhatsApp.txt'));

  /// Whether [q] (lower case, trimmed) is in the theme, scripture, focus or a song name.
  bool matches(String q) =>
      q.isEmpty ||
      [
        info.theme,
        title,
        info.scripture,
        info.focus,
        for (final s in songs) s.name,
      ].any((t) => t != null && t.toLowerCase().contains(q));
}

/// Reads every `<[outDir]>/<year>/<service>/diens.json`, newest date first, Oggend after Aand on one day;
/// a folder whose file is broken is skipped. Loaded once per call: no watcher.
List<LibraryService> loadLibrary(String outDir) {
  final root = Directory(outDir);
  if (!root.existsSync()) return [];
  final all = <LibraryService>[];
  for (final f in root.listSync(recursive: true).whereType<File>()) {
    if (p.basename(f.path) != 'diens.json') continue;
    try {
      final j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
      final dir = f.parent;
      all.add(
        LibraryService(
          dir,
          ServiceInfo.fromJson(j['info'] as Map<String, dynamic>),
          j['title'] as String?,
          [
            for (final n in (j['files'] as List? ?? const []))
              if ('$n'.endsWith('.mp4')) p.join(dir.path, '$n'),
          ],
          [
            for (final s in (j['songs'] as List? ?? const []))
              LibrarySong(
                (s as Map)['n'] as int,
                s['name'] as String?,
                s['file'] == null
                    ? null
                    : p.join(dir.path, s['file'] as String),
              ),
          ],
        ),
      );
    } on Object {
      continue;
    }
  }
  all.sort((a, b) {
    final d = b.info.date.compareTo(a.info.date);
    return d != 0 ? d : (b.info.evening ? 1 : 0) - (a.info.evening ? 1 : 0);
  });
  return all;
}

/// The WhatsApp text of [s]: its `WhatsApp.txt`, else made from [template].
String libraryWhatsapp(LibraryService s, String template) =>
    s.whatsappFile.existsSync()
    ? s.whatsappFile.readAsStringSync()
    : whatsappText(template, s.info);

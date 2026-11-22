// @stelsel storage
//   soort: module
//   wanneer: by laai en ná 'n taak
//   groep: core | Kern
//   skryf: —
//   doel: lêergroottes (som van 'n gids), SA-formaat "1,42 GB", en vrye skyfspasie (df / fsutil)
//   status: bou
import 'dart:io';

import 'package:path/path.dart' as p;

/// Total size in bytes of every file under [d]; 0 when the folder is missing.
Future<int> dirSize(Directory d) async {
  if (!await d.exists()) return 0;
  var n = 0;
  await for (final e in d.list(recursive: true, followLinks: false)) {
    if (e is File) n += await e.length();
  }
  return n;
}

/// Size of each sermon's work folder (`<root>/<id>`: source, output, Shorts, audio); missing = 0.
Future<Map<String, int>> sermonSizes(
  Directory root,
  Iterable<String> ids,
) async => {
  for (final id in ids) id: await dirSize(Directory(p.join(root.path, id))),
};

/// "1,42 GB", "86 MB", "12 KB": decimal comma and a no-break space (South African style).
String formatBytes(int b) {
  const nbsp = ' ';
  String f(double v, int dec, String u) =>
      '${v.toStringAsFixed(dec).replaceAll('.', ',')}$nbsp$u';
  if (b >= 1e9) return f(b / 1e9, b >= 1e11 ? 0 : (b >= 1e10 ? 1 : 2), 'GB');
  if (b >= 1e6) return f(b / 1e6, 0, 'MB');
  if (b >= 1e3) return f(b / 1e3, 0, 'KB');
  return '$b${nbsp}B';
}

/// Free bytes on the volume holding [d], or null when it cannot be read (the status bar then omits it).
/// One call on request (never polled); an argument list, no shell.
Future<int?> freeBytes(Directory d) async {
  try {
    if (Platform.isWindows) {
      final r = await Process.run('fsutil', [
        'volume',
        'diskfree',
        p.rootPrefix(p.absolute(d.path)),
      ]);
      // First line is the total free bytes; fsutil prints "name : 123456 (1.2 GB)".
      final m = RegExp(
        r':\s*([\d.,\s]+?)\s*(\(|$)',
        multiLine: true,
      ).firstMatch(r.stdout as String);
      return m == null
          ? null
          : int.tryParse(m[1]!.replaceAll(RegExp(r'\D'), ''));
    }
    final r = await Process.run('df', ['-Pk', d.path]);
    final cols = (r.stdout as String)
        .trim()
        .split('\n')
        .last
        .split(RegExp(r'\s+'));
    final kb = int.tryParse(cols[3]);
    return kb == null ? null : kb * 1024;
  } catch (_) {
    return null;
  }
}

/// Bytes used by the work folder and bytes free on its volume, for the status bar.
Future<(int, int?)> readStorage(Directory work) async =>
    (await dirSize(work), await freeBytes(work));

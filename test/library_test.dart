import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/library.dart';

void service(Directory out, String year, String name, Map<String, dynamic> j) {
  final d = Directory(p.join(out.path, year, name))
    ..createSync(recursive: true);
  File(p.join(d.path, 'diens.json')).writeAsStringSync(jsonEncode(j));
}

Directory twoServices() {
  final out = Directory.systemTemp.createTempSync('lib');
  service(out, '2026', '2026-11-08 Oggend - Genade', {
    'info': {'date': '2026-11-08', 'theme': 'Genade', 'psalms': <int>[]},
    'title': 'Genade',
    'files': ['Volle preek.mp4'],
    'songs': <Map<String, dynamic>>[],
  });
  service(out, '2026', '2026-11-15 Oggend - Uit die oorvloed', {
    'info': {
      'date': '2026-11-15',
      'theme': 'Uit die oorvloed van die hart',
      'scripture': 'Lukas 6:43-45',
      'psalms': [33, 42],
    },
    'title': 'Uit die oorvloed van die hart praat die mond',
    'files': ['Volle preek.mp4', 'Net die woord.mp4'],
    'songs': [
      {'n': 1, 'name': 'Psalm 33', 'file': 'Sang/01 Psalm 33.mp3'},
      {'n': 2, 'name': 'Psalm 42', 'file': 'Sang/02 Psalm 42.mp3'},
    ],
  });
  return out;
}

void main() {
  test('loads both services, newest first, with their songs and files', () {
    final out = twoServices();
    addTearDown(() => out.deleteSync(recursive: true));
    final all = loadLibrary(out.path);
    expect(all.map((s) => s.info.date), ['2026-11-15', '2026-11-08']);
    expect(all.first.songs.map((s) => s.name), ['Psalm 33', 'Psalm 42']);
    expect(
      all.first.songs.first.file,
      p.join(all.first.dir.path, 'Sang', '01 Psalm 33.mp3'),
    );
    expect(p.basename(all.first.video!), 'Volle preek.mp4');
  });

  test('search covers theme, scripture and song name', () {
    final out = twoServices();
    addTearDown(() => out.deleteSync(recursive: true));
    final all = loadLibrary(out.path);
    List<String> hits(String q) => [
      for (final s in all)
        if (s.matches(q)) s.info.date,
    ];
    expect(hits('psalm 42'), ['2026-11-15']);
    expect(hits('lukas'), ['2026-11-15']);
    expect(hits('genade'), ['2026-11-08']);
    expect(hits(''), hasLength(2));
  });

  test('a missing folder and a broken diens.json give no crash', () {
    expect(loadLibrary('/nonexistent-folder-x'), isEmpty);
    final out = Directory.systemTemp.createTempSync('lib');
    addTearDown(() => out.deleteSync(recursive: true));
    service(out, '2026', 'x', {});
    expect(loadLibrary(out.path), isEmpty);
  });
}

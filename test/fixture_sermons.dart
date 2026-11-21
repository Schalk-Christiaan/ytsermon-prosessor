// Caption fixtures for the sermon-bounds tests: `test/fixtures/<id>.af-orig.json3.gz`.
// Re-fetch: yt-dlp --skip-download --write-auto-subs --sub-langs af-orig --sub-format json3 -o '%(id)s' https://youtu.be/<id>
// then `gzip -9 <id>.af-orig.json3`. `sermons.json` holds duration and description from info.json plus the
// prayer-to-prayer bounds (seconds) read by hand from the captions.
import 'dart:convert';
import 'dart:io';

import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/sound.dart';

typedef FixtureSermon = ({
  String id,
  double duration,
  String description,
  double start,
  double end,
  List<Segment> segs,
});

List<FixtureSermon> fixtureSermons() => [
  for (final j in jsonDecode(
    File('test/fixtures/sermons.json').readAsStringSync(),
  ) as List)
    (
      id: j['id'] as String,
      duration: (j['duration'] as num).toDouble(),
      description: j['description'] as String,
      start: (j['start'] as num).toDouble(),
      end: (j['end'] as num).toDouble(),
      segs: parseJson3(
        utf8.decode(
          gzip.decode(
            File('test/fixtures/${j['id']}.af-orig.json3.gz').readAsBytesSync(),
          ),
        ),
      ),
    ),
];

/// The saved per-second sound features of video [id] (`test/fixtures/sound/<id>.json.gz`).
SoundFeatures fixtureSoundFeatures(String id) {
  final j = jsonDecode(
    utf8.decode(
      gzip.decode(File('test/fixtures/sound/$id.json.gz').readAsBytesSync()),
    ),
  ) as Map<String, dynamic>;
  List<double> f(String k) => [
    for (final v in j[k] as List) (v as num).toDouble(),
  ];
  return SoundFeatures(f('db'), f('lef'), f('flat'));
}

/// The classified sound blocks of video [id].
List<TimeBlock> fixtureSound(String id) => classify(fixtureSoundFeatures(id));

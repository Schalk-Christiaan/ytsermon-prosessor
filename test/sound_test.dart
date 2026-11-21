import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/sound.dart';

import 'fixture_sermons.dart';

/// Expected music stretches per service from navorsing/spektrogram-prototipe/segmente.txt.
Map<String, List<(int, int)>> _expected() {
  final ids = {
    'yw': 'YWz5gf0onjk',
    '6s_FFatG0so': '6s_FFatG0so',
    'lBMwRt3eIus': 'lBMwRt3eIus',
    'uub_CnO7bd0': 'uub_CnO7bd0',
  };
  final out = <String, List<(int, int)>>{};
  List<(int, int)>? cur;
  int sec(String s) {
    final m = s.trim().split(':');
    return int.parse(m[0].trim()) * 60 + int.parse(m[1]);
  }

  for (final l in File(
    'navorsing/spektrogram-prototipe/segmente.txt',
  ).readAsLinesSync()) {
    if (l.startsWith('== ')) {
      cur = out[ids[l.substring(3).trim()]!] = [];
    } else if (l.contains(RegExp(r'\s+musiek\s'))) {
      final m = RegExp(r'^\s*(\d+:\d+)-\s*(\d+:\d+)').firstMatch(l)!;
      cur!.add((sec(m[1]!), sec(m[2]!)));
    }
  }
  return out;
}

void main() {
  test('sound.json round trip: loadSound reads what saveSound wrote', () {
    final d = Directory.systemTemp.createTempSync('snd');
    addTearDown(() => d.deleteSync(recursive: true));
    expect(loadSound(d), isEmpty);
    final b = classify(fixtureSoundFeatures('YWz5gf0onjk'));
    saveSound(d, b);
    final r = loadSound(d);
    expect(r.length, b.length);
    expect(
      r.map((x) => (x.start, x.end, x.kind)),
      b.map((x) => (x.start, x.end, x.kind)),
    );
  });

  test('YWz5gf0onjk music at 11:40-14:44, 22:10-23:30, 56:34-60:52', () {
    final music = [
      for (final b in classify(fixtureSoundFeatures('YWz5gf0onjk')))
        if (b.kind == SegmentKind.music) (b.start, b.end),
    ];
    for (final w in [(700, 884), (1330, 1410), (3394, 3652)]) {
      expect(
        music.any((m) => (m.$1 - w.$1).abs() <= 2 && (m.$2 - w.$2).abs() <= 2),
        isTrue,
        reason: '$w in $music',
      );
    }
  });

  test('soundArgs asks for 16 kHz mono PCM on stdout', () {
    final a = soundArgs('v.mp4');
    expect(a, containsAllInOrder(['-i', 'v.mp4', '-ac', '1', '-ar', '16000']));
    expect(a.last, '-');
  });

  test(
    'soundFeatures: silence is quiet, a tone is flat-free music-like',
    () async {
      // 3 s silence then 3 s of a pure tone, as s16le.
      final pcm = <int>[];
      for (var i = 0; i < 16000 * 6; i++) {
        final v = i < 16000 * 3
            ? 0
            : (8000 * _sin(i * 440 * 2 * 3.14159265 / 16000)).round();
        pcm.addAll([v & 0xff, (v >> 8) & 0xff]);
      }
      final f = await soundFeatures(Stream.value(pcm));
      expect(f.db.length, 5);
      expect(f.db[0], lessThan(-60));
      expect(f.db[4], greaterThan(-30));
      expect(f.flat[4], lessThan(0.06));
    },
  );

  test('classify: label runs, short runs merge into the previous one', () {
    // 60 s silent (db -90), 30 s music (flat .02, lef 0), 5 s speech blip, 30 s music.
    List<double> rep(double v, int n) => List.filled(n, v);
    final f = SoundFeatures(
      [...rep(-90, 60), ...rep(-30, 65)],
      [...rep(0, 60), ...rep(0, 30), ...rep(0.4, 5), ...rep(0, 30)],
      [...rep(0, 60), ...rep(0.02, 30), ...rep(0.2, 5), ...rep(0.02, 30)],
    );
    final b = classify(f);
    expect(
      [for (final x in b) x.kind],
      [SegmentKind.silence, SegmentKind.music],
    );
    expect(b.last.end, 125);
  });

  for (final e in _expected().entries) {
    test('classify ${e.key}: every music stretch within 2 s', () {
      final music = [
        for (final b in classify(fixtureSoundFeatures(e.key)))
          if (b.kind == SegmentKind.music) (b.start.round(), b.end.round()),
      ];
      expect(music.length, e.value.length, reason: '$music');
      for (var i = 0; i < music.length; i++) {
        expect((music[i].$1 - e.value[i].$1).abs(), lessThanOrEqualTo(2));
        expect((music[i].$2 - e.value[i].$2).abs(), lessThanOrEqualTo(2));
      }
    });
  }
}

double _sin(double x) => math.sin(x);

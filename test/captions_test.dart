import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

void main() {
  test(
    'YWz5gf0onjk: Vader in the prayer gets its own time inside the line',
    () {
      final segs = fixtureSermons().first.segs;
      final line = segs.firstWhere((s) => (s.start - 886.6).abs() < 0.1);
      final v = line.words.firstWhere((w) => w.text == 'Vader');
      expect(v.start, closeTo(886.9, 0.01));
      expect(line.words.first.text, 'Onse');
    },
  );

  test('words get their own time from tOffsetMs; a word ends where the next starts', () {
    const j =
        '{"events":[{"tStartMs":1000,"dDurationMs":3000,"segs":[{"utf8":">> Onse"},'
        '{"utf8":" Vader","tOffsetMs":300},{"utf8":" Amen.","tOffsetMs":900}]}]}';
    final w = parseJson3(j).single.words;
    expect(w.map((x) => x.text), ['Onse', 'Vader', 'Amen.']);
    expect(w.map((x) => x.start), [1.0, 1.3, 1.9]);
    expect(w.map((x) => x.end), [1.3, 1.9, 4.0]);
  });

  test(
    'a line without word times spreads its words by length over the line',
    () {
      final w = parseJson3(
        '{"events":[{"tStartMs":0,"dDurationMs":4000,"segs":[{"utf8":"aa bbbbbb"}]}]}',
      ).single.words;
      expect(w.map((x) => x.text), ['aa', 'bbbbbb']);
      expect(w[1].start, closeTo(1.0, 1e-9));
      expect(w[1].end, 4.0);
    },
  );

  final raw = File('test/fixtures/sample.af-orig.json3').readAsStringSync();
  final segs = parseJson3(raw);

  test('parseJson3 skips newline events and classifies music', () {
    expect(segs.where((s) => s.text.isEmpty), isEmpty);
    expect(segs.first.kind, SegmentKind.music);
    expect(segs.first.start, closeTo(58.295, 1e-6));
    final speech = segs.firstWhere((s) => s.kind == SegmentKind.speech);
    expect(speech.text, 'dis by hierdie erediens inskakel');
    expect(speech.end, lessThanOrEqualTo(526.6));
  });

  test('music markers: [Musiek], [sang], combined', () {
    final j =
        '{"events":[{"tStartMs":0,"dDurationMs":1000,"segs":[{"utf8":"[Musiek]"}]},'
        '{"tStartMs":2000,"dDurationMs":1000,"segs":[{"utf8":"[sang][musiek]"}]},'
        '{"tStartMs":4000,"dDurationMs":1000,"segs":[{"utf8":"hallo"}]}]}';
    final s = parseJson3(j);
    expect(s.map((e) => e.kind), [
      SegmentKind.music,
      SegmentKind.music,
      SegmentKind.speech,
    ]);
  });

  test('compact groups per ~30 s as [mm:ss] text', () {
    final c = compact(segs);
    final lines = c.split('\n');
    expect(lines.first, startsWith('[00:58] '));
    expect(
      lines.any(
        (l) =>
            l.startsWith('[08:44] ') && l.contains('dis by hierdie erediens'),
      ),
      isTrue,
    );
    expect(c, isNot(contains('\n\n')));
  });

  test('toSrt: relative times, <=42 chars, <=2 lines per block', () {
    final srt = toSrt(segs, 524.0, 545.0);
    expect(srt, startsWith('1\n00:00:00,2'));
    for (final block in srt.trim().split('\n\n')) {
      final l = block.split('\n');
      expect(l.length, inInclusiveRange(3, 4));
      for (final t in l.skip(2)) {
        expect(t.length, lessThanOrEqualTo(42));
      }
    }
    expect(srt, contains('dis by hierdie erediens inskakel'));
  });

  test('real video token estimate (if cached)', () {
    final f = File(
      '/tmp/claude-1000/live/work/YWz5gf0onjk/YWz5gf0onjk.af-orig.json3',
    );
    if (!f.existsSync()) return;
    final c = compact(parseJson3(f.readAsStringSync()));
    final words = c.split(RegExp(r'\s+')).length;
    // ignore: avoid_print
    print('words=$words tokens~${(words * 1.4).round()}');
    expect(words * 1.4, lessThan(12000));
  });
}

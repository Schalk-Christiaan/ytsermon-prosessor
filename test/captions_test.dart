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

  test('parseJson3 skips newline events and sound-tag lines', () {
    expect(segs.where((s) => s.text.isEmpty), isEmpty);
    expect(segs.where((s) => s.text.startsWith('[')), isEmpty);
    expect(segs.first.start, greaterThan(58.3));
    final speech = segs.firstWhere((s) => s.text.contains('dis by hierdie'));
    expect(speech.text, 'dis by hierdie erediens inskakel');
    expect(speech.end, lessThanOrEqualTo(526.6));
  });

  test('compact groups the block words per ~30 s as [mm:ss] text', () {
    final bl = [
      Block([
        const Word(65, 66, 'a'),
        const Word(66, 67, 'b'),
        const Word(100, 101, 'c'),
      ], 101),
    ];
    expect(compact(bl, 0, 1000), '[01:05] a b\n[01:40] c');
    expect(compact(bl, 66, 100), '[01:06] b');
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

  test('parseClock reads what a time field shows and what people type', () {
    expect(parseClock('23:04'), 1384);
    expect(parseClock(' 1:02:03 '), 3723);
    expect(parseClock('23:04.5'), 1384.5);
    expect(parseClock('23:04,5'), 1384.5);
    expect(parseClock('90'), 90);
    for (final bad in ['', 'abc', '1:2:3:4', '-5', '12:xx']) {
      expect(parseClock(bad), isNull, reason: bad);
    }
    expect(parseClock(formatTime(1384)), 1384);
  });

  test('formatTime with hours is the sermon length format', () {
    expect(formatTime(1384.4, hours: true), '23:04');
    expect(formatTime(3725, hours: true), '1:02:05');
    expect(formatTime(3725), '62:05');
  });
}

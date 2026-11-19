import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

void main() {
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

  test('timeline merges into speech/music blocks', () {
    final t = timeline(segs);
    expect(t.first.kind, SegmentKind.music);
    expect(t.first.start, closeTo(58.295, 1e-6));
    expect(t.first.end, greaterThan(77));
    expect(t.last.kind, SegmentKind.speech);
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

// Step 14: the Klank waveform is not rebuilt per paint; the painter repaints only on real change.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/features/review/service_timeline.dart';

void main() {
  final levels = [for (var i = 0; i < 600; i++) -30.0 - i % 20];
  final blocks = [const TimeBlock(0, 300, SegmentKind.speech)];
  final shorts = [Short(start: 10, end: 40, title: 's')];
  const c = Colors.red;
  List<(double, Color)> bars() =>
      waveBars(levels, blocks, 600, 400, c, c, Colors.black);
  final b = bars();
  TracksPainter make({List<(double, Color)>? bars, double end = 500}) =>
      TracksPainter(
        duration: 600,
        blocks: blocks,
        levels: levels,
        bars: bars ?? b,
        shorts: shorts,
        cuts: [Span(100, 110)],
        prayers: const [],
        songs: const [],
        faulty: const {},
        cutLabel: 'x',
        musicLabel: 'm',
        start: 20,
        end: end,
        speech: c,
        music: c,
        sermon: c,
        wood: c,
        error: c,
        ink: Colors.black,
        ground: Colors.white,
        labelStyle: const TextStyle(),
      );

  test('same data: no repaint', () {
    expect(make().shouldRepaint(make()), isFalse);
  });

  test('changed handle, new bars or an in-place Short edit: repaint', () {
    expect(make().shouldRepaint(make(end: 400)), isTrue);
    expect(make().shouldRepaint(make(bars: bars())), isTrue);
    final before = make();
    shorts.first.end = 50;
    expect(make().shouldRepaint(before), isTrue);
  });

  test('waveBars: one bar per 2 px, loud is taller, colour from the block', () {
    expect(b, hasLength(200));
    expect(waveBars(const [], blocks, 600, 400, c, c, c), isEmpty);
  });
}

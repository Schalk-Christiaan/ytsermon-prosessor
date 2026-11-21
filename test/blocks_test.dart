import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

void main() {
  final yw = fixtureSermons().firstWhere((s) => s.id == 'YWz5gf0onjk');
  final sound = fixtureSound('YWz5gf0onjk');
  final music = [
    for (final b in sound)
      if (b.kind == SegmentKind.music) b,
  ];

  test('YWz5gf0onjk: 15-50 blocks, none crosses music, ordered', () {
    final bl = blocks(yw.segs, sound);
    expect(bl.length, inInclusiveRange(15, 50));
    for (final b in bl) {
      for (final m in music) {
        expect(
          b.end <= m.start || b.start >= m.end,
          isTrue,
          reason: '${b.start}-${b.end} vs ${m.start}-${m.end}',
        );
      }
    }
    for (var i = 1; i < bl.length; i++) {
      expect(bl[i].start, greaterThanOrEqualTo(bl[i - 1].end));
    }
  });

  test('the prayer at 14:46 opens a block, right after the music', () {
    final bl = blocks(yw.segs, sound);
    final b = bl.firstWhere((b) => b.start >= 884);
    expect(b.start, closeTo(886.6, 1.0));
    expect(b.text, startsWith('Onse Vader'));
  });

  test('a block ends at "Amen", at a pause of 2 s and at music', () {
    Word w(double s, String t) => Word(s, s + 0.4, t);
    final words = [
      w(0, 'a'),
      w(1, 'b'),
      w(2, 'Amen.'),
      w(3, 'c'),
      w(8, 'd'),
      w(20, 'e'),
      w(22, 'f'),
    ];
    final seg = Segment(0, 23, 'x', words: words);
    final bl = blocks([seg], [const TimeBlock(15, 18, SegmentKind.music)]);
    expect([for (final b in bl) b.text], ['a b Amen.', 'c', 'd', 'e f']);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

void main() {
  test('a chunk ending in Amen with a prayer cue is a candidate', () {
    const s = [
      Segment(0, 5, 'Liewe gemeente ons lees'),
      Segment(5, 10, 'Amen. Kom ons dank saam.'),
      Segment(10, 15, 'Onse Vader ons dank U'),
      Segment(15, 20, 'in Jesus se Naam. Amen.'),
      Segment(20, 25, '[musiek]', kind: SegmentKind.music),
    ];
    final p = prayers(s);
    expect(p.length, 1);
    expect(p.single.start, 5);
    expect(p.single.end, 20);
    expect(p.single.first, startsWith('Kom ons dank saam'));
    expect(p.single.last, endsWith('Amen.'));
  });

  for (final f in fixtureSermons()) {
    test('${f.id}: candidates hold both prayer bounds (±30 s)', () {
      final p = prayers(f.segs);
      expect(
        p.any((c) => (c.start - f.start).abs() <= 30),
        isTrue,
        reason: p
            .map((c) => '${formatTime(c.start)}-${formatTime(c.end)}')
            .join(', '),
      );
      expect(
        p.any((c) => (c.end - f.end).abs() <= 30),
        isTrue,
        reason: p
            .map((c) => '${formatTime(c.start)}-${formatTime(c.end)}')
            .join(', '),
      );
    });
  }
}

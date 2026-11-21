import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

void main() {
  test('a chunk ending in Amen with a prayer cue is a candidate', () {
    const s = [
      Segment(0, 5, 'Liewe gemeente ons lees'),
      Segment(5, 10, 'Amen. Kom ons dank saam.'),
      Segment(10, 50, 'Onse Vader ons dank U'),
      Segment(50, 60, 'in Jesus se Naam. Amen.'),
      Segment(60, 65, '[musiek]', kind: SegmentKind.music),
    ];
    final p = prayers(s);
    expect(p.length, 1);
    expect(p.single.start, closeTo(6.25, 0.01)); // "Kom" by length inside 5-10
    expect(p.single.end, closeTo(58.07, 0.01)); // Amen start + 0.7 s
  });

  test('a short formula (seëngroet, geloofsbelydenis) is no candidate', () {
    const s = [
      Segment(0, 5, 'Almagtige Vader, genade en vrede van God ons Vader'),
      Segment(5, 10, 'deur die werking van die Heilige Gees. Amen.'),
    ];
    expect(prayers(s), isEmpty);
  });

  // Older recordings (no word times) only know the caption line, so their bounds are good to ~3 s.
  const lineLevel = {'IdZO-xP3iB0', 'a1kwRShCDpE'};
  for (final f in fixtureSermons()) {
    test('${f.id}: candidates hold both prayer bounds', () {
      final tol = lineLevel.contains(f.id) ? 3.0 : 1.5;
      final p = prayers(f.segs);
      final why = p
          .map(
            (c) => '${c.start.toStringAsFixed(2)}-${c.end.toStringAsFixed(2)}',
          )
          .join(', ');
      expect(
        p.any((c) => (c.start - f.start).abs() <= tol),
        isTrue,
        reason: 'start ${f.start}: $why',
      );
      expect(
        p.any((c) => (c.end - f.end).abs() <= tol),
        isTrue,
        reason: 'end ${f.end}: $why',
      );
    });
  }
}

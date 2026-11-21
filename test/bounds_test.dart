import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/bounds.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

void main() {
  // Older recordings (no word times) only know the caption line, so their bounds are good to ~3 s.
  const lineLevel = {'IdZO-xP3iB0', 'a1kwRShCDpE'};

  for (final f in fixtureSermons()) {
    test('${f.id}: findBounds picks both prayers', () {
      final tol = lineLevel.contains(f.id) ? 3.0 : 1.5;
      final b = findBounds(f.segs, prayers(f.segs));
      expect(b.sure, isTrue, reason: '${b.reason}');
      expect(b.start, closeTo(f.start, tol));
      expect(b.end, closeTo(f.end, tol));
    });
  }

  test('a service cut short has no full sermon: not sure, no false cut', () {
    final f = fixtureSermons().firstWhere((f) => f.id == 'a1kwRShCDpE');
    final segs = f.segs.where((s) => s.start < 20 * 60).toList();
    final b = findBounds(segs, prayers(segs));
    expect(b.sure, isFalse);
    expect(b.reason, BoundsDoubt.noSermon);
  });

  test('two long stretches of similar length: not sure', () {
    Segment s(double a, double b, String t) => Segment(a, b, t);
    final segs = [
      s(0, 60, 'Kom ons bid. Onse Vader ons dank U vir hierdie dag. Amen.'),
      s(100, 1100, 'woorde van die eerste preek'),
      s(1100, 1110, 'dis die einde. Amen.'),
      s(1110, 1200, 'Kom ons dank. Onse Vader ons dank U vir die woord. Amen.'),
      s(1300, 2200, 'woorde van die tweede preek'),
      s(2200, 2210, 'dis die einde. Amen.'),
      s(2210, 2300, 'Kom ons dank. Onse Vader ons dank U. Amen.'),
    ];
    final b = findBounds(segs, prayers(segs));
    expect(b.sure, isFalse);
    expect(b.reason, BoundsDoubt.twoSermons);
  });

  test('silence snap lands within 0.5 s of the hand marks', () {
    final sil = jsonDecode(
      File('test/fixtures/silences.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final f in fixtureSermons()) {
      List<(double, double)> at(String k) => parseSilences(
        sil[f.id][k]['out'] as String,
        (sil[f.id][k]['from'] as num).toDouble(),
      );
      final b = findBounds(f.segs, prayers(f.segs));
      final tol = lineLevel.contains(f.id) ? 2.0 : 0.5;
      expect(
        snapStart(b.start, at('start')),
        closeTo(f.start, tol),
        reason: f.id,
      );
      expect(snapEnd(b.end, at('end')), closeTo(f.end, tol), reason: f.id);
    }
  });

  test('no silence: the word time stays', () {
    expect(snapStart(10, []), 10);
    expect(snapEnd(10, []), 10);
    expect(parseSilences('silence_start: 5.5\n', 100), isEmpty);
  });
}

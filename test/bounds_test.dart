import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/bounds.dart';
import 'package:preekverwerker/core/models.dart';

import 'fixture_sermons.dart';

/// A block of one word from [a] to [b] (the last word "Amen" when [amen]).
Block _b(double a, double b, BlockLabel l, {bool amen = false}) =>
    Block([Word(a, b, amen ? 'Amen.' : 'woord')], b, label: l);

void main() {
  // The hand marks of `sermons.json` for the services that also have labels.
  final hand = [
    for (final f in fixtureSermons())
      if (labelledIds.contains(f.id)) f,
  ];

  for (final f in hand) {
    test('${f.id}: findBounds on the labels picks both prayers', () async {
      final b = findBounds(
        (await fixtureAnalysis(f.id)).blocks,
        fixtureSound(f.id),
      );
      expect(b.sure, isTrue, reason: '${b.reason}');
      expect(b.start, closeTo(f.start, 1.5));
      expect(b.end, closeTo(f.end, 1.5));
    });
  }

  test('a service cut short has no full sermon: not sure, no false cut', () {
    final b = findBounds([
      _b(0, 60, BlockLabel.gebed, amen: true),
      _b(100, 800, BlockLabel.preek),
    ], const []);
    expect(b.sure, isFalse);
    expect(b.reason, BoundsDoubt.noSermon);
  });

  test(
    'two long runs of similar length, both opened by a prayer: not sure',
    () {
      final b = findBounds([
        _b(0, 60, BlockLabel.gebed, amen: true),
        _b(100, 1100, BlockLabel.preek),
        _b(1110, 1200, BlockLabel.gebed, amen: true),
        _b(1300, 2200, BlockLabel.preek),
        _b(2210, 2300, BlockLabel.gebed, amen: true),
      ], const []);
      expect(b.sure, isFalse);
      expect(b.reason, BoundsDoubt.twoSermons);
    },
  );

  test('a lead-in block before the Amen is followed to the prayer\'s end', () {
    final b = findBounds([
      _b(0, 60, BlockLabel.gebed, amen: true),
      _b(100, 1100, BlockLabel.preek),
      _b(1110, 1112, BlockLabel.gebed),
      _b(1120, 1200, BlockLabel.gebed, amen: true),
    ], const []);
    expect(b.sure, isTrue);
    expect(b.start, 0);
    expect(b.end, 1200);
  });

  test('a prayer of several blocks: the cut starts at the first', () {
    final b = findBounds([
      _b(0, 60, BlockLabel.gebed),
      _b(70, 120, BlockLabel.gebed, amen: true),
      _b(130, 1130, BlockLabel.preek),
      _b(1140, 1200, BlockLabel.gebed, amen: true),
    ], const []);
    expect(b.sure, isTrue);
    expect(b.start, 0);
  });

  test('no prayer before: not sure, cut starts at the sermon', () {
    final b = findBounds([
      _b(100, 1100, BlockLabel.preek),
      _b(1110, 1200, BlockLabel.gebed, amen: true),
    ], const []);
    expect(b.reason, BoundsDoubt.noPrayerBefore);
    expect(b.start, 100);
  });

  test('silence snap lands within 0.5 s of the hand marks', () async {
    final sil = jsonDecode(
      File('test/fixtures/silences.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    for (final f in hand) {
      List<(double, double)> at(String k) => parseSilences(
        sil[f.id][k]['out'] as String,
        (sil[f.id][k]['from'] as num).toDouble(),
      );
      final b = findBounds(
        (await fixtureAnalysis(f.id)).blocks,
        fixtureSound(f.id),
      );
      expect(
        snapStart(b.start, at('start')),
        closeTo(f.start, 0.5),
        reason: f.id,
      );
      expect(snapEnd(b.end, at('end')), closeTo(f.end, 0.5), reason: f.id);
    }
  });

  test('no silence: the word time stays', () {
    expect(snapStart(10, []), 10);
    expect(snapEnd(10, []), 10);
    expect(parseSilences('silence_start: 5.5\n', 100), isEmpty);
  });
}

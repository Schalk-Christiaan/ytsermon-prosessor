import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'fixture_sermons.dart';

void main() {
  test(
    '9 sermons with hand-marked bounds, a note and silence output per bound',
    () {
      final sil = jsonDecode(
        File('test/fixtures/silences.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final all = fixtureSermons();
      expect(all.length, 9);
      for (final f in all) {
        expect(f.end - f.start, greaterThan(15 * 60), reason: f.id);
        for (final k in ['start', 'end']) {
          expect(sil[f.id]?[k]?['out'], isA<String>(), reason: '${f.id} $k');
        }
      }
    },
  );
}

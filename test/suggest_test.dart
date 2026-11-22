import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/playlists.dart';
import 'package:preekverwerker/core/suggest.dart';

Brief brief(String id, {String excerpt = ''}) =>
    Brief(id, 'Preek $id', 'Mattheus 5', '2026-11-01', excerpt);

ChatFn reply(Object content, [void Function(Map<String, dynamic>)? seen]) =>
    (body) async {
      seen?.call(body);
      return {
        'message': {
          'content': content is String ? content : jsonEncode(content),
        },
      };
    };

void main() {
  final group = PlaylistGroup('1', 'Advent 2026', description: 'Vier Sondae')
    ..sermons.add('in');

  test(
    'suggestSermons keeps valid ids, drops unknown and already-in ids',
    () async {
      Map<String, dynamic>? seen;
      final r = await suggestSermons(
        group,
        [brief('in'), brief('a', excerpt: 'Advent is koms'), brief('b')],
        chat: reply({
          'suggestions': [
            {'id': 'a', 'reason': 'oor Advent'},
            {'id': 'zzz', 'reason': 'onbekend'},
            {'id': 'in', 'reason': 'reeds daar'},
            {'id': 'b'},
          ],
        }, (b) => seen = b),
      );
      expect(r.map((s) => s.id), ['a', 'b']);
      expect(r.first.reason, 'oor Advent');
      expect(r.last.reason, '');
      final prompt = jsonEncode(seen);
      expect(prompt, contains('Advent 2026'));
      expect(prompt, contains('Vier Sondae'));
      expect(prompt, contains('Advent is koms'));
      expect(
        prompt,
        isNot(contains('"in"')),
      ); // a sermon already in the group is not offered
    },
  );

  test('suggestSermons: invalid JSON is a SuggestException; none to offer = no call', () async {
    await expectLater(
      suggestSermons(group, [brief('a')], chat: reply('nie json nie')),
      throwsA(isA<SuggestException>()),
    );
    var called = false;
    final r = await suggestSermons(
      group,
      [brief('in')],
      chat: (b) async {
        called = true;
        return {};
      },
    );
    expect(r, isEmpty);
    expect(called, isFalse);
  });

  test(
    'a long excerpt is cut to a word budget that shrinks with many sermons',
    () {
      final long = List.filled(900, 'woord').join(' ');
      expect(wordBudget(1), 500);
      expect(wordBudget(1000), 40);
      expect(cutWords(long, 5).split(' '), hasLength(5));
      expect(cutWords('kort', 5), 'kort');
    },
  );
}

import 'dart:async';
import 'dart:convert';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/store.dart';
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
  final adv = PlaylistGroup('1', 'Advent 2026', description: 'Vier Sondae')
    ..sermons.add('in');

  test(
    'suggestSermons keeps valid ids, drops unknown and already-in ids',
    () async {
      Map<String, dynamic>? seen;
      final r = await suggestSermons(
        adv,
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
      suggestSermons(adv, [brief('a')], chat: reply('nie json nie')),
      throwsA(isA<SuggestException>()),
    );
    var called = false;
    final r = await suggestSermons(
      adv,
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

  group('after a render', () {
    late Directory root;
    late SermonStore store;
    late AppSettings settings;
    setUp(() {
      root = Directory.systemTemp.createTempSync('sug');
      store = SermonStore(root)
        ..load()
        ..merge([const ChannelItem('aaaaaaaaaaa', 'Advent een', 1)]);
      settings = AppSettings.load(root)
        ..groups.add(PlaylistGroup('g1', 'Advent 2026'))
        ..groups.add(PlaylistGroup('g2', 'Johannes'));
    });
    tearDown(() => root.deleteSync(recursive: true));

    JobQueue queue() => JobQueue(
      store,
      plan: (_) async {},
      cut: (_) async {},
      audio: (_) async {},
    );

    test('a finished cut gets one suggestion; accept files it, creating the new group', () async {
      final jobs = queue();
      var asked = 0;
      final sug = GroupSuggestions(
        settings,
        store,
        chat: (b) async {
          asked++;
          return {
            'message': {
              'content': jsonEncode({
                'groups': ['g1', 'zzz'],
                'new_name': 'Adventsreeks',
              }),
            },
          };
        },
      )..attach(jobs);
      jobs.enqueue('aaaaaaaaaaa', JobKind.cut);
      await jobs.idle;
      await Future<void>.delayed(Duration.zero);
      await sug.settled;
      expect(asked, 1);
      final s = sug.pending['aaaaaaaaaaa']!;
      expect(s.groupIds, ['g1']);
      expect(s.newName, 'Adventsreeks');
      expect(sug.names(s), ['Advent 2026', 'Adventsreeks']);
      sug.accept('aaaaaaaaaaa');
      expect(sug.pending, isEmpty);
      expect(settings.groups.first.sermons, ['aaaaaaaaaaa']);
      final made = settings.groups.last;
      expect([made.name, ...made.sermons], ['Adventsreeks', 'aaaaaaaaaaa']);
      expect(AppSettings.load(root).groups, hasLength(3));
      // a second cut of the same sermon does not ask again
      jobs.enqueue('aaaaaaaaaaa', JobKind.cut);
      await jobs.idle;
      await sug.settled;
      expect(asked, 1);
    });

    test(
      'ignore drops it; an Ollama error leaves no suggestion and the job done',
      () async {
        final jobs = queue();
        var fail = true;
        final sug = GroupSuggestions(
          settings,
          store,
          chat: (b) async {
            if (fail) throw const SocketException('weg');
            return {
              'message': {
                'content': jsonEncode({
                  'groups': ['g2'],
                  'new_name': '',
                }),
              },
            };
          },
        )..attach(jobs);
        jobs.enqueue('aaaaaaaaaaa', JobKind.cut);
        await jobs.idle;
        await sug.settled;
        expect(jobs.jobs.single.status, JobStatus.klaar);
        expect(sug.pending, isEmpty);
        fail = false;
        await sug.request('aaaaaaaaaaa');
        expect(sug.pending['aaaaaaaaaaa']!.newName, isNull);
        sug.ignore('aaaaaaaaaaa');
        expect(sug.pending, isEmpty);
        expect(settings.groups.every((g) => g.sermons.isEmpty), isTrue);
      },
    );

    test('an existing klaar job at start is not re-suggested; the render never waits for Ollama', () async {
      final jobs = queue();
      jobs.enqueue('aaaaaaaaaaa', JobKind.cut);
      await jobs.idle;
      final gate = Completer<Map<String, dynamic>>();
      final sug = GroupSuggestions(settings, store, chat: (b) => gate.future)
        ..attach(jobs);
      expect(sug.pending, isEmpty);
      store.merge([const ChannelItem('bbbbbbbbbbb', 'B', 2)]);
      jobs.enqueue('bbbbbbbbbbb', JobKind.cut);
      await jobs.idle; // completes while the chat is still waiting
      expect(jobs.jobs.last.status, JobStatus.klaar);
      expect(sug.pending, isEmpty);
      gate.complete({
        'message': {'content': '{"groups":[],"new_name":"Nuut"}'},
      });
      await sug.settled;
      expect(sug.pending['bbbbbbbbbbb']!.newName, 'Nuut');
    });
  });
}

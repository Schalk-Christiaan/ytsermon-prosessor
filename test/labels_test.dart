// AI labels for the speech blocks and songs. The Ollama answers per service are stored in
// test/fixtures/ollama/<id>.json; record them again with `E2E=1 flutter test test/labels_test.dart` (real Ollama).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/bounds.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/service_info.dart';

import 'fixture_sermons.dart';

const _ids = ['YWz5gf0onjk', '6s_FFatG0so', 'lBMwRt3eIus', 'uub_CnO7bd0'];

Map<String, dynamic> _info(String id) =>
    jsonDecode(File('test/fixtures/info/$id.json').readAsStringSync())
        as Map<String, dynamic>;

List<Segment> _segs(String id) => parseJson3(
  utf8.decode(
    gzip.decode(File('test/fixtures/$id.af-orig.json3.gz').readAsBytesSync()),
  ),
);

File _fx(String id) => File('test/fixtures/ollama/$id.json');

Future<Analysis> _analyse(String id, ChatFn chat) {
  final segs = _segs(id), sound = fixtureSound(id);
  final info = ServiceInfo.fromInfo(_info(id));
  return Planner(chat: chat).analyse(
    blocks: blocks(segs, sound),
    sound: sound,
    duration: (_info(id)['duration'] as num).toDouble(),
    originalDescription: _info(id)['description'] as String,
    psalms: info.psalms,
  );
}

ChatFn _stored(String id) =>
    (_) async => {
      'message': {'content': _fx(id).readAsStringSync()},
    };

void main() {
  test('the request: one call, no thinking, temperature 0, block list and songs in the prompt', () async {
    final seen = <Map<String, dynamic>>[];
    final a = await _analyse('YWz5gf0onjk', (b) async {
      seen.add(b);
      return {
        'message': {
          'content': jsonEncode({
            'gebed_voor': 0,
            'preek_van': 1,
            'preek_tot': 1,
            'gebed_na': 2,
            'gebede': <int>[],
            'seen': [99],
            'songs': [
              {'nr': 1, 'name': 'Psalm 33'},
              {'nr': 2, 'name': 'Psalm 99'}, // not in the description's list
            ],
            'service': 'geen',
          }),
        },
      };
    });
    expect(seen.length, 1);
    final r = seen.single;
    expect(r['think'], false);
    expect(r['options']['temperature'], 0);
    expect(r['options']['seed'], 1);
    final user = r['messages'][1]['content'] as String;
    expect(user, contains('#1 [07:45'));
    expect(user, contains('Musiekstuk 1'));
    expect(
      user,
      isNot(contains('Musiekstuk 4')),
      reason: 'music before the first speech is no song',
    );
    expect(a.blocks[0].label, BlockLabel.preek);
    expect(a.blocks[1].label, BlockLabel.gebed);
    expect(
      a.blocks[2].label,
      BlockLabel.ander,
      reason: 'unlabelled (or number out of range) -> ander',
    );
    expect(a.songs.length, 3);
    expect(a.songs[0].name, 'Psalm 33');
    expect(
      a.songs[1].name,
      isNull,
      reason: 'Psalm 99 is not in the description',
    );
    expect(a.service, isNull);
  });

  if (Platform.environment['E2E'] != null) {
    test('record the real Ollama answers', () async {
      for (final id in _ids) {
        await _analyse(id, (body) async {
          final res = await ollamaChat(body);
          _fx(id)
            ..createSync(recursive: true)
            ..writeAsStringSync(res['message']['content'] as String);
          return res;
        });
      }
    }, timeout: const Timeout(Duration(minutes: 30)));
  }

  for (final id in _ids) {
    test(
      '$id (stored answer): one sermon run of 15 min or more, framed by prayers',
      () async {
        if (!_fx(id).existsSync()) fail('no stored answer: run with E2E=1');
        final a = await _analyse(id, _stored(id));
        final runs = [
          for (final r in sermonRuns(a.blocks))
            if (r.last.end - r.first.start >= kMinSermon) r,
        ];
        expect(
          runs.length,
          1,
          reason: [
            for (final b in a.blocks) '${formatTime(b.start)} ${b.label?.name}',
          ].join('\n'),
        );
        final i = a.blocks.indexOf(runs.single.first);
        final j = a.blocks.indexOf(runs.single.last);
        expect(a.blocks[i - 1].label, BlockLabel.gebed);
        expect(a.blocks[j + 1].label, BlockLabel.gebed);
      },
    );
  }

  test(
    'YWz5gf0onjk (stored answer): the songs include Psalm 33, 42 and 46',
    () async {
      final a = await _analyse('YWz5gf0onjk', _stored('YWz5gf0onjk'));
      final names = [for (final s in a.songs) s.name ?? ''].join('|');
      for (final n in ['33', '42', '46']) {
        expect(names, contains('Psalm $n'), reason: names);
      }
    },
  );
}

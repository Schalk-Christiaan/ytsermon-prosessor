import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/store.dart';

void main() {
  late Directory root;
  setUp(() => root = Directory.systemTemp.createTempSync('store'));
  tearDown(() => root.deleteSync(recursive: true));

  const a = ChannelItem('aaaaaaaaaaa', 'A', 100);
  const b = ChannelItem('bbbbbbbbbbb', 'B', 200);

  test('merge: new ids are nuut and returned; existing keep their state', () {
    final s = SermonStore(root)..load();
    expect(s.merge([a, b]).map((e) => e.id), ['aaaaaaaaaaa', 'bbbbbbbbbbb']);
    s.save(s.byId('aaaaaaaaaaa')!..state = SermonState.gesny);
    final s2 = SermonStore(root)..load(); // "herbegin"
    final fresh = s2.merge([a, b, const ChannelItem('ccccccccccc', 'C', 3)]);
    expect(fresh.map((e) => e.id), ['ccccccccccc']);
    expect(s2.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
    expect(s2.byId('bbbbbbbbbbb')!.state, SermonState.nuut);
    expect(s2.sorted.map((e) => e.id), [
      'aaaaaaaaaaa',
      'bbbbbbbbbbb',
      'ccccccccccc',
    ]);
  });

  test('roundtrip with date, error and outputs; write is atomic', () {
    final s = SermonStore(root)..load();
    s.merge([a]);
    s.save(
      s.byId(a.id)!
        ..date = '2026-11-15'
        ..state = SermonState.fout
        ..error = 'oeps'
        ..outputs = ['x.mp4'],
    );
    final dir = Directory(p.join(root.path, a.id));
    expect(dir.listSync().map((f) => p.basename(f.path)), ['sermon.json']);
    final r = (SermonStore(root)..load()).byId(a.id)!;
    expect(
      [r.date, r.state, r.error, r.outputs, r.duration],
      [
        '2026-11-15',
        SermonState.fout,
        'oeps',
        ['x.mp4'],
        100.0,
      ],
    );
  });

  test('phase 1 plan.json without sermon.json counts as beplan', () {
    final dir = Directory(p.join(root.path, a.id))..createSync();
    File(p.join(dir.path, 'plan.json')).writeAsStringSync('{}');
    File(p.join(dir.path, '${a.id}.info.json'))
        .writeAsStringSync(jsonEncode({'upload_date': '20261115'}));
    final s = SermonStore(root)..load();
    s.merge([a]);
    expect(s.byId(a.id)!.state, SermonState.beplan);
    expect(s.byId(a.id)!.date, '2026-11-15');
  });

  test('an unreadable sermon.json is skipped, the others still load', () {
    final s0 = SermonStore(root)..merge([a, b]);
    File(p.join(root.path, a.id, 'sermon.json')).writeAsStringSync('{"id": ');
    final s = SermonStore(root)..load();
    expect(s.byId(a.id), isNull);
    expect(s.byId(b.id), isNotNull);
    expect(s0.sorted.length, 2);
  });

  test('merge drops untouched sermons that the listing no longer has', () {
    final s = SermonStore(root)..merge([a, b]);
    s.byId(b.id)!.state = SermonState.beplan;
    s.save(s.byId(b.id)!);
    s.merge([const ChannelItem('ccccccccccc', 'C', 5)]);
    expect(s.byId(a.id), isNull);
    expect(s.byId(b.id), isNotNull, reason: 'work was done on it');
    expect(File(p.join(root.path, a.id, 'sermon.json')).existsSync(), isFalse);
    s.merge([]);
    expect(
      s.byId('ccccccccccc'),
      isNotNull,
      reason: 'an empty list is no proof',
    );
  });
}

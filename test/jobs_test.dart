import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/tools.dart';

void main() {
  late Directory root;
  late SermonStore store;
  setUp(() {
    root = Directory.systemTemp.createTempSync('jobs');
    store = SermonStore(root)
      ..load()
      ..merge([
        const ChannelItem('aaaaaaaaaaa', 'A', 1),
        const ChannelItem('bbbbbbbbbbb', 'B', 2),
      ]);
  });
  tearDown(() => root.deleteSync(recursive: true));

  JobQueue queue({JobRun? plan, JobRun? cut}) =>
      JobQueue(store, plan: plan ?? (_) async {}, cut: cut ?? (_) async {});

  test('runs in order, one at a time, sets states', () async {
    final log = <String>[];
    var running = 0;
    final q = queue(
      plan: (c) async {
        expect(++running, 1);
        log.add('plan ${c.id}');
        await Future<void>.delayed(const Duration(milliseconds: 10));
        running--;
      },
      cut: (c) async => log.add('cut ${c.id}'),
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.enqueue('bbbbbbbbbbb', JobKind.plan);
    q.enqueue('aaaaaaaaaaa', JobKind.cut);
    q.enqueue('aaaaaaaaaaa', JobKind.cut); // duplicate ignored
    q.start();
    await q.idle;
    expect(log, ['plan aaaaaaaaaaa', 'plan bbbbbbbbbbb', 'cut aaaaaaaaaaa']);
    expect(store.byId('bbbbbbbbbbb')!.state, SermonState.beplan);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.gesny);
    expect(q.jobs.every((j) => j.status == JobStatus.klaar), isTrue);
  });

  test('a job that was besig at restart runs again', () async {
    final first = queue(plan: (_) => Completer<void>().future);
    first.enqueue('aaaaaaaaaaa', JobKind.plan);
    first.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(first.jobs.single.status, JobStatus.besig);
    // "herbegin": a new queue on the same folder
    final ran = <String>[];
    final second = queue(plan: (c) async => ran.add(c.id));
    expect(second.jobs.single.status, JobStatus.wag);
    second.start();
    await second.idle;
    expect(ran, ['aaaaaaaaaaa']);
    expect(second.jobs.single.status, JobStatus.klaar);
  });

  test('failure marks job and sermon fout; retry runs it again', () async {
    var fail = true;
    final q = queue(
      plan: (_) async {
        if (fail) {
          throw ProcessException('yt-dlp', [], 'ERROR: boom', 1);
        }
      },
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.start();
    await q.idle;
    final s = store.byId('aaaaaaaaaaa')!;
    expect(s.state, SermonState.fout);
    expect(s.error, isNotEmpty);
    expect(q.jobs.single.status, JobStatus.fout);
    expect(q.jobs.single.log.join('\n'), contains('boom'));
    fail = false;
    q.retry(q.jobs.single);
    await q.idle;
    expect(q.jobs.single.status, JobStatus.klaar);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.beplan);
    expect(File(p.join(root.path, 'jobs.json')).existsSync(), isTrue);
    expect(
      jsonDecode(File(p.join(root.path, 'jobs.json')).readAsStringSync()),
      isList,
    );
  });

  test('cancel stops the current job; the next one still runs', () async {
    final q = queue(
      plan: (c) async {
        if (c.id == 'aaaaaaaaaaa') {
          await c.cancel;
          throw JobCancelled();
        }
      },
    );
    q.enqueue('aaaaaaaaaaa', JobKind.plan);
    q.enqueue('bbbbbbbbbbb', JobKind.plan);
    q.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    q.cancel();
    await q.idle;
    expect(q.jobs[0].status, JobStatus.gekanselleer);
    expect(q.jobs[1].status, JobStatus.klaar);
    expect(store.byId('aaaaaaaaaaa')!.state, SermonState.nuut);
  });
}

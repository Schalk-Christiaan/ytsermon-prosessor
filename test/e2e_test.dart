// Full flow through the queue on the real test video; run with E2E=1.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/store.dart';

void main() {
  test(
    'id -> plan job -> cut job',
    () async {
      HttpOverrides.global = null;
      final out = Directory('out/e2e')..createSync(recursive: true);
      final store = SermonStore(Directory('/tmp/claude-1000/e2e/work'))
        ..load()
        ..merge([const ChannelItem('YWz5gf0onjk', 'Toetspreek', 3728)]);
      final q = JobQueue(
        store,
        out: out,
        font: File('assets/fonts/sans.ttf').absolute,
      );
      q.enqueue('YWz5gf0onjk', JobKind.plan);
      await q.idle;
      expect(store.byId('YWz5gf0onjk')!.state, SermonState.beplan);
      q.enqueue('YWz5gf0onjk', JobKind.cut);
      await q.idle;
      final s = store.byId('YWz5gf0onjk')!;
      expect(s.state, SermonState.gesny, reason: '${s.error}');
      // ignore: avoid_print
      print('uitset: ${s.outputs}');
    },
    skip: Platform.environment['E2E'] == null ? 'E2E=1 only' : null,
    timeout: const Timeout(Duration(minutes: 15)),
  );
}

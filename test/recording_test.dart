import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/recording.dart';
import 'package:preekverwerker/core/store.dart';

void main() {
  test('importRecording copies, writes meta and a manual plan; fetchMeta needs no yt-dlp', () async {
    final tmp = Directory.systemTemp.createTempSync('opname');
    final src = File(p.join(tmp.path, 'diens.mp4'));
    await Process.run('ffmpeg', [
      '-y',
      '-f',
      'lavfi',
      '-i',
      'testsrc=size=160x120:rate=25:duration=4',
      '-f',
      'lavfi',
      '-i',
      'sine=duration=4',
      '-pix_fmt',
      'yuv420p',
      '-shortest',
      src.path,
    ]);
    final root = Directory(p.join(tmp.path, 'werk'));
    final store = SermonStore(root);
    final s = await importRecording(
      src,
      'Kersdiens',
      DateTime(2026, 12, 25),
      store,
      now: DateTime(2026, 12, 26, 9, 5, 7),
    );
    expect(s.id, 'opname-20261226-090507');
    expect(isRecording(s.id), isTrue);
    expect(s.state, SermonState.beplan);
    expect(s.date, '2026-12-25');
    expect(s.duration, closeTo(4, 0.2));
    expect(store.sorted.first.id, s.id);
    expect(src.existsSync(), isTrue, reason: 'copied, not moved');

    final m = await fetchMeta(s.id, root);
    expect(m.video.lengthSync(), src.lengthSync());
    expect(m.info.titleText, 'Kersdiens');
    expect(m.info.uploadDate, '2026-12-25');
    final plan = await Planner().loadOrPlan(
      m.dir,
      blocks: <Block>[],
      bounds: const Bounds(0, 4),
      duration: s.duration,
      originalDescription: '',
    );
    expect(plan.sermonStart, 0);
    expect(plan.sermonEnd, closeTo(4, 0.2));
    expect(plan.title, 'Kersdiens');

    store.load();
    expect(store.byId(s.id)!.title, 'Kersdiens');
    tmp.deleteSync(recursive: true);
  });
}

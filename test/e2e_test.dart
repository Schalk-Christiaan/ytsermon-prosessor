// Full flow through the controller on the real test video; run with E2E=1.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

void main() {
  test(
    'url -> plan -> review -> cut',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      HttpOverrides.global = null;
      MediaKit.ensureInitialized();
      final out = Directory('out/e2e')..createSync(recursive: true);
      final c = ReviewController(
        work: Directory('/tmp/claude-1000/e2e/work'),
        out: out,
        font: File('assets/fonts/sans.ttf').absolute,
      );
      final stages = <LoadStage>{};
      c.addListener(() => stages.add(c.stage));
      await c.load('https://youtu.be/YWz5gf0onjk');
      expect(c.state, ReviewState.ready, reason: '${c.error}');
      // ignore: avoid_print
      print(
        'plan ${c.plan!.sermonStart}-${c.plan!.sermonEnd} shorts ${c.plan!.shorts.length}',
      );
      final r = await c.approveAndCut();
      // ignore: avoid_print
      print('cut ${r.$1} preek, ${r.$2} Shorts in ${r.$3.path}');
      expect(r.$1, 1);
    },
    skip: Platform.environment['E2E'] == null ? 'E2E=1 only' : null,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}

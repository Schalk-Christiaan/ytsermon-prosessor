// Sermon-bounds benchmark against the real qwen3:8b: 3 fixture sermons x 3 runs, each run must land
// within ±30 s of the prayer-to-prayer bounds. Run with BOUNDS=1 (needs Ollama, no internet).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/planner.dart';

import 'fixture_sermons.dart';

void main() {
  for (final f in fixtureSermons()) {
    test(
      '${f.id}: 3 runs within ±30 s of the prayers',
      () async {
        HttpOverrides.global = null;
        for (var run = 1; run <= 3; run++) {
          final sw = Stopwatch()..start();
          final p = await Planner().plan(
            compactText: compact(f.segs),
            prayers: prayers(f.segs),
            duration: f.duration,
            originalDescription: f.description,
          );
          // ignore: avoid_print
          print(
            '${f.id} lopie $run: ${formatTime(p.sermonStart)}–${formatTime(p.sermonEnd)} '
            '(verwag ${formatTime(f.start)}–${formatTime(f.end)}; '
            'afwyking ${(p.sermonStart - f.start).round()} s / ${(p.sermonEnd - f.end).round()} s; '
            '${sw.elapsed.inSeconds} s)',
          );
          expect((p.sermonStart - f.start).abs(), lessThanOrEqualTo(30));
          expect((p.sermonEnd - f.end).abs(), lessThanOrEqualTo(30));
        }
      },
      skip: Platform.environment['BOUNDS'] == null ? 'BOUNDS=1 only' : null,
      timeout: const Timeout(Duration(minutes: 30)),
    );
  }
}

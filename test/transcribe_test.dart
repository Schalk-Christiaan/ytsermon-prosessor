import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/captions.dart';
import 'package:preekverwerker/core/tools.dart';
import 'package:preekverwerker/core/transcribe.dart';

import 'tools_test.dart' show fakeFfmpeg;

void main() {
  final sample = File('test/fixtures/whisper-sample.json').readAsStringSync();

  test('whisperToJson3: words with times, repeated segments dropped', () {
    final segs = parseJson3(whisperToJson3(sample));
    // 7 whisper segments; the 2nd occurs three times in a row, and a segment equal to the previous two is a loop.
    expect(segs.map((s) => s.text), [
      'Gee toch vir hulle al die kracht daartoe, vraag ons.',
      'Ach, gee toch vir hulle al die wijsheid wat hulle nodig het.',
      'Ach, gee toch vir hulle al die wijsheid wat hulle nodig het.',
      'Vervul hulle toch met die heilige gees,',
      'so dat hier die gemeente mekaar ook in waarheid mag liefhe.',
      'Ons bid vir die vervolgde kerk,',
    ]);
    final first = segs.first;
    expect(first.start, closeTo(5.26, 0.001));
    expect(first.words.map((w) => w.text).take(4), [
      'Gee',
      'toch',
      'vir',
      'hulle',
    ]);
    expect(first.words.first.start, closeTo(5.26, 0.001));
    for (final s in segs) {
      for (var i = 1; i < s.words.length; i++) {
        expect(s.words[i].start, greaterThanOrEqualTo(s.words[i - 1].start));
      }
    }
    // the converted segments feed the same block builder as YouTube's
    expect(blocks(segs, const []), isNotEmpty);
  });

  group('transcribeLocal with fake ffmpeg and whisper-cli', () {
    late Directory d;
    setUp(() {
      d = Directory.systemTemp.createTempSync('tr');
      resetVideoEncoder();
    });
    tearDown(() {
      ffmpegTool = 'ffmpeg';
      d.deleteSync(recursive: true);
    });

    test('writes <id>.local.json3 and reports progress', () async {
      ffmpegTool = fakeFfmpeg(d, listed: false, works: false);
      final whisper = File(p.join(d.path, 'whisper-cli'))
        ..writeAsStringSync('''#!/bin/sh
while [ \$# -gt 0 ]; do
  case "\$1" in -of) OUT="\$2";; -m) echo "\$2" > "${d.path}/model";; esac
  shift
done
echo "whisper_print_progress_callback: progress =  20%" >&2
echo "whisper_print_progress_callback: progress = 100%" >&2
cp ${File('test/fixtures/whisper-sample.json').absolute.path} "\$OUT.json"
''');
      Process.runSync('chmod', ['+x', whisper.path]);
      final video = File(p.join(d.path, 'v.mp4'))..writeAsStringSync('x');
      File(p.join(d.path, 'm.bin')).writeAsStringSync('x');
      final seen = <double>[];
      final out = await transcribeLocal(
        video,
        File(p.join(d.path, 'abc.local.json3')),
        whisper: whisper.path,
        model: File(p.join(d.path, 'm.bin')),
        onProgress: seen.add,
      );
      expect(p.basename(out.path), 'abc.local.json3');
      expect(parseJson3(out.readAsStringSync()), hasLength(6));
      expect(seen, [0.2, 1.0]);
      expect(
        File(p.join(d.path, 'model')).readAsStringSync().trim(),
        endsWith('m.bin'),
      );
      // temp files are gone
      expect(
        d.listSync().map((e) => p.basename(e.path)),
        isNot(anyOf(contains('abc.wav'), contains('abc.wav.json'))),
      );
    }, skip: Platform.isWindows);
  });
}

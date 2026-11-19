import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/cutter.dart';
import 'package:preekverwerker/core/tools.dart';

void main() {
  test('sermonFileName strips <>:"/\\|?* and prefixes the date', () {
    expect(
      sermonFileName('2026-11-15', 'Wat? "Die" hart: A/B'),
      '2026-11-15 Wat Die hart AB.mp4',
    );
  });

  test('sermonArgs is a stream copy of [start, end]', () {
    expect(sermonArgs('v.mp4', 1384.0, 3210.0, 'out/s.mp4'), [
      '-y',
      '-ss',
      '1384.000',
      '-to',
      '3210.000',
      '-i',
      'v.mp4',
      '-c',
      'copy',
      'out/s.mp4',
    ]);
  });

  test('shortArgs: 9:16 crop, relative srt, fontsdir, x264 + aac, progress pipe', () {
    final a = shortArgs(
      'video.mp4',
      'short-1.srt',
      100.0,
      160.0,
      '/abs/out/short-1.mp4',
    );
    expect(
      a,
      containsAllInOrder([
        '-ss',
        '100.000',
        '-to',
        '160.000',
        '-i',
        'video.mp4',
      ]),
    );
    final vf = a[a.indexOf('-vf') + 1];
    expect(
      vf,
      "crop=ih*9/16:ih,scale=1080:1920,subtitles=short-1.srt:fontsdir=fonts:"
      "force_style='FontName=Source Sans 3,FontSize=14,Alignment=2,MarginV=70'",
    );
    expect(
      a,
      containsAllInOrder(['-c:v', 'libx264', '-crf', '20', '-c:a', 'aac']),
    );
    expect(a, containsAllInOrder(['-progress', 'pipe:1']));
    expect(a.last, '/abs/out/short-1.mp4');
  });

  test('parseFfmpegProgress reads out_time_us', () {
    expect(parseFfmpegProgress('out_time_us=30000000'), 30.0);
    expect(parseFfmpegProgress('frame=3'), isNull);
    expect(parseFfmpegProgress('out_time_us=N/A'), isNull);
  });

  test('sermonFileName takes an extension for the WhatsApp audio', () {
    expect(
      sermonFileName('2026-11-16', 'Tema: Genade?', ext: 'mp3'),
      '2026-11-16 Tema Genade.mp3',
    );
  });

  test('audioArgs: mono mp3 64 kbps with an ID3 title, no video', () {
    final a = audioArgs('in/preek.mp4', 'out/p.mp3', 'Uit die oorvloed');
    expect(a, containsAllInOrder(['-i', 'in/preek.mp4', '-vn']));
    expect(
      a,
      containsAllInOrder(['-ac', '1', '-c:a', 'libmp3lame', '-b:a', '64k']),
    );
    expect(
      a,
      containsAllInOrder([
        '-id3v2_version',
        '3',
        '-metadata',
        'title=Uit die oorvloed',
      ]),
    );
    expect(a, containsAllInOrder(['-progress', 'pipe:1']));
    expect(a.last, 'out/p.mp3');
  });

  test(
    'cutAudio makes a mono 64 kbps mp3 with a title tag (real ffmpeg)',
    () async {
      final d = Directory.systemTemp.createTempSync('audio');
      final src = File(p.join(d.path, 'in.mp4'));
      await Process.run('ffmpeg', [
        '-y',
        '-f',
        'lavfi',
        '-i',
        'sine=frequency=440:duration=5',
        '-ac',
        '2',
        src.path,
      ]);
      final out = await cutAudio(src, 'Toets: tema', '2026-11-16', d);
      expect(p.basename(out.path), '2026-11-16 Toets tema.mp3');
      final r = await Process.run('ffprobe', [
        '-v',
        'error',
        '-show_entries',
        'stream=codec_name,channels,bit_rate:format_tags=title',
        '-of',
        'json',
        out.path,
      ]);
      final j = jsonDecode(r.stdout as String);
      final st = j['streams'][0];
      expect(st['codec_name'], 'mp3');
      expect(st['channels'], 1);
      expect(st['bit_rate'], '64000');
      expect(j['format']['tags']['title'], 'Toets: tema');
      d.deleteSync(recursive: true);
    },
    skip: findExecutable('ffmpeg') == null ? 'ffmpeg ontbreek' : null,
  );
}

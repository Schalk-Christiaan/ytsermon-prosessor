import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/cutter.dart';

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
}

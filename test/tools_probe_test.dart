import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/tools.dart';

void main() {
  test(
    'probeAll with empty PATH reports yt-dlp/ffmpeg/ffprobe as missing',
    () async {
      final r = await probeAll(path: '');
      for (final s in r.take(3)) {
        expect(s.ok, isFalse, reason: s.name);
        expect(s.detail, 'missing');
      }
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';

void main() {
  test('videoIdFromUrl', () {
    for (final u in [
      'https://youtu.be/YWz5gf0onjk',
      'https://www.youtube.com/watch?v=YWz5gf0onjk&t=3s',
      'https://www.youtube.com/live/YWz5gf0onjk?si=x',
      'YWz5gf0onjk',
    ]) {
      expect(videoIdFromUrl(u), 'YWz5gf0onjk', reason: u);
    }
    expect(videoIdFromUrl('https://example.com/'), isNull);
  });

  test('parseProgress reads yt-dlp download lines', () {
    expect(
      parseProgress('[download]  42.3% of  1.20GiB at 5MiB/s ETA 01:02'),
      42.3,
    );
    expect(parseProgress('[download] 100% of 1.20GiB in 00:03:00'), 100);
    expect(parseProgress('[info] something else'), isNull);
  });
}

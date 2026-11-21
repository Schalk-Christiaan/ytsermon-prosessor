import 'dart:convert';
import 'dart:io';

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

  test('normalizeChannelUrl takes every form and gives one', () {
    for (final u in [
      '@gereformeerdekerk',
      ' @gereformeerdekerk ',
      'youtube.com/@gereformeerdekerk',
      'https://www.youtube.com/@gereformeerdekerk/videos',
      'http://m.youtube.com/@gereformeerdekerk?si=x',
    ]) {
      expect(
        normalizeChannelUrl(u),
        'https://www.youtube.com/@gereformeerdekerk',
        reason: u,
      );
    }
    const id = 'UCabcdefghijklmnopqrstuv';
    expect(
      normalizeChannelUrl('https://www.youtube.com/channel/$id/streams'),
      'https://www.youtube.com/channel/$id',
    );
    expect(
      normalizeChannelUrl('youtube.com/c/KerkNaam'),
      'https://www.youtube.com/c/KerkNaam',
    );
    for (final bad in [
      '',
      'kerk',
      '--exec rm',
      'https://example.com/@x',
      'https://www.youtube.com/watch?v=YWz5gf0onjk',
      '@a b',
    ]) {
      expect(normalizeChannelUrl(bad), isNull, reason: bad);
    }
  });

  test('parseProgress reads yt-dlp download lines', () {
    expect(
      parseProgress('[download]  42.3% of  1.20GiB at 5MiB/s ETA 01:02'),
      42.3,
    );
    expect(parseProgress('[download] 100% of 1.20GiB in 00:03:00'), 100);
    expect(parseProgress('[info] something else'), isNull);
  });
  test(
    'parseChannel keeps list order, merges tabs on id, date stays unknown',
    () {
      final j = jsonDecode(
        File('test/fixtures/channel-flat.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final items = parseChannel([j['streams'], j['videos']]);
      final ids = [for (final i in items) i.id];
      expect(ids.toSet().length, ids.length);
      expect(ids.first, 'YWz5gf0onjk');
      expect(ids.length, 5);
      expect(items.first.duration, 3728);
      expect(items.first.title, isNotEmpty);
    },
  );
}

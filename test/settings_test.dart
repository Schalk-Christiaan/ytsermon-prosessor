import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/channel.dart' show kChannelUrl;
import 'package:preekverwerker/core/settings.dart';

void main() {
  test('defaults, then a round trip through settings.json', () {
    final d = Directory.systemTemp.createTempSync('set');
    final s = AppSettings.load(d);
    expect(s.clientFile, p.join(d.path, 'client_secret.json'));
    expect(s.privacy, 'private');
    expect(s.rules, ['book', 'year']);
    expect(s.template, contains('{skriflesing}'));
    expect(s.outDir, endsWith(p.join('Videos', 'Preke')));
    expect(s.setupDone, isFalse);
    s
      ..privacy = 'unlisted'
      ..rules = ['year']
      ..outDir = '/x/y'
      ..setupDone = true
      ..save();
    final again = AppSettings.load(d);
    expect(again.privacy, 'unlisted');
    expect(again.rules, ['year']);
    expect(again.outDir, '/x/y');
    expect(again.setupDone, isTrue);
    expect(File(p.join(d.path, 'settings.json')).existsSync(), isTrue);
    d.deleteSync(recursive: true);
  });

  test('an unreadable settings.json gives the defaults', () {
    final d = Directory.systemTemp.createTempSync('set');
    File(p.join(d.path, 'settings.json')).writeAsStringSync('');
    expect(AppSettings.load(d).privacy, 'private');
    d.deleteSync(recursive: true);
  });

  test('channelUrl defaults to the church channel and survives a save', () {
    final d = Directory.systemTemp.createTempSync('set');
    final s = AppSettings.load(d);
    expect(s.channelUrl, kChannelUrl);
    s
      ..channelUrl = 'https://www.youtube.com/@ander'
      ..save();
    expect(AppSettings.load(d).channelUrl, 'https://www.youtube.com/@ander');
    d.deleteSync(recursive: true);
  });

  test('a channelUrl that is not a channel never reaches yt-dlp', () {
    final d = Directory.systemTemp.createTempSync('set');
    File(p.join(d.path, 'settings.json'))
        .writeAsStringSync('{"channelUrl": "--exec=x"}');
    expect(AppSettings.load(d).channelUrl, kChannelUrl);
    File(p.join(d.path, 'settings.json'))
        .writeAsStringSync('{"channelUrl": "youtube.com/@ander/videos"}');
    expect(AppSettings.load(d).channelUrl, 'https://www.youtube.com/@ander');
    d.deleteSync(recursive: true);
  });
}

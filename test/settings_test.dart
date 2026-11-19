import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/settings.dart';

void main() {
  test('defaults, then a round trip through settings.json', () {
    final d = Directory.systemTemp.createTempSync('set');
    final s = AppSettings.load(d);
    expect(s.clientFile, p.join(d.path, 'client_secret.json'));
    expect(s.privacy, 'private');
    expect(s.rules, ['book', 'year']);
    expect(s.template, contains('{skriflesing}'));
    s
      ..privacy = 'unlisted'
      ..rules = ['year']
      ..save();
    final again = AppSettings.load(d);
    expect(again.privacy, 'unlisted');
    expect(again.rules, ['year']);
    expect(File(p.join(d.path, 'settings.json')).existsSync(), isTrue);
    d.deleteSync(recursive: true);
  });
}

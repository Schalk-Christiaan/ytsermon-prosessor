import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/tools.dart';

void main() {
  test('findExecutable: empty PATH gives null, PATH dir is found', () {
    final dir = Directory.systemTemp.createTempSync('tools');
    final name = Platform.isWindows ? 'faketool.exe' : 'faketool';
    File(p.join(dir.path, name)).writeAsStringSync('x');
    expect(findExecutable('faketool', path: ''), isNull);
    expect(findExecutable('faketool', path: dir.path), p.join(dir.path, name));
    dir.deleteSync(recursive: true);
  });
}

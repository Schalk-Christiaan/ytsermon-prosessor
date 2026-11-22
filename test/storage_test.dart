// Step 6: folder sizes per sermon and the South African size format.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/storage.dart';

void main() {
  test('dirSize: empty, one file, nested, missing', () async {
    final root = Directory.systemTemp.createTempSync('sz');
    addTearDown(() => root.deleteSync(recursive: true));
    final d = Directory(p.join(root.path, 'a'))..createSync();
    expect(await dirSize(d), 0);
    File(p.join(d.path, 'x.mp4')).writeAsBytesSync(List.filled(1000, 1));
    expect(await dirSize(d), 1000);
    Directory(p.join(d.path, 'shorts', 'deep')).createSync(recursive: true);
    File(p.join(d.path, 'shorts', 'deep', 'y.mp4')).writeAsBytesSync([1, 2, 3]);
    expect(await dirSize(d), 1003);
    expect(await dirSize(Directory(p.join(root.path, 'weg'))), 0);
    expect(await sermonSizes(root, ['a', 'weg']), {'a': 1003, 'weg': 0});
  });

  test('formatBytes: decimal comma, no-break space', () {
    expect(formatBytes(1420000000), '1,42 GB');
    expect(formatBytes(86000000), '86 MB');
    expect(formatBytes(10300000000), '10,3 GB');
    expect(formatBytes(512), '512 B');
    expect(formatBytes(0), '0 B');
  });
}

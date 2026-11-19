import 'dart:async';
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
  runToolTests();
}

void runToolTests() {
  final sh = Platform.isWindows ? null : '/bin/sh';

  test('runTool: stdout lines go to onLine', () async {
    final lines = <String>[];
    await runTool(sh!, ['-c', 'echo a; echo b'], onLine: lines.add);
    expect(lines, ['a', 'b']);
  }, skip: sh == null);

  test('runTool: non-zero exit throws ProcessException with stderr', () async {
    await expectLater(
      runTool(sh!, ['-c', 'echo oeps >&2; exit 3']),
      throwsA(
        isA<ProcessException>()
            .having((e) => e.errorCode, 'code', 3)
            .having((e) => e.message, 'message', contains('oeps')),
      ),
    );
  }, skip: sh == null);

  test('runTool: cancel kills the process and throws JobCancelled', () async {
    final c = Completer<void>();
    final sw = Stopwatch()..start();
    final f = runTool(sh!, ['-c', 'sleep 30'], cancel: c.future);
    Future.delayed(const Duration(milliseconds: 200), c.complete);
    await expectLater(f, throwsA(isA<JobCancelled>()));
    expect(sw.elapsed, lessThan(const Duration(seconds: 10)));
  }, skip: sh == null);

  test('runTool: cancel also kills the process children', () async {
    final c = Completer<void>();
    // A unique duration so no other sleep in `ps` is mistaken for ours.
    final f = runTool(sh!, ['-c', 'sleep 37 & wait'], cancel: c.future);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    c.complete();
    await expectLater(f, throwsA(isA<JobCancelled>()));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    final ps = await Process.run('pgrep', ['-f', 'sleep 37']);
    expect(ps.stdout.toString().trim(), isEmpty);
  }, skip: sh == null);

  test('runTool: ProcessException carries all of stderr', () async {
    await expectLater(
      runTool(sh!, ['-c', 'head -c 100000 /dev/zero | tr "\\0" x >&2; exit 1']),
      throwsA(
        isA<ProcessException>().having((e) => e.message.length, 'len', 100000),
      ),
    );
  }, skip: sh == null);
}

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/features/review/review_controller.dart';

ReviewController _ready(
  Directory dir,
  Future<File> Function(FetchedMeta, {void Function(double)? onProgress}) dl,
  Stream<Duration>? positions,
) {
  final c = ReviewController(
    download: dl,
    openVideo: (_) async {},
    positions: positions,
  );
  c.debugReady(
    FetchedMeta('x', dir, {}),
    [],
    SermonPlan(
      sermonStart: 0,
      sermonEnd: 100,
      title: 't',
      description: '',
      shorts: [],
    ),
    100,
  );
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  test('repeated downloads keep one position subscription', () async {
    final dir = Directory.systemTemp.createTempSync();
    var listens = 0;
    final positions = Stream<Duration>.multi((_) => listens++);
    final c = _ready(dir, (m, {onProgress}) async => File('v.mp4'), positions);
    c.setManually();
    await c.downloadFuture;
    c.reset();
    c.debugReady(
      FetchedMeta('x', dir, {}),
      [],
      c.plan ??
          SermonPlan(
            sermonStart: 0,
            sermonEnd: 100,
            title: 't',
            description: '',
            shorts: [],
          ),
      100,
    );
    c.setManually();
    await c.downloadFuture;
    expect(listens, 1);
  });

  test('a download error leaves no unhandled async error', () async {
    final dir = Directory.systemTemp.createTempSync();
    final c = _ready(dir, (m, {onProgress}) async => throw 'stuk', null);
    c.setManually();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(c.error, 'stuk');
    // approveAndCut still sees the failure when it awaits the download.
    await expectLater(c.downloadFuture, throwsA('stuk'));
  });
}

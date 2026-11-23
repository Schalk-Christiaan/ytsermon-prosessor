import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/tools.dart';
import 'package:preekverwerker/features/settings/system_status.dart';

import 'screen_kit.dart';

void main() {
  for (final (enc, text) in [
    ('h264_nvenc', 'GPU (NVENC)'),
    ('libx264', 'CPU (libx264)'),
  ]) {
    testWidgets('Stelsel shows the video encoder: $text', (t) async {
      await loadFonts();
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Scaffold(
            body: SystemStatus(
              probe: () async => [ToolStatus('encoder', true, enc)],
            ),
          ),
        ),
      );
      await t.pump();
      expect(find.text('Video-enkodering'), findsOneWidget);
      expect(find.text(text), findsOneWidget);
    });
  }
}

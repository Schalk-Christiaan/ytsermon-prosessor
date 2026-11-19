import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/tools.dart';

void main() {
  group('friendlyError', () {
    const disk =
        'Die skyf is vol. Maak plek (ou video\'s in die werkgids) en probeer weer.';
    const net = 'Geen internet nie. Kyk die netwerk en probeer weer.';
    test('Ollama only for its own port', () {
      final port = ollamaBase().port;
      expect(
        friendlyError(SocketException('x', port: port)),
        startsWith('Ollama'),
      );
      expect(
        friendlyError(const HttpException('Ollama 500: boom')),
        startsWith('Ollama'),
      );
      expect(friendlyError(const SocketException('x', port: 443)), net);
      expect(friendlyError(const HandshakeException('tls')), net);
    });
    test('a full disk, from Dart or from a tool', () {
      expect(
        friendlyError(
          const FileSystemException('w', 'f', OSError('No space', 28)),
        ),
        disk,
      );
      expect(
        friendlyError(const FileSystemException('w', 'f', OSError('vol', 112))),
        disk,
      );
      expect(
        friendlyError(
          ProcessException('ffmpeg', [], 'x: No space left on device', 1),
        ),
        disk,
      );
    });
    test('yt-dlp without a network', () {
      expect(
        friendlyError(
          ProcessException(
            'yt-dlp',
            [],
            'ERROR: Unable to download webpage: <urlopen error [Errno -3] Temporary failure in name resolution>',
            1,
          ),
        ),
        net,
      );
    });
  });
}

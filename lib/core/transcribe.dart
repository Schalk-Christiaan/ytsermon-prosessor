// @stelsel transcribe
//   soort: module
//   wanneer: as 'n video geen af-orig-onderskrifte het nie, of as Schalk in Hersien plaaslik wil transkribeer
//   groep: core | Kern
//   skryf: <id>/<id>.local.json3
//   doel: ffmpeg maak 16 kHz mono WAV, whisper-cli (whisper.cpp, taal af) transkribeer dit, die JSON word json3 in YouTube se vorm sodat captions/bounds/planner onveranderd werk
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'tools.dart';

final _special = RegExp(r'^(\[_[^\]]*\]|<\|.*\|>)$');
final _progress = RegExp(r'progress =\s*(\d+)%');

/// Converts whisper.cpp's `-ojf` JSON into YouTube-style json3 (so `parseJson3` reads it): one event per
/// segment, one `segs` piece per word (a token that starts with a space starts a word) with its offset.
/// A segment equal to the previous two is dropped: whisper loops on music and silence.
String whisperToJson3(String whisperJson) {
  final events = <Map<String, Object>>[];
  final seen = <String>[];
  for (final s in (jsonDecode(whisperJson)['transcription'] as List)) {
    final text = (s['text'] as String).trim();
    if (text.isEmpty) continue;
    if (seen.length >= 2 &&
        seen[seen.length - 1] == text &&
        seen[seen.length - 2] == text) {
      continue;
    }
    seen.add(text);
    final from = (s['offsets']['from'] as num).toInt();
    final words = <(int, StringBuffer)>[];
    for (final t in (s['tokens'] as List)) {
      final piece = t['text'] as String;
      if (_special.hasMatch(piece)) continue;
      if (words.isEmpty || piece.startsWith(' ')) {
        words.add(((t['offsets']['from'] as num).toInt(), StringBuffer()));
      }
      words.last.$2.write(piece.trimLeft());
    }
    events.add({
      'tStartMs': from,
      'dDurationMs': (s['offsets']['to'] as num).toInt() - from,
      'segs': [
        for (var i = 0; i < words.length; i++)
          {
            'utf8': '${i == 0 ? '' : ' '}${words[i].$2}',
            'tOffsetMs': words[i].$1 - from,
          },
      ],
    });
  }
  return jsonEncode({'events': events});
}

/// Transcribes [video] in Afrikaans with whisper.cpp and writes json3 to [out]; [onProgress] gets 0..1
/// from whisper's `-pp` output. [whisper] defaults to `whisper-cli` found like the other tools; throws
/// [StateError] when it or the [model] is missing. No `--prompt`: it made whisper loop (navorsing/2026-11-22).
Future<File> transcribeLocal(
  File video,
  File out, {
  required File model,
  String? whisper,
  void Function(double frac)? onProgress,
  Future<void>? cancel,
  void Function(String line)? log,
}) async {
  final exe = whisper ?? findExecutable('whisper-cli');
  if (exe == null) throw StateError('whisper-cli ontbreek');
  if (!model.existsSync()) throw StateError('Spraakmodel ontbreek');
  final base = p.join(out.parent.path, p.basenameWithoutExtension(out.path));
  final wav = File('$base.wav'), json = File('$base.wav.json');
  try {
    await runTool(ffmpegTool, [
      '-y', '-v', 'error', '-i', video.path, '-vn', '-ar', '16000', '-ac', '1',
      '-c:a', 'pcm_s16le', wav.path, //
    ], cancel: cancel);
    await runTool(
      exe,
      [
        '-m',
        model.path,
        '-l',
        'af',
        '-ojf',
        '-pp',
        '-of',
        wav.path,
        '-f',
        wav.path,
      ],
      cancel: cancel,
      onLine: log,
      onErr: (c) {
        for (final m in _progress.allMatches(c)) {
          onProgress?.call(int.parse(m.group(1)!) / 100);
        }
      },
    );
    out.writeAsStringSync(whisperToJson3(json.readAsStringSync()));
    return out;
  } finally {
    for (final f in [wav, json]) {
      if (f.existsSync()) f.deleteSync();
    }
  }
}

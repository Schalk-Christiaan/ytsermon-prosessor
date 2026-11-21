// @stelsel sound
//   soort: module
//   wanneer: in planJob, ná die aflaai (die video is nodig)
//   groep: core | Kern
//   skryf: <werkmap>/<id>/sound.json | die klas van elke sekonde (stilte/musiek/spraak/geraas)
//   doel: een ffmpeg-proses gee 16 kHz-PCM; Dart bereken per sekonde lae-energie-rame, platheid en dB en klassifiseer in stilte/musiek/spraak/geraas (spektrogram, nie YouTube se [musiek]-merkers nie)
//   status: bou
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'tools.dart';

// Thresholds from navorsing/2026-11-21-spektrogram-spraak-musiek.md (4 services, one set for all).
/// Below this level (dB, 2 s window) a second is silence.
const kSilenceDb = -60.0;

/// From this share of low-energy frames (RMS < half the window mean) a second is speech; music is ~0.
const kSpeechLef = 0.15;

/// Below this spectral flatness (100-4000 Hz) a second is music; speech is 0.1-0.3.
const kMusicFlat = 0.06;

/// Median window (seconds) over the per-second features.
const _smooth = 9;

/// A run shorter than this (seconds) is merged into the one before it.
const kMinRun = 10;

const _hop = 160, _win = 400, _fft = 512;

/// ffmpeg arguments that write [video]'s sound as 16 kHz mono s16le PCM to stdout.
List<String> soundArgs(String video) => [
  '-hide_banner',
  '-nostats',
  '-i',
  video,
  '-vn',
  '-ac',
  '1',
  '-ar',
  '16000',
  '-f',
  's16le',
  '-',
];

/// Per-second features over a centred 2 s window: level in dB, share of low-energy frames, spectral flatness.
class SoundFeatures {
  const SoundFeatures(this.db, this.lef, this.flat);
  final List<double> db, lef, flat;
}

final _hann = Float64List.fromList([
  for (var k = 0; k < _win; k++)
    0.5 - 0.5 * math.cos(2 * math.pi * k / (_win - 1)),
]);
final _cos = Float64List.fromList([
  for (var k = 0; k < _fft ~/ 2; k++) math.cos(-2 * math.pi * k / _fft),
]);
final _sinT = Float64List.fromList([
  for (var k = 0; k < _fft ~/ 2; k++) math.sin(-2 * math.pi * k / _fft),
]);
final _rev = Int32List.fromList([
  for (var i = 0; i < _fft; i++)
    int.parse(
      i.toRadixString(2).padLeft(9, '0').split('').reversed.join(),
      radix: 2,
    ),
]);

/// In-place radix-2 FFT of [re]/[im] (length 512).
void _fftInPlace(Float64List re, Float64List im) {
  for (var i = 0; i < _fft; i++) {
    final j = _rev[i];
    if (j > i) {
      final a = re[i], b = im[i];
      re[i] = re[j];
      im[i] = im[j];
      re[j] = a;
      im[j] = b;
    }
  }
  for (var len = 2; len <= _fft; len <<= 1) {
    final half = len >> 1, step = _fft ~/ len;
    for (var s = 0; s < _fft; s += len) {
      for (var k = 0; k < half; k++) {
        final c = _cos[k * step], sn = _sinT[k * step];
        final a = s + k, b = a + half;
        final tr = re[b] * c - im[b] * sn, ti = re[b] * sn + im[b] * c;
        re[b] = re[a] - tr;
        im[b] = im[a] - ti;
        re[a] += tr;
        im[a] += ti;
      }
    }
  }
}

/// Reads s16le PCM (16 kHz mono) as it streams and returns the per-second [SoundFeatures]:
/// 10 ms hop, 25 ms Hann frames; flatness = geometric/arithmetic mean of the power in bins 3-127 (100-4000 Hz).
Future<SoundFeatures> soundFeatures(Stream<List<int>> pcm) async {
  final rms = <double>[], flat = <double>[];
  final re = Float64List(_fft), im = Float64List(_fft);
  var carry = Float64List(0); // samples not yet consumed by a whole frame
  var odd = <int>[]; // a trailing half sample
  await for (final chunk in pcm) {
    final bytes = Uint8List.fromList([...odd, ...chunk]);
    final n = bytes.length ~/ 2;
    odd = bytes.length.isOdd ? [bytes.last] : [];
    final bd = ByteData.sublistView(bytes);
    final x = Float64List(carry.length + n)..setAll(0, carry);
    for (var i = 0; i < n; i++) {
      x[carry.length + i] = bd.getInt16(i * 2, Endian.little) / 32768;
    }
    var p = 0;
    for (; p + _win <= x.length; p += _hop) {
      var sq = 0.0;
      for (var i = 0; i < _win; i++) {
        sq += x[p + i] * x[p + i];
        re[i] = x[p + i] * _hann[i];
        im[i] = 0;
      }
      for (var i = _win; i < _fft; i++) {
        re[i] = 0;
        im[i] = 0;
      }
      _fftInPlace(re, im);
      var sumLog = 0.0, sum = 0.0;
      for (var k = 3; k < 128; k++) {
        final pw = re[k] * re[k] + im[k] * im[k] + 1e-12;
        sumLog += math.log(pw);
        sum += pw;
      }
      rms.add(math.sqrt(sq / _win));
      flat.add(math.exp(sumLog / 125) / (sum / 125));
    }
    carry = Float64List.sublistView(x, p);
  }
  final secs = rms.length ~/ 100;
  final db = <double>[], lef = <double>[], fl = <double>[];
  for (var i = 0; i < secs; i++) {
    final a = math.max(0, i * 100 - 50), b = math.min(rms.length, a + 200);
    var mean = 0.0, fsum = 0.0;
    for (var k = a; k < b; k++) {
      mean += rms[k];
      fsum += flat[k];
    }
    mean /= b - a;
    var low = 0;
    for (var k = a; k < b; k++) {
      if (rms[k] < 0.5 * mean) low++;
    }
    db.add(20 * math.log(mean + 1e-9) / math.ln10);
    lef.add(low / (b - a));
    fl.add(fsum / (b - a));
  }
  return SoundFeatures(db, lef, fl);
}

/// Runs ffmpeg once over [video] and returns its [SoundFeatures]; [cancel] kills ffmpeg.
Future<SoundFeatures> analyseSound(String video, {Future<void>? cancel}) async {
  final exe = findExecutable('ffmpeg');
  if (exe == null) throw StateError('ffmpeg ontbreek');
  final proc = await Process.start(exe, soundArgs(video));
  var cancelled = false;
  cancel?.then((_) {
    cancelled = true;
    proc.kill();
  });
  proc.stderr.drain<void>();
  final f = await soundFeatures(proc.stdout);
  final code = await proc.exitCode;
  if (cancelled) throw JobCancelled();
  if (code != 0) throw ProcessException('ffmpeg', soundArgs(video), '', code);
  return f;
}

double _median(List<double> v, int i) {
  final w = v.sublist(
    math.max(0, i - _smooth ~/ 2),
    math.min(v.length, i + _smooth ~/ 2 + 1),
  )..sort();
  return w.length.isOdd
      ? w[w.length ~/ 2]
      : (w[w.length ~/ 2 - 1] + w[w.length ~/ 2]) / 2;
}

/// Labels each second (median over 9 s: `db < -60` silence; `lef >= .15` speech; `flat < .06` music; else noise)
/// and merges runs shorter than [kMinRun] seconds into the previous one. Times in whole seconds.
List<TimeBlock> classify(SoundFeatures f) {
  final lab = [
    for (var i = 0; i < f.db.length; i++)
      _median(f.db, i) < kSilenceDb
          ? SegmentKind.silence
          : _median(f.lef, i) >= kSpeechLef
          ? SegmentKind.speech
          : _median(f.flat, i) < kMusicFlat
          ? SegmentKind.music
          : SegmentKind.noise,
  ];
  final runs = <(int, int, SegmentKind)>[];
  for (var i = 0; i < lab.length; i++) {
    if (runs.isNotEmpty && runs.last.$3 == lab[i]) {
      runs.last = (runs.last.$1, i + 1, lab[i]);
    } else {
      runs.add((i, i + 1, lab[i]));
    }
  }
  final out = <(int, int, SegmentKind)>[];
  for (final r in runs) {
    if (out.isNotEmpty && (r.$2 - r.$1 < kMinRun || out.last.$3 == r.$3)) {
      out.last = (out.last.$1, r.$2, out.last.$3);
    } else {
      out.add(r);
    }
  }
  return [
    for (final r in out) TimeBlock(r.$1.toDouble(), r.$2.toDouble(), r.$3),
  ];
}

/// File in the work folder that holds the classified [TimeBlock]s of the service.
const kSoundFile = 'sound.json';

/// Writes the classified blocks to [kSoundFile] in [dir].
void saveSound(Directory dir, List<TimeBlock> blocks) =>
    File(p.join(dir.path, kSoundFile)).writeAsStringSync(
      jsonEncode([
        for (final b in blocks)
          {'start': b.start, 'end': b.end, 'kind': b.kind.name},
      ]),
    );

/// The saved sound blocks of the work folder [dir]; empty when the video was never analysed.
List<TimeBlock> loadSound(Directory dir) {
  final f = File(p.join(dir.path, kSoundFile));
  if (!f.existsSync()) return [];
  return [
    for (final j in jsonDecode(f.readAsStringSync()) as List)
      TimeBlock(
        (j['start'] as num).toDouble(),
        (j['end'] as num).toDouble(),
        SegmentKind.values.byName(j['kind'] as String),
      ),
  ];
}

// stap: diensindeling 1 Klank | een ffmpeg-proses lees die klank, Dart klassifiseer elke sekonde as stilte/musiek/spraak/geraas; die uitslag word in sound.json bewaar
/// The sound blocks of [video], analysed once and cached in [dir] as [kSoundFile].
Future<List<TimeBlock>> soundBlocks(
  Directory dir,
  File video, {
  Future<void>? cancel,
}) async {
  final saved = loadSound(dir);
  if (saved.isNotEmpty) return saved;
  final b = classify(await analyseSound(video.path, cancel: cancel));
  saveSound(dir, b);
  return b;
}

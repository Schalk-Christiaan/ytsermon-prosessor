// @stelsel captions
//   soort: module
//   wanneer: ná fetchMeta
//   groep: core | Kern
//   skryf: —
//   doel: json3-onderskrifte → segmente met woordtye, kompakte teks vir die KI, spraakblokke (pouse/Amen/musiek), SRT
//   status: bou
import 'dart:convert';
import 'dart:math' as math;

import 'models.dart';

final _musicTag = RegExp(r'^(?:\[(?:musiek|sang)\])+$', caseSensitive: false);

/// Parses YouTube json3 captions into segments; `\n` separator events are dropped and a line
/// ends where the next line starts (roll-up captions overlap).
List<Segment> parseJson3(String raw) {
  final events = (jsonDecode(raw)['events'] as List)
      .cast<Map<String, dynamic>>();
  final lines = <(double, double, String, List<(double, String)>)>[];
  for (final e in events) {
    final segs = e['segs'] as List?;
    if (segs == null) continue;
    final text = segs
        .map((s) => s['utf8'] as String)
        .join()
        .replaceAll('\n', ' ')
        .trim();
    if (text.isEmpty) continue;
    final start = (e['tStartMs'] as num) / 1000;
    final dur = ((e['dDurationMs'] ?? 0) as num) / 1000;
    final parts = [
      for (final s in segs)
        (start + ((s['tOffsetMs'] ?? 0) as num) / 1000, s['utf8'] as String),
    ];
    lines.add((start, start + dur, text, parts));
  }
  return [
    for (var i = 0; i < lines.length; i++)
      () {
        final end = i + 1 < lines.length && lines[i + 1].$1 < lines[i].$2
            ? lines[i + 1].$1
            : lines[i].$2;
        final music = _musicTag.hasMatch(lines[i].$3);
        return Segment(
          lines[i].$1,
          end,
          lines[i].$3,
          kind: music ? SegmentKind.music : SegmentKind.speech,
          words: music ? const [] : _words(lines[i].$4, end),
        );
      }(),
  ];
}

/// Words with their own times: each caption piece starts at its `tOffsetMs`; a piece that holds several
/// words (older recordings have no word times) is spread over its span by length. The speaker-change
/// marker `>>` is no word.
List<Word> _words(List<(double, String)> parts, double lineEnd) {
  final out = <Word>[];
  for (var i = 0; i < parts.length; i++) {
    final tokens = parts[i].$2
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t != '>>')
        .toList();
    final from = parts[i].$1;
    final to = i + 1 < parts.length ? parts[i + 1].$1 : lineEnd;
    final total = tokens.join().length;
    var done = 0;
    for (final t in tokens) {
      final a = from + (to - from) * done / total;
      done += t.length;
      out.add(Word(a, from + (to - from) * done / total, t));
    }
  }
  return out;
}

/// `mm:ss` (minutes may exceed 59), the format of the captions and the timeline labels.
String formatTime(double s) {
  final t = s.floor();
  return '${(t ~/ 60).toString().padLeft(2, '0')}:${(t % 60).toString().padLeft(2, '0')}';
}

/// Groups captions per [window] seconds as `[mm:ss] text` lines for the LLM; a music run becomes one `[musiek]`.
String compact(List<Segment> segs, {double window = 30}) {
  final out = StringBuffer();
  int? group;
  var firstOnLine = true;
  var prevMusic = false;
  for (final s in segs) {
    final g = s.start ~/ window;
    if (g != group) {
      if (group != null) out.write('\n');
      out.write('[${formatTime(s.start)}]');
      group = g;
      prevMusic = false;
    }
    final music = s.kind == SegmentKind.music;
    if (music && prevMusic) continue;
    out.write(music ? ' [musiek]' : ' ${s.text}');
    prevMusic = music;
    firstOnLine = false;
  }
  return firstOnLine ? '' : out.toString();
}

List<String> _wrap(String text, int max) {
  final lines = <String>[];
  var cur = '';
  for (final w in text.split(RegExp(r'\s+'))) {
    if (cur.isEmpty) {
      cur = w;
    } else if (cur.length + 1 + w.length <= max) {
      cur = '$cur $w';
    } else {
      lines.add(cur);
      cur = w;
    }
  }
  if (cur.isNotEmpty) lines.add(cur);
  return lines;
}

String _ts(double s) {
  final ms = (s * 1000).round();
  String p(int n, int w) => n.toString().padLeft(w, '0');
  return '${p(ms ~/ 3600000, 2)}:${p(ms ~/ 60000 % 60, 2)}:${p(ms ~/ 1000 % 60, 2)},${p(ms % 1000, 3)}';
}

/// SRT for the clip [from, to] with times relative to [from]; blocks are <=2 lines of <=42 chars,
/// splitting a caption's time by character count. Music markers are skipped.
String toSrt(List<Segment> segs, double from, double to) {
  final out = StringBuffer();
  var n = 0;
  for (final s in segs) {
    if (s.kind == SegmentKind.music || s.end <= from || s.start >= to) continue;
    final lines = _wrap(s.text, 42);
    final blocks = [
      for (var i = 0; i < lines.length; i += 2)
        lines.sublist(i, i + 2 > lines.length ? lines.length : i + 2),
    ];
    final total = lines.join().length;
    final a = s.start.clamp(from, to);
    final b = s.end.clamp(from, to);
    var t = a;
    for (final bl in blocks) {
      final end = t + (b - a) * bl.join().length / total;
      out.write(
        '${++n}\n${_ts(t - from)} --> ${_ts(end - from)}\n${bl.join('\n')}\n\n',
      );
      t = end;
    }
  }
  return out.toString();
}

final _amen = RegExp(r'^amen[.!,]*$', caseSensitive: false);

/// Whether a caption word is "Amen".
bool isAmen(String word) => _amen.hasMatch(word);

/// The words of a segment: its caption word times, or its text spread over the line.
List<Word> wordsOf(Segment s) =>
    s.words.isNotEmpty ? s.words : _words([(s.start, s.text)], s.end);

/// Spoken length of "Amen", since a word ends where the next starts and the pause after it is not speech.
const kAmenLength = 0.7;

/// Longest spoken length of one word; a word ends where the next starts, so a pause shows only as a long gap.
const kMaxWordLength = 1.0;

/// A gap of this many seconds between one word's spoken end ([kMaxWordLength] at most) and the next word's
/// start ends a block. Real pauses are shorter than the gap: 2 s gave 87 blocks for YWz5gf0onjk, 3 s gives ~39.
const kBlockPause = 3.0;

double _spokenEnd(Word w) =>
    w.start +
    math.min(w.end - w.start, isAmen(w.text) ? kAmenLength : kMaxWordLength);

// stap: diensindeling 2 Spraakblokke | die woorde word gesny by musiek, 'n pouse van 3 s en "Amen"; elke blok kry later 'n etiket
/// Cuts the spoken words into blocks: a new block after a pause of [kBlockPause] seconds, after an "Amen",
/// and around every music stretch of [sound] (words inside music are dropped: that is singing).
/// Caption sound tags (`[geproes]`) are no words.
List<Block> blocks(List<Segment> segs, List<TimeBlock> sound) {
  final music = [
    for (final b in sound)
      if (b.kind == SegmentKind.music) b,
  ];
  final out = <Block>[];
  var cur = <Word>[];
  void close() {
    if (cur.isNotEmpty) out.add(Block(cur, _spokenEnd(cur.last)));
    cur = [];
  }

  for (final s in segs) {
    if (s.kind == SegmentKind.music) continue;
    var inTag = false;
    for (final w in wordsOf(s)) {
      if (w.text.startsWith('[')) inTag = true;
      final tag = inTag;
      if (w.text.endsWith(']')) inTag = false;
      if (tag) continue;
      if (music.any((b) => w.start >= b.start && w.start < b.end)) {
        close();
        continue;
      }
      if (cur.isNotEmpty) {
        final pause = w.start - _spokenEnd(cur.last) >= kBlockPause;
        final crosses = music.any(
          (b) => b.start >= cur.last.start && b.start < w.start,
        );
        if (pause || crosses || isAmen(cur.last.text)) close();
      }
      cur.add(w);
    }
  }
  close();
  return out;
}

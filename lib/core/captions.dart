// @stelsel captions
//   soort: module
//   wanneer: ná fetchMeta
//   groep: core | Kern
//   skryf: —
//   doel: json3-onderskrifte → segmente met woordtye, kompakte teks vir die KI, kandidaat-gebede (preekgrense), SRT en dienstydlyn (spraak/musiek)
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

/// Merges captions into speech/music blocks (gaps up to [gap] seconds are bridged) for the service timeline.
List<TimeBlock> timeline(List<Segment> segs, {double gap = 10}) {
  final out = <TimeBlock>[];
  for (final s in segs) {
    if (out.isNotEmpty &&
        out.last.kind == s.kind &&
        s.start - out.last.end <= gap) {
      final l = out.removeLast();
      out.add(TimeBlock(l.start, s.end > l.end ? s.end : l.end, l.kind));
    } else {
      out.add(TimeBlock(s.start, s.end, s.kind));
    }
  }
  return out;
}

final _amen = RegExp(r'^amen[.!,]*$', caseSensitive: false);

/// Whether a caption word is "Amen".
bool isAmen(String word) => _amen.hasMatch(word);

/// Words that open a prayer: an invitation ("Kom ons bid", "Laat ons saam dank") or an
/// address to God; matched against the words from one position on.
final _prayerCue = RegExp(
  r'^(?:(?:kom|laat)\s+ons\b.{0,20}\b(?:bid|dank)|(?:onse?|o|hemelse|liewe|heilige|regverdige)\s+vader\b|o\s+here\b|here\s+onse\s+here\b|ons\s+almagtige\b|almagtige\b|genadige\b)',
  caseSensitive: false,
);

/// Longest stretch counted as one prayer; a longer "cue … Amen" run is sermon text.
const kMaxPrayer = 15 * 60.0;

/// Shortest stretch counted as a prayer: the seëngroet, geloofsbelydenis and short formulas end in
/// "Amen" too but run under ~30 s, while the prayers around the sermon run 1-9 min.
const kMinPrayer = 45.0;

/// The words of a segment: its caption word times, or its text spread over the line.
List<Word> wordsOf(Segment s) =>
    s.words.isNotEmpty ? s.words : _words([(s.start, s.text)], s.end);

/// A cue only counts at the start of a sentence or after a pause (a line break, music): the creed's
/// "…die Vader, die Almagtige" and "dan saam bid. Nou eerst Psalm" are no prayers.
bool _endsSentence(Word prev, Word w) =>
    RegExp(r'[.!?]$').hasMatch(prev.text) || w.start - prev.end >= 1.0;

/// Spoken length of "Amen", since a word ends where the next starts and the pause after it is not speech.
const kAmenLength = 0.7;

/// Candidate prayers on word level: a prayer runs from the first word of its cue to the end of the
/// "Amen" word; the captions are split at each "Amen". Music lines are skipped.
List<Prayer> prayers(List<Segment> segs) {
  final w = [
    for (final s in segs)
      if (s.kind != SegmentKind.music) ...wordsOf(s),
  ];
  final out = <Prayer>[];
  int? from;
  for (var i = 0; i < w.length; i++) {
    if (_amen.hasMatch(w[i].text)) {
      final a = from;
      final end = w[i].start + math.min(kAmenLength, w[i].end - w[i].start);
      if (a != null &&
          end - w[a].start >= kMinPrayer &&
          end - w[a].start <= kMaxPrayer) {
        final text = [for (var k = a; k <= i; k++) w[k].text];
        String take(Iterable<String> t) => t.join(' ');
        out.add(
          Prayer(
            w[a].start,
            end,
            take(text.take(12)),
            take(text.skip(text.length > 12 ? text.length - 12 : 0)),
          ),
        );
      }
      from = null;
    } else if (from == null &&
        (i == 0 || _endsSentence(w[i - 1], w[i])) &&
        _prayerCue.hasMatch(
          [for (var k = i; k < w.length && k < i + 8; k++) w[k].text].join(' '),
        )) {
      from = i;
    }
  }
  return out;
}

// @stelsel captions
//   soort: module
//   wanneer: ná fetchMeta
//   groep: core | Kern
//   skryf: —
//   doel: json3-onderskrifte → segmente, kompakte teks vir die KI, kandidaat-gebede (preekgrense), SRT en dienstydlyn (spraak/musiek)
//   status: oop
import 'dart:convert';

import 'models.dart';

final _musicTag = RegExp(r'^(?:\[(?:musiek|sang)\])+$', caseSensitive: false);

/// Parses YouTube json3 captions into segments; `\n` separator events are dropped and a line
/// ends where the next line starts (roll-up captions overlap).
List<Segment> parseJson3(String raw) {
  final events = (jsonDecode(raw)['events'] as List)
      .cast<Map<String, dynamic>>();
  final lines = <(double, double, String)>[];
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
    lines.add((start, start + dur, text));
  }
  return [
    for (var i = 0; i < lines.length; i++)
      Segment(
        lines[i].$1,
        i + 1 < lines.length && lines[i + 1].$1 < lines[i].$2
            ? lines[i + 1].$1
            : lines[i].$2,
        lines[i].$3,
        kind: _musicTag.hasMatch(lines[i].$3)
            ? SegmentKind.music
            : SegmentKind.speech,
      ),
  ];
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

final _amen = RegExp(r'\bamen\b[.!,]*', caseSensitive: false);

/// Words that open a prayer: an invitation ("Kom ons bid", "Laat ons saam dank") or an address to God.
final _prayerCue = RegExp(
  r'^(?:>>\s*)?(?:(?:kom|laat)\s+ons\b.{0,20}\b(?:bid|dank)|(?:onse?|o|hemelse|liewe|heilige)\s+vader\b|o\s+here\b|almagtige\b|genadige\b)',
  caseSensitive: false,
);

/// Longest stretch counted as one prayer; a longer "cue … Amen" run is sermon text.
const kMaxPrayer = 15 * 60.0;

/// Candidate prayers: the captions are split into chunks that each end at an "Amen" (text after the
/// Amen on the same line starts the next chunk); a chunk with a prayer cue is a prayer from its first
/// cue to the end of the Amen line.
List<Prayer> prayers(List<Segment> segs) {
  final out = <Prayer>[];
  final words = <String>[];
  double? start;
  void cue(double t, String text) {
    if (start == null && _prayerCue.hasMatch(text)) start = t;
    if (start != null) words.add(text);
  }

  for (final s in segs) {
    if (s.kind == SegmentKind.music) continue;
    final m = _amen.firstMatch(s.text);
    if (m == null) {
      cue(s.start, s.text);
      continue;
    }
    final before = s.text.substring(0, m.end).trim();
    if (start == null) {
      cue(s.start, before); // "O Here … Amen" on one line
    } else {
      words.add(before);
    }
    final a = start;
    if (a != null && s.end - a <= kMaxPrayer) {
      final text = words.join(' ').split(RegExp(r'\s+'));
      String take(Iterable<String> w) => w.join(' ');
      out.add(
        Prayer(
          a,
          s.end,
          take(text.take(12)),
          take(text.skip(text.length > 12 ? text.length - 12 : 0)),
        ),
      );
    }
    start = null;
    words.clear();
    final rest = s.text.substring(m.end).trim();
    if (rest.isNotEmpty) cue(s.start, rest);
  }
  return out;
}

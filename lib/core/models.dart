// @stelsel models
//   soort: module
//   wanneer: oral waar 'n plan gebruik word
//   groep: core | Kern
//   skryf: —
//   doel: Word, Segment (met woordtye), TimeBlock, Block/BlockLabel (spraakblok met etiket), Song, Bounds, Short, Span, SermonPlan (preek minus uitgeknipte stukke = segmente) met JSON
//   status: klaar
//   bewys: 7236634
/// What a stretch of the service sounds like (`silence` and `noise` come from the sound classification).
enum SegmentKind { speech, music, silence, noise }

/// One spoken word; a word ends where the next one starts (the last one where its line ends).
class Word {
  const Word(this.start, this.end, this.text);
  final double start;
  final double end;
  final String text;
}

/// One caption line; times in seconds from video start.
class Segment {
  const Segment(this.start, this.end, this.text, {this.words = const []});
  final double start;
  final double end;
  final String text;

  /// Per-word times from the captions' `tOffsetMs`; empty for hand-made segments.
  final List<Word> words;
}

/// A contiguous speech or music stretch for the service timeline.
class TimeBlock {
  const TimeBlock(this.start, this.end, this.kind);
  final double start;
  final double end;
  final SegmentKind kind;
}

/// What a speech block is, as named by the AI (`ander` = anything else or unknown).
enum BlockLabel {
  gebed,
  preek,
  skriflesing,
  geloofsbelydenis,
  seengroet,
  wet,
  aankondiging,
  kollekte,
  seen,
  ander,
}

/// One spoken stretch of the service: words without a long pause, a music stretch or an "Amen" inside.
/// [label] is null until the AI has named it.
class Block {
  Block(this.words, this.end, {this.label});
  final List<Word> words;

  /// End of the last word as spoken: an "Amen" counts `kAmenLength`, any other word at most `kMaxWordLength`.
  final double end;
  BlockLabel? label;
  double get start => words.first.start;
  String get text => words.map((w) => w.text).join(' ');
}

/// One song (a music stretch of the service); [name] comes from the announcement before it, null when unknown;
/// [n] is its number (1, 2 …) in the service.
class Song {
  const Song(this.start, this.end, this.name, this.n);
  final double start;
  final double end;
  final String? name;
  final int n;

  Map<String, dynamic> toJson() => {
    'start': start,
    'end': end,
    'name': ?name,
    'n': n,
  };
  factory Song.fromJson(Map<String, dynamic> j) => Song(
    (j['start'] as num).toDouble(),
    (j['end'] as num).toDouble(),
    j['name'] as String?,
    j['n'] as int,
  );
}

/// Why [Bounds] is not sure; Hersien shows the matching ARB text above the timeline.
enum BoundsDoubt { noSermon, noPrayerBefore, noPrayerAfter, twoSermons }

/// The cut chosen by code (`findBounds`): first word of the prayer before the sermon to the end of the
/// prayer after it. When [sure] is false [reason] says why and [start]/[end] are a best guess.
class Bounds {
  const Bounds(this.start, this.end, {this.reason});
  final double start;
  final double end;
  final BoundsDoubt? reason;
  bool get sure => reason == null;
}

/// A vertical clip [start, end) in seconds with its title.
class Short {
  Short({required this.start, required this.end, required this.title});
  double start;
  double end;
  String title;

  Map<String, dynamic> toJson() => {'start': start, 'end': end, 'title': title};
  factory Short.fromJson(Map<String, dynamic> j) => Short(
    start: (j['start'] as num).toDouble(),
    end: (j['end'] as num).toDouble(),
    title: j['title'] as String,
  );
}

/// A time range [start, end) in seconds: a cut-out middle piece or a kept part of the sermon.
class Span {
  Span(this.start, this.end);
  double start;
  double end;

  Map<String, dynamic> toJson() => {'start': start, 'end': end};
  factory Span.fromJson(Map<String, dynamic> j) =>
      Span((j['start'] as num).toDouble(), (j['end'] as num).toDouble());
}

/// The reviewed cut plan for one sermon video; persisted as plan.json.
class SermonPlan {
  SermonPlan({
    required this.sermonStart,
    required this.sermonEnd,
    required this.title,
    required this.description,
    required this.shorts,
    List<Span>? cuts,
    this.doubt,
  }) : cuts = cuts ?? [];
  double sermonStart;
  double sermonEnd;
  String title;
  String description;
  List<Short> shorts;

  /// Middle pieces cut out of the sermon (an announcement, a baptism); see [parts].
  List<Span> cuts;

  /// Why the code is unsure of [sermonStart]/[sermonEnd] (see [Bounds]); Hersien shows it until the cut is approved.
  BoundsDoubt? doubt;

  /// The kept segments in order: [sermonStart, sermonEnd] minus [cuts]; the cutter joins these.
  List<Span> parts() {
    final out = <Span>[];
    var t = sermonStart;
    for (final c in [...cuts]..sort((a, b) => a.start.compareTo(b.start))) {
      if (c.start > t) out.add(Span(t, c.start.clamp(t, sermonEnd)));
      if (c.end > t) t = c.end;
      if (t >= sermonEnd) break;
    }
    if (t < sermonEnd) out.add(Span(t, sermonEnd));
    return [
      for (final s in out)
        if (s.end > s.start) s,
    ];
  }

  Map<String, dynamic> toJson() => {
    'sermonStart': sermonStart,
    'sermonEnd': sermonEnd,
    'title': title,
    'description': description,
    'shorts': [for (final s in shorts) s.toJson()],
    'cuts': [for (final c in cuts) c.toJson()],
    if (doubt != null) 'doubt': doubt!.name,
  };

  factory SermonPlan.fromJson(Map<String, dynamic> j) => SermonPlan(
    sermonStart: (j['sermonStart'] as num).toDouble(),
    sermonEnd: (j['sermonEnd'] as num).toDouble(),
    title: j['title'] as String,
    description: j['description'] as String,
    shorts: [
      for (final s in (j['shorts'] as List))
        Short.fromJson(s as Map<String, dynamic>),
    ],
    cuts: [
      for (final c in (j['cuts'] as List? ?? const []))
        Span.fromJson(c as Map<String, dynamic>),
    ],
    doubt: BoundsDoubt.values.asNameMap()[j['doubt']],
  );
}

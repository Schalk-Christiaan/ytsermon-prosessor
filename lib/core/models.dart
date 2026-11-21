// @stelsel models
//   soort: module
//   wanneer: oral waar 'n plan gebruik word
//   groep: core | Kern
//   skryf: —
//   doel: Segment, TimeBlock, Prayer, Short, SermonPlan met JSON
//   status: bou
enum SegmentKind { speech, music }

/// One caption line (or music marker); times in seconds from video start.
class Segment {
  const Segment(
    this.start,
    this.end,
    this.text, {
    this.kind = SegmentKind.speech,
  });
  final double start;
  final double end;
  final String text;
  final SegmentKind kind;
}

/// A contiguous speech or music stretch for the service timeline.
class TimeBlock {
  const TimeBlock(this.start, this.end, this.kind);
  final double start;
  final double end;
  final SegmentKind kind;
}

/// A candidate prayer in the service: from its first cue to the end of its "Amen" line.
class Prayer {
  const Prayer(this.start, this.end, this.first, this.last);
  final double start;
  final double end;

  /// Opening and closing words, shown to the LLM so it can tell the prayers apart.
  final String first;
  final String last;
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
  }) : cuts = cuts ?? [];
  double sermonStart;
  double sermonEnd;
  String title;
  String description;
  List<Short> shorts;

  /// Middle pieces cut out of the sermon (an announcement, a baptism); see [parts].
  List<Span> cuts;

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
  );
}

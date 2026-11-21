// @stelsel bounds
//   soort: module
//   wanneer: ná parseJson3 en prayers, in planJob
//   groep: core | Kern
//   skryf: —
//   doel: kies die snit-grense met reëls (geen KI): preek = langste stuk sonder Amen of musiek, begin by die gebed voor, einde by die Amen van die eerste gebed ná die preek
//   status: bou
import 'captions.dart';
import 'models.dart';

/// Shortest stretch without "Amen" or music that counts as the sermon.
const kMinSermon = 15 * 60.0;

/// A second stretch this close to the longest one (fraction of it) makes the choice doubtful.
const kSimilarStretch = 0.8;

/// Picks the cut from the captions and their candidate [prayers]: the sermon is the longest stretch
/// without an "Amen" or music line (at least [kMinSermon]); the cut starts at the last prayer that
/// begins before it and ends at the end of the first prayer that begins after it. The order of the
/// service is not fixed, so nothing else is assumed. Doubt (and its [BoundsDoubt]) when there is no
/// full sermon, no prayer on one side, or a second stretch, opened by a prayer, nearly as long as the first.
// vloei: v1
Bounds findBounds(List<Segment> segs, List<Prayer> prayers) {
  final stretches = <(double, double)>[];
  var from = 0.0;
  void cut(double to, double next) {
    stretches.add((from, to));
    from = next;
  }

  for (final s in segs) {
    if (s.kind == SegmentKind.music) {
      cut(s.start, s.end);
      continue;
    }
    for (final w in wordsOf(s)) {
      if (isAmen(w.text)) cut(w.start, w.end);
    }
  }
  final total = segs.isEmpty ? 0.0 : segs.last.end;
  cut(total, total);
  stretches.sort((a, b) => (b.$2 - b.$1).compareTo(a.$2 - a.$1));
  final main = stretches.first;
  final len = main.$2 - main.$1;
  if (len < kMinSermon) return Bounds(0, total, reason: BoundsDoubt.noSermon);

  final before = prayers.where((p) => p.end <= main.$1 + 1).lastOrNull;
  final after = prayers.where((p) => p.start >= main.$2 - 1).firstOrNull;
  // A rival only counts when a prayer opens it too: what follows the benediction is no second sermon.
  final rival = stretches
      .skip(1)
      .any(
        (x) =>
            x.$2 - x.$1 >= len * kSimilarStretch &&
            prayers.any((p) => p.end <= x.$1 + 1 && p.end > x.$1 - 120),
      );
  return Bounds(
    before?.start ?? main.$1,
    after?.end ?? main.$2,
    reason: rival
        ? BoundsDoubt.twoSermons
        : before == null
        ? BoundsDoubt.noPrayerBefore
        : after == null
        ? BoundsDoubt.noPrayerAfter
        : null,
  );
}

/// Silences `(start, end)` in absolute seconds from ffmpeg `silencedetect` output, whose times are
/// relative to the window that began at [from]. A silence still open at the window's end is closed by it.
List<(double, double)> parseSilences(String out, double from) {
  final r = <(double, double)>[];
  double? open;
  for (final m in RegExp(r'silence_(start|end): (-?[\d.]+)').allMatches(out)) {
    final t = from + double.parse(m.group(2)!);
    if (m.group(1) == 'start') {
      open = t;
    } else if (open != null) {
      r.add((open, t));
      open = null;
    }
  }
  return r;
}

/// The cut start: the end of the last silence that begins at or before the first word [t], so the
/// cut falls right before the speech; no silence = [t] unchanged.
double snapStart(double t, List<(double, double)> silences) =>
    silences.where((s) => s.$1 <= t).lastOrNull?.$2 ?? t;

/// The cut end: the start of the first silence that ends after the "Amen" [t]; none = [t] unchanged.
double snapEnd(double t, List<(double, double)> silences) =>
    silences.where((s) => s.$2 > t).firstOrNull?.$1 ?? t;

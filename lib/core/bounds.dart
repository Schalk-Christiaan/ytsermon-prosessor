// @stelsel bounds
//   soort: module
//   wanneer: ná die KI-etikette (Planner.analyse), in planJob (met die video af, vir die stilte-snap)
//   groep: core | Kern
//   skryf: —
//   doel: kies die snit-grense met reëls uit die etikette van die spraakblokke (die KI kies nooit tye): preek = langste loop preek-blokke, begin by die gebed voor, einde by die Amen van die gebed ná die preek; snapBounds pas albei by die naaste stilte aan (ffmpeg silencedetect)
//   status: bou
import 'dart:io';
import 'dart:math' as math;

import 'captions.dart';
import 'cutter.dart';
import 'models.dart';
import 'tools.dart';

/// Shortest stretch without "Amen" or music that counts as the sermon.
const kMinSermon = 15 * 60.0;

/// The runs of consecutive blocks labelled `preek`, in order; the sermon is the longest of them.
List<List<Block>> sermonRuns(List<Block> blocks) {
  final runs = <List<Block>>[];
  var open = false;
  for (final b in blocks) {
    if (b.label != BlockLabel.preek) {
      open = false;
    } else if (open) {
      runs.last.add(b);
    } else {
      runs.add([b]);
      open = true;
    }
  }
  return runs;
}

/// A second sermon run this close to the longest one (fraction of it) makes the choice doubtful.
const kSimilarStretch = 0.8;

/// Labels that end a prayer when walking back from it: what is read, announced or said in the
/// service is no part of the prayer; mislabelled prayer blocks (`ander`, `kollekte`) are.
const _notPrayer = {
  BlockLabel.preek,
  BlockLabel.aankondiging,
  BlockLabel.skriflesing,
  BlockLabel.geloofsbelydenis,
  BlockLabel.seengroet,
  BlockLabel.wet,
  BlockLabel.seen,
};

// stap: diensindeling 5 Grense uit etikette | preek = langste loop `preek`-blokke (≥ 15 min); begin by die eerste blok van die gebed daarvoor (terug tot by musiek), einde by die Amen van die gebed daarna; twyfel gee 'n rede vir Hersien
/// Picks the cut from the labelled [blocks]: the sermon is the longest run of `preek` blocks (at least
/// [kMinSermon]). The cut starts at the prayer before it: the last `gebed` block before the run, back to
/// the first block of the same stretch without music in between (a long prayer is several blocks and the
/// AI mislabels some of them). It ends where the `gebed` after the run ends in "Amen" (a short lead-in
/// like "Kom ons dank" is followed through to the block with the Amen). Doubt (and its [BoundsDoubt])
/// when there is no full sermon, no prayer on one side, or a second run, opened by a prayer, nearly as
/// long as the first. [sound] tells where the music is.
Bounds findBounds(List<Block> blocks, List<TimeBlock> sound) {
  final total = blocks.isEmpty ? 0.0 : blocks.last.end;
  double len(List<Block> r) => r.last.end - r.first.start;
  final runs = sermonRuns(blocks)..sort((a, b) => len(b).compareTo(len(a)));
  if (runs.isEmpty || len(runs.first) < kMinSermon) {
    return Bounds(0, total, reason: BoundsDoubt.noSermon);
  }
  bool musicBetween(Block a, Block b) => sound.any(
    (t) => t.kind == SegmentKind.music && t.end > a.end && t.start < b.start,
  );
  // Index of the first block of the prayer that ends right before block [i], or -1.
  int prayerBefore(int i) {
    var k = i - 1;
    while (k >= 0 && blocks[k].label != BlockLabel.gebed) {
      if (_notPrayer.contains(blocks[k].label)) return -1;
      k--;
    }
    if (k < 0) return -1;
    while (k > 0 &&
        !_notPrayer.contains(blocks[k - 1].label) &&
        !musicBetween(blocks[k - 1], blocks[k])) {
      k--;
    }
    return k;
  }

  final main = runs.first;
  final i = blocks.indexOf(main.first), j = blocks.indexOf(main.last);
  final first = prayerBefore(i);
  Block? after;
  for (var k = j + 1; k < blocks.length; k++) {
    if (blocks[k].label != BlockLabel.gebed) break;
    after = blocks[k];
    if (isAmen(after.words.last.text)) break;
  }
  final rival = runs
      .skip(1)
      .any(
        (r) =>
            len(r) >= len(main) * kSimilarStretch &&
            prayerBefore(blocks.indexOf(r.first)) >= 0,
      );
  return Bounds(
    first >= 0 ? blocks[first].start : main.first.start,
    after?.end ?? main.last.end,
    reason: rival
        ? BoundsDoubt.twoSermons
        : first < 0
        ? BoundsDoubt.noPrayerBefore
        : after == null
        ? BoundsDoubt.noPrayerAfter
        : null,
  );
}

// stap: diensindeling 6 Net die woord | alle spraak tussen die gebede (Skriflesing ingesluit), sonder gebede en sang, in een snit aanmekaar
/// The kept pieces of "Net die woord": every labelled block that is not a prayer, inside the [within] spans
/// (the sermon cut), joined into one span while neither a prayer nor music comes between.
List<Span> wordParts(
  List<({double start, double end, BlockLabel label})> labels,
  List<TimeBlock> sound,
  List<Span> within,
) {
  final runs = <Span>[];
  Span? run;
  for (final b in labels) {
    if (b.label == BlockLabel.gebed) {
      run = null;
    } else if (run != null &&
        sound.any(
          (t) =>
              t.kind == SegmentKind.music &&
              t.end > run!.end &&
              t.start < b.start,
        )) {
      run = null;
    }
    if (b.label == BlockLabel.gebed) continue;
    if (run == null) runs.add(run = Span(b.start, b.end));
    run.end = b.end;
  }
  return [
    for (final r in runs)
      for (final w in within)
        if (r.end > w.start && r.start < w.end)
          Span(
            r.start < w.start ? w.start : r.start,
            r.end > w.end ? w.end : r.end,
          ),
  ];
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

// stap: preekgrense 1 Stilte-snap | begin na die einde van die laaste stilte voor die eerste woord, einde by die begin van die eerste stilte ná "Amen" (ffmpeg silencedetect, ±3 s)
/// Snaps both cuts of [b] to the silence around them: one ffmpeg call over 6 s of sound per cut
/// (see [silenceArgs]); where none is found the word time stays. [Bounds.reason] is kept.
// skakel: → cutter.silenceArgs (die ffmpeg-oproep vir die stilte)
Future<Bounds> snapBounds(File video, Bounds b, {Future<void>? cancel}) async {
  Future<List<(double, double)>> around(double t) async {
    final from = math.max(0.0, t - 3), out = StringBuffer();
    await runTool(
      'ffmpeg',
      silenceArgs(video.path, from, t + 3),
      onErr: out.write,
      cancel: cancel,
    );
    return parseSilences(out.toString(), from);
  }

  final start = snapStart(b.start, await around(b.start));
  final end = snapEnd(b.end, await around(b.end));
  return Bounds(start, end, reason: b.reason);
}

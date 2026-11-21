// @stelsel service_timeline
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: —
//   doel: bane met etiket (Klank = golfvorm uit sound.level.json, Diens = spraak/musiek, gebede, sleepbare preek-hakies (sleutels 1 s / Shift 0,1 s), uitgeknipte stukke gestreep; Shorts = sleepbaar, ongeldige met foutkleur) en een oranje speelkop deur almal; zoem rol horisontaal
//   status: klaar
//   bewys: 7236634
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/captions.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

const _kHandleW = 20.0;
const _kGutter = 72.0;
const _kSoundH = 44.0, _kServiceY = 48.0, _kServiceH = 48.0;
const _kShortsY = 100.0, _kShortsH = 28.0, _kTracksH = 128.0;

/// The tracks timeline: Klank (waveform), Diens (speech/music, sermon brackets, cuts, prayers) and Shorts,
/// one orange playhead through all; [zoom] widens the tracks inside a horizontal scroll.
class ServiceTimeline extends StatefulWidget {
  const ServiceTimeline({
    super.key,
    required this.duration,
    required this.blocks,
    required this.sermonStart,
    required this.sermonEnd,
    required this.shorts,
    this.levels = const [],
    this.zoom = 1,
    this.cuts = const [],
    this.prayers = const [],
    this.songs = const [],
    this.faulty = const {},
    required this.position,
    required this.animateKey,
    required this.onSeek,
    required this.onSermonChanged,
    required this.onSermonCommit,
    required this.onNudge,
    required this.onShortMove,
  });

  final double duration;
  final List<TimeBlock> blocks;
  final double sermonStart;
  final double sermonEnd;
  final List<Short> shorts;

  /// Loudness per second (dB) for the waveform; empty draws the speech/music blocks as plain bars.
  final List<double> levels;

  /// 1 = the whole service fits; more widens the tracks and scrolls.
  final double zoom;

  /// Cut-out pieces (hatched) and candidate prayers (a line above the track).
  final List<Span> cuts, prayers;

  /// The songs; a music piece that starts one shows its name (else "Sang").
  final List<Song> songs;

  /// Invalid Shorts, drawn in the error colour with an outline (not colour alone).
  final Set<Short> faulty;
  final ValueListenable<double> position;

  /// Changes when a new plan arrives; the handles then glide from the full width to the sermon.
  final int animateKey;
  final ValueChanged<double> onSeek;
  final void Function(double start, double end) onSermonChanged;
  final VoidCallback onSermonCommit;
  final void Function(bool isStart, double secs) onNudge;

  /// A Short dragged by [dt] seconds; the drag ends with [onSermonCommit].
  final void Function(Short s, double dt) onShortMove;

  @override
  State<ServiceTimeline> createState() => _ServiceTimelineState();
}

class _ServiceTimelineState extends State<ServiceTimeline>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glide = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
  );
  late final Animation<double> _t = CurvedAnimation(
    parent: _glide,
    curve: Curves.easeOutCubic,
  );
  final _scroll = ScrollController();
  Object? _barsKey;
  List<(double, Color)> _bars = const [];

  /// [waveBars] memoised on the data, the width and the colours: the build runs often, the bars do not.
  List<(double, Color)> _barsFor(double w, ColorScheme cs) {
    final key = (
      widget.levels,
      widget.blocks,
      w,
      cs.secondary,
      cs.tertiary,
      cs.onSurface,
    );
    if (_barsKey != key) {
      _barsKey = key;
      _bars = waveBars(
        widget.levels,
        widget.blocks,
        widget.duration,
        w,
        cs.secondary,
        cs.tertiary,
        cs.onSurface,
      );
    }
    return _bars;
  }

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _run();
    }
  }

  @override
  void didUpdateWidget(ServiceTimeline old) {
    super.didUpdateWidget(old);
    if (old.animateKey != widget.animateKey) _run();
    if (old.zoom != widget.zoom) {
      // Keep the playhead in the middle of the view when the zoom changes.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        final vp = _scroll.position.viewportDimension;
        final w = vp * widget.zoom;
        // At the very start (nothing played yet) the sermon bracket is what the user zooms to.
        final at = widget.position.value > 0
            ? widget.position.value
            : widget.sermonStart;
        _scroll.jumpTo(
          (at / widget.duration * w - vp / 2).clamp(
            0,
            _scroll.position.maxScrollExtent,
          ),
        );
      });
    }
  }

  void _run() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _glide.value = 1;
    } else {
      _glide.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _drag(bool isStart, double dx, double w) {
    final dt = dx / w * widget.duration;
    var s = widget.sermonStart, e = widget.sermonEnd;
    if (isStart) {
      s = (s + dt).clamp(0, e - 1);
    } else {
      e = (e + dt).clamp(s + 1, widget.duration);
    }
    widget.onSermonChanged(s, e);
    widget.onSeek(isStart ? s : e);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final cs = th.colorScheme;
    final label = th.textTheme.labelMedium!;
    Widget gutter(String text, double y, double h) => Positioned(
      top: y,
      height: h,
      left: 0,
      width: _kGutter - 8,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: label, maxLines: 1),
      ),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: _kGutter,
          height: _kTracksH,
          child: Stack(
            children: [
              gutter(l.trackSound, 0, _kSoundH),
              gutter(l.trackService, _kServiceY, _kServiceH),
              gutter(l.trackShorts, _kShortsY, _kShortsH),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              final w = c.maxWidth * widget.zoom;
              double x(double t) => t / widget.duration * w;
              return Scrollbar(
                controller: _scroll,
                thumbVisibility: widget.zoom > 1,
                child: SingleChildScrollView(
                  controller: _scroll,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: w,
                    child: AnimatedBuilder(
                      animation: _t,
                      builder: (context, _) {
                        final s = lerpDouble(0, widget.sermonStart, _t.value)!;
                        final e = lerpDouble(
                          widget.duration,
                          widget.sermonEnd,
                          _t.value,
                        )!;
                        Widget handle(bool isStart) {
                          final time = formatTime(isStart ? s : e);
                          return Positioned(
                            left: x(isStart ? s : e) - _kHandleW / 2,
                            top: _kServiceY,
                            width: _kHandleW,
                            height: _kServiceH,
                            child: _Handle(
                              key: ValueKey(
                                'ctl.hersien.handle-${isStart ? 'start' : 'end'}',
                              ),
                              label: isStart
                                  ? l.sermonHandleStart(time)
                                  : l.sermonHandleEnd(time),
                              onDrag: (dx) => _drag(isStart, dx, w),
                              onEnd: widget.onSermonCommit,
                              onNudge: (secs) => widget.onNudge(isStart, secs),
                            ),
                          );
                        }

                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: _kTracksH,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Positioned.fill(
                                    child: GestureDetector(
                                      key: const ValueKey(
                                        'ctl.hersien.timeline',
                                      ),
                                      behavior: HitTestBehavior.opaque,
                                      onTapUp: (d) => widget.onSeek(
                                        d.localPosition.dx /
                                            w *
                                            widget.duration,
                                      ),
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: TracksPainter(
                                            duration: widget.duration,
                                            blocks: widget.blocks,
                                            levels: widget.levels,
                                            bars: _barsFor(w, cs),
                                            shorts: widget.shorts,
                                            cuts: widget.cuts,
                                            prayers: widget.prayers,
                                            songs: widget.songs,
                                            faulty: widget.faulty,
                                            cutLabel: l.cutOut,
                                            musicLabel: l.music,
                                            start: s,
                                            end: e,
                                            speech: cs.secondary,
                                            music: cs.tertiary,
                                            sermon: cs.primary,
                                            wood: th
                                                .extension<AppTokens>()!
                                                .wood,
                                            error: cs.error,
                                            ink: cs.onSurface,
                                            ground: cs.surface,
                                            labelStyle: th.textTheme.labelSmall!
                                                .copyWith(color: cs.onSurface),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final sh in widget.shorts)
                                    Positioned(
                                      left: x(sh.start),
                                      width: (x(sh.end) - x(sh.start)).clamp(
                                        8,
                                        w,
                                      ),
                                      top: _kShortsY,
                                      height: _kShortsH,
                                      child: MouseRegion(
                                        cursor: SystemMouseCursors.grab,
                                        child: GestureDetector(
                                          key: const ValueKey(
                                            'ctl.hersien.short-block',
                                          ),
                                          behavior: HitTestBehavior.opaque,
                                          onHorizontalDragUpdate: (d) =>
                                              widget.onShortMove(
                                                sh,
                                                d.delta.dx /
                                                    w *
                                                    widget.duration,
                                              ),
                                          onHorizontalDragEnd: (_) =>
                                              widget.onSermonCommit(),
                                        ),
                                      ),
                                    ),
                                  handle(true),
                                  handle(false),
                                  // The playhead repaints on its own; the tracks do not.
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: RepaintBoundary(
                                        child: CustomPaint(
                                          painter: _PlayheadPainter(
                                            position: widget.position,
                                            duration: widget.duration,
                                            color: cs.primary,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 20,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  _label(formatTime(s), x(s), w, th),
                                  _label(formatTime(e), x(e), w, th),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _label(String text, double x, double w, ThemeData th) {
    const half = 24.0;
    return Positioned(
      left: (x - half).clamp(0, w - 2 * half),
      width: 2 * half,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: th.textTheme.labelMedium!.copyWith(
          color: th.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Handle extends StatefulWidget {
  const _Handle({
    super.key,
    required this.label,
    required this.onDrag,
    required this.onEnd,
    required this.onNudge,
  });
  final String label;
  final ValueChanged<double> onDrag;
  final VoidCallback onEnd;
  final ValueChanged<double> onNudge;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  bool _focus = false;
  final _node = FocusNode();

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  KeyEventResult _key(FocusNode n, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? 0.1 : 1.0;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onNudge(-step);
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onNudge(step);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: widget.label,
      slider: true,
      focusable: true,
      child: Focus(
        focusNode: _node,
        onKeyEvent: _key,
        onFocusChange: (f) => setState(() => _focus = f),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeLeftRight,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => _node.requestFocus(),
            onHorizontalDragUpdate: (d) => widget.onDrag(d.delta.dx),
            onHorizontalDragEnd: (_) => widget.onEnd(),
            child: Center(
              child: Container(
                width: 8,
                decoration: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(4),
                  border: _focus
                      ? Border.all(color: cs.onSurface, width: 2)
                      : null,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The orange playhead through all tracks; the only thing that repaints while playing.
class _PlayheadPainter extends CustomPainter {
  _PlayheadPainter({
    required this.position,
    required this.duration,
    required this.color,
  }) : super(repaint: position);
  final ValueListenable<double> position;
  final double duration;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final px = position.value.clamp(0, duration) / duration * size.width;
    canvas.drawRect(
      Rect.fromLTWH(px - 1, 0, 2, size.height),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_PlayheadPainter o) =>
      o.duration != duration || o.color != color;
}

/// The three tracks. Static: it repaints when the data or the width change, never per playback tick.
@visibleForTesting
class TracksPainter extends CustomPainter {
  TracksPainter({
    required this.duration,
    required this.blocks,
    required this.levels,
    required this.bars,
    required this.shorts,
    required this.cuts,
    required this.prayers,
    required this.songs,
    required this.faulty,
    required this.cutLabel,
    required this.musicLabel,
    required this.start,
    required this.end,
    required this.speech,
    required this.music,
    required this.sermon,
    required this.wood,
    required this.error,
    required this.ink,
    required this.ground,
    required this.labelStyle,
  }) : _sig = Object.hash(
         Object.hashAll([for (final s in shorts) Object.hash(s.start, s.end)]),
         Object.hashAll([for (final c in cuts) Object.hash(c.start, c.end)]),
         Object.hashAll([for (final p in prayers) Object.hash(p.start, p.end)]),
         Object.hashAll([for (final s in songs) Object.hash(s.start, s.name)]),
         faulty.length,
         blocks.length,
       );

  final double duration, start, end;
  final List<TimeBlock> blocks;
  final List<double> levels;

  /// Waveform bars (height, colour) from [waveBars], computed once per data/width, not per paint.
  final List<(double, Color)> bars;
  final List<Short> shorts;
  final List<Span> cuts, prayers;
  final List<Song> songs;
  final Set<Short> faulty;
  final String cutLabel, musicLabel;
  final Color speech, music, sermon, wood, error, ink, ground;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double t) => t / duration * size.width;
    RRect row(double y, double h) => RRect.fromRectAndRadius(
      Rect.fromLTWH(0, y, size.width, h),
      const Radius.circular(4),
    );
    final wash = Paint()..color = ink.withValues(alpha: 0.06);
    final sound = row(0, _kSoundH), service = row(_kServiceY, _kServiceH);
    canvas.drawRRect(sound, wash);
    canvas.drawRRect(service, wash);
    canvas.drawRRect(row(_kShortsY, _kShortsH), wash);

    Color kind(SegmentKind k) => k == SegmentKind.music ? music : speech;
    // Klank: one bar per ~2 px from the loudness, in the colour of what plays then.
    canvas.save();
    canvas.clipRRect(sound);
    if (levels.isEmpty) {
      for (final b in blocks) {
        if (b.kind != SegmentKind.music && b.kind != SegmentKind.speech)
          continue;
        canvas.drawRect(
          Rect.fromLTRB(
            x(b.start),
            14,
            x(b.end).clamp(x(b.start) + 1, size.width),
            _kSoundH - 14,
          ),
          Paint()..color = kind(b.kind).withValues(alpha: 0.6),
        );
      }
    } else {
      for (var i = 0; i < bars.length; i++) {
        final (amp, color) = bars[i];
        canvas.drawRect(
          Rect.fromLTWH(i * 2.0, _kSoundH / 2 - amp, 1.4, amp * 2),
          Paint()..color = color,
        );
      }
    }
    canvas.restore();

    // Diens: speech and music with song names, the sermon bracket, prayers, cuts.
    canvas.save();
    canvas.clipRRect(service);
    for (final b in blocks) {
      if (b.kind != SegmentKind.music && b.kind != SegmentKind.speech) continue;
      final r = Rect.fromLTRB(
        x(b.start),
        _kServiceY,
        x(b.end).clamp(x(b.start) + 1, size.width),
        _kServiceY + _kServiceH,
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = kind(b.kind)
              .withValues(alpha: b.kind == SegmentKind.music ? 0.32 : 0.28),
      );
      if (b.kind == SegmentKind.music && r.width > 44) {
        final song = songs
            .where((s) => (s.start - b.start).abs() < 2)
            .firstOrNull;
        final tp = TextPainter(
          text: TextSpan(text: song?.name ?? musicLabel, style: labelStyle),
          maxLines: 1,
          ellipsis: '…',
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.width);
        tp.paint(canvas, Offset(r.left + 4, r.center.dy - tp.height / 2));
      }
    }
    canvas.restore();
    final sr = Rect.fromLTRB(
      x(start),
      _kServiceY - 2,
      x(end),
      _kServiceY + _kServiceH + 2,
    );
    canvas.drawRect(sr, Paint()..color = sermon.withValues(alpha: 0.14));
    final bar = Paint()..color = sermon;
    canvas.drawRect(Rect.fromLTRB(sr.left, sr.top, sr.right, sr.top + 3), bar);
    canvas.drawRect(
      Rect.fromLTRB(sr.left, sr.bottom - 3, sr.right, sr.bottom),
      bar,
    );
    for (final p in prayers) {
      canvas.drawRect(
        Rect.fromLTRB(
          x(p.start),
          _kServiceY,
          x(p.end).clamp(x(p.start) + 2, size.width),
          _kServiceY + 3,
        ),
        Paint()..color = ink,
      );
    }
    for (final c in cuts) {
      final r = Rect.fromLTRB(
        x(c.start),
        _kServiceY,
        x(c.end),
        _kServiceY + _kServiceH,
      );
      canvas.save();
      canvas.clipRect(r);
      canvas.drawRect(r, Paint()..color = ground.withValues(alpha: 0.7));
      final stripe = Paint()
        ..color = ink.withValues(alpha: 0.5)
        ..strokeWidth = 1.5;
      for (var sx = r.left - r.height; sx < r.right; sx += 6) {
        canvas.drawLine(
          Offset(sx, r.bottom),
          Offset(sx + r.height, r.top),
          stripe,
        );
      }
      if (r.width > 60) {
        final tp = TextPainter(
          text: TextSpan(
            text: cutLabel,
            style: labelStyle.copyWith(backgroundColor: ground),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.width - 8);
        tp.paint(canvas, Offset(r.left + 4, r.center.dy - tp.height / 2));
      }
      canvas.restore();
    }

    // Shorts
    for (final s in shorts) {
      final bad = faulty.contains(s);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x(s.start),
          _kShortsY + 3,
          x(s.end).clamp(x(s.start) + 3, size.width),
          _kShortsY + _kShortsH - 3,
        ),
        const Radius.circular(2),
      );
      canvas.drawRRect(r, Paint()..color = bad ? error : wood);
      if (bad) {
        canvas.drawRRect(
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = ink,
        );
      }
    }
  }

  /// Shorts, cuts and prayers are mutated in place, so they are compared by value.
  final int _sig;

  @override
  bool shouldRepaint(TracksPainter o) =>
      !identical(o.levels, levels) ||
      !identical(o.bars, bars) ||
      o._sig != _sig ||
      o.duration != duration ||
      o.start != start ||
      o.end != end ||
      o.cutLabel != cutLabel ||
      o.musicLabel != musicLabel ||
      o.speech != speech ||
      o.music != music ||
      o.sermon != sermon ||
      o.wood != wood ||
      o.error != error ||
      o.ink != ink ||
      o.ground != ground ||
      o.labelStyle != labelStyle;
}

/// The Klank bars: one per ~2 px, loudest second in each, in the colour of what plays then.
List<(double, Color)> waveBars(
  List<double> levels,
  List<TimeBlock> blocks,
  double duration,
  double width,
  Color speech,
  Color music,
  Color ink,
) {
  final n = (width / 2).floor();
  if (levels.isEmpty || n <= 0) return const [];
  final secsPerBar = duration / n;
  return [
    for (var i = 0; i < n; i++)
      () {
        final a = (i * secsPerBar).floor(),
            b = math.max(a + 1, ((i + 1) * secsPerBar).ceil());
        var peak = -120.0;
        for (var k = a; k < b && k < levels.length; k++) {
          peak = math.max(peak, levels[k]);
        }
        final t = (i + 0.5) * secsPerBar;
        final blk = blocks.where((q) => t >= q.start && t < q.end).firstOrNull;
        final c = blk == null
            ? ink
            : (blk.kind == SegmentKind.music ? music : speech);
        return (
          ((peak + 60) / 60).clamp(0.04, 1.0) * (_kSoundH / 2 - 2),
          c.withValues(alpha: 0.75),
        );
      }(),
  ];
}

// @stelsel service_timeline
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: —
//   doel: dienstydlyn: spraak/musiek, gebedsmerkers, sleepbare preek-hakies (sleutels 1 s / Shift 0,1 s), uitgeknipte stukke gestreep, sleepbare Shorts (ongeldige met foutkleur), speelposisie
//   status: bou
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/captions.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

const _kHandleW = 20.0;
const _kBarH = 56.0;

/// The service timeline: draggable sermon brackets, cut pieces, prayer marks and Shorts.
class ServiceTimeline extends StatefulWidget {
  const ServiceTimeline({
    super.key,
    required this.duration,
    required this.blocks,
    required this.sermonStart,
    required this.sermonEnd,
    required this.shorts,
    this.cuts = const [],
    this.prayers = const [],
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

  /// Cut-out pieces (hatched) and candidate prayers (a line above the track).
  final List<Span> cuts, prayers;

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
    super.dispose();
  }

  double _x(double t, double w) => t / widget.duration * w;

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
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final s = lerpDouble(0, widget.sermonStart, _t.value)!;
            final e = lerpDouble(widget.duration, widget.sermonEnd, _t.value)!;
            Widget handle(bool isStart) {
              final time = formatTime(isStart ? s : e);
              final label = isStart
                  ? l.sermonHandleStart(time)
                  : l.sermonHandleEnd(time);
              return Positioned(
                left: _x(isStart ? s : e, w) - _kHandleW / 2,
                top: 0,
                width: _kHandleW,
                height: _kBarH,
                child: _Handle(
                  label: label,
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
                  height: _kBarH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTapUp: (d) => widget.onSeek(
                            d.localPosition.dx / w * widget.duration,
                          ),
                          child: CustomPaint(
                            painter: _TimelinePainter(
                              duration: widget.duration,
                              blocks: widget.blocks,
                              shorts: widget.shorts,
                              cuts: widget.cuts,
                              prayers: widget.prayers,
                              cutLabel: l.cutOut,
                              faulty: widget.faulty,
                              error: th.colorScheme.error,
                              start: s,
                              end: e,
                              position: widget.position,
                              speech: th.colorScheme.secondary,
                              music: th.colorScheme.tertiary,
                              sermon: th.colorScheme.primary,
                              wood: th.extension<AppTokens>()!.wood,
                              ink: th.colorScheme.onSurface,
                              surface: th.colorScheme.surface,
                              musicLabel: l.music,
                              labelStyle: th.textTheme.labelSmall!.copyWith(
                                color: th.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final sh in widget.shorts)
                        Positioned(
                          left: _x(sh.start, w),
                          width: (_x(sh.end, w) - _x(sh.start, w)).clamp(8, w),
                          bottom: 6,
                          height: 24,
                          child: MouseRegion(
                            cursor: SystemMouseCursors.grab,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragUpdate: (d) => widget.onShortMove(
                                sh,
                                d.delta.dx / w * widget.duration,
                              ),
                              onHorizontalDragEnd: (_) =>
                                  widget.onSermonCommit(),
                            ),
                          ),
                        ),
                      handle(true),
                      handle(false),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  height: 20,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _label(formatTime(s), _x(s, w), w, th),
                      _label(formatTime(e), _x(e, w), w, th),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
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

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.duration,
    required this.blocks,
    required this.shorts,
    required this.cuts,
    required this.prayers,
    required this.cutLabel,
    required this.faulty,
    required this.error,
    required this.start,
    required this.end,
    required this.position,
    required this.speech,
    required this.music,
    required this.sermon,
    required this.wood,
    required this.ink,
    required this.surface,
    required this.musicLabel,
    required this.labelStyle,
  }) : super(repaint: position);

  final double duration, start, end;
  final List<TimeBlock> blocks;
  final List<Short> shorts;
  final List<Span> cuts, prayers;
  final String cutLabel;
  final Set<Short> faulty;
  final Color error;
  final ValueListenable<double> position;
  final Color speech, music, sermon, wood, ink, surface;
  final String musicLabel;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    double x(double t) => t / duration * size.width;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 8, size.width, size.height - 16),
      const Radius.circular(4),
    );
    canvas.save();
    canvas.clipRRect(track);
    canvas.drawRect(
      track.outerRect,
      Paint()..color = ink.withValues(alpha: 0.06),
    );
    for (final b in blocks) {
      if (b.kind != SegmentKind.music && b.kind != SegmentKind.speech) continue;
      final r = Rect.fromLTRB(
        x(b.start),
        8,
        x(b.end).clamp(x(b.start) + 1, size.width),
        size.height - 8,
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = (b.kind == SegmentKind.music ? music : speech).withValues(
            alpha: b.kind == SegmentKind.music ? 0.32 : 0.45,
          ),
      );
      if (b.kind == SegmentKind.music && r.width > 44) {
        final tp = TextPainter(
          text: TextSpan(text: musicLabel, style: labelStyle),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.width);
        tp.paint(canvas, Offset(r.left + 4, r.center.dy - tp.height / 2));
      }
    }
    canvas.restore();
    final sr = Rect.fromLTRB(x(start), 4, x(end), size.height - 4);
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
          0,
          x(p.end).clamp(x(p.start) + 2, size.width),
          3,
        ),
        Paint()..color = ink,
      );
    }
    for (final c in cuts) {
      final r = Rect.fromLTRB(x(c.start), 8, x(c.end), size.height - 8);
      canvas.save();
      canvas.clipRect(r);
      canvas.drawRect(r, Paint()..color = surface.withValues(alpha: 0.7));
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
            style: labelStyle.copyWith(backgroundColor: surface),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: r.width - 8);
        tp.paint(canvas, Offset(r.left + 4, r.center.dy - tp.height / 2));
      }
      canvas.restore();
    }
    for (final s in shorts) {
      final bad = faulty.contains(s);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(
          x(s.start),
          size.height - (bad ? 26 : 22),
          x(s.end).clamp(x(s.start) + 3, size.width),
          size.height - 10,
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
    final px = x(position.value.clamp(0, duration));
    canvas.drawRect(
      Rect.fromLTWH(px - 1, 0, 2, size.height),
      Paint()..color = ink,
    );
  }

  @override
  // Shorts are mutated in place (length slider), so a diff is impossible; the
  // painter is only rebuilt when the parent rebuilds, i.e. on a change.
  bool shouldRepaint(_TimelinePainter o) => true;
}

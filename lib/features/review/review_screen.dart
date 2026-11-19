// @stelsel review_screen
//   soort: skerm
//   wanneer: Hersien (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: die preekredigeerder: preek uit Preke → plan → hakies, I/O, uitknip, transkripsie, Shorts, ontdoen (kortpaaie) → keur goed en sny
//   status: oop

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/captions.dart';
import '../../core/models.dart';
import '../../core/planner.dart';
import '../../l10n/app_localizations.dart';
import 'review_controller.dart';
import 'service_timeline.dart';
import 'transcript.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.controller});

  /// Owned by the shell, which opens a sermon in it from Preke.
  final ReviewController controller;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final _c = widget.controller;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  (int, int)? _synced;
  int _tab = 1;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _syncFields() {
    if (_c.state == ReviewState.ready &&
        _synced != (_c.planRevision, _c.edits)) {
      _synced = (_c.planRevision, _c.edits);
      _title.text = _c.plan!.title;
      _desc.text = _c.plan!.description;
    }
  }

  Future<void> _cut(L l) async {
    final m = ScaffoldMessenger.of(context);
    try {
      _c.approveAndCut();
      m.showSnackBar(SnackBar(content: Text(l.cutQueued)));
    } on Object catch (e) {
      m.showSnackBar(SnackBar(content: Text(l.errorGeneric(e.toString()))));
    }
  }

  Future<void> _replan(L l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.replanConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(l.replan),
          ),
        ],
      ),
    );
    if (ok == true) _c.replan();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        _syncFields();
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Expanded(child: _body(l))],
          ),
        );
      },
    );
  }

  Widget _body(L l) {
    final th = Theme.of(context);
    switch (_c.state) {
      case ReviewState.empty:
        return Center(
          child: Text(l.emptyReview, style: th.textTheme.titleMedium),
        );
      case ReviewState.unplanned:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.unplanned, style: th.textTheme.titleMedium),
              const SizedBox(height: 16),
              FilledButton(onPressed: _c.replan, child: Text(l.planNow)),
            ],
          ),
        );
      case ReviewState.loading:
        return Center(child: _Loading(c: _c));
      case ReviewState.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_rounded, color: th.colorScheme.error, size: 32),
              const SizedBox(height: 12),
              Text(
                l.errorGeneric(_c.error.toString()),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(onPressed: _c.replan, child: Text(l.retry)),
                  if (_c.meta != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: _c.setManually,
                      child: Text(l.setManually),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      case ReviewState.ready:
        return _ready(l, th);
    }
  }

  /// Editor shortcuts; ignored while a text field has focus (typing "i" is text).
  KeyEventResult _key(FocusNode _, KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    final focus = FocusManager.instance.primaryFocus?.context;
    if (focus?.findAncestorWidgetOfExactType<EditableText>() != null) {
      return KeyEventResult.ignored;
    }
    final k = HardwareKeyboard.instance;
    final key = e.logicalKey;
    if (k.isControlPressed && key == LogicalKeyboardKey.keyZ) {
      k.isShiftPressed ? _c.redo() : _c.undo();
    } else if (k.isControlPressed && key == LogicalKeyboardKey.keyY) {
      _c.redo();
    } else if (key == LogicalKeyboardKey.keyI) {
      _c.markIn();
    } else if (key == LogicalKeyboardKey.keyO) {
      _c.markOut();
    } else if (key == LogicalKeyboardKey.space) {
      _c.playPause();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  Widget _ready(L l, ThemeData th) {
    final plan = _c.plan!;
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _preview(th)),
                const SizedBox(width: 24),
                SizedBox(width: 400, child: _meta(l, th, plan)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ServiceTimeline(
            duration: _c.duration,
            blocks: _c.blocks,
            sermonStart: plan.sermonStart,
            sermonEnd: plan.sermonEnd,
            shorts: plan.shorts,
            cuts: plan.cuts,
            prayers: _c.prayerMarks,
            faulty: {
              for (final s in plan.shorts)
                if (shortFault(s, plan) != null) s,
            },
            position: _c.position,
            animateKey: _c.planRevision,
            onSeek: _c.seek,
            onSermonChanged: (s, e) => _c.setSermon(s, e, save: false),
            onSermonCommit: _c.commit,
            onNudge: (start, d) {
              _c.nudge(start, d);
              _c.seek(start ? plan.sermonStart : plan.sermonEnd);
            },
            onShortMove: (s, d) => _c.moveShort(s, d, save: false),
          ),
          _playBar(l, th),
          const SizedBox(height: 8),
          Row(
            children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: 1,
                    label: Text(l.shortsTab(plan.shorts.length)),
                  ),
                  ButtonSegment(
                    value: 0,
                    label: Text(l.cutsTab(plan.cuts.length)),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.single),
              ),
              const SizedBox(width: 16),
              _tab == 0
                  ? TextButton.icon(
                      onPressed: _c.addCut,
                      icon: const Icon(Icons.content_cut_rounded),
                      label: Text(l.addCut),
                    )
                  : TextButton.icon(
                      onPressed: () => _c.addShort(l.newShortTitle),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l.addShort),
                    ),
              const Spacer(),
              Flexible(
                child: Text(
                  l.editorKeys,
                  textAlign: TextAlign.end,
                  style: th.textTheme.labelMedium,
                ),
              ),
            ],
          ),
          SizedBox(
            height: 96,
            child: _tab == 0 ? _cuts(l, th, plan) : _shorts(l, th, plan),
          ),
          const SizedBox(height: 12),
          _actions(l, th),
        ],
      ),
    );
  }

  Widget _playBar(L l, ThemeData th) => Row(
    children: [
      IconButton(
        tooltip: l.playPause,
        onPressed: _c.playPause,
        icon: const Icon(Icons.play_arrow_rounded),
      ),
      ValueListenableBuilder<double>(
        valueListenable: _c.position,
        builder: (context, v, _) => Text(
          formatTime(v),
          style: th.textTheme.labelLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
      const SizedBox(width: 16),
      TextButton(
        onPressed: () => _c.playFrom(true),
        child: Text(l.playFromStart),
      ),
      TextButton(onPressed: () => _c.playFrom(false), child: Text(l.playEnd)),
      TextButton.icon(
        onPressed: _c.previewCut,
        icon: Icon(
          _c.previewing ? Icons.check_rounded : Icons.slideshow_rounded,
        ),
        label: Text(l.previewCut),
      ),
      const Spacer(),
      IconButton(
        tooltip: l.undo,
        onPressed: _c.canUndo ? _c.undo : null,
        icon: const Icon(Icons.undo_rounded),
      ),
      IconButton(
        tooltip: l.redo,
        onPressed: _c.canRedo ? _c.redo : null,
        icon: const Icon(Icons.redo_rounded),
      ),
    ],
  );

  Widget _cuts(L l, ThemeData th, SermonPlan plan) => plan.cuts.isEmpty
      ? Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.noCuts, style: th.textTheme.bodyMedium),
          ),
        )
      : ListView.builder(
          itemCount: plan.cuts.length,
          itemExtent: 48,
          itemBuilder: (context, i) {
            final c = plan.cuts[i];
            return Row(
              children: [
                SizedBox(
                  width: 120,
                  child: Text(l.cutN(i + 1), style: th.textTheme.titleSmall),
                ),
                SizedBox(
                  width: 140,
                  child: Text(
                    l.shortRange(formatTime(c.start), formatTime(c.end)),
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => _c.setCutStart(c),
                  child: Text(l.startHere),
                ),
                TextButton(
                  onPressed: () => _c.setCutEnd(c),
                  child: Text(l.endHere),
                ),
                TextButton(
                  onPressed: () => _c.seek(c.start - 3),
                  child: Text(l.play),
                ),
                const Spacer(),
                IconButton(
                  tooltip: l.remove,
                  onPressed: () => _c.removeCut(c),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            );
          },
        );

  Widget _preview(ThemeData th) => Center(
    child: AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(
            color: th.colorScheme.onSurface.withValues(alpha: 0.08),
            child: _c.videoReady
                ? Video(controller: _c.video)
                : const SizedBox.shrink(),
          ),
          ValueListenableBuilder<double>(
            valueListenable: _c.downloadPct,
            builder: (context, v, _) => v >= 100
                ? const SizedBox.shrink()
                : Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      color: th.colorScheme.surface.withValues(alpha: 0.9),
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            L.of(context).downloadProgress(v.round()),
                            style: th.textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: v / 100,
                            color: th.colorScheme.secondary,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );

  Widget _meta(L l, ThemeData th, SermonPlan plan) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('title'),
        controller: _title,
        minLines: 1,
        maxLines: 2,
        maxLength: 100,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter:
            (c, {required currentLength, required isFocused, maxLength}) =>
                isFocused
                ? Text(
                    l.counter(currentLength, maxLength ?? 100),
                    style: th.textTheme.labelMedium,
                  )
                : null,
        style: th.textTheme.titleLarge,
        decoration: InputDecoration(
          labelText: l.title,
          border: const OutlineInputBorder(),
        ),
        onChanged: _c.setTitle,
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 88,
        child: TextField(
          controller: _desc,
          maxLength: 5000,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          buildCounter:
              (c, {required currentLength, required isFocused, maxLength}) =>
                  isFocused
                  ? Text(
                      l.counter(currentLength, maxLength ?? 5000),
                      style: th.textTheme.labelMedium,
                    )
                  : null,
          decoration: InputDecoration(
            labelText: l.description,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: _c.setDescription,
        ),
      ),
      const SizedBox(height: 8),
      Text(l.transcript, style: th.textTheme.titleSmall),
      const SizedBox(height: 4),
      Expanded(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: th.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Transcript(
            segments: _c.segments,
            prayers: _c.prayerMarks,
            position: _c.position,
            onSeek: _c.seek,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          if (_c.saved) ...[
            Icon(
              Icons.check_rounded,
              size: 16,
              color: th.colorScheme.secondary,
            ),
            const SizedBox(width: 4),
            Text(l.saved, style: th.textTheme.labelMedium),
          ],
        ],
      ),
    ],
  );

  Widget _shorts(L l, ThemeData th, SermonPlan plan) => plan.shorts.isEmpty
      ? Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(l.noShorts, style: th.textTheme.bodyMedium),
          ),
        )
      : ListView.builder(
          itemCount: plan.shorts.length,
          itemExtent: 48,
          itemBuilder: (context, i) {
            final s = plan.shorts[i];
            final fault = shortFault(s, plan);
            final secs = (s.end - s.start).round();
            final reason = switch (fault) {
              ShortFault.tooLong => l.shortTooLong(secs),
              ShortFault.tooShort => l.shortTooShort(secs),
              ShortFault.outside => l.shortOutside,
              null => null,
            };
            final err = th.colorScheme.error;
            return Row(
              children: [
                Container(
                  width: 27,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: fault == null ? th.colorScheme.tertiary : err,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (i + 1).toString(),
                    style: th.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 140,
                  child: Text(
                    l.shortRange(formatTime(s.start), formatTime(s.end)),
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Expanded(
                  child: TextFormField(
                    key: ValueKey(('short', i, _c.planRevision, _c.edits)),
                    initialValue: s.title,
                    style: th.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l.shortLength(i + 1),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => _c.setShortTitle(s, v),
                  ),
                ),
                if (reason != null) ...[
                  Icon(Icons.error_outline_rounded, size: 18, color: err),
                  const SizedBox(width: 4),
                  Text(reason, style: TextStyle(color: err)),
                ],
                SizedBox(
                  width: 160,
                  child: Slider(
                    semanticFormatterCallback: (_) => l.shortLength(i + 1),
                    min: 20,
                    max: secs > 120 ? secs.toDouble() : 120,
                    value: secs.clamp(20, 100000).toDouble(),
                    onChanged: (v) =>
                        _c.setShortEnd(s, s.start + v, save: false),
                    onChangeEnd: (_) => _c.commit(),
                  ),
                ),
                TextButton(
                  onPressed: () => _c.setShortStart(s),
                  child: Text(l.startHere),
                ),
                TextButton(
                  onPressed: () {
                    _c.seek(s.start);
                    _c.playPause();
                  },
                  child: Text(l.play),
                ),
                IconButton(
                  tooltip: l.remove,
                  onPressed: () => _c.removeShort(s),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            );
          },
        );

  Widget _actions(L l, ThemeData th) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(onPressed: _c.skip, child: Text(l.skip)),
      const SizedBox(width: 12),
      // A recording without captions has nothing for the LLM to plan from.
      if (_c.segments.isNotEmpty) ...[
        OutlinedButton(onPressed: () => _replan(l), child: Text(l.replan)),
        const SizedBox(width: 12),
      ],
      if (_c.hasShortFault) ...[
        Text(l.approveBlocked, style: TextStyle(color: th.colorScheme.error)),
        const SizedBox(width: 12),
      ],
      FilledButton(
        onPressed: _c.hasShortFault ? null : () => _cut(l),
        child: Text(l.approveAndCut),
      ),
    ],
  );
}

class _Loading extends StatelessWidget {
  const _Loading({required this.c});
  final ReviewController c;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
      builder: (context, _) {
        final text = switch (c.stage) {
          LoadStage.meta => l.stageMeta,
          LoadStage.plan => l.stagePlan,
          LoadStage.cut => l.stageCut,
        };
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 320,
              child: LinearProgressIndicator(
                value: c.stage == LoadStage.cut ? c.cutFraction : null,
                color: th.colorScheme.secondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              c.stage == LoadStage.cut
                  ? l.stageCutPct((c.cutFraction * 100).round())
                  : text,
              style: th.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              l.elapsed(formatTime(c.stopwatch.elapsed.inSeconds.toDouble())),
              style: th.textTheme.labelMedium,
            ),
          ],
        );
      },
    );
  }
}

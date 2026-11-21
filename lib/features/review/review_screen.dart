// @stelsel review_screen
//   soort: skerm
//   wanneer: Hersien (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: die preekredigeerder: preek uit Preke → plan → hakies, I/O, uitknip, transkripsie, Shorts, ontdoen (kortpaaie) → kies uitvoere, Oggend/Aand en soort diens (liedname op die tydlyn) → keur goed en sny
//   status: bou

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../app/theme.dart';
import '../../core/captions.dart';
import '../../core/jobs.dart';
import '../../core/models.dart';
import '../../core/planner.dart';
import '../../core/settings.dart';
import '../../core/store.dart';
import '../../l10n/app_localizations.dart';
import 'review_controller.dart';
import 'service_timeline.dart';
import 'properties_panel.dart';
import 'transport_bar.dart';

/// Hersien, the sermon editor: video, transcript, timeline, cuts, Shorts and actions.
class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, required this.controller, this.onWork});

  /// Owned by the shell, which opens a sermon in it from Preke.
  final ReviewController controller;

  /// Goes to Werk, where the cut runs and "Laai op" follows (V1: Oom Johan must not hunt for it).
  final VoidCallback? onWork;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final _c = widget.controller;
  double _zoom = 1;
  bool _propsOpen = false;
  late final _settings = AppSettings.load(_c.store.root);

  Future<void> _cut(L l) async {
    final m = ScaffoldMessenger.of(context);
    try {
      _c.approveAndCut();
      m.showSnackBar(
        SnackBar(
          content: Text(l.cutQueued),
          action: widget.onWork == null
              ? null
              : SnackBarAction(label: l.navWerk, onPressed: widget.onWork!),
        ),
      );
    } on Object catch (e) {
      m.showSnackBar(SnackBar(content: Text(l.errorGeneric(e.toString()))));
    }
  }

  // stap: v4 5 Beplan weer | loop die grense en die teks weer van voor af as die hele voorstel verkeerd is (bevestiging)
  Future<void> _replan(L l) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(l.replanConfirm),
        actions: [
          TextButton(
            key: const ValueKey('ctl.hersien.replan-cancel'),
            onPressed: () => Navigator.pop(c, false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const ValueKey('ctl.hersien.replan-confirm'),
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
        return Padding(
          padding: const EdgeInsets.all(kPanelGap),
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
              FilledButton(
                key: const ValueKey('ctl.hersien.plan-now'),
                onPressed: _c.replan,
                child: Text(l.planNow),
              ),
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
                  FilledButton(
                    key: const ValueKey('ctl.hersien.retry'),
                    onPressed: _c.replan,
                    child: Text(l.retry),
                  ),
                  if (_c.meta != null) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      key: const ValueKey('ctl.hersien.set-manually'),
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

  // stap: v1 3 Hersien | kyk die hakies by die gebede, die titel, Skriflesing en beskrywing
  // stap: v4 1 Sien die fout | 'n banier wys waarom die kode onseker is en spring na die grens; gebedsmerkers wys waar die gebede is
  // tak: kode onseker → banier met die rede (ARB) en "Gaan na die grens"
  Widget _ready(L l, ThemeData th) {
    final plan = _c.plan!;
    final tokens = th.extension<AppTokens>()!;
    final wide = MediaQuery.sizeOf(context).width >= 1280;
    final props = Material(
      key: const ValueKey('review.properties'),
      color: tokens.panel,
      borderRadius: BorderRadius.circular(kPanelRadius),
      clipBehavior: Clip.antiAlias,
      elevation: wide ? 0 : 8,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: PropertiesPanel(c: _c, settings: _settings),
      ),
    );
    final stage = Material(
      key: const ValueKey('review.stage'),
      color: tokens.panel,
      borderRadius: BorderRadius.circular(kPanelRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: _preview(th)),
            const SizedBox(height: 8),
            ToolBar(c: _c),
            TransportBar(
              c: _c,
              zoom: _zoom,
              onZoom: (v) => setState(() => _zoom = v),
            ),
            const SizedBox(height: 8),
            ServiceTimeline(
              duration: _c.duration,
              blocks: _c.sound,
              levels: _c.levels,
              zoom: _zoom,
              sermonStart: plan.sermonStart,
              sermonEnd: plan.sermonEnd,
              shorts: plan.shorts,
              cuts: plan.cuts,
              prayers: _c.prayerMarks,
              songs: _c.songs,
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
          ],
        ),
      ),
    );
    return Focus(
      autofocus: true,
      onKeyEvent: _key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  plan.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: th.textTheme.titleLarge,
                ),
              ),
              IconButton(
                key: const ValueKey('ctl.hersien.undo'),
                tooltip: l.undo,
                onPressed: _c.canUndo ? _c.undo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              IconButton(
                key: const ValueKey('ctl.hersien.redo'),
                tooltip: l.redo,
                onPressed: _c.canRedo ? _c.redo : null,
                icon: const Icon(Icons.redo_rounded),
              ),
              if (!wide)
                IconButton(
                  key: const ValueKey('ctl.hersien.properties-toggle'),
                  tooltip: l.properties,
                  isSelected: _propsOpen,
                  onPressed: () => setState(() => _propsOpen = !_propsOpen),
                  icon: const Icon(Icons.tune_rounded),
                ),
            ],
          ),
          if (plan.doubt != null) ...[
            _doubt(l, th, plan.doubt!),
            const SizedBox(height: kPanelGap),
          ],
          Expanded(
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: stage),
                      const SizedBox(width: kPanelGap),
                      SizedBox(width: 380, child: props),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned.fill(child: stage),
                      if (_propsOpen)
                        Positioned(
                          top: 0,
                          bottom: 0,
                          right: 0,
                          width: 380,
                          child: props,
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: kPanelGap),
          _actions(l, th),
        ],
      ),
    );
  }

  /// Why the code is unsure of the cut, with a jump to the boundary to check.
  Widget _doubt(L l, ThemeData th, BoundsDoubt d) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: th.colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: th.colorScheme.onTertiaryContainer,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(switch (d) {
            BoundsDoubt.noSermon => l.doubtNoSermon,
            BoundsDoubt.noPrayerBefore => l.doubtNoPrayerBefore,
            BoundsDoubt.noPrayerAfter => l.doubtNoPrayerAfter,
            BoundsDoubt.twoSermons => l.doubtTwoSermons,
          }, style: TextStyle(color: th.colorScheme.onTertiaryContainer)),
        ),
        TextButton(
          key: const ValueKey('ctl.hersien.go-to-boundary'),
          onPressed: () => _c.seek(
            d == BoundsDoubt.noPrayerAfter
                ? _c.plan!.sermonEnd
                : _c.plan!.sermonStart,
          ),
          child: Text(l.goToBoundary),
        ),
      ],
    ),
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

  Widget _actions(L l, ThemeData th) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(
        key: const ValueKey('ctl.hersien.skip'),
        onPressed: _c.skip,
        child: Text(l.skip),
      ),
      const SizedBox(width: 12),
      // A recording without captions has nothing for the LLM to plan from.
      if (_c.segments.isNotEmpty) ...[
        OutlinedButton(
          key: const ValueKey('ctl.hersien.replan'),
          onPressed: () => _replan(l),
          child: Text(l.replan),
        ),
        const SizedBox(width: 12),
      ],
      if (_c.hasShortFault) ...[
        Text(l.approveBlocked, style: TextStyle(color: th.colorScheme.error)),
        const SizedBox(width: 12),
      ],
      if (_uploaded) ...[
        OutlinedButton(
          key: const ValueKey('ctl.hersien.approve'),
          onPressed: _c.hasShortFault ? null : () => _cut(l),
          child: Text(l.approveAndCut),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          key: const ValueKey('ctl.hersien.push'),
          onPressed: _c.updating ? null : () => _push(l),
          icon: _c.updating
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_upload_rounded),
          label: Text(l.updateOnYouTube),
        ),
      ] else
        FilledButton(
          key: const ValueKey('ctl.hersien.approve'),
          onPressed: _c.hasShortFault ? null : () => _cut(l),
          child: Text(l.approveAndCut),
        ),
    ],
  );

  bool get _uploaded =>
      _c.updateYouTube != null && _c.sermon?.state == SermonState.opgelaai;

  // stap: v8 2 Werk op YouTube by | knoppie verskyn net vir 'n opgelaaide preek; strook sê hoeveel video's
  // tak: geen internet of video weg → strook met friendlyError
  /// V8: a mistake after upload; the edited title and description go to YouTube without a new upload.
  Future<void> _push(L l) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final n = await _c.pushToYouTube();
      m.showSnackBar(SnackBar(content: Text(l.updatedOnYouTube(n))));
    } on Object catch (e) {
      m.showSnackBar(SnackBar(content: Text(friendlyError(e))));
    }
  }
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

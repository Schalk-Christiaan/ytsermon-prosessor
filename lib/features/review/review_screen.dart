// @stelsel review_screen
//   soort: skerm
//   wanneer: Hersien (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: URL → plan → hersien op die dienstydlyn → keur goed en sny
//   status: oop

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../core/captions.dart';
import '../../core/models.dart';
import '../../core/tools.dart';
import '../../l10n/app_localizations.dart';
import 'review_controller.dart';
import 'service_timeline.dart';

class ReviewScreen extends StatefulWidget {
  const ReviewScreen({super.key, this.controller});

  /// Injected by tests; the app lets the screen own its controller.
  final ReviewController? controller;

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  late final _c = widget.controller ?? ReviewController();
  final _url = TextEditingController();
  final _title = TextEditingController();
  final _desc = TextEditingController();
  int _synced = -1;

  @override
  void dispose() {
    if (widget.controller == null) _c.dispose();
    _url.dispose();
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _syncFields() {
    if (_c.state == ReviewState.ready && _synced != _c.planRevision) {
      _synced = _c.planRevision;
      _title.text = _c.plan!.title;
      _desc.text = _c.plan!.description;
    }
  }

  Future<void> _cut(L l) async {
    final m = ScaffoldMessenger.of(context);
    try {
      final (s, sh, out) = await _c.approveAndCut();
      m.showSnackBar(
        SnackBar(
          content: Text(l.cutDone(s, sh)),
          action: SnackBarAction(
            label: l.showInFolder,
            onPressed: () => openFolder(out),
          ),
        ),
      );
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
            children: [
              _urlBar(l),
              const SizedBox(height: 16),
              Expanded(child: _body(l)),
            ],
          ),
        );
      },
    );
  }

  Widget _urlBar(L l) {
    final busy = _c.state == ReviewState.loading;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _url,
            autofocus: true,
            enabled: !busy,
            decoration: InputDecoration(
              labelText: l.pasteUrl,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (v) => _c.load(v),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: busy ? null : () => _c.load(_url.text),
          child: Text(l.load),
        ),
      ],
    );
  }

  Widget _body(L l) {
    final th = Theme.of(context);
    switch (_c.state) {
      case ReviewState.empty:
        return Center(
          child: Text(l.emptyReview, style: th.textTheme.titleMedium),
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
                    onPressed: () => _c.load(_url.text),
                    child: Text(l.retry),
                  ),
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

  Widget _ready(L l, ThemeData th) {
    final plan = _c.plan!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _preview(th)),
              const SizedBox(width: 24),
              SizedBox(width: 360, child: _meta(l, th, plan)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(l.serviceTimeline, style: th.textTheme.titleMedium),
        const SizedBox(height: 8),
        ServiceTimeline(
          duration: _c.duration,
          blocks: _c.blocks,
          sermonStart: plan.sermonStart,
          sermonEnd: plan.sermonEnd,
          shorts: plan.shorts,
          position: _c.position,
          animateKey: _c.planRevision,
          onSeek: _c.seek,
          onSermonChanged: (s, e) => _c.setSermon(s, e, save: false),
          onSermonCommit: _c.commit,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(l.shorts, style: th.textTheme.titleMedium),
            const SizedBox(width: 16),
            TextButton.icon(
              onPressed: () => _c.addShort(l.newShortTitle),
              icon: const Icon(Icons.add_rounded),
              label: Text(l.addShort),
            ),
          ],
        ),
        SizedBox(height: 96, child: _shorts(l, th, plan)),
        const SizedBox(height: 12),
        _actions(l),
      ],
    );
  }

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
        controller: _title,
        maxLength: 100,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter:
            (c, {required currentLength, required isFocused, maxLength}) =>
                Text(
                  l.counter(currentLength, maxLength ?? 100),
                  style: th.textTheme.labelMedium,
                ),
        style: th.textTheme.headlineSmall,
        decoration: InputDecoration(
          labelText: l.title,
          border: const OutlineInputBorder(),
        ),
        onChanged: _c.setTitle,
      ),
      const SizedBox(height: 12),
      Expanded(
        child: TextField(
          controller: _desc,
          maxLength: 5000,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          buildCounter:
              (c, {required currentLength, required isFocused, maxLength}) =>
                  Text(
                    l.counter(currentLength, maxLength ?? 5000),
                    style: th.textTheme.labelMedium,
                  ),
          decoration: InputDecoration(
            labelText: l.description,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: _c.setDescription,
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

  Widget _shorts(L l, ThemeData th, SermonPlan plan) => ListView.builder(
    itemCount: plan.shorts.length,
    itemExtent: 48,
    itemBuilder: (context, i) {
      final s = plan.shorts[i];
      return Row(
        children: [
          Container(
            width: 27,
            height: 44,
            decoration: BoxDecoration(
              border: Border.all(color: th.colorScheme.tertiary, width: 2),
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text((i + 1).toString(), style: th.textTheme.labelMedium),
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
          Expanded(child: Text(s.title, overflow: TextOverflow.ellipsis)),
          TextButton(
            onPressed: () => _c.seek(s.start),
            child: Text(l.shortPreview(i + 1)),
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

  Widget _actions(L l) => Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      TextButton(onPressed: _c.reset, child: Text(l.skip)),
      const SizedBox(width: 12),
      OutlinedButton(onPressed: () => _replan(l), child: Text(l.replan)),
      const SizedBox(width: 12),
      FilledButton(onPressed: () => _cut(l), child: Text(l.approveAndCut)),
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

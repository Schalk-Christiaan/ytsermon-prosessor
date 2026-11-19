// @stelsel work_screen
//   soort: skerm
//   wanneer: Werk (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: wys die werkry: huidige taak met vordering en Kanselleer, wag-, klaar- en fout-lyste
//   status: oop
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/jobs.dart';
import '../../core/store.dart';
import '../../core/tools.dart';
import '../../l10n/app_localizations.dart';

class WorkScreen extends StatelessWidget {
  const WorkScreen({
    super.key,
    required this.store,
    required this.jobs,
    required this.onBack,
    this.open = openPath,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Esc: back to Preke.
  final VoidCallback onBack;

  /// Test seam: opens a file (default: the system player / file manager).
  final Future<void> Function(String path, {bool select}) open;

  String _title(Job j) => store.byId(j.sermon)?.title ?? j.sermon;

  String _kind(L l, Job j) => j.kind == JobKind.plan ? l.taskPlan : l.taskCut;

  String _phase(L l, JobPhase? p) => switch (p) {
    JobPhase.meta || null => l.stageMeta,
    JobPhase.plan => l.stagePlan,
    JobPhase.download => l.stageDownload,
    JobPhase.cut => l.stageCut,
  };

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onBack},
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: jobs,
          builder: (context, _) {
            final cur = jobs.current;
            final waiting = jobs.jobs.where((j) => j.status == JobStatus.wag);
            final done = jobs.jobs.reversed.where(
              (j) => j.status == JobStatus.klaar,
            );
            final failed = jobs.jobs.where(
              (j) =>
                  j.status == JobStatus.fout ||
                  j.status == JobStatus.gekanselleer,
            );
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(l.navWerk, style: th.textTheme.headlineMedium),
                const SizedBox(height: 16),
                if (jobs.jobs.isEmpty) Text(l.workEmpty),
                if (cur != null) _current(l, th, cur),
                if (waiting.isNotEmpty) _section(l.workWaiting, th),
                for (final j in waiting) _line(l, th, j),
                if (failed.isNotEmpty) _section(l.workFailed, th),
                for (final j in failed) _failed(l, th, j),
                if (done.isNotEmpty) _section(l.workDone, th),
                for (final j in done) _done(l, th, j),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _section(String text, ThemeData th) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Text(text, style: th.textTheme.headlineSmall),
  );

  Widget _current(L l, ThemeData th, Job j) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        l.taskLine(_kind(l, j), _title(j)),
        style: th.textTheme.headlineSmall,
      ),
      const SizedBox(height: 12),
      ValueListenableBuilder<JobPhase?>(
        valueListenable: jobs.phase,
        builder: (context, phase, _) => ValueListenableBuilder<double?>(
          valueListenable: jobs.progress,
          builder: (context, v, _) => Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: v,
                  color: th.colorScheme.secondary,
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 56,
                child: Text(
                  v == null ? '' : l.percent((v * 100).round()),
                  style: th.textTheme.labelMedium,
                ),
              ),
              Text(_phase(l, phase)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(onPressed: jobs.cancel, child: Text(l.cancel)),
    ],
  );

  Widget _line(L l, ThemeData th, Job j, {Widget? trailing}) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: Text(
            l.taskLine(_kind(l, j), _title(j)),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _done(L l, ThemeData th, Job j) {
    final out = store.byId(j.sermon)?.outputs ?? const [];
    return _line(
      l,
      th,
      j,
      trailing: j.kind == JobKind.cut && out.isNotEmpty
          ? Row(
              children: [
                TextButton(
                  onPressed: () => open(out.first),
                  child: Text(l.play),
                ),
                TextButton(
                  onPressed: () => open(out.first, select: true),
                  child: Text(l.showInFolder),
                ),
              ],
            )
          : null,
    );
  }

  Widget _failed(L l, ThemeData th, Job j) {
    final cancelled = j.status == JobStatus.gekanselleer;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(
          l,
          th,
          j,
          trailing: TextButton(
            onPressed: () => jobs.retry(j),
            child: Text(l.retry),
          ),
        ),
        Row(
          children: [
            Icon(
              cancelled ? Icons.cancel_rounded : Icons.error_rounded,
              size: 18,
              color: th.colorScheme.error,
            ),
            const SizedBox(width: 6),
            Text(
              cancelled ? l.taskCancelled : j.error ?? '',
              style: TextStyle(color: th.colorScheme.error),
            ),
          ],
        ),
        if (j.log.isNotEmpty)
          ExpansionTile(
            title: Text(l.technicalLog),
            tilePadding: EdgeInsets.zero,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(
                  j.log.join('\n'),
                  style: th.textTheme.bodySmall,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

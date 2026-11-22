// @stelsel job_progress
//   soort: module
//   wanneer: Werk-skerm, Hersien-laai, Opstel en oral waar iets wag
//   groep: app | App-raam
//   skryf: —
//   doel: gedeelde vorderingswyer: stappelys van die taak se fases (huidige vet), balk met persentasie, detailreël, tyd sedert begin, onbepaald-met-woorde en uitvoubare besonderhede (laaste 20 reëls)
//   status: bou
import 'pixel_scenes.dart';

import 'package:flutter/material.dart';

import '../core/captions.dart' show formatTime;
import '../core/jobs.dart';
import '../l10n/app_localizations.dart';

/// The one thin progress bar used everywhere (secondary colour; [value] null = unknown).
class ProgressLine extends StatelessWidget {
  const ProgressLine({super.key, this.value});
  final double? value;

  @override
  Widget build(BuildContext context) => LinearProgressIndicator(
    value: value,
    color: Theme.of(context).colorScheme.secondary,
  );
}

/// The phases a job of [kind] goes through, in order.
List<JobPhase> stepsOf(JobKind kind) => switch (kind) {
  JobKind.plan => [JobPhase.meta, JobPhase.download, JobPhase.plan],
  JobKind.cut => [JobPhase.meta, JobPhase.download, JobPhase.cut],
  JobKind.audio => [JobPhase.audio],
  JobKind.upload => [JobPhase.upload],
};

String _step(L l, JobPhase p) => switch (p) {
  JobPhase.meta => l.stepMeta,
  JobPhase.download => l.stepDownload,
  JobPhase.plan => l.stepPlan,
  JobPhase.cut => l.stepCut,
  JobPhase.audio => l.stepAudio,
  JobPhase.upload => l.stepUpload,
};

/// Shows the running job of [jobs]: steps, bar, detail, elapsed time and the output.
class JobProgress extends StatefulWidget {
  const JobProgress({super.key, required this.jobs});
  final JobQueue jobs;

  @override
  State<JobProgress> createState() => _JobProgressState();
}

class _JobProgressState extends State<JobProgress> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context), th = Theme.of(context), q = widget.jobs;
    final job = q.current;
    if (job == null) return const SizedBox.shrink();
    return ListenableBuilder(
      listenable: Listenable.merge([q.phase, q.progress, q.detail, q.output]),
      builder: (context, _) {
        final steps = stepsOf(job.kind);
        final at = steps.indexOf(q.phase.value ?? steps.first);
        final v = q.progress.value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            phaseScene(
              steps[at],
              progress: v,
              shorts: q.detail.value?.startsWith('Short') ?? false,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                for (final (i, s) in steps.indexed)
                  Text(
                    i < at
                        ? '✓ ${_step(l, s)}'
                        : i == at
                        ? '● ${_step(l, s)}'
                        : _step(l, s),
                    style: th.textTheme.titleSmall?.copyWith(
                      fontWeight: i == at ? FontWeight.w700 : FontWeight.w400,
                      color: i > at ? th.colorScheme.onSurfaceVariant : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ProgressLine(value: v)),
                const SizedBox(width: 16),
                SizedBox(
                  width: 56,
                  child: Text(
                    v == null ? '' : l.percent((v * 100).round()),
                    style: th.textTheme.labelMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (q.detail.value != null) Text(q.detail.value!),
            if (v == null)
              Text(l.progressSlow, style: th.textTheme.labelMedium),
            StreamBuilder<int>(
              stream: Stream.periodic(const Duration(seconds: 1), (i) => i),
              builder: (context, _) => Text(
                l.elapsed(
                  formatTime(
                    DateTime.now()
                        .difference(q.started ?? DateTime.now())
                        .inSeconds
                        .toDouble(),
                  ),
                ),
                style: th.textTheme.labelMedium,
              ),
            ),
            TextButton(
              key: const ValueKey('ctl.werk.details'),
              onPressed: () => setState(() => _open = !_open),
              child: Text(_open ? l.progressHide : l.progressShow),
            ),
            if (_open)
              SelectableText(
                q.output.value.join('\n'),
                style: th.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
          ],
        );
      },
    );
  }
}

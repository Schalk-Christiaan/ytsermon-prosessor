// @stelsel work_screen
//   soort: skerm
//   wanneer: Werk (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: wys die werkry: huidige taak met vordering en Kanselleer, wag-, klaar- en fout-lyste; klaar-items: Speel, Wys in gids, Klank vir WhatsApp, Kopieer WhatsApp-teks, Laai op, Wys op YouTube; oplaai-teller
//   status: klaar
//   bewys: 7236634
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as p;

import '../../core/cutter.dart' show kWhatsappTemplate;
import '../../core/jobs.dart';
import '../../core/library.dart';
import '../../core/store.dart';
import '../../core/tools.dart';
import '../../core/youtube.dart';
import '../../l10n/app_localizations.dart';

/// Werkry: the running job with progress, then done and failed jobs with their actions.
class WorkScreen extends StatelessWidget {
  const WorkScreen({
    super.key,
    required this.store,
    required this.jobs,
    required this.onBack,
    this.open = openPath,
    this.quota,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Esc: back to Preke.
  final VoidCallback onBack;

  /// Test seam: opens a file (default: the system player / file manager).
  final Future<void> Function(String path, {bool select}) open;

  /// Today's upload count; null hides the line.
  final UploadQuota? quota;

  String _title(Job j) => store.byId(j.sermon)?.title ?? j.sermon;

  String _kind(L l, Job j) => switch (j.kind) {
    JobKind.plan => l.taskPlan,
    JobKind.cut => l.taskCut,
    JobKind.audio => l.taskAudio,
    JobKind.upload => l.taskUpload,
  };

  String _phase(L l, JobPhase? p) => switch (p) {
    JobPhase.meta || null => l.stageMeta,
    JobPhase.plan => l.stagePlan,
    JobPhase.download => l.stageDownload,
    JobPhase.cut => l.stageCut,
    JobPhase.audio => l.stageAudio,
    JobPhase.upload => l.stageUpload,
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
                if (quota != null)
                  Text(
                    l.quotaToday(quota!.used, UploadQuota.limit),
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
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
      OutlinedButton(
        key: const ValueKey('ctl.werk.cancel'),
        onPressed: jobs.cancel,
        child: Text(l.cancel),
      ),
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

  // stap: v7 1 WhatsApp-klank | by die gesnyde preek in Werkry; een klik
  // stap: v7 3 Wys in gids | maak die gids met die mp3 oop om in WhatsApp te sleep
  Widget _done(L l, ThemeData th, Job j) {
    final s = store.byId(j.sermon);
    final out = s?.outputs ?? const <String>[];
    if (j.kind == JobKind.upload) {
      final id = s?.uploads[out.firstOrNull];
      return _line(
        l,
        th,
        j,
        trailing: id == null
            ? null
            : TextButton(
                key: const ValueKey('ctl.werk.open-youtube'),
                onPressed: () =>
                    open('https://studio.youtube.com/video/$id/edit'),
                child: Text(l.openOnYouTube),
              ),
      );
    }
    // A cut job offers its sermon video; an audio job its mp3.
    final ext = j.kind == JobKind.audio ? '.mp3' : '.mp4';
    final file = out.where((o) => o.endsWith(ext)).firstOrNull;
    if (j.kind == JobKind.plan || file == null) return _line(l, th, j);
    return _line(
      l,
      th,
      j,
      trailing: Row(
        children: [
          TextButton(
            key: const ValueKey('ctl.werk.play'),
            onPressed: () => open(file),
            child: Text(l.play),
          ),
          TextButton(
            key: const ValueKey('ctl.werk.show'),
            onPressed: () => open(file, select: true),
            child: Text(l.showInFolder),
          ),
          Builder(
            builder: (ctx) => TextButton(
              key: const ValueKey('ctl.werk.copy'),
              onPressed: () => _copyWhatsapp(ctx, l, file),
              child: Text(l.copyWhatsappText),
            ),
          ),
          if (j.kind == JobKind.cut) ...[
            TextButton(
              key: const ValueKey('ctl.werk.audio'),
              onPressed: () => jobs.enqueue(j.sermon, JobKind.audio),
              child: Text(l.whatsappAudio),
            ),
            if (s?.state != SermonState.opgelaai)
              TextButton(
                key: const ValueKey('ctl.werk.upload'),
                onPressed: () => jobs.enqueue(j.sermon, JobKind.upload),
                child: Text(l.upload),
              ),
          ],
        ],
      ),
    );
  }

  // stap: diensindeling 11 Kopieer WhatsApp-teks | die teks langs die uitvoere (WhatsApp.txt) op die knipbord, om saam met die klank te plak
  /// Puts the `WhatsApp.txt` next to [file] on the clipboard.
  Future<void> _copyWhatsapp(BuildContext context, L l, String file) async {
    final s = readService(Directory(p.dirname(file)));
    if (s == null) return;
    final m = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: libraryWhatsapp(s, kWhatsappTemplate)),
    );
    m.showSnackBar(SnackBar(content: Text(l.whatsappTextCopied)));
  }

  // stap: v5 3 Mislukte taak | rooi ikoon, die rede en Probeer weer
  // stap: v9 2 Werkry wys die rede | die sin uit friendlyError onder die taak, met Probeer weer
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
            key: const ValueKey('ctl.werk.retry'),
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
            key: const ValueKey('ctl.werk.log'),
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

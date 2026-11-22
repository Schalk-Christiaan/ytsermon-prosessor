// @stelsel work_screen
//   soort: skerm
//   wanneer: Werk (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: wys die werkry: huidige taak met vordering en Kanselleer, wag- en fout-lyste, voorgestelde snitlyste (Aanvaar/Ignoreer), en die uitvoere in drie groepe (Volle preke, Shorts, Klank vir WhatsApp) met kies-alles en 'n aftreklys per groep (Laai op, Kopieer na gids, Wys in gids, Kopieer WhatsApp-teks, Klank vir WhatsApp); oplaai-teller
//   status: bou
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:path/path.dart' as p;

import '../../core/cutter.dart' show kFullName, kWhatsappTemplate, kWordName;
import '../../core/jobs.dart';
import '../../core/library.dart';
import '../../core/storage.dart' show formatBytes;
import '../../core/store.dart';
import '../../core/suggest.dart';
import '../../core/tools.dart';
import '../../core/youtube.dart';
import '../../l10n/app_localizations.dart';

/// The three groups of outputs on the Werk screen.
enum WorkGroup { full, shorts, audio }

/// One output file and the sermon it belongs to.
class WorkItem {
  const WorkItem(this.sermon, this.path);
  final Sermon sermon;
  final String path;
}

/// Picks a folder to copy into; null when cancelled.
Future<String?> pickFolder() => getDirectoryPath();

/// Werkry: the running job with progress, then the outputs in groups (full sermons, Shorts, audio) with their actions.
class WorkScreen extends StatefulWidget {
  const WorkScreen({
    super.key,
    required this.store,
    required this.jobs,
    required this.onBack,
    this.open = openPath,
    this.quota,
    this.pickDir = pickFolder,
    this.onSelection,
    this.suggestions,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Esc: back to Preke.
  final VoidCallback onBack;

  /// Test seam: opens a file (default: the system player / file manager).
  final Future<void> Function(String path, {bool select}) open;

  /// Today's upload count; null hides the line.
  final UploadQuota? quota;

  /// Test seam: the folder picker for "Kopieer na gids…".
  final Future<String?> Function() pickDir;

  /// Status-bar text for the selection, null when nothing is selected.
  final void Function(String?)? onSelection;

  /// Playlist suggestions made after a render; null hides the section.
  final GroupSuggestions? suggestions;

  @override
  State<WorkScreen> createState() => _WorkScreenState();
}

class _WorkScreenState extends State<WorkScreen> {
  final _sel = <String>{};
  final _sizes = <String, int>{};
  String? _reported;

  SermonStore get store => widget.store;
  JobQueue get jobs => widget.jobs;

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

  WorkGroup _groupOf(String path) {
    if (path.endsWith('.mp3')) return WorkGroup.audio;
    final n = p.basename(path);
    return n == '$kFullName.mp4' || n == '$kWordName.mp4'
        ? WorkGroup.full
        : WorkGroup.shorts;
  }

  /// Every output file of every sermon (newest sermon first), by group.
  Map<WorkGroup, List<WorkItem>> _items() {
    final m = {for (final g in WorkGroup.values) g: <WorkItem>[]};
    for (final s in store.sorted) {
      for (final o in s.outputs) {
        if (o.endsWith('.mp4') || o.endsWith('.mp3')) {
          m[_groupOf(o)]!.add(WorkItem(s, o));
        }
      }
    }
    return m;
  }

  int _size(String path) => _sizes.putIfAbsent(path, () {
    try {
      return File(path).lengthSync();
    } on FileSystemException {
      return 0;
    }
  });

  String _groupName(L l, WorkGroup g) => switch (g) {
    WorkGroup.full => l.groupFull,
    WorkGroup.shorts => l.groupShorts,
    WorkGroup.audio => l.whatsappAudio,
  };

  /// Tells the shell's status bar what is selected in total.
  void _report(L l, Map<WorkGroup, List<WorkItem>> all) {
    final items = [for (final g in all.values) ...g];
    final sel = items.where((i) => _sel.contains(i.path)).toList();
    final text = sel.isEmpty
        ? null
        : l.statusSelected(
            sel.length,
            items.length,
            formatBytes(sel.fold(0, (a, i) => a + _size(i.path))),
          );
    if (text == _reported) return;
    _reported = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelection?.call(text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): widget.onBack,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: Listenable.merge([jobs, ?widget.suggestions]),
          builder: (context, _) {
            final cur = jobs.current;
            final waiting = jobs.jobs.where((j) => j.status == JobStatus.wag);
            final failed = jobs.jobs.where(
              (j) =>
                  j.status == JobStatus.fout ||
                  j.status == JobStatus.gekanselleer,
            );
            final groups = _items();
            _sel.retainAll([
              for (final g in groups.values) ...g.map((i) => i.path),
            ]);
            _report(l, groups);
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(l.navWerk, style: th.textTheme.headlineMedium),
                if (widget.quota != null)
                  Text(
                    l.quotaToday(widget.quota!.used, UploadQuota.limit),
                    style: th.textTheme.bodyMedium?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const SizedBox(height: 16),
                if (jobs.jobs.isEmpty && groups.values.every((g) => g.isEmpty))
                  Text(l.workEmpty),
                if (cur != null) _current(l, th, cur),
                if (waiting.isNotEmpty) _section(l.workWaiting, th),
                for (final j in waiting) _line(l, th, j),
                if (failed.isNotEmpty) _section(l.workFailed, th),
                for (final j in failed) _failed(l, th, j),
                ..._suggested(l, th),
                for (final g in WorkGroup.values)
                  ..._group(l, th, g, groups[g]!),
              ],
            );
          },
        ),
      ),
    );
  }

  /// One row per sermon with suggested playlists: the names, Aanvaar and Ignoreer.
  List<Widget> _suggested(L l, ThemeData th) {
    final sug = widget.suggestions;
    if (sug == null || sug.pending.isEmpty) return const [];
    return [
      _section(l.workSuggestions, th),
      for (final (i, e) in sug.pending.entries.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l.suggestFor(
                    store.byId(e.key)?.title ?? e.key,
                    sug.names(e.value).join(', '),
                  ),
                  style: th.textTheme.bodyLarge,
                ),
              ),
              TextButton(
                key: ValueKey('ctl.werk.suggest-ignore.$i'),
                onPressed: () => sug.ignore(e.key),
                child: Text(l.suggestIgnore),
              ),
              FilledButton(
                key: ValueKey('ctl.werk.suggest-accept.$i'),
                onPressed: () => sug.accept(e.key),
                child: Text(l.suggestAcceptOne),
              ),
            ],
          ),
        ),
    ];
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

  // volle preke, Shorts en klank elk met kies-alles, telling en 'n aksie-kieslys
  List<Widget> _group(L l, ThemeData th, WorkGroup g, List<WorkItem> items) {
    final n = items.where((i) => _sel.contains(i.path)).length;
    final total = items.fold(0, (a, i) => a + _size(i.path));
    final name = g.name;
    return [
      Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Container(
          height: 40,
          color: th.colorScheme.surfaceContainer,
          child: Row(
            children: [
              SizedBox(
                width: 40,
                child: Checkbox(
                  key: ValueKey('ctl.werk.select-$name'),
                  tristate: true,
                  value: n == 0 ? false : (n == items.length ? true : null),
                  onChanged: items.isEmpty
                      ? null
                      : (_) => setState(() {
                          final ids = items.map((i) => i.path);
                          n == items.length
                              ? _sel.removeAll(ids)
                              : _sel.addAll(ids);
                        }),
                ),
              ),
              Text(
                _groupName(l, g),
                style: th.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                l.workGroupCount(items.length, formatBytes(total)),
                key: ValueKey('werk.count-$name'),
                style: th.textTheme.labelMedium,
              ),
              const Spacer(),
              _menu(l, g, items, ValueKey('ctl.werk.menu-$name')),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
      for (final i in items) _row(l, th, g, i),
    ];
  }

  /// The items an action works on: the selected ones of [g], else all of them.
  List<WorkItem> _targets(List<WorkItem> items) {
    final sel = items.where((i) => _sel.contains(i.path)).toList();
    return sel.isEmpty ? items : sel;
  }

  // Laai op, Kopieer na gids, Wys in gids en WhatsApp-aksies vir die gekose items van die groep
  Widget _menu(L l, WorkGroup g, List<WorkItem> items, Key key) => Builder(
    builder: (ctx) {
      Widget entry(String k, String text, VoidCallback f) => MenuItemButton(
        key: ValueKey('ctl.werk.$k'),
        onPressed: f,
        child: Text(text),
      );
      List<Widget> kids() {
        List<WorkItem> t() => _targets(items);
        return [
          if (g != WorkGroup.audio) ...[
            entry(
              'upload-public',
              g == WorkGroup.shorts ? l.uploadShortsPublic : l.uploadPublic,
              () => _upload(t(), 'public'),
            ),
            entry(
              'upload-unlisted',
              l.uploadUnlisted,
              () => _upload(t(), 'unlisted'),
            ),
          ],
          if (g == WorkGroup.full)
            entry('audio', l.whatsappAudio, () => _audio(t())),
          if (g == WorkGroup.audio)
            entry('copy', l.copyWhatsappText, () => _copyText(ctx, l, t())),
          entry('copy-to', l.copyToFolder, () => _copyTo(ctx, l, t())),
          entry(
            'show',
            l.showInFolder,
            () => widget.open(t().first.path, select: true),
          ),
        ];
      }

      return MenuAnchor(
        menuChildren: kids(),
        builder: (_, c, _) => FilledButton(
          key: key,
          onPressed: items.isEmpty
              ? null
              : () => c.isOpen ? c.close() : c.open(),
          child: Text(g == WorkGroup.audio ? l.workShare : l.upload),
        ),
      );
    },
  );

  void _upload(List<WorkItem> items, String privacy) {
    final by = <String, List<String>>{};
    for (final i in items) {
      (by[i.sermon.id] ??= []).add(i.path);
    }
    by.forEach(
      (id, paths) =>
          jobs.enqueue(id, JobKind.upload, privacy: privacy, only: paths),
    );
  }

  void _audio(List<WorkItem> items) {
    for (final id in {for (final i in items) i.sermon.id}) {
      jobs.enqueue(id, JobKind.audio);
    }
  }

  void _copyText(BuildContext ctx, L l, List<WorkItem> items) =>
      _copyWhatsapp(ctx, l, items.first.path);

  /// Copies the files into a folder Schalk picks.
  Future<void> _copyTo(BuildContext ctx, L l, List<WorkItem> items) async {
    final m = ScaffoldMessenger.of(ctx);
    final dir = await widget.pickDir();
    if (dir == null) return;
    for (final i in items) {
      await File(i.path).copy(p.join(dir, p.basename(i.path)));
    }
    m.showSnackBar(SnackBar(content: Text(l.workCopied(items.length))));
  }

  // stap: v7 1 WhatsApp-klank | by die gesnyde preek in Werkry; een klik
  // stap: v7 3 Wys in gids | maak die gids met die mp3 oop om in WhatsApp te sleep
  Widget _row(L l, ThemeData th, WorkGroup g, WorkItem it) {
    final id = it.sermon.uploads[it.path];
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Checkbox(
              key: const ValueKey('ctl.werk.select'),
              value: _sel.contains(it.path),
              onChanged: (v) => setState(() {
                v == true ? _sel.add(it.path) : _sel.remove(it.path);
              }),
            ),
          ),
          Expanded(
            child: InkWell(
              key: const ValueKey('ctl.werk.play'),
              onTap: () => widget.open(it.path),
              child: SizedBox(
                height: 32,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${it.sermon.title} · ${p.basenameWithoutExtension(it.path)}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Text(
              formatBytes(_size(it.path)),
              textAlign: TextAlign.end,
              style: th.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          if (id != null)
            TextButton(
              key: const ValueKey('ctl.werk.open-youtube'),
              onPressed: () =>
                  widget.open('https://studio.youtube.com/video/$id/edit'),
              child: Text(l.openOnYouTube),
            ),
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

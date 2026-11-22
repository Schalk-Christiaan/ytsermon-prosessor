// @stelsel sermons_screen
//   soort: skerm
//   wanneer: Preke (rail, tuis)
//   groep: features | Skerms
//   skryf: —
//   doel: die hele kanaal (uit instellings) as tabel (Titel, Datum, Lengte, Stand, Grootte; klik op opskrif sorteer) of rooster; filter (ook "Nie opgelaai nie"), soek; "Verwerk nuutste diens" → plan → Hersien; "Verwerk volgende" → werkry; "Voer opname in" (knoppie of insleep) → Hersien
//   status: bou
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';

import '../../app/job_progress.dart' show MiniProgress;
import '../../app/pixel_scenes.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/captions.dart' show formatTime;
import '../../core/channel.dart';
import '../../core/jobs.dart';
import '../../core/recording.dart';
import '../../core/settings.dart';
import '../../core/storage.dart';
import '../../core/store.dart';
import '../../l10n/app_localizations.dart';
import '../settings/settings_screen.dart';
import '../settings/system_status.dart';

/// The word for a sermon state, so state is never shown by colour alone.
String stateLabel(L l, SermonState s) => switch (s) {
  SermonState.nuut => l.stateNuut,
  SermonState.beplan => l.stateBeplan,
  SermonState.goedgekeur => l.stateGoedgekeur,
  SermonState.gesny => l.stateGesny,
  SermonState.opgelaai => l.stateOpgelaai,
  SermonState.fout => l.stateFout,
  SermonState.oorgeslaan => l.stateOorgeslaan,
};

/// The icon for a sermon state.
IconData stateIcon(SermonState s) => switch (s) {
  SermonState.nuut => Icons.fiber_new_rounded,
  SermonState.beplan => Icons.fact_check_rounded,
  SermonState.goedgekeur => Icons.thumb_up_alt_rounded,
  SermonState.gesny => Icons.content_cut_rounded,
  SermonState.opgelaai => Icons.cloud_done_rounded,
  SermonState.fout => Icons.error_rounded,
  SermonState.oorgeslaan => Icons.skip_next_rounded,
};

/// Preke: the channel's sermons with state, filters, process and import.
class SermonsScreen extends StatefulWidget {
  const SermonsScreen({
    super.key,
    required this.store,
    required this.jobs,
    required this.onOpen,
    this.list,
    this.pickVideo = pickVideoFile,
    this.importFile,
    this.settings,
    this.sizes,
    this.onSelection,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Row tap: open this sermon in Hersien.
  final void Function(String id) onOpen;

  /// Test seam: the channel lister (default: the channel set in Instellings).
  final Future<List<ChannelItem>> Function()? list;

  /// Test seams for "Voer opname in"; [importFile] defaults to [importRecording] into [store].
  final Future<String?> Function() pickVideo;
  final Future<Sermon> Function(File f, String title, DateTime date)?
  importFile;

  /// Test seam: folder sizes by sermon ID (default: [sermonSizes] under the store's root).
  final Future<Map<String, int>> Function(List<String> ids)? sizes;

  /// Status-bar text for the selection ("3 van 7 gekies · 4,31 GB"), null when nothing is selected.
  final void Function(String?)? onSelection;

  /// The shell's one [AppSettings]; a second instance would overwrite the other screens' saves.
  final AppSettings? settings;

  @override
  State<SermonsScreen> createState() => _SermonsScreenState();
}

class _SermonsScreenState extends State<SermonsScreen> {
  static const _thumbH = 126.0;

  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  late final _settings = widget.settings ?? AppSettings.load(widget.store.root);
  final _filter = <SermonState>{};
  bool _notUploaded = false;
  final _selected = <String>{};
  List<Sermon> _rows = []; // the filtered, sorted list on screen: select-all and ranges work on it
  String? _anchor; // last clicked row, the start of a Shift range
  String? _reported;
  bool _loading = false;
  bool _importing = false;
  bool _dragging = false;
  String? _error;
  int _fresh = 0;

  // Table sort: null column = channel order (newest first); a click on a header sorts, again reverses.
  String? _sortCol;
  bool _asc = true;

  // Size of each sermon's work folder; read at load and after the queue runs empty, kept only here.
  Map<String, int> _sizes = {};
  late final VoidCallback _idle;

  @override
  void initState() {
    super.initState();
    _refresh(); // once per start, and again on "Probeer weer"
    _idle = widget.jobs.onIdle(_loadSizes);
  }

  Future<void> _loadSizes() async {
    final ids = [for (final s in widget.store.sorted) s.id];
    final sizes =
        await (widget.sizes?.call(ids) ?? sermonSizes(widget.store.root, ids));
    if (mounted) setState(() => _sizes = sizes);
  }

  @override
  void dispose() {
    widget.jobs.removeListener(_idle);
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final first = widget.store.sorted.isEmpty;
    try {
      final fresh = widget.store.merge(
        await (widget.list?.call() ?? listChannel(_settings.channelUrl)),
      );
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fresh = first ? 0 : fresh.length;
      });
      _loadSizes();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyError(e);
      });
    }
  }

  void _processNext() {
    final all = widget.store.sorted;
    final todo = _selected.isNotEmpty
        ? all.where((s) => _selected.contains(s.id))
        : all
              .where((s) => s.state == SermonState.nuut)
              .toList()
              .reversed
              .take(1);
    for (final s in todo) {
      widget.jobs.enqueue(s.id, JobKind.plan);
    }
    setState(_selected.clear);
  }

  // stap: v1 1 Verwerk nuutste diens | Preke: een knoppie verfris die lys, beplan die boonste diens en maak Hersien oop
  // tak: nog besig met beplan → Hersien wys die laaistap; geen internet → strook met die rede
  /// The usual Monday: refresh the list, plan the newest service if it is new, open it in Hersien.
  Future<void> _processLatest() async {
    await _refresh();
    final all = widget.store.sorted.where((s) => !isRecording(s.id));
    if (all.isEmpty) return;
    final s = all.first;
    if (s.state == SermonState.nuut && !widget.jobs.hasPending(s.id)) {
      widget.jobs.enqueue(s.id, JobKind.plan);
    }
    widget.onOpen(s.id);
  }

  // stap: v3 1 Voer opname in | lêerkieser of insleep → dialoog met titel (lêernaam) en datum
  // tak: kanselleer → niks verander nie; kopie misluk (skyf vol) → strook met friendlyError
  /// "Voer opname in": file (picked or dropped) → title and date → copy into the work folder → Hersien.
  Future<void> _import([String? path]) async {
    final l = L.of(context);
    path ??= await widget.pickVideo();
    if (path == null || !mounted) return;
    final title = TextEditingController(text: p.basenameWithoutExtension(path));
    var date = DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(l.importRecording),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  key: const ValueKey('ctl.preke.import-title'),
                  controller: title,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l.title,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  key: const ValueKey('ctl.preke.import-date'),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(l.serviceDate(_ymd(date))),
                  onPressed: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (d != null) set(() => date = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('ctl.preke.import-cancel'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel),
            ),
            FilledButton(
              key: const ValueKey('ctl.preke.import-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.importConfirm),
            ),
          ],
        ),
      ),
    );
    // Not disposed: the dialog's closing animation still reads it; GC takes it.
    final name = title.text.trim();
    if (ok != true || !mounted) return;
    setState(() => _importing = true);
    try {
      final f = File(path);
      final s = await (widget.importFile != null
          ? widget.importFile!(f, name.isEmpty ? p.basename(path) : name, date)
          : importRecording(
              f,
              name.isEmpty ? p.basename(path) : name,
              date,
              widget.store,
            ));
      if (mounted) widget.onOpen(s.id);
    } on Object catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  static String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (d) {
        setState(() => _dragging = false);
        if (d.files.isNotEmpty) _import(d.files.first.path);
      },
      child: Stack(
        children: [
          _page(l, th),
          if (_dragging)
            Positioned.fill(
              child: ColoredBox(
                color: th.colorScheme.surface.withValues(alpha: 0.92),
                child: Center(
                  child: Text(
                    l.dropToImport,
                    style: th.textTheme.headlineSmall,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _page(L l, ThemeData th) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _processNext,
        const SingleActivator(LogicalKeyboardKey.keyA, control: true): () {
          if (_allState != true) _toggleAll();
        },
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: Listenable.merge([widget.store, widget.jobs]),
            builder: (context, _) {
              final l = L.of(context);
              final all = widget.store.sorted;
              final q = _search.text.trim().toLowerCase();
              final rows = [
                for (final s in all)
                  if ((_filter.isEmpty || _filter.contains(s.state)) &&
                      (!_notUploaded ||
                          (s.state != SermonState.opgelaai &&
                              s.state != SermonState.oorgeslaan)) &&
                      (q.isEmpty ||
                          '${s.title} ${s.scripture ?? ''} ${s.date ?? ''}'
                              .toLowerCase()
                              .contains(q)))
                    s,
              ];
              _sortRows(rows);
              _rows = rows;
              _report(l);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(l, th),
                  const SizedBox(height: 16),
                  _filters(l),
                  if (_fresh > 0)
                    _strip(l, th, l.newServices(_fresh), () {
                      setState(() => _fresh = 0);
                    }),
                  if (_error != null && all.isNotEmpty)
                    _strip(l, th, l.listError(_error!), null),
                  const SizedBox(height: 8),
                  Expanded(child: _body(l, th, all.isEmpty, rows)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// Tells the shell's status bar how many of the visible rows are selected and their size.
  void _report(L l) {
    final sel = _rows.where((s) => _selected.contains(s.id)).toList();
    final text = sel.isEmpty
        ? null
        : l.statusSelected(
            sel.length,
            _rows.length,
            formatBytes(sel.fold(0, (a, s) => a + (_sizes[s.id] ?? 0))),
          );
    if (text == _reported) return;
    _reported = text;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onSelection?.call(text);
    });
  }

  /// Tri-state over the visible rows: all, some (null) or none.
  bool? get _allState {
    final n = _rows.where((s) => _selected.contains(s.id)).length;
    return n == 0 ? false : (n == _rows.length ? true : null);
  }

  /// Selects every visible row, or clears them when all are selected.
  void _toggleAll() => setState(() {
    final ids = _rows.map((s) => s.id);
    _allState == true ? _selected.removeAll(ids) : _selected.addAll(ids);
  });

  Widget _selectAll() => Checkbox(
    key: const ValueKey('ctl.preke.select-all'),
    tristate: true,
    value: _allState,
    onChanged: (_) => _toggleAll(),
  );

  /// Row click: Ctrl toggles it, Shift selects from the last click to here, plain opens it in Hersien.
  void _tap(Sermon s) {
    final k = HardwareKeyboard.instance;
    if (k.isShiftPressed && _anchor != null) {
      final a = _rows.indexWhere((r) => r.id == _anchor);
      final b = _rows.indexWhere((r) => r.id == s.id);
      if (a >= 0 && b >= 0) {
        setState(() {
          for (var i = a < b ? a : b; i <= (a < b ? b : a); i++) {
            _selected.add(_rows[i].id);
          }
        });
        return;
      }
    }
    if (k.isControlPressed) {
      setState(() {
        _selected.contains(s.id) ? _selected.remove(s.id) : _selected.add(s.id);
        _anchor = s.id;
      });
      return;
    }
    widget.onOpen(s.id);
  }

  void _sortRows(List<Sermon> rows) {
    final c = _sortCol;
    if (c == null) return;
    int cmp(Sermon a, Sermon b) => switch (c) {
      'title' => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      'date' => (a.date ?? '').compareTo(b.date ?? ''),
      'length' => a.duration.compareTo(b.duration),
      'state' => a.state.index.compareTo(b.state.index),
      _ => (_sizes[a.id] ?? 0).compareTo(_sizes[b.id] ?? 0),
    };
    rows.sort((a, b) => _asc ? cmp(a, b) : cmp(b, a));
  }

  /// One sortable column header: the word and, on the sorted column, an arrow (shape, not colour).
  Widget _sortHead(
    ThemeData th,
    String id,
    String label, {
    bool right = false,
  }) {
    final on = _sortCol == id;
    return InkWell(
      key: ValueKey('ctl.preke.sort-$id'),
      onTap: () => setState(() {
        if (_sortCol == id) {
          _asc = !_asc;
        } else {
          _sortCol = id;
          _asc = true;
        }
      }),
      child: SizedBox(
        height: 32,
        child: Row(
          mainAxisAlignment: right
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: th.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (on)
              Icon(
                _asc
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
              ),
          ],
        ),
      ),
    );
  }

  Widget _tableHead(L l, ThemeData th) => Container(
    height: 32,
    color: th.colorScheme.surfaceContainer,
    child: Row(
      children: [
        SizedBox(width: 40, child: _selectAll()),
        const SizedBox(width: 64 + 12),
        Expanded(child: _sortHead(th, 'title', l.title)),
        SizedBox(width: 104, child: _sortHead(th, 'date', l.colDate)),
        SizedBox(width: 72, child: _sortHead(th, 'length', l.colLength)),
        SizedBox(width: 140, child: _sortHead(th, 'state', l.colState)),
        SizedBox(
          width: 88,
          child: _sortHead(th, 'size', l.colSize, right: true),
        ),
        const SizedBox(width: 12),
      ],
    ),
  );

  Widget _header(L l, ThemeData th) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    runSpacing: 8,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.navPreke, style: th.textTheme.headlineMedium),
          const SizedBox(width: 16),
          ViewToggle(
            keyName: 'ctl.preke.view',
            settings: _settings,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton.icon(
            key: const ValueKey('ctl.preke.import'),
            onPressed: _importing ? null : _import,
            icon: _importing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.video_file_rounded),
            label: Text(_importing ? l.importing : l.importRecording),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            key: const ValueKey('ctl.preke.process-next'),
            onPressed: _processNext,
            child: Text(l.processNext),
          ),
          const SizedBox(width: 12),
          FilledButton(
            key: const ValueKey('ctl.preke.process-latest'),
            onPressed: _loading ? null : _processLatest,
            child: Text(l.processLatest),
          ),
        ],
      ),
    ],
  );

  // stap: v2 1 Filter nie opgelaai nie | die chip wys net preke wat nog nie op YouTube is nie, nuutste bo
  Widget _filters(L l) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 240,
        child: TextField(
          key: const ValueKey('ctl.preke.search'),
          controller: _search,
          focusNode: _searchFocus,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l.searchSermons,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ),
      const SizedBox(width: 8),
      FilterChip(
        key: const ValueKey('ctl.preke.filter-not-uploaded'),
        avatar: const Icon(Icons.cloud_off_rounded, size: 18),
        label: Text(l.filterNotUploaded),
        selected: _notUploaded,
        onSelected: (v) => setState(() => _notUploaded = v),
      ),
      for (final s in SermonState.values)
        FilterChip(
          key: ValueKey('ctl.preke.filter-${s.name}'),
          avatar: Icon(stateIcon(s), size: 18),
          label: Text(stateLabel(l, s)),
          selected: _filter.contains(s),
          onSelected: (v) => setState(() {
            v ? _filter.add(s) : _filter.remove(s);
          }),
        ),
    ],
  );

  Widget _strip(L l, ThemeData th, String text, VoidCallback? onClose) =>
      Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: th.colorScheme.secondary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text)),
            if (onClose != null)
              IconButton(
                key: const ValueKey('ctl.preke.dismiss'),
                tooltip: l.dismiss,
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
              ),
          ],
        ),
      );

  Widget _body(L l, ThemeData th, bool none, List<Sermon> rows) {
    if (none && _loading) return const _Skeleton();
    if (none) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Icon(Icons.error_rounded, color: th.colorScheme.error, size: 32),
              const SizedBox(height: 12),
              Text(l.listError(_error!), textAlign: TextAlign.center),
            ] else ...[
              sowerScene(),
              const SizedBox(height: 8),
              Text(l.noSermons, style: th.textTheme.titleMedium),
            ],
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(
                  key: const ValueKey('ctl.preke.retry'),
                  onPressed: _refresh,
                  child: Text(l.retry),
                ),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
                    key: const ValueKey('ctl.preke.update-ytdlp'),
                    onPressed: () => updateYtDlpSnack(context),
                    child: Text(l.updateYtDlp),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }
    if (rows.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(l.noMatches, style: th.textTheme.bodyMedium),
      );
    }
    if (_settings.sermonGrid) {
      return Column(
        children: [
          Row(
            children: [
              _selectAll(),
              Text(l.selectAll, style: th.textTheme.labelMedium),
            ],
          ),
          Expanded(child: _grid(l, th, rows)),
        ],
      );
    }
    return _table(l, th, rows);
  }

  Widget _grid(L l, ThemeData th, List<Sermon> rows) => GridView.builder(
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 300,
      // Thumbnail + text block; the text block grows with the text scale so the card never overflows.
      mainAxisExtent: _thumbH + MediaQuery.textScalerOf(context).scale(112),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: rows.length,
    itemBuilder: (context, i) => _card(l, th, rows[i]),
  );

  Widget _table(L l, ThemeData th, List<Sermon> rows) => Column(
    children: [
      _tableHead(l, th),
      Expanded(
        child: ListView.builder(
          itemCount: rows.length,
          itemExtent: 48,
          itemBuilder: (context, i) => _row(l, th, rows[i]),
        ),
      ),
    ],
  );

  Widget _status(L l, ThemeData th, Sermon s) {
    final cur = widget.jobs.current;
    if (cur != null && cur.sermon == s.id && cur.status == JobStatus.besig) {
      return MiniProgress(
        key: const ValueKey('preke.mini-progress'),
        jobs: widget.jobs,
      );
    }
    final queued = widget.jobs.hasPending(s.id);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          queued ? Icons.hourglass_top_rounded : stateIcon(s.state),
          size: 18,
          color: s.state == SermonState.fout ? th.colorScheme.error : null,
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(queued ? l.inQueue : stateLabel(l, s.state))),
      ],
    );
  }

  Widget _select(Sermon s) => Checkbox(
    key: const ValueKey('ctl.preke.select'),
    value: _selected.contains(s.id),
    onChanged: (v) => setState(() {
      v == true ? _selected.add(s.id) : _selected.remove(s.id);
      _anchor = s.id;
    }),
  );

  /// Grid card: thumbnail, date, title, state.
  Widget _card(L l, ThemeData th, Sermon s) => Card(
    clipBehavior: Clip.antiAlias,
    margin: EdgeInsets.zero,
    child: InkWell(
      key: const ValueKey('ctl.preke.row'),
      onTap: () => _tap(s),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              SermonThumb(sermon: s, width: 300, height: _thumbH),
              Positioned(top: 0, left: 0, child: _select(s)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(s.date ?? l.noDate, style: th.textTheme.labelMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              s.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: th.textTheme.titleMedium,
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Row(
              children: [
                Expanded(child: _status(l, th, s)),
                if (_sizes[s.id] != null)
                  Text(
                    formatBytes(_sizes[s.id]!),
                    style: th.textTheme.labelMedium,
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  // stap: v2 2 Kies die ou preek | klik die ry → Hersien; nog nie beplan nie → Hersien beplan dit eers (laaistap)
  Widget _row(L l, ThemeData th, Sermon s) => InkWell(
    key: const ValueKey('ctl.preke.row'),
    onTap: () => _tap(s),
    child: Row(
      children: [
        _select(s),
        SermonThumb(sermon: s, width: 64, height: 36),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: th.textTheme.titleMedium,
              ),
              if (s.scripture != null)
                Text(
                  s.scripture!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: th.textTheme.bodySmall,
                ),
            ],
          ),
        ),
        SizedBox(
          width: 104,
          child: Text(s.date ?? l.noDate, style: th.textTheme.labelMedium),
        ),
        SizedBox(
          width: 72,
          child: Text(
            formatTime(s.duration, hours: true),
            style: th.textTheme.labelMedium,
          ),
        ),
        SizedBox(width: 140, child: _status(l, th, s)),
        SizedBox(
          width: 88,
          child: Text(
            _sizes[s.id] == null ? '' : formatBytes(_sizes[s.id]!),
            textAlign: TextAlign.end,
            style: th.textTheme.labelMedium,
          ),
        ),
        const SizedBox(width: 12),
      ],
    ),
  );
}

/// The YouTube thumbnail of a sermon; no network, a local recording or a failed load shows
/// the state icon on a panel tone instead (Image.network's own cache, no extra layer).
class SermonThumb extends StatelessWidget {
  const SermonThumb({
    super.key,
    required this.sermon,
    required this.width,
    required this.height,
  });
  final Sermon sermon;
  final double width, height;

  @override
  Widget build(BuildContext context) {
    final th = Theme.of(context);
    final fallback = ColoredBox(
      key: const ValueKey('preke.thumb-fallback'),
      color: th.colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(
          stateIcon(sermon.state),
          color: th.colorScheme.onSurfaceVariant,
        ),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: width,
        height: height,
        child: isRecording(sermon.id)
            ? fallback
            : Image.network(
                'https://i.ytimg.com/vi/${sermon.id}/mqdefault.jpg',
                fit: BoxFit.cover,
                semanticLabel: sermon.title,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, p) => p == null ? child : fallback,
              ),
      ),
    );
  }
}

/// Loading placeholder rows (no shimmer: nothing animates).
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemExtent: 64,
      itemCount: 8,
      itemBuilder: (_, _) => Center(
        child: Container(
          height: 16,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

/// List/grid switch shared by Preke and Werk; stores the choice in [AppSettings.sermonGrid].
class ViewToggle extends StatelessWidget {
  const ViewToggle({
    super.key,
    required this.keyName,
    required this.settings,
    required this.onChanged,
  });

  final String keyName;
  final AppSettings settings;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return SegmentedButton<bool>(
      key: ValueKey(keyName),
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          icon: const Icon(Icons.view_list_rounded),
          label: Text(l.viewList),
        ),
        ButtonSegment(
          value: true,
          icon: const Icon(Icons.grid_view_rounded),
          label: Text(l.viewGrid),
        ),
      ],
      selected: {settings.sermonGrid},
      onSelectionChanged: (v) {
        settings
          ..sermonGrid = v.single
          ..save();
        onChanged();
      },
    );
  }
}

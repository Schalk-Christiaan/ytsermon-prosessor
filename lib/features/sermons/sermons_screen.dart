// @stelsel sermons_screen
//   soort: skerm
//   wanneer: Preke (rail, tuis)
//   groep: features | Skerms
//   skryf: —
//   doel: die hele kanaal as lys met toestand; filter, soek, "Verwerk volgende" → werkry
//   status: oop
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/channel.dart';
import '../../core/jobs.dart';
import '../../core/store.dart';
import '../../l10n/app_localizations.dart';
import '../settings/system_status.dart';

String stateLabel(L l, SermonState s) => switch (s) {
  SermonState.nuut => l.stateNuut,
  SermonState.beplan => l.stateBeplan,
  SermonState.goedgekeur => l.stateGoedgekeur,
  SermonState.gesny => l.stateGesny,
  SermonState.opgelaai => l.stateOpgelaai,
  SermonState.fout => l.stateFout,
  SermonState.oorgeslaan => l.stateOorgeslaan,
};

IconData stateIcon(SermonState s) => switch (s) {
  SermonState.nuut => Icons.fiber_new_rounded,
  SermonState.beplan => Icons.fact_check_rounded,
  SermonState.goedgekeur => Icons.thumb_up_alt_rounded,
  SermonState.gesny => Icons.content_cut_rounded,
  SermonState.opgelaai => Icons.cloud_done_rounded,
  SermonState.fout => Icons.error_rounded,
  SermonState.oorgeslaan => Icons.skip_next_rounded,
};

class SermonsScreen extends StatefulWidget {
  const SermonsScreen({
    super.key,
    required this.store,
    required this.jobs,
    required this.onOpen,
    this.list = listChannel,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Row tap: open this sermon in Hersien.
  final void Function(String id) onOpen;

  /// Test seam: the channel lister.
  final Future<List<ChannelItem>> Function() list;

  @override
  State<SermonsScreen> createState() => _SermonsScreenState();
}

class _SermonsScreenState extends State<SermonsScreen> {
  final _search = TextEditingController();
  final _searchFocus = FocusNode();
  final _filter = <SermonState>{};
  final _selected = <String>{};
  bool _loading = false;
  String? _error;
  int _fresh = 0;

  @override
  void initState() {
    super.initState();
    _refresh(); // once per start, and again on "Probeer weer"
  }

  @override
  void dispose() {
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
      final fresh = widget.store.merge(await widget.list());
      if (!mounted) return;
      setState(() {
        _loading = false;
        _fresh = first ? 0 : fresh.length;
      });
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

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _searchFocus.requestFocus(),
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _processNext,
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListenableBuilder(
            listenable: Listenable.merge([widget.store, widget.jobs]),
            builder: (context, _) {
              final all = widget.store.sorted;
              final q = _search.text.trim().toLowerCase();
              final rows = [
                for (final s in all)
                  if ((_filter.isEmpty || _filter.contains(s.state)) &&
                      (q.isEmpty ||
                          '${s.title} ${s.scripture ?? ''} ${s.date ?? ''}'
                              .toLowerCase()
                              .contains(q)))
                    s,
              ];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(l, th),
                  const SizedBox(height: 12),
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

  Widget _header(L l, ThemeData th) => Row(
    children: [
      Text(l.navPreke, style: th.textTheme.headlineMedium),
      const SizedBox(width: 24),
      Expanded(
        child: TextField(
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
      const SizedBox(width: 12),
      FilledButton(onPressed: _processNext, child: Text(l.processNext)),
    ],
  );

  Widget _filters(L l) => Wrap(
    spacing: 8,
    children: [
      for (final s in SermonState.values)
        FilterChip(
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
            ] else
              Text(l.noSermons, style: th.textTheme.titleMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: _refresh, child: Text(l.retry)),
                if (_error != null) ...[
                  const SizedBox(width: 12),
                  OutlinedButton(
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
    return ListView.builder(
      itemCount: rows.length,
      itemExtent: 56,
      itemBuilder: (context, i) => _row(l, th, rows[i]),
    );
  }

  Widget _row(L l, ThemeData th, Sermon s) {
    final queued = widget.jobs.hasPending(s.id);
    return InkWell(
      onTap: () => widget.onOpen(s.id),
      child: Row(
        children: [
          Checkbox(
            value: _selected.contains(s.id),
            onChanged: (v) => setState(() {
              v == true ? _selected.add(s.id) : _selected.remove(s.id);
            }),
          ),
          SizedBox(
            width: 104,
            child: Text(s.date ?? l.noDate, style: th.textTheme.labelMedium),
          ),
          Expanded(
            child: Text(
              s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: th.textTheme.headlineSmall?.copyWith(fontSize: 18),
            ),
          ),
          SizedBox(
            width: 180,
            child: Text(
              s.scripture ?? '',
              overflow: TextOverflow.ellipsis,
              style: th.textTheme.bodyMedium,
            ),
          ),
          SizedBox(
            width: 140,
            child: Row(
              children: [
                Icon(
                  queued ? Icons.hourglass_top_rounded : stateIcon(s.state),
                  size: 18,
                  color: s.state == SermonState.fout
                      ? th.colorScheme.error
                      : null,
                ),
                const SizedBox(width: 6),
                Text(queued ? l.inQueue : stateLabel(l, s.state)),
              ],
            ),
          ),
        ],
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
      itemExtent: 56,
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

// @stelsel playlists_screen
//   soort: skerm
//   wanneer: Snitlyste (rail)
//   groep: features | Skerms
//   skryf: <werkmap>/settings.json | reëls, groepe en jabloon
//   doel: snitlysreëls aan/af en in volgorde, eie snitlysgroepe (skep, wysig, preke by, uitvee), voorskou hoeveel preke in elke snitlys val, beskrywingsjabloon, WhatsApp-sjabloon met voorskou
//   status: bou
import 'package:flutter/material.dart';

import '../../core/cutter.dart';
import '../../core/playlists.dart';
import '../../core/service_info.dart';
import '../../core/settings.dart';
import '../../core/store.dart';
import '../../l10n/app_localizations.dart';

/// Lists the channel's playlists and which series each sermon goes into.
class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({
    super.key,
    required this.store,
    required this.settings,
  });
  final SermonStore store;
  final AppSettings settings;

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  static const _all = ['book', 'year'];
  late final _order = [
    ...widget.settings.rules,
    ..._all.where((r) => !widget.settings.rules.contains(r)),
  ];
  late final _template = TextEditingController(text: widget.settings.template);
  late final _whatsapp = TextEditingController(
    text: widget.settings.whatsappTemplate,
  );

  @override
  void dispose() {
    _template.dispose();
    _whatsapp.dispose();
    super.dispose();
  }

  void _save() {
    widget.settings
      ..rules = [
        for (final r in _order)
          if (widget.settings.rules.contains(r)) r,
      ]
      ..save();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final rules = widget.settings.rules;
    return ListenableBuilder(
      listenable: widget.store,
      builder: (context, _) {
        final counts = <String?, int>{};
        for (final s in widget.store.sorted) {
          final n = playlistFor(s, rules);
          counts[n] = (counts[n] ?? 0) + 1;
        }
        final named = counts.entries.where((e) => e.key != null).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final none = counts[null] ?? 0;
        return Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(l.navSnitlyste, style: th.textTheme.headlineMedium),
                _heading(th, l.playlistRules),
                Text(l.playlistRulesHelp, style: th.textTheme.bodyMedium),
                const SizedBox(height: 8),
                ReorderableListView(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  onReorderItem: (a, b) {
                    _order.insert(b, _order.removeAt(a));
                    _save();
                  },
                  children: [
                    for (final (i, r) in _order.indexed)
                      SwitchListTile(
                        key: ValueKey('ctl.snitlyste.rule-$r'),
                        contentPadding: EdgeInsets.zero,
                        value: rules.contains(r),
                        title: Text(r == 'book' ? l.ruleBook : l.ruleYear),
                        secondary: ReorderableDragStartListener(
                          index: i,
                          child: const Icon(Icons.drag_indicator_rounded),
                        ),
                        onChanged: (on) {
                          widget.settings.rules = on
                              ? [
                                  for (final x in _order)
                                    if (x == r || rules.contains(x)) x,
                                ]
                              : [...rules.where((x) => x != r)];
                          _save();
                        },
                      ),
                  ],
                ),
                _heading(th, l.groupsHeading),
                Text(l.groupsHelp, style: th.textTheme.bodyMedium),
                const SizedBox(height: 8),
                if (widget.settings.groups.isEmpty)
                  Text(l.groupsEmpty, style: th.textTheme.bodyLarge),
                for (final (i, g) in widget.settings.groups.indexed)
                  _group(th, l, i, g),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('ctl.snitlyste.group-add'),
                    onPressed: () => _edit(null),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(l.groupAdd),
                  ),
                ),
                _heading(th, l.playlistPreview),
                for (final e in named) _count(th, l, e.key!, e.value),
                if (none > 0) _count(th, l, l.noPlaylist, none, quiet: true),
                _heading(th, l.template),
                TextField(
                  key: const ValueKey('ctl.snitlyste.template'),
                  controller: _template,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    helperText: l.templateHelp(
                      '{tema}',
                      '{skriflesing}',
                      '{datum}',
                      '{beskrywing}',
                    ),
                  ),
                  onChanged: (v) => setState(
                    () => widget.settings
                      ..template = v
                      ..save(),
                  ),
                ),
                if (widget.store.sorted.firstOrNull case final s?) ...[
                  const SizedBox(height: 16),
                  Text(l.templatePreview, style: th.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    describe(
                      widget.settings.template,
                      tema: s.title,
                      scripture: s.scripture,
                      date: s.date,
                      description: '',
                    ).trim(),
                    style: th.textTheme.bodyMedium,
                  ),
                ],
                // stap: diensindeling 8 WhatsApp-sjabloon | die teks met plekhouers en 'n voorskou met die nuutste preek
                _heading(th, l.whatsappTemplate),
                TextField(
                  key: const ValueKey('ctl.snitlyste.whatsapp'),
                  controller: _whatsapp,
                  minLines: 4,
                  maxLines: 8,
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    helperText: l.whatsappTemplateHelp(
                      '{diens}',
                      '{datum}',
                      '{tema}',
                      '{skriflesing}',
                      '{fokus}',
                      '{belydenis}',
                    ),
                  ),
                  onChanged: (v) => setState(
                    () => widget.settings
                      ..whatsappTemplate = v
                      ..save(),
                  ),
                ),
                if (widget.store.sorted.firstOrNull case final s?) ...[
                  const SizedBox(height: 16),
                  Text(l.templatePreview, style: th.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    whatsappText(
                      widget.settings.whatsappTemplate,
                      ServiceInfo(
                        date: s.date ?? '2000-01-01',
                        theme: s.title,
                        scripture: s.scripture,
                      ),
                    ),
                    key: const ValueKey('whatsappPreview'),
                    style: th.textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _saveGroups() {
    widget.settings.save();
    setState(() {});
  }

  /// A group row: name, count, and its actions.
  Widget _group(ThemeData th, L l, int i, PlaylistGroup g) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(g.name, style: th.textTheme.titleMedium),
              if (g.description.isNotEmpty)
                Text(g.description, style: th.textTheme.bodyMedium),
            ],
          ),
        ),
        Text(
          l.sermonCount(g.sermons.length),
          style: th.textTheme.bodyMedium?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(
          key: ValueKey('ctl.snitlyste.group-sermons.$i'),
          onPressed: () => _pickSermons(g),
          child: Text(l.groupSermons),
        ),
        IconButton(
          key: ValueKey('ctl.snitlyste.group-edit.$i'),
          tooltip: l.groupRename,
          onPressed: () => _edit(g),
          icon: const Icon(Icons.edit_outlined),
        ),
        IconButton(
          key: ValueKey('ctl.snitlyste.group-delete.$i'),
          tooltip: l.groupDelete,
          onPressed: () => _delete(g),
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    ),
  );

  /// Name and description of a new ([g] null) or existing group.
  Future<void> _edit(PlaylistGroup? g) async {
    final l = L.of(context);
    final name = TextEditingController(text: g?.name);
    final description = TextEditingController(text: g?.description);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.groupEditTitle),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const ValueKey('ctl.snitlyste.group-name'),
                controller: name,
                autofocus: true,
                decoration: InputDecoration(labelText: l.groupNameLabel),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('ctl.snitlyste.group-description'),
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(labelText: l.groupDescriptionLabel),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            key: const ValueKey('ctl.snitlyste.group-save'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.groupSave),
          ),
        ],
      ),
    );
    final n = name.text.trim();
    final d = description.text.trim();
    // not disposed: the dialog is still animating out; an unlistened controller is just garbage
    if (ok != true || n.isEmpty) return;
    if (g == null) {
      widget.settings.groups.add(
        PlaylistGroup(
          DateTime.now().microsecondsSinceEpoch.toString(),
          n,
          description: d,
        ),
      );
    } else {
      g
        ..name = n
        ..description = d;
    }
    _saveGroups();
  }

  /// Ticks the sermons that belong to [g].
  Future<void> _pickSermons(PlaylistGroup g) async {
    final l = L.of(context);
    final sermons = widget.store.sorted;
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, set) => AlertDialog(
          title: Text(l.groupSermonsTitle(g.name)),
          content: SizedBox(
            width: 520,
            height: 420,
            child: ListView(
              children: [
                for (final (i, s) in sermons.indexed)
                  CheckboxListTile(
                    key: ValueKey('ctl.snitlyste.group-sermon.$i'),
                    dense: true,
                    value: g.sermons.contains(s.id),
                    title: Text(s.title, overflow: TextOverflow.ellipsis),
                    onChanged: (on) {
                      set(() {
                        on == true
                            ? g.sermons.add(s.id)
                            : g.sermons.remove(s.id);
                      });
                      _saveGroups();
                    },
                  ),
              ],
            ),
          ),
          actions: [
            FilledButton(
              key: const ValueKey('ctl.snitlyste.group-done'),
              onPressed: () => Navigator.pop(context),
              child: Text(l.groupDone),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(PlaylistGroup g) async {
    final l = L.of(context);
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.groupDeleteAsk(g.name)),
        actions: [
          TextButton(
            key: const ValueKey('ctl.snitlyste.group-delete-no'),
            onPressed: () => Navigator.pop(context, false),
            child: Text(l.groupKeep),
          ),
          FilledButton(
            key: const ValueKey('ctl.snitlyste.group-delete-yes'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.groupDelete),
          ),
        ],
      ),
    );
    if (yes != true) return;
    widget.settings.groups.remove(g);
    _saveGroups();
  }

  Widget _heading(ThemeData th, String text) => Padding(
    padding: const EdgeInsets.only(top: 32, bottom: 8),
    child: Text(text, style: th.textTheme.headlineSmall),
  );

  Widget _count(ThemeData th, L l, String name, int n, {bool quiet = false}) =>
      SizedBox(
        height: 44,
        child: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: quiet
                    ? th.textTheme.bodyLarge
                    : th.textTheme.titleMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              l.sermonCount(n),
              style: th.textTheme.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      );
}

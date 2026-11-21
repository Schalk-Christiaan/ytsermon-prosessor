// @stelsel library_screen
//   soort: skerm
//   wanneer: Biblioteek (rail)
//   groep: features | Skerms
//   skryf: —
//   doel: die dienste in die uitvoergids as Preke (per jaar, nuutste eerste) en Sang (alle liedere); soek op tema, skriflesing en liedname; Speel, Wys in gids, Kopieer WhatsApp-teks; laai by oopmaak en met Herlaai
//   status: bou
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/cutter.dart' show longDate;
import '../../core/library.dart';
import '../../core/settings.dart';
import '../../core/tools.dart';
import '../../l10n/app_localizations.dart';

/// Biblioteek: what was cut, as sermons and as songs, with a search over theme, scripture and song name.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({
    super.key,
    required this.settings,
    this.open = openPath,
    this.load = loadLibrary,
  });
  final AppSettings settings;

  /// Test seam: opens a file (default: the system player / file manager).
  final Future<void> Function(String path, {bool select}) open;

  /// Test seam: reads the output folder.
  final List<LibraryService> Function(String outDir) load;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _search = TextEditingController();
  late List<LibraryService> _all = widget.load(widget.settings.outDir);
  int _view = 0;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  String _day(L l, LibraryService s) =>
      '${longDate(s.info.date)} · ${s.info.evening ? l.serviceEvening : l.serviceMorning}';

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final q = _search.text.trim().toLowerCase();
    final shown = [
      for (final s in _all)
        if (s.matches(q)) s,
    ];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(l.libraryPreke)),
                  ButtonSegment(value: 1, label: Text(l.librarySang)),
                ],
                selected: {_view},
                onSelectionChanged: (v) => setState(() => _view = v.single),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 320,
                child: TextField(
                  key: const ValueKey('librarySearch'),
                  controller: _search,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l.searchLibrary,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () =>
                    setState(() => _all = widget.load(widget.settings.outDir)),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(l.reload),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _all.isEmpty
                ? Text(l.libraryEmpty(widget.settings.outDir))
                : shown.isEmpty
                ? Text(l.libraryNoMatch)
                : _view == 0
                ? _sermons(l, th, shown)
                : _songs(l, th, shown, q),
          ),
        ],
      ),
    );
  }

  // stap: diensindeling 13 Preke-aansig | per jaar, nuutste eerste; Speel, Wys in gids en Kopieer WhatsApp-teks per diens
  Widget _sermons(L l, ThemeData th, List<LibraryService> shown) {
    final rows = <Widget>[];
    String? year;
    for (final s in shown) {
      final y = s.info.date.substring(0, 4);
      if (y != year) {
        year = y;
        rows.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(y, style: th.textTheme.headlineSmall),
          ),
        );
      }
      rows.add(
        ListTile(
          key: ValueKey('service-${s.dir.path}'),
          title: Text(s.info.theme ?? s.title ?? s.dir.path),
          subtitle: Text(
            [
              _day(l, s),
              if (s.info.label != null) s.info.label!,
              if (s.info.scripture != null) s.info.scripture!,
            ].join(' · '),
          ),
          trailing: Wrap(
            spacing: 4,
            children: [
              if (s.video != null)
                TextButton(
                  onPressed: () => widget.open(s.video!),
                  child: Text(l.play),
                ),
              TextButton(
                onPressed: () => widget.open(s.dir.path, select: true),
                child: Text(l.showInFolder),
              ),
              Builder(
                builder: (ctx) => TextButton(
                  onPressed: () => _copy(ctx, l, s),
                  child: Text(l.copyWhatsappText),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView(children: rows);
  }

  // stap: diensindeling 14 Sang-aansig | alle liedere met naam, diens en datum; 'n soektog wys net die liedere wat pas
  Widget _songs(L l, ThemeData th, List<LibraryService> shown, String q) {
    final rows = <Widget>[];
    for (final s in shown) {
      for (final song in s.songs) {
        final name = song.name ?? l.songUnnamed(song.n);
        // A search that hit the service by its theme still lists only the songs that match.
        if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;
        rows.add(
          ListTile(
            key: ValueKey('song-${s.dir.path}-${song.n}'),
            title: Text(name),
            subtitle: Text(_day(l, s)),
            trailing: song.file == null
                ? null
                : Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => widget.open(song.file!),
                        child: Text(l.play),
                      ),
                      TextButton(
                        onPressed: () => widget.open(song.file!, select: true),
                        child: Text(l.showInFolder),
                      ),
                    ],
                  ),
          ),
        );
      }
    }
    return rows.isEmpty ? Text(l.libraryNoMatch) : ListView(children: rows);
  }

  Future<void> _copy(BuildContext context, L l, LibraryService s) async {
    final m = ScaffoldMessenger.of(context);
    await Clipboard.setData(
      ClipboardData(text: libraryWhatsapp(s, widget.settings.whatsappTemplate)),
    );
    m.showSnackBar(SnackBar(content: Text(l.whatsappTextCopied)));
  }
}

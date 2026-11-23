// @stelsel shell
//   soort: skerm
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: Sybalk (200 px, ikoon + woord, oranje streep) en inhoud as twee panele op die grond, statusbalk onder (keuse links, skyfspasie regs); sybalk: Preke (tuis), Hersien, Werk, Snitlyste, Biblioteek, Instellings (Kanaal + Stelsel); begin op Opstelling tot dit klaar is
//   status: bou

// vloei: v1 | Verwerk nuutste diens
// inleiding: Maandag: die diens van gister word een knoppie later 'n gesnyde preek met Shorts op YouTube.
// hoekom: die gewone week; Oom Johan moet dit sonder hulp kan doen, met net een gevulde knoppie op elke skerm.
// vloei: diensindeling | Die hele diens verstaan
// inleiding: Die app hoor waar musiek en spraak is, benoem elke spraakstuk, en maak uit een diens drie uitvoere (volle preek, net die woord, sang) in een gids met 'n WhatsApp-teks.
// hoekom: Schalk wil die woord en die sang apart hê, en die diensorde verskil van week tot week; musiek uit die klank is betroubaarder as YouTube se merkers.
// vloei: v2 | 'n Ou preek verwerk
// inleiding: 'n Diens van weke gelede wat nog nie opgelaai is nie, gevind met die filter "Nie opgelaai nie".
// hoekom: die agterstand van die kanaal word so een vir een ingehaal.
// vloei: v3 | Voer opname in
// inleiding: 'n Video wat nie op YouTube is nie (USB, kamera) word gekopieer, met die hand begrens en gesny.
// hoekom: soms faal die regstreekse uitsending; dan is die eie opname die enigste bron.
// vloei: v4 | Die grense is onseker of verkeerd
// inleiding: Die kode het die gebede nie seker gevind nie (Hersien wys die rede), of die hakie staan nie by die gebed nie; die mens skuif dit met die transkripsie en die sleutelbord reg.
// hoekom: die grense kom uit reëls, nie 'n KI nie, maar is net so min onfeilbaar; die predikant wil nie 'n preek wat halfpad begin nie.
// vloei: v5 | Hervat ná 'n onderbreking
// inleiding: Die app of die krag gaan af in die middel van 'n aflaai of snit; by die volgende begin loop die werk voort.
// hoekom: 'n uur se aflaai mag nie verlore gaan nie, en niemand moet onthou wat besig was nie.
// vloei: v6 | Eerste keer op die kerk-PC
// inleiding: Ná Setup.exe bring die Opstelling-lys alles tot groen sonder 'n terminaal.
// hoekom: die kerk-PC het geen ontwikkelaar langsaan nie.
// vloei: v7 | Vinnige WhatsApp-klank
// inleiding: Die gesnyde preek word 'n mp3 wat die WhatsApp-admin in die groep sleep.
// hoekom: baie lidmate luister net op hul foon; die admin wil nie die app leer nie.
// vloei: v8 | Fout ná oplaai
// inleiding: Die titel of Skriflesing is verkeerd op YouTube; Hersien stuur die regstelling sonder om weer op te laai.
// hoekom: weer oplaai kos kwota en breek die skakel wat reeds gedeel is.
// vloei: v9 | Geen internet of vol skyf
// inleiding: 'n Taak misluk; Werkry sê in gewone taal wat fout is en hoe om dit reg te stel.
// hoekom: "SocketException" sê niks vir Oom Johan nie; die regstelling moet in die boodskap staan.
// vloei: preekgrense | Preekgrense: van gebed tot gebed
// inleiding: Die snit begin by die eerste woord van die gebed voor die preek en eindig ná die "Amen" van die eerste gebed daarna; kode kies dit, nie Ollama nie.
// hoekom: Ollama het die grense soms verkeerd gekies (of 30 min gedink); reëls oor woordtye en stilte is herhaalbaar en binne 0,5 s.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'motion.dart';
import 'pixel_art.dart';
import '../core/channel.dart';
import '../core/jobs.dart';
import '../core/settings.dart';
import '../core/storage.dart';
import '../core/store.dart';
import '../core/tools.dart';
import '../core/youtube.dart';
import '../features/library/library_screen.dart';
import '../core/suggest.dart';
import '../features/playlists/playlists_screen.dart';
import '../features/review/review_controller.dart';
import '../features/review/review_screen.dart';
import '../features/sermons/sermons_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/system_status.dart';
import '../features/setup/setup_screen.dart';
import '../features/work/work_screen.dart';
import '../l10n/app_localizations.dart';
import 'theme.dart';

/// Rail indexes of the screens that report a selection to the status bar.
const _kPreke = 0, _kWerk = 2;

/// The app frame: navigation rail and the five screens; starts on Opstelling until setup is done.

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.store,
    required this.jobs,
    this.list,
    this.settings,
    this.auth,
    this.quota,
    this.storage,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// App wiring; tests leave these null and get files under the store's root (token in memory).
  final AppSettings? settings;
  final GoogleAuth? auth;
  final UploadQuota? quota;

  /// Disk figures for the status bar: (bytes used by the work folder, bytes free), read on request.
  /// App wiring passes [readStorage]; tests leave it null and the bar shows nothing.
  final Future<(int, int?)> Function()? storage;

  /// Test seam: the channel lister (default: the channel set in Instellings).
  final Future<List<ChannelItem>> Function()? list;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with SingleTickerProviderStateMixin {
  // 0 Preke, 1 Hersien, 2 Werk, 3 Snitlyste, 4 Instellings, 5 Opstelling (no rail item), 6 Biblioteek
  // stap: v6 1 Begin op Opstelling | tot setupDone waar is, wys die app net die Opstelling-lys
  late int _i = _settings.setupDone ? 0 : 5;
  // Fade-through of the content on a screen change: new screen fades in and slides up 8 px.
  late final _switch = AnimationController(vsync: this, value: 1);
  late final _fade = CurvedAnimation(parent: _switch, curve: kMotionCurve);

  /// Go to screen [i]; the content fades in (instantly under reduced motion).
  void _go(int i) {
    setState(() => _i = i);
    final d = motion(context);
    if (d == Duration.zero) {
      _switch.value = 1;
    } else {
      _switch.duration = d;
      _switch.forward(from: 0);
    }
  }

  late final _review = ReviewController(store: widget.store, jobs: widget.jobs)
    ..updateYouTube = (id) => updateOnYouTube(
      widget.store,
      id,
      yt: YouTube(_auth),
      settings: _settings,
    );
  late final _settings = widget.settings ?? AppSettings.load(widget.store.root);

  /// Playlist suggestions after every finished cut (asked once, never blocks the render).
  late final _suggestions = GroupSuggestions(_settings, widget.store)
    ..attach(widget.jobs);
  late final _quota =
      widget.quota ??
      UploadQuota(File(p.join(widget.store.root.path, 'quota.json')));
  String? _memToken;
  late final _auth =
      widget.auth ??
      GoogleAuth(
        File(_settings.clientFile),
        read: () async => _memToken,
        write: (v) async => _memToken = v,
      );

  /// Status-bar text for the selection of each screen; only the visible screen's shows.
  final selection = <int, ValueNotifier<String?>>{
    _kPreke: ValueNotifier<String?>(null),
    _kWerk: ValueNotifier<String?>(null),
  };
  (int, int?)? _disk; // bytes used by the work folder, bytes free
  late final VoidCallback _idle;

  @override
  void initState() {
    super.initState();
    _readDisk();
    _idle = widget.jobs.onIdle(
      _readDisk,
    ); // refresh the disk figures when the queue runs empty (no polling)
  }

  Future<void> _readDisk() async {
    final r = await widget.storage?.call();
    if (r == null || !mounted) return;
    setState(() => _disk = r);
  }

  @override
  void dispose() {
    widget.jobs.removeListener(_idle);
    for (final n in selection.values) {
      n.dispose();
    }
    _fade.dispose();
    _switch.dispose();
    _review.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(kPanelGap),
              child: Row(
                children: [
                  _panel(
                    SizedBox(
                      key: const ValueKey('shell.sidebar'),
                      width: 200,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          _dest(Icons.church_rounded, l.navPreke, 0),
                          _dest(Icons.rate_review_rounded, l.navReview, 1),
                          _dest(Icons.work_history_rounded, l.navWerk, 2),
                          _dest(Icons.playlist_play_rounded, l.navSnitlyste, 3),
                          _dest(
                            Icons.video_library_rounded,
                            l.navBiblioteek,
                            6,
                          ),
                          const Spacer(),
                          _dest(Icons.settings_rounded, l.navSettings, 4),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: kPanelGap),
                  Expanded(
                    child: _panel(
                      // Titles, paths and errors can be selected and copied.
                      SelectionArea(
                        child: FadeTransition(
                          key: const ValueKey('shell.switch'),
                          opacity: _fade,
                          child: AnimatedBuilder(
                            animation: _switch,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(
                                0,
                                8 * (1 - kMotionCurve.transform(_switch.value)),
                              ),
                              child: child,
                            ),
                            child: IndexedStack(
                              index: _i,
                              children: [
                                SermonsScreen(
                                  key: ValueKey(_settings.channelUrl),
                                  store: widget.store,
                                  jobs: widget.jobs,
                                  list: widget.list,
                                  settings: _settings,
                                  onSelection: (v) =>
                                      selection[_kPreke]!.value = v,
                                  onOpen: (id) {
                                    _review.open(id);
                                    _go(1);
                                  },
                                ),
                                ReviewScreen(
                                  controller: _review,
                                  settings: _settings,
                                  onWork: () => _go(_kWerk),
                                ),
                                WorkScreen(
                                  store: widget.store,
                                  jobs: widget.jobs,
                                  onBack: () => _go(_kPreke),
                                  quota: _quota,
                                  onSelection: (v) =>
                                      selection[_kWerk]!.value = v,
                                  suggestions: _suggestions,
                                  settings: _settings,
                                ),
                                PlaylistsScreen(
                                  store: widget.store,
                                  settings: _settings,
                                  suggestions: _suggestions,
                                ),
                                SettingsScreen(
                                  settings: _settings,
                                  auth: _auth,
                                  signIn: () => _auth.signIn(openPath),
                                  system: SystemStatus(
                                    model: whisperModelFile(widget.store.root),
                                  ),
                                  onChannelChanged: () => setState(() {}),
                                  onSetup: () => _go(5),
                                ),
                                // Built only while shown, so it probes Ollama when opened, not at every start.
                                if (_i == 5)
                                  SetupScreen(
                                    settings: _settings,
                                    auth: _auth,
                                    signIn: () => _auth.signIn(openPath),
                                    onSettings: () => _go(4),
                                    onDone: () => _go(_kPreke),
                                  )
                                else
                                  const SizedBox(),
                                // Built only while shown, so the folder is read when opened.
                                if (_i == 6)
                                  LibraryScreen(settings: _settings)
                                else
                                  const SizedBox(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _statusBar(context),
        ],
      ),
    );
  }

  /// Bottom bar: selection on the left, disk figures on the right.
  Widget _statusBar(BuildContext context) {
    final th = Theme.of(context);
    return Container(
      key: const ValueKey('shell.status'),
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: th.colorScheme.surfaceContainer,
      child: Row(
        children: [
          ListenableBuilder(
            listenable: Listenable.merge(selection.values.toList()),
            builder: (_, _) => Text(
              selection[_i]?.value ?? '',
              style: th.textTheme.labelMedium,
            ),
          ),
          const Spacer(),
          // The walking sheep: a task runs (click: Werk); it lies down when nothing runs.
          ListenableBuilder(
            listenable: widget.jobs,
            builder: (_, _) => InkWell(
              key: const ValueKey('ctl.skulp.sheep'),
              onTap: () => _go(_kWerk),
              child: PixelSprite(
                sheep,
                scale: 2,
                animate: widget.jobs.current != null,
              ),
            ),
          ),
          const SizedBox(width: 16),
          if (_disk != null)
            CountText(
              value: _disk!.$1,
              style: th.textTheme.labelMedium,
              format: (used) => _disk!.$2 == null
                  ? L.of(context).statusDiskUsed(formatBytes(used))
                  : L
                        .of(context)
                        .statusDisk(formatBytes(used), formatBytes(_disk!.$2!)),
            ),
        ],
      ),
    );
  }

  Widget _panel(Widget child) =>
      appPanel(context, child, key: const ValueKey('shell.panel'));

  Widget _dest(IconData icon, String label, int i) {
    final cs = Theme.of(context).colorScheme;
    final sel = _i == i;
    return Semantics(
      selected: sel,
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        child: InkWell(
          key: ValueKey('ctl.skulp.nav-$i'),
          borderRadius: BorderRadius.circular(kPanelRadius),
          onTap: () => _go(i),
          child: Ink(
            height: 36,
            decoration: sel
                ? BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(kPanelRadius),
                  )
                : null,
            child: Row(
              children: [
                // The stripe is shape, not only colour, so the current screen reads without colour.
                if (sel)
                  Container(
                    key: const ValueKey('shell.nav-stripe'),
                    width: 3,
                    height: 20,
                    color: cs.primary,
                  )
                else
                  const SizedBox(width: 3),
                const SizedBox(width: 10),
                Icon(
                  icon,
                  size: 20,
                  color: sel ? cs.onSecondaryContainer : null,
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: sel ? FontWeight.w700 : null,
                    color: sel ? cs.onSecondaryContainer : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

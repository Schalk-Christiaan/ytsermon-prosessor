// @stelsel shell
//   soort: skerm
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: Rail en inhoud as twee panele (radius 16) op die grond; rail: Preke (tuis), Hersien, Werk, Snitlyste, Biblioteek, Instellings (Kanaal + Stelsel); begin op Opstelling tot dit klaar is
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

import '../core/channel.dart';
import '../core/jobs.dart';
import '../core/settings.dart';
import '../core/store.dart';
import '../core/tools.dart';
import '../core/youtube.dart';
import '../features/library/library_screen.dart';
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

/// The app frame: navigation rail and the five screens; starts on Opstelling until setup is done.
class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.store,
    required this.jobs,
    this.list = listChannel,
    this.settings,
    this.auth,
    this.quota,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// App wiring; tests leave these null and get files under the store's root (token in memory).
  final AppSettings? settings;
  final GoogleAuth? auth;
  final UploadQuota? quota;

  /// Test seam: the channel lister.
  final Future<List<ChannelItem>> Function() list;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  // 0 Preke, 1 Hersien, 2 Werk, 3 Snitlyste, 4 Instellings, 5 Opstelling (no rail item), 6 Biblioteek
  // stap: v6 1 Begin op Opstelling | tot setupDone waar is, wys die app net die Opstelling-lys
  late int _i = _settings.setupDone ? 0 : 5;
  late final _review = ReviewController(store: widget.store, jobs: widget.jobs)
    ..updateYouTube = (id) => updateOnYouTube(
      widget.store,
      id,
      yt: YouTube(_auth),
      settings: _settings,
    );
  late final _settings = widget.settings ?? AppSettings.load(widget.store.root);
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

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(kPanelGap),
        child: Row(
          children: [
            _panel(
              SizedBox(
                width: 88,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    _dest(Icons.church_rounded, l.navPreke, 0),
                    _dest(Icons.rate_review_rounded, l.navReview, 1),
                    _dest(Icons.work_history_rounded, l.navWerk, 2),
                    _dest(Icons.playlist_play_rounded, l.navSnitlyste, 3),
                    _dest(Icons.video_library_rounded, l.navBiblioteek, 6),
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
                IndexedStack(
                  index: _i,
                  children: [
                    SermonsScreen(
                      store: widget.store,
                      jobs: widget.jobs,
                      list: widget.list,
                      settings: _settings,
                      onOpen: (id) {
                        _review.open(id);
                        setState(() => _i = 1);
                      },
                    ),
                    ReviewScreen(
                      controller: _review,
                      settings: _settings,
                      onWork: () => setState(() => _i = 2),
                    ),
                    WorkScreen(
                      store: widget.store,
                      jobs: widget.jobs,
                      onBack: () => setState(() => _i = 0),
                      quota: _quota,
                    ),
                    PlaylistsScreen(store: widget.store, settings: _settings),
                    SettingsScreen(
                      settings: _settings,
                      auth: _auth,
                      signIn: () => _auth.signIn(openPath),
                      system: const SystemStatus(),
                      onSetup: () => setState(() => _i = 5),
                    ),
                    // Built only while shown, so it probes Ollama when opened, not at every start.
                    if (_i == 5)
                      SetupScreen(
                        settings: _settings,
                        auth: _auth,
                        signIn: () => _auth.signIn(openPath),
                        onSettings: () => setState(() => _i = 4),
                        onDone: () => setState(() => _i = 0),
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
          ],
        ),
      ),
    );
  }

  /// A flat panel on the ground (DESIGN.md): panel fill, radius 16, content clipped to it.
  Widget _panel(Widget child) => Material(
    key: const ValueKey('shell.panel'),
    color: Theme.of(context).extension<AppTokens>()!.panel,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(kPanelRadius),
    ),
    child: child,
  );

  Widget _dest(IconData icon, String label, int i) {
    final cs = Theme.of(context).colorScheme;
    final sel = _i == i;
    return Semantics(
      selected: sel,
      button: true,
      label: label,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: InkWell(
          key: ValueKey('ctl.skulp.nav-$i'),
          borderRadius: BorderRadius.circular(12),
          onTap: () => setState(() => _i = i),
          child: Ink(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: sel
                ? BoxDecoration(
                    color: cs.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  )
                : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: sel ? cs.onSecondaryContainer : null),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

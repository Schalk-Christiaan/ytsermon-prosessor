// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Afrikaans (`af`).
class LAf extends L {
  LAf([String locale = 'af']) : super(locale);

  @override
  String get appTitle => 'Preekverwerker';

  @override
  String get navReview => 'Hersien';

  @override
  String get navSettings => 'Instellings';

  @override
  String get navPreke => 'Preke';

  @override
  String get navWerk => 'Werk';

  @override
  String get navSnitlyste => 'Snitlyste';

  @override
  String get settingsSystem => 'Stelsel';

  @override
  String get toolReady => 'Gereed';

  @override
  String toolReadyVersion(String version) {
    return 'Gereed · $version';
  }

  @override
  String toolMissing(String name) {
    return 'Ontbreek: installeer $name';
  }

  @override
  String modelMissing(String model) {
    return 'Model $model ontbreek: hardloop ollama pull $model';
  }

  @override
  String get ollamaNotRunning => 'Ollama loop nie: begin die Ollama-diens';

  @override
  String get stageMeta => 'Lees onderskrifte…';

  @override
  String get stagePlan => 'Soek die preek…';

  @override
  String get stageDownload => 'Laai video af…';

  @override
  String get stageCut => 'Sny…';

  @override
  String elapsed(String time) {
    return '$time verloop';
  }

  @override
  String errorGeneric(String message) {
    return 'Iets het skeefgeloop: $message';
  }

  @override
  String get unplanned => 'Hierdie preek is nog nie beplan nie';

  @override
  String get planNow => 'Beplan nou';

  @override
  String get cutQueued => 'Gestuur na Werk';

  @override
  String get searchSermons => 'Soek preke';

  @override
  String get processNext => 'Verwerk volgende';

  @override
  String get noSermons => 'Geen preke gevind nie';

  @override
  String listError(String message) {
    return 'Die kanaal se lys kon nie gelaai word nie: $message';
  }

  @override
  String get updateYtDlp => 'Werk yt-dlp by';

  @override
  String updateYtDlpDone(String result) {
    return 'yt-dlp: $result';
  }

  @override
  String newServices(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n nuwe dienste',
      one: '1 nuwe diens',
    );
    return '$_temp0';
  }

  @override
  String get dismiss => 'Maak toe';

  @override
  String get noDate => '—';

  @override
  String get inQueue => 'In die ry';

  @override
  String get stateNuut => 'Nuut';

  @override
  String get stateBeplan => 'Beplan';

  @override
  String get stateGoedgekeur => 'Goedgekeur';

  @override
  String get stateGesny => 'Gesny';

  @override
  String get stateOpgelaai => 'Opgelaai';

  @override
  String get stateFout => 'Fout';

  @override
  String get stateOorgeslaan => 'Oorgeslaan';

  @override
  String get workNow => 'Besig';

  @override
  String get workWaiting => 'Wag';

  @override
  String get workDone => 'Klaar';

  @override
  String get workFailed => 'Foute';

  @override
  String get workEmpty => 'Niks in die ry nie.';

  @override
  String get play => 'Speel';

  @override
  String get technicalLog => 'Tegniese log';

  @override
  String get taskPlan => 'Plan';

  @override
  String get taskCut => 'Sny';

  @override
  String get taskAudio => 'Klank';

  @override
  String get stageAudio => 'Maak klank…';

  @override
  String get whatsappAudio => 'Klank vir WhatsApp';

  @override
  String get taskCancelled => 'Gekanselleer';

  @override
  String percent(int pct) {
    return '$pct%';
  }

  @override
  String taskLine(String kind, String title) {
    return '$kind: $title';
  }

  @override
  String get retry => 'Probeer weer';

  @override
  String get setManually => 'Stel self in';

  @override
  String get title => 'Titel';

  @override
  String get description => 'Beskrywing';

  @override
  String counter(int n, int max) {
    return '$n / $max';
  }

  @override
  String get saved => 'Gestoor';

  @override
  String get serviceTimeline => 'Dienstydlyn';

  @override
  String get speech => 'Spraak';

  @override
  String get music => 'Sang';

  @override
  String sermonHandleStart(String time) {
    return 'Preek begin $time';
  }

  @override
  String sermonHandleEnd(String time) {
    return 'Preek eindig $time';
  }

  @override
  String get shorts => 'Shorts';

  @override
  String get addShort => 'Voeg Short by';

  @override
  String get remove => 'Verwyder';

  @override
  String get approveAndCut => 'Keur goed en sny';

  @override
  String get replan => 'Beplan weer';

  @override
  String get doubtNoSermon =>
      'Geen preek van 15 minute of langer gevind nie; die hele diens is gekies. Stel die grense self.';

  @override
  String get doubtNoPrayerBefore =>
      'Geen gebed voor die preek gevind nie; die snit begin by die preek self. Kontroleer die begin.';

  @override
  String get doubtNoPrayerAfter =>
      'Geen gebed ná die preek gevind nie; die snit eindig by die preek self. Kontroleer die einde.';

  @override
  String get doubtTwoSermons =>
      'Twee lang stukke sonder \"Amen\"; dalk twee preke. Kontroleer albei grense.';

  @override
  String get goToBoundary => 'Gaan na die grens';

  @override
  String get skip => 'Slaan oor';

  @override
  String get replanConfirm => 'Jou wysigings aan titel en snit gaan verlore';

  @override
  String get cancel => 'Kanselleer';

  @override
  String get showInFolder => 'Wys in gids';

  @override
  String get emptyReview => 'Kies \'n preek in Preke.';

  @override
  String get skipped => 'Oorgeslaan';

  @override
  String downloadProgress(int pct) {
    return 'Laai video af: $pct%';
  }

  @override
  String shortRange(String start, String end) {
    return '$start – $end';
  }

  @override
  String get newShortTitle => 'Nuwe Short';

  @override
  String stageCutPct(int pct) {
    return 'Sny… $pct%';
  }

  @override
  String shortTooLong(int s) {
    return '$s s; maks 90 s';
  }

  @override
  String shortTooShort(int s) {
    return '$s s; minstens 20 s';
  }

  @override
  String get shortOutside => 'Lê buite die preek';

  @override
  String shortLength(int n) {
    return 'Lengte van Short $n';
  }

  @override
  String get approveBlocked => 'Herstel eers die Shorts wat rooi gemerk is';

  @override
  String shortPreview(int n) {
    return 'Short $n';
  }

  @override
  String get taskUpload => 'Oplaai';

  @override
  String get stageUpload => 'Laai op…';

  @override
  String get upload => 'Laai op';

  @override
  String get openOnYouTube => 'Wys op YouTube';

  @override
  String quotaToday(int n, int max) {
    return 'Oplaaie vandag: $n van $max';
  }

  @override
  String get navSettingsTitle => 'Instellings';

  @override
  String get settingsChannel => 'Kanaal';

  @override
  String get clientFile => 'Kliënt-ID-lêer (Google, Desktop app)';

  @override
  String get clientFileHelp =>
      'Laai dit by Google Cloud af; sien die stappe in die handleiding.';

  @override
  String get clientMissing => 'Geen kliënt-ID-lêer nie';

  @override
  String get notConnected => 'Nie gekoppel nie';

  @override
  String get connected => 'Gekoppel';

  @override
  String get connect => 'Koppel kanaal';

  @override
  String get disconnect => 'Ontkoppel';

  @override
  String get connectWaiting => 'Kies die kerk se rekening in die blaaier…';

  @override
  String get uploadPrivacy => 'Nuwe oplaaie is';

  @override
  String get privacyPrivate => 'Privaat';

  @override
  String get privacyUnlisted => 'Ongelys';

  @override
  String get privacyPublic => 'Publiek';

  @override
  String get playlistRules => 'Reëls';

  @override
  String get playlistRulesHelp =>
      'Die eerste reël wat by \'n preek pas, kies sy snitlys. Sleep om die volgorde te verander.';

  @override
  String get ruleBook => 'Bybelboek uit die Skriflesing';

  @override
  String get ruleYear => 'Jaar (\"Preke 2026\")';

  @override
  String get playlistPreview => 'Voorskou';

  @override
  String sermonCount(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n preke',
      one: '1 preek',
    );
    return '$_temp0';
  }

  @override
  String get noPlaylist => 'Sonder snitlys';

  @override
  String get template => 'Beskrywingsjabloon';

  @override
  String get templatePreview => 'So lyk dit vir die nuutste preek';

  @override
  String templateHelp(
    String tema,
    String skriflesing,
    String datum,
    String beskrywing,
  ) {
    return '$tema, $skriflesing, $datum en $beskrywing word ingevul.';
  }

  @override
  String get navSetup => 'Opstelling';

  @override
  String get setupIntro =>
      'Vier dinge, een keer. Daarna begin die app by Preke.';

  @override
  String get setupOllama => 'Ollama (die KI op hierdie rekenaar) loop';

  @override
  String get setupModel => 'Die KI-model is afgelaai (5 GB)';

  @override
  String get setupChannel => 'Jou YouTube-rekening is gekoppel (om op te laai)';

  @override
  String setupFolder(String path) {
    return 'Gids vir gesnyde preke: $path';
  }

  @override
  String get stepDone => 'Klaar';

  @override
  String get stepTodo => 'Nog nie';

  @override
  String get startOllama => 'Begin Ollama';

  @override
  String get downloadModel => 'Laai model af';

  @override
  String get clientFirst => 'Kies eers die kliënt-ID-lêer in Instellings';

  @override
  String get goSettings => 'Gaan na Instellings';

  @override
  String get makeFolder => 'Maak gids';

  @override
  String get startWork => 'Begin werk';

  @override
  String get checkAgain => 'Kontroleer weer';

  @override
  String get outFolder => 'Gids vir gesnyde preke';

  @override
  String get introOutro => 'Intro en outro';

  @override
  String get introOutroHelp =>
      'Video\'s wat voor en ná elke volle preek kom (nie op Shorts nie). Albei is opsioneel.';

  @override
  String get intro => 'Intro';

  @override
  String get outro => 'Outro';

  @override
  String get noClip => 'Geen';

  @override
  String get chooseFile => 'Kies…';

  @override
  String clipWithLength(String name, String length) {
    return '$name ($length)';
  }

  @override
  String clipUnreadable(String name) {
    return '$name kan nie gelees word nie';
  }

  @override
  String get noCaptions =>
      'Geen onderskrifte nie, stel die begin en einde self';

  @override
  String get transcript => 'Transkripsie';

  @override
  String get prayer => 'Gebed';

  @override
  String get cutOut => 'Uitgeknip';

  @override
  String cutsTab(int n) {
    return 'Uitgeknip ($n)';
  }

  @override
  String shortsTab(int n) {
    return 'Shorts ($n)';
  }

  @override
  String cutN(int n) {
    return 'Uitgeknip $n';
  }

  @override
  String get addCut => 'Knip uit by speelkop';

  @override
  String get noCuts =>
      'Niks uitgeknip nie. Speel na \'n stuk wat uit moet, soos \'n lied, en kies \"Knip uit by speelkop\".';

  @override
  String get startHere => 'Begin hier';

  @override
  String get endHere => 'Einde hier';

  @override
  String get playPause => 'Speel of pouse (spasie)';

  @override
  String get playFromStart => 'Speel van begin';

  @override
  String get playEnd => 'Speel die einde';

  @override
  String get previewCut => 'Voorskou van die snit';

  @override
  String get editorKeys =>
      'I/O: begin/einde by speelkop; ←/→: hakie 1 s, Shift 0,1 s';

  @override
  String get undo => 'Ontdoen (Ctrl+Z)';

  @override
  String get redo => 'Herdoen (Ctrl+Shift+Z)';

  @override
  String get noShorts =>
      'Nog geen Shorts nie. Speel na \'n sterk stuk van die preek en kies \"Voeg Short by\".';

  @override
  String get processLatest => 'Verwerk nuutste diens';

  @override
  String get filterNotUploaded => 'Nie opgelaai nie';

  @override
  String get importRecording => 'Voer opname in';

  @override
  String get importConfirm => 'Voer in';

  @override
  String get importing => 'Kopieer opname…';

  @override
  String get dropToImport => 'Los die video om dit as opname in te voer';

  @override
  String serviceDate(String date) {
    return 'Diens op $date';
  }

  @override
  String get updateOnYouTube => 'Werk op YouTube by';

  @override
  String updatedOnYouTube(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n video\'s op YouTube bygewerk',
      one: '1 video op YouTube bygewerk',
    );
    return '$_temp0';
  }

  @override
  String get outputsLabel => 'Uitvoere';

  @override
  String get outFull => 'Volle preek';

  @override
  String get outWord => 'Net die woord';

  @override
  String get outSongs => 'Sang';

  @override
  String get serviceDayLabel => 'Diens';

  @override
  String get serviceMorning => 'Oggend';

  @override
  String get serviceEvening => 'Aand';

  @override
  String get serviceKind => 'Soort diens';

  @override
  String get serviceKindNone => 'Gewone diens';

  @override
  String get serviceKindNagmaal => 'Nagmaal';

  @override
  String get serviceKindDoop => 'Doop';

  @override
  String get serviceKindKategismus => 'Kategismus';

  @override
  String get serviceKindBelydenis => 'Belydenis';

  @override
  String get serviceKindFeesdag => 'Feesdag';

  @override
  String get copyWhatsappText => 'Kopieer WhatsApp-teks';

  @override
  String get whatsappTextCopied => 'WhatsApp-teks gekopieer';

  @override
  String get whatsappTemplate => 'WhatsApp-teks';

  @override
  String whatsappTemplateHelp(
    String diens,
    String datum,
    String tema,
    String skriflesing,
    String fokus,
    String belydenis,
  ) {
    return '$diens, $datum, $tema, $skriflesing, $fokus en $belydenis word ingevul; \'n reël sonder inhoud val weg.';
  }

  @override
  String get navBiblioteek => 'Biblioteek';

  @override
  String get libraryPreke => 'Preke';

  @override
  String get librarySang => 'Sang';

  @override
  String get searchLibrary => 'Soek tema, skriflesing of lied';

  @override
  String get reload => 'Herlaai';

  @override
  String libraryEmpty(String folder) {
    return 'Nog geen dienste in $folder. Sny \'n preek in Hersien, dan verskyn dit hier.';
  }

  @override
  String get libraryNoMatch => 'Niks pas by die soektog nie.';

  @override
  String songUnnamed(int n) {
    return 'Lied $n';
  }

  @override
  String get trackSound => 'Klank';

  @override
  String get trackService => 'Diens';

  @override
  String get trackShorts => 'Shorts';

  @override
  String get seekBack5 => '5 s terug';

  @override
  String get seekForward5 => '5 s vorentoe';

  @override
  String get zoom => 'Zoem';

  @override
  String get zoomField => 'Zoem (×)';

  @override
  String get markIn => 'Preek begin by speelkop (I)';

  @override
  String get markOut => 'Preek einde by speelkop (O)';

  @override
  String get tabSermon => 'Preek';

  @override
  String get tabOutput => 'Uitvoer';

  @override
  String get properties => 'Eienskappe';

  @override
  String get resetProposal => 'Herstel na voorstel';

  @override
  String get shortBegin => 'Begin';

  @override
  String get shortSeconds => 'Lengte (s)';

  @override
  String get timeFieldError => 'Ongeldig; tik soos 23:04 of 60';

  @override
  String get previewVideoMissing => 'Video nog nie gereed nie';

  @override
  String get viewList => 'Lys';

  @override
  String get viewGrid => 'Rooster';

  @override
  String get noMatches => 'Geen preke pas by die soektog of filter nie';

  @override
  String get channelLabel => 'Jou YouTube-kanaal';

  @override
  String get channelHelp => 'Tik @naam, of plak die skakel van die kanaal.';

  @override
  String get channelCheck => 'Kontroleer';

  @override
  String channelFound(String name) {
    return 'Gevind: $name';
  }

  @override
  String get channelBadForm =>
      'Dit lyk nie soos \'n YouTube-kanaal nie. Probeer @naam, of plak die skakel.';

  @override
  String get channelNotFound =>
      'Kon nie hierdie kanaal vind nie. Kyk die naam en die internet, en probeer weer.';

  @override
  String statusDisk(String used, String free) {
    return 'Preke op skyf: $used · $free vry';
  }

  @override
  String statusDiskUsed(String used) {
    return 'Preke op skyf: $used';
  }

  @override
  String get colDate => 'Datum';

  @override
  String get colLength => 'Lengte';

  @override
  String get colState => 'Stand';

  @override
  String get colSize => 'Grootte';

  @override
  String statusSelected(int n, int total, String size) {
    return '$n van $total gekies · $size';
  }

  @override
  String get selectAll => 'Kies alles';

  @override
  String get groupFull => 'Volle preke';

  @override
  String get groupShorts => 'Shorts';

  @override
  String workGroupCount(int n, String size) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lêers',
      one: '1 lêer',
    );
    return '$_temp0 · $size';
  }

  @override
  String get uploadPublic => 'YouTube (openbaar)';

  @override
  String get uploadShortsPublic => 'YouTube Shorts (openbaar)';

  @override
  String get uploadUnlisted => 'YouTube (ongelys)';

  @override
  String get copyToFolder => 'Kopieer na gids…';

  @override
  String get workShare => 'Deel';

  @override
  String workCopied(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n lêers',
      one: '1 lêer',
    );
    return '$_temp0 gekopieer';
  }

  @override
  String get volume => 'Klankvolume (voorskou)';

  @override
  String get infoTab => 'Inligting';

  @override
  String shortOf(int n, int total) {
    return 'Short $n van $total';
  }

  @override
  String cutOf(int n, int total) {
    return 'Uitgeknip $n van $total';
  }

  @override
  String shortRow(int n, String time, int secs) {
    return 'Short $n · $time · $secs s';
  }

  @override
  String get groupsHeading => 'Eie snitlyste';

  @override
  String get groupsHelp =>
      'Maak \'n snitlys vir \'n reeks of \'n seisoen. \'n Preek kan in meer as een wees; by oplaai kom dit ook by hierdie snitlyste.';

  @override
  String get groupsEmpty => 'Nog geen eie snitlyste nie.';

  @override
  String get groupAdd => 'Nuwe snitlys';

  @override
  String get groupEditTitle => 'Snitlys';

  @override
  String get groupNameLabel => 'Naam';

  @override
  String get groupDescriptionLabel => 'Beskrywing (opsioneel)';

  @override
  String get groupSave => 'Stoor';

  @override
  String get groupRename => 'Wysig';

  @override
  String get groupSermons => 'Preke';

  @override
  String get groupDone => 'Klaar';

  @override
  String get groupDelete => 'Vee uit';

  @override
  String groupDeleteAsk(String name) {
    return 'Vee \"$name\" uit? Die preke self bly.';
  }

  @override
  String get groupKeep => 'Hou';

  @override
  String groupSermonsTitle(String name) {
    return 'Preke in \"$name\"';
  }

  @override
  String get groupSuggest => 'Stel preke voor';

  @override
  String suggestTitle(String name) {
    return 'Voorgestel vir \"$name\"';
  }

  @override
  String get suggestWorking =>
      'Ollama kyk deur die preke. Dit kan \'n minuut of twee neem.';

  @override
  String get suggestNone => 'Geen preke pas by hierdie snitlys nie.';

  @override
  String get suggestAccept => 'Aanvaar gekose';

  @override
  String get suggestIgnore => 'Ignoreer';

  @override
  String get suggestClose => 'Maak toe';

  @override
  String get suggestOllamaDown =>
      'Ollama het nie geantwoord nie. Maak Ollama oop en probeer weer.';

  @override
  String get workSuggestions => 'Voorgestelde snitlyste';

  @override
  String suggestFor(String title, String names) {
    return '$title: $names';
  }

  @override
  String get suggestAcceptOne => 'Aanvaar';

  @override
  String get stepMeta => 'Inligting';

  @override
  String get stepDownload => 'Aflaai';

  @override
  String get stepPlan => 'Preek soek';

  @override
  String get stepCut => 'Sny';

  @override
  String get stepAudio => 'Klank';

  @override
  String get stepUpload => 'Oplaai';

  @override
  String get progressSlow => 'Dit kan \'n paar minute duur.';

  @override
  String get progressShow => 'Wys besonderhede';

  @override
  String get progressHide => 'Versteek besonderhede';
}

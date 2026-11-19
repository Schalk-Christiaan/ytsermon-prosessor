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
  String get setupChannel => 'Die kerk se YouTube-kanaal is gekoppel';

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
}

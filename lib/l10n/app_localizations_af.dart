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
  String get comingPhase2 => 'Kom in fase 2';

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
  String get pasteUrl => 'Plak \'n YouTube-skakel';

  @override
  String get load => 'Laai';

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
  String cutDone(int sermons, int shorts) {
    return 'Gesny: $sermons preek, $shorts Shorts';
  }

  @override
  String get showInFolder => 'Wys in gids';

  @override
  String get emptyReview => 'Plak \'n skakel om \'n preek te hersien.';

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
}

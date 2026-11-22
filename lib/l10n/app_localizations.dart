import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_af.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of L
/// returned by `L.of(context)`.
///
/// Applications need to include `L.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: L.localizationsDelegates,
///   supportedLocales: L.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the L.supportedLocales
/// property.
abstract class L {
  L(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static L of(BuildContext context) {
    return Localizations.of<L>(context, L)!;
  }

  static const LocalizationsDelegate<L> delegate = _LDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('af')];

  /// No description provided for @appTitle.
  ///
  /// In af, this message translates to:
  /// **'Preekverwerker'**
  String get appTitle;

  /// No description provided for @navReview.
  ///
  /// In af, this message translates to:
  /// **'Hersien'**
  String get navReview;

  /// No description provided for @navSettings.
  ///
  /// In af, this message translates to:
  /// **'Instellings'**
  String get navSettings;

  /// No description provided for @navPreke.
  ///
  /// In af, this message translates to:
  /// **'Preke'**
  String get navPreke;

  /// No description provided for @navWerk.
  ///
  /// In af, this message translates to:
  /// **'Werk'**
  String get navWerk;

  /// No description provided for @navSnitlyste.
  ///
  /// In af, this message translates to:
  /// **'Snitlyste'**
  String get navSnitlyste;

  /// No description provided for @settingsSystem.
  ///
  /// In af, this message translates to:
  /// **'Stelsel'**
  String get settingsSystem;

  /// No description provided for @toolReady.
  ///
  /// In af, this message translates to:
  /// **'Gereed'**
  String get toolReady;

  /// No description provided for @toolReadyVersion.
  ///
  /// In af, this message translates to:
  /// **'Gereed · {version}'**
  String toolReadyVersion(String version);

  /// No description provided for @toolMissing.
  ///
  /// In af, this message translates to:
  /// **'Ontbreek: installeer {name}'**
  String toolMissing(String name);

  /// No description provided for @modelMissing.
  ///
  /// In af, this message translates to:
  /// **'Model {model} ontbreek: hardloop ollama pull {model}'**
  String modelMissing(String model);

  /// No description provided for @ollamaNotRunning.
  ///
  /// In af, this message translates to:
  /// **'Ollama loop nie: begin die Ollama-diens'**
  String get ollamaNotRunning;

  /// No description provided for @stageMeta.
  ///
  /// In af, this message translates to:
  /// **'Lees onderskrifte…'**
  String get stageMeta;

  /// No description provided for @stagePlan.
  ///
  /// In af, this message translates to:
  /// **'Soek die preek…'**
  String get stagePlan;

  /// No description provided for @stageDownload.
  ///
  /// In af, this message translates to:
  /// **'Laai video af…'**
  String get stageDownload;

  /// No description provided for @stageCut.
  ///
  /// In af, this message translates to:
  /// **'Sny…'**
  String get stageCut;

  /// No description provided for @elapsed.
  ///
  /// In af, this message translates to:
  /// **'{time} verloop'**
  String elapsed(String time);

  /// No description provided for @errorGeneric.
  ///
  /// In af, this message translates to:
  /// **'Iets het skeefgeloop: {message}'**
  String errorGeneric(String message);

  /// No description provided for @unplanned.
  ///
  /// In af, this message translates to:
  /// **'Hierdie preek is nog nie beplan nie'**
  String get unplanned;

  /// No description provided for @planNow.
  ///
  /// In af, this message translates to:
  /// **'Beplan nou'**
  String get planNow;

  /// No description provided for @cutQueued.
  ///
  /// In af, this message translates to:
  /// **'Gestuur na Werk'**
  String get cutQueued;

  /// No description provided for @searchSermons.
  ///
  /// In af, this message translates to:
  /// **'Soek preke'**
  String get searchSermons;

  /// No description provided for @processNext.
  ///
  /// In af, this message translates to:
  /// **'Verwerk volgende'**
  String get processNext;

  /// No description provided for @noSermons.
  ///
  /// In af, this message translates to:
  /// **'Geen preke gevind nie'**
  String get noSermons;

  /// No description provided for @listError.
  ///
  /// In af, this message translates to:
  /// **'Die kanaal se lys kon nie gelaai word nie: {message}'**
  String listError(String message);

  /// No description provided for @updateYtDlp.
  ///
  /// In af, this message translates to:
  /// **'Werk yt-dlp by'**
  String get updateYtDlp;

  /// No description provided for @updateYtDlpDone.
  ///
  /// In af, this message translates to:
  /// **'yt-dlp: {result}'**
  String updateYtDlpDone(String result);

  /// No description provided for @newServices.
  ///
  /// In af, this message translates to:
  /// **'{n, plural, =1{1 nuwe diens} other{{n} nuwe dienste}}'**
  String newServices(int n);

  /// No description provided for @dismiss.
  ///
  /// In af, this message translates to:
  /// **'Maak toe'**
  String get dismiss;

  /// No description provided for @noDate.
  ///
  /// In af, this message translates to:
  /// **'—'**
  String get noDate;

  /// No description provided for @inQueue.
  ///
  /// In af, this message translates to:
  /// **'In die ry'**
  String get inQueue;

  /// No description provided for @stateNuut.
  ///
  /// In af, this message translates to:
  /// **'Nuut'**
  String get stateNuut;

  /// No description provided for @stateBeplan.
  ///
  /// In af, this message translates to:
  /// **'Beplan'**
  String get stateBeplan;

  /// No description provided for @stateGoedgekeur.
  ///
  /// In af, this message translates to:
  /// **'Goedgekeur'**
  String get stateGoedgekeur;

  /// No description provided for @stateGesny.
  ///
  /// In af, this message translates to:
  /// **'Gesny'**
  String get stateGesny;

  /// No description provided for @stateOpgelaai.
  ///
  /// In af, this message translates to:
  /// **'Opgelaai'**
  String get stateOpgelaai;

  /// No description provided for @stateFout.
  ///
  /// In af, this message translates to:
  /// **'Fout'**
  String get stateFout;

  /// No description provided for @stateOorgeslaan.
  ///
  /// In af, this message translates to:
  /// **'Oorgeslaan'**
  String get stateOorgeslaan;

  /// No description provided for @workNow.
  ///
  /// In af, this message translates to:
  /// **'Besig'**
  String get workNow;

  /// No description provided for @workWaiting.
  ///
  /// In af, this message translates to:
  /// **'Wag'**
  String get workWaiting;

  /// No description provided for @workDone.
  ///
  /// In af, this message translates to:
  /// **'Klaar'**
  String get workDone;

  /// No description provided for @workFailed.
  ///
  /// In af, this message translates to:
  /// **'Foute'**
  String get workFailed;

  /// No description provided for @workEmpty.
  ///
  /// In af, this message translates to:
  /// **'Niks in die ry nie.'**
  String get workEmpty;

  /// No description provided for @play.
  ///
  /// In af, this message translates to:
  /// **'Speel'**
  String get play;

  /// No description provided for @technicalLog.
  ///
  /// In af, this message translates to:
  /// **'Tegniese log'**
  String get technicalLog;

  /// No description provided for @taskPlan.
  ///
  /// In af, this message translates to:
  /// **'Plan'**
  String get taskPlan;

  /// No description provided for @taskCut.
  ///
  /// In af, this message translates to:
  /// **'Sny'**
  String get taskCut;

  /// No description provided for @taskAudio.
  ///
  /// In af, this message translates to:
  /// **'Klank'**
  String get taskAudio;

  /// No description provided for @stageAudio.
  ///
  /// In af, this message translates to:
  /// **'Maak klank…'**
  String get stageAudio;

  /// No description provided for @whatsappAudio.
  ///
  /// In af, this message translates to:
  /// **'Klank vir WhatsApp'**
  String get whatsappAudio;

  /// No description provided for @taskCancelled.
  ///
  /// In af, this message translates to:
  /// **'Gekanselleer'**
  String get taskCancelled;

  /// No description provided for @percent.
  ///
  /// In af, this message translates to:
  /// **'{pct}%'**
  String percent(int pct);

  /// No description provided for @taskLine.
  ///
  /// In af, this message translates to:
  /// **'{kind}: {title}'**
  String taskLine(String kind, String title);

  /// No description provided for @retry.
  ///
  /// In af, this message translates to:
  /// **'Probeer weer'**
  String get retry;

  /// No description provided for @setManually.
  ///
  /// In af, this message translates to:
  /// **'Stel self in'**
  String get setManually;

  /// No description provided for @title.
  ///
  /// In af, this message translates to:
  /// **'Titel'**
  String get title;

  /// No description provided for @description.
  ///
  /// In af, this message translates to:
  /// **'Beskrywing'**
  String get description;

  /// No description provided for @counter.
  ///
  /// In af, this message translates to:
  /// **'{n} / {max}'**
  String counter(int n, int max);

  /// No description provided for @saved.
  ///
  /// In af, this message translates to:
  /// **'Gestoor'**
  String get saved;

  /// No description provided for @serviceTimeline.
  ///
  /// In af, this message translates to:
  /// **'Dienstydlyn'**
  String get serviceTimeline;

  /// No description provided for @speech.
  ///
  /// In af, this message translates to:
  /// **'Spraak'**
  String get speech;

  /// No description provided for @music.
  ///
  /// In af, this message translates to:
  /// **'Sang'**
  String get music;

  /// No description provided for @sermonHandleStart.
  ///
  /// In af, this message translates to:
  /// **'Preek begin {time}'**
  String sermonHandleStart(String time);

  /// No description provided for @sermonHandleEnd.
  ///
  /// In af, this message translates to:
  /// **'Preek eindig {time}'**
  String sermonHandleEnd(String time);

  /// No description provided for @shorts.
  ///
  /// In af, this message translates to:
  /// **'Shorts'**
  String get shorts;

  /// No description provided for @addShort.
  ///
  /// In af, this message translates to:
  /// **'Voeg Short by'**
  String get addShort;

  /// No description provided for @remove.
  ///
  /// In af, this message translates to:
  /// **'Verwyder'**
  String get remove;

  /// No description provided for @approveAndCut.
  ///
  /// In af, this message translates to:
  /// **'Keur goed en sny'**
  String get approveAndCut;

  /// No description provided for @replan.
  ///
  /// In af, this message translates to:
  /// **'Beplan weer'**
  String get replan;

  /// No description provided for @doubtNoSermon.
  ///
  /// In af, this message translates to:
  /// **'Geen preek van 15 minute of langer gevind nie; die hele diens is gekies. Stel die grense self.'**
  String get doubtNoSermon;

  /// No description provided for @doubtNoPrayerBefore.
  ///
  /// In af, this message translates to:
  /// **'Geen gebed voor die preek gevind nie; die snit begin by die preek self. Kontroleer die begin.'**
  String get doubtNoPrayerBefore;

  /// No description provided for @doubtNoPrayerAfter.
  ///
  /// In af, this message translates to:
  /// **'Geen gebed ná die preek gevind nie; die snit eindig by die preek self. Kontroleer die einde.'**
  String get doubtNoPrayerAfter;

  /// No description provided for @doubtTwoSermons.
  ///
  /// In af, this message translates to:
  /// **'Twee lang stukke sonder \"Amen\"; dalk twee preke. Kontroleer albei grense.'**
  String get doubtTwoSermons;

  /// No description provided for @goToBoundary.
  ///
  /// In af, this message translates to:
  /// **'Gaan na die grens'**
  String get goToBoundary;

  /// No description provided for @skip.
  ///
  /// In af, this message translates to:
  /// **'Slaan oor'**
  String get skip;

  /// No description provided for @replanConfirm.
  ///
  /// In af, this message translates to:
  /// **'Jou wysigings aan titel en snit gaan verlore'**
  String get replanConfirm;

  /// No description provided for @cancel.
  ///
  /// In af, this message translates to:
  /// **'Kanselleer'**
  String get cancel;

  /// No description provided for @showInFolder.
  ///
  /// In af, this message translates to:
  /// **'Wys in gids'**
  String get showInFolder;

  /// No description provided for @emptyReview.
  ///
  /// In af, this message translates to:
  /// **'Kies \'n preek in Preke.'**
  String get emptyReview;

  /// No description provided for @skipped.
  ///
  /// In af, this message translates to:
  /// **'Oorgeslaan'**
  String get skipped;

  /// No description provided for @downloadProgress.
  ///
  /// In af, this message translates to:
  /// **'Laai video af: {pct}%'**
  String downloadProgress(int pct);

  /// No description provided for @shortRange.
  ///
  /// In af, this message translates to:
  /// **'{start} – {end}'**
  String shortRange(String start, String end);

  /// No description provided for @newShortTitle.
  ///
  /// In af, this message translates to:
  /// **'Nuwe Short'**
  String get newShortTitle;

  /// No description provided for @stageCutPct.
  ///
  /// In af, this message translates to:
  /// **'Sny… {pct}%'**
  String stageCutPct(int pct);

  /// No description provided for @shortTooLong.
  ///
  /// In af, this message translates to:
  /// **'{s} s; maks 90 s'**
  String shortTooLong(int s);

  /// No description provided for @shortTooShort.
  ///
  /// In af, this message translates to:
  /// **'{s} s; minstens 20 s'**
  String shortTooShort(int s);

  /// No description provided for @shortOutside.
  ///
  /// In af, this message translates to:
  /// **'Lê buite die preek'**
  String get shortOutside;

  /// No description provided for @shortLength.
  ///
  /// In af, this message translates to:
  /// **'Lengte van Short {n}'**
  String shortLength(int n);

  /// No description provided for @approveBlocked.
  ///
  /// In af, this message translates to:
  /// **'Herstel eers die Shorts wat rooi gemerk is'**
  String get approveBlocked;

  /// No description provided for @shortPreview.
  ///
  /// In af, this message translates to:
  /// **'Short {n}'**
  String shortPreview(int n);

  /// No description provided for @taskUpload.
  ///
  /// In af, this message translates to:
  /// **'Oplaai'**
  String get taskUpload;

  /// No description provided for @stageUpload.
  ///
  /// In af, this message translates to:
  /// **'Laai op…'**
  String get stageUpload;

  /// No description provided for @upload.
  ///
  /// In af, this message translates to:
  /// **'Laai op'**
  String get upload;

  /// No description provided for @openOnYouTube.
  ///
  /// In af, this message translates to:
  /// **'Wys op YouTube'**
  String get openOnYouTube;

  /// No description provided for @quotaToday.
  ///
  /// In af, this message translates to:
  /// **'Oplaaie vandag: {n} van {max}'**
  String quotaToday(int n, int max);

  /// No description provided for @navSettingsTitle.
  ///
  /// In af, this message translates to:
  /// **'Instellings'**
  String get navSettingsTitle;

  /// No description provided for @settingsChannel.
  ///
  /// In af, this message translates to:
  /// **'Kanaal'**
  String get settingsChannel;

  /// No description provided for @clientFile.
  ///
  /// In af, this message translates to:
  /// **'Kliënt-ID-lêer (Google, Desktop app)'**
  String get clientFile;

  /// No description provided for @clientFileHelp.
  ///
  /// In af, this message translates to:
  /// **'Laai dit by Google Cloud af; sien die stappe in die handleiding.'**
  String get clientFileHelp;

  /// No description provided for @clientMissing.
  ///
  /// In af, this message translates to:
  /// **'Geen kliënt-ID-lêer nie'**
  String get clientMissing;

  /// No description provided for @notConnected.
  ///
  /// In af, this message translates to:
  /// **'Nie gekoppel nie'**
  String get notConnected;

  /// No description provided for @connected.
  ///
  /// In af, this message translates to:
  /// **'Gekoppel'**
  String get connected;

  /// No description provided for @connect.
  ///
  /// In af, this message translates to:
  /// **'Koppel kanaal'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In af, this message translates to:
  /// **'Ontkoppel'**
  String get disconnect;

  /// No description provided for @connectWaiting.
  ///
  /// In af, this message translates to:
  /// **'Kies die kerk se rekening in die blaaier…'**
  String get connectWaiting;

  /// No description provided for @uploadPrivacy.
  ///
  /// In af, this message translates to:
  /// **'Nuwe oplaaie is'**
  String get uploadPrivacy;

  /// No description provided for @privacyPrivate.
  ///
  /// In af, this message translates to:
  /// **'Privaat'**
  String get privacyPrivate;

  /// No description provided for @privacyUnlisted.
  ///
  /// In af, this message translates to:
  /// **'Ongelys'**
  String get privacyUnlisted;

  /// No description provided for @privacyPublic.
  ///
  /// In af, this message translates to:
  /// **'Publiek'**
  String get privacyPublic;

  /// No description provided for @playlistRules.
  ///
  /// In af, this message translates to:
  /// **'Reëls'**
  String get playlistRules;

  /// No description provided for @playlistRulesHelp.
  ///
  /// In af, this message translates to:
  /// **'Die eerste reël wat by \'n preek pas, kies sy snitlys. Sleep om die volgorde te verander.'**
  String get playlistRulesHelp;

  /// No description provided for @ruleBook.
  ///
  /// In af, this message translates to:
  /// **'Bybelboek uit die Skriflesing'**
  String get ruleBook;

  /// No description provided for @ruleYear.
  ///
  /// In af, this message translates to:
  /// **'Jaar (\"Preke 2026\")'**
  String get ruleYear;

  /// No description provided for @playlistPreview.
  ///
  /// In af, this message translates to:
  /// **'Voorskou'**
  String get playlistPreview;

  /// No description provided for @sermonCount.
  ///
  /// In af, this message translates to:
  /// **'{n, plural, =1{1 preek} other{{n} preke}}'**
  String sermonCount(int n);

  /// No description provided for @noPlaylist.
  ///
  /// In af, this message translates to:
  /// **'Sonder snitlys'**
  String get noPlaylist;

  /// No description provided for @template.
  ///
  /// In af, this message translates to:
  /// **'Beskrywingsjabloon'**
  String get template;

  /// No description provided for @templatePreview.
  ///
  /// In af, this message translates to:
  /// **'So lyk dit vir die nuutste preek'**
  String get templatePreview;

  /// Arguments are the literal tokens {tema} etc.
  ///
  /// In af, this message translates to:
  /// **'{tema}, {skriflesing}, {datum} en {beskrywing} word ingevul.'**
  String templateHelp(
    String tema,
    String skriflesing,
    String datum,
    String beskrywing,
  );

  /// No description provided for @navSetup.
  ///
  /// In af, this message translates to:
  /// **'Opstelling'**
  String get navSetup;

  /// No description provided for @setupIntro.
  ///
  /// In af, this message translates to:
  /// **'Vier dinge, een keer. Daarna begin die app by Preke.'**
  String get setupIntro;

  /// No description provided for @setupOllama.
  ///
  /// In af, this message translates to:
  /// **'Ollama (die KI op hierdie rekenaar) loop'**
  String get setupOllama;

  /// No description provided for @setupModel.
  ///
  /// In af, this message translates to:
  /// **'Die KI-model is afgelaai (5 GB)'**
  String get setupModel;

  /// No description provided for @setupChannel.
  ///
  /// In af, this message translates to:
  /// **'Jou YouTube-rekening is gekoppel (om op te laai)'**
  String get setupChannel;

  /// No description provided for @setupFolder.
  ///
  /// In af, this message translates to:
  /// **'Gids vir gesnyde preke: {path}'**
  String setupFolder(String path);

  /// No description provided for @stepDone.
  ///
  /// In af, this message translates to:
  /// **'Klaar'**
  String get stepDone;

  /// No description provided for @stepTodo.
  ///
  /// In af, this message translates to:
  /// **'Nog nie'**
  String get stepTodo;

  /// No description provided for @startOllama.
  ///
  /// In af, this message translates to:
  /// **'Begin Ollama'**
  String get startOllama;

  /// No description provided for @downloadModel.
  ///
  /// In af, this message translates to:
  /// **'Laai model af'**
  String get downloadModel;

  /// No description provided for @clientFirst.
  ///
  /// In af, this message translates to:
  /// **'Kies eers die kliënt-ID-lêer in Instellings'**
  String get clientFirst;

  /// No description provided for @goSettings.
  ///
  /// In af, this message translates to:
  /// **'Gaan na Instellings'**
  String get goSettings;

  /// No description provided for @makeFolder.
  ///
  /// In af, this message translates to:
  /// **'Maak gids'**
  String get makeFolder;

  /// No description provided for @startWork.
  ///
  /// In af, this message translates to:
  /// **'Begin werk'**
  String get startWork;

  /// No description provided for @checkAgain.
  ///
  /// In af, this message translates to:
  /// **'Kontroleer weer'**
  String get checkAgain;

  /// No description provided for @outFolder.
  ///
  /// In af, this message translates to:
  /// **'Gids vir gesnyde preke'**
  String get outFolder;

  /// No description provided for @introOutro.
  ///
  /// In af, this message translates to:
  /// **'Intro en outro'**
  String get introOutro;

  /// No description provided for @introOutroHelp.
  ///
  /// In af, this message translates to:
  /// **'Video\'s wat voor en ná elke volle preek kom (nie op Shorts nie). Albei is opsioneel.'**
  String get introOutroHelp;

  /// No description provided for @intro.
  ///
  /// In af, this message translates to:
  /// **'Intro'**
  String get intro;

  /// No description provided for @outro.
  ///
  /// In af, this message translates to:
  /// **'Outro'**
  String get outro;

  /// No description provided for @noClip.
  ///
  /// In af, this message translates to:
  /// **'Geen'**
  String get noClip;

  /// No description provided for @chooseFile.
  ///
  /// In af, this message translates to:
  /// **'Kies…'**
  String get chooseFile;

  /// No description provided for @clipWithLength.
  ///
  /// In af, this message translates to:
  /// **'{name} ({length})'**
  String clipWithLength(String name, String length);

  /// No description provided for @clipUnreadable.
  ///
  /// In af, this message translates to:
  /// **'{name} kan nie gelees word nie'**
  String clipUnreadable(String name);

  /// No description provided for @noCaptions.
  ///
  /// In af, this message translates to:
  /// **'Geen onderskrifte nie, stel die begin en einde self'**
  String get noCaptions;

  /// No description provided for @transcript.
  ///
  /// In af, this message translates to:
  /// **'Transkripsie'**
  String get transcript;

  /// No description provided for @prayer.
  ///
  /// In af, this message translates to:
  /// **'Gebed'**
  String get prayer;

  /// No description provided for @cutOut.
  ///
  /// In af, this message translates to:
  /// **'Uitgeknip'**
  String get cutOut;

  /// No description provided for @cutsTab.
  ///
  /// In af, this message translates to:
  /// **'Uitgeknip ({n})'**
  String cutsTab(int n);

  /// No description provided for @shortsTab.
  ///
  /// In af, this message translates to:
  /// **'Shorts ({n})'**
  String shortsTab(int n);

  /// No description provided for @cutN.
  ///
  /// In af, this message translates to:
  /// **'Uitgeknip {n}'**
  String cutN(int n);

  /// No description provided for @addCut.
  ///
  /// In af, this message translates to:
  /// **'Knip uit by speelkop'**
  String get addCut;

  /// No description provided for @noCuts.
  ///
  /// In af, this message translates to:
  /// **'Niks uitgeknip nie. Speel na \'n stuk wat uit moet, soos \'n lied, en kies \"Knip uit by speelkop\".'**
  String get noCuts;

  /// No description provided for @startHere.
  ///
  /// In af, this message translates to:
  /// **'Begin hier'**
  String get startHere;

  /// No description provided for @endHere.
  ///
  /// In af, this message translates to:
  /// **'Einde hier'**
  String get endHere;

  /// No description provided for @playPause.
  ///
  /// In af, this message translates to:
  /// **'Speel of pouse (spasie)'**
  String get playPause;

  /// No description provided for @playFromStart.
  ///
  /// In af, this message translates to:
  /// **'Speel van begin'**
  String get playFromStart;

  /// No description provided for @playEnd.
  ///
  /// In af, this message translates to:
  /// **'Speel die einde'**
  String get playEnd;

  /// No description provided for @previewCut.
  ///
  /// In af, this message translates to:
  /// **'Voorskou van die snit'**
  String get previewCut;

  /// No description provided for @editorKeys.
  ///
  /// In af, this message translates to:
  /// **'I/O: begin/einde by speelkop; ←/→: hakie 1 s, Shift 0,1 s'**
  String get editorKeys;

  /// No description provided for @undo.
  ///
  /// In af, this message translates to:
  /// **'Ontdoen (Ctrl+Z)'**
  String get undo;

  /// No description provided for @redo.
  ///
  /// In af, this message translates to:
  /// **'Herdoen (Ctrl+Shift+Z)'**
  String get redo;

  /// No description provided for @noShorts.
  ///
  /// In af, this message translates to:
  /// **'Nog geen Shorts nie. Speel na \'n sterk stuk van die preek en kies \"Voeg Short by\".'**
  String get noShorts;

  /// No description provided for @processLatest.
  ///
  /// In af, this message translates to:
  /// **'Verwerk nuutste diens'**
  String get processLatest;

  /// No description provided for @filterNotUploaded.
  ///
  /// In af, this message translates to:
  /// **'Nie opgelaai nie'**
  String get filterNotUploaded;

  /// No description provided for @importRecording.
  ///
  /// In af, this message translates to:
  /// **'Voer opname in'**
  String get importRecording;

  /// No description provided for @importConfirm.
  ///
  /// In af, this message translates to:
  /// **'Voer in'**
  String get importConfirm;

  /// No description provided for @importing.
  ///
  /// In af, this message translates to:
  /// **'Kopieer opname…'**
  String get importing;

  /// No description provided for @dropToImport.
  ///
  /// In af, this message translates to:
  /// **'Los die video om dit as opname in te voer'**
  String get dropToImport;

  /// No description provided for @serviceDate.
  ///
  /// In af, this message translates to:
  /// **'Diens op {date}'**
  String serviceDate(String date);

  /// No description provided for @updateOnYouTube.
  ///
  /// In af, this message translates to:
  /// **'Werk op YouTube by'**
  String get updateOnYouTube;

  /// No description provided for @updatedOnYouTube.
  ///
  /// In af, this message translates to:
  /// **'{n, plural, =1{1 video op YouTube bygewerk} other{{n} video\'s op YouTube bygewerk}}'**
  String updatedOnYouTube(int n);

  /// No description provided for @outputsLabel.
  ///
  /// In af, this message translates to:
  /// **'Uitvoere'**
  String get outputsLabel;

  /// No description provided for @outFull.
  ///
  /// In af, this message translates to:
  /// **'Volle preek'**
  String get outFull;

  /// No description provided for @outWord.
  ///
  /// In af, this message translates to:
  /// **'Net die woord'**
  String get outWord;

  /// No description provided for @outSongs.
  ///
  /// In af, this message translates to:
  /// **'Sang'**
  String get outSongs;

  /// No description provided for @serviceDayLabel.
  ///
  /// In af, this message translates to:
  /// **'Diens'**
  String get serviceDayLabel;

  /// No description provided for @serviceMorning.
  ///
  /// In af, this message translates to:
  /// **'Oggend'**
  String get serviceMorning;

  /// No description provided for @serviceEvening.
  ///
  /// In af, this message translates to:
  /// **'Aand'**
  String get serviceEvening;

  /// No description provided for @serviceKind.
  ///
  /// In af, this message translates to:
  /// **'Soort diens'**
  String get serviceKind;

  /// No description provided for @serviceKindNone.
  ///
  /// In af, this message translates to:
  /// **'Gewone diens'**
  String get serviceKindNone;

  /// No description provided for @serviceKindNagmaal.
  ///
  /// In af, this message translates to:
  /// **'Nagmaal'**
  String get serviceKindNagmaal;

  /// No description provided for @serviceKindDoop.
  ///
  /// In af, this message translates to:
  /// **'Doop'**
  String get serviceKindDoop;

  /// No description provided for @serviceKindKategismus.
  ///
  /// In af, this message translates to:
  /// **'Kategismus'**
  String get serviceKindKategismus;

  /// No description provided for @serviceKindBelydenis.
  ///
  /// In af, this message translates to:
  /// **'Belydenis'**
  String get serviceKindBelydenis;

  /// No description provided for @serviceKindFeesdag.
  ///
  /// In af, this message translates to:
  /// **'Feesdag'**
  String get serviceKindFeesdag;

  /// No description provided for @copyWhatsappText.
  ///
  /// In af, this message translates to:
  /// **'Kopieer WhatsApp-teks'**
  String get copyWhatsappText;

  /// No description provided for @whatsappTextCopied.
  ///
  /// In af, this message translates to:
  /// **'WhatsApp-teks gekopieer'**
  String get whatsappTextCopied;

  /// No description provided for @whatsappTemplate.
  ///
  /// In af, this message translates to:
  /// **'WhatsApp-teks'**
  String get whatsappTemplate;

  /// Arguments are the literal tokens {diens} etc.
  ///
  /// In af, this message translates to:
  /// **'{diens}, {datum}, {tema}, {skriflesing}, {fokus} en {belydenis} word ingevul; \'n reël sonder inhoud val weg.'**
  String whatsappTemplateHelp(
    String diens,
    String datum,
    String tema,
    String skriflesing,
    String fokus,
    String belydenis,
  );

  /// No description provided for @navBiblioteek.
  ///
  /// In af, this message translates to:
  /// **'Biblioteek'**
  String get navBiblioteek;

  /// No description provided for @libraryPreke.
  ///
  /// In af, this message translates to:
  /// **'Preke'**
  String get libraryPreke;

  /// No description provided for @librarySang.
  ///
  /// In af, this message translates to:
  /// **'Sang'**
  String get librarySang;

  /// No description provided for @searchLibrary.
  ///
  /// In af, this message translates to:
  /// **'Soek tema, skriflesing of lied'**
  String get searchLibrary;

  /// No description provided for @reload.
  ///
  /// In af, this message translates to:
  /// **'Herlaai'**
  String get reload;

  /// No description provided for @libraryEmpty.
  ///
  /// In af, this message translates to:
  /// **'Nog geen dienste in {folder}. Sny \'n preek in Hersien, dan verskyn dit hier.'**
  String libraryEmpty(String folder);

  /// No description provided for @libraryNoMatch.
  ///
  /// In af, this message translates to:
  /// **'Niks pas by die soektog nie.'**
  String get libraryNoMatch;

  /// No description provided for @songUnnamed.
  ///
  /// In af, this message translates to:
  /// **'Lied {n}'**
  String songUnnamed(int n);

  /// No description provided for @trackSound.
  ///
  /// In af, this message translates to:
  /// **'Klank'**
  String get trackSound;

  /// No description provided for @trackService.
  ///
  /// In af, this message translates to:
  /// **'Diens'**
  String get trackService;

  /// No description provided for @trackShorts.
  ///
  /// In af, this message translates to:
  /// **'Shorts'**
  String get trackShorts;

  /// No description provided for @seekBack5.
  ///
  /// In af, this message translates to:
  /// **'5 s terug'**
  String get seekBack5;

  /// No description provided for @seekForward5.
  ///
  /// In af, this message translates to:
  /// **'5 s vorentoe'**
  String get seekForward5;

  /// No description provided for @zoom.
  ///
  /// In af, this message translates to:
  /// **'Zoem'**
  String get zoom;

  /// No description provided for @zoomField.
  ///
  /// In af, this message translates to:
  /// **'Zoem (×)'**
  String get zoomField;

  /// No description provided for @markIn.
  ///
  /// In af, this message translates to:
  /// **'Preek begin by speelkop (I)'**
  String get markIn;

  /// No description provided for @markOut.
  ///
  /// In af, this message translates to:
  /// **'Preek einde by speelkop (O)'**
  String get markOut;

  /// No description provided for @tabSermon.
  ///
  /// In af, this message translates to:
  /// **'Preek'**
  String get tabSermon;

  /// No description provided for @tabOutput.
  ///
  /// In af, this message translates to:
  /// **'Uitvoer'**
  String get tabOutput;

  /// No description provided for @sermonBegin.
  ///
  /// In af, this message translates to:
  /// **'Begin'**
  String get sermonBegin;

  /// No description provided for @sermonEndLabel.
  ///
  /// In af, this message translates to:
  /// **'Einde'**
  String get sermonEndLabel;

  /// No description provided for @volume.
  ///
  /// In af, this message translates to:
  /// **'Klankvolume (voorskou)'**
  String get volume;

  /// No description provided for @properties.
  ///
  /// In af, this message translates to:
  /// **'Eienskappe'**
  String get properties;

  /// No description provided for @resetProposal.
  ///
  /// In af, this message translates to:
  /// **'Herstel na voorstel'**
  String get resetProposal;

  /// No description provided for @shortBegin.
  ///
  /// In af, this message translates to:
  /// **'Begin'**
  String get shortBegin;

  /// No description provided for @shortSeconds.
  ///
  /// In af, this message translates to:
  /// **'Lengte (s)'**
  String get shortSeconds;

  /// No description provided for @timeFieldError.
  ///
  /// In af, this message translates to:
  /// **'Ongeldig; tik soos 23:04 of 60'**
  String get timeFieldError;

  /// No description provided for @previewVideoMissing.
  ///
  /// In af, this message translates to:
  /// **'Video nog nie gereed nie'**
  String get previewVideoMissing;

  /// No description provided for @viewList.
  ///
  /// In af, this message translates to:
  /// **'Lys'**
  String get viewList;

  /// No description provided for @viewGrid.
  ///
  /// In af, this message translates to:
  /// **'Rooster'**
  String get viewGrid;

  /// No description provided for @noMatches.
  ///
  /// In af, this message translates to:
  /// **'Geen preke pas by die soektog of filter nie'**
  String get noMatches;

  /// No description provided for @channelLabel.
  ///
  /// In af, this message translates to:
  /// **'Jou YouTube-kanaal'**
  String get channelLabel;

  /// No description provided for @channelHelp.
  ///
  /// In af, this message translates to:
  /// **'Tik @naam, of plak die skakel van die kanaal.'**
  String get channelHelp;

  /// No description provided for @channelCheck.
  ///
  /// In af, this message translates to:
  /// **'Kontroleer'**
  String get channelCheck;

  /// No description provided for @channelFound.
  ///
  /// In af, this message translates to:
  /// **'Gevind: {name}'**
  String channelFound(String name);

  /// No description provided for @channelBadForm.
  ///
  /// In af, this message translates to:
  /// **'Dit lyk nie soos \'n YouTube-kanaal nie. Probeer @naam, of plak die skakel.'**
  String get channelBadForm;

  /// No description provided for @channelNotFound.
  ///
  /// In af, this message translates to:
  /// **'Kon nie hierdie kanaal vind nie. Kyk die naam en die internet, en probeer weer.'**
  String get channelNotFound;
}

class _LDelegate extends LocalizationsDelegate<L> {
  const _LDelegate();

  @override
  Future<L> load(Locale locale) {
    return SynchronousFuture<L>(lookupL(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['af'].contains(locale.languageCode);

  @override
  bool shouldReload(_LDelegate old) => false;
}

L lookupL(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'af':
      return LAf();
  }

  throw FlutterError(
    'L.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}

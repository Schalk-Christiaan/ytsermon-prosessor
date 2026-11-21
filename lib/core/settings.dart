// @stelsel settings
//   soort: module
//   wanneer: by begin gelaai; gestoor as Instellings of Snitlyste verander
//   groep: core | Kern
//   skryf: <werkmap>/settings.json | atomies
//   doel: Schalk se keuses: kliënt-ID-lêer, oplaai-privaatheid, beskrywingsjabloon, snitlysreëls, uitsetgids, watter uitvoere 'n sny maak, WhatsApp-sjabloon, of Opstelling klaar is
//   status: klaar
//   bewys: 7236634
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'channel.dart' show kChannelUrl;
import 'cutter.dart' show kWhatsappTemplate;
import 'paths.dart';
import 'store.dart';

const kDefaultTemplate =
    '{beskrywing}\n\nSkriflesing: {skriflesing}\n'
    'Diens van {datum}, Gereformeerde Kerk Oranjerivier.';

/// The outputs of a service: `full` (Volle preek), `word` (Net die woord), `songs` (Sang).
const kExports = ['full', 'word', 'songs'];

/// App settings in `<work>/settings.json`; missing keys fall back to defaults.
class AppSettings {
  AppSettings._(this._file, Map<String, dynamic> j)
    : clientFile =
          j['clientFile'] as String? ??
          p.join(p.dirname(_file.path), 'client_secret.json'),
      channelUrl = j['channelUrl'] as String? ?? kChannelUrl,
      privacy = j['privacy'] as String? ?? 'private',
      template = j['template'] as String? ?? kDefaultTemplate,
      outDir = j['outDir'] as String? ?? defaultOutDir(),
      setupDone = j['setupDone'] as bool? ?? false,
      sermonGrid = j['sermonGrid'] as bool? ?? false,
      intro = j['intro'] as String?,
      outro = j['outro'] as String?,
      exports = {...((j['exports'] as List?)?.cast<String>() ?? kExports)},
      whatsappTemplate = j['whatsappTemplate'] as String? ?? kWhatsappTemplate,
      rules = [...?(j['rules'] as List?)?.cast<String>()] {
    if (!j.containsKey('rules')) rules = ['book', 'year'];
  }

  factory AppSettings.load(Directory root) {
    final f = File(p.join(root.path, 'settings.json'));
    Map<String, dynamic> j = {};
    try {
      j = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    } on Object {
      // missing or damaged: start from the defaults rather than fail to open
    }
    return AppSettings._(f, j);
  }

  final File _file;
  Directory get root => _file.parent;

  /// Google's downloaded `client_secret_*.json` (Desktop app).
  String clientFile;

  /// The YouTube channel whose services are listed (see `normalizeChannelUrl`); the church's by default.
  String channelUrl;

  /// YouTube privacyStatus for uploads: private, unlisted or public.
  String privacy;
  String template;

  /// Playlist rules in order: `book`, `year`.
  List<String> rules;

  /// Where cut sermons, Shorts and audio go.
  String outDir;

  /// The Opstelling list was completed once; the app then starts on Preke.
  bool setupDone;

  /// Preke shows the grid instead of the list (remembered across restarts).
  bool sermonGrid;

  /// Which outputs a cut makes (see [kExports]); all by default.
  Set<String> exports;

  /// The WhatsApp text template (see `whatsappText`).
  String whatsappTemplate;

  /// Video clips joined before and after every full sermon (not Shorts); null = none.
  String? intro, outro;

  void save() => writeJson(_file, {
    'clientFile': clientFile,
    'channelUrl': channelUrl,
    'privacy': privacy,
    'template': template,
    'rules': rules,
    'outDir': outDir,
    'setupDone': setupDone,
    'sermonGrid': sermonGrid,
    'intro': intro,
    'outro': outro,
    'exports': [
      for (final e in kExports)
        if (exports.contains(e)) e,
    ],
    'whatsappTemplate': whatsappTemplate,
  });
}

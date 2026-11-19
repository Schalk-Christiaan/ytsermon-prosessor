// @stelsel settings
//   soort: module
//   wanneer: by begin gelaai; gestoor as Instellings of Snitlyste verander
//   groep: core | Kern
//   skryf: <werkmap>/settings.json | atomies
//   doel: Schalk se keuses: kliënt-ID-lêer, oplaai-privaatheid, beskrywingsjabloon, snitlysreëls, uitsetgids, of Opstelling klaar is
//   status: oop
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'paths.dart';
import 'store.dart';

const kDefaultTemplate =
    '{beskrywing}\n\nSkriflesing: {skriflesing}\n'
    'Diens van {datum}, Gereformeerde Kerk Oranjerivier.';

/// App settings in `<work>/settings.json`; missing keys fall back to defaults.
class AppSettings {
  AppSettings._(this._file, Map<String, dynamic> j)
    : clientFile =
          j['clientFile'] as String? ??
          p.join(p.dirname(_file.path), 'client_secret.json'),
      privacy = j['privacy'] as String? ?? 'private',
      template = j['template'] as String? ?? kDefaultTemplate,
      outDir = j['outDir'] as String? ?? defaultOutDir(),
      setupDone = j['setupDone'] as bool? ?? false,
      rules = [...?(j['rules'] as List?)?.cast<String>()] {
    if (!j.containsKey('rules')) rules = ['book', 'year'];
  }

  factory AppSettings.load(Directory root) {
    final f = File(p.join(root.path, 'settings.json'));
    return AppSettings._(
      f,
      f.existsSync()
          ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
          : {},
    );
  }

  final File _file;

  /// Google's downloaded `client_secret_*.json` (Desktop app).
  String clientFile;

  /// YouTube privacyStatus for uploads: private, unlisted or public.
  String privacy;
  String template;

  /// Playlist rules in order: `book`, `year`.
  List<String> rules;

  /// Where cut sermons, Shorts and audio go.
  String outDir;

  /// The Opstelling list was completed once; the app then starts on Preke.
  bool setupDone;

  void save() => writeJson(_file, {
    'clientFile': clientFile,
    'privacy': privacy,
    'template': template,
    'rules': rules,
    'outDir': outDir,
    'setupDone': setupDone,
  });
}

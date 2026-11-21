// @stelsel paths
//   soort: module
//   wanneer: by laai en sny
//   groep: core | Kern
//   skryf: —
//   doel: werkmap, gebundelde lettertipe en verstek-uitsetgids
//   status: bou
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// `<app-support>/work`, one folder per video ID.
Future<Directory> workRoot() async =>
    Directory(p.join((await getApplicationSupportDirectory()).path, 'work'));

/// The bundled font next to the executable (`flutter_assets`), for the burned-in subtitles.
File bundledFont() => File(
  p.join(
    p.dirname(Platform.resolvedExecutable),
    'data',
    'flutter_assets',
    'assets',
    'fonts',
    'sans.ttf',
  ),
);

/// Default output folder: `<home>/Videos/Preke` (the Videos library on Windows).
String defaultOutDir() => p.join(
  Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '.',
  'Videos',
  'Preke',
);

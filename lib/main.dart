import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'app/shell.dart';
import 'app/theme.dart';
import 'core/jobs.dart';
import 'core/paths.dart';
import 'core/store.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final store = SermonStore(await workRoot())..load();
  runApp(PreekApp(store: store, jobs: JobQueue(store)..start()));
}

class PreekApp extends StatelessWidget {
  const PreekApp({super.key, required this.store, required this.jobs});
  final SermonStore store;
  final JobQueue jobs;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (c) => L.of(c).appTitle,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: Shell(store: store, jobs: jobs),
  );
}

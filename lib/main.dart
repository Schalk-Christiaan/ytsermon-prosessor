import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;

import 'app/shell.dart';
import 'app/theme.dart';
import 'core/jobs.dart';
import 'core/paths.dart';
import 'core/settings.dart';
import 'core/storage.dart';
import 'core/store.dart';
import 'core/youtube.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final store = SermonStore(await workRoot())..load();
  final settings = AppSettings.load(store.root);
  const vault = FlutterSecureStorage();
  const key = 'youtube_refresh_token';
  final auth = GoogleAuth(
    File(settings.clientFile),
    read: () => vault.read(key: key),
    write: (v) =>
        v == null ? vault.delete(key: key) : vault.write(key: key, value: v),
  );
  final quota = UploadQuota(File(p.join(store.root.path, 'quota.json')));
  final jobs = JobQueue(
    store,
    upload: uploadJob(
      store,
      yt: YouTube(auth),
      settings: settings,
      quota: quota,
    ),
  )..start();
  runApp(
    PreekApp(
      store: store,
      jobs: jobs,
      settings: settings,
      auth: auth,
      quota: quota,
      storage: () => readStorage(store.root),
    ),
  );
}

class PreekApp extends StatelessWidget {
  const PreekApp({
    super.key,
    required this.store,
    required this.jobs,
    required this.settings,
    required this.auth,
    required this.quota,
    this.themeMode = ThemeMode.system,
    this.storage,
  });
  final Future<(int, int?)> Function()? storage;
  final SermonStore store;
  final JobQueue jobs;
  final AppSettings settings;
  final GoogleAuth auth;
  final UploadQuota quota;

  /// Test seam: the integration test runs the app in light and dark.
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) => MaterialApp(
    onGenerateTitle: (c) => L.of(c).appTitle,
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: themeMode,
    localizationsDelegates: const [
      L.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: L.supportedLocales,
    home: Shell(
      store: store,
      jobs: jobs,
      settings: settings,
      auth: auth,
      quota: quota,
      storage: storage,
    ),
  );
}

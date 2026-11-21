// @stelsel settings_screen
//   soort: skerm
//   wanneer: Instellings (rail)
//   groep: features | Skerms
//   skryf: <werkmap>/settings.json | kliëntlêer en privaatheid; refresh-token via GoogleAuth
//   doel: Kanaal (kliënt-ID-lêer, Koppel/Ontkoppel, privaatheid van oplaaie), uitsetgids, intro/outro (met lengte) en Opstelling, bo die Stelsel-lys
//   status: klaar
//   bewys: 7236634
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../app/theme.dart';
import '../../core/captions.dart';
import '../../core/cutter.dart';
import '../../core/jobs.dart';
import '../../core/settings.dart';
import '../../core/youtube.dart';
import '../../l10n/app_localizations.dart';

/// Instellings: channel, folders, intro/outro, description template and system status.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.auth,
    required this.signIn,
    required this.system,
    this.onSetup,
    this.pickVideo = pickVideoFile,
    this.probe = probeMedia,
  });
  final AppSettings settings;
  final GoogleAuth auth;

  /// Opens Google's consent page and waits for the account (test seam).
  final Future<void> Function() signIn;

  /// The Stelsel list below the channel group.
  final Widget system;

  /// Opens the Opstelling list again.
  final VoidCallback? onSetup;

  /// Test seams: the file picker and ffprobe (for the clip length).
  final Future<String?> Function() pickVideo;
  final Future<MediaInfo> Function(File f) probe;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

/// File dialog for one video; null when cancelled. Shared by intro/outro and "Voer opname in".
Future<String?> pickVideoFile() async => (await openFile(
  acceptedTypeGroups: const [
    XTypeGroup(
      label: 'Video',
      extensions: ['mp4', 'mov', 'mkv', 'avi', 'webm'],
    ),
  ],
))?.path;

class _SettingsScreenState extends State<SettingsScreen> {
  late final _file = TextEditingController(text: widget.settings.clientFile);
  late final _out = TextEditingController(text: widget.settings.outDir);
  bool? _signedIn;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _file.dispose();
    _out.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final v = await widget.auth.signedIn;
    if (mounted) setState(() => _signedIn = v);
  }

  void _setFile(String path) {
    widget.settings
      ..clientFile = path.trim()
      ..save();
    widget.auth.clientFile = File(path.trim());
    setState(() {});
  }

  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.signIn();
    } on Object catch (e) {
      _error = friendlyError(e);
    }
    _busy = false;
    await _refresh();
  }

  Future<void> _disconnect() async {
    await widget.auth.signOut();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final tokens = th.extension<AppTokens>()!;
    final configured = widget.auth.configured;
    final ok = configured && _signedIn == true;
    final status = !configured
        ? l.clientMissing
        : ok
        ? l.connected
        : l.notConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l.navSettingsTitle,
                          style: th.textTheme.headlineMedium,
                        ),
                      ),
                      if (widget.onSetup != null)
                        TextButton(
                          key: const ValueKey('ctl.instellings.setup'),
                          onPressed: widget.onSetup,
                          child: Text(l.navSetup),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(l.settingsChannel, style: th.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        ok
                            ? Icons.check_circle_rounded
                            : Icons.link_off_rounded,
                        color: ok ? tokens.success : th.colorScheme.outline,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(status, style: th.textTheme.titleMedium),
                      ),
                      if (ok)
                        TextButton(
                          key: const ValueKey('ctl.instellings.disconnect'),
                          onPressed: _disconnect,
                          child: Text(l.disconnect),
                        )
                      else
                        FilledButton(
                          key: const ValueKey('ctl.instellings.connect'),
                          onPressed: configured && !_busy ? _connect : null,
                          child: Text(l.connect),
                        ),
                    ],
                  ),
                  if (_busy) ...[
                    const SizedBox(height: 8),
                    Text(l.connectWaiting),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: th.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey('ctl.instellings.client-file'),
                    controller: _file,
                    decoration: InputDecoration(
                      labelText: l.clientFile,
                      helperText: l.clientFileHelp,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: _setFile,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(l.uploadPrivacy),
                      const SizedBox(width: 16),
                      SegmentedButton<String>(
                        key: const ValueKey('ctl.instellings.privacy'),
                        segments: [
                          ButtonSegment(
                            value: 'private',
                            label: Text(l.privacyPrivate),
                          ),
                          ButtonSegment(
                            value: 'unlisted',
                            label: Text(l.privacyUnlisted),
                          ),
                          ButtonSegment(
                            value: 'public',
                            label: Text(l.privacyPublic),
                          ),
                        ],
                        selected: {widget.settings.privacy},
                        onSelectionChanged: (v) => setState(
                          () => widget.settings
                            ..privacy = v.single
                            ..save(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    key: const ValueKey('ctl.instellings.out-dir'),
                    controller: _out,
                    decoration: InputDecoration(
                      labelText: l.outFolder,
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (v) => widget.settings
                      ..outDir = v.trim()
                      ..save(),
                  ),
                  const SizedBox(height: 24),
                  Text(l.introOutro, style: th.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(l.introOutroHelp, style: th.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  _clip(l, th, true),
                  _clip(l, th, false),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
        Expanded(flex: 2, child: widget.system),
      ],
    );
  }

  /// One intro/outro row: name, file and length (ffprobe), "Kies…" and remove.
  Widget _clip(L l, ThemeData th, bool intro) {
    final s = widget.settings;
    final path = intro ? s.intro : s.outro;
    void set(String? v) => setState(() {
      intro ? s.intro = v : s.outro = v;
      s.save();
    });
    return SizedBox(
      height: 56,
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              intro ? l.intro : l.outro,
              style: th.textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: path == null
                ? Text(l.noClip, style: th.textTheme.bodyMedium)
                : FutureBuilder<MediaInfo>(
                    key: ValueKey(path),
                    future: widget.probe(File(path)),
                    builder: (context, snap) => Text(
                      snap.hasError
                          ? l.clipUnreadable(p.basename(path))
                          : l.clipWithLength(
                              p.basename(path),
                              snap.hasData
                                  ? formatTime(snap.data!.duration)
                                  : '…',
                            ),
                      overflow: TextOverflow.ellipsis,
                      style: th.textTheme.bodyMedium?.copyWith(
                        color: snap.hasError ? th.colorScheme.error : null,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
          ),
          OutlinedButton(
            key: ValueKey(
              'ctl.instellings.choose-${intro ? 'intro' : 'outro'}',
            ),
            onPressed: () async {
              final v = await widget.pickVideo();
              if (v != null) set(v);
            },
            child: Text(l.chooseFile),
          ),
          if (path != null)
            IconButton(
              key: ValueKey(
                'ctl.instellings.remove-${intro ? 'intro' : 'outro'}',
              ),
              tooltip: l.remove,
              onPressed: () => set(null),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

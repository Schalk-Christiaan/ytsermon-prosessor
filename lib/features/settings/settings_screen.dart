// @stelsel settings_screen
//   soort: skerm
//   wanneer: Instellings (rail)
//   groep: features | Skerms
//   skryf: <werkmap>/settings.json | kliëntlêer en privaatheid; refresh-token via GoogleAuth
//   doel: Kanaal (kliënt-ID-lêer, Koppel/Ontkoppel, privaatheid van oplaaie) bo die Stelsel-lys
//   status: oop
import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/jobs.dart';
import '../../core/settings.dart';
import '../../core/youtube.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.settings,
    required this.auth,
    required this.signIn,
    required this.system,
  });
  final AppSettings settings;
  final GoogleAuth auth;

  /// Opens Google's consent page and waits for the account (test seam).
  final Future<void> Function() signIn;

  /// The Stelsel list below the channel group.
  final Widget system;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _file = TextEditingController(text: widget.settings.clientFile);
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
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.navSettingsTitle, style: th.textTheme.headlineMedium),
                const SizedBox(height: 24),
                Text(l.settingsChannel, style: th.textTheme.headlineSmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      ok ? Icons.check_circle_rounded : Icons.link_off_rounded,
                      color: ok ? tokens.success : th.colorScheme.outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(status, style: th.textTheme.titleMedium),
                    ),
                    if (ok)
                      TextButton(
                        onPressed: _disconnect,
                        child: Text(l.disconnect),
                      )
                    else
                      FilledButton(
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
                  Text(_error!, style: TextStyle(color: th.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                TextField(
                  key: const ValueKey('clientFile'),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        Expanded(child: widget.system),
      ],
    );
  }
}

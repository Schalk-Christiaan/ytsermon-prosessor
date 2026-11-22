// @stelsel setup_screen
//   soort: skerm
//   wanneer: eerste begin (setupDone vals); Instellings → Opstelling
//   groep: features | Skerms
//   skryf: <werkmap>/settings.json | setupDone; maak die uitsetgids
//   doel: Opstelling-lys: Ollama loop → model afgelaai → kanaal gekoppel (ChannelField) → uitsetgids, elk een knoppie; "Begin werk" as alles klaar is
//   status: bou
import 'dart:io';

import '../../app/job_progress.dart';

import '../../app/pixel_scenes.dart';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/channel.dart' show channelName;
import '../../core/jobs.dart';
import '../../core/settings.dart';
import '../../core/tools.dart' as tools;
import '../../core/tools.dart' show ToolStatus;
import '../../core/youtube.dart';
import '../../l10n/app_localizations.dart';
import '../settings/channel_field.dart';

/// Opstelling: four steps to green (Ollama, model, channel, folder), one button at a time.
class SetupScreen extends StatefulWidget {
  const SetupScreen({
    super.key,
    required this.settings,
    required this.auth,
    required this.signIn,
    required this.onSettings,
    required this.onDone,
    this.probe = tools.probeOllama,
    this.startOllama = tools.startOllama,
    this.pull = tools.pullModel,
    this.validateChannel = channelName,
  });
  final AppSettings settings;
  final GoogleAuth auth;
  final Future<void> Function() signIn;
  final VoidCallback onSettings, onDone;
  final Future<ToolStatus> Function() probe;
  final Future<void> Function() startOllama;
  final Future<void> Function({required void Function(double) onProgress}) pull;

  /// Test seam: the yt-dlp check of the channel field.
  final Future<String> Function(String url) validateChannel;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  ToolStatus? _ollama;
  bool _signedIn = false;
  String? _busy; // which step is running
  double? _pull;
  String? _error;

  @override
  void initState() {
    super.initState();
    _check();
  }

  // stap: v6 2 Kontroleer | kyk wat klaar is: Ollama, model, kanaal, uitsetgids
  Future<void> _check() async {
    final o = await widget.probe();
    final s = await widget.auth.signedIn;
    if (mounted) {
      setState(() {
        _ollama = o;
        _signedIn = s;
      });
    }
  }

  // stap: v6 3 Een knoppie op 'n slag | Begin Ollama → Laai model af → Koppel kanaal → Maak gids
  // tak: geen kliënt-ID-lêer → "Gaan na Instellings"
  Future<void> _run(String step, Future<void> Function() f) async {
    setState(() {
      _busy = step;
      _error = null;
    });
    try {
      await f();
    } on Object catch (e) {
      _error = friendlyError(e);
    }
    _busy = null;
    _pull = null;
    await _check();
  }

  // stap: v6 4 Begin werk | aktief as alles groen is; gaan na Preke en verskyn nie weer nie
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final o = _ollama;
    final running = o != null && !o.notRunning && o.detail != 'missing';
    final model = o?.ok ?? false;
    final client = widget.auth.configured;
    final channel = client && _signedIn;
    final folder = Directory(widget.settings.outDir).existsSync();
    final all = running && model && channel && folder;
    // Only the first open step's button is filled: one primary action at a time.
    final first = [running, model, channel, folder].indexOf(false) + 1;
    Widget btn(int n, String label, VoidCallback? onPressed) => n == first
        ? FilledButton(
            key: ValueKey('ctl.opstelling.step-$n'),
            onPressed: onPressed,
            child: Text(label),
          )
        : OutlinedButton(
            key: ValueKey('ctl.opstelling.step-$n'),
            onPressed: onPressed,
            child: Text(label),
          );
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            restScene(),
            const SizedBox(height: 8),
            Text(l.navSetup, style: th.textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(l.setupIntro, style: th.textTheme.bodyLarge),
            const SizedBox(height: 24),
            ChannelField(
              settings: widget.settings,
              screen: 'opstelling',
              validate: widget.validateChannel,
            ),
            const SizedBox(height: 16),
            _step(
              th,
              l,
              1,
              l.setupOllama,
              running,
              action: btn(
                1,
                l.startOllama,
                _busy == null ? () => _run('ollama', widget.startOllama) : null,
              ),
            ),
            _step(
              th,
              l,
              2,
              l.setupModel,
              model,
              action: btn(
                2,
                l.downloadModel,
                running && _busy == null
                    ? () => _run(
                        'model',
                        () => widget.pull(
                          onProgress: (v) => setState(() => _pull = v),
                        ),
                      )
                    : null,
              ),
              below: _busy == 'model'
                  ? Row(
                      children: [
                        Expanded(child: ProgressLine(value: _pull)),
                        const SizedBox(width: 16),
                        Text(
                          _pull == null
                              ? ''
                              : l.percent((_pull! * 100).round()),
                          style: th.textTheme.labelMedium?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            _step(
              th,
              l,
              3,
              l.setupChannel,
              channel,
              action: client
                  ? btn(
                      3,
                      l.connect,
                      _busy == null
                          ? () => _run('channel', widget.signIn)
                          : null,
                    )
                  : btn(3, l.goSettings, widget.onSettings),
              below: client ? null : Text(l.clientFirst),
            ),
            _step(
              th,
              l,
              4,
              l.setupFolder(widget.settings.outDir),
              folder,
              action: btn(
                4,
                l.makeFolder,
                () => _run(
                  'folder',
                  () async =>
                      Directory(widget.settings.outDir)
                          .createSync(recursive: true),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: th.colorScheme.error)),
            ],
            const SizedBox(height: 32),
            Row(
              children: [
                FilledButton(
                  key: const ValueKey('ctl.opstelling.begin'),
                  onPressed: all
                      ? () {
                          widget.settings
                            ..setupDone = true
                            ..save();
                          widget.onDone();
                        }
                      : null,
                  child: Text(l.startWork),
                ),
                const SizedBox(width: 16),
                TextButton(
                  key: const ValueKey('ctl.opstelling.check'),
                  onPressed: _busy == null ? _check : null,
                  child: Text(l.checkAgain),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// One numbered line: state (icon + word), what it is, and its one button while not done.
  Widget _step(
    ThemeData th,
    L l,
    int n,
    String text,
    bool done, {
    required Widget action,
    Widget? below,
  }) {
    final ok = th.extension<AppTokens>()!.success;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Text('$n', style: th.textTheme.titleLarge),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: th.textTheme.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      done
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 18,
                      color: done ? ok : th.colorScheme.outline,
                    ),
                    const SizedBox(width: 6),
                    Text(done ? l.stepDone : l.stepTodo),
                  ],
                ),
                if (below != null) ...[const SizedBox(height: 8), below],
              ],
            ),
          ),
          if (!done) action,
        ],
      ),
    );
  }
}

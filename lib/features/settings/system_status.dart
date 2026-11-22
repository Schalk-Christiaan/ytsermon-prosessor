// @stelsel system_status
//   soort: skerm
//   wanneer: Instellings → Stelsel
//   groep: features | Skerms
//   skryf: —
//   doel: wys yt-dlp/ffmpeg/ffprobe/Ollama en die video-enkodeerder (GPU/CPU) en die spraakmodel met ikoon + woord (Gereed / Ontbreek); "Laai spraakmodel af"; "Werk yt-dlp by"
//   status: bou
import '../../app/motion.dart';

import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/jobs.dart';
import '../../core/tools.dart';
import '../../l10n/app_localizations.dart';

/// Test seam: a test swaps this so no real `yt-dlp -U` runs.
@visibleForTesting
Future<String> Function() ytDlpUpdater = updateYtDlp;

/// Runs `yt-dlp -U` and reports the result (or the failure) as a SnackBar.
Future<void> updateYtDlpSnack(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  final l = L.of(context);
  try {
    m.showSnackBar(
      SnackBar(content: Text(l.updateYtDlpDone(await ytDlpUpdater()))),
    );
  } on Object catch (e) {
    m.showSnackBar(SnackBar(content: Text(l.errorGeneric(friendlyError(e)))));
  }
}

/// Shows yt-dlp, ffmpeg, ffprobe and Ollama as green or red; sized to its content so the page above scrolls as one.
class SystemStatus extends StatefulWidget {
  const SystemStatus({
    super.key,
    this.probe = probeAll,
    this.model,
    this.pullModel = pullWhisperModel,
  });

  /// The whisper model file; null hides its row. [pullModel] is the test seam for its download.
  final File? model;
  final Future<void> Function(
    File dest, {
    required void Function(double) onProgress,
  })
  pullModel;

  /// Test seam: the real probes run processes, which a widget test cannot await.
  final Future<List<ToolStatus>> Function() probe;

  @override
  State<SystemStatus> createState() => _SystemStatusState();
}

class _SystemStatusState extends State<SystemStatus> {
  late final Future<List<ToolStatus>> _f = widget.probe();
  double? _pull; // 0..1 while the model downloads
  String? _pullError;

  /// "Laai spraakmodel af": the model download with progress, like Ollama's pull.
  Future<void> _download(L l) async {
    setState(() {
      _pull = 0;
      _pullError = null;
    });
    try {
      await widget.pullModel(
        widget.model!,
        onProgress: (v) {
          if (mounted) setState(() => _pull = v);
        },
      );
    } on Object {
      _pullError = l.whisperDownloadFailed;
    }
    if (mounted) setState(() => _pull = null);
  }

  Widget _modelRow(L l, ThemeData th) {
    final has = widget.model!.existsSync();
    final pulling = _pull != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            has ? Icons.check_circle_rounded : Icons.error_rounded,
            color: has
                ? th.extension<AppTokens>()!.success
                : th.colorScheme.error,
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 160,
            child: Text(l.whisperLabel, style: th.textTheme.titleMedium),
          ),
          Expanded(
            child: Text(has ? l.whisperReady : _pullError ?? l.whisperMissing),
          ),
          if (!has) ...[
            const SizedBox(width: 16),
            OutlinedButton(
              key: const ValueKey('ctl.instellings.whisper-model'),
              onPressed: pulling ? null : () => _download(l),
              child: Text(
                pulling
                    ? l.whisperDownloading((_pull! * 100).round())
                    : l.whisperDownload,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _text(L l, ToolStatus s) {
    if (s.name == 'encoder') {
      return s.detail == 'h264_nvenc' ? l.encoderGpu : l.encoderCpu;
    }
    if (s.ok) return l.toolReadyVersion(s.detail);
    if (s.notRunning) return l.ollamaNotRunning;
    if (s.missingModel != null) return l.modelMissing(s.missingModel!);
    return l.toolMissing(s.name);
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsSystem, style: th.textTheme.headlineSmall),
          const SizedBox(height: 16),
          FutureBuilder<List<ToolStatus>>(
            future: _f,
            builder: (c, snap) => Column(
              children: [
                for (final s in snap.data ?? const <ToolStatus>[])
                  SizedBox(
                    height: 56,
                    child: Row(
                      children: [
                        PopIn(
                          key: ValueKey(s.ok),
                          child: Icon(
                            s.ok
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: s.ok
                                ? th.extension<AppTokens>()!.success
                                : th.colorScheme.error,
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 160,
                          child: Text(
                            s.name == 'encoder' ? l.encoderLabel : s.name,
                            style: th.textTheme.titleMedium,
                          ),
                        ),
                        Expanded(child: Text(_text(l, s))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          if (widget.model != null) _modelRow(l, th),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('ctl.instellings.update-ytdlp'),
            onPressed: () => updateYtDlpSnack(context),
            child: Text(l.updateYtDlp),
          ),
        ],
      ),
    );
  }
}

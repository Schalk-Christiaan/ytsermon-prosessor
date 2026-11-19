// @stelsel system_status
//   soort: skerm
//   wanneer: Instellings → Stelsel
//   groep: features | Skerms
//   skryf: —
//   doel: wys yt-dlp/ffmpeg/ffprobe/Ollama met ikoon + woord (Gereed / Ontbreek); "Werk yt-dlp by"
//   status: oop
import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/jobs.dart';
import '../../core/tools.dart';
import '../../l10n/app_localizations.dart';

/// Runs `yt-dlp -U` and reports the result (or the failure) as a SnackBar.
Future<void> updateYtDlpSnack(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  final l = L.of(context);
  try {
    m.showSnackBar(
      SnackBar(content: Text(l.updateYtDlpDone(await updateYtDlp()))),
    );
  } on Object catch (e) {
    m.showSnackBar(SnackBar(content: Text(l.errorGeneric(friendlyError(e)))));
  }
}

class SystemStatus extends StatefulWidget {
  const SystemStatus({super.key});

  @override
  State<SystemStatus> createState() => _SystemStatusState();
}

class _SystemStatusState extends State<SystemStatus> {
  late final Future<List<ToolStatus>> _f = probeAll();

  String _text(L l, ToolStatus s) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.settingsSystem, style: th.textTheme.headlineSmall),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<List<ToolStatus>>(
              future: _f,
              builder: (c, snap) => ListView(
                children: [
                  for (final s in snap.data ?? const <ToolStatus>[])
                    SizedBox(
                      height: 56,
                      child: Row(
                        children: [
                          Icon(
                            s.ok
                                ? Icons.check_circle_rounded
                                : Icons.error_rounded,
                            color: s.ok
                                ? th.extension<AppTokens>()!.success
                                : th.colorScheme.error,
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: 120,
                            child: Text(
                              s.name,
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
          ),
          OutlinedButton(
            onPressed: () => updateYtDlpSnack(context),
            child: Text(l.updateYtDlp),
          ),
        ],
      ),
    );
  }
}

// @stelsel transcript
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: —
//   doel: transkripsiestrook: onderskrifreëls met tyd, klik soek daarheen, gebede gemerk, huidige reël uitgelig; kop met "Plaaslike transkripsie"-merk en "Transkribeer plaaslik"; leeg = stel self
//   status: bou
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/captions.dart';
import '../../core/models.dart';
import '../../l10n/app_localizations.dart';

/// The caption transcript strip; a click seeks the video to that line.
class Transcript extends StatelessWidget {
  const Transcript({
    super.key,
    required this.segments,
    required this.prayers,
    required this.position,
    required this.onSeek,
    this.local = false,
    this.progress,
    this.onTranscribeLocal,
  });

  /// The strip is whisper's transcript (badge); [progress] is 0..1 while it runs; [onTranscribeLocal] null hides the button.
  final bool local;
  final double? progress;
  final VoidCallback? onTranscribeLocal;

  final List<Segment> segments;
  final List<Span> prayers;
  final ValueListenable<double> position;
  final ValueChanged<double> onSeek;

  // stap: v4 2 Soek in die transkripsie | klik die gebed se reël; die video spring daarheen
  // stap: v3 3 Stel self | geen onderskrifte nie: die strook sê so; stel begin en einde met I/O by die speelkop
  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    final head = _header(l, th);
    final body = _body(context, l, th);
    if (head == null) return body;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        head,
        Expanded(child: body),
      ],
    );
  }

  Widget? _header(L l, ThemeData th) {
    if (!local && onTranscribeLocal == null) return null;
    final running = progress != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: [
          if (local)
            Text(
              l.transcriptLocalBadge,
              style: th.textTheme.labelLarge?.copyWith(
                color: th.colorScheme.primary,
              ),
            ),
          if (onTranscribeLocal != null)
            TextButton(
              key: const ValueKey('ctl.hersien.transcribe-local'),
              onPressed: running ? null : onTranscribeLocal,
              child: Text(
                running
                    ? l.transcribeLocalRunning((progress! * 100).round())
                    : l.transcribeLocal,
              ),
            ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context, L l, ThemeData th) {
    if (segments.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            l.noCaptions,
            textAlign: TextAlign.center,
            style: th.textTheme.bodyMedium,
          ),
        ),
      );
    }
    final time = th.textTheme.labelMedium!.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    bool inPrayer(int i) =>
        i >= 0 &&
        prayers.any(
          (p) => segments[i].start >= p.start && segments[i].start < p.end,
        );
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, pos, _) => ListView.builder(
        itemCount: segments.length,
        itemBuilder: (context, i) {
          final s = segments[i];
          final prayer = inPrayer(i);
          final now = pos >= s.start && pos < s.end;
          return InkWell(
            key: ValueKey('ctl.hersien.transcript-line.${s.start}'),
            onTap: () => onSeek(s.start),
            child: Container(
              color: now ? th.colorScheme.secondaryContainer : null,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(formatTime(s.start), style: time),
                  ),
                  Expanded(
                    child: Text(
                      prayer && !inPrayer(i - 1)
                          ? '${l.prayer}: ${s.text}'
                          : s.text,
                      style: th.textTheme.bodyMedium?.copyWith(
                        fontStyle: prayer ? FontStyle.italic : null,
                        color: now ? th.colorScheme.onSecondaryContainer : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

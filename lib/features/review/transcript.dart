// @stelsel transcript
//   soort: module
//   wanneer: Hersien-skerm
//   groep: features | Skerms
//   skryf: —
//   doel: transkripsiestrook: onderskrifreëls met tyd, klik soek daarheen, gebede gemerk, huidige reël uitgelig; leeg = stel self
//   status: klaar
//   bewys: 7236634
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
  });

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

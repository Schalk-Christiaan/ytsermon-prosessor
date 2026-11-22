// @stelsel transport_bar
//   soort: module
//   wanneer: Hersien-skerm (onder die voorskou)
//   groep: features | Skerms
//   skryf: —
//   doel: vervoerbalk (speel/pouse, tyd, na die hakies, 5 s terug/vorentoe, klankvolume met demp, zoem met syferveld) en gereedskapbalk (I/O, knip uit, Short by, voorskou van die snit)
//   status: klaar
//   bewys: 7236634
import 'package:flutter/material.dart';

import '../../core/captions.dart';
import '../../l10n/app_localizations.dart';
import 'review_controller.dart';
import 'slider_field.dart';

/// Play/pause, the time, jumps and the timeline zoom.
class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.c,
    required this.zoom,
    required this.onZoom,
  });
  final ReviewController c;
  final double zoom;
  final ValueChanged<double> onZoom;

  void _by(double d) => c.seek((c.position.value + d).clamp(0, c.duration));

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: const ValueKey('ctl.hersien.play-pause'),
          tooltip: l.playPause,
          onPressed: c.playPause,
          icon: const Icon(Icons.play_arrow_rounded),
        ),
        ValueListenableBuilder<double>(
          valueListenable: c.position,
          builder: (context, v, _) => Text(
            '${formatTime(v)} / ${formatTime(c.duration)}',
            style: th.textTheme.labelLarge?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey('ctl.hersien.play-from-start'),
          tooltip: l.playFromStart,
          onPressed: () => c.playFrom(true),
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.back5'),
          tooltip: l.seekBack5,
          onPressed: () => _by(-5),
          icon: const Icon(Icons.replay_5_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.forward5'),
          tooltip: l.seekForward5,
          onPressed: () => _by(5),
          icon: const Icon(Icons.forward_5_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.play-end'),
          tooltip: l.playEnd,
          onPressed: () => c.playFrom(false),
          icon: const Icon(Icons.skip_next_rounded),
        ),
        const SizedBox(width: 8),
        ValueListenableBuilder<double>(
          valueListenable: c.volume,
          builder: (context, v, _) => Row(
            children: [
              IconButton(
                key: const ValueKey('ctl.hersien.mute'),
                tooltip: l.volume,
                onPressed: c.toggleMute,
                icon: Icon(
                  v == 0 ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                ),
              ),
              SizedBox(
                width: 100,
                child: Slider(
                  key: const ValueKey('ctl.hersien.volume'),
                  value: v,
                  min: 0,
                  max: 100,
                  divisions: 20,
                  semanticFormatterCallback: (v) => '${v.round()} %',
                  onChanged: c.setVolume,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        const Icon(Icons.zoom_in_rounded, size: 20),
        SizedBox(
          width: 240,
          child: SliderField(
            id: 'zoom',
            label: l.zoomField,
            showLabel: false,
            fieldWidth: 56,
            value: zoom,
            min: 1,
            max: 16,
            format: (v) => v == v.roundToDouble()
                ? v.round().toString()
                : v.toStringAsFixed(1),
            parse: parseClock,
            onChanged: onZoom,
          ),
        ),
      ],
    );
  }
}

/// The tools that act at the playhead: sermon ends, a cut, a Short, and the preview of the cut.
class ToolBar extends StatelessWidget {
  const ToolBar({super.key, required this.c, this.showHint = true});
  final ReviewController c;

  /// The key-shortcut hint; dropped in the narrow layout (tooltips carry the same words).
  final bool showHint;

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return Row(
      children: [
        IconButton(
          key: const ValueKey('ctl.hersien.mark-in'),
          tooltip: l.markIn,
          onPressed: c.markIn,
          icon: const Icon(Icons.first_page_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.mark-out'),
          tooltip: l.markOut,
          onPressed: c.markOut,
          icon: const Icon(Icons.last_page_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.add-cut'),
          tooltip: l.addCut,
          onPressed: c.addCut,
          icon: const Icon(Icons.content_cut_rounded),
        ),
        IconButton(
          key: const ValueKey('ctl.hersien.add-short'),
          tooltip: l.addShort,
          onPressed: () => c.addShort(l.newShortTitle),
          icon: const Icon(Icons.smartphone_rounded),
        ),
        TextButton.icon(
          key: const ValueKey('ctl.hersien.preview-cut'),
          onPressed: c.previewCut,
          icon: Icon(
            c.previewing ? Icons.check_rounded : Icons.slideshow_rounded,
          ),
          label: Text(l.previewCut),
        ),
        if (showHint) const SizedBox(width: 12),
        if (showHint)
          Flexible(
            child: Text(
              l.editorKeys,
              textAlign: TextAlign.end,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: th.textTheme.labelMedium,
            ),
          ),
      ],
    );
  }
}

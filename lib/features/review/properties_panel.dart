// @stelsel properties_panel
//   soort: module
//   wanneer: Hersien-skerm (regs; onder 1280 breed in 'n laai)
//   groep: features | Skerms
//   skryf: <werkmap>/<id>/plan.json (via die beheerder), instellings.json (uitvoere)
//   doel: eienskappe in oortjies (Preek, Shorts, Uitgeknip, Uitvoer, Transkripsie): titel, beskrywing, elke slider met 'n syferveld, uitvoere en Herstel na die KI-voorstel
//   status: bou
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/captions.dart';
import '../../core/models.dart';
import '../../core/planner.dart';
import '../../core/settings.dart';
import '../../l10n/app_localizations.dart';
import 'review_controller.dart';
import 'slider_field.dart';
import 'transcript.dart';

enum _Tab { sermon, shorts, cuts, output, transcript }

/// The properties of the open plan, one tab at a time; every slider has its number field.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({super.key, required this.c, required this.settings});
  final ReviewController c;
  final AppSettings settings;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel> {
  late final c = widget.c;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  (int, int)? _synced;
  _Tab _tab = _Tab.sermon;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  void _syncFields() {
    if (c.state == ReviewState.ready && _synced != (c.planRevision, c.edits)) {
      _synced = (c.planRevision, c.edits);
      _title.text = c.plan!.title;
      _desc.text = c.plan!.description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final th = Theme.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        _syncFields();
        final plan = c.plan;
        if (plan == null) return const SizedBox.shrink();
        final names = {
          _Tab.sermon: l.tabSermon,
          _Tab.shorts: l.shortsTab(plan.shorts.length),
          _Tab.cuts: l.cutsTab(plan.cuts.length),
          _Tab.output: l.tabOutput,
          _Tab.transcript: l.transcript,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final t in _Tab.values)
                  ChoiceChip(
                    key: ValueKey('ctl.hersien.tab-${t.name}'),
                    label: Text(names[t]!),
                    selected: _tab == t,
                    onSelected: (_) => setState(() => _tab = t),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_tab) {
                _Tab.sermon => _sermon(l, th, plan),
                _Tab.shorts => _shorts(l, th, plan),
                _Tab.cuts => _cuts(l, th, plan),
                _Tab.output => _output(l, th),
                _Tab.transcript => DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: th.colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Transcript(
                    segments: c.segments,
                    prayers: c.prayerMarks,
                    position: c.position,
                    onSeek: c.seek,
                  ),
                ),
              },
            ),
            const Divider(),
            Row(
              children: [
                if (c.saved) ...[
                  Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: th.colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(l.saved, style: th.textTheme.labelMedium),
                ],
                const Spacer(),
                OutlinedButton(
                  key: const ValueKey('ctl.hersien.reset'),
                  onPressed: c.canReset ? c.resetToProposal : null,
                  child: Text(l.resetProposal),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // stap: v8 1 Maak reg | open die opgelaaide preek in Hersien en wysig titel of beskrywing
  Widget _sermon(L l, ThemeData th, SermonPlan plan) => ListView(
    children: [
      TextField(
        key: const ValueKey('ctl.hersien.title'),
        controller: _title,
        minLines: 1,
        maxLines: 2,
        maxLength: 100,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        buildCounter:
            (c, {required currentLength, required isFocused, maxLength}) =>
                isFocused
                ? Text(
                    l.counter(currentLength, maxLength ?? 100),
                    style: th.textTheme.labelMedium,
                  )
                : null,
        style: th.textTheme.titleLarge,
        decoration: InputDecoration(
          labelText: l.title,
          border: const OutlineInputBorder(),
        ),
        onChanged: c.setTitle,
      ),
      const SizedBox(height: 12),
      SizedBox(
        height: 96,
        child: TextField(
          key: const ValueKey('ctl.hersien.description'),
          controller: _desc,
          maxLength: 5000,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          buildCounter:
              (c, {required currentLength, required isFocused, maxLength}) =>
                  isFocused
                  ? Text(
                      l.counter(currentLength, maxLength ?? 5000),
                      style: th.textTheme.labelMedium,
                    )
                  : null,
          decoration: InputDecoration(
            labelText: l.description,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: c.setDescription,
        ),
      ),
      const SizedBox(height: 12),
      SliderField(
        id: 'sermon-start',
        label: l.sermonBegin,
        value: plan.sermonStart,
        min: 0,
        max: plan.sermonEnd - 1,
        format: formatTime,
        parse: parseClock,
        onChanged: (v) {
          c.setSermon(v, plan.sermonEnd, save: false);
          c.seek(v);
        },
        onCommit: c.commit,
      ),
      SliderField(
        id: 'sermon-end',
        label: l.sermonEndLabel,
        value: plan.sermonEnd,
        min: plan.sermonStart + 1,
        max: c.duration,
        format: formatTime,
        parse: parseClock,
        onChanged: (v) {
          c.setSermon(plan.sermonStart, v, save: false);
          c.seek(v);
        },
        onCommit: c.commit,
      ),
      ValueListenableBuilder<double>(
        valueListenable: c.volume,
        builder: (context, v, _) => SliderField(
          id: 'volume',
          label: l.volume,
          value: v,
          min: 0,
          max: 100,
          fieldWidth: 64,
          format: (x) => x.round().toString(),
          parse: parseClock,
          onChanged: c.setVolume,
        ),
      ),
    ],
  );

  Widget _shorts(L l, ThemeData th, SermonPlan plan) {
    if (plan.shorts.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(l.noShorts, style: th.textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      itemCount: plan.shorts.length,
      separatorBuilder: (_, _) => const Divider(height: 24),
      itemBuilder: (context, i) {
        final s = plan.shorts[i];
        final secs = (s.end - s.start).round();
        final reason = switch (shortFault(s, plan)) {
          ShortFault.tooLong => l.shortTooLong(secs),
          ShortFault.tooShort => l.shortTooShort(secs),
          ShortFault.outside => l.shortOutside,
          null => null,
        };
        final err = th.colorScheme.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 27,
                  height: 44,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: reason == null ? th.colorScheme.tertiary : err,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    (i + 1).toString(),
                    style: th.textTheme.labelMedium,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    key: ValueKey(
                      'ctl.hersien.short-title.$i.${c.planRevision}.${c.edits}',
                    ),
                    initialValue: s.title,
                    style: th.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: l.shortLength(i + 1),
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => c.setShortTitle(s, v),
                  ),
                ),
                IconButton(
                  key: const ValueKey('ctl.hersien.short-remove'),
                  tooltip: l.remove,
                  onPressed: () => c.removeShort(s),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            SliderField(
              id: 'short-begin',
              label: l.shortBegin,
              value: s.start,
              min: plan.sermonStart,
              max: (plan.sermonEnd - (s.end - s.start)).clamp(
                plan.sermonStart + 1,
                plan.sermonEnd,
              ),
              format: formatTime,
              parse: parseClock,
              onChanged: (v) => c.moveShort(s, v - s.start, save: false),
              onCommit: c.commit,
            ),
            SliderField(
              id: 'short-length',
              label: l.shortSeconds,
              value: secs.toDouble(),
              min: 20,
              max: secs > 120 ? secs.toDouble() : 120,
              fieldWidth: 64,
              format: (v) => v.round().toString(),
              parse: parseClock,
              onChanged: (v) => c.setShortEnd(s, s.start + v, save: false),
              onCommit: c.commit,
            ),
            if (reason != null)
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: err),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(reason, style: TextStyle(color: err)),
                  ),
                ],
              ),
            Wrap(
              children: [
                TextButton(
                  key: const ValueKey('ctl.hersien.short-start'),
                  onPressed: () => c.setShortStart(s),
                  child: Text(l.startHere),
                ),
                TextButton(
                  key: const ValueKey('ctl.hersien.short-play'),
                  onPressed: () {
                    c.seek(s.start);
                    c.playPause();
                  },
                  child: Text(l.play),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _cuts(L l, ThemeData th, SermonPlan plan) {
    if (plan.cuts.isEmpty) {
      return Align(
        alignment: Alignment.topLeft,
        child: Text(l.noCuts, style: th.textTheme.bodyMedium),
      );
    }
    return ListView.separated(
      itemCount: plan.cuts.length,
      separatorBuilder: (_, _) => const Divider(height: 16),
      itemBuilder: (context, i) {
        final cut = plan.cuts[i];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(l.cutN(i + 1), style: th.textTheme.titleSmall),
                ),
                Text(
                  l.shortRange(formatTime(cut.start), formatTime(cut.end)),
                  style: th.textTheme.bodyMedium?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  key: const ValueKey('ctl.hersien.cut-remove'),
                  tooltip: l.remove,
                  onPressed: () => c.removeCut(cut),
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
            Wrap(
              children: [
                TextButton(
                  key: const ValueKey('ctl.hersien.cut-start'),
                  onPressed: () => c.setCutStart(cut),
                  child: Text(l.startHere),
                ),
                TextButton(
                  key: const ValueKey('ctl.hersien.cut-end'),
                  onPressed: () => c.setCutEnd(cut),
                  child: Text(l.endHere),
                ),
                TextButton(
                  key: const ValueKey('ctl.hersien.cut-play'),
                  onPressed: () => c.seek(cut.start - 3),
                  child: Text(l.play),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  // stap: diensindeling 7 Kies die uitvoere | drie merkblokkies (almal aan, onthou in Instellings), Oggend/Aand en die soort diens; die sny gebruik dit
  /// The outputs the cut makes and the service's day part and kind.
  Widget _output(L l, ThemeData th) {
    final names = {'full': l.outFull, 'word': l.outWord, 'songs': l.outSongs};
    final kinds = {
      null: l.serviceKindNone,
      'nagmaal': l.serviceKindNagmaal,
      'doop': l.serviceKindDoop,
      'kategismus': l.serviceKindKategismus,
      'belydenis': l.serviceKindBelydenis,
      'feesdag': l.serviceKindFeesdag,
    };
    final s = widget.settings;
    return ListView(
      children: [
        Text(l.outputsLabel, style: th.textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final e in names.entries)
              FilterChip(
                key: ValueKey('ctl.hersien.out-${e.key}'),
                label: Text(e.value),
                selected: s.exports.contains(e.key),
                onSelected: (on) => setState(() {
                  on ? s.exports.add(e.key) : s.exports.remove(e.key);
                  s.save();
                }),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l.serviceDayLabel, style: th.textTheme.labelLarge),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: SegmentedButton<bool>(
            key: const ValueKey('ctl.hersien.service-day'),
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: false, label: Text(l.serviceMorning)),
              ButtonSegment(value: true, label: Text(l.serviceEvening)),
            ],
            selected: {c.service.evening},
            onSelectionChanged: (v) => c.setEvening(v.single),
          ),
        ),
        const SizedBox(height: 8),
        DropdownButton<String?>(
          key: const ValueKey('ctl.hersien.service-kind'),
          isExpanded: true,
          value: kinds.containsKey(c.service.label) ? c.service.label : null,
          items: [
            for (final e in kinds.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: c.setServiceKind,
          hint: Text(l.serviceKind),
        ),
      ],
    );
  }
}

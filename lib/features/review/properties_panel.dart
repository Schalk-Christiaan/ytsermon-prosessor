// @stelsel properties_panel
//   soort: module
//   wanneer: Hersien-skerm (regs; onder 1280 breed in 'n laai)
//   groep: features | Skerms
//   skryf: <werkmap>/<id>/plan.json (via die beheerder), instellings.json (uitvoere)
//   doel: twee oortjies (Inligting, Transkripsie); Inligting wys titel, beskrywing, uitvoere en die Shorts- en snitlyste, of net die Short/snit wat in die diensbaan gekies is (slider met syferveld); Herstel na die KI-voorstel
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

/// The properties of the open plan, one tab at a time; every slider has its number field.
class PropertiesPanel extends StatefulWidget {
  const PropertiesPanel({super.key, required this.c, required this.settings});
  final ReviewController c;
  final AppSettings settings;

  @override
  State<PropertiesPanel> createState() => _PropertiesPanelState();
}

class _PropertiesPanelState extends State<PropertiesPanel>
    with SingleTickerProviderStateMixin {
  late final c = widget.c;
  final _title = TextEditingController();
  final _desc = TextEditingController();
  (int, int)? _synced;
  late final _tabs = TabController(length: 2, vsync: this);
  Object? _seenSelection;

  @override
  void initState() {
    super.initState();
    c.addListener(_follow);
  }

  /// Picking a Short or cut while Transkripsie is open jumps to Inligting.
  void _follow() {
    if (c.selected != null &&
        c.selected != _seenSelection &&
        _tabs.index != 0) {
      _tabs.animateTo(0);
    }
    _seenSelection = c.selected;
  }

  @override
  void dispose() {
    c.removeListener(_follow);
    _tabs.dispose();
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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              controller: _tabs,
              tabs: [
                Tab(
                  key: const ValueKey('ctl.hersien.tab-info'),
                  text: l.infoTab,
                ),
                Tab(
                  key: const ValueKey('ctl.hersien.tab-transcript'),
                  text: l.transcript,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListenableBuilder(
                listenable: _tabs,
                builder: (context, _) => _tabs.index == 1
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: th.colorScheme.outlineVariant,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Transcript(
                          segments: c.segments,
                          prayers: c.prayerMarks,
                          position: c.position,
                          onSeek: c.seek,
                        ),
                      )
                    : _info(l, th, plan),
              ),
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

  /// Inligting: the overview with nothing selected, else the one selected Short or cut.
  Widget _info(L l, ThemeData th, SermonPlan plan) {
    final sel = c.selected;
    final si = sel is Short ? plan.shorts.indexOf(sel) : -1;
    final ci = sel is Span ? plan.cuts.indexOf(sel) : -1;
    if (si >= 0 || ci >= 0) {
      final short = si >= 0;
      final n = short ? si + 1 : ci + 1;
      final total = short ? plan.shorts.length : plan.cuts.length;
      return ListView(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('ctl.hersien.select-back'),
              onPressed: c.clearSelection,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text(l.infoTab),
            ),
          ),
          Text(
            short ? l.shortOf(n, total) : l.cutOf(n, total),
            style: th.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          short ? _shortItem(l, th, plan, si) : _cutItem(l, th, plan, ci),
        ],
      );
    }
    Widget heading(String t) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(t, style: th.textTheme.titleSmall),
    );
    final tab = th.textTheme.bodyMedium?.copyWith(
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ListView(
      children: [
        ..._sermon(l, th, plan),
        const SizedBox(height: 16),
        ..._output(l, th),
        heading(l.shortsTab(plan.shorts.length)),
        if (plan.shorts.isEmpty)
          Text(l.noShorts, style: th.textTheme.bodyMedium),
        for (final (i, s) in plan.shorts.indexed)
          InkWell(
            key: ValueKey('ctl.hersien.select-short.$i'),
            onTap: () => c.selectShort(s),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.shortRow(
                        i + 1,
                        formatTime(s.start),
                        (s.end - s.start).round(),
                      ),
                      style: tab,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
        heading(l.cutsTab(plan.cuts.length)),
        if (plan.cuts.isEmpty) Text(l.noCuts, style: th.textTheme.bodyMedium),
        for (final (i, cut) in plan.cuts.indexed)
          InkWell(
            key: ValueKey('ctl.hersien.select-cut.$i'),
            onTap: () => c.selectCut(cut),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${l.cutN(i + 1)} · ${l.shortRange(formatTime(cut.start), formatTime(cut.end))}',
                      style: tab,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // stap: v8 1 Maak reg | open die opgelaaide preek in Hersien en wysig titel of beskrywing
  List<Widget> _sermon(L l, ThemeData th, SermonPlan plan) => [
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
  ];

  Widget _shortItem(L l, ThemeData th, SermonPlan plan, int i) {
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
              child: Text((i + 1).toString(), style: th.textTheme.labelMedium),
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
  }

  Widget _cutItem(L l, ThemeData th, SermonPlan plan, int i) {
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
  }

  // stap: diensindeling 7 Kies die uitvoere | drie merkblokkies (almal aan, onthou in Instellings), Oggend/Aand en die soort diens; die sny gebruik dit
  /// The outputs the cut makes and the service's day part and kind.
  List<Widget> _output(L l, ThemeData th) {
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
    return [
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
    ];
  }
}

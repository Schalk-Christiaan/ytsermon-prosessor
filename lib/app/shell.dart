// @stelsel shell
//   soort: skerm
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: NavigationRail: Preke (tuis), Hersien, Werk, Instellings; Snitlyste af tot fase 3
//   status: oop
import 'package:flutter/material.dart';

import '../core/channel.dart';
import '../core/jobs.dart';
import '../core/store.dart';
import '../features/review/review_controller.dart';
import '../features/review/review_screen.dart';
import '../features/sermons/sermons_screen.dart';
import '../features/settings/system_status.dart';
import '../features/work/work_screen.dart';
import '../l10n/app_localizations.dart';

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.store,
    required this.jobs,
    this.list = listChannel,
  });
  final SermonStore store;
  final JobQueue jobs;

  /// Test seam: the channel lister.
  final Future<List<ChannelItem>> Function() list;

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0; // 0 Preke, 1 Hersien, 2 Werk, 3 Instellings
  late final _review = ReviewController(store: widget.store, jobs: widget.jobs);

  @override
  void dispose() {
    _review.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget disabled(IconData icon, String label) => Tooltip(
      message: l.comingPhase3,
      child: Opacity(
        opacity: 0.38,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: 88,
            child: Column(
              children: [
                const SizedBox(height: 8),
                _dest(Icons.church_rounded, l.navPreke, 0),
                _dest(Icons.rate_review_rounded, l.navReview, 1),
                _dest(Icons.work_history_rounded, l.navWerk, 2),
                disabled(Icons.playlist_play_rounded, l.navSnitlyste),
                const Spacer(),
                _dest(Icons.settings_rounded, l.navSettings, 3),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _i,
              children: [
                SermonsScreen(
                  store: widget.store,
                  jobs: widget.jobs,
                  list: widget.list,
                  onOpen: (id) {
                    _review.open(id);
                    setState(() => _i = 1);
                  },
                ),
                ReviewScreen(controller: _review),
                WorkScreen(
                  store: widget.store,
                  jobs: widget.jobs,
                  onBack: () => setState(() => _i = 0),
                ),
                const SystemStatus(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dest(IconData icon, String label, int i) {
    final cs = Theme.of(context).colorScheme;
    final sel = _i == i;
    return Semantics(
      selected: sel,
      button: true,
      label: label,
      child: InkWell(
        onTap: () => setState(() => _i = i),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: sel ? cs.secondary.withValues(alpha: 0.14) : null,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: sel ? cs.secondary : null),
              const SizedBox(height: 4),
              Text(label, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        ),
      ),
    );
  }
}

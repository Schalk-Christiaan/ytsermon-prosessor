// @stelsel shell
//   soort: skerm
//   wanneer: by opstart
//   groep: app | App-raam
//   skryf: —
//   doel: NavigationRail; net Hersien en Instellings aktief in fase 1
//   status: oop
import 'package:flutter/material.dart';

import '../features/review/review_screen.dart';
import '../features/settings/system_status.dart';
import '../l10n/app_localizations.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int _i = 0; // 0 = Hersien, 1 = Instellings

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    Widget disabled(IconData icon, String label) => Tooltip(
      message: l.comingPhase2,
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
                disabled(Icons.church_rounded, l.navPreke),
                _dest(Icons.rate_review_rounded, l.navReview, 0),
                disabled(Icons.work_history_rounded, l.navWerk),
                disabled(Icons.playlist_play_rounded, l.navSnitlyste),
                const Spacer(),
                _dest(Icons.settings_rounded, l.navSettings, 1),
                const SizedBox(height: 8),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: IndexedStack(
              index: _i,
              children: const [ReviewScreen(), SystemStatus()],
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

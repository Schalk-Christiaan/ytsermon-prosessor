import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/job_progress.dart';
import 'package:preekverwerker/core/jobs.dart';

import 'screen_kit.dart';

void main() {
  Future<JobQueue> show(
    WidgetTester t,
    JobKind kind,
    JobPhase phase, {
    double? progress,
    String? detail,
  }) async {
    await loadFonts();
    setView(t, 900, 600);
    final (_, q) = workQueue();
    q.current = Job('aaaaaaaaaaa', kind, status: JobStatus.besig);
    q.started = DateTime.now().subtract(const Duration(seconds: 65));
    q.phase.value = phase;
    q.progress.value = progress;
    q.detail.value = detail;
    q.output.value = ['reël een', 'reël twee'];
    await t.pumpWidget(
      appWrap(Brightness.light, Scaffold(body: JobProgress(jobs: q))),
    );
    return q;
  }

  TextStyle? styleOf(WidgetTester t, String text) =>
      t.widget<Text>(find.text(text)).style;

  testWidgets('plan job: the current step is bold, done steps are ticked', (
    t,
  ) async {
    await show(t, JobKind.plan, JobPhase.download, progress: 0.42);
    expect(find.text('✓ Inligting'), findsOneWidget);
    expect(styleOf(t, '● Aflaai')?.fontWeight, FontWeight.w700);
    expect(find.text('Preek soek'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('01:05 verloop'), findsOneWidget);
  });

  testWidgets('every job kind lists its own steps', (t) async {
    await show(t, JobKind.upload, JobPhase.upload, progress: 0.5);
    expect(find.text('● Oplaai'), findsOneWidget);
    expect(find.textContaining('Aflaai'), findsNothing);
    await show(t, JobKind.cut, JobPhase.cut);
    expect(find.text('✓ Aflaai'), findsOneWidget);
    expect(find.text('● Sny'), findsOneWidget);
  });

  testWidgets('detail line shows, unknown progress says it takes minutes', (
    t,
  ) async {
    await show(t, JobKind.cut, JobPhase.cut, detail: 'Short 2 van 3');
    expect(find.text('Short 2 van 3'), findsOneWidget);
    expect(find.textContaining('minute'), findsOneWidget);
  });

  testWidgets('Wys besonderhede opens the last output lines', (t) async {
    await show(t, JobKind.cut, JobPhase.cut);
    expect(find.text('reël twee'), findsNothing);
    await t.tap(find.byKey(const ValueKey('ctl.werk.details')));
    await t.pump();
    expect(find.textContaining('reël twee'), findsOneWidget);
    expect(find.text('Versteek besonderhede'), findsOneWidget);
  });
}

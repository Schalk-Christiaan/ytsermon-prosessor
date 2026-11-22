// One behaviour test per inventory control (controls_inventory.dart): tap or drag it and check the
// effect on the (fake) controller or the screen. The last test fails when a listed key was not exercised.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/jobs.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/service_info.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/core/tools.dart' show JobCancelled;
import 'package:preekverwerker/features/review/review_controller.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/features/library/library_screen.dart';
import 'package:preekverwerker/features/playlists/playlists_screen.dart';
import 'package:preekverwerker/features/settings/settings_screen.dart';
import 'package:preekverwerker/features/review/review_screen.dart';
import 'package:preekverwerker/features/work/work_screen.dart';
import 'package:preekverwerker/features/sermons/sermons_screen.dart';
import 'package:preekverwerker/features/settings/system_status.dart';

import 'controls_inventory.dart';
import 'helpers.dart';
import 'screen_kit.dart';

final covered = <String>{};

Finder key(String id) => find.byKey(ValueKey('ctl.$id'));

/// Taps [id] (`<screen>.<action>`) and records it as covered.
Future<void> tapKey(WidgetTester t, String id) async {
  covered.add('ctl.${baseKey('ctl.$id').substring(4)}');
  await t.ensureVisible(key(id).first);
  await t.tap(key(id).first);
  await t.pump();
  await t.pump(const Duration(milliseconds: 400));
}

/// Types into [id], submits, and records it.
Future<void> typeKey(WidgetTester t, String id, String text) async {
  covered.add('ctl.$id');
  await t.enterText(key(id).first, text);
  await t.testTextInput.receiveAction(TextInputAction.done);
  await t.pump();
}

Future<void> ctrlKey(WidgetTester t, LogicalKeyboardKey k) async {
  await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await t.sendKeyEvent(k);
  await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await t.pump();
}

void cover(Iterable<String> ids) => covered.addAll(ids.map((i) => 'ctl.$i'));

Future<ReviewController> hersien(
  WidgetTester t, {
  ReviewController? c,
  double w = 1400,
}) async {
  await loadFonts();
  setView(t, w, 900);
  c ??= readyController();
  await t.pumpWidget(const SizedBox());
  c.meta = FetchedMeta('x', Directory.systemTemp.createTempSync('ct'), {});
  await t.pumpWidget(
    appWrap(
      Brightness.light,
      Scaffold(
        body: ReviewScreen(key: UniqueKey(), controller: c),
      ),
    ),
  );
  await t.pump(const Duration(seconds: 1));
  return c;
}

void main() {
  group('hersien', () {
    testWidgets('mark in/out, undo/redo, cut, Short, jumps, preview, play', (
      t,
    ) async {
      final c = await hersien(t);
      c.position.value = 1500;
      await tapKey(t, 'hersien.mark-in');
      expect(c.plan!.sermonStart, 1500);
      c.position.value = 3000;
      await tapKey(t, 'hersien.mark-out');
      expect(c.plan!.sermonEnd, 3000);
      await tapKey(t, 'hersien.undo');
      expect(c.plan!.sermonEnd, 3210);
      await tapKey(t, 'hersien.redo');
      expect(c.plan!.sermonEnd, 3000);
      final cuts = c.plan!.cuts.length, shorts = c.plan!.shorts.length;
      await tapKey(t, 'hersien.add-cut');
      expect(c.plan!.cuts.length, cuts + 1);
      await tapKey(t, 'hersien.add-short');
      expect(c.plan!.shorts.length, shorts + 1);
      c.position.value = 2000;
      await tapKey(t, 'hersien.forward5');
      expect(c.position.value, 2005);
      await tapKey(t, 'hersien.back5');
      expect(c.position.value, 2000);
      await tapKey(t, 'hersien.play-from-start');
      expect(c.position.value, c.plan!.sermonStart);
      await tapKey(t, 'hersien.play-end');
      expect(c.position.value, c.plan!.sermonEnd - 10);
      await tapKey(t, 'hersien.preview-cut');
      expect(c.previewing, isTrue);
      await tapKey(
        t,
        'hersien.play-pause',
      ); // no video in a test: must not throw
      expect(t.takeException(), isNull);
    });

    testWidgets('handle follows the pointer when moves outpace frames', (
      t,
    ) async {
      final c = await hersien(t);
      final w = t.getSize(key('hersien.timeline')).width;
      final before = c.plan!.sermonStart;
      final g = await t.startGesture(t.getCenter(key('hersien.handle-start')));
      await g.moveBy(const Offset(20, 0)); // past the drag slop
      await t.pump();
      final atStart = c.plan!.sermonStart;
      for (var i = 0; i < 10; i++) {
        await g.moveBy(
          const Offset(10, 0),
        ); // no pump: several events per frame
      }
      await g.up();
      await t.pump();
      expect(c.plan!.sermonStart, greaterThan(before));
      expect(c.plan!.sermonStart - atStart, closeTo(100 / w * c.duration, 0.5));
    });

    testWidgets('timeline seeks, handles and Short blocks move', (t) async {
      final c = await hersien(t);
      final tl = t.getTopLeft(key('hersien.timeline'));
      await t.tapAt(tl + const Offset(40, 8));
      expect(c.position.value, greaterThanOrEqualTo(0));
      cover(['hersien.timeline']);
      final before = c.plan!.sermonStart;
      await t.drag(key('hersien.handle-start'), const Offset(30, 0));
      await t.pump();
      expect(c.plan!.sermonStart, greaterThan(before));
      final end = c.plan!.sermonEnd;
      await t.drag(key('hersien.handle-end'), const Offset(-30, 0));
      await t.pump();
      expect(c.plan!.sermonEnd, lessThan(end));
      cover(['hersien.handle-start', 'hersien.handle-end']);
      final s0 = c.plan!.shorts.first.start;
      await t.drag(key('hersien.short-block').first, const Offset(30, 0));
      await t.pump();
      expect(c.plan!.shorts.first.start, greaterThan(s0));
      cover(['hersien.short-block']);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('zoom and Herstel', (t) async {
      final c = await hersien(t);
      await typeKey(t, 'hersien.zoom-field', '3');
      expect(t.widget<Slider>(key('hersien.zoom')).value, 3);
      final r = t.getRect(key('hersien.zoom'));
      await t.tapAt(Offset(r.left + r.width * 0.9, r.center.dy));
      await t.pump();
      expect(t.widget<Slider>(key('hersien.zoom')).value, greaterThan(8));
      cover(['hersien.zoom']);
      c.setSermon(1500, 3000);
      await t.pump();
      await tapKey(t, 'hersien.reset');
      expect(c.plan!.sermonStart, 1384);
      expect(c.plan!.sermonEnd, 3210);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('Preek tab: title and description write to the plan', (
      t,
    ) async {
      final c = await hersien(t);
      cover(['hersien.tab-sermon']);
      await t.enterText(key('hersien.title'), 'Nuwe titel');
      expect(c.plan!.title, 'Nuwe titel');
      await t.enterText(key('hersien.description'), 'Nuwe beskrywing');
      expect(c.plan!.description, 'Nuwe beskrywing');
      cover(['hersien.title', 'hersien.description']);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('Shorts tab: every control', (t) async {
      final c = await hersien(t);
      await tapKey(t, 'hersien.tab-shorts');
      await t.enterText(
        key('hersien.short-title.0.${c.planRevision}.${c.edits}'),
        'Nuwe Short',
      );
      expect(c.plan!.shorts.first.title, 'Nuwe Short');
      cover(['hersien.short-title']);
      final s = c.plan!.shorts.first;
      await typeKey(t, 'hersien.short-begin-field', '26:00');
      expect(s.start, 1560);
      await t.drag(key('hersien.short-begin').first, const Offset(30, 0));
      await t.pump();
      expect(s.start, greaterThan(1560));
      cover(['hersien.short-begin']);
      await typeKey(t, 'hersien.short-length-field', '45');
      expect(s.end - s.start, closeTo(45, 0.6));
      await t.drag(key('hersien.short-length').first, const Offset(30, 0));
      await t.pump();
      expect(s.end - s.start, greaterThan(45));
      cover(['hersien.short-length']);
      c.position.value = 1700;
      await tapKey(t, 'hersien.short-start');
      expect(c.plan!.shorts.first.start, 1700);
      await tapKey(t, 'hersien.short-play');
      expect(c.position.value, c.plan!.shorts.first.start);
      final n = c.plan!.shorts.length;
      await tapKey(t, 'hersien.short-remove');
      expect(c.plan!.shorts.length, n - 1);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('Uitgeknip tab: set ends, play, remove', (t) async {
      final c = await hersien(t);
      await tapKey(t, 'hersien.tab-cuts');
      final cut = c.plan!.cuts.first;
      c.position.value = 2060;
      await tapKey(t, 'hersien.cut-start');
      expect(cut.start, 2060);
      c.position.value = 2150;
      await tapKey(t, 'hersien.cut-end');
      expect(cut.end, 2150);
      await tapKey(t, 'hersien.cut-play');
      expect(c.position.value, 2057);
      await tapKey(t, 'hersien.cut-remove');
      expect(c.plan!.cuts, isEmpty);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('Uitvoer tab: chips, Aand and the service kind', (t) async {
      final c = await hersien(t);
      await tapKey(t, 'hersien.tab-output');
      final set = AppSettings.load(c.store.root);
      expect(set.exports, {'full', 'word', 'songs'});
      for (final e in ['full', 'word', 'songs']) {
        await tapKey(t, 'hersien.out-$e');
      }
      expect(AppSettings.load(c.store.root).exports, isEmpty);
      await t.tap(find.text('Aand'));
      await t.pump();
      expect(c.service.evening, isTrue);
      cover(['hersien.service-day']);
      await t.tap(key('hersien.service-kind'));
      await t.pumpAndSettle();
      await t.tap(find.text('Nagmaal').last);
      await t.pumpAndSettle();
      expect(c.service.label, 'nagmaal');
      cover(['hersien.service-kind']);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets('Transkripsie tab: a line seeks', (t) async {
      final c = await hersien(t);
      await tapKey(t, 'hersien.tab-transcript');
      final line = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey<String> &&
            (w.key! as ValueKey<String>).value.startsWith(
              'ctl.hersien.transcript-line.',
            ),
      );
      await t.tap(line.at(2));
      expect(c.position.value, c.segments[2].start);
      cover(['hersien.transcript-line']);
    });

    testWidgets('shortcuts I, O, Space, Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y, arrows', (
      t,
    ) async {
      final c = await hersien(t);
      c.position.value = 1500;
      await t.sendKeyEvent(LogicalKeyboardKey.keyI);
      expect(c.plan!.sermonStart, 1500);
      c.position.value = 3000;
      await t.sendKeyEvent(LogicalKeyboardKey.keyO);
      expect(c.plan!.sermonEnd, 3000);
      await t.sendKeyEvent(LogicalKeyboardKey.space);
      expect(t.takeException(), isNull);
      Future<void> ctrl(LogicalKeyboardKey k, {bool shift = false}) async {
        await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        if (shift) await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyEvent(k);
        if (shift) await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await t.pump();
      }

      await ctrl(LogicalKeyboardKey.keyZ);
      expect(c.plan!.sermonEnd, 3210);
      await ctrl(LogicalKeyboardKey.keyZ, shift: true);
      expect(c.plan!.sermonEnd, 3000);
      await ctrl(LogicalKeyboardKey.keyZ);
      await ctrl(LogicalKeyboardKey.keyY);
      expect(c.plan!.sermonEnd, 3000);
      final start = find.bySemanticsLabel(RegExp('Preek begin 25:'));
      await t.tap(start.first);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(c.plan!.sermonStart, 1501);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(c.plan!.sermonStart, 1500);
      await t.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(c.plan!.sermonStart, closeTo(1500.1, 1e-9));
      await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await t.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      expect(c.plan!.sermonStart, closeTo(1500, 1e-9));
      shortcutsCovered.addAll([
        'hersien: I',
        'hersien: O',
        'hersien: Space',
        'hersien: Ctrl+Z',
        'hersien: Ctrl+Shift+Z',
        'hersien: Ctrl+Y',
        'hersien: Left',
        'hersien: Right',
        'hersien: Shift+Left',
        'hersien: Shift+Right',
      ]);
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    });

    testWidgets(
      'doubt banner jumps to the boundary; narrow window toggles properties',
      (t) async {
        final c = readyController()..plan!.doubt = BoundsDoubt.noPrayerAfter;
        await hersien(t, c: c);
        await tapKey(t, 'hersien.go-to-boundary');
        expect(c.position.value, 3210);
        await hersien(t, c: c, w: 1100);
        expect(find.byKey(const ValueKey('review.properties')), findsNothing);
        await tapKey(t, 'hersien.properties-toggle');
        expect(find.byKey(const ValueKey('review.properties')), findsOneWidget);
      },
    );

    testWidgets('approve, skip, replan, push (and their disabled state)', (
      t,
    ) async {
      var c = readyController();
      await hersien(t, c: c);
      await tapKey(t, 'hersien.approve');
      await t.pump(const Duration(milliseconds: 300));
      expect(c.jobs.jobs.any((j) => j.kind == JobKind.cut), isTrue);

      c = readyController();
      c.plan!.shorts.first.end = c.plan!.shorts.first.start + 200; // too long
      await hersien(t, c: c);
      expect(
        t.widget<ButtonStyleButton>(key('hersien.approve')).onPressed,
        isNull,
        reason: 'a faulty Short blocks approval',
      );

      c = readyController();
      await hersien(t, c: c);
      await tapKey(t, 'hersien.replan');
      await tapKey(t, 'hersien.replan-cancel');
      expect(c.state, ReviewState.ready);
      await tapKey(t, 'hersien.replan');
      await tapKey(t, 'hersien.replan-confirm');
      expect(c.state, isNot(ReviewState.ready));

      c = readyController();
      await hersien(t, c: c);
      await tapKey(t, 'hersien.skip');
      expect(c.store.byId('x')!.state, SermonState.oorgeslaan);

      c = readyController();
      var pushed = 0;
      c.updateYouTube = (_) async => ++pushed;
      c.store.byId('x')!.state = SermonState.opgelaai;
      await hersien(t, c: c);
      await tapKey(t, 'hersien.push');
      await t.pump();
      expect(pushed, 1);
      await t.pump(const Duration(seconds: 5));
    });

    testWidgets('unplanned and error states: plan now, retry, set manually', (
      t,
    ) async {
      // A download that never finishes: no libmpv in a widget test.
      final c = testController(
        download: (m, {onProgress}) => Completer<File>().future,
      ).$1;
      c.id = 'x';
      c.state = ReviewState.unplanned;
      c.meta = FetchedMeta('x', Directory.systemTemp.createTempSync('ct'), {});
      await loadFonts();
      setView(t, 1400, 900);
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Scaffold(
            body: ReviewScreen(key: UniqueKey(), controller: c),
          ),
        ),
      );
      await t.pump();
      await tapKey(t, 'hersien.plan-now');
      expect(c.jobs.jobs.where((j) => j.kind == JobKind.plan), isNotEmpty);
      c.state = ReviewState.error;
      c.error = 'Ollama het nie geantwoord nie.';
      c.notifyListeners();
      await t.pump();
      await tapKey(t, 'hersien.retry');
      expect(
        c.jobs.jobs.where((j) => j.kind == JobKind.plan).length,
        greaterThan(0),
      );
      c.state = ReviewState.error;
      c.duration = 600;
      c.meta = FetchedMeta('x', Directory.systemTemp, {});
      c.notifyListeners();
      await t.pump();
      await tapKey(t, 'hersien.set-manually');
      expect(c.state, ReviewState.ready);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 2));
    });
  });

  group('preke', () {
    Future<(SermonStore, JobQueue, List<String>)> preke(
      WidgetTester t, {
      Future<List<ChannelItem>> Function()? list,
      Future<String?> Function()? pickVideo,
      List<String>? opened,
      double w = 1280,
    }) async {
      await loadFonts();
      setView(t, w, 900);
      await t.pumpWidget(const SizedBox());
      final (st, q) = seededSermons();
      final o = opened ?? <String>[];
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          prekeScreen(st, q, list: list, pickVideo: pickVideo, onOpen: o.add),
        ),
      );
      await t.pumpAndSettle();
      return (st, q, o);
    }

    int rows() => find.byKey(const ValueKey('ctl.preke.row')).evaluate().length;

    testWidgets('filters narrow the list; search and Ctrl+F', (t) async {
      final (st, _, _) = await preke(t);
      await tapKey(t, 'preke.filter-fout');
      expect(rows(), 1);
      await tapKey(t, 'preke.filter-fout');
      for (final s in SermonState.values) {
        await tapKey(t, 'preke.filter-${s.name}');
        final n = st.sorted.where((x) => x.state == s).length;
        if (n == 0) {
          expect(find.textContaining('Geen preke pas'), findsOneWidget);
        } else {
          expect(
            rows(),
            n > 8 ? greaterThan(5) : n,
          ); // a long list builds only what is in view
        }
        await tapKey(t, 'preke.filter-${s.name}');
      }
      await tapKey(t, 'preke.filter-not-uploaded');
      expect(rows(), lessThanOrEqualTo(st.sorted.length));
      await tapKey(t, 'preke.filter-not-uploaded');
      await typeKey(t, 'preke.search', 'Preek 7');
      expect(rows(), 1);
      await t.enterText(key('preke.search'), '');
      await t.pump();
      await tapKey(t, 'preke.filter-nuut'); // moves focus off the search field
      await tapKey(t, 'preke.filter-nuut');
      await ctrlKey(t, LogicalKeyboardKey.keyF);
      expect(
        t.widget<TextField>(key('preke.search')).focusNode!.hasFocus,
        isTrue,
      );
      shortcutsCovered.add('preke: Ctrl+F');
    });

    testWidgets('select, Verwerk volgende and Ctrl+Enter plan the sermons', (
      t,
    ) async {
      final (st, q, _) = await preke(t);
      final id = st.sorted.first.id;
      await tapKey(t, 'preke.select');
      await tapKey(t, 'preke.process-next');
      expect(
        q.jobs.any((j) => j.sermon == id && j.kind == JobKind.plan),
        isTrue,
      );
      q.jobs.clear();
      await t.tap(key('preke.select').at(1));
      await t.pump();
      await ctrlKey(t, LogicalKeyboardKey.enter);
      expect(q.jobs.where((j) => j.kind == JobKind.plan), hasLength(1));
      shortcutsCovered.add('preke: Ctrl+Enter');
    });

    testWidgets(
      'Verwerk nuutste opens the newest service; a row opens its sermon; view toggles',
      (t) async {
        final (st, _, opened) = await preke(t);
        await tapKey(t, 'preke.process-latest');
        await t.pumpAndSettle();
        expect(opened, [st.sorted.first.id]);
        await tapKey(t, 'preke.row');
        expect(opened.length, 2);
        await t.tap(
          find.descendant(
            of: key('preke.view'),
            matching: find.text('Rooster'),
          ),
        );
        await t.pumpAndSettle();
        expect(find.byType(GridView), findsOneWidget);
        cover(['preke.view']);
      },
    );

    testWidgets('select-all box and Ctrl+A', (t) async {
      final (st, _, _) = await preke(t);
      await tapKey(t, 'preke.select-all');
      expect(t.widget<Checkbox>(key('preke.select-all')).value, isTrue);
      await tapKey(t, 'preke.select-all');
      expect(t.widget<Checkbox>(key('preke.select-all')).value, isFalse);
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendKeyEvent(LogicalKeyboardKey.keyA);
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await t.pump();
      expect(t.widget<Checkbox>(key('preke.select-all')).value, isTrue);
      expect(st.sorted, isNotEmpty);
      shortcutsCovered.add('preke: Ctrl+A');
    });

    testWidgets('column headers sort the table', (t) async {
      final (st, _, _) = await preke(t);
      String first() => t
          .widget<Text>(
            find
                .descendant(
                  of: key('preke.row').first,
                  matching: find.textContaining('Preek '),
                )
                .first,
          )
          .data!;
      expect(first(), st.sorted.first.title);
      for (final c in ['title', 'date', 'length', 'state', 'size']) {
        await tapKey(t, 'preke.sort-$c');
      }
      await tapKey(t, 'preke.sort-title');
      await tapKey(t, 'preke.sort-title');
      expect(first(), 'Preek 9');
    });

    testWidgets('new services strip can be dismissed', (t) async {
      await preke(
        t,
        list: () async => [
          ...sampleItems,
          const ChannelItem('nuwe0000001', 'Nuwe preek', 3000),
        ],
      );
      expect(find.textContaining('nuwe'), findsWidgets);
      await tapKey(t, 'preke.dismiss');
      expect(key('preke.dismiss'), findsNothing);
    });

    testWidgets('import: cancel does nothing, confirm opens the sermon', (
      t,
    ) async {
      final opened = <String>[];
      await loadFonts();
      setView(t, 1280, 900);
      var imported = 0;
      final (st, q) = seededSermons();
      Widget screen() => Scaffold(
        body: SermonsScreen(
          key: UniqueKey(),
          store: st,
          jobs: q,
          list: () async => sampleItems,
          onOpen: opened.add,
          pickVideo: () async => '/tmp/opname.mp4',
          importFile: (f, title, date) async {
            imported++;
            return st.sorted.first;
          },
        ),
      );
      await t.pumpWidget(appWrap(Brightness.light, screen()));
      await t.pumpAndSettle();
      await tapKey(t, 'preke.import');
      await t.pumpAndSettle();
      await tapKey(t, 'preke.import-cancel');
      await t.pumpAndSettle();
      expect(imported, 0);
      await tapKey(t, 'preke.import');
      await t.pumpAndSettle();
      await t.enterText(key('preke.import-title'), 'My opname');
      cover(['preke.import-title']);
      await tapKey(t, 'preke.import-date');
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await tapKey(t, 'preke.import-confirm');
      await t.pumpAndSettle();
      expect(imported, 1);
      expect(opened, [st.sorted.first.id]);
    });

    testWidgets('list error: retry reloads, update yt-dlp runs the updater', (
      t,
    ) async {
      var fail = true;
      var updated = 0;
      ytDlpUpdater = () async => '${++updated}';
      await loadFonts();
      setView(t, 1280, 900);
      final tc = testController(seed: false);
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          prekeScreen(
            tc.$2,
            tc.$3,
            list: () async => fail ? throw 'geen net' : sampleItems,
          ),
        ),
      );
      await t.pumpAndSettle();
      await tapKey(t, 'preke.update-ytdlp');
      expect(updated, 1);
      fail = false;
      await tapKey(t, 'preke.retry');
      await t.pumpAndSettle();
      expect(rows(), greaterThan(0));
      expect(key('preke.retry'), findsNothing);
    });
  });

  group('werk', () {
    Future<void> werk(
      WidgetTester t,
      SermonStore st,
      JobQueue q, {
      void Function()? onBack,
      List<String>? opened,
    }) async {
      await loadFonts();
      setView(t, 1100, 900);
      await t.pumpWidget(const SizedBox());
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Scaffold(
            body: WorkScreen(
              key: UniqueKey(),
              store: st,
              jobs: q,
              onBack: onBack ?? () {},
              open: (path, {select = false}) async =>
                  opened?.add('${select ? 'show:' : 'play:'}$path'),
            ),
          ),
        ),
      );
      await t.pump();
    }

    testWidgets('done cut: play, show, audio and upload act on the output', (
      t,
    ) async {
      final (st, q) = workQueue();
      final opened = <String>[];
      await werk(t, st, q, opened: opened);
      await tapKey(t, 'werk.play');
      await tapKey(t, 'werk.show');
      expect(opened, [
        'play:/tmp/2026-11-15 Preek.mp4',
        'show:/tmp/2026-11-15 Preek.mp4',
      ]);
      await tapKey(t, 'werk.audio');
      expect(
        q.jobs.any((j) => j.kind == JobKind.audio && j.sermon == 'ccccccccccc'),
        isTrue,
      );
      await tapKey(t, 'werk.upload');
      expect(
        q.jobs.any(
          (j) => j.kind == JobKind.upload && j.sermon == 'ccccccccccc',
        ),
        isTrue,
      );
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets('failed job: retry requeues it and the log opens', (t) async {
      final (st, q) = workQueue();
      await werk(t, st, q);
      await tapKey(t, 'werk.log');
      await t.pumpAndSettle();
      expect(find.textContaining('Connection refused'), findsOneWidget);
      final failed = q.jobs.firstWhere((j) => j.status == JobStatus.fout);
      await tapKey(t, 'werk.retry');
      expect(failed.status, isNot(JobStatus.fout));
      await t.pump(const Duration(seconds: 3));
    });

    testWidgets(
      'uploaded: open on YouTube; copy puts WhatsApp.txt on the clipboard; Esc goes back',
      (t) async {
        final d = Directory.systemTemp.createTempSync('wa');
        addTearDown(() => d.deleteSync(recursive: true));
        File('${d.path}/WhatsApp.txt')
            .writeAsStringSync('*Aanddiens*\nTema: X');
        File('${d.path}/diens.json').writeAsStringSync(
          jsonEncode({'info': ServiceInfo(date: '2026-11-15').toJson()}),
        );
        final tc = testController(seed: false);
        final st = tc.$2
          ..merge([const ChannelItem('ccccccccccc', 'Preek c', 100)]);
        final file = '${d.path}/Volle preek.mp4';
        st.byId('ccccccccccc')!
          ..outputs = [file]
          ..uploads = {file: 'abc123'};
        final q = tc.$3;
        q.jobs.addAll([
          Job('ccccccccccc', JobKind.cut, status: JobStatus.klaar),
          Job('ccccccccccc', JobKind.upload, status: JobStatus.klaar),
        ]);
        String? copied;
        t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData')
              copied = (call.arguments as Map)['text'] as String;
            return null;
          },
        );
        addTearDown(
          () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        final opened = <String>[];
        var back = 0;
        await werk(t, st, q, opened: opened, onBack: () => back++);
        await tapKey(t, 'werk.open-youtube');
        expect(opened, ['play:https://studio.youtube.com/video/abc123/edit']);
        await tapKey(t, 'werk.copy');
        expect(copied, '*Aanddiens*\nTema: X');
        await t.sendKeyEvent(LogicalKeyboardKey.escape);
        expect(back, 1);
        shortcutsCovered.add('werk: Escape');
        await t.pump(const Duration(seconds: 5));
      },
    );

    testWidgets('Avbreek stops the running job', (t) async {
      final tc = testController(
        cut: (ctx) async {
          await ctx.cancel;
          throw JobCancelled();
        },
      );
      tc.$3.enqueue('x', JobKind.cut);
      await werk(t, tc.$2, tc.$3);
      await t.pump(const Duration(milliseconds: 50));
      await tapKey(t, 'werk.cancel');
      await t.pump(const Duration(milliseconds: 50));
      expect(tc.$3.jobs.single.status, JobStatus.gekanselleer);
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('snitlyste', () {
    testWidgets('rules toggle, both templates are saved', (t) async {
      await loadFonts();
      setView(t, 1100, 1400);
      final st = playlistStore();
      final set = AppSettings.load(st.root);
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Scaffold(
            body: PlaylistsScreen(store: st, settings: set),
          ),
        ),
      );
      await t.pump();
      for (final r in ['book', 'year']) {
        final before = set.rules.contains(r);
        await tapKey(t, 'snitlyste.rule-$r');
        expect(set.rules.contains(r), !before);
        expect(AppSettings.load(st.root).rules.contains(r), !before);
      }
      await typeKey(t, 'snitlyste.template', 'Tema: {tema}');
      expect(AppSettings.load(st.root).template, 'Tema: {tema}');
      await typeKey(t, 'snitlyste.whatsapp', 'Fokus: {fokus}');
      expect(AppSettings.load(st.root).whatsappTemplate, 'Fokus: {fokus}');
      await t.pumpWidget(const SizedBox());
    });
  });

  group('instellings', () {
    testWidgets(
      'connect, disconnect, client file, privacy, folder, clips, yt-dlp, setup',
      (t) async {
        await loadFonts();
        setView(t, 1100, 900);
        var picked = '/tmp/intro.mp4';
        var setup = 0;
        ytDlpUpdater = () async => 'ok';
        final (w, set) = settingsScreen(
          onSetup: () => setup++,
          pickVideo: () async => picked,
          system: const SystemStatus(),
        );
        await t.pumpWidget(appWrap(Brightness.light, w));
        await t.pump();
        await tapKey(t, 'instellings.setup');
        expect(setup, 1);
        await tapKey(t, 'instellings.connect');
        await t.pump();
        expect(find.text('Gekoppel'), findsWidgets);
        await tapKey(t, 'instellings.disconnect');
        await t.pump();
        expect(key('instellings.connect'), findsOneWidget);
        await t.enterText(key('instellings.client-file'), '/tmp/client.json');
        await t.testTextInput.receiveAction(TextInputAction.done);
        await t.pump();
        expect(set.clientFile, '/tmp/client.json');
        cover(['instellings.client-file']);
        await t.tap(
          find.descendant(
            of: key('instellings.privacy'),
            matching: find.text('Publiek'),
          ),
        );
        await t.pump();
        expect(set.privacy, 'public');
        cover(['instellings.privacy']);
        await typeKey(t, 'instellings.out-dir', '/tmp/Preke');
        expect(set.outDir, '/tmp/Preke');
        await tapKey(t, 'instellings.choose-intro');
        expect(set.intro, '/tmp/intro.mp4');
        picked = '/tmp/outro.mp4';
        await tapKey(t, 'instellings.choose-outro');
        expect(set.outro, '/tmp/outro.mp4');
        await tapKey(t, 'instellings.remove-intro');
        expect(set.intro, isNull);
        await tapKey(t, 'instellings.remove-outro');
        expect(set.outro, isNull);
        await tapKey(t, 'instellings.update-ytdlp');
        await t.pump();
        expect(find.textContaining('ok'), findsWidgets);
        await t.pumpWidget(const SizedBox());
        await t.pump(const Duration(seconds: 5));
      },
    );
  });

  group('opstelling', () {
    testWidgets(
      'four steps then Begin werk; Kontroleer weer; no client file goes to Instellings',
      (t) async {
        await loadFonts();
        setView(t, 1100, 900);
        final (w, set, calls) = setupScreen();
        await t.pumpWidget(appWrap(Brightness.light, w));
        await t.pumpAndSettle();
        expect(
          t.widget<ButtonStyleButton>(key('opstelling.begin')).onPressed,
          isNull,
        );
        await tapKey(t, 'opstelling.step-1');
        await t.pumpAndSettle();
        await tapKey(t, 'opstelling.step-2');
        await t.pumpAndSettle();
        await tapKey(t, 'opstelling.step-3');
        await t.pumpAndSettle();
        await tapKey(t, 'opstelling.step-4');
        await t.pumpAndSettle();
        expect(calls, ['start', 'pull', 'signIn']);
        expect(Directory(set.outDir).existsSync(), isTrue);
        await tapKey(t, 'opstelling.check');
        await t.pumpAndSettle();
        await tapKey(t, 'opstelling.begin');
        expect(calls.last, 'done');

        final (w2, set2, calls2) = setupScreen();
        File(set2.clientFile).deleteSync();
        await t.pumpWidget(const SizedBox());
        await t.pumpWidget(appWrap(Brightness.light, w2));
        await t.pumpAndSettle();
        await tapKey(t, 'opstelling.step-3');
        expect(calls2, ['settings']);
      },
    );
  });

  group('kanaal', () {
    for (final screen in ['instellings', 'opstelling']) {
      testWidgets('$screen: the channel field checks, then keeps it', (
        t,
      ) async {
        await loadFonts();
        setView(t, 1100, 900);
        final seen = <String>[];
        Future<String> validate(String u) async {
          seen.add(u);
          if (u.endsWith('weg')) throw 'nie gevind';
          return 'Ander Kerk';
        }

        final AppSettings set;
        final Widget w;
        if (screen == 'instellings') {
          (w, set) = settingsScreen(validate: validate);
        } else {
          final r = setupScreen(validate: validate);
          (w, set) = (r.$1, r.$2);
        }
        await t.pumpWidget(appWrap(Brightness.light, w));
        await t.pumpAndSettle();
        await typeKey(t, '$screen.channel', 'baie sleg');
        expect(find.textContaining('lyk nie soos'), findsOneWidget);
        expect(seen, isEmpty);
        await typeKey(t, '$screen.channel', '@weg');
        await t.pumpAndSettle();
        expect(find.textContaining('Kon nie hierdie kanaal'), findsOneWidget);
        expect(set.channelUrl, kChannelUrl);
        await t.enterText(
          key('$screen.channel').first,
          'youtube.com/@ander/videos',
        );
        await tapKey(t, '$screen.channel-check');
        await t.pumpAndSettle();
        expect(find.text('Gevind: Ander Kerk'), findsOneWidget);
        expect(set.channelUrl, 'https://www.youtube.com/@ander');
        cover(['$screen.channel-check']);
      });
    }
  });

  group('biblioteek', () {
    testWidgets('Preke/Sang view, search, reload, play, show and copy', (
      t,
    ) async {
      await loadFonts();
      setView(t, 1100, 900);
      final (w, set, opened) = libraryScreen();
      String? copied;
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData')
            copied = (call.arguments as Map)['text'] as String;
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await t.pumpWidget(appWrap(Brightness.light, w));
      await t.pump();
      await t.tap(key('biblioteek.play').first);
      await t.pump();
      expect(opened.single.$1, endsWith('Volle preek.mp4'));
      expect(opened.single.$2, isFalse);
      cover(['biblioteek.play']);
      await tapKey(t, 'biblioteek.show');
      expect(opened.last.$2, isTrue);
      await tapKey(t, 'biblioteek.copy');
      expect(copied, isNotNull);
      await typeKey(t, 'biblioteek.search', 'Genade');
      expect(key('biblioteek.play'), findsOneWidget);
      await t.enterText(key('biblioteek.search'), '');
      await t.pump();
      final out = Directory(set.outDir);
      Directory('${out.path}/2026/2026-11-22 Nuut').createSync(recursive: true);
      File('${out.path}/2026/2026-11-22 Nuut/diens.json').writeAsStringSync(
        jsonEncode({
          'info': {'date': '2026-11-22', 'theme': 'Nuut', 'psalms': <int>[]},
          'title': 'Nuut',
          'files': ['Volle preek.mp4'],
          'songs': <Map<String, dynamic>>[],
        }),
      );
      final before = key('biblioteek.play').evaluate().length;
      await tapKey(t, 'biblioteek.reload');
      expect(key('biblioteek.play').evaluate().length, before + 1);
      await t.tap(
        find.descendant(
          of: key('biblioteek.view'),
          matching: find.text('Sang'),
        ),
      );
      await t.pump();
      cover(['biblioteek.view']);
      await t.tap(key('biblioteek.song-play').first);
      await t.pump();
      cover(['biblioteek.song-play']);
      expect(opened.last.$1, endsWith('.mp3'));
      expect(opened.last.$2, isFalse);
      await tapKey(t, 'biblioteek.song-show');
      expect(opened.last.$2, isTrue);
    });
  });

  group('skulp', () {
    testWidgets('every rail item opens its screen', (t) async {
      await loadFonts();
      setView(t, 1280, 900);
      final tc = testController();
      await t.pumpWidget(
        appWrap(
          Brightness.light,
          Shell(
            store: tc.$2,
            jobs: tc.$3,
            list: () async => [],
            settings: AppSettings.load(tc.$2.root)..setupDone = true,
          ),
        ),
      );
      await t.pump();
      for (final (i, type) in [
        (1, ReviewScreen),
        (2, WorkScreen),
        (3, PlaylistsScreen),
        (4, SettingsScreen),
        (6, LibraryScreen),
        (0, SermonsScreen),
      ]) {
        await tapKey(t, 'skulp.nav-$i');
        expect(find.byType(type), findsOneWidget, reason: 'nav-$i');
      }
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 5));
    });
  });

  test('every inventory control and shortcut has a behaviour test', () {
    final missing = allControlKeys
        .map(baseKey)
        .toSet()
        .difference(covered.map(baseKey).toSet());
    expect(missing, isEmpty, reason: 'controls without a behaviour test');
    expect(kShortcuts.difference(shortcutsCovered), isEmpty);
  });
}

final shortcutsCovered = <String>{};

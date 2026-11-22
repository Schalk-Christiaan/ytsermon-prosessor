// Meta-test: every interactive widget on every screen carries a `ctl.<screen>.<action>` key that is
// listed in controls_inventory.dart. A new button without a key fails here.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/app/shell.dart';
import 'package:preekverwerker/core/settings.dart';
import 'package:preekverwerker/core/store.dart';
import 'package:preekverwerker/features/review/review_controller.dart';
import 'package:preekverwerker/features/review/review_screen.dart';
import 'package:preekverwerker/features/work/work_screen.dart';
import 'package:preekverwerker/features/playlists/playlists_screen.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/channel.dart';

import 'controls_inventory.dart';
import 'helpers.dart';
import 'screen_kit.dart';

bool _isControl(Widget w) =>
    w is ButtonStyleButton ||
    w is IconButton ||
    w is Slider ||
    w is Switch ||
    w is SwitchListTile ||
    w is SegmentedButton ||
    w is Checkbox ||
    w is FilterChip ||
    w is ChoiceChip ||
    w is TextField ||
    w is TextFormField ||
    w is DropdownButton ||
    w is ExpansionTile ||
    (w is InkWell && w.onTap != null) ||
    (w is ListTile && w.onTap != null);

/// Keys of all top-level controls under [root] (a control inside another control, other than an
/// InkWell row, is part of it); `null` stands for a control without a string key.
List<String?> controlKeys(WidgetTester t, Finder root) {
  final out = <String?>[];
  for (final e
      in find
          .descendant(of: root, matching: find.byWidgetPredicate(_isControl))
          .evaluate()) {
    var nested = false;
    e.visitAncestorElements((a) {
      if (_isControl(a.widget) && a.widget is! InkWell) nested = true;
      return !nested;
    });
    if (nested) continue;
    final k = e.widget.key;
    out.add(
      k is ValueKey<String> && k.value.startsWith('ctl.') ? k.value : null,
    );
  }
  return out;
}

/// Whether the control [e] answers the keyboard and the pointer: a disabled button is skipped.
bool _enabled(Widget w) =>
    !(w is ButtonStyleButton && w.onPressed == null) &&
    !(w is IconButton && w.onPressed == null) &&
    !(w is TextField && w.enabled == false);

/// Tab through [screen] once: every enabled control with a `ctl.` key must get the keyboard focus
/// (so it has a focus ring) and be at least 32 px high (a hit target an unsure hand can find).
Future<void> checkKeyboard(WidgetTester t, String screen) async {
  final want = <String, double>{};
  for (final e
      in find
          .descendant(
            of: find.byType(Scaffold).first,
            matching: find.byWidgetPredicate(_isControl),
          )
          .evaluate()) {
    var nested = false;
    e.visitAncestorElements((a) {
      if (_isControl(a.widget) && a.widget is! InkWell) nested = true;
      return !nested;
    });
    final k = e.widget.key;
    if (nested || k is! ValueKey<String> || !_enabled(e.widget)) continue;
    final box = e.renderObject as RenderBox;
    want[k.value] = box.size.height;
  }
  expect(want, isNotEmpty, reason: screen);
  final reached = <String>{};
  for (var i = 0; i < want.length * 2 + 20; i++) {
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((a) {
      final k = a.widget.key;
      if (k is ValueKey<String> && k.value.startsWith('ctl.')) {
        reached.add(k.value);
        return false;
      }
      return true;
    });
  }
  final skip = {
    for (final k in want.keys)
      if (k.contains('.row') || k.endsWith('hersien.zoom')) k,
  };
  expect(
    want.keys.where((k) => !reached.contains(k) && !skip.contains(k)),
    isEmpty,
    reason: '$screen: not reachable with Tab',
  );
  expect(
    want.entries
        .where((e) => e.value < 31.5 && !skip.contains(e.key))
        .map((e) => '${e.key} ${e.value}'),
    isEmpty,
    reason: '$screen: shorter than 32 px',
  );
}

void checkScreen(WidgetTester t, String screen) {
  final keys = controlKeys(t, find.byType(Scaffold).first);
  expect(keys, isNotEmpty, reason: '$screen shows no controls');
  expect(
    keys.where((k) => k == null),
    isEmpty,
    reason: '$screen: control without ctl key',
  );
  for (final k in keys.cast<String>()) {
    expect(
      allControlKeys,
      contains(baseKey(k)),
      reason: 'not in inventory: $k',
    );
    expect(
      k.startsWith('ctl.$screen.') || k.startsWith('ctl.skulp.'),
      isTrue,
      reason: '$k on screen $screen',
    );
  }
}

void main() {
  for (final b in Brightness.values) {
    Future<void> pump(WidgetTester t, Widget w, {bool settle = true}) async {
      await loadFonts();
      setView(t, 1280, 900);
      await t.pumpWidget(appWrap(b, w));
      settle
          ? await t.pumpAndSettle()
          : await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
    }

    group(b.name, () {
      testWidgets('preke', (t) async {
        final (st, q) = seededSermons();
        await pump(t, prekeScreen(st, q));
        checkScreen(t, 'preke');
        await checkKeyboard(t, 'preke');
      });

      testWidgets('preke: fout en invoer-dialoog', (t) async {
        final tc = testController(seed: false);
        await pump(
          t,
          prekeScreen(tc.$2, tc.$3, list: () async => throw 'geen net'),
        );
        checkScreen(t, 'preke');
        expect(
          find.byKey(const ValueKey('ctl.preke.update-ytdlp')),
          findsOneWidget,
        );
        final (st, q) = seededSermons();
        await pump(
          t,
          prekeScreen(st, q, pickVideo: () async => '/tmp/opname.mp4'),
        );
        await t.tap(find.byKey(const ValueKey('ctl.preke.import')));
        await t.pumpAndSettle();
        final keys = controlKeys(t, find.byType(AlertDialog));
        expect(
          keys,
          containsAll(['ctl.preke.import-title', 'ctl.preke.import-cancel']),
        );
        for (final k in keys) {
          expect(allControlKeys, contains(k));
        }
      });

      testWidgets('hersien: klaar, opgelaai, twyfel, uitknip-oortjie', (
        t,
      ) async {
        final c = readyController();
        c.updateYouTube = (_) async => 1;
        c.store.byId('x')!.state = SermonState.opgelaai;
        c.plan!.doubt = BoundsDoubt.noPrayerAfter;
        await pump(
          t,
          Scaffold(body: ReviewScreen(controller: c)),
          settle: false,
        );
        checkScreen(t, 'hersien');
        await checkKeyboard(t, 'hersien');
        final keys = controlKeys(t, find.byType(Scaffold).first);
        expect(
          keys,
          containsAll([
            'ctl.hersien.push',
            'ctl.hersien.go-to-boundary',
            'ctl.hersien.title',
            'ctl.hersien.zoom',
            'ctl.hersien.reset',
          ]),
        );
        for (final (tab, key) in [
          ('shorts', 'ctl.hersien.short-length'),
          ('cuts', 'ctl.hersien.cut-start'),
          ('output', 'ctl.hersien.out-full'),
          ('transcript', 'ctl.hersien.transcript-line'),
        ]) {
          await t.tap(find.byKey(ValueKey('ctl.hersien.tab-$tab')));
          await t.pump();
          checkScreen(t, 'hersien');
          expect(
            controlKeys(
              t,
              find.byType(Scaffold).first,
            ).any((k) => k!.startsWith(key)),
            isTrue,
            reason: key,
          );
        }
      });

      testWidgets('hersien: leeg, onbeplan, fout', (t) async {
        final c = testController().$1;
        for (final s in [ReviewState.unplanned, ReviewState.error]) {
          c.state = s;
          c.error = 'Ollama het nie geantwoord nie.';
          c.meta = FetchedMeta('x', Directory.systemTemp, {});
          await pump(
            t,
            Scaffold(body: ReviewScreen(controller: c)),
            settle: false,
          );
          checkScreen(t, 'hersien');
        }
      });

      testWidgets('werk', (t) async {
        for (final audio in [false, true]) {
          final (st, q) = workQueue(audio: audio);
          await pump(
            t,
            Scaffold(
              body: WorkScreen(store: st, jobs: q, onBack: () {}),
            ),
            settle: false,
          );
          checkScreen(t, 'werk');
          await checkKeyboard(t, 'werk');
        }
      });

      testWidgets('snitlyste', (t) async {
        final st = playlistStore();
        await pump(
          t,
          Scaffold(
            body: PlaylistsScreen(
              store: st,
              settings: AppSettings.load(st.root),
            ),
          ),
        );
        checkScreen(t, 'snitlyste');
        await checkKeyboard(t, 'snitlyste');
      });

      testWidgets('instellings', (t) async {
        for (final token in [null, 'rt']) {
          final (w, set) = settingsScreen(token: token);
          set.intro = '/tmp/intro.mp4';
          await pump(t, w, settle: false);
          checkScreen(t, 'instellings');
          await checkKeyboard(t, 'instellings');
        }
      });

      testWidgets('opstelling', (t) async {
        final (w, _, _) = setupScreen();
        await pump(t, w);
        checkScreen(t, 'opstelling');
        await checkKeyboard(t, 'opstelling');
      });

      testWidgets('biblioteek', (t) async {
        final (w, _, _) = libraryScreen();
        await pump(t, w, settle: false);
        checkScreen(t, 'biblioteek');
        await checkKeyboard(t, 'biblioteek');
        await t.tap(find.byKey(const ValueKey('ctl.biblioteek.view')));
        await t.tap(find.text('Sang'));
        await t.pump();
        checkScreen(t, 'biblioteek');
      });

      testWidgets('skulp', (t) async {
        final tc = testController();
        await pump(
          t,
          Shell(
            store: tc.$2,
            jobs: tc.$3,
            list: () async => [],
            settings: AppSettings.load(tc.$2.root)..setupDone = true,
          ),
          settle: false,
        );
        final keys = controlKeys(t, find.byType(Scaffold).first);
        expect(keys.where((k) => k == null), isEmpty);
        expect(keys.where((k) => k!.startsWith('ctl.skulp.')), hasLength(6));
      });
    });
  }
}

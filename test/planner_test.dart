import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/models.dart';
import 'package:preekverwerker/core/planner.dart';
import 'package:preekverwerker/core/tools.dart';

SermonPlan okPlan() => SermonPlan(
  sermonStart: 23 * 60,
  sermonEnd: 52 * 60,
  title: 'Uit die oorvloed van die hart',
  description: 'Tema: x',
  shorts: [Short(start: 1500, end: 1560, title: 'a')],
);

void main() {
  const duration = 3728.0;

  test('validate accepts a good plan', () {
    expect(validate(okPlan(), duration), isEmpty);
  });

  test('validate reports Afrikaans errors', () {
    final p = okPlan()
      ..sermonEnd = 23 * 60 + 180
      ..title = 'x' * 101
      ..description = 'y' * 5001
      ..shorts = [
        Short(start: 100, end: 110, title: 'buite'),
        Short(start: 1500, end: 1510, title: 'kort'),
      ];
    final e = validate(p, duration);
    expect(e.length, 3, reason: e.join('\n'));
    expect(e.any((m) => m.contains('preek')), isTrue);
    expect(validate(okPlan()..sermonEnd = duration + 5, duration), isNotEmpty);
    expect(validate(okPlan()..sermonStart = -1, duration), isNotEmpty);
  });

  test('shortFault separates Short errors from plan errors', () {
    final p = okPlan();
    Short sh(double a, double b) => Short(start: a, end: b, title: 't');
    expect(shortFault(sh(1500, 1560), p), isNull);
    expect(shortFault(sh(1500, 1595), p), ShortFault.tooLong);
    expect(shortFault(sh(1500, 1510), p), ShortFault.tooShort);
    expect(shortFault(sh(100, 160), p), ShortFault.outside);
    expect(shortFault(sh(3100, 3160), p), ShortFault.outside);
    p.shorts.add(sh(1500, 1595));
    expect(validate(p, duration), isEmpty);
  });

  test('parseTime handles mm:ss, h:mm:ss and numbers', () {
    expect(parseTime('23:04'), 1384);
    expect(parseTime('1:02:03'), 3723);
    expect(parseTime(75), 75);
    expect(parseTime('x'), isNull);
  });

  test(
    'plan() parses the stubbed Ollama JSON and sends the expected request',
    () async {
      Map<String, dynamic>? seen;
      final planner = Planner(
        chat: (body) async {
          seen = body;
          return {
            'message': {
              'content': jsonEncode({
                'sermonStart': '23:00',
                'sermonEnd': '52:00',
                'title': 'T',
                'description': 'D',
                'shorts': [
                  {'start': '25:00', 'end': '26:00', 'title': 'S'},
                ],
              }),
            },
          };
        },
      );
      final p = await planner.plan(
        compactText: '[23:00] hallo',
        duration: duration,
        originalDescription: 'Psalm 1',
      );
      expect(p.sermonStart, 1380);
      expect(p.shorts.single.end, 1560);
      expect(seen!['model'], 'qwen3:8b');
      expect(seen!['stream'], false);
      expect(seen!['think'], true);
      expect(seen!['options']['num_ctx'], 16384);
      expect(seen!['format'], isA<Map>());
      expect(jsonEncode(seen!['messages']), contains('Psalm 1'));
    },
  );

  test(
    'plan() keeps a Short over 90 s unchanged; the plan stays valid',
    () async {
      final planner = Planner(
        chat: (_) async => {
          'message': {
            'content': jsonEncode({
              'sermonStart': '23:00',
              'sermonEnd': '52:00',
              'title': 'T',
              'description': 'D',
              'shorts': [
                {'start': '25:00', 'end': '27:02', 'title': 'lank'},
              ],
            }),
          },
        },
      );
      final p = await planner.plan(
        compactText: 'x',
        duration: 3728,
        originalDescription: '',
      );
      expect(p.shorts.single.end - p.shorts.single.start, 122);
      expect(shortFault(p.shorts.single, p), ShortFault.tooLong);
    },
  );

  test('plan() throws PlanException for an invalid plan', () async {
    final planner = Planner(
      chat: (_) async => {
        'message': {
          'content': jsonEncode({
            'sermonStart': '00:10',
            'sermonEnd': '03:10',
            'title': 'T',
            'description': 'D',
            'shorts': <dynamic>[],
          }),
        },
      },
    );
    expect(
      planner.plan(
        compactText: 'x',
        duration: duration,
        originalDescription: '',
      ),
      throwsA(isA<PlanException>()),
    );
  });

  test(
    'loadOrPlan reads an existing plan.json without calling Ollama',
    () async {
      final dir = Directory.systemTemp.createTempSync('plan');
      File('${dir.path}/plan.json')
          .writeAsStringSync(jsonEncode(okPlan().toJson()));
      final planner = Planner(
        chat: (_) async => throw StateError('must not be called'),
      );
      final p = await planner.loadOrPlan(
        dir,
        compactText: 'x',
        duration: duration,
        originalDescription: '',
      );
      expect(p.title, 'Uit die oorvloed van die hart');
      dir.deleteSync(recursive: true);
    },
  );

  test(
    'loadOrPlan: a cancel before Ollama answers writes no plan.json',
    () async {
      final dir = Directory.systemTemp.createTempSync('cancelplan');
      final cancel = Completer<void>();
      final planner = Planner(
        chat: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return {
            'message': {
              'content': jsonEncode({
                'sermonStart': '00:10',
                'sermonEnd': '30:00',
                'title': 'T',
                'description': 'D',
                'shorts': <dynamic>[],
              }),
            },
          };
        },
      );
      final f = planner.loadOrPlan(
        dir,
        compactText: 'x',
        duration: duration,
        originalDescription: '',
        cancel: cancel.future,
      );
      cancel.complete();
      await expectLater(f, throwsA(isA<JobCancelled>()));
      expect(File('${dir.path}/$kPlanFile').existsSync(), isFalse);
      dir.deleteSync(recursive: true);
    },
  );
}

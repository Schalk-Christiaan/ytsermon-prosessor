import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/channel.dart';
import 'package:preekverwerker/core/service_info.dart';

const _sast = Duration(hours: 2);

Map<String, dynamic> _info(String id) =>
    jsonDecode(File('test/fixtures/info/$id.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  test('YWz5gf0onjk: 15 Nov (not the upload day 16), evening, fields', () {
    final i = ServiceInfo.fromInfo(_info('YWz5gf0onjk'), offset: _sast);
    expect(i.date, '2026-11-15');
    expect(i.evening, isTrue);
    expect(i.theme, 'Uit die oorvloed van die hart praat die mond');
    expect(i.scripture, 'Mattheus 12:22-37');
    expect(i.focus, 'Mattheus 12:34,36,37');
    expect(i.creed, 'NGB Artikel 37');
    expect(i.psalms, [33, 42, 46]);
  });

  test(
    '6s_FFatG0so: 15 Nov morning; "Skrifgedeelte" counts as the reading',
    () {
      final i = ServiceInfo.fromInfo(_info('6s_FFatG0so'), offset: _sast);
      expect(i.date, '2026-11-15');
      expect(i.evening, isFalse);
      expect(i.scripture, 'Efesiërs 6:10-20. Mattheus 26:31-46');
      expect(i.creed, isNull);
      expect(i.psalms, [138, 69, 30, 84]);
    },
  );

  test('labels without a colon (uub_CnO7bd0)', () {
    final i = ServiceInfo.fromInfo(_info('uub_CnO7bd0'), offset: _sast);
    expect(i.theme, 'Die goeie boodskap van die nagmaal');
    expect(i.scripture, '2 Kon 6 en 7');
    expect(i.focus, '2 Kon 7:9');
    expect(i.psalms, [107, 146, 9]);
  });

  test('uploadDate is the service day, not the upload day', () {
    // Local time of the test machine decides; SAST machines (and CI with TZ set) give the 15th.
    final j = _info('YWz5gf0onjk');
    expect(j['upload_date'], '20261116');
    expect(serviceStart(j, offset: _sast)!.day, 15);
    if (DateTime.now().timeZoneOffset == _sast) {
      expect(j.uploadDate, '2026-11-15');
    }
  });

  test('no timestamps: falls back to upload_date, morning', () {
    final i = ServiceInfo.fromInfo({
      'upload_date': '20261108',
      'description': '',
    });
    expect(i.date, '2026-11-08');
    expect(i.evening, isFalse);
    expect(i.theme, isNull);
  });

  test('json round trip', () {
    final i = ServiceInfo.fromInfo(_info('YWz5gf0onjk'), offset: _sast)
      ..label = 'doop';
    final r = ServiceInfo.fromJson(jsonDecode(jsonEncode(i.toJson())));
    expect(
      [r.date, r.evening, r.label, r.psalms],
      [
        i.date,
        true,
        "doop",
        [33, 42, 46],
      ],
    );
  });
}

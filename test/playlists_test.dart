import 'package:flutter_test/flutter_test.dart';
import 'package:preekverwerker/core/playlists.dart';
import 'package:preekverwerker/core/store.dart';

void main() {
  test('bookFrom takes the book name before the chapter', () {
    expect(bookFrom('1 Korinthiërs 13:1-13'), '1 Korinthiërs');
    expect(bookFrom('Mattheus 12:22-37'), 'Mattheus');
    expect(bookFrom('Psalm 42'), 'Psalm');
    expect(bookFrom(null), isNull);
    expect(bookFrom(''), isNull);
  });

  test('playlistFor uses the first rule that yields a name', () {
    final s = Sermon(
      'a',
      't',
      1,
      date: '2026-11-15',
      scripture: 'Efesiërs 6:10-20',
    );
    expect(playlistFor(s, ['book', 'year']), 'Efesiërs');
    expect(playlistFor(s, ['year', 'book']), 'Preke 2026');
    expect(playlistFor(Sermon('b', 't', 1), ['book', 'year']), isNull);
    expect(playlistFor(s, []), isNull);
  });

  test('describe fills the template and caps at 5000', () {
    expect(
      describe(
        '{beskrywing}\nSkriflesing: {skriflesing}\n{datum} {tema}',
        tema: 'Genade',
        scripture: 'Rom 5',
        date: '2026-11-15',
        description: 'Oor genade.',
      ),
      'Oor genade.\nSkriflesing: Rom 5\n2026-11-15 Genade',
    );
    expect(
      describe(
        '{beskrywing}',
        tema: '',
        scripture: null,
        date: null,
        description: 'x' * 6000,
      ).length,
      5000,
    );
  });
}

// @stelsel playlists
//   soort: module
//   wanneer: by oplaai en in die Snitlyste-skerm se voorskou
//   groep: core | Kern
//   skryf: —
//   doel: snitlysnaam per preek uit reëls (Bybelboek, jaar) en die YouTube-beskrywing uit die jabloon
//   status: klaar
//   bewys: 7236634
import 'store.dart';

/// The Bible book of a reading: everything before the first chapter number (`1 Korinthiërs 13:1` → `1 Korinthiërs`).
String? bookFrom(String? scripture) {
  final m = RegExp(
    r'^((?:\d\s*)?\p{L}[\p{L}\s.]*?)\s+\d',
    unicode: true,
  ).firstMatch(scripture?.trim() ?? '');
  return m?.group(1)?.trim();
}

/// Playlist name from the first rule in [rules] that yields one; null = no playlist.
String? playlistFor(Sermon s, List<String> rules) {
  for (final r in rules) {
    final name = switch (r) {
      'book' => bookFrom(s.scripture),
      'year' => s.date == null ? null : 'Preke ${s.date!.substring(0, 4)}',
      _ => null,
    };
    if (name != null) return name;
  }
  return null;
}

/// Fills `{tema}`, `{skriflesing}`, `{datum}` and `{beskrywing}`; YouTube allows 5000 characters.
String describe(
  String template, {
  required String tema,
  required String? scripture,
  required String? date,
  required String description,
}) {
  final s = template
      .replaceAll('{tema}', tema)
      .replaceAll('{skriflesing}', scripture ?? '')
      .replaceAll('{datum}', date ?? '')
      .replaceAll('{beskrywing}', description);
  return s.length > 5000 ? s.substring(0, 5000) : s;
}

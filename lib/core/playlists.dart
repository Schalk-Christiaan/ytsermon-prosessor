// @stelsel playlists
//   soort: module
//   wanneer: by oplaai en in die Snitlyste-skerm se voorskou
//   groep: core | Kern
//   skryf: —
//   doel: snitlysnaam per preek uit reëls (Bybelboek, jaar), Schalk se eie snitlysgroepe (naam, beskrywing, preek-ID's) en die YouTube-beskrywing uit die jabloon
//   status: bou
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

/// A playlist Schalk makes himself (e.g. "Advent 2026"); a sermon may be in several.
class PlaylistGroup {
  PlaylistGroup(this.id, this.name, {this.description = ''});

  final String id;
  String name, description;

  /// IDs of the sermons in the group.
  final List<String> sermons = [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'sermons': sermons,
  };

  /// Null when [j] is not a usable group (missing id or name); a bad `sermons` list is empty.
  static PlaylistGroup? fromJson(Object? j) {
    if (j is! Map || j['id'] is! String || j['name'] is! String) return null;
    return PlaylistGroup(
        j['id'] as String,
        j['name'] as String,
        description: j['description'] as String? ?? '',
      )
      ..sermons.addAll(
        j['sermons'] is List
            ? (j['sermons'] as List).whereType<String>()
            : const [],
      );
  }
}

/// All playlists a sermon goes into: the rule's name, then its groups, without duplicates.
List<String> playlistsFor(
  Sermon s,
  List<String> rules,
  List<PlaylistGroup> groups,
) => {
  ?playlistFor(s, rules),
  for (final g in groups)
    if (g.sermons.contains(s.id)) g.name,
}.toList();

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

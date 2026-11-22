// @stelsel suggest
//   soort: module
//   wanneer: Schalk vra "Stel preke voor" by 'n snitlysgroep; ná 'n render (stap 15)
//   groep: core | Kern
//   skryf: —
//   doel: vra Ollama (qwen3:8b) watter preke by 'n snitlysgroep pas, uit titel, Skriflesing, datum en die begin van die transkripsie; antwoord is JSON, onbekende ID's word weggelaat, een oproep op versoek
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'captions.dart';
import 'planner.dart';
import 'playlists.dart';
import 'store.dart';
import 'tools.dart';

export 'planner.dart' show ChatFn;

/// What Ollama sees of one sermon.
class Brief {
  Brief(this.id, this.title, this.scripture, this.date, this.excerpt);
  final String id, title, excerpt;
  final String? scripture, date;
}

/// A suggested sermon with Ollama's short reason (may be empty).
typedef Suggestion = ({String id, String reason});

/// Ollama answered, but not with anything usable.
class SuggestException implements Exception {
  SuggestException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Words of transcript per sermon: 500 for few sermons, fewer when many share one context window.
int wordBudget(int sermons) =>
    (8000 ~/ (sermons < 1 ? 1 : sermons)).clamp(40, 500);

String cutWords(String text, int n) {
  final w = text.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
  return w.length <= n ? w.join(' ') : w.take(n).join(' ');
}

/// The brief of [s]: its first ~500 transcript words when the captions are on disk.
Brief briefOf(Sermon s, Directory root) {
  var excerpt = '';
  final f = File(p.join(root.path, s.id, '${s.id}.af-orig.json3'));
  if (f.existsSync()) {
    try {
      excerpt = cutWords(
        parseJson3(f.readAsStringSync()).map((g) => g.text).join(' '),
        500,
      );
    } on Object {
      // damaged captions: the title and reading still say something
    }
  }
  return Brief(s.id, s.title, s.scripture, s.date, excerpt);
}

const _groupPrompt = '''Jy help 'n Gereformeerde kerk om sy preke in snitlyste (reekse) te ordent.
Jy kry die naam en beskrywing van 'n snitlys, en 'n lys preke (ID, titel, Skriflesing, datum, begin van die transkripsie).
Kies net die preke wat werklik by die snitlys se naam en beskrywing pas, en gee by elk 'n kort rede in Afrikaans (hoogstens 12 woorde). Gebruik net ID's uit die lys. Pas niks, gee 'n leë lys. Antwoord net met JSON volgens die skema.''';

/// Asks Ollama which of [candidates] fit [group]; sermons already in the group are not offered.
Future<List<Suggestion>> suggestSermons(
  PlaylistGroup group,
  List<Brief> candidates, {
  ChatFn? chat,
}) async {
  final pool = [
    for (final b in candidates)
      if (!group.sermons.contains(b.id)) b,
  ];
  if (pool.isEmpty) return const [];
  final n = wordBudget(pool.length);
  final list = [
    for (final b in pool)
      'ID: ${b.id}\nTitel: ${b.title}\nSkriflesing: ${b.scripture ?? '-'}\nDatum: ${b.date ?? '-'}\nTeks: ${cutWords(b.excerpt, n)}',
  ].join('\n\n');
  final res = await (chat ?? ollamaChat)({
    'model': kModel,
    'stream': false,
    'think': false,
    'format': {
      'type': 'object',
      'properties': {
        'suggestions': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
              'reason': {'type': 'string'},
            },
            'required': ['id'],
          },
        },
      },
      'required': ['suggestions'],
    },
    'options': {
      'num_ctx': 16384,
      'temperature': 0,
      'num_predict': 1024,
      'seed': 1,
    },
    'messages': [
      {'role': 'system', 'content': _groupPrompt},
      {
        'role': 'user',
        'content':
            'Snitlys: ${group.name}\nBeskrywing: ${group.description}\n\nPreke:\n\n$list',
      },
    ],
  });
  final Object? j;
  try {
    j = jsonDecode(res['message']['content'] as String);
  } on Object {
    throw SuggestException('Die KI het nie \'n bruikbare antwoord gegee nie.');
  }
  final known = {for (final b in pool) b.id};
  return [
    if (j is Map && j['suggestions'] is List)
      for (final s in j['suggestions'] as List)
        if (s is Map && known.remove(s['id']))
          (id: s['id'] as String, reason: '${s['reason'] ?? ''}'.trim()),
  ];
}

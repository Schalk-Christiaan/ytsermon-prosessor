// @stelsel suggest
//   soort: module
//   wanneer: Schalk vra "Stel preke voor" by 'n snitlysgroep; een keer ná elke klaar snit
//   groep: core | Kern
//   skryf: <werkmap>/settings.json | net as Schalk 'n voorstel aanvaar
//   doel: vra Ollama (qwen3:8b) watter preke by 'n snitlysgroep pas, uit titel, Skriflesing, datum en die begin van die transkripsie; antwoord is JSON, onbekende ID's word weggelaat; GroupSuggestions vra ná 'n klaar snit (sonder dat die render wag) by watter groepe die preek pas en hoogstens een nuwe groepnaam, en hou dit in die geheue tot Aanvaar of Ignoreer
//   status: bou
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:path/path.dart' as p;

import 'captions.dart';
import 'planner.dart';
import 'jobs.dart';
import 'playlists.dart';
import 'settings.dart';
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

/// Where one sermon might go: existing groups (by ID) and at most one new group name.
typedef SermonSuggestion = ({List<String> groupIds, String? newName});

const _sermonPrompt = '''Jy help 'n Gereformeerde kerk om sy preke in snitlyste (reekse) te ordent.
Jy kry een preek (titel, Skriflesing, datum, begin van die transkripsie), die bestaande snitlyste (ID, naam, beskrywing) en die titels van ander preke.
1. "groups": die ID's van die bestaande snitlyste waarby die preek werklik pas (leeg as geeneen).
2. "new_name": net as die preek saam met ander preke 'n duidelike reeks of tema vorm wat nog nie 'n snitlys het nie (bv. 'n reeks wat in die titels herhaal), 'n kort naam vir 'n nuwe snitlys; anders 'n leë string.
Gebruik net ID's uit die lys. Antwoord net met JSON volgens die skema.''';

/// One Ollama call: which of [groups] fit [b] and whether to start a new group (names that already exist are dropped).
Future<SermonSuggestion> suggestGroupsFor(
  Brief b,
  List<PlaylistGroup> groups,
  List<String> otherTitles, {
  ChatFn? chat,
}) async {
  final res = await (chat ?? ollamaChat)({
    'model': kModel,
    'stream': false,
    'think': false,
    'format': {
      'type': 'object',
      'properties': {
        'groups': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'new_name': {'type': 'string'},
      },
      'required': ['groups', 'new_name'],
    },
    'options': {
      'num_ctx': 8192,
      'temperature': 0,
      'num_predict': 256,
      'seed': 1,
    },
    'messages': [
      {'role': 'system', 'content': _sermonPrompt},
      {
        'role': 'user',
        'content':
            'Preek: ${b.title}\nSkriflesing: ${b.scripture ?? '-'}\nDatum: ${b.date ?? '-'}\nTeks: ${cutWords(b.excerpt, 300)}\n\nSnitlyste:\n${[for (final g in groups) '${g.id}: ${g.name} - ${g.description}'].join('\n')}\n\nAnder preke:\n${otherTitles.take(60).join('\n')}',
      },
    ],
  });
  final Object? j;
  try {
    j = jsonDecode(res['message']['content'] as String);
  } on Object {
    throw SuggestException('Die KI het nie \'n bruikbare antwoord gegee nie.');
  }
  if (j is! Map)
    throw SuggestException('Die KI het nie \'n bruikbare antwoord gegee nie.');
  final known = {for (final g in groups) g.id};
  final ids = [
    for (final id in (j['groups'] is List ? j['groups'] as List : const []))
      if (known.remove(id)) id as String,
  ];
  final name = '${j['new_name'] ?? ''}'.trim();
  final fresh =
      name.isEmpty ||
      name.length > 60 ||
      groups.any((g) => g.name.toLowerCase() == name.toLowerCase());
  return (groupIds: ids, newName: fresh ? null : name);
}

/// The suggestions made after a render, waiting for Aanvaar or Ignoreer on the Werk screen.
class GroupSuggestions extends ChangeNotifier {
  GroupSuggestions(this.settings, this.store, {this.chat});
  final AppSettings settings;
  final SermonStore store;
  final ChatFn? chat;

  /// By sermon ID; in memory only (a restart forgets them).
  final pending = <String, SermonSuggestion>{};
  final _asked = <String>{};
  final _handled = <Job>{};
  final _inflight = <Future<void>>[];

  /// Completes when every request started so far is done.
  Future<void> get settled => Future.wait(List.of(_inflight));

  /// Display names of a suggestion: the groups, then the new one.
  List<String> names(SermonSuggestion s) => [
    for (final id in s.groupIds)
      ?settings.groups.where((g) => g.id == id).firstOrNull?.name,
    ?s.newName,
  ];

  /// Starts asking for every cut that finishes from now on; never makes the render wait.
  void attach(JobQueue jobs) {
    _handled.addAll(jobs.jobs.where((j) => j.status == JobStatus.klaar));
    jobs.addListener(() {
      for (final j in jobs.jobs) {
        if (j.kind == JobKind.cut &&
            j.status == JobStatus.klaar &&
            _handled.add(j)) {
          final f = request(j.sermon);
          _inflight.add(f);
          f.whenComplete(() => _inflight.remove(f));
        }
      }
    });
  }

  /// Asks once per sermon; any failure just means no suggestion.
  Future<void> request(String sermonId) async {
    final s = store.byId(sermonId);
    if (s == null || !_asked.add(sermonId)) return;
    try {
      final r = await suggestGroupsFor(
        briefOf(s, store.root),
        [
          for (final g in settings.groups)
            if (!g.sermons.contains(sermonId)) g,
        ],
        [
          for (final o in store.sorted)
            if (o.id != sermonId) o.title,
        ],
        chat: chat,
      );
      if (r.groupIds.isEmpty && r.newName == null) return;
      pending[sermonId] = r;
      notifyListeners();
    } on Object {
      // Ollama off or nonsense: no suggestion, nothing breaks; a later render may ask again
      _asked.remove(sermonId);
    }
  }

  /// Files the sermon in the suggested groups and creates the new one.
  void accept(String sermonId) {
    final s = pending.remove(sermonId);
    if (s == null) return;
    for (final g in settings.groups) {
      if (s.groupIds.contains(g.id) && !g.sermons.contains(sermonId)) {
        g.sermons.add(sermonId);
      }
    }
    if (s.newName != null) {
      settings.groups.add(
        PlaylistGroup(
          DateTime.now().microsecondsSinceEpoch.toString(),
          s.newName!,
        )..sermons.add(sermonId),
      );
    }
    settings.save();
    notifyListeners();
  }

  void ignore(String sermonId) {
    if (pending.remove(sermonId) != null) notifyListeners();
  }
}

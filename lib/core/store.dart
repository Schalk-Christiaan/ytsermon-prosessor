// @stelsel store
//   soort: module
//   wanneer: by begin (laai almal) en by elke toestandsverandering van 'n preek
//   groep: core | Kern
//   skryf: <werkmap>/<id>/sermon.json | atomies (.tmp, dan hernoem)
//   doel: elke diens as Sermon met toestand wat herbegin oorleef; voeg die kanaallys by
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'channel.dart';
import 'planner.dart';

/// The reading from a `Skriflesing: Mattheus 12:22-37` line in [description]; null if absent.
String? scriptureFrom(String description) => RegExp(
  r'^Skriflesing:\s*(.+)$',
  multiLine: true,
  caseSensitive: false,
).firstMatch(description)?.group(1)?.trim();

/// Writes [json] to [f] atomically (`.tmp`, then rename), creating the folder.
void writeJson(File f, Object? json) {
  f.parent.createSync(recursive: true);
  File('${f.path}.tmp')
    ..writeAsStringSync(jsonEncode(json))
    ..renameSync(f.path);
}

/// Where a sermon is in its life: new, planned, approved, cut, uploaded, failed or skipped.
enum SermonState { nuut, beplan, goedgekeur, gesny, opgelaai, fout, oorgeslaan }

/// One service on the channel with its processing state.
class Sermon {
  Sermon(
    this.id,
    this.title,
    this.duration, {
    this.date,
    this.scripture,
    this.state = SermonState.nuut,
    this.error,
    this.outputs = const [],
    this.uploads = const {},
    this.playlist,
    this.order = _unlisted,
  });
  static const _unlisted = 1 << 30;

  final String id;
  String title;
  double duration;

  /// `JJJJ-MM-DD`; null until `fetchMeta` has run (the flat channel list has no date).
  String? date;

  /// The `Skriflesing:` line of the YouTube description, once known.
  String? scripture;
  SermonState state;
  String? error;
  List<String> outputs;

  /// Uploaded output file → YouTube video ID (a retried upload job skips these).
  Map<String, String> uploads;

  /// The playlist the uploaded sermon was added to.
  String? playlist;

  /// Position in the channel list (0 = newest).
  int order;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'duration': duration,
    'date': date,
    'scripture': scripture,
    'state': state.name,
    'error': error,
    'outputs': outputs,
    'uploads': uploads,
    'playlist': playlist,
    'order': order,
  };

  factory Sermon.fromJson(Map<String, dynamic> j) => Sermon(
    j['id'] as String,
    j['title'] as String,
    (j['duration'] as num).toDouble(),
    date: j['date'] as String?,
    scripture: j['scripture'] as String?,
    state: SermonState.values.byName(j['state'] as String),
    error: j['error'] as String?,
    outputs: [...?(j['outputs'] as List?)?.cast<String>()],
    uploads: {...?(j['uploads'] as Map?)?.cast<String, String>()},
    playlist: j['playlist'] as String?,
    order: j['order'] as int? ?? _unlisted,
  );
}

/// All sermons under the work root; notifies on every change so lists rebuild.
class SermonStore extends ChangeNotifier {
  SermonStore(this.root);
  final Directory root;
  final _byId = <String, Sermon>{};

  Sermon? byId(String id) => _byId[id];

  /// Newest first (channel list order).
  List<Sermon> get sorted =>
      _byId.values.toList()..sort((a, b) => a.order.compareTo(b.order));

  File _file(String id) => File(p.join(root.path, id, 'sermon.json'));

  /// Reads every `<id>/sermon.json` once. A phase 1 folder with only `plan.json` becomes `beplan`.
  void load() {
    _byId.clear();
    if (!root.existsSync()) return;
    for (final d in root.listSync().whereType<Directory>()) {
      final id = p.basename(d.path);
      final hasPlan = File(p.join(d.path, kPlanFile)).existsSync();
      final f = _file(id);
      Sermon? s;
      if (f.existsSync()) {
        s = Sermon.fromJson(jsonDecode(f.readAsStringSync()));
      } else if (hasPlan) {
        final info = File(p.join(d.path, '$id.info.json'));
        final j = info.existsSync()
            ? jsonDecode(info.readAsStringSync()) as Map<String, dynamic>
            : <String, dynamic>{};
        s = Sermon(
          id,
          '${j['title'] ?? id}',
          (j['duration'] as num?)?.toDouble() ?? 0,
          date: j.containsKey('upload_date') ? j.uploadDate : null,
          scripture: scriptureFrom(j.descriptionText),
        );
      }
      if (s == null) continue;
      if (hasPlan && s.state == SermonState.nuut) s.state = SermonState.beplan;
      _byId[id] = s;
    }
  }

  /// Writes `sermon.json` atomically (`.tmp`, then rename) and notifies.
  void save(Sermon s) {
    _write(s);
    notifyListeners();
  }

  void _write(Sermon s) {
    _byId[s.id] = s;
    writeJson(_file(s.id), s.toJson());
  }

  /// Adds the listed channel entries: new IDs become `nuut` (returned), known ones keep their state.
  List<Sermon> merge(List<ChannelItem> listed) {
    final fresh = <Sermon>[];
    for (var i = 0; i < listed.length; i++) {
      final it = listed[i];
      var s = _byId[it.id];
      if (s == null) {
        fresh.add(s = Sermon(it.id, it.title, it.duration));
      } else if (s.order == i) {
        continue;
      }
      s.order = i;
      _write(s);
    }
    notifyListeners();
    return fresh;
  }
}

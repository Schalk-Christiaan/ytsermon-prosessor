// @stelsel planner
//   soort: module
//   wanneer: ná captions, een Ollama-oproep per preek
//   groep: core | Kern
//   skryf: werkmap/<id>/plan.json, analysis.json | die plan; die etikette van die spraakblokke, die liedere en die diens-soort
//   doel: laat qwen3:8b net teks skryf (Shorts, titel, beskrywing) binne die snit wat findBounds reeds bepaal het (geen grense van die KI nie); analyse() benoem die spraakblokke en liedere (nooit tye); validate() toets die plan, shortFault() elke Short apart; berg plan.json op
//   status: bou
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'captions.dart';
import 'models.dart';
import 'tools.dart';

/// Longest allowed Short in seconds.
const kMaxShort = 90;

const kPlanFile = 'plan.json';

/// Planning failed in a way the user can act on (no captions, Ollama gave nonsense).
class PlanException implements Exception {
  PlanException(this.errors, {this.plan});
  final List<String> errors;

  /// The rejected plan, when the JSON parsed (lets the UI offer manual correction).
  final SermonPlan? plan;
  @override
  String toString() => errors.join('; ');
}

typedef ChatFn = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> body,
);

const _systemPrompt =
    '''Jy help 'n Gereformeerde kerk om opnames van sy kerkdienste te verwerk.
Jy kry die teks van die snit as reëls "[mm:ss] teks" (hoogstens elke 30 sekondes 'n reël), en die tye waar die snit van die preek begin en eindig. Die snit is reeds bepaal en sluit die gebede voor en ná die preek in; jy verander dit nie.

Doen die volgende:
1. Kies 1 tot 3 SHORTS binne die snit, elk 'n volledige gedagte. Elke Short moet tussen 30 en 80 sekondes lank wees (eindtyd minus begintyd): gebruik die begin van een reël as begintyd en die begin van die volgende of oor-volgende reël as eindtyd (60 sekondes is 'n goeie lengte).
2. Skryf 'n TITEL (die tema van die preek, hoogstens 100 karakters).
3. Skryf 'n BESKRYWING in Afrikaans met reëls "Tema: …", "Skriflesing: …", "Fokusgedeelte: …", dan 3 tot 4 sinne opsomming, en laastens die psalms uit die oorspronklike beskrywing (as dit daar is). Hou die beskrywing onder 1500 karakters.

Gee tye as "mm:ss" soos in die onderskrifte. Antwoord net met JSON volgens die skema.''';

Map<String, dynamic> get _schema {
  const t = {'type': 'string'};
  return {
    'type': 'object',
    'properties': {
      'title': t,
      'description': t,
      'shorts': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {'start': t, 'end': t, 'title': t},
          'required': ['start', 'end', 'title'],
        },
      },
    },
    'required': ['title', 'description', 'shorts'],
  };
}

/// Seconds from `mm:ss`, `h:mm:ss` or a number; null if unparseable.
double? parseTime(Object? v) {
  if (v is num) return v.toDouble();
  if (v is! String) return null;
  final parts = v.trim().split(':').map(double.tryParse).toList();
  if (parts.isEmpty || parts.length > 3 || parts.contains(null)) return null;
  return parts.fold<double>(0, (a, b) => a * 60 + b!);
}

/// Checks the plan itself (sermon bounds, title, description); returns Afrikaans messages (empty = valid).
/// Short errors are not plan errors: see [shortFault].
List<String> validate(SermonPlan plan, double duration) {
  final e = <String>[];
  final len = plan.sermonEnd - plan.sermonStart;
  if (plan.sermonStart < 0 ||
      plan.sermonEnd > duration ||
      plan.sermonStart >= plan.sermonEnd) {
    e.add('Die preek se grense lê buite die video.');
  } else if (len < 15 * 60 || len > 90 * 60) {
    e.add(
      'Die preek is ${(len / 60).round()} min; dit moet tussen 15 en 90 min wees.',
    );
  }
  if (plan.title.isEmpty || plan.title.length > 100)
    e.add('Die titel moet 1 tot 100 karakters wees.');
  if (plan.description.length > 5000)
    e.add('Die beskrywing is langer as 5000 karakters.');
  return e;
}

/// Why a Short cannot be cut: outside the sermon, under 20 s or over 90 s.
enum ShortFault { outside, tooShort, tooLong }

/// Why a Short can't be cut (outside the sermon, or not 20-90 s); null = fine.
/// The plan stays valid: Hersien marks the Short instead (no truncation, no replan).
ShortFault? shortFault(Short s, SermonPlan plan) {
  if (s.start < plan.sermonStart || s.end > plan.sermonEnd || s.start >= s.end)
    return ShortFault.outside;
  final d = s.end - s.start;
  if (d < 20) return ShortFault.tooShort;
  return d > kMaxShort ? ShortFault.tooLong : null;
}

/// Writes plan.json into [dir]; called on every edit.
void savePlan(Directory dir, SermonPlan plan) => File(
  p.join(dir.path, kPlanFile),
).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(plan.toJson()));

/// One non-streaming `/api/chat` call to the local Ollama server.
Future<Map<String, dynamic>> ollamaChat(Map<String, dynamic> body) async {
  final c = HttpClient()..connectionTimeout = const Duration(seconds: 5);
  try {
    final req = await c.postUrl(ollamaBase().resolve('/api/chat'));
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode(body)));
    final res = await req.close();
    final text = await res.transform(utf8.decoder).join();
    if (res.statusCode != 200)
      throw HttpException('Ollama ${res.statusCode}: $text');
    return jsonDecode(text) as Map<String, dynamic>;
  } finally {
    c.close(force: true);
  }
}

const _analysisPrompt = '''Jy help 'n Gereformeerde kerk om opnames van sy kerkdienste te verwerk. Jy kry (1) die oorspronklike beskrywing, die spraakblokke van die diens in volgorde ("#nr [begintyd · duur] eerste woorde … laaste woorde"), (2) die musiekstukke (sang) met die woorde net daarvoor.

Doen die volgende:
1. Benoem die spraakblokke met hul nommers (#nr). Orde van 'n diens: gebed, aankondiging, seengroet, sang, gebed, skriflesing, preek, gebed, kollekte, sang, seën. Gee: gebed_voor (nommer van die laaste blok van die gebed direk voor die preek; die predikant bid, begin gewoonlik met "Kom ons bid" of "Onse Vader" en eindig op Amen), preek_van en preek_tot (eerste en laaste blok van die preek self, ook sy inleiding en slot; gewoonlik 20 tot 50 minute), gebed_na (nommer van die blok wat die gebed direk ná die preek met "Amen" afsluit; 'n kort "Kom ons dank saam" of "Laat ons bid" is net die aanloop, die gebed self is die volgende blok wat op Amen eindig); en lyste nommers: gebede (alle ander gebede), skriflesing (voorlees uit die Bybel), geloofsbelydenis (die Apostoliese geloofsbelydenis "Ek glo in God die Vader, die Almagtige … Amen" is NOOIT 'n gebed nie), aankondigings (verwelkoming, kerknuus, lied aankondig), kollekte, seen (die seën aan die einde). Gebruik 0 as iets nie in die diens voorkom nie.
2. Vir elke musiekstuk: die naam van die lied soos dit net daarvoor aangekondig word (bv. "Psalm 33"); as dit nie genoem word nie, 'n leë string.
3. diens: nagmaal, doop, kategismus, belydenis, feesdag, of "geen" as dit 'n gewone diens is.

Jy kies nooit grense of tye van die preek nie; jy benoem net. Antwoord net met JSON volgens die skema.''';

const _labelLists = {
  'gebede': BlockLabel.gebed,
  'skriflesing': BlockLabel.skriflesing,
  'geloofsbelydenis': BlockLabel.geloofsbelydenis,
  'aankondigings': BlockLabel.aankondiging,
  'kollekte': BlockLabel.kollekte,
  'seen': BlockLabel.seen,
};

Map<String, dynamic> _analysisSchema() {
  const t = {'type': 'string'};
  const n = {'type': 'integer'};
  const nrs = {'type': 'array', 'maxItems': 6, 'items': n};
  return {
    'type': 'object',
    'properties': {
      // Small answer (block numbers), not one label per block: qwen3 8b
      // loops or drifts on a long label array. analyse() builds the labels.
      'gebed_voor': n,
      'preek_van': n,
      'preek_tot': n,
      'gebed_na': n,
      for (final k in _labelLists.keys) k: nrs,
      'songs': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'nr': {'type': 'integer'},
            'name': t,
          },
          'required': ['nr', 'name'],
        },
      },
      'service': t,
    },
    'required': [
      'gebed_voor',
      'preek_van',
      'preek_tot',
      'gebed_na',
      ..._labelLists.keys,
      'songs',
      'service',
    ],
  };
}

/// Service labels the AI may give besides "geen".
const kServiceLabels = [
  'nagmaal',
  'doop',
  'kategismus',
  'belydenis',
  'feesdag',
];

/// What the labelling call returned: labelled [blocks], the [songs] with names and the service label.
/// No times of the cut: those come from the labels (see `findBounds`). Title, description and Shorts
/// stay with [Planner.plan]: one call with the whole caption text made qwen3 8b drift on the labels.
class Analysis {
  Analysis({required this.blocks, required this.songs, required this.service});
  final List<Block> blocks;
  final List<Song> songs;
  final String? service;
}

/// Work-folder file with the labelled blocks (start, end, label), the songs and the service label.
const kAnalysisFile = 'analysis.json';

/// Saves [a] to `<dir>/analysis.json`: what Hersien needs to mark prayers and songs on the timeline.
void saveAnalysis(Directory dir, Analysis a) =>
    File(p.join(dir.path, kAnalysisFile)).writeAsStringSync(
      jsonEncode({
        'blocks': [
          for (final b in a.blocks)
            {'start': b.start, 'end': b.end, 'label': b.label?.name},
        ],
        'songs': [for (final x in a.songs) x.toJson()],
        'service': a.service,
      }),
    );

/// A labelled span of the saved analysis.
typedef Labelled = ({double start, double end, BlockLabel label});

/// The saved analysis of the work folder [dir] (read once): labelled spans, songs and service label;
/// empty when the service was never analysed.
({List<Labelled> labels, List<Song> songs, String? service}) loadAnalysis(
  Directory dir,
) {
  final f = File(p.join(dir.path, kAnalysisFile));
  final j = f.existsSync()
      ? jsonDecode(f.readAsStringSync()) as Map<String, dynamic>
      : const <String, dynamic>{};
  return (
    labels: [
      for (final b in (j['blocks'] as List? ?? const []))
        (
          start: (b['start'] as num).toDouble(),
          end: (b['end'] as num).toDouble(),
          label: BlockLabel.values.asNameMap()[b['label']] ?? BlockLabel.ander,
        ),
    ],
    songs: [
      for (final x in (j['songs'] as List? ?? const []))
        Song.fromJson(x as Map<String, dynamic>),
    ],
    service: j['service'] as String?,
  );
}

String _excerpt(List<Word> w, int head, int tail) {
  final s = [for (final x in w) x.text];
  return s.length <= head + tail
      ? s.join(' ')
      : '${s.take(head).join(' ')} … ${s.skip(s.length - tail).join(' ')}';
}

/// The music stretches that count as songs: those after the first speech (what plays before is the
/// prelude), each with its number.
List<TimeBlock> songStretches(List<Block> blocks, List<TimeBlock> sound) => [
  for (final b in sound)
    if (b.kind == SegmentKind.music &&
        blocks.isNotEmpty &&
        b.start >= blocks.first.start)
      b,
];

/// Asks Ollama for the text of one [SermonPlan] per sermon (a single call, no retries); the cut itself is the given [bounds].
class Planner {
  Planner({ChatFn? chat}) : _chat = chat ?? ollamaChat;
  final ChatFn _chat;

  Future<SermonPlan> plan({
    required List<Block> blocks,
    required Bounds bounds,
    required double duration,
    required String originalDescription,
  }) async {
    final res = await _chat({
      'model': kModel,
      'stream': false,
      'think': false,
      'format': _schema,
      'options': {
        'num_ctx': 16384,
        'temperature': 0,
        'num_predict': 2048,
        'seed': 1,
      },
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content':
              'Duur van die video: ${duration.round()} s.\n\nOorspronklike beskrywing:\n$originalDescription\n\nDie snit: ${formatTime(bounds.start)} tot ${formatTime(bounds.end)}.\n\nTeks van die snit:\n${compact(blocks, bounds.start, bounds.end)}\n',
        },
      ],
    });
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(
        res['message']['content'] as String,
      ) as Map<String, dynamic>;
    } on Object {
      throw PlanException(['Die KI het nie geldige JSON gegee nie.']);
    }
    final shorts = <Short>[];
    for (final s in (j['shorts'] as List? ?? const [])) {
      final a = parseTime(s['start']), b = parseTime(s['end']);
      if (a != null && b != null)
        shorts.add(Short(start: a, end: b, title: '${s['title']}'));
    }
    final plan = SermonPlan(
      sermonStart: bounds.start,
      sermonEnd: bounds.end,
      title: '${j['title'] ?? ''}'.trim(),
      description: '${j['description'] ?? ''}'.trim(),
      shorts: shorts,
      doubt: bounds.reason,
    );
    final errors = validate(plan, duration);
    if (errors.isNotEmpty) throw PlanException(errors, plan: plan);
    return plan;
  }

  /// Loads `<dir>/plan.json` if present (never overwritten); otherwise plans and saves it.
  Future<SermonPlan> loadOrPlan(
    Directory dir, {
    required List<Block> blocks,
    required Bounds bounds,
    required double duration,
    required String originalDescription,
    Future<void>? cancel,
  }) async {
    final f = File(p.join(dir.path, kPlanFile));
    if (f.existsSync())
      return SermonPlan.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    // Ollama's HTTP call cannot be killed: when [cancel] fires its answer is dropped.
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    final plan = await this.plan(
      blocks: blocks,
      bounds: bounds,
      duration: duration,
      originalDescription: originalDescription,
    );
    if (cancelled) throw JobCancelled();
    savePlan(dir, plan);
    return plan;
  }

  /// One Ollama call: labels for every speech block, a name for every song, the service label and the
  /// text of the plan (title, description, Shorts). Sets [Block.label] on [blocks]; an unknown or missing
  /// label becomes `ander`. A song name that is a psalm missing from [psalms] (the description's list,
  /// when it has one) becomes null.
  // stap: diensindeling 4 KI-etikette | een Ollama-oproep sonder onderskrifte kry die blokke, liedere en beskrywing en gee net nommers terug (gebed voor en ná die preek); die blokke tussen die twee gebede word preek; die KI kies nooit tye nie
  Future<Analysis> analyse({
    required List<Block> blocks,
    required List<TimeBlock> sound,
    required double duration,
    required String originalDescription,
    List<int> psalms = const [],
  }) async {
    final stretches = songStretches(blocks, sound);
    final list = StringBuffer();
    for (var i = 0; i < blocks.length; i++) {
      final b = blocks[i];
      list.writeln(
        '#${i + 1} [${formatTime(b.start)} · ${(b.end - b.start).round()} s${isAmen(b.words.last.text) ? ' · eindig op Amen' : ''}] ${_excerpt(b.words, 40, 20)}',
      );
    }
    final songList = StringBuffer();
    for (var i = 0; i < stretches.length; i++) {
      final before = [
        for (final b in blocks)
          for (final w in b.words)
            if (w.start < stretches[i].start) w,
      ];
      songList.writeln(
        'Musiekstuk ${i + 1} [${formatTime(stretches[i].start)}–${formatTime(stretches[i].end)}], die woorde net daarvoor: ${_excerpt(before.length > 25 ? before.sublist(before.length - 25) : before, 25, 0)}',
      );
    }
    final res = await _chat({
      'model': kModel,
      'stream': false,
      'think': false,
      'format': _analysisSchema(),
      'options': {
        'num_ctx': 16384,
        'temperature': 0,
        'num_predict': 1024,
        'seed': 1,
      },
      'messages': [
        {'role': 'system', 'content': _analysisPrompt},
        {
          'role': 'user',
          'content':
              'Duur van die video: ${duration.round()} s.\n\nOorspronklike beskrywing:\n$originalDescription\n\nSpraakblokke:\n$list\nMusiekstukke:\n$songList',
        },
      ],
    });
    final Map<String, dynamic> j;
    try {
      j = jsonDecode(
        res['message']['content'] as String,
      ) as Map<String, dynamic>;
    } on Object {
      throw PlanException(['Die KI het nie geldige JSON gegee nie.']);
    }
    int nr(Object? v) => v is int ? v : 0;
    void mark(int i, BlockLabel l) {
      if (i >= 1 && i <= blocks.length) blocks[i - 1].label = l;
    }

    for (final b in blocks) {
      b.label = BlockLabel.ander;
    }
    for (final e in _labelLists.entries) {
      for (final i in (j[e.key] as List? ?? const [])) {
        mark(nr(i), e.value);
      }
    }
    for (var i = nr(j['preek_van']); i <= nr(j['preek_tot']); i++) {
      mark(i, BlockLabel.preek);
    }
    // Everything between the two framing prayers belongs to the sermon (reading,
    // creed and the like inside it stay preek: "volle preek" runs prayer to prayer).
    final voor = nr(j['gebed_voor']), na = nr(j['gebed_na']);
    if (voor > 0) {
      for (var i = voor + 1; i < na; i++) {
        mark(i, BlockLabel.preek);
      }
    }
    mark(voor, BlockLabel.gebed);
    mark(na, BlockLabel.gebed);
    // The closing blessing has fixed words; the AI calls it gebed or ander too often.
    for (final b in blocks.skip(na)) {
      if (_blessing.hasMatch(b.text.toLowerCase())) b.label = BlockLabel.seen;
    }
    final names = {
      for (final e in (j['songs'] as List? ?? const []))
        if (e is Map && e['nr'] is int) e['nr'] as int: '${e['name']}'.trim(),
    };
    final songs = [
      for (var i = 0; i < stretches.length; i++)
        Song(
          stretches[i].start,
          stretches[i].end,
          _songName(names[i + 1], psalms),
          i + 1,
        ),
    ];
    final service = '${j['service']}'.trim().toLowerCase();
    return Analysis(
      blocks: blocks,
      songs: songs,
      service: kServiceLabels.contains(service) ? service : null,
    );
  }
}

/// The Aaronic or apostolic blessing ("Die Here seën u en behoed u", "Die genade van onse Here …"),
/// also with caption slips like "seun" for "seën".
final _blessing = RegExp(
  r'seën u en behoed|u seën en u behoed|ontvang (nou )?(die|sy) se|genade van (onse|ons) here',
);

/// [name] as given by the AI, or null when empty or a psalm that the description's [psalms] do not list.
String? _songName(String? name, List<int> psalms) {
  if (name == null || name.isEmpty) return null;
  final n = RegExp(r'^Psalm\s+(\d+)', caseSensitive: false).firstMatch(name);
  if (n != null &&
      psalms.isNotEmpty &&
      !psalms.contains(int.parse(n.group(1)!))) {
    return null;
  }
  return name;
}

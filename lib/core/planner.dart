// @stelsel planner
//   soort: module
//   wanneer: ná captions, een Ollama-oproep per preek
//   groep: core | Kern
//   skryf: werkmap/<id>/plan.json
//   doel: laat qwen3:8b die gebed voor en ná die preek uit die kandidaat-gebede kies (snit = gebed tot gebed), plus Shorts, titel en beskrywing; validate() toets die plan, shortFault() elke Short apart; berg plan.json op
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
Jy kry die onderskrifte van die hele diens as reëls "[mm:ss] teks" (hoogstens elke 30 sekondes 'n reël; "[musiek]" is sang of musiek), en 'n genommerde lys KANDIDAAT-GEBEDE ("G1", "G2", …) met tye en die eerste en laaste woorde van elke gebed.

Die snit van die preek begin met 'n gebed en eindig met 'n gebed, en sluit albei gebede in.

Doen die volgende:
1. Vind die PREEK (die prediker se verkondiging ná die Skriflesing; dit eindig gewoonlik met "Amen" waarna die prediker sê "Kom ons dank saam"). Kies dan uit die kandidaat-gebede:
   - openingPrayer: die nommer van die LAASTE gebed VOOR die preek en sy Skriflesing (gewoonlik 'n lang gebed of voorbidding wat vir die prediking bid; daarna kom dikwels 'n psalm en die Skriflesing). Nie die geloofsbelydenis ("Almagtige Vader … 'n ewige lewe. Amen") of die seëngroet nie.
   - closingPrayer: die nommer van die EERSTE gebed NA die preek (die dankgebed, gewoonlik "Kom ons dank saam" of "Laat ons saam dank"). Nie 'n "Amen" binne die preek self nie.
2. Kies 1 tot 3 SHORTS binne die preek, elk 'n volledige gedagte. Elke Short moet tussen 30 en 80 sekondes lank wees (eindtyd minus begintyd): gebruik die begin van een reël as begintyd en die begin van die volgende of oor-volgende reël as eindtyd (60 sekondes is 'n goeie lengte).
3. Skryf 'n TITEL (die tema van die preek, hoogstens 100 karakters).
4. Skryf 'n BESKRYWING in Afrikaans met reëls "Tema: …", "Skriflesing: …", "Fokusgedeelte: …", dan 3 tot 4 sinne opsomming, en laastens die psalms uit die oorspronklike beskrywing (as dit daar is). Hou die beskrywing onder 1500 karakters.

Gee tye as "mm:ss" soos in die onderskrifte en gebede as nommers (1 vir G1). Antwoord net met JSON volgens die skema.''';

/// The numbered candidate list for the prompt: `G1 14:46–21:29 (6:43): "first" … "last"`.
String prayerList(List<Prayer> prayers) => [
  for (var i = 0; i < prayers.length; i++)
    'G${i + 1} ${formatTime(prayers[i].start)}–${formatTime(prayers[i].end)} '
        '(${formatTime(prayers[i].end - prayers[i].start)}): '
        '"${prayers[i].first}" … "${prayers[i].last}"',
].join('\n');

Map<String, dynamic> get _schema {
  const t = {'type': 'string'};
  return {
    'type': 'object',
    'properties': {
      'openingPrayer': {'type': 'integer'},
      'closingPrayer': {'type': 'integer'},
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
    'required': [
      'openingPrayer',
      'closingPrayer',
      'title',
      'description',
      'shorts',
    ],
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

Future<Map<String, dynamic>> _ollamaChat(Map<String, dynamic> body) async {
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

/// Asks Ollama for one [SermonPlan] per sermon (a single call, no retries).
class Planner {
  Planner({ChatFn? chat, this.think = true}) : _chat = chat ?? _ollamaChat;
  final ChatFn _chat;
  final bool think;

  Future<SermonPlan> plan({
    required String compactText,
    required List<Prayer> prayers,
    required double duration,
    required String originalDescription,
  }) async {
    if (prayers.length < 2)
      throw PlanException([
        'Minder as twee gebede in die onderskrifte gevind.',
      ]);
    final res = await _chat({
      'model': kModel,
      'stream': false,
      'think': think,
      'format': _schema,
      // Qwen3's thinking-mode sampling: greedy decoding (temperature 0) can think in circles for
      // half an hour. num_predict caps a runaway at a few minutes; the seed keeps runs reproducible.
      'options': {
        'num_ctx': 16384,
        'temperature': 0.6,
        'top_p': 0.95,
        'top_k': 20,
        'num_predict': 8192,
        'seed': 1,
      },
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content':
              'Duur van die video: ${duration.round()} s.\n\nOorspronklike beskrywing:\n$originalDescription\n\nKandidaat-gebede:\n${prayerList(prayers)}\n\nOnderskrifte:\n$compactText',
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
    Prayer? pick(Object? n) => n is num && n >= 1 && n <= prayers.length
        ? prayers[n.toInt() - 1]
        : null;
    final open = pick(j['openingPrayer']), close = pick(j['closingPrayer']);
    if (open == null || close == null || open.start >= close.start)
      throw PlanException(['Die KI het nie twee geldige gebede gekies nie.']);
    // The cut includes both prayers (CONTEXT.md, Besluite).
    final start = open.start, end = close.end;
    final shorts = <Short>[];
    for (final s in (j['shorts'] as List? ?? const [])) {
      final a = parseTime(s['start']), b = parseTime(s['end']);
      if (a != null && b != null)
        shorts.add(Short(start: a, end: b, title: '${s['title']}'));
    }
    final plan = SermonPlan(
      sermonStart: start,
      sermonEnd: end,
      title: '${j['title'] ?? ''}'.trim(),
      description: '${j['description'] ?? ''}'.trim(),
      shorts: shorts,
    );
    final errors = validate(plan, duration);
    if (errors.isNotEmpty) throw PlanException(errors, plan: plan);
    return plan;
  }

  /// Loads `<dir>/plan.json` if present (never overwritten); otherwise plans and saves it.
  Future<SermonPlan> loadOrPlan(
    Directory dir, {
    required String compactText,
    required List<Prayer> prayers,
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
      compactText: compactText,
      prayers: prayers,
      duration: duration,
      originalDescription: originalDescription,
    );
    if (cancelled) throw JobCancelled();
    savePlan(dir, plan);
    return plan;
  }
}

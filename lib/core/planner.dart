// @stelsel planner
//   soort: module
//   wanneer: ná captions, een Ollama-oproep per preek
//   groep: core | Kern
//   skryf: werkmap/<id>/plan.json
//   doel: vra qwen3:8b vir preekgrense, Shorts, titel en beskrywing; valideer en berg plan.json op
//   status: oop
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'models.dart';
import 'tools.dart';

/// Longest allowed Short in seconds.
const kMaxShort = 90;

const kPlanFile = 'plan.json';

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
Jy kry die onderskrifte van die hele diens as reëls "[mm:ss] teks" (hoogstens elke 30 sekondes 'n reël; "[musiek]" is sang of musiek).

Doen die volgende:
1. Vind die PREEK: dit begin wanneer die prediker die tema en/of teks aankondig en eindig by die amen waarmee die prediker sy preek self afsluit, net VOOR die dankgebed ("Kom ons dank saam"). Die Skriflesing, voorafgaande sang, gebede en die dankgebed ná die preek is nie deel van die preek nie.
2. Kies 1 tot 3 SHORTS binne die preek, elk 'n volledige gedagte. Elke Short moet tussen 30 en 80 sekondes lank wees (eindtyd minus begintyd): gebruik die begin van een reël as begintyd en die begin van die volgende of oor-volgende reël as eindtyd (60 sekondes is 'n goeie lengte).
3. Skryf 'n TITEL (die tema van die preek, hoogstens 100 karakters).
4. Skryf 'n BESKRYWING in Afrikaans met reëls "Tema: …", "Skriflesing: …", "Fokusgedeelte: …", dan 3 tot 4 sinne opsomming, en laastens die psalms uit die oorspronklike beskrywing (as dit daar is). Hou die beskrywing onder 1500 karakters.

Gee tye as "mm:ss" soos in die onderskrifte. Antwoord net met JSON volgens die skema.''';

Map<String, dynamic> get _schema {
  const t = {'type': 'string'};
  return {
    'type': 'object',
    'properties': {
      'sermonStart': t,
      'sermonEnd': t,
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
    'required': ['sermonStart', 'sermonEnd', 'title', 'description', 'shorts'],
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

/// Checks a plan against the rules; returns Afrikaans messages (empty = valid).
List<String> validate(SermonPlan plan, double duration) {
  final e = <String>[];
  final len = plan.sermonEnd - plan.sermonStart;
  if (plan.sermonStart < 0 ||
      plan.sermonEnd > duration ||
      plan.sermonStart >= plan.sermonEnd) {
    e.add('Die preek se grense lê buite die video.');
  } else if (len < 15 * 60 || len > 75 * 60) {
    e.add(
      'Die preek is ${(len / 60).round()} min; dit moet tussen 15 en 75 min wees.',
    );
  }
  for (final s in plan.shorts) {
    if (s.start < plan.sermonStart ||
        s.end > plan.sermonEnd ||
        s.start >= s.end) {
      e.add('Short "${s.title}" lê nie binne die preek nie.');
    } else if (s.end - s.start < 20 || s.end - s.start > kMaxShort) {
      e.add(
        'Short "${s.title}" is ${(s.end - s.start).round()} s; dit moet 20 tot 90 s wees.',
      );
    }
  }
  if (plan.title.isEmpty || plan.title.length > 100)
    e.add('Die titel moet 1 tot 100 karakters wees.');
  if (plan.description.length > 5000)
    e.add('Die beskrywing is langer as 5000 karakters.');
  return e;
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
    required double duration,
    required String originalDescription,
  }) async {
    final res = await _chat({
      'model': kModel,
      'stream': false,
      'think': think,
      'format': _schema,
      'options': {'num_ctx': 16384, 'temperature': 0, 'seed': 1},
      'messages': [
        {'role': 'system', 'content': _systemPrompt},
        {
          'role': 'user',
          'content':
              'Duur van die video: ${duration.round()} s.\n\nOorspronklike beskrywing:\n$originalDescription\n\nOnderskrifte:\n$compactText',
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
    final start = parseTime(j['sermonStart']), end = parseTime(j['sermonEnd']);
    if (start == null || end == null)
      throw PlanException(['Die KI het nie die preek se tye gegee nie.']);
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
    required double duration,
    required String originalDescription,
  }) async {
    final f = File(p.join(dir.path, kPlanFile));
    if (f.existsSync())
      return SermonPlan.fromJson(
        jsonDecode(f.readAsStringSync()) as Map<String, dynamic>,
      );
    final plan = await this.plan(
      compactText: compactText,
      duration: duration,
      originalDescription: originalDescription,
    );
    savePlan(dir, plan);
    return plan;
  }
}

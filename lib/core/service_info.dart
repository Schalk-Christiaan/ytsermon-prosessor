// @stelsel service_info
//   soort: module
//   wanneer: ná fetchMeta (info.json) en in cutJob
//   groep: core | Kern
//   skryf: —
//   doel: diensdatum in plaaslike tyd (nie upload_date nie), Oggend/Aand en die velde uit die YouTube-beskrywing (tema, skriflesing, fokus, belydenis, psalms)
//   status: bou
/// When the service began, as wall-clock time (a UTC-flagged [DateTime] holding the local clock reading):
/// from `release_timestamp` (stream start), else `timestamp`; null without either. [offset] defaults to this
/// machine's UTC offset. `upload_date` is no good: the upload comes a day later than the service.
DateTime? serviceStart(Map<String, dynamic> j, {Duration? offset}) {
  final ts = j['release_timestamp'] ?? j['timestamp'];
  if (ts is! num) return null;
  final ms = ts.toInt() * 1000;
  final off = offset ?? DateTime.fromMillisecondsSinceEpoch(ms).timeZoneOffset;
  return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).add(off);
}

String? _field(String d, String labels) {
  final m = RegExp(
    '^(?:$labels)\\s*:?\\s*(.+)\$',
    multiLine: true,
    caseSensitive: false,
  ).firstMatch(d);
  return m?.group(1)?.trim();
}

/// One service: its day, whether it was the evening one, and the facts from the video description.
class ServiceInfo {
  ServiceInfo({
    required this.date,
    this.evening = false,
    this.label,
    this.theme,
    this.scripture,
    this.focus,
    this.creed,
    this.psalms = const [],
  });

  /// `JJJJ-MM-DD`.
  String date;

  /// Aand (stream began at 13:00 or later) rather than Oggend.
  bool evening;

  /// The AI's service label (`nagmaal`, `doop`, `kategismus`, `belydenis`, `feesdag`) or null.
  String? label;
  String? theme, scripture, focus, creed;
  List<int> psalms;

  /// Reads the `Tema:`, `Skriflesing:`/`Skrifgedeelte:`, `Fokusgedeelte:`, creed (`NGB`/`HK`/`Dordtse`/`Sondag …`)
  /// and `Psalm n` lines of [description]; the colon is optional.
  factory ServiceInfo.fromDescription(String description, {String date = ''}) =>
      ServiceInfo(
        date: date,
        theme: _field(description, 'Tema'),
        scripture: _field(description, 'Skriflesing|Skrifgedeelte'),
        focus: _field(description, 'Fokusgedeelte'),
        creed: RegExp(
          r'^(?:NGB|HK|Dordtse|Sondag)\b.*$',
          multiLine: true,
        ).firstMatch(description)?.group(0)?.trim(),
        psalms: [
          for (final m in RegExp(
            r'^Psalm\s+(\d+)',
            multiLine: true,
            caseSensitive: false,
          ).allMatches(description))
            int.parse(m.group(1)!),
        ],
      );

  /// From yt-dlp's info.json: the day and Oggend/Aand from [serviceStart], the rest from the description.
  factory ServiceInfo.fromInfo(Map<String, dynamic> j, {Duration? offset}) {
    final t = serviceStart(j, offset: offset);
    final u = '${j['upload_date'] ?? '00000000'}';
    String two(int n) => n.toString().padLeft(2, '0');
    return ServiceInfo.fromDescription(
      '${j['description'] ?? ''}',
      date: t == null
          ? '${u.substring(0, 4)}-${u.substring(4, 6)}-${u.substring(6, 8)}'
          : '${t.year}-${two(t.month)}-${two(t.day)}',
    )..evening = t != null && t.hour >= 13;
  }

  Map<String, dynamic> toJson() => {
    'date': date,
    'evening': evening,
    'label': ?label,
    'theme': ?theme,
    'scripture': ?scripture,
    'focus': ?focus,
    'creed': ?creed,
    'psalms': psalms,
  };

  factory ServiceInfo.fromJson(Map<String, dynamic> j) => ServiceInfo(
    date: j['date'] as String,
    evening: j['evening'] as bool? ?? false,
    label: j['label'] as String?,
    theme: j['theme'] as String?,
    scripture: j['scripture'] as String?,
    focus: j['focus'] as String?,
    creed: j['creed'] as String?,
    psalms: [for (final p in (j['psalms'] as List? ?? const [])) p as int],
  );
}

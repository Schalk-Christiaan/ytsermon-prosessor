// @stelsel youtube
//   soort: module
//   wanneer: "Koppel kanaal" (Instellings) en die oplaai-taak in die werkry
//   groep: core | Kern
//   skryf: refresh-token (deur die roeper: Windows Credential Manager / libsecret); <werkmap>/quota.json; <werkmap>/<id>/upload-*.json | hervat-sessie
//   doel: desktop-OAuth (loopback + PKCE), hervatbare oplaai, snitlyste en die 100-per-dag-teller; net dart:io, endpunte uit die kliëntlêer sodat toetse 'n vals bediener gebruik
//   status: oop
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'store.dart';
import 'tools.dart';

const _scopes =
    'https://www.googleapis.com/auth/youtube.upload '
    'https://www.googleapis.com/auth/youtube';

/// One HTTP round trip; returns status, headers and the body as text.
Future<(int, HttpHeaders, String)> _send(
  String method,
  Uri url, {
  Map<String, String> headers = const {},
  List<int>? body,
}) async {
  final c = HttpClient();
  try {
    final q = await c.openUrl(method, url);
    q.followRedirects = false;
    headers.forEach(q.headers.set);
    if (body != null) {
      q.contentLength = body.length;
      q.add(body);
    }
    final r = await q.close();
    return (r.statusCode, r.headers, await utf8.decodeStream(r));
  } finally {
    c.close();
  }
}

String _b64(List<int> b) => base64Url.encode(b).replaceAll('=', '');

String _random() =>
    _b64(List.generate(48, (_) => Random.secure().nextInt(256)));

/// Desktop OAuth for one Google account; the refresh token lives wherever [read]/[write] keep it.
class GoogleAuth {
  GoogleAuth(this.clientFile, {required this.read, required this.write});
  final File clientFile;
  final Future<String?> Function() read;
  final Future<void> Function(String? token) write;
  String? _token;
  DateTime _expiry = DateTime(0);

  bool get configured => clientFile.existsSync();
  Future<bool> get signedIn async => await read() != null;

  Map<String, dynamic> _client() {
    if (!configured) {
      throw StateError(
        'Geen kliënt-ID-lêer nie (${clientFile.path}). Laai dit by Google af en kies dit in Instellings.',
      );
    }
    final j = jsonDecode(clientFile.readAsStringSync()) as Map<String, dynamic>;
    final c = (j['installed'] ?? j['web']) as Map<String, dynamic>?;
    if (c == null) {
      throw StateError(
        'Die kliënt-ID-lêer is nie \'n Google "Desktop app"-lêer nie.',
      );
    }
    return c;
  }

  Future<Map<String, dynamic>> _tokenCall(Map<String, String> form) async {
    final c = _client();
    final (code, _, body) = await _send(
      'POST',
      Uri.parse(c['token_uri'] as String),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: utf8.encode(
        Uri(
          queryParameters: {
            'client_id': c['client_id'] as String,
            'client_secret': c['client_secret'] as String? ?? '',
            ...form,
          },
        ).query,
      ),
    );
    if (code != 200)
      throw HttpException('Google-aanmelding het misluk ($code): $body');
    final j = jsonDecode(body) as Map<String, dynamic>;
    _token = j['access_token'] as String;
    _expiry = DateTime.now().add(
      Duration(seconds: (j['expires_in'] as num? ?? 3600).toInt() - 60),
    );
    return j;
  }

  /// Opens the consent page via [open] and waits for Google's redirect to a one-shot loopback server.
  Future<void> signIn(Future<void> Function(String url) open) async {
    final c = _client();
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final redirect = 'http://127.0.0.1:${server.port}';
    final verifier = _random();
    final state = _random();
    final got = Completer<Map<String, String>>();
    server.listen((q) async {
      final p = q.uri.queryParameters;
      final mine = p['state'] == state && !got.isCompleted;
      q.response
        ..statusCode = mine ? 200 : 404
        ..headers.contentType = ContentType.html
        ..write(mine ? '<p>Klaar. Jy kan hierdie venster toemaak.</p>' : '');
      await q.response.close();
      if (mine) got.complete(p);
    });
    final url = Uri.parse(c['auth_uri'] as String).replace(
      queryParameters: {
        'client_id': c['client_id'] as String,
        'redirect_uri': redirect,
        'response_type': 'code',
        'scope': _scopes,
        'code_challenge': _b64(sha256.convert(ascii.encode(verifier)).bytes),
        'code_challenge_method': 'S256',
        'state': state,
        'access_type': 'offline',
        'prompt': 'consent',
      },
    );
    try {
      final opened = open('$url');
      final p = await got.future.timeout(const Duration(minutes: 10));
      await opened.catchError((_) {});
      if (p['code'] == null) throw StateError('Aanmelding gekanselleer.');
      final j = await _tokenCall({
        'grant_type': 'authorization_code',
        'code': p['code']!,
        'code_verifier': verifier,
        'redirect_uri': redirect,
      });
      await write(j['refresh_token'] as String?);
    } finally {
      await server.close(force: true);
    }
  }

  /// A valid access token, refreshed with the stored refresh token when needed.
  Future<String> accessToken() async {
    if (_token != null && DateTime.now().isBefore(_expiry)) return _token!;
    final rt = await read();
    if (rt == null)
      throw StateError(
        'Die kanaal is nie gekoppel nie (Instellings → Koppel kanaal).',
      );
    await _tokenCall({'grant_type': 'refresh_token', 'refresh_token': rt});
    return _token!;
  }

  Future<void> signOut() async {
    _token = null;
    await write(null);
  }
}

/// The few YouTube Data API calls the app needs.
class YouTube {
  YouTube(
    this.auth, {
    this.api = 'https://www.googleapis.com',
    this.chunk = 8 << 20,
  });
  final GoogleAuth auth;
  final String api;

  /// Upload chunk size; Google wants a multiple of 256 KiB.
  final int chunk;

  Future<Map<String, dynamic>> _call(
    String method,
    String path, {
    Map<String, String> query = const {},
    Object? json,
  }) async {
    final (code, _, body) = await _send(
      method,
      Uri.parse('$api$path').replace(queryParameters: query),
      headers: {
        'authorization': 'Bearer ${await auth.accessToken()}',
        if (json != null) 'content-type': 'application/json; charset=utf-8',
      },
      body: json == null ? null : utf8.encode(jsonEncode(json)),
    );
    if (code ~/ 100 != 2) throw HttpException('YouTube $path ($code): $body');
    return body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
  }

  /// Resumable upload; the session lives in [session] so a broken upload continues where the server stopped. Returns the video ID.
  Future<String> upload(
    File file, {
    required String title,
    required String description,
    required String privacy,
    required File session,
    void Function(double frac)? onProgress,
    Future<void>? cancel,
  }) async {
    var cancelled = false;
    cancel?.then((_) => cancelled = true);
    final size = file.lengthSync();
    var offset = 0;
    String uri;
    final auth = {'authorization': 'Bearer ${await this.auth.accessToken()}'};
    if (session.existsSync()) {
      uri = (jsonDecode(session.readAsStringSync()) as Map)['uri'] as String;
      final (code, h, body) = await _send(
        'PUT',
        Uri.parse(uri),
        headers: {...auth, 'content-range': 'bytes */$size'},
        body: const [],
      );
      if (code ~/ 100 == 2) return _done(session, body);
      if (code != 308)
        throw HttpException('Oplaai hervat het misluk ($code): $body');
      offset = _next(h);
    } else {
      final (code, h, body) = await _send(
        'POST',
        Uri.parse('$api/upload/youtube/v3/videos').replace(
          queryParameters: {
            'uploadType': 'resumable',
            'part': 'snippet,status',
          },
        ),
        headers: {
          ...auth,
          'content-type': 'application/json; charset=utf-8',
          'x-upload-content-length': '$size',
          'x-upload-content-type': 'video/mp4',
        },
        body: utf8.encode(
          jsonEncode({
            'snippet': {'title': title, 'description': description},
            'status': {
              'privacyStatus': privacy,
              'selfDeclaredMadeForKids': false,
            },
          }),
        ),
      );
      if (code != 200)
        throw HttpException('Oplaai kon nie begin nie ($code): $body');
      uri = h.value('location')!;
      writeJson(session, {'uri': uri, 'size': size});
    }
    final raf = await file.open();
    try {
      while (true) {
        if (cancelled) throw JobCancelled();
        onProgress?.call(offset / size);
        await raf.setPosition(offset);
        final bytes = await raf.read(min(chunk, size - offset));
        final end = offset + bytes.length - 1;
        final (code, h, body) = await _send(
          'PUT',
          Uri.parse(uri),
          headers: {...auth, 'content-range': 'bytes $offset-$end/$size'},
          body: bytes,
        );
        if (code ~/ 100 == 2) {
          onProgress?.call(1);
          return _done(session, body);
        }
        if (code != 308)
          throw HttpException(
            'Oplaai onderbreek ($code); probeer weer om te hervat.',
          );
        offset = _next(h);
      }
    } finally {
      await raf.close();
    }
  }

  /// First byte the server still wants, from a 308's `Range: bytes=0-N`.
  int _next(HttpHeaders h) {
    final r = h.value('range');
    return r == null ? 0 : int.parse(r.split('-').last) + 1;
  }

  String _done(File session, String body) {
    if (session.existsSync()) session.deleteSync();
    return (jsonDecode(body) as Map)['id'] as String;
  }

  /// The channel's playlists, title → ID (all pages).
  Future<Map<String, String>> playlists() async {
    final out = <String, String>{};
    String? page;
    do {
      final j = await _call(
        'GET',
        '/youtube/v3/playlists',
        query: {
          'part': 'snippet',
          'mine': 'true',
          'maxResults': '50',
          'pageToken': ?page,
        },
      );
      for (final it in (j['items'] as List? ?? const [])) {
        out[it['snippet']['title'] as String] = it['id'] as String;
      }
      page = j['nextPageToken'] as String?;
    } while (page != null);
    return out;
  }

  /// Creates a private playlist and returns its ID.
  Future<String> createPlaylist(String title) async =>
      (await _call(
            'POST',
            '/youtube/v3/playlists',
            query: {'part': 'snippet,status'},
            json: {
              'snippet': {'title': title},
              'status': {'privacyStatus': 'private'},
            },
          ))['id']
          as String;

  Future<void> addToPlaylist(String playlist, String video) => _call(
    'POST',
    '/youtube/v3/playlistItems',
    query: {'part': 'snippet'},
    json: {
      'snippet': {
        'playlistId': playlist,
        'resourceId': {'kind': 'youtube#video', 'videoId': video},
      },
    },
  );
}

class QuotaExceeded implements Exception {
  @override
  String toString() => 'Vandag se 100 oplaaie is op; probeer môre weer.';
}

/// Counts `videos.insert` calls per Pacific day (YouTube's own bucket of 100).
// ponytail: fixed UTC-8; during US summer time the reset is an hour off.
class UploadQuota {
  UploadQuota(this.file, {DateTime Function()? now})
    : _now = now ?? DateTime.now;
  static const limit = 100;
  final File file;
  final DateTime Function() _now;

  /// Uploads booked today (0 once the Pacific day has turned).
  int get used {
    if (!file.existsSync()) return 0;
    final j = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    return j['day'] == _day ? j['used'] as int : 0;
  }

  String get _day => _now()
      .toUtc()
      .subtract(const Duration(hours: 8))
      .toIso8601String()
      .substring(0, 10);

  /// Books one upload, or throws [QuotaExceeded].
  void take() {
    final n = used;
    if (n >= limit) throw QuotaExceeded();
    writeJson(file, {'day': _day, 'used': n + 1});
  }
}

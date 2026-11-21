// OAuth (loopback + PKCE), resumable upload and playlists against a local fake Google server; no real calls.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:preekverwerker/core/youtube.dart';

/// A tiny stand-in for accounts.google.com, oauth2.googleapis.com and the YouTube API.
class FakeGoogle {
  late HttpServer server;
  String get base => 'http://127.0.0.1:${server.port}';
  String? challenge;
  final received = BytesBuilder();
  var failAtChunk = -1;
  var chunks = 0;
  final playlistsMade = <String>[];
  final added = <(String, String)>[];
  final uploads = <Map<String, dynamic>>[];
  final updates = <Map<String, dynamic>>[];
  var refreshes = 0;

  Future<void> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen(_handle);
  }

  Future<void> _json(HttpResponse r, Object o, [int code = 200]) async {
    r.statusCode = code;
    r.headers.contentType = ContentType.json;
    r.write(jsonEncode(o));
    await r.close();
  }

  Future<void> _handle(HttpRequest q) async {
    final r = q.response;
    final path = q.uri.path;
    if (path == '/auth') {
      challenge = q.uri.queryParameters['code_challenge'];
      expect(q.uri.queryParameters['code_challenge_method'], 'S256');
      expect(q.uri.queryParameters['scope'], contains('youtube.upload'));
      final back = Uri.parse(q.uri.queryParameters['redirect_uri']!).replace(
        queryParameters: {
          'code': 'abc',
          'state': q.uri.queryParameters['state'],
        },
      );
      r.redirect(back);
      return;
    }
    if (path == '/token') {
      final f = Uri.splitQueryString(await utf8.decodeStream(q));
      expect(f['client_id'], 'cid');
      if (f['grant_type'] == 'authorization_code') {
        expect(f['code'], 'abc');
        final v = f['code_verifier']!;
        expect(
          base64Url
              .encode(sha256.convert(ascii.encode(v)).bytes)
              .replaceAll('=', ''),
          challenge,
        );
        return _json(r, {
          'access_token': 'at1',
          'refresh_token': 'rt',
          'expires_in': 3600,
        });
      }
      expect(f['grant_type'], 'refresh_token');
      expect(f['refresh_token'], 'rt');
      refreshes++;
      return _json(r, {'access_token': 'at2', 'expires_in': 3600});
    }
    expect(q.headers.value('authorization'), startsWith('Bearer at'));
    if (path == '/upload/youtube/v3/videos') {
      expect(q.uri.queryParameters['uploadType'], 'resumable');
      uploads.add(jsonDecode(await utf8.decodeStream(q)));
      r.headers.set('location', '$base/session/1');
      await r.close();
      return;
    }
    if (path == '/session/1') {
      final range = q.headers.value('content-range')!;
      final total = int.parse(range.split('/').last);
      if (range.startsWith('bytes */')) {
        await q.drain<void>();
      } else {
        final bytes = await q.fold<List<int>>([], (a, b) => a..addAll(b));
        if (chunks++ == failAtChunk) {
          r.statusCode = 503;
          await r.close();
          return;
        }
        received.add(bytes);
      }
      if (received.length == total) {
        return _json(r, {'id': 'VID'});
      }
      r.statusCode = 308;
      if (received.length > 0) {
        r.headers.set('range', 'bytes=0-${received.length - 1}');
      }
      await r.close();
      return;
    }
    if (path == '/youtube/v3/videos' && q.method == 'GET') {
      await q.drain<void>();
      expect(q.uri.queryParameters, {'part': 'snippet', 'id': 'VID'});
      return _json(r, {
        'items': [
          {
            'id': 'VID',
            'snippet': {
              'title': 'Oud',
              'description': 'Ou beskrywing',
              'categoryId': '29',
              'tags': ['preek'],
              'channelTitle': 'read-only',
            },
          },
        ],
      });
    }
    if (path == '/youtube/v3/videos' && q.method == 'PUT') {
      expect(q.uri.queryParameters['part'], 'snippet');
      updates.add(jsonDecode(await utf8.decodeStream(q)));
      return _json(r, {'id': 'VID'});
    }
    if (path == '/youtube/v3/playlists' && q.method == 'GET') {
      await q.drain<void>();
      return q.uri.queryParameters['pageToken'] == null
          ? _json(r, {
              'items': [
                {
                  'id': 'PL1',
                  'snippet': {'title': 'Mattheus'},
                },
              ],
              'nextPageToken': 'p2',
            })
          : _json(r, {
              'items': [
                {
                  'id': 'PL2',
                  'snippet': {'title': 'Efesiërs'},
                },
              ],
            });
    }
    if (path == '/youtube/v3/playlists') {
      final j = jsonDecode(await utf8.decodeStream(q));
      expect(j['status']['privacyStatus'], 'private');
      playlistsMade.add(j['snippet']['title']);
      return _json(r, {'id': 'PLNEW'});
    }
    if (path == '/youtube/v3/playlistItems') {
      final j = jsonDecode(await utf8.decodeStream(q));
      added.add((
        j['snippet']['playlistId'],
        j['snippet']['resourceId']['videoId'],
      ));
      return _json(r, {'id': 'ITEM'});
    }
    r.statusCode = 404;
    await r.close();
  }
}

void main() {
  late FakeGoogle g;
  late Directory d;
  late GoogleAuth auth;
  String? stored;

  setUp(() async {
    g = FakeGoogle();
    await g.start();
    d = Directory.systemTemp.createTempSync('yt');
    final client = File(p.join(d.path, 'client.json'))
      ..writeAsStringSync(
        jsonEncode({
          'installed': {
            'client_id': 'cid',
            'client_secret': 'sec',
            'auth_uri': '${g.base}/auth',
            'token_uri': '${g.base}/token',
          },
        }),
      );
    stored = null;
    auth = GoogleAuth(
      client,
      read: () async => stored,
      write: (v) async => stored = v,
    );
  });

  tearDown(() async {
    await g.server.close(force: true);
    d.deleteSync(recursive: true);
  });

  /// The "browser": follows the consent redirect back to the app's loopback server.
  Future<void> browser(String url) async {
    final c = HttpClient();
    final res = await (await c.getUrl(Uri.parse(url))).close();
    await res.drain<void>();
    c.close();
  }

  test(
    'signIn: loopback + PKCE stores the refresh token; refresh works',
    () async {
      expect(await auth.signedIn, isFalse);
      await auth.signIn(browser);
      expect(stored, 'rt');
      expect(await auth.signedIn, isTrue);
      expect(await auth.accessToken(), 'at1');
      final fresh = GoogleAuth(
        File(p.join(d.path, 'client.json')),
        read: () async => stored,
        write: (v) async => stored = v,
      );
      expect(await fresh.accessToken(), 'at2');
      expect(g.refreshes, 1);
      await fresh.signOut();
      expect(stored, isNull);
    },
  );

  test('a missing or wrong client file explains itself', () async {
    final a = GoogleAuth(
      File(p.join(d.path, 'nope.json')),
      read: () async => null,
      write: (_) async {},
    );
    expect(a.configured, isFalse);
    expect(
      () => a.signIn(browser),
      throwsA(
        isA<StateError>().having((e) => e.message, 'msg', contains('kliënt')),
      ),
    );
  });

  test('resumable upload in chunks resumes after a failed chunk', () async {
    stored = 'rt';
    final yt = YouTube(auth, api: g.base, chunk: 4);
    final f = File(p.join(d.path, 'v.mp4'))
      ..writeAsBytesSync(List.generate(10, (i) => i));
    final session = File(p.join(d.path, 'upload.json'));
    g.failAtChunk = 1;
    final fr = <double>[];
    await expectLater(
      yt.upload(
        f,
        title: 'T',
        description: 'D',
        privacy: 'private',
        session: session,
      ),
      throwsA(isA<HttpException>()),
    );
    expect(session.existsSync(), isTrue);
    final id = await yt.upload(
      f,
      title: 'T',
      description: 'D',
      privacy: 'private',
      session: session,
      onProgress: fr.add,
    );
    expect(id, 'VID');
    expect(g.uploads, hasLength(1));
    expect(g.uploads.single['status']['privacyStatus'], 'private');
    expect(g.uploads.single['snippet']['title'], 'T');
    expect(g.received.toBytes(), List.generate(10, (i) => i));
    expect(fr.last, 1.0);
    expect(session.existsSync(), isFalse);
  });

  test(
    'playlists: lists all pages, creates a private one, adds a video',
    () async {
      stored = 'rt';
      final yt = YouTube(auth, api: g.base);
      expect(await yt.playlists(), {'Mattheus': 'PL1', 'Efesiërs': 'PL2'});
      expect(await yt.createPlaylist('Romeine'), 'PLNEW');
      await yt.addToPlaylist('PLNEW', 'VID');
      expect(g.playlistsMade, ['Romeine']);
      expect(g.added, [('PLNEW', 'VID')]);
    },
  );

  test(
    'updateVideo keeps the category and tags, changes title and description',
    () async {
      stored = 'rt';
      final yt = YouTube(auth, api: g.base);
      await yt.updateVideo(
        'VID',
        title: 'Nuut',
        description: 'Nuwe beskrywing',
      );
      expect(g.updates, [
        {
          'id': 'VID',
          'snippet': {
            'title': 'Nuut',
            'description': 'Nuwe beskrywing',
            'categoryId': '29',
            'tags': ['preek'],
          },
        },
      ]);
    },
  );

  test('UploadQuota counts per Pacific day and stops at 100', () {
    var now = DateTime.utc(2026, 11, 20, 7, 59); // 23:59 the 19th, Pacific
    final q = UploadQuota(File(p.join(d.path, 'quota.json')), now: () => now);
    for (var i = 0; i < 100; i++) {
      q.take();
    }
    expect(q.used, 100);
    expect(q.take, throwsA(isA<QuotaExceeded>()));
    now = DateTime.utc(2026, 11, 20, 8, 1); // new Pacific day
    expect(
      UploadQuota(File(p.join(d.path, 'quota.json')), now: () => now).used,
      0,
    );
  });
}

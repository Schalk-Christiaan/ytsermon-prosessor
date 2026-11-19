status: oop

# Fase 3: Oplaai en snitlyste

## Doel
'n Gesnyde preek (en sy Shorts) gaan met een knoppie na die kanaal: desktop-OAuth (loopback + PKCE), hervatbare oplaai, altyd **privaat** (verstek; Instellings kan dit later verander), met titel en beskrywing uit 'n jabloon, en die preek kom in die regte snitlys volgens reëls (Bybelboek uit die Skriflesing, jaar). 'n Teller hou die 100-oplaaie-per-dag-emmer dop (navorsing 2026-11-19). Die kliënt-ID kom uit 'n lêer wat Schalk by Google aflaai (`client_secret_*.json`); die pad is in Instellings verstelbaar. Toetse loop teen 'n plaaslike vals HTTP-bediener; **geen regte oproepe** nie.

## Lêers
- `lib/core/settings.dart` (nuut): `AppSettings` ↔ `<werkmap>/settings.json` (kliëntlêer, privaatheid, jabloon, snitlysreëls). Fase 5/6 bou hierop voort.
- `lib/core/youtube.dart` (nuut): `GoogleAuth` (kliëntlêer lees, aanmeld via loopback, token verfris), `YouTube` (hervatbare oplaai, snitlyste lys/skep/byvoeg), `UploadQuota` (`<werkmap>/quota.json`).
- `lib/core/playlists.dart` (nuut): `playlistFor(sermon, rules)`, `bookFrom(scripture)`, `describe(template, …)`.
- `lib/core/store.dart`: `Sermon.uploads` (lêerpad → video-ID) sodat 'n herhaalde taak nie dubbel oplaai nie.
- `lib/core/jobs.dart`: `JobKind.upload`, `JobPhase.upload`, `uploadJob(...)`; klaar → `opgelaai`.
- `lib/features/playlists/playlists_screen.dart` (nuut): Snitlyste-skerm (reëls + voorskou + jabloon).
- `lib/features/settings/settings_screen.dart` (nuut): Kanaal-groep (kliëntlêer, "Koppel kanaal"/"Ontkoppel", status) + bestaande Stelsel.
- `lib/features/work/work_screen.dart`: "Laai op" op 'n klaar sny-item + "Oplaaie vandag: n/100".
- `lib/app/shell.dart`, `lib/main.dart`, `lib/l10n/app_af.arb`, `pubspec.yaml` (`crypto` direk vir PKCE S256, `flutter_secure_storage` vir die refresh-token).
- Toetse: `test/youtube_test.dart` (vals bediener), `test/playlists_test.dart`, `test/settings_test.dart`, `test/jobs_test.dart`, `test/screens_test.dart`.

## Stappe
1. `AppSettings` (json, verstekke: kliëntlêer `<werkmap>/client_secret.json`, privaatheid `private`, jabloon, reëls `[book, year]`), atomies gestoor. — kontrole: `settings_test` rondreis + verstekke eers rooi.
2. `playlists.dart`: `bookFrom('1 Korinthiërs 13:1-13') = '1 Korinthiërs'`, `playlistFor` (eerste aktiewe reël wat 'n waarde gee: boek → boeknaam, jaar → "Preke 2026"), `describe(template)` vervang `{tema}`, `{skriflesing}`, `{datum}`, `{beskrywing}`; afgekap tot 5000. — kontrole: `playlists_test` eers rooi.
3. `GoogleAuth`: lees `installed.client_id/client_secret/auth_uri/token_uri`; `signIn(open)` = `HttpServer.bind(loopback, 0)`, PKCE S256 + `state`, maak die blaaier oop via `openPath`, wag op `?code=`, ruil by `token_uri`; `accessToken()` verfris met die refresh-token (gestoor via 'n `read/write`-paar; app = `flutter_secure_storage`, toets = geheue). Scopes `youtube.upload` + `youtube`. — kontrole: `youtube_test` met vals bediener (auth-eindpunt herlei na die loopback-URI, token-eindpunt kontroleer `code_verifier`) eers rooi.
4. `YouTube.upload(file, title, description, privacy)`: `POST {upload}/youtube/v3/videos?uploadType=resumable&part=snippet,status` → `Location`; stukke van 8 MB met `Content-Range`, 308 → volgende stuk; sessie-URI in `<id>/upload-<naam>.json` sodat 'n onderbroke oplaai met `Content-Range: bytes */N` hervat; kanselleer tussen stukke. `playlists()` (blaai `mine=true`), `createPlaylist(title)` (privaat), `addToPlaylist(pl, video)`. — kontrole: vals bediener: oplaai in 3 stukke, onderbreking ná stuk 1 → hervat by die bediener se `Range`, snitlys gevind of geskep; eers rooi.
5. `UploadQuota`: tel per Pacific-dag (UTC−8), gooi `QuotaExceeded` ("Vandag se 100 oplaaie is op; probeer môre weer.") by 100. `uploadJob`: preek-mp4 + elke Short (privaat), titel/beskrywing uit plan + jabloon, preek in snitlys (bestaande hergebruik op naam), `uploads` ná elke lêer gestoor (herhaal = slaan oor), klaar → `opgelaai`. — kontrole: `jobs_test` met vals `YouTube`-funksies: dubbel = een oplaai, kwota op = gewone-taal fout; eers rooi.
6. UI: Instellings → Kanaal (kliëntlêer-pad + status "Gekoppel"/"Nie gekoppel nie", "Koppel kanaal", "Ontkoppel"); Snitlyste-skerm (reëls aan/af in volgorde, voorskou "Mattheus → 4 preke", jabloon-veld met voorskou); Werk: "Laai op" + teller. Rail: Snitlyste aktief. — kontrole: widget-toetse eers rooi; kiekies `out/shots/{instellings,snitlyste}-{light,dark}-{1100,1920}.png`.
7. `@stelsel`-blokke, `kaart.py --check`, `dart analyze`, `flutter test`, `dart format`.

## Aanvaarding
- `flutter test` groen sonder internet; die hele OAuth- en oplaaivloei is teen die vals bediener getoets (aanmeld, verfris, hervat, snitlys).
- Werk: "Laai op" → taak met vordering → preek `opgelaai`; teller wys n/100.
- Geen regte Google-oproep in toetse nie.

## Prestasie-begroting
Een oplaai op 'n slag deur die bestaande werkry; stukke gestroom uit die lêer (nie die hele lêer in geheue nie). Geen polling of timers; die loopback-bediener leef net tydens aanmeld. `playlists()` een keer per taak.

## Buite bestek
Bestaande video's op die kanaal bywerk (`videos.update`, fase 6 V8), outomatiese publiek-maak, Shorts in snitlyste, prediker- en reeksreëls (geen betroubare bron in die data nie).

## Ingryp
- As Google se loopback-vloei 'n vaste poort vereis: gebruik `127.0.0.1:<vry>` (Google aanvaar enige poort vir Desktop-kliënte).

## Vrae
- **Ongetoets: regte oplaai.** Stappe vir Schalk (eenmalig): (1) console.cloud.google.com → nuwe projek "Preekverwerker"; (2) APIs & Services → Library → "YouTube Data API v3" → Enable; (3) OAuth consent screen → External, app-naam, sy e-pos, scopes `youtube.upload` en `youtube`, voeg sy Google-rekening as toetsgebruiker by, dan **Publish app → In production** (anders verval die token ná 7 dae); (4) Credentials → Create credentials → OAuth client ID → **Desktop app** → Download JSON; (5) in die app: Instellings → Kanaal → kies die afgelaaide lêer (of kopieer dit na `<werkmap>/client_secret.json`) → "Koppel kanaal" → kies die kerk se kanaal se rekening, aanvaar die "nie geverifieer nie"-waarskuwing; (6) Werk → "Laai op" op een gesnyde preek; kyk in YouTube Studio dat dit privaat is en in die regte snitlys.
- (aanname) Shorts word ook opgelaai (privaat), maar in geen snitlys nie.
- (aanname) Snitlysreëls net Bybelboek en jaar; prediker/reeks het geen bron (beskrywings dra dit nie betroubaar nie).
- (aanname) Pacific-dag as vaste UTC−8 (somertyd ignoreer; hoogstens een uur vroeër/later herstel).
- (aanname) Jabloon-verstek: `{beskrywing}\n\nSkriflesing: {skriflesing}\nDiens van {datum}, Gereformeerde Kerk Oranjerivier.`

## Log

## Verslag

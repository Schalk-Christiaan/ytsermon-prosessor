status: oop

# Fase 6: Die preekredigeerder

## Doel
Hersien word **die preekredigeerder**: die mens kyk na wat die KI voorgestel het, en kan dit met muis of sleutelbord presies regmaak sonder om iets te breek. Die werk:
- Sleepbare hakies, met ←/→ = 1 s, Shift = 0,1 s, en I/O wat die hakie by die speelkop sit.
- Speel van 'n hakie af, en speel 'n voorskou van die gesnyde preek.
- 'n Transkripsiestrook waar 'n klik op 'n reël na daardie plek spring, met gebede uitgelig.
- Middelstukke uitknip, sodat die snit 'n lys segmente word.
- Shorts wat jy kan wysig, sleep en voorskou.
- Ontdoen en herdoen.

Dieselfde fase bring:
- **"Verwerk nuutste diens"**: een knoppie vir die gewone Maandag.
- **intro/outro** voor en ná elke volle preek.
- **"Voer opname in"** vir video's wat nie op YouTube is nie.
- Foutboodskappe wat sê of dit die internet of die skyf is.
- Die drie bekende uitlegfoute.

## Lêers
- `lib/core/models.dart`: `SermonPlan.cuts` (uitgeknipte stukke), `parts()` (die segmente wat bly).
- `lib/core/cutter.dart`:
  - `probeMedia` (ffprobe: breedte, hoogte, fps, duur, klank);
  - `joinArgs` (filter_complex: segmente plus intro/outro, met scale/pad/fps/aresample en concat);
  - `cutSermon` bly by stroomkopie as daar een segment is en geen intro/outro nie.
- `lib/core/settings.dart`: `intro`, `outro` (paaie, opsioneel).
- `lib/core/jobs.dart`:
  - `cutJob` gee intro/outro deur;
  - `friendlyError` onderskei internet, Ollama en 'n vol skyf.
- `lib/core/recording.dart` (nuut): `importRecording` kopieer die lêer na `<werk>/<id>/video.mp4` met 'n plaaslike ID en skryf `info.json`, leë onderskrifte en 'n handmatige plan.
- `lib/core/channel.dart`: `fetchMeta` aanvaar plaaslike ID's (`opname-…`) sonder yt-dlp.
- `lib/core/youtube.dart`: `updateVideo(id, title, description)` vir V8.
- `lib/features/review/review_controller.dart`:
  - ontdoen/herdoen;
  - hakie-skuiwe en I/O;
  - uitknip;
  - Shorts skuif, titel en begin;
  - voorskou van die snit;
  - speel van die hakie af;
  - "Werk op YouTube by".
- `lib/features/review/service_timeline.dart`: uitgeknipte stukke, gebedsmerkers, sleepbare Shorts; die stap word 1 s / 0,1 s.
- `lib/features/review/transcript.dart` (nuut): die transkripsiestrook.
- `lib/features/review/review_screen.dart`: nuwe uitleg, kortpaaie, segment- en Shorts-lyste.
- `lib/features/sermons/sermons_screen.dart`:
  - rye met twee reëls (titel bo, Skriflesing onder);
  - "Verwerk nuutste diens";
  - filter "Nie opgelaai nie";
  - "Voer opname in".
- `lib/features/settings/settings_screen.dart`: intro/outro met lengte.
- `lib/app/shell.dart`, `lib/l10n/app_af.arb`, `pubspec.yaml` (`file_selector`, `desktop_drop`).
- Toetse:
  - `test/models_test.dart` (nuut);
  - `cutter_test`, `review_controller_test`, `recording_test` (nuut), `jobs_test`, `youtube_test`, `screens_test`.

## Stappe
1. `SermonPlan.cuts` + `parts()`: [begin, einde] minus die uitgeknipte stukke, gesorteer en geknip tot binne die preek; JSON bly terugwaarts versoenbaar (`cuts` ontbreek → leeg).
   - kontrole: `models_test` eers rooi.
2. `probeMedia` + `joinArgs` + `cutSermon(intro:, outro:)`. Met een segment en geen klippies nie bly dit stroomkopie. Anders gaan elke deel deur een ffmpeg-proses: elke segment `-ss/-to -i`, en die klippies word geskaal en gepad na die preek se grootte en fps, met `anullsrc` vir 'n klippie sonder klank. Daarna `concat`, en uitset met libx264/aac.
   - kontrole: `cutter_test` eers rooi, met argumente en met regte ffmpeg op klein `testsrc`-klippies:
     - die hoofvideo 320×240 @ 25 met klank;
     - 'n intro 160×120 @ 30 sonder klank;
     - 'n outro met klank.
   - Twee segmente plus albei klippies gee by `ffprobe` 320×240, die duur ≈ die som (±0,3 s) en een klankstroom.
3. Instellings: intro/outro (pad, "Kies…", "Verwyder", lengte via `probeMedia`); `cutJob` gee dit deur (net vir die volle preek, nie Shorts nie).
   - kontrole: `jobs_test` eers rooi: die gestubde sny kry die paaie.
4. Redigeerder-beheerder:
   - `undo/redo`: momentopnames van plan.json, met opeenvolgende titel- of beskrywing-tik saamgevoeg;
   - `nudge(start|end, s)`, `markIn/markOut` (speelkop);
   - `addCut/setCut/removeCut`;
   - `moveShort`, `setShortStart`, `setShortTitle`;
   - `playFrom(start|end)`;
   - `previewCut()`: speel die snit en spring oor uitgeknipte stukke; stop by die einde.
   - kontrole: `review_controller_test` eers rooi.
5. Redigeerder-UI:
   - Uitleg: video bo-links. Regs die titel (twee reëls), die beskrywing en die transkripsie. Onder die tydlyn, en onder dit oortjies "Uitgeknip" en "Shorts". Heel onder die aksies.
   - Kortpaaie: I/O, ←/→ (+Shift) op die gefokusde hakie, spasie = speel/pouse, Ctrl+Z / Ctrl+Shift+Z.
   - Gebede word op die tydlyn en in die transkripsie gemerk.
   - Uitgeknipte stukke het 'n gestreepte vlak met die woord "Uitgeknip".
   - Shorts sleep op die tydlyn.
   - Leë transkripsie: "Geen onderskrifte nie, stel die begin en einde self".
   - kontrole: widget-toetse eers rooi; kiekies `out/shots/hersien-{light,dark}-{1100,1920}.png` en `hersien-opname-light-1100.png`.
6. Preke:
   - rye met twee reëls (titel tot die volle breedte, Skriflesing daaronder in kleiner tipe);
   - "Verwerk nuutste diens" (primêr): lys verfris → nuutste diens beplan → Hersien;
   - "Verwerk volgende" (sekondêr);
   - filter "Nie opgelaai nie".
   - kontrole: widget-toets eers rooi; kiekies `preke-{light,dark}-{1100,1920}.png` en `preke-light-750.png`.
7. "Voer opname in":
   - `importRecording(file, title, date)`, en `fetchMeta` vir plaaslike ID's;
   - Preke: knoppie → lêerkieser → dialoog met titel en datum → Hersien; insleep op Preke doen dieselfde.
   - kontrole: `recording_test` eers rooi (kopie, info.json, handmatige plan, `fetchMeta` sonder yt-dlp).
8. `friendlyError`:
   - `SocketException` na Ollama se poort → Ollama;
   - ander `SocketException` → "Geen internet nie …";
   - `FileSystemException` met ENOSPC (28) of Windows 112 → "Die skyf is vol …".
   - kontrole: `jobs_test` eers rooi.
9. V8: `YouTube.updateVideo`, en in Hersien "Werk op YouTube by" vir 'n opgelaaide preek.
   - kontrole: `youtube_test` (vals bediener: `PUT videos?part=snippet` met categoryId behou) eers rooi.
10. Vloeie as `vloei:`/`stap:`-kommentaar, die CONTEXT.md-reëls, en die kritiekrondes op die kiekies. Daarna `kaart.py --check`, `dart analyze`, `flutter test`, `dart format` en `flutter build linux --debug`.

## Aanvaarding
- `flutter test` groen; `dart analyze` skoon; `kaart.py --check` skoon.
- 'n Plan met 'n uitgeknipte stuk plus intro/outro sny tot een mp4: `ffprobe` gee die hoofvideo se grootte, die duur is die som, en daar is een klankstroom.
- In Hersien:
  - die hakies skuif met sleutels per 1 s / 0,1 s;
  - I/O stel die hakie;
  - Ctrl+Z draai dit terug;
  - 'n klik op 'n transkripsiereël soek daarheen.
- Preke by 750 breed: die titel is nie afgekap voor die helfte van die ry nie, en die Skriflesing staan nie teen die titel nie.
- 'n Ingevoerde opname maak in Hersien oop met die leë-toestand-teks, en kan gesny word sonder YouTube.

## Prestasie-begroting
- Geen nuwe timers of polling nie. Die voorskou luister na die bestaande posisiestroom.
- Die transkripsie is 'n `ListView.builder`; ~1500 reëls is goed.
- Ontdoen hou hoogstens 100 momentopnames.
- Stroomkopie bly die vinnige pad. Herkodering gebeur net as daar uitgeknip word of 'n klippie is (~1× tempo vir 40 min op die kerk-PC; die werkry wys vordering).

## Buite bestek
- Whisper vir opnames sonder onderskrifte (sien Vrae).
- 'n Golfvorm op die tydlyn.
- Intro/outro op Shorts (aanname).
- Video's se miniatuurprente.
- Meer as een preek tegelyk redigeer.

## Ingryp
- As `desktop_drop` nie op Linux bou nie: los insleep, hou die lêerkieser en noteer dit.
- As herkodering van 'n 60 min-preek op Linux > 2× die tydsduur neem: gebruik `-preset veryfast` en noteer dit.

## Vrae
- (aanname) Intro/outro net voor en ná die volle preek, nie op Shorts nie.
- (aanname) Met intro/outro of uitgeknipte stukke word die preek herkodeer: libx264 CRF 20 `veryfast`, aac 160k. Sonder dit bly dit stroomkopie.
- (aanname) Klippies word geskaal en gepad (swart rande) na die preek se resolusie en fps, nie gerek nie.
- (aanname) 'n Ingevoerde opname word **gekopieer** na die werkgids, nie verwys nie, sodat 'n verskuifde USB-lêer nie die werk breek nie. Die ID is `opname-JJJJMMDD-HHMMSS`.
- (oop vraag) Whisper vir eie opnames: nie gevra nie. Sonder onderskrifte is daar geen KI-plan of Shorts-onderskrifte nie; die begin en einde word met die hand gestel.
- (aanname) "Verwerk nuutste diens" verwerk die boonste preek in die kanaallys (die nuutste), ook as dit nie `nuut` is nie. Dan maak dit net Hersien oop.
- (aanname) V8 werk net die titel en beskrywing op YouTube by. Die Skriflesing staan in die beskrywing. Die snitlys skuif nie.

## Vloeie
(word ná die bou met kritiek ingevul)

## Persona's
(word ná die bou ingevul)

## Log

## Verslag

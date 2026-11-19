status: hersien

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
Vorm: skerm → aksie → wat die app wys → foutpad. Daaronder die kritiek per persona (kliks, waar die persoon vassit, wat ek verander het). In die kode as `vloei: v1…v9` (definisies bo-aan `lib/app/shell.dart`) en `stap:`-reëls by die funksies; `kaart.py --check` is skoon.

**V1 Verwerk nuutste diens** (die gewone Maandag)
Preke → "Verwerk nuutste diens" → die lys verfris, die boonste diens kry 'n beplan-taak en Hersien maak oop met die laaistappe (onderskrifte, video, Ollama) → Hersien wys die hakies by die gebede, die titel, Skriflesing en beskrywing → "Keur goed en sny" → strook "Gestuur na Werk" met **Werk** → Werk wys vordering → "Laai op" → die skakel "Maak oop op YouTube". Met intro/outro in Instellings kom die klippies voor en ná die volle preek (nie op Shorts nie).
Foutpad: geen internet → Werk: "Geen internet nie. Kyk die netwerk en probeer weer." + Probeer weer; Ollama af → "Ollama het nie geantwoord nie. Maak seker dit loop."; kwota op → "Vandag se 100 oplaaie is op; probeer môre weer.".
- Oom Johan: 4 kliks (Verwerk nuutste diens, Keur goed en sny, Werk, Laai op). Vassit: ná "Keur goed en sny" was daar net 'n strook en hy moes self weet om na Werk te gaan. **Verander:** die strook het nou 'n knoppie **Werk** wat daarheen gaan. Steeds: "Laai op" is 'n aparte klik (doelbewus: 'n mens kyk die snit voor dit publiek word).
- Schalk: dieselfde, maar met die sleutelbord in Hersien; die log in Werk wys elke ffmpeg-/yt-dlp-reël. Geen vassit nie.
- Die predikant: kyk in Hersien die titel (twee reëls, nie afgekap nie), die beskrywing met die Skriflesing, en of die begin-hakie by die gebed staan (gebedsmerker op die tydlyn, "Gebed:" in die transkripsie). "Speel van begin" wys die eerste sekondes.

**V2 'n Ou preek** (agterstand)
Preke → chip "Nie opgelaai nie" → net preke sonder oplaai, nuutste bo → klik die ry → Hersien (beplan eers as dit nuut is) → verder soos V1.
Foutpad: soos V1; 'n preek sonder onderskrifte wys die leë transkripsie met "stel self".
- Oom Johan: 2 kliks tot Hersien. Vassit: die soekveld en die chip lyk eenders belangrik. Nie verander nie (die chip het 'n wolk-ikoon en staan eerste ná die soekveld).
- Schalk: tik in die soekveld (titel of Skriflesing). Geen vassit nie.

**V3 Voer opname in** (geen YouTube nie)
Preke → "Voer opname in" (of sleep die lêer op Preke; oorleg "Los die video om dit as opname in te voer") → lêerkieser → dialoog: titel (lêernaam), datum (datumkieser) → "Voer in" → strook "Kopieer opname…" → die lêer word **gekopieer** na `<werk>/opname-JJJJMMDD-HHMMSS/video.mp4` met `info.json`, leë onderskrifte en 'n plan oor die hele lêer → Hersien met "Geen onderskrifte nie, stel die begin en einde self" → speel, I/O by die gebede → "Keur goed en sny".
Foutpad: kanselleer → niks verander nie; skyf vol → "Die skyf is vol. Maak plek (ou video's in die werkgids) en probeer weer."; 'n lêer wat ffprobe nie ken nie → die strook met die rede.
- Oom Johan: 5 kliks plus die hakies stel; die hakies sonder transkripsie is moeilik met net die muis (sleep op 'n uur lange tydlyn). Nie verander nie; Whisper sou dit oplos (oop vraag).
- Schalk: I/O en ←/→ maak dit vinnig. Vassit: die dialoog vra die datum elke keer (verstek vandag); goed so.
- Die predikant: geen KI-titel nie, die titel is die lêernaam tot iemand dit tik.

**V4 Ollama het die grense verkeerd**
Hersien → die hakie staan nie by 'n gebedsmerker nie → klik die gebed se reël in die transkripsie (video spring daarheen) → I (of sleep, of ←/→ en Shift) → "Speel van begin" om te kyk → Ctrl+Z as dit erger is → "Beplan weer" as die hele voorstel verkeerd is.
Foutpad: Beplan weer vra bevestiging (handwerk gaan verlore); Ollama af → strook met die rede.
- Oom Johan: 3 kliks (reël, dan sleep die hakie of klik die "I"-wenk se ekwivalent: hy sleep). Vassit: die sleutelwenk "I/O: begin/einde by speelkop" sê vir hom niks. Nie verander nie; die sleep werk met die muis en die ontdoen-pyle staan sigbaar regs.
- Schalk: klik reël, I, klaar: 2 aksies.
- Die predikant: sien "Gebed:" in die transkripsie en die merkers; kan bevestig dat die preek nie halfpad begin nie.

**V5 Ineenstorting of kragonderbreking**
Die app begin weer → `jobs.json` word gelees, 'n taak wat besig was, wag weer en loop van voor af → yt-dlp gaan voort met die halwe `.part`-lêer; 'n klaar `video.mp4` word oorgeslaan → 'n snit begin van voor (ffmpeg oorskryf).
Foutpad: 'n taak wat misluk, staan in Werk met die rede en Probeer weer.
- Oom Johan: 0 kliks; hy hoef niks te onthou nie. Vassit: geen boodskap sê "hervat" nie; Werk wys net weer vordering. Nie verander nie.
- Schalk: die log wys die nuwe begin. Plan-redigering in Hersien word by elke verandering gestoor, dus verloor hy hoogstens die laaste tik.

**V6 Eerste keer op die kerk-PC**
Setup.exe → die app begin op Opstelling → "Begin Ollama" → "Laai model af" (vordering) → "Koppel kanaal" (Google-aanmelding in die blaaier) → "Maak gids" → "Begin werk" → Preke.
Foutpad: geen kliënt-ID-lêer → "Kies eers die kliënt-ID-lêer in Instellings" + "Gaan na Instellings".
- Oom Johan: 5 kliks, een gevulde knoppie op 'n slag. Vassit: die kliënt-ID-lêer; dit is Schalk se werk (een keer).
- Schalk: kopieer `client_secret.json`, dan dieselfde 5 kliks.

**V7 Vinnige WhatsApp-klank**
Werk → by die gesnyde preek "WhatsApp-klank" → mp3 `JJJJ-MM-DD Tema.mp3` langs die preek → "Wys in gids" → sleep in WhatsApp.
Foutpad: nog nie gesny nie → "Sny eers die preek."
- Die WhatsApp-admin: 3 kliks (Werk, WhatsApp-klank, Wys in gids). Vassit: as die preek nog nie gesny is nie, is daar geen knoppie nie; dan moet hy Schalk of Oom Johan vra. Nie verander nie.
- Oom Johan: dieselfde 3 kliks.

**V8 Fout ná oplaai**
Preke → die opgelaaide preek → Hersien → wysig titel of beskrywing → "Werk op YouTube by" (verskyn net vir 'n opgelaaide preek) → strook "3 video's op YouTube bygewerk".
Foutpad: geen internet → strook met die internet-sin; video op YouTube uitgevee → "Video … is nie meer op YouTube nie.".
- Die predikant: sien die fout op YouTube en vra; Schalk of Oom Johan doen dit in 3 kliks plus tik.
- Oom Johan: vassit: "Keur goed en sny" staan ook nog daar (nou omlyn, nie gevul nie), sodat die gevulde knoppie "Werk op YouTube by" is. Die snit self skuif nie (aanname).

**V9 Geen internet of vol skyf**
'n Taak misluk → Werk: rooi ikoon, die sin uit `friendlyError` ("Geen internet nie …" / "Die skyf is vol …" / "Ollama het nie geantwoord nie. Maak seker dit loop.") en Probeer weer → die taak staan weer in die ry.
- Oom Johan: 1 klik (Probeer weer), ná die regstelling. Die sin sê wat om te doen; "SocketException" verskyn nie meer nie.
- Schalk: die log hou die rou fout.

## Persona's
- **Schalk**: tegnies; wil die sleutelbord (I/O, ←/→, Shift, spasie, Ctrl+Z), spoed en die log. Hersien en Werk is vir hom gebou; die kortpaaie staan in 'n wenk regs bo die lyste.
- **Oom Johan** (±65): net die muis, wil een knoppie, gewone Afrikaans en sekerheid. Elke skerm het een gevulde knoppie; toestande het 'n woord en ikoon, nie net kleur nie; foute sê wat om te doen. Sy vassit-punte: na Werk ná die snit (nou opgelos), die hakies sonder transkripsie (V3), die kliënt-ID (Schalk se werk).
- **Die predikant**: kyk die titel, Skriflesing en beskrywing, en dat die preek nie halfpad begin nie. Hersien wys die titel in twee reëls, die gebede gemerk en "Speel van begin"; V8 maak 'n fout ná oplaai reg.
- **Die WhatsApp-admin**: wil net die klank. V7: drie kliks in Werk, die lêer het die datum en tema in die naam.

## Log
- 2026-11-19 stap 1: `SermonPlan.cuts` en `parts()`; models_test rooi → groen.
- 2026-11-19 stap 2-3: `probeMedia`, `joinArgs`, `cutSermon(intro:, outro:)`; Instellings kies intro/outro met lengte; `cutJob` gee dit deur. cutter_test met regte ffmpeg op `testsrc` (320×240 @ 25 + 160×120 @ 30 sonder klank + outro): `ffprobe` 320×240, duur = som ±0,3 s, een klankstroom. jobs_test groen.
- 2026-11-19 stap 4: redigeerder-beheerder (ontdoen/herdoen, nudge, I/O, uitknip, Shorts, voorskou); review_controller_test rooi → groen.
- 2026-11-19 stap 5: redigeerder-UI; widget-toetse rooi → groen; kiekies `hersien-{light,dark}-{1100,1920}`, `hersien-opname-light-1100`.
- 2026-11-19 stap 6: Preke-rye met twee reëls, "Verwerk nuutste diens", filter; kiekies `preke-*` en `preke-light-750` (titel tot die volle breedte, Skriflesing onder).
- 2026-11-19 stap 7: "Voer opname in" (kieser, dialoog, insleep met `desktop_drop`); recording_test rooi → groen.
- 2026-11-19 stap 8: `friendlyError` (Ollama-poort, geen internet, vol skyf); errors_test rooi → groen.
- 2026-11-19 stap 9: `YouTube.updateVideo` + "Werk op YouTube by"; youtube_test (vals bediener, kategorie behou) rooi → groen.
- 2026-11-19 stap 10: vloeie V1–V9 as `vloei:`/`stap:`; `kaart:` in CONTEXT.md (die kontrole het voorheen niks gelees nie) en `status: oop` → `bou` (oop is nie 'n geldige status nie); doc-reëls by die publieke klasse. Kritiek V1: strook ná "Keur goed en sny" kry **Werk** (widget-toets rooi → groen). `flutter test` 132 groen (1 oorgeslaan), `dart analyze` skoon, `kaart.py --check` skoon (net "Onvoltooid": status bou tot /bewys), `flutter build linux --debug` bou (ook `desktop_drop`).

## Verslag
Hersien is nou die preekredigeerder: sleepbare hakies (←/→ 1 s, Shift 0,1 s, I/O by die speelkop), speel van 'n hakie en voorskou van die snit, 'n transkripsiestrook waar 'n klik soek en gebede gemerk is, uitgeknipte middelstukke (gestreep op die tydlyn, 'n lys segmente), Shorts wat sleep en wysig, en ontdoen/herdoen met Ctrl+Z / Ctrl+Shift+Z. Intro/outro kom voor en ná die volle preek. Preke het "Verwerk nuutste diens", die filter "Nie opgelaai nie", "Voer opname in" (kieser en insleep) en rye met die titel bo en die Skriflesing onder. Foute sê of dit die internet, Ollama of die skyf is. 'n Opgelaaide preek se titel en beskrywing kan met "Werk op YouTube by" reggemaak word.
Kritiekrondes op die kiekies:
- Hersien (1100/1920, lig/donker): een gevulde knoppie ("Keur goed en sny"); die titel was afgekap → twee reëls; die sleutelwenk staan stil regs. Opname-kiekie: die leë transkripsie sê wat om te doen.
- Preke (750/1100/1920): titel tot die volle breedte, Skriflesing daaronder in kleiner tipe; die soekveld is na die filterry geskuif sodat dit by 750 nie platgedruk word nie.
- Vloeie: ná "Keur goed en sny" kry die strook 'n knoppie Werk (Oom Johan).
Ongetoets: regte insleep uit 'n lêerbestuurder (net die kode-pad), die regte YouTube `videos.update` (net teen 'n vals bediener), die lêerkieser en insleep op Windows, en herkodering van 'n volle 60 min-preek op die kerk-PC (die Ingryp-reël oor `veryfast` is reeds die verstek).

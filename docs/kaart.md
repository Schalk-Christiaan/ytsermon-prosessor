# Stelselkaart

## Breinkaart

- **ytsermon-prosessor** — 'n Selfstandige Windows-app (Flutter, installeerder-exe, geen Claude nodig) wat preke van @gereformeerdekerkoranjeriv5791 aflaai, tot die preek sny, Shorts maak, en met titels/beskrywings in snitlyste terug oplaai; ook klank vir WhatsApp uitvoer.
  - Werk wat jy aanvra
    - Die hele diens verstaan
    - Preekgrense: van gebed tot gebed
    - Verwerk nuutste diens
    - 'n Ou preek verwerk
    - Voer opname in
    - Die grense is onseker of verkeerd
    - Hervat ná 'n onderbreking
    - Eerste keer op die kerk-PC
    - en 3 ander
  - Waar die geheue leef
    - —
    - werkmap/<id>/ (info.json, onderskrifte, video.mp4)
    - out/<jaar>/<diens>/
    - <werkmap>/jobs.json
    - werkmap/<id>/plan.json, analysis.json
    - <werkmap>/settings.json
    - werkmap/opname-…/ (video.mp4, info.json, leë onderskrifte, plan.json, sermon.json)
    - <app-support>/work/<id>/plan.json
    - en 4 ander
  - Die dele
    - Skerms
    - App-raam
    - Kern

## Vloeie

### Die hele diens verstaan

Die app hoor waar musiek en spraak is, benoem elke spraakstuk, en maak uit een diens drie uitvoere (volle preek, net die woord, sang) in een gids met 'n WhatsApp-teks.

Hoekom: Schalk wil die woord en die sang apart hê, en die diensorde verskil van week tot week; musiek uit die klank is betroubaarder as YouTube se merkers.

1. Klank — een ffmpeg-proses lees die klank, Dart klassifiseer elke sekonde as stilte/musiek/spraak/geraas; die uitslag word in sound.json bewaar (`lib/core/sound.dart:254–255`)
2. Spraakblokke — die woorde word gesny by musiek, 'n pouse van 3 s en "Amen"; elke blok kry later 'n etiket (`lib/core/captions.dart:181–184`)
3. Diensdatum — die dag en Oggend/Aand uit die stroom se begintyd (nie upload_date nie, wat 'n dag laat is); tema, Skriflesing en psalms uit die beskrywing (`lib/core/service_info.dart:79–119`)
4. KI-etikette — een Ollama-oproep sonder onderskrifte kry die blokke, liedere en beskrywing en gee net nommers terug (gebed voor en ná die preek); die blokke tussen die twee gebede word preek; die KI kies nooit tye nie (`lib/core/planner.dart:361–484`)
5. Grense uit etikette — preek = langste loop `preek`-blokke (≥ 15 min); begin by die eerste blok van die gebed daarvoor (terug tot by musiek), einde by die Amen van die gebed daarna; twyfel gee 'n rede vir Hersien (`lib/core/bounds.dart:52–59`)
6. Net die woord — alle spraak tussen die gebede (Skriflesing ingesluit), sonder gebede en sang, in een snit aanmekaar (`lib/core/bounds.dart:117–119`)
7. Kies die uitvoere — drie merkblokkies (almal aan, onthou in Instellings), Oggend/Aand en die soort diens; die sny gebruik dit (`lib/features/review/review_screen.dart:656–748`)
8. WhatsApp-sjabloon — die teks met plekhouers en 'n voorskou met die nuutste preek (`lib/features/playlists/playlists_screen.dart:156–233`)
9. Uitvoere — `<uitgids>/<jaar>/<datum> <Oggend|Aand> - <tema>/` kry Volle preek.mp4, Net die woord.mp4, Sang/NN <lied>.mp3, WhatsApp.txt en diens.json (`lib/core/cutter.dart:354–355`)
10. Sny die uitvoere — Volle preek, Net die woord en Sang soos in Instellings gekies, in die diensgids; dan WhatsApp.txt en diens.json (`lib/core/jobs.dart:353–355`)
11. Kopieer WhatsApp-teks — die teks langs die uitvoere (WhatsApp.txt) op die knipbord, om saam met die klank te plak (`lib/features/work/work_screen.dart:227–237`)
12. Preke-aansig — per jaar, nuutste eerste; Speel, Wys in gids en Kopieer WhatsApp-teks per diens (`lib/features/library/library_screen.dart:115–165`)
13. Sang-aansig — alle liedere met naam, diens en datum; 'n soektog wys net die liedere wat pas (`lib/features/library/library_screen.dart:167–209`)

### Preekgrense: van gebed tot gebed

Die snit begin by die eerste woord van die gebed voor die preek en eindig ná die "Amen" van die eerste gebed daarna; kode kies dit, nie Ollama nie.

Hoekom: Ollama het die grense soms verkeerd gekies (of 30 min gedink); reëls oor woordtye en stilte is herhaalbaar en binne 0,5 s.

1. Stilte-snap — begin na die einde van die laaste stilte voor die eerste woord, einde by die begin van die eerste stilte ná "Amen" (ffmpeg silencedetect, ±3 s) (`lib/core/bounds.dart:174–177`)
2. Herkodeer — libx264 presies op die grense (nie -c copy nie, wat net op 'n sleutelraam sny) (`lib/core/cutter.dart:250–252`)

### Verwerk nuutste diens

Maandag: die diens van gister word een knoppie later 'n gesnyde preek met Shorts op YouTube.

Hoekom: die gewone week; Oom Johan moet dit sonder hulp kan doen, met net een gevulde knoppie op elke skerm.

1. Verwerk nuutste diens — Preke: een knoppie verfris die lys, beplan die boonste diens en maak Hersien oop (`lib/features/sermons/sermons_screen.dart:136–148`)
   - nog besig met beplan → Hersien wys die laaistap; geen internet → strook met die rede
2. Beplan — onderskrifte + video af; Ollama benoem die blokke, kode kies die grense (gebed tot gebed, stilte-snap), Ollama skryf net teks (`lib/core/jobs.dart:296–299`)
   - Ollama af → "Ollama het nie geantwoord nie" met Probeer weer in Werkry
3. Hersien — kyk die hakies by die gebede, die titel, Skriflesing en beskrywing (`lib/features/review/review_screen.dart:196–196`)
4. Sny — herkodeer presies van die eerste woord tot ná die Amen (met intro/outro en uitgeknipte stukke saamgevoeg); uitset in die uitsetgids (`lib/core/jobs.dart:351–351`)
5. Laai op — volle preek en Shorts na YouTube, in die regte snitlys (`lib/core/jobs.dart:553–555`)
   - kwota op → "probeer môre weer"; geen internet → Probeer weer

### 'n Ou preek verwerk

'n Diens van weke gelede wat nog nie opgelaai is nie, gevind met die filter "Nie opgelaai nie".

Hoekom: die agterstand van die kanaal word so een vir een ingehaal.

1. Filter nie opgelaai nie — die chip wys net preke wat nog nie op YouTube is nie, nuutste bo (`lib/features/sermons/sermons_screen.dart:343–439`)
2. Kies die ou preek — klik die ry → Hersien; nog nie beplan nie → Hersien beplan dit eers (laaistap) (`lib/features/sermons/sermons_screen.dart:441–524`)

### Voer opname in

'n Video wat nie op YouTube is nie (USB, kamera) word gekopieer, met die hand begrens en gesny.

Hoekom: soms faal die regstreekse uitsending; dan is die eie opname die enigste bron.

1. Voer opname in — lêerkieser of insleep → dialoog met titel (lêernaam) en datum (`lib/features/sermons/sermons_screen.dart:150–341`)
   - kanselleer → niks verander nie; kopie misluk (skyf vol) → strook met friendlyError
2. Kopieer en beplan — video.mp4, info.json, leë onderskrifte en 'n plan oor die hele lêer (`lib/core/recording.dart:23–25`)
3. Stel self — geen onderskrifte nie: die strook sê so; stel begin en einde met I/O by die speelkop (`lib/features/review/transcript.dart:31–96`)
4. Sny sonder YouTube — dieselfde snit; die opname het geen Shorts-onderskrifte nie (`lib/core/jobs.dart:352–352`)

### Die grense is onseker of verkeerd

Die kode het die gebede nie seker gevind nie (Hersien wys die rede), of die hakie staan nie by die gebed nie; die mens skuif dit met die transkripsie en die sleutelbord reg.

Hoekom: die grense kom uit reëls, nie 'n KI nie, maar is net so min onfeilbaar; die predikant wil nie 'n preek wat halfpad begin nie.

1. Sien die fout — 'n banier wys waarom die kode onseker is en spring na die grens; gebedsmerkers wys waar die gebede is (`lib/features/review/review_screen.dart:197–468`)
   - kode onseker → banier met die rede (ARB) en "Gaan na die grens"
2. Soek in die transkripsie — klik die gebed se reël; die video spring daarheen (`lib/features/review/transcript.dart:30–30`)
3. Skuif die hakie — sleep, ←/→ 1 s, Shift 0,1 s, of I/O by die speelkop (`lib/features/review/review_controller.dart:359–583`)
4. Ontdoen — Ctrl+Z draai die laaste skuif terug, Ctrl+Shift+Z herdoen (`lib/features/review/review_controller.dart:355–357`)
5. Beplan weer — loop die grense en die teks weer van voor af as die hele voorstel verkeerd is (bevestiging) (`lib/features/review/review_screen.dart:79–194`)

### Hervat ná 'n onderbreking

Die app of die krag gaan af in die middel van 'n aflaai of snit; by die volgende begin loop die werk voort.

Hoekom: 'n uur se aflaai mag nie verlore gaan nie, en niemand moet onthou wat besig was nie.

1. Hervat ná 'n onderbreking — jobs.json word gelees; 'n taak wat besig was, wag weer en loop van voor af (`lib/core/jobs.dart:132–269`)
2. Aflaai hervat — yt-dlp gaan voort met die halwe .part-lêer; 'n klaar video word oorgeslaan (`lib/core/channel.dart:131–133`)
3. Mislukte taak — rooi ikoon, die rede en Probeer weer (`lib/features/work/work_screen.dart:239–239`)

### Eerste keer op die kerk-PC

Ná Setup.exe bring die Opstelling-lys alles tot groen sonder 'n terminaal.

Hoekom: die kerk-PC het geen ontwikkelaar langsaan nie.

1. Begin op Opstelling — tot setupDone waar is, wys die app net die Opstelling-lys (`lib/app/shell.dart:92–223`)
2. Kontroleer — kyk wat klaar is: Ollama, model, kanaal, uitsetgids (`lib/features/setup/setup_screen.dart:58–68`)
3. Een knoppie op 'n slag — Begin Ollama → Laai model af → Koppel kanaal → Maak gids (`lib/features/setup/setup_screen.dart:70–85`)
   - geen kliënt-ID-lêer → "Gaan na Instellings"
4. Begin werk — aktief as alles groen is; gaan na Preke en verskyn nie weer nie (`lib/features/setup/setup_screen.dart:87–280`)

### Vinnige WhatsApp-klank

Die gesnyde preek word 'n mp3 wat die WhatsApp-admin in die groep sleep.

Hoekom: baie lidmate luister net op hul foon; die admin wil nie die app leer nie.

1. WhatsApp-klank — by die gesnyde preek in Werkry; een klik (`lib/features/work/work_screen.dart:170–170`)
2. Klank uitvoer — mp3 van Net die woord (of Volle preek as dit nie gesny is nie), langs die gesnyde video (`lib/core/jobs.dart:468–470`)
   - preek nog nie gesny nie → "Sny eers die preek"
3. Wys in gids — maak die gids met die mp3 oop om in WhatsApp te sleep (`lib/features/work/work_screen.dart:171–225`)

### Fout ná oplaai

Die titel of Skriflesing is verkeerd op YouTube; Hersien stuur die regstelling sonder om weer op te laai.

Hoekom: weer oplaai kos kwota en breek die skakel wat reeds gedeel is.

1. Maak reg — open die opgelaaide preek in Hersien en wysig titel of beskrywing (`lib/features/review/review_screen.dart:470–654`)
2. Werk op YouTube by — knoppie verskyn net vir 'n opgelaaide preek; strook sê hoeveel video's (`lib/features/review/review_screen.dart:750–807`)
   - geen internet of video weg → strook met friendlyError
3. Stuur na elke opgelaaide video — titel en beskrywing uit die plan, per mp4-uitset (`lib/core/jobs.dart:527–528`)
4. YouTube PUT — haal die snippet, verander titel en beskrywing, stuur dit terug (`lib/core/youtube.dart:300–389`)
   - video weg → "Video … is nie meer op YouTube nie."

### Geen internet of vol skyf

'n Taak misluk; Werkry sê in gewone taal wat fout is en hoe om dit reg te stel.

Hoekom: "SocketException" sê niks vir Oom Johan nie; die regstelling moet in die boodskap staan.

1. Gewone-taal fout — internet, Ollama of vol skyf word elk sy eie sin met die regstelling (`lib/core/jobs.dart:96–97`)
2. Werkry wys die rede — die sin uit friendlyError onder die taak, met Probeer weer (`lib/features/work/work_screen.dart:240–286`)
3. Probeer weer — die mislukte taak staan weer in die ry, die werk tot dusver bly (`lib/core/jobs.dart:271–294`)

## Geheue

| Lêer | Wat dit hou | Wie skryf |
|---|---|---|
| `—` |  | bounds, captions, library, library_screen, models, paths, playlists, review_screen, sermons_screen, service_timeline, shell, system_status, theme, tools, transcript, work_screen |
| `werkmap/<id>/ (info.json, onderskrifte, video.mp4)` |  | channel |
| `out/<jaar>/<diens>/` | Volle preek.mp4, Net die woord.mp4, Sang/*.mp3, Shorts | cutter |
| `<werkmap>/jobs.json` | die ry; sermon.json van die preek wat verwerk word | jobs |
| `werkmap/<id>/plan.json, analysis.json` | die plan; die etikette van die spraakblokke, die liedere en die diens-soort | planner |
| `<werkmap>/settings.json` | reëls en jabloon | playlists_screen, settings, settings_screen, setup_screen |
| `werkmap/opname-…/ (video.mp4, info.json, leë onderskrifte, plan.json, sermon.json)` |  | recording |
| `<app-support>/work/<id>/plan.json` | die plan; elke wysiging stoor dadelik | review_controller |
| `<werkmap>/<id>/service.json` | Oggend/Aand en diens-soort wat Schalk in Hersien kies | service_info |
| `<werkmap>/<id>/sound.json` | die klas van elke sekonde (stilte/musiek/spraak/geraas) | sound |
| `<werkmap>/<id>/sermon.json` | atomies (.tmp, dan hernoem) | store |
| `refresh-token (deur die roeper: Windows Credential Manager / libsecret); <werkmap>/quota.json; <werkmap>/<id>/upload-*.json` | hervat-sessie | youtube |

## Dele

Pyl = roep; pyle wat ook via 'n ander hoofstuk loop, is weggelaat (volle lys in die tabel).

```mermaid
flowchart TB
  subgraph g0["skerm"]
    n6["library_screen"]:::bou
    n11["playlists_screen"]:::bou
    n14["review_screen"]:::bou
    n15["sermons_screen"]:::bou
    n19["settings_screen"]:::bou
    n20["setup_screen"]:::bou
    n21["shell"]:::bou
    n24["system_status"]:::bou
    n28["work_screen"]:::bou
  end
  subgraph g1["module"]
    n0["bounds"]:::bou
    n1["captions"]:::bou
    n2["channel"]:::bou
    n3["cutter"]:::bou
    n4["jobs"]:::bou
    n5["library"]:::bou
    n7["models"]:::bou
    n8["paths"]:::bou
    n9["planner"]:::bou
    n10["playlists"]:::bou
    n12["recording"]:::bou
    n13["review_controller"]:::bou
    n16["service_info"]:::bou
    n17["service_timeline"]:::bou
    n18["settings"]:::bou
    n22["sound"]:::bou
    n23["store"]:::bou
    n25["theme"]:::bou
    n26["tools"]:::bou
    n27["transcript"]:::bou
    n29["youtube"]:::bou
  end
  n0 --> n3
  classDef bou fill:#fde68a,stroke:#b45309,color:#000
  classDef klaar fill:#bbf7d0,stroke:#15803d,color:#000
  classDef stukkend fill:#fecaca,stroke:#b91c1c,color:#000
```

| Naam | Soort | Wanneer | Doel | Roep | Status | Lêer | Inhoud |
|---|---|---|---|---|---|---|---|
| bounds | module | ná die KI-etikette (Planner.analyse), in planJob (met die video af, vir die stilte-snap) | kies die snit-grense met reëls uit die etikette van die spraakblokke (die KI kies nooit tye): preek = langste loop preek-blokke, begin by die gebed voor, einde by die Amen van die gebed ná die preek; snapBounds pas albei by die naaste stilte aan (ffmpeg silencedetect) |  | bou | `lib/core/bounds.dart` | sermonRuns, findBounds, musicBetween, wordParts, snapStart, snapEnd, snapBounds |
| captions | module | ná fetchMeta | json3-onderskrifte → segmente met woordtye, kompakte teks vir die KI (uit blokke), spraakblokke (pouse/Amen/musiek), SRT |  | bou | `lib/core/captions.dart` | parseJson3, formatTime, compact, toSrt, wordsOf, blocks |
| channel | module | as 'n preek-URL gelaai word | lys die kanaal (flat), video-ID uit URL, haal metadata + af-orig-onderskrifte, laai die video een keer af |  | bou | `lib/core/channel.dart` | ChannelItem, parseChannel, listChannel, videoIdFromUrl, parseProgress, FetchedMeta, fetchMeta, downloadVideo, InfoFields |
| cutter | module | by 'Keur goed en sny' en 'Klank vir WhatsApp' | gids per diens (serviceDir), sny Volle preek en Net die woord (herkodeer net die stuk, of segmente plus intro/outro saamgevoeg), Shorts (9:16 met ingebrande onderskrif), elke lied as mp3 en WhatsApp-klank (mono mp3 64 kbps) met ffmpeg; skryf die WhatsApp-teks |  | bou | `lib/core/cutter.dart` | sermonFileName, sermonArgs, silenceArgs, shortArgs, audioArgs, MediaInfo, probeMedia, joinArgs, parseFfmpegProgress, cutParts, cutShort, cutAudio, serviceDir, songArgs, cutSong, longDate, whatsappText |
| jobs | module | "Verwerk volgende", "Keur goed en sny", "Beplan weer", "Klank vir WhatsApp", "Laai op" en by begin (hervat) | een taak op 'n slag (plan: klank → blokke → etikette → grense → stilte-snap; sny: die gekose uitvoere in die diensgids met WhatsApp.txt en diens.json; klank of oplaai), hervat ná herbegin, kanselleer, probeer weer |  | bou | `lib/core/jobs.dart` | JobKind, JobStatus, JobPhase, Job, JobCtx, friendlyError, JobQueue, planJob, cutJob, audioJob, updateOnYouTube, uploadJob |
| library | module | as die Biblioteek-skerm oopmaak of herlaai | lees elke <uitvoer>/<jaar>/<diens>/diens.json in een lys diens (nuutste eerste) met hul liedere; die blaaier soek daarin |  | bou | `lib/core/library.dart` | LibrarySong, LibraryService, readService, loadLibrary, libraryWhatsapp |
| library_screen | skerm | Biblioteek (rail) | die dienste in die uitvoergids as Preke (per jaar, nuutste eerste) en Sang (alle liedere); soek op tema, skriflesing en liedname; Speel, Wys in gids, Kopieer WhatsApp-teks; laai by oopmaak en met Herlaai |  | bou | `lib/features/library/library_screen.dart` | LibraryScreen |
| models | module | oral waar 'n plan gebruik word | Word, Segment (met woordtye), TimeBlock, Block/BlockLabel (spraakblok met etiket), Song, Bounds, Short, Span, SermonPlan (preek minus uitgeknipte stukke = segmente) met JSON |  | bou | `lib/core/models.dart` | SegmentKind, Word, Segment, TimeBlock, BlockLabel, Block, Song, BoundsDoubt, Bounds, Short, Span, SermonPlan |
| paths | module | by laai en sny | werkmap, gebundelde lettertipe en verstek-uitsetgids |  | bou | `lib/core/paths.dart` | workRoot, bundledFont, defaultOutDir |
| planner | module | ná captions, een Ollama-oproep per preek | laat qwen3:8b net teks skryf (Shorts, titel, beskrywing) binne die snit wat findBounds reeds bepaal het (geen grense van die KI nie); analyse() benoem die spraakblokke en liedere (nooit tye); validate() toets die plan, shortFault() elke Short apart; berg plan.json op |  | bou | `lib/core/planner.dart` | PlanException, parseTime, validate, ShortFault, shortFault, savePlan, ollamaChat, Analysis, saveAnalysis, songStretches, Planner |
| playlists | module | by oplaai en in die Snitlyste-skerm se voorskou | snitlysnaam per preek uit reëls (Bybelboek, jaar) en die YouTube-beskrywing uit die jabloon |  | bou | `lib/core/playlists.dart` | bookFrom, playlistFor, describe |
| playlists_screen | skerm | Snitlyste (rail) | snitlysreëls aan/af en in volgorde, voorskou hoeveel preke in elke snitlys val, beskrywingsjabloon, WhatsApp-sjabloon met voorskou |  | bou | `lib/features/playlists/playlists_screen.dart` | PlaylistsScreen |
| recording | module | by "Voer opname in" (knoppie of insleep op Preke) | 'n eie video-opname (nie op YouTube nie) word 'n preek met 'n plaaslike ID en 'n handmatige plan, sodat Hersien en sny dit soos enige ander preek hanteer |  | bou | `lib/core/recording.dart` | importRecording |
| review_controller | module | Hersien-skerm | laai meta en plan van 'n preek uit die stoor en redigeer dit (hakies, gebedsmerkers uit die etikette (analysis.json), I/O, uitknip, Shorts, ontdoen/herdoen, voorskou van die snit); plan en sny loop deur die werkry |  | bou | `lib/features/review/review_controller.dart` | ReviewState, LoadStage, ReviewController |
| review_screen | skerm | Hersien (rail) | die preekredigeerder: preek uit Preke → plan → hakies, I/O, uitknip, transkripsie, Shorts, ontdoen (kortpaaie) → kies uitvoere, Oggend/Aand en soort diens (liedname op die tydlyn) → keur goed en sny |  | bou | `lib/features/review/review_screen.dart` | ReviewScreen |
| sermons_screen | skerm | Preke (rail, tuis) | die hele kanaal as lys met toestand (titel bo, Skriflesing onder); filter (ook "Nie opgelaai nie"), soek; "Verwerk nuutste diens" → plan → Hersien; "Verwerk volgende" → werkry; "Voer opname in" (knoppie of insleep) → Hersien |  | bou | `lib/features/sermons/sermons_screen.dart` | stateLabel, stateIcon, SermonsScreen |
| service_info | module | ná fetchMeta (info.json) en in cutJob | diensdatum in plaaslike tyd (nie upload_date nie), Oggend/Aand en die velde uit die YouTube-beskrywing (tema, skriflesing, fokus, belydenis, psalms); Schalk se keuses oor Oggend/Aand en diens-soort |  | bou | `lib/core/service_info.dart` | serviceStart, ServiceInfo, applyChoices, saveChoices |
| service_timeline | module | Hersien-skerm | dienstydlyn: spraak/musiek, gebedsmerkers, sleepbare preek-hakies (sleutels 1 s / Shift 0,1 s), uitgeknipte stukke gestreep, sleepbare Shorts (ongeldige met foutkleur), speelposisie |  | bou | `lib/features/review/service_timeline.dart` | ServiceTimeline |
| settings | module | by begin gelaai; gestoor as Instellings of Snitlyste verander | Schalk se keuses: kliënt-ID-lêer, oplaai-privaatheid, beskrywingsjabloon, snitlysreëls, uitsetgids, watter uitvoere 'n sny maak, WhatsApp-sjabloon, of Opstelling klaar is |  | bou | `lib/core/settings.dart` | AppSettings |
| settings_screen | skerm | Instellings (rail) | Kanaal (kliënt-ID-lêer, Koppel/Ontkoppel, privaatheid van oplaaie), uitsetgids, intro/outro (met lengte) en Opstelling, bo die Stelsel-lys |  | bou | `lib/features/settings/settings_screen.dart` | SettingsScreen, pickVideoFile |
| setup_screen | skerm | eerste begin (setupDone vals); Instellings → Opstelling | Opstelling-lys: Ollama loop → model afgelaai → kanaal gekoppel → uitsetgids, elk een knoppie; "Begin werk" as alles klaar is |  | bou | `lib/features/setup/setup_screen.dart` | SetupScreen |
| shell | skerm | by opstart | NavigationRail: Preke (tuis), Hersien, Werk, Snitlyste, Biblioteek, Instellings (Kanaal + Stelsel); begin op Opstelling tot dit klaar is |  | bou | `lib/app/shell.dart` | Shell |
| sound | module | in planJob, ná die aflaai (die video is nodig) | een ffmpeg-proses gee 16 kHz-PCM; Dart bereken per sekonde lae-energie-rame, platheid en dB en klassifiseer in stilte/musiek/spraak/geraas (spektrogram, nie YouTube se [musiek]-merkers nie) |  | bou | `lib/core/sound.dart` | soundArgs, SoundFeatures, soundFeatures, analyseSound, classify, saveSound, loadSound, soundBlocks |
| store | module | by begin (laai almal) en by elke toestandsverandering van 'n preek | elke diens as Sermon met toestand wat herbegin oorleef; voeg die kanaallys by |  | bou | `lib/core/store.dart` | scriptureFrom, writeJson, SermonState, Sermon, SermonStore |
| system_status | skerm | Instellings → Stelsel | wys yt-dlp/ffmpeg/ffprobe/Ollama met ikoon + woord (Gereed / Ontbreek); "Werk yt-dlp by" |  | bou | `lib/features/settings/system_status.dart` | updateYtDlpSnack, SystemStatus |
| theme | module | by opstart | ontwerpstelsel (kleure, tipe) uit planne/hoofplan.md, lig + donker |  | bou | `lib/app/theme.dart` | AppTokens, buildTheme |
| tools | module | by oopmaak van Instellings en voor elke aflaai/KI-oproep | vind yt-dlp/ffmpeg/ffprobe/ollama (langs die exe, Ollama se gids, PATH), loop eksterne prosesse (runTool), toets Ollama + qwen3:8b, laai die model af, begin Ollama |  | bou | `lib/core/tools.dart` | ollamaBase, findExecutable, JobCancelled, runTool, ToolStatus, openPath, updateYtDlp, probeOllama, pullModel, startOllama, probeAll |
| transcript | module | Hersien-skerm | transkripsiestrook: onderskrifreëls met tyd, klik soek daarheen, gebede gemerk, huidige reël uitgelig; leeg = stel self |  | bou | `lib/features/review/transcript.dart` | Transcript |
| work_screen | skerm | Werk (rail) | wys die werkry: huidige taak met vordering en Kanselleer, wag-, klaar- en fout-lyste; klaar-items: Speel, Wys in gids, Klank vir WhatsApp, Kopieer WhatsApp-teks, Laai op, Wys op YouTube; oplaai-teller |  | bou | `lib/features/work/work_screen.dart` | WorkScreen |
| youtube | module | "Koppel kanaal" (Instellings) en die oplaai-taak in die werkry | desktop-OAuth (loopback + PKCE), hervatbare oplaai, snitlyste en die 100-per-dag-teller; net dart:io, endpunte uit die kliëntlêer sodat toetse 'n vals bediener gebruik |  | bou | `lib/core/youtube.dart` | GoogleAuth, YouTube, QuotaExceeded, UploadQuota |

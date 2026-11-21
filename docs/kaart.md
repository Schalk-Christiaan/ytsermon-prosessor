# Stelselkaart

## Breinkaart

- **ytsermon-prosessor-preekgrense-gebed** — 'n Selfstandige Windows-app (Flutter, installeerder-exe, geen Claude nodig) wat preke van @gereformeerdekerkoranjeriv5791 aflaai, tot die preek sny, Shorts maak, en met titels/beskrywings in snitlyste terug oplaai; ook klank vir WhatsApp uitvoer.
  - Werk wat jy aanvra
    - Preekgrense: van gebed tot gebed
    - Verwerk nuutste diens
    - 'n Ou preek verwerk
    - Voer opname in
    - Die grense is onseker of verkeerd
    - Hervat ná 'n onderbreking
    - Eerste keer op die kerk-PC
    - Vinnige WhatsApp-klank
    - en 2 ander
  - Waar die geheue leef
    - —
    - werkmap/<id>/ (info.json, onderskrifte, video.mp4)
    - out/
    - <werkmap>/jobs.json
    - werkmap/<id>/plan.json
    - <werkmap>/settings.json
    - werkmap/opname-…/ (video.mp4, info.json, leë onderskrifte, plan.json, sermon.json)
    - <app-support>/work/<id>/plan.json
    - en 2 ander
  - Die dele
    - Skerms
    - App-raam
    - Kern

## Vloeie

### Preekgrense: van gebed tot gebed

Die snit begin by die eerste woord van die gebed voor die preek en eindig ná die "Amen" van die eerste gebed daarna; kode kies dit, nie Ollama nie.

Hoekom: Ollama het die grense soms verkeerd gekies (of 30 min gedink); reëls oor woordtye en stilte is herhaalbaar en binne 0,5 s.

1. Gebede soek — woordtye uit die onderskrifte; 'n gebed loop van die merkwoord ("Kom ons bid", "Onse Vader") tot die "Amen"-woord (`lib/core/captions.dart:205–207`)
2. Preek en grense — preek = langste stuk sonder Amen of musiek; begin by die gebed daarvoor, einde by die Amen van die eerste gebed daarna; twyfel gee 'n rede vir Hersien (`lib/core/bounds.dart:22–27`)
3. Stilte-snap — begin na die einde van die laaste stilte voor die eerste woord, einde by die begin van die eerste stilte ná "Amen" (ffmpeg silencedetect, ±3 s) (`lib/core/bounds.dart:101–104`)
4. Herkodeer — libx264 presies op die grense (nie -c copy nie, wat net op 'n sleutelraam sny) (`lib/core/cutter.dart:249–251`)

### Verwerk nuutste diens

Maandag: die diens van gister word een knoppie later 'n gesnyde preek met Shorts op YouTube.

Hoekom: die gewone week; Oom Johan moet dit sonder hulp kan doen, met net een gevulde knoppie op elke skerm.

1. Verwerk nuutste diens — Preke: een knoppie verfris die lys, beplan die boonste diens en maak Hersien oop (`lib/features/sermons/sermons_screen.dart:136–148`)
   - nog besig met beplan → Hersien wys die laaistap; geen internet → strook met die rede
2. Beplan — onderskrifte + video af; kode kies die grense (gebed tot gebed, stilte-snap), Ollama skryf net teks (`lib/core/jobs.dart:289–292`)
   - Ollama af → "Ollama het nie geantwoord nie" met Probeer weer in Werkry
3. Hersien — kyk die hakies by die gebede, die titel, Skriflesing en beskrywing (`lib/features/review/review_screen.dart:194–194`)
4. Sny — herkodeer presies van die eerste woord tot ná die Amen (met intro/outro en uitgeknipte stukke saamgevoeg); uitset in die uitsetgids (`lib/core/jobs.dart:330–330`)
5. Laai op — volle preek en Shorts na YouTube, in die regte snitlys (`lib/core/jobs.dart:465–467`)
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
4. Sny sonder YouTube — dieselfde snit; die opname het geen Shorts-onderskrifte nie (`lib/core/jobs.dart:331–332`)

### Die grense is onseker of verkeerd

Die kode het die gebede nie seker gevind nie (Hersien wys die rede), of die hakie staan nie by die gebed nie; die mens skuif dit met die transkripsie en die sleutelbord reg.

Hoekom: die grense kom uit reëls, nie 'n KI nie, maar is net so min onfeilbaar; die predikant wil nie 'n preek wat halfpad begin nie.

1. Sien die fout — 'n banier wys waarom die kode onseker is en spring na die grens; gebedsmerkers wys waar die gebede is (`lib/features/review/review_screen.dart:195–464`)
   - kode onseker → banier met die rede (ARB) en "Gaan na die grens"
2. Soek in die transkripsie — klik die gebed se reël; die video spring daarheen (`lib/features/review/transcript.dart:30–30`)
3. Skuif die hakie — sleep, ←/→ 1 s, Shift 0,1 s, of I/O by die speelkop (`lib/features/review/review_controller.dart:312–536`)
4. Ontdoen — Ctrl+Z draai die laaste skuif terug, Ctrl+Shift+Z herdoen (`lib/features/review/review_controller.dart:308–310`)
5. Beplan weer — loop die grense en die teks weer van voor af as die hele voorstel verkeerd is (bevestiging) (`lib/features/review/review_screen.dart:77–192`)

### Hervat ná 'n onderbreking

Die app of die krag gaan af in die middel van 'n aflaai of snit; by die volgende begin loop die werk voort.

Hoekom: 'n uur se aflaai mag nie verlore gaan nie, en niemand moet onthou wat besig was nie.

1. Hervat ná 'n onderbreking — jobs.json word gelees; 'n taak wat besig was, wag weer en loop van voor af (`lib/core/jobs.dart:130–267`)
2. Aflaai hervat — yt-dlp gaan voort met die halwe .part-lêer; 'n klaar video word oorgeslaan (`lib/core/channel.dart:130–132`)
3. Mislukte taak — rooi ikoon, die rede en Probeer weer (`lib/features/work/work_screen.dart:215–215`)

### Eerste keer op die kerk-PC

Ná Setup.exe bring die Opstelling-lys alles tot groen sonder 'n terminaal.

Hoekom: die kerk-PC het geen ontwikkelaar langsaan nie.

1. Begin op Opstelling — tot setupDone waar is, wys die app net die Opstelling-lys (`lib/app/shell.dart:88–213`)
2. Kontroleer — kyk wat klaar is: Ollama, model, kanaal, uitsetgids (`lib/features/setup/setup_screen.dart:58–68`)
3. Een knoppie op 'n slag — Begin Ollama → Laai model af → Koppel kanaal → Maak gids (`lib/features/setup/setup_screen.dart:70–85`)
   - geen kliënt-ID-lêer → "Gaan na Instellings"
4. Begin werk — aktief as alles groen is; gaan na Preke en verskyn nie weer nie (`lib/features/setup/setup_screen.dart:87–280`)

### Vinnige WhatsApp-klank

Die gesnyde preek word 'n mp3 wat die WhatsApp-admin in die groep sleep.

Hoekom: baie lidmate luister net op hul foon; die admin wil nie die app leer nie.

1. WhatsApp-klank — by die gesnyde preek in Werkry; een klik (`lib/features/work/work_screen.dart:164–164`)
2. Klank uitvoer — mp3 `JJJJ-MM-DD Tema.mp3` langs die gesnyde preek (`lib/core/jobs.dart:388–390`)
   - preek nog nie gesny nie → "Sny eers die preek"
3. Wys in gids — maak die gids met die mp3 oop om in WhatsApp te sleep (`lib/features/work/work_screen.dart:165–213`)

### Fout ná oplaai

Die titel of Skriflesing is verkeerd op YouTube; Hersien stuur die regstelling sonder om weer op te laai.

Hoekom: weer oplaai kos kwota en breek die skakel wat reeds gedeel is.

1. Maak reg — open die opgelaaide preek in Hersien en wysig titel of beskrywing (`lib/features/review/review_screen.dart:466–691`)
2. Werk op YouTube by — knoppie verskyn net vir 'n opgelaaide preek; strook sê hoeveel video's (`lib/features/review/review_screen.dart:693–750`)
   - geen internet of video weg → strook met friendlyError
3. Stuur na elke opgelaaide video — titel en beskrywing uit die plan, per mp4-uitset (`lib/core/jobs.dart:439–440`)
4. YouTube PUT — haal die snippet, verander titel en beskrywing, stuur dit terug (`lib/core/youtube.dart:300–389`)
   - video weg → "Video … is nie meer op YouTube nie."

### Geen internet of vol skyf

'n Taak misluk; Werkry sê in gewone taal wat fout is en hoe om dit reg te stel.

Hoekom: "SocketException" sê niks vir Oom Johan nie; die regstelling moet in die boodskap staan.

1. Gewone-taal fout — internet, Ollama of vol skyf word elk sy eie sin met die regstelling (`lib/core/jobs.dart:94–95`)
2. Werkry wys die rede — die sin uit friendlyError onder die taak, met Probeer weer (`lib/features/work/work_screen.dart:216–262`)
3. Probeer weer — die mislukte taak staan weer in die ry, die werk tot dusver bly (`lib/core/jobs.dart:269–287`)

## Geheue

| Lêer | Wat dit hou | Wie skryf |
|---|---|---|
| `—` |  | bounds, captions, models, paths, playlists, review_screen, sermons_screen, service_timeline, shell, system_status, theme, tools, transcript, work_screen |
| `werkmap/<id>/ (info.json, onderskrifte, video.mp4)` |  | channel |
| `out/` |  | cutter |
| `<werkmap>/jobs.json` | die ry; sermon.json van die preek wat verwerk word | jobs |
| `werkmap/<id>/plan.json` |  | planner |
| `<werkmap>/settings.json` | reëls en jabloon | playlists_screen, settings, settings_screen, setup_screen |
| `werkmap/opname-…/ (video.mp4, info.json, leë onderskrifte, plan.json, sermon.json)` |  | recording |
| `<app-support>/work/<id>/plan.json` | die plan; elke wysiging stoor dadelik | review_controller |
| `<werkmap>/<id>/sermon.json` | atomies (.tmp, dan hernoem) | store |
| `refresh-token (deur die roeper: Windows Credential Manager / libsecret); <werkmap>/quota.json; <werkmap>/<id>/upload-*.json` | hervat-sessie | youtube |

## Dele

Pyl = roep; pyle wat ook via 'n ander hoofstuk loop, is weggelaat (volle lys in die tabel).

```mermaid
flowchart TB
  subgraph g0["skerm"]
    n9["playlists_screen"]:::bou
    n12["review_screen"]:::bou
    n13["sermons_screen"]:::bou
    n16["settings_screen"]:::bou
    n17["setup_screen"]:::bou
    n18["shell"]:::bou
    n20["system_status"]:::bou
    n24["work_screen"]:::bou
  end
  subgraph g1["module"]
    n0["bounds"]:::bou
    n1["captions"]:::bou
    n2["channel"]:::bou
    n3["cutter"]:::bou
    n4["jobs"]:::bou
    n5["models"]:::bou
    n6["paths"]:::bou
    n7["planner"]:::bou
    n8["playlists"]:::bou
    n10["recording"]:::bou
    n11["review_controller"]:::bou
    n14["service_timeline"]:::bou
    n15["settings"]:::bou
    n19["store"]:::bou
    n21["theme"]:::bou
    n22["tools"]:::bou
    n23["transcript"]:::bou
    n25["youtube"]:::bou
  end
  n0 --> n3
  classDef bou fill:#fde68a,stroke:#b45309,color:#000
  classDef klaar fill:#bbf7d0,stroke:#15803d,color:#000
  classDef stukkend fill:#fecaca,stroke:#b91c1c,color:#000
```

| Naam | Soort | Wanneer | Doel | Roep | Status | Lêer | Inhoud |
|---|---|---|---|---|---|---|---|
| bounds | module | ná parseJson3 en prayers, in planJob (met die video af, vir die stilte-snap) | kies die snit-grense met reëls (geen KI): preek = langste stuk sonder Amen of musiek, begin by die gebed voor, einde by die Amen van die eerste gebed ná die preek; snapBounds pas albei by die naaste stilte aan (ffmpeg silencedetect) |  | bou | `lib/core/bounds.dart` | findBounds, snapStart, snapEnd, snapBounds |
| captions | module | ná fetchMeta | json3-onderskrifte → segmente met woordtye, kompakte teks vir die KI, kandidaat-gebede op woordvlak (merkwoord tot Amen-woord, vir findBounds), SRT en dienstydlyn (spraak/musiek) |  | bou | `lib/core/captions.dart` | parseJson3, formatTime, compact, toSrt, timeline, wordsOf, prayers |
| channel | module | as 'n preek-URL gelaai word | lys die kanaal (flat), video-ID uit URL, haal metadata + af-orig-onderskrifte, laai die video een keer af |  | bou | `lib/core/channel.dart` | ChannelItem, parseChannel, listChannel, videoIdFromUrl, parseProgress, FetchedMeta, fetchMeta, downloadVideo, InfoFields |
| cutter | module | by 'Keur goed en sny' en 'Klank vir WhatsApp' | sny die preek (herkodeer net die preekstuk, of segmente plus intro/outro saamgevoeg), Shorts (9:16 met ingebrande onderskrif) en WhatsApp-klank (mono mp3 64 kbps) met ffmpeg |  | bou | `lib/core/cutter.dart` | sermonFileName, sermonArgs, silenceArgs, shortArgs, audioArgs, MediaInfo, probeMedia, joinArgs, parseFfmpegProgress, cutSermon, cutShort, cutAudio |
| jobs | module | "Verwerk volgende", "Keur goed en sny", "Beplan weer", "Klank vir WhatsApp", "Laai op" en by begin (hervat) | een taak op 'n slag (plan met grense en stilte-snap, sny, klank of oplaai), hervat ná herbegin, kanselleer, probeer weer |  | bou | `lib/core/jobs.dart` | JobKind, JobStatus, JobPhase, Job, JobCtx, friendlyError, JobQueue, planJob, cutJob, audioJob, updateOnYouTube, uploadJob |
| models | module | oral waar 'n plan gebruik word | Word, Segment (met woordtye), TimeBlock, Prayer, Bounds, Short, Span, SermonPlan (preek minus uitgeknipte stukke = segmente) met JSON |  | bou | `lib/core/models.dart` | SegmentKind, Word, Segment, TimeBlock, Prayer, BoundsDoubt, Bounds, Short, Span, SermonPlan |
| paths | module | by laai en sny | werkmap, gebundelde lettertipe en verstek-uitsetgids |  | bou | `lib/core/paths.dart` | workRoot, bundledFont, defaultOutDir |
| planner | module | ná captions, een Ollama-oproep per preek | laat qwen3:8b net teks skryf (Shorts, titel, beskrywing) binne die snit wat findBounds reeds bepaal het (geen grense van die KI nie); validate() toets die plan, shortFault() elke Short apart; berg plan.json op |  | bou | `lib/core/planner.dart` | PlanException, parseTime, validate, ShortFault, shortFault, savePlan, Planner |
| playlists | module | by oplaai en in die Snitlyste-skerm se voorskou | snitlysnaam per preek uit reëls (Bybelboek, jaar) en die YouTube-beskrywing uit die jabloon |  | bou | `lib/core/playlists.dart` | bookFrom, playlistFor, describe |
| playlists_screen | skerm | Snitlyste (rail) | snitlysreëls aan/af en in volgorde, voorskou hoeveel preke in elke snitlys val, beskrywingsjabloon |  | bou | `lib/features/playlists/playlists_screen.dart` | PlaylistsScreen |
| recording | module | by "Voer opname in" (knoppie of insleep op Preke) | 'n eie video-opname (nie op YouTube nie) word 'n preek met 'n plaaslike ID en 'n handmatige plan, sodat Hersien en sny dit soos enige ander preek hanteer |  | bou | `lib/core/recording.dart` | importRecording |
| review_controller | module | Hersien-skerm | laai meta en plan van 'n preek uit die stoor en redigeer dit (hakies, gebedsmerkers uit prayers(), I/O, uitknip, Shorts, ontdoen/herdoen, voorskou van die snit); plan en sny loop deur die werkry |  | bou | `lib/features/review/review_controller.dart` | ReviewState, LoadStage, ReviewController |
| review_screen | skerm | Hersien (rail) | die preekredigeerder: preek uit Preke → plan → hakies, I/O, uitknip, transkripsie, Shorts, ontdoen (kortpaaie) → keur goed en sny |  | bou | `lib/features/review/review_screen.dart` | ReviewScreen |
| sermons_screen | skerm | Preke (rail, tuis) | die hele kanaal as lys met toestand (titel bo, Skriflesing onder); filter (ook "Nie opgelaai nie"), soek; "Verwerk nuutste diens" → plan → Hersien; "Verwerk volgende" → werkry; "Voer opname in" (knoppie of insleep) → Hersien |  | bou | `lib/features/sermons/sermons_screen.dart` | stateLabel, stateIcon, SermonsScreen |
| service_timeline | module | Hersien-skerm | dienstydlyn: spraak/musiek, gebedsmerkers, sleepbare preek-hakies (sleutels 1 s / Shift 0,1 s), uitgeknipte stukke gestreep, sleepbare Shorts (ongeldige met foutkleur), speelposisie |  | bou | `lib/features/review/service_timeline.dart` | ServiceTimeline |
| settings | module | by begin gelaai; gestoor as Instellings of Snitlyste verander | Schalk se keuses: kliënt-ID-lêer, oplaai-privaatheid, beskrywingsjabloon, snitlysreëls, uitsetgids, of Opstelling klaar is |  | bou | `lib/core/settings.dart` | AppSettings |
| settings_screen | skerm | Instellings (rail) | Kanaal (kliënt-ID-lêer, Koppel/Ontkoppel, privaatheid van oplaaie), uitsetgids, intro/outro (met lengte) en Opstelling, bo die Stelsel-lys |  | bou | `lib/features/settings/settings_screen.dart` | SettingsScreen, pickVideoFile |
| setup_screen | skerm | eerste begin (setupDone vals); Instellings → Opstelling | Opstelling-lys: Ollama loop → model afgelaai → kanaal gekoppel → uitsetgids, elk een knoppie; "Begin werk" as alles klaar is |  | bou | `lib/features/setup/setup_screen.dart` | SetupScreen |
| shell | skerm | by opstart | NavigationRail: Preke (tuis), Hersien, Werk, Snitlyste, Instellings (Kanaal + Stelsel); begin op Opstelling tot dit klaar is |  | bou | `lib/app/shell.dart` | Shell |
| store | module | by begin (laai almal) en by elke toestandsverandering van 'n preek | elke diens as Sermon met toestand wat herbegin oorleef; voeg die kanaallys by |  | bou | `lib/core/store.dart` | scriptureFrom, writeJson, SermonState, Sermon, SermonStore |
| system_status | skerm | Instellings → Stelsel | wys yt-dlp/ffmpeg/ffprobe/Ollama met ikoon + woord (Gereed / Ontbreek); "Werk yt-dlp by" |  | bou | `lib/features/settings/system_status.dart` | updateYtDlpSnack, SystemStatus |
| theme | module | by opstart | ontwerpstelsel (kleure, tipe) uit planne/hoofplan.md, lig + donker |  | bou | `lib/app/theme.dart` | AppTokens, buildTheme |
| tools | module | by oopmaak van Instellings en voor elke aflaai/KI-oproep | vind yt-dlp/ffmpeg/ffprobe/ollama (langs die exe, Ollama se gids, PATH), loop eksterne prosesse (runTool), toets Ollama + qwen3:8b, laai die model af, begin Ollama |  | bou | `lib/core/tools.dart` | ollamaBase, findExecutable, JobCancelled, runTool, ToolStatus, openPath, updateYtDlp, probeOllama, pullModel, startOllama, probeAll |
| transcript | module | Hersien-skerm | transkripsiestrook: onderskrifreëls met tyd, klik soek daarheen, gebede gemerk, huidige reël uitgelig; leeg = stel self |  | bou | `lib/features/review/transcript.dart` | Transcript |
| work_screen | skerm | Werk (rail) | wys die werkry: huidige taak met vordering en Kanselleer, wag-, klaar- en fout-lyste; klaar-items: Speel, Wys in gids, Klank vir WhatsApp, Laai op, Wys op YouTube; oplaai-teller |  | bou | `lib/features/work/work_screen.dart` | WorkScreen |
| youtube | module | "Koppel kanaal" (Instellings) en die oplaai-taak in die werkry | desktop-OAuth (loopback + PKCE), hervatbare oplaai, snitlyste en die 100-per-dag-teller; net dart:io, endpunte uit die kliëntlêer sodat toetse 'n vals bediener gebruik |  | bou | `lib/core/youtube.dart` | GoogleAuth, YouTube, QuotaExceeded, UploadQuota |

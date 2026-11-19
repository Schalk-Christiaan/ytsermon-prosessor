status: oop

# Fase 1: Enjin + Hersien-skerm op een preek (Linux)

## Doel
Bewys die kern van `planne/hoofplan.md` in die regte app: vir een video vind die KI die preek, die mens hersien dit op die dienstydlyn met videovoorskou, en die app sny die preek en Shorts. Dien `## Doel` in CONTEXT.md (preek sny, Shorts, plaaslik, geen Claude).

Toetsvideo: `https://youtu.be/YWz5gf0onjk` (preek ~23–52 min). Ontwerpstelsel, skerm-uitleg en tekste: `planne/hoofplan.md` → Ontwerpstelsel en Skerms → Hersien. UI-reëls: skill `projekkonteks:ui-ux` (Flutter-afdeling).

## Lêers
- `pubspec.yaml`; `flutter create --org za.co.gkoranjerivier --project-name preekverwerker --platforms=linux,windows .` (Windows-gids nou al, sodat fase 5 net bou).
- `lib/main.dart`, `lib/app/theme.dart`, `lib/app/shell.dart` (NavigationRail; net Hersien en Instellings → Stelsel aktief, ander bestemmings gedeaktiveer met tooltip "Kom in fase 2").
- `lib/l10n/app_af.arb` + `l10n.yaml`.
- `assets/fonts/` Source Serif 4 en Source Sans 3 (OFL, lisensie saam).
- `lib/core/tools.dart`, `channel.dart`, `captions.dart`, `planner.dart`, `cutter.dart`, `models.dart` (`SermonPlan`, `Short`, `Segment`).
- `lib/features/review/review_screen.dart`, `service_timeline.dart`, `review_controller.dart`; `lib/features/settings/system_status.dart`.
- `test/captions_test.dart`, `test/planner_test.dart` (validering + JSON-ontleding, Ollama gestub), `test/cutter_test.dart` (ffmpeg-argumentlyste), `test/theme_contrast_test.dart`, `test/fixtures/sample.af-orig.json3` (klein uittreksel).

## Stappe
1. Skep die Flutter-projek (bo), voeg pakkette by (`media_kit`, `media_kit_video`, `media_kit_libs_video`, `path_provider`, `path`, `intl`, `flutter_localizations`), skryf `theme.dart` met die tokens uit die hoofplan (lig + donker), lettertipes as bates, ARB-opstelling. — kontrole: `flutter run -d linux` wys 'n leë shell met rail in die regte lettertipe; `dart analyze` skoon; kontrastoets slaag.
2. `tools.dart`: vind `yt-dlp`, `ffmpeg`, `ffprobe`, `ollama` (eers langs `Platform.resolvedExecutable`, dan PATH), weergawe-opdrag, Ollama `/api/version` + of `qwen3:8b` in `/api/tags` is. Instellings → Stelsel wys elk met ikoon + woord ("Gereed" / "Ontbreek: installeer …"). — kontrole: skerm wys al vier groen op hierdie masjien; hernoem tydelik PATH → rooi met regstel-teks.
3. `channel.dart`: `fetchMeta(url)` laai `--write-info-json --write-auto-subs --sub-langs af-orig --sub-format json3 --skip-download` na `<app-support>/work/<id>/` (slaan oor as dit bestaan); `downloadVideo(id)` met `-f "bv*[height<=1080]+ba/b" --merge-output-format mp4 --newline` en vordering uit stdout. Volle aflaai (nie `--download-sections` nie: breek tans). — kontrole: lêers bestaan vir die toetsvideo; vordering 0→100 gerapporteer.
4. `captions.dart`: ontleed json3 → `Segment(start, end, text, kind: speech|music)` (`[musiek]`, `[sang]`, `[Musiek]` → music); `compact()` groepeer per ~30 s as `[mm:ss] teks`; `toSrt(from, to)` met tye relatief tot `from`, ≤ 42 karakters × 2 reëls per blok; `timeline()` gee spraak/musiek-blokke vir die tydlyn. — kontrole: `flutter test test/captions_test.dart`; vir die toetsvideo ≤ ~12k tokens (≈ woorde × 1.4) gedruk in 'n toets-uitset.
5. `planner.dart`: POST `/api/chat` (`OLLAMA_HOST` of `http://127.0.0.1:11434`) met `model`, `stream:false`, `think:false`, `format` = JSON-skema, `options.num_ctx:16384`, Afrikaanse stelselprompt: preek = vanaf die aankondiging van tema/teks deur die prediker tot die amen ná die preek, Skriflesing en gebede uitgesluit; 1–3 Shorts van 20–90 s binne die preek, elk 'n volledige gedagte; titel = tema; beskrywing = tema, Skriflesing, Fokusgedeelte, 3–4 sinne opsomming, psalms uit die oorspronklike beskrywing. `validate()`: 0 ≤ start < end ≤ duur, preek 15–75 min, Shorts binne die preek en 20–90 s, titel ≤ 100, beskrywing ≤ 5000; foute as Afrikaanse boodskappe. Stoor `plan.json`; bestaande plan word gelaai, nie oorskryf nie. — kontrole: `flutter test test/planner_test.dart`; regte oproep vir die toetsvideo gee grense binne ~2 min van 23:00 en 52:00 (druk tyd van die oproep).
6. `cutter.dart`: `cutSermon` (`-ss -to -i video.mp4 -c copy`, lêernaam `JJJJ-MM-DD Titel.mp4` met `<>:"/\|?*` verwyder), `cutShort` (`crop=ih*9/16:ih,scale=1080:1920,subtitles=short-N.srt:force_style='FontName=Source Sans 3,FontSize=14,Alignment=2,MarginV=70'`, `libx264 -crf 20`, `aac`, `cwd` = werkgids sodat die SRT-pad relatief is: Windows-dryfletter breek die filter; `fontsdir` na die app se bates), vordering via `-progress pipe:1`. — kontrole: `flutter test test/cutter_test.dart` (argumentlyste); regte snit: `ffprobe` preek ≈ plan ±5 s, Shorts 1080x1920.
7. Hersien-skerm volgens die hoofplan: URL-veld bo ("Plak 'n YouTube-skakel") as tydelike invoer tot fase 2; voorskou (`media_kit`), metadata-paneel met tellers, **dienstydlyn** (CustomPainter: spraak/musiek-blokke, oranje sleepbare preek-hakie met pyltjiesleutels ±5 s en Shift ±1 s, houtkleur Shorts-blokke, klik = soek, tyd-etikette tabulêr, `Semantics` op die hakie-handvatsels: "Preek begin 23:04"), Shorts-lys met 9:16-voorskouraam, primêre "Keur goed en sny", sekondêr "Beplan weer" (bevestig) en "Slaan oor". Laai-toestand met fase-teks + verstreke tyd; fout-toestand met regstel; outeursmoment (hakie gly 400 ms na grense, direk by `MediaQuery.disableAnimations`). Elke wysiging stoor dadelik. — kontrole: skermkiekies (grim) in lig en donker by 1100×720 en 1920×1080: tydlyn is eerste blik, geen oorloop; sleep die hakie → video soek en `plan.json` verander.
8. Vloei end-tot-end: plak toetsvideo-URL → meta + plan (vordering) → hersien → "Keur goed en sny" → video aflaai + snye met vordering → SnackBar "Gesny: 1 preek, 2 Shorts" met "Wys in gids". — kontrole: `out/` bevat die preek en Shorts; skermkiekie van een Short-raam toon prediker gesentreer en leesbare Afrikaanse onderskrif.
9. `README.md` en `CLAUDE.md` Opdragte bygewerk; `@stelsel`-blokke bo-aan `lib/core/*.dart` en die Hersien-skerm. — kontrole: `dart analyze` skoon, `flutter test` slaag.

## Aanvaarding
- `flutter test` slaag (captions, planner, cutter, kontras); `dart analyze` sonder waarskuwings.
- Vir `https://youtu.be/YWz5gf0onjk`: plan-grense binne ~2 min van 23:00/52:00 met `qwen3:8b`.
- `out/` bevat een preek-mp4 (tydsduur = plan ±5 s) en 1–3 Shorts van 1080x1920, 20–90 s, met ingebrande onderskrif.
- Skermkiekies van Hersien (lig + donker, twee groottes) en Instellings → Stelsel, sonder oorloop; geen hardgekodeerde kleure of teks in widgets (grep `Color(0x` buite `theme.dart` en string-literale in `lib/features/` gee niks).

## Prestasie-begroting
Een Ollama-oproep per preek; video een keer afgelaai en hergebruik; tydlyn herteken net by verandering (geen tick-handlers nie, speelposisie via `media_kit`-stroom); geen agtergrond-polling.

## Buite bestek
Preke-lys, werkry, oplaai, snitlyste, WhatsApp, installeerder, Opstelling-lys (fases 2–5).

## Ingryp
- `qwen3:8b` > 2 min af: probeer `think:true`, dan meld met die gemete afwyking en stop; geen heuristiek-stapels nie.
- `media_kit` werk nie op Linux nie (libmpv): meld die fout en die pakket wat ontbreek; moenie na 'n ander videopakket oorskakel sonder vra nie.
- `subtitles`-filter misluk weens font/pad: meld die presiese ffmpeg-fout.

## Vrae

## Log

## Verslag

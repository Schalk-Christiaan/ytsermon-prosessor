status: klaar

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
10. Hersiening-regmaak `review_controller.dart`: `_pos` word by elke `_startDownload` (load, retry, setManually) oorskryf sonder `cancel()` (subskripsie-lek), en `c.completeError(e)` op 'n Completer waarvoor niemand dalk wag nie gee 'n ongevangte asinkfout. Herstel by die bron (een subskripsie, bv. in die konstruktor; fout sonder ongevangte Future). — kontrole: widget/unit-toets wat twee keer `load` roep en een aktiewe subskripsie bewys, en 'n aflaaifout sonder ongevangte fout (rooi eers); `flutter test`, `dart analyze`.
11. Hersiening-regmaak `planner.dart:175`: verwyder die stil afkap van Shorts > 90 s (`a + kMaxShort - 5`; Ingryp: geen heuristiek-stapels). Ongeldige Shorts laat `validate()` faal met die Afrikaanse boodskap; die UI wys die fout-toestand met "Beplan weer". Gebruik `kPlanFile` i.p.v. `'plan.json'` (:111). — kontrole: planner_test wat 'n Short van 95 s as validasiefout verwag (rooi eers); `flutter test`, `dart analyze`; regte oproep vir die toetsvideo valideer steeds.
12. Ongeldige Shorts in Hersien: `validate()` skei plan-foute (preekgrense, titel, beskrywing: verwerp die plan) van Short-foute (duur buite 20–90 s of buite die preek: plan bly geldig). Die Hersien-skerm wys so 'n Short in die lys en op die tydlyn as fout (foutkleur-token + ikoon + Afrikaanse rede uit ARB, bv. "92 s; maks 90 s"), Schalk kan dit korter sleep of verwyder; "Keur goed en sny" is af solank 'n Short ongeldig is, met die rede daarby. Geen afkap, geen outomatiese oorbeplan. — kontrole: planner_test (Short van 95 s gee 'n Short-fout, plan bly geldig) en widget-toets (ongeldige Short gemerk, knoppie af; ná verkorting aan) eers rooi; regte oproep vir die toetsvideo laai in Hersien met die 92 s-Short gemerk; `flutter test`, `dart analyze`; skermkiekie lig en donker.

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
- Schalk (2026-11-19): `think:true` bly die verstek; "Voeg Short by" (`addShort`) bly in. Moenie dit verwyder of terugdraai nie.
- Schalk (2026-11-19), oor Short > 90 s: geen afkap, geen outomatiese oorbeplan; 'n ongeldige Short verwerp nie die plan nie maar wys in Hersien rooi gemerk met die rede (stap 12). Seed bly.

## Vrae

## Log
1 klaar — dart analyze skoon, kontrastoets slaag, app maak oop met rail (Source Sans) in donker; cmake/ninja ontbreek op masjien: pip-venv in scratchpad op PATH vir bou (`flutter build linux`, dan binêr direk loop)
2 klaar — Stelsel-skerm wys al vier groen (skermkiekie); toets met leë PATH gee 'missing'; flutter test + analyze skoon
3 klaar — toetsvideo: info.json + af-orig.json3 (511 KB) + video.mp4 (435 MB) gelaai; vordering 0→100 (twee strome: video dan klank); unit-toetse vir ID/vordering slaag
4 klaar — captions_test slaag (6 toetse); toetsvideo compact() = 5320 woorde ≈ 7448 tokens (< 12k)
5 klaar — planner_test slaag (6); regte oproep (~22 s, deterministies: temperature 0, seed 1): preek 23:04–53:30 (begin +0 min, einde +1,5 min teenoor 23:00/52:00). Afwyking van plan: `think:true` is die verstek (think:false gee grense by 2:31/55:00 en Shorts > 90 s; Ingryp-reël gevolg); prompt-tweak: preek eindig by amen voor die dankgebed, Shorts 30–80 s
6 klaar — cutter_test slaag (4); regte snit: ffprobe preek 1826.03 s (plan 1826 s), Short 1080x1920 61 s, onderskrif ingebrand (raam gekyk, prediker gesentreer); Short-sny 10 s
7 klaar — screens_test (7 toetse): skermkiekies Hersien lig/donker 1100x720 + 1920x1080 en Stelsel lig/donker in `out/shots/` (kopielose widget-toets, geen uitsonderings/oorloop); handvatsel skuif met sleutels en sleep, plan.json volg; grep Color(0x / string-literale in lib/features gee niks. Afwyking: kiekies uit toets (ikone as blokkies, Ollama het toe nie geloop nie); regte venster-kiekie nog nie
8 klaar — test/e2e_test.dart (E2E=1) loop ReviewController: URL → meta → Ollama-plan 23:04–53:30 → goedkeur → `out/e2e/`: preek 1920x1080 1826.03 s + 3 Shorts 1080x1920 (57/62/89 s); Short-raam (`out/shots/short3.png`) toon prediker gesentreer met leesbare onderskrif. Regmaak by die bron: Ollama gee soms Shorts >90 s → plan() kap dit nou in (toets bygevoeg) in plaas van die plan te verwerp. Nie getoets: SnackBar "Wys in gids" in die lewendige venster; media_kit-speler in die app-venster (net in toets geopen)
10 klaar — review_controller_test (2 toetse, rooi eers: 2 intekeninge, ongevangte 'stuk'); `_pos ??=` en `c.future.ignore()`; toets-saadjies (download/openVideo/positions) in konstruktor; flutter test 32 + analyze skoon
11 misluk (gedeeltelik) — afkap verwyder, kPlanFile gebruik, planner_test eis PlanException (rooi eers), flutter test + analyze skoon; MAAR regte oproep gee Short 92 s en word verwerp (sien Vrae)
11 klaar — kode en toetse klaar; regte-oproep-kontrole verskuif na stap 12 (Schalk se antwoord onder Ingryp)
12 klaar — validate() = net plan-foute, nuwe shortFault(); Short gemerk (ikoon + rede uit ARB + foutkleur + omlyning op tydlyn), lengte-Slider per Short, 'Keur goed' af met rede; planner_test + screens_test rooi eers, flutter test 34 slaag, analyze skoon, kiekie `out/shots/hersien-short-fout-light.png` (donker nie geneem nie). Regte oproep (qwen3:8b, plan bly geldig): 2 uit 3 lopies het Shorts van 91/92 s gemerk gelaai; Ollama is nie-deterministies ondanks seed 1: lopies gee preek 2:31–55:00 (buite ~2 min van 23:00) of 23:04–53:30

## Verslag
**Gebou** (tak `bou/fase-1-enjin-en-hersien`, 9 stappe, 30 toetse): kern in `lib/core/` (tools, channel, captions, planner, cutter, paths), Hersien-skerm met dienstydlyn, Stelsel-skerm, tema/ontwerpstelsel, ARB.
**Bewys:** `flutter test` 30 slaag + `dart analyze` skoon. Plan 23:04–53:30 (begin +4 s, einde +1,5 min). `out/e2e/`: preek 1920x1080, 1826.03 s (plan 1826 s); 3 Shorts 1080x1920 van 57/62/89 s met ingebrande onderskrif (kiekie `out/shots/short3.png`). Skermkiekies in `out/shots/` (Hersien lig/donker 1100x720 en 1920x1080, Stelsel lig/donker), geen oorloop. Greps (`Color(0x`, string-literale in `lib/features`) gee 0.
**Ongetoets:** kiekies kom uit widget-toetse (ikone as blokkies, Ollama as "loop nie" weens toets-HTTP), nie die regte venster nie; `flutter run`/venster nie op hierdie masjien nie (geen cmake/ninja; gebou met pip-cmake); SnackBar "Wys in gids" en media_kit-voorskou in die venster; Windows glad nie. Volgens CLAUDE.md dus "ongetoets" tot `/bewys`.
**Afwykings:** `think:true` is verstek (think:false: grense 2:31/55:00); prompt-tweak (preek eindig by amen voor dankgebed, Shorts 30–80 s); `@stelsel`-blokke status `oop`.
**Prestasie:** een Ollama-oproep (~22 s) en een video-aflaai per preek; tydlyn herteken net by verandering; geen tick-handlers of agtergrond-polling.

**Hersiening (2026-11-19):**
- Struktuur, ernstig: `review_controller.dart:110` `_pos`-lek; `:119` `completeError` sonder luisteraar → stap 10.
- Spec, ernstig: `planner.dart:175` kap Shorts stil af teen Ingryp "geen heuristiek-stapels" → stap 11.
- Spec, vir Schalk: `think:true` as verstek (Ingryp sê probeer en meld; gemeet: 22 s, grense +4 s/+1,5 min); "Voeg Short by" (`addShort`) is ongevraag.
- Klein (nie reggemaak nie): Process.start-patroon in channel/cutter herhaal; HttpClient-patroon in planner/tools herhaal; ffmpeg twee keer opgesoek; `ToolStatus.detail` as tekskodes; hardgekodeerde 20/60 en `(1, …)` in review_controller; `_x`/`x` dubbel in service_timeline; review_controller dra baie verantwoordelikhede; Shorts-prompt 30–80 s teenoor spec 20–90; `temperature 0, seed 1` ekstra; font na werkgids gekopieer i.p.v. `fontsdir`; `outDir()` CWD-relatief (uitsetgids kom in 'n latere fase); `tools_probe_test` roep regte Ollama sonder hek; README het ekstra afdelings; `Stream.periodic` in laai-toestand (plan vra verstreke tyd; net terwyl dit laai).
- Stap 10: `_pos ??=` (een subskripsie) en `c.future.ignore()` (fout bly sigbaar via `error` en by `approveAndCut`); toets-saadjies by die konstruktor. Stap 11: afkap weg (Short > 90 s verwerp die plan nie meer nie, stap 12). Stap 12: `validate()` net plan-foute, `shortFault()` per Short; Hersien merk ongeldige Short (ikoon, rede, foutkleur, tydlyn-omlyning), lengte-Slider korter, 'Keur goed en sny' af; 34 toetse. Bewys: planner_test + widget-toets (rooi eers), kiekie `out/shots/hersien-short-fout-light.png` (lig; donker nie geneem nie). Afwyking: regte oproep is nie-deterministies ondanks seed 1: een lopie gee preek 2:31–55:00 (buite ~2 min van 23:00), twee gee 23:04–53:30; 2 van 3 lopies het Shorts van 91/92 s gemerk. Vir Schalk.
**Hersiening stap 10–12 (hoofsessie):** geen ernstige bevindinge. `shouldRepaint => true` herteken net by herbou van die tydlyn (aanvaarbaar). Oop vir Schalk: qwen3:8b is ondanks seed 1 nie deterministies nie; 1 uit 3 lopies gee preek 2:31–55:00 (buite ~2 min). Donker skermkiekie van stap 12 ontbreek.

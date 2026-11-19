status: oop

# Fase 2: Preke-lys, werkry en stoor (Linux)

## Doel
Die app ken die hele kanaal: elke diens is 'n preek met 'n toestand wat oor herbeginne bly. "Verwerk volgende" sit werk in een werkry (een taak op 'n slag, hervat ná herbegin), die Werk-skerm wys en herstel dit, en Hersien maak 'n preek uit die lys oop in plaas van 'n geplakte skakel. Preekgrense verfyn is **nie** hier nie (sien `CONTEXT.md`: eers die raamwerk).

## Lêers
- `lib/core/tools.dart`: een `runTool(exe, args, {onLine, cwd, cancel})` vir alle eksterne prosesse (vervang `_run` in `channel.dart` en `_ffmpeg` in `cutter.dart`; tweede werklike geval, dus nou een funksie), plus `openPath(path, {select})` (`xdg-open` / `explorer [/select,]`), `updateYtDlp()`.
- `lib/core/channel.dart`: `listChannel()` (flat-lys van `/streams` + `/videos` van die kanaal).
- `lib/core/store.dart` (nuut): `Sermon` + `SermonState` + laai/stoor `<work>/<id>/sermon.json`.
- `lib/core/jobs.dart` (nuut): `JobQueue` (ChangeNotifier), `<work>/jobs.json`.
- `lib/core/models.dart`: net as `Sermon` daar beter pas as in `store.dart` (een plek, nie albei nie).
- `lib/features/sermons/sermons_screen.dart` (nuut), `lib/features/work/work_screen.dart` (nuut).
- `lib/features/review/review_controller.dart`, `review_screen.dart`: laai per preek-ID uit die stoor; plan en sny via die werkry; URL-veld weg.
- `lib/app/shell.dart` (Preke tuis, Hersien, Werk aktief; Snitlyste bly af met "Kom in fase 3"), `lib/main.dart`.
- `lib/features/settings/system_status.dart`: knoppie "Werk yt-dlp by".
- `lib/l10n/app_af.arb`.
- `test/store_test.dart`, `test/jobs_test.dart`, `test/channel_test.dart` (lys-ontleding uit 'n fixture), `test/screens_test.dart` (Preke + Werk), `test/fixtures/channel-flat.json` (klein uittreksel).

## Stappe
1. `runTool` in `tools.dart`: Process.start met argumentlys (nooit `runInShell`), stdout-reëls na `onLine`, stderr gebuffer, nie-nul uitgang → `ProcessException` met stderr; `cancel` (Future of token) maak die proses dood en gooi `JobCancelled`. `channel.dart` en `cutter.dart` roep dit (alle roepers gegrep; die ou `_run`/`_ffmpeg` weg). ffmpeg/yt-dlp-soektog een keer (`findExecutable ?? throw` nie meer gedupliseer nie). — kontrole: `tools_test` (eggo-proses: reëls, foutkode, kanselleer maak proses dood) eers rooi; bestaande `cutter_test`/`channel_test` bly groen.
2. `channel.dart` `listChannel()`: `yt-dlp --flat-playlist -J` op `<kanaal>/streams` en `<kanaal>/videos` (kanaal-URL as een konstante uit `CONTEXT.md`), saamgevoeg op ID → `(id, title, date, duration)`. Meet eers of die flat-uitset 'n datum dra (`timestamp`/`release_timestamp`/`upload_date`); sien Ingryp as nie. — kontrole: `channel_test` ontleed `fixtures/channel-flat.json`; regte oproep druk aantal (~326) en tyd, en elke item het 'n datum.
3. `store.dart`: `SermonState { nuut, beplan, goedgekeur, gesny, opgelaai, fout, oorgeslaan }`; `Sermon(id, title, date, duration, state, error?, outputs)` ↔ `<work>/<id>/sermon.json` (atomies: skryf `.tmp`, dan hernoem). `loadAll(root)`, `save(s)`, `merge(listed)`: nuwe ID's word `nuut`, bestaande hou hul toestand, gee die nuwe terug. Bestaande `plan.json` in 'n gids → toestand minstens `beplan` (fase 1-data gaan nie verlore nie). — kontrole: `store_test` (rondreis, merge hou toestand, tmp-hernoem, plan.json → beplan) eers rooi.
4. `jobs.dart`: `JobQueue` met take `plan(id)` (fetchMeta + captions + planner → `beplan`) en `cut(id)` (downloadVideo + cutSermon + cutShort → `gesny`, uitsetpaaie in `sermon.json`). Een taak op 'n slag in 'n gewone async-lus (geen Timer/polling); ry in `<work>/jobs.json`; by begin word 'n taak wat `besig` was weer `wag`. Fout → preek `fout` met gewone-taal boodskap + laaste 200 log-reëls; `retry(job)`, `cancel()` via `runTool`. Vordering as `ValueNotifier<double?>` + fase-teks. Hergebruik die bestaande funksies in `channel`/`captions`/`planner`/`cutter`; geen nuwe pyplyn-kode nie. — kontrole: `jobs_test` met gestubde take: volgorde, een op 'n slag, hervat ná "herbegin" (nuwe JobQueue op dieselfde gids), fout → `fout`, kanselleer; eers rooi.
5. `ReviewController`: `open(id)` laai meta/plan uit die stoor; "Beplan weer" sit 'n `plan`-taak in die ry; "Keur goed en sny" stel `goedgekeur` en sit 'n `cut`-taak in die ry (sny loop nie meer in die controller nie); "Slaan oor" stel `oorgeslaan`. URL-veld en die inlyn-pyplyn weg; laai-toestand volg die werkry se fase. Fase 1-gedrag bly: tydlyn, Shorts-foute rooi, `addShort`, `think:true`. — kontrole: `review_controller_test` + `screens_test` aangepas (eers rooi), `flutter test` groen.
6. Preke-skerm (tuis) volgens die hoofplan: `ListView.builder`-rye 56 dp: datum (tabulêr), titel (serif), Skriflesing (uit die beskrywing as dit in `info.json` is, anders leeg), toestand-chip (ikoon + woord). Filter-chips per toestand, soek (Ctrl+F), primêr **"Verwerk volgende"** (oudste `nuut`, of geselekteerdes; Ctrl+Enter) → `plan`-take. Ry-klik → Hersien. Leeg ("Geen preke gevind nie" + "Probeer weer"), laai (skelet-rye), fout (yt-dlp: wat gebeur het + "Probeer weer" + "Werk yt-dlp by"). By elke begin: `listChannel` → `merge` → as nuut > 0 'n strook "2 nuwe dienste sedert <datum>" (geen modaal). — kontrole: widget-toetse (lys, filter, soek, leeg/fout) eers rooi; skermkiekies lig en donker by 1100×720 en 1920×1080.
7. Werk-skerm: huidige taak bo (fase, persentasie, "Kanselleer"), wag-lys, klaar-lys met "Speel" en "Wys in gids" (`openPath`), foute met boodskap + "Probeer weer" en invoubare tegniese log. Esc = terug. — kontrole: widget-toets met 'n gestubde ry (besig/wag/klaar/fout) eers rooi; skermkiekies lig en donker by albei groottes.
8. Shell en Instellings: rail Preke · Hersien · Werk (+ Snitlyste af, "Kom in fase 3") · Instellings onder; Hersien sonder gekose preek wys "Kies 'n preek in Preke". "Werk yt-dlp by" in Stelsel (`yt-dlp -U` via `runTool`, uitslag as SnackBar). Alle nuwe teks in ARB. — kontrole: grep `Color(0x` buite `theme.dart` en string-literale in `lib/features/` gee niks; `dart analyze` skoon.
9. End-tot-end in die regte venster (`flutter build linux --debug`, binêr direk; cmake/ninja uit die scratchpad-venv as die stelsel dit nie het nie): begin → lys laai → toetsvideo `YWz5gf0onjk` gemerk → "Verwerk volgende" → Werk wys plan-vordering → Hersien → "Keur goed en sny" → Werk wys aflaai/sny → klaar-item → "Wys in gids". Maak die app toe tydens 'n sny en begin weer: taak hervat. Skermkiekies met `grim` van die venster. `@stelsel`-blokke vir nuwe/veranderde hoofstukke; `kaart.py --check`. — kontrole: `out/` bevat preek + Shorts; kiekies lig en donker; terminaal sonder uitsonderings.

## Aanvaarding
- `flutter test` slaag (ou + store, jobs, channel-lys, skerms); `dart analyze` skoon.
- Die Preke-skerm lys die hele kanaal (~326) met datum, titel en toestand; toestande bly ná 'n herbegin; fase 1 se `plan.json` vir die toetsvideo wys as `beplan`.
- "Verwerk volgende" → `beplan` → Hersien → "Keur goed en sny" → `gesny` loop deur die werkry, een taak op 'n slag, met vordering op die Werk-skerm.
- 'n Taak wat tydens 'n herbegin besig was, hervat; "Kanselleer" maak die yt-dlp/ffmpeg-proses dood (geen weesproses in `ps` nie); 'n fout wys gewone taal + "Probeer weer".
- Skermkiekies van Preke, Werk en Hersien in lig en donker, 1100×720 en 1920×1080, uit die **regte venster**, sonder oorloop; geen hardgekodeerde kleure of teks in widgets.

## Prestasie-begroting
Een `listChannel` per begin (en by "Probeer weer"); geen polling, geen Timer, geen periodieke herlaai van die kanaal. Een eksterne proses op 'n slag (die werkry). `sermon.json`-lêers een keer by begin gelees (~330 klein lêers), daarna net die gewysigde een geskryf. Die bestaande `Stream.periodic` in Hersien se laai-toestand mag bly (verstreke tyd); geen nuwe nie. Lys herteken net by verandering (`ListenableBuilder` op die stoor/ry).

## Buite bestek
Preekgrense of prompt verfyn, oplaai/OAuth/"Koppel kanaal" en snitlyste (fase 3), WhatsApp-klank (fase 4), installeerder en Opstelling-lys (fase 5), parallelle take, databasis.

## Ingryp
- Flat-lys dra geen datum nie: meld wat dit wel dra en stop; moenie 330 volle `info.json`-oproepe doen sonder vra nie.
- `yt-dlp -U` misluk op Linux (stelselpakket): dis verwag; wys die fout as SnackBar en gaan voort.
- Moenie fase 1 se besluite terugdraai nie: `think:true`, `addShort`, ongeldige Shorts rooi in Hersien, seed bly.
- Maak 'n venster op Schalk se skerm net in stap 9 oop, en maak dit weer toe.

## Vrae

## Log

## Verslag

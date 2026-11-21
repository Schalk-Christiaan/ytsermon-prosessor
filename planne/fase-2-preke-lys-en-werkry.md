status: klaar

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

10. Werk-skerm in git: `.gitignore` se `work/` vang `lib/features/work/`. Verander na `/work/` (verankerd) en commit `work_screen.dart`. — kontrole: `git ls-tree -r bou/fase-2-preke-lys-en-werkry lib/features/work` wys die lêer; skoon kloon van die tak in die scratchpad: `flutter pub get && dart analyze` skoon.
11. Hersien se voorskou-aflaai bots nie met die werkry nie: `approveAndCut` wag nie op die aflaai nie (sit dadelik `goedgekeur` + `cut`-taak; die sny-taak laai self af/slaan oor), en geen `_download!`-null-crash nie. `_startDownload` begin nie as 'n taak vir dié preek wag/besig is nie. 'n Aflaai wat klaarkom ná `reset()`/`open(ander)` word geïgnoreer (vergelyk ID), sodat die speler nooit die vorige preek se video oopmaak nie. Die "hangende taak"-toets bestaan op drie plekke (`jobs.dart`, `review_controller.dart`, `sermons_screen.dart`): maak een `JobQueue`-metode en roep dit oral. — kontrole: `review_controller_test` (approve sonder klaar aflaai → taak in ry; stale aflaai ná open(ander) → speler nie oopgemaak; geen aflaai as cut-taak aktief) eers rooi.
12. Kanselleer maak die hele prosesboom dood: yt-dlp se ffmpeg-kind leef nou voort ná `proc.kill()`. Linux: maak eers die kinders dood (`pkill -TERM -P <pid>` via `Process.run` met argumentlys), dan die ouer; Windows: `taskkill /T /F /PID <pid>`. `runTool` wag op stdout **en** stderr klaar voor dit `ProcessException` bou (stderr nie afgekap nie); verwyder die cancel-luisteraar. — kontrole: `tools_test` met 'n skrip wat 'n kind (`sleep 30`) begin: ná kanselleer is daar geen `sleep 30` in `ps` nie; eers rooi.
13. Werkry is robuust en fout-log volledig: `JobCtx.log` word deur `onLine` van elke `runTool`-oproep in die taak gevoed; by fout stoor die preek die gewone-taal boodskap + laaste 200 log-reëls (stap 4 se eis), en Werk wys dit in die invoubare log. `store.byId`, `store.save` en `_persist` binne die try, sodat 'n uitsondering nooit 'n taak op `besig` laat vassit of die lus doodmaak nie. `cutJob` stoor `outputs` ná elke lêer (nie net aan die einde nie). — kontrole: `jobs_test` (taak wat reëls log en dan faal → `error` bevat die reëls; ontbrekende preek → taak `fout`, volgende taak loop) eers rooi.
14. 'n Gekanselleerde plan-taak skryf nie `plan.json` nie: as Ollama ná kanselleer antwoord, word die resultaat weggegooi (kyk kanselleer voor die skryf). — kontrole: `jobs_test` met 'n stadige gestubde planner wat ná kanselleer klaarkom: geen `plan.json`, preek-toestand onveranderd; eers rooi. Daarna weer `flutter test`, `dart analyze`, `E2E=1 flutter test test/e2e_test.dart`, en Verslag bygewerk (status `hersien`).

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
- 2026-11-19 Schalk: datum **lui per preek**. `listChannel` hou die lysvolgorde (nuutste eerste) as sorteersleutel; `Sermon.date` is nullable en wys '—' tot `fetchMeta` (in die `plan`-taak) dit invul en in `sermon.json` stoor. Geen ekstra oproepe nie. Stap 2 se kontrole 'elke item het 'n datum' val weg; toets eerder dat volgorde behou word.
- Flat-lys dra geen datum nie: meld wat dit wel dra en stop; moenie 330 volle `info.json`-oproepe doen sonder vra nie.
- `yt-dlp -U` misluk op Linux (stelselpakket): dis verwag; wys die fout as SnackBar en gaan voort.
- Moenie fase 1 se besluite terugdraai nie: `think:true`, `addShort`, ongeldige Shorts rooi in Hersien, seed bly.
- Maak 'n venster op Schalk se skerm net in stap 9 oop, en maak dit weer toe.

## Vrae

## Log
1 klaar — tools_test (3 runTool-toetse rooi dan groen), flutter test 37 groen, dart analyze skoon; kaart: nie gekonfigureer in CONTEXT.md nie, --check leeg
2 klaar — channel_test rooi dan groen; regte oproep: 326 items in 16 s; datum lui (Ingryp), volgorde behou
3 klaar — store_test (3 toetse) rooi dan groen; analyze skoon
4 klaar — jobs_test (4 toetse: volgorde/een-op-slag, hervat, fout+retry, kanselleer) rooi dan groen; flutter test groen
5 klaar — review_controller_test (+3 nuwe: open(id), unplanned/replan, approve→cut-taak/skip) en screens_test aangepas; flutter test 48 groen, analyze skoon; shell/main bedraad met stoor+ry (Shell(store,jobs))
6 klaar — 3 widget-toetse (lys/filter/soek, Verwerk volgende+ry-klik, nuwe-strook/leeg/fout) rooi dan groen; kiekies out/shots/preke-*.png (toets-renderer, ikone as blokkies; regte venster in stap 9). Afwyking: strook sê '{n} nuwe dienste' sonder 'sedert <datum>' (datums is lui); Skriflesing in sermon.json by plan-tyd gestoor
7 klaar — widget-toets met gestubde ry (besig/wag/klaar/fout, Speel/Wys in gids via openPath-saadjie, Probeer weer, Esc) rooi dan groen; kiekies out/shots/werk-*.png
8 klaar — shell-toets (rail → Hersien-wenk, Werk), grep Color(0x buite theme.dart en string-literale in features/app = niks, analyze skoon, flutter test groen
9 klaar (gedeeltelik in die regte venster) — flutter build linux --debug; venster: Preke lys 325 nuwe + toetsvideo as beplan, soek, Hersien-wenk vir onbeplande preek, Stelsel groen + 'Werk yt-dlp by' (kiekies out/shots/real-*); E2E=1 flutter test test/e2e_test.dart groen (37 s): id → plan-taak → sny-taak, uitset preek 1826 s + Shorts 57/62/89 s (ffprobe), geen weesproses; kaart.py --check skoon
10 klaar — .gitignore /work/ verankerd; work_screen.dart in die tak (git ls-tree); skoon kloon: pub get + dart analyze skoon
11 klaar — 3 nuwe review_controller_test (goedkeur wag nie op aflaai, ou aflaai ná open(ander) geïgnoreer, geen aflaai met hangende taak) rooi dan groen; JobQueue.hasPending op een plek; flutter test 64 groen
12 klaar — tools_test: sleep-kind weg ná kanselleer (rooi dan groen), stderr 100000 grepe volledig; _killTree (pkill -P / taskkill /T /F); luisteraar doen niks ná klaar
13 klaar — jobs_test (preek ontbreek → fout en volgende taak loop; log max 200 met fout) rooi dan groen; fetchMeta/downloadVideo/cutSermon/cutShort voer log:c.log; lus-wedloop (taak gestrand as die eerste sinchroon eindig) reggemaak; uitsette ná elke lêer
14 klaar — planner_test (cancel voor Ollama antwoord → geen plan.json, JobCancelled) rooi dan groen; flutter test 69 groen, dart analyze skoon, E2E=1 groen, kaart.py --check skoon, geen weesprosesse

## Verslag
**Hersiening gebou (stappe 10-14):** `.gitignore` `/work/` verankerd en `work_screen.dart` in die tak (skoon kloon: analyze skoon); `approveAndCut` wag nie meer op die voorskou-aflaai nie, ou aflaaie ná `open(ander)`/`reset()` word geïgnoreer, geen aflaai terwyl 'n taak hang nie, en `JobQueue.hasPending` vervang die drie kopieë; kanselleer maak die prosesboom dood (`pkill -P` / `taskkill /T /F`) en stderr word volledig gelees; `log:` uit fetchMeta/downloadVideo/cutSermon/cutShort voer die taak se log (max 200), die lus oorleef 'n ontbrekende preek of skryffout (ook 'n wedloop reggemaak: 'n taak kon gestrand bly as die vorige sinchroon eindig), `outputs` ná elke lêer; 'n gekanselleerde plan skryf geen plan.json nie (`loadOrPlan(cancel:)`). Toetse: nou 69 groen, E2E=1 groen, kaart.py --check skoon. Afwyking: stap 14 se toets is in planner_test (waar die regmaak woon) i.p.v. jobs_test, want planJob roep yt-dlp; die log-voeding uit runTool-roepers is nie eenheidgetoets nie (E2E dek die pad).

**Gebou:** Preke-skerm (kanaallys, soek, filter, "Verwerk volgende"), SermonStore (sermon.json per preek), JobQueue (een taak op 'n slag, jobs.json, hervat, kanselleer), Werk-skerm, Hersien uit die stoor, Shell met Preke/Hersien/Werk/Instellings, `runTool` met kanselleer, "Werk yt-dlp by".
**Bewys per kriterium:**
- Toetse: `flutter test` 61 groen + 1 oorgeslaan (E2E), `dart analyze` skoon.
- Lys: regte venster wys 325 dienste; toetsvideo wys as `beplan` (fase 1 se plan.json). Toestand ná herbegin: store_test; in die venster het die toestande ná die herbegin teruggekom.
- Vloei: E2E=1 groen (id → plan-taak → sny-taak; preek 1826 s, Shorts 57/62/89 s per ffprobe). Een taak op 'n slag: jobs_test.
- Hervat/kanselleer/fout: jobs_test (besig → wag by herbegin), tools_test (kanselleer maak proses dood), werk-toets (Probeer weer); `ps` na E2E: geen yt-dlp/ffmpeg nie.
- Kiekies: out/shots/ (toets-renderer, ikone as blokkies) vir Preke, Werk, Hersien in lig/donker 1100 en 1920. Geen `Color(0x` buite theme.dart nie, geen string-literale in features/app nie.
**Ongetoets:** Regte-venster-kiekies in lig én by 1920×1080 en vir Werk/Hersien met 'n lopende taak (muis-outomatisering het die lessenaar se uitleg omgeskakel; net donker, smal venster en sleutelbord gedoen). Handmatige Kanselleer en toe-maak-tydens-sny in die venster. 'Werk yt-dlp by'-SnackBar nie gesien nie (net die proses `yt-dlp -U` het gehardloop).
**Afwykings:** datum lui per preek (Schalk se keuse b); strook sê "{n} nuwe dienste" sonder "sedert <datum>"; Skriflesing in sermon.json by plan-tyd; CONTEXT.md het geen `kaart:`-sleutel nie (nie bygevoeg; kaart.py --check uit die plugin loop skoon).
**Prestasie:** een `listChannel` per begin (~14 s, op die agtergrond), geen nuwe timers/peiling; een eksterne proses op 'n slag; die Ollama-oproep self kan nie doodgemaak word nie, kanselleer laat dit los.

**Hersiening (2026-11-19), ernstige bevindinge → stappe 10–14.** Klein, nie gebou nie (later of nooit): `review_screen` wys `e.toString()` i.p.v. `friendlyError` (r.57, 127); `_processNext` kyk nie toestand nie (gesnyde preek kan weer beplan word); `merge()` verfris nie titel/duur nie; korrupte `sermon.json`/`jobs.json` breek opstart (geen try); `addShort` se clamp gooi vir preke < 20 s; `yt-dlp -U` loop buite die werkry; `friendlyError` hoort in `tools.dart`; lêernaam-konstruksie (info.json/plan.json) versprei oor 4 lêers; herhaalde `switch` op `JobKind`; `ReviewController` doen te veel (340 reëls); `store.load` heet nie `loadAll` nie; `_ffmpegArgs` soek ffmpeg weer.

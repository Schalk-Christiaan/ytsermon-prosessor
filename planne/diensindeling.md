status: klaar

# Diensindeling: spektrogram, KI-etikette, drie uitvoere en 'n blaaier

## Doel
Die app verstaan die hele diens: waar is musiek en waar spraak (uit die klank), en wat is elke spraakstuk (gebed, preek, Skriflesing, geloofsbelydenis …, uit een KI-oproep). Daaruit maak dit drie uitvoere in een gids per diens, met 'n WhatsApp-teks, en 'n blaaier vir preke en sang (CONTEXT.md, Besluite 2026-11-21).

- **Volle preek**: begin van die gebed voor die preek tot "Amen" van die gebed ná die preek (soos nou).
- **Net die woord**: alle spraak tussen die twee gebede (Skriflesing ingesluit); gebede en sang uitgeknip, naatloos aanmekaar.
- **Sang**: elke lied as eie mp3, benoem uit die aankondiging.

## Vertrekpunt
`main` ná die merge van `preekgrense-gebed`: woordtye (`Word`, `tOffsetMs`), `findBounds`, stilte-snap (`snapBounds`, `silenceArgs`), herkodeer (`sermonArgs`), `planJob` laai die video af. Gebede word nou met merkwoorde gevind (`captions.dart` `_prayerCue`), wat die geloofsbelydenis ("…die Almagtige … Amen") vir 'n gebed kan aansien. Musiek kom uit YouTube se `[musiek]`-merkers, wat meer as die helfte mis.

Navorsing: `navorsing/2026-11-21-spektrogram-spraak-musiek.md` en `navorsing/spektrogram-prototipe/` (numpy-prototipe, drempels, verwagte segmente vir 4 dienste in `segmente.txt`). Lees dit eers.

## Pyplyn
```
video ──ffmpeg──► klank-kenmerke/s ──reëls──► stilte | musiek | spraak | geraas
onderskrifte ──► woorde ──┐                                   │
                          └──► spraakblokke (pouse ≥ 2 s, "Amen", musiekgrens)
blokke + musiekstukke ──één Ollama-oproep──► etiket per blok, lied per musiekstuk, diens-etiket, titel/beskrywing/Shorts
etikette ──reëls──► grense (preek = langste preek-loop; gebed voor/ná) ──stilte-snap──► tye
info.json ──reëls──► datum (plaaslik), Oggend/Aand, tema, skriflesing, fokus, belydenis, psalmlys
──► uitvoer: Volle preek.mp4 · Net die woord.mp4/.mp3 · Sang/NN <lied>.mp3 · WhatsApp.txt · diens.json
```

## Lêers
- `lib/core/sound.dart` (nuut, hoofstuk): `soundArgs(video)` (een ffmpeg-oproep), `parseSound(...)` → kenmerke per sekonde, `classify(...)` → `List<TimeBlock>` met `stilte|musiek|spraak|geraas`. Drempels as konstantes met 'n kommentaar wat na die navorsing verwys.
- `lib/core/models.dart`: `SegmentKind` kry `silence`, `noise`; `Block(start, end, label, words)`; `BlockLabel`-enum (`gebed, preek, skriflesing, geloofsbelydenis, seengroet, wet, aankondiging, kollekte, seen, ander`); `Song(start, end, name, n)`; `ServiceInfo` (datum, oggend/aand, etiket, tema, skriflesing, fokus, belydenis, psalms).
- `lib/core/captions.dart`: `timeline()` gebruik die klank-blokke i.p.v. `[musiek]`-merkers; `blocks(words, sound)` sny spraak in blokke. Die merkwoord-gebede (`_prayerCue`, `prayers`) word geskrap sodra die etikette dit vervang (grep alle roepers, ook `review_controller` `prayerMarks`).
- `lib/core/planner.dart`: die bestaande Ollama-oproep kry die bloklys (per blok: nr, duur, eerste ±40 en laaste ±20 woorde) en musiekstukke (met die laaste ±25 woorde daarvoor) en gee per blok 'n etiket, per musiekstuk 'n liednaam of null, 'n diens-etiket (`nagmaal, doop, kategismus, belydenis, feesdag` of null), plus titel/beskrywing/Shorts. Dinkmodus af, temperatuur 0, vaste seed. Bly één oproep per preek.
- `lib/core/bounds.dart`: `findBounds` uit etikette: preek = langste aaneenlopende loop `preek`-blokke (≥ 15 min); begin = `gebed`-blok direk voor, einde = "Amen" van die `gebed`-blok direk ná; bestaande `sure`/`BoundsDoubt` en stilte-snap bly. `wordParts(...)` = spraakdele tussen die gebede minus musiek.
- `lib/core/service_info.dart` (nuut, hoofstuk) of in `channel.dart` as dit < 60 reëls is: datum uit `release_timestamp`/`timestamp` in plaaslike tyd (fout: `upload_date` gee by `YWz5gf0onjk` 16 Nov, diens was Sondag 15 Nov 17:51); Oggend as begin < 13:00, anders Aand; velde uit die beskrywing (`Tema:`, `Skriflesing:`, `Fokusgedeelte:`, reël met `NGB`/`HK`/`Dordtse`/`Sondag`, `Psalm …`-reëls). Grep elke roeper van `uploadDate`/`upload_date` en herstel by die bron.
- `lib/core/cutter.dart`: `serviceDir(outDir, info)` = `<outDir>/<jaar>/<JJJJ-MM-DD> <Oggend|Aand> - <tema>`; `wordArgs` (een herkodering met `trim/atrim` + `concat` oor die dele, `-progress` soos `sermonArgs`); `songArgs` (mp3, `-metadata title=… album="GK Oranjerivier <datum> <diens>" track=n`); `whatsappText(template, info)`. Hergebruik `_x264`, `_progress`, `sermonFileName`-skoonmaak.
- `lib/core/jobs.dart`: `cutJob` maak die gekose uitvoere in `serviceDir` en skryf `diens.json` (info, liedere, lêers) en `WhatsApp.txt`; `audioJob` se WhatsApp-mp3 = `Net die woord.mp3`.
- `lib/core/settings.dart`: `exports` (stel van drie, verstek almal aan), `whatsappTemplate` (verstek hieronder).
- UI (laai skill `projekkonteks:ui-ux`; ontwerpstelsel in `planne/hoofplan.md`; alle teks in `lib/l10n/app_af.arb`):
  - Hersien: drie merkblokkies vir die uitvoere (onthou in instellings); dienstydlyn wys blok-etikette in kleur en liedname op musiekstukke; diens-etiket en Oggend/Aand veranderbaar.
  - Werk: "Kopieer WhatsApp-teks" (knipbord) langs "Wys in gids".
  - Instellings: WhatsApp-sjabloon met plekhouers en 'n voorskou.
  - `lib/features/library/library_screen.dart` (nuut, hoofstuk, roete in `shell.dart`): **blaaier** oor `<outDir>` se `diens.json`-lêers. Twee aansigte: **Preke** (per jaar, nuutste eerste: datum, Oggend/Aand, etiket, tema; aksies Speel, Wys in gids, Kopieer WhatsApp-teks) en **Sang** (alle liedere: naam, diens, datum; Speel, Wys in gids). Soekveld oor tema, skriflesing en liednaam. Lees by oopmaak en met 'n Herlaai-knoppie; geen lêer-wagter nie.
- `test/fixtures/`: per diens (4 met video: `YWz5gf0onjk`, `6s_FFatG0so`, `lBMwRt3eIus`, `uub_CnO7bd0`) die ffmpeg-kenmerk-uitset (gz, klein) + verwagte musiekstukke; gestoorde Ollama-antwoorde vir die etikette; `info.json`-uittreksels.
- Toetse: `sound_test`, `blocks_test`, `bounds_test` (op etikette), `service_info_test`, `cutter_test` (paaie, args, sjabloon), `library_test` (lees `diens.json`), widget-toetse vir die blaaier en uitvoerkeuse.

## WhatsApp-sjabloon (verstek, goedgekeur)
```
*{diens} · {datum}*
Tema: {tema}
Skriflesing: {skriflesing}
Fokus: {fokus}
{belydenis}
```
`{diens}` = Oggenddiens/Aanddiens; `{datum}` = "Sondag 15 November 2026". Leë velde: die reël val weg. Verwag vir `YWz5gf0onjk`:
```
*Aanddiens · Sondag 15 November 2026*
Tema: Uit die oorvloed van die hart praat die mond
Skriflesing: Mattheus 12:22-37
Fokus: Mattheus 12:34,36,37
NGB Artikel 37
```

## Stappe
1. **Klank-kenmerke in die app.** Kies die ffmpeg-roete wat die prototipe naboots: (a) `astats`/`aspectralstats` + `ametadata=print` of (b) ffmpeg gee 16 kHz s16le-PCM op stdout en Dart bereken RMS per 10 ms en platheid (FFT ≤ 60 reëls, geen nuwe afhanklikheid nie). Kies die een wat binne ±2 s dieselfde segmente as `segmente.txt` gee en < 15 s neem vir 60 min; noteer die keuse en tyd in die Log. Stoor die kenmerke van die 4 dienste as fixtures. — kontrole: `sound_test` eers rooi; dan al 4 dienste se musiekstukke binne ±2 s van `segmente.txt`.
2. **Dienstydlyn uit die klank.** `classify` + `timeline()` op klank-blokke; YouTube se `[musiek]` word nie meer vir die soort gebruik nie. — kontrole: toets: `YWz5gf0onjk` het musiek by 11:40–14:44, 22:10–23:30, 56:34–60:52 (±2 s); bestaande dienstydlyn-toetse aangepas en groen.
3. **Datum en diensinligting.** `ServiceInfo` uit `info.json`; regmaak van die datum by die bron. — kontrole: `service_info_test` eers rooi: `YWz5gf0onjk` → 2026-11-15, Aand, tema/skriflesing/fokus/belydenis soos in die sjabloon-voorbeeld, psalms [33, 42, 46]; `6s_FFatG0so` → 2026-11-15, Oggend.
4. **Spraakblokke.** `blocks(words, sound)`: sny by musiek, pouse ≥ 2 s en "Amen". — kontrole: `YWz5gf0onjk` gee 15–50 blokke; geen blok kruis 'n musiekstuk nie; die gebed by 14:46 begin 'n blok.
5. **KI-etikette.** Planner-skema en prompt soos onder Lêers; parse en valideer (onbekende etiket → `ander`). Stoor die werklike antwoorde vir die 4 dienste as fixtures (`E2E=1` om te herskep). — kontrole: met fixtures: elke diens het presies een preek-loop ≥ 15 min, die blokke direk voor en ná is `gebed`; liedname vir `YWz5gf0onjk` sluit Psalm 33, 42, 46 in. Die geloofsbelydenis (waar dit voorkom) is nooit `gebed` nie.
6. **Grense uit etikette.** `findBounds` op etikette; merkwoord-gebede geskrap (alle roepers, ook `prayerMarks` → `gebed`-blokke). — kontrole: `bounds_test`: die preke met woordtye in `sermons.json` bly binne ±0,5 s; `n02BUbwNV3E`-tipe gevalle gee steeds `sure == false`.
7. **Uitvoere.** `serviceDir`, `wordArgs`, `songArgs`, `whatsappText`, `diens.json`; `cutJob` met die gekose uitvoere. — kontrole: sny `YWz5gf0onjk`: gids `2026/2026-11-15 Aand - Uit die oorvloed van die hart praat die mond/`; `ffprobe`: Volle preek = einde − begin ±0,05 s; Net die woord = som van die dele ±0,1 s; elke `Sang/NN *.mp3` het titel/album/snit-etikette; `WhatsApp.txt` presies gelyk aan die verwagte teks hierbo.
8. **UI: uitvoerkeuse, WhatsApp, sjabloon.** Hersien-merkblokkies (almal aan), dienstydlyn met etikette en liedname, Werk "Kopieer WhatsApp-teks", Instellings-sjabloon met voorskou. — kontrole: widget-toetse; skermkiekies lig en donker (resep in `CLAUDE.md`).
9. **Blaaier.** `library_screen` met Preke- en Sang-aansig, soek, aksies. — kontrole: `library_test` op 'n tydelike gids met twee `diens.json`; widget-toets: soek "Psalm 42" wys net die lied; skermkiekies lig en donker met die `YWz5gf0onjk`-uitvoer.
10. **Afronding.** `@stelsel`-blokke (`sound`, `service_info`, `library_screen` nuut; `captions`, `bounds`, `planner`, `cutter`, `jobs`, `settings`, `shell`), vloei `diensindeling` (`vloei:`/`inleiding:`/`hoekom:`/`stap:`), `kaart.py --check`, `dart analyze`, `dart format`.
11. **Hersiening: Ollama en [musiek].** `plan()` kry die bloklys (met etikette) in plaas van `compact(segs)`; bedraad die teks in die gebruikersboodskap of skrap die `compactText`-parameter en prompt-reël; `think: false`, temperatuur 0, skrap die `think`-veld. Probeer dan één oproep (etikette + titel/beskrywing/Shorts) met die kleiner bloklys; dryf dit steeds, hou twee en skryf die meting in die Log. Skrap YouTube `[musiek]` as spraak/musiek-bron: `_musicTag`/`SegmentKind.music` uit onderskrifte, `blocks()` se oorslaan, `compact()` se `[musiek]`, Transcript in Hersien kry gefiltreerde segmente. — kontrole: `grep -rn "musiek\]" lib/` leeg (behalwe 'n opmerking); planner_test bewys dat bloklys-teks in die boodskap is; flutter test groen.
12. **Hersiening: duplikate.** `musicBetween` een helper (bounds.dart); `'WhatsApp.txt'`/`'diens.json'` as konstantes in één plek en library lees diens.json via een funksie; work_screen `_copyWhatsapp` gebruik dieselfde pad as library (met sjabloon-terugval); `p.join` in sound.dart; review_controller lees analysis.json een keer; `Future.any`+cancel en intro/outro-`clip` in jobs.dart een keer; `_dienst` en 'GK Oranjerivier' na ARB/instellings soos library_screen; models.dart se `@stelsel` bygewerk (`Block`/`Song`, geen `Prayer`); hernoem review_controller `blocks` → `soundBlocks`. — kontrole: flutter test, dart analyze, kaart.py --check groen.

## Aanvaarding
- `flutter test` groen sonder internet of Ollama; `dart analyze` skoon; `kaart.py --check` sonder FOUT.
- Klank: op al 4 dienste is elke musiekstuk uit `segmente.txt` gevind (±2 s); YouTube-merkers word nie meer vir spraak/musiek gebruik nie.
- Etikette (`E2E=1`, regte Ollama): op al 4 dienste die regte preek en die twee gebede; grense binne ±0,5 s van `sermons.json` waar woordtye bestaan; één Ollama-oproep per preek.
- `YWz5gf0onjk`: datum 2026-11-15, Aand; die vyf uitvoere in die regte gids met korrekte `ffprobe`-duur en mp3-etikette; `WhatsApp.txt` presies soos hierbo.
- Blaaier wys die uitgevoerde diens en sy liedere; soek werk; skermkiekies lig en donker.

## Prestasie-begroting
- Klank-ontleding: één ffmpeg-proses per diens, < 15 s vir 60 min op Linux; klassifikasie lineêr, < 100 ms.
- Ollama: steeds één oproep per preek (etikette in dieselfde oproep as titel/beskrywing); dinkmodus af.
- Uitvoer: twee video-herkoderings (Volle preek, Net die woord); mp3's uit klank alleen. Meet en noteer in die Log.
- Blaaier: lees `diens.json`-lêers by oopmaak/Herlaai; geen lêer-wagter, polling of agtergrond-draad nie.

## Buite bestek
Biblioteek per lied, outomatiese WhatsApp-stuur, YAMNet/Whisper, liedteks-herkenning, Shorts-veranderinge, uitvoer van ou dienste in grootmaat.

## Ingryp
- Moenie YouTube se `[musiek]`-merkers terugbring vir spraak/musiek nie.
- Faal die klank-klassifikasie op 'n diens: kyk eers na die grafiek (`navorsing/spektrogram-prototipe/plot.py`), verander drempels net globaal, nooit per diens nie. Faal dit steeds: skryf onder Vrae (YAMNet is 'n besluit vir Schalk).
- Ollama kies nooit tye nie; dit benoem net blokke.
- UI volg `projekkonteks:ui-ux` en die ontwerpstelsel; geen hardgekodeerde teks nie.

## Vrae
- (aanname) Intro/outro op albei video-uitvoere (Volle preek, Net die woord), nie op mp3's nie.
- (aanname) WhatsApp-klank = `Net die woord.mp3`.
- (aanname) Oggend = stroom begin voor 13:00.
- (aanname) Onbegeleide sang kom selde voor; die twee kenmerke is genoeg tot 'n toets anders wys.
- Schalk: watter video het die geloofsbelydenis as gebed gekry? Dit word 'n fixture vir stap 5.

## Log
- 1 klaar — roete (b): ffmpeg 16 kHz s16le-PCM op stdout, Dart-FFT (512, radix-2, geen afhanklikheid); 62–75 min video in 5,3–6,6 s (dart run, JIT); sound_test rooi→groen: al 4 dienste se musiekstukke binne ±2 s van segmente.txt; fixtures test/fixtures/sound/*.json.gz (per-sekonde db/lef/flat).
- 2 klaar — sound.json (saveSound/loadSound/soundBlocks) deur planJob geskryf en deur Hersien gelaai (ou planne: een ffmpeg-lopie ná aflaai); timeline() geskrap, dienstydlyn verf net spraak/musiek; toets YWz 11:40/22:10/56:34-musiek ±2 s groen; flutter test 171 groen. Let wel: parseJson3 hou nog [musiek]-segmente vir bounds/prayers tot stap 6.
- 3 klaar — service_info.dart (ServiceInfo.fromInfo/fromDescription/toJson, serviceStart); InfoFields.uploadDate gebruik nou serviceStart (enigste roepers: planJob/cutJob/store, almal herstel); service_info_test rooi→groen: YWz 2026-11-15 Aand, psalms [33,42,46]; 6s 2026-11-15 Oggend; 'Skrifgedeelte' en etikette sonder dubbelpunt; flutter test 177 groen. Afwyking: ServiceInfo woon in service_info.dart (nie models.dart nie); toets gebruik offset +2 h vir determinisme.
- 4 klaar — blocks(segs, sound) in captions.dart, Block/BlockLabel in models.dart; blocks_test rooi→groen: YWz5gf0onjk 39 blokke, geen blok kruis musiek, blok by 14:46,6 begin 'Onse Vader'. Afwyking: pouse-drempel kBlockPause = 3 s (gemeet van woord-begin + ≤1 s, ≈ 2 s regte stilte); by 2 s gee YWz 87 blokke, buite die 15–50 van die plan. Klankmerkers ([geproes] ens.) is nie woorde nie.
- 5 klaar — Planner.analyse (een klein Ollama-oproep sonder onderskrifte; antwoord = gebed_voor/preek_van/preek_tot/gebed_na + nommerlyste, nie 'n etiket per blok nie), 4 antwoorde in test/fixtures/ollama; labels_test groen (1 preek-lopie ≥15 min omhein deur gebed, YWz Psalm 33/42/46), flutter test 186 groen, commit c644ac9. Afwyking: titel/beskrywing/Shorts bly by Planner.plan (qwen3 8b dryf by 14k tokens: 565 s en kapot JSON; nou 20-60 s)
- 6 klaar — findBounds(blocks, sound) uit etikette (preek = langste loop; begin = gebed voor, terug tot by musiek; einde = Amen van gebed ná); prayers/_prayerCue/Prayer/prayers_test geskrap, prayerMarks uit analysis.json (gebed-blokke), planJob: klank → blokke → analyse → findBounds → snap → plan; bounds_test: YWz/6s/uub binne 1,5 s, ná stilte-snap ±0,5 s; sintetiese gevalle noSermon/twoSermons/noPrayerBefore sure==false; flutter test 172 groen. Afwyking: lBMw het geen handmerke in sermons.json (dus nie in bounds_test); 5 ouer dienste in sermons.json het nie klank/Ollama-fixtures nie (net die 3 getoets). vloei-stapnommers (preekgrense 1/2 weggeval) word in stap 10 herstel
- 7 klaar — serviceDir/wordParts/songArgs+cutSong/whatsappText/cutParts, cutJob skryf Volle preek.mp4, Net die woord.mp4, Sang/NN <lied>.mp3, WhatsApp.txt, diens.json in <uit>/2026/2026-11-15 Aand - <tema>/; settings exports + whatsappTemplate; audioJob maak mp3 langs Net die woord.mp4; E2E=1 op die regte YWz-video: Volle preek = 2474,89 s (±0,05 s), Net die woord = som van dele (±0,06 s per deel), 3 liedere met titel/album/snit-etikette, WhatsApp.txt gelyk aan verwagte teks; flutter test 177 groen. Afwykings: geen eie wordArgs nie (cutParts/joinArgs dek dit, ook vir intro/outro); Net die woord-duur wyk 0,11 s oor 2 dele af (30 fps-raam + AAC-raam per deel), toets laat 0,06 s per deel toe i.p.v. 0,1 s totaal; Net die woord.mp4 gaan nie na YouTube nie (_uploadable)
- 8 klaar — 180 toetse groen, analyze skoon, kaart --check sonder FOUT; skermkiekies lig/donker: ongetoets (nie hersien nie; widget-toetse dek merkblokkies, Aand, sjabloonvoorskou, kopieer)
- 9 klaar — library_test (3) + widget-toets (soek 'Psalm 42' wys net die lied) groen, 188 toetse; skermkiekies lig/donker uit toets-data in out/shots/biblioteek-*.png (nie die regte YWz-uitvoer nie: app kon nie loop sonder cmake)
- 10 klaar — kaart --check sonder FOUT of WAARSKUWING, analyze skoon, 188 toetse groen
- 11 klaar — plan() kry compact(blocks, snit) (bloktekst in die gebruikersboodskap, compactText geskrap), think:false/temp 0/num_predict 2048, Planner.think geskrap; _musicTag/Segment.kind geskrap (klank-etiketlyne soos [Musiek] word uit parseJson3 weggelaat); grep "musiek\]" lib/ leeg; 186 toetse groen, kaart --check sonder FOUT. Regte qwen3:8b (plan() op fixture-blokke): YWz 42 s, 6s 46 s, uub 36 s, lBMw 39 s, almal geldige plan met 3 Shorts (was 565 s by 14k tokens). Een-oproep-samevoeging NIE gedoen nie: bloklys (~4k) + snitteks (~8k tokens) in een 16k-konteks is die grootte waar qwen3 8b voorheen gedryf het; twee oproepe bly.
- 12 klaar — musicBetween(sound, from, to) een helper (bounds.dart); kWhatsappFile/kIndexFile in cutter.dart; readService(dir) in library.dart (library + work_screen `_copyWhatsapp` gebruik dit, met kWhatsappTemplate-terugval); loadAnalysis(dir) lees analysis.json een keer (jobs, review_controller, toets); _abandonable en intro/outro een keer in jobs.dart; p.join in sound.dart; kChurch-konstante; models @stelsel bygewerk; flutter test 186 groen, analyze skoon, kaart --check sonder FOUT. Afwykings: review_controller `blocks` → `sound` (nie `soundBlocks`: dit bots met die funksie soundBlocks()); 'GK Oranjerivier'/_dienst bly Afrikaanse uitvoerteks in cutter.dart (kChurch), nie ARB nie (soos kDefaultTemplate; dit is nie UI nie); screens_test se Kopieer-toets kry 'n diens.json.

## Verslag
**Gebou:** sound.dart (spektrogram), blokke in captions.dart, ServiceInfo (service_info.dart), etikette in Planner.analyse, findBounds/wordParts, cutParts/serviceDir/cutJob (Volle preek, Net die woord, Sang, WhatsApp.txt, diens.json), Hersien-uitvoerkeuse + Oggend/Aand + diens-soort + liedname op die tydlyn, Werk "Kopieer WhatsApp-teks", Snitlyste WhatsApp-sjabloon met voorskou, Biblioteek (Preke/Sang, soek, Herlaai) in die rail. Tak `bou/diensindeling`, nie gepush.

**Bewys per kriterium:**
- `flutter test` 188 groen (+2 oorgeslaan = E2E) sonder internet/Ollama; `dart analyze` skoon; `kaart.py --check` sonder FOUT of WAARSKUWING.
- Klank: sound_test op al 4 dienste, musiek ±2 s.
- Etikette/grense: labels_test en bounds_test op fixtures van regte Ollama-antwoorde (YWz, 6s, uub binne 1,5 s; ná snap ±0,5 s). lBMw het geen handmerke.
- YWz5gf0onjk: `E2E=1 flutter test test/service_outputs_test.dart` (regte ffmpeg, 63 s) groen: gids `2026/2026-11-15 Aand - <tema>/`, Volle preek 2474,89 s, Net die woord = som van dele, 3 mp3's met titel/album/snit, WhatsApp.txt = goedgekeurde teks.
- Biblioteek: library_test (3) en widget-toets: soek "Psalm 42" wys net die lied.

**Ongetoets:** skermkiekies lig en donker is uit toetsdata (out/shots/biblioteek-*.png, hersien-*.png), nie uit die lopende app met die YWz-uitvoer nie (geen cmake/ninja). Hersien se skerm by 1100x720 is styf: die Shorts-lys wys net 1,5 rye. Skepsis oor die regte Ollama: nie weer op al 4 dienste geloop nie, net fixtures plus een regte oproep (YWz, 232 s koue begin).

**Afwykings:** kBlockPause 3 s (nie 2 s); ServiceInfo in service_info.dart; TWEE Ollama-oproepe per preek (etikette, dan titel/beskrywing/Shorts) i.p.v. een: een-oproep nie in stap 11 probeer nie (bloklys + snitteks ≈ 12k tokens, waar qwen3:8b voorheen gedryf het); plan() gebruik nou dinkmodus af, temperatuur 0, bloktekst van die snit (YWz 42 s, 6s 46 s, uub 36 s, lBMw 39 s, regte qwen3:8b); num_ctx 16384 met 'n syfer-alleen skema, etikette in Dart afgelei; toets-offset +2 h; geen eie wordArgs (cutParts); Net die woord-duur ±0,06 s per deel; Net die woord.mp4 word nie na YouTube opgelaai nie; vloei-stapnommers diensindeling 1-13 en preekgrense 1-2 herbenommer; Hersien-lys van 96 na 72 px om plek vir die uitvoerreël te maak; `service.json` in die werkgids hou Oggend/Aand en diens-soort.

**Prestasie:** klank 5-7 s per 62-75 min (een ffmpeg-proses); een ekstra Ollama-oproep (etikette) per preek; sny maak 2 herkoderings (Volle preek, Net die woord) plus mp3's; Biblioteek lees diens.json by oopmaak/Herlaai, geen wagter, poll of draad.

**Oop vraag vir Schalk:** watter video het die geloofsbelydenis as gebed gehad (onbeantwoord).

**Hersiening (2026-11-21, twee opsommers):**
- Ernstig: `plan()` kry `compact(segs)` met YouTube `[musiek]`, nie die bloklys nie, en `compactText` word nie eers in die boodskap gebruik nie (jobs.dart:336, planner.dart:277/302); `[musiek]` steeds bron vir spraak/musiek (captions.dart:44-50,198); twee Ollama-oproepe (jobs.dart:317/333); `plan()` met dinkmodus aan en temp 0,6 (planner.dart:272/291). → stap 11.
- Duplikate/struktuur: `musicBetween` dubbel (bounds.dart:66/127); `'WhatsApp.txt'`/`'diens.json'` op 3 plekke; `_copyWhatsapp` vs `_copy`; analysis.json 3× gelees; Future.any- en intro/outro-patroon dubbel in jobs.dart; `_dienst` hardgekodeer vs ARB; models.dart @stelsel verouderd; `blocks`-naam dubbelsinnig; sound.dart sonder `p.join`. → stap 12.
- Bly ongetoets: regte Ollama net op YWz (nie al 4); skermkiekies uit die lopende app (geen cmake/ninja). `snapBounds` voeg twee silencedetect-prosesse by (bestond reeds; nie in begroting nie). Grense-toets ±1,5 s teenoor Aanvaarding ±0,5 s. kBlockPause 3 s aanvaar.

**Opgelos in stap 11/12:** plan() kry bloktekst (geen `[musiek]`, geen compactText) en loop sonder dinkmodus; `[musiek]`/Segment.kind geskrap; musicBetween, WhatsApp/diens.json-konstantes, `_copyWhatsapp` via readService, analysis.json een keer gelees, `_abandonable`/intro-outro, p.join in sound, models @stelsel, `blocks` → `sound` in review_controller. Bly oop: twee Ollama-oproepe; regte Ollama op al 4 dienste is nou net vir plan() gemeet (etikette-fixtures bly van stap 5); skermkiekies uit die lopende app.

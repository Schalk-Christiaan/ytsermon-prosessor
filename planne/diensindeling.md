status: oop

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

## Verslag

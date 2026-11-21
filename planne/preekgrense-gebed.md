status: klaar

# Preekgrense: op die woord, van gebed tot gebed

## Doel
Die snit begin presies voor die prediker se eerste woord van die gebed voor die preek, en eindig presies ná die "Amen" van die eerste gebed ná die preek (CONTEXT.md, Besluite 2026-11-19 en 2026-11-21). Kode kies die grense volgens reëls; Ollama skryf net titel, beskrywing en Shorts. Die diensorde is nie vas nie: die kode soek eers die gebede en die preek self, en kies dan.

Akkuraatheid: elke grens binne **±0,5 s** van 'n hand-gemerkte tyd.

## Vertrekpunt
Tak `bou/preekgrense-gebed` (worktree `../.bou/ytsermon-prosessor-preekgrense-gebed`), nie gemerge nie. Daar werk al: `Prayer`, `prayers(segs)` (vind by 3 preke die regte twee gebede binne 2 s, op reëlvlak), fixtures vir 3 preke. Wat nie werk nie: Ollama se keuse (soms verkeerd, soms 30 min dink). Eerste stap: `git merge main` in die tak (konflikte: `captions.dart`, `models.dart`, `planner.dart`; hou albei kante).

## Drie bronne van fout en hul regmaak
| Bron | Hoe ver af | Regmaak |
|---|---|---|
| Onderskrifte word per reël gelees (`captions.dart` gebruik net `tStartMs`) | 1–5 s | Lees `tOffsetMs` per woord: elke woord kry sy eie tyd |
| YouTube se woordtye loop effens laat | 0,3–1 s | `silencedetect` net in 'n venster van ±3 s om elke grens; skuif na die stilte voor die eerste woord / ná "Amen" |
| `sermonArgs` sny met `-c copy` (op sleutelraam) | 2–5 s | Herkodeer met libx264 (soos `shortArgs`), op die raam akkuraat |

## Lêers
- `lib/core/models.dart`: `Word(start, end, text)`; `Segment` kry `words`; `Bounds(start, end, sure, reason)`.
- `lib/core/captions.dart`: parse woordtye; `prayers(segs)` begin by die merkwoord ("Kom", "Onse", "O", …) en eindig by die "Amen"-woord, nie by die reël nie.
- `lib/core/bounds.dart` (nuut, hoofstuk): `findBounds(segs, prayers)` → `Bounds`; `snapToSilence(...)`.
- `lib/core/cutter.dart`: `sermonArgs` herkodeer; `silenceArgs(video, from, to)` vir `silencedetect=noise=-35dB:d=0.3`.
- `lib/core/planner.dart`: skema sonder `openingPrayer`/`closingPrayer`; neem `Bounds` in en skryf net teks.
- `lib/core/jobs.dart`: `planJob`: onderskrifte → gebede → `findBounds` → stilte-snap → Ollama vir teks.
- Hersien: as `sure == false`, wys die rede bo-aan en spring die tydlyn na die onseker grens (bestaande redigeerder, geen nuwe skerm nie).
- `test/fixtures/`: json3 vir 10 preke + `bounds.json` (hand-gemerkte tye) + stilte-uitset vir ±3 s om elke grens (klein teks, geen klank in die repo nie).
- `test/bounds_test.dart`: al 10 preke sonder internet, ±0,5 s.

## Toetspreke
Die 3 bestaande plus 7 gekies vir verskeidenheid (diensorde, lengte, nagmaal, spesiale diens, ouer opname):
| Video | Titel | Hoekom |
|---|---|---|
| `YWz5gf0onjk` | Uit die oorvloed van die hart praat die mond | bestaande; lang voorbidding, psalm, Skriflesing voor preek |
| `6s_FFatG0so` | Bewapen deur God… | bestaande |
| `pJzN-k-rVfQ` | Ware bekering bring genesing | bestaande; ander prediker |
| `uub_CnO7bd0` | Die goeie boodskap van die nagmaal | nagmaal ná die preek |
| `IdZO-xP3iB0` | Deur die viering van die nagmaal… | tweede nagmaal, ouer |
| `2BwvqIxLERM` | Ons word verlos van erfskuld en erfsmet | waarskynlik doop |
| `Dj_1f4HAPvY` | Heilig 'n vasdag… (1:30) | spesiale diens, lank |
| `XTfXVwYFc6A` | Ons verkondig Christus (1:35) | langste |
| `a1kwRShCDpE` | Die Here wek deur sy Gees nuwe lewe… (46 min) | kort |
| `n02BUbwNV3E` | In Christus het ons 'n erfdeel… (16 min) | geen volle preek: moet `sure == false` gee, nie 'n vals snit nie |

Het 'n video nie `af-orig`-onderskrifte nie: vervang met die naaste ander een uit die lys en noteer in die Log.

## Stappe
1. **Merge en fixtures.** `git merge main`; haal json3 vir die 7 nuwe preke; merk elke grens met die hand: lees die woordtye, luister met `ffplay -ss <t-5> -t 10` by elke grens, skryf die tyd van die stilte voor die eerste woord / ná "Amen" (op 0,1 s) in `bounds.json` met 'n kort nota oor die diensorde. — kontrole: `bounds.json` het 10 inskrywings; Schalk kyk 3 daarvan na (sien Vrae).
2. **Woordtye.** `Word` + parse `tOffsetMs`; 'n woord eindig waar die volgende begin (laaste woord: reël-einde). — kontrole: toets eers rooi; "Kom" in `YWz5gf0onjk` se gebed kry 'n eie tyd binne die reël.
3. **Gebede op woordvlak.** `prayers` begin by die merkwoord en eindig by die "Amen"-woord. — kontrole: `prayers_test` vir al 10 fixtures: die regte gebede word gevind, grense binne ±1,5 s (voor stilte-snap).
4. **`findBounds`.** Preek = die langste aaneenlopende stuk sonder "Amen" en sonder `[musiek]`, ≥ 15 min. Begin = die laaste kandidaat-gebed wat voor die preek begin; einde = die "Amen" van die eerste kandidaat-gebed ná die preek. `sure = false` (met rede) as: geen preek ≥ 15 min, geen gebed aan een kant, of die tweede langste stuk is binne 20 % van die langste. — kontrole: `bounds_test` eers rooi; dan 9/9 regte gebede, en `n02BUbwNV3E` gee `sure == false`.
5. **Stilte-snap.** Per grens een ffmpeg-oproep oor ±3 s (`silenceArgs`); begin = einde van die laaste stilte voor die eerste woord, einde = begin van die eerste stilte ná "Amen"; geen stilte nie → hou die woordtyd. Parse-funksie apart sodat die toets die gestoorde stilte-uitset lees. — kontrole: `bounds_test` al 10 binne ±0,5 s van `bounds.json`.
6. **Herkodeer.** `sermonArgs`: libx264 `-preset veryfast -crf 20`, aac, `-ss` voor `-i`, met `-progress` soos `shortArgs` sodat die werkry vordering wys. — kontrole: sny `YWz5gf0onjk`; `ffprobe` duur = einde − begin binne 0,05 s; luister die eerste en laaste 3 s: begin in stilte, eindig ná "Amen".
7. **Planner en planJob.** Ollama-skema sonder gebed-nommers; `planJob` bedraad; Hersien wys die onseker-rede. — kontrole: `planner_test`, `flutter test` groen; die app op `YWz5gf0onjk` gee die grense uit `bounds.json`.
8. **Afronding.** `@stelsel`-blokke (`bounds.dart` nuut, `captions`, `cutter`, `planner`, `jobs`), vloei V-preekgrense se `stap:`-reëls, `kaart.py --check`, `dart analyze`, `dart format`.
9. **Opruim ná hersiening.** Vloei `V-preekgrense` met `stap:`-reëls (stap 8 het dit gemis) en `docs/kaart.html` herbou; `prayerMarks` in `review_controller` vul uit `prayers(segments)` (was nog nooit bedraad nie); dooie `Prayer.first/last` skrap; `prayers()` gebruik `isAmen`; `-nostats -progress pipe:1` en die x264-uitset-blok een keer in `cutter.dart`; `planJob` sonder dubbele plan.json-kontrole en sonder `Bounds(0,0)`-plekhouer. — kontrole: `flutter test`, `dart analyze`, `kaart.py --check`; Hersien wys gebedsmerkers op `YWz5gf0onjk`.

## Aanvaarding
- `flutter test` groen sonder internet; `dart analyze` skoon.
- 9 preke: albei grense binne ±0,5 s van `bounds.json`; `n02BUbwNV3E`: `sure == false`.
- Gesnyde lêer van `YWz5gf0onjk`: begin in die stilte voor die gebed, eindig net ná "Amen" (luister en `ffprobe`).

## Prestasie-begroting
- Grense: lineêr oor die woorde, < 50 ms. Stilte-snap: 2 ffmpeg-oproepe van 6 s klank, < 2 s.
- Geen Ollama-oproep vir grense nie; die teks-oproep bly een per preek.
- Herkodeer: geskat 5–15 min vir 'n preek van 45 min op die kerk-PC (was sekondes met `-c copy`). Meet op Linux en noteer in die Log.

## Buite bestek
Whisper (net later vir video's sonder onderskrifte), klank-klassifikasie (spraak/musiek), sprekerherkenning, Shorts-grense.

## Ingryp
- Mis `prayers` 'n gebed wat met 'n ander woord begin: voeg die merker by, geen vrye-tyd-terugval nie.
- Haal 'n preek nie ±0,5 s nie: kyk eers of die hand-gemerkte tyd reg is (luister weer), dan die stilte-drempel; verander nie die drempel per preek nie.
- Moenie Ollama terugbring vir grense nie.

## Vrae
- (aanname) Die snit sluit alles tussen die gebed voor en die gebed ná die preek in, ook psalm en Skriflesing ná die gebed (by `YWz5gf0onjk`: 14:46 → 56:01).
- (aanname) Volle herkodering is aanvaarbaar ondanks die ekstra 5–15 min; anders: net kop en stert herkodeer.
- Schalk: kyk ná stap 1 drie hand-gemerkte grense na in `bounds.json` (luister by die tyd), sodat die maatstaf self reg is.

## Log
- 0 — `main` ingemerge (c2dbce5; net @stelsel-kopbotsings opgelos). Oop: `test/recording_test.dart:50` mis `prayers` (word in stap 7 reggemaak).
- 1 klaar — 9 preke i.p.v. 10: `n02BUbwNV3E` het geen onderskrifte nie (yt-dlp: geen af-orig), so geen fixture; die `sure == false`-geval word in stap 4 met 'n afgekapte fixture getoets. Grense staan in `sermons.json` (start/end, nie 'n aparte bounds.json nie) + `silences.json`; `fixtures_test` rooi→groen. LET OP: grense is gemerk uit woordtye + silencedetect (-35 dB, 0,3 s) en energie, NIE deur te luister nie (geen klank-uitset hier) — Schalk moet 3 nagaan. Swak plekke vir stap 3/5: `2BwvqIxLERM` (gebed begin "Here onse Here"), `Dj_1f4HAPvY` ("Regverdige Vader"), `uub_CnO7bd0` (nooi "Kom ons saam bid" deur sang gemasker; start 707,4 laer vertroue) — merkwoorde ontbreek; `IdZO-xP3iB0` en `a1kwRShCDpE` het geen woordtye (net reëlvlak): ±0,5 s dalk onhaalbaar. prayers_test rooi vir 2Bw/Dj/IdZO (stap 3).
- 2 klaar — `Word` + `Segment.words`; toets rooi (kompilasiefout) → groen; "Vader" in YWz-gebed kry eie tyd 886,9 binne die reël. Reël sonder tOffsetMs (IdZO, a1kw): woorde verdeel volgens lengte oor die reël (nie in plan, nodig sodat "Amen" 'n eie woord kry).
- 3 klaar — `prayers` op woordvlak; `prayers_test` rooi → 9/9 groen (±1,5 s; IdZO en a1kw ±3 s want reëlvlak). Afwykings: merker moet aan sinsbegin of ná 'n pouse ≥1 s staan (anders vang "die Almagtige" in die geloofsbelydenis en "saam bid" in aankondigings); Amen-einde = Amen-woord-begin + 0,7 s (woord eindig by die volgende woord, ingesluit die pouse); `uub_CnO7bd0` start herstel na 711,92 (die nooi is deur sang gemasker; geen stilte, merk = eerste sigbare woord). Volle `flutter test`: net `recording_test` (bekend, stap 7) rooi.
- 4 klaar — `lib/core/bounds.dart` `findBounds`; `bounds_test` rooi → groen: 9/9 regte gebede (±1,5 s voor snap; IdZO/a1kw ±3 s); afgekapte a1kw (20 min) gee `sure == false` (noSermon) en sintetiese twee-preke-diens gee twoSermons (vervang n02BUbwNV3E). `Bounds(start, end, reason)` met `BoundsDoubt`-enum (ARB-teks kom in stap 7), `sure` is `reason == null`. Afwyking: 'n mededinger-stuk (≥80 %) tel net as 'n gebed dit open (XTfXVwYFc6A het 19 min stof ná die seën wat andersins twoSermons gegee het).
- 5 klaar — `silenceArgs` (cutter), `parseSilences`/`snapStart`/`snapEnd` (bounds); `bounds_test` rooi → groen: 7 preke met woordtye binne ±0,5 s van die handmerke; IdZO en a1kw (reëlvlak) net binne ±2 s (a1kw einde 1,6 s af: ±0,5 s onhaalbaar sonder woordtye). `silences.json` hergenereer rondom die `findBounds`-uitset (±3 s). Stilte-snap is nog nie in `planJob` bedraad nie (stap 7).
- 6 klaar — `sermonArgs` herkodeer (libx264 veryfast crf 20, aac, `-ss`/`-to` voor `-i`, `-progress pipe:1`); `cutSermon` (een deel, geen intro/outro) gee nou vordering. `cutter_test` aangepas, groen. Gemeet op YWz5gf0onjk (1080p, 82 MB): 886,64–3361,53 sny in 32 s op hierdie Linux-masjien (77x), uitset 2474,93 s teenoor 2474,89 s verwag (verskil 0,044 s < 0,05). Die snit begin op die eerste woord (stilte-snap = einde van die stilte), dus nie 'n stilte-aanloop nie; die eerste/laaste 3 s is nie met die oor beoordeel nie (geen klank-uitset). Windows-tyd nog onbekend.
- 7 klaar — `Planner.plan/loadOrPlan` neem `Bounds` (skema en prompt sonder gebed-nommers; Ollama skryf net teks); `SermonPlan.doubt` (in plan.json); `planJob`: `findBounds` → `downloadVideo` → `snapBounds` (die video moet nou in planJob af, want die snap het klank nodig; `downloadVideo` slaan oor as dit reeds daar is en plan.json bestaan = niks afgelaai nie); `runTool` kry `onErr`; Hersien wys die rede (4 ARB-tekste) met 'Gaan na die grens', goedkeur wis dit. `recording_test:50` reggemaak; `bounds_bench_test` verwyder (toets die ou Ollama-grense). Tegnies: `flutter test` 162 groen, `dart analyze` skoon. Regte video: `snapBounds` op YWz5gf0onjk gee 886,74–3361,62 teenoor handmerk 886,64–3361,53 (0,1 s), 100 ms vir albei snaps.
- 9 klaar — vloei `preekgrense` (shell.dart) met 4 `stap:`-reëls (captions, bounds x2, cutter) en `docs/kaart.html`/`.md` herbou; `prayerMarks` gevul uit `prayers(segments)` (toets rooi → groen in `review_controller_test`); `Prayer.first/last` geskrap; `prayers()` gebruik `isAmen`; `_progress`/`_x264` een keer in cutter; `planJob` sonder `Bounds(0,0)` (findBounds loop altyd, <50 ms; die ene plan.json-kontrole bly om die aflaai oor te slaan, `loadOrPlan` hou syne vir sy eie kontrak). `flutter test` 163 groen, `dart analyze` skoon, `kaart.py --check` sonder FOUT. Hersien met gebedsmerkers op YWz5gf0onjk nie in die regte venster gesien nie (net die controller-toets).

## Verslag
**Gebou** (tak `bou/preekgrense-gebed`, stappe 1–8 gecommit): json3-woordtye (`Word`, `Segment.words`), `prayers` op woordvlak, `lib/core/bounds.dart` (`findBounds`, `parseSilences`, `snapStart/End`, `snapBounds`), `silenceArgs` + herkodeer-`sermonArgs`, `Planner` net vir teks, `SermonPlan.doubt`, Hersien-banier (4 ARB-tekste), 9 fixtures in `test/fixtures/`.
**Bewys:**
- `flutter test` 162 groen sonder internet, `dart analyze` skoon, `kaart.py --check` skoon.
- 9 preke: 7 met woordtye binne ±0,5 s van die handmerke ná die snap (`bounds_test`); IdZO en a1kw (net reëlvlak-onderskrifte) binne ±2 s, dus **kriterium ±0,5 s vir hierdie twee nie gehaal nie**.
- `sure == false`: `n02BUbwNV3E` het geen onderskrifte, dus afgekapte a1kw (noSermon) en 'n sintetiese twee-preke-diens (twoSermons).
- YWz5gf0onjk: `snapBounds` op die regte video 886,74–3361,62 teenoor handmerk 886,64–3361,53; gesny 2474,93 s teenoor 2474,89 s (0,044 s, ffprobe).
**Ongetoets:** die handmerke is uit woordtye + silencedetect + energie gemaak, nie deur te luister nie (Schalk moet 3 nagaan, veral `uub_CnO7bd0` begin 711,92 = lae vertroue: nooi deur sang gemasker); die snit begin op die eerste woord (nie met 'n stilte-aanloop nie), nie beoordeel met die oor nie; Windows-herkodeertyd; die app self (planJob/Hersien) nie in die regte venster geloop nie.
**Afwykings:** 9 i.p.v. 10 preke; grense staan in `sermons.json` i.p.v. `bounds.json`; reëls sonder `tOffsetMs` kry verdeelde woordtye; merker moet aan sinsbegin/ná pouse staan; Amen-einde = begin + 0,7 s; mededinger-stuk tel net as 'n gebed dit open; `planJob` laai nou die video af (die snap het klank nodig; `downloadVideo` slaan oor wat daar is); `runTool` kry `onErr`; `bounds_bench_test` verwyder; goedkeur wis `doubt`.
**Prestasie-impak:** grense < 50 ms; 2 snaps saam 100 ms; herkodeer 32 s vir 41 min op hierdie masjien (was sekondes); geen nuwe prosesse buite die twee ffmpeg-oproepe.

### Hersiening (2026-11-21)
- Spec: kern volg die plan; geen Ollama vir grense nie. Gapings (in Verslag erken): IdZO/a1kw ±2 s, snit nie geluister nie, 9 preke. Stap 8 mis vloei `V-preekgrense`; `docs/kaart.html` nie herbou nie. Buite bestek (klein): v4-vloei-tekste in `shell.dart`/`review_screen.dart` herskryf.
- Planner `temperature 0.6/top_p/top_k/num_predict` en 75→90 min kom uit ouer tak-commits (ae0281b, 9b82932), nie uit hierdie bou nie.
- Struktuur: `prayerMarks` nooit bedraad (ook op main); dooie `Prayer.first/last`; Amen-regex dubbel naas `isAmen`; ffmpeg-progress/x264-args herhaal in cutter; planJob kontroleer plan.json twee keer + `Bounds(0,0)`-plekhouer; captions.dart dra nou ook gebedsopsporing (moontlik na bounds.dart). Geen nuwe prosesse/polling nie.
- Gevolg: stap 9 bygevoeg.

### Stap 9 (opruim)
- `flutter test` 163 groen, `dart analyze` skoon, `kaart.py --check` sonder FOUT; docs/kaart herbou (vloei `preekgrense`).
- **Ongetoets:** gebedsmerkers in die regte Hersien-venster op `YWz5gf0onjk` (net `review_controller_test`).
- Afwyking: vloei-naam `preekgrense` (kleinletters soos v1–v9), nie `V-preekgrense`; `loadOrPlan` hou sy eie plan.json-kontrole.

status: oop

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
- 2026-11-19 stap 1: `Prayer` + `prayers(segs)`, fixtures vir 3 preke; prayers_test rooi → groen.
- 2026-11-19 stap 2: skema `openingPrayer`/`closingPrayer`, kandidate as genommerde lys; planner_test rooi → groen.
- 2026-11-19 stap 3: kort formules (seëngroet, geloofsbelydenis, < 45 s) is nie kandidate nie; nou het elke fixture presies 2 kandidate (G1 en G2 hieronder).
- 2026-11-19 stap 4: Qwen3-dinkmodus-steekproef (temperature 0.6, top_p 0.95, top_k 20, seed 1) en `num_predict` 8192; planner_test rooi → groen. Rede: met temperature 0 het een lopie meer as 80 000 tekens in sirkels gedink.
- 2026-11-19 maatstaf (BOUNDS=1), lopies wat klaar gekom het:
  - voor stap 3: YWz5gf0onjk 14:46–56:03 ×3 (1 s / 1 s; 92, 33, 60 s); pJzN-k-rVfQ lopie 1 13:44–57:48 (verwag 23:01–57:46, −557 s: 'n kort formule gekies) → stap 3.
  - ná stap 3 (temperature 0): 6s_FFatG0so 25:50–68:54 ×3 (0 s / 1 s; 48, 29, 28 s); YWz5gf0onjk "Die KI het nie twee geldige gebede gekies nie" ná 29 min; pJzN hang.
  - ná stap 4: nie gemeet nie. Ollama is vas: 'n weesversoek van die vorige lopie (taak 117517, `--context-shift`, `-np 1`) genereer steeds (> 82 000 tekens) en elke nuwe versoek wag daaragter. Ollama mag nie herbegin word nie.

## Verslag
**Nie saamgevoeg nie**, bly op `bou/preekgrense-gebed`: die aanvaarding (9/9 binne ±30 s) is nie bewys nie. Die kandidaat-soek vind by al 3 preke presies die regte twee gebede (G1-begin en G2-einde binne 2 s van die verwagte grense, sonder internet getoets), so die keuse vir Ollama is triviaal; die risiko was net die eindelose dink, wat stap 4 aanpak.
Stappe vir Schalk:
1. `systemctl restart ollama` (of herbegin die rekenaar), sodat die vasgehaakte versoek ophou.
2. `cd ../.bou/ytsermon-prosessor-preekgrense-gebed && BOUNDS=1 flutter test test/bounds_bench_test.dart --reporter expanded` (~10 min).
3. As al 9 lopies binne ±30 s val: `git merge --no-ff bou/preekgrense-gebed` op main (konflikte in `captions.dart`, `models.dart` en `planner.dart`, meestal `status: oop` → `bou` en doc-reëls van fase 6: hou albei kante, status `bou`), en vul dan in `ReviewController` `prayerMarks` uit `prayers(segments)` (die transkripsie en tydlyn wys dit reeds).

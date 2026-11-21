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

## Verslag

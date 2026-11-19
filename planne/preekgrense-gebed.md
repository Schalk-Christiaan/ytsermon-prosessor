status: oop

# Preekgrense: van gebed tot gebed

## Doel
Die snit begin by die gebed voor die preek en eindig by die "Amen" van die gebed ná die preek (CONTEXT.md, Besluite 2026-11-19). In plaas daarvan dat qwen3:8b vrye tye raai, soek die kode die **kandidaat-gebede** uit die onderskrifte (aanroep/uitnodiging → "Amen") en Ollama kies net twee nommers: die gebed voor en die gebed ná die preek. `think:true`, `temperature:0` en `seed:1` bly.

## Lêers
- `lib/core/models.dart`: `Prayer(start, end, first, last)`.
- `lib/core/captions.dart`: `prayers(segs)` vind kandidaat-gebede.
- `lib/core/planner.dart`: prompt + skema vra `openingPrayer`/`closingPrayer` (nommers) i.p.v. `sermonStart`/`sermonEnd`; grense = gebed se begin/einde; preeklengte 15–90 min.
- `lib/core/jobs.dart`: `planJob` gee die kandidate deur.
- `test/fixtures/<id>.af-orig.json3.gz` (3 preke) + `test/fixtures/README` (hoe om weer op te haal).
- `test/prayers_test.dart` (kandidate sonder internet), `test/planner_test.dart` (nommers → tye), `test/bounds_bench_test.dart` (BOUNDS=1: 3 preke × 3 lopies teen regte Ollama).

## Verwagte grense (self uit die onderskrifte bepaal)
| Video | Gebed voor | Gebed ná (Amen) | Opmerking |
|---|---|---|---|
| `YWz5gf0onjk` | 14:46 "Onse Vader in die hemel" (886 s) | 56:01 (≈3363 s) | voorbidding tot 21:27, Psalm 42, Skriflesing 23:32, preek-amen 53:13 "Kom ons dank saam" |
| `6s_FFatG0so` | 25:50 "Onse Vader in die hemel" (1550 s) | 68:52 (≈4134 s) | voorbidding tot 34:19, Psalm 30, preek 36:59–66:19 |
| `pJzN-k-rVfQ` | 23:01 "laat ons nou saam bid" (1381 s) | 57:43 (≈3466 s) | gebed tot 29:52, Psalm 19, Skriflesing 33:33, preek-amen 56:36 |

## Stappe
1. `Prayer` + `prayers(segs)`: deel die onderskrifte in stukke wat by elke "Amen" eindig (teks ná "Amen" in dieselfde reël begin die volgende stuk); 'n stuk is 'n kandidaat as dit 'n gebed-merker bevat ("Kom/Laat ons … bid/dank", "Onse/Ons Vader", "O Here/Vader", "Hemelse/Liewe/Heilige Vader", "Almagtige", "Genadige"); die gebed begin by die eerste merker, eindig by die Amen-reël, hoogstens 15 min. Fixtures vir die 3 preke as gz. — kontrole: `prayers_test` eers rooi; dan vir elke preek is daar 'n kandidaat binne ±30 s van albei verwagte grense.
2. Planner: skema `openingPrayer`/`closingPrayer` (heelgetal), die kandidate as genommerde lys in die gebruikersboodskap ("G3 14:46–21:27 (6:41): 'Onse Vader…' … '…Amen.'"), prompt verduidelik dat die snit albei gebede insluit. Ongeldige nommer of voor ≥ ná → `PlanException`. Preek 15–90 min. — kontrole: `planner_test` (nommers → tye; ongeldige nommer → fout) eers rooi.
3. `planJob` bedraad; maatstaf `BOUNDS=1 flutter test test/bounds_bench_test.dart`: 3 preke × 3 lopies teen qwen3:8b, druk elke lopie se grense, faal as een > 30 s af is. — kontrole: 9/9 binne ±30 s; tye in die Log.
4. `@stelsel`-blokke bygewerk; `dart analyze`, `flutter test`, `dart format`.

## Aanvaarding
- `flutter test` groen sonder internet (fixtures); `dart analyze` skoon.
- `BOUNDS=1`: al 3 lopies van al 3 preke binne ±30 s van die gebed-grense hierbo.

## Prestasie-begroting
Kandidaat-soek is een lineêre deurloop oor die segmente (~1500), geen ekstra proses of Ollama-oproep; die prompt word korter (kandidaatlys is ~20 reëls). Steeds een Ollama-oproep per preek.

## Buite bestek
Whisper, middelstukke uitsny (fase 6), UI-veranderinge in Hersien.

## Ingryp
- As die kandidaat-soek 'n gebed mis wat net met "Vader," of "Here," begin: voeg die merker by, nie 'n vrye-tyd-terugval nie.
- Moenie fase 1 se `think:true`/seed terugdraai nie.

## Vrae
- (aanname) "Sluit albei gebede in" lees ek as: van die eerste woord van die laaste gebed vóór die preek (in hierdie gemeente die lang voorbidding, wat die psalm en Skriflesing ná die gebed insluit) tot die "Amen" van die dankgebed ná die preek. Wil Schalk eerder net die preek met die gebede direk daaromheen, of die gebede uit, is dit twee reëls in `Planner.plan` (gebruik `prayer.end`/`prayer.start` andersom).
- (aanname) Twee ander preke: `6s_FFatG0so` (bevestiging/wapenrusting) en `pJzN-k-rVfQ` ("Ware bekering bring genesing", ander prediker).

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
3. As al 9 lopies binne ±30 s val: `git merge --no-ff bou/preekgrense-gebed` op main (konflik in `jobs.dart` `planJob` en `planner.dart`: hou albei kante), en vul dan in `ReviewController` `prayerMarks` uit `prayers(segments)` (die transkripsie en tydlyn wys dit reeds).

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

## Verslag

status: stop

# Hersien-paneel volg die keuse in die diensbaan

## Doel
Die regterkantse paneel in Hersien (`lib/features/review/properties_panel.dart`) het vyf chip-oortjies wat oor drie rye vou (Preek, Shorts, Snitte, Uitvoer, Transkripsie), en onder titel en beskrywing is dit grootliks leeg. Schalk hou nie daarvan nie. Besluit 2026-11-22 (`CONTEXT.md` → Besluite): die paneel volg wat in die diensbaan gekies is, soos die inspekteur in 'n video-redigeerder. Die preek-tydskuifbalke en die klankvolume is reeds verwyder (`9ac4e14`).

## Ontwerp
- **Twee gewone Material-oortjies** bo-aan (`TabBar` met onderstreep, nie chips nie): **Inligting** en **Transkripsie**.
- **Inligting, niks gekies nie:** Titel, Beskrywing, daaronder Uitvoer (die huidige `_output`: uitvoersoorte + soort diens), en daaronder twee kort lyste **Shorts (n)** en **Snitte (n)**. Elke ry is 'n `ListTile` (bv. "Short 2 · 31:20 · 58 s", "Snit 1 · 40:10–41:02"). 'n Tik kies daardie item. So kan 'n sleutelbord-gebruiker ook kies, nie net met die muis in die diensbaan nie.
- **Inligting, 'n Short gekies** (tik op 'n Short-blok in die diensbaan of op sy ry): bo 'n terug-knoppie "← Inligting" en die opskrif "Short 2 van 3", dan die huidige velde vir een Short (titel, begin, lengte, Begin hier, Speel, Vee uit). Dit is dieselfde inhoud as nou in `_shorts`, maar vir een item.
- **Inligting, 'n snit gekies** (tik op die gestreepte snit in die diensbaan of op sy ry): dieselfde patroon met die huidige `_cuts`-inhoud vir een snit.
- **Terug na niks gekies:** die terug-knoppie, `Esc`, 'n tik op 'n leë plek in die diensbaan (wat ook steeds soek), of as die gekose item uitgevee word.
- **Gekose blok in die diensbaan** kry 'n sigbare merk wat nie net kleur is nie (dikker buitelyn in `onSurface`, soos die hakies se fokusrand).
- **Onderaan** bly "✓ Gestoor" en "Herstel na voorstel" soos nou.
- Kies jy 'n item terwyl Transkripsie oop is, spring die paneel na Inligting.

## Lêers
- `lib/features/review/review_controller.dart`: kies-toestand (een gekose Short of snit, of niks), met `notifyListeners`. Wis dit by uitvee, ontdoen/herdoen as die item nie meer bestaan nie, en by `resetToProposal`.
- `lib/features/review/service_timeline.dart`: tik op Short-blok kies dit; tik op 'n snit-span kies dit (raaktoets op `cuts` in die bestaande `onTapUp`); tik elders soek én wis die keuse; teken die gekose merk.
- `lib/features/review/properties_panel.dart`: nuwe uitleg hierbo; hergebruik die bestaande Short- en snit-wyers, moenie hulle herskryf nie. Die `_Tab`-enum en chips verdwyn.
- `lib/features/review/review_screen.dart`: `Esc` wis die keuse (die bestaande `_key`-hanteerder); die paneel in die laai onder 1280 breed werk dieselfde.
- `lib/l10n/app_af.arb` (+ `flutter gen-l10n`): nuwe tekste (bv. "Inligting", "Short {n} van {total}", "Snit {n} van {total}", terug-etiket); verwyder ongebruikte sleutels (`tabSermon`, `tabOutput`, `shortsTab`, `cutsTab` as hulle nie meer gebruik word nie).
- Toetse: `test/controls_test.dart`, `test/controls_inventory.dart`, `test/controls_meta_test.dart`, `test/workspace_test.dart`, `test/screens_test.dart` (kiekies).

## Stappe
1. **Rooi toetse vir die keuse.** In `test/controls_test.dart` of 'n nuwe `test/selection_test.dart`: (a) tik op 'n Short-blok → paneel wys "Short 1 van n" en die Short se titelveld; (b) tik op 'n snit in die diensbaan → paneel wys die snit; (c) terug-knoppie en `Esc` → Inligting met Titel; (d) uitvee van die gekose Short → terug na Inligting; (e) tik op 'n ry in die Shorts-lys kies daardie Short; (f) Tab bereik die lys-rye. — kontrole: die toetse faal op die huidige kode.
2. **Kies-toestand in die beheerder** (+ eenheidstoets in `test/review_controller_test.dart`: kies, uitvee wis, ontdoen na 'n toestand sonder die item wis, `resetToProposal` wis). — kontrole: eenheidstoets groen.
3. **Diensbaan:** tik kies Short/snit, tik elders soek en wis, gekose merk geteken (nie net kleur nie). — kontrole: toetse 1(a), 1(b) se diensbaan-deel groen; bestaande sleep-toetse (insluitend "handle follows the pointer") bly groen.
4. **Paneel:** twee oortjies, Inligting (titel, beskrywing, uitvoer, Shorts- en Snitte-lys), item-aansig met terug-knoppie, Transkripsie. Hergebruik die bestaande wyers. — kontrole: alle toetse van stap 1 groen; `controls_inventory.dart` en `controls_meta_test.dart` bygewerk (nuwe sleutels `ctl.hersien.tab-info`, `ctl.hersien.tab-transcript`, `ctl.hersien.select-back`, lys-rye; ou `tab-*`-sleutels weg); Tab bereik elke kontrole, ≥ 40 px.
5. **Esc en laai:** `Esc` wis die keuse; onder 1280 breed (laai) werk die paneel dieselfde. — kontrole: toets by 1100×720.
6. **Poleer en kiekies** (skill `projekkonteks:ui-ux`): `SHOTS=<gids> flutter test test/screens_test.dart` met nuwe kiekies van Hersien met niks gekies, 'n Short gekies, 'n snit gekies en Transkripsie, lig en donker, 1100 en 1600 breed. Bekyk hulle self: geen oorloop nie, geen leë paneel nie, kontras ≥ 4,5:1. Kopieer die kiekies na `docs/kiekies/hersien-paneel/` en sit dit in die Verslag (hulle is gitignored, so hulle bly net op skyf in die hoofgids).
7. **Afsluiting:** `dart format`, `dart analyze` skoon, `flutter test` groen, `@stelsel`-blokke en funksie-kommentaar van geraakte lêers bygewerk (`status: bou`, nie `klaar` nie), `python3 ~/.claude/plugins/cache/projekkonteks/projekkonteks/0.12.1/hooks/kaart.py --check` 0 FOUT.

## Aanvaarding
- Die paneel het nie meer chip-oortjies nie, net Inligting en Transkripsie op een ry.
- 'n Tik op 'n Short-blok of snit in die diensbaan wys net daardie item in die paneel; terug-knoppie, `Esc` en 'n tik op 'n leë plek gaan terug na Inligting.
- Shorts en snitte is ook sonder muis kiesbaar (lys-rye in Inligting, bereikbaar met Tab).
- Die gekose blok in die diensbaan is sigbaar gemerk, nie net met kleur nie.
- Uitvee, ontdoen en Herstel laat nooit 'n gekose item agter wat nie meer bestaan nie.
- `flutter test` groen, `dart analyze` skoon, kiekies lig en donker by 1100 en 1600 sonder oorloop.

## Prestasie-begroting
Geen nuwe prosesse, drade, timers of polling nie. Die diensbaan se `TracksPainter` mag net herteken as die keuse verander, nie per speel-tik nie (dieselfde reël as nou: die speelkop teken apart). Geen nuwe pub-afhanklikheid nie.

## Buite bestek
Nuwe kenmerke vir Shorts of snitte (byvoeg met sleep, meer velde), die transport-balk, die video-paneel, en kleure of lettertipes van die ontwerpstelsel. Niks word na YouTube opgelaai nie.

## Ingryp

## Vrae

## Log
- 2026-11-22: opgeneem as stap 12 in `planne/desktop-poleer.md`; hierdie plan bly as ontwerpverwysing.
- 2026-11-22: plan geskryf ná Schalk se keuse "Volg die keuse".

## Verslag

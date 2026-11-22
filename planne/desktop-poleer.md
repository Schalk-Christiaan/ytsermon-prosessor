status: oop

# Desktop-poleer: Windows-styl, Karoo-wit, Werk-rooster, stoorspasie, snitlysgroepe met KI, pixel-kuns uit Bybelverhale

## Doel
Die app voel steeds soos 'n foon-app. Dit is 'n Windows-program vir die kerk-PC. Schalk het op 2026-11-22 gekies (artefak "Preekverwerker-style", https://claude.ai/artifact/BVzU66uJQknTgmvWi5uSyx):
- **Styl A (Verkenner)** as basis.
- **Styl C** se groepe per afdeling, met 'n Oplaai-aftreklys, op die Werk-skerm.
- 'n **Karoo-wit, aardse kleurskema**.
- **Animasies** tussen skerm- en paneelverskuiwings, in elke deel van die app.
- **Pixel-kuns uit Bybelverhale** as ekstra grafika: laai- en vorderingstonele, leë toestande en klein karakters.
- **Duidelike vordering:** Schalk weet nou nie wat besig is terwyl dit laai nie. Elke wag moet sê wat gebeur, hoe ver dit is en wat volgende kom.

Hierdie plan sluit ook `planne/hersien-paneel.md` in (Hersien-paneel volg die keuse; daardie plan is `stop`), plus die res van Schalk se lys:
- 0,8 px-oorloop in die rooster;
- kies-alles;
- klankskuifbalk in Hersien;
- stoorspasie;
- snitlysgroepe met KI-voorstelle, ook ná 'n render.

**Grens:** niks word in toetse of tydens die bou regtig na YouTube opgelaai nie. Geen `videos.insert` en geen snitlys-skrywe op 'n regte kanaal nie; YouTube-oproepe in toetse gebruik vervalsings. KI-voorstelle word net gewys; Schalk aanvaar hulle self.

## Ontwerpstelsel (vervang die kleurtabel in `planne/hoofplan.md`)
Kontras is nagegaan (WCAG). Hou die rolname in `lib/app/theme.dart` (`_scheme`) en vervang net die waardes:

| Rol | Lig: Karoo-wit | Donker: Karoo-nag | Rede |
|---|---|---|---|
| `surface` | `#F4F0E8` kalkwit | `#1C1915` | die Karoo se gebleikte klip en kalk; aards, nie koel grys nie |
| `surfaceContainerLowest` / panele | `#FBF8F2` | `#24201B` | verhoogde panele effens ligter (lig) / ligter (donker) |
| `surfaceContainer` | `#ECE6DA` | `#2B2620` | kolomopskrifte, statusbalk, sybalk |
| `surfaceContainerHigh` | `#E4DCCD` | `#332D26` | sweef/gekose agtergrond van rye |
| `onSurface` | `#2B2620` (13,2:1) | `#EDE6DA` (14,1:1) | donker ystersteen-ink |
| `outline` / sekondêre teks | `#6E6458` (5,1:1) | `#9C9284` (5,7:1) | |
| `outlineVariant` | `#D6CCBB` | `#3A332B` | tabellyne |
| `primary` Oranje (aksie) | `#B34E17` (4,6:1; wit daarop 5,2:1) | `#F08A4B` (7,0:1) | bly: die rivier se naam, nou ook roesrooi Karoo-grond |
| `secondary` Karoobos (seleksie, vordering, inligting) | `#5A6B47` (5,1:1; wit daarop 5,8:1) | `#A9BC93` (8,6:1) | vervang die rivier-teal: die bossies se grysgroen |
| `secondaryContainer` (gekose ry) | `#DDE3D2` | `#34402B` | |
| `tertiary` kanselhout (Shorts) | `#6B4A32` | `#C9A27E` | bly |
| fout / sukses | bly soos nou | bly | altyd met ikoon en woord |

Lettertipes bly Source Serif 4 (opskrifte, preektitels) en Source Sans 3 (UI).

**Desktop-tema (styl A):**
- `VisualDensity.compact` en `MaterialTapTargetSize.shrinkWrap`.
- Knoppies en invoervelde 32 px hoog; radius 4 oral (dialoë 8).
- Geen skaduwees op kaarte nie; tabelle met kolomopskrifte in plaas van lyste kaarte.
- Hover-toestande op elke ry en knoppie. Muiswyser `SystemMouseCursors.click` op alles wat klikbaar is.
- Basisteks 14 px en kleinste UI-teks 12 px. Die pakket se 40 px-reël (`controls_meta_test.dart`) word **32 px** vir desktop; dit is die Windows-norm vir muis.
- Navigasie: die `NavigationRail` in `lib/app/shell.dart` word 'n vaste sybalk van ±200 px met ikoon en woord, met 'n oranje streep by die huidige skerm (vorm, nie net kleur nie). Bo elke skerm staan 'n opdragbalk met die skerm se aksies; onderaan die venster 'n statusbalk.
- Geen nuwe pub-pakket nie: Material met 'n eie desktop-tema.

**Beweging** (`Theme` + gedeelde konstantes in `lib/app/theme.dart`, bv. `kMotionFast = 150 ms`, `kMotionMed = 250 ms`, kurwe `Curves.easeOutCubic`; uitgang korter as ingang):
- **Skermwissel** in die sybalk: fade-through (oue vervaag uit, nuwe vervaag in en skuif 8 px op), 250 ms, met `AnimatedSwitcher`/`FadeTransition`. Die `animations`-pakket is nie nodig nie.
- **Hersien-paneel:** van Inligting na 'n gekose item skuif die item 16 px in van regs en vervaag in; terug skuif dit uit.
- **Paneel en laai:** die eienskappe-laai onder 1280 breed skuif in.
- **Aftreklyste en kieslyste:** skaal van 0,95 en vervaag (die Material-verstek is goed).
- **Rye** wat by die Werk-lys bykom of klaar raak, vervaag in en uit.
- **Verminderde beweging:** as `MediaQuery.disableAnimations` aan is, is alle duurtes 0 of net 'n kort vervaag.
- **Geen** beweging op die speelkop, vorderingsbalke of die diensbaan-sleep nie.

**Pixel-kuns** (nuwe lêer `lib/app/pixel_art.dart`; geen beeldlêers en geen nuwe pakket nie):
- *Tegniek:* elke sprite is 'n klein rooster van karakters in Dart (bv. 16×16 of 32×24, een string per ry, `.` = deursigtig) met 'n palet van 4–6 kleure. Elke kleur is 'n tema-rol, sodat die kuns vanself in Karoo-wit en Karoo-nag werk. Animasie is 2–6 rame.
- *Weergawe:* 'n `PixelSprite`-wyer teken die rooster met `CustomPainter` as skerp vierkante, op 'n heelgetal-skaal (×3, ×4, ×6), sonder anti-aliasing. 'n `PixelScene` lê 'n paar sprites en 'n grondlyn saam.
- *Animasie:* hoogstens 8 rame per sekonde, uit een `Ticker` wat net loop terwyl die toneel sigbaar is (`TickerMode`) en die taak besig is. Met verminderde beweging, of as die toneel klaar is, wys dit net een stil raam.
- *Hoekom so:* die kuns word kode wat 'n agent kan skryf, in 'n toets kan nagaan en in 'n diff kan hersien. Dit herkleur vanself met die tema, en die installeerder groei nie.

**Wat dit wys:**
- **Geen afbeelding van God of Christus nie.** Dit is 'n Gereformeerde gemeente; respekteer die tweede gebod. Wys mense uit die verhale (klein, sonder gesigsdetail), diere, voorwerpe en simbole.
- Die toon is warm en eerbiedig, nie snaaks nie, en nooit by 'n fout of verlore werk nie.

**Toneel per fase** (`JobPhase` in `lib/core/jobs.dart`), elk met die teks wat sê wat gebeur:

| Fase / toestand | Toneel | Hoekom dié verhaal | Vordering in die toneel |
|---|---|---|---|
| `meta` (inligting haal) | Abraham kyk na die sterre | tel en kyk, voor die reis | sterre verskyn een vir een |
| `download` | Noag se duif vlieg met die olyftak terug ark toe | iets word teruggebring | die duif vlieg van links na regs volgens die persentasie |
| `plan` (KI soek die preek) | die wyse manne volg die ster | soek die regte plek | kameelkaravaan stap; onbekende duur, so die ster flikker sag |
| `cut` (volle preek) | Nehemia bou die muur | steen vir steen saamgestel | stene word gelê volgens die persentasie |
| `cut` (Shorts) | Dawid kies vyf gladde klippe uit die spruit | klein, uitgesoekte stukke | een klip per Short wat klaar is |
| `audio` | Dawid speel die harp vir Saul | klank | note sweef op |
| `upload` | Jakob se leer | iets gaan op | 'n figuur klim sport vir sport volgens die persentasie |
| wag in die ry | skape agter die herder | wag hul beurt | een skaap per item in die ry |
| klaar | Noag se reënboog oor die ark | belofte nagekom | eenmalig, dan stil |
| fout | Jona op die strand, uitgespoeg | 'n tweede kans | stil; die teks sê wat fout is en "Probeer weer" |
| leeg (geen preke) | die saaier saai | begin hier | stil; die knoppie "Laai preke" staan langsaan |
| leeg (geen werk) | herder by die kraal, skape rus | niks te doen nie | stil |

**Karakters elders** (spaarsaam: hoogstens een per skerm, nooit in die pad van 'n taak nie):
- 'n klein skaap in die statusbalk wat stap terwyl 'n taak loop (kliek → Werk-skerm), en lê as niks loop nie;
- die herder by die eerste-gebruik-opstelling (`setup_screen.dart`) wat elke stap "toon" (stil rame);
- 'n duif by die oplaai-bevestiging;
- by "Gestoor" in Hersien nie, want dit gebeur te dikwels (ui-ux: persoonlikheid net waar dit verdien word).

**Vordering wat sê wat gebeur** (die eintlike probleem):
- Elke taak wys 'n stappelys van sy fases met die huidige een vet: ✓ Inligting · ✓ Aflaai · ● Preek soek · Sny · Shorts · Klank. Die volgorde kom uit die job se soort (`JobKind`), sodat Schalk sien wat nog voorlê.
- Onder die toneel staan 'n reël met die konkrete stand, uit 'n nuwe `detail`-`ValueNotifier<String?>` langs `progress` en `phase` in `jobs.dart`, wat die runners vul. Voorbeelde:
  - "Laai af: 312 MB van 1,2 GB · 4,1 MB/s · ±3 min oor" (uit yt-dlp se uitset);
  - "KI lees die transkripsie (dit neem 1–3 min)";
  - "Short 2 van 3 · 58 s";
  - "Laai op: 41 %".
- Die tyd sedert die begin ("besig vir 2:14") tik saam met die toneel se Ticker, sonder 'n ekstra timer.
- Onbekende duur (`progress == null`) wys 'n onbepaalde balk plus 'n tipiese duur in woorde, nooit net 'n draaiende sirkel nie.
- 'n Uitvoubare "Wys besonderhede" toon die laaste 20 reëls van yt-dlp/ffmpeg/Ollama se uitset (al gelees deur die runners; net in die geheue, nie op skyf nie).
- Waar dit verskyn:
  - die Werk-skerm se huidige taak (groot, met toneel);
  - die Preke-ry of -kaart van 'n besige preek (klein: fase, persentasie en die skaap);
  - Hersien se laai-oorleg en die opstelskerm se aflaaie (dieselfde wyer, hergebruik; `review_screen.dart` r. 408/457/509, `setup_screen.dart` r. 169, `sermons_screen.dart` r. 373 en `work_screen.dart` r. 133 gebruik nou elk hul eie `ProgressIndicator`).

**Animasie oral** (bo-op Beweging hierbo):
- knoppies krimp effens by druk (0,97);
- blokkies se regmerkie teken in;
- rye skuif in wanneer hulle bykom;
- 'n Short- of snit-blok in die diensbaan vervaag in na skep;
- die statusbalk se getalle tel op na die nuwe waarde (150 ms);
- 'n suksesmerk kom in met 'n skaal van 0,9 na 1.

Alles gaan deur die bewegingskonstantes en `disableAnimations`.

## Lêers (hoofsaaklik)
- `lib/app/theme.dart`: palet, desktop-tema, bewegingskonstantes.
- `lib/app/shell.dart`: sybalk, statusbalk (stoorspasie), skermwissel-animasie.
- `lib/features/sermons/sermons_screen.dart`:
  - roosteroorloop;
  - kies-alles;
  - grootte per preek;
  - lysaansig word 'n tabel met kolomme (Titel, Datum, Lengte, Stand, Grootte);
  - opdragbalk.
- `lib/features/work/work_screen.dart`: rooster/tabel gegroepeer per afdeling, elk met 'n drie-stand-blokkie en 'n Oplaai-aftreklys.
- `lib/features/review/`:
  - `transport_bar.dart`: klankskuifbalk;
  - `review_controller.dart`, `service_timeline.dart`, `properties_panel.dart`, `review_screen.dart`: die keuse (uit `hersien-paneel.md`).
- `lib/features/playlists/playlists_screen.dart` en `lib/core/playlists.dart`: snitlysgroepe en KI-voorstelle.
- `lib/core/library.dart` of 'n nuwe klein funksie in `lib/core/paths.dart`: lêergroottes per preek.
- `lib/core/settings.dart` / `lib/core/store.dart`: groepe stoor.
- `lib/core/jobs.dart`: ná 'n render, vra voorstelle.
- Bestaande Ollama-oproep (grep `ollama`/`qwen3` in `lib/core/planner.dart`): hergebruik dit vir die voorstelle.
- `lib/app/pixel_art.dart` (nuut): `PixelSprite`, `PixelScene`, sprite-roosters; `lib/app/job_progress.dart` (nuut): die gedeelde vorderingswyer (toneel, stappelys, detailreël, besonderhede).
- `lib/core/jobs.dart`: `detail` en die laaste uitsetreëls by die runners; `lib/core/tools.dart`/`youtube.dart`: gee yt-dlp se grootte en spoed deur.
- `lib/l10n/app_af.arb`: alle nuwe teks.
- Toetse: `test/controls_test.dart`, `test/controls_inventory.dart`, `test/controls_meta_test.dart`, `test/workspace_test.dart`, `test/screens_test.dart`, plus nuwe eenheidstoetse vir grootte en groepe.

## Stappe
Elke stap: skryf eers die toets of kontrole en sien dit **rooi**, bou dan tot groen.

### A. Foute
1. **Roosteroorloop 0,8 px.** Reproduseer eers: 'n widget-toets wat die Preke-rooster by 1100×720 en 1600×900 bou (lig en donker, langste titel uit die toetsdata) en op `FlutterError` vir RenderFlex-oorloop faal. Herstel by die bron: die kaart se inhoud moet by sy hoogte pas, nie `mainAxisExtent` net 1 px groter maak nie. Kyk ook na teksskaal 1,0 en 1,25. — kontrole: die toets is rooi voor en groen ná; geen oorloop-waarskuwing in `flutter run -d linux` nie.

### B. Ontwerpstelsel en desktop-tema
2. **Karoo-wit-palet** in `theme.dart` volgens die tabel hierbo; werk die kleurtabel in `planne/hoofplan.md` by. Grep vir hardgekodeerde kleure in `lib/` (`Color(0x`) buite `theme.dart` en vervang hulle met rolle. — kontrole: 'n eenheidstoets wat die kontrasverhoudings van die tabel bereken (onSurface/surface ≥ 4,5, primary/surface ≥ 4,5, onPrimary/primary ≥ 4,5, secondary/surface ≥ 4,5, in lig en donker).
3. **Desktop-tema:** digtheid, radius 4, knoppie- en veldhoogtes, hover, muiswysers en tipe-groottes. Werk die minimumgrootte in `controls_meta_test.dart` by na 32 px. — kontrole: `controls_meta_test` groen met 32 px; `flutter test` groen.
4. **Sybalk en statusbalk** in `shell.dart`:
   - die sybalk het ikoon en woord, en 'n oranje streep by die huidige skerm;
   - die statusbalk wys links die aantal gekose items en hul grootte (waar die skerm 'n keuse het), en regs "Preke op skyf: 10,3 GB · 312 GB vry";
   - vrye spasie kom uit een oproep op versoek (by opstart en ná 'n taak), geen polling nie. Op Windows: grep eers of iets in die kodebasis dit reeds doen; anders `fsutil volume diskfree` / `df` met `Process.run` en 'n argumentlys. As dit te omslagtig is, laat vrye spasie weg en skryf dit onder `## Vrae`.
   - kontrole: widget-toets vir die sybalk-sleutels en die statusbalk-teks.
5. **Beweging** (konstantes en skermwissel, volgens Ontwerpstelsel → Beweging), met `disableAnimations` gerespekteer. — kontrole: 'n widget-toets dat die skermwissel 'n `FadeTransition` het; 'n tweede toets met `MediaQueryData(disableAnimations: true)` dat dit onmiddellik wissel (`pump()` sonder `pumpAndSettle`-tyd).

### C. Preke-skerm
6. **Grootte per preek** (`lib/core`): som die lêers in die preek se werkgids (bron, uitvoer, Shorts, klank). Gebruik `package:path` en `File.length`, asinkroon, net by laai en ná 'n taak; die resultaat word gekas in die skerm se toestand, nie op skyf nie. Wys dit as "1,42 GB" of "86 MB", met SA-desimale komma en 'n nie-breek-spasie. — kontrole: eenheidstoets met 'n tydelike gids (0 lêers, 1 lêer, geneste gids, ontbrekende gids → 0).
7. **Lysaansig as tabel:**
   - kolomme Titel, Datum, Lengte, Stand, Grootte;
   - kolomopskrifte, en klik op 'n opskrif sorteer;
   - die roosteraansig bly as keuse (die bestaande `sermonGrid`-instelling), en die kaarte kry ook die grootte;
   - opdragbalk bo met die skerm se aksies.
   - kontrole: widget-toets vir die kolomme en sortering.
8. **Kies-alles:**
   - 'n drie-stand-blokkie (`Checkbox(tristate: true)`) in die tabelopskrif en in die opdragbalk van die roosteraansig;
   - `Ctrl+A` kies alles, en Shift- en Ctrl-klik kies reekse en enkeles;
   - die keuse werk op die huidige gefiltreerde lys;
   - die statusbalk wys "3 van 7 gekies · 4,31 GB".
   - kontrole: toetse vir kies-alles, gedeeltelik (drie-stand) en ontkies, plus Ctrl+A.

### D. Werk-skerm (styl C se groepe)
9. **Gegroepeer per afdeling:**
   - drie groepe: Volle preke, Shorts en Klank vir WhatsApp, elk met 'n kopry: drie-stand-blokkie, naam, aantal · grootte, Oplaai-knoppie;
   - daaronder 'n rooster of tabel (dieselfde aansigkeuse en kaart/ry-styl as die Preke-skerm; hergebruik daardie wyer, moenie 'n tweede maak nie);
   - die huidige taak met vordering en Kanselleer bly bo-aan;
   - fout-items bly sigbaar met hul foutteks.
   - kontrole: widget-toets vir drie groepe met hul tellings, en dat kies-alles per groep net daardie groep raak.
10. **Oplaai-aftreklys per afdeling** (`MenuAnchor`), met die plekke vir daardie afdeling:
    - *Volle preke:* YouTube (openbaar), YouTube (ongelys), Kopieer na gids…, Wys in gids.
    - *Shorts:* YouTube Shorts (openbaar), YouTube (ongelys), Kopieer na gids…, Wys in gids.
    - *Klank:* Wys in gids (vir WhatsApp), Kopieer WhatsApp-teks, Kopieer na gids…
    
    Die aksie geld vir die gekose items in daardie groep, of vir een item as dit vanaf 'n ry se eie kieslys kom. Die bestaande aksies (Laai op, Wys in gids, Klank vir WhatsApp, Kopieer WhatsApp-teks, Wys op YouTube) word hergebruik, nie herskryf nie. "Kopieer na gids…" gebruik die bestaande gidskieser as daar een is; anders skryf dit onder `## Vrae` en laat dit weg. — kontrole: widget-toets met 'n vervalste YouTube-diens: die regte plekke per groep, en die aksie word met die gekose items geroep. Geen regte oplaai nie.

### E. Hersien
11. **Klankskuifbalk** in `transport_bar.dart`, langs die vorentoe- en terug-knoppies:
    - 'n klein ikoon (`volume_up`/`volume_off`; 'n klik demp) plus 'n skuifbalk van ±100 px;
    - beheer die speler se volume via die bestaande media_kit-speler;
    - die waarde bly in die sessie en hoef nie gestoor te word nie;
    - sleutel `ctl.hersien.volume`; pyltjiesleutels werk wanneer dit fokus het.
    
    Dit vervang die volume wat in `9ac4e14` uit die paneel gehaal is: die volume hoort by die transport, nie in die paneel nie. — kontrole: widget-toets: sleep of pyltjie verander die volume op die beheerder, en 'n klik op die ikoon demp en ontdemp.
12. **Hersien-paneel volg die keuse:** bou al die stappe 1–7 en die Aanvaarding uit `planne/hersien-paneel.md` (lees dié plan vir die ontwerp). Gebruik die beweging van stap 5 vir die oorgang van Inligting na 'n gekose item. — kontrole: soos in daardie plan.

### F. Snitlyste: groepe en KI
13. **Snitlysgroepe:**
    - Schalk kan in die Snitlyste-skerm 'n groep skep, hernoem en uitvee, met naam en opsionele beskrywing (bv. "Advent 2026", "Reeks: Die Bergpredikasie"), en preke daarby voeg of uithaal;
    - 'n preek kan in meer as een groep wees;
    - die bestaande reëls (Bybelboek, jaar) bly en werk soos voorheen;
    - groepe word in `settings.json` gestoor, met preek-ID's per groep (verdraag korrupte of ontbrekende velde soos die res van `settings.dart`);
    - by oplaai word 'n video ook by sy groepe se snitlyste gevoeg, via die bestaande `playlists()`/`createPlaylist`/`addToPlaylist` in `youtube.dart`.
    - kontrole: eenheidstoetse vir stoor en laai (ook korrup), en vir "die snitlyste van 'n preek = reël + groepe" sonder duplikate; widget-toets vir skep, hernoem, uitvee en preek byvoeg; oplaai-toets met 'n vervalste diens.
14. **KI-voorstelle vir 'n groep:**
    - 'n knoppie "Stel preke voor" by 'n groep vra Ollama (`qwen3:8b`, via die bestaande Ollama-kode) watter preke by die groep se naam en beskrywing pas;
    - die invoer is per preek: titel, Skriflesing, datum en die eerste ±500 woorde van die transkripsie as dit bestaan;
    - die antwoord is JSON (preek-ID's met 'n kort rede);
    - voorstelle word as 'n lys met blokkies gewys (Aanvaar gekose / Ignoreer), met 'n vorderingsaanduiding terwyl Ollama werk en 'n duidelike fout as Ollama nie loop nie;
    - een oproep op versoek; geen agtergrondwerk nie.
    - kontrole: eenheidstoets met 'n vervalste Ollama-antwoord (geldig, ongeldige JSON, onbekende ID's word weggelaat); widget-toets vir die voorstel-lys.
15. **Voorstelle ná 'n render:**
    - wanneer 'n preek se verwerking in `jobs.dart` klaar is, vra die app een keer vir voorstelle: by watter bestaande groepe die preek pas, en hoogstens een nuwe groepnaam (bv. 'n reeks wat in die titels herhaal);
    - die voorstel verskyn by die klaar-item op die Werk-skerm ("Voorgestelde snitlyste: Advent 2026, Johannes") met Aanvaar en Ignoreer;
    - die render wag nooit vir Ollama nie; faal Ollama, is daar net geen voorstel nie.
    - kontrole: toets met 'n vervalste job en Ollama: ná klaar is daar 'n voorstel, Aanvaar voeg die preek by die groep, en 'n Ollama-fout breek die job nie.

### G. Vordering en pixel-kuns
16. **Vordering sê wat gebeur** (`jobs.dart`):
    - voeg `detail` (teks) en 'n ring van die laaste 20 uitsetreëls by;
    - die runners vul dit vir aflaai (MB, spoed en tyd oor, uit yt-dlp se `--progress`-reëls), plan, sny (Short n van m), klank en oplaai.
    - kontrole: eenheidstoets vir die yt-dlp-vorderingsontleder met regte voorbeeldreëls (ook "Unknown" en "~"), en dat `detail` per fase gestel en ná die job leeg gemaak word.
17. **Gedeelde vorderingswyer** `job_progress.dart`: stappelys, detailreël, tyd sedert begin, onbepaald-met-woorde en "Wys besonderhede". Vervang die vyf los `ProgressIndicator`s wat in die Lêers genoem word. — kontrole: widget-toets per fase (die regte stap is vet, die detail word gewys, besonderhede vou oop); grep wys geen los `LinearProgressIndicator` meer buite die wyer nie (die skuifbalke uitgesluit).
18. **Pixel-enjin** `pixel_art.dart`: `PixelSprite` en `PixelScene`, palet uit tema-rolle, heelgetal-skaal, Ticker net wanneer sigbaar, en stil raam met `disableAnimations`. — kontrole:
    - eenheidstoets dat elke sprite se rye ewe lank is en net palet-karakters bevat;
    - goue toets (`matchesGoldenFile`) van een sprite op ×4 in lig en donker;
    - toets dat die Ticker stop as die wyer weg is of `TickerMode` af is.
19. **Tonele en karakters** volgens die tabel en die karakterlys hierbo, in die vorderingswyer, die leë toestande, die statusbalk-skaap en die opstelskerm. Geen afbeelding van God of Christus nie. — kontrole:
    - widget-toets dat elke `JobPhase` sy toneel kry;
    - kiekies van elke toneel in lig en donker, bekyk vir leesbaarheid op ×3 en ×4;
    - Oom Koos-deurloop: weet hy op elke vorderingskerm sonder om te raai wat besig is en hoe lank dit nog vat?
20. **Animasie oral** volgens "Animasie oral" hierbo. — kontrole: widget-toetse vir die druk-skaal en die ry-inskuif, en dieselfde toetse met `disableAnimations` (geen animasie nie).

### H. Afsluiting
21. **Poleer en kiekies** (skills `projekkonteks:ui-ux`, `impeccable`):
    - `SHOTS=<gids> flutter test test/screens_test.dart` vir elke skerm: Preke as rooster en as tabel met 'n keuse, Werk met groepe en 'n oop Oplaai-aftreklys, Hersien (niks gekies, Short gekies), Snitlyste met 'n groep en voorstelle, Instellings, die Werk-skerm tydens elke fase (met vervalste jobs) en die leë toestande;
    - lig en donker, 1100 en 1600 breed;
    - kritiseer volgens die ui-ux-skill se Kritiek (een sekonde, eerste blik, Oom Koos-deurloop) en herstel die top 3;
    - kopieer die kiekies na `docs/kiekies/desktop-poleer/` (in die hoofgids, buite die worktree, sodat hulle nie saam met die worktree verdwyn nie) en noem hulle in die Verslag.
22. **Kontrole:**
    - `dart format`, `dart analyze` skoon, `flutter test` groen;
    - `flutter build linux --debug` slaag, en die app begin sonder uitsonderings of oorloop-waarskuwings in die terminaal (`flutter run -d linux`, 20 s);
    - `@stelsel`-blokke en funksie-kommentaar van geraakte lêers bygewerk (`status: bou`);
    - `python3 ~/.claude/plugins/cache/projekkonteks/projekkonteks/0.12.1/hooks/kaart.py --check` gee 0 FOUT.

## Aanvaarding
- Geen oorloop-waarskuwing op enige skerm by 1100 en 1600 breed nie, lig en donker.
- Die app gebruik die Karoo-wit-palet (lig) en Karoo-nag (donker); kontrastoets groen; geen hardgekodeerde kleure buite `theme.dart` nie.
- Die app lyk soos 'n Windows-program:
  - vaste sybalk met woorde;
  - opdragbalk en statusbalk;
  - digte tabelle;
  - knoppies van 32 px en radius 4;
  - hover-toestande.
- Skermwissels en paneel-oorgange is geanimeer en val weg as verminderde beweging aan is.
- Preke: kies-alles (drie-stand, Ctrl+A), grootte per preek, en totale stoorspasie in die statusbalk.
- Werk: groepe per afdeling met eie kies-alles en 'n Oplaai-aftreklys met die regte plekke per afdeling.
- Hersien: klankskuifbalk by die transport; die paneel volg die keuse (Aanvaarding van `hersien-paneel.md`).
- Snitlyste: groepe skep, wysig en uitvee; KI stel preke vir 'n groep voor; ná 'n render word snitlyste voorgestel. Niks word sonder Schalk se Aanvaar toegepas nie.
- Elke wag in die app wys wat besig is (fase in 'n stappelys), hoe ver (persentasie of 'n tipiese duur in woorde) en die konkrete stand; besonderhede is uitvoubaar.
- Pixel-kuns uit Bybelverhale by vordering, leë toestande en spaarsaam elders; geen afbeelding van God of Christus nie; herkleur met die tema; stil met verminderde beweging.
- Animasie in elke deel van die app (druk, inskuif, regmerk, telling, oorgange), almal met die gedeelde konstantes.
- `flutter test` groen, `dart analyze` skoon, `kaart.py --check` 0 FOUT.

## Prestasie-begroting
- Geen nuwe agtergrondprosesse, timers of polling nie. Die enigste uitsondering: die pixel-toneel se `Ticker` (≤ 8 rame/s, net sigbaar en net terwyl 'n taak loop), wat ook die "besig vir"-tyd voed.
- Lêergroottes en vrye spasie word op versoek bereken (laai, ná 'n taak), asinkroon, nie in `build` nie.
- Hoogstens een Ollama-oproep per knoppiedruk en een per voltooide render.
- Animasies net op transform en opacity; geen herteken van die diensbaan per raam nie.
- Geen nuwe pub-pakket nie, tensy die rede in die Log staan.
- Die installeerder groei nie met meer as 2 % nie.

## Buite bestek
- Regte oplaai of snitlys-skrywe tydens die bou of in toetse.
- OAuth-veranderinge.
- `fluent_ui` of 'n ander UI-pakket.
- Nuwe lettertipes.
- Wolkberging.
- Beeldlêers of 'n sprite-redigeerder; klank-effekte.
- Outomatiese toepassing van KI-voorstelle.

## Ingryp

## Vrae

## Log
- 2026-11-22: pixel-kuns uit Bybelverhale, duidelike vordering en animasie oral bygevoeg (stappe 16–20).
- 2026-11-22: plan geskryf ná Schalk se keuse (styl A + C se Werk-groepe, Karoo-wit aards, animasies). Neem `hersien-paneel.md` op.

## Verslag

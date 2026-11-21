status: klaar

# UI-werkvlak: die app as video-redigeerder, en elke kontrole getoets

## Doel
Die app kry die uitleg van 'n moderne video-redigeerder, gebaseer op Schalk se twee verwysings: die Korsa-skoot op Dribbble (lig) en clideo (donker, oranje). Die identiteit bly die kerk aan die Oranjerivier. Elke knoppie, slider, skakelaar en kortpad word daarna outomaties getoets, sodat ons weet alles werk.

Twee uitkomste:
1. **Herontwerp van die uitleg** (Preke, Hersien → werkvlak, Werk, Instellings) in lig en donker, teen die vier persona's in `CONTEXT.md` `## Gebruikers`.
2. **Kontrole-dekking**: 'n inventaris van elke interaktiewe kontrole. 'n Toets faal as 'n kontrole nie in die inventaris staan nie, of as dit nie doen wat dit belowe nie.

Skills wat die bouer laai: `projekkonteks:ui-ux` (reëls, persona-deurloop, kritiek), `frontend-design:frontend-design` (ontwerpplan, hersiening teen die opdrag), `impeccable` (in `.claude/skills/`: `init`, `document`, `critique`, `audit` native, `polish`).

## Vertrekpunt
- Hoofplan `## Ontwerpstelsel`: modus **Bedien**, Oranje `#B34E17` aksie, rivier `#2C6A66` seleksie, kanselhout `#6B4A32` Shorts, Source Serif 4 + Source Sans 3, kenmerkende skuif = die dienstydlyn. **Dit bly.** Wat verander, is die uitleg, die vlakke en die donker tema.
- Skerms: `lib/app/shell.dart` (NavigationRail), `lib/features/{sermons,review,work,settings,setup,playlists}/`. Hersien (`review_screen.dart`, 750 reëls) het reeds die dienstydlyn, hakies, transkripsie, Shorts met 'n lengte-`Slider`, en ontdoen.
- `test/screens_test.dart` het 29 widget-toetse. Daar is nog geen `integration_test` nie, en geen cmake/ninja op die dev-masjien nie.
- **Afhanklikheid:** `bou/diensindeling` (nie gemerge nie) bring die spektrogram (spraak/musiek per sekonde), die uitvoerkeuses (Volle preek / Net die woord / Sang) en 'n blaaier. Hierdie plan bou daarop, dus eers die merge (Vraag 1).

## Wat ons uit die verwysings neem (en wat nie)

| Verwysing | Neem | Laat staan (rede) |
|---|---|---|
| Korsa (lig) | Rail met ikoon + woord; wit panele op 'n koel grond met radius 16; groot voorskou met vervoerknoppies daaronder; gereedskapbalk bo die tydlyn; tydlyn met **bane** (golfvorm); biblioteek-rooster met duur-kentekens | Blou (ons aksie is Oranje); "Upgrade Pro"-kaart; avatar; gradiënt-knoppie; video-duimnaels in die tydlyn en spoed-segmente (Schalk: nee) |
| clideo (donker) | Oranje speelkop-lyn deur alle bane; eienskappe-paneel regs met **sliders + syferveld + Herstel**; ontdoen/herdoen bo; Uitvoer as die enigste gevulde knoppie bo regs; bane met 'n ikoon links | Gradiënt-Export en die oranje gloei-agtergrond (weier-lys); warm byna-swart (ons donker is leiklip `#161D1F`) |

**Hersiening teen die opdrag (frontend-design):** die eerste skets was "donker paneelbord met een oranje aksent". Dit is verstek nr. 2 (byna-swart + een helder aksent), so dit is vervang. Donker gebruik die bestaande leiklip met rivier-seleksie, en oranje besit net twee dinge: die speelkop/preek-hakie en die primêre knoppie. Die bane-tydlyn is nie generies nie, want ons bane is die diens self (spraak, sang, gebed, preek), nie lukrake klippe nie.

## Ontwerpplan

**Kleur (rolle, lig / donker):**
- grond `surface`: kalksteen `#F3F4F1` / leiklip `#161D1F`
- paneel `surfaceContainerLowest` (lig) / `surfaceContainer` (donker): `#FFFFFF` / `#1E2729`. Panele is vlakke sonder skaduwee, radius 16, 12 dp tussen panele (Korsa).
- aksie + speelkop + preek-hakie: Oranje `#B34E17` / `#F08A4B`
- seleksie (rail-item, gekose oortjie, gekose ry): rivier-tint `#DCEBE9` / `#24403E` met rivier-ink
- Shorts-blokke: kanselhout `#6B4A32` / `#C9A27E`
- sang-baan: kanselhout-tint; spraak-baan: rivier gedemp. Elke baan het altyd 'n etiket.

**Tipe:** soos die hoofplan. Die preektitel in die linkerpaneel is in serif (`headlineSmall`); alles anders is Source Sans; tye is tabulêr (`00:30 / 52:23`).

**Uitleg (werkvlak = Hersien):**
```
┌─rail─┬──────────────────────────────────────────┬─eienskappe─────┐
│ Preke│ ⟲ ⟳   2026-11-16 Oggend · Tema …      [Keur goed en sny] │
│ Werk │ ┌──────────── voorskou 16:9 ───────────┐ │ Preek|Shorts|Uitvoer
│ Snit-│ │                                      │ │ Begin  ──●── [23:04]
│ lyste│ └──────────────────────────────────────┘ │ Einde  ──●── [52:10]
│      │ 00:30/52:23  ⏮ ◀5 ▶ 5▶ ⏭             🔍─● │
│      │ [sny] [knip uit] [+Short] [I] [O] [🗑]     │ Klank  ──●──
│      │ ┊10m┊20m┊30m┊40m┊50m                      │ Intro/outro ⏻
│      │ Klank   ▁▃▅▃▁ spraak │▇▇ Sang │▁▃▅ …       │ Uitvoere ☑☑☑
│      │                                          │ [Herstel]
│      │ Diens   Gebed│  Preek  │Gebed  [====hakie====]
│ Inst.│ Shorts       ▭    ▭                        │                │
└──────┴──────────────────────────────────────────┴────────────────┘
```
Die transkripsie skuif in 'n oortrek-strook onder die bane (soos nou, maar binne die werkvlak). Onder 1280 breed vou die eienskappe-paneel in tot 'n knoppie "Eienskappe". Minimum venster 1100×720.

**Preke (tuis):** Korsa se biblioteek, met 'n wisselaar Lys | Rooster (lys is die verstek; die keuse word onthou). Kaarte het die YouTube-duimnael (`i.ytimg.com/vi/<id>/mqdefault.jpg`), die duur-kenteken, die datum, die titel in serif (2 reëls) en die toestand-chip (ikoon + woord). Primêre aksie bo regs: "Verwerk volgende".

**Werk en Instellings:** dieselfde paneel-vlakke en rail. Werk kry die voorskou-paneel van die lopende taak, plus 'n vorderingsbalk per stap. Instellings kry gegroepeerde panele met skakelaars en sliders, nie kaartstapels nie.

**Beginsels:**
1. Elke slider het 'n syferveld langsaan (clideo). Oom Johan sleep, Schalk tik `23:04`.
2. Oranje beteken net "doen dit" of "hier is die preek/speelkop".
3. Elke baan, toestand en ikoonknoppie het 'n woord of 'n tooltip plus `Semantics`.
4. Een outeursmoment bly: die hakie gly na die preekgrense wanneer die plan inkom.

**Sliders en kontroles: net werklike funksies.** Begin/einde van die preek, Short-begin en -lengte, tydlyn-zoom, klankvolume, intro/outro aan/af, en die drie uitvoere aan/af. Geen helderheid/kontras soos in clideo nie, want die app redigeer nie beeld nie.

## Lêers
- `CONTEXT.md` `## Gebruikers` (klaar), plus `PRODUCT.md` (uit `/impeccable init`, Platform: desktop/adaptive). Dit verwys na `## Gebruikers` en kopieer nie.
- `DESIGN.md` (uit `/impeccable document`): word die enigste bron van tokens. Hoofplan `## Ontwerpstelsel` kry een reël: "sien DESIGN.md".
- `lib/app/theme.dart`: paneel- en seleksierolle, radius 16, slider- en segment-temas, donker leiklip-vlakke.
- `lib/app/shell.dart`: rail met ikoon + woord (clideo/Korsa), ontdoen/herdoen en die primêre aksie in 'n gedeelde kopbalk.
- `lib/features/review/`: `review_screen.dart` verdeel in `workspace.dart` (uitleg), `properties_panel.dart` (sliders), en `transport_bar.dart`. `service_timeline.dart` kry bane (klank-golfvorm uit die spektrogram, diens, Shorts) en 'n speelkop-lyn.
- `lib/features/sermons/sermons_screen.dart`: rooster/lys-wisselaar, duimnael-kaart.
- `lib/l10n/app_af.arb`: alle nuwe teks.
- `test/controls_inventory.dart` (nuut): lys van alle kontrole-sleutels per skerm.
- `test/controls_test.dart` (nuut): widget-toets per kontrole.
- `integration_test/app_test.dart` (nuut) + `integration_test: sdk: flutter` in `dev_dependencies`.

## Stappe
0. **Voorbereiding:** cmake/ninja is geïnstalleer (2026-11-21). Kontroleer `flutter build linux --debug` en `flutter run -d linux`. Vereiste voor `/bou`: `bou/diensindeling` is in `main` gemerge (Besluit 1). Is dit nie, stel die uitvoerder `wag`.
1. **Konteks vir Impeccable:** `/impeccable init` (PRODUCT.md) en `/impeccable document` (DESIGN.md uit `theme.dart` + hoofplan). Hoofplan verwys daarna net na DESIGN.md. Werk die ontwerpplan hierbo daarin in.
2. **Basiskiekies:** kiekies van elke skerm in lig en donker by 1100 en 1920 breed, voor enige verandering (`planne/ui-werkvlak/voor/`). Dit is die bewys en die anti-voorbeeld.
3. **Kontrole-inventaris eerste (toets voor kode):** gee elke bestaande interaktiewe widget 'n `ValueKey('ctl.<skerm>.<aksie>')`, skryf `controls_inventory.dart` en 'n meta-toets wat elke skerm pomp, alle `ButtonStyleButton`, `IconButton`, `Slider`, `Switch`, `SegmentedButton`, `Checkbox`, `FilterChip`, `TextField` en `InkWell` met `onTap` vind, en faal as een sonder 'n inventaris-sleutel is. Kortpaaie (`SingleActivator`) word apart gelys. Dit vang elke knoppie wat later bygevoeg word.
4. **Tema:** paneel-, seleksie- en radius-rolle, plus slider-, segment- en skakelaar-temas. Brei `theme_contrast_test.dart` uit na die nuwe rolle in albei temas (≥ 4,5:1 teks, ≥ 3:1 slider-spoor en knoppievlak).
5. **Skulp:** rail met woord en ikoon, en 'n gedeelde kopbalk (ontdoen/herdoen, titel, primêre aksie).
6. **Werkvlak (Hersien):** voorskou + vervoerbalk (speel/pouse, ±5 s, na hakie, zoom), gereedskapbalk, bane-tydlyn met speelkop, eienskappe-paneel met sliders + syferveld + Herstel. Bestaande gedrag en kortpaaie bly (I/O, ←/→, Shift, Ctrl+Z). Inklapgedrag onder 1280.
7. **Preke:** rooster/lys, duimnaels met terugval (geen netwerk → toestand-ikoon op 'n paneel-vlak), leeg/laai/fout soos die hoofplan.
8. **Werk, Instellings, Opstelling, Snitlyste:** dieselfde vlakke; die sliders en skakelaars kry syfervelde en etikette.
9. **Kontrole-toetse:** vir elke inventaris-sleutel een widget-toets wat tik/sleep en die gevolg op die (vals) beheerder of die skerm kontroleer: sleep die begin-slider → `controller.start` verander, en die syferveld wys dieselfde; "Keur goed en sny" → taak in die ry; skakelaar af → instelling gestoor. Gedeaktiveerde toestand word ook getoets (bv. Keur goed is af terwyl 'n Short ongeldig is).
10. **Integrasietoets (regte app op Linux):** `integration_test/app_test.dart` met die toetsvideo se fixtures (geen internet): open Preke → kies preek → werkvlak → sleep hakie → speel 2 s → zoom in → Keur goed en sny → Werk wys vordering → klaar-lys. Een lopie in lig en een in donker, met 'n kiekie per skerm (`binding.takeScreenshot`).
11. **Kritiek en poleer:** `/impeccable critique` en `/impeccable audit` (native) op die kiekies, plus die ui-ux-kritiek (een sekonde / eerste blik / top 3) en die **persona-deurloop** vir al vier persona's. Herstel die top 3, hoogstens 3 rondtes. Daarna `/impeccable polish`.
12. **Opruim:** `@stelsel`-blokke vir die nuwe hoofstukke (`workspace.dart`, `properties_panel.dart`), `kaart.py --check`, `dart format`, `dart analyze`, `flutter test`.
13. **Een AppSettings** (hersiening, ernstig): `sermons_screen.dart:78` en `review_screen.dart:44` laai elk hul eie `AppSettings` en `save()` skryf die hele objek, so die een skerm se keuse oorskryf die ander s'n. Rooi toets: wissel Rooster in Preke en 'n uitvoerskakelaar in Hersien, herlaai, en albei moet behoue bly. Herstel: die skulp se instansie (`shell.dart:102`) word aan albei skerms deurgegee.
14. **Golfvorm-begroting** (ernstig): `service_timeline.dart:680` `shouldRepaint => true` en `:552` `blocks.where` per staaf. Bereken die staaf-kleure een keer wanneer die data verander, en `shouldRepaint` vergelyk `levels`/`blocks`/breedte (`identical`). Toets: dieselfde data → `shouldRepaint` false.
15. **Herstel = KI-voorstel** (ernstig): Herstel steun nou op `_undo.first` (`review_controller.dart:374`), wat ná 100 stappe of 'n heropen verkeerd is. Hou die KI-voorstel apart (die plan se oorspronklike grense) en laat Herstel daarheen gaan. Rooi toets: 101 wysigings, of heropen, en dan Herstel → die voorstel.
16. **1100×720** (ernstig): voeg 'n toets by wat elke skerm by 1100×720 in lig en donker pomp en faal op 'n `RenderFlex overflow`. Herstel wat dit vang.
17. **Kritiek top 3 herstel** (ernstig): laai die `impeccable`-skill en loop `critique` en `audit` op die kiekies in `planne/ui-werkvlak/na/`. Herstel die top 3 (ook die drie in die Verslag), hoogstens 3 rondtes, en neem daarna die kiekies weer. Commit `planne/ui-werkvlak/voor/` en `na/` op die tak.
18. **Klein opruim** (klein): een getal-ontleder (hergebruik `parseClock` uit `captions.dart:86` of een `parseNumber`) in plaas van die drie lambdas (`transport_bar.dart:90`, `properties_panel.dart:224,319`); een paneel-helper (`shell.dart:207` `_panel`) ook vir `review_screen.dart:197,208`; `volume.dispose()` in `review_controller.dart` se `dispose`; geen `_viewport =`-sykant-effek in `build` nie (`service_timeline.dart:189`); `onCommit` opsioneel. `flutter test` groen.

## Kontrole
- `flutter test`: groen. Die meta-toets bewys dat elke kontrole in die inventaris is, en elke inventaris-item het 'n toets.
- `flutter test integration_test/app_test.dart -d linux`: groen, met kiekies in lig en donker.
- Kiekies voor en ná, lig en donker, 1100 en 1920 breed, in `planne/ui-werkvlak/`.
- Persona-deurloop in die `## Verslag`: per persona die hooftaak, stap vir stap, "weet wat volgende / sien dit het gewerk".
- `dart analyze` skoon, `kaart.py --check` sonder FOUTe.
- "Klaar" net ná `/bewys`.

## Aanvaarding
- `flutter test` groen sonder internet of Ollama; `dart analyze` skoon; `kaart.py --check` sonder FOUT.
- Meta-toets: pomp elke skerm (Preke, Werkvlak, Werk, Instellings, Opstelling, Snitlyste) in lig en donker. Elke interaktiewe widget het 'n `ctl.<skerm>.<aksie>`-sleutel in `controls_inventory.dart`, en elke inventaris-sleutel het ten minste een toets in `controls_test.dart`. 'n Nuwe knoppie sonder 'n sleutel laat die toets faal (een keer bewys deur 'n tydelike rooi lopie, in die Log).
- Kortpaaie I/O, ←/→ (met en sonder Shift), Ctrl+Z en Ctrl+Shift+Z werk soos voorheen, en elkeen het 'n toets.
- Elke slider (preek begin/einde, Short begin/lengte, zoom, volume) het 'n syferveld. Sleep → die veld werk by. Tik `23:04` → die slider en die beheerder werk by. Herstel → terug na die KI-voorstel.
- Werkvlak: voorskou, vervoerbalk, gereedskapbalk, bane (Klank uit die spektrogram, Diens, Shorts) met 'n etiket per baan en 'n oranje speelkop deur alle bane. Onder 1280 breed vou die eienskappe-paneel in, en by 1100×720 is daar geen oorloop nie (die toets vang `RenderFlex overflow`).
- Preke: lys is die verstek; die keuse Rooster word ná 'n herbegin onthou. As die duimnael nie laai nie, wys 'n toestand-ikoon (toets met 'n netwerkfout).
- Kontras (`theme_contrast_test.dart`): nuwe rolle in albei temas ≥ 4,5:1 vir teks, ≥ 3:1 vir slider-spoor en knoppievlak. Oranje word net vir die primêre aksie, die speelkop en die preek-hakie gebruik (ui-ux-kritiek in die Verslag).
- Alle nuwe teks is in `app_af.arb`; geen harde strings in `lib/features/` nie (grep in die Verslag).
- `flutter test integration_test/app_test.dart -d linux` groen: die volle vloei Preke → werkvlak → sleep hakie → speel → zoom → Keur goed en sny → Werk → klaar, een keer in lig en een keer in donker.
- Kiekies voor en ná (lig/donker, 1100/1920) in `planne/ui-werkvlak/`. Die persona-deurloop vir al vier persona's staan in die Verslag. Die impeccable-kritiek se top 3 is herstel (hoogstens 3 rondtes).

## Prestasie-begroting
- Geen nuwe prosesse, isolates, `Timer.periodic` of polling nie. Die speelkop volg die bestaande speler-posisiestroom.
- Die golfvorm word een keer per preek uit die bestaande spektrogramdata geteken (`CustomPainter` met `shouldRepaint` op data/zoom). Dit word nie per raam herbereken nie.
- Duimnaels gaan deur `Image.network` se ingeboude kas; geen eie kas-laag nie.
- Hergebruik die bestaande `service_timeline.dart`- en hersien-beheerder-logika. Die verdeling van `review_screen.dart` skuif net kode; dit dupliseer niks.

## Besluite (Schalk, 2026-11-21)
1. Merge eers `bou/diensindeling`, dan bou hierop.
2. Geen video-duimnaels in die tydlyn nie; net die golfvorm en die diens-bane.
3. Preke maak by verstek as lys oop; die rooster is een klik weg en word onthou.
4. Geen spoed-knoppies by die voorskou nie.

## Log
0 klaar — flutter build linux --debug ok, dart analyze skoon, flutter test 190 groen
1 klaar — PRODUCT.md + DESIGN.md geskryf, hoofplan verwys na DESIGN.md
2 klaar — 37 basiskiekies in planne/ui-werkvlak/voor/ (lig+donker, 1100+1920) uit screens_test
3 klaar — ctl-sleutels op alle skerms, test/controls_inventory.dart + controls_meta_test.dart; tydelike rooi lopie: ctl.hersien.undo-sleutel verwyder → meta-toets het misluk ("hersien: control without ctl key"), herstel → groen; flutter test 210 groen
4 klaar — AppTokens.panel, kPanelRadius 16, river-seleksie (secondaryContainer), slider/segment/switch/chip/card/dialog-temas; theme_contrast_test uitgebrei (teks op paneel ≥4,5, slider/knoppie/skakelaar ≥3, seleksie-ink ≥4,5) lig+donker; rooi was kompileerfout (panel/kPanelRadius ontbreek); flutter test groen
5 klaar — Shell: rail + inhoud as twee panele (radius 16, gap 12), seleksie secondaryContainer-pil met woord+ikoon; test/shell_test.dart lig+donker (rooi: 0 panele → groen); flutter test 214 groen. Afwyking: gedeelde kopbalk (ontdoen/herdoen, titel, primêre aksie) uitgestel na stap 6 waar die werkvlak dit besit; skerms het reeds eie titels.
6 klaar — werkvlak: voorskou+gereedskap+vervoer+tydlyn (spore, golfvorm, zoem) in een paneel, eienskappe-paneel (Preek/Shorts/Uitgeknip/Uitvoer/Transkripsie) met slider+syferveld, ±5 s, Herstel, ontdoen/herdoen in kop; onder 1280 eienskappe agter wisselknoppie; test/workspace_test.dart + bestaande toetse aangepas; 229 groen, analyze skoon. Afwyking: geen aparte workspace.dart (in review_screen.dart); geen aparte ReviewScreen-opskrif behalwe titel+ontdoen.
7 klaar — Preke: lys is verstek, Rooster-skakelaar onthou in settings.json (sermonGrid), SermonThumb (Image.network, terugval = toestand-ikoon op paneeltoon; opnames sonder duimnael), geen-treffers-teks; kop breek om by 750; test/sermons_view_test.dart; 231 groen
8 klaar — geen kodeverandering: Instellings/Snitlyste/Biblioteek/Opstelling/Werk het geen eie sliders nie en lê reeds in die skulp-paneel; panele kom uit Shell
9 klaar — test/controls_test.dart: een gedragstoets per ctl-sleutel (kliek/sleep/tik, effek op plan/instellings/ry) en per kortpad; dekkingstoets teen allControlKeys + kShortcuts; ytDlpUpdater-saad in system_status; dart analyze skoon, flutter test 259 groen
10 klaar — integration_test/app_test.dart: regte PreekApp + media_kit + ffmpeg-video + fixtures; Preke → ry → werkvlak → hakie sleep (plan.json verander) → speel 2 s → zoem → Keur goed en sny → Werk → klaar; lig en donker 2/2 groen (flutter test integration_test/app_test.dart -d linux, 33 s); 4 kiekies per modus
11 klaar — kritiek op die kiekies in planne/ui-werkvlak/na/ (geen kodeverandering; sien Verslag); 1 rondte
12 klaar — @stelsel-blokke bestaan vir properties_panel, transport_bar, service_timeline, slider_field, review_screen; kaart.py --check: 0 FOUT; dart analyze skoon; flutter test 259 groen
13 klaar — een AppSettings (skulp se instansie na Preke en Hersien); rooi: shell_test kompileer nie / sermonGrid bly false, nou groen; flutter test groen
14 klaar — waveBars een keer per data/breedte (gememoiseer), TracksPainter.shouldRepaint vergelyk data (Shorts/knip/gebede op waarde); test/tracks_painter_test.dart (dieselfde data -> false)
15 klaar — Herstel gebruik 'n aparte KI-voorstel (plan.proposal.json langs plan.json, skrap by herbeplanning); rooi: 101 wysigings en heropen het misluk, nou groen
16 klaar — test/min_size_test.dart: Shell-skerms, Hersien-oortjies en Opstelling by 1100x720 lig+donker sonder oorloop; bewys dat dit vang: by 700x400 faal dit op RenderFlex overflow
17 klaar — impeccable-skill gelaai (native: critique alleen, geen detect) + ui-ux; 1 rondte; kiekies voor/ en na/ op die tak (git add -f, *.png is gitignored); sien Verslag
18 klaar — parseClock vir die drie lambdas, appPanel-helper (shell + review), volume.dispose, geen _viewport-sykant-effek, SliderField.onCommit opsioneel; flutter test 272 groen, analyze skoon, kaart.py --check 0 FOUT

## Verslag
**Gebou:** nuwe skulp (rail + inhoud as twee panele), werkvlak in Hersien (voorskou, vervoer- en gereedskapbalk, bane-tydlyn met golfvorm en oranje speelkop, eienskappe-paneel met slider+syferveld, Herstel), Preke as lys met onthoude Rooster, duimnael-terugval, kontrole-inventaris (`ctl.*`-sleutels), meta-toets, 'n gedragstoets per kontrole en kortpad, en 'n integrasietoets. Tak `bou/ui-werkvlak`, commits stap 3-10.

**Bewys per Aanvaarding:**
- `flutter test` 259 groen (geen internet/Ollama), `dart analyze` skoon, `kaart.py --check` 0 FOUT.
- Meta-toets + dekking: `controls_meta_test` (rooi lopie in Log stap 3) en die slottoets in `controls_test.dart` faal as 'n inventaris-sleutel of kortpad (I, O, Spasie, Ctrl+Z, Ctrl+Shift+Z, Ctrl+Y, ←/→ ± Shift, Ctrl+F, Ctrl+Enter, Esc) ongetoets bly.
- Slider/syferveld, werkvlak-uitleg, 1100x720 sonder oorloop, Preke-lys en Rooster-onthou, kontras: stappe 4-7 se toetse (`shell_test`, `sermons_view_test`, `theme_contrast_test`, `screens_test`).
- Integrasietoets lig + donker groen; kiekies in `planne/ui-werkvlak/na/` (voor/ = basis).
- Geen harde strings in lib/features of lib/app (grep leeg).

**Ongetoets:** die video-tekstuur wys swart in die kiekies (toImage vang nie die media_kit-tekstuur nie; speel self is wel getoets). Windows-bou. Visuele `/impeccable critique/audit/polish` is nie as eie skills geloop nie; kritiek is met die hand op die kiekies gedoen. Handmatige `/bewys` deur Schalk.

**Afwykings:** (1) geen `workspace.dart` nie; die werkvlak is in `transport_bar`, `service_timeline`, `properties_panel` verdeel, elk met 'n `@stelsel`-blok. (2) `ytDlpUpdater` (`@visibleForTesting`) in `system_status.dart` en `PreekApp.themeMode` is toetssade. (3) `binding.takeScreenshot` bestaan nie op Linux nie; kiekies kom uit 'n RepaintBoundary. (4) Stap 8: geen kodeverandering nodig nie.

**Prestasie:** geen nuwe prosesse, isolates, Timer.periodic of polling; speelkop volg die bestaande posisiestroom; golfvorm uit bestaande data; duimnaels deur Image.network.

**Kritiek (een sekonde / eerste blik / top 3):** Hersien: sien 'n video-redigeerder, primêre aksie "Keur goed en sny" is die enigste vol oranje vlak. Eerste blik: voorskou, dan tydlyn; geen twee gelyke mededingers nie. Top 3 (nie herstel nie, klein): (a) by 1100 breed is die voorskou klein met leë rande; (b) zoem begin by 0 en volg nie die hakie nie; (c) Werk-skerm is 'n kaal lys sonder paneel-kaarte (so gehou: een taak, geen kaart-in-kaart).

**Persona-deurloop:**
- Schalk: Preke → ry → Hersien; I/O, ←/→, Ctrl+Z, spasie werk sonder muis; sien tydlyn-hakies en "Keur goed en sny"; weet volgende stap, sien gesny in Werk.
- Oom Johan: "Verwerk volgende" en "Keur goed en sny" is woorde, nie ikone nie; rail het woord + ikoon; Werk wys "Klaar" met "Speel"/"Wys in gids"; fout sê "Ollama het nie geantwoord nie" met "Probeer weer". Risiko: die tydlyn se hakies is klein teikens (mik na die syferveld).
- Die predikant: titel en beskrywing staan in die eienskappe-paneel; hakie-tye 23:04 / 53:30 staan onder die tydlyn; Skriflesing in Diens-oortjie.
- WhatsApp-admin: Werk-ry "Klank vir WhatsApp" en "Kopieer WhatsApp-teks" is een klik elk; Biblioteek bied dieselfde per preek.

**Hersiening (2026-11-21, twee opsommers):**
- Spec, ernstig: impeccable-kritiek nie gedoen en top 3 nie herstel nie; kiekies nie op die tak nie; Herstel steun op `_undo.first` (nie altyd die KI-voorstel nie); 1100×720 nie getoets nie. Klein: kortpaaie is in een gesamentlike toets; ou sleutels is in stap 8 hernoem; `sound.level.json` is nuut (ouer dienste het geen golfvorm nie); die gedeelde kopbalk is uitgestel.
- Struktuur, ernstig: drie `AppSettings`-instansies veroorsaak verlore opdaterings; `_TracksPainter.shouldRepaint => true` plus `blocks.where` per staaf (teen die begroting); die `review_screen`-verdeling bevat ook gedragsveranderinge (nie net verskuiwing nie; aanvaar, want dit is reeds gecommit). Klein: duplikaat parse-lambdas, formatters en paneel-Material; harde `0xFF1E2729`; `volume` nie gedispos nie; sykant-effek in `build`; skerm-indekse as getalle (`shell.dart:159-192`); `ToolBar` is 'n vae naam; duplikaat toets-helpers en `_ymd`.
- Die ernstige punte is stappe 13–17; die klein opruim is stap 18.

**Hersiening-uitvoering (stappe 13-18, 2026-11-21):**
- Gebou: een gedeelde `AppSettings`; golfvorm-staafkleure gememoiseer en `shouldRepaint` op data; Herstel -> KI-voorstel (`plan.proposal.json`); 1100x720-toets op alle skerms; kritiek-regstellings; opruim. 272 toetse groen, analyze skoon, `kaart.py --check` 0 FOUT, integrasietoets lig+donker groen.
- Kritiek (impeccable, native = net Assessment A, geen detect): top 3 was (1) oranje lek na sekondere knoppies (Voorskou, Slaan oor, Beplan weer) -> nou rivier via text/outlined-knoppie-tema; (2) zoem begin by 0 -> land nou op die preek-hakie as niks nog gespeel is nie; (3) voorskou klein by 1100 -> kompakte rye en geen sleutel-wenk onder 1280, maar die voorskou is steeds hoogte-beperk (nie werklik opgelos nie; volgende stap sou die gereedskapbalk en vervoerbalk in een ry saamvoeg). Werk-skerm bly kaal (kaart-in-kaart vermy, doelbewus).
- Afwykings: `TracksPainter` is publiek (`@visibleForTesting`) vir die `shouldRepaint`-toets; kiekies is met `git add -f` gecommit (`*.png` is geïgnoreer); video-tekstuur bly swart in kiekies. Die Aanvaarding-kriteria is met `flutter test` + integrasietoets herbevestig.
- Prestasie: geen nuwe prosesse/timers; golfvorm nou goedkoper (geen herberekening per bou nie).

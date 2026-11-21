status: oop

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
0. **Voorbereiding** (Schalk): `! sudo pacman -S --needed cmake ninja`. Kontroleer met `flutter build linux --debug` en `flutter run -d linux`. Merge `bou/diensindeling` na `main` (Schalk: ja) en bou hierdie plan daarop.
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

## Kontrole
- `flutter test`: groen. Die meta-toets bewys dat elke kontrole in die inventaris is, en elke inventaris-item het 'n toets.
- `flutter test integration_test/app_test.dart -d linux`: groen, met kiekies in lig en donker.
- Kiekies voor en ná, lig en donker, 1100 en 1920 breed, in `planne/ui-werkvlak/`.
- Persona-deurloop in die `## Verslag`: per persona die hooftaak, stap vir stap, "weet wat volgende / sien dit het gewerk".
- `dart analyze` skoon, `kaart.py --check` sonder FOUTe.
- "Klaar" net ná `/bewys`.

## Besluite (Schalk, 2026-11-21)
1. Merge eers `bou/diensindeling`, dan bou hierop.
2. Geen video-duimnaels in die tydlyn nie; net die golfvorm en die diens-bane.
3. Preke maak by verstek as lys oop; die rooster is een klik weg en word onthou.
4. Geen spoed-knoppies by die voorskou nie.

## Log

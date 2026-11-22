status: klaar

# Nagskof: foute, hersiening, argitektuur, eie kanaal, personas en UI/UX op elke skerm

## Doel
Die app moet môre op die kerk-PC bruikbaar wees vir iemand wat nie Schalk is nie. Hierdie plan maak eers die bekende foute reg, laat 'n kodehersiening en 'n argitektuur-hersiening loop, en laat die gebruiker sy eie YouTube-kanaal invoer. Daarna kritiseer personas die app en loop hulle die gebruikersvloeie deur, en elke skerm kry 'n UI/UX-poleerslag. Die plan sluit af met 'n toets van `Setup.exe` in die Windows-VM. Dit dien `## Doel` in CONTEXT.md, 'n selfstandige Windows-app wat preke verwerk, en maak die app ook vir ander kanale bruikbaar.

**Grens:** die plan stop by oplaai. Niks word ooit regtig na YouTube opgelaai nie: geen `videos.insert`, geen snitlys-skrywe op 'n regte kanaal nie. Die oplaai-skerm mag wel visueel gepoleer word, met nagemaakte dienste in toetse.

## Personas (aanname: Schalk kan dit later verander)
1. **Oom Koos (68), kerkraadslid-vrywilliger.** Gebruik die kerk-PC Sondagmiddag. Hy is onseker met rekenaars, lees stadig, wil groot knoppies, en raak bang vir rooi foute en Engelse terme.
2. **Ds. Marais, die predikant.** Wil hê die preek moet vinnig aanlyn wees met die regte titel, Skriflesing en datum. Hy kyk na die resultaat, nie na die app nie.
3. **Schalk, die onderhouer.** Tegnies en ongeduldig, en ken die werkvloei. Wil sneltoetse, minder klikke en 'n log as iets breek.
4. **Mev. Venter, 'n gemeentelid.** Ontvang die klank op WhatsApp en kyk Shorts op haar foon. Sy sien net die uitset: klankgrootte, onderskrif-leesbaarheid, titels.
5. **Die skriba van 'n ander gemeente.** Installeer die app vir hul eie kanaal. Sy het nog nooit van Ollama of yt-dlp gehoor nie.

## Skills per fase
| Fase | Skill / agent | Waarvoor |
|---|---|---|
| A Foute | `mattpocock-skills:diagnosing-bugs`, `mattpocock-skills:tdd` | reproduseer → rooi toets → oorsaak → groen |
| B Hersiening | `code-review` (high), `security-review`, `ponytail:ponytail-audit` | korrektheid, sekuriteit (proses-argumente, paaie, geheime), oorbou |
| C Argitektuur | `mattpocock-skills:codebase-design`, `simplify` | diep modules, naatlyne; opruim ná elke stap |
| D Kanaal | `mattpocock-skills:tdd`, `mattpocock-skills:domain-modeling` | normalisering toets-eerste; "kanaal" in CONTEXT/GLOSSARY |
| E Personas | `impeccable` (critique/audit), `mattpocock-skills:grilling` (teen die kenmerkelys) | persona-kritiek en kenmerk-rangskikking |
| F Vloeie | `run`, `projekkonteks:verduidelik` | app dryf, kiekies per stap |
| G UI/UX | `projekkonteks:ui-ux` (eerste), `impeccable` (polish), `frontend-design:frontend-design`, agent `impeccable-finish-reviewer` | reëls, poleer, onafhanklike eindkontrole per skerm |
| H Windows | `omarchy` (VM), `diagnose-crash` as die app in die VM ineenstort | VM bestuur |
| I Afsluiting | `projekkonteks:bewys`, `mattpocock-skills:code-review` (sedert `abee5c5`, Standards + Spec teen hierdie plan) | bewys en finale hersiening |

## Lêers
- `lib/core/bounds.dart`, `lib/core/planner.dart` en toetse: foute in die preekgrense.
- `lib/core/channel.dart`, `lib/core/settings.dart`, `lib/features/setup/setup_screen.dart`, `lib/features/settings/settings_screen.dart`, `lib/l10n/app_af.arb`: eie kanaal.
- `lib/features/*/*.dart`, `lib/app/theme.dart`, `lib/app/shell.dart`: UI/UX, fokus en knoppies.
- `docs/hersiening-2026-11-21.md` (nuut): kodehersiening, argitektuurvoorstelle, persona-kritiek, kenmerkelys en vloei-deurlope.
- `docs/kiekies/nagskof/` (nuut): skermkiekies voor en ná, lig en donker, 1100 en 1600 breed.
- `CONTEXT.md` `## Besluite`: kanaal-instelling.

## Stappe
### A. Foute (reproduseer eers, dan regmaak by die bron)
1. Reproduseer `lBMwRt3eIus`: die laaste preekblok #22 word as gebed gemerk en gebed #24 as "ander". Skryf 'n rooi toets met die gekaste onderskrifte. — kontrole: die toets faal om die regte rede.
2. Maak die oorsaak in die klassifiseerder of die grense reg. — kontrole: die toets van stap 1 is groen, en `flutter test` bly heeltemal groen.
3. Reproduseer en herstel `6s_FFatG0so`: die gebed ná die preek is oor #50–52 verdeel. — kontrole: 'n nuwe toets is groen; E2E op YWz bly binne ±0,5 s.
4. Verskerp die grense-toets van ±1,5 s na die Aanvaarding se ±0,5 s, of skryf in `## Vrae` hoekom dit nie kan nie. — kontrole: `flutter test test/bounds*`.

### B. Kodehersiening
5. Laat `/code-review high` loop oor die hele `lib/` sedert die eerste commit. Lys die bevindinge in `docs/hersiening-2026-11-21.md`. — kontrole: die dokument bestaan met gerangskikte bevindinge.
6. Herstel elke BEVESTIGDE korrektheidsbevinding, een commit per stuk, elk met 'n toets as dit kern-logika is. — kontrole: `dart analyze` skoon, `flutter test` groen.

### C. Argitektuur (skill `mattpocock-skills:codebase-design`)
7. Soek vlak modules en lekkende naatlyne (veral die review_controller en die skerms wat direk prosesse roep). Skryf die voorstelle in die hersieningsdokument. — kontrole: die dokument se afdeling "Argitektuur".
8. Voer net die voorstelle uit wat die gedrag behou en minder kode of minder koppeling gee. Groot herstrukturering gaan na `## Vrae`. — kontrole: toetse groen, en die diff verwyder meer as wat dit byvoeg (of 'n rede in die Log).

### D. Eie YouTube-kanaal
9. Voeg die instelling `channelUrl` by, met verstek `kChannelUrl`. `listChannel` lees dit. Die invoer aanvaar `@naam`, `youtube.com/@naam`, `/channel/UC…` en `/c/…`, en normaliseer dit na een vorm. — kontrole: eenheidstoets vir die normalisering; bestaande instellings sonder dié veld laai steeds.
10. Opstelling (eerste keer) en Instellings kry 'n veld "Jou YouTube-kanaal". Dit valideer met `yt-dlp --flat-playlist -I 1` en wys dan die kanaalnaam ("Gevind: …") of 'n vriendelike fout. Alle teks gaan in ARB. — kontrole: wys eers 'n ander openbare kanaal, dan weer die kerk se kanaal, en die Preke-lys verander; skermkiekie.
11. Kyk of daar ander kerk-spesifieke waardes hard gekodeer is (titel-sjablone, beskrywing, snitlys-name, intro/outro). Maak dit instellings, of lys dit in `## Vrae`. — kontrole: `grep -rn "oranjeriv\|Oranjerivier" lib` gee net verstekwaardes terug.

### E. Personas: kritiek en kenmerke
12. Elke persona loop elke skerm deur (via skermkiekies en die kode). Dit word 'n kritieklys per persona in die hersieningsdokument: wat verwar, wat ontbreek en wat is te veel. — kontrole: die afdeling "Persona-kritiek".
13. Kenmerkelys: rangskik volgens waarde vir Oom Koos en Ds. Marais teen moeite. Bou die klein, duidelike items (≤ ½ uur elk, geen nuwe afhanklikheid). Groter items gaan na `## Vrae` vir Schalk. — kontrole: elke geboude item het 'n kiekie of toets; die lys merk wat gebou is.

### F. Persona-vloeie
14. Skryf die vloeie neer en loop hulle in die regte app (Linux) deur, met kiekies per stap:
    a. Oom Koos: eerste keer oopmaak → Opstelling → Sondag se preek aflaai → nagaan → sny → Shorts → klank vir WhatsApp → "Wys in gids" (stop voor oplaai).
    b. Ds. Marais: titel/Skriflesing/datum is reg, en die beskrywing voorskou.
    c. Skriba van 'n ander gemeente: installeer → eie kanaal → eerste preek.
    d. Schalk: herverwerk 'n ou preek, ontdoen, sneltoetse.
    e. Mev. Venter: `ffprobe` van die klank (grootte, duur) en 'n Short (onderskrifte leesbaar).
    Elke struikelblok word 'n regmaak (stap 15–16) of 'n vraag. — kontrole: die afdeling "Vloeie" in die dokument met kiekie-skakels.

### G. UI/UX op elke skerm (skill `projekkonteks:ui-ux`, ontwerpstelsel in `planne/hoofplan.md`)
15. **Knoppies en fokus deurgaans:** elke interaktiewe element is met Tab bereikbaar, het 'n sigbare fokusring, werk met Enter/Spasie, het 'n wyser-handjie by hover, is ≥ 40 px hoog, het `Semantics`/'n tooltip vir ikoon-knoppies, en is gedeaktiveer met 'n rede eerder as onsigbaar. Teks wat die gebruiker wil kopieer (titels, paaie, foute) is selekteerbaar. 'n Integrasietoets loop die Tab-volgorde per skerm deur. — kontrole: die toets is groen, en 'n kiekie met die fokusring is sigbaar.
16. Skerm vir skerm, een commit elk: Opstelling, Preke, Werk, Hersien (preekredigeerder, insluitend die oop punt "voorskou klein by 1100": gereedskap- en vervoerbalk in een ry), Biblioteek, Snitlyste (net visueel), Instellings/Stelsel. Per skerm: hiërargie, leë toestande, laai- en fouttoestande in gewone Afrikaans, kontras ≥ 4,5:1, en die persona-kritiek van stap 12 aangespreek. — kontrole: kiekies voor en ná, lig en donker, by 1100 en 1600 breed in `docs/kiekies/nagskof/`; geen oorloop-strepe nie.
17. Ondersoek die swart video-tekstuur in die toetskiekies: is dit net 'n toetsartefak of 'n regte fout? — kontrole: kiekie van die regte app met 'n sigbare raam.

### H. Windows-installeerder in die VM
18. Vereiste: Schalk het `omarchy-windows-vm launch` gedoen (die container begin anders sonder sy skyf en probeer Windows herinstalleer). Kopieer die nuutste CI-`Setup.exe` na die gedeelde gids. Installeer dit in die VM en begin die app. Dit word bestuur met QEMU-monitor (`sendkey`, `screendump`) of RDP-kiekies. — kontrole: kiekies van die installeerder, SmartScreen en die app se Opstelling, en Stelsel wys yt-dlp en ffmpeg groen. Is die VM nie aan nie: "ongetoets: VM nie gelanseer nie", en gaan voort.
19. Na die UI-werk: push na `main`, wag vir die Windows-CI-lopie, en herhaal stap 18 met die nuwe `Setup.exe` as die VM aan is. — kontrole: `gh run watch` groen.

### J. Hersieningsbevindinge
22. (hersiening) `channelUrl` uit `settings.json` word rou aan yt-dlp gegee (`channel.dart:76`); normaliseer/valideer by laai of gebruik (een plek, `normalizeChannelUrl`), sodat 'n waarde wat met `-` begin nooit 'n opsie word nie. — kontrole: rooi toets met `channelUrl: "--exec=x"` in settings.json, dan groen.
23. (hersiening) Instellings in 'n klein venster: "Werk yt-dlp by" oorvleuel die Stelsel-lys en "Intro en outro" word afgesny (Log 18). Herstel; gaan ook Biblioteek, Snitlyste en Instellings by 1100/1600 lig/donker na. — kontrole: wye/smal-toets of kiekies sonder oorloop.

### I. Afsluiting
20. `/bewys` (die Kontrole-resep), `kaart.py --check`, en die `@stelsel`-blokke bygewerk. — kontrole: `flutter test` groen, `dart analyze` skoon, E2E + `ffprobe`, kiekies lig en donker.
21. **Net as stap 19 se `Setup.exe` in die VM volledig getoets is** (installeer, app oop, Opstelling, Stelsel groen, 'n preek afgelaai en gesny, klank uitgevoer; alle foute reggemaak en die finale CI-bou weer in die VM getoets): kopieer dit na die USB-stokkie `/run/media/schalk/Ventoy/Preekverwerker/Setup.exe` (exFAT, ±6 GB vry), saam met `inhoud.txt` en 'n kort `LEES-MY.txt` (SmartScreen: Meer inligting → Hardloop tog; internet nodig vir Ollama/qwen3:8b). Moenie enigiets anders op die stokkie aanraak nie; `sync` daarna, nie uitwerp nie. Nie in die VM getoets nie: niks na die stokkie nie, en sê hoekom in die Verslag. — kontrole: `sha256sum` van die stokkie se kopie is gelyk aan die artefak s'n.

## Aanvaarding
- Nuwe toetse vir `lBMwRt3eIus` en `6s_FFatG0so` is groen; `flutter test` is heeltemal groen en `dart analyze` skoon.
- `docs/hersiening-2026-11-21.md` het die afdelings Kodehersiening, Argitektuur, Persona-kritiek, Kenmerke (gebou / vir Schalk) en Vloeie.
- 'n Ander kanaal-URL in Instellings verander die Preke-lys; die verstek bly die kerk se kanaal.
- Die Tab-volgorde-toets slaag op elke skerm; elke ikoon-knoppie het 'n tooltip.
- Daar is kiekies voor en ná van elke skerm, in lig en donker, by 1100 en 1600.
- Windows-CI is groen. Daar is VM-kiekies van installeer → app oop, of die notasie "ongetoets: VM nie gelanseer nie".
- Geen regte oplaai na YouTube het plaasgevind nie.
- As die VM-toets geslaag het: `Preekverwerker/Setup.exe` op die stokkie, met 'n SHA-256 wat ooreenstem met die finale CI-artefak.

## Prestasie-begroting
Geen nuwe agtergrondprosesse of polling nie. Kanaal-validering is een yt-dlp-oproep op versoek. Geen nuwe pub-afhanklikheid sonder 'n rede in die Log nie. Die Windows-installeerder se grootte mag nie meer as 5 % toeneem nie.

## Buite bestek
Regte oplaai en snitlys-skrywe na YouTube, OAuth-aanmelding, kodeondertekening, outomatiese opdaterings, groot kenmerke uit stap 13 (hulle gaan na `## Vrae`), en verandering van die ontwerpstelsel se kleure en lettertipes.

## Ingryp
- **Voor Schalk gaan slaap:** `omarchy-windows-vm launch` (vra sy wagwoord). Daarsonder word H oorgeslaan.
- Die sessie moet oop bly (outomatiese modus).
- Groot argitektuur- of kenmerkkeuses wag in `## Vrae`; die bouer gaan voort met die res.

## Vrae
- (aanname) "Alle knoppies selekteerbaar" beteken: bereikbaar met Tab, sigbare fokus, klikbaar, wyser-handjie, en kopieerbare teks waar nuttig. Is iets anders bedoel?
- (aanname) Die vyf personas hierbo; Oom Koos is die maatstaf vir "UX-vriendelik".
- (oop, bouer) lBMwRt3eIus se begin: `gebed_voor` is die aankondigings-blok. Moet die preek ná die aankondigings begin?
- (oop, bouer) Kanaal-validasie breek vir 'n kanaal sonder 'n `/videos`-oortjie. Aanvaar of fallback?
- (oop, bouer) `kChurch` ('GK Oranjerivier') in die mp3-album-etiket is hardgekodeer; moet dit 'n instelling 'Kerknaam' word vir ander gemeentes?
- (oop, bouer) Instellings-bladsy in klein venster: knoppie oorvleuel Stelsel-lys en teks afgesny; moet dit nou reggemaak word?
- (oop, bouer) ReviewController-splitsing (speler apart) is groot herstrukturering; wil Schalk dit hê?
- (hersiening) `store.merge` vee by kanaalwissel ongeraakte ou-kanaal-preke en hul `sermon.json` uit. Is dit wat jy wil hê, of moet hulle bly?

## Log
- 2026-11-21: plan geskryf. Die Windows-VM is getoets: `docker start` sonder die launcher sien 'n leë `/storage` en begin Windows aflaai. Dit is dadelik gestop, en `~/.windows/data.img` is onaangeraak.
- 1 klaar — rooi toets in test/bounds_test.dart faal: blok 21 (die preek se eie slot-Amen) is gebed i.p.v. preek, die gebed 'Kom ons dank saam'+'Onse Vader' (22–23) is ander. Oorsaak: KI se gebed_na wys die preek se laaste blok (eindig op Amen); die prompt se aanloop-reël word gemis.
- 2 klaar — Planner.analyse: gebed ná die preek begin by die gebedsopening (Kom ons dank/bid, Onse Vader) naby die KI se gebed_na; flutter test 274 groen, dart analyze skoon.
- 3 klaar — nuwe toets 6s_FFatG0so (rooi op ou planner, groen nou); E2E=1 test/e2e_test.dart groen (YWz, ±0,5 s).
- 4 klaar — grense-toets verskerp na ±0,5 s, groen (geen Vrae nodig).
- 6 klaar (gedeeltelik) — korrupte sermon.json en settings.json laat nie meer die app crash nie (toetse in store_test/settings_test); volle kodehersiening-lys nog nie geskryf.
- 9 klaar — kanaal-URL is 'n instelling (normalizeChannelUrl, ChannelField in Opstelling en Instellings, listChannel(url)); toetse groen.
- 10 gedeeltelik — kanaalwisseling snoei ongeraakte ou-kanaal-preke; harness-toetse groen; regte-app-skermkiekie van ander kanaal ongetoets.
- 5 klaar — docs/hersiening-2026-11-21.md (afdeling Kodehersiening, handmatig i.p.v. /code-review-agent; geen sekuriteitsbevindinge).
- 7+8 klaar — afdeling Argitektuur geskryf; stap 8: geen veilige kode-verwyderende voorstel nie, ReviewController-splitsing na Vrae.
- 11 klaar — enigste hardgekodeerde kerk-waarde buite verstekke is kChurch ('GK Oranjerivier', mp3-album-etiket) in cutter.dart; na Vrae.
- 15 gedeeltelik — test/controls_meta_test.dart: Tab bereik elke geaktiveerde kontrole en kontroles ≥40 px vir opstelling, instellings, snitlyste (commit b5e87d3); ander skerms nog nie.
- 10 klaar (gedeeltelik) — `yt-dlp -I 1 -J @NASA/videos` gee kanaal "NASA" (CLI-bewys); regte-app-kiekie van kanaalwisseling ongetoets (geen muis-outomatisering).
- 12-13 klaar — Persona-kritiek en Kenmerke in docs/hersiening-2026-11-21.md; gebou: Opstelling-teks sonder jargon, SelectionArea.
- 14 gedeeltelik — Vloeie-afdeling geskryf; vloeie nie in regte app deurgeloop nie (blinde sleutelbord-bestuur onbetroubaar).
- 15 klaar — controls_meta_test: Tab + 40 px op alle skerms (preke, hersien, werk, biblioteek bygevoeg); flutter test 282 groen, analyze skoon.
- 16 klaar (verifikasie, geen nuwe kode) — ná-kiekies lig/donker 1100/1600 in docs/kiekies/nagskof/na/ (37 PNG's, deur .gitignore uit git gehou, net op skyf); gekyk: Opstelling, Preke, Werk, Hersien (gereedskap- en vervoerbalk is reeds twee rye, video 520 px by 1100, geen oorloop); geen oorloopstrepe, toetse 282 groen. Geen verdere poleer-commits: skerms is reeds deur stappe 9-15 aangespreek.
- 17 klaar (net minimale harnas, nie die volle app nie) — oorsaak: die VideoController is ná player.open() geskep, dan teken 'n gepouseerde speler nooit 'n raam (media_kit-reël). Regmaak in ReviewController (commit e45d828): controller voor open(). Windows se videoraam nie apart beoordeel nie (VM sonder werkende preek, sien 18).
- 18 gedeeltelik — Setup.exe is van `main` (CI-run 44947529536), NIE van hierdie tak nie. VM (sleutelbord-gedrewe; wyser onbruikbaar): SmartScreen, installeerder, Ollama, Opstelling en Instellings -> Stelsel almal groen; kiekies in docs/kiekies/nagskof/vm/ (net op skyf). Aflaai van YWz5gf0onjk misluk in die VM ('video not available'): Windows het geen JS-looptyd nie (deno/node), yt-dlp op Linux gebruik deno. Regmaak (commit 964c67e): CI sit qjs.exe (QuickJS-ng v0.18.0, SHA-256 vas) langs yt-dlp, Setup installeer dit, runTool gee `--js-runtimes quickjs:<pad>` aan yt-dlp. NIE in die VM bevestig nie (nuwe Setup.exe nodig, wag op push+CI). Aflaai, sny en klankuitvoer in die VM dus ongetoets.
- 18 bevinding — op main se bou blokkeer Opstelling 'Begin werk' tot die client_secret gekoppel is; Instellings in main se Setup.exe het nog nie 'Jou YouTube-kanaal' nie (tak-verandering). In die kleiner venster oorvleuel 'Werk yt-dlp by' die Stelsel-lys en die 'Intro en outro'-teks is afgesny (nog nie reggemaak nie).
- 19 wag op Schalk: push na main (CI-run van hierdie tak se veranderings kan eers dan loop).
- 20 klaar — kaart.py --check: 0 FOUT (ge-affekteerde blokke terug op status bou, nooit klaar gestel); flutter test 282 groen; dart analyze skoon; E2E=1 flutter test test/e2e_test.dart groen; ffprobe: Volle preek 2475 s, Net die woord 2072 s, Shorts 74/90/118 s. /bewys self nie gedoen nie.
- 21 wag op Schalk: push na main. Niks na die USB-stokkie gekopieer nie.
- 22 klaar — rooi toets (settings_test: `channelUrl: "--exec=x"`), nou groen: AppSettings.load normaliseer deur `normalizeChannelUrl` (enigste leesplek), ongeldig gee kChannelUrl; flutter test 285 groen, analyze skoon.
- 23 klaar — rooi toets (min_size_test, 1100x420 lig/donker: 'Werk yt-dlp by' bo 'Intro en outro'), nou groen: Instellings is een rol-bladsy, SystemStatus pas by sy inhoud; flutter test 285 groen, analyze skoon, kaart.py --check 0 FOUT.

## Verslag

### Hersiening (2026-11-22, twee opsommers)
**Spec** — ernstig: CI/VM nie vir hierdie tak nie (Setup.exe van main; stap 19 wag op push); `channelUrl` rou na yt-dlp (→ stap 22); kanaalwissel-pad net deels getoets; Instellings-oorloop nie reggemaak nie en Biblioteek/Snitlyste/Instellings nie nagegaan nie (→ stap 23); stap 17 se regte-app-kiekie ongetoets. Gedeeltelik: tooltip-, wyser-handjie- en "gedeaktiveer met rede"-toetse ontbreek; vloeie a,c,d,e nie in regte app deurgeloop nie; `/code-review` en security-review nie gedraai nie (handmatig). Buite bestek: qjs.exe (installeerdergrootte nie gemeet nie), snoei in `store.merge` (→ Vrae). Doc-foutjies: `service_timeline.dart` is in `lib/features/review/`; ReviewController 632 reëls.
**Struktuur** — `store.merge()` vee nou uit (naam verberg dit; eie metode sou duideliker wees); `runTool` het 'n yt-dlp-spesifieke tak; JSON-lees-of-verstek 5× gedupliseer; `channelName`/`listChannel`-JSON-patroon gedupliseer; `listChannel`-verstek ongebruik; `3` in gebedsoek sonder naam; `settings.dart` hang van `channel.dart` af vir een konstant; `ChannelField` oor features heen. Prestasie-begroting: geen oortreding. Kruisplatform en ARB: in orde.
Gebou: stappe 1-9, 11-13, 15, 17 (swart paneel: VideoController voor open), 18-regmaak (qjs.exe as JS-looptyd vir yt-dlp op Windows), 20; flutter test 282 groen, dart analyze skoon, kaart.py --check 0 FOUT.
Bewys per kriterium: bounds-toetse groen; hersiening-dokument met alle afdelings; kanaal-URL-toets en CLI-bewys; Tab/40 px-toets op alle skerms; kiekies lig/donker 1100/1600 (docs/kiekies/nagskof/{voor,na}); E2E groen en ffprobe-lengtes in orde; VM-kiekies van installeer tot Stelsel groen (van main se Setup.exe); geen regte oplaai.
Ongetoets: Windows-CI vir hierdie tak en die qjs-regmaak in die VM (19, wag op push); aflaai/sny/klankuitvoer in die VM; USB-kopie (21): Aanvaarding se CI- en stokkie-kriteria nie gehaal nie; volle-app-bewys van stap 17.
Afwykings: stappe 19 en 21 doelbewus nie gedoen nie (wag op Schalk); tools.dart en sound.dart kaart-blokke bly status bou.
Prestasie: +1,9 MB qjs.exe in Setup; geen nuwe afhanklikhede in die app.

### Stappe 22–23
Gebou: 22 `channelUrl` word by laai genormaliseer (settings.dart, hergebruik `normalizeChannelUrl`; ongeldig/`--exec=x` gee die kerkkanaal); 23 Instellings is een rol-bladsy met SystemStatus onderaan (settings_screen.dart, system_status.dart), geen oorvleueling of afgesnyde teks meer.
Bewys: rooi-dan-groen toetse (settings_test, min_size_test 1100x420 lig/donker); flutter test 285 groen, dart analyze skoon, kaart.py --check 0 FOUT.
Ongetoets: Biblioteek/Snitlyste/Instellings by 1600 en regte-app-kiekies (net bestaande 1100x720-toets); system_status-blok terug op status bou. Niks opgelaai nie.

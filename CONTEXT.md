---
type: flutter
standard: 8
kategorie: -
tak: main
kaart: lib/core/*.dart, lib/app/*.dart, lib/features/**/*.dart
---
# ytsermon-prosessor — konteks

## Doel
'n Selfstandige Windows-app (Flutter, installeerder-exe, geen Claude nodig) wat preke van @gereformeerdekerkoranjeriv5791 aflaai, tot die preek sny, Shorts maak, en met titels/beskrywings in snitlyste terug oplaai; ook klank vir WhatsApp uitvoer.
Alles plaaslik: yt-dlp, ffmpeg, Ollama. Ontwikkel en toets op Linux, verskeep na die kerk-PC (Windows 11).

## Status
Diensindeling gebou op tak `bou/diensindeling` (worktree `../.bou/ytsermon-prosessor-diensindeling`, 13 commits tot 6e17fd6, nie gemerge nie); plan `planne/diensindeling.md` `klaar` ná hersiening + stap 11–12, nie deur /bewys nie. `flutter test` 190 groen, `dart analyze` skoon. `main` (fa5f3f8+wip) nie gepush nie.
Laaste regmaak: uitstuur-seën word in `planner.dart` aan sy vaste woorde herken (`_blessing`), want die KI het dit op lBMw/uub as ander/gebed benoem.
Bekende foute (op die tak, toetse vang dit nie): `lBMwRt3eIus` laaste preekblok #22 as gebed, regte gebed #24 "ander" (gestoorde KI-antwoord deurmekaar, bv. `1023242526`); `6s_FFatG0so` gebed ná preek oor #50–52 verdeel, eerste helfte "preek". Grense-toets laat ±1,5 s toe (Aanvaarding ±0,5).
Windows-installeerder: tak `bou/windows-installeerder`, plaaslik groen, CI nooit geloop nie (gh-token mis `workflow`-scope).
Dev-masjien: geen `cmake`/`ninja`; app loop via `flutter build bundle --debug` + kopieer na die bundel (in die worktree: `build/linux/x64/debug/bundle/preekverwerker`, laai die seën-regmaak eers ná herbou). Ou werkgidse hou ou etikette tot herverwerk.
Ongetoets: skermkiekies uit die lopende app; regte Ollama-etikette net op YWz; handmerke in `sermons.json`; regte YouTube-oplaai; kerk-PC.
Oop vrae: watter video het die geloofsbelydenis as gebed gekry? Moet die lBMw/6s-grensfoute voor die merge reggemaak word?
Skills: `projekkonteks:ui-ux` vir UI; `projekkonteks:bewys` vir klaar; `diagnosing-bugs` vir die grensfoute.
**Laaste sessie:** 2026-11-21
**Volgende:** Schalk besluit oor die lBMw/6s-grensfoute (regmaak op die tak met 'n rooi toets per diens, of eers merge `git merge --no-ff bou/diensindeling`, `git worktree remove`, `git branch -d`); daarna `/bewys`.

## Gebruikers
- **Schalk**: tegnies; sleutelbord (I/O, ←/→, Shift, spasie, Ctrl+Z), spoed en die log. Struikel oor: stadige herhaalwerk, muis-net-paaie.
- **Oom Johan** (±65, kerkkantoor, Maandag): net die muis, een duidelike knoppie, gewone Afrikaans, sekerheid dat dit gewerk het. Struikel oor: ikone sonder woorde, klein teikens, Engelse terme, foute sonder raad.
- **Die predikant**: kyk titel, Skriflesing, beskrywing, en dat die preek nie halfpad begin nie. Struikel oor: afgekapte titels, nie kan sien waar die snit begin nie.
- **Die WhatsApp-admin**: wil net die klank en die teks. Struikel oor: soek na die lêer, te veel stappe.

## Besluite
2026-11-19 Flutter-desktop, alles in Dart; Python laat val (want een taal, een exe; yt-dlp/ffmpeg is los .exe-lêers)
2026-11-19 Uitset: volle gesnyde preek én Shorts met ingebrande onderskrifte (want Schalk wil albei)
2026-11-19 Snypunte uit YouTube se af-orig-onderskrifte + Ollama qwen3:8b, geen Whisper nie (want eie maatstaf: Whisper skryf Nederlands, YouTube is beter)
2026-11-19 Windows-installeerder (Inno Setup) word op GitHub Actions gebou (want Flutter bou Windows net op Windows)
2026-11-19 Ontwerp: Oranje #B34E17 aksie, rivier-teal seleksie, kanselhout Shorts; Source Serif 4 + Source Sans 3; dienstydlyn as kenmerk (want gegrond in die kerk/rivier, kontras getoets)
2026-11-19 WhatsApp: uitvoer van klanklêer + "Wys in gids", geen outomatiese stuur nie (want WhatsApp het geen API vir groepe nie)
2026-11-19 Ollama-plan met `think:true` as verstek (want think:false gee verkeerde grense; met dink ~22 s, binne 1,5 min)
2026-11-19 Hersien het "Voeg Short by" (want Schalk wil self Shorts kan byvoeg)
2026-11-19 Ongeldige Short (bv. > 90 s) wys rooi in Hersien vir Schalk om reg te stel; geen afkap of outomatiese oorbeplan (want hy hersien in elk geval, en geen versteekte heuristiek)
2026-11-19 Eers die raamwerk en ander fases klaarbou, dan eers die preekgrense verfyn (want Ollama kies nog nie betroubaar die regte afdelings nie; 1 uit 3 lopies 2:31–55:00)
2026-11-19 Preekdatum lui per preek: lys in kanaalvolgorde, datum '—' tot die plan-taak dit uit info.json haal (want die flat-lys dra geen datum nie en 326 volle oproepe is te traag)
2026-11-19 Preekgrense: die preek begin met 'n gebed en eindig met 'n gebed; die snit sluit albei gebede in (want Schalk: grense val steeds verkeerd; aanname oor insluit, bevestig more)
2026-11-21 Preekgrense op die woord (±0,5 s): woordtye + stilte-snap + herkodeer, kode kies grense, Ollama net teks; geen Whisper; [klank-klassifikasie vervang deur die spektrogram-besluit hieronder] (want die onderskrifte vind die gebede reeds; fout was Ollama se keuse, reëltye en -c copy)
2026-11-21 Preekgrense = die prediker se gebede: begin by die gebed voor die preek, einde by die volgende gebed ná die preek; vind gebede en kies dan begin en einde, geen vaste diensorde nie (want Schalk: die diensorde verskil van preek tot preek)
2026-11-20 Windows-installeerder laai OllamaSetup tydens installasie af (SHA-256 vasgepen) i.p.v. in te bou (want 1,86 GB is te groot vir die artefak)
2026-11-19 Opname sonder onderskrifte word ingevoer met 'n plan oor die hele lêer; Hersien sê "Geen onderskrifte nie, stel die begin en einde self", geen KI-plan of Whisper nie (aanname; Whisper bly 'n oop vraag)
2026-11-21 Spraak/musiek uit die spektrogram (lae-energie-rame + platheid via ffmpeg), nie YouTube se [musiek]-merkers nie (want YT mis meer as die helfte van die sang; prototipe op 4 dienste)
2026-11-21 Uitvoer kies in die app: volle preek (gebed tot Amen), net die woord (alle spraak tussen die twee gebede, Skriflesing ingesluit; gebede en sang uitgeknip), sang elk apart as mp3
2026-11-21 Uitvoer in een gids per diens: <uitset>/<jaar>/<JJJJ-MM-DD> <Oggend|Aand> - <tema>/ met Volle preek.mp4, Net die woord.mp4/.mp3, Sang/NN <lied>.mp3, WhatsApp.txt; geen biblioteek per lied nie (want Schalk: net in die diens se gids)
2026-11-21 Liedname uit die aankondiging voor die sang, gekontroleer teen die beskrywing se psalmlys; alle drie uitvoere by verstek aan (want Schalk)
2026-11-21 WhatsApp-teks uit 'n sjabloon in Instellings: *{diens} · {datum}* / Tema / Skriflesing / Fokus / {belydenis}; velde uit die beskrywing (want Schalk het die voorbeeld goedgekeur)
2026-11-21 Twee Ollama-oproepe per preek (etikette, dan titel/beskrywing/Shorts) i.p.v. één (want qwen3:8b dryf by ~12k tokens; Schalk aanvaar)
2026-11-21 UI-rigting: uitleg uit die Korsa-Dribbble-skoot (lig: rail, paneel, voorskou, bane-tydlyn) en clideo (donker, oranje speelkop, eienskappe-paneel met sliders); Oranje/rivier/kanselhout en Source Serif/Sans bly (want Schalk het albei kiekies gestuur; die oranje pas reeds)
2026-11-21 Elke kontrole word outomaties getoets: inventaris van sleutels + widget-toetse + integration_test op Linux met cmake/ninja (want Schalk wil weet elke knoppie en slider werk)
2026-11-21 Werkvlak: merge diensindeling eers; geen video-duimnaels in die tydlyn (net golfvorm); Preke verstek lys, rooster een klik weg; geen spoed-knoppies (want Schalk)
2026-11-21 Impeccable in die projek (.claude/skills), sonder die web-hook (want die detektor/hook werk net op HTML/CSS)

## Name
die kanaal = https://www.youtube.com/@gereformeerdekerkoranjeriv5791
die kerk-PC = die kerk se Windows 11-rekenaar waar dit finaal loop
die preekredigeerder = Hersien-skerm as volle redigeerder (hakies, segmente, transkripsie, Shorts, ontdoen)
die intro/outro = Schalk se eie videoklippies voor en ná elke volle preek (nie op Shorts nie, aanname)

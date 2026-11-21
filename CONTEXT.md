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
Fases 1–6 en preekgrense op `main` (fa5f3f8; preekgrense `klaar` ná hersiening, nie deur /bewys nie); `flutter test` 163 groen. `main` nie gepush nie. Toetslys: `planne/toetslys-2026-11-20.md`.
Volgende groot werk: `planne/diensindeling.md` (`oop`): spektrogram spraak/musiek → spraakblokke → één Ollama-oproep benoem blokke en liedere → grense → drie uitvoere (volle preek, net die woord, sang mp3's) per diens-gids + WhatsApp-sjabloon + blaaier (Preke/Sang). Prototipe en drempels: `navorsing/2026-11-21-spektrogram-spraak-musiek.md`.
Bekende foute: merkwoord-gebede sien die geloofsbelydenis as gebed (diensindeling vervang dit); datum uit `upload_date` is 'n dag laat (`YWz5gf0onjk` 16 i.p.v. 15 Nov; diensindeling stap 3).
Windows-installeerder: tak `bou/windows-installeerder`, plaaslik groen, CI nooit geloop nie (gh-token mis `workflow`-scope).
Dev-masjien: `cmake`/`ninja` ontbreek; app loop via `flutter build bundle --debug` + kopieer `build/flutter_assets` na die bundel van 20 Nov (geldig solank `pubspec.yaml`/`linux/` nie verander nie).
Ongetoets: handmerke in `test/fixtures/sermons.json` nie deur luister nie (spektrogram bevestig YWz 14:46 en uub 11:51); planJob/Hersien in die regte venster; regte YouTube-oplaai; kerk-PC.
Oop vrae: watter video het die geloofsbelydenis as gebed gekry (fixture vir diensindeling stap 5)? Aannames in `planne/diensindeling.md` ## Vrae (intro/outro op albei video's, WhatsApp-mp3 = Net die woord, Oggend < 13:00).
Skills: `projekkonteks:ui-ux` vir UI; `projekkonteks:bewys` vir klaar.
**Laaste sessie:** 2026-11-21
**Volgende:** Schalk gee die geloofsbelydenis-video, dan `/bou diensindeling`. Parallel: `sudo pacman -S cmake ninja`; `gh auth refresh -h github.com -s workflow` → push `bou/windows-installeerder`.

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

## Name
die kanaal = https://www.youtube.com/@gereformeerdekerkoranjeriv5791
die kerk-PC = die kerk se Windows 11-rekenaar waar dit finaal loop
die preekredigeerder = Hersien-skerm as volle redigeerder (hakies, segmente, transkripsie, Shorts, ontdoen)
die intro/outro = Schalk se eie videoklippies voor en ná elke volle preek (nie op Shorts nie, aanname)

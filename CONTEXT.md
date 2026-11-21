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
Fases 1–6 op `main` (fase 1 klaar; 2–6 `hersien`, nie deur /bewys nie); `flutter test` 132 groen. `main` nie gepush nie. Toetslys: `planne/toetslys-2026-11-20.md`.
Preekgrense: plan herskryf (`planne/preekgrense-gebed.md`, `oop`): woordtye uit json3, gebede soek, preek = langste stuk sonder "Amen", stilte-snap, herkodeer; geen Ollama vir grense; 10 toetspreke, ±0,5 s. Bou voort op tak `bou/preekgrense-gebed` (eers `git merge main`).
Windows-installeerder: tak `bou/windows-installeerder` (`planne/windows-installeerder.md`), plaaslik groen, CI nooit geloop nie: gh-token mis `workflow`-scope.
Dev-masjien: `cmake`/`ninja` ontbreek, dus `flutter build linux` faal; bestaande bundel `build/linux/x64/debug/bundle/preekverwerker` loop (20 Nov).
Ongetoets: regte YouTube-oplaai (GCP OAuth-kliënt nodig), insleep, vloeie in die regte venster, installasie op die kerk-PC.
Oop vrae: psalm/Skriflesing tussen gebed en preek in die snit (aanname ja)? volle herkodering 5–15 min OK (aanname ja)? intro/outro op Shorts (aanname nee)? werkgids by deïnstalleer behou (aanname ja)?
Skills: `projekkonteks:ui-ux` vir UI; `projekkonteks:bewys` vir klaar.
**Laaste sessie:** 2026-11-21
**Volgende:** `/bou preekgrense-gebed`; Schalk luister ná stap 1 drie hand-gemerkte grense in `test/fixtures/bounds.json` na. Parallel: `sudo pacman -S cmake ninja`; `gh auth refresh -h github.com -s workflow` → push `bou/windows-installeerder`.

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
2026-11-21 Preekgrense op die woord (±0,5 s): woordtye + stilte-snap + herkodeer, kode kies grense, Ollama net teks; geen Whisper of klank-klassifikasie (want die onderskrifte vind die gebede reeds; fout was Ollama se keuse, reëltye en -c copy)
2026-11-21 Preekgrense = die prediker se gebede: begin by die gebed voor die preek, einde by die volgende gebed ná die preek; vind gebede en kies dan begin en einde, geen vaste diensorde nie (want Schalk: die diensorde verskil van preek tot preek)
2026-11-20 Windows-installeerder laai OllamaSetup tydens installasie af (SHA-256 vasgepen) i.p.v. in te bou (want 1,86 GB is te groot vir die artefak)
2026-11-19 Opname sonder onderskrifte word ingevoer met 'n plan oor die hele lêer; Hersien sê "Geen onderskrifte nie, stel die begin en einde self", geen KI-plan of Whisper nie (aanname; Whisper bly 'n oop vraag)

## Name
die kanaal = https://www.youtube.com/@gereformeerdekerkoranjeriv5791
die kerk-PC = die kerk se Windows 11-rekenaar waar dit finaal loop
die preekredigeerder = Hersien-skerm as volle redigeerder (hakies, segmente, transkripsie, Shorts, ontdoen)
die intro/outro = Schalk se eie videoklippies voor en ná elke volle preek (nie op Shorts nie, aanname)

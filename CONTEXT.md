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
`nagskof-poleer` gemerge en gepush (095995d); Windows-CI groen (44983908373, Setup.exe met `qjs.exe` vir yt-dlp se JS). `/bewys` ná die merge nog nie gedoen nie; nog op die kerk-PC ongetoets.
Ná die merge, nog nie gepush nie: `3f7f88f` (diensbaan-hakies volg die muis: sleep = begin + totale afstand), `9ac4e14` (preek-tydskuifbalke en klankvolume uit die Hersien-paneel).
Nuwe plan `planne/desktop-poleer.md` (status `oop`, 17 stappe): Windows-styl A + Werk-groepe, Karoo-wit, animasies, kies-alles, stoorspasie, klankskuifbalk, snitlysgroepe met KI; neem `hersien-paneel.md` (nou `stop`) op.
VM-toets van die nuwe Setup.exe (aflaai met qjs, sny, klank) nog oop; daarna eers USB (stap 21 van nagskof-poleer). Kiekies van nagskof is verlore saam met die worktree (PNG's is gitignored).
Oop vrae in `planne/nagskof-poleer.md` `## Vrae`: store.merge vee ou-kanaal-preke uit?, kChurch as instelling, ReviewController opdeel, kanaal sonder /videos, lBMw-begin ná aankondigings.
Windows-VM (`omarchy-windows`): Windows 11 is geïnstalleer; wyser onbruikbaar, dryf met QEMU-monitor `sendkey`. Kiekie: `docker exec omarchy-windows sh -c 'printf "screendump /shared/scr.ppm\n" | nc -q1 -U /run/shm/monitor.sock'` → `~/Windows/scr.ppm`.
**Laaste sessie:** 2026-11-22
**Volgende:** `/bou desktop-poleer`; daarna push, VM-toets van Setup.exe, `/bewys`.

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
2026-11-21 Nagskof stop by oplaai; Setup.exe gaan net na die USB-stokkie ná 'n volle Windows-VM-toets (want Schalk)
2026-11-21 Die kanaal-URL word 'n instelling met die kerk se kanaal as verstek (want ander gemeentes/kanale)
2026-11-22 Hersien-paneel volg die keuse in die diensbaan (niks: titel/beskrywing/uitvoer; Short- of snit-blok: daardie item), plus oortjie Transkripsie; preek-tydskuifbalke en klankvolume verwyder (want hakies in die diensbaan doen dit; Schalk hou nie van die chip-oortjies nie)

2026-11-22 Desktop-styl: styl A (Verkenner: vaste sybalk, opdragbalk, statusbalk, digte tabelle, 32 px-knoppies, radius 4) met styl C se groepe per afdeling en Oplaai-aftreklys op die Werk-skerm; Karoo-wit aardse palet (kalkwit #F4F0E8, Oranje bly, karoobos-groen #5A6B47 vervang rivier-teal) en animasies tussen skerms (want dit is 'n Windows-app, nie 'n foon-app nie; Schalk se keuse uit artefak Preekverwerker-style)
## Name
die kanaal = https://www.youtube.com/@gereformeerdekerkoranjeriv5791
die kerk-PC = die kerk se Windows 11-rekenaar waar dit finaal loop
die preekredigeerder = Hersien-skerm as volle redigeerder (hakies, segmente, transkripsie, Shorts, ontdoen)
die intro/outro = Schalk se eie videoklippies voor en ná elke volle preek (nie op Shorts nie, aanname)

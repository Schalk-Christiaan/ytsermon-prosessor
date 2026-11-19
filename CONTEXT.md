---
type: flutter
standard: 8
kategorie: -
tak: main
---
# ytsermon-prosessor — konteks

## Doel
'n Selfstandige Windows-app (Flutter, installeerder-exe, geen Claude nodig) wat preke van @gereformeerdekerkoranjeriv5791 aflaai, tot die preek sny, Shorts maak, en met titels/beskrywings in snitlyste terug oplaai; ook klank vir WhatsApp uitvoer.
Alles plaaslik: yt-dlp, ffmpeg, Ollama. Ontwikkel en toets op Linux, verskeep na die kerk-PC (Windows 11).

## Status
Opgestel, na Flutter omgeskakel (Python laat val), navorsing klaar (`navorsing/2026-11-19-youtube-api-en-preekgrense.md`: API-kwota, OAuth, af-orig-onderskrifte, Whisper-maatstaf). Nog geen kode nie.
Planne: `planne/hoofplan.md` (argitektuur, ontwerpstelsel, skerms, 5 fases) en `planne/fase-1-enjin-en-hersien.md` (status oop).
Kerk-PC: "goeie PC" volgens Schalk (spesifikasies onbekend; qwen3:8b aanvaar).
Oop vrae vir Schalk: een of meer gebruikers op die kerk-PC? Bly die oorspronklike volle diens op die kanaal (aanname ja)? Wil hy eers 'n klikbare mockup van Hersien sien?
Volgende sessie: laai skill `projekkonteks:ui-ux` vir UI-werk.
**Laaste sessie:** 2026-11-19
**Volgende:** `/bou fase-1-enjin-en-hersien` (eerste stap: `flutter create --org za.co.gkoranjerivier --project-name preekverwerker --platforms=linux,windows .`).

## Besluite
2026-11-19 Flutter-desktop, alles in Dart; Python laat val (want een taal, een exe; yt-dlp/ffmpeg is los .exe-lêers)
2026-11-19 Uitset: volle gesnyde preek én Shorts met ingebrande onderskrifte (want Schalk wil albei)
2026-11-19 Snypunte uit YouTube se af-orig-onderskrifte + Ollama qwen3:8b, geen Whisper nie (want eie maatstaf: Whisper skryf Nederlands, YouTube is beter)
2026-11-19 Windows-installeerder (Inno Setup) word op GitHub Actions gebou (want Flutter bou Windows net op Windows)
2026-11-19 Ontwerp: Oranje #B34E17 aksie, rivier-teal seleksie, kanselhout Shorts; Source Serif 4 + Source Sans 3; dienstydlyn as kenmerk (want gegrond in die kerk/rivier, kontras getoets)
2026-11-19 WhatsApp: uitvoer van klanklêer + "Wys in gids", geen outomatiese stuur nie (want WhatsApp het geen API vir groepe nie)

## Name
die kanaal = https://www.youtube.com/@gereformeerdekerkoranjeriv5791
die kerk-PC = die kerk se Windows 11-rekenaar waar dit finaal loop

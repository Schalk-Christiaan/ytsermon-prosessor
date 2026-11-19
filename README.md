# ytsermon-prosessor

Desktop app (Flutter) for the church: downloads sermons from the YouTube channel, cuts them to the sermon, makes Shorts, re-uploads with titles, descriptions and playlists, and exports audio for WhatsApp. Runs fully local (yt-dlp, ffmpeg, Ollama).

## Gebruik
- Kerk-PC: run `Setup.exe` from the latest GitHub Actions/Release build.
- Dev (Linux): `flutter pub get && flutter run -d linux` (needs `yt-dlp`, `ffmpeg`, `ollama pull qwen3:8b`).

## Fase 1: Hersien
Plak 'n YouTube-skakel in **Hersien**: die app laai die metadata en Afrikaanse onderskrifte, vra Ollama (`qwen3:8b`, ~20 s) vir die preekgrense, Shorts, titel en beskrywing, en wys dit op 'n dienstydlyn. Skuif die handvatsels (sleep, of Tab + pyltjies; Shift = 1 s), pas teks aan en kies **Keur goed en sny**: die preek en Shorts (1080×1920, ingebrande onderskrif) kom in `out/`. Die plan word in `<app-data>/work/<video-ID>/plan.json` gestoor.

## Toetse
- `flutter test` – eenhede, skermkiekies na `out/shots/` (`test/screens_test.dart`).
- `E2E=1 flutter test test/e2e_test.dart` – volle vloei op die toetsvideo (vereis internet en Ollama; ~1 min met gekaste video).
- Linux-bou vereis `cmake` en `ninja`.

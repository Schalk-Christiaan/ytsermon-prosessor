# ytsermon-prosessor

Desktop app (Flutter) for the church: downloads sermons from the YouTube channel, cuts them to the sermon, makes Shorts, re-uploads with titles, descriptions and playlists, and exports audio for WhatsApp. Runs fully local (yt-dlp, ffmpeg, Ollama).

## Gebruik
- Kerk-PC: run `Setup.exe` from the latest GitHub Actions/Release build.
- Dev (Linux): `flutter pub get && flutter run -d linux` (needs `yt-dlp`, `ffmpeg`, `ollama pull qwen3:8b`).

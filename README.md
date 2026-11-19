# ytsermon-prosessor

Download sermons from the church YouTube channel, trim them to the sermon, make Shorts, and re-upload with playlists and descriptions.

## Gebruik
```
uv sync
uv run python -m sermon process <video-url> --dry-run
```
Needs `yt-dlp` and `ffmpeg` on PATH (Windows: `winget install yt-dlp.yt-dlp Gyan.FFmpeg`).

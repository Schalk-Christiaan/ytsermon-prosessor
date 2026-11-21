# Spraak/musiek uit die spektrogram (2026-11-21)

- **waar**: YouTube se `[musiek]`/`[sang]`-merkers dek net 0–55 % van die werklike sangtyd (4 dienste; `spektrogram-prototipe/segmente.txt`, kolom "YT-musiek").
- **waar**: twee kenmerke per sekonde (2 s-venster, 10 ms-rame, 16 kHz mono) skei spraak en musiek op al 4 dienste met dieselfde drempels:
  - lae-energie-rame = deel van die 10 ms-rame met RMS < 0,5 × venster-gemiddeld: spraak 0,3–0,6, musiek ~0.
  - spektrale platheid (100–4000 Hz): musiek ~0,02, spraak 0,1–0,3.
  - reël: dB < −60 → stilte; lef ≥ 0,15 → spraak; platheid < 0,06 → musiek; anders geraas (geroesemoes voor die diens, stil pouse). Mediaan oor 9 s, stukke < 10 s by die vorige ingesmelt.
- **waar**: kruiskontrole met handmerke: spraak begin 14:44 by YWz5gf0onjk (gebed-handmerk 14:46,6); 11:51 by uub_CnO7bd0 (handmerk 711,92 s).
- **waar**: ~2 s numpy vir 62 min klank; klank uithaal 3 s.
- Swak kenmerke hier: spektrale flux (plat), 40–150 Hz-aandeel (raserig). 4 Hz-modulasie skei wel, maar swakker as lae-energie-rame.
- **onbewys**: onbegeleide gemeentesang en 'n solis; ffmpeg `astats`/`aspectralstats` as plaasvervanger vir die numpy-kenmerke.
- Alternatiewe as dit faal: YAMNet (~4 MB, "Speech"/"Singing"/"Music"); Silero VAD help nie (sang = stem); inaSpeechSegmenter te swaar (TensorFlow).

Prototipe: `spektrogram-prototipe/feat.py` (kenmerke), `cls.py` (klassifiseer), `plot.py` (grafiek). Loop: `uv run --with numpy python -I feat.py a.raw <json3> <prefix>`, `a.raw` = `ffmpeg -i video.mp4 -vn -ac 1 -ar 16000 -f s16le a.raw`.

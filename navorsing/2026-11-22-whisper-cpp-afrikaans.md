# whisper.cpp vir Afrikaans: weergawe, model, gehalte, spoed (2026-11-22)

Merke: **waar** = self gemeet of van die bron gelees; **onbewys** = nie getoets nie.

## Weergawe en Windows-bate
- Nuutste vrystelling met binêre: **b5907** (2026-11-20), `ggml-org/whisper.cpp`. (Tag `v1.9.5` het geen bate nie; die binêre kom op `b####`-tags.) — waar
- Bate vir die kerk-PC (RTX 3050, CUDA): `whisper-bin-win-cuda-12.4.0-x64.zip`, 735 571 214 grepe,
  SHA-256 `34f872ce724ca1ff0a4afca481853e5ee74250f8cb22153e499f953562846039`
  (URL: `https://github.com/ggml-org/whisper.cpp/releases/download/b5907/whisper-bin-win-cuda-12.4.0-x64.zip`). — waar (digest van die GitHub-API)
- CPU-terugval: `whisper-bin-x64.zip`, 9 168 428 grepe,
  SHA-256 `ecca07b277d943e9b9f4712856a144b857271a6b333104e511e1988e80db582b`. — waar
- Daar is **geen Windows-Vulkan-bate** nie (net CUDA 11.8/12.4/13.5-arm64, OpenCL-Adreno, CPU, BLAS). — waar
- **Let op (stap 8):** die CUDA-zip is **735 MB** (cuBLAS-DLL's). In Setup.exe of in CI-aflaai is dit swaar. Kies by stap 8: net `whisper-cli.exe` + die nodige `ggml*.dll`/`cublas*.dll` uitpak, of die model-aflaai-patroon ook vir die CUDA-bundel gebruik. CUDA 12.4 vereis NVIDIA-drywer >= 551 (onbewys op die kerk-PC).
- Die CLI heet `whisper-cli` (`main` is 'n verouderde alias). `-pp` skryf `whisper_print_progress_callback: progress =  20%` op stderr; `-ojf` skryf `<-of>.json` met per segment `offsets.from/to` (ms), `text` en `tokens[]` met `offsets`, `p`. — waar

## Model vir 4 GB VRAM
- `ggml-large-v3-turbo-q5_0.bin`: 574 041 195 grepe, SHA-256 `394221709cd5ad1f40c46e6031ca61bce88931e6e088c188294c6d5a55ffa7e2` (ooreenstem met wat ek afgelaai het). URL `https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin`. — waar
- Laai 573 MB op die CPU; op die GPU ongeveer dieselfde plus ~0,5-1 GB werkgeheue, dus pas in 4 GB. — onbewys (geen NVIDIA hier nie)
- Alternatiewe: turbo-q8_0 874 MB, medium-q5_0 539 MB (swakker). Keuse: **turbo q5_0**.

## Afrikaans-fyngestemde model
- Bestaan op Hugging Face, maar nie as ggml nie: `andreoosthuizen/whisper-large-v3-afrikaans` (LoRA-adapter, CC-BY-4.0, 123 aflaaie), `DanieClar/stillscript-whisper-large-v3-afrikaans` (safetensors, CC-BY-4.0, 38 aflaaie). Gebruik is 'n omskakeling en eie toetsing nodig; die lisensie laat dit toe. — waar (lêerlys en kaart); gehalte **onbewys**, **buite bestek** (fyninstelling/omskakeling).

## Maatstaf (Linux, CPU, eie toets)
Masjien: dev-PC, 12 drade (ggml `zen4`-agterkant), **CPU-only**. Die Vulkan-weergawe is **onbewys**: `vulkan-headers` ontbreek (`/usr/include/vulkan` bestaan nie) en niks word stelselwyd geïnstalleer sonder om te vra nie. Dus: amptelike `whisper-bin-ubuntu-x64` b5907, model turbo q5_0, `-l af -ojf -pp`.
Video `YWz5gf0onjk`, twee vensters van 10 min; vergelyk met YouTube `af-orig` van dieselfde venster (die onderskrifte het nie die bate-gids se gids nie; `yt-dlp --write-auto-subs --sub-langs af-orig`).
Maatstawwe: **Nederlands-merkers** = woorde in 'n lys van Nederlandse vorms (toch, niet, zijn, mijn, hebben, koninkrijk, duivels, ...) of met `ij` of op `-lijk(e)` (Afrikaans: `-lik`); `segmente met NL` = segmente met minstens een merker; **ooreenkoms** = `difflib.SequenceMatcher`-verhouding van woordreekse teenoor YouTube. Dit is 'n growwe skatting (die merkerlys is nie volledig nie).

| Venster | Opdrag | Tyd | x intyds | NL-woorde | Segmente met NL | Ooreenkoms met YouTube |
|---|---|---|---|---|---|---|
| 20:00-30:00 (gebed, sang, begin preek) | sonder `--prompt` | 340 s | 0,57 | 29 / 1142 (2,5 %) | 23 / 179 (13 %) | 0,80 |
| 20:00-30:00 | met `--prompt` | 421 s | 0,70 | 13 / 2536 | 9 / 415 | **0,11 (lus)** |
| 30:00-40:00 (preek) | sonder `--prompt` | 360 s | 0,60 | 11 / 1235 (0,9 %) | 11 / 109 (10 %) | 0,81 |
| 30:00-40:00 | met `--prompt` | 364 s | 0,61 | 11 / 1230 (0,9 %) | 11 / 122 (9 %) | 0,82 |
YouTube self het in die twee vensters 1 en 0 merkers.

### Bevindings
- **Gehalte is bruikbaar, maar nie so goed as YouTube nie:** minder as 15 % van die segmente het 'n Nederlandse vorm (verre onder die helfte), ooreenkoms ~0,8 met YouTube. Tipiese slips: "ontzettend", "goddelooses", "makkelijk", "wonderlijk", "pijn", "koninkrijk". Dit is genoeg vir grense, beplanning en Shorts-onderskrifte as terugval; vir 'n gelese transkripsie is YouTube beter.
- **`--prompt` help nie:** op die preek maak dit geen verskil nie (9 % teenoor 10 %). In die sang-venster het dit 'n **herhalingslus** veroorsaak: "Aan die fontein van my leven." 391 keer, 25 uniek van 415 segmente. Gevolg: **geen `--prompt` by verstek** nie. Die lus kom ook sonder prompt voor by ware sang/musiek-gebiede (daar skryf die model "ZANG EN MUZIEK"); `--vad` (Silero-model) of `--max-context 0` kan dit verminder, **onbewys**.
- **Spoed op die CPU:** 0,57-0,70 x intyds; 'n 75-min diens ~45 min. Die vroeëre faster-whisper-maatstaf (0,14 x op 'n 6-kern Ryzen 5 7600 met VAD) is vinniger as whisper.cpp se CPU-pad hier; die CPU is dus net 'n noodterugval. GPU-spoed (RTX 3050): **onbewys**, net op die kerk-PC meetbaar.
- Ontwerp-gevolg vir stap 5-6: `-ojf` gee token-tye; woorde word saamgestel uit tekens wat met 'n spasie begin; segmente met klein gapings en dieselfde herhaalde teks moet gefiltreer word (anti-lus: laat 'n segment weg as dit identies is aan die vorige twee).

## Onbewys (kom by die kerk-PC / later)
- Vulkan-bou en GPU-spoed op AMD; CUDA-spoed en VRAM-gebruik op die RTX 3050; drywer-vereiste; die reële grootte van die uitgepakte CUDA-DLL's; `--vad`/`--max-context 0` teen herhalingslusse.

status: klaar

# GPU-enkodering (NVENC) en plaaslike spraak-na-teks as terugval

## Doel
Die kerk-PC is 'n skootrekenaar met 'n Ryzen 7 5800H, 'n RTX 3050 (waarskynlik 4 GB VRAM) en 16 GB DDR4 (`CONTEXT.md` → Name).

Twee dinge:
1. **NVENC:** ffmpeg enkodeer op die RTX 3050 (`h264_nvenc`) as dit werk, anders soos nou op die CPU (`libx264`). Die gebruiker hoef niks te kies nie.
2. **Spraak-na-teks:** maak 'n plaaslike transkripsie (whisper.cpp op die GPU, taal `af`) **net** as 'n video geen YouTube-`af-orig`-onderskrifte het nie, of as Schalk in Hersien vra om plaaslik te transkribeer omdat YouTube s'n swak is.
   - YouTube bly eerste.
   - Besluit 2026-11-22 (Schalk): "Terugval". Dit vervang "geen Whisper" van 2026-11-19 net vir hierdie twee gevalle.

## Bestaande feite (moenie weer naslaan nie)
- **`navorsing/2026-11-19-youtube-api-en-preekgrense.md`** → "Maatstaf": faster-whisper op die CPU.
  - Spoed: large-v3-turbo ≈ 0,14× intyds.
  - Gehalte: al die modelle glip na Nederlands; YouTube is beter.
  - faster-whisper is Python, en die app het geen Python nie (besluit 2026-11-19). Daarom **whisper.cpp** (`whisper-cli.exe`): 'n los exe, net soos yt-dlp/ffmpeg.
- **Dev-masjien:** AMD Radeon RX 7600, geen NVIDIA nie.
  - ffmpeg n9.0.2 lys `h264_nvenc`, maar dit kan hier nie enkodeer nie. Op Linux word die terugval dus regtig getoets.
  - NVENC se spoed kan net op die kerk-PC gemeet word.
- **Windows-CI:** gebruik GyanD se `essentials_build` (`.github/workflows/windows.yml`), wat `h264_nvenc` insluit.
- **Onderskrifte:** `channel.dart` laai `<id>.af-orig.json3` af en gooi `StateError('Geen af-orig-onderskrifte …')` as dit ontbreek.
  - `captions.dart` ontleed json3.
  - `bounds.dart` gebruik woordtye.

## Ontwerp
- **Enkodeerder-keuse** (`lib/core/tools.dart`):
  - `videoEncoder()` toets eenmaal per sessie:
    - staan `h264_nvenc` in `ffmpeg -hide_banner -encoders`?
    - slaag 'n proef-enkodering van 'n paar rame (`-f lavfi -i color=…:s=256x256 -frames:v 5 -c:v h264_nvenc -f null -`)?
  - Albei waar → NVENC, anders libx264. Die uitslag word gekas.
  - Die Instellings → Stelsel-lys wys "Video-enkodering: GPU (NVENC)" of "CPU (libx264)".
- **Cutter** (`lib/core/cutter.dart`):
  - Die huidige `_x264` en die tweede `libx264`-plek (±93) kom uit een funksie wat die gekose enkodeerder se argumente gee:
    - NVENC: `-c:v h264_nvenc -preset p5 -tune hq -rc vbr -cq 21 -b:v 0`;
    - libx264: soos nou.
  - Faal 'n NVENC-enkodering, word dieselfde snit een keer met libx264 herprobeer, en die kas word op libx264 gestel.
  - Presiese snypunte bly, want dit is steeds 'n herkodering.
- **Transkripsie** (nuwe `lib/core/transcribe.dart`):
  1. `ffmpeg` maak 16 kHz mono WAV.
  2. Dit loop `whisper-cli -m <model> -l af -ojf -pp -f <wav>`, met `--prompt` gelaai met kort Afrikaanse kerkteks (bv. "Ons lees uit die Bybel. Die Here is ons herder. Julle, duiwels, koninkryk.") om die Nederlandse glip te demp.
  3. Die JSON (tokens met tye) word omgeskakel na **dieselfde json3-vorm** as YouTube s'n en as `<id>.local.json3` gestoor.
  - Alles stroomaf (captions, bounds, planner, Shorts-onderskrifte) werk dus onveranderd.
  - `channel.dart`: ontbreek `af-orig`, gooi dit nie meer nie. Die job kry 'n transkribeer-stap, en die leser kies `af-orig` → `local`.
- **UI:**
  - Die vorderingswyer wys die stap as "Transkribeer plaaslik (GPU)" met persentasie uit whisper se `-pp`-uitset. Die fase is `plan` met eie detail-teks; daar is geen nuwe JobPhase nie, tensy die toets wys dit is nodig.
  - Hersien se Transkripsie-oortjie wys 'n merk "Plaaslike transkripsie" as die bron `local` is.
  - Die knoppie "Transkribeer plaaslik" vervang die onderskrifte vir daardie preek, met 'n bevestiging wat die gevolg noem. Die ou json3 word as `.bak` behou.
- **Model:** dit word nie in Setup.exe ingesluit nie.
  - Instellings → Stelsel het "Laai spraakmodel af", soos die Ollama-model, met vordering.
  - Die model word gekies in stap 1 (verwag large-v3-turbo q5_0 ≈ 550 MB, wat in 4 GB VRAM pas).
- **Windows-bundel:**
  - whisper.cpp se amptelike Windows-vrystelling met CUDA (cuBLAS) is vasgepen met SHA-256 in `windows.yml`, plus die CPU-bou as terugval as daar geen NVIDIA-drywer is nie.
  - Die rooktoets roep `whisper-cli --help` op.

## Lêers
- `lib/core/tools.dart`: `videoEncoder()`, die vind van `whisper-cli` en die model, en die model-aflaai.
- `lib/core/cutter.dart`: enkodeerder-argumente uit een plek, en die herprobeer met libx264.
- `lib/core/transcribe.dart` (nuut): wav → whisper-cli → json3.
- `lib/core/channel.dart` en `lib/core/jobs.dart`: geen onderskrifte → transkribeer-stap in plaas van 'n fout.
- `lib/core/captions.dart`: kies die bron (`af-orig` eers, dan `local`).
- Skerms:
  - `lib/features/settings/…`: Stelsel-rye vir die enkodeerder en die spraakmodel;
  - `lib/features/review/…`: merk en knoppie in Transkripsie.
- `lib/l10n/app_af.arb`.
- `.github/workflows/windows.yml` en die Inno-skrip: whisper-cli + DLL's.
- `navorsing/2026-11-22-whisper-cpp-afrikaans.md` (nuut).
- Toetse: `test/tools_test.dart`, `test/cutter_test.dart`, `test/transcribe_test.dart`, `test/jobs_test.dart`, controls_*.

## Stappe
### A. NVENC
1. **Enkodeerder-keuse:** `videoEncoder()` met 'n vervalste ffmpeg in die toets: (a) nvenc gelys en die proef slaag → nvenc; (b) gelys maar die proef faal → libx264; (c) nie gelys nie → libx264; die kas word hergebruik. — kontrole: die toets is eers rooi, dan groen. Op die dev-masjien gee die regte ffmpeg libx264 (geval b).
2. **Cutter:** die argumente kom uit een plek; 'n NVENC-mislukking herprobeer met libx264 en stel die kas. — kontrole:
   - eenheidstoets met 'n vervalste ffmpeg wat op nvenc faal → die snit slaag met libx264;
   - `grep -n libx264 lib/core/cutter.dart` gee net die een definisie;
   - 'n regte snit van die toetsvideo op Linux: `ffprobe` wys h264, en die duur stem tot ±0,1 s ooreen met die vorige uitset.
3. **Stelsel-ry:** Instellings → Stelsel wys die enkodeerder. — kontrole: widget-toets; kiekie lig/donker.

### B. Spraak-na-teks
4. **Navorsing** (`navorsing/2026-11-22-whisper-cpp-afrikaans.md`):
   - die whisper.cpp-weergawe en Windows-CUDA-bate (URL + SHA-256);
   - model-keuse vir 4 GB VRAM;
   - of daar 'n Afrikaans-fyngestemde Whisper/ggml-model bestaan, en sy lisensie;
   - of `--prompt` die Nederlandse glip verminder;
   - **maatstaf op Linux:** bou whisper.cpp met Vulkan, want die dev-GPU is AMD. Doen dit in die scratchpad, nie in die repo nie. Gebruik 10 min van YWz5gf0onjk: tyd, en 'n telling van Nederlandse woorde teenoor YouTube `af-orig` (met en sonder prompt).
   - kontrole: die lêer het **waar/onbewys**-merke en die maatstaftabel. As die gehalte onbruikbaar is (meer as die helfte van die sinne het Nederlands): stel `status: wag` met 'n vraag aan Schalk.
5. **Transkribeer-module:** wav → whisper-cli → json3, getoets met 'n vaste whisper-JSON-toestel (`test/fixtures/`) → json3 → `parseCaptions` gee segmente met woordtye. — kontrole: die eenheidstoets is eers rooi, dan groen; `bounds`-toetse op die omgeskakelde json3 slaag.
6. **Job-vloei:**
   - geen `af-orig` nie → transkribeer-stap (detail-teks + persentasie uit `-pp`), daarna plan soos gewoonlik;
   - geen whisper/model nie → 'n duidelike fout met die weg na Instellings ("Laai spraakmodel af");
   - een whisper-proses op 'n slag, deur die bestaande JobQueue.
   - kontrole: `jobs_test` met 'n vervalste whisper-cli en ffmpeg; geen netwerk nie.
7. **UI:**
   - Stelsel-ry vir die spraakmodel + "Laai spraakmodel af" met vordering;
   - Hersien → Transkripsie: merk "Plaaslike transkripsie" en die knoppie "Transkribeer plaaslik" (bevestiging, `.bak` behou).
   - Nuwe kontrole-sleutels `ctl.instellings.whisper-model`, `ctl.hersien.transcribe-local`.
   - kontrole: widget-toetse; controls_inventory/controls_test bygewerk; kiekies lig/donker by 1100 en 1600.
8. **Windows-bundel:** whisper-cli (CUDA + CPU-terugval) vasgepen in `windows.yml`, by Setup gevoeg, met `whisper-cli --help` in die rooktoets. — kontrole: die YAML is geldig (`python3 -c 'import yaml…'`); die CI-lopie self gebeur ná die merge op main, so skryf "ongetoets: CI" in die Verslag.
9. **Werklike vloei op Linux:** 'n video sonder onderskrifte (vervals deur `af-orig` tydelik te hernoem in 'n kopie van die werkgids) → transkribeer → plan → sny. — kontrole: die log wys "Transkribeer plaaslik", die snit slaag, en `ffprobe` van die uitset is reg.
10. **Afsluiting:**
    - `dart format`, `dart analyze` en `flutter test` groen;
    - `@stelsel`-blokke (nuwe hoofstuk `transcribe` met `status: bou`);
    - `kaart.py --check` 0 FOUT;
    - `CONTEXT.md` → Besluite: die 2026-11-22-terugvalreël is reeds bygevoeg; maak seker dit stem.

## Aanvaarding
- Op 'n masjien sonder werkende NVENC enkodeer alles soos voorheen met libx264, sonder foute. Waar NVENC werk (kerk-PC), word `h264_nvenc` gebruik, en 'n NVENC-mislukking val terug sonder dat die taak faal.
- Instellings → Stelsel wys watter enkodeerder gebruik word, en of die spraakmodel teenwoordig is.
- 'n Video met `af-orig` gebruik **nooit** whisper nie.
- 'n Video sonder `af-orig` word plaaslik getranskribeer en kry 'n plan, snitte en Shorts-onderskrifte. Die vorderingswyer sê wat besig is, met 'n persentasie.
- Hersien laat Schalk 'n swak YouTube-transkripsie plaaslik vervang, met 'n bevestiging, en die ou een word behou.
- Die model word nie in Setup.exe ingesluit nie; dit word op versoek afgelaai.
- Toetse vervals ffmpeg/whisper/YouTube/Ollama; `flutter test` groen; kiekies lig en donker.

## Prestasie-begroting
- Geen nuwe timers of polling nie.
- Die enkodeerder-proef loop een keer per sessie (< 2 s), nie by elke snit nie.
- Whisper loop net as daar geen `af-orig` is nie, of op versoek, een proses op 'n slag deur die JobQueue.
- Geen nuwe pub-afhanklikheid nie, tensy die navorsing een vereis; vra dan eers.

## Buite bestek
- NVENC vir AV1/HEVC.
- AMD/Intel-enkodeerders (AMF/QSV).
- Whisper vir alle video's.
- Fyninstelling van 'n eie model.
- Transkripsie-redigering.
- Ollama-instellings vir die 4 GB-GPU.
- Niks word na YouTube opgelaai nie.

## Ingryp

## Vrae

## Log
- 2026-11-22: plan geskryf ná Schalk se keuses "NVENC eers" en "spraak-na-teks as terugval".
- 2026-11-22: 1 klaar — videoEncoder() 3 gevalle + kas getoets (rooi→groen); regte ffmpeg op Linux gee libx264.
- 2026-11-22: 2 klaar — videoArgs() een definisie, _encode herprobeer met libx264; regte snit: h264, 7.52 s vir 7.5 s. Afwyking: Shorts kry nou ook -preset veryfast (was x264-verstek).
- 2026-11-22: 3 klaar — probeAll kry 'encoder'-ry; system_status_test (GPU/CPU) + tools_probe_test; kiekies lig/donker in docs/kiekies/gpu-en-spraak/stelsel-rye-*.png; flutter test 361 groen. SystemStatus kry `probe`-naat (Process.run kan nie in widget-toets nie).
- 2026-11-22: 4 klaar — navorsing/2026-11-22-whisper-cpp-afrikaans.md: b5907, CUDA-zip 735 MB + SHA-256, turbo q5_0 (574 MB); CPU 0,6x intyds; ~10 % segmente met Nederlandse vorms (nie >50 %), ooreenkoms 0,8 met YouTube; `--prompt` help nie en veroorsaak herhalingslus in sang. Vulkan onbewys (vulkan-headers ontbreek; niks geïnstalleer).
- 2026-11-22: 5 klaar — lib/core/transcribe.dart (whisperToJson3 + transcribeLocal); test/transcribe_test.dart rooi→groen met fixture whisper-sample.json en vervalste ffmpeg/whisper-cli; parseJson3 gee woordtye, blocks() werk, bounds-/captions-toetse groen. Anti-lus: segment gelyk aan vorige twee word weggelaat.
- 2026-11-22: 6 klaar — fetchMeta gooi nie meer sonder af-orig nie; FetchedMeta.anyCaptions (af-orig dan local) in jobs/suggest/review; planJob: checkWhisper vroeg (fout wys na Instellings "Laai spraakmodel af"), transkribeStep ná aflaai met detail+persentasie; jobs_test (vervalste whisper-cli/ffmpeg, twee take agtermekaar) groen; volle suite 366 groen.
- 2026-11-22: 7 klaar — Stelsel-ry "Spraakmodel" + "Laai spraakmodel af" (pullWhisperModel: .part, SHA-256, hernoem; getoets met plaaslike HttpServer); Hersien → Transkripsie: badge "Plaaslike transkripsie" + "Transkribeer plaaslik" (bevestiging, .bak van af-orig/local); sleutels ctl.instellings.whisper-model, ctl.hersien.transcribe-local(+cancel/confirm) in inventory en getoets; volle suite 379 groen; kiekies lig/donker 1400+1600 (Hersien) en 1100/1400/1600 (Stelsel) in docs/kiekies/gpu-en-spraak/ (1100 vir Hersien wys die paneel nie, dis die bestaande uitleg).
- 2026-11-22: 8 klaar (afwyking) — windows.yml laai whisper-bin-x64 b5907 (SHA-256 vasgepen) af, kopieer whisper-cli.exe + whisper.dll + ggml*.dll na deps/whisper, setup.iss installeer dit langs die exe, rooktoets loop `whisper-cli --help`; YAML parse OK. CUDA-zip (735 MB) NIE gebundel nie (te groot, drywer >= 551 onbewys); sy URL/SHA staan as kommentaar. CI self: ongetoets: CI.
- 2026-11-23: 9 deels — regte vloei op 'n 4-min-knip van YWz5gf0onjk sonder af-orig: whisper-cli (CPU) → `local.json3` (12 KB) met vordering 12→53 % in die detail-reël → plan het korrek geweier ("Die preek is 4 min; moet 15–90 min"); snit dus nie op regte data bewys nie (eenheidstoetse dek dit). Transkripsie wys Nederlandse glip ("toch", "kracht", "wij").
- 2026-11-23: 10 klaar (hoofsessie) — tydelike toets weg; format, analyze skoon, 379 toetse groen, kaart 0 FOUT.

## Verslag
**Gebou:** `videoEncoder()` + `videoArgs()` (NVENC met proef en libx264-terugval, ook per snit); Stelsel-rye Enkodeerder en Spraakmodel (+ aflaai met SHA-256); `lib/core/transcribe.dart` (wav → whisper-cli → json3 `local`); job-vloei transkribeer as af-orig ontbreek; Hersien-merk en "Transkribeer plaaslik" (.bak); windows.yml bundel whisper-cli CPU-bou b5907.
**Bewys:** 379 toetse (vervalste ffmpeg/whisper/HTTP); regte snit op Linux h264 7,52 s; regte whisper-lopie tot plan (stap 9); navorsing met maatstaf.
**Ongetoets:** NVENC op 'n NVIDIA-kaart (kerk-PC); whisper op Windows; CI-lopie; volle regte snit uit 'n plaaslike transkripsie.
**Afwykings:** net CPU-whisper gebundel (CUDA-zip 735 MB); Shorts kry ook `-preset veryfast`; `--prompt` nie gebruik nie (help nie, veroorsaak lusse); anti-lus-filter vir herhaalde segmente.
**Hersiening (2026-11-23):** niks ernstig nie. Klein, later: Hersien se "Transkribeer plaaslik" loop buite die JobQueue (kan saam met 'n taak se whisper loop); duplikate in `_pickEncoder`/`runTool` en `pullWhisperModel`/`pullModel`; Windows-toetse oorgeslaan; zip-paaie in CI ongetoets.
**Prestasie:** een proef per sessie; whisper net sonder af-orig of op versoek, deur die JobQueue; CPU-whisper ≈ 0,6× intyds hier, op die kerk-PC na verwagting effens stadiger.


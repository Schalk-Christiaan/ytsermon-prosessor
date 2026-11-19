# YouTube API-limiete en preek-begin/einde vind

Datum: 2026-11-19. Uitspraak per bewering: **waar / deels / vals / onbewys**.

## Die kanaal self (eie toets met yt-dlp 2026.08.19)
- **waar**: `/@gereformeerdekerkoranjeriv5791/streams` gee 321 opnames (1–2 uur elk), `/videos` net 5, geen `/shorts`-oortjie. Volledige lys, nie by ~100 afgekap nie.
- **waar**: beskrywings bevat reeds `Tema:`, `Skriflesing:`, `Fokusgedeelte:`, NGB/HK-artikel en psalms, dus bruikbaar vir titel/snitlys (Bybelboek).
- **waar**: verlede strome het outo-onderskrifte `af-orig` (json3 met tydstempels, `[musiek]`/`[sang]`-merkers). Haal: `yt-dlp --skip-download --write-auto-subs --sub-langs af-orig --sub-format json3`.
  Toetsvideo YWz5gf0onjk: preek duidelik ~23–52 min. Geen whisper nodig vir die konsep nie.
- Valstrik: YouTube lees "Mattheus 12:22" in die beskrywing as 'n tydstempel en maak valse hoofstukke. Ignoreer `chapters`.
- yt-dlp op Arch is ouer as 90 dae en waarsku oor SABR; hou dit op datum (op Windows: `yt-dlp -U` of winget).

## YouTube Data API v3
- **waar**: `videos.insert` het sy eie emmer: 100 oplaaie/dag, koste 1 elk. Ander metodes deel 10 000 eenhede/dag; `playlistItems.insert`, `playlists.insert`, `videos.update` = 50 elk (≈200 snitlys-/opdaterings-oproepe per dag). Herstel middernag Pacific.
  [determine_quota_cost](https://developers.google.com/youtube/v3/determine_quota_cost), [revision_history](https://developers.google.com/youtube/v3/revision_history) (2025-12-04 en 2026-06-01). Ou bronne noem 1600: verouderd.
- **waar**: sedert 2026-11-02 word oplaaie uit ongeverifieerde API-projekte nie meer tot `private` beperk nie. Weggelate `privacyStatus` gee `public`, so stel dit altyd uitdruklik. [revision_history](https://developers.google.com/youtube/v3/revision_history)
- **waar**: meer as die standaardkwota vereis 'n oudit ([vorm](https://support.google.com/youtube/contact/yt_api_form)). Nie nodig by 100 oplaaie/dag nie.
- **waar**: scope `https://www.googleapis.com/auth/youtube.upload` (plus `youtube` vir snitlyste); Desktop-OAuth-kliënt met loopback-herleiding. [installed-apps](https://developers.google.com/youtube/v3/guides/auth/installed-apps)
- **waar**: in "Testing"-status verval die refresh-token ná 7 dae. [oauth2#expiration](https://developers.google.com/identity/protocols/oauth2#expiration) Gevolg: publiseer die OAuth-app ("In production"), anders moet die kerk-PC weekliks weer aanmeld. **onbewys**: of 'n ongeverifieerde "In production"-app vir een gebruiker net 'n waarskuwingskerm wys (verwag ja).
- **waar**: ongeverifieerde YouTube-rekeninge is beperk tot 15 min per video; die kanaal laai reeds 1 uur+ op, dus geverifieer. [answer/71673](https://support.google.com/youtube/answer/71673)
- **waar**: Python: `google-api-python-client` + `google-auth-oauthlib`, `MediaFileUpload(..., resumable=True)` met herprobeer. [uploading_a_video](https://developers.google.com/youtube/v3/guides/uploading_a_video)
- **waar**: Shorts = vertikaal, tot 3 minute. [answer/10059070](https://support.google.com/youtube/answer/10059070) **onbewys**: 'n API-vlag vir Shorts. Nie gevind nie; YouTube lei dit af uit vorm en lengte.

## Snypunte en verwerking
- **deels**: "live strome kry net Engelse outo-onderskrifte" ([answer/6373554](https://support.google.com/youtube/answer/6373554)) geld vir lewendige onderskrifte; die opnames daarna het wel `af-orig` (sien bo).
- **waar**: faster-whisper ken `language="af"`, woord-tydstempels, Silero-VAD ([repo](https://github.com/SYSTRAN/faster-whisper)). Rugsteun as 'n video geen onderskrifte het nie. **onbewys**: CPU-spoed van medium/large op die kerk-PC.
- **onbewys**: Whisper se Afrikaanse WER (Tabel 13, [arXiv 2212.04356](https://arxiv.org/pdf/2212.04356)) kon nie betroubaar gelees word nie.
- **waar**: inaSpeechSegmenter skei spraak/musiek ([repo](https://github.com/ina-foss/inaSpeechSegmenter)), maar dit is TensorFlow-swaar; die `[musiek]`/`[sang]`-merkers in die onderskrifte maak dit vir nou onnodig.
- **waar**: `-ss` met `-c copy` sny op die naaste sleutelraam (onakkuraat, goed genoeg vir 'n volle preek); presies = herkodeer. 9:16: `crop=ih*9/16:ih,scale=1080:1920`. [ffmpeg.html](https://ffmpeg.org/ffmpeg.html), [filters](https://ffmpeg.org/ffmpeg-filters.html)
- Voorstel (nie bewys nie): 'n LLM oor die getydstempelde transkripsie kies preek-begin/einde en Shorts-uittreksels en skryf titel/beskrywing; die mens keur goed voor oplaai.

## Gevolgtrekking vir die konsep
yt-dlp (lys + `af-orig`-onderskrifte) → LLM kies snypunte → ffmpeg sny → mens keur → API laai op (`private` eers). Geen whisper/GPU nodig nie.

## Maatstaf: plaaslike Whisper teenoor YouTube-onderskrifte (eie toets)
faster-whisper 1.2.1, CPU int8, Ryzen 5 7600 (6 kerne), 10 min preek uit YWz5gf0onjk, `language="af"`, VAD aan:

| Model | Tyd vir 10 min | x intyds | 75-min diens | 321 dienste |
|---|---|---|---|---|
| small | 52 s | 0.09 | ~7 min | ~1.5 dae |
| large-v3-turbo | 86 s | 0.14 | ~11 min | ~2.5 dae |
| large-v3 | 249 s | 0.42 | ~31 min | ~7 dae |

- **Gehalte: slegter as YouTube.** Al drie glip na Nederlands ("koninkrijk", "duivels", "door", "jylle", "eerst"); small is onbruikbaar. YouTube `af-orig` het korrekte Afrikaans met leestekens ("Beëlsebul", "duiwels", "julle").
- Gevolg: gebruik YouTube-onderskrifte vir grense, beskrywings en Shorts-onderskrifte. Whisper net as rugsteun vir video's sonder onderskrifte (of probeer later 'n Afrikaans-fyngestemde model).
- Valstrik: faster-whisper 1.2.1 + nuutste PyAV gee `open() got an unexpected keyword argument 'metadata_errors'`; omseil deur 'n numpy-skikking te gee of `av` vas te pen.

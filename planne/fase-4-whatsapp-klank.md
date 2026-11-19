status: hersien

# Fase 4: WhatsApp-klank

## Doel
Vir elke gesnyde preek kan Schalk met een knoppie 'n klanklêer vir die gemeente se WhatsApp-groep maak: mono mp3, 64 kbps (~20 MB vir 40 min, onder WhatsApp se 100 MB), lêernaam `JJJJ-MM-DD Tema.mp3`, ID3-titel = tema. Dit loop as 'n taak in die werkry (een proses op 'n slag, kanselleerbaar, "Probeer weer"), en ná klaar wys "Wys in gids" die lêer sodat hy dit self na WhatsApp sleep. Geen outomatiese stuur nie (CONTEXT.md, Besluite).

## Lêers
- `lib/core/cutter.dart`: `audioArgs(...)`, `cutAudio(...)`; `sermonFileName` kry 'n `ext`.
- `lib/core/jobs.dart`: `JobKind.audio`, `JobPhase.audio`, `audioJob(store)`; toestand van die preek bly onveranderd ná 'n klank-taak.
- `lib/features/work/work_screen.dart`: klaar-sny-item kry "Klank vir WhatsApp"; klaar-klank-item kry "Wys in gids".
- `lib/l10n/app_af.arb`: `whatsappAudio`, `taskAudio`, `stageAudio`.
- `test/cutter_test.dart`, `test/jobs_test.dart`, `test/screens_test.dart`.

## Stappe
1. `audioArgs(input, out, title)` = `-y -i <preek.mp4> -vn -ac 1 -c:a libmp3lame -b:a 64k -id3v2_version 3 -metadata title=<tema> -nostats -progress pipe:1 <uit>`; bron is die gesnyde preek (`outputs.first`), sodat latere snitte (fase 6, segmente) vanself saamkom. `cutAudio` hergebruik `_ffmpeg` met vordering. — kontrole: `cutter_test` (argumente + lêernaam `2026-11-16 Tema.mp3`, onwettige karakters weg) eers rooi; regte ffmpeg op 'n 5 s-toetsklank → `ffprobe`: mp3, 1 kanaal, 64 kb/s, titel-tag.
2. `JobKind.audio` + `audioJob`: preek moet 'n `.mp4` in `outputs` hê (anders gewone-taal fout "Sny eers die preek"); skryf mp3 langs die preek; voeg die pad by `outputs` (nie dubbel nie). `_run` verander die preek se toestand net vir plan/sny. — kontrole: `jobs_test` (audio-taak met gestubde runner laat toestand `gesny`; sonder mp4 → fout) eers rooi.
3. Werk-skerm: klaar sny-item → "Klank vir WhatsApp" (sit `audio`-taak in die ry); klaar klank-item → "Speel" en "Wys in gids" op die mp3. Laai = die bestaande vorderingsbalk met fase "Maak klank…"; fout = bestaande fout-ry met "Probeer weer"; leeg = bestaande "Niks in die ry nie.". — kontrole: widget-toets eers rooi; kiekies `out/shots/werk-klank-{light,dark}-{1100,1920}.png`.
4. `@stelsel`-blokke, `dart analyze`, `flutter test`, `dart format`, E2E-klank op die toetsvideo se gesnyde preek (`ffprobe` grootte < 100 MB).

## Aanvaarding
- `flutter test` groen, `dart analyze` skoon.
- 'n Klanklêer van die toetspreek: mono, 64 kb/s, ID3-titel, < 100 MB, naam `JJJJ-MM-DD Tema.mp3`.
- Werk-skerm: "Klank vir WhatsApp" → taak met vordering → "Wys in gids" kies die mp3.

## Prestasie-begroting
Een ffmpeg-proses deur die bestaande werkry; geen nuwe timers, polling of isolate. Klank uit die reeds gesnyde mp4 (geen tweede video-dekodering van die volle diens nie).

## Buite bestek
Outomatiese stuur na WhatsApp; `share_plus` (sien Vrae); kritiekronde op alle skerms (skuif na fase 6, waar Hersien herontwerp word en ui-ux/frontend-design se kritiek in elk geval op elke skerm loop).

## Ingryp
- As `libmp3lame` in die gyan-essentials-bou van ffmpeg ontbreek: stop en meld (dit is daar volgens gyan se lys; Linux se ffmpeg het dit).

## Vrae
- `share_plus` ondersoek (pub.dev, 13.3.1, 2026-11-19): lêers deel word op Windows ondersteun (Windows-deelpaneel), nie op Linux nie. **Onbewys** of WhatsApp Desktop as teiken in die deelpaneel verskyn en 'n mp3 aanvaar; kan nie op Linux getoets word nie. Dus nie ingebou nie. Stap vir Schalk op die kerk-PC: regsklik op 'n mp3 in Explorer → "Deel" en kyk of WhatsApp in die lys is. As ja, is 'n "Deel"-knoppie met `share_plus` 'n klein volgende stap.
- (aanname) Bron vir klank is die gesnyde preek-mp4, nie die oorspronklike video nie.
- (aanname) Lêernaam se "Tema" = die plan se titel (wat die tema is volgens die prompt).
- (aanname) Klank-uitvoer is per preek met die hand ("Klank vir WhatsApp"), nie outomaties ná elke sny nie.

## Log
- 2026-11-19 stap 1: `audioArgs`/`cutAudio`, `sermonFileName(ext:)`; cutter_test rooi (kompileer nie) → groen; regte ffmpeg + ffprobe: mp3, 1 kanaal, 64000 b/s, titel-tag.
- 2026-11-19 stap 2: `JobKind.audio`/`JobPhase.audio`/`audioJob`; jobs_test rooi → groen (toestand bly `gesny` by klaar én fout; sonder mp4 → "Sny eers die preek.").
- 2026-11-19 stap 3: Werk-skerm-knoppies; widget-toets rooi → groen; kiekies `out/shots/werk-klank-{light,dark}-{1100,1920}.png`.
- 2026-11-19 stap 4: E2E op die toetsvideo se gesnyde preek (30:26): 6 s, 14,6 MB, mp3 mono 64 kb/s, titel-tag reg. `flutter test` 79 groen, `dart analyze` skoon, `kaart.py --check` skoon.

## Verslag
Klaar gebou op `bou/fase-4-whatsapp-klank`. "Klank vir WhatsApp" op 'n klaar sny-item sit 'n klank-taak in die ry (vordering "Maak klank…", Kanselleer, Probeer weer by fout); klaar klank-item wys Speel en Wys in gids op die mp3. Die mp3 kom langs die preek-mp4 en word by `outputs` gevoeg. Self-hersiening: geen nuwe proses buiten een ffmpeg deur die werkry; plan-lees volg dieselfde patroon as `cutJob` (twee gevalle, nog nie 'n helper werd nie).
Ongetoets: "Deel" na WhatsApp Desktop (sien Vrae); ikone in die toets-kiekies is blokkies (toetsfont; word in fase 6 reggemaak).

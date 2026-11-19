status: bou

# Windows-installeerder wat werklik werk

## Doel
Fase 5 het `installer/setup.iss` en `.github/workflows/windows.yml` geskryf, maar dit het nog nooit op GitHub Actions geloop nie. Hierdie plan maak dit werklik: die werkvloei bou `Setup.exe`, installeer dit self stil op `windows-latest`, rook-toets die app, gradeer oor 'n lopende app heen op, deïnstalleer, en laai `Setup.exe` plus 'n inhoudslys as artefak op.

## Wat die installeerder moet doen
1. **Per gebruiker, sonder admin**: `PrivilegesRequired=lowest`, in `%LOCALAPPDATA%\Preekverwerker` (`yt-dlp -U` kan daar skryf). Net x64, Windows 10 1809+ (`MinVersion=10.0.17763`).
2. **Die Flutter Release-bundel** (`build\windows\x64\runner\Release\*`): `preekverwerker.exe`, `flutter_windows.dll`, `data\`, die inprop-DLL's (`desktop_drop_plugin.dll`, `file_selector_windows_plugin.dll`, `flutter_secure_storage_windows_plugin.dll`, `media_kit_*`), en libmpv (`libmpv-2.dll`) van `media_kit_libs_windows_video`.
3. **VC++-looptyd langs die exe**: `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll` uit die runner se `System32` (app-lokale ontplooiing; 'n skoon Windows 11 het dit dikwels nie). Geen redist-installasie nie, want dié vra admin.
4. **yt-dlp.exe, ffmpeg.exe, ffprobe.exe langs die exe**, vasgepen (yt-dlp 2026.10.26, ffmpeg 9.0.2 essentials van GyanD) en SHA-256 nagegaan in die werkvloei. Die app vind hulle daar: `findExecutable` kyk eers in `dirname(Platform.resolvedExecutable)`, dan Ollama se gids, dan PATH (toets in `tools_test`).
5. **Ollama stil installeer as dit ontbreek**: taak "Installeer Ollama (die KI, ±1,9 GB aflaai)", net sigbaar as `%LOCALAPPDATA%\Programs\Ollama\ollama.exe` nie bestaan nie, verstek aan. OllamaSetup v0.40.16 is 1,86 GB: te groot om in te bou (Inno/artefak-limiet), dus laai die installeerder dit tydens installasie af met `DownloadTemporaryFile` teen 'n vasgepende SHA-256 en loop dit `/VERYSILENT`. Geen internet of fout: 'n boodskap, en die installasie gaan voort (Opstelling wys Ollama dan rooi). Die model (qwen3:8b) laai die app se Opstelling-lys af.
6. **Start-kieslys** altyd; **lessenaar-ikoon** opsioneel (taak, verstek aan die eerste keer).
7. **Opgradering oor 'n bestaande installasie**: dieselfde `AppId`, `CloseApplications=yes` (Restart Manager maak die lopende app toe, ook in stil modus), `[UninstallRun] taskkill` vir die deïnstalleerder. Instellings en die werkgids lê in `%APPDATA%\za.co.gkoranjerivier\preekverwerker` (buite `{app}`) en bly dus.
8. **Deïnstalleer**: verwyder die programlêers en ikone; vra dan "Vee ook die werkgids uit?" met verstek **Nee** (stil deïnstalleer = Nee). Die gesnyde preke in die uitsetgids (`Videos\Preke`) raak dit nooit nie.
9. **Weergawe uit `pubspec.yaml`** (`/DAppVersion=` aan ISCC; ook `VersionInfoVersion`).
10. **Taal**: Inno se `Dutch.isl` met die sigbaarste knoppies en boodskappe in `[Messages]` na Afrikaans oorgeskryf; ons eie teks (`[CustomMessages]`, take, status) in Afrikaans.
11. **Ná installasie**: "Maak Preekverwerker oop" (nie in stil modus nie).
12. **SmartScreen**: die exe is nie onderteken nie; die eerste keer wys Windows "Windows het jou rekenaar beskerm" → **Meer inligting → Hardloop tog**. Staan in Vrae vir Schalk.
13. **Werkvloei** (`windows.yml`): loop op push na `main` en `bou/windows-installeerder`, tags `v*` en met die hand; bou, laai af + checksum, ISCC, dan die rook-toets (installeer stil na `RUNNER_TEMP`, kontroleer die lêerlys, `yt-dlp --version`/`ffprobe -version` uit die installasiegids, begin die app 20 s, installeer weer oor die lopende app, deïnstalleer stil en kontroleer dat die werkgids bly), artefak `Setup` = `Setup.exe` + `inhoud.txt`.

## Lêers
- `installer/setup.iss`: herskryf volgens die lys hierbo.
- `.github/workflows/windows.yml`: tak-trigger, checksums, rook-toets, inhoudslys.
- `test/tools_test.dart`: `findExecutable` verkies die exe-gids bo PATH.
- `planne/windows-installeerder.md` (hierdie).

## Stappe
1. Plan. — kontrole: hierdie lêer.
2. `tools_test`: 'n hulpmiddel in die exe-gids wen van een op PATH. — kontrole: `flutter test test/tools_test.dart` groen (kode bestaan reeds; dis 'n regressie-wag).
3. `setup.iss` herskryf (punte 1–12). — kontrole: ISCC op die runner (geen ISCC op Linux).
4. `windows.yml` (punt 13). — kontrole: YAML-parse plaaslik.
5. Push `bou/windows-installeerder`, volg die lopie, herstel tot groen. — kontrole: `gh run watch` groen; `gh run download` → `Setup.exe` + `inhoud.txt` met exe, DLL's (ook VC++), yt-dlp, ffmpeg, ffprobe.
6. `dart analyze`, `flutter test`; merge lokaal in `main` (`--no-ff`), `flutter test` op main; status `hersien`.

## Aanvaarding
- Die werkvloei is groen op `bou/windows-installeerder`, insluitend die rook-toets (installeer, begin, opgradeer oor lopende app, deïnstalleer, werkgids bly).
- Die artefak bevat `Setup.exe`; `inhoud.txt` wys `preekverwerker.exe`, `flutter_windows.dll`, `libmpv-2.dll`, `desktop_drop_plugin.dll`, `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, `yt-dlp.exe`, `ffmpeg.exe`, `ffprobe.exe`.
- `flutter test` groen, `dart analyze` skoon.

## Buite bestek
Kodeondertekening, GitHub Release by 'n tag, outomatiese opdatering van die app, die model in die installeerder, 'n volledige `Afrikaans.isl`, toets van die Ollama-aflaai op CI (1,9 GB; die taak word daar afgeskakel).

## Vrae
- (aanname) Deïnstalleer vra net oor die werkgids (afgelaaide dienste, instellings, kwota); die uitsetgids met gesnyde preke word nooit uitgevee nie, want dit is die gebruiker se eie gids en kan enige plek wees.
- (aanname) Ollama word tydens installasie afgelaai eerder as ingebou (1,86 GB).

## Log

## Verslag

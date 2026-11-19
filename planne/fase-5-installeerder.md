status: hersien

# Fase 5: Installeerder en Opstelling

## Doel
Een `Setup.exe` vir die kerk-PC, gebou op GitHub Actions (Flutter bou Windows net op Windows). Dit installeer per gebruiker in `%LOCALAPPDATA%\Preekverwerker` (geen admin; `yt-dlp -U` kan daar skryf), met yt-dlp, ffmpeg en ffprobe langs die exe en Ollama stil geïnstalleer. By die eerste begin bring die **Opstelling-lys** in die app alles tot groen sonder 'n terminaal: Ollama loop → model afgelaai → kanaal gekoppel → uitsetgids. Die uitsetgids word 'n instelling: `outDir()` was `./out` relatief tot die werkgids, wat op Windows in die installasiegids of `System32` sou beland.

## Lêers
- `.github/workflows/windows.yml` (nuut): windows-latest, Flutter 3.47.9, `flutter build windows`, vasgepende yt-dlp 2026.10.26, ffmpeg 9.0.2 essentials (GyanD/codexffmpeg), OllamaSetup v0.40.16, VC++-runtime-DLL's, `ISCC` → artefak `Setup`.
- `installer/setup.iss` (nuut): Inno Setup 6, `PrivilegesRequired=lowest`, `{localappdata}\Preekverwerker`, Start-kieslys + lessenaar-ikoon, OllamaSetup `/VERYSILENT` net as Ollama nog nie daar is nie.
- `lib/core/settings.dart`: `outDir` (verstek `<tuis>/Videos/Preke`), `setupDone`.
- `lib/core/paths.dart`: `outDir()` weg; `defaultOutDir()`.
- `lib/core/jobs.dart`: `cutJob` lees die uitsetgids uit die instellings as niks deurgegee is nie.
- `lib/core/tools.dart`: `pullModel(onProgress)` (Ollama `/api/pull` gestroom), `startOllama()`; `findExecutable` kyk ook in `%LOCALAPPDATA%\Programs\Ollama`.
- `lib/features/setup/setup_screen.dart` (nuut): Opstelling-lys.
- `lib/app/shell.dart`: begin op Opstelling as `setupDone` vals is; Instellings het "Opstelling" om terug te gaan.
- `lib/features/settings/settings_screen.dart`: uitsetgids-veld; "Stelsel"-opskrif een vlak laer.
- `lib/l10n/app_af.arb`; toetse `test/settings_test.dart`, `test/tools_test.dart`, `test/screens_test.dart`.

## Stappe
1. `AppSettings.outDir`/`setupDone`, `defaultOutDir()`; `cutJob` gebruik dit. — kontrole: `settings_test` (verstek eindig op `Videos/Preke`, rondreis) eers rooi; `jobs_test` bly groen.
2. `pullModel` teen 'n vals Ollama-bediener (`OLLAMA_HOST`-plek: `base`-parameter): gestroomde `{"total","completed"}`-reëls → vordering 0..1, `{"status":"success"}` → klaar, `{"error"}` → gewone-taal fout. — kontrole: `tools_test` eers rooi.
3. Opstelling-skerm: vier rye, elk ikoon + woord (Klaar / Nog nie) + een knoppie: "Begin Ollama", "Laai model af" (vorderingsbalk, persentasie), "Koppel kanaal" (of "Kies eers die kliënt-ID-lêer in Instellings" met "Gaan na Instellings"), "Maak gids"; "Begin werk" (primêr) word aktief as al vier klaar is → Preke. "Kontroleer weer" laai die status oor. Shell begin hier as `setupDone` vals is. — kontrole: widget-toets (gestubde status: knoppies, "Begin werk" af tot alles klaar, dan Preke) eers rooi; kiekies `out/shots/opstelling-{light,dark}-{1100,1920}.png`.
4. `windows.yml` + `setup.iss`. — kontrole: YAML plaaslik deur `actionlint` (of 'n YAML-parse as dit nie beskikbaar is nie); `.iss` hersien teen Inno se dokumentasie (geen ISCC op Linux).
5. `@stelsel`-blokke, `kaart.py --check`, `dart analyze`, `flutter test`, `dart format`, `flutter build linux --debug`.

## Aanvaarding
- `flutter test` groen; `dart analyze` skoon; `actionlint` skoon op `windows.yml`.
- Opstelling-lys: met alles groen gaan "Begin werk" na Preke en verskyn dit nie weer by die volgende begin nie.
- Gesnyde preke beland in die uitsetgids uit Instellings, nie in die werkgids nie.

## Prestasie-begroting
Opstelling se kontroles is dieselfde vier `probeAll`-oproepe as Stelsel, net by oopmaak en "Kontroleer weer" (geen polling). Model-aflaai stroom reëls; geen tydhouers nie.

## Buite bestek
Kodeondertekening (SmartScreen: "Meer inligting → Hardloop tog"), GitHub Release by 'n tag (net 'n artefak), outomatiese opdatering van die app self, 'n gidskieser (die pad is 'n teksveld; fase 6 bring `file_selector` vir "Voer opname in" en kan dit hergebruik).

## Ingryp
- As `flutter build windows` op die runner 'n ander Visual Studio-komponent vra: voeg die stap by en noteer dit; moenie fase 6 daarvoor stop nie.
- Geen push nie: die werkvloei word net plaaslik gevalideer.

## Vrae
- **Ongetoets: die GitHub Actions-lopie en `Setup.exe`.** Stappe vir Schalk: (1) `git push` (die werkvloei loop by elke push na `main` en met die hand via Actions → "Windows" → "Run workflow"); (2) wag ±15 min, Actions → die lopie → Artifacts → `Setup` aflaai en uitpak; (3) op die kerk-PC: `Setup.exe` dubbelklik → SmartScreen "Meer inligting → Hardloop tog" → Volgende tot Klaar (geen admin-vraag nie; Ollama installeer stil saam); (4) die app maak oop op die Opstelling-lys: "Laai model af" (5 GB, ±10–30 min), kopieer `client_secret.json` na die gids wat Instellings → Kanaal wys, "Koppel kanaal", "Maak gids", "Begin werk"; (5) Instellings → Stelsel moet yt-dlp/ffmpeg/ffprobe/Ollama groen wys.
- (aanname) Uitsetgids-verstek `%USERPROFILE%\Videos\Preke` (Linux `~/Videos/Preke`).
- (aanname) Ollama word net geïnstalleer as `%LOCALAPPDATA%\Programs\Ollama\ollama.exe` nog nie bestaan nie; die model word deur die app afgelaai, nie die installeerder nie (5 GB in 'n installeerder is te groot vir 'n artefak).
- (aanname) Inno Setup het geen Afrikaanse vertaling nie; die installeerder se knoppies is in Nederlands (`Dutch.isl`), ons eie teks in Afrikaans.
- (aanname) Die werkvloei loop op push na `main`, op tags `v*` en met die hand; die artefak hou 30 dae.

## Log
- 2026-11-19 stap 1: `AppSettings.outDir` (verstek `<tuis>/Videos/Preke`) en `setupDone`; `outDir()` (`./out`) weg, `cutJob` lees die instelling; settings_test rooi → groen, jobs_test groen.
- 2026-11-19 stap 2: `pullModel` (gestroomde `/api/pull`, fout-reël en voortydige einde → gewone-taal fout), `startOllama` (losgekoppelde `ollama serve`), `findExecutable` kyk in `%LOCALAPPDATA%\Programs\Ollama`; tools_test teen 'n vals Ollama rooi → groen.
- 2026-11-19 stap 3: Opstelling-skerm; Shell begin daar tot `setupDone`; Instellings kry "Opstelling" en die uitsetgids-veld; "Stelsel" een opskrifvlak laer. Widget-toetse rooi → groen; kiekies `out/shots/opstelling-{light,dark}-{1100,1920}.png`. Kritiek: twee gevulde knoppies het meegeding → net die eerste oop stap se knoppie is gevul.
- 2026-11-19 stap 4: `.github/workflows/windows.yml` + `installer/setup.iss`; `actionlint` skoon (rc 0). ISCC nie op Linux nie.
- 2026-11-19 stap 5: `flutter test` 108 groen (1 oorgeslaan), `dart analyze` skoon, `kaart.py --check` skoon, `flutter build linux --debug` bou.

## Verslag
Gebou op `bou/fase-5-installeerder`. Die app begin by die eerste keer op die Opstelling-lys: vier genommerde stappe met ikoon + woord, elk een knoppie, net die volgende oop stap s'n gevul; "Begin werk" word aktief as al vier klaar is en die lys verskyn dan nie weer nie (Instellings → "Opstelling" bring dit terug). Gesnyde preke gaan na `Videos\Preke` (instelbaar), nie meer na 'n gids relatief tot waar die app begin is nie. Die werkvloei bou `Setup.exe` met vasgepende weergawes (yt-dlp 2026.10.26, ffmpeg 9.0.2 essentials, Ollama v0.40.16) en die VC++-runtime langs die exe.
Ongetoets: die GitHub Actions-lopie, `Setup.exe` en die Opstelling op die kerk-PC (stappe onder Vrae); `ISCC` het nie plaaslik geloop nie, so 'n tikfout in `setup.iss` wys eers op die runner.

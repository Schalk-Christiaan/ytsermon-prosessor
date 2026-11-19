# ytsermon-prosessor

Flutter desktop app: download sermons from the church YouTube channel, trim them, make Shorts, re-upload with playlists and descriptions, export audio for WhatsApp. Runs standalone (yt-dlp, ffmpeg, Ollama).

Type: flutter · Platforms: linux (dev), windows (church PC; built on GitHub Actions)

## Opdragte
```
flutter pub get · dart analyze · flutter test · dart format <veranderde lêers>
flutter build linux --debug (bou; `flutter run` vereis cmake+ninja) · E2E=1 flutter test test/e2e_test.dart (volle vloei, internet + Ollama)
```
Eksterne tools op PATH (dev): `yt-dlp`, `ffmpeg`, `ollama` met `qwen3:8b`. Windows-bou + installeerder: `.github/workflows/windows.yml`.

## Kontrole
Begin `flutter run -d linux`; gesond? die venster maak oop sonder uitsonderings in die terminaal en Instellings → Stelsel wys yt-dlp/ffmpeg/Ollama groen; dryf: `flutter test` vir die kern (`lib/core/`), handmatig/skermkiekie vir UI (`grim -g "$(hyprctl activewindow -j | jq -r '"\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"')" kiekie.png`), toetsvideo `https://youtu.be/YWz5gf0onjk` (preek ~23–52 min); bewys: toets-uitset, `ffprobe` van uitsetlêers en skermkiekies in lig en donker. Windows: GitHub Actions-artefak `Setup.exe` op die kerk-PC.
Sê "klaar" net ná `/bewys` (hierdie resep) geslaag het; anders "ongetoets: {rede}" en die stap vir Schalk.

## Konvensies
- Kode in Engels; gesprek en commit-boodskappe in Afrikaans waar die projek reeds so is.
- Kyk eers in `navorsing/` voor jy iets weer naslaan.
- Groter werk: `/plan` skryf `planne/<slug>.md`, `/bou <slug>` bou dit in die agtergrond op tak `bou/<slug>`. Bug: vind en herstel die bron-oorsaak (reproduseer eers); 'n tweede regmaak van dieselfde fout = soek dieper.
- Voor nuwe kode: hergebruik → stdlib → platform → bestaande afhanklikheid → minimum kode. Grep elke roeper voor 'n regmaak; herstel by die bron.
- Kruisplatform: `package:path` vir paaie, `Process.start` met argumentlyste (nooit `runInShell`), sodat dit op Windows loop.
- UI: volg skill `projekkonteks:ui-ux` en die ontwerpstelsel in `planne/hoofplan.md`; alle teks in ARB (`lib/l10n/`).
- Hoofstukke (modules, hooks, bevele, skerms, roetes) kry bo-aan 'n `@stelsel`-blok (formaat: `hooks/kaart.py`; `kaart:` in `CONTEXT.md` sê waar). Net hoofstukke; `status: klaar` net via `/bewys`, `stukkend` via `/fout`; verander jy 'n lêer, werk sy blok by. Funksie-kommentaar: reël 1 = wat dit doen (en hoekom, as dit nie voor die hand lê nie); opsioneel `skakel: → hoofstuk.funksie (rede)` en `vloei: <naam>`; klaar → `kaart.py --check`.
- Vloeie (`docs/kaart.html`): `vloei: <naam> | <titel>` met `inleiding:` en `hoekom:`; `stap: <vloei> <n> <titel> | <uitleg>`; formaat: `hooks/kaart.py`.
- Abstraksie eers by die tweede werklike geval; een geval kry gewone kode.

## Domein
Besluite en name staan in `CONTEXT.md` (`## Besluite`, `## Name`). Sodra Schalk iets besluit of 'n ding 'n naam gee, voeg een reël daar by. Bly 'n verwysing dubbelsinnig: vra watter een. Lang afwegings: `docs/adr/NNNN-slug.md`; terme: `GLOSSARY.md`.

## Sessie-reël
`CONTEXT.md` se kapsule kom by opstart in; die **Status** word net deur `/oorhandig` of op versoek van die konteks-wag herskryf. Die plugin commit en push outomaties aan die einde.

# ytsermon-prosessor

Pipeline: download sermons from the church YouTube channel, trim them, make Shorts, re-upload with playlists and descriptions.

Type: python · Platforms: linux (testing), windows 11 (church PC)

## Opdragte
```
uv sync · uv run python -m sermon --help · uv run python -m unittest
```
Externe tools: `yt-dlp`, `ffmpeg` (op Windows: `winget install yt-dlp.yt-dlp Gyan.FFmpeg`).

## Kontrole
Begin: `uv run python -m sermon process <video-url> --dry-run` op een preek; gesond? geen traceback, die beplande snypunte, titel en beskrywing word gedruk; dryf: `uv run python -m unittest` vir logika, kyk die gesnyde mp4 in `out/` handmatig; bewys: toets-uitset + snypunte/tydsduur van die uitset (`ffprobe`). Oplaai word net met Schalk se ja getoets (eerste keer as `private`).
Sê "klaar" net ná `/bewys` (hierdie resep) geslaag het; anders "ongetoets: {rede}" en die stap vir Schalk.

## Konvensies
- Kode in Engels; gesprek en commit-boodskappe in Afrikaans waar die projek reeds so is.
- Kyk eers in `navorsing/` voor jy iets weer naslaan.
- Groter werk: `/plan` skryf `planne/<slug>.md`, `/bou <slug>` bou dit in die agtergrond op tak `bou/<slug>`. Bug: vind en herstel die bron-oorsaak (reproduseer eers); 'n tweede regmaak van dieselfde fout = soek dieper.
- Voor nuwe kode: hergebruik → stdlib → platform → bestaande afhanklikheid → minimum kode. Grep elke roeper voor 'n regmaak; herstel by die bron.
- Kruisplatform: `pathlib` vir paaie, geen shell-spesifieke opdragte nie (`subprocess` met lyste), sodat dit op Windows loop.
- Hoofstukke (modules, hooks, bevele, skerms, roetes) kry bo-aan 'n `@stelsel`-blok (formaat: `hooks/kaart.py`; `kaart:` in `CONTEXT.md` sê waar). Net hoofstukke; `status: klaar` net via `/bewys`, `stukkend` via `/fout`; verander jy 'n lêer, werk sy blok by. Funksie-kommentaar: reël 1 = wat dit doen (en hoekom, as dit nie voor die hand lê nie); opsioneel `skakel: → hoofstuk.funksie (rede)` en `vloei: <naam>`; klaar → `kaart.py --check`.
- Vloeie (`docs/kaart.html`): `vloei: <naam> | <titel>` met `inleiding:` en `hoekom:`; `stap: <vloei> <n> <titel> | <uitleg>`; formaat: `hooks/kaart.py`.
- Abstraksie eers by die tweede werklike geval; een geval kry gewone kode.

## Domein
Besluite en name staan in `CONTEXT.md` (`## Besluite`, `## Name`). Sodra Schalk iets besluit of 'n ding 'n naam gee, voeg een reël daar by. Bly 'n verwysing dubbelsinnig: vra watter een. Lang afwegings: `docs/adr/NNNN-slug.md`; terme: `GLOSSARY.md`.

## Sessie-reël
`CONTEXT.md` se kapsule kom by opstart in; die **Status** word net deur `/oorhandig` of op versoek van die konteks-wag herskryf. Die plugin commit en push outomaties aan die einde.

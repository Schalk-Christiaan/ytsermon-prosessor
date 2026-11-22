# Hersiening 2026-11-21 (nagskof-poleer)

## Kodehersiening
Handmatige hersiening van `lib/core` (prosesse, JSON-lees, bounds, kanaal) en die plekke in `lib/features` wat lêers of prosesse raak. Gerangskik volgens erns.

| # | Bevinding | Status |
|---|---|---|
| 1 | Beskadigde `sermon.json`/`settings.json` het die app by opstart laat crash. | BEVESTIG, herstel (toetse in `store_test`, `settings_test`) |
| 2 | Gebed ná die preek is op die preek se eie slot-Amen gemerk (`lBMwRt3eIus`, `6s_FFatG0so`). | BEVESTIG, herstel in `Planner.analyse` |
| 3 | `probeMedia` gooi `StateError` vir 'n lêer sonder videostroom (`firstWhere` sonder `orElse`). Net intro/outro-lêers word geprobeer; 'n klankspoor as intro gee 'n rou fout. | Laag, nie herstel nie; lêerkieser wys die fout. |
| 4 | `channelUrl` uit 'n handgewysigde `settings.json` word nie genormaliseer nie; dit gaan as een argument (`$url/videos`) na yt-dlp, dus geen opsie-inspuiting, maar 'n ongeldige URL gee 'n yt-dlp-fout. | Laag, aanvaar. |
| 5 | Kanaal sonder `/videos`- of `/streams`-oortjie laat `listChannel` en `channelName` misluk. | Oop vraag (sien plan). |

Sekuriteit: geen `runInShell`; alle prosesse kry argumentlyste; OAuth-token lê in die platform se geheimstoor; `_killTree` gebruik `pkill -P <pid>` (nommer, nie gebruikersteks nie). Geen bevindinge nie.
Oorbou: geen duidelike nie; `service_timeline.dart` (765) en `sermons_screen.dart` (691) is die grootste lêers maar hoogs kohesief.

## Argitektuur
- Skerms roep geen prosesse direk nie; alles gaan deur `core/` (`runTool`, `JobQueue`). Naatlyn is skoon.
- `ReviewController` (631 reëls) meng spelerbeheer, plan-wysiging en stoor. Voorstel: skei die speler-gedeelte (`playFrom`, `_skipCuts`, `previewCut`) in 'n eie klas. Dit is groot herstrukturering en die toetse dek dit; gaan na `## Vrae`, nie hierdie plan nie.
- Geen veranderinge in stap 8 nie: geen voorstel behou gedrag EN verwyder kode sonder risiko nie.

## Persona-kritiek
Gebaseer op die bestaande toets-kiekies (`docs/kiekies/nagskof/voor/`), die kode en een kort looptyd van die Linux-app (Opstelling by 734 breed).
- **Oom Koos:** Opstelling-stap 3 het gesê "Die kerk se YouTube-kanaal is gekoppel" met "kliënt-ID-lêer": verwarrend, en dit is nie sy kanaal wat gekoppel word nie, maar sy rekening vir oplaai. *Herstel: teks is nou "Jou YouTube-rekening is gekoppel (om op te laai)".* Verder: Ollama/yt-dlp-terme in Stelsel is vir Schalk, nie vir hom nie; die foute noem nie altyd wat om te doen nie.
- **Ds. Marais:** Titel, Skriflesing en datum is in Hersien, maar die beskrywing-voorskou lê onder 'n oortjie. Aanvaar vir nou (kenmerk: voorskou by "Keur goed").
- **Schalk:** sneltoetse i/o/Ctrl+Z bestaan in die redigeerder; geen sneltoets vir "Verwerk nuutste diens" nie. Log is sigbaar by Werk.
- **Mev. Venter:** kyk net die uitset; klankgrootte en onderskrifte is gedek deur die bestaande `ffprobe`-bewys (E2E).
- **Skriba van 'n ander gemeente:** die kanaalveld is nou eerste in Opstelling (gedoen). Ollama-installasie word genoem maar nie gekoppel nie; die album-etiket sê steeds "GK Oranjerivier" (sien Vrae in die plan).

## Kenmerke
Gebou: (1) kanaalveld in Opstelling/Instellings; (2) Tab/40 px-toets op alle skerms; (3) kopieerbare teks (`SelectionArea` om die skerm-inhoud); (4) Opstelling-teks sonder jargon.
Vir Schalk (nie gebou): beskrywing-voorskou by "Keur goed"; kerknaam-instelling vir die album-etiket; ReviewController-splitsing; bondel-installeerder-gids vir Ollama.

## Vloeie
Nie in die regte app deurgeloop nie (geen muis/ydotool beskikbaar; blinde sleutelbord-bestuur het Hersien bereik maar die Opstelling-vloei nie betroubaar gewys nie). Gedek deur toetse: opstelling, preke, hersien, werk, biblioteek, instellings (widget-toetse met kiekies in `docs/kiekies/nagskof/voor/`), E2E vir die kern. Ongetoets: vloei a (regte app), c (nuwe kanaal, regte app) en die ná-kiekies.
Kanaal-validasie met yt-dlp is wel met `https://www.youtube.com/@NASA/videos` bevestig (kanaalnaam "NASA").

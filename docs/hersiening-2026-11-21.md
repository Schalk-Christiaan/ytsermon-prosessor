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

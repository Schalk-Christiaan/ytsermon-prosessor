status: oop

# Hoofplan: Preekverwerker (Flutter-desktop vir die kerk-PC)

Padkaart. Elke fase kry sy eie `planne/fase-N-*.md` wat `/bou` alleen kan bou; net fase 1 is reeds uitgewerk. Feite agter die keuses: `navorsing/2026-11-19-youtube-api-en-preekgrense.md`.

## Doel
Een app op die kerk-PC wat sonder Claude of internet-KI die hele weg loop: kanaal lees → preek vind → mens hersien → sny (preek + Shorts) → oplaai in snitlyste → klank vir WhatsApp. Die mens se enigste werk is hersien en goedkeur.

## Argitektuur

```
Flutter-app (Dart, een exe)
 ├─ lib/core/           suiwer Dart, getoets met flutter test, geen widgets nie
 │   tools.dart         vind yt-dlp/ffmpeg/ollama (langs die exe, dan PATH); Process.start met lyste
 │   channel.dart       yt-dlp: lys strome (/streams + /videos), info.json, af-orig json3
 │   captions.dart      json3 → segmente; kompakteer vir die LLM; SRT vir Shorts; spraak/musiek-tydlyn
 │   planner.dart       Ollama /api/chat (dart:io HttpClient, JSON-skema) → SermonPlan; valideer
 │   cutter.dart        ffmpeg: preek (-c copy), Shorts (9:16 + onderskrif), klank vir WhatsApp
 │   uploader.dart      googleapis YouTube v3 + googleapis_auth (desktop-OAuth, loopback)
 │   playlists.dart     reëls: Bybelboek uit "Skriflesing:", reeks, prediker → snitlysnaam
 │   store.dart         een JSON per preek in app-support-gids (geen databasis vir ~350 rekords)
 │   jobs.dart          een werkry, een taak op 'n slag, hervat ná herbegin
 ├─ lib/features/       skerms (sien hieronder), ChangeNotifier + ListenableBuilder (geen state-pakket)
 ├─ lib/app/theme.dart  ontwerpstelsel (tokens hieronder)
 └─ lib/l10n/app_af.arb alle teks; Afrikaans eerste, en.arb later
Installeerder (Inno Setup, per gebruiker in %LOCALAPPDATA%, sodat `yt-dlp -U` kan skryf)
 ├─ app + yt-dlp.exe + ffmpeg.exe/ffprobe.exe
 └─ OllamaSetup.exe (stil); qwen3:8b (5 GB) word by eerste begin deur die app afgelaai
```

Pakkette (elk met rede): `media_kit` (+ `media_kit_video`, `media_kit_libs_video`): videovoorskou met soek op Windows/Linux, nodig vir hersien. `googleapis`, `googleapis_auth`: oplaai/snitlyste. `flutter_secure_storage`: refresh-token in Windows Credential Manager (nie platte teks nie). `path_provider`, `path`, `intl`/`flutter_localizations`. Niks anders sonder rede in die fase-plan nie.

Toestand van 'n preek (een veld, een betekenis, ook in die UI met woord + ikoon):
`nuut → beplan → goedgekeur → gesny → opgelaai`, plus `fout` (met boodskap en "Probeer weer") en `oorgeslaan`.

## Ontwerpstelsel

Modus: **Bedien**. Sien DESIGN.md. Bekende Material 3-desktoppatrone; die identiteit leef in palet, tipe en een kenmerkende skuif. Gebruikstoneel: een vrywilliger in die kerkkantoor, oordag, Maandag ná die diens; lig tema as verstek, donker ontwerp en beskikbaar (volg stelsel).

**Grond in die onderwerp:** 'n Gereformeerde kerk aan die Oranjerivier: kansel van hout, die Woord in druk, die rivier.

| Rol | Lig | Donker | Rede |
|---|---|---|---|
| Grond (`surface`) | Karoo-wit `#F4F0E8` | Karoo-nag `#1C1915` | gebleikte klip en kalk; aards (gewysig deur desktop-poleer) |
| Ink (`onSurface`) | `#2B2620` | `#EDE6DA` | vol ink vir lopende teks |
| Aksie (`primary`) | Oranje `#B34E17` | `#F08A4B` | "doen dit": die rivier se naam; net vir primêre aksies en die preek-hakie |
| Seleksie/inligting (`secondary`) | Karoobos `#5A6B47` | `#A9BC93` | geselekteerde ry, vordering, inligting |
| Kanselhout (`tertiary`) | `#6B4A32` | `#C9A27E` | Shorts-merkers op die tydlyn, niks anders nie |
| Fout / sukses | `#B3261E` / `#2A7549` | `#F2B8B5` / `#8FD1A6` | altyd met ikoon + woord |

Bou met `ColorScheme.fromSeed(seedColor: oranje)` en oorskryf die rolle hierbo; vlakke deur `surfaceContainer*`, geen lukrake skaduwees. Kontras ≥ 4.5:1 vir teks, 3:1 vir rande en knoppievlakke, in albei temas; kontroleer met 'n klein toets in `test/theme_contrast_test.dart`.

**Tipe** (twee gesinne, ingebind as bates, geen netwerk):
- *Source Serif 4* vir preektitels en skermopskrifte (`display`/`headline`): die preek is gedrukte Woord, die serif dra dit.
- *Source Sans 3* vir alle UI (`title`/`body`/`label`): dieselfde familie, leesbaar op klein groottes, nie Inter/Roboto-verstek nie.
- Skaal deur Material-rolle, stappe ≥ 1.25×; liggaam 14–16 sp; `FontFeature.tabularFigures()` op alle tye (`23:04`) en tellings. Volg stelsel-teksgrootte.

**Spasie:** 4-basis (4/8/12/16/24/32/48). Lyste dig (rye 56 dp), hersien-paneel ruim. Venster minimum 1100×720; uitleg werk tot 1920 breed.

**Ikone:** Material Symbols Rounded, een lynwydte.

**Kenmerkende skuif: die dienstydlyn.** 'n Horisontale strook van die hele diens: spraak (rivier, gedemp) en sang/musiek (kanselhout-tint, gestreep nie, net 'n ander toon + etiket "Sang") uit die onderskrif-merkers, met die **preek as 'n oranje hakie** wat jy aan albei punte kan sleep (en met pyltjiesleutels per 5 s skuif), en Shorts as klein houtkleur-blokke daarbinne. Klik op die tydlyn soek die video. Dit is die skerm se eerste blik en die een ding wat net hierdie app het.
- **Een outeursmoment:** wanneer die KI se plan inkom, gly die hakie van die volle breedte na die preek se grense (400 ms, `Curves.easeOutCubic`); met verminderde beweging spring dit direk.
- Beweging verder net vir terugvoer: knoppies reageer by druk, toestandwissels 150–300 ms, skerm-oorgange fade-through.

**Weier:** geen statistiek-kaarte ("321 preke!"), geen kicker-etikette, geen ikoon-teëls bo opskrifte, geen gradiënte, geen emoji, geen modale vir dinge wat nie hoef te onderbreek nie, geen pulserende kolletjies nie.

## Skerms

Navigasie: `NavigationRail` links (vier bestemmings) + Instellings onder in die rail. Sleutelbord: Ctrl+F soek, Ctrl+Enter = primêre aksie van die skerm, Esc = terug.

1. **Preke** (tuis). Taak: kies wat volgende verwerk word.
   - Lys (`ListView.builder`): datum (tabulêr), preektitel (serif), Skriflesing, toestand-chip (ikoon + woord). Filter-chips per toestand, soek.
   - Primêre aksie: **"Verwerk volgende"** (neem die oudste `nuut`, of geselekteerdes) → werkry. Ry-klik → Hersien.
   - Leeg (geen kanaal gekoppel): "Koppel die kerk se YouTube-kanaal om preke te sien." + knoppie "Koppel kanaal". Laai: skelet-rye. Fout (yt-dlp misluk): wat gebeur het + "Probeer weer" + "Werk yt-dlp by".
   - Nuwe dienste word by elke begin opgespoor ("2 nuwe dienste sedert Sondag").
2. **Hersien** (een preek). Taak: keur die snit, titel en beskrywing goed.
   - Bo: video-voorskou (links, 16:9) + metadata-paneel (regs): titel (≤ 100, teller), beskrywing (≤ 5000, teller), snitlys (voorgestel, veranderbaar).
   - Onder oor die volle breedte: **dienstydlyn** met preek-hakie en Shorts; onder dit die Shorts-lys: per Short 'n 9:16-voorskouraam, tyd, titel, "Verwyder"; "Voeg Short by" by die huidige speelposisie.
   - Primêre aksie: **"Keur goed en sny"**. Sekondêr: "Beplan weer" (vra bevestiging: "Jou wysigings aan titel en snit gaan verlore"), "Slaan oor".
   - Laai (Ollama dink, minute op CPU): vorderingsboodskap met fase ("Lees onderskrifte…", "Soek die preek…") en verstreke tyd; die skerm bly bruikbaar. Fout: "Die KI het nie 'n geldige plan gegee nie (preek van 3 min)." + "Beplan weer" of "Stel self in" (hakie handmatig).
   - Geen outomatiese stoor-verlies: elke wysiging stoor dadelik in die preek se JSON ("Gestoor").
3. **Werk** (werkry). Taak: sien wat besig is en herstel foute.
   - Huidige taak bo met fase, persentasie (ffmpeg/yt-dlp vordering) en "Kanselleer"; daaronder wag- en klaar-lys. Foute met gewone-taal boodskap + "Probeer weer"; tegniese log invoubaar.
   - Klaar-items: "Speel", "Wys in gids", "Klank vir WhatsApp".
4. **Snitlyste.** Taak: bepaal hoe preke gegroepeer word.
   - Reëls in volgorde (Bybelboek uit Skriflesing, reeks uit titel, prediker, jaar), elk aan/af; voorskou: "Mattheus 12 → snitlys 'Mattheus' (14 preke)". Bestaande snitlyste op die kanaal word hergebruik, nie gedupliseer nie.
5. **Instellings** (gegroepeerde lys, nie kaarte nie): Kanaal (gekoppel as …, "Ontkoppel"), KI-model (Ollama-status, model, "Laai model af" met vordering), Oplaai-verstek (privaat / ongelys / publiek; verstek privaat tot die eerste paar goed lyk), Uitsetgids, WhatsApp-klank (formaat), Stelsel (yt-dlp/ffmpeg/Ollama weergawe + groen/rooi met woord, "Werk yt-dlp by").
- **Eerste begin: Opstelling-lys** (nie 'n modale towenaar nie): 'n skerm met vier stappe wat elk afgemerk word: Ollama loop → model afgelaai (5 GB, vorderingsbalk, kan op agtergrond) → YouTube gekoppel → uitsetgids. Elke stap het een knoppie; klaar → Preke.

## Fases

1. **Enjin + Hersien op een preek** (Linux). `planne/fase-1-enjin-en-hersien.md`. Projek skep, tema, `core/` (tools, channel, captions, planner, cutter), Hersien-skerm met tydlyn en video, sny preek + Shorts na `out/`.
2. **Preke-lys, werkry en stoor.** Hele kanaal lys, toestande, werkry met hervat, Werk-skerm, "Verwerk volgende", opsporing van nuwe dienste.
3. **Oplaai en snitlyste.** Google Cloud-projek (Schalk skep eenmalig; app op "In production" sodat tokens nie ná 7 dae verval nie), desktop-OAuth, hervatbare oplaai (100/dag-perk gerespekteer met 'n teller), snitlysreëls + skerm, beskrywingsjabloon. Eerste oplaaie privaat.
4. **WhatsApp-klank en afronding.** Klank: mono mp3 64 kbps (~20 MB vir 40 min, onder WhatsApp se 100 MB), lêernaam `JJJJ-MM-DD Tema.mp3`, ID3-titel; "Wys in gids" (`explorer /select,` op Windows, `xdg-open` op Linux). Ondersoek Windows se deelpaneel (`share_plus`) as tweede weg (onbewys of dit lêers na WhatsApp Desktop deel). Leeg/laai/fout-toestande en kritiekronde op alle skerms.
5. **Installeerder en die kerk-PC.** `.github/workflows/windows.yml` (windows-latest): `flutter build windows`, laai vasgepende `yt-dlp.exe`, ffmpeg (gyan essentials) en `OllamaSetup.exe`, `iscc installer/setup.iss` → `Setup.exe`-artefak/Release. Opstelling-lys in die app. Eerste installasie op die kerk-PC saam met Schalk. Ongetekende exe → SmartScreen-waarskuwing ("Meer inligting → Hardloop tog"); kodeondertekening is buite bestek.

## Aanvaarding (einde van fase 5)
- Op 'n skoon Windows 11: `Setup.exe` installeer sonder admin, die app maak oop, die Opstelling-lys bring dit tot groen sonder 'n terminaal.
- Een preek gaan van `nuut` tot `opgelaai` met net hersien + "Keur goed en sny" + oplaai; video verskyn in die regte snitlys met titel en beskrywing.
- Klanklêer < 100 MB en speel in WhatsApp Desktop.
- `flutter test` slaag; skermkiekies van elke skerm in lig en donker, by 1100×720 en 1920×1080, sonder oorloop.

## Buite bestek (vir nou)
Whisper, outomatiese weeklikse verwerking sonder om die app oop te maak (Windows-taakskeduleerder), podcast/RSS, webwerf-preeklys, kodeondertekening, Engelse vertaling.
- Later (Schalk, 2026-11-22): NVENC (`h264_nvenc`) op die kerk-PC se RTX 3050 met terugval na `libx264` in `lib/core/cutter.dart`; eers meet op die skootrekenaar.

## Vrae
- Wie gebruik die app op die kerk-PC (een persoon of meer)? Bepaal of die Opstelling-lys moet verduidelik wat 'n Short is.
- Moet die oorspronklike volle diens op die kanaal bly (aanname: ja, die nuwe video's is ekstra)?

## Log

## Verslag

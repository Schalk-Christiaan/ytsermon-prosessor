# DESIGN (enigste bron van tokens; kode: `lib/app/theme.dart`)

Modus Bedien. Kenmerkende skuif: die dienstydlyn met bane (klank, diens, Shorts) en 'n oranje speelkop.

## Kleurrolle (lig / donker)
| Rol | Lig | Donker |
|---|---|---|
| grond `surface` | kalksteen #F3F4F1 | leiklip #161D1F |
| paneel | #FFFFFF (surfaceContainerLowest) | #1E2729 (surfaceContainer) |
| ink `onSurface` | #1B2629 | #E6EBEA |
| aksie `primary` (primêre knoppie, speelkop, preek-hakie) | oranje #B34E17 | #F08A4B |
| seleksie `secondaryContainer` (rail-item, oortjie, gekose ry) | rivier-tint #DCEBE9 | #24403E |
| rivier `secondary` | #2C6A66 | #7FC4BD |
| kanselhout `tertiary` (Shorts, sang-baan) | #6B4A32 | #C9A27E |
| fout / sukses | #B3261E / #2E7D4F | #F2B8B5 / #8FD1A6 |

Oranje besit net: die primêre aksie, die speelkop, die preek-hakie.

## Vorm en spasie
Panele: vlak, geen skaduwee, radius 16, 12 dp tussen panele. Spasie 4/8/12/16/24/32/48.

## Tipe
Source Serif 4 (display/headline: preektitels), Source Sans 3 (alles anders). Tye tabulêr. Skaal deur Material-rolle.

## Kontroles
Elke slider het 'n syferveld (`23:04`) en Herstel. Elke ikoonknoppie het 'n tooltip en Semantics. Ikone: Material Rounded. Elke kontrole het 'n `ctl.<skerm>.<aksie>`-sleutel (`test/controls_inventory.dart`).

## Weier
Gradiënte, gloei, glas, kaart-in-kaart, kicker-etikette, Inter/Roboto.

# Credits & licensing — Lake Cleanup

Status: ✅ cleared as-is · ⚠️ action needed before shipping · ❓ needs confirmation/input

This file tracks where every third-party asset in the game comes from and whether its
license actually covers shipping this game. Update it whenever an asset is added, swapped,
or its licensing status changes — it should always reflect reality, not aspiration.

## Art

The in-game credits board (`scripts/credits_board.gd`) lists every pack below under a single
"Art and Assets" heading, in each pack's **own required credit wording** and with no mention
of what the asset is (Richard, 2026-09-16). This file is the only place the asset → pack
mapping and the licence status live, so keep it current when either changes. AI-generated
art is credited nowhere, by decision.

The board carries three other headings — "Design and programming", "Music and sound" and,
since 2026-09-19, "Tools" (see below). "Art and Assets" is still the one heading every art
pack stands under; nothing about an art pack goes anywhere else on that board.

- **Decoration and small objects** (`art_source/Decoration_Clean_Dirty.psd` →
  `assets/decor_clean.png` / `decor_dirty.png`, and the earlier
  `TopDownHouse_SmallItems.png`, `TopDownHouse_FurnitureState1.png`,
  `TopDownHouse_FurnitureState2.png`) — "Top-Down Retro Interior" by Penzilla
  (https://penzilla.itch.io/top-down-retro-interior). ⚠️ **Not cleared.** Commercial use
  requires purchasing the pack (suggested $8 minimum) plus the credit "Graphics created by
  Penzilla Design." Credited on the board as of 2026-09-16; still unpurchased.
  **Action: purchase before shipping.**

- **Decoration and small objects** (same art) — "Modern Interiors" by LimeZu
  (https://limezu.itch.io/moderninteriors, free-version overview:
  https://limezu.itch.io/moderninteriors/devlog/244045/free-version-overview-18042021-update).
  ⚠️ **Not cleared.** The free version's licence is **non-commercial only** ("You CAN use the
  asset for non commercial purposes"); the paid version is what covers shipping. Credited on
  the board as of 2026-09-16 as "Modern Interiors by LimeZu" — the pack's `LICENSE.txt` may
  name an exact string, which has not been read. **Action: purchase the commercial version
  before shipping, and check the required wording against `LICENSE.txt`.**

- **Dogs** (`assets/dog*`, `scripts/dog.gd`'s art) — "Pixel Dogs" by Benvictus
  (https://benvictus.itch.io/pixel-dogs). ✅ Cleared (purchased/licensed by Richard,
  2026-09-16). Name-your-own-price; the author allows commercial use and asks for a credit
  where there's no contribution. Credited as "Benvictus".

- **Recycle box** (`assets/Recycle_Box.png`, and everything painted out of its wood — the
  piers, the ferry's hull, the shed's walls) — by xStrax (https://straxportfolio.carrd.co/).
  ✅ Cleared (2026-09-16). No public licence terms; the portfolio is the credit link.

- **Forest, grass and sand tiles** (`assets/forest*`, the ground atlas `Ground._pack_props`
  packs, the master palette in `resources/palette.tres`) — "[FREE] 2d isometric forest Pixel
  art - 32x32" by Kipperfalcon (https://kipperfalcon.itch.io/2d-isometric-forest-pixel-art).
  ✅ **CC0 for the art**, free for commercial use, modification allowed; redistribution and
  AI training are not. Credit is appreciated, not required — given anyway as "Kipperfalcon".

- **Shed** (`assets/shed.png`, via `art_source/shed_tan.png` → `tools/downres_shed.py` →
  `tools/recolor_shed.py`) — "Isoverse Medieval Outdoors" by Zato Pixel Cultist
  (https://zatoart.itch.io/isoverse-medieval-outdoors). ✅ Cleared (purchased 2026-09-16).
  **CC BY 4.0**, which makes the attribution mandatory and fixes its wording: the board
  carries the pack's own string, `Asset by Zato - https://zatoart.itch.io/`, verbatim. NFTs
  and AI training are prohibited; redistribution of the assets is too.

- **Ferry hull** (`art_source/Blue_Boat/blue_boat_16dir.png` → `assets/boat_sail_frames.png`)
  — PixZels, credited @Pixel_Salvaje. ❓ Licence terms and purchase status not recorded here;
  the credit is on the board. **Action: confirm and write the terms down.**

- **Pigeon sprites** (`assets/Pigeons/`, `pigeon_contact.png`, `pigeons.json`) — "Pigeons 2D
  Pixel Asset Pack" by Pop Shop Packs (https://pop-shop-packs.itch.io/pigeons-2d-pixel-asset-pack).
  ✅ Commercial use explicitly allowed; credit appreciated, not required.

- **Net_Cast_spritesheet.jpg, Net_Closing_Drag.jpg, Net_Upgrades_Menu.jpg** — AI-generated.
  Decision (2026-09-06): keep as-is, not disclosed as AI-generated. Fact check on that
  decision: itch.io's generative-AI disclosure requirement is **mandatory only for asset
  packs published for reuse by other developers**; for a finished game like this one,
  disclosure is currently "encouraged," not enforced (no de-indexing risk for a game page).
  Two things this doesn't cover: (1) itch.io's stance has been tightening and could change;
  (2) if this ever reaches Steam, Steam's AI-disclosure requirement on the store page *is*
  mandatory today, unlike itch's. Also worth knowing regardless of platform rules: purely
  AI-generated art may not be copyrightable in some jurisdictions (notably the US), meaning
  this specific net art could be freely copied by others without legal recourse. Not a
  lawyer — flagging the facts, the keep-and-don't-disclose call stands as made.

- **UI_Buttons.jpg, ui.png** — AI-generated placeholder. Flagged as feeling "ugly" —
  planned for a rework later (design/quality issue, not a licensing one). `shed.png` used to
  be listed here; it is Zato's pack art now (see **Shed** above), corrected 2026-09-16.

- **character.png (angler)** — AI-generated with [PixelLab](https://pixellab.ai/), then
  hand-fixed by Richard in `art_source/Character_Sprite_Sheet.psd`. Same AI-disclosure notes
  as the net art above apply.

## Font

- **Bungee-Regular.ttf** — Google Font by David Jonathan Ross, "Bungee" family. ✅ **SIL Open
  Font License 1.1** (`assets/Bungee-OFL.txt`, bundled with the download) — free for
  commercial use, no attribution required. Wired in 2026-09-06 as the display face for the
  settings/shed panels and the trophy/defeat/farewell screens, replacing RubbishFont2 below.

- **RubbishFont2-Regular.ttf** — "Rubbish" by Nathan Thomson (dafont.com). ⚠️ Was **not
  cleared** (personal-use only; commercial use needed the author's sign-off, never obtained).
  No longer referenced anywhere in code as of the Bungee swap above — the concern is moot
  unless it gets used again. The file itself is still sitting in `assets/`; safe to delete
  whenever, not done here since deleting isn't this pass's job.

## Music and Sound

**Every piece of music and every recorded sound in the game is by Nuven** (Spotify:
open.spotify.com/artist/3Cdtqtl7PvG7793m9pkg34; Richard, 2026-09-15). ✅ Personal
license/agreement in place with the artist (confirmed 2026-09-06).

- **Music**, `assets/music/`, built from `art_source/Music` by `tools/build_music.py` (the
  `_radio` files are the same songs filtered): "beatgucci (Zé)" (`beatgucci`), "Save ME"
  (`save_me`), "Goin (edit2)" (`goin`, byte for byte the file that was `music_goin.mp3`),
  "INDIE BOI" (`indie_boi_radio`), "Habibs 2" (`habibs`).
- **Sound effects**, `assets/sfx/`, cut from the recordings in `art_source/SFX` by
  `tools/build_sfx.py`. The few sounds still built in code (`scripts/sfx.gd`) are
  arithmetic, not recordings.

- **The Spotify mark** beside Nuven on the credits board (`assets/ui/spotify_icon.png`) —
  Spotify's own icon, downloaded from their design guidelines
  (https://developer.spotify.com/documentation/design) and only trimmed, squared and
  resampled by `tools/build_spotify_icon.py`. ✅ Their guidelines allow the mark to point at
  Spotify content; they forbid redrawing, recolouring or distorting it, so it is never
  rebuilt in code and never tinted. Decoration only — it is not a link (2026-09-16).

## Tools

- **Godot Engine** (https://godotengine.org) — the engine the game is built and exported
  with. ✅ **MIT licence**, which asks only that the licence text travel with copies of the
  *engine's own source*; a game made with it owes no attribution at all. Credited anyway on
  the board as "Made with Godot Engine" under a **Tools** heading (Richard, 2026-09-19),
  because a player has nowhere else to look it up. **This is the only entry in this file
  that is not a licence obligation.**

- **Not credited, deliberately**: Bungee (SIL OFL 1.1 asks for no attribution — see **Font**
  above), PixelLab (the AI tool behind the angler sheet, covered by the AI-art decision
  under **Art**), ffmpeg and the psd-extract pipeline (build-time only, nothing of theirs
  ships). A list of everything that asks for nothing has no end; the board carries the
  required credits and one courtesy.

## Not yet reviewed

Anything not listed above (e.g. remaining UI pieces, any other unattributed asset added
later) hasn't been checked for this pass — don't assume it's clear just because it's absent
from this file.

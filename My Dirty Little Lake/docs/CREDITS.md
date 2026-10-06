# Credits & licensing — My Dirty Little Lake

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
  (https://penzilla.itch.io/top-down-retro-interior). ✅ Cleared (purchased 2026-09-20).
  Name-your-own-price; commercial use requires paying the suggested price, and the licence
  (`PenzillaDesign_StandardLicense.pdf`, in the zip) names the credit wording. The board
  carries that string verbatim: `Graphics created by Penzilla Design`. The bought zip is
  `art_source/Top-Down_Retro_Interior.zip`.

- **Decoration and small objects** (same art) — "Modern Interiors" by LimeZu
  (https://limezu.itch.io/moderninteriors, free-version overview:
  https://limezu.itch.io/moderninteriors/devlog/244045/free-version-overview-18042021-update).
  ✅ Cleared (complete version purchased 2026-09-20). The **free** version is
  non-commercial only; the complete version (paying at least $1.50) allows commercial use
  and editing, forbids reselling or redistributing the assets, and **requires a credit with
  the pack's link** — so the board's line is the link itself, `limezu.itch.io`, not
  "Modern Interiors by LimeZu" as it read until this purchase. The bought zip is
  `art_source/moderninteriors-win.zip`.

- **Dogs** (`assets/dogs/`, three breeds off `art_source/PixelDogsSprites`, `scripts/dog.gd`'s art) — "Pixel Dogs" by Benvictus
  (https://benvictus.itch.io/pixel-dogs). ✅ Cleared (purchased/licensed by Richard,
  2026-09-16). Name-your-own-price; the author allows commercial use and asks for a credit
  where there's no contribution. Credited as "Benvictus". The game's icon (`icon.png`,
  `icon.ico`, the Steam icons, `tools/build_icon.py`) is the orange dog's first sit frame
  from this pack.

- **Recycle box** (`assets/Recycle_Box.png`, and everything painted out of its wood — the
  piers, the ferry's hull, the shed's walls) — by xStrax (https://straxportfolio.carrd.co/).
  ✅ Cleared (2026-09-16). No public licence terms; the portfolio is the credit link.

- **Forest, grass and sand tiles** (`assets/forest*`, the ground atlas `Ground._pack_props`
  packs, the master palette in `resources/palette.tres`) — "[FREE] 2d isometric forest Pixel
  art - 32x32" by Kipperfalcon (https://kipperfalcon.itch.io/2d-isometric-forest-pixel-art).
  ✅ **CC0 for the art**, free for commercial use, modification allowed; redistribution and
  AI training are not. Credit is appreciated, not required — given anyway as "Kipperfalcon".

- **Input prompts** (`assets/ui/prompts/`, cut by `tools/build_prompts.py` off
  `art_source/kenney_inputPromptsPixel16×/`; the first-steps hints and every pad button glyph,
  Xbox and PlayStation) — "Input Prompts Pixel 16×"
  by Kenney (https://kenney.nl). ✅ **CC0**, `License.txt` beside the tiles. Credit is not
  required; given anyway as "Kenney", the Kipperfalcon rule.

- **Shed** (until 2026-10-01 `assets/shed.png`, via `art_source/shed_tan.png` → `tools/downres_shed.py` →
  `tools/recolor_shed.py`; now `assets/shed_*.png`, rule-built by `tools/build_shed_v2.py` on
  the old hut's outline only, no pixels of the pack — whether the credit is still owed is open) — "Isoverse Medieval Outdoors" by Zato Pixel Cultist
  (https://zatoart.itch.io/isoverse-medieval-outdoors). ✅ Cleared (purchased 2026-09-16).
  **CC BY 4.0**, which makes the attribution mandatory and fixes its wording: the board
  carries the pack's own string, `Asset by Zato - https://zatoart.itch.io/`, verbatim. NFTs
  and AI training are prohibited; redistribution of the assets is too.

- **Ferry hull** (`art_source/Blue_Boat/blue_boat_16dir.png` → `assets/boat_sail_frames.png`)
  — "Free Pixelart Boats (16 directions)" by @pixel_Salvaje
  (https://pixel-salvaje.itch.io/free-boat-16-directions). ✅ Cleared (2026-09-20,
  Richard: downloaded free from itch). Name-your-own-price, billed as "Free to use boats",
  no further terms stated. Nothing is owed; the credit `@Pixel_Salvaje` is on the board as a
  courtesy. (`PixZels` is the author's pixel-art *program*, not the pack — this file used to
  name it as the source.)

- **Pigeon sprites** (`art_source/Pigeons/` → `assets/pigeons_inked.png`, `pigeons.json`) — "Pigeons 2D
  Pixel Asset Pack" by Pop Shop Packs (https://pop-shop-packs.itch.io/pigeons-2d-pixel-asset-pack).
  ✅ Commercial use explicitly allowed; credit appreciated, not required.

- **Songbirds** (`art_source/birds/` → halved into `assets/wildlife/critters.png` by
  `tools/build_wildlife.py`, `bird_<species>_*`; sparrow, tit, bluebird and cardinal — the
  cockatoo and the parrot are in the folder and not used) — "Wild Birds - 32x32 Animated
  Birds" by Kelano Studio (https://kelano-studio.itch.io/wild-birds). ✅ Cleared (purchased
  by Richard, 2026-10-03). "Free for personal and commercial projects. Don't resell or
  redistribute the assets themselves." Credit is not asked for; given anyway as
  "Kelano Studio", the Kipperfalcon rule.

- **Land animals** (`art_source/Fauna/` → cut into `assets/wildlife/critters.png` by
  `tools/build_wildlife.py`, the fauna pass of 2026-10-05):
  - Bunnies (`bunny_<coat>_*`: Brown2Color, BunnyBlack, WhiteBunny) — "Bunny Pixel
    Animations Mega Pack" by Toffeecraft (https://toffeecraft.itch.io/bunny-pixel-animations-mega-pack).
    ✅ Cleared: Richard bought the paid pack (2026-10-05), "For commercial or personal use",
    no redistribution or resale. The frames are cut from the `AllBunniesFree` folder, the same
    drawings. Credit not asked for, given as "Toffeecraft".
  - Turtle (`turtle_<anim>*`: Idle, Sit, Sleep, Hide, Walking, from `art_source/Fauna/TurtlePaid`)
    — Toffeecraft's turtle pack (https://toffeecraft.itch.io/), the bunnies' artist. ✅ Bought
    by Richard (2026-10-05), the paid pack. Credited with the bunnies, "Toffeecraft".
  - Round trees, forest-floor wood and plants (`assets/trees/round_dark.png`, `round_light.png`,
    `floor.png` by `tools/build_trees.py`; the `pk_*` and `shrub_pk_*` entries of
    `assets/flora.png` by `tools/build_flora.py`, from `art_source/Fauna/AnimatedTreesUpdates`
    and `art_source/Fauna/LakePlants`) — Toffeecraft's animated trees and lake plants, the
    bunnies' artist. ✅ Bought by Richard (2026-10-05) in the same mega deal as the bunnies.
    Credited with them, "Toffeecraft".
  - Snakes (`snake_<coat>_*`: SnakeBlue, SnakeCorn) — "Snake Sprites" by Carysaurus
    (https://carysaurus.itch.io/snake-sprites). ✅ Free and commercial; no redistribution or
    resale. **Credit must be given**: "Carysaurus" on the board.
  - Fox and wolf (`fox_*`: MiniFox [Original], `wolf_*`: MiniWolf [Metal]) — "Wolf and Fox
    Forest Animals Mod" by LapizWCG (https://lapizwcg.itch.io/wolf-and-fox-forest-animals-mod-by-lapizwcg),
    recoloured from "MiniFolks - Forest Animals" by LYASeeK (https://lyaseek.itch.io/miniffanimals).
    ✅ "You can use this asset as you like, just don't resell it." Credit not required;
    given to both, "LYASeeK" and "LapizWCG".
  - Capybara (`capy_*`) — "Capybara Sprite Sheet" by Rainloaf
    (https://rainloaf.itch.io/capybara-sprite-sheet). ✅ Free or commercial work "with credit
    to me (Rainloaf)": "Rainloaf" on the board.
  - Peacock (`peacock_*`, `Peacock-folded-tail-Sheet.png`, `Peacock-walk-Sheet.png`) —
    "Pixel Art Creature Animal - Peacock (Free)" by Pixeline
    (https://pixeline-k.itch.io/pixel-art-creature-animal-peacock-free). ✅ "You can use this
    asset for personal and commercial purpose (excluding printing and reditribiuting on
    physical objects)"; may be edited, not resold or redistributed. Credit not asked for;
    given as "Pixeline", the Kipperfalcon rule.

- **Net_Cast_spritesheet.jpg, Net_Closing_Drag.jpg, Net_Upgrades_Menu.jpg** — AI-generated.
  The two net sheets are retired (2026-10-02): the net is drawn by rule in code
  (`scripts/net_shape.gd`, `shaders/net_mesh.gdshader`), and the JPEGs sit in
  `art_source/retired_assets/net/`, which does not ship.
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

- **UI_Buttons.jpg, ui.png** — AI-generated placeholders, never drawn; deleted 2026-10-03
  with `tools/slice_ui.gd` and `tools/slice_shed.gd`. The angler is the only AI art in the build.

- **character.png (angler)** — AI-generated with [PixelLab](https://pixellab.ai/), then
  hand-fixed by Richard in `art_source/Character_Sprite_Sheet.psd`. Same AI-disclosure notes
  as the net art above apply.

- **assets/ui/flags/*.png (language flags)** — DaFluffyPotato's 15x10 pixel flags (`marketing/flags_15x10/`). Free to use, credit not required but appreciated; credited on the in-game credits board as "Flags by DaFluffyPotato". Nine copied: us, br, es, de, fr, jp, cn, kr and unknown (the debug pseudo-locale). Added 2026-09-26 for the language chooser.

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

- **GodotSteam** (https://godotsteam.com, `addons/godotsteam/`, GDExtension 4.23,
  2026-10-06) — the bridge to Steam's achievements. ✅ **MIT licence**, and unlike the
  engine its compiled library ships with the game (`libgodotsteam…dll`), so the licence
  text has to travel with it: **copy `addons/godotsteam/license.md` beside the exported exe
  as `GodotSteam_LICENSE.md`** with every build. Not on the credits board, by the rule
  below. `steam_api64.dll` is Valve's redistributable under the Steamworks SDK Access
  Agreement the studio signed with the app; nothing to credit.

- **Not credited, deliberately**: Bungee (SIL OFL 1.1 asks for no attribution — see **Font**
  above), PixelLab (the AI tool behind the angler sheet, covered by the AI-art decision
  under **Art**), ffmpeg and the psd-extract pipeline (build-time only, nothing of theirs
  ships). A list of everything that asks for nothing has no end; the board carries the
  required credits and one courtesy.

## Not yet reviewed

Anything not listed above (e.g. remaining UI pieces, any other unattributed asset added
later) hasn't been checked for this pass — don't assume it's clear just because it's absent
from this file.

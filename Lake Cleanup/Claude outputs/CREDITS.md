# Credits & licensing — Lake Cleanup

Status: ✅ cleared as-is · ⚠️ action needed before shipping · ❓ needs confirmation/input

This file tracks where every third-party asset in the game comes from and whether its
license actually covers shipping this game. Update it whenever an asset is added, swapped,
or its licensing status changes — it should always reflect reality, not aspiration.

## Art

- **TopDownHouse_SmallItems.png, TopDownHouse_FurnitureState1.png, TopDownHouse_FurnitureState2.png**
  — "Top-Down Retro Interior" by Penzilla (https://penzilla.itch.io/top-down-retro-interior).
  ⚠️ **Not cleared.** Commercial use requires purchasing the pack (suggested $8 minimum) plus
  the credit "Graphics created by Penzilla Design." Currently used uncredited and unpurchased.
  This feeds ~111 placeholder sprites (ART_BRIEF.md) so it's cheaper to buy the pack than
  re-source everything. **Action: purchase before shipping.**

- **kenney_watercraft-pack** (feeds `boat_frames.png`, baked from `ship-cargo-c.glb`) —
  Kenney, confirmed source: https://kenney-assets.itch.io/watercraft-kit. ✅ **CC0 1.0
  Universal** — commercial use allowed, no attribution required.

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

- **UI_Buttons.jpg, ui.png, shop.png, character.png (angler), shed.png** — AI-generated
  placeholder. Flagged as feeling "ugly" — planned for a rework later (design/quality issue,
  not a licensing one).

## Font

- **RubbishFont2-Regular.ttf** — "Rubbish" by Nathan Thomson (dafont.com). ⚠️ **Not cleared.**
  Licensed free for personal use only; author requires emailing
  nathan.thomson.89@gmail.com for commercial use. **Action: get commercial clearance from the
  author, or replace the font.**

## Music

- **music_goin.mp3, music_goin_radio.mp3** — by Nuven (Spotify:
  open.spotify.com/artist/3Cdtqtl7PvG7793m9pkg34). ✅ Personal license/agreement in place
  with the artist (confirmed 2026-09-06).

## Not yet reviewed

Anything not listed above (e.g. remaining UI pieces, any other unattributed asset added
later) hasn't been checked for this pass — don't assume it's clear just because it's absent
from this file.

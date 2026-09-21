# Every player-facing string

The inventory issue #28 step 1 asks for: what the player can read, where it is written, and
what box it has to fit in. Nothing here has moved yet — this is the list to look over before
a single literal is replaced.

Counted by hand off a scan of `scripts/*.gd`, `scenes/main.tscn` and `assets/pieces.json`.
**203 strings in, 34 dead strings deleted, 5 groups out by decision.** Since seeded into
`locale/translations.csv` as **205** keys: the aquarium and the rug joined the finds the same day.
The CSV is the source of truth from here; this file is the record of how it was drawn up.

Three columns run through every table:

- **Key** — the name it will carry in `translations.csv`. `AREA_THING`, the area first, so
  the CSV sorts into the boards a reviewer sees on screen.
- **Box** — what it has to fit inside, in design pixels, and at which size off `Style`'s
  ladder. `—` means nothing clips it (a line that wraps, or a plank sized to its own word).
  These are the budgets the width probe will measure properly in step 2; the ones written in
  here are read off the constants, not measured.
- **Fmt** — the placeholders a translation must carry through unchanged.

---

## 1. The main menu (`menu.gd`)

Six planks, 232x56, `TEXT_BODY`. A `PlankButton` is sized to its own word
(`LABEL_SHARE`), so the plank grows rather than the word shrinking — but six planks of
different widths in one stack would read badly, so the **widest** word is the budget and
the rest are padded to it.

| Key | EN | Where | Box |
|---|---|---|---|
| `MENU_CONTINUE` | Continue | `menu.gd:42` | 232x56 plank |
| `MENU_NEW` | New game | `menu.gd:43` | ” |
| `MENU_SETTINGS` | Settings | `menu.gd:44` | ” |
| `MENU_HOW` | How to play | `menu.gd:45` | ” |
| `MENU_CREDITS` | Credits | `menu.gd:46` | ” |
| `MENU_QUIT` | Quit | `menu.gd:47` | ” |

## 2. Start-over confirm (`menu_confirm.gd`)

Board 420 wide, face 358. The line has no wrap and no clip (`Style.write` does neither), and
**its EN already overran a 400-wide board by 10 px** — that is why `BOARD_WIDE` is 420. The
doors are 174 each.

| Key | EN | Where | Box |
|---|---|---|---|
| `CONFIRM_NEW_TITLE` | Start over? | `menu_confirm.gd:19` | 358 |
| `CONFIRM_NEW_WORDS` | The saved lake will be thrown away. | `:20` | **358, no wrap** |
| `CONFIRM_NEW_YES` | Start over | `:21` | 174 door |
| `CONFIRM_NEW_NO` | Keep it | `:22` | 174 door |

## 3. Settings board (`settings_skin.gd`)

Board 460 wide, face 432, rows inset 10. A label shares its row with a switch (44) and,
on a choice row, the value column (150) and two arrows (22 each) — so a **label has about
180 px** on a choice row and about 360 on a sound row. `TEXT_BODY`.

The board is **666 of the 680 the smallest window leaves**: 14 px of slack for the whole
board. A longer label does not push a row off — `dropped_lines` counts what fell off the
foot and `test_lake` asks for zero — but a language that needs a taller row will drop the
bottom button, which is *Save and go to menu*.

| Key | EN | Where | Box |
|---|---|---|---|
| `SETTINGS_TITLE` | Settings | `:43` | ribbon, less the close cross |
| `SETTINGS_MASTER` | Master | `:257` | ~360 |
| `SETTINGS_GROUP_MIX` | Mix | `:258` | heading, — |
| `SETTINGS_MUSIC` | Music | `:259` | ~360 |
| `SETTINGS_SFX` | Sound effects | `:260` | ~360 |
| `SETTINGS_AMBIENCE` | Ambience | `:261` | ~360 |
| `SETTINGS_GROUP_SCREEN` | Screen | `:262` | heading, — |
| `SETTINGS_WINDOW` | Window | `:263` | ~180 |
| `SETTINGS_RESOLUTION` | Resolution | `:264` | ~180 |
| `SETTINGS_VSYNC` | VSync | `:265` | ~180 |
| `SETTINGS_FPS` | Frame cap | `:266` | ~180 |
| `SETTINGS_CONTROLS` | Controls | `:181` | dark plate |
| `SETTINGS_QUIT` | Save and go to menu | `:180` | dark plate, the widest word on the board |
| `SETTINGS_DEAD_SIZE` | set by Window | `:109` | **said only where it fits whole** — a reason cut in half is worse than none |

Choice values, all in the 150 px value column:

| Key | EN | Where |
|---|---|---|
| `WINDOW_WINDOWED` | Windowed | `:539` |
| `WINDOW_BORDERLESS` | Borderless | `:542` |
| `WINDOW_EXCLUSIVE` | Exclusive | `:541` |
| `VSYNC_OFF` | Off | `:549` |
| `VSYNC_ON` | On | `:552` |
| `VSYNC_ADAPTIVE` | Adaptive | `:551` |
| `FPS_UNCAPPED` | Uncapped | `:553` |

The exclusive-fullscreen safeguard, its own `MenuConfirm`:

| Key | EN | Where | Fmt |
|---|---|---|---|
| `KEEP_MODE_TITLE` | Keep this? | `:441` | |
| `KEEP_MODE_YES` | Keep it | `:442` | |
| `KEEP_MODE_NO` | Put it back | `:443` | |
| `KEEP_MODE_WORDS` | Putting it back in %d seconds. | `:454` | `%d` |

`%d x %d` (`:545`, `:561`) is two numbers and a mark. **Not a key** — see §14.

## 4. Controls board (`controls_skin.gd`, `binds.gd`)

Board 640 wide. Two device columns; a verb's label gets the left column, about 300 px.
`TEXT_BODY`. Board is **666 of 680** — same slack as the settings board.

| Key | EN | Where |
|---|---|---|
| `CONTROLS_TITLE` | Controls | `controls_skin.gd:32` |
| `CONTROLS_DEFAULT` | Set to default | `:64` |
| `CONTROLS_CAPTURING` | Press… | `:65` |
| `CONTROLS_COL_KEY` | Keyboard | `:70` |
| `CONTROLS_COL_PAD` | Gamepad | `:71` |
| `CONTROLS_HINT` | Click a cell and press · right-click resets | `:72` | 314 px of empty band |
| `CONTROLS_MOVED` | ␣␣— moved here | `:402` | flash on the row that lost a binding |
| `CONFIRM_BINDS_TITLE` | Are you sure? | `:76` |
| `CONFIRM_BINDS_YES` | Set to default | `:80` |
| `CONFIRM_BINDS_NO` | Keep current | `:81` — cut from "Keep current buttons" (209 px) to fit the 174 door |

Verb labels and their group headings (`binds.gd:48–111`):

| Key | EN | Group |
|---|---|---|
| `VERB_WALK_UP` / `_DOWN` / `_LEFT` / `_RIGHT` | Walk up / down / left / right | `GROUP_MOVE` = Move |
| `VERB_CAST` | Cast the net | `GROUP_NET` = Net |
| `VERB_LAY_NET` | Lay a lit net | ” |
| `VERB_INTERACT` | Interact | ” |
| `VERB_OPEN_SHED` | Open the shed | `GROUP_OPEN` = Open |
| `VERB_OPEN_UPGRADES` | Open the upgrades | ” |
| `VERB_OPEN_SETTINGS` | Open the settings | ” |
| `VERB_ZOOM_IN` / `_OUT` | Zoom in / out | `GROUP_VIEW` = View |
| `VERB_RECENTRE` | Look at the angler | ” |
| `VERB_SHED_ROTATE` | Turn the piece | `GROUP_SHED` = In the shed |
| `VERB_SHED_SWITCH` | Work a switch | ” |
| `BIND_STICK` | Left stick | `binds.gd:133` |

**Device button names stay English** — see §14.

## 5. Upgrades shop (`lake.gd`, `shop_skin.gd`)

The tightest boxes in the game, and the ones the whole layout was fought over three times.
**A row's writing gets 87 px** after the rail and the price tag. Names run `TEXT_BODY` and
fall back to `TEXT_SMALL` then `TEXT_TINY`; **8 EN rows already cut mid-run**, so a longer
language cuts more. This is the surface most likely to want a widened board — see the plan's
overflow rule.

Board titles (`shop_skin.gd`, ribbons):

| Key | EN |
|---|---|
| `SHOP_BOARD_NET` | NET |
| `SHOP_BOARD_BOATS` | BOATS |
| `SHOP_BOARD_DOGS` | DOGS |
| `SHOP_BOARD_LUCK` | LUCK |

Group headings (`shop_skin.gd:40–49`), carved over their rows:

| Key | EN |
|---|---|
| `SHOP_GROUP_RUN` | The run |
| `SHOP_GROUP_FLEET` | The fleet |
| `SHOP_GROUP_PACK` | The pack |
| `SHOP_GROUP_TRIP` | The trip |
| `SHOP_GROUP_ON_CAST` | On a cast |
| `SHOP_GROUP_AT_YARDS` | At the yards |

Row names (`lake.gd:3735–3785`). **Every one is unique across all four boards** and
`test_lake` guards it — a translation must keep them 17 distinct words. **87 px each.**

| Key | EN | Key | EN |
|---|---|---|---|
| `TRACK_NET_WIDTH` | Width | `TRACK_DOG_COUNT` | Pack |
| `TRACK_NET_STRENGTH` | Strength | `TRACK_DOG_STRENGTH` | Carry |
| `TRACK_NET_RANGE` | Range | `TRACK_DOG_FETCH` | Fetch |
| `TRACK_REEL` | Reel | `TRACK_DOG_WAIT` | Keenness |
| `TRACK_NET_HOLD` | Catch | `TRACK_RECYCLE_BONUS` | Bonus yard |
| `TRACK_BOAT_SPEED` | Sailing | `TRACK_BIRD_WORTH` | Pigeons |
| `TRACK_CARGO` | Hold | `TRACK_LUCKY_HAUL` | Lucky cast |
| `TRACK_BOAT_VOLLEY` | Loading | `TRACK_DOUBLE_CAST` | Double cast |
| `TRACK_FLEET` | Fleet | | |

One word inside a value, the prefix on the two tier tracks:

| Key | EN | Where |
|---|---|---|
| `SHOP_TIER_PREFIX` | `Tier ` | `lake.gd:3737`, `:3774` — the trailing space is part of it |
| `SHOP_MAX` | Max | `lake.gd:3799` — what a maxed row's tag says instead of a price |

The 17 blurbs behind the "?" (`lake.gd:3681–3699`). Drawn on a plate beside the row,
**wrapped by `ShopSkin._wrap`**, so length is soft. Still the longest prose in the game
after the letter.

| Key | EN |
|---|---|
| `BLURB_NET_WIDTH` | How wide the net's mouth opens, so one cast covers more water. |
| `BLURB_NET_STRENGTH` | The heaviest weight tier the net can lift. |
| `BLURB_NET_RANGE` | How far from the shore the angler can throw. |
| `BLURB_REEL` | How fast the net is reeled back in. |
| `BLURB_NET_HOLD` | How many pieces one cast can carry home. |
| `BLURB_BOAT_SPEED` | How fast the ferry sails between the island and the yards. |
| `BLURB_CARGO` | How many pieces the ferry carries a trip. |
| `BLURB_BOAT_VOLLEY` | How quickly a ferry throws its load aboard and into the yard's box. |
| `BLURB_FLEET` | Another ferry in the water. |
| `BLURB_DOG_FETCH` | How many pieces the dog brings back a trip. |
| `BLURB_DOG_WAIT` | How long the dog lazes about between trips, at most. |
| `BLURB_DOG_COUNT` | Another dog for the pack, trained like the first. |
| `BLURB_DOG_STRENGTH` | The heaviest and biggest pieces the dogs can carry back. |
| `BLURB_LUCKY_HAUL` | Odds that a cast lifts one tier heavier and holds more. |
| `BLURB_DOUBLE_CAST` | Odds that a cast throws a second net beside the first. |
| `BLURB_RECYCLE_BONUS` | One yard at a time pays over the odds, and it moves. |
| `BLURB_BIRD_WORTH` | What a netted pigeon is worth. |

**The blurbs are placeholder wording** — CLAUDE.md says Richard writes the real lines once
the rows read right. Translating a placeholder wastes the translation. Flag: rewrite these
in EN before the language pass, or accept re-translating 17 lines later.

The pricing plate (`lake.gd:3858`, `shop_skin.gd:1052`):

| Key | EN | Fmt |
|---|---|---|
| `SHOP_LEGEND` | Each material sells at its own yard. Heavier pieces always pay more. | wrapped |
| `SHOP_BONUS_LINE` | Bonus yard: %s for %ds | `%s` yard name, `%d` seconds |

## 6. The HUD (`hud_skin.gd`, `hud_buttons.gd`, `shed_room.gd`)

| Key | EN | Where | Box |
|---|---|---|---|
| `HUD_WAITING` | Waiting | `hud_skin.gd:94` | stock plate, sized to the word — plate grows |
| `HUD_UPGRADES` | Upgrades | `hud_skin.gd:111` | button foot, 120 wide |
| `HUD_DECORATE` | Decorate | `hud_buttons.gd:105` | button foot, 120 wide |
| `HUD_PIECES_LEFT_1` | 1 piece left | `lake.gd:5082` | hint line, the span beside the garbage circle |
| `HUD_PIECES_LEFT_N` | %d pieces left | `lake.gd:5083` | ” — `%d` |
| `SHELF_TITLE` | Decorate | `shed_room.gd:2126` | shelf ribbon |
| `SHELF_TITLE_N` | Decorate␣␣%d | `shed_room.gd:2126` | ” — `%d` |
| `SHELF_EMPTY` | Nothing kept yet. | `shed_shelf.gd:61` | shelf face |

The pollution meter's `%d%%` and the money plate's `%d` are figures with marks. **Not keys**
— §14.

## 7. The letter / How to play (`letter.gd`)

Four cards, 428 design px tall, the face about 430 wide. **Every line is measured against
the paper** (`_fitted`, `overruns`, `dropped_lines`) and `test_lake` asks for zero overruns,
captions included — so this surface already fails loudly rather than drawing off the board.
The greeting is wrapped evenly (`_wrap_even`); card sentences are not wrapped at all and
drop a size instead.

| Key | EN | Where |
|---|---|---|
| `LETTER_TITLE` | A letter | `:36` |
| `LETTER_GREETING` | Congratulations, you are the new owner of My Dirty Little Lake. | `:39` |
| `LETTER_NET_HEAD` | Net | `:48` |
| `LETTER_NET_LINE` | Cast your net to catch what floats. | `:49` |
| `LETTER_NET_GREEN` | Green: a catch | `:51` caption |
| `LETTER_NET_RED` | Red: nothing to lift | `:52` caption |
| `LETTER_NET_WHITE` | White: out of range | `:53` caption |
| `LETTER_UPGRADES_HEAD` | Upgrades | `:57` |
| `LETTER_UPGRADES_L1` | Upgrade your net, your boats and your dogs | `:59` |
| `LETTER_UPGRADES_L2` | to clean and recycle faster. | `:60` |
| `LETTER_WEIGHT_HEAD` | Weight | `:65` |
| `LETTER_WEIGHT_L1` | Heavier things sit in five tiers. | `:67` |
| `LETTER_WEIGHT_L2` | Strength is the upgrade that lifts the next one. | `:68` |
| `LETTER_WEIGHT_CAP1` | Too heavy | `:70` caption |
| `LETTER_WEIGHT_CAP2` | Buy Strength | `:70` caption |
| `LETTER_DECOR_HEAD` | Decoration | `:73` |
| `LETTER_DECOR_LINE` | Some catches are furniture for your shed. | `:74` |
| `LETTER_DECOR_CAP1` | Catch it | `:75` caption |
| `LETTER_DECOR_CAP2` | Wash it | `:75` caption |
| `LETTER_DECOR_CAP3` | Place it | `:75` caption |
| `LETTER_START` | Start cleaning | `:82` — stands at the pager's right end |

**The nine stills on these cards carry the game's English UI** and are out of this pass
(see §13). A card whose sentence is translated beside a photograph of an English shop row
is the known cost.

## 8. The wash room and the pump (`wash_room.gd`, `lake.gd`)

| Key | EN | Where |
|---|---|---|
| `WASH_TITLE` | To wash | `wash_room.gd:39` |
| `WASH_EMPTY_1` | Nothing waiting. | `:40` |
| `WASH_EMPTY_2` | Net a find and | `:40` |
| `WASH_EMPTY_3` | bring it here. | `:40` |

`%s␣␣%d` (`:307`) is a find's name and its soap; `$%d` (`:344`) is a price. Both are
composition, not words — §14. The find's name itself is §10.

## 9. The ending (`farewell.gd`)

Over open water, centred, wrapped to `ROLL_WIDE`.

| Key | EN | Where |
|---|---|---|
| `END_LINE_1` | You have cleaned your lake and can now live in peace. | `:28` |
| `END_LINE_2` | Thanks for playing! | `:29` |
| `END_BACK` | Back to menu | `:120` — the plaque |

`:34` "Something is stirring in the water." and `:35` "Face it" are the **siege's** ending —
§13.

## 10. Names of things (`trash_def.gd`, `pieces.json`)

**Material names are already translated** — `dropoff.gd:210` puts `kind_name()` through
`tr()`, the game's one existing call, so the yard signs change with the language and the
sheet does not. That call becomes `Text.MATERIAL_*` like everything else.

| Key | EN | Where | Seen |
|---|---|---|---|
| `MATERIAL_PLASTIC` | Plastic | `trash_def.gd:17` | pier sign, shop legend |
| `MATERIAL_WOOD` | Wood | ” | ” |
| `MATERIAL_METAL` | Metal | ” | ” |
| `MATERIAL_RUBBER` | Rubber | ” | ” |

**A pier sign is drawn at the zoom's own pixel size** under a transform that undoes the
zoom, on a plank about 60 painted px wide — the tightest box in the world layer. `WOOD` fits
at four letters; German *Holz* fits, *Kunststoff* (10) does not. Flag for the width probe.

| Key | EN | Where |
|---|---|---|
| `TIER_LIGHT` / `_SMALL` / `_MEDIUM` / `_HEAVY` / `_BULKY` | Light / Small / Medium / Heavy / Bulky | `lake.gd:3672` |

The 37 find titles in `assets/pieces.json` — `DECOR_SOFA` … `DECOR_GLOBE`. Shown on the
shelf (cut with an ellipsis when long), on the wash room's tray, and on the trophy card.
Full list in the json; they are data, so the CSV is generated from it rather than hand-typed.

| Key | EN | Where |
|---|---|---|
| `TROPHY_FOUND` | New decoration available to wash | `trophy.gd:56` |

## 11. Credits (`credits_board.gd`)

Board face 430; a line too wide **wraps on spaces** (`_wrap`), so length is soft. The longest
EN line is 370.

Headings — **translated**:

| Key | EN |
|---|---|
| `CREDITS_TITLE` | Credits |
| `CREDITS_HEAD_DESIGN` | Design and programming |
| `CREDITS_HEAD_MUSIC` | Music and sound |
| `CREDITS_HEAD_ART` | Art and Assets |
| `CREDITS_HEAD_TOOLS` | Tools |

Everything under them — **verbatim English, no key**: `Modern Daedalus Studio`, `Nuven`,
`Benvictus`, `xStrax`, `Graphics created by Penzilla Design`, `limezu.itch.io`,
`Kipperfalcon`, `Asset by Zato - https://zatoart.itch.io/`, `Pop Shop Packs`,
`@Pixel_Salvaje`, `Made with Godot Engine`. Names, and licence obligations that may not be
reworded — CLAUDE.md already forbids shortening them.

## 12. The console shelf (`console_shelf.gd`)

| Key | EN | Where | Fmt |
|---|---|---|---|
| `CONSOLE_COUNT` | CONSOLES␣␣␣%d / %d | `:218` | `%d`, `%d` |

A spike as of `06e5ab0`. In, but cheap to drop if the shelf does not survive.

---

## 13. Out of this pass, by decision

- **Credits attribution strings** (§11) — verbatim by licence.
- **The nine letter stills** `assets/letter/*.png` — photographs of the game's own English
  UI. Re-shooting them per language is its own job; `tools/shot_letter_art.tscn` is the
  probe when it comes.
- **Steam store page** — lives in `marketing/`, not in the game.
- **Tuners, probes, `tools/*`** — `GroundTuner` (F4), `ButtonTuner` (F7), `PerfHud` (F3),
  `PlayLog`, every probe's log line. Never shipped to a player.
- **The siege** — `siege.gd` (6 sludge names, 2 ending lines, the wave readout), `defeat.gd`
  (4 lines), `charm.gd` (4 charm names), and `hud_skin.gd`'s wave/shield/ammo block at
  `:469–511`. `Lake._next_scene()` returns "" and nothing routes there; its cleanup is its
  own job (#38). **If the siege is ever revived it needs its own extraction pass** — about
  20 strings.
- **Engine and developer messages**: `lake.gd:847` / `:1683` "Lake: missing %s",
  `day_cycle.gd:56`, `prefs.gd:229`, `console_shelf.gd:75`, `perf_hud.gd:31`. Printed, not
  drawn.

## 14. Not a string, by decision

Composition that carries no word, and would gain nothing from a key:

- `ARROW` `→` (`lake.gd`) — a mark, the same in every language, and Bungee has it.
- Figures with marks: `%d%%`, `$%d`, `%ds`, `%d x %d`, `+%d$`, `%d`. `%`, `$` and `s` are
  marks rather than words — that is the shop's own settled rule.
- `Style.write`'s own arguments; sprite and sheet keys; save keys; bus names.
- **Gamepad button names** (`binds.gd:138–151`): `A`, `B`, `X`, `Y`, `LB`, `RT`, `D-Pad Up`,
  `Left click`, `Wheel up` … Xbox's own printed names, which are not translated on the
  hardware either. Keyboard keys already come from
  `DisplayServer.keyboard_get_label_from_physical`, so a French player is told ZQSD without
  a string being involved. **`Left stick` is a key** (§4) because it is a sentence fragment
  standing in a table cell, not a legend printed on a button.

Open question for the language pass, not for this one: `D-Pad Up` is half a name and half a
direction. Left as is.

## 15. Dead text found on the sweep — deleted 2026-09-20

Four surfaces wrote strings no player could reach. **All deleted**, in the commit before the
extraction; the counts here are what was actually cut.

1. **The stock shop panel** — 26. `scenes/main.tscn`'s whole `HUD/Shop` subtree (16 labels
   and buttons: "Net width", "Cast range", "Back to the water  (E)" …) and the block of
   `Lake._update_hud` that formatted 10 more into it every frame the board was open.
   `lake.gd` said so itself: *"which no player sees (the drawn board replaces it)"*.
   `auto_ferry` was real state living on that panel's invisible `CheckButton` — it is
   `Lake._auto_ferry_on` now, same save key, no `SAVE_VERSION` bump. `_send_ferry` and
   `_any_boat_docked` were reachable only from it and went with it.
2. **`Lake._fleet_line`** — 2. No caller at all. **`Boat.status_line` was kept**: it is read
   by `tools/test_lake.gd` for failure messages, which makes its 5 strings a developer
   message (§13), not player text. Its docstring says so now.
3. **`Lake._note_save`** — 6. Written to `_save_note`, its timer ticked at `lake.gd:4518`,
   the string never drawn anywhere.
4. **`Lake._polish_panel_controls`** — 0 strings, found by the cut. With the shop panel gone
   it pointed only at `HUD/Shed/Pad/Lines/Title` and `Note`, **which are not in the scene**,
   so it had already been styling nothing. `scripts/wood_ui.gd`, its only client, is
   unreferenced now and left on disk pending a call.

**34 strings**, which would otherwise have been extracted, translated eight times and put in
front of native speakers for text nobody can read. `test_lake` asks that `HUD/Shop` is gone
rather than hidden — the check a deleted-because-invisible node needs. 940 checks, 0 failed.

## What this adds up to

| Surface | Keys |
|---|---|
| Menu, confirm | 10 |
| Settings, window/vsync values, keep-mode | 25 |
| Controls, verbs, groups | 31 |
| Shop: boards, groups, rows, blurbs, legend | 48 |
| HUD | 8 |
| Letter | 21 |
| Wash room | 4 |
| Ending | 3 |
| Materials, tiers, finds, trophy | 47 |
| Credits headings | 5 |
| Console shelf | 1 |
| **In** | **203** |
| Out by decision (siege, credits attribution, dev messages) | ~50 |
| Dead, deleted | 34 |

The 37 find titles are generated from `pieces.json`; the other 166 are hand-listed above.

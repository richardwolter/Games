# Lake Cleanup — visual asset list

A brief for pixel artists. It lists what the game draws today, where that art comes from,
and what is still drawn in code and needs a real asset. Everything is 2D, isometric, and
rendered in Godot 4.7.

## Project constants an artist needs

| Thing | Value |
| --- | --- |
| Projection | 2:1 isometric, tile 64 x 32 px |
| Source grid for props | 16 px cells (current rubbish sheets), upscaled x1.5 in game |
| Rubbish sprite size on screen | 15–46 px on the longest side |
| Ferry hull on screen | ~138 x 57 px, 16 px of freeboard |
| Net frame | drawn ~1–4 tiles wide, sized from a measured "rim" width per frame |
| Angler | 192 x 192 px source pose cells |
| Shed interior | drawn on an 8 px grid at x3 zoom, floor 30 x 20 cells |
| Palette | near-black ink outline, muted naturals; water is a shader |
| Format wanted | PNG with alpha, no premultiplied edges, no anti-aliasing on outlines |

Several existing sheets are **JPG** (`Net_Cast_spritesheet.jpg`, `Net_Closing_Drag.jpg`,
`Net_Upgrades_Menu.jpg`, `UI_Buttons.jpg`). They are keyed off a background colour by the
slicing tools in `tools/`, which is lossy and leaves fringes. All replacements should be
PNG with a real alpha channel.

---

## 1. Rubbish and furniture — the thing the whole game is about

**Status: placeholder.** Currently 111 sprites cut from third-party top-down house packs
(`TopDownHouse_SmallItems.png`, 61 pieces; `TopDownHouse_FurnitureState1/2.png`, 50 pieces),
catalogued in `assets/pieces.json`.

### 1a. Sellable rubbish — 16 named pieces, 4 materials x 5 weight tiers

These are hand-authored in code and each needs its own sprite. They are seen floating in
water, gathered in the net, piled in a crate, and stacked in a boat hold — so each must read
at about 20 px.

| Material | Pieces (tier) |
| --- | --- |
| Plastic | Mug (0), Jar (0), Bottle (0), Fish bowl (2) |
| Timber | Shelf board (0), Book (1), Chopping board (2), Crate (3) |
| Metal | Tin plate (0), Cooking pot (2), Teapot (3), Wall clock (4) |
| Rubber | Rubber duck (0), Chew toy (1), Ball (2), Urn (4) |

Each piece wants two reads: **clean** and **filthy**. The game grimes them with a shader,
but a drawn soaked/slimed variant would sell it better.

### 1b. Collectible furniture — about 50 pieces

One of each is hidden in the lake, never sold, and displayed in the shed. Currently
auto-generated from the furniture sheet with auto-prettified names. Wants a purpose-drawn
set of household furniture in the same isometric read: chairs, tables, beds, wardrobes,
dressers, lamps, rugs, shelving, sinks, stoves, and so on. Each is seen twice — small and
wet in the water, and clean at x3 zoom in the shed — so **two states per piece
(waterlogged / restored)** would carry a lot of the game's payoff.

---

## 2. The ferry

**Status: placeholder.** 16 headings baked from a Kenney 3D model (`ship-cargo-c.glb`) at
45 degrees azimuth / 30 degrees elevation into `boat_frames.png`, 128 px frames.

Wanted, hand-drawn:

- Hull, **16 headings**, 128 px frames, about 104 px of actual hull in each.
- Upgrade tells, since the player buys these: a **skimmer net rig on the transom** (5 visible
  levels), a fuller/faster hull read for speed levels, and a deeper hold.
- Up to **3 hulls in the water** at once — ideally visibly different boats, not palette swaps.
- Wake, bow spray and hull ripples are drawn in code and can stay code, but a **wake sprite
  set** would look better than the current stacked polygons.

## 3. The net (the player's main verb)

**Status: real art, wrong format.** Four 5-frame sequences in `assets/net_frames.json`:
`cast_far`, `cast_near`, `land`, `drag`. Sliced from two JPGs.

Wanted:

- The same four sequences redrawn as PNG, ideally **6–8 frames each** — the closing drag is
  the money shot and 5 frames is thin.
- The net must read as a **bag with junk inside it**, seen from above at 2:1. The game draws
  the catch behind the net art, so the mesh needs open weave with real alpha.
- **Upgrade tells:** width has 8+ levels and currently just scales the same drawing. Two or
  three distinct mesh drawings (small hand net through to wide dragnet) would make purchases
  read.

## 4. The angler

**Status: real art.** `assets/character.json` — idle (9), run (17) and cast (16) in four
directions, straw hat painted in.

Wanted:

- **Hold, reel and haul-in poses.** The cast loops while the net comes home.
- A **carrying** pose for hauling a find up the beach.

## 5. The lake and the shore — all drawn in code today

**Status: fully procedural. This is the biggest gap.**

- **Water** — shader (`shaders/water.gdshader`) with a per-tile filth map. Wants a tileable
  clean/dirty water treatment, a foam line at the shore, and a sparkle pass for the cleaned
  lake.
- **Bank and beach** — drawn as polygons. Wants a **shoreline tile set**: sand, grass, the
  transition between them, and scatter (reeds, rocks, stumps).
- **The island** — sand plus green blobs plus the shed. Wants a drawn island.
- **The four merchant yards** (Plastic / Timber / Metal / Rubber) — currently a plank pier,
  crates and a coloured sign per yard, all polygons. Wants **4 distinct dockside buildings**
  with pier, sign and material-coloured stock. These are the landmarks the player navigates
  by.
- **The yard crate on the island** — a code-drawn wooden box the catch piles into. Wants a
  real crate with a fill read.
- **The shed exterior** — currently the shed *button icon* reused on the ground, plus a
  code-drawn lamp. Wants a proper hut, with a lit-window state.

## 6. The shed interior (the collection screen)

**Status: floor and walls are code-drawn**; the furniture uses the placeholder sheet.

Wanted: a room on an 8 px grid at x3 zoom — floor boards, walls, door, window — and a
**furniture-list panel** down the right, 260 px wide with 56 px rows.

## 7. Pigeons

**Status: real art, third-party.** `assets/pigeons.json`, 7 colour rows in use (browns and
tans deliberately excluded). They perch on floating rubbish and can be netted for a bonus.

Wanted: idle, peck, take-off and fly cycles in a matching style, plus a **perched-on-junk**
pose.

## 8. UI

**Status: real art, one JPG sheet.** `assets/ui.json` holds 4 pieces: the pollution `meter`,
the `money` plate, the `shed` button and the `upgrades` button. The upgrades boards are
drawn in code (`scripts/shop_skin.gd`) in the pollution meter's colours; the painted shop
sheet and its five icons are retired.

Gaps:

- The **settings panel, the save/load notices, and the farewell/ending screen** are unskinned.
- The font is `RubbishFont2-Regular.ttf`; a matching pixel font would tie the UI together.

## 9. Effects — all code-drawn

Splashes, ripples, the haul arc (junk thrown from the net to the island), the pollution meter
fill, and the end-of-game sparkle. Sprite sheets for **splash**, **ripple ring** and **catch
sparkle** would replace the weakest-looking drawing in the game.

---

## Suggested order of work

1. The 16 rubbish pieces plus filthy variants — seen constantly, currently borrowed.
2. Merchant yards, island, shed exterior — the whole shore is placeholder geometry.
3. The ferry: hulls plus skimmer upgrade tells.
4. Net sequences redrawn as PNG with more frames.
5. The furniture collection set — the long tail, about 50 pieces, two states each.
6. The 4 missing upgrade icons, plus the settings and ending screens.
7. Effects sheets.

## Licensing note

`TopDownHouse_*`, `kenney_watercraft-pack` and the pigeon sheets are third-party. Anything
shipped commercially should either honour their licences or be replaced — which is most of
what this brief asks for anyway.

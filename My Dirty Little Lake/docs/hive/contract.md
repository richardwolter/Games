# The Hive: build contract

This is the one reference every agent builds against. It was written from the grilled plan
with Richard (2026-09-29, see memory `lake-beehive-sidequest`), the approved mockup
(`tools/hive_mockup.py`, which renders `tools/last_hive_mockup_{island,room}.png`), and
the integration map (`docs/hive/map_digest.txt`, with the full detail in
`docs/hive/understand_map.txt`).

**Never deviate silently.** If something here is wrong or impossible, write the reason at
the top of your report.

## 0. Toolchain (this machine)

- Godot: `"/c/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe"`, from the
  project directory `My Dirty Little Lake/` (the worktree is
  `C:/Users/Administrador/Documents/Games/.claude/worktrees/hive-sidequest`).
- Import after any new `class_name`, PNG or CSV row:
  `<exe> --path . --headless --import --log-file tools/last_import_hive.log`
- The harness: `timeout 900 <exe> --path . --headless res://tools/test_lake.tscn --log-file tools/last_hive_test_engine.log`.
  - It writes `tools/last_test.log`, and the last line is `test_lake: N checks, M failed`.
  - **Baseline in this worktree: 1563 checks, 1 failed** ("nothing is bought while the tour
    is up", a CRLF artefact). Compare against that, not against zero.
  - Always grep the engine log for `SCRIPT ERROR` / `Parse Error`.
- **Python with PIL.** The venv's `python.exe` is blocked by Windows Application Control, so
  run the base Python with the venv's packages on the path:
  `PYTHONPATH="C:/Users/Administrador/.claude/skills/psd-extract/.venv/Lib/site-packages" python tools/<script>.py`
  from `My Dirty Little Lake/`.
  - Write text files with `newline="\n"`.
  - Never let Python text mode write CRLF.
- CRLF: most files in this checkout are CRLF and `lake.gd`/`test_lake.gd` are LF. Keep each
  file's existing line endings when editing. Source-string checks in `test_lake` must be
  single-line.
- Never `git stash`. Never edit `project.godot` (the open editor re-saves it). Never write
  the player's `user://my_dirty_little_lake.save` or `settings.cfg`.

## 1. What is being built (decisions, not up for change)

- **An old, empty hive stands on the island's free lawn, left of the hut on screen**, from a
  new game. It is one isometric sprite: the hive, plus a **jar shelf** behind its shaded side
  (two thin pine planks on posts). The jars are scenery: **3 per harvest, at most 12** (four
  harvests), filling the top plank first.
- **Paint: sky blue** (`PAINTS["sky"]` in the mockup). The hive is weathered grey with faded
  blue flakes until the colony moves in, then its paint comes back. The roof is coral.
- **The swarm arrives mid-run**: it needs `play >= 15 min` and at least `SWARM_HOSTS` (6)
  grown bee-host flowers on the island, or `play >= 25 min` and at least 1. It hangs on a
  flowering shrub beside the hive, drawn by the hive node, which grows in when the swarm
  comes.
  - The arrival gets the wildlife moment's treatment: a glide, a paper card
    `Text.HIVE_SWARM`, and a glide home.
  - Refills are shown only in the world: honey rising in the hive's window, bees crowding
    the entrance, and a gold ready mark over the roof when a harvest is ready.
- **E (pad A) at the hive** opens the **hive room** only when there is something to do (a
  swarm to catch, or a harvest ready). A lamp shows then, like the pump's.
- **The hive room** is a full-screen room like the wash room. It is outdoors: the wash
  room's own backdrop is behind it, veiled 0.82 rather than 0.66, the lake keeps running,
  and the music is muffled as in the wash room. It shows:
  - an oak **step plank** at the top: a row of comb cells that fill with honey as each step
    is done, each labelled;
  - a **paper hint card** at the bottom, with the verb in the head ink and the device's
    prompt icon;
  - a **close cross** top right.
- **First harvest (the ceremony)**: catch the swarm, smoke, find the queen, uncap, crank,
  pour. **Later harvests (2nd to 4th)**: uncap, pour. **No failure states. Nothing is
  kept**: no money, no items. Nothing is charged.
- **Every step must feel satisfying**: smooth motion, a payoff at the end of every step
  (sparkles, a settle, a sound), and generous input.
- **Sounds are built in code for now**, under names a recording can later replace.
- **Strings go through `locale/translations.csv`** (pt_BR is the source language; en
  follows it).
- **Saved under one key `hive`**. A missing key means empty, arc not started. No
  `SAVE_VERSION` bump.

## 2. Files and owners

| File | New/Edit | What |
|---|---|---|
| `tools/build_hive.py` | new | Bakes both sheets. Moves the mockup's drawing functions here; `tools/hive_mockup.py` imports them back |
| `assets/hive.png` + `hive.json` | new (built) | Island sheet |
| `assets/hive_room.png` + `hive_room.json` | new (built) | Room pieces |
| `scripts/hive_art.gd` | new | `class_name HiveArt`, static: loads both sheets once, piece regions, drawing helpers |
| `scripts/hive.gd` | new | `class_name Hive extends Node2D`: the world object, its state and its save |
| `scripts/hive_room.gd` | new | `class_name HiveRoom extends Control`: the room shell, plan, plank, card and close |
| `scripts/hive_step.gd` | new | `class_name HiveStep extends Control`: the base for the six steps |
| `scripts/hive_step_{catch,smoke,queen,uncap,crank,pour}.gd` | new | One minigame each |
| `scripts/hive_sounds.gd` | new | `class_name HiveSounds`, static: code-built takes and loops |
| `scripts/sfx.gd` | edit | Register built hive one-shots and the hum bed |
| `scripts/lake.gd` + walkers and flora | edit | Integration (section 9) |
| `scripts/wash_backdrop.gd` | edit | `DARKEN` const becomes var `darken` (default 0.66); add var `bank_offset` (default 0) |
| `locale/translations.csv` + `scripts/text.gd` | edit | Keys (section 8); run `tools/build_translations.py` |
| `tools/test_lake.gd` | edit | New `_stage_hive` (section 10) |
| `tools/shot_hive.gd/.tscn` | new | Desktop probe (section 10) |
| `CLAUDE.md`, `docs/scope-lock.md` | edit | Last |

## 3. Art contract

Everything is authored at **one painted pixel**. The island sheet draws at `ART_SCALE` 2.0
world px per painted px. The room draws at 2 canvas px per painted px (the room's art grid
is 640x360 painted px at the 1280x720 design canvas).

### 3.1 `assets/hive.json` (island)

```json
{
  "size": [W, H],
  "foot": [fx, fy],
  "ground_hive": gh,
  "ground_shelf": gs,
  "frames": {
    "hive_weathered": [x, y, W, H], "hive_colony": [...], "hive_full": [...],
    "shelf_weathered": [...], "shelf_0": [...], "shelf_3": [...], "shelf_6": [...], "shelf_9": [...], "shelf_12": [...]
  },
  "window": [x, y, w, h],
  "entrance": [x, y],
  "ready_at": [x, y],
  "swarm": [x, y, w, h],
  "swarm_at": [x, y],
  "shrub_at": [x, y],
  "foot_tiles": {"centre": [ctx, cty], "half": [hx, hy]}
}
```

- **Every frame is the same size** (W x H, the union of the opaque boxes, cropped with a
  1 px margin), on the same canvas, so the parts overlay exactly.
- To draw, draw the shelf frame, then the hive frame, both into the same box:
  `Rect2(-foot * ART_SCALE, size * ART_SCALE)`.
- `foot` is the painted pixel under the middle of the hive stand's leg diamond: the node's
  origin, which is `Hive.tile`.
- `ground_hive` / `ground_shelf` are each part's own `ground` for `Shade.Cast.lay` and for
  `Skirt.hem`: (H - lowest row of that part) / H, plus a little.
- `window` is the honey window on the lit face, as painted px within a frame.
  - `hive_colony` has the window's honey empty (dark).
  - The node draws the honey level over it at runtime: a gold fill rising from the bottom.
  - `hive_full` has it full.
- `entrance` is the landing board, where commuting bees leave and land.
- `ready_at` is over the roof peak: where the gold ready mark and the lamp go. **The lamp
  goes 8 px above the ready mark when both show.**
- `swarm`: the island swarm cluster sprite's rect on the sheet.
- `swarm_at` is where it hangs, and `shrub_at` where the flowering shrub stands (the flora
  sheet's `shrub_flowering`), both as painted-px offsets **from `foot`**. The shrub stands
  on the lawn clear of the hive's footprint, and the swarm hangs from its side.
- `foot_tiles` is the walker footprint in **tile space, relative to `Hive.tile`**: a
  rectangle covering the hive stand and the whole shelf. The builder computes it from the
  iso geometry it drew (painted px back to tiles: a tile is 32x16 painted px, since the tile
  is 64x32 world at 2x).

The island hive is the mockup's `island_hive` (sky, jar shelf behind): 44x40 painted px
before inking, the hive's `cx` 30. Keep it exactly as approved on the sheet.
`tools/last_hive_sheet.png` is a contact sheet of every frame at x6.

### 3.2 `assets/hive_room.json` (room pieces)

```json
{"pieces": {"<name>": {"rect": [x, y, w, h], "anchors": {"<a>": [x, y]}}}}
```

Anchors are in painted px **inside the piece**. Every piece is inked (the near-black
`(24,18,17)` outline), as drawn in the mockup. Pieces and their anchors:

| name | from mockup | anchors |
|---|---|---|
| `hive_front` | `room_hive(sky, window=0.35)` | `entrance` (landing slot centre), `roof` (ridge top), `feet` (bottom centre) |
| `hive_open` | `room_hive(sky, lid=False, open_top=True)` | `top` (open top centre), `feet` |
| `box` | the catch step's open brood box (sky) | `mouth` (top-face centre), `feet` |
| `branch` | `branch_with_swarm` **without the swarm** | `hang` (where the swarm hangs), `grip` (a point on the bough the player grabs) |
| `smoker` | `smoker()` | `nozzle` (spout tip), `bellows` (centre of the bellows) |
| `frame_brood` | `brood_frame(300, 180, seed=9, cell=CELL_BIG)` | `inner_tl`, `inner_br` (the comb area) |
| `frame_capped` | the honey frame, every cell capped (`uncap_to=-1` equivalent), CELL_BIG, 300x180 | as above |
| `frame_open` | the same frame with every cell uncapped honey (`uncap_to=huge`), same geometry | as above |
| `knife` | `hot_knife(294)` | `blade_l`, `blade_r` (the blade's top edge ends), `handle` |
| `wax_curl` | the tip curl alone | `root` |
| `extractor` | `extractor()` **without the crank arm and knob** (keep the gear box and shaft) | `shaft` (pivot top), `gate` (spout tip), `rim_c` (centre of the top rim ellipse), `bucket` (top centre of its bucket) |
| `knob` | the wooden crank knob | `pin` |
| `bottling` | the enamel bottling bucket, label and brass gate on its stand (the pour step) | `gate` (under the spout) |
| `jar_glass` | `jar(fill=0)` | `inner_tl`, `inner_br` (the honey area), `neck` |
| `jar_full` | `jar(fill=0.86, lid=True, label=True)` | `feet` |
| `glove_l`, `glove_r` | `glove()`, `glove(flip=True)` | `grip` |
| `crown` | `crown()` | `c` |
| `bee_r`, `bee_r_rest`, `bee_u`, `bee_d` | `bee()` variants (right, wings up; right, wings folded; turned up; turned down) | `c` |
| `queen_r` | `bee(queen=True, wings_up=False)` | `c`, `dot` (the white dot) |
| `pip_done`, `pip_now`, `pip_todo` | the step plank's comb cells | `c` |
| `puff_s`, `puff_m`, `puff_l` | `puff()` baked at r 5 / 10 / 15, dissolving rim | `c` |

Mirrored left-facing variants are drawn by the code (a negative x scale transform), not
baked. The comb geometry for the uncap step goes into `hive_room.json` as
`"comb": {"inner": [x, y, w, h] (relative to frame_capped), "pitch": [8, 7], "offset": 4, "cell": [7, 8]}`.
`tools/last_hive_room_sheet.png` is a contact sheet.

**Colours**: the mockup's constants (honey ramp, wax, pine, steel, brass, enamel, gingham,
the sky paint, the coral roof), moved into `build_hive.py`. The game code needs only a few
runtime colours: honey for the jar fill, window and drips; bee gold and stripe for code-drawn
specks; the star gold. `HiveArt` carries them as constants, the same values as the builder.

## 4. `HiveArt` (scripts/hive_art.gd): static helpers every room step uses

```gdscript
class_name HiveArt extends RefCounted
const SHEET := "res://assets/hive_room.png"
const CONTRACT := "res://assets/hive_room.json"
const PIXEL := 2.0                      # canvas px per painted px in the room
# colours (must match build_hive.py)
const HONEY_DEEP, HONEY_MID, HONEY, HONEY_LIGHT, HONEY_SHINE, WAX, WAX_LIT, WAX_SHADE,
      BEE_GOLD, BEE_STRIPE, GOLD, TRIM, OUT, SMOKE_* ...
static func sheet() -> Texture2D                       # cached, NEAREST drawn by caller's texture_filter
static func has(name: StringName) -> bool
static func rect(name: StringName) -> Rect2           # region on the sheet
static func size(name: StringName) -> Vector2         # painted px
static func anchor(name: StringName, a: StringName) -> Vector2   # painted px inside the piece
static func comb() -> Dictionary
# draw helpers: `ci` is the CanvasItem drawing, `at` is where the piece's anchor lands in CANVAS px
static func draw(ci: CanvasItem, name: StringName, at: Vector2, anchor_name := &"", flip := false, alpha := 1.0) -> Rect2
static func draw_region(ci, name, dest: Rect2, src_local: Rect2, alpha := 1.0)   # part of a piece (the uncap reveal)
static func star(ci, at: Vector2, arm: int, alpha := 1.0)          # the finds' four-point star in whole painted px (PIXEL)
static func drip(ci, at: Vector2, length_px: float, alpha := 1.0)  # honey run with a bead
static func px(ci, at: Vector2, color: Color)                      # one painted pixel, snapped
static func snap(p: Vector2) -> Vector2                            # to the painted-px grid
```

`draw()` returns the canvas rect the piece covered. When a piece is missing (for example a
harness with no import), everything draws nothing and returns an empty rect. It never
errors.

## 5. World: `Hive` (scripts/hive.gd)

```gdscript
class_name Hive extends Node2D
enum Stage { EMPTY, SWARM, READY, BUSY, DONE }
const ART := "res://assets/hive.png"; const CONTRACT := "res://assets/hive.json"
const ART_SCALE := 2.0
const SKIRT_SEED := 6203
const JARS_PER := 3; const HARVESTS_MOST := 4
static var tile := Vector2.INF          # reset in _exit_tree
static var centre := Vector2.ZERO       # footprint centre offset (tiles), from json
static var half := Vector2(0.45, 0.35)  # footprint half extents (tiles), from json
const WALK_KEEP := 0.12
static func covers(at: Vector2, grow := 0.0) -> bool      # rectangle in tile space; false while tile is INF
static func hides(at: Vector2, margin := 6.0) -> bool      # a plant at `at` would draw into the picture (asymmetric rect)
var day: DayCycle
var lit := false
var stage := Stage.EMPTY
var jars := 0            # 0..12
var harvests := 0        # 0..4
var first_done := false  # the first-harvest ceremony finished
var refill_at := 0.0     # the lake's play clock at which BUSY turns READY
var refill_from := 0.0   # when the refill started (window fill share)
var moment_seen := false
var held := false        # a borrowed lake holds the arc (set by the lake)
var play_now := 0.0      # pushed by the lake every second, for the window's fill
func picture_rect() -> Rect2       # local rect of the whole drawn picture (asymmetric)
func actionable() -> bool          # stage == SWARM or stage == READY
func plan() -> Array[StringName]   # the room's steps for this visit (section 6)
func to_save() -> Dictionary
func from_save(d: Dictionary) -> void   # clamps every field; absent means the empty defaults
func roof() -> Dictionary          # {image, texture, rect}: the current frame's cached Image + AtlasTexture of shelf+hive composited
func set_stage(s: Stage)           # re-lays the shade, redraws
signal changed
```

Drawing, in order:
1. Two `Shade.Cast` children, one for the shelf and one for the hive, each laid off its own
   part's cached `Image` (`get_region` of the frame) with its own `ground`.
   - Re-lay them **whenever the frame changes**: recreate the Cast, because `Cast.lay` caches
     on box and ground only.
2. The shelf frame for the jars: `shelf_weathered` when EMPTY or SWARM, else
   `shelf_<jars>`.
3. The hive frame: weathered for EMPTY/SWARM, `hive_full` for READY, `hive_colony` for
   BUSY/DONE plus the runtime window fill.
4. The window fill: `share = clamp((play_now - refill_from) / (refill_at - refill_from))`
   while BUSY, 0.35 when DONE, full (`hive_full`) when READY.
5. The skirts: `Skirt.hem`, one per part, baked once, over the pictures.
6. The shrub and swarm (SWARM), and the shrub after it (READY/BUSY/DONE): drawn from the
   flora sheet `assets/flora.png`, rect `shrub_flowering` [123,19,15,12], at 2x.
   - It grows in over 1.2 s on the stage change: it rises from its sprout rect
     `flora.json` `sprout`.
   - The swarm cluster is the sheet's `swarm` frame, plus 10 bee specks circling it (2x2
     painted px, Flora's `BEE_COLOR`/stripe), on a clock.
7. Commuting bees (READY/BUSY/DONE) go on a child `Node2D` at **absolute z 20**
   (`z_as_relative = false`), so they fly over hulls and walkers.
   - 8 bees ping-pong between `entrance` and grown island flower spots. The lake hands a
     Callable `host_spots: Callable -> PackedVector2Array` (world positions). With none,
     the bees loop near the hive.
   - READY crowds 6 more bees at the entrance.
8. The ready mark (READY) bobs 2 px over `ready_at`: the builder's `ready_mark` sprite, or
   drawn. The lamp (`lit`) is two soft circles like the pump's, 8 px above it.

Hum: the lake pushes `Sfx.main().set_hive_hum(share)` each frame (section 7), from the
angler's distance. It is silent while EMPTY and loudest while SWARM or READY.

## 6. The room: `HiveRoom` (scripts/hive_room.gd) and `HiveStep` (scripts/hive_step.gd)

```gdscript
class_name HiveRoom extends Control
signal close_asked
signal swarm_caught
signal harvested            # a harvest's last step is done (the lake adds the jars)
const Style := preload("res://scripts/style.gd")
const STEP_NAMES := {&"catch": ..., &"smoke": ..., &"queen": ..., &"uncap": ..., &"crank": ..., &"pour": ...}  # -> scripts
const BETWEEN := 0.7        # the settle beat between two steps
const DONE_HOLD := 2.2      # after the last step, the done card, then close_asked by itself
# lent by the lake, as for the wash room
var day: DayCycle
var filth_left: Callable; var pack_size: Callable; var fleet_size: Callable
var rubbish: Array; var flock: Flock
var hive: Hive
func open(up: bool) -> void          # up: builds the plan from hive.plan() and starts the first step
func step_name() -> StringName
func plan() -> Array[StringName]
func origin() -> Vector2             # canvas px of the art grid's top left (640x360 painted px centred in the room)
# pad
func pad_focus() -> Array            # the close cross (and anything clickable in menu-like moments)
func pad_free() -> bool              # the current step's pad_free()
```

- **Layout.** In `_ready`: `add_to_group(Pad.FOCUS_GROUP)`,
  `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`, `mouse_filter = STOP` and
  `texture_filter = NEAREST`. The children, in order:
  1. the `WashBackdrop` (full rect, `darken = 0.82`, `bank_offset = 150`);
  2. the step host (full rect), which holds the current `HiveStep`;
  3. the room's own overlay (a Control that draws the plank and the card, and ignores the
     mouse);
  4. the `CloseButton`, last.
  - `open()` lends the backdrop its inputs the way `WashRoom.open` does, then calls
    `_backdrop.reset()`.
  - `_process` pushes the sun, tint and shade the way `WashRoom._process` does.
- **The step plank** (top centre): oak, `Style` wood colours `FRAME`/`FRAME_LIT`/`FRAME_LOW`/
  `FRAME_DEEP`.
  - One comb pip per step of *this plan*: `pip_done`, `pip_now` or `pip_todo`, joined by a
    line (honey when done).
  - The label under each pip is `Text.of("HIVE_STEP_" + name.to_upper())` at `TEXT_TINY`
    (13) in `RIBBON_INK` (`GOLD` for the current one), with a dark shade.
  - A later harvest shows 2 pips.
- **The hint card** (bottom centre): paper (`Style.PAPER`, rim `FirstSteps.NOTE_OUTER`, edge
  `PAPER_EDGE`).
  - Its size follows the words: `Text.of("HIVE_HINT_" + name)`. A word between asterisks
    is drawn in `Style.PAPER_HEAD`, the rest in `PAPER_INK`, with no shade (use
    `draw_string`, not `Style.write`).
  - A Kenney prompt icon on its left (`assets/ui/prompts/mouse_click.png`, or `pad_rt.png`
    / `pad_a.png` when `Pad.is_pad()`), drawn at 2 canvas px per tile px.
  - The card swaps words with a quick fade. The done card is `HIVE_HINT_DONE`.
- **The close cross**: `CloseButton` on a small oak plank top right, `pressed` -> `close_asked`.
- **The step sequence**:
  1. `open(true)` builds `hive.plan()`.
  2. For each step: instance the script, `add_child` to the host, `begin()`, and wait for
     its `finished`.
  3. Mark the pip done (the pip fills with honey: 0.3 s), then the `BETWEEN` beat, then the
     next step.
  4. After the catch step, emit `swarm_caught` (the lake turns the hive READY and restores
     the paint).
  5. After the last step, emit `harvested`, show the done card with a burst of stars over
     the plank and `Sfx` `hive_done`, then emit `close_asked` after `DONE_HOLD`.
  - **Closing mid-plan** keeps nothing but what has already been emitted: a caught swarm
    stays caught, and a harvest is only counted on `harvested`.
- **The pad**:
  - `pad_free()` is the step's own. On a hands-on step the step moves the hidden pointer:
    `Pad.move_cursor(Input.get_vector(&"walk_left", &"walk_right", &"walk_up",
    &"walk_down"), delta)`, and reads `Input.is_action_pressed(&"cast") or
    Input.is_action_pressed(&"interact")` as the tool.
  - `pad_focus()` returns the close cross (key `&"close"`) when not free.
  - B (synthetic Escape) closes the room (the lake's Escape chain).

```gdscript
class_name HiveStep extends Control
signal finished
const WAKE_AFTER := 0.4
var room: HiveRoom
func begin() -> void                 # reset; arms the wake gate
func awake() -> bool                 # WashStand's latch: the choosing press released AND WAKE_AFTER passed
func tool_down() -> bool             # Input.is_mouse_button_pressed(LEFT) or (Pad.is_pad() and (cast or interact pressed))
func art_mouse() -> Vector2          # get_local_mouse_position() in painted px of the art grid
func to_canvas(p: Vector2) -> Vector2  # painted px -> local canvas px (room.origin() + p * PIXEL)
func pad_free() -> bool              # default true
func done_once() -> void             # emits finished once, and guards double emits
```

- Each step is a full-rect Control with `mouse_filter = STOP` that draws in `_draw` and
  redraws while alive.
- It reads the mouse through `_gui_input` or polling.
- It must be drivable headless by the harness through public methods (listed per step
  below), **not gated on `awake()`**, the way `WashStand.spray` is not.

### The six steps

All positions are in painted px on the 640x360 art grid (the mockup's coordinates). Every
number here is a first guess.

1. **Catch** (`hive_step_catch.gd`). The `branch` enters from the top left, with the swarm
   hanging at `hang`: a `bee_mass`-style clump of `bee_r`/`bee_r_rest` sprites, laid out
   once from a seed, tall 70. The `box` stands below on the lawn, its mouth under the
   swarm, in a warm glow.
   - **Interaction**: press on the branch or swarm and drag left and right. The bough bends
     with the pointer (a spring) and the swarm sways. Each swing past 18 px from where the
     press began, reversing direction, is a **shake**.
   - Each shake drops a third of the swarm as a falling clump: it falls with gravity into the
     box, bees pour after it, and 3-4 bees fly off.
   - The third shake drops the last of it, the queen with it. The box glows gold, and a
     crown pops over it with stars and `hive_crown`.
   - Pad: hold A (or RT) and move the stick left and right.
   - `shake()` is the harness hook, with no gate.
   - Satisfying: the branch springs back with overshoot, the clumps squash on landing, and
     the bees boil over the top bars for a moment.
2. **Smoke** (`hive_step_smoke.gd`). `hive_front` stands centre left, bees at its
   entrance, the hum marks over the roof; the `smoker` stands right.
   - **Interaction**: each press (click or tap anywhere, pad A/RT) pumps the bellows. The
     bellows squash on the press and spring back on the release. A puff (`puff_s`→`puff_l`)
     leaves the `nozzle`, drifts and grows along an arc to the `entrance`, and dissolves.
     Each puff plays `hive_puff`.
   - Every puff lowers `calm` (hum marks shrink and fade). Bees on the board walk in.
   - 5 puffs finish it: the hum marks are gone, the last bees file in, a soft sparkle over
     the roof.
   - `puff()` is the harness hook.
3. **Queen** (`hive_step_queen.gd`). The `frame_brood` is held up by `glove_l`/`glove_r` at
   the ears, with `hive_open` behind at the left edge.
   - 30 workers wander slowly on the comb (random walk, turning, `bee_r`/`bee_u`/`bee_d`,
     mirrored for left). The queen (`queen_r`) walks slowly too, and her court of 8 bees
     faces her and follows.
   - **The cursor is a magnifying lens**, radius 33 painted px. Inside it the comb and the
     bees are drawn at twice the size (a child with `clip_children` under a circle, or the
     same draws scaled 2x about the lens centre inside a clip).
     - The rim is brass, the handle wood, with a sheen.
   - **Click (A) with the queen inside the inner half of the lens** finds her: a gold halo
     on the lens, a crown pops above, stars, and `hive_crown`.
     - A click that misses makes the bees under the lens scatter a little and buzz. It has
       no penalty.
   - Pad: the stick moves the lens (free pointer), with **a gentle pull toward the queen
     when within 1.5 lens radii**, like the aim assist. A finds her.
   - `find_at(p)` is the harness hook: it returns true if the queen is found at `p`.
     `queen_pos()` exposes where she is.
4. **Uncap** (`hive_step_uncap.gd`). The honey frame is held by the gloves. It shows
   `frame_open` fully, with `frame_capped` drawn **only below the cut line** (a
   `draw_region` of the capped piece from the cut row down).
   - **The knife follows the pointer's y** (eased, smooth: an exponential ease at 18/s) and
     only moves down. The blade spans the comb.
   - The **cut line snaps to comb rows** (pitch 7): each row passed pops open with a
     crackle (`hive_crackle`, rate-limited to 20/s) and a glint.
   - A **rolled wax sheet** rides the blade, thickening with rows cut. Honey drips run off
     the hot edge; heat shimmer; faint ghost copies of the blade trail above it (the
     glide).
   - The knife's sizzle loop (a room-owned player) plays while it moves.
   - When the cut reaches the bottom, the face is done:
     - **the frame flips** (a squash to 0 width and back, 0.35 s) to its second face,
       capped again;
     - the second face's cut finishing ends the step, with a golden sweep of stars down
       the open comb.
   - Pad: the stick's y drives the knife, or RT/A held glides it down at a steady pace.
   - The harness hooks are `cut_to(share)` (0..1 of the current face) and `face()`.
   - Anything already cut stays cut.
5. **Crank** (`hive_step_crank.gd`). The `extractor` stands centre, the crank's `knob` on
   a horizontal circle about the `shaft` (an ellipse rx 51, ry 13, arm drawn as a steel
   line from the shaft to the knob).
   - A dashed gold guide ring is drawn, its far half behind the extractor and its near half
     in front.
   - **Interaction**: press near the knob, or anywhere, and **turn in circles** round the
     shaft's screen point. Angular progress accumulates from the pointer's angle change
     (either direction counts as forward), and the speed is capped at 1.6 turns/s.
   - The drum's inner blur spins with speed. Honey is flung over the rim at speed. The
     whirr loop (room-owned) follows speed by pitch.
   - **Beat notches** (4 on the ring) pulse on `Music` `beat_clock()`. Passing the knob
     over a notch as it pulses sparkles it. There is no penalty off the beat.
   - 6 turns finish it: the drum slows, honey runs from the `gate` into the bucket with a
     splash crown, stars.
   - Pad: the angle of the left stick, when pushed past 0.5, drives the knob, capped the
     same. RT/A also turn it steadily.
   - `turn(radians)` is the harness hook. `turns()` is the progress.
6. **Pour** (`hive_step_pour.gd`). The `bottling` bucket stands on its stand top centre,
   its gate over an empty jar. Filled jars wait on a board to the right; 3 are to fill.
   - **Hold** (mouse or A/RT): the gate opens and a thick honey ribbon flows (a 6→4 px
     stream with a wobble and a lit edge). It coils where it lands. The jar fills at 0.34
     of its height per second. A glug loop (room-owned) plays while pouring.
   - A gold dashed **fill line** sits at 0.86 of the jar and glows as the honey nears it.
   - Let go at or over 0.7: the jar is done. It slides to the board, its lid pops on
     (`jar_full`), stars burst, `hive_pop` plays, and the next empty jar slides in.
     - At or over 0.97, honey runs down the jar's side. It still counts; there is no
       failure.
     - Let go under 0.7: the jar waits for more.
   - 3 jars finish it.
   - Pad: hold A/RT.
   - The harness hooks are `pour(seconds)` and `release()`; `jars_done()` is the progress.

## 7. Sounds (built in code: scripts/hive_sounds.gd)

- **One-shots**, registered as names in `Sfx.SOUNDS` with their streams **built in
  `Sfx._ready` after `_load_recordings()`**, only when no file was found (so a later
  `assets/sfx/<name>.wav` wins):
  - `hive_swarm` (AMBIENT: a swelling buzz, 1.4 s)
  - `hive_puff` (a bellows puff, 3 takes)
  - `hive_crackle` (a wax crackle, 3 takes)
  - `hive_pop` (a jar lid pop)
  - `hive_crown` (a bright three-note chime)
  - `hive_done` (a warm flourish)
  - dBs are in (-60, 0] and are first guesses.
  - Put `hive_swarm` and `hive_hum` in `Sfx.AMBIENT`.
  - **Do not name anything `play_catch` or `play_found`.**
- **Hum bed**: `hive_hum` (a 2 s seamless loop, AMBIENT) through a `_bed()` player in `Sfx`:
  - `set_hive_hum(share: float)` sets the want dB (`share` 0..1 of `HIVE_HUM_DB`, silent at
    0);
  - it is gated on `not shopping and not indoors`;
  - `hush()` resets it.
- **Room-owned loops**: `hive_sizzle` (the knife), `hive_whirr` (the extractor), `hive_pour`
  (the stream).
  - Each is loaded from `res://assets/sfx/<name>.ogg` if it exists, else built.
  - Played by the step's own `AudioStreamPlayer` with `bus = Prefs.BUS_SFX`, starting at
    `Prefs.BUS_SILENT`, eased with `move_toward`.
- **Builders** (`HiveSounds.make(name) -> AudioStreamWAV`):
  - seeded local RNG;
  - mono 16-bit at 22050 Hz;
  - loops whole-cycle or tail-crossfaded;
  - peak-normalised to 0.8;
  - short: a take under 1.5 s, a loop at most 2 s.
  - Keep the boot cost under 40 ms total.

## 8. Strings (locale/translations.csv; then `tools/build_translations.py`; then import)

| key | en | pt_BR (source) | `_where` | `_size` | `_least` | `_width` |
|---|---|---|---|---|---|---|
| HIVE_SWARM | A swarm has come to the hive! | Um enxame chegou à colmeia! | moment_card.gd | 20 | 16 | 1190 |
| HIVE_STEP_CATCH | Catch | Pegar | hive_room.gd | 13 | 11 | 80 |
| HIVE_STEP_SMOKE | Smoke | Fumaça | hive_room.gd | 13 | 11 | 80 |
| HIVE_STEP_QUEEN | Queen | Rainha | hive_room.gd | 13 | 11 | 80 |
| HIVE_STEP_UNCAP | Uncap | Abrir | hive_room.gd | 13 | 11 | 80 |
| HIVE_STEP_CRANK | Crank | Girar | hive_room.gd | 13 | 11 | 80 |
| HIVE_STEP_POUR | Pour | Envasar | hive_room.gd | 13 | 11 | 80 |
| HIVE_HINT_CATCH | \*Shake\* the branch over the box | \*Sacuda\* o galho sobre a caixa | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_SMOKE | \*Puff\* the smoker, the bees settle | \*Solte\* fumaça, as abelhas se acalmam | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_QUEEN | \*Find\* the queen, she wears a white dot | \*Ache\* a rainha, ela tem um ponto branco | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_UNCAP | \*Draw\* the hot knife down the comb | \*Passe\* a faca quente pelo favo | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_CRANK | \*Turn\* the crank in steady circles | \*Gire\* a manivela em círculos | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_POUR | \*Hold\* to pour, let go at the line | \*Segure\* para despejar, solte na linha | hive_room.gd | 20 | 16 | 600 |
| HIVE_HINT_DONE | \*Harvest\* done! The jars go on the shelf | \*Colheita\* feita! Os potes vão para a prateleira | hive_room.gd | 20 | 16 | 600 |

- Fill es/de/fr/ja/zh_CN/ko with natural machine drafts and every `_back_<locale>`.
  `_note`: "Hive room (2026-09-30)".
- qps is left for the builder to fill.
- Read the words at draw time through `Text.of(key)` (runtime-built keys), never cached in
  `_ready`.

## 9. Lake integration checklist (the one integration agent)

Mirror the pump everywhere. Every line of the map's pump checklist applies:
- **Creation**: `Lake._ready` creates `_hive` right after the pump, **before
  `_grow_nature()`/`_start_weather()`**.
  - `const HIVE_AT := Vector2(-2.02, 1.98)` offset from `Iso.shed_centre()`, snapped to an
    even world position; `const HIVE_RANGE := 1.5`.
  - `Hive.tile`, and the statics from the json.
- **Borrowed lakes** hold the arc (`_hive.held = true`, like the tours in `_raise_front`),
  unless `static var force_hive` is set (read once).
- **Walkers and statics**:
  - `player.gd` `_can_stand`/`_slide`: rectangle extents, measured from
    `Hive.tile + Hive.centre`.
  - `dog.gd` `_may_stand`/`_bumped` (return `[Hive.tile + Hive.centre, Hive.half +
    Vector2(keep, keep)]`)/`_elbow_room`.
  - `flora.gd` `_sow`: `Hive.covers(at, 0.5)` or (`Hive.covers(at, 3.5)` and
    `Hive.hides(at)`).
  - `wildlife.gd` `_add_shore`/`_on_sand`, `puddles.gd` `may_lie` (covers, plus not under
    the picture).
  - `_weather_roofs` appends `_hive` after the yard and the pump (the hut stays index 0);
    `_weather_statics` too.
- **Draw order**: `_walker_layer` puts a walker north of the footprint and inside the
  picture's x span on BEHIND_CRATE.
- **Input**: `_at_hive()` (`Hive.tile` set, `_hive.actionable()`, distance to the footprint
  centre < HIVE_RANGE), in both interact chains before `_at_shed()`.
  - The lamp is `_hive.lit`, set in `_process`.
- **The room**: `_hive_room`, `_hive_open`, and `_set_hive_room(open)` built lazily like
  `_set_wash`.
  - Lend `day`, `filth_left`, `pack_size`, `fleet_size`, `rubbish`, `flock` and `hive`;
    connect `close_asked` → `_shut(_set_hive_room)`.
  - `swarm_caught` → the hive goes READY (paint back), save.
  - `harvested` → jars += 3, harvests += 1, first_done = true; BUSY with `refill_at` (or
    DONE at 4); save.
  - Add `_hive_open` to:
    - `_panelled()`, `pad_cursor_wanted()`, `_hold_the_angler()` (and call it),
      `_push_rooms()` (`music.muffled`), the Escape chain, the desk E (closes the room);
    - both `open_upgrades` guards and pad Start;
    - `_enter_menu` (close), `_world_frozen()` (the hive node).
  - Hide `_skin`/`_coins` while it is open.
- **The swarm gate**: `_hive_step(delta)` throttled to 1 s in the `not _in_menu and not
  _world_paused` block of `_process`.
  - EMPTY → SWARM when the gate passes (unless held).
  - BUSY → READY when `play >= refill_at`.
  - Push `play_now`.
  - The refill time is `lerp(11, 5, clamp(hosts / 40.0, 0, 1)) * 60` s at harvest.
- **Flora**: new `Flora.island_hosts() -> int` (grown bee hosts on island ground) and
  `Flora.island_host_spots() -> PackedVector2Array` (their world heads).
- **The moment**: generalise `_moment_owed` into a queue of `{at, text, seen: Callable}`.
  - The wildlife moment enqueues `{WILDLIFE_BACK, set _wildlife_seen}`; the swarm enqueues
    `{HIVE_SWARM, set hive.moment_seen}`.
  - Keep every existing wait and `_check_signals` passing.
  - **Fix the zoom bug**: `if _glide < 0.0 and _moment < 0.0: _push_zoom()`.
- **Save**: `"hive": _hive.to_save()`. On load:
  `_hive.from_save(save.get("hive", {}) if save.get("hive", {}) is Dictionary else {})`,
  **assigned every load**, after the version and seed refusals. No `SAVE_VERSION` bump.
- **The hum**: each frame `Sfx.main().set_hive_hum(share)`, where share is 0 for
  EMPTY/BUSY/DONE-far, the distance falloff against `Iso.tile_circle_extent(Dog.HEAR)`, and
  1.0 at the hive for SWARM/READY (0.5 for BUSY/DONE colony).
- **`wash_backdrop.gd`**: `var darken := 0.66` replaces the const at every use (default
  unchanged); `var bank_offset := 0.0` shifts the far bank strip's tiling. Nothing else
  moves; the wash room is unchanged.

## 10. Tests and probe

- **`test_lake`**: a new stage `37: _stage_hive()` at the end; `_stage_first_steps`'s
  final `_finish()` becomes `_advance()`, and `_stage_hive` ends with `_finish()`. Checks:
  - **placement**: on lawn, clear of the hut, crate and pump; the footprint covers its rect
    only; the angler is refused inside and `_at_hive` is true beside it once actionable;
    `_at_hive` and `_at_shed` are never both true.
  - **walker layer**: north under, south over, at both the hive and the shelf end.
  - **flora**: no candidate on the footprint or hidden behind the picture; the roof list
    keeps the hut at index 0.
  - **the gate**: not before 15 min, nor under the hosts; it fires after; held for a
    borrowed lake.
  - **the moment**: queued, the card text is `Text.HIVE_SWARM` and is not the raw key; the
    wildlife moment still works; both owed at once are both shown.
  - **the room**: opens only when actionable; it holds the angler; it is panelled; Escape
    closes it; `_enter_menu` closes it; the music is muffled; `Sfx.indoors` is false.
  - **the steps**: driven by their hooks to the end.
    - The first harvest's plan is 6 steps from SWARM (5 from READY with first_done false),
      and a later one is 2.
    - The jars are +3 and capped at 12; the money, `unlocked`, `unwashed` and the crate are
      unchanged.
  - **refill**: BUSY → READY at `refill_at`.
  - **save**: the round trip, and an absent key gives EMPTY.
  - **sounds**: the built names are loaded, the hum is silent indoors and while shopping,
    the room's loop players are on SFX.
  - **text**: every `HIVE_*` key reads back as other than its own name.
- **The probe `tools/shot_hive.gd/.tscn`** (desktop, `--fixed-fps 60`):
  - its own save `user://probe_hive.save`, deleted at start;
  - the lake under its own node;
  - `force_hive`;
  - a wall-clock quit at 150 s.
  - It saves `tools/last_hive_{empty,swarm,ready,busy,moment}.png` (island crops) and
    `tools/last_hive_room_{catch,smoke,queen,uncap,crank,pour,done}.png` (mid-step, driven
    by the hooks), plus `tools/last_hive.log`.
  - Run it windowed:
    `<exe> --path . --fixed-fps 60 res://tools/shot_hive.tscn --log-file tools/last_hive_engine.log`.

# Tornado mock

A shared harness for trying looks for the tornado (a waterspout) event. The harness plays
one fixed, deterministic 16 s event on a real lake and does everything that happens to the
lake; a **look** only draws the funnel and the debris it carries.

Nothing here is game code. Only files under `tools/tornado_mock/` are touched.

## Run

Desktop build, **never `--headless`** (nothing renders, no shader compiles). Always pass
`--log-file` and read it: GDScript errors do not stop the run.

```
"C:/Users/Administrador/Desktop/Godot_v4.7.1-stable_win64.exe" --path . --fixed-fps 60 res://tools/tornado_mock/shot_a.tscn --log-file tools/tornado_mock/a_engine.log
powershell -ExecutionPolicy Bypass -File tools/tornado_mock/make_gif.ps1 a
```

- `shot_a.tscn` / `shot_b.tscn` / `shot_c.tscn` each load `look_<letter>.gd`. A missing
  look falls back to `look_a.gd` (logged). `TORNADO_LOOK=b` overrides the scene's letter.
- `TORNADO_WIDE=1` films the same event from further out (zoom 0.67), full window scaled
  to 960x540, into `out_<look>/wide/`; `make_gif.ps1 <look> wide` builds from those.
- About 60-90 s wall time. Quits on its last frame and on a 150 s wall clock.
- Own save `user://tornado_mock.save`, deleted first; the lake hangs under the harness node
  (not the root), so no menu, and `autoload_save` is off.

## Outputs (`out_<look>/`)

| file | what |
|---|---|
| `f_0000.png`... | 480 frames, 30 fps (every 2nd physics frame), an 800x640 crop of the 1920x1080 window (`CROP`), base ~560 px down it |
| `still_{touchdown,roam_mid,hit2,collapse,calm}.png` | full window at 1.5 / 6.0 / 11.1 / 13.1 / 15.5 s |
| `log.txt` | per phase: lifted, flung, landed, filth remaps, carried now/most; each hit; each still |
| `tornado_<look>.gif`, `.mp4`, `sheet_<look>.png` | from `make_gif.ps1` (gif 600 px wide, nearest, no dither; 4x3 contact sheet) |

## The timeline (tornado clock, seconds)

| t | phase | |
|---|---|---|
| 0-2 | `touchdown` | strength 0 -> 1 (smoothstep), drifting slowly; a lightning strike at 0 |
| 2-9.5 | `roam` | along a curve round the island's east/south-east, 5.5-8.5 tiles past its shore, 72 px/s |
| 9.5, 11.0 | `hit` (0.6 s each), then `roam` at half speed | net lands; strength steps to 0.74, then 0.5 (dips lower first and recovers over ~0.25 s); knocked back away from the angler; 2 pieces shaken loose |
| 12.5-14 | `collapse` | third net; strength to 0 over ~1.2 s with a wobble; everything carried is shed, highest first, one every 0.06 s; lightning strike |
| 14-16 | `gone` | a few rings where it stood; the filth map shows where things landed |

The harness does, identically for every look: lifting (`LakeGrid.take` of the top piece
within 0.9 tiles of the base, one every 0.14 s, never a find, tier <= 3, a tile not again
for 3 s, 14 carried at most), flinging (one every 1.2 s once more than 6 are carried, every
0.55 s when full; lands 2.5-4.5 tiles out on a floating tile, `LakeGrid.insert` on top,
splash + ring + bumps), shoving and bobbing the pieces round it (`shove_to` tangentially
within 2.6 tiles, `bump` within 1.8), foot spray (`WaterSplash.drip`), spiralling rings
(`WaterSplash.ripple`), hit bursts, the filth remap (every 0.5 s, the lake's own worker
thread), the stand-in net, the shadows of carried and flung pieces, and drawing the flung
pieces themselves.

## The look API

A look is a script `extends Node2D` (no `class_name`) at `tools/tornado_mock/look_<x>.gd`:

```gdscript
func setup(ctx: Dictionary) -> void      # once
func tick(delta: float, s: Dictionary) -> void   # every physics frame, then queue_redraw()
func _draw() -> void                     # draw the funnel and the carried debris
```

The harness makes it a child of the lake (world space), sets `position` to the **base**
(where the funnel meets the water) every frame and `z_index = 20`. Draw in local
coordinates: (0, 0) is the base, up is -y.

### `ctx` (setup)

`main` (the Lake), `grid` (LakeGrid), `splash` (WaterSplash), `palette` (Palette.master()),
`art_pixel` (2.0), `day` (DayCycle), `weather` (Weather), `height` (300), `base_r` (12),
`top_r` (72). A look may call `splash` itself for extra water effects; it must not change
the grid.

### `s` (every tick)

| key | type | |
|---|---|---|
| `phase` | String | `touchdown`, `roam`, `hit`, `collapse`, `gone` |
| `t` | float | seconds in this phase |
| `time` | float | seconds since touchdown began (0-16) |
| `strength` | float | 0-1 overall size: grows on touchdown, steps on each hit, 0 at the end of collapse |
| `hits` | int | 0-3 |
| `hit_flash` | float | 1 at a hit, decays to 0 in ~0.45 s |
| `since_hit` | float | seconds since the last hit (large before the first) |
| `collapse` | float | 0-1 through the collapse |
| `velocity` | Vector2 | base's world px/s |
| `spin` | float | accumulated angle (rad), 3-7 rad/s with strength |
| `height` | float | funnel height at strength 1 (300 world px); actual = `height * strength` |
| `lean` | Vector2 | where the top trails (eased, from velocity); already inside `axis_at` |
| `axis_at` | Callable(frac) -> Vector2 | the funnel's axis at `frac` of its height (0 water, 1 top), local; includes lean, a snake and the hit jolt |
| `radius_at` | Callable(frac) -> float | funnel radius there, world px, strength and hit swell applied |
| `debris` | Array[Dictionary] | the carried pieces, see below |
| `flung` | Array[Dictionary] | pieces in flight, see below (the harness draws them) |
| `net` | Dictionary | the stand-in net, empty when none: `state` (`fly`/`lie`/`reel`), `at`, `ground`, `hand` (world), `open` 0-1, `fade` |
| `base` | Vector2 | the base in world px (= the look's position) |
| `tint`, `ink` | Color, float | the day's light (already applied to the whole canvas by the lake) and shadow ink |
| `rain`, `flash` | float | rain 0-1 (held at 1), lightning flash 0-1 |

**Use `axis_at`/`radius_at` for the funnel's shape**: the debris orbits on them (radius +
6-22 px margin), so a funnel drawn off its own curve will have pieces inside or floating
off it. If a look wants a different profile, change `radius_at` in the harness for all.

### Debris fields (`s.debris[i]`)

`def` (TrashDef), `def_index`, `local` (Vector2, sprite centre relative to the base),
`ground` (its point on the water under it, relative to the base), `height` (world px up),
`angle` (rad; 0 right, PI/2 front), `radius`, `front` (bool, `sin(angle) > 0`), `depth`
(`sin(angle)`, sort key), `rot` (sprite turn), `scale`, `alpha`, `state` (`lift` for the
0.9 s it rises from the water, then `orbit`), `band` (0-1 height it settles at), `age`.

### Flung fields (`s.flung[i]`, world coordinates)

`def`, `at` (sprite centre), `ground` (shadow point), `height`, `from`, `to`, `t`, `dur`,
`rot`, `scale`. Drawn by the harness at z 19 (under the funnel); a look may add trails in
its own `_draw` (convert with `to_local`).

### Draw order and layers

Inside the look's `_draw`, in this order:

1. `DebrisDraw.draw_debris(self, s, false)` (the back half, behind the funnel)
2. the funnel (and anything behind/around it: skirt, cloud)
3. `DebrisDraw.draw_debris(self, s, true)` (the front half)
4. anything on top (spray over the foot, hit flash)

Z: water 1, splash 4, rubbish soup 5, harness shadows 6, walkers 9, hulls 12, flung pieces
and the net 19, **the look 20**, beams 20, birds 21, rain 22. A look may add child nodes at
other z (e.g. a low skirt under the rubbish at 4) with `z_index` set on the child.

### Helpers (`debris_draw.gd`, preload it)

```gdscript
const DebrisDraw := preload("res://tools/tornado_mock/debris_draw.gd")
DebrisDraw.draw_debris(canvas, s, front)
DebrisDraw.draw_piece(canvas, def, at, rot, scale, alpha, tint)
DebrisDraw.pixel_ellipse(canvas, centre, rx, ry, colour)       # filled, whole art pixels
DebrisDraw.pixel_ring(canvas, centre, rx, ry, colour, thick, from, to)  # outline / arc
DebrisDraw.pixel_line(canvas, a, b, colour, thick)
DebrisDraw.draw_shadow(canvas, at, half_w, alpha, ink)
DebrisDraw.snap(canvas, local)   # a local point onto the world's 2 px art grid
```

All take local points and snap to the **world** art grid (they read the canvas's global
position), so shapes stay on the grid while the base glides.

## Pixel-art rules (the game's)

Whole art pixels (2 world px) for every shape; palette colours (`Palette.master()`:
`water_*` ramps, `foam`, `foam_light`, `foam_dirty`, `sky_*`) or `Style` constants
(`preload("res://scripts/style.gd")`, e.g. `Style.NET_INK`); no gradients, no dithering;
pattern motion on stepped time (8 fps, `floor(s.time * 8) / 8`); positions may glide.

## Pitfalls hit building this

- `Style` has no `class_name`: `preload("res://scripts/style.gd")`. `Palette`, `TrashDef`,
  `LakeGrid`, `WaterSplash`, `Iso` do have one and can be named.
- `round()` returns a Variant: use `roundf` with `:=`, or the script fails to parse (and the
  whole harness with it, since the look is loaded by path).
- The look is instanced with `set_script` on a plain `Node2D`: no `_ready` ordering tricks,
  do set-up in `setup()`.
- `LakeGrid.take` / `insert` restamp the soup; never call them from a look.
- The lake's `_on_net_caught` marks the filth map stale; the harness moves the meter by hand
  instead so the remap stays on its 0.5 s beat.
- Randomness: the harness seeds the global RNG and its own, so every look sees the same
  lifts, flings and landings. A look using `randf()` in `_draw` would change the splash
  layer's rolls after it; use a local `RandomNumberGenerator` or a hash.
- The rain is held at full and the lake is dark under it; the hour is held at
  `DAY_PHASE` 0.5 and random lightning is off (strikes only at touchdown and collapse).

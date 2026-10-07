class_name Wildlife
extends Node2D
## The animals that come back with the clean water (2026-09-22, `/grill-me` with Richard):
## frogs on the beaches and the pads, turtles basking at the water's edge, ducks with their
## ducklings landing on clean water, and dragonflies darting over it. Bees are Flora's.
##
## Purely ambient, like the fish: nothing catches them, nothing pays for them, nothing is
## saved. They live only where the filth map calls the water clean — the honest map, never a
## catch patch — and there are more of them the more of the lake is clean (`stage`), all of
## them from the first clean water. They do flee: a net landing, the angler or a dog walking
## up, a hull coming by. A frog jumps in, a turtle pulls its head in or dives, the ducks take
## off, a dragonfly darts away.
##
## Art: the frogs are the Pixel Frog pack recoloured onto the palette, everything else is
## built by rule (tools/build_wildlife.py). Pictures face left and are mirrored for right.
## Four draw layers: under the water's surface (tracks, and every shadow on the lakebed),
## what is under the water drawn through it, on the water and the beaches (the animals, and
## every shadow on the land or the water's surface, the flying ones' included), and in the
## air (flying ducks, dragonflies). Nothing is drawn on the air layer but the fliers
## themselves: a shadow lies on the surface it falls on.
##
## **One sun** (2026-10-02, `/grill-me` with Richard): every shadow here is `Shade`'s ink for
## the surface it falls on (`Shade.On`: land, the water's surface, the bed), at the day's
## strength, so it greys with the weather and flashes with the lightning like the rest of
## the lake. What stands on the ground is its own picture laid down by `Shade.lying`; what
## is up in the air throws it from the ground point plus `Shade.drop` of its height; what is
## under the water throws it onto the bed by the depth (`Fish.shadow_drop`). No caster here
## picks its own colour, alpha or gain.

const FROG_SHEETS := ["res://assets/wildlife/frog_green.png", "res://assets/wildlife/frog_brown.png"]
const CRITTERS := "res://assets/wildlife/critters.png"
const CRITTER_TABLE := "res://assets/wildlife/critters.json"
## World px to a painted px, the game's own.
const SCALE := 2.0
## Nothing goes away where it can be seen (2026-10-06, Richard: "wildlife suddenly
## disappearing or fading out, it should not happen where player can see"). An animal leaving
## (a fleeing bank animal, a songbird or a brood flying off, a crayfish or a fish school whose
## water turned) is only taken off once it is this far outside the view, world px; until then
## it keeps going, at full strength. `_in_view`.
const VIEW_MARGIN := 48.0
const BROOD_VIEW_MARGIN := 160.0
## A frog cell is 16 painted px square (the pack halved); feet on row 15, column 8.
const FROG_CELL := 16.0
const FROG_FOOT := Vector2(8.0, 15.0)
## Frogs are drawn 1.2x smaller than their art's grain (2026-10-06, Richard), sitting,
## hopping and swimming: drawn smaller, not rebaked, picked off tools/last_shrink_sheet.png
## (the rebake lost the face and mangled the swimming shape). Fractional pixels, accepted.
const FROG_DRAWN := 1.0 / 1.2
const FROG_ART := SCALE * FROG_DRAWN

## How many of each at a fully clean lake; `ceil(most * stage)` from the first clean water.
const FROGS_MOST := 30
const TURTLES_MOST := 14
const BROODS_MOST := 5
const DRAGONFLIES_MOST := 20
## Songbirds (2026-10-03, `/grill-me` with Richard): Kelano Studio's Wild Birds, four kinds,
## on the sand of both shores and the island's lawn, never on the water. A landing spot is
## open only when the shore water beside it is clean; how many are about is the clean share.
const SONGBIRDS_MOST := 24
const BIRD_SPECIES: Array[String] = ["sparrow", "tit", "bluebird", "cardinal"]
## The pack's 32 px cells are halved by the builder; drawn at one world px a painted px.
const BIRD_SCALE := 0.5
## How far up the beach (or onto the island's lawn) from its shore water a spot may be, tiles.
const BIRD_WATER_REACH := 3.5
## Spots dealt round each shore spot, once, at build.
const BIRD_SPOTS_PER_SHORE := 3
## Something moving inside BIRD_WARY walks a bird away; inside BIRD_SHY it flies. Tiles.
const BIRD_WARY := 2.6
const BIRD_SHY := 1.4
## How far a flushed bird looks for somewhere else to land, tiles; none, it leaves the lake.
const BIRD_FLUSH_REACH := 7.0
const BIRD_FLUSH_LEAST := 2.0
const BIRD_WALK := 12.0
const BIRD_SCURRY := 30.0
const BIRD_FLY := 120.0
const BIRD_HOP_ARC := 28.0
const BIRD_FROM := 700.0
const BIRD_IN_ALT := 140.0
const BIRD_GAP := Vector2(1.5, 5.0)
const BIRD_IDLE := Vector2(1.0, 4.0)
const BIRD_IDLE_FPS := 5.0
const BIRD_FLY_FPS := 12.0
## One walk frame every this many world px walked: the feet step with the ground covered.
const BIRD_STEP_PX := 2.5
## A peck: PECK_TIME seconds over the five frames, the head lowest at PECK_HIT of the way,
## which is what lands on the beat. A bird pecks one to PECKS_MOST times, a beat apart.
const PECK_TIME := 0.42
const PECK_HIT := 0.5
const PECKS_MOST := 3
## The flying shadow shrinks and thins with height, as the ducks' does, up to this altitude.
const BIRD_SHADE_ALT := 120.0
## The meter's reading the late arrivals wait for, and they fill in from it to a cleaned lake.
const LATE_FROM := 0.6
## Seconds between reconciling what should be about with what is.
const RECKON_EVERY := 2.0
## Crayfish on the lakebed (2026-09-30, the lakebed pass): how many at most, how deep they
## go (the shader's depth; the bed is sharp to about here), their crawl and their dart in
## world px a second, how long they rest and crawl, and how near a threat has to come, in
## tiles. They flee backwards, tail first, the way a crayfish does.
const CRAYFISH_MOST := 12
## Crayfish are drawn 1.5x smaller than their art's grain (2026-10-06, Richard), drawn smaller
## rather than rebaked or redrawn (Richard's pick off tools/last_shrink_sheet.png).
const CRAY_DRAWN := 1.0 / 1.5
## 2026-10-01 (Richard): off the shallows, into the middle and deep bands, and they never
## dart from anything — not walkers, hulls or nets. `_cray_fright` is unused now.
const CRAY_SHALLOWEST := 0.3
const CRAY_DEEPEST := 0.85
const CRAY_CRAWL := 7.0
const CRAY_DART := 70.0
const CRAY_REST := Vector2(2.0, 6.0)
const CRAY_WALK := Vector2(1.5, 4.0)
const CRAY_STEP_PX := 3.0
## Seconds between one brood arriving and the next, at most one at a time.
const BROOD_GAP := Vector2(6.0, 16.0)

## Flee radii, tiles: something this close sends the animal off.
const FROG_SHY := 1.6
const TURTLE_SHY := 1.3
const DUCK_SHY := 2.6
const FLY_SHY := 1.1

## Frog timings. A sitting frog waits FROG_SIT_BEATS beats, then picks what to do and the
## beat to do it on: a hop or a jump is launched early enough to **land** on that beat, a
## croak starts on it and swells over FROG_CROAK_BEATS. Each frog picks its own beats, a
## few ahead (FROG_PICK_AHEAD), so the beach grooves without moving in lockstep.
const FROG_SIT_BEATS := Vector2i(3, 10)
const FROG_PICK_AHEAD := Vector2i(1, 3)
const FROG_CROAK_BEATS := 2.0
## A cue whose start is this many beats gone is a clock jump, not a late frame: re-pick it.
const CUE_MISSED := 0.25
const FROG_HOP_TIME := 0.45
const FROG_HOP_REACH := 0.5
const FROG_HOP_HIGH := 5.0 * FROG_DRAWN
const FROG_JUMP_TIME := 0.62
const FROG_JUMP_HIGH := 14.0 * FROG_DRAWN
const FROG_SWIM_SPEED := 22.0
const FROG_SWIM_FPS := 6.0
## How far a frog will swim for a pad, tiles.
const FROG_PAD_REACH := 7.0

## Turtle timings.
## Slow, to match the pack's feet (Richard, 2026-10-05: "walk much slower to match the feet
## animation"): a walk cycle carries the body about 2 painted px, so at `TURTLE_STEP_PX` a frame
## the eight frames play at about 8 a second. It swims a little quicker, paddling on the clock
## (`TURTLE_PADDLE_FPS`). And it rests far more than it moves ("it should idle much more than
## walk and swim"): long basks, rarely down to the water (`TURTLE_TO_WATER`), and a short
## paddle (`TURTLE_PADDLE_ON`) before it comes out again.
const TURTLE_WALK := 2.5 * TURTLE_DRAWN
const TURTLE_SWIM := 5.0 * TURTLE_DRAWN
const TURTLE_BASK := Vector2(25.0, 60.0)
const TURTLE_TO_WATER := 0.2
const TURTLE_PADDLE_ON := 0.25
const TURTLE_PADDLE_FPS := 6.0
const TURTLE_TUCK := 3.0
const TURTLE_UNDER := Vector2(2.0, 4.0)
## The walk is paced by ground covered, not by the clock: a turtle's legs step once for
## every TURTLE_STEP_PX world px it moves, so a turtle that is not going anywhere does not
## move its legs. Four frames, one leg at a time (tools/build_wildlife.py TURTLE_STRIDE).
const TURTLE_STEP_PX := 0.3 * TURTLE_DRAWN
const TURTLE_STEPS := 8
## The pack turtle (2026-10-05, Richard bought TurtlePaid; supersedes the rule-built turtle):
## drawn at one world px a painted px. At rest it idles or sits with its head bobbing to the
## song, one bob a beat (half of them half a beat behind, `nod_seed`), or sleeps; a fright on
## land plays Hide into the shell and back out (`TURTLE_HIDE_FPS`). On the water it swims the
## dogs' and the capybaras' way: cut at the waterline (`TURTLE_SINK`), bobbing, a foam collar,
## the ferry's streak and one ring going in.
## Drawn 1.3x smaller than that since 2026-10-06 (Richard), drawn smaller rather than rebaked,
## the bunnies' and snakes' pick (`TURTLE_DRAWN`): its walk, its stride, its swim, its streak,
## its rings and its plant-cover box come in with it, so the feet still carry the body.
const TURTLE_DRAWN := 1.0 / 1.3
const TURTLE_ART := 0.5 * TURTLE_DRAWN
const TURTLE_POSES := {"idle": 0.45, "sit": 0.35, "sleep": 0.2}
const TURTLE_SLEEP_FPS := 5.0
const TURTLE_HIDE_FPS := 20.0
const TURTLE_HIDE_FRAMES := 13
const TURTLE_SINK := 0.45
## The walking turtle's own height in painted px: its crop is taller, padded for the sleep
## frames' Z's, and the waterline is a share of the turtle, not of the padding.
const TURTLE_INK := 15.0
const TURTLE_BOB := 1.0
const TURTLE_BOB_RATE := 2.6
## The head's slow nod: up one painted pixel for NOD_UP seconds out of every NOD_EVERY,
## each turtle out of step with the others. Resting and walking; not swimming or tucked.
## Since the beat pass: on every beat of the song, up on the beat and down on the off-beat,
## half the turtles a half beat behind the other half so they are not all in lockstep.

## Ducks.
const DUCK_SWIM := 14.0
const DUCK_FLY := 130.0
const DUCK_ALT := 150.0
const DUCK_FROM := 900.0
const DUCK_STAY := Vector2(40.0, 100.0)
const DUCKLINGS := Vector2i(0, 5)
## Leader positions kept for the ducklings to follow, one every TRAIL_STEP seconds.
const TRAIL_STEP := 0.12
const TRAIL_GAP := 4
## A flying brood's shadow shrinks and thins with the height the flight has carried it to,
## as the pigeons' does: a shadow the same size at every height reads as a duck sliding
## along the surface. Shares at the top of the climb (`DUCK_ALT`). The ink itself is
## `Shade`'s, for whatever surface the shadow lands on.
const SHADE_SHRINK := 0.35
const SHADE_THIN := 0.5
## What floats sits low in the water, so its shadow on the surface is short: this share of
## the sun's lean and stretch, laid from the waterline.
const FLOAT_SHADE := 0.45

## Dragonflies.
const FLY_ALT := Vector2(10.0, 18.0)
const FLY_DART := Vector2(0.18, 0.4)
const FLY_HOVER := Vector2(0.4, 2.2)
const FLY_ROAM := 3.0
const FLY_BODIES := [Color(0.38, 0.64, 0.86), Color(0.82, 0.32, 0.22), Color(0.46, 0.72, 0.36)]
const FLY_WING := Color(0.9, 0.96, 1.0, 0.55)
const ART := 2.0
## A dragonfly hovers a whole number of beats, then darts off on the next one.
const FLY_HOVER_BEATS := Vector2i(1, 5)

## The foam pixels a floating animal sits in.
const FOAM := Color(0.933, 0.965, 0.984, 0.8)
## How far over the bed a crayfish's shadow is thrown from, world px: it walks on the bed,
## so only its own height. About the 3 px it always fell at midday.
const CRAY_SHADE_UP := 16.0 * CRAY_DRAWN
## Tracks in the sand (2026-09-22, Richard): a frog's hop leaves a pair of dents where it
## lands, a turtle leaves two rows of footprints either side of the drag of its shell. They
## fade over TRACK_LIFE; at most TRACKS_MOST are kept, oldest dropped. Sand only.
const TRACK_LIFE := 14.0
const TRACKS_MOST := 500
const TRACK_INK := Color(0.45, 0.33, 0.2, 0.5)
## How far a turtle walks between one set of prints and the next, world px.
const TURTLE_STRIDE := 6.0

var grid: LakeGrid
var splash: WaterSplash
var flora: Flora
var day: DayCycle
var crate_tile := Vector2.INF
## Tile points the animals keep clear of: the yards' feet and berths.
var avoid := PackedVector2Array()
## World points that frighten: the angler, the dogs, the hulls. Asked once a frame.
var threats: Callable
## The same without the hulls: the ducks are not frightened by the ferries (2026-09-28,
## Richard). Unset, the ducks read `threats`.
var walker_threats: Callable
## Where the angler stands (world px), for what is within earshot: an animal is heard only
## inside the dogs' own `Dog.HEAR` (2026-09-28). Unset, nothing is heard.
var ear: Callable
## Whether this sitting's first brood has come in yet: its arrival always calls.
var _ducks_came := false
## World points that stand still — the angler or a dog not moving. Nothing is frightened by
## them; the animals walk and swim round them (`_round`) and do not pick a spot on them.
var obstacles: Callable
var _still := PackedVector2Array()
const OBSTACLE_REACH := 0.9	## tiles an animal keeps off a still walker
## The beat the animals move to (MusicStation.beat_clock). Without one they keep to a
## silent FALLBACK_BPM of their own.
var music: MusicStation
var stage: float = 0.0
## How much of the lake's rubbish is gone, 0 to 1: the pollution meter's own reading, not
## the clean-water share. The late arrivals (ducks, foxes) wait on this (Richard, 2026-09-25:
## "ducks should come later, around 60% of pollution cleaned").
var cleared: float = 0.0

var _frog_sheets: Array[Texture2D] = []
var _critters: Texture2D
var _table: Dictionary = {}
## One dictionary a shore spot: land/water (world), normal (world, unit, towards water),
## index (the water tile), side ("island" / "bank").
var _shore: Array = []
var _clean := PackedInt32Array()
var _pads := PackedVector2Array()
var _frogs: Array = []
## The lake has gone from no animals to some: the lake's "wildlife is coming back" moment
## (2026-09-26). Fires on every such turn; the lake keeps the once-per-save flag.
signal first_arrived(at: Vector2)
var _turtles: Array = []
var _broods: Array = []
var _flies: Array = []
var _critters_on_land: Array = []
## Songbirds, and every spot one may land on: {at (world), shore (index into `_shore`), side}.
var _birds: Array = []
var _bird_spots: Array = []
var _bird_in := 2.0
var _reckon_in := 0.0
## A probe's hold: while set, no animal arrives or is topped up (the store shots lay the
## life out by hand and must not have it refilled behind them).
var held := false
var _brood_in := 3.0
var _now := 0.0
## One track mark each: world point (snapped to the art grid), age.
var _track_at := PackedVector2Array()
var _track_age := PackedFloat32Array()
var _rng := RandomNumberGenerator.new()

var _under: Layer
var _submerged: Layer
## The crayfish and their shadows, on the lakebed itself: under the fish (2026-10-02,
## Richard: fish were drawn under the crayfish). Two layers handed to the lake
## (`bed_layers`), which puts them in its tree before the fish, since a fish and the bed share
## z 3 and only the tree's order between them decides.
var _bed_shade: Layer
var _bed: Layer
var _ground: Layer
var _air: Layer


## A canvas of its own at its own z, painted by a callable on the owner.
class Layer:
	extends Node2D
	var paint: Callable

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


func _ready() -> void:
	_rng.seed = 20260922
	for path: String in FROG_SHEETS:
		var tex := load(path) as Texture2D
		if tex != null:
			_frog_sheets.append(tex)
	_critters = load(CRITTERS) as Texture2D
	if FileAccess.file_exists(CRITTER_TABLE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CRITTER_TABLE))
		if parsed is Dictionary:
			_table = parsed
	_under = _layer(&"Under", 3, _paint_under)
	# Over the shadows and the legs, still under the surface: what is under the water drawn
	# through it, by the fish's shader (see `_paint_submerged`).
	_submerged = _layer(&"Submerged", 3, _paint_submerged)
	var through := ShaderMaterial.new()
	through.shader = load("res://shaders/fish.gdshader")
	_submerged.material = through
	_bed_shade = _layer(&"BedShade", 3, _paint_bed_shade)
	_bed = _layer(&"Bed", 3, _paint_bed)
	_bed.material = through
	_ground = _layer(&"Ground", 6, _paint_ground)
	_air = _layer(&"Air", 20, _paint_air)
	if grid != null:
		_find_shore()


## The two bed layers, for the lake to put before its fish.
func bed_layers() -> Array[Node2D]:
	return [_bed_shade, _bed]


## Crayfish shadows on the bed itself, thrown only by their own height, not the water's depth.
func _paint_bed_shade(on: CanvasItem) -> void:
	for c: Dictionary in _crays:
		var r := _region(_cray_frame(c))
		var at: Vector2 = c["at"]
		if r.size.x > 0.0 and Fish.bed_shows(grid, at):
			on.draw_texture_rect_region(_critters, Rect2(at + Shade.drop(day, CRAY_SHADE_UP) - r.size * SCALE * CRAY_DRAWN * 0.5, r.size * SCALE * CRAY_DRAWN), r,
				Shade.tint_on(day, Shade.On.BED, float(c["fade"])))


## Crayfish lie on the bed, so as much water is over them as over it (the shader's bed_mix).
func _paint_bed(on: CanvasItem) -> void:
	for c: Dictionary in _crays:
		var at: Vector2 = c["at"]
		var r := _region(_cray_frame(c))
		if r.size.x <= 0.0 or not Fish.bed_shows(grid, at):
			continue
		on.draw_texture_rect_region(_critters, Rect2(at - r.size * SCALE * CRAY_DRAWN * 0.5, r.size * SCALE * CRAY_DRAWN), r,
			Fish.through_tint(at, float(c["fade"]), 0.38, 0.52, 0.72))


func _layer(name: StringName, z: int, paint: Callable) -> Layer:
	var layer := Layer.new()
	layer.name = name
	layer.z_index = z
	layer.z_as_relative = false
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.paint = paint
	add_child(layer)
	return layer


func ready_to_live() -> bool:
	return not _frog_sheets.is_empty() and _critters != null and not _table.is_empty()


func frog_count() -> int:
	return _frogs.size()


func turtle_count() -> int:
	return _turtles.size()


func brood_count() -> int:
	return _broods.size()


func dragonfly_count() -> int:
	return _flies.size()


func shore_count() -> int:
	return _shore.size()


func songbird_count() -> int:
	return _birds.size()


func songbirds() -> Array:
	return _birds


func bird_spots() -> Array:
	return _bird_spots


func frogs() -> Array:
	return _frogs


func turtles() -> Array:
	return _turtles


func broods() -> Array:
	return _broods


func flies() -> Array:
	return _flies


## The lake's clean water changed: `clean` is every water tile index the map calls clean.
func refresh(clean_share: float, clean: PackedInt32Array, cleared_share: float = 0.0) -> void:
	stage = clean_share
	cleared = cleared_share
	_clean = clean
	_reckon_in = 0.0


## Forget every animal. For the harness, which refills the lake.
func reset() -> void:
	_crays.clear()
	_frogs.clear()
	_turtles.clear()
	_broods.clear()
	_flies.clear()
	_critters_on_land.clear()
	for id in _streaks.keys():
		(_streaks[id] as HullFoam).queue_free()
	_streaks.clear()
	Dog.calm = PackedVector2Array()
	_birds.clear()
	_track_at.resize(0)
	_track_age.resize(0)


## Something hit the water at `at` (world): everything within reach runs.
func scare(at: Vector2, reach_tiles: float = DUCK_SHY) -> void:
	var reach := Iso.tile_circle_extent(reach_tiles)
	for f: Dictionary in _frogs:
		if (f["at"] as Vector2).distance_to(at) < reach:
			_frog_fright(f, at)
	for t: Dictionary in _turtles:
		if (t["at"] as Vector2).distance_to(at) < reach:
			_turtle_fright(t, at)
	for b: Dictionary in _broods:
		if (b["at"] as Vector2).distance_to(at) < reach:
			_brood_fright(b, at)
	for d: Dictionary in _flies:
		if (d["at"] as Vector2).distance_to(at) < reach:
			_fly_fright(d, at)
	for c: Dictionary in _critters_on_land:
		if float(KINDS[c["kind"]]["shy"]) > 0.0 and (c["at"] as Vector2).distance_to(at) < reach:
			_land_fright(c, at)
	for s: Dictionary in _birds:
		if (s["at"] as Vector2).distance_to(at) < maxf(reach, Iso.tile_circle_extent(BIRD_SHY)):
			_bird_flush(s, at)


## Beats since the song began, and a beat's length in seconds. See MusicStation.beat_clock.
func beat() -> float:
	if music != null:
		return music.beat_clock()
	return _now * MusicStation.FALLBACK_BPM / 60.0


func beat_length() -> float:
	if music != null:
		return music.beat_length()
	return 60.0 / MusicStation.FALLBACK_BPM


func _process(delta: float) -> void:
	_now += delta
	_reckon_in -= delta
	if _reckon_in <= 0.0:
		_reckon_in = RECKON_EVERY
		_reckon()
	_crowd_in -= delta
	if _crowd_in <= 0.0:
		_crowd_in = CROWD_EVERY
		_push_crowds()
	_brood_in -= delta
	_age_tracks(delta)
	var seen := PackedVector2Array()
	if threats.is_valid():
		seen = threats.call()
	_still = obstacles.call() if obstacles.is_valid() else PackedVector2Array()
	for f: Dictionary in _frogs:
		_frog_step(f, delta, seen)
	for c: Dictionary in _crays:
		_cray_step(c, delta, seen)
	_crays = _crays.filter(func(c: Dictionary) -> bool: return not c.get("gone", false))
	for t: Dictionary in _turtles:
		_turtle_step(t, delta, seen)
	var seen_by_ducks: PackedVector2Array = walker_threats.call() if walker_threats.is_valid() else seen
	for b: Dictionary in _broods:
		_brood_step(b, delta, seen_by_ducks)
	for d: Dictionary in _flies:
		_fly_step(d, delta, seen)
	_building_boxes = buildings.call() if buildings.is_valid() else []
	for c: Dictionary in _critters_on_land:
		_land_step(c, delta, seen)
	_lay_streaks(delta)
	# What the dogs walk round: the capybaras, which never run (Dog.calm). Not the peacock
	# (2026-10-06, Richard: "no collision with peacock, its buggy").
	_calm = PackedVector2Array()
	for c: Dictionary in _critters_on_land:
		if c["kind"] == &"capy" and not bool(c["wet"]):
			_calm.append(c["at"])
	Dog.calm = _calm
	_bird_in -= delta
	for s: Dictionary in _birds:
		_bird_step(s, delta, seen_by_ducks)
	_birds = _birds.filter(func(s: Dictionary) -> bool: return not s.get("gone", false))
	_frogs =_frogs.filter(func(f: Dictionary) -> bool: return not f.get("gone", false))
	_turtles = _turtles.filter(func(t: Dictionary) -> bool: return not t.get("gone", false))
	_broods = _broods.filter(func(b: Dictionary) -> bool: return not b.get("gone", false))
	_flies = _flies.filter(func(d: Dictionary) -> bool: return not d.get("gone", false))
	_critters_on_land = _critters_on_land.filter(func(c: Dictionary) -> bool: return not c.get("gone", false))
	_cover_plants()
	_under.queue_redraw()
	_submerged.queue_redraw()
	if is_instance_valid(_bed):
		_bed.queue_redraw()
		_bed_shade.queue_redraw()
	_ground.queue_redraw()
	_air.queue_redraw()


## Everything standing on the ground layer, as [drawn box, feet's y], for the plants and the
## tufts in front of it to be drawn again over it (2026-10-05, Richard: "make sure animals go
## behind the bushes and vegetation"; `Flora.cover`, `Ground.cover`). Boxes are generous
## halves and heights of what each is drawn at, world px.
func _cover_plants() -> void:
	var bodies: Array = []
	# Only what is on screen: a plant drawn over an animal nobody can see is work for nothing.
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	view = view.grow(40.0)
	for c: Dictionary in _critters_on_land:
		var k: Dictionary = KINDS[c["kind"]]
		if view.has_point(c["at"]):
			bodies.append(_body(c["at"], float(k["half"]), float(k["tall"])))
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM and view.has_point(f["at"]):
			bodies.append(_body(f["at"], 10.0 * FROG_DRAWN, 18.0 * FROG_DRAWN))
	for t: Dictionary in _turtles:
		if int(t["state"]) != Turtle.UNDER and view.has_point(t["at"]):
			bodies.append(_body(t["at"], 14.0 * TURTLE_DRAWN, 21.0 * TURTLE_DRAWN))
	for s: Dictionary in _birds:
		if float(s["alt"]) <= 0.5 and view.has_point(s["at"]):
			bodies.append(_body(s["at"], 8.0, 14.0))
	if flora != null:
		flora.cover(bodies)
	for g in grounds:
		g.cover(bodies)


static func _body(at: Vector2, half: float, tall: float) -> Array:
	return [Rect2(at.x - half, at.y - tall, half * 2.0, tall), at.y]


## A step from `at` to `next`, bent round every still walker: the part of the step heading
## into one is taken off, so the animal slides along the edge of its room instead of
## walking into it, and anything still inside is put back on the edge.
func _round(at: Vector2, next: Vector2) -> Vector2:
	if _still.is_empty():
		return next
	var r := Iso.tile_circle_extent(OBSTACLE_REACH)
	for p in _still:
		var d := next - p
		if d.length() >= r:
			continue
		var n := (at - p).normalized() if (at - p).length() > 0.01 else Vector2.RIGHT
		var step := next - at
		step -= n * minf(step.dot(n), 0.0)
		next = at + step
		if (next - p).length() < r:
			next = p + (next - p).normalized() * r if (next - p).length() > 0.01 else p + n * r
	return next


## Is `to` inside a still walker's room — no place to hop to or wander to.
func _taken_by_still(to: Vector2) -> bool:
	var r := Iso.tile_circle_extent(OBSTACLE_REACH)
	for p in _still:
		if p.distance_to(to) < r:
			return true
	return false


# ---- where they live --------------------------------------------------------------------

## Every spot along both shores a frog or a turtle might call home: a point on the sand, the
## point in the water in front of it, and the tile that water is. Walked round both shores
## once, on bearings, by finding where each ray crosses the drawn water's edge.
func _find_shore() -> void:
	_shore.clear()
	for i in 90:
		var a := TAU * float(i) / 90.0
		var dir := Vector2(cos(a), sin(a))
		var edge := _cross(Iso.ISLAND_CENTRE, dir, 2.0, 16.0, func(p: Vector2) -> float: return Iso.past_shelf(p))
		if edge == Vector2.INF:
			continue
		_add_shore(edge - dir * 0.8, edge + dir * 1.1, dir, "island")
	for i in 160:
		var a := TAU * float(i) / 160.0
		var dir := Vector2(cos(a), sin(a))
		var edge := _cross(Iso.CENTRE, dir, 20.0, 50.0, func(p: Vector2) -> float: return Ground.out_of_water(p.x, p.y))
		if edge == Vector2.INF:
			continue
		_add_shore(edge + dir * 1.0, edge - dir * 1.1, -dir, "bank")
	_find_bird_spots()
	_bank_ring = _shore.filter(func(s: Dictionary) -> bool: return s["side"] == "bank")
	_find_isle()


## Where along a ray a function goes from negative to positive, to a twentieth of a tile.
func _cross(from: Vector2, dir: Vector2, near: float, far: float, f: Callable) -> Vector2:
	var lo := near
	var hi := far
	if float(f.call(from + dir * lo)) > 0.0 or float(f.call(from + dir * hi)) < 0.0:
		return Vector2.INF
	for n in 12:
		var mid := (lo + hi) * 0.5
		if float(f.call(from + dir * mid)) > 0.0:
			hi = mid
		else:
			lo = mid
	return from + dir * (lo + hi) * 0.5


func _add_shore(land: Vector2, water: Vector2, normal: Vector2, side: String) -> void:
	if Iso.in_shed(land.x, land.y, Iso.SHED_COVER + 0.6):
		return
	if Pump.covers(land, 1.0):
		return
	# Nor at the beehive (2026-09-30): it stands well inside the lawn today, so this never
	# bites, but a spot beside it would put a frog under the bees if the hive were moved.
	if Hive.covers(land, 1.0):
		return
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, land, 1.0):
		return
	for p in avoid:
		if land.distance_to(p) < 3.0 or water.distance_to(p) < 3.0:
			return
	var wt := Vector2i(int(floor(water.x)), int(floor(water.y)))
	if not Iso.in_lake(wt.x, wt.y) or grid == null:
		return
	var lw := Iso.tile_to_world(land.x, land.y)
	var ww := Iso.tile_to_world(water.x, water.y)
	_shore.append({
		"land": lw, "water": ww, "normal": (ww - lw).normalized(),
		"index": grid.index_of(wt.x, wt.y), "side": side,
	})


func _shore_clean(spot: Dictionary) -> bool:
	return grid.water_state(int(spot["index"])) == 0


## Is this world point on the beach its shore spot is on: dry, and not far up it.
func _on_sand(at: Vector2, side: String) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_COVER + 0.3) or Pump.covers(tile, 0.6):
		return false
	if Hive.covers(tile, 0.6):
		return false
	if crate_tile != Vector2.INF and Yard.covers(crate_tile, tile, 0.6):
		return false
	if side == "island":
		var shelf := Iso.past_shelf(tile)
		return shelf < -0.15 and shelf > -2.0
	var out := Ground.out_of_water(tile.x, tile.y)
	return out > 0.3 and out < 2.4


## Is this world point clean open water a thing may swim in.
func _swimmable(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	var t := Vector2i(int(floor(tile.x)), int(floor(tile.y)))
	if not Iso.in_lake(t.x, t.y):
		return false
	if Iso.past_shelf(tile) < 0.15:
		return false
	if Ground.out_of_water(tile.x, tile.y) > -0.15:
		return false
	return grid.water_state(grid.index_of(t.x, t.y)) == 0


## Is this world point in the water as it is drawn (past both edges).
func _wet(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	return Iso.past_shelf(tile) > 0.05 and Ground.out_of_water(tile.x, tile.y) < -0.05


func _clean_shore() -> Array:
	return _shore.filter(func(s: Dictionary) -> bool: return _shore_clean(s))


# ---- how many ---------------------------------------------------------------------------

func _want(most: int) -> int:
	if stage < 0.02:
		return 0
	return mini(ceili(float(most) * clampf(stage, 0.0, 1.0)), most)


## How many of a late arrival: none until the meter reads LATE_FROM cleared, then filling in
## to `most` on a cleaned lake.
func _want_late(most: int) -> int:
	if cleared < LATE_FROM or stage < 0.02:
		return 0
	var t := clampf((cleared - LATE_FROM) / (1.0 - LATE_FROM), 0.0, 1.0)
	return clampi(ceili(float(most) * maxf(t, 0.001)), 1, most)


func _reckon() -> void:
	if held or grid == null or not ready_to_live():
		return
	var none_yet := _alive() == 0
	if flora != null:
		_pads = flora.pad_spots()
	var shore := _clean_shore()
	if not shore.is_empty():
		for n in maxi(_want(FROGS_MOST) - _frogs.size(), 0):
			_frogs.append(_new_frog(shore[_rng.randi_range(0, shore.size() - 1)]))
		for n in maxi(_want(TURTLES_MOST) - _turtles.size(), 0):
			_turtles.append(_new_turtle(shore[_rng.randi_range(0, shore.size() - 1)]))
	var bank := shore.filter(func(sp: Dictionary) -> bool: return sp["side"] == "bank")
	if not bank.is_empty():
		for n in maxi(_want(BUNNIES_MOST) - bunny_count(), 0):
			_critters_on_land.append(_new_land(&"bunny", bank[_rng.randi_range(0, bank.size() - 1)],
				BUNNY_COATS[_rng.randi_range(0, BUNNY_COATS.size() - 1)]))
		for n in maxi(_want_from(FOXES_MOST, CANID_FROM) - kind_count(&"fox"), 0):
			_critters_on_land.append(_new_land(&"fox", _spread_spot(bank)))
		for n in maxi(_want_from(WOLVES_MOST, CANID_FROM) - kind_count(&"wolf"), 0):
			_critters_on_land.append(_new_land(&"wolf", _spread_spot(bank)))
		var pairs := _critters_on_land.filter(func(c: Dictionary) -> bool:
			return c["kind"] == &"capy" and not c.has("lead")).size()
		for n in maxi(_want_from(CAPY_PAIRS, CAPY_FROM) - pairs, 0):
			var spot: Dictionary = bank[_rng.randi_range(0, bank.size() - 1)]
			var lead := _new_land(&"capy", spot)
			var follower := _new_land(&"capy", spot)
			follower["at"] = (lead["at"] as Vector2) + Vector2(CAPY_BEHIND, CAPY_BESIDE)
			follower["lead"] = lead
			_critters_on_land.append(lead)
			_critters_on_land.append(follower)
	# The bank only (Richard, 2026-10-05: "no snake on main isle"), off one of its beaches'
	# shore spots, though it lives on the grass behind it (2026-10-06).
	var sandy := bank.filter(func(sp: Dictionary) -> bool: return _on_sand(sp["land"], "bank"))
	if not sandy.is_empty():
		for n in maxi(_want(SNAKES_MOST) - kind_count(&"snake"), 0):
			var spot: Dictionary = sandy[_rng.randi_range(0, sandy.size() - 1)]
			_critters_on_land.append(_new_land(&"snake", spot, SNAKE_COATS[_rng.randi_range(0, SNAKE_COATS.size() - 1)]))
	for n in maxi(_want_from(ISLE_BUNNIES_MOST, ISLE_BUNNY_FROM) - bunny_count(true), 0):
		var at := _free_spot(&"bunny", _isle_lawn)
		if at != Vector2.INF:
			_critters_on_land.append(_out_of_the_box(&"bunny", BUNNY_COATS[_rng.randi_range(0, BUNNY_COATS.size() - 1)], at))
	if kind_count(&"peacock") < _want_from(1, PEACOCK_FROM):
		var at := _free_spot(&"peacock", _peacock_spots)
		if at != Vector2.INF:
			_critters_on_land.append(_out_of_the_box(&"peacock", "", at))
	if _broods.size() < _want_late(BROODS_MOST) and _brood_in <= 0.0 and _clean.size() > 12:
		var b := _new_brood()
		if not b.is_empty():
			_broods.append(b)
			if not _ducks_came and Sfx.main() != null:
				Sfx.main().play_duck(true)
			_ducks_came = true
			_brood_in = _rng.randf_range(BROOD_GAP.x, BROOD_GAP.y)
	for n in maxi(_want(CRAYFISH_MOST) - _crays.size(), 0):
		var c := _new_cray()
		if not c.is_empty():
			_crays.append(c)
	if not shore.is_empty() or not _pads.is_empty():
		for n in maxi(_want(DRAGONFLIES_MOST) - _flies.size(), 0):
			_flies.append(_new_fly(shore))
	# Songbirds fly in one at a time, `BIRD_GAP` apart, to a spot with clean water beside it.
	if _birds.size() < _want(SONGBIRDS_MOST) and _bird_in <= 0.0:
		var s := _new_bird()
		if not s.is_empty():
			_birds.append(s)
			_bird_in = _rng.randf_range(BIRD_GAP.x, BIRD_GAP.y)
	if none_yet and _alive() > 0:
		first_arrived.emit(_first_spot())


## How often the animals within earshot are counted for the sound's crowd
## (`Sfx.set_crowd`, 2026-10-05): the more of a kind round the angler, the shorter its gap.
const CROWD_EVERY := 1.0
var _crowd_in := 0.0


## Counts the frogs, broods and songbirds within earshot and hands them to the sound.
func _push_crowds() -> void:
	var sfx := Sfx.main()
	if sfx == null:
		return
	sfx.set_crowd(&"frog", _heard_of(_frogs))
	sfx.set_crowd(&"duck", _heard_of(_broods))
	sfx.set_crowd(&"songbird", _heard_of(_birds))


## How many of a list of animals stand within earshot.
func _heard_of(list: Array) -> int:
	var count := 0
	for a: Dictionary in list:
		if a.has("at") and hears(a["at"]):
			count += 1
	return count


## Whether a sound at `at` (world px) is in the angler's earshot.
func hears(at: Vector2) -> bool:
	if not ear.is_valid():
		return false
	return (ear.call() as Vector2).distance_to(at) < Iso.tile_circle_extent(Dog.HEAR)


## Every animal on the lake, of every kind.
func _alive() -> int:
	return _frogs.size() + _turtles.size() + _broods.size() + _flies.size() + _critters_on_land.size() \
		+ _birds.size()


## Where the first animal of a fresh lake is headed: the spot the moment is framed on. A frog,
## a turtle or a critter heads for its shore spot's sand, a dragonfly hovers at its home, a
## brood is on its way in and is framed where it will land.
func _first_spot() -> Vector2:
	for f: Dictionary in _frogs:
		return f["land_at"]
	for t: Dictionary in _turtles:
		return (t["spot"] as Dictionary)["land"]
	for c: Dictionary in _critters_on_land:
		return c.get("edge", c["home"])
	for d: Dictionary in _flies:
		return d["home"]
	for b: Dictionary in _broods:
		return b.get("to", b.get("at", Vector2.ZERO))
	for s: Dictionary in _birds:
		return s.get("to", s.get("at", Vector2.ZERO))
	return Vector2.ZERO



# ---- frogs ------------------------------------------------------------------------------

enum Frog { SIT, CROAK, HOP, JUMP, SWIM }


## A frog arrives out of the water: swimming in towards its shore, fading up as it comes.
func _new_frog(spot: Dictionary) -> Dictionary:
	var water: Vector2 = spot["water"]
	var start := water + (spot["normal"] as Vector2) * _rng.randf_range(16.0, 40.0)
	return {
		"state": Frog.SWIM, "at": start, "from": start, "to": water, "t": 0.0,
		"spot": spot, "sheet": _rng.randi_range(0, _frog_sheets.size() - 1),
		"row": 0, "timer": 0.0, "clock": _rng.randf() * 3.0, "fade": 0.0,
		"on_pad": false, "croaks": 0, "land_at": spot["land"],
	}


func _frog_step(f: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	f["clock"] = float(f["clock"]) + delta
	f["fade"] = minf(float(f["fade"]) + delta / 0.8, 1.0)
	var at: Vector2 = f["at"]
	var state: int = f["state"]
	if state == Frog.SIT or state == Frog.CROAK or state == Frog.HOP:
		var shy := Iso.tile_circle_extent(FROG_SHY)
		for p in seen:
			if p.distance_to(at) < shy:
				_frog_fright(f, p)
				return
	match state:
		Frog.SIT:
			if f.has("plan"):
				_frog_on_cue(f)
			else:
				f["timer"] = float(f["timer"]) - delta
				if float(f["timer"]) <= 0.0:
					_frog_choose(f)
		Frog.CROAK:
			f["t"] = float(f["t"]) + delta / (FROG_CROAK_BEATS * beat_length())
			if float(f["t"]) >= 1.0:
				f["t"] = 0.0
				f["croaks"] = int(f["croaks"]) - 1
				if int(f["croaks"]) <= 0:
					_frog_sit(f)
		Frog.HOP, Frog.JUMP:
			var dur := FROG_HOP_TIME if state == Frog.HOP else FROG_JUMP_TIME
			f["t"] = float(f["t"]) + delta / dur
			var t := minf(float(f["t"]), 1.0)
			f["at"] = (f["from"] as Vector2).lerp(f["to"], t)
			if t >= 1.0:
				_frog_landed(f)
		Frog.SWIM:
			var to: Vector2 = f["to"]
			var step := to - at
			var go := FROG_SWIM_SPEED * delta
			if float(f.get("flee", 0.0)) > 0.0:
				f["flee"] = float(f["flee"]) - delta
				go *= 2.2
			var next := _round(at, at + step.normalized() * go)
			if step.length() <= go:
				f["at"] = to
				_frog_swum(f)
			elif not _wet(next):
				# Never over the sand: the shadow is under the water or nowhere. Out the
				# way its own shore faces, and a fresh place to go.
				f["at"] = at + ((f["spot"] as Dictionary)["normal"] as Vector2) * go
				f["to"] = _frog_swim_target(f)
			else:
				f["at"] = next
				f["row"] = _plane_heading(step)
			f["timer"] = float(f["timer"]) - delta
			if float(f["timer"]) <= 0.0:
				f["timer"] = _rng.randf_range(0.9, 1.8)
				if splash != null and float(f["fade"]) > 0.5:
					_ripple(f["at"], 7.0)


func _frog_sit(f: Dictionary) -> void:
	f["state"] = Frog.SIT
	f.erase("plan")
	f["timer"] = float(_rng.randi_range(FROG_SIT_BEATS.x, FROG_SIT_BEATS.y)) * beat_length()


## How many beats before its cue a move has to start so that it lands on the cue.
func _lead_of(kind: int) -> float:
	match kind:
		Frog.HOP:
			return FROG_HOP_TIME / beat_length()
		Frog.JUMP:
			return FROG_JUMP_TIME / beat_length()
	return 0.0


## What a sitting frog does next — croak, hop along the sand, or go for a swim — and the
## beat it does it on. Nothing moves yet: `_frog_on_cue` starts it when the beat comes.
func _frog_choose(f: Dictionary) -> void:
	var plan := _frog_plan(f)
	if plan.is_empty():
		_frog_sit(f)
		return
	var lead := _lead_of(int(plan["kind"]))
	f["plan"] = plan
	f["cue"] = floorf(beat() + lead) + float(_rng.randi_range(FROG_PICK_AHEAD.x, FROG_PICK_AHEAD.y))


## Start the planned move once its beat is near enough that it lands on it. The clock
## jumps when the heard song changes — backwards to a new song's start, or either way at
## a crossfade's handover — so a cue left far ahead, or already missed, is picked again
## on the new grid rather than waited for or fired late and off the beat.
func _frog_on_cue(f: Dictionary) -> void:
	var plan: Dictionary = f["plan"]
	var lead := _lead_of(int(plan["kind"]))
	var now := beat()
	var start := float(f["cue"]) - lead
	if start - now > 8.0 or now - start > CUE_MISSED:
		f["cue"] = floorf(now + lead) + 1.0
	if now < float(f["cue"]) - lead:
		return
	f.erase("plan")
	match int(plan["kind"]):
		Frog.CROAK:
			f["state"] = Frog.CROAK
			f["t"] = 0.0
			f["croaks"] = int(plan["croaks"])
			if hears(f["at"]) and Sfx.main() != null:
				Sfx.main().play_frog()
		Frog.HOP:
			_frog_leap(f, plan["to"], Frog.HOP)
		Frog.JUMP:
			_frog_jump_in(f, f["at"])


## {kind, ...} for the next move, or empty to sit on.
func _frog_plan(f: Dictionary) -> Dictionary:
	var roll := _rng.randf()
	if roll < 0.3:
		return {"kind": Frog.CROAK, "croaks": _rng.randi_range(1, 2)}
	if roll < 0.75 and not bool(f["on_pad"]):
		var spot: Dictionary = f["spot"]
		var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
		for attempt in 4:
			var to: Vector2 = (f["at"] as Vector2) + along * _rng.randf_range(-1.0, 1.0) * Iso.tile_circle_extent(FROG_HOP_REACH) \
				+ (spot["normal"] as Vector2) * _rng.randf_range(-6.0, 4.0)
			if _on_sand(to, String(spot["side"])) and to.distance_to(spot["land"]) < Iso.tile_circle_extent(1.4) \
					and not _taken_by_still(to):
				return {"kind": Frog.HOP, "to": to}
	if roll < 0.87:
		return {"kind": Frog.JUMP}
	return {}


## Two dents a frog's feet leave where it lands (or takes off) on sand.
func _frog_prints(at: Vector2) -> void:
	if not _sandy(at):
		return
	_track(at + Vector2(-ART * 2.0, 0.0))
	_track(at + Vector2(ART, 0.0))


func _frog_leap(f: Dictionary, to: Vector2, kind: int) -> void:
	_frog_prints(f["at"])
	f["from"] = f["at"]
	f["to"] = to
	f["t"] = 0.0
	f["state"] = kind
	f["row"] = _row_of(to - (f["at"] as Vector2))


## Into the water: from the sand to the water in front of it, from a pad to the water beside.
func _frog_jump_in(f: Dictionary, away_from: Vector2) -> void:
	var at: Vector2 = f["at"]
	var to: Vector2
	if bool(f["on_pad"]):
		var off := at - away_from
		if off.length() < 1.0:
			off = Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5))
		to = at + off.normalized() * 22.0
	else:
		var spot: Dictionary = f["spot"]
		to = (spot["water"] as Vector2) + Vector2(_rng.randf_range(-8.0, 8.0), _rng.randf_range(-4.0, 4.0))
	f["on_pad"] = false
	f["dive"] = true
	_frog_leap(f, to, Frog.JUMP)


func _frog_landed(f: Dictionary) -> void:
	_frog_prints(f["at"])
	if bool(f.get("dive", false)):
		f["dive"] = false
		if splash != null:
			_ripple(f["at"], 10.0)
			_ripple(f["at"], 20.0)
		f["state"] = Frog.SWIM
		f["timer"] = 0.6
		f["to"] = _frog_swim_target(f)
		return
	_frog_sit(f)


## Somewhere to swim to: a pad in reach half the time, else a clean bit of shore.
func _frog_swim_target(f: Dictionary) -> Vector2:
	var at: Vector2 = f["at"]
	if not _pads.is_empty() and _rng.randf() < 0.5:
		var reach := Iso.tile_circle_extent(FROG_PAD_REACH)
		var near: Array = []
		for p in _pads:
			if p.distance_to(at) < reach and _clear_path(at, p):
				near.append(p)
		if not near.is_empty():
			f["pad"] = near[_rng.randi_range(0, near.size() - 1)]
			return f["pad"]
	f.erase("pad")
	var shore := _clean_shore()
	if shore.is_empty():
		return (f["spot"] as Dictionary)["water"]
	var best: Dictionary = f["spot"]
	var bd := INF
	for n in 10:
		var s: Dictionary = shore[_rng.randi_range(0, shore.size() - 1)]
		var d := (s["water"] as Vector2).distance_to(at)
		if d < bd and d < Iso.tile_circle_extent(FROG_PAD_REACH) and _clear_path(at, s["water"]):
			bd = d
			best = s
	f["spot"] = best
	return best["water"]


## A straight swim from `a` to `b` that stays in the water the whole way.
func _clear_path(a: Vector2, b: Vector2) -> bool:
	var n := maxi(int(a.distance_to(b) / 8.0), 1)
	for i in range(1, n + 1):
		if not _wet(a.lerp(b, float(i) / float(n))):
			return false
	return true


## Swum to where it was going: out onto the pad, or out onto the sand.
func _frog_swum(f: Dictionary) -> void:
	if f.has("pad"):
		var pad: Vector2 = f["pad"]
		f.erase("pad")
		f["on_pad"] = true
		_frog_leap(f, pad, Frog.JUMP)
	else:
		var spot: Dictionary = f["spot"]
		f["on_pad"] = false
		_frog_leap(f, spot["land"], Frog.JUMP)
	if splash != null:
		_ripple(f["at"], 9.0)


func _frog_fright(f: Dictionary, from: Vector2) -> void:
	var state: int = f["state"]
	if state == Frog.JUMP:
		return
	# A heard fright ribbits now and then, on the frogs' own gap (2026-09-28).
	if Sfx.main() != null and hears(f["at"]) and _rng.randf() < Sfx.FROG_FRIGHT_ODDS:
		Sfx.main().play_frog()
	if state == Frog.SWIM:
		var off := (f["at"] as Vector2) - from
		if off.length() < 1.0:
			off = Vector2.RIGHT
		var to := (f["at"] as Vector2) + off.normalized() * 60.0
		if _swimmable(to):
			f["to"] = to
			f.erase("pad")
		f["flee"] = 1.2
		return
	_frog_jump_in(f, from)


# ---- turtles ----------------------------------------------------------------------------

enum Turtle { BASK, WALK, TUCK, SWIM, UNDER }


## A turtle arrives under the water in front of its beach, surfaces and swims in.
func _new_turtle(spot: Dictionary) -> Dictionary:
	var water: Vector2 = spot["water"]
	var at := water + (spot["normal"] as Vector2) * _rng.randf_range(20.0, 50.0)
	return {
		"state": Turtle.UNDER, "at": at, "to": water, "spot": spot, "timer": _rng.randf_range(0.5, 2.0),
		"facing": 1.0, "fade": 0.0, "clock": _rng.randf() * 4.0, "then": Turtle.SWIM, "pose": "idle",
		"nod_seed": 0.5 * float(_rng.randi_range(0, 1)), "walked": 0.0,
	}


func _turtle_step(t: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	t["clock"] = float(t["clock"]) + delta
	var at: Vector2 = t["at"]
	var state: int = t["state"]
	if state != Turtle.UNDER and state != Turtle.TUCK:
		var shy := Iso.tile_circle_extent(TURTLE_SHY)
		for p in seen:
			if p.distance_to(at) < shy:
				_turtle_fright(t, p)
				return
	match state:
		Turtle.BASK:
			t["fade"] = minf(float(t["fade"]) + delta, 1.0)
			t["timer"] = float(t["timer"]) - delta
			if float(t["timer"]) <= 0.0:
				var spot: Dictionary = t["spot"]
				t["pose"] = "idle"
				if _rng.randf() < TURTLE_TO_WATER:
					_turtle_walk(t, spot["water"])
				else:
					var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
					var to := at + along * _rng.randf_range(-14.0, 14.0)
					if _on_sand(to, String(spot["side"])) and not _taken_by_still(to):
						_turtle_walk(t, to)
					else:
						t["timer"] = 3.0
		Turtle.TUCK:
			t["timer"] = float(t["timer"]) - delta
			t["tuck_t"] = float(t.get("tuck_t", 0.0)) + delta
			if float(t["timer"]) <= 0.0:
				_turtle_rest(t)
		Turtle.WALK, Turtle.SWIM:
			var to: Vector2 = t["to"]
			var wet := _wet(at)
			var speed := TURTLE_SWIM if wet else TURTLE_WALK
			var step := to - at
			if absf(step.x) > 0.5:
				t["facing"] = 1.0 if step.x < 0.0 else -1.0
			var go := speed * delta
			if step.length() <= go:
				t["at"] = to
				_turtle_arrived(t)
			else:
				t["at"] = _round(at, at + step.normalized() * go)
			t["walked"] = float(t.get("walked", 0.0)) + minf(go, step.length())
			if not wet:
				t["stride"] = float(t.get("stride", 0.0)) + go
				if float(t["stride"]) >= TURTLE_STRIDE:
					t["stride"] = 0.0
					_turtle_prints(t["at"], step.normalized())
			var now_wet := _wet(t["at"])
			if now_wet != wet and splash != null:
				_ripple(t["at"], 12.0 * TURTLE_DRAWN)
			t["state"] = Turtle.SWIM if now_wet else Turtle.WALK
			t["fade"] = minf(float(t["fade"]) + delta, 1.0)
		Turtle.UNDER:
			t["timer"] = float(t["timer"]) - delta
			if float(t["timer"]) <= 0.0:
				# Its fade is kept: it was seen under the water, and reset it blinked out as it
				# came up (2026-10-06, nothing goes away on screen).
				t["state"] = t["then"]
				if splash != null:
					_ripple(at, 10.0 * TURTLE_DRAWN)


## A turtle's prints: a foot each side of the line it walks, and the shell's drag between.
func _turtle_prints(at: Vector2, heading: Vector2) -> void:
	if not _sandy(at):
		return
	var across := Vector2(-heading.y, heading.x * 0.5).normalized() * ART * 2.5
	_track(at + across)
	_track(at - across)
	_track(at)


func _turtle_walk(t: Dictionary, to: Vector2) -> void:
	t["to"] = to
	t["state"] = Turtle.SWIM if _wet(t["at"]) else Turtle.WALK


## Where a walk or a swim ended: a turtle in the water swims a little and comes back out;
## one on the sand basks.
func _turtle_arrived(t: Dictionary) -> void:
	var spot: Dictionary = t["spot"]
	if _wet(t["at"]):
		if _rng.randf() < TURTLE_PADDLE_ON or not _shore_clean(spot):
			# A paddle along the shallows, then out again somewhere near.
			var shore := _clean_shore()
			if not shore.is_empty() and _rng.randf() < 0.4:
				t["spot"] = shore[_rng.randi_range(0, shore.size() - 1)]
				if (t["spot"]["water"] as Vector2).distance_to(t["at"]) > Iso.tile_circle_extent(6.0):
					t["spot"] = spot
			var along := Vector2(-(spot["normal"] as Vector2).y, (spot["normal"] as Vector2).x)
			var to: Vector2 = (t["spot"]["water"] as Vector2) + along * _rng.randf_range(-30.0, 30.0)
			if _swimmable(to):
				t["to"] = to
				return
		t["to"] = (t["spot"] as Dictionary)["land"]
		return
	_turtle_rest(t)


## Settled on the sand: idle, sit or sleep, rolled.
func _turtle_rest(t: Dictionary) -> void:
	t["state"] = Turtle.BASK
	t["timer"] = _rng.randf_range(TURTLE_BASK.x, TURTLE_BASK.y)
	var roll := _rng.randf()
	var pose := "idle"
	for name: String in TURTLE_POSES:
		roll -= float(TURTLE_POSES[name])
		if roll < 0.0:
			pose = name
			break
	t["pose"] = pose


func _turtle_fright(t: Dictionary, _from: Vector2) -> void:
	var state: int = t["state"]
	if state == Turtle.UNDER:
		return
	if _wet(t["at"]):
		# Dives, and comes up again a little way off.
		t["state"] = Turtle.UNDER
		t["timer"] = _rng.randf_range(TURTLE_UNDER.x, TURTLE_UNDER.y)
		t["then"] = Turtle.SWIM
		if splash != null:
			_ripple(t["at"], 12.0 * TURTLE_DRAWN)
		var spot: Dictionary = t["spot"]
		t["at"] = (t["at"] as Vector2) + (spot["normal"] as Vector2) * 24.0
		t["to"] = spot["water"]
		return
	t["state"] = Turtle.TUCK
	t["timer"] = TURTLE_TUCK
	t["tuck_t"] = 0.0


# ---- the land animals -------------------------------------------------------------------
#
# Bunnies, the fox and the wolf, snakes, capybaras and the peacock (2026-10-05, `/grill-me`
# with Richard; supersedes the rule-built rabbits and fox). One list, `_critters_on_land`,
# one dictionary an animal, its `kind` deciding everything else. Where each lives:
#   bunny   the bank's lawn by the trees (14), and from ISLE_BUNNY_FROM a pair on the island
#   fox     the bank's beaches, patrolling along them (5 each, spread round the lake)
#   wolf      "
#   snake   the bank's lawn and the woods' edge, slithering slowly and basking (8); never
#           the sand (2026-10-06) and never the island
#   capy    pairs on the bank's shore, swimming to the island now and then (3 pairs)
#   peacock the island's lawn in front of the hut, fanning its tail at the angler (1)
# Bunnies, the fox and the wolf run; a snake slithers a short way off; a capybara never runs,
# it steps out of a walker's way; the peacock never runs and pays the walkers no mind at all
# (`_minds_walkers`). Every one keeps off the trees and rocks
# (`Ground.clashes`) and off the island's buildings, so none is drawn over a thing it stands
# behind or under a thing it stands in front of.

enum Land { SIT, MOVE, FLEE, RISE, DISPLAY }


## What one kind of land animal is: how big its picture is drawn (`scale`, 0.5 is one world
## px a painted px), how fast it walks and runs (world px a second), how near a moving
## walker may come (tiles), and the box its drawing takes (world px: half wide, tall), which
## is what the trees, the rocks and the buildings are tested against. Bunnies and snakes are
## drawn 1.5x smaller than their art (2026-10-06, Richard), drawn smaller rather than rebaked
## (his pick off tools/last_shrink_sheet.png), with their boxes come in to match.
const KINDS := {
	&"bunny": {"scale": 0.5 / 1.5, "walk": 26.0, "run": 80.0, "shy": 2.2, "half": 7.0, "tall": 12.0},
	&"fox": {"scale": 1.0, "walk": 30.0, "run": 90.0, "shy": 3.0, "half": 18.0, "tall": 24.0},
	&"wolf": {"scale": 1.0, "walk": 30.0, "run": 90.0, "shy": 3.0, "half": 20.0, "tall": 26.0},
	&"snake": {"scale": 0.5 / 1.5, "walk": 8.0, "run": 16.0, "shy": 1.4, "half": 9.5, "tall": 11.5},
	&"capy": {"scale": 0.5, "walk": 14.0, "run": 30.0, "shy": 0.0, "half": 13.0, "tall": 22.0},
	&"peacock": {"scale": 0.5, "walk": 12.0, "run": 12.0, "shy": 0.0, "half": 17.0, "tall": 32.0},
}
const BUNNY_COATS: Array[String] = ["brown", "black", "white"]
const SNAKE_COATS: Array[String] = ["blue", "corn"]
## How many, and the meter's reading each waits for (0 is the first clean shore).
const BUNNIES_MOST := 14
const ISLE_BUNNIES_MOST := 2
const ISLE_BUNNY_FROM := 0.7
const FOXES_MOST := 5
const WOLVES_MOST := 5
const CANID_FROM := 0.4
const SNAKES_MOST := 8
const CAPY_PAIRS := 3
const CAPY_FROM := 0.5
const PEACOCK_FROM := 0.8
const FLEE_SPEED := Vector2(70.0, 90.0)
## How long one sits between moves, how far a move goes (world px), and how far a frightened
## bank animal runs before it is out of sight in the trees.
const LAND_SIT := Vector2(2.0, 7.0)
const LAND_WANDER := Vector2(18.0, 60.0)
const FLEE_REACH := 140.0
const LAND_PRINT_EVERY := 10.0
## The bunnies' home on the bank (Richard, 2026-09-25: "more concentrated on grass and near
## forest"): the lawn towards the treeline, `LAND_HOME` tiles out of the water, and now and
## then a trip down to the sand and back.
const LAND_HOME := Vector2(6.0, 9.5)
const LAND_BEACH_ODDS := 0.15
## Out of the forest (Richard, 2026-10-05: "animals should come from the forest like they are
## rediscovering the lake, and they should also be around the grass and forest sometimes"):
## every bank animal arrives from `FOREST_FROM` tiles past where the woods begin
## (Ground.WOOD_FROM), walking out to its home; the bank's ground reaches `FOREST_REACH` tiles
## into the woods; now and then (`INLAND_ODDS`, by kind) one wanders up onto the grass or to
## the forest's edge, between `INLAND` tiles out of the water and the woods' edge.
const FOREST_FROM := Vector2(1.5, 3.5)
const FOREST_REACH := 2.5
const INLAND := Vector2(2.0, 3.0)
const INLAND_ODDS := {&"bunny": 0.15, &"fox": 0.35, &"wolf": 0.35, &"capy": 0.2, &"snake": 0.3}
## A snake's home is on the grass, this many tiles past the lawn's line (2026-10-06,
## Richard: "not on sand but only forest and grass"; it was 0.5-5 tiles out of the water,
## sand included). It never steps onto the sand: `_walkable` holds it to `SNAKE_GRASS_IN`
## tiles past the line, so its drawing does not lie out over the beach.
const SNAKE_HOME := Vector2(0.4, 5.5)
const SNAKE_GRASS_IN := 0.25
## Frames a second: a bunny's idle loop and its run, a canid's idle and its run, which at
## walking pace is played slower. A snake, a capybara and the peacock step by ground covered.
const BUNNY_IDLE_FPS := 6.0
const BUNNY_RUN_FPS := 12.0
const CANID_IDLE_FPS := 4.0
const CANID_WALK_FPS := 6.0
const CANID_RUN_FPS := 12.0
const SNAKE_STEP_PX := 1.0  # 1.5 until the snake was drawn 1.5x smaller (2026-10-06)
const CAPY_STEP_PX := 3.0
const PEACOCK_STEP_PX := 3.0
## A fox or a wolf patrols the bank's beach: from its shore spot, along the ring of spots by
## this many either way, a waypoint every `PATROL_STRIDE` spots so it never cuts across the
## water, pulled up to `PATROL_INLAND` tiles up the sand.
const PATROL_REACH := Vector2i(4, 18)
const PATROL_STRIDE := 2
const PATROL_INLAND := 1.2
## A snake keeps to `SNAKE_RANGE` tiles of its spot, and a fright sends it `SNAKE_AWAY` tiles.
const SNAKE_RANGE := 1.6
const SNAKE_AWAY := Vector2(1.4, 2.4)
## A capybara pair: the follower keeps `CAPY_BEHIND` px behind and `CAPY_BESIDE` beside its
## lead, catching up at a run past `CAPY_CATCH_UP`. Each rest the lead may set off for the
## island (`CAPY_VISIT_ODDS`), stays `CAPY_STAY` seconds and swims home.
const CAPY_BEHIND := 14.0
const CAPY_BESIDE := 8.0
const CAPY_CATCH_UP := 40.0
const CAPY_GO := 10.0
const CAPY_STOP := 2.0
const CAPY_KEEP_UP := 1.15
const CAPY_VISIT_ODDS := 0.3
const CAPY_STAY := Vector2(40.0, 90.0)
## Rest poses a capybara rolls (idle, sit, lie) and how long it takes to sit or lie down.
const CAPY_SETTLE := 0.6
## The capybara swims the dogs' way: cut at the waterline (`CAPY_SINK` of its picture under
## it), bobbing, a foam collar on the cut, the ferry's foam streak behind it and one ring
## going in (Dog.ENTRY_SPAN).
const CAPY_SINK := 0.45
const CAPY_BOB := 1.0
const CAPY_BOB_RATE := 3.4
## A walker inside `ROOM` tiles of a capybara or the peacock: it walks off, calmly, to
## `ROOM_OFF` tiles away.
const ROOM := 1.0
const ROOM_OFF := 1.8
## The peacock: its home within `PEACOCK_REACH` tiles of the hut, in front of it; it fans its
## tail at the angler or a dog inside `PEACOCK_NEAR` tiles and folds it `PEACOCK_HOLD`
## seconds after they leave. The open tail strutting on the spot at `PEACOCK_STRUT_FPS`.
const PEACOCK_REACH := Vector2(1.6, 4.2)
const PEACOCK_NEAR := 2.6
const PEACOCK_HOLD := 2.5
const PEACOCK_STRUT_FPS := 3.0
## A step that would put the animal into a tree, a rock or a building is turned this far
## either way (radians, in order); blocked every way, a walk gives up after `STUCK_TIME`.
const SIDESTEPS: Array[float] = [0.6, -0.6, 1.2, -1.2]
const STUCK_TIME := 0.6

## The grounds the trees and rocks stand on, and the buildings' drawn boxes (world), handed
## in by the lake. See `_blocked`.
var grounds: Array[Ground] = []
var buildings: Callable
var _building_boxes: Array = []
## Every capybara's and the peacock's place, world px: what the dogs walk round (Dog.calm).
var _calm := PackedVector2Array()
## Spots on the island's lawn, and the peacock's, worked out with the shore. See `_find_isle`.
var _isle_lawn: Array = []
var _peacock_spots: Array = []


func bunny_count(isle: bool = false) -> int:
	return _critters_on_land.filter(func(c: Dictionary) -> bool:
		return c["kind"] == &"bunny" and (c["zone"] == "isle") == isle).size()


func kind_count(kind: StringName) -> int:
	return _critters_on_land.filter(func(c: Dictionary) -> bool: return c["kind"] == kind).size()


func land_animals() -> Array:
	return _critters_on_land


## A late arrival: none until the meter reads `from` cleared, then filling in to `most` on a
## cleaned lake. `from` 0 is the first clean shore, filling in with the clean share instead.
func _want_from(most: int, from: float) -> int:
	if from <= 0.0:
		return _want(most)
	if cleared < from or stage < 0.02:
		return 0
	var t := clampf((cleared - from) / (1.0 - from), 0.0, 1.0)
	return clampi(ceili(float(most) * maxf(t, 0.001)), 1, most)


## The island's lawn spots and the peacock's, once, off the island's shore spots.
func _find_isle() -> void:
	_isle_lawn.clear()
	_peacock_spots.clear()
	var keep := RandomNumberGenerator.new()
	keep.seed = 20261005
	var hut := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	for spot: Dictionary in _shore:
		if spot["side"] != "island":
			continue
		var inland := -(spot["normal"] as Vector2)
		for k in 3:
			var at: Vector2 = (spot["land"] as Vector2) + inland * Iso.tile_circle_extent(keep.randf_range(1.0, 4.0))
			if not _isle_ok(at):
				continue
			_isle_lawn.append(at)
			var d := Iso.world_to_tile(at).distance_to(Iso.ISLAND_CENTRE)
			# In front of the hut: its feet below the hut's, so it is never stood behind it.
			if at.y > hut.y + Iso.TILE_H and d > PEACOCK_REACH.x and d < PEACOCK_REACH.y:
				_peacock_spots.append(at)


## A spot off a list an island animal of `kind` may appear on: clear of the walkers and of
## the buildings' drawings. INF when a few tries find none.
func _free_spot(kind: StringName, spots: Array) -> Vector2:
	if spots.is_empty():
		return Vector2.INF
	var probe := _animal(kind, "", Vector2.ZERO, Vector2.ZERO, {}, "isle")
	for n in 8:
		var at: Vector2 = spots[_rng.randi_range(0, spots.size() - 1)]
		if (not _minds_walkers(probe) or not _taken_by_still(at)) and not _blocked(probe, at):
			return at
	return Vector2.INF


## The island's shore spot nearest a point: what an island animal calls its own bit of shore.
func _isle_shore_near(at: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var near := INF
	for s: Dictionary in _shore:
		if s["side"] == "island" and (s["land"] as Vector2).distance_to(at) < near:
			near = (s["land"] as Vector2).distance_to(at)
			best = s
	return best


## The island's lawn, off the hut, the pump, the hive and the crate.
func _isle_ok(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.past_shelf(tile) > -0.5 or not Iso.on_lawn(tile):
		return false
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_COVER + 0.6) or Pump.covers(tile, 1.0) or Hive.covers(tile, 1.0):
		return false
	return crate_tile == Vector2.INF or not Yard.covers(crate_tile, tile, 1.0)


## The island's ground an animal may walk: its sand and lawn, dry, off the buildings.
func _on_isle(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.past_shelf(tile) > -0.2:
		return false
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_COVER + 0.3) or Pump.covers(tile, 0.6) or Hive.covers(tile, 0.6):
		return false
	return crate_tile == Vector2.INF or not Yard.covers(crate_tile, tile, 0.6)


## A bank animal comes out of the trees behind its bit of beach.
func _new_land(kind: StringName, spot: Dictionary, coat: String = "") -> Dictionary:
	var inland := -(spot["normal"] as Vector2)
	var probe := _animal(kind, coat, spot["land"], spot["land"], spot, "bank")
	var home: Vector2 = spot["land"]
	# A home clear of the trees and the rocks: a few rolls, then the beach itself.
	for n in 8:
		if kind == &"bunny":
			home = _inland_to(spot["land"], inland, _rng.randf_range(LAND_HOME.x, LAND_HOME.y))
		elif kind == &"snake":
			home = _to_grass(spot["land"], inland, _rng.randf_range(SNAKE_HOME.x, SNAKE_HOME.y))
		else:
			home = _inland_to(spot["land"], inland, _rng.randf_range(0.6, PATROL_INLAND))
		if not _blocked(probe, home) and (kind != &"snake" or _walkable(probe, home)):
			break
		home = spot["land"] if kind != &"snake" else _to_grass(spot["land"], inland, SNAKE_HOME.x)
	# Out of the trees behind its bit of shore, rediscovering the lake: it fades in among the
	# trunks and walks out to its home. A snake comes at its quicker pace, or it would be a
	# minute on the way.
	var from := _inland_to(spot["land"], inland, Ground.WOOD_FROM + _rng.randf_range(FOREST_FROM.x, FOREST_FROM.y))
	var c := _animal(kind, coat, from, home, spot, "bank")
	c["edge"] = _inland_to(spot["land"], inland, Ground.WOOD_FROM - 0.5)
	# Unseen among the trees: it fades in once it steps out of them, clear of every trunk, so
	# it is never drawn over a tree it is walking behind (`_land_move`).
	c["arriving"] = true
	if kind == &"snake":
		c["speed"] = float(KINDS[kind]["run"])
	return c


func _animal(kind: StringName, coat: String, at: Vector2, to: Vector2, spot: Dictionary, zone: String) -> Dictionary:
	return {
		"kind": kind, "coat": coat, "spot": spot, "zone": zone, "at": at, "to": to, "home": to,
		"state": Land.MOVE, "timer": 0.0, "facing": Flock.facing_of(at, to), "clock": _rng.randf() * 3.0,
		"fade": 0.0, "walked": 0.0, "pose": "idle", "pose_t": 0.0, "view": "side", "path": [],
		"stuck": 0.0, "wet": false,
	}


## An island animal walks out from behind the recycle box (Richard, 2026-10-05: "peacock and
## bunnies can spawn behind the box and just come out walking"): the island has no forest to
## come out of. It starts behind the box's picture, unseen (`arriving`, held at 0 while its
## drawing overlaps the box), and fades in as it steps out on its way to `to`. With the box's
## picture not known yet, it appears at `to` instead.
func _out_of_the_box(kind: StringName, coat: String, to: Vector2) -> Dictionary:
	var spot := _isle_shore_near(to)
	var box := _crate_box()
	if box.size == Vector2.ZERO:
		return _appears(kind, coat, to, spot, "isle")
	var from := Vector2(box.get_center().x + _rng.randf_range(-0.2, 0.2) * box.size.x, box.position.y + box.size.y * 0.55)
	var c := _animal(kind, coat, from, to, spot, "isle")
	c["arriving"] = true
	c["edge"] = to
	return c


## The recycle box's drawn box on the island, world px: the building whose box holds the
## crate's own foot. Empty before the buildings are known.
func _crate_box() -> Rect2:
	if crate_tile == Vector2.INF:
		return Rect2()
	var foot := Iso.tile_to_world(crate_tile.x, crate_tile.y)
	for r: Rect2 in _building_boxes:
		if r.grow(4.0).has_point(foot):
			return r
	return Rect2()


## One that simply appears where it lives, fading in: a bunny or the peacock on the island (nowhere to have walked from).
func _appears(kind: StringName, coat: String, at: Vector2, spot: Dictionary, zone: String) -> Dictionary:
	var c := _animal(kind, coat, at, at, spot, zone)
	c["state"] = Land.SIT
	c["timer"] = _rng.randf_range(LAND_SIT.x, LAND_SIT.y)
	c["facing"] = 1.0 if _rng.randf() < 0.5 else -1.0
	return c


## From a point on the bank's sand, straight inland until the ground is `out` tiles out of
## the water. World in, world out.
func _inland_to(from: Vector2, inland: Vector2, out: float) -> Vector2:
	var at := from
	for i in 80:
		var tile := Iso.world_to_tile(at)
		if Ground.out_of_water(tile.x, tile.y) >= out:
			break
		at += inland * 4.0
	return at


## The bank's ground a bank animal may walk: dry, off the water's edge, short of the woods.
func _on_bank(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	var out := Ground.out_of_water(tile.x, tile.y)
	return out > 0.3 and out < Ground.WOOD_FROM + FOREST_REACH


## Tiles past the bank's lawn line at a spot: positive on the grass, negative on the sand. The
## outer ground's own answer, which is what the shader draws by; with no ground known, the
## line's plain ellipse.
func _past_lawn(at: Vector2) -> float:
	var tile := Iso.world_to_tile(at)
	for g in grounds:
		if g.layer == Ground.Layer.OUTSIDE:
			return g.coverage_at(tile)
	return Ground.out_of_water(tile.x, tile.y) - Ground.SAND_OUT


## From a point on the bank's sand, straight inland until the ground is `past` tiles past the
## lawn's line. World in, world out.
func _to_grass(from: Vector2, inland: Vector2, past: float) -> Vector2:
	var at := from
	for i in 160:
		if _past_lawn(at) >= past:
			break
		at += inland * 4.0
	return at


## Ground this animal may stand on, by where it lives and where it is going. A snake only on
## the grass and the woods' edge, never the sand (2026-10-06).
func _walkable(c: Dictionary, at: Vector2) -> bool:
	if c["zone"] == "isle":
		return _on_isle(at)
	if c["kind"] == &"snake":
		return _on_bank(at) and _past_lawn(at) > SNAKE_GRASS_IN
	return _on_bank(at)


## Would this animal's drawing, standing on `at`, be drawn wrongly against a tree, a rock or
## a building: under one it stands in front of, over one it stands behind, or with its feet
## in one's base. The buildings' boxes are any overlap at all: the island's animals are on a
## layer the walkers' sorting does not reach.
func _blocked(c: Dictionary, at: Vector2) -> bool:
	var k: Dictionary = KINDS[c["kind"]]
	var half := float(k["half"])
	var tall := float(k["tall"])
	var box := Rect2(at.x - half, at.y - tall, half * 2.0, tall)
	for r: Rect2 in _building_boxes:
		if r.intersects(box):
			return true
	if c["zone"] == "isle":
		return false
	for g in grounds:
		if g.layer == Ground.Layer.OUTSIDE and g.clashes(at, half, tall):
			return true
	return false


## Is a world point on the screen, or within `margin` world px of it.
func _in_view(at: Vector2, margin: float = VIEW_MARGIN) -> bool:
	if not is_inside_tree():
		return false
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.grow(margin).has_point(at)


## Does this animal keep out of the walkers' way: slide round a still angler or dog, refuse a
## spot inside one's room. Not the peacock (2026-10-06, Richard: "no collision with peacock,
## its buggy"): the angler and the dogs walk through it and it through them. It still keeps off
## the buildings, the trees and the rocks (`_blocked`).
func _minds_walkers(c: Dictionary) -> bool:
	return c["kind"] != &"peacock"


## A step towards `to`, `go` px long, turned off whatever would block it. Returns where the
## animal ends up; standing still means every way was blocked.
func _step_to(c: Dictionary, to: Vector2, go: float, forced: bool = false) -> Vector2:
	var at: Vector2 = c["at"]
	var dir := (to - at).normalized() if at.distance_to(to) > 0.01 else Vector2.ZERO
	var next := at + dir * minf(go, at.distance_to(to))
	if not forced and _minds_walkers(c):
		next = _round(at, next)
	# On its own ground it does not step off it: a fox or a wolf patrolling between two beach
	# spots does not cut across the water (2026-10-06, Richard: "foxes are walking over
	# water"), and a snake on its grass does not cross a sandy bay. Sidestepped instead. A
	# capybara's swim and a fleeing animal are forced and go where they go.
	var keep: bool = not forced and _walkable(c, at)
	if (not _blocked(c, next) or _blocked(c, at)) and (not keep or _walkable(c, next)):
		return next
	for turn in SIDESTEPS:
		var side := at + dir.rotated(turn) * go
		if not _blocked(c, side) and (not keep or _walkable(c, side)):
			return side
	return next if forced else at


func _land_step(c: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	c["clock"] = float(c["clock"]) + delta
	c["pose_t"] = float(c["pose_t"]) + delta
	var kind: StringName = c["kind"]
	var k: Dictionary = KINDS[kind]
	var at: Vector2 = c["at"]
	var state: int = c["state"]
	if c.has("lead"):
		_capy_follow(c, delta)
		return
	# Frights: the ones that run, by what is moving near them.
	var shy := float(k["shy"])
	if shy > 0.0 and state != Land.FLEE:
		var reach := Iso.tile_circle_extent(shy)
		for p in seen:
			if p.distance_to(at) < reach:
				_land_fright(c, p)
				return
	# The capybaras step out of a walker's way, moving or still. The peacock does not: it
	# ignores the walkers altogether (`_minds_walkers`).
	if kind == &"capy" and not bool(c["wet"]) and c["path"].is_empty():
		if _make_room(c, seen):
			return
	if kind == &"peacock" and _peacock_display(c, seen, delta):
		return
	match state:
		Land.SIT:
			c["fade"] = minf(float(c["fade"]) + delta, 1.0)
			c["timer"] = float(c["timer"]) - delta
			if float(c["timer"]) <= 0.0:
				_land_choose(c)
		Land.RISE:
			c["timer"] = float(c["timer"]) - delta
			if float(c["timer"]) <= 0.0:
				c["state"] = Land.MOVE
				c["pose"] = "idle"
		Land.MOVE, Land.FLEE:
			_land_move(c, delta, state == Land.FLEE)


## Where to next, once a rest is over.
func _land_choose(c: Dictionary) -> void:
	var kind: StringName = c["kind"]
	var at: Vector2 = c["at"]
	var spot: Dictionary = c["spot"]
	var n: Vector2 = spot["normal"]
	var along := Vector2(-n.y, n.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	var home: Vector2 = c["home"]
	var to := at
	c["path"] = []
	if c["zone"] == "bank" and not c.get("up_inland", false) and _rng.randf() < float(INLAND_ODDS.get(kind, 0.0)):
		var up := _inland_to(spot["land"], -n, _rng.randf_range(INLAND.x, Ground.WOOD_FROM + INLAND.y - 2.0))
		up += along * _rng.randf_range(0.0, 30.0)
		if _walkable(c, up) and not _blocked(c, up):
			c["up_inland"] = true
			_set_off(c, up)
			return
	c["up_inland"] = false
	match kind:
		&"bunny":
			if c["zone"] == "isle":
				to = _isle_lawn[_rng.randi_range(0, _isle_lawn.size() - 1)] if not _isle_lawn.is_empty() else at
				to = at + (to - at).limit_length(_rng.randf_range(LAND_WANDER.x, LAND_WANDER.y))
			elif _rng.randf() < LAND_BEACH_ODDS and not c.get("on_beach", false):
				# Down to the sand for a look at the water.
				to = (spot["land"] as Vector2) + along * _rng.randf_range(0.0, 20.0)
				c["on_beach"] = true
			elif c.get("on_beach", false):
				to = home + along * _rng.randf_range(0.0, 20.0)
				c["on_beach"] = false
			else:
				# Grazing along the grass, pulled back towards home.
				to = at + along * _rng.randf_range(LAND_WANDER.x, LAND_WANDER.y) + (home - at) * 0.4
		&"fox", &"wolf":
			c["path"] = _patrol(c)
			to = c["path"].pop_front() if not c["path"].is_empty() else at
		&"snake":
			var mid: Vector2 = home
			to = at + along * _rng.randf_range(8.0, 24.0)
			if to.distance_to(mid) > Iso.tile_circle_extent(SNAKE_RANGE):
				to = at + (mid - at).normalized() * _rng.randf_range(8.0, 24.0)
		&"capy":
			to = _capy_choose(c)
		&"peacock":
			if not _peacock_spots.is_empty():
				to = _peacock_spots[_rng.randi_range(0, _peacock_spots.size() - 1)]
				to = at + (to - at).limit_length(_rng.randf_range(20.0, 50.0))
	if not c["path"].is_empty() or (_walkable(c, to) and not (_minds_walkers(c) and _taken_by_still(to)) and not _blocked(c, to)):
		_set_off(c, to)
	else:
		c["timer"] = 1.0


## Off to `to`: a capybara sitting or lying gets up first.
func _set_off(c: Dictionary, to: Vector2) -> void:
	c["to"] = to
	if c["kind"] == &"capy" and c["pose"] != "idle":
		c["state"] = Land.RISE
		c["timer"] = CAPY_SETTLE
		c["rising"] = c["pose"]
		c["pose_t"] = 0.0
		return
	c["state"] = Land.MOVE


## Walking (or fleeing) towards `to`, then the next waypoint, then a rest.
func _land_move(c: Dictionary, delta: float, flee: bool) -> void:
	var kind: StringName = c["kind"]
	var k: Dictionary = KINDS[kind]
	var at: Vector2 = c["at"]
	var to: Vector2 = c["to"]
	var speed := float(c.get("speed", k["walk"]))
	if c.get("trip", false) or (kind == &"capy" and bool(c["wet"])):
		speed = float(k["walk"]) * 1.2
	var go := speed * delta
	if flee:
		# Runs on at full strength; it is gone only once off the screen (`VIEW_MARGIN`).
		if c["zone"] == "bank" and kind != &"snake" and not _in_view(at):
			c["gone"] = true
			return
	else:
		if c.get("arriving", false):
			var tile := Iso.world_to_tile(at)
			if Ground.out_of_water(tile.x, tile.y) > Ground.WOOD_FROM or _blocked(c, at):
				c["fade"] = 0.0
			else:
				c["arriving"] = false
		if not c.get("arriving", false):
			c["fade"] = minf(float(c["fade"]) + delta / 0.8, 1.0)
	if at.distance_to(to) <= go:
		c["at"] = to
		_arrived(c, flee)
	else:
		var next := _step_to(c, to, go, (flee and c["zone"] == "bank") or bool(c.get("trip", false)))
		if next == at:
			c["stuck"] = float(c["stuck"]) + delta
			if float(c["stuck"]) > STUCK_TIME:
				c["stuck"] = 0.0
				c["path"] = []
				_rest(c)
			return
		c["stuck"] = 0.0
		c["facing"] = Flock.facing_of(at, next) if absf(next.x - at.x) > 0.05 else float(c["facing"])
		c["view"] = _view_of(next - at)
		c["at"] = next
		c["walked"] = float(c["walked"]) + at.distance_to(next)
		c["step_px"] = float(c.get("step_px", 0.0)) + at.distance_to(next)
		if float(c["walked"]) >= LAND_PRINT_EVERY:
			c["walked"] = 0.0
			if _sandy(next) and kind != &"snake":
				_track(next)
	if kind == &"capy":
		_capy_water(c)


## The view a walk shows: side on, or straight down or up the screen (a capybara and the
## peacock have those; the rest only side on).
static func _view_of(v: Vector2) -> String:
	if absf(v.y) > absf(v.x) * 1.2:
		return "front" if v.y > 0.0 else "back"
	return "side"


func _arrived(c: Dictionary, flee: bool) -> void:
	if flee and c["zone"] == "bank" and c["kind"] != &"snake":
		# Still on the screen: on the same way, another stretch, until it is off it.
		if _in_view(c["at"]):
			var away: Vector2 = c.get("flee_dir", Vector2.UP)
			c["to"] = (c["at"] as Vector2) + away * FLEE_REACH
			return
		c["gone"] = true
		return
	c.erase("speed")
	if not (c["path"] as Array).is_empty():
		c["to"] = (c["path"] as Array).pop_front()
		c["state"] = Land.MOVE
		return
	if c.get("trip", false):
		c["trip"] = false
		c["zone"] = c.get("trip_to", c["zone"])
		for f in _followers_of(c):
			f["zone"] = c["zone"]
		if c["zone"] == "isle":
			c["stay"] = _now + _rng.randf_range(CAPY_STAY.x, CAPY_STAY.y)
	_rest(c)


func _rest(c: Dictionary) -> void:
	c["state"] = Land.SIT
	c["timer"] = _rng.randf_range(LAND_SIT.x, LAND_SIT.y)
	c["pose_t"] = 0.0
	if c["kind"] == &"capy":
		var roll := _rng.randf()
		c["pose"] = "idle" if roll < 0.45 else ("sit" if roll < 0.8 else "lie")
		c["timer"] = float(c["timer"]) * 2.0


## Off, away from whatever came near: a bank animal into the trees behind the beach, fading
## as it goes; an island bunny across the island; a snake a short way along the grass.
func _land_fright(c: Dictionary, from: Vector2) -> void:
	if int(c["state"]) == Land.FLEE:
		return
	var kind: StringName = c["kind"]
	var at: Vector2 = c["at"]
	var away := (at - from).normalized() if at.distance_to(from) > 0.1 else Vector2.RIGHT
	c["path"] = []
	if kind == &"snake":
		var spot: Dictionary = c["spot"]
		var n: Vector2 = spot["normal"]
		var along := Vector2(-n.y, n.x)
		if along.dot(away) < 0.0:
			along = -along
		# Along the grass, bent towards the lawn's own curve if the straight line leaves it.
		var to := at
		var reach := Iso.tile_circle_extent(_rng.randf_range(SNAKE_AWAY.x, SNAKE_AWAY.y))
		for turn: float in [0.0, 0.3, -0.3, 0.6, -0.6, PI]:
			for share: float in [1.0, 0.6, 0.35]:
				var p := at + along.rotated(turn) * reach * share
				if _walkable(c, p):
					to = p
					break
			if to != at:
				break
		c["to"] = to
		c["speed"] = float(KINDS[kind]["run"])
		c["state"] = Land.FLEE
		return
	if c["zone"] == "isle":
		var best := at
		for p: Vector2 in _isle_lawn:
			if (p - at).dot(away) > 0.0 and p.distance_to(from) > best.distance_to(from):
				best = p
		c["to"] = best
		c["speed"] = float(KINDS[kind]["run"])
		c["state"] = Land.FLEE
		return
	var inland := -((c["spot"] as Dictionary)["normal"] as Vector2)
	c["flee_dir"] = (inland * 1.3 + away).normalized()
	c["to"] = at + (c["flee_dir"] as Vector2) * FLEE_REACH
	c["state"] = Land.FLEE
	c["speed"] = _rng.randf_range(FLEE_SPEED.x, FLEE_SPEED.y)


# ---- fox and wolf: patrolling the beaches ------------------------------------------------

## The bank's shore spots in order round the lake. Built with the shore.
var _bank_ring: Array = []


## A patrol from where this one stands, along the ring of bank spots, a waypoint every
## `PATROL_STRIDE` spots, each pulled a little way up the beach.
func _patrol(c: Dictionary) -> Array:
	if _bank_ring.is_empty():
		return []
	var at: Vector2 = c["at"]
	var here := 0
	var near := INF
	for i in _bank_ring.size():
		var d := at.distance_to((_bank_ring[i] as Dictionary)["land"])
		if d < near:
			near = d
			here = i
	var span := _rng.randi_range(PATROL_REACH.x, PATROL_REACH.y) * (1 if _rng.randf() < 0.5 else -1)
	var out: Array = []
	var step := PATROL_STRIDE * signi(span)
	var i := here
	while absi(i - here) < absi(span):
		i += step
		var spot: Dictionary = _bank_ring[posmod(i, _bank_ring.size())]
		if not _shore_clean(spot):
			break
		var inland := -(spot["normal"] as Vector2)
		var p := _inland_to(spot["land"], inland, _rng.randf_range(0.6, PATROL_INLAND))
		if _blocked(c, p):
			break
		out.append(p)
	return out


## A bank spot for a new fox or wolf: the clean one furthest round the ring from every other
## fox and wolf, so they spread round the lake rather than meeting.
func _spread_spot(bank: Array) -> Dictionary:
	var best: Dictionary = bank[0]
	var best_gap := -1.0
	for n in 12:
		var spot: Dictionary = bank[_rng.randi_range(0, bank.size() - 1)]
		var gap := INF
		for c: Dictionary in _critters_on_land:
			if c["kind"] == &"fox" or c["kind"] == &"wolf":
				gap = minf(gap, (c["at"] as Vector2).distance_to(spot["land"]))
		if gap > best_gap:
			best_gap = gap
			best = spot
	return best


# ---- capybaras: pairs, and the swim to the island ----------------------------------------

func _followers_of(lead: Dictionary) -> Array:
	return _critters_on_land.filter(func(f: Dictionary) -> bool: return f.get("lead") == lead)


## The lead's next move: a wander near home, a trip to the island, or the trip back.
func _capy_choose(c: Dictionary) -> Vector2:
	var at: Vector2 = c["at"]
	var spot: Dictionary = c["spot"]
	if c["zone"] == "isle":
		if _now >= float(c.get("stay", 0.0)):
			var isle := _isle_spot_for(spot)
			c["path"] = [isle["water"], spot["water"], c["home"]]
			c["trip"] = true
			c["trip_to"] = "bank"
			return isle["land"]
		var to := at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-0.5, 0.5)).normalized() \
			* _rng.randf_range(LAND_WANDER.x, LAND_WANDER.y)
		return to
	if _rng.randf() < CAPY_VISIT_ODDS:
		var isle := _isle_spot_for(spot)
		if not isle.is_empty():
			c["path"] = [isle["water"], isle["land"]]
			c["trip"] = true
			c["trip_to"] = "isle"
			return spot["water"]
	var n: Vector2 = spot["normal"]
	var along := Vector2(-n.y, n.x) * (1.0 if _rng.randf() < 0.5 else -1.0)
	return at + along * _rng.randf_range(LAND_WANDER.x, LAND_WANDER.y) + ((c["home"] as Vector2) - at) * 0.4


## The island's shore spot facing a bank spot across the water: the straight swim between
## their water points crosses the lake along a radius.
func _isle_spot_for(spot: Dictionary) -> Dictionary:
	var mid := Iso.tile_to_world(Iso.ISLAND_CENTRE.x, Iso.ISLAND_CENTRE.y)
	var want := ((spot["land"] as Vector2) - mid).normalized()
	var best: Dictionary = {}
	var best_dot := -2.0
	for s: Dictionary in _shore:
		if s["side"] != "island":
			continue
		var d := ((s["land"] as Vector2) - mid).normalized().dot(want)
		if d > best_dot:
			best_dot = d
			best = s
	return best


## The follower keeps beside and behind its lead, catching up at a run, resting when it rests.
func _capy_follow(c: Dictionary, delta: float) -> void:
	var lead: Dictionary = c["lead"]
	if lead.get("gone", false):
		c["gone"] = true
		return
	c["zone"] = lead["zone"]
	c["fade"] = 0.0 if lead.get("arriving", false) else minf(float(c["fade"]) + delta / 0.8, 1.0)
	var at: Vector2 = c["at"]
	var lat: Vector2 = lead["at"]
	var back := Vector2(float(lead["facing"]), 0.0)
	# Behind and beside its lead, or the first of the other places round it that is clear of
	# the trees, the rocks and the buildings; the lead's own spot last.
	var goal := lat
	for off: Vector2 in [back * CAPY_BEHIND + Vector2(0.0, CAPY_BESIDE), back * CAPY_BEHIND - Vector2(0.0, CAPY_BESIDE),
			back * CAPY_BEHIND * 1.4, -back * CAPY_BEHIND + Vector2(0.0, CAPY_BESIDE)]:
		if lead.get("trip", false) or not _blocked(c, lat + off):
			goal = lat + off
			break
	var gap := at.distance_to(goal)
	# Sets off once its place is `CAPY_GO` away and walks until it is within `CAPY_STOP`: one
	# threshold had it starting and stopping every few frames behind a walking lead, swapping
	# its walk and rest pictures (2026-10-06, Richard: "jiggly and bugged when walking"). It
	# walks a little quicker than its lead so it closes the gap rather than holding it.
	var going := int(c["state"]) == Land.MOVE
	if gap > (CAPY_STOP if going else CAPY_GO):
		var speed := float(KINDS[&"capy"]["run"]) if gap > CAPY_CATCH_UP else float(KINDS[&"capy"]["walk"]) * CAPY_KEEP_UP
		speed *= 1.25 if lead.get("trip", false) else 1.0
		var next := _step_to(c, goal, speed * delta, bool(lead.get("trip", false)))
		c["facing"] = Flock.facing_of(at, next) if absf(next.x - at.x) > 0.05 else float(c["facing"])
		c["view"] = _view_of(next - at)
		c["step_px"] = float(c.get("step_px", 0.0)) + at.distance_to(next)
		c["at"] = next
		c["state"] = Land.MOVE
		c["pose"] = "idle"
		c["speed"] = speed
	elif int(c["state"]) != Land.SIT:
		c["state"] = Land.SIT
		c["pose_t"] = 0.0
		c["pose"] = lead["pose"] if int(lead["state"]) == Land.SIT else "idle"
		c.erase("speed")
	_capy_water(c)


## In the water or out of it: the ring going in, and the streak while swimming.
func _capy_water(c: Dictionary) -> void:
	var wet := _wet(c["at"])
	if wet and not bool(c["wet"]):
		_ripple(c["at"], Dog.ENTRY_SPAN)
	c["wet"] = wet


## Out of a walker's way, calmly: a capybara with somebody inside `ROOM` walks
## to a spot `ROOM_OFF` away from them. True when it set off.
func _make_room(c: Dictionary, seen: PackedVector2Array) -> bool:
	if c.get("arriving", false):
		return false
	var at: Vector2 = c["at"]
	var reach := Iso.tile_circle_extent(ROOM)
	var walkers := PackedVector2Array(seen)
	walkers.append_array(_still)
	for p in walkers:
		if p.distance_to(at) >= reach or int(c["state"]) == Land.MOVE and c.get("making_room", false):
			continue
		var away := (at - p).normalized() if at.distance_to(p) > 0.5 else Vector2.RIGHT
		for turn: float in [0.0, 0.7, -0.7, 1.4, -1.4]:
			var to := p + away.rotated(turn) * Iso.tile_circle_extent(ROOM_OFF)
			if _walkable(c, to) and not _blocked(c, to):
				c["to"] = to
				c["state"] = Land.MOVE
				c["pose"] = "idle"
				c["making_room"] = true
				c["path"] = []
				return true
	if int(c["state"]) != Land.MOVE:
		c["making_room"] = false
	return false


# ---- the peacock -------------------------------------------------------------------------

## The peacock fans its tail at the angler or a dog near it, turned towards them, and folds
## it `PEACOCK_HOLD` seconds after they have gone. True while it is displaying.
func _peacock_display(c: Dictionary, seen: PackedVector2Array, delta: float) -> bool:
	# Still coming out from behind the box: it walks on, unseen, and fans nothing.
	if c.get("arriving", false):
		return false
	if c.get("making_room", false) and int(c["state"]) == Land.MOVE:
		return false
	var at: Vector2 = c["at"]
	var near := Iso.tile_circle_extent(PEACOCK_NEAR)
	var who := Vector2.INF
	var walkers := PackedVector2Array(seen)
	walkers.append_array(_still)
	for p in walkers:
		if p.distance_to(at) < near and (who == Vector2.INF or p.distance_to(at) < who.distance_to(at)):
			who = p
	if who != Vector2.INF:
		c["state"] = Land.DISPLAY
		c["timer"] = PEACOCK_HOLD
		c["fade"] = minf(float(c["fade"]) + delta, 1.0)
		var look := who - at
		c["view"] = _view_of(look)
		if absf(look.x) > 0.5:
			c["facing"] = Flock.facing_of(at, who)
		return true
	if int(c["state"]) == Land.DISPLAY:
		c["timer"] = float(c["timer"]) - delta
		if float(c["timer"]) <= 0.0:
			_rest(c)
			c["timer"] = 0.0
		return true
	return false


# ---- drawing them ------------------------------------------------------------------------

## The picture this land animal is showing this instant.
func _land_frame(c: Dictionary) -> String:
	var kind: StringName = c["kind"]
	var state: int = c["state"]
	var clock := float(c["clock"])
	var moving := state == Land.MOVE or state == Land.FLEE
	var stepped := float(c.get("step_px", 0.0))
	match kind:
		&"bunny":
			if moving:
				var fps := BUNNY_RUN_FPS * (1.6 if state == Land.FLEE else 1.0)
				return "bunny_%s_run%d" % [c["coat"], int(clock * fps) % 8]
			return "bunny_%s_idle%d" % [c["coat"], int(clock * BUNNY_IDLE_FPS) % 12]
		&"fox", &"wolf":
			var runs := 4 if kind == &"fox" else 6
			if state == Land.FLEE:
				return "%s_run%d" % [kind, int(clock * CANID_RUN_FPS) % runs]
			if moving:
				return "%s_run%d" % [kind, int(clock * CANID_WALK_FPS) % runs]
			return "%s_idle%d" % [kind, int(clock * CANID_IDLE_FPS) % 4]
		&"snake":
			return "snake_%s_%d" % [c["coat"], int(stepped / SNAKE_STEP_PX) % 7 if moving else 0]
		&"capy":
			if moving:
				var view: String = c["view"]
				var anim := "walk" if view == "side" else ("fwalk" if view == "front" else "bwalk")
				if float(c.get("speed", 0.0)) > float(KINDS[&"capy"]["walk"]) * 1.5 and view == "side" and not bool(c["wet"]):
					return "capy_run%d" % (int(stepped / CAPY_STEP_PX) % 5)
				return "capy_%s%d" % [anim, int(stepped / CAPY_STEP_PX) % 5]
			var t := float(c["pose_t"])
			var settle := mini(int(t / CAPY_SETTLE * 5.0), 4)
			if state == Land.RISE:
				var from: String = c.get("rising", "idle")
				if from == "sit":
					return "capy_sit%d" % (4 - settle)
				return "capy_stand%d" % settle
			match String(c["pose"]):
				"sit":
					return "capy_sit%d" % settle
				"lie":
					return "capy_stand%d" % (4 - settle)
			return "capy_idle%d" % (int(clock * 4.0) % 5)
		&"peacock":
			var view: String = c["view"]
			if state == Land.DISPLAY:
				return "peacock_open_%s%d" % [view, int(clock * PEACOCK_STRUT_FPS) % 3]
			if moving:
				return "peacock_fold_%s%d" % [view, int(stepped / PEACOCK_STEP_PX) % 4]
			return "peacock_fold_%s0" % view
	return ""


func _draw_land(on: CanvasItem, c: Dictionary) -> void:
	var name := _land_frame(c)
	var r := _region(name)
	if r.size.x <= 0.0:
		return
	var scale_by := float(KINDS[c["kind"]]["scale"])
	var at := (c["at"] as Vector2).round()
	# Only a side view is mirrored: the front and back views are drawn the one way.
	var facing := 1.0 if ("fwalk" in name or "bwalk" in name or "_front" in name or "_back" in name) \
		else float(c["facing"])
	var fade := float(c["fade"])
	if c["kind"] == &"capy" and bool(c["wet"]):
		# Swimming the dogs' way: cut at the waterline, bobbing, its shadow cut where it is,
		# a foam collar on the cut.
		var cut := floorf(r.size.y * CAPY_SINK)
		var shown := Rect2(r.position, Vector2(r.size.x, r.size.y - cut))
		var water := at + Vector2(0.0, roundf(sin(float(c["clock"]) * CAPY_BOB_RATE) * CAPY_BOB))
		var sun := _sun() * FLOAT_SHADE
		Flock.stamp(on, _critters, shown, Vector2.ZERO, facing, Shade.tint_on(day, Shade.On.WATER, fade),
			Shade.lying(water, sun.x, sun.y), Vector2.ZERO, scale_by * SCALE / Flock.SCALE)
		Flock.stamp(on, _critters, shown, water, facing, Color(1.0, 1.0, 1.0, fade),
			Transform2D.IDENTITY, Vector2.ZERO, scale_by * SCALE / Flock.SCALE)
		_collar(on, water, r.size.x * scale_by * SCALE * 0.8, float(c["clock"]), fade)
		return
	# The sun's shadow, the dog's own: the picture laid on the land from the feet.
	_lay(on, name, at, facing, Shade.On.LAND, fade, scale_by)
	_stamp(on, name, at, facing, Color(1.0, 1.0, 1.0, fade), scale_by)


## The capybaras' and the turtles' foam streaks: the ferry's HullFoam, small, behind each
## one swimming.
var _streaks: Dictionary = {}


func _lay_streaks(delta: float) -> void:
	var alive := {}
	var swimmers: Array = []
	for c: Dictionary in _critters_on_land:
		if c["kind"] == &"capy":
			swimmers.append([c, bool(c["wet"]), 1.0])
	for t: Dictionary in _turtles:
		swimmers.append([t, int(t["state"]) == Turtle.SWIM, TURTLE_DRAWN])
	for pair: Array in swimmers:
		var c: Dictionary = pair[0]
		var swimming: bool = pair[1]
		var small: float = pair[2]
		var id: int = c.get_or_add("id", _rng.randi())
		alive[id] = true
		var streak: HullFoam = _streaks.get(id)
		if streak == null:
			streak = HullFoam.new()
			streak.half_length = Dog.STREAK_LONG * small
			streak.half_width = Dog.STREAK_WIDE * small
			streak.show_behind_parent = true
			_ground.add_child(streak)
			_streaks[id] = streak
		var at: Vector2 = c["at"]
		var was: Vector2 = c.get("streak_from", at)
		c["streak_from"] = at
		var heading := at - was if at.distance_squared_to(was) > 0.0001 else Vector2(-float(c["facing"]), 0.0)
		streak.position = at
		streak.lay(heading, 1.0 if swimming and at != was else 0.0, delta)
	for id in _streaks.keys():
		if not alive.has(id):
			(_streaks[id] as HullFoam).queue_free()
			_streaks.erase(id)


# ---- songbirds ---------------------------------------------------------------------------

enum Bird { GROUND, FLY }
enum Pose { IDLE, WALK, PECK }


## Every spot a songbird may land: dealt once round each shore spot, from its own sand up to
## `BIRD_WATER_REACH` tiles inland (onto the island's lawn, never the bank's), each keeping
## the shore spot whose water decides whether it is open.
func _find_bird_spots() -> void:
	_bird_spots.clear()
	var keep := RandomNumberGenerator.new()
	keep.seed = 20261003
	for i in _shore.size():
		var spot: Dictionary = _shore[i]
		var inland := -(spot["normal"] as Vector2)
		var along := Vector2(-inland.y, inland.x)
		var side := String(spot["side"])
		for k in BIRD_SPOTS_PER_SHORE:
			var at: Vector2 = (spot["land"] as Vector2) \
				+ inland * Iso.tile_circle_extent(keep.randf_range(0.0, BIRD_WATER_REACH)) \
				+ along * Iso.tile_circle_extent(keep.randf_range(-0.6, 0.6))
			if _bird_ground(at, side):
				_bird_spots.append({"at": at, "shore": i, "side": side})


## Ground a songbird may stand or walk on: the island's sand and lawn, or the bank's sand, dry
## and off the hut, the pump, the hive and the crate.
func _bird_ground(at: Vector2, side: String) -> bool:
	if _wet(at):
		return false
	if side == "bank":
		return _on_sand(at, "bank")
	var tile := Iso.world_to_tile(at)
	if Iso.past_shelf(tile) > -0.15:
		return false
	if Iso.in_shed(tile.x, tile.y, Iso.SHED_COVER + 0.3) or Pump.covers(tile, 0.6) or Hive.covers(tile, 0.6):
		return false
	return crate_tile == Vector2.INF or not Yard.covers(crate_tile, tile, 0.6)


## Is this spot open: is the water beside it clean, on the honest map.
func _bird_open(spot: Dictionary) -> bool:
	return _shore_clean(_shore[int(spot["shore"])])


## A bird flies in from off the lake to an open spot.
func _new_bird() -> Dictionary:
	var open := _bird_spots.filter(func(sp: Dictionary) -> bool: return _bird_open(sp) and not _taken_by_still(sp["at"]))
	if open.is_empty():
		return {}
	var spot: Dictionary = open[_rng.randi_range(0, open.size() - 1)]
	var to: Vector2 = spot["at"]
	var a := _rng.randf_range(0.0, TAU)
	var from := to + Vector2(cos(a), sin(a) * 0.5) * BIRD_FROM
	var s := {
		"species": BIRD_SPECIES[_rng.randi_range(0, BIRD_SPECIES.size() - 1)],
		"at": from, "alt": BIRD_IN_ALT, "fade": 0.0, "clock": _rng.randf() * 3.0,
		"facing": 1.0, "spot": spot, "pose": Pose.IDLE, "timer": 0.0, "walked": 0.0,
	}
	_bird_fly(s, to, BIRD_IN_ALT, 0.0, 0.0)
	return s


## Off on a flight: from where it is (at `alt_from`) to `to` (at `alt_to`), arcing `arc`
## higher in the middle. The ground point moves in a line; the height is the arc.
func _bird_fly(s: Dictionary, to: Vector2, alt_from: float, alt_to: float, arc: float) -> void:
	s["state"] = Bird.FLY
	s["from"] = s["at"]
	s["to"] = to
	s["alt_from"] = alt_from
	s["alt_to"] = alt_to
	s["arc"] = arc
	s["t"] = 0.0
	s["facing"] = Flock.facing_of(s["at"], to)
	s.erase("cue")


func _bird_step(s: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	s["clock"] = float(s["clock"]) + delta
	var at: Vector2 = s["at"]
	if int(s["state"]) == Bird.FLY:
		var span := (s["from"] as Vector2).distance_to(s["to"])
		s["t"] = float(s["t"]) + delta * BIRD_FLY / maxf(span, 1.0)
		var t := minf(float(s["t"]), 1.0)
		s["at"] = (s["from"] as Vector2).lerp(s["to"], t)
		s["alt"] = lerpf(float(s["alt_from"]), float(s["alt_to"]), t) + float(s["arc"]) * sin(t * PI)
		s["fade"] = minf(float(s["fade"]) + delta / 0.6, 1.0)
		if t >= 1.0:
			if bool(s.get("leaving", false)):
				# Flies on the way it was going until it is off the screen.
				if _in_view(s["at"]):
					var on := ((s["to"] as Vector2) - (s["from"] as Vector2)).normalized()
					_bird_fly(s, (s["at"] as Vector2) + on * BIRD_FROM, float(s["alt"]), float(s["alt"]), 0.0)
					return
				s["gone"] = true
				return
			s["state"] = Bird.GROUND
			s["alt"] = 0.0
			_bird_idle(s)
		return
	# On the ground: anything moving close sends it off, a little closer and it flies.
	var wary := Iso.tile_circle_extent(BIRD_WARY)
	var shy := Iso.tile_circle_extent(BIRD_SHY)
	for p in seen:
		var d := p.distance_to(at)
		if d < shy:
			_bird_flush(s, p)
			return
		if d < wary and not bool(s.get("scurry", false)):
			_bird_away(s, p)
			break
	if hears(at) and Sfx.main() != null and _rng.randf() < delta * 0.5:
		Sfx.main().play_songbird(String(s["species"]))
	match int(s["pose"]):
		Pose.IDLE:
			if s.has("cue"):
				_bird_on_cue(s)
			else:
				s["timer"] = float(s["timer"]) - delta
				if float(s["timer"]) <= 0.0:
					_bird_choose(s)
		Pose.PECK:
			s["t"] = float(s["t"]) + delta / PECK_TIME
			if float(s["t"]) >= 1.0:
				s["pecks"] = int(s["pecks"]) - 1
				if int(s["pecks"]) > 0:
					s["pose"] = Pose.IDLE
					s["cue"] = floorf(beat() + _peck_lead()) + 1.0
				else:
					_bird_idle(s)
		Pose.WALK:
			var to: Vector2 = s["to"]
			var step := to - at
			var go := (BIRD_SCURRY if bool(s.get("scurry", false)) else BIRD_WALK) * delta
			if absf(step.x) > 0.3:
				s["facing"] = Flock.facing_of(at, to)
			if step.length() <= go:
				s["at"] = to
				s.erase("scurry")
				_bird_idle(s)
			else:
				var next := _round(at, at + step.normalized() * go)
				if not _bird_ground(next, String((s["spot"] as Dictionary)["side"])):
					s.erase("scurry")
					_bird_idle(s)
				else:
					s["walked"] = float(s["walked"]) + at.distance_to(next)
					s["at"] = next


func _bird_idle(s: Dictionary) -> void:
	s["pose"] = Pose.IDLE
	s["timer"] = _rng.randf_range(BIRD_IDLE.x, BIRD_IDLE.y)
	s.erase("cue")


## How many beats before its beat a peck starts so its lowest frame lands on it.
func _peck_lead() -> float:
	return PECK_TIME * PECK_HIT / beat_length()


## What a standing bird does next: a run of pecks on its own coming beats, a few steps, or
## another look round.
func _bird_choose(s: Dictionary) -> void:
	var roll := _rng.randf()
	if roll < 0.5:
		s["pecks"] = _rng.randi_range(1, PECKS_MOST)
		s["cue"] = floorf(beat() + _peck_lead()) + float(_rng.randi_range(1, 2))
		return
	if roll < 0.85:
		var side := String((s["spot"] as Dictionary)["side"])
		for attempt in 4:
			var a := _rng.randf_range(0.0, TAU)
			var to: Vector2 = (s["at"] as Vector2) + Vector2(cos(a), sin(a) * 0.5) * Iso.tile_circle_extent(_rng.randf_range(0.3, 1.0))
			# Pulled back towards its spot, so it does not wander off up the island.
			to = to.lerp((s["spot"] as Dictionary)["at"], 0.3)
			if _bird_ground(to, side) and not _taken_by_still(to):
				s["pose"] = Pose.WALK
				s["to"] = to
				return
	_bird_idle(s)


## A peck starts once its beat is near enough for the head to be down on it; a cue the clock
## jumped past (a song changing) is picked again, as the frogs' are.
func _bird_on_cue(s: Dictionary) -> void:
	var lead := _peck_lead()
	var now := beat()
	var start := float(s["cue"]) - lead
	if start - now > 8.0 or now - start > CUE_MISSED:
		s["cue"] = floorf(now + lead) + 1.0
	if now < float(s["cue"]) - lead:
		return
	s.erase("cue")
	s["pose"] = Pose.PECK
	s["t"] = 0.0


## Something moving came near, not near enough to fly: a quick walk directly away.
func _bird_away(s: Dictionary, from: Vector2) -> void:
	var at: Vector2 = s["at"]
	var off := at - from
	if off.length() < 0.5:
		off = Vector2.RIGHT
	var to := at + off.normalized() * Iso.tile_circle_extent(0.8)
	if _bird_ground(to, String((s["spot"] as Dictionary)["side"])) and not _taken_by_still(to):
		s["pose"] = Pose.WALK
		s["to"] = to
		s["scurry"] = true
		s.erase("cue")


## Up and away from `from`: to another open spot a few tiles off, or off the lake if none.
func _bird_flush(s: Dictionary, from: Vector2) -> void:
	if int(s["state"]) == Bird.FLY:
		return
	var at: Vector2 = s["at"]
	if hears(at) and Sfx.main() != null:
		Sfx.main().play_flush()
	var near: Array = []
	var reach := Iso.tile_circle_extent(BIRD_FLUSH_REACH)
	var least := Iso.tile_circle_extent(BIRD_FLUSH_LEAST)
	var shy := Iso.tile_circle_extent(BIRD_WARY)
	for sp: Dictionary in _bird_spots:
		var p: Vector2 = sp["at"]
		var d := p.distance_to(at)
		if d < reach and d > least and p.distance_to(from) > shy and _bird_open(sp) and not _taken_by_still(p):
			near.append(sp)
	s.erase("scurry")
	if near.is_empty():
		var off := at - from
		if off.length() < 0.5:
			off = Vector2.UP
		s["leaving"] = true
		_bird_fly(s, at + off.normalized() * BIRD_FROM, 0.0, BIRD_IN_ALT, 0.0)
		return
	var spot: Dictionary = near[_rng.randi_range(0, near.size() - 1)]
	s["spot"] = spot
	_bird_fly(s, spot["at"], 0.0, 0.0, BIRD_HOP_ARC + at.distance_to(spot["at"]) * 0.15)


## The picture a bird shows this instant.
func _bird_frame(s: Dictionary) -> String:
	var species := String(s["species"])
	if int(s["state"]) == Bird.FLY:
		return "bird_%s_fly%d" % [species, int(float(s["clock"]) * BIRD_FLY_FPS) % 4]
	match int(s["pose"]):
		Pose.PECK:
			return "bird_%s_peck%d" % [species, mini(int(float(s["t"]) * 5.0), 4)]
		Pose.WALK:
			return "bird_%s_walk%d" % [species, int(float(s["walked"]) / BIRD_STEP_PX) % 5]
	return "bird_%s_idle%d" % [species, int(float(s["clock"]) * BIRD_IDLE_FPS) % 5]


## A bird on the ground: its own picture laid down by the sun from its feet, in the ink of
## what it stands on, then the bird.
func _draw_bird_ground(on: CanvasItem, s: Dictionary) -> void:
	var name := _bird_frame(s)
	var at := (s["at"] as Vector2).round()
	var fade := float(s["fade"])
	_lay(on, name, at, float(s["facing"]), _surface_at(at), fade, BIRD_SCALE)
	_stamp(on, name, at, float(s["facing"]), Color(1.0, 1.0, 1.0, fade), BIRD_SCALE)


## A flying bird's shadow: its silhouette thrown from the ground point under it by its height
## (`Shade.drop`), on whatever it falls on, shrunk and thinned with the height.
func _draw_bird_shadow(on: CanvasItem, s: Dictionary) -> void:
	var alt := float(s["alt"])
	var up := clampf(alt / BIRD_SHADE_ALT, 0.0, 1.0)
	var ground := (s["at"] as Vector2) + Shade.drop(day, alt)
	_lay(on, _bird_frame(s), ground.round(), float(s["facing"]), _surface_at(ground),
		float(s["fade"]) * (1.0 - SHADE_THIN * up), BIRD_SCALE * (1.0 - SHADE_SHRINK * up))


func _draw_bird_air(on: CanvasItem, s: Dictionary) -> void:
	var at := ((s["at"] as Vector2) - Vector2(0.0, float(s["alt"]))).round()
	_stamp(on, _bird_frame(s), at, float(s["facing"]), Color(1.0, 1.0, 1.0, float(s["fade"])), BIRD_SCALE)


# ---- ducks ------------------------------------------------------------------------------

enum Brood { FLY_IN, SWIM, DABBLE, TAKE_OFF }


## A brood flies in from off the lake to a clean tile: a drake alone, or a hen with ducklings.
func _new_brood() -> Dictionary:
	for attempt in 16:
		var index := _clean[_rng.randi_range(0, _clean.size() - 1)]
		var tile := grid.tile_of(index)
		var land := Iso.tile_to_world(float(tile.x) + 0.5, float(tile.y) + 0.5)
		if not _swimmable(land) or not _swimmable(land + Vector2(24.0, 0.0)) or not _swimmable(land - Vector2(24.0, 0.0)):
			continue
		var a := _rng.randf_range(0.0, TAU)
		var from := land + Vector2(cos(a), sin(a) * 0.5) * DUCK_FROM
		var hen := _rng.randf() < 0.65
		var kids := _rng.randi_range(maxi(DUCKLINGS.x, 1), DUCKLINGS.y) if hen else 0
		var kid_list: Array = []
		for k in kids:
			kid_list.append({"at": from, "wobble": _rng.randf() * 10.0})
		return {
			"state": Brood.FLY_IN, "at": from, "from": from, "to": land, "alt": DUCK_ALT,
			"t": 0.0, "kind": "hen" if hen else "drake", "kids": kid_list,
			"trail": PackedVector2Array(), "trail_in": 0.0, "facing": Flock.facing_of(from, land),
			"timer": _rng.randf_range(DUCK_STAY.x, DUCK_STAY.y), "wake": 0.0, "clock": _rng.randf() * 5.0,
			"goal": land,
		}
	return {}


func _brood_step(b: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	b["clock"] = float(b["clock"]) + delta
	# A brood in earshot calls now and then; the gap is the station's (`Sfx.DUCK_GAP`).
	if Sfx.main() != null and hears(b["at"]):
		Sfx.main().play_duck()
	var state: int = b["state"]
	var at: Vector2 = b["at"]
	match state:
		Brood.FLY_IN:
			var span := (b["from"] as Vector2).distance_to(b["to"])
			b["t"] = float(b["t"]) + delta * DUCK_FLY / maxf(span, 1.0)
			var t := minf(float(b["t"]), 1.0)
			b["at"] = (b["from"] as Vector2).lerp(b["to"], t)
			# Glides down over the last stretch, not the whole way.
			b["alt"] = DUCK_ALT * clampf((1.0 - t) / 0.45, 0.0, 1.0)
			_kids_fly(b)
			if t >= 1.0:
				b["state"] = Brood.SWIM
				b["alt"] = 0.0
				if splash != null:
					_ripple(b["at"], 20.0)
					_ripple(b["at"], 34.0)
				for kid: Dictionary in b["kids"]:
					kid["at"] = b["at"]
		Brood.SWIM, Brood.DABBLE:
			var shy := Iso.tile_circle_extent(DUCK_SHY)
			for p in seen:
				if p.distance_to(at) < shy:
					_brood_fright(b, p)
					return
			b["timer"] = float(b["timer"]) - delta
			if float(b["timer"]) <= 0.0 or not _swimmable(at):
				_brood_fright(b, at + Vector2(_rng.randf_range(-1.0, 1.0), _rng.randf_range(-1.0, 1.0)))
				return
			if state == Brood.DABBLE:
				b["dabble"] = float(b["dabble"]) - delta
				if float(b["dabble"]) <= 0.0:
					b["state"] = Brood.SWIM
			else:
				var goal: Vector2 = b["goal"]
				var step := goal - at
				if step.length() < 3.0:
					if _rng.randf() < 0.25:
						b["state"] = Brood.DABBLE
						b["dabble"] = _rng.randf_range(1.5, 3.0)
					b["goal"] = _duck_goal(at)
				else:
					var next := at + step.normalized() * DUCK_SWIM * delta
					if _swimmable(next):
						b["at"] = next
						if absf(step.x) > 0.5:
							b["facing"] = 1.0 if step.x < 0.0 else -1.0
					else:
						b["goal"] = _duck_goal(at)
				b["wake"] = float(b["wake"]) - delta
				if float(b["wake"]) <= 0.0:
					b["wake"] = _rng.randf_range(1.2, 2.0)
					if splash != null:
						_ripple(b["at"], 9.0)
			_kids_swim(b, delta)
		Brood.TAKE_OFF:
			var vel: Vector2 = b["vel"]
			b["t"] = float(b["t"]) + delta
			var speed := minf(float(b["t"]) * 140.0, DUCK_FLY * 1.2)
			b["at"] = at + vel * speed * delta
			b["alt"] = minf(float(b["alt"]) + delta * (40.0 + float(b["t"]) * 60.0), DUCK_ALT * 1.3)
			_kids_fly(b)
			if (b["at"] as Vector2).distance_to(b["from"]) > DUCK_FROM and not _in_view(b["at"], BROOD_VIEW_MARGIN):
				b["gone"] = true


## A new place to paddle to, a couple of tiles off, on clean water.
func _duck_goal(at: Vector2) -> Vector2:
	for n in 8:
		var a := _rng.randf_range(0.0, TAU)
		var to := at + Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(30.0, 110.0)
		if _swimmable(to):
			return to
	return at


func _brood_fright(b: Dictionary, from: Vector2) -> void:
	if int(b["state"]) == Brood.TAKE_OFF or int(b["state"]) == Brood.FLY_IN:
		return
	var off := (b["at"] as Vector2) - from
	if off.length() < 1.0:
		off = Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
	var dir := Vector2(off.x, off.y * 0.5).normalized()
	b["state"] = Brood.TAKE_OFF
	b["vel"] = dir
	b["from"] = b["at"]
	b["t"] = 0.0
	b["facing"] = 1.0 if dir.x < 0.0 else -1.0
	if splash != null:
		_ripple(b["at"], 18.0)
		for kid: Dictionary in b["kids"]:
			_ripple(kid["at"], 8.0)


## Ducklings on the water follow the leader's own wake, a few steps apart.
func _kids_swim(b: Dictionary, delta: float) -> void:
	b["trail_in"] = float(b["trail_in"]) - delta
	var trail: PackedVector2Array = b["trail"]
	if float(b["trail_in"]) <= 0.0:
		b["trail_in"] = TRAIL_STEP
		trail.insert(0, b["at"])
		var keep := ((b["kids"] as Array).size() + 1) * TRAIL_GAP + 1
		if trail.size() > keep:
			trail.resize(keep)
		b["trail"] = trail
	var kids: Array = b["kids"]
	for i in kids.size():
		var kid: Dictionary = kids[i]
		var k := mini((i + 1) * TRAIL_GAP, trail.size() - 1)
		var want: Vector2 = trail[k] if k >= 0 and trail.size() > 0 else b["at"]
		var at: Vector2 = kid["at"]
		var step := want - at
		if absf(step.x) > 0.3:
			kid["facing"] = 1.0 if step.x < 0.0 else -1.0
		kid["at"] = at + step * minf(delta * 4.0, 1.0)


## Ducklings in the air keep station behind the leader.
func _kids_fly(b: Dictionary) -> void:
	var kids: Array = b["kids"]
	var facing := float(b["facing"])
	for i in kids.size():
		var kid: Dictionary = kids[i]
		var row := float(i / 2 + 1)
		var side := -1.0 if i % 2 == 0 else 1.0
		kid["at"] = (b["at"] as Vector2) + Vector2(facing * 10.0 * row, side * 5.0 * row + 3.0)
		kid["facing"] = facing
	b["trail"] = PackedVector2Array()


# ---- dragonflies ------------------------------------------------------------------------

## A dragonfly keeps to a patch near a clean shore or over a pad, hovering and darting.
func _new_fly(shore: Array) -> Dictionary:
	var home: Vector2
	if not _pads.is_empty() and (shore.is_empty() or _rng.randf() < 0.5):
		home = _pads[_rng.randi_range(0, _pads.size() - 1)]
	else:
		var spot: Dictionary = shore[_rng.randi_range(0, shore.size() - 1)]
		home = (spot["water"] as Vector2).lerp(spot["land"], 0.4)
	return {
		"at": home, "from": home, "to": home, "home": home, "t": 1.0, "dur": 0.3,
		"timer": _rng.randf_range(FLY_HOVER.x, FLY_HOVER.y), "alt": _rng.randf_range(FLY_ALT.x, FLY_ALT.y),
		"heading": Vector2.LEFT, "body": _rng.randi_range(0, FLY_BODIES.size() - 1), "fade": 0.0,
		"jit": Vector2.ZERO,
	}


func _fly_step(d: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	d["fade"] = minf(float(d["fade"]) + delta * 1.5, 1.0)
	var at: Vector2 = d["at"]
	if float(d["t"]) < 1.0:
		d["t"] = float(d["t"]) + delta / float(d["dur"])
		var t := minf(float(d["t"]), 1.0)
		var e := 1.0 - pow(1.0 - t, 3.0)
		d["at"] = (d["from"] as Vector2).lerp(d["to"], e)
		return
	var shy := Iso.tile_circle_extent(FLY_SHY)
	for p in seen:
		if p.distance_to(at) < shy:
			_fly_fright(d, p)
			return
	d["timer"] = float(d["timer"]) - delta
	# Hovering: a pixel of jitter now and then.
	if _rng.randf() < delta * 8.0:
		d["jit"] = Vector2(_rng.randi_range(-1, 1), _rng.randi_range(-1, 1)) * ART
	if float(d["timer"]) <= 0.0 and not d.has("cue"):
		d["cue"] = floorf(beat()) + 1.0
	if d.has("cue") and (beat() - float(d["cue"]) > CUE_MISSED or float(d["cue"]) - beat() > 2.0):
		d["cue"] = floorf(beat()) + 1.0
	if d.has("cue") and beat() >= float(d["cue"]):
		d.erase("cue")
		var home: Vector2 = d["home"]
		var reach := Iso.tile_circle_extent(FLY_ROAM)
		var a := _rng.randf_range(0.0, TAU)
		var to := home + Vector2(cos(a), sin(a) * 0.5) * _rng.randf_range(0.2, 1.0) * reach
		_fly_dart(d, to)


func _fly_dart(d: Dictionary, to: Vector2) -> void:
	d["from"] = d["at"]
	d["to"] = to
	d["t"] = 0.0
	d["dur"] = _rng.randf_range(FLY_DART.x, FLY_DART.y)
	d["timer"] = float(_rng.randi_range(FLY_HOVER_BEATS.x, FLY_HOVER_BEATS.y)) * beat_length()
	var step := to - (d["at"] as Vector2)
	if step.length() > 0.5:
		d["heading"] = step.normalized()
	d["jit"] = Vector2.ZERO


func _fly_fright(d: Dictionary, from: Vector2) -> void:
	var off := (d["at"] as Vector2) - from
	if off.length() < 1.0:
		off = Vector2.UP
	_fly_dart(d, (d["at"] as Vector2) + off.normalized() * Iso.tile_circle_extent(2.0))
	d["dur"] = 0.2


func _track(at: Vector2) -> void:
	if _track_at.size() >= TRACKS_MOST:
		_track_at.remove_at(0)
		_track_age.remove_at(0)
	_track_at.append((at / ART).floor() * ART)
	_track_age.append(0.0)


func _age_tracks(delta: float) -> void:
	var drop := 0
	for i in _track_age.size():
		_track_age[i] += delta
		if _track_age[i] >= TRACK_LIFE:
			drop = i + 1
	if drop > 0:
		_track_at = _track_at.slice(drop)
		_track_age = _track_age.slice(drop)



## Sand, of either shore, and dry: the only ground that takes a print.
func _sandy(at: Vector2) -> bool:
	var tile := Iso.world_to_tile(at)
	if Iso.island_fraction(tile.x, tile.y) < 1.5:
		return Iso.past_shelf(tile) < -0.1 and Iso.lawn_depth(tile) < -0.2
	var out := Ground.out_of_water(tile.x, tile.y)
	return out > 0.15 and out < Ground.BEACH_IN


## A ring on the water, if the splash layer has room: the animals may use at most half of
## its rings, so a net's landing ring or a walker's entry ring is never the one refused.
func _ripple(at: Vector2, span: float) -> void:
	if splash == null:
		return
	var rings: PackedFloat32Array = splash.get(&"_ripple_age")
	if rings.size() >= WaterSplash.MAX_RIPPLES / 2:
		return
	splash.ripple(at, span)


# ---- facing -----------------------------------------------------------------------------

## The frog sheet's row for a screen direction. The rows run S, SE, E, NE, N, NW, W, SW
## (read off the jump frames, which point the way the frog goes).  Screen angle k, in
## eighths clockwise from east, is row (2 - k).
static func _row_of(v: Vector2) -> int:
	if v.length() < 0.001:
		return 0
	var k := posmod(roundi(atan2(v.y, v.x) / (PI / 4.0)), 8)
	return posmod(2 - k, 8)


## The swim shadow's heading for a screen direction: eighths of a turn on the plane.
static func _plane_heading(v: Vector2) -> int:
	if v.length() < 0.001:
		return 0
	return posmod(roundi(atan2(v.y * 2.0, v.x) / (PI / 4.0)), 8)


# ---- drawing ----------------------------------------------------------------------------

func _region(name: String) -> Rect2:
	var r: Array = _table.get(name, [0, 0, 0, 0])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## A critter picture standing on `at`, facing (+1 left as drawn, -1 mirrored).
func _stamp(on: CanvasItem, name: String, at: Vector2, facing: float, tint: Color = Color.WHITE, scale_by: float = 1.0) -> void:
	var frame := _region(name)
	if frame.size.x <= 0.0:
		return
	Flock.stamp(on, _critters, frame, at, facing, tint, Transform2D.IDENTITY, Vector2.ZERO, scale_by * SCALE / Flock.SCALE)


## The sun's lean and stretch as `Shade.lying` takes them: the day's, or the lake's own
## (`Shade.sun_of`); with neither, the fallback `Shade.drop` uses, so a laid shadow and a
## dropped one agree.
func _sun() -> Vector2:
	var sun := Shade.sun_of(day)
	if sun == null:
		return Vector2(-0.2, 0.8)
	return Vector2(sun.lean, sun.stretch)


## The surface a shadow at `at` (world) falls on: the water as it is drawn, or the land.
func _surface_at(at: Vector2) -> int:
	return Shade.On.WATER if _wet(at) else Shade.On.LAND


## A critter picture's shadow: the picture laid down from `at` by the sun (`Shade.lying`), in
## `Shade`'s ink for `surface`. `reach` shortens it (a floating body, `FLOAT_SHADE`).
func _lay(on: CanvasItem, name: String, at: Vector2, facing: float, surface: int, fade: float,
		scale_by: float = 1.0, reach: float = 1.0) -> void:
	var frame := _region(name)
	if frame.size.x <= 0.0:
		return
	var sun := _sun() * reach
	Flock.stamp(on, _critters, frame, Vector2.ZERO, facing, Shade.tint_on(day, surface, fade),
		Shade.lying(at, sun.x, sun.y), Vector2.ZERO, scale_by * SCALE / Flock.SCALE)


# ---- crayfish on the lakebed -----------------------------------------------------------

enum Cray { REST, CRAWL, DART }
var _crays: Array = []


func crayfish_count() -> int:
	return _crays.size()


func crayfish() -> Array:
	return _crays


## Water a crayfish may be on: clean on the honest map, over the bed, not too deep.
func _cray_ok(at: Vector2) -> bool:
	if grid == null or not _wet(at) or not Fish.bed_shows(grid, at):
		return false
	var tile := Iso.world_to_tile(at)
	if grid.water_state(grid.index_of(int(floor(tile.x)), int(floor(tile.y)))) != 0:
		return false
	var depth := Fish.depth_at(at)
	return depth >= CRAY_SHALLOWEST and depth < CRAY_DEEPEST


func _new_cray() -> Dictionary:
	if _clean.is_empty():
		return {}
	for attempt in 12:
		var tile := grid.tile_of(_clean[_rng.randi_range(0, _clean.size() - 1)])
		var at := Iso.tile_to_world(float(tile.x) + _rng.randf(), float(tile.y) + _rng.randf())
		if _cray_ok(at):
			return {"at": at, "angle": _rng.randf_range(0.0, TAU), "state": Cray.REST,
				"timer": _rng.randf_range(CRAY_REST.x, CRAY_REST.y), "fade": 0.0, "walked": 0.0}
	return {}


func _cray_step(c: Dictionary, delta: float, seen: PackedVector2Array) -> void:
	var at: Vector2 = c["at"]
	var ok := _cray_ok(at)
	# Off clean water it fades away only where nobody sees it: on the screen, through water
	# that still shows the bed, it holds and crawls on.
	var held := not ok and Fish.bed_shows(grid, at) and _in_view(at)
	if not held:
		c["fade"] = clampf(float(c["fade"]) + (delta if ok else -delta) / 0.8, 0.0, 1.0)
	if not ok and not held and float(c["fade"]) <= 0.0:
		c["gone"] = true
		return
	c["timer"] = float(c["timer"]) - delta
	var state: int = c["state"]
	if state == Cray.REST:
		if float(c["timer"]) <= 0.0:
			c["state"] = Cray.CRAWL
			c["angle"] = float(c["angle"]) + _rng.randf_range(-1.2, 1.2)
			c["timer"] = _rng.randf_range(CRAY_WALK.x, CRAY_WALK.y)
		return
	var a := float(c["angle"])
	var dir := Vector2(cos(a), sin(a) * 0.5).normalized()
	var speed := CRAY_CRAWL
	if state == Cray.DART:
		dir = -dir                                   # backwards, tail first
		speed = CRAY_DART
	var next := _round(at, at + dir * speed * delta)
	if not _cray_ok(next):
		c["angle"] = a + PI * _rng.randf_range(0.5, 0.9) * (1.0 if _rng.randf() < 0.5 else -1.0)
		c["state"] = Cray.REST
		c["timer"] = _rng.randf_range(CRAY_REST.x, CRAY_REST.y) * 0.5
		return
	c["walked"] = float(c["walked"]) + at.distance_to(next)
	c["at"] = next
	if float(c["timer"]) <= 0.0:
		c["state"] = Cray.REST
		c["timer"] = _rng.randf_range(CRAY_REST.x, CRAY_REST.y)



func _cray_frame(c: Dictionary) -> String:
	var k := posmod(roundi(float(c["angle"]) / (TAU / 8.0)), 8)
	var f := int(float(c["walked"]) / CRAY_STEP_PX) % 2
	return "crayfish_%d_%d" % [k, f]


## Tracks on the sand, then what lies on the lakebed through clean water (2026-09-30, the
## lakebed pass): every swimming or floating animal's shadow on the bed, in the bed's ink
## and thrown along the sun by the depth of the water (`Fish.shadow_drop`, one sun since
## 2026-10-02), and the legs of what floats, under the waterline. All of it only where the
## bed shows (`Fish.bed_shows`).
func _paint_under(on: CanvasItem) -> void:
	for i in _track_at.size():
		var fade := 1.0 - _track_age[i] / TRACK_LIFE
		on.draw_rect(Rect2(_track_at[i], Vector2(ART, ART)), Color(TRACK_INK, TRACK_INK.a * fade))
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM or not _wet(f["at"]):
			continue
		var frame: int = [0, 1, 2, 1][int(float(f["clock"]) * FROG_SWIM_FPS) % 4]
		var at: Vector2 = f["at"]
		_shadow_of(on, "frogswim_%d_%d" % [int(f["row"]), frame], at, 1.0, float(f["fade"]), FROG_DRAWN)
	for t: Dictionary in _turtles:
		var state := int(t["state"])
		if state == Turtle.UNDER or state == Turtle.SWIM:
			_shadow_of(on, _turtle_frame(t), t["at"], float(t["facing"]), float(t["fade"]), TURTLE_ART)
	for b: Dictionary in _broods:
		if float(b["alt"]) > 0.5:
			continue
		var kind := String(b["kind"])
		for kid: Dictionary in b["kids"]:
			_shadow_of(on, "duckling_swim0", kid["at"], float(kid.get("facing", b["facing"])), 1.0)
			_duck_legs(on, kid["at"], float(b["clock"]) + float(kid["wobble"]), true)
		_shadow_of(on, "%s_swim0" % kind, b["at"], float(b["facing"]), 1.0)
		_duck_legs(on, b["at"], float(b["clock"]), false)


## Something's own picture laid on the bed under it as a shadow, where the bed shows: thrown
## along the sun by the depth of the water (`Fish.shadow_drop`), in the bed's ink.
func _shadow_of(on: CanvasItem, name: String, at: Vector2, facing: float, fade: float, scale_by: float = 1.0) -> void:
	if not Fish.bed_shows(grid, at):
		return
	_stamp(on, name, at + Fish.shadow_drop(at, day), facing, Shade.tint_on(day, Shade.On.BED, fade), scale_by)


## Under a floating duck, two legs paddling by turns, a webbed foot on each; a duckling's
## are a pixel shorter. Mixed towards the water over them.
const DUCK_FOOT := Color(0.86, 0.52, 0.2)
const LEGS_WATER := [0.3, 0.46, 0.6]
func _duck_legs(on: CanvasItem, at: Vector2, clock: float, small: bool) -> void:
	if not Fish.bed_shows(grid, at):
		return
	var ink := Fish.under_water(at, DUCK_FOOT, LEGS_WATER[0], LEGS_WATER[1], LEGS_WATER[2])
	var dark := Fish.under_water(at, DUCK_FOOT.darkened(0.35), LEGS_WATER[0], LEGS_WATER[1], LEGS_WATER[2])
	var beat := int(clock * 3.0) % 2
	var reach := 1 if small else 2
	var base := (at / ART).floor() * ART + Vector2(0.0, ART)
	for s in [-1, 1]:
		var forward := (1 if (s > 0) == (beat == 0) else 0)
		var x := base.x + float(s) * ART * (1.0 if small else 2.0)
		for k in reach:
			on.draw_rect(Rect2(Vector2(x, base.y + float(k) * ART), Vector2(ART, ART)), dark)
		var foot := Vector2(x + float(forward * 2 - 1) * ART, base.y + float(reach) * ART)
		on.draw_rect(Rect2(foot, Vector2(ART * (1.0 if small else 2.0), ART)), ink)


## What is under the water, drawn through it: a swimming frog in its own colours, kicking,
## and a turtle that has dived, deeper and so fainter. The vertex colour is
## `Fish.through_tint`, the fish shader's packing.
func _paint_submerged(on: CanvasItem) -> void:
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM or not _wet(f["at"]):
			continue
		var at: Vector2 = f["at"]
		if not Fish.bed_shows(grid, at):
			continue
		var frame: int = [0, 1, 2, 1][int(float(f["clock"]) * FROG_SWIM_FPS) % 4]
		var colour := "green" if int(f["sheet"]) == 0 else "brown"
		var r := _region("frogdive_%s_%d_%d" % [colour, int(f["row"]), frame])
		if r.size.x <= 0.0:
			continue
		on.draw_texture_rect_region(_critters, Rect2(at - r.size * FROG_ART * 0.5, r.size * FROG_ART), r,
			Fish.through_tint(at, float(f["fade"]), 0.18, 0.36, 0.5))
	for t: Dictionary in _turtles:
		if int(t["state"]) != Turtle.UNDER:
			continue
		var at: Vector2 = t["at"]
		if not Fish.bed_shows(grid, at):
			continue
		var frame := _region(_turtle_frame(t))
		Flock.stamp(on, _critters, frame, at, float(t["facing"]), Fish.through_tint(at, float(t["fade"]), 0.32, 0.48, 0.62),
			Transform2D.IDENTITY, Vector2.ZERO, TURTLE_ART * SCALE / Flock.SCALE)


func _paint_ground(on: CanvasItem) -> void:
	# The dragonflies' shadows first, flat on whatever they fall on: the fliers are on the air
	# layer, and a shadow is never drawn there.
	for d: Dictionary in _flies:
		_draw_fly_shadow(on, d)
	var items: Array = []
	for f: Dictionary in _frogs:
		if int(f["state"]) != Frog.SWIM:
			items.append([(f["at"] as Vector2).y, 0, f])
	for t: Dictionary in _turtles:
		if int(t["state"]) != Turtle.UNDER:
			items.append([(t["at"] as Vector2).y, 1, t])
	for c: Dictionary in _critters_on_land:
		items.append([(c["at"] as Vector2).y, 4, c])
	for b: Dictionary in _broods:
		if float(b["alt"]) <= 0.5:
			items.append([(b["at"] as Vector2).y, 2, b])
		else:
			items.append([(b["at"] as Vector2).y, 3, b])
	for s: Dictionary in _birds:
		items.append([(s["at"] as Vector2).y, 6 if float(s["alt"]) > 0.5 else 5, s])
	items.sort_custom(func(a: Array, c: Array) -> bool: return float(a[0]) < float(c[0]))
	for item: Array in items:
		match int(item[1]):
			0:
				_draw_frog(on, item[2])
			1:
				_draw_turtle(on, item[2])
			2:
				_draw_brood_water(on, item[2])
			3:
				_draw_brood_shadow(on, item[2])
			4:
				_draw_land(on, item[2])
			5:
				_draw_bird_ground(on, item[2])
			6:
				_draw_bird_shadow(on, item[2])


func _paint_air(on: CanvasItem) -> void:
	for b: Dictionary in _broods:
		if float(b["alt"]) > 0.5:
			_draw_brood_air(on, b)
	for d: Dictionary in _flies:
		_draw_fly(on, d)
	for s: Dictionary in _birds:
		if float(s["alt"]) > 0.5:
			_draw_bird_air(on, s)


func _draw_frog(on: CanvasItem, f: Dictionary) -> void:
	var sheet: Texture2D = _frog_sheets[int(f["sheet"]) % _frog_sheets.size()]
	var state: int = f["state"]
	var col := 0
	var lift := 0.0
	match state:
		Frog.SIT:
			col = [0, 0, 0, 1, 2, 1][int(float(f["clock"]) * 4.0) % 6]
		Frog.CROAK:
			col = [3, 4, 5, 6, 6, 5, 4, 3][mini(int(float(f["t"]) * 8.0), 7)]
		Frog.HOP:
			var t := clampf(float(f["t"]), 0.0, 1.0)
			col = 11 + mini(int(t * 5.0), 4)
			lift = sin(t * PI) * FROG_HOP_HIGH
		Frog.JUMP:
			var t := clampf(float(f["t"]), 0.0, 1.0)
			col = 7 if t < 0.12 else (9 if t < 0.5 else (10 if t < 0.88 else 8))
			lift = sin(t * PI) * FROG_JUMP_HIGH
	var at: Vector2 = f["at"]
	var row: int = f["row"]
	var src := Rect2(float(col) * FROG_CELL, float(row) * FROG_CELL, FROG_CELL, FROG_CELL)
	# The sun's shadow: the frog's own picture laid down from its feet, sitting or in a hop.
	# In the air it is thrown from the ground under it by the hop's height, so the shadow
	# slides out along the sun as the frog rises. On a pad, or over the water, the water's
	# ink; on the sand, the land's.
	var ground := at + Shade.drop(day, lift)
	var surface := Shade.On.WATER if bool(f["on_pad"]) or _wet(ground) else Shade.On.LAND
	var sun := _sun()
	on.draw_set_transform_matrix(Shade.lying(ground.round(), sun.x, sun.y))
	on.draw_texture_rect_region(sheet, Rect2(-FROG_FOOT * FROG_ART, Vector2(FROG_CELL, FROG_CELL) * FROG_ART), src,
		Shade.tint_on(day, surface, float(f["fade"])))
	on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var box := Rect2((at - FROG_FOOT * FROG_ART - Vector2(0.0, lift)).round(), Vector2(FROG_CELL, FROG_CELL) * FROG_ART)
	on.draw_texture_rect_region(sheet, box, src, Color(1.0, 1.0, 1.0, float(f["fade"])))


func _draw_turtle(on: CanvasItem, t: Dictionary) -> void:
	var name := _turtle_frame(t)
	var r := _region(name)
	if r.size.x <= 0.0:
		return
	var at := (t["at"] as Vector2).round()
	var facing := float(t["facing"])
	var fade := float(t["fade"])
	if int(t["state"]) == Turtle.SWIM:
		# Swimming the dogs' way: cut at the waterline, bobbing, its shadow cut where it is, a
		# foam collar on the cut.
		var cut := floorf(TURTLE_INK * TURTLE_SINK)
		var shown := Rect2(r.position, Vector2(r.size.x, r.size.y - cut))
		var water := at + Vector2(0.0, roundf(sin(float(t["clock"]) * TURTLE_BOB_RATE) * TURTLE_BOB))
		var sun := _sun() * FLOAT_SHADE
		Flock.stamp(on, _critters, shown, Vector2.ZERO, facing, Shade.tint_on(day, Shade.On.WATER, fade),
			Shade.lying(water, sun.x, sun.y), Vector2.ZERO, TURTLE_ART * SCALE / Flock.SCALE)
		Flock.stamp(on, _critters, shown, water, facing, Color(1.0, 1.0, 1.0, fade),
			Transform2D.IDENTITY, Vector2.ZERO, TURTLE_ART * SCALE / Flock.SCALE)
		_collar(on, water, r.size.x * TURTLE_ART * SCALE * 0.8, float(t["clock"]), fade)
		return
	# The sun's shadow on the land from the feet (or the water's edge it stands at).
	_lay(on, name, at, facing, _surface_at(at), fade, TURTLE_ART)
	_stamp(on, name, at, facing, Color(1.0, 1.0, 1.0, fade), TURTLE_ART)


## The picture a turtle shows this instant. Idle and sit bob the head on the song's beat:
## the sheets' head is up at the start of a cycle and down half way, and one cycle is one
## beat, so the head is up on the beat (`nod_seed` puts half of them half a beat behind).
func _turtle_frame(t: Dictionary) -> String:
	var state: int = t["state"]
	match state:
		Turtle.TUCK:
			# Into the shell, held there, and back out over the timer's last stretch.
			var into := minf(float(t.get("tuck_t", 0.0)), float(t["timer"]))
			return "turtle_hide%d" % mini(int(into * TURTLE_HIDE_FPS), TURTLE_HIDE_FRAMES - 1)
		Turtle.WALK:
			return "turtle_walk%d" % (int(float(t.get("walked", 0.0)) / TURTLE_STEP_PX) % TURTLE_STEPS)
		Turtle.SWIM, Turtle.UNDER:
			return "turtle_walk%d" % (int(float(t["clock"]) * TURTLE_PADDLE_FPS) % TURTLE_STEPS)
	match String(t.get("pose", "idle")):
		"sit":
			return "turtle_sit%d" % _beat_frame(t, 7)
		"sleep":
			return "turtle_sleep%d" % (int(float(t["clock"]) * TURTLE_SLEEP_FPS) % 12)
	return "turtle_idle%d" % _beat_frame(t, 8)


## Which of `count` frames a beat-bound loop shows: one loop a beat.
func _beat_frame(t: Dictionary, count: int) -> int:
	var phase := fposmod(beat() + float(t.get("nod_seed", 0.0)), 1.0)
	return mini(int(phase * float(count)), count - 1)


func _draw_brood_water(on: CanvasItem, b: Dictionary) -> void:
	var kind := String(b["kind"])
	var clock := float(b["clock"])
	var pose := "dabble" if int(b["state"]) == Brood.DABBLE else "swim%d" % (int(clock * 1.6) % 2)
	var at: Vector2 = b["at"]
	# Every shadow of the brood on the water's surface first, so none lies over a duck: each
	# its own picture laid from the waterline, short, as what floats sits low (`FLOAT_SHADE`).
	# Their shadows on the bed are `_paint_under`'s.
	for kid: Dictionary in b["kids"]:
		var name := "duckling_swim%d" % (int(clock * 2.0 + float(kid["wobble"])) % 2)
		_lay(on, name, (kid["at"] as Vector2).round(), float(kid.get("facing", b["facing"])),
			Shade.On.WATER, 1.0, 1.0, FLOAT_SHADE)
	_lay(on, "%s_%s" % [kind, pose], at.round(), float(b["facing"]), Shade.On.WATER, 1.0, 1.0, FLOAT_SHADE)
	for kid: Dictionary in b["kids"]:
		var kat: Vector2 = kid["at"]
		var name := "duckling_swim%d" % (int(clock * 2.0 + float(kid["wobble"])) % 2)
		_stamp(on, name, kat.round(), float(kid.get("facing", b["facing"])))
		_collar(on, kat, 9.0, clock + float(kid["wobble"]), 1.0)
	_stamp(on, "%s_%s" % [kind, pose], at.round(), float(b["facing"]))
	_collar(on, at, 20.0, clock, 1.0)


## A flying brood's shadows, the ducklings' with the leader's: each its own silhouette laid
## down by the sun, thrown from the ground point under it by the height it flies at
## (`Shade.drop`), in the ink of whatever it lands on — the water's, or the land's while the
## brood is still coming in over the bank. Drawn on this layer, the surface's, never on the
## air's. Shrunk and thinned with the height (`SHADE_SHRINK`, `SHADE_THIN`).
func _draw_brood_shadow(on: CanvasItem, b: Dictionary) -> void:
	var alt := float(b["alt"])
	var up := clampf(alt / DUCK_ALT, 0.0, 1.0)
	var fade := 1.0 - SHADE_THIN * up
	var shrink := 1.0 - SHADE_SHRINK * up
	var lift := Shade.drop(day, alt)
	var clock := float(b["clock"])
	for kid: Dictionary in b["kids"]:
		var kat: Vector2 = (kid["at"] as Vector2) + lift
		var name := "duckling_fly%d" % (int(clock * 14.0 + float(kid["wobble"])) % 2)
		_lay(on, name, kat, float(kid.get("facing", b["facing"])), _surface_at(kat), fade, shrink)
	var at: Vector2 = (b["at"] as Vector2) + lift
	_lay(on, "%s_%s" % [String(b["kind"]), _fly_pose(b)], at, float(b["facing"]), _surface_at(at), fade, shrink)


func _fly_pose(b: Dictionary) -> String:
	return ["fly0", "fly1", "fly2", "fly1"][int(float(b["clock"]) * 10.0) % 4]


func _draw_brood_air(on: CanvasItem, b: Dictionary) -> void:
	var lift := Vector2(0.0, -float(b["alt"]))
	var clock := float(b["clock"])
	for kid: Dictionary in b["kids"]:
		var name := "duckling_fly%d" % (int(clock * 14.0 + float(kid["wobble"])) % 2)
		_stamp(on, name, ((kid["at"] as Vector2) + lift).round(), float(kid.get("facing", b["facing"])))
	_stamp(on, "%s_%s" % [String(b["kind"]), _fly_pose(b)], ((b["at"] as Vector2) + lift).round(), float(b["facing"]))


## Whole foam pixels along the waterline either side of a floating animal, torn by time.
func _collar(on: CanvasItem, at: Vector2, wide: float, clock: float, fade: float) -> void:
	var beat := int(clock * 2.0)
	var y: float = floor(at.y / ART) * ART
	var x0: float = floor((at.x - wide * 0.5) / ART) * ART
	var n := int(wide / ART)
	for i in n:
		var h := fmod(sin(float(i) * 12.9898 + float(beat) * 78.233) * 43758.5453, 1.0)
		if absf(h) < 0.45:
			continue
		on.draw_rect(Rect2(x0 + float(i) * ART, y - ART * 0.5, ART, ART), Color(FOAM, FOAM.a * fade))


## A dragonfly's shadow, one art pixel: thrown from the ground point under it by the height
## it hovers at (`Shade.drop`), snapped to the art grid, in the ink of what it falls on.
## Drawn by the ground layer (`_paint_ground`), never the air's.
func _draw_fly_shadow(on: CanvasItem, d: Dictionary) -> void:
	var ground := ((d["at"] as Vector2) / ART).floor() * ART
	var at := (ground + Shade.drop(day, float(d["alt"]))).snapped(Vector2(ART, ART))
	on.draw_rect(Rect2(at, Vector2(ART, ART)), Shade.tint_on(day, _surface_at(at), float(d["fade"])))


## A dragonfly on whole art pixels: head, thorax and a long abdomen along its heading
## (snapped to eighths), two pairs of wings flicking. Its shadow is `_draw_fly_shadow`.
func _draw_fly(on: CanvasItem, d: Dictionary) -> void:
	var fade := float(d["fade"])
	var ground := ((d["at"] as Vector2) / ART).floor() * ART
	var at := ground + Vector2(0.0, -float(d["alt"])).snapped(Vector2(ART, ART)) + (d["jit"] as Vector2)
	var h: Vector2 = d["heading"]
	var k := posmod(roundi(atan2(h.y, h.x) / (PI / 4.0)), 8)
	var dir := Vector2(roundf(cos(float(k) * PI / 4.0)), roundf(sin(float(k) * PI / 4.0)))
	var side := Vector2(-dir.y, dir.x)
	var body: Color = FLY_BODIES[int(d["body"])]
	body.a = fade
	var dark := body.darkened(0.45)
	var wing := Color(FLY_WING, FLY_WING.a * fade)
	var beat := int(_now * 22.0) % 2 == 0
	var wing_at := at - dir * ART if beat else at - dir * ART * 2.0
	for s in [1.0, -1.0]:
		on.draw_rect(Rect2(wing_at + side * ART * s, Vector2(ART, ART)), wing)
		on.draw_rect(Rect2(wing_at + side * ART * 2.0 * s, Vector2(ART, ART)), wing)
		on.draw_rect(Rect2(wing_at + (side * ART * s) - dir * ART, Vector2(ART, ART)), wing)
	on.draw_rect(Rect2(at + dir * ART, Vector2(ART, ART)), dark)
	on.draw_rect(Rect2(at, Vector2(ART, ART)), body)
	for i in range(1, 5):
		on.draw_rect(Rect2(at - dir * ART * float(i), Vector2(ART, ART)), body if i < 4 else dark)

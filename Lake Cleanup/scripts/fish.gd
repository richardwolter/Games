class_name Fish
extends Node2D
## The fish that come back to clean water, seen through it with their shadows on the lakebed
## below, and the rings they leave on the surface. Purely ambient, by decision (2026-09-16): nothing catches them,
## nothing pays for them, nothing aims at them. They live in water the filth map calls
## clean — the honest map, never the transient patch a catch opens — and come in tiers as
## the whole lake clears: minnows first, then perch-sized schools, then one big carp.
##
## Drawn between the water (z 2) and the splash layer (4) so the rings the splash layer
## draws lie over the fish, as a ring on the surface lies over a fish under it.
##
## **Seen fish since 2026-09-30** (the lakebed pass, picked off tools/lakebed_mockup.py): they
## were fish-shaped shadows and nothing else. Now each is a lit body in one of six species
## (tools/build_fish.py, assets/fish.png: sixteen headings, three tail beats), mixed towards
## the water's colour by depth (shaders/fish.gdshader), with its flat shadow on the bed
## further down the screen the deeper the water. One species a school; the tier says which
## species it may be. Sizes are the sheet's own, at `ART` world px an art pixel.

## Clean share at which each tier appears, and what a school of it is.
##
## About a third more schools in every tier since 2026-09-18 (Richard: "increase fish
## population by a little"): `most` 14/7/2 to 18/9/3 and `per_tiles` 70/160/700 to
## 55/125/550. Half as many again on 2026-09-25 (Richard: "more prominent"): 27/14/5 and
## 36/83/360. When each tier arrives, and what a school is, are as they were.
const TIERS := [
	{"at": 0.12, "size": Vector2(20.0, 7.0), "members": Vector2i(3, 6), "speed": 26.0,
		"per_tiles": 36.0, "most": 27, "ripple": 2.6, "span": 6.0, "species": ["minnow"]},
	{"at": 0.38, "size": Vector2(28.0, 10.0), "members": Vector2i(3, 5), "speed": 34.0,
		"per_tiles": 83.0, "most": 14, "ripple": 1.8, "span": 12.0, "species": ["roach", "perch", "rudd"]},
	{"at": 0.68, "size": Vector2(42.0, 14.0), "members": Vector2i(1, 1), "speed": 22.0,
		"per_tiles": 360.0, "most": 5, "ripple": 1.2, "span": 26.0, "species": ["tench", "carp"]},
]
const SHEET := "res://assets/fish.png"
const SHEET_JSON := "res://assets/fish.json"
## World px to an art pixel of the sheet, the rubbish's own.
const ART := 2.0
## Tail beats a second, and how much faster fleeing.
const BEAT := 3.2
const BEAT_FLEE := 2.5
## The water's share over a fish, shallow to the last depth band, and past it; the depth the
## bands end at (the shader's `bed_bands.z`) and how many steps it takes. Fish swim over the
## bed, so less water lies between them and the eye than between the bed and the eye.
const MIX_SHALLOW := 0.12
const MIX_BAND_END := 0.36
const MIX_DEEP := 0.5
const BAND_END := 0.85
const LEVELS := 5
## The shadow on the bed: how dark, and how far it falls, in world px, from the fish, at the
## shallows and at the deepest water.
const SHADOW_INK := 0.3
const SHADOW_NEAR := Vector2(6.0, 16.0)
const SHADOW_FAR := Vector2(18.0, 40.0)

## Seconds between reconciling what should be swimming with what is.
const RECKON_EVERY := 2.0
## How far ahead a school looks before turning, in tiles, and how hard it turns per second.
const LOOK_AHEAD := 1.6
const TURN := 2.4
## A hull, a net landing or a splash within this many tiles sends a school away.
const FLEE_TILES := 3.0
const FLEE_SPEED := 3.0
const FLEE_TIME := 1.6
## The spread of a school round its leader, in world px, per unit of its shadow's length.
const SPREAD := 1.6
## A school that has left the clean water fades out and is replaced.
const FADE := 0.8

var grid: LakeGrid
var splash: WaterSplash
var boats: Array[Boat] = []
var stage: float = 0.0

## One dictionary a school: tier, at (world), heading (unit, world), members (offsets),
## wobble seeds, ripple clock, fade 0..1, flee timer.
var _schools: Array = []
var _clean_tiles := PackedInt32Array()
var _reckon_in: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sheet: Texture2D
var _cell := Vector2(48, 40)
var _headings := 16
var _species: Array = []
var _rows_per := 4
var _bodies: Node2D
## The water's ramp over a fish: deep to light, the palette's clean swatches.
var _water: Array[Color] = [Color(0.173, 0.302, 0.431), Color(0.255, 0.42, 0.573),
	Color(0.353, 0.525, 0.678), Color(0.498, 0.655, 0.776), Color(0.769, 0.859, 0.91)]


func _ready() -> void:
	z_index = 3
	z_as_relative = false
	_rng.seed = 20260916
	# Pixel art drawn at two world px an art pixel: nearest, or the shadows go soft.
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(SHEET) and FileAccess.file_exists(SHEET_JSON):
		var spec: Variant = JSON.parse_string(FileAccess.get_file_as_string(SHEET_JSON))
		if spec is Dictionary:
			_sheet = load(SHEET)
			_cell = Vector2(spec["cell"][0], spec["cell"][1])
			_headings = int(spec["headings"])
			_species = spec["species"]
			_rows_per = int(spec["rows_per_species"])
	var palette := Palette.master()
	if palette != null:
		_water = [palette.water_clean_deep, palette.water_clean_mid, palette.water_clean,
			palette.water_clean_shallow, palette.water_clean_light]
	# The bodies over the shadows, on a child with the fish shader: the shadows are this
	# node's own drawing, so they sit under every fish of every school.
	_bodies = Node2D.new()
	_bodies.name = &"Bodies"
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/fish.gdshader")
	_bodies.material = material
	_bodies.draw.connect(_draw_bodies)
	add_child(_bodies)


func school_count() -> int:
	return _schools.size()


func schools() -> Array:
	return _schools


## The lake's clean water changed: `clean` is every water tile index the map calls clean.
func refresh(clean_share: float, clean: PackedInt32Array) -> void:
	stage = clean_share
	_clean_tiles = clean
	_reckon_in = 0.0


## Something hit the water at `at` (world): every school within reach turns and runs.
func scare(at: Vector2, reach_tiles: float = FLEE_TILES) -> void:
	var reach := Iso.tile_circle_extent(reach_tiles)
	for s: Dictionary in _schools:
		var off: Vector2 = (s["at"] as Vector2) - at
		if off.length() > reach:
			continue
		s["heading"] = _flat(off).normalized() if off.length() > 0.5 else Vector2.RIGHT
		s["flee"] = FLEE_TIME


func _process(delta: float) -> void:
	_reckon_in -= delta
	if _reckon_in <= 0.0:
		_reckon_in = RECKON_EVERY
		_reckon()
	if _schools.is_empty():
		return
	for boat in boats:
		if not is_instance_valid(boat):
			continue
		scare(boat.position, FLEE_TILES * 0.8)
	var gone: Array = []
	for s: Dictionary in _schools:
		_swim(s, delta)
		if float(s["fade"]) <= 0.0:
			gone.append(s)
	for s in gone:
		_schools.erase(s)
	queue_redraw()
	_bodies.queue_redraw()


## Bring the schools up to what the stage buys, and no further.
func _reckon() -> void:
	if grid == null:
		return
	var by_tier := [0, 0, 0]
	for s: Dictionary in _schools:
		by_tier[int(s["tier"])] += 1
	for tier in TIERS.size():
		var spec: Dictionary = TIERS[tier]
		if stage < float(spec["at"]):
			continue
		var want := mini(int(float(_clean_tiles.size()) / float(spec["per_tiles"])), int(spec["most"]))
		var have: int = by_tier[tier]
		if have >= want:
			continue
		for n in want - have:
			var s := _spawn(tier)
			if not s.is_empty():
				_schools.append(s)


func _spawn(tier: int) -> Dictionary:
	if _clean_tiles.is_empty():
		return {}
	var spec: Dictionary = TIERS[tier]
	for attempt in 12:
		var index := _clean_tiles[_rng.randi_range(0, _clean_tiles.size() - 1)]
		var tile := grid.tile_of(index)
		var at := Vector2(float(tile.x) + 0.5, float(tile.y) + 0.5)
		if not _swimmable(at):
			continue
		var count := _rng.randi_range(spec["members"].x, spec["members"].y)
		var members := PackedVector2Array()
		var reach := float(spec["size"].x) * SPREAD
		for i in count:
			members.append(Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.5))
		var angle := _rng.randf_range(0.0, TAU)
		var kinds: Array = spec["species"]
		return {
			"tier": tier, "at": Iso.tile_to_world(at.x, at.y),
			"species": kinds[_rng.randi_range(0, kinds.size() - 1)],
			"heading": Vector2(cos(angle), sin(angle) * 0.5).normalized(),
			"members": members, "seed": _rng.randf() * 100.0, "ripple": _rng.randf() * 2.0,
			"fade": 0.0, "flee": 0.0, "rising": true,
		}
	return {}


## Water a fish may be in: the lake, clean on the map, off both shores.
func _swimmable(at: Vector2) -> bool:
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if not Iso.in_lake(tile.x, tile.y):
		return false
	if Iso.island_fraction(at.x, at.y) < 1.0 + Iso.SHELF_CLEAR + 0.4:
		return false
	if Iso.shore_fraction(at.x, at.y) > 0.93:
		return false
	return grid.water_state(grid.index_of(tile.x, tile.y)) == 0


func _swim(s: Dictionary, delta: float) -> void:
	var spec: Dictionary = TIERS[int(s["tier"])]
	var speed := float(spec["speed"])
	var flee := float(s["flee"])
	if flee > 0.0:
		s["flee"] = flee - delta
		speed *= FLEE_SPEED
	var at: Vector2 = s["at"]
	var heading: Vector2 = s["heading"]
	# A slow wander in the heading, so a school meanders rather than running a line.
	var t := float(Time.get_ticks_msec()) * 0.001 + float(s["seed"])
	var wander := sin(t * 0.7) * 0.6 + sin(t * 1.9) * 0.3
	heading = _turn(heading, wander * TURN * 0.4 * delta)
	# Look ahead; if that is not clean water, turn until it is.
	var ahead_tile := Iso.world_to_tile(at + heading * Iso.tile_circle_extent(LOOK_AHEAD))
	if not _swimmable(ahead_tile):
		var turned := false
		for k in range(1, 7):
			for sign in [1.0, -1.0]:
				var try := _turn(heading, sign * 0.5 * float(k))
				if _swimmable(Iso.world_to_tile(at + try * Iso.tile_circle_extent(LOOK_AHEAD))):
					heading = _turn(heading, sign * TURN * delta * 3.0)
					turned = true
					break
			if turned:
				break
		if not turned:
			s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
			s["rising"] = false
	s["heading"] = heading
	at += heading * speed * delta
	s["at"] = at
	# Where the school is now: still clean? Otherwise fade away, and something new will come.
	if not _swimmable(Iso.world_to_tile(at)):
		s["rising"] = false
		s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
	elif bool(s["rising"]):
		s["fade"] = minf(float(s["fade"]) + delta / FADE, 1.0)
	# The rings: one from the leader every so often, more often while fleeing.
	var clock := float(s["ripple"]) - delta * (3.0 if flee > 0.0 else 1.0)
	if clock <= 0.0:
		clock = float(spec["ripple"]) * _rng.randf_range(0.7, 1.3)
		if splash != null and float(s["fade"]) > 0.3:
			var m: PackedVector2Array = s["members"]
			var who := m[_rng.randi_range(0, m.size() - 1)] if not m.is_empty() else Vector2.ZERO
			# Half the splash layer's rings at most, the wildlife's rule: with the schools
			# raised (2026-09-25) they filled it and a walker's entry ring was refused.
			var rings: PackedFloat32Array = splash.get(&"_ripple_age")
			if rings.size() < WaterSplash.MAX_RIPPLES / 2:
				splash.ripple(at + who, float(spec["span"]))
	s["ripple"] = clock


## Turn a heading on the plane (the 2:1 squash taken out and put back).
static func _turn(heading: Vector2, by: float) -> Vector2:
	var flat := Vector2(heading.x, heading.y * 2.0).rotated(by)
	return Vector2(flat.x, flat.y * 0.5).normalized()


static func _flat(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y)


## Every fish, as (school, member index, where) in draw order: back to front.
func _fish_spots() -> Array:
	var out: Array = []
	var t := float(Time.get_ticks_msec()) * 0.001
	for s: Dictionary in _schools:
		var m: PackedVector2Array = s["members"]
		for i in m.size():
			var ts := t + float(s["seed"])
			var spot: Vector2 = (s["at"] as Vector2) + m[i] \
				+ Vector2(sin(ts * 1.3 + float(i)), cos(ts * 1.1 + float(i) * 0.7) * 0.5) * 3.0
			out.append([s, i, spot])
	out.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector2).y < (b[2] as Vector2).y)
	return out


## The shadows, on the bed under each fish.
func _draw() -> void:
	if _sheet == null:
		return
	for f: Array in _fish_spots():
		var s: Dictionary = f[0]
		var spot: Vector2 = f[2]
		var d := depth_at(spot)
		var drop := SHADOW_NEAR.lerp(SHADOW_FAR, d)
		var region := _region(String(s["species"]), _heading_index(s, int(f[1])), _rows_per - 1)
		draw_texture_rect_region(_sheet, Rect2(spot + drop - _cell * ART * 0.5, _cell * ART), region,
			Color(0.02, 0.06, 0.08, SHADOW_INK * float(s["fade"])))


## The bodies, on the child with the fish shader. The vertex colour carries the water's
## colour over the fish and, packed in its alpha, the water's share and how far in it has faded.
func _draw_bodies() -> void:
	if _sheet == null:
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	for f: Array in _fish_spots():
		var s: Dictionary = f[0]
		var i: int = f[1]
		var spot: Vector2 = f[2]
		var beat := BEAT * (BEAT_FLEE if float(s["flee"]) > 0.0 else 1.0)
		var wag: int = [0, 1, 2, 1][posmod(int(floor(t * beat * 2.0 + float(s["seed"]) + float(i) * 0.61)), 4)]
		var region := _region(String(s["species"]), _heading_index(s, i), wag)
		var d := depth_at(spot)
		var q := floorf(clampf(d / BAND_END, 0.0, 0.999) * float(LEVELS)) / float(LEVELS - 1)
		var share := MIX_DEEP if d >= BAND_END else lerpf(MIX_SHALLOW, MIX_BAND_END, q)
		var water: Color = _water[clampi(int(roundf(3.0 - 2.0 * q)), 0, 4)] if d < BAND_END else _water[1]
		var packed := int(roundf(share * 15.0)) * 16 + int(roundf(clampf(float(s["fade"]), 0.0, 1.0) * 15.0))
		water.a = float(packed) / 255.0
		_bodies.draw_texture_rect_region(_sheet, Rect2(spot - _cell * ART * 0.5, _cell * ART), region, water)


## Which of the sheet's sixteen headings a member faces: the school's, swung a little by its
## wander, on the plane.
func _heading_index(s: Dictionary, i: int) -> int:
	var heading: Vector2 = s["heading"]
	var t := float(Time.get_ticks_msec()) * 0.001 + float(s["seed"])
	var angle := atan2(heading.y * 2.0, heading.x) + sin(t * 6.0 + float(i) * 1.7) * 0.12
	return posmod(int(roundf(angle / TAU * float(_headings))), _headings)


func _region(species: String, heading: int, row: int) -> Rect2:
	var si := maxi(_species.find(species), 0)
	return Rect2(Vector2(heading, si * _rows_per + row) * _cell, _cell)


## The water shader's depth: 0 at the bank, 1 over the deepest water, shoaling up to the
## island. The shader folds `shore_lap` into the radius; this does not, which is a few
## hundredths of depth at the bank and nothing a fish shows.
static func depth_at(world: Vector2) -> float:
	var tile := Iso.world_to_tile(world)
	var s := clampf(Iso.shore_fraction(tile.x, tile.y), 0.0, 1.0)
	return sqrt(maxf(1.0 - s, 0.0)) * smoothstep(1.0, 2.6, Iso.island_fraction(tile.x, tile.y))

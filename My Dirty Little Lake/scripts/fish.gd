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
## thrown along the sun, further the deeper the water (one sun, 2026-10-02: see
## `shadow_drop`). One species a school; the tier says which species it may be. Sizes are
## the sheet's own, at `ART` world px an art pixel.

## What each tier is, and how it comes in as the lake clears.
##
## About a third more schools in every tier since 2026-09-18 (Richard: "increase fish
## population by a little"): `most` 14/7/2 to 18/9/3 and `per_tiles` 70/160/700 to
## 55/125/550. Half as many again on 2026-09-25 (Richard: "more prominent"): 27/14/5 and
## 36/83/360.
##
## **Progressive since 2026-10-19** (Richard: "Fish are appearing too sudden, lets make it more
## progressive, with small schools then growing in population and size as the lake cleans
## up"). A tier used to switch on at its share and buy every school its clean water allowed on
## the next reckon: nineteen schools of minnows came in on one frame at 17% clean, fourteen
## perch-sized at 38%, five carp at 68%. Now each tier has a ramp, from its first school at
## `at` to its whole `most` at `full`, eased in (`smoothstep`, rounded up, so the first school
## comes as soon as the ramp opens and the next few come slowly), and the ramp also moves the
## school's size from `members_from` to `members_to`: the first minnows are a pair or three,
## and a school already swimming grows a fish at a time as the lake clears (`_grow_one`). The
## larger tiers' ramps start later and overlap, so the bigger fish come in one school at a
## time over the middle and the end of the run. `at` is still where a tier's first fish may
## come. The end of the run is what it was: 27/14/5 schools of 3-6/3-5/1.
const TIERS := [
	{"at": 0.08, "full": 0.6, "size": Vector2(20.0, 7.0),
		"members_from": Vector2i(2, 3), "members_to": Vector2i(3, 6), "speed": 26.0,
		"per_tiles": 36.0, "most": 27, "ripple": 2.6, "span": 6.0, "species": ["minnow"]},
	{"at": 0.3, "full": 0.85, "size": Vector2(28.0, 10.0),
		"members_from": Vector2i(2, 3), "members_to": Vector2i(3, 5), "speed": 34.0,
		"per_tiles": 83.0, "most": 14, "ripple": 1.8, "span": 12.0, "species": ["roach", "perch", "rudd"]},
	{"at": 0.55, "full": 0.95, "size": Vector2(42.0, 14.0),
		"members_from": Vector2i(1, 1), "members_to": Vector2i(1, 1), "speed": 22.0,
		"per_tiles": 360.0, "most": 5, "ripple": 1.2, "span": 26.0, "species": ["tench", "carp"]},
]
## How the schools come in: at most one new school every `ARRIVE_GAP` seconds (rolled between
## the two, so arrivals have no beat), whatever the share did, the tier furthest behind what
## its ramp asks for first. A school that could not find clean water to start in is tried again
## `ARRIVE_RETRY` later. Loading a run (`refresh`'s `settled`) still puts them all in at once.
const ARRIVE_GAP := Vector2(2.5, 4.5)
const ARRIVE_RETRY := 0.5
## And how a school grows: one fish added to one school short of its size every `GROW_GAP`
## seconds, fading in over `MEMBER_FADE` a whole art pixel at a time as a school does
## (`shaders/fish.gdshader` dissolves on the packed fade).
const GROW_GAP := Vector2(1.2, 2.4)
const MEMBER_FADE := 1.6
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
## More water over the fish than over the rest of the life seen through it (2026-10-01,
## Richard: they should read as under the water, not on it).
const DEEPER := 0.15
const BAND_END := 0.85
const LEVELS := 5
## The shadow on the bed (one sun, 2026-10-02, `/grill-me` with Richard): `Shade`'s ink for
## the bed (`Shade.On.BED`), thrown along the sun the way the angler's is, as though the fish
## stood this many world px over the bed — `SHADOW_DEPTH_NEAR` in the shallows to
## `SHADOW_DEPTH_FAR` over the deepest water. So it falls the same way as every other shadow
## in the lake, lengthens late in the day and greys with the weather. The two depths put it
## where the old drop fell (16 and 40 px down the screen) in the middle of the day's swing.
## Retired: `SHADOW_NEAR`/`SHADOW_FAR`, a fixed drop straight down the screen whatever the
## hour, and the shadow's own colour and alpha.
const SHADOW_DEPTH_NEAR := 40.0
const SHADOW_DEPTH_FAR := 100.0

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
## A school that has left the clean water fades out and is replaced, but only off the screen
## (2026-10-06, Richard: wildlife must not disappear where the player can see): on it, a
## school boxed in by foul water slows and turns, and one whose water turned under it swims
## on at full strength (`_in_view`, `Wildlife.VIEW_MARGIN`).
const FADE := 0.8
const BOXED_SLOW := 0.2

var grid: LakeGrid
var splash: WaterSplash
var boats: Array[Boat] = []
var stage: float = 0.0

## One dictionary a school: tier, at (world), heading (unit, world), members (offsets),
## member_fade (each member's own 0..1, for the ones that join it later), size_roll (where in
## its tier's range of sizes this school sits), wobble seeds, ripple clock, fade 0..1, flee timer.
var _schools: Array = []
var _clean_tiles := PackedInt32Array()
var _reckon_in: float = 0.0
## What the stage asks of each tier, worked out by `_reckon`: schools wanted, and how far along
## its ramp the tier is (0..1), which sets how big its schools are.
var _want := [0, 0, 0]
var _ramp := [0.0, 0.0, 0.0]
var _arrive_in: float = 0.0
var _grow_in: float = 0.0
var _rng := RandomNumberGenerator.new()
var _sheet: Texture2D
var _cell := Vector2(48, 40)
var _headings := 16
var _species: Array = []
var _rows_per := 4
var _bodies: Node2D
## Every fish this frame, worked out once in `_process` and drawn twice (shadows, bodies):
## [school, member, spot, shadow drop, body tint, fade]. It was worked out in each draw, with the
## lake's depth asked three times a fish (2026-10-02, the clean-lake bench).
var _spots: Array = []
## The water's ramp over anything under it: deep to light, the palette's clean swatches.
## Static, because the wildlife and the flora ask it too (see `through_tint`).
static var _water: Array[Color] = []


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
## `settled` (a run just loaded, 2026-10-13): the schools the stage buys are put in at once,
## already faded in.
func refresh(clean_share: float, clean: PackedInt32Array, settled: bool = false) -> void:
	stage = clean_share
	_clean_tiles = clean
	_reckon_in = 0.0
	if settled:
		_reckon()
		_reckon_in = RECKON_EVERY
		_fill_all()
		for s: Dictionary in _schools:
			s["fade"] = 1.0
			var each: PackedFloat32Array = s.get("member_fade", PackedFloat32Array())
			each.fill(1.0)
			s["member_fade"] = each
		_spots = _fish_spots()
		queue_redraw()


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
	_arrive_in -= delta
	if _arrive_in <= 0.0:
		_arrive_in = _rng.randf_range(ARRIVE_GAP.x, ARRIVE_GAP.y) if _arrive_one() else ARRIVE_RETRY
	_grow_in -= delta
	if _grow_in <= 0.0:
		_grow_in = _rng.randf_range(GROW_GAP.x, GROW_GAP.y) if _grow_one() else ARRIVE_RETRY
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
	_spots = _fish_spots()
	queue_redraw()
	_bodies.queue_redraw()


## What the stage buys of each tier: how far along its ramp it is, and the schools that
## buys, never more than its clean water has room for (`per_tiles`). Only works it out; the
## schools come in one at a time (`_arrive_one`) and grow one fish at a time (`_grow_one`).
func _reckon() -> void:
	for tier in TIERS.size():
		var spec: Dictionary = TIERS[tier]
		var ramp := ramp_of(tier, stage)
		_ramp[tier] = ramp
		if ramp <= 0.0:
			_want[tier] = 0
			continue
		# Rounded up, so the first school comes as soon as the ramp has opened at all.
		var by_ramp := ceili(float(spec["most"]) * ramp)
		_want[tier] = mini(by_ramp, int(float(_clean_tiles.size()) / float(spec["per_tiles"])))


## How far along its ramp a tier is at clean share `share`: nought before `at`, one from
## `full`, eased between.
static func ramp_of(tier: int, share: float) -> float:
	var spec: Dictionary = TIERS[tier]
	if share < float(spec["at"]):
		return 0.0
	return smoothstep(float(spec["at"]), float(spec["full"]), share)


## How many fish a school of `tier` is at this point of its ramp, for a school whose
## `size_roll` (0..1) says where in the tier's range it sits.
func _size_of(tier: int, roll: float) -> int:
	var spec: Dictionary = TIERS[tier]
	var from: Vector2i = spec["members_from"]
	var to: Vector2i = spec["members_to"]
	var ramp: float = _ramp[tier]
	var least := lerpf(float(from.x), float(to.x), ramp)
	var most := lerpf(float(from.y), float(to.y), ramp)
	return maxi(int(roundf(lerpf(least, most, roll))), 1)


## Schools of each tier swimming now.
func _have() -> Array:
	var by_tier := [0, 0, 0]
	for s: Dictionary in _schools:
		by_tier[int(s["tier"])] += 1
	return by_tier


## One new school, for the tier furthest behind what its ramp asks (by share of what it asks,
## so a tier that has only just opened is not starved by one with many owed). False when
## nothing is owed or no clean water would take one this time.
func _arrive_one() -> bool:
	if grid == null:
		return false
	var have := _have()
	var pick := -1
	var behind := 0.0
	for tier in TIERS.size():
		var want: int = _want[tier]
		if want <= int(have[tier]):
			continue
		var short := float(want - int(have[tier])) / float(want)
		if short > behind:
			behind = short
			pick = tier
	if pick < 0:
		return false
	var s := _spawn(pick)
	if s.is_empty():
		return false
	_schools.append(s)
	return true


## Every school the stage buys, all at once and at its full size: a run just loaded is not
## the lake clearing, it is the lake as it stands.
func _fill_all() -> void:
	if grid == null:
		return
	var have := _have()
	for tier in TIERS.size():
		for n in maxi(int(_want[tier]) - int(have[tier]), 0):
			var s := _spawn(tier)
			if not s.is_empty():
				_schools.append(s)
	for s: Dictionary in _schools:
		while _add_member(s):
			pass


## One fish joins one school that is short of its size, the one furthest behind first. The
## school must be in sight of its water (fading in or swimming whole), not on its way out.
func _grow_one() -> bool:
	var pick: Dictionary = {}
	var behind := 0
	for s: Dictionary in _schools:
		# A school put in by hand (a probe's) has no size of its own to grow to.
		if not bool(s["rising"]) or not s.has("size_roll"):
			continue
		var short := _size_of(int(s["tier"]), float(s["size_roll"])) - (s["members"] as PackedVector2Array).size()
		if short > behind:
			behind = short
			pick = s
	if pick.is_empty():
		return false
	return _add_member(pick)


## A fish more in `s`, if it is short of its size: somewhere in the school's spread, faded
## out, to fade in on its own (`MEMBER_FADE`).
func _add_member(s: Dictionary) -> bool:
	var tier := int(s["tier"])
	var members: PackedVector2Array = s["members"]
	if not s.has("size_roll") or members.size() >= _size_of(tier, float(s["size_roll"])):
		return false
	var reach := float(TIERS[tier]["size"].x) * SPREAD
	members.append(Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.5))
	var each: PackedFloat32Array = s.get("member_fade", PackedFloat32Array())
	while each.size() < members.size() - 1:
		each.append(1.0)
	each.append(0.0)
	s["members"] = members
	s["member_fade"] = each
	return true


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
		# A new school comes in at the size its tier's ramp has reached; the whole of it fades
		# in with the school, so each member's own fade starts full.
		var roll := _rng.randf()
		var count := _size_of(tier, roll)
		var members := PackedVector2Array()
		var each := PackedFloat32Array()
		var reach := float(spec["size"].x) * SPREAD
		for i in count:
			members.append(Vector2(_rng.randf_range(-reach, reach), _rng.randf_range(-reach, reach) * 0.5))
			each.append(1.0)
		var angle := _rng.randf_range(0.0, TAU)
		var kinds: Array = spec["species"]
		return {
			"tier": tier, "at": Iso.tile_to_world(at.x, at.y),
			"species": kinds[_rng.randi_range(0, kinds.size() - 1)],
			"heading": Vector2(cos(angle), sin(angle) * 0.5).normalized(),
			"members": members, "member_fade": each, "size_roll": roll,
			"seed": _rng.randf() * 100.0, "ripple": _rng.randf() * 2.0,
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
			s["rising"] = false
			if _in_view(at):
				heading = _turn(heading, TURN * delta * 3.0)
				speed *= BOXED_SLOW
			else:
				s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
	s["heading"] = heading
	at += heading * speed * delta
	s["at"] = at
	# Where the school is now: still clean? Otherwise fade away, and something new will come.
	if not _swimmable(Iso.world_to_tile(at)):
		s["rising"] = false
		if not _in_view(at):
			s["fade"] = maxf(float(s["fade"]) - delta / FADE, 0.0)
	elif bool(s["rising"]):
		s["fade"] = minf(float(s["fade"]) + delta / FADE, 1.0)
	# A fish that joined the school later fades in on its own, whatever the school is doing:
	# it is drawn at the school's fade times its own, so it never shows more than the school.
	if s.has("member_fade"):
		var each: PackedFloat32Array = s["member_fade"]
		for i in each.size():
			if each[i] < 1.0:
				each[i] = minf(each[i] + delta / MEMBER_FADE, 1.0)
		s["member_fade"] = each
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


## Is a world point on the screen, or near enough to it that a fish there could be seen.
func _in_view(at: Vector2) -> bool:
	if not is_inside_tree():
		return false
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	return view.grow(Wildlife.VIEW_MARGIN).has_point(at)


## Turn a heading on the plane (the 2:1 squash taken out and put back).
static func _turn(heading: Vector2, by: float) -> Vector2:
	var flat := Vector2(heading.x, heading.y * 2.0).rotated(by)
	return Vector2(flat.x, flat.y * 0.5).normalized()


static func _flat(v: Vector2) -> Vector2:
	return Vector2(v.x, v.y)


## Every fish, as (school, member index, where, shadow drop, body tint, fade) in draw order: back
## to front. The depth under each is asked once, for both the drop and the tint.
func _fish_spots() -> Array:
	var out: Array = []
	var t := float(Time.get_ticks_msec()) * 0.001
	# The sun's drop for one world px of water, asked once a frame rather than once a fish.
	var sun := Shade.drop(null, 1.0)
	for s: Dictionary in _schools:
		var m: PackedVector2Array = s["members"]
		var each: PackedFloat32Array = s.get("member_fade", PackedFloat32Array())
		for i in m.size():
			var fade := float(s["fade"]) * (each[i] if i < each.size() else 1.0)
			var ts := t + float(s["seed"])
			var spot: Vector2 = (s["at"] as Vector2) + m[i] \
				+ Vector2(sin(ts * 1.3 + float(i)), cos(ts * 1.1 + float(i) * 0.7) * 0.5) * 3.0
			var d := depth_at(spot)
			out.append([s, i, spot, sun * lerpf(SHADOW_DEPTH_NEAR, SHADOW_DEPTH_FAR, d),
				_tint_at(d, fade, MIX_SHALLOW + DEEPER, MIX_BAND_END + DEEPER, MIX_DEEP + DEEPER), fade])
	out.sort_custom(func(a: Array, b: Array) -> bool: return (a[2] as Vector2).y < (b[2] as Vector2).y)
	return out


## The shadows, on the bed under each fish, in the bed's ink (`Shade.On.BED`).
func _draw() -> void:
	if _sheet == null:
		return
	var ink := Shade.tint_on(null, Shade.On.BED)
	for f: Array in _spots:
		var s: Dictionary = f[0]
		var spot: Vector2 = f[2]
		var drop: Vector2 = f[3]
		var region := _region(String(s["species"]), _heading_index(s, int(f[1])), _rows_per - 1)
		draw_texture_rect_region(_sheet, Rect2(spot + drop - _cell * ART * 0.5, _cell * ART), region,
			Color(ink, ink.a * float(f[5])))


## The bodies, on the child with the fish shader. The vertex colour carries the water's
## colour over the fish and, packed in its alpha, the water's share and how far in it has faded.
func _draw_bodies() -> void:
	if _sheet == null:
		return
	var t := float(Time.get_ticks_msec()) * 0.001
	for f: Array in _spots:
		var s: Dictionary = f[0]
		var i: int = f[1]
		var spot: Vector2 = f[2]
		var beat := BEAT * (BEAT_FLEE if float(s["flee"]) > 0.0 else 1.0)
		var wag: int = [0, 1, 2, 1][posmod(int(floor(t * beat * 2.0 + float(s["seed"]) + float(i) * 0.61)), 4)]
		var region := _region(String(s["species"]), _heading_index(s, i), wag)
		_bodies.draw_texture_rect_region(_sheet, Rect2(spot - _cell * ART * 0.5, _cell * ART), region, f[4])


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


## The clean water's ramp, deep to light, off the master palette.
static func water_ramp() -> Array[Color]:
	if _water.is_empty():
		_water = [Color(0.173, 0.302, 0.431), Color(0.255, 0.42, 0.573),
			Color(0.353, 0.525, 0.678), Color(0.498, 0.655, 0.776), Color(0.769, 0.859, 0.91)]
		var palette := Palette.master()
		if palette != null:
			_water = [palette.water_clean_deep, palette.water_clean_mid, palette.water_clean,
				palette.water_clean_shallow, palette.water_clean_light]
	return _water


## How much water lies between the eye and something under the surface at `at`, and its
## colour there: the bed's five depth steps, with the shares given (a fish's by default; a
## thing deeper down takes larger ones).
static func water_over(at: Vector2, shallow := MIX_SHALLOW, band_end := MIX_BAND_END,
		deep := MIX_DEEP) -> Color:
	return _water_at(depth_at(at), shallow, band_end, deep)


## `water_over` at a depth already known.
static func _water_at(d: float, shallow: float, band_end: float, deep: float) -> Color:
	var ramp := water_ramp()
	var q := floorf(clampf(d / BAND_END, 0.0, 0.999) * float(LEVELS)) / float(LEVELS - 1)
	var share := deep if d >= BAND_END else lerpf(shallow, band_end, q)
	var water: Color = ramp[clampi(int(roundf(3.0 - 2.0 * q)), 0, 4)] if d < BAND_END else ramp[1]
	water.a = share
	return water


## A colour of something under the surface, as the eye sees it: `own` mixed towards the
## water over it. Opaque; for pictures drawn in code rather than through the fish shader.
static func under_water(at: Vector2, own: Color, shallow := MIX_SHALLOW, band_end := MIX_BAND_END,
		deep := MIX_DEEP) -> Color:
	var water := water_over(at, shallow, band_end, deep)
	var out := own.lerp(water, water.a)
	out.a = own.a
	return out


## The vertex colour `shaders/fish.gdshader` reads: the water's colour at `at`, and in its
## alpha the water's share in fifteenths times sixteen plus how far in the thing has faded.
static func through_tint(at: Vector2, fade: float, shallow := MIX_SHALLOW, band_end := MIX_BAND_END,
		deep := MIX_DEEP) -> Color:
	return _tint_at(depth_at(at), fade, shallow, band_end, deep)


## `through_tint` at a depth already known.
static func _tint_at(d: float, fade: float, shallow: float, band_end: float, deep: float) -> Color:
	var water := _water_at(d, shallow, band_end, deep)
	var packed := int(roundf(water.a * 15.0)) * 16 + int(roundf(clampf(fade, 0.0, 1.0) * 15.0))
	water.a = float(packed) / 255.0
	return water


## How far a shadow on the bed falls from the thing at `at`: along the sun (`Shade.drop`),
## further the deeper the water (`shadow_depth`). The shared helper for everything that
## throws a shadow onto the bed — the fish, the wildlife, the flora's pads and stems. `day`
## may be null: `Shade` then asks the lake's own.
static func shadow_drop(at: Vector2, day: DayCycle = null) -> Vector2:
	return Shade.drop(day, shadow_depth(at))


## The height over the bed a shadow at `at` is thrown from, in world px: the depth of water
## under it, shallows to deepest.
static func shadow_depth(at: Vector2) -> float:
	return lerpf(SHADOW_DEPTH_NEAR, SHADOW_DEPTH_FAR, depth_at(at))


## Something under the surface at `at` is drawn over a bed the eye can see: the water shader
## shows the bed on clean and hazy water.
static func bed_shows(grid: LakeGrid, at: Vector2) -> bool:
	if grid == null:
		return true
	var tile := Iso.world_to_tile(at)
	var tx := int(floor(tile.x))
	var ty := int(floor(tile.y))
	if tx < 0 or ty < 0 or tx >= Iso.COLS or ty >= Iso.ROWS:
		return false
	# Water under it, not the beach: the map reads a dry tile as clean too.
	if Iso.shore_fraction(tile.x, tile.y) >= 1.0 or Iso.island_fraction(tile.x, tile.y) < 1.0:
		return false
	return grid.water_state(grid.index_of(tx, ty)) <= 1


## The water shader's depth: 0 at the bank, 1 over the deepest water, shoaling up to the
## island. The shader folds `shore_lap` into the radius; this does not, which is a few
## hundredths of depth at the bank and nothing a fish shows.
static func depth_at(world: Vector2) -> float:
	var tile := Iso.world_to_tile(world)
	var s := clampf(Iso.shore_fraction(tile.x, tile.y), 0.0, 1.0)
	return sqrt(maxf(1.0 - s, 0.0)) * smoothstep(1.0, 2.6, Iso.island_fraction(tile.x, tile.y))

class_name Flora
extends Node2D
## The plants that grow back as the lake comes clean: flowers, shrubs and patches on the
## lawns, reeds and pale grass on the beaches, lily pads on the water along the shore.
##
## Decoration only, by decision (2026-09-16): nothing collides with a plant, nothing reads
## one, nothing is saved. What is drawn follows from two things the lake already knows —
## the filth map (is the water beside this spot clean?) and how much of the whole lake is
## clean (`stage`) — so a load lands on the same plants a run would have grown.
##
## Every possible plant is rolled once at build (`_sow`): a spot, a species by the ground it
## stands on, and a rank in 0..1. A plant is *due* when the water nearest it reads clean on
## the map and its rank is under the density the stage buys. Once due it grows in over
## GROW_TIME, staggered by its own delay, and never goes back: the lake cannot get dirtier.
##
## One batch, one draw call, off assets/flora.png (tools/build_flora.py): the island redraws
## every frame, and the rule from Ground's props holds — anything in the hundreds goes in a
## triangle array, never a loop of draw_texture_rect. Their shadows are a second batch off
## the same sheet, drawn first (2026-10-02, one sun: see `_lay`).

const SHEET := "res://assets/flora.png"
const TABLE := "res://assets/flora.json"
## World px to a painted px, the game's own.
const SCALE := 2.0
## How much of the lawn/beach is planted at the end: the share of candidate spots.
const MOST := 0.55
## Candidates per tile on the lawn, the beach, and the water's edge.
const LAWN_SPOTS := 2
const BEACH_SPOTS := 1
const WATER_SPOTS := 1
## Shore band the outer bank's plants live in, tiles out of the water: the shores are where
## the eye is, and a wood full of flowers a screen from any water is not "the lake coming
## back".
const BANK_REACH := 7.0
## The forest floor (2026-09-28, Richard: "grow more inside the forest... not over trees"):
## flowers, patches, ferns and mushrooms on the lawn between the trees, from BANK_REACH out
## to FOREST_DEEP tiles past the woods' edge, never where a tree's or a rock's drawing is
## (`Ground.hidden_by_prop`). They wait on the clean water off their stretch of bank, like
## the rest.
const FOREST_DEEP := 8.0
const FOREST_SPOTS := 2
## Lily pads: this far past the drawn water's edge, in tiles, and no further.
const PAD_OUT := Vector2(0.5, 1.6)
## Open water (2026-09-22): clumps of pads and reeds away from both shores. A spot is in a
## clump where a coarse value noise over `OPEN_CELL` tiles is over `OPEN_AT`, so the pads
## gather in beds rather than peppering the lake. Kept `OPEN_CLEAR` tiles off the yards'
## jetties and berths (`avoid`), where the ferries turn.
const OPEN_CELL := 4.5
const OPEN_AT := 0.6
const OPEN_CLEAR := 3.5
## Bees: at most this many, on the flowers whose rank is under this share of what has grown,
## one or two to a flower, circling its head. Tiny dots, drawn in one untextured batch.
const BEES_MOST := 90
const BEE_SHARE := 0.45
const BEE_COLOR := Color(0.96, 0.8, 0.28)
const BEE_BAND := Color(0.18, 0.13, 0.06)
const BEE_WING := Color(0.93, 0.97, 0.98, 0.55)
## The plants a bee visits, by the start of the species' name.
const BEE_HOSTS := ["flower_", "patch_", "tulip_", "daisies", "clover_", "shrub_flowering", "thrift", "beach_flower",
	"pk_flower_", "pk_bed_"]
## One painted pixel, in world px: a bee is on the art grid like everything else.
const ART := 2.0
## On each beat of the song a bee's orbit jumps ahead by BEE_PULSE radians, fast at the beat
## and easing out before the next, so the whole meadow quickens in time. The beat is
## `music`'s (MusicStation.beat_clock); none, and the orbit runs even.
const BEE_PULSE := 1.1
## Seconds a plant takes to arrive, and the most its own delay can add.
const GROW_TIME := 3.5
const GROW_STAGGER := 2.5
## A sprout shows until this far through the grow; the full picture rises after.
const SPROUT_UNTIL := 0.4
## How often a growing plant's picture is laid out again, a second.
const GROW_FPS := 12.0
## How far the filth map is followed to find "the water beside this spot", in tiles.
const WATER_LOOK := 9
## The map's byte under which water is clean enough for something to grow beside it. The
## shader's first cutoff, clean to hazy, is on the bent value (LakeGrid.water_state); this
## asks the same.
const SEED := 20260916

var grid: LakeGrid
var grounds: Array[Ground] = []
var crate_tile := Vector2.INF
## Tile points the open-water clumps keep `OPEN_CLEAR` away from: the yards' feet and berths.
var avoid := PackedVector2Array()
var music: MusicStation
## The daylight, for the plants' shadows. Unset, `Shade` asks the lake's own
## (`DayCycle.here`); with no day at all the plants throw no shadow on land or water, as the
## ground's props do not.
var day: DayCycle
## 0..1, the share of the lake's water that reads clean. Set by `refresh`.
var stage: float = 0.0

var _sheet: Texture2D
var _table: Dictionary = {}
## Parallel arrays, one entry a candidate, in painter's order (by foot y).
var _foot := PackedVector2Array()
var _rank := PackedFloat32Array()
var _delay := PackedFloat32Array()
var _species := PackedStringArray()
var _water_index := PackedInt32Array()
## -1 not due, otherwise seconds since it became due.
var _age := PackedFloat32Array()
var _growing := 0
## Where the angler stands (world px): a plant growing in, or a bee, is heard only inside the
## dogs' `Dog.HEAR` of it (2026-09-28). Unset, nothing is heard.
var ear: Callable
## Seconds to the next look for a bee within earshot; one host asked a look.
var _bee_listen := 0.0
const BEE_LISTEN := 1.0
## The woods heard from what has grown back (2026-10-05): about once a second the grown
## plants and bee flowers within earshot are counted for `Sfx.set_crowd`, and with at least
## `FOREST_LEAST` plants grown round the angler the woods chirp on their own gap, not only
## as a plant shows itself. A bare shore stays quiet.
const FOREST_LISTEN := 1.0
const FOREST_LEAST := 5
var _listen_at := 0
var _listen_grown := 0
var _alive := 0

var _points := PackedVector2Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()
var _dirty := true
var _grow_tick := 0.0
## The land plants' and the standing reeds' shadows (2026-10-02, one sun): every plant on
## the lawn, the beach and the forest floor is laid again along the sun under itself, like the
## ground's props, and a reed standing in the lake throws one on the water. Their own batch,
## drawn first in `_draw`, so every shadow is under every plant; corners packed like the
## plants' (see `SHADE_LAND`), so they sway with them and take the day's ink every frame.
var _shade_points := PackedVector2Array()
var _shade_uvs := PackedVector2Array()
var _shade_colors := PackedColorArray()
var _shade_indices := PackedInt32Array()
## The sun the shadows were laid for. They are geometry, so they are laid again only when it
## has moved `Ground.SUN_STEP`, the ground's own bargain; the ink is a uniform and follows
## every frame.
var _sun_lean := INF
var _sun_stretch := INF
var _below: Below
## What is under the water plants through clean water (2026-09-30, the lakebed pass): each
## pad's shadow on the bed, and a stem from each pad or reed down to a root on the bed. Laid
## with the plants in `_lay` as (kind, from, to) rows; drawn by `Below`, behind the plants.
var _below_rows: Array = []
## The pads' shadows on the bed, as one batch on `Below`'s own child (`BedShade`), packed
## afloat so each bobs with the pad it is the shadow of.
var _bed_points := PackedVector2Array()
var _bed_uvs := PackedVector2Array()
var _bed_colors := PackedColorArray()
var _bed_indices := PackedInt32Array()
const STEM := Color(0.3, 0.44, 0.2)
const ROOT := Color(0.2, 0.26, 0.12)
## The water's share over a stem: it runs from the surface to the bed, so its mean depth.
const STEM_WATER := [0.3, 0.48, 0.64]
## The flowers bees are circling, and each bee's seed. Parallel.
var _bee_host := PackedInt32Array()
var _bee_seed := PackedFloat32Array()
var _bee_points := PackedVector2Array()
var _bee_colors := PackedColorArray()
var _bee_indices := PackedInt32Array()
## The bees draw on a child of their own, so their frame-by-frame redraw does not send the
## whole plant batch again with them.
var _bees: Bees


class Bees:
	extends Node2D
	var flora: Flora

	func _draw() -> void:
		flora._draw_bees(self)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# The shadows' ink and their packed corners are the shader's to read, so it is always on;
	# the bench's A/B (`BENCH_OFF=sway`) stills the motion instead of taking the shader off.
	var bench_still := OS.is_debug_build() and OS.get_environment("BENCH_OFF").contains("sway")
	material = sway_material()
	if bench_still:
		_still(material as ShaderMaterial)
	z_index = 3
	z_as_relative = false
	_below = Below.new()
	_below.name = &"Below"
	_below.flora = self
	_below.show_behind_parent = true
	add_child(_below)
	_below.shade = BedShade.new()
	_below.shade.name = &"BedShade"
	_below.shade.flora = self
	_below.shade.show_behind_parent = true
	_below.shade.material = sway_material()
	if bench_still:
		_still(_below.shade.material as ShaderMaterial)
	_below.add_child(_below.shade)
	_bees = Bees.new()
	_bees.name = &"Bees"
	_bees.flora = self
	add_child(_bees)
	_over = Over.new()
	_over.name = &"Over"
	_over.flora = self
	_over.z_index = OVER_LAYER
	_over.z_as_relative = false
	_over.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_over.material = material
	add_child(_over)
	_sheet = load(SHEET) as Texture2D
	if FileAccess.file_exists(TABLE):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(TABLE))
		if parsed is Dictionary:
			_table = parsed
	if grid != null and _sheet != null and not _table.is_empty():
		_sow()
	# Always: the shadows' ink is pushed every frame (`_follow_sun`), and on an idle frame that
	# is all this does.
	set_process(true)


## The plants move with the water (2026-10-02): afloat ones ride the lake's swell with the
## rubbish, land ones lean their tops in its rhythm. See shaders/flora_sway.gdshader; the
## island ground's tufts share it (Ground). Children (the stems below, the bees) do not.
const SWAY_SHADER := "res://shaders/flora_sway.gdshader"
## A land plant's top leans this many art px at the swell's crest, rounded to whole ones.
const LEAN := 1.4
## What a corner does, in the blue of its packed colour (see the shader).
const AFLOAT := 1.0
const TOP := 0.5
const FOOT := 0.0
## The ground's trees (2026-10-05): an old Forest tree's top corner, leaning on the wind, and
## every corner of an animated tree, stepped through its frames. See the shader.
const WIND := 0.375
const FRAMES := 0.125
## What a shadow's corner carries in its alpha, which is also the surface it falls on and so
## the ink the shader draws it in (2026-10-02, one sun). A plant is alpha 1; any other alpha
## is not packed. The ground's props use the same three (Ground).
const SHADE_WATER := 0.25
const SHADE_LAND := 0.5
const SHADE_BED := 0.75


static func sway_material() -> ShaderMaterial:
	var skin := ShaderMaterial.new()
	skin.shader = load(SWAY_SHADER) as Shader
	skin.set_shader_parameter(&"wave_amplitude", LakeGrid.WAVE_AMPLITUDE)
	skin.set_shader_parameter(&"wave_speed", LakeGrid.WAVE_SPEED)
	skin.set_shader_parameter(&"sway", LakeGrid.SWAY)
	skin.set_shader_parameter(&"anchor_span", LakeGrid.ANCHOR_SPAN)
	skin.set_shader_parameter(&"art_pixel", ART)
	skin.set_shader_parameter(&"lean", LEAN)
	return skin


## The shadows' inks on a sway material, one a surface, for the day as it is this frame —
## overcast and lightning included, since both are in the day's ink. `Shade.tint_on` decides
## every one of them; nothing here picks a colour. `day` may be null.
static func shade_skin(skin: ShaderMaterial, day: DayCycle) -> void:
	if skin == null:
		return
	skin.set_shader_parameter(&"land_ink", Shade.tint_on(day, Shade.On.LAND))
	skin.set_shader_parameter(&"water_ink", Shade.tint_on(day, Shade.On.WATER))
	skin.set_shader_parameter(&"bed_ink", Shade.tint_on(day, Shade.On.BED))


## Where a picture's width lies on the ground under this sun: the x axis of `Shade.cast`,
## which a leaning top's shadow moves along. Pushed whenever a batch's shadows are laid, so
## it always matches the geometry it moves.
static func shade_across(skin: ShaderMaterial, lean: float, stretch: float) -> void:
	if skin != null:
		skin.set_shader_parameter(&"shadow_across", Shade.cast(Vector2.ZERO, lean, stretch).x)


## A sway material with the motion taken out, for the bench's A/B.
static func _still(skin: ShaderMaterial) -> void:
	skin.set_shader_parameter(&"wave_amplitude", 0.0)
	skin.set_shader_parameter(&"sway", 0.0)
	skin.set_shader_parameter(&"lean", 0.0)
	skin.set_shader_parameter(&"wind_lean", 0.0)
	skin.set_shader_parameter(&"tree_fps", 0.0)


## Whether the art is in the project and read.
func ready_to_grow() -> bool:
	return _sheet != null and not _table.is_empty() and not _foot.is_empty()


func candidate_count() -> int:
	return _foot.size()


func alive_count() -> int:
	return _alive


## Where the k-th plant stands (tile coordinates) and what it is. For the harness.
func candidate(k: int) -> Dictionary:
	return {
		"tile": Iso.world_to_tile(_foot[k]), "species": _species[k],
		"kind": String(_table[_species[k]]["kind"]), "alive": _age[k] >= 0.0,
	}


## Forget everything that has grown. For the harness, which refills the lake; a run never
## goes backwards.
func reset() -> void:
	_age.fill(-1.0)
	_growing = 0
	_alive = 0
	_bee_host.resize(0)
	_bee_seed.resize(0)
	_dirty = true
	queue_redraw()


## The lake's clean share changed, or the map did: see what is due now.
func refresh(clean_share: float) -> void:
	stage = clean_share
	if grid == null or grid.filth.is_empty():
		return
	var density := clampf(stage, 0.0, 1.0) * MOST
	for k in _foot.size():
		if _age[k] >= 0.0:
			continue
		if _rank[k] >= density:
			continue
		if grid.water_state(_water_index[k]) != 0:
			continue
		_age[k] = 0.0
		_growing += 1
		_alive += 1
	if _growing > 0:
		set_process(true)
	_dirty = true
	_find_bees()
	queue_redraw()


func bee_count() -> int:
	return _bee_host.size()


## Whether a species is one the bees visit: its name starts with one of `BEE_HOSTS`.
static func is_host(name: String) -> bool:
	for prefix: String in BEE_HOSTS:
		if name.begins_with(prefix):
			return true
	return false


## How many bee-host plants have grown in on the island's own ground (2026-09-30, the
## beehive: the swarm waits on these). Not `bee_count`, which is lake-wide, capped and holds
## a flower once or twice over; not `_find_bees`' "near", which reaches the shore water. A
## plant counts once it has finished growing in, and only on the island's ground.
func island_hosts() -> int:
	var count := 0
	for k in _foot.size():
		if _island_host(k):
			count += 1
	return count


## Where those same plants hold their heads up, in the lake's space (the flora's own, which
## is the hive's): where the hive's bees fly to and from.
func island_host_spots() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in _foot.size():
		if _island_host(k):
			var rect: Array = _table[_species[k]]["full"]
			out.append(_foot[k] - Vector2(0.0, float(rect[3]) * _grain_of(_species[k]) * 0.85))
	return out


func _island_host(k: int) -> bool:
	if _age[k] < 0.0 or _age[k] < _delay[k] + GROW_TIME:
		return false
	if not is_host(_species[k]):
		return false
	var tile := Iso.world_to_tile(_foot[k])
	return Iso.on_island_ground(tile)


## Where the grown pads are, world px: somewhere a frog may sit. Shore pads and open ones.
func pad_spots() -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in _foot.size():
		if _age[k] < _delay[k] + GROW_TIME:
			continue
		var name := _species[k]
		if name.contains("reed"):
			continue
		var kind := String(_table[name]["kind"])
		if kind == "water" or kind == "open":
			out.append(_foot[k] - Vector2(0.0, 4.0))
	return out


## The flowers with bees at them: the lowest ranks among the grown hosts, up to BEES_MOST.
func _find_bees() -> void:
	_bee_host.resize(0)
	_bee_seed.resize(0)
	var density := clampf(stage, 0.0, 1.0) * MOST * BEE_SHARE
	# Every grown host under the density, lowest rank first — the painter's order put all
	# of them on the far bank — with the island's own flowers well up the queue, since the
	# island is where the player stands.
	var hosts: Array = []
	for k in _foot.size():
		if _age[k] < 0.0 or _rank[k] >= density:
			continue
		var tile := Iso.world_to_tile(_foot[k])
		var near := Iso.island_fraction(tile.x, tile.y) < 1.5
		hosts.append([_rank[k] * (0.25 if near else 1.0), k])
	hosts.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for pair: Array in hosts:
		var k: int = pair[1]
		if _bee_host.size() >= BEES_MOST:
			break
		var name := _species[k]
		var host := false
		for prefix: String in BEE_HOSTS:
			if name.begins_with(prefix):
				host = true
				break
		if not host:
			continue
		var n := 1 if _hash(float(k) * 1.3, 4.0) < 0.7 else 2
		# Never past the cap: a host with two bees taken as the last one under it put the
		# count one over (found when the beehive's footprint moved which flowers are sown).
		n = mini(n, BEES_MOST - _bee_host.size())
		for i in n:
			_bee_host.append(k)
			_bee_seed.append(_hash(float(k) * 2.1 + float(i) * 5.3, 9.0) * 100.0)
	if not _bee_host.is_empty():
		set_process(true)


## Counts what has grown back within earshot for the sound's crowd, and lets the woods
## chirp off a grown shore. The candidates are walked a slice a frame, the whole list once
## every `FOREST_LISTEN`, so no frame pays for thousands of plants at once.
func _listen_for_crowds(delta: float) -> void:
	var sfx := Sfx.main()
	if sfx == null or not ear.is_valid() or _age.is_empty():
		return
	var here: Vector2 = ear.call()
	var reach := Iso.tile_circle_extent(Dog.HEAR)
	var count := _age.size()
	var slice := mini(count - _listen_at, ceili(float(count) * delta / FOREST_LISTEN))
	for k in range(_listen_at, _listen_at + slice):
		if _age[k] >= 0.0 and _age[k] >= _delay[k] and here.distance_to(_foot[k]) < reach:
			_listen_grown += 1
	_listen_at += slice
	if _listen_at < count:
		return
	_listen_at = 0
	var hosts := 0
	for k in _bee_host:
		if here.distance_to(_foot[k]) < reach:
			hosts += 1
	sfx.set_crowd(&"forest", _listen_grown)
	sfx.set_crowd(&"bee", hosts)
	if _listen_grown >= FOREST_LEAST:
		sfx.play_forest()
	_listen_grown = 0


func _heard(at: Vector2) -> bool:
	return ear.is_valid() and (ear.call() as Vector2).distance_to(at) < Iso.tile_circle_extent(Dog.HEAR)


func _process(delta: float) -> void:
	_follow_sun()
	if _growing > 0:
		var still := 0
		for k in _age.size():
			if _age[k] < 0.0:
				continue
			var done := _delay[k] + GROW_TIME
			if _age[k] >= done:
				continue
			var was := _age[k]
			_age[k] += delta
			still += 1
			# A plant showing itself near the angler: the woods answer (`Sfx.play_forest`).
			if was < _delay[k] and _age[k] >= _delay[k] and _heard(_foot[k]) and Sfx.main() != null:
				Sfx.main().play_forest()
		# Laid out again at GROW_FPS while anything grows, not every frame (2026-10-02): the
		# whole batch is rebuilt each time, about a millisecond on a cleaned half lake, and
		# after a clean everything that comes due grows in together for several seconds.
		# Stepped, the way the lake's other pattern animation ticks; the last step always
		# lands.
		_grow_tick += delta
		if (still > 0 and _grow_tick >= 1.0 / GROW_FPS) or still == 0:
			_grow_tick = 0.0
			_dirty = true
			queue_redraw()
		_growing = still
	_listen_for_crowds(delta)
	if not _bee_host.is_empty():
		_bees.queue_redraw()
		_bee_listen -= delta
		if _bee_listen <= 0.0:
			_bee_listen = BEE_LISTEN
			var k := _bee_host[randi() % _bee_host.size()]
			if _heard(_foot[k]) and Sfx.main() != null:
				Sfx.main().play_bee()


## Every frame: the shadows' inks for the day as it is (uniforms, so a flash reaches them the
## frame it strikes), and a fresh lay once the sun has moved far enough that the shadows'
## geometry is worth laying again. Nothing grown, nothing to lay.
var _ink_seen := Color(-1.0, -1.0, -1.0, -1.0)


func _follow_sun() -> void:
	var sun := Shade.sun_of(day)
	var ink := Shade.tint_on(sun, Shade.On.LAND)
	if ink != _ink_seen:
		_ink_seen = ink
		shade_skin(material as ShaderMaterial, sun)
		if _below != null and _below.shade != null:
			shade_skin(_below.shade.material as ShaderMaterial, sun)
	if sun == null or _alive == 0:
		return
	if absf(sun.lean - _sun_lean) >= Ground.SUN_STEP \
			or absf(sun.stretch - _sun_stretch) >= Ground.SUN_STEP:
		_dirty = true
		queue_redraw()


## Every spot a plant could stand, rolled once. Lawn and beach tiles of both grounds within
## the shore band, and the ring of water just off each shore for the pads.
func _sow() -> void:
	var entries: Array = []
	for tx in Iso.COLS:
		for ty in Iso.ROWS:
			var kinds := _kinds_at(tx, ty)
			for spot in kinds.size():
				var kind: String = kinds[spot]
				var per := LAWN_SPOTS if kind == "lawn" else (BEACH_SPOTS if kind == "beach"
					else (FOREST_SPOTS if kind == "forest" else WATER_SPOTS))
				if kind == "open" and _near_avoid(Vector2(float(tx) + 0.5, float(ty) + 0.5)):
					continue
				for n in per:
					var at := Vector2(
						float(tx) + 0.1 + 0.8 * _hash(float(tx) * 3.3 + float(n) * 7.1, float(ty) * 1.9 + 2.0),
						float(ty) + 0.1 + 0.8 * _hash(float(ty) * 5.7 + float(n) * 2.3, float(tx) * 4.1 - 1.0)
					)
					var here := _kind_at(at)
					if here != kind:
						continue
					if Iso.in_shed(at.x, at.y, Iso.SHED_COVER):
						continue
					if Pump.covers(at, 0.5):
						continue
					if Pump.covers(at, 2.5) and Pump.hides(at):
						continue
					# And off the beehive and out from behind its picture (2026-09-30): the
					# hive and its shelf are about eighty pixels tall, so the reach asked of
					# `hides` is wider than the pump's, and the shrub and swarm it puts up
					# later count as picture too.
					if Hive.covers(at, 0.5):
						continue
					if Hive.covers(at, 3.5) and Hive.hides(at):
						continue
					if crate_tile != Vector2.INF and Yard.covers(crate_tile, at, 0.6):
						continue
					if kind == "forest" and _under_a_prop(Iso.tile_to_world(at.x, at.y)):
						continue
					var water := _water_beside(at, kind)
					if water < 0:
						continue
					var species := _pick_species(kind, at)
					if species.is_empty():
						continue
					entries.append([Iso.tile_to_world(at.x, at.y), _hash(at.x * 9.7, at.y * 6.3),
						_hash(at.y * 2.9, at.x * 8.1) * GROW_STAGGER, species, water])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return (a[0] as Vector2).y < (b[0] as Vector2).y)
	for e: Array in entries:
		_foot.append(e[0])
		_rank.append(e[1])
		_delay.append(e[2])
		_species.append(e[3])
		_water_index.append(e[4])
		_age.append(-1.0)


## What may grow on a tile, by its middle: none, or a list of kinds. Water gets a pad
## candidate only along the shores.
func _kinds_at(tx: int, ty: int) -> Array:
	var at := Vector2(float(tx) + 0.5, float(ty) + 0.5)
	var kind := _kind_at(at)
	if kind.is_empty():
		return []
	return [kind]


## "lawn", "beach", "water" or "" for a spot on the plane.
func _kind_at(at: Vector2) -> String:
	for ground in grounds:
		var k := ground.kind_at(at.x, at.y)
		if k == Ground.Kind.NONE or k == Ground.Kind.WATER:
			continue
		if ground.layer == Ground.Layer.OUTSIDE:
			var out := Ground.out_of_water(at.x, at.y)
			# Past the shore band, or on the sand that runs out under the water.
			if out < 0.3:
				return ""
			if out > BANK_REACH:
				if k == Ground.Kind.GRASS and out <= Ground.WOOD_FROM + FOREST_DEEP:
					return "forest"
				return ""
		elif Iso.past_shelf(at) > -0.6:
			# The island's drowned sand, as its tufts are kept off it.
			return ""
		return "lawn" if k == Ground.Kind.GRASS else "beach"
	# Not ground: the water just off a shore is a pad's.
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if not Iso.in_lake(tile.x, tile.y):
		return ""
	var shelf := Iso.past_shelf(at)
	if shelf > PAD_OUT.x and shelf < PAD_OUT.y:
		return "water"
	var out := -Ground.out_of_water(at.x, at.y)
	if out > PAD_OUT.x + 1.0 and out < PAD_OUT.y + 1.0:
		return "water"
	# Out on the open water, in a bed.
	if shelf > PAD_OUT.y + 1.5 and out > PAD_OUT.y + 2.5 and _noise(at / OPEN_CELL) > OPEN_AT:
		return "open"
	return ""


func _under_a_prop(world: Vector2) -> bool:
	for ground in grounds:
		if ground.layer == Ground.Layer.OUTSIDE and ground.hidden_by_prop(world):
			return true
	return false


func _near_avoid(at: Vector2) -> bool:
	for p in avoid:
		if at.distance_to(p) < OPEN_CLEAR:
			return true
	return false


## Value noise, 0..1, smooth between whole-number corners.
func _noise(p: Vector2) -> float:
	var i := p.floor()
	var f := p - i
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var a := _hash(i.x, i.y)
	var b := _hash(i.x + 1.0, i.y)
	var c := _hash(i.x, i.y + 1.0)
	var d := _hash(i.x + 1.0, i.y + 1.0)
	return lerpf(lerpf(a, b, f.x), lerpf(c, d, f.x), f.y)


## The index of the water tile this spot answers to: itself if it is water, else the first
## lake tile walking out from the shore it stands on. -1 if none within WATER_LOOK.
func _water_beside(at: Vector2, kind: String) -> int:
	var tile := Vector2i(int(floor(at.x)), int(floor(at.y)))
	if kind == "water" or kind == "open":
		return grid.index_of(tile.x, tile.y)
	var on_island := kind != "forest" and Iso.island_fraction(at.x, at.y) < 1.0 + 1.5
	var dir: Vector2
	if on_island:
		dir = (at - Iso.ISLAND_CENTRE)
	else:
		dir = (Iso.CENTRE - at)
	if dir.length() < 0.001:
		return -1
	dir = dir.normalized()
	var look := WATER_LOOK
	if kind == "forest":
		look += int(Ground.WOOD_FROM + FOREST_DEEP)
	for step in range(1, look * 2):
		var p := at + dir * float(step) * 0.5
		var t := Vector2i(int(floor(p.x)), int(floor(p.y)))
		if not Iso.in_lake(t.x, t.y):
			continue
		if Iso.shore_fraction(p.x, p.y) < 1.0 and Iso.island_fraction(p.x, p.y) > 1.0 + Iso.SHELF_CLEAR:
			return grid.index_of(t.x, t.y)
	return -1


## Reeds stand at the water's edge, not up the sand: on either shore, a beach spot further
## than REED_REACH tiles from the drawn waterline grows something else.
const REEDS := ["reed", "cattail"]
const REED_REACH := 1.0


## World px a painted px of a species' full picture (the json's "scale", 2 when absent).
func _grain_of(name: String) -> float:
	return float((_table.get(name, {}) as Dictionary).get("scale", SCALE))


## A beach plant that only grows by the water: our old reed and cattail, or a pack entry
## marked "reed" (Toffeecraft's cattails and reeds, 2026-10-05).
func is_reed(name: String) -> bool:
	return REEDS.has(name) or bool((_table.get(name, {}) as Dictionary).get("reed", false))


## Tiles from the drawn water's edge, for a spot on sand: the island's shelf line or the
## outer bank's, whichever it is nearer.
func _from_water(at: Vector2) -> float:
	if Iso.island_fraction(at.x, at.y) < 2.5:
		return maxf(-Iso.past_shelf(at), 0.0)
	return maxf(Ground.out_of_water(at.x, at.y), 0.0)


func _pick_species(kind: String, at: Vector2) -> String:
	var names: Array = []
	var weights: Array = []
	for name: String in _table.keys():
		var table_kind := String(_table[name]["kind"])
		if kind == "forest":
			# The lawn's own plants, less the shrubs, which would stand like more trees.
			if table_kind != "lawn" or name.begins_with("shrub"):
				continue
		elif table_kind != kind:
			continue
		if kind == "beach" and is_reed(name) and _from_water(at) > REED_REACH:
			continue
		names.append(name)
		# Shrubs are big and rarer; patches and flowers common. The pack's entries carry
		# their own weight (tools/build_flora.py), so a kind's many small entries add up to
		# what one of ours used to be.
		var weight := 1.0
		if (_table[name] as Dictionary).has("weight"):
			weight = float(_table[name]["weight"])
		elif name.begins_with("shrub"):
			weight = 0.25
		weights.append(weight)
	if names.is_empty():
		return ""
	var total := 0.0
	for w: float in weights:
		total += w
	var roll := _hash(at.x * 4.4 + 1.0, at.y * 7.9 + 3.0) * total
	for i in names.size():
		roll -= weights[i]
		if roll <= 0.0:
			return names[i]
	return names[names.size() - 1]


## Every grown plant into the batch, with its shadows: the shadow on the land or the water
## under it (`_shade_*`), the pad's on the bed (`_bed_*`), and the stems (`_below_rows`).
##
## A shadow is the plant's own quad laid along the sun from its foot (`Shade.cast`, the
## ground's props' rule), so it is exactly as big as the picture is this frame: a sprout's
## shadow is a sprout's, and a plant rising in casts a shadow rising with it. Its corners
## carry the plant's own packed foot and role, so the sway shader moves its far end as it
## leans the plant's top, and an afloat reed's shadow rides the swell with the reed. On land
## for the lawn, the beach and the forest floor; on the water for a reed standing in the
## lake; none for a pad lying flat on it, which throws its shadow on the bed instead.
func _lay() -> void:
	_below_rows.clear()
	_points.resize(0)
	_uvs.resize(0)
	_colors.resize(0)
	_indices.resize(0)
	_shade_points.resize(0)
	_shade_uvs.resize(0)
	_shade_colors.resize(0)
	_shade_indices.resize(0)
	_bed_points.resize(0)
	_bed_uvs.resize(0)
	_bed_colors.resize(0)
	_bed_indices.resize(0)
	var sun := Shade.sun_of(day)
	if sun != null:
		_sun_lean = sun.lean
		_sun_stretch = sun.stretch
		shade_across(material as ShaderMaterial, sun.lean, sun.stretch)
	var sheet_size := Vector2(_sheet.get_width(), _sheet.get_height())
	_quad_at.resize(_foot.size())
	_quad_at.fill(-1)
	_over_stale = true
	for k in _foot.size():
		if _age[k] < 0.0:
			continue
		var t := clampf((_age[k] - _delay[k]) / GROW_TIME, 0.0, 1.0)
		if t <= 0.0:
			continue
		var entry: Dictionary = _table[_species[k]]
		var rect: Array
		var rise: float
		if t < SPROUT_UNTIL:
			rect = entry["sprout"]
			rise = 1.0
		else:
			rect = entry["full"]
			var u := (t - SPROUT_UNTIL) / (1.0 - SPROUT_UNTIL)
			rise = 0.5 + 0.5 * (1.0 - (1.0 - u) * (1.0 - u))
		# World px a painted px: the pack's plants are drawn at 1, a big lake plant and ours
		# at 2 (the json's "scale"). A sprout is ours, so always at 2.
		var grain := SCALE if t < SPROUT_UNTIL else float(entry.get("scale", SCALE))
		var w := float(rect[2]) * grain
		var h := float(rect[3]) * grain * rise
		var foot := _foot[k]
		var box := Rect2(foot - Vector2(w * 0.5, h), Vector2(w, h))
		var uv := Rect2(Vector2(rect[0], rect[1]) / sheet_size, Vector2(rect[2], rect[3]) / sheet_size)
		var kind := String(entry["kind"])
		# Afloat, the whole picture rides the swell; on land, only the top corners lean.
		var afloat := kind == "water" or kind == "open"
		var standing := bool(entry.get("stand", false))
		if afloat and t >= SPROUT_UNTIL and Fish.bed_shows(grid, foot):
			var drop := Fish.shadow_drop(foot, sun)
			var from := foot if standing else box.get_center()
			_below_rows.append([&"stem", from, from + drop])
			if not standing:
				var lies := Rect2(box.position + drop, box.size)
				var bob := LakeGrid.pack_anchor(foot.x, AFLOAT, SHADE_BED)
				_bed_quad(_corners(Transform2D.IDENTITY, lies), uv, bob, bob)
		if sun != null and (standing or not afloat):
			var lie := Shade.cast(foot, sun.lean, sun.stretch)
			var flag := SHADE_WATER if afloat else SHADE_LAND
			var far := LakeGrid.pack_anchor(foot.x, AFLOAT if afloat else TOP, flag)
			var near := LakeGrid.pack_anchor(foot.x, AFLOAT if afloat else FOOT, flag)
			_shade_quad(_corners(lie, Rect2(Vector2(-w * 0.5, -h), Vector2(w, h))), uv, far, near)
		var base := _points.size()
		if not afloat or standing:
			_quad_at[k] = base
		_points.append_array(_corners(Transform2D.IDENTITY, box))
		_uvs.append(uv.position)
		_uvs.append(Vector2(uv.end.x, uv.position.y))
		_uvs.append(uv.end)
		_uvs.append(Vector2(uv.position.x, uv.end.y))
		var top := LakeGrid.pack_anchor(foot.x, AFLOAT if afloat else TOP, 1.0)
		var still := LakeGrid.pack_anchor(foot.x, AFLOAT if afloat else FOOT, 1.0)
		_colors.append_array(PackedColorArray([top, top, still, still]))
		_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	_dirty = false
	if _below != null:
		_below.queue_redraw()
		if _below.shade != null:
			_below.shade.queue_redraw()


## A box's corners, top-left, top-right, bottom-right, bottom-left, put through `xform`: the
## top two are the picture's top, whatever the transform lays them out as.
static func _corners(xform: Transform2D, box: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		xform * box.position, xform * Vector2(box.end.x, box.position.y),
		xform * box.end, xform * Vector2(box.position.x, box.end.y),
	])


## One shadow quad into the land-and-water batch: `far` on the picture's top corners, `near`
## on its foot.
func _shade_quad(corners: PackedVector2Array, uv: Rect2, far: Color, near: Color) -> void:
	var base := _shade_points.size()
	_shade_points.append_array(corners)
	_shade_uvs.append(uv.position)
	_shade_uvs.append(Vector2(uv.end.x, uv.position.y))
	_shade_uvs.append(uv.end)
	_shade_uvs.append(Vector2(uv.position.x, uv.end.y))
	_shade_colors.append_array(PackedColorArray([far, far, near, near]))
	_shade_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## One pad's shadow into the bed's batch.
func _bed_quad(corners: PackedVector2Array, uv: Rect2, far: Color, near: Color) -> void:
	var base := _bed_points.size()
	_bed_points.append_array(corners)
	_bed_uvs.append(uv.position)
	_bed_uvs.append(Vector2(uv.end.x, uv.position.y))
	_bed_uvs.append(uv.end)
	_bed_uvs.append(Vector2(uv.position.x, uv.end.y))
	_bed_colors.append_array(PackedColorArray([far, far, near, near]))
	_bed_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


## The shadows first, as their own triangle array, so every one is under every plant; then
## the plants. Two draw calls for the whole of the flora, off one sheet and one material.
func _draw() -> void:
	if _sheet == null or _foot.is_empty():
		return
	if _dirty:
		_lay()
	if not _shade_indices.is_empty():
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), _shade_indices, _shade_points, _shade_colors, _shade_uvs,
			PackedInt32Array(), PackedFloat32Array(), _sheet.get_rid()
		)
	if _indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		get_canvas_item(), _indices, _points, _colors, _uvs,
		PackedInt32Array(), PackedFloat32Array(), _sheet.get_rid()
	)


## Plants standing in front of an animal, drawn again over it (2026-10-05, Richard: "make
## sure animals go behind the bushes and vegetation"). Flora is one batch under every animal
## (z 3), so a rabbit behind a shrub was drawn over the shrub. Each frame Wildlife hands over
## its animals' drawn boxes (`cover`), and every land plant whose foot is lower on the screen
## than an animal's feet and whose picture overlaps it is drawn a second time on `Over`, at
## OVER_LAYER: over the animals (Wildlife's ground layer, 6), under the walkers (9). The same
## quads, colours and sway material as the batch, so the copy lies exactly on the plant.
## Floating pads are not redrawn (an animal is never behind one); standing reeds are.
const OVER_LAYER := 7
## A tile cell as one int key, x * CELL_KEY + y: cheaper to hash than a Vector2i.
const CELL_KEY := 4096
var _quad_at := PackedInt32Array()
var _by_cell: Dictionary = {}
var _over: Over
var _over_keys := PackedInt32Array()
var _over_stale := true
var _over_points := PackedVector2Array()
var _over_uvs := PackedVector2Array()
var _over_colors := PackedColorArray()
var _over_indices := PackedInt32Array()


class Over:
	extends Node2D
	var flora: Flora

	func _draw() -> void:
		if flora == null or flora._sheet == null or flora._over_indices.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), flora._over_indices, flora._over_points, flora._over_colors,
			flora._over_uvs, PackedInt32Array(), PackedFloat32Array(), flora._sheet.get_rid()
		)


## The plants over these animals: `bodies` is a list of [drawn box, feet's y], world px.
func cover(bodies: Array) -> void:
	if _over == null or _foot.is_empty():
		return
	if _by_cell.is_empty():
		for k in _foot.size():
			var t := Iso.world_to_tile(_foot[k])
			var cell := int(floor(t.x)) * CELL_KEY + int(floor(t.y))
			if not _by_cell.has(cell):
				_by_cell[cell] = []
			(_by_cell[cell] as Array).append(k)
	var picked := PackedInt32Array()
	var seen := {}
	for b: Array in bodies:
		var body: Rect2 = b[0]
		var feet_y: float = b[1]
		var t := Iso.world_to_tile(Vector2(body.get_center().x, feet_y))
		var cx := int(floor(t.x))
		var cy := int(floor(t.y))
		# A plant can only be over an animal if its foot is lower on the screen, within a
		# picture's height: a tile behind to two in front.
		for dx in range(-1, 3):
			for dy in range(-1, 3):
				var cell := (cx + dx) * CELL_KEY + cy + dy
				if not _by_cell.has(cell):
					continue
				for k in (_by_cell[cell] as Array):
					if seen.has(k) or k >= _quad_at.size():
						continue
					var q := _quad_at[k]
					if q < 0 or _foot[k].y <= feet_y:
						continue
					if Rect2(_points[q], _points[q + 2] - _points[q]).intersects(body):
						seen[k] = true
						picked.append(k)
	picked.sort()
	if picked == _over_keys and not _over_stale:
		return
	_over_keys = picked
	_over_stale = false
	_over_points.resize(0)
	_over_uvs.resize(0)
	_over_colors.resize(0)
	_over_indices.resize(0)
	for k in picked:
		var q := _quad_at[k]
		var base := _over_points.size()
		for i in 4:
			_over_points.append(_points[q + i])
			_over_uvs.append(_uvs[q + i])
			_over_colors.append(_colors[q + i])
		_over_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))
	_over.queue_redraw()


## How many plants are drawn over an animal this frame. For the harness.
func over_count() -> int:
	return _over_keys.size()


## Under the water plants, behind them: the pads' shadows on the bed (`shade`, its own
## child, drawn behind this), then the stems over them, each a column of whole art pixels
## stepping sideways as it goes down, and a root on the bed.
class Below:
	extends Node2D
	var flora: Flora
	var shade: BedShade

	func _draw() -> void:
		if flora == null or flora._sheet == null:
			return
		for row: Array in flora._below_rows:
			if row[0] != &"stem":
				continue
			var from: Vector2 = (row[1] as Vector2 / ART).floor() * ART
			var to: Vector2 = (row[2] as Vector2 / ART).floor() * ART
			var stem := Fish.under_water(from, STEM, STEM_WATER[0], STEM_WATER[1], STEM_WATER[2])
			var root := Fish.under_water(from, ROOT, STEM_WATER[0], STEM_WATER[1], STEM_WATER[2])
			var rows := maxi(int((to.y - from.y) / ART), 1)
			for i in rows:
				var x := roundf(lerpf(from.x, to.x, float(i) / float(rows)) / ART) * ART
				draw_rect(Rect2(Vector2(x, from.y + float(i) * ART), Vector2(ART, ART)), stem)
			draw_rect(Rect2(to + Vector2(-ART, 0.0), Vector2(ART * 3.0, ART)), root)


## The pads' shadows on the lakebed, one batch: each the pad's picture where `Fish.shadow_drop`
## puts it along the sun, in the bed's ink (`Shade.On.BED`, pushed every frame), and packed
## afloat on the pad's own foot so it bobs and wanders with the pad over it. Its own node with
## its own sway material, because the stems drawn on `Below` are plain colours that a sway
## material would read as packed.
class BedShade:
	extends Node2D
	var flora: Flora

	func _draw() -> void:
		if flora == null or flora._sheet == null or flora._bed_indices.is_empty():
			return
		RenderingServer.canvas_item_add_triangle_array(
			get_canvas_item(), flora._bed_indices, flora._bed_points, flora._bed_colors,
			flora._bed_uvs, PackedInt32Array(), PackedFloat32Array(), flora._sheet.get_rid()
		)


## Each bee circles its flower's head on a wobbling loop, on whole art pixels: a yellow dot,
## a dark one behind it, and a pale wing pixel flicking over it. One untextured batch.
func _draw_bees(on: CanvasItem) -> void:
	if _bee_host.is_empty():
		return
	_bee_points.resize(0)
	_bee_colors.resize(0)
	_bee_indices.resize(0)
	var now := float(Time.get_ticks_msec()) * 0.001
	var flick := int(now * 18.0) % 2 == 0
	var pulse := 0.0
	if music != null:
		var b := music.beat_clock()
		var into := b - floorf(b)
		pulse = (floorf(b) + 1.0 - pow(1.0 - into, 3.0)) * BEE_PULSE
	for i in _bee_host.size():
		var k := _bee_host[i]
		var t := clampf((_age[k] - _delay[k]) / GROW_TIME, 0.0, 1.0)
		if t < 1.0:
			continue
		var rect: Array = _table[_species[k]]["full"]
		var head := _foot[k] - Vector2(0.0, float(rect[3]) * _grain_of(_species[k]) * 0.85)
		var seed := _bee_seed[i]
		var rx := 5.0 + fmod(seed, 5.0)
		var ry := 3.0 + fmod(seed * 1.7, 3.0)
		var a := now * (2.2 + fmod(seed, 1.3)) + seed + pulse
		var at := head + Vector2(cos(a) * rx + sin(a * 2.3) * 2.0, sin(a * 1.6) * ry - 2.0)
		at = (at / ART).floor() * ART
		# The dark band trails the way it is flying.
		var back := Vector2(signf(sin(a)), 0.0) * ART
		_bee_quad(at, BEE_COLOR)
		_bee_quad(at + back, BEE_BAND)
		if flick:
			_bee_quad(at + Vector2(0.0, -ART), BEE_WING)
	if _bee_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(
		on.get_canvas_item(), _bee_indices, _bee_points, _bee_colors
	)


func _bee_quad(at: Vector2, color: Color) -> void:
	var base := _bee_points.size()
	_bee_points.append(at)
	_bee_points.append(at + Vector2(ART, 0.0))
	_bee_points.append(at + Vector2(ART, ART))
	_bee_points.append(at + Vector2(0.0, ART))
	for n in 4:
		_bee_colors.append(color)
	_bee_indices.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))


func _hash(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7 + float(SEED) * 0.0001) * 43758.5453
	return h - floor(h)

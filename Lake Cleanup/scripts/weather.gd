## Rain (2026-09-25, `/grill-me` with Richard): a few showers a run, atmosphere only.
##
## Nothing here touches the game. A shower does not move a piece, a price, a boat or a dog —
## it greys the light, pours whole-pixel streaks over the view, splashes wherever a drop lands
## on something drawn, wets the island into puddles, and now and then throws a flash of
## lightning with thunder behind it. Like the rope, it is drawn only.
##
## **At most `MOST` showers a run, at random times** (Richard: "like 5 max for the whole
## playthrough, in a random way, not timed"). The count and the time to the next roll are
## saved (`showers`, `rain_next`); a save without them reads as none yet.
##
## **Where a drop lands is decided when it is born**: a spot in the view is picked, and what
## is drawn there — a roof, a walker's head, the top of a floating piece, the lake, the
## island — is asked once. The drop is then simply laid on the line that falls onto that spot.
## So only drops in view cost anything, and 33k pieces off screen cost nothing.
##
## **Roofs are silhouettes, measured off the art** (`_tops`, the way `Skirt.hem` reads the
## lowest row of a column): a drop hitting the hut lands on the thatch it hits, not on the
## picture's box, and some run off the nearer eave and drip to the ground.
class_name Weather
extends Node2D

## The showers in a whole run, at most.
const MOST := 5

## Seconds of play before the first roll, and between showers after it. Rolled uniformly:
## a run of about fifty minutes sees four or five.
const FIRST_AFTER := Vector2(240.0, 720.0)
const GAP := Vector2(360.0, 840.0)

## How long a shower lasts, and how long it takes to come in and to clear.
const LASTS := Vector2(60.0, 120.0)
const RISE := 8.0
const CLEAR := 10.0

## A shower that would start while the game says not now (the intro, a tour, the ending)
## is tried again this much later rather than lost.
const HELD_RETRY := 20.0

## Drops in the air per world px² of view at full rain, and the cap whatever the view.
const DENSITY := 0.00055
const DROPS_MOST := 900

## How a drop falls: its direction (a little to the left, the way the shadows lean), its
## speed, and the streak drawn behind it, all in world px.
const FALL := Vector2(-0.22, 1.0)
const SPEED := Vector2(620.0, 760.0)
const STREAK := 5
const PIXEL := 2.0

## Of the drops that land on a floating piece's tile, how many hit the piece rather than the
## water beside it. A tile is mostly water.
const PIECE_ODDS := 0.45

## A roof drop that runs off the eave, and how long it hangs there before it lets go.
const DRIP_ODDS := 0.18
const DRIP_HANG := Vector2(0.15, 0.6)
const GRAVITY := 900.0

## Splash bits: how many, how fast, how long.
const BITS := Vector2i(2, 4)
const BIT_SPEED := Vector2(40.0, 110.0)
const BIT_LIFE := 0.28
const BITS_MOST := 700

## Rings on the water: the share of water drops that push one, their span, and the share of
## the splash layer's rings the rain may hold at once (the wildlife's own rule).
const RING_ODDS := 0.5
const RING_SPAN := Vector2(4.0, 8.0)
const RING_SHARE := 0.45

## Lightning: only in a heavy enough shower, the gap between rolls, the odds a roll strikes,
## and the thunder's delay after the flash.
const FLASH_FROM := 0.6
const FLASH_GAP := Vector2(7.0, 18.0)
const FLASH_ODDS := 0.6
## How bright a flash gets, 0 to 1: halved on 2026-09-25 (Richard: "reduce flash from
## lightning"). Everything that reads the flash (the day's tint, the shed's shaft, the wash
## room) follows.
const FLASH_PEAK := 0.5
## The thunder comes a little after the flash, never on it (2026-09-28, Richard).
const THUNDER_AFTER := Vector2(1.2, 3.2)

## The storm's rain with its thunder cut out, and the thunder in takes of its own played
## after a flash (2026-09-28, `tools/build_sfx.py`).
const RAIN_SOUND := "res://assets/sfx/rain.ogg"
const THUNDER_SOUNDS := [
	"res://assets/sfx/thunder_1.wav",
	"res://assets/sfx/thunder_2.wav",
	"res://assets/sfx/thunder_3.wav",
	"res://assets/sfx/thunder_4.wav",
]
const RAIN_DB := -10.0
const RAIN_INDOORS_DB := -12.0
const THUNDER_DB := -6.0

enum Hit { WATER, GROUND, ROOF, PIECE }

## The rain now, 0 to 1, and the flash, for anything drawn outside the lake — the wash room's
## backdrop and the shed's window read these rather than being handed a node.
static var now: float = 0.0
static var flash_now: float = 0.0

## Wired by the lake.
var grid: LakeGrid
var splash: WaterSplash
var day: DayCycle
var puddles: Puddles
## Callable -> Rect2: the world the camera sees.
var view: Callable
## Callable -> Array of {image: Image or null, rect: Rect2}: what a drop can land on top of.
## With no image, the rect's top edge is the roof (walkers, hulls).
var roofs: Callable
## Callable -> bool: true while a shower may not start (the intro, a tour, the ending).
var held: Callable
## Callable -> bool: true while the world is paused behind the menu. The clock does not run.
var paused: Callable

## Saved.
var showers: int = 0
var next_in: float = -1.0

var _rain: float = 0.0
var _left: float = 0.0
var _flash: float = 0.0
var _flash_in: float = 0.0
var _flash_beats: Array[float] = []
var _thunder_in: float = -1.0
var _rng := RandomNumberGenerator.new()

var _drop_at := PackedVector2Array()
var _drop_land := PackedVector2Array()
var _drop_speed := PackedFloat32Array()
var _drop_hit := PackedByteArray()
var _drop_roof := PackedInt32Array()

var _bit_at := PackedVector2Array()
var _bit_vel := PackedVector2Array()
var _bit_age := PackedFloat32Array()

## Drips hanging off an eave, then falling: position, speed down, time left hanging, the
## ground they fall to.
var _drip_at := PackedVector2Array()
var _drip_fall := PackedFloat32Array()
var _drip_hang := PackedFloat32Array()
var _drip_floor := PackedFloat32Array()

var _roofs: Array = []
## Topmost opaque row per column, per image, measured once.
var _tops_cache: Dictionary = {}

var _ink: Color
var _ink_far: Color
var _bit_ink: Color

var _rain_voice: AudioStreamPlayer
var _thunder_voice: AudioStreamPlayer
var _thunders: Array[AudioStream] = []


func _ready() -> void:
	_rng.randomize()
	if next_in < 0.0:
		next_in = _rng.randf_range(FIRST_AFTER.x, FIRST_AFTER.y)
	var palette := Palette.master()
	var pale := palette.foam_light if palette != null else Color(0.85, 0.9, 0.95)
	_ink = Color(pale, 0.85)
	_ink_far = Color(pale, 0.45)
	_bit_ink = Color(pale, 0.85)
	_rain_voice = AudioStreamPlayer.new()
	_rain_voice.bus = Prefs.BUS_AMBIENCE
	_rain_voice.volume_db = -80.0
	if ResourceLoader.exists(RAIN_SOUND):
		var bed: AudioStream = load(RAIN_SOUND)
		if bed is AudioStreamOggVorbis:
			(bed as AudioStreamOggVorbis).loop = true
		_rain_voice.stream = bed
	add_child(_rain_voice)
	_thunder_voice = AudioStreamPlayer.new()
	_thunder_voice.bus = Prefs.BUS_AMBIENCE
	add_child(_thunder_voice)
	for path: String in THUNDER_SOUNDS:
		if ResourceLoader.exists(path):
			_thunders.append(load(path))


func _exit_tree() -> void:
	now = 0.0
	flash_now = 0.0


## The save's two numbers back in. A shower in progress is not saved: a load is clear sky.
func restore(count: int, next: float) -> void:
	showers = clampi(count, 0, MOST)
	next_in = next if next >= 0.0 else _rng.randf_range(FIRST_AFTER.x, FIRST_AFTER.y)


## Is it raining at all, 0 to 1.
func rain() -> float:
	return _rain


## Start a shower now, whatever the schedule says. For the harness and the probe; a shower
## forced this way still counts against `MOST`.
func pour(lasting: float = -1.0) -> void:
	if showers >= MOST:
		return
	showers += 1
	_left = lasting if lasting > 0.0 else _rng.randf_range(LASTS.x, LASTS.y)
	_flash_in = _rng.randf_range(FLASH_GAP.x * 0.5, FLASH_GAP.y)


## A storm the tornado brings (2026-09-30): the same rain and grey light as a shower, but not
## one of the run's `MOST` showers and not counted. Poured for `lasting` seconds, or until
## `clear_storm` lets it go.
func storm(lasting: float) -> void:
	_left = maxf(_left, lasting)
	_flash_in = minf(_flash_in, _rng.randf_range(1.0, 4.0))


## The tornado's storm is over: the rain eases off over `CLEAR` as a shower's end does.
func clear_storm() -> void:
	_left = 0.0


## A flash now, for the harness and the probe.
func strike() -> void:
	_flash_beats = [0.0, 0.16]
	_thunder_in = _rng.randf_range(THUNDER_AFTER.x, THUNDER_AFTER.y)


func _process(delta: float) -> void:
	var still: bool = paused.is_valid() and bool(paused.call())
	if not still:
		_schedule(delta)
	var want := 1.0 if _left > 0.0 else 0.0
	var rate := delta / (RISE if want > _rain else CLEAR)
	_rain = move_toward(_rain, want, rate)
	_tick_flash(delta)
	now = _rain
	flash_now = _flash
	if day != null:
		day.overcast = _rain
		day.flash = _flash
	if puddles != null:
		puddles.tick(_rain, _flash, delta)
	_tick_sound()
	_roofs = roofs.call() if roofs.is_valid() else []
	_spawn(delta)
	_fall(delta)
	_tick_drips(delta)
	_tick_bits(delta)
	if _rain > 0.0 or not _drop_at.is_empty() or not _bit_at.is_empty() or not _drip_at.is_empty():
		queue_redraw()


func _schedule(delta: float) -> void:
	if _left > 0.0:
		_left -= delta
		if _rain >= FLASH_FROM:
			_flash_in -= delta
			if _flash_in <= 0.0:
				_flash_in = _rng.randf_range(FLASH_GAP.x, FLASH_GAP.y)
				if _rng.randf() < FLASH_ODDS:
					strike()
		return
	if showers >= MOST:
		return
	next_in -= delta
	if next_in > 0.0:
		return
	if held.is_valid() and bool(held.call()):
		next_in = HELD_RETRY
		return
	pour()
	next_in = _rng.randf_range(GAP.x, GAP.y)


## A flash is two quick pulses: a bright one and a smaller echo, each up in a frame and gone
## over a third of a second.
func _tick_flash(delta: float) -> void:
	var lit := 0.0
	var kept: Array[float] = []
	for i in _flash_beats.size():
		var age: float = _flash_beats[i] + delta
		if age < 0.45:
			kept.append(age)
		if age >= 0.0:
			var size := FLASH_PEAK * (1.0 if i == 0 else 0.6)
			lit = maxf(lit, size * exp(-age * 9.0))
	_flash_beats = kept
	_flash = lit
	if _thunder_in >= 0.0:
		_thunder_in -= delta
		if _thunder_in < 0.0 and not _thunders.is_empty() and Sfx.main() != null \
				and Sfx.main().may_play(&"lake_ambient"):
			_thunder_voice.stream = _thunders[Sfx.main().next_step(&"thunder", _thunders.size())]
			_thunder_voice.volume_db = THUNDER_DB + _rng.randf_range(-3.0, 1.0)
			_thunder_voice.pitch_scale = _rng.randf_range(0.9, 1.08)
			_thunder_voice.play()


func _tick_sound() -> void:
	if _rain_voice.stream == null:
		return
	if _rain <= 0.0:
		if _rain_voice.playing:
			_rain_voice.stop()
		return
	if not _rain_voice.playing:
		_rain_voice.play()
	var indoors := Sfx.main() != null and Sfx.main().indoors
	var db := RAIN_DB + (RAIN_INDOORS_DB if indoors else 0.0)
	_rain_voice.volume_db = db + linear_to_db(maxf(_rain, 0.001))


# --- Drops -------------------------------------------------------------------------------

func _spawn(delta: float) -> void:
	if _rain <= 0.0 or not view.is_valid():
		return
	var seen: Rect2 = view.call()
	var want := mini(int(_rain * DENSITY * seen.get_area()), DROPS_MOST)
	# Born at the rate that keeps `want` in the air, given how long a drop takes to fall.
	var fall_time := seen.size.y / ((SPEED.x + SPEED.y) * 0.5)
	var born := float(want) * delta / maxf(fall_time, 0.05)
	var count := int(born) + (1 if _rng.randf() < fmod(born, 1.0) else 0)
	var dir := FALL.normalized()
	for _i in count:
		if _drop_at.size() >= DROPS_MOST:
			return
		var spot := Vector2(
			_rng.randf_range(seen.position.x, seen.end.x),
			_rng.randf_range(seen.position.y, seen.end.y + 40.0)
		)
		var landing := _landing(spot)
		var land: Vector2 = landing[1]
		# Started above the top of the view on the line through its landing, so no drop
		# appears out of thin air in the middle of the screen.
		var up := (land.y - seen.position.y) + _rng.randf_range(10.0, 80.0)
		_drop_at.append(land - dir * (up / dir.y))
		_drop_land.append(land)
		_drop_speed.append(_rng.randf_range(SPEED.x, SPEED.y))
		_drop_hit.append(landing[0])
		_drop_roof.append(landing[2])


## What a drop falling onto `spot` hits: [Hit, where, roof index or -1].
func _landing(spot: Vector2) -> Array:
	# The frontmost roof whose drawing covers the spot: the one standing lowest on screen.
	var best := -1
	var best_top := 0.0
	var best_foot := -INF
	for i in _roofs.size():
		var roof: Dictionary = _roofs[i]
		var box: Rect2 = roof["rect"]
		if spot.x < box.position.x or spot.x >= box.end.x or spot.y > box.end.y:
			continue
		var top := _roof_top(roof, spot.x)
		if is_nan(top) or spot.y < top:
			continue
		if box.end.y > best_foot:
			best_foot = box.end.y
			best = i
			best_top = top
	if best >= 0:
		return [Hit.ROOF, Vector2(spot.x, best_top), best]
	var at := Iso.world_to_tile(spot)
	var tx := int(floor(at.x))
	var ty := int(floor(at.y))
	if grid != null and tx >= 0 and ty >= 0 and tx < Iso.COLS and ty < Iso.ROWS:
		var index := grid.index_of(tx, ty)
		if not grid.stacks[index].is_empty() and _rng.randf() < PIECE_ODDS:
			var top := grid.perch_point(index)
			return [Hit.PIECE, top + Vector2(_rng.randf_range(-3.0, 3.0), 1.0), -1]
	if _wet(at):
		return [Hit.WATER, spot, -1]
	return [Hit.GROUND, spot, -1]


## Water as it is drawn: past the island's drawn edge and inside the outer bank's.
func _wet(at: Vector2) -> bool:
	if Iso.on_island_ground(at):
		return false
	return Iso.shore_fraction(at.x, at.y) < 1.0


## The roof's height over column `x`, in world px, or NAN where the picture is empty there.
func _roof_top(roof: Dictionary, x: float) -> float:
	var box: Rect2 = roof["rect"]
	var image: Image = roof.get("image")
	if image == null:
		# A walker or a hull: a rounded top, highest in the middle.
		var across := (x - box.position.x) / maxf(box.size.x, 1.0) * 2.0 - 1.0
		return box.position.y + box.size.y * (0.06 + 0.12 * across * across)
	var tops := _tops(image)
	var column := clampi(int((x - box.position.x) / box.size.x * image.get_width()), 0, tops.size() - 1)
	if tops[column] < 0:
		return NAN
	return box.position.y + float(tops[column]) / float(image.get_height()) * box.size.y


func _tops(image: Image) -> PackedInt32Array:
	var key := image.get_instance_id()
	if _tops_cache.has(key):
		return _tops_cache[key]
	var tops := PackedInt32Array()
	tops.resize(image.get_width())
	for x in image.get_width():
		tops[x] = -1
		for y in image.get_height():
			if image.get_pixel(x, y).a > 0.5:
				tops[x] = y
				break
	_tops_cache[key] = tops
	return tops


func _fall(delta: float) -> void:
	var dir := FALL.normalized()
	var i := 0
	while i < _drop_at.size():
		var at := _drop_at[i] + dir * _drop_speed[i] * delta
		if at.y >= _drop_land[i].y:
			_land(_drop_hit[i], _drop_land[i], _drop_roof[i])
			_drop_at.remove_at(i)
			_drop_land.remove_at(i)
			_drop_speed.remove_at(i)
			_drop_hit.remove_at(i)
			_drop_roof.remove_at(i)
			continue
		_drop_at[i] = at
		i += 1


func _land(hit: int, at: Vector2, roof: int) -> void:
	match hit:
		Hit.WATER:
			if splash != null and _rng.randf() < RING_ODDS \
					and splash.ripples_up() < int(WaterSplash.MAX_RIPPLES * RING_SHARE):
				splash.ripple(at, _rng.randf_range(RING_SPAN.x, RING_SPAN.y))
			_bits(at, 1, 0.6)
		Hit.GROUND:
			_bits(at, _rng.randi_range(BITS.x, BITS.y - 1), 0.8)
			if puddles != null:
				puddles.hit(at)
		Hit.PIECE:
			_bits(at, _rng.randi_range(BITS.x, BITS.y), 1.0)
		Hit.ROOF:
			_bits(at, _rng.randi_range(BITS.x, BITS.y), 1.0)
			if roof >= 0 and roof < _roofs.size() and _rng.randf() < DRIP_ODDS:
				_drip_from(_roofs[roof], at)


func _bits(at: Vector2, count: int, strength: float) -> void:
	for _i in count:
		if _bit_at.size() >= BITS_MOST:
			return
		var angle := _rng.randf_range(-PI * 0.9, -PI * 0.1)
		var speed := _rng.randf_range(BIT_SPEED.x, BIT_SPEED.y) * strength
		_bit_at.append(at)
		_bit_vel.append(Vector2(cos(angle), sin(angle)) * speed)
		_bit_age.append(_rng.randf_range(0.0, BIT_LIFE * 0.3))


func _tick_bits(delta: float) -> void:
	var i := 0
	while i < _bit_at.size():
		_bit_age[i] += delta
		if _bit_age[i] >= BIT_LIFE:
			_bit_at.remove_at(i)
			_bit_vel.remove_at(i)
			_bit_age.remove_at(i)
			continue
		_bit_vel[i].y += GRAVITY * delta
		_bit_at[i] += _bit_vel[i] * delta
		i += 1


## A drop that runs off the roof: to the nearer end of the silhouette's row it landed on,
## where it hangs a moment, then falls to the ground at the foot of the picture.
func _drip_from(roof: Dictionary, at: Vector2) -> void:
	var box: Rect2 = roof["rect"]
	var image: Image = roof.get("image")
	var edge := box.position.x if at.x < box.get_center().x else box.end.x
	var foot := box.end.y
	if image != null:
		var tops := _tops(image)
		var row := int((at.y - box.position.y) / box.size.y * image.get_height()) + 1
		var column := int((at.x - box.position.x) / box.size.x * image.get_width())
		var step := -1 if at.x < box.get_center().x else 1
		var last := column
		while column >= 0 and column < tops.size() and tops[column] >= 0 \
				and tops[column] <= row + 3:
			last = column
			row = maxi(row, tops[column])
			column += step
		edge = box.position.x + (float(last) + (1.0 if step > 0 else 0.0)) / image.get_width() * box.size.x
		at.y = box.position.y + float(row + 1) / image.get_height() * box.size.y
	if _drip_at.size() > 60:
		return
	_drip_at.append(Vector2(edge, at.y))
	_drip_fall.append(0.0)
	_drip_hang.append(_rng.randf_range(DRIP_HANG.x, DRIP_HANG.y))
	_drip_floor.append(foot + _rng.randf_range(-2.0, 4.0))


func _tick_drips(delta: float) -> void:
	var i := 0
	while i < _drip_at.size():
		if _drip_hang[i] > 0.0:
			_drip_hang[i] -= delta
			i += 1
			continue
		_drip_fall[i] += GRAVITY * delta
		_drip_at[i].y += _drip_fall[i] * delta
		if _drip_at[i].y >= _drip_floor[i]:
			var at := Vector2(_drip_at[i].x, _drip_floor[i])
			_bits(at, 2, 0.5)
			if puddles != null:
				puddles.hit(at)
			_drip_at.remove_at(i)
			_drip_fall.remove_at(i)
			_drip_hang.remove_at(i)
			_drip_floor.remove_at(i)
			continue
		i += 1


# --- Drawing -----------------------------------------------------------------------------

func _snap(at: Vector2) -> Vector2:
	return (at / PIXEL).floor() * PIXEL


func _draw() -> void:
	var cell := Vector2(PIXEL, PIXEL)
	var dir := FALL.normalized()
	for i in _drop_at.size():
		var head := _drop_at[i]
		# A streak of whole art pixels trailing up the line it fell down, fading.
		for k in STREAK:
			var at := _snap(head - dir * PIXEL * 1.6 * float(k))
			draw_rect(Rect2(at, cell), _ink if k < 2 else _ink_far)
	for i in _drip_at.size():
		draw_rect(Rect2(_snap(_drip_at[i]), cell), _bit_ink)
		if _drip_hang[i] <= 0.0:
			draw_rect(Rect2(_snap(_drip_at[i] - Vector2(0.0, PIXEL)), cell), _ink_far)
	for i in _bit_at.size():
		var fade := 1.0 - _bit_age[i] / BIT_LIFE
		draw_rect(Rect2(_snap(_bit_at[i]), cell), Color(_bit_ink, _bit_ink.a * fade))

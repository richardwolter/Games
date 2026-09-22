## What is behind the wash stand: the view from the pump (2026-09-19, `/grill-me` with
## Richard: "a proper background and floorground... as if I'm looking at the lake on a 1st
## person view"). Top to bottom: the sky, the far bank's trees and sand, the lake, the
## island's own sand, and its lawn running under the stand to the bottom of the window.
##
## **Two painted strips and two things drawn here.** The bank and the lawn are baked by
## `tools/build_wash_backdrop.py` out of the pack's own trees and tiles. The water between
## them and the sky over them are drawn in code, because they are the two things that are
## not always the same:
## - **The water is the player's own lake**: one of the palette's five ramps, picked by how
##   much filth the lake still holds through `LakeGrid.FILTH_STATE_AT` — the cutoffs the
##   lake's own shader steps on. Soup early, blue at the end. Flat bands, hard edges, no
##   dither. Set when the room opens and left alone while it is up.
## - **The sky follows the day** (`DayCycle.sun`): `SKY_STEPS` flat steps from the palette's
##   high swatch down to its low one, lerped between morning, noon and afternoon. The only
##   sky in the game.
##
## **And it is alive** (second pass the same day, Richard: "water movement and pigeons
## flying... pixelated clouds and a little bit of movement... the dogs running around"). All
## of it on one stepped clock (`PIXEL_FPS`, the lake's own `pixel_fps`), so what moves moves
## in whole painted pixels a few times a second, like the lake's water:
## - **The water**: the streaks drift along the shore, faster the nearer they are, and blink
##   in and out whole; the near shore's foam line laps a painted pixel in stretches.
## - **Clouds**: the builder's baked puffs in two layers drifting at two paces, wrapping.
## - **Pigeons** cross over the lake, one or a pair every `BIRD_EVERY`, the flock's own
##   birds and flap. **Dogs**, as many as the pack holds, trot about the lawn between the
##   beach and the stand, smaller the further back, and stop to sit or lie.
## - **Both answer the jet** (`sprayed_at`): a bird veers up and away with a puff and a coo,
##   a dog bolts from it with a bark. No pay, no count — a gag. Only while the jet is off
##   the find: a bird passing behind the piece is not what is being washed.
## - **The lake is the player's lake in what is on it too** (third pass, Richard: "we should
##   see objects on the lake so it does not break immersion. And boats also crossing...
##   depending on how many boats you have"): the lake's own rubbish afloat, `RUBBISH_MOST`
##   pieces on a full lake and none on a clean one — the same pieces off one seed, so they
##   thin out as the meter falls rather than reshuffling — and as many ferries as the fleet
##   holds crossing shore to shore on two lanes. **The jet does nothing to either, by
##   decision**: birds and dogs are the gag, the lake is the view.
## - **Which way a thing faces is asked of the thing's owner, never written here**:
##   `Flock.facing_of` for a bird, `Boat.turn_sailing` for a hull, `DogArt.stamp`'s own
##   `facing_left`. The first pigeons here flew tail first, because `Flock.stamp`'s sign is
##   the sheet's (drawn facing left), not the direction of travel, and this file guessed.
## Decoration, the fish's own rule: nothing reads any of it back and nothing is saved. They
## are not the lake's real dogs and birds, which carry on behind the room.
##
## **The whole of it is darkened** (`DARKEN`, the loading screen's trick) and multiplied by
## the day's tint: the grime and the dirty spray are the water's own filthy greens, and
## against a full-strength lawn they lose the contrast the flat dark wall used to give them.
## One knob, by eye.
##
## At `PIXEL` canvas pixels to a painted one, the lake's own grain — finer than the stand's
## and the nozzle's, on purpose: what is far is fine.
##
## Holds nothing of the lake's. The room hands it `filth`, `sun` and `tint`.
class_name WashBackdrop
extends Control

const DogArt := preload("res://scripts/dog_art.gd")

const BANK_ART := "res://assets/wash_bank.png"
const LAWN_ART := "res://assets/wash_lawn.png"
const CLOUD_ART := "res://assets/wash_clouds.png"
const CONTRACT := "res://assets/wash_backdrop.json"

## How many times a second anything here steps: the lake's own `pixel_fps`.
const PIXEL_FPS := 8.0
const SKY_STEPS := 5
## The clouds: how many ride each layer, each layer's pace in canvas pixels a second, how
## big it draws, and how far down the sky (as a share of it) its clouds may sit. The far
## layer is smaller, slower and lower.
const CLOUD_LAYERS := [[4, 3.0, 1.0, Vector2(0.35, 0.8)], [3, 6.0, 2.0, Vector2(0.05, 0.5)]]
const CLOUD_SEED := 611
## The streaks' drift along the shore at the far and the near shore, canvas pixels a second,
## how long one stays before it is rolled again, and how many are showing at once.
const STREAK_PACE := Vector2(2.0, 9.0)
const STREAK_HOLD := 2.6
const STREAK_SHOWN := 0.7
## The near foam line laps in stretches this long, this often.
const LAP_LONG := 56.0
const LAP_PACE := 0.5

## Pigeons: seconds between crossings, how many cross together, their pace, how high the
## arc lifts them, and how close the jet has to come. Startled, a bird climbs at `BIRD_FLEE`
## and flies `BIRD_HURRY` times as fast.
const BIRD_EVERY := Vector2(8.0, 20.0)
const BIRD_PAIR_ODDS := 0.4
const BIRD_PACE := Vector2(120.0, 170.0)
const BIRD_ARC := Vector2(10.0, 40.0)
const BIRD_NEAR := 22.0
const BIRD_FLEE := 150.0
const BIRD_HURRY := 1.8
const FLAP := 0.09
## The puff a startled bird leaves: foam squares that go whole, not faded.
const PUFF_BITS := 7
const PUFF_LIFE := 0.45

## Dogs: a standing dog's height at the beach and at the stand's feet, the band of lawn they
## keep to as shares of the window's height below the near waterline, their trot, how long
## they stop, and the jet's reach. A bolt is `DOG_BOLT` times the trot and at least
## `BOLT_LEAST` long.
## (26 to 54 until Richard's first look: "too small in comparison".)
const DOG_TALL := Vector2(36.0, 72.0)
const DOG_BAND := Vector2(0.07, 0.3)
const DOG_PACE := 95.0
const DOG_REST := Vector2(1.5, 6.0)
const DOG_NEAR := 40.0
const DOG_BOLT := 2.3
const BOLT_LEAST := 320.0
const BARK_GAP := 2.0
const REST_POSES: Array[StringName] = [&"idle", &"idle", &"sit", &"laid", &"sleep"]

## Rubbish afloat: how many on a full lake, how far down the lake (as shares of it) they
## lie, how much of each is under water, and the depth past which a piece draws at the full
## `PIXEL` rather than half of it — what is far is small.
const RUBBISH_MOST := 40
const RUBBISH_SEED := 2909
const RUBBISH_BAND := Vector2(0.12, 0.94)
const RUBBISH_SUNK := 0.3
const RUBBISH_NEAR_FROM := 0.55
const BOB_PACE := 0.35
## Ferries: each lane's waterline down the lake, its canvas pixels to a painted one, and its
## pace. A hull crosses, waits out of sight `BOAT_WAIT`, and comes back the other way.
## (20 and 38 until Richard's look: "can seem a little bit quicker".)
const BOAT_LANES := [[0.2, 1.0, 32.0], [0.72, 2.0, 60.0]]
## The foam collar where a piece or a hull meets the water (Richard, same look: "it lacks
## the objects' foams"): the lake's own collar said in this grain — a torn row of whole foam
## pixels along the waterline and a thinner one under it, re-torn `FOAM_BEATS` times a
## second, the filthy foam on filthy water. How much of each row is there, and how far past
## the picture's ends it runs, in its own pixels.
const FOAM_BEATS := 2.0
const FOAM_ROWS := [0.75, 0.35]
const FOAM_PAST := 1
## The dogs throw the sun's shadow (`Shade.lying`, the day's lean, stretch and ink lent by
## the room as `shade`), at `DOG_SHADE_GAIN` of the ink: the lawn is already darkened.
const DOG_SHADE_GAIN := 1.5
const BOAT_WAIT := Vector2(6.0, 20.0)
const BOAT_MARGIN := 140.0

const PIXEL := 2.0
## Where the near waterline stands down the window, and how tall the lake is drawn, in
## painted pixels. First guesses: judge on `tools/last_wash_room.png`.
const HORIZON := 0.52
const LAKE_TALL := 44
const DARKEN := 0.66
## How far down the bank strip the treetops are, as a share of it: where the sky ends.
const CROWNS_AT := 0.12

## The palette's name for each water state, clean to dirty — `LakeGrid.water_state`'s order.
const STATE_NAMES: Array[String] = ["clean", "hazy", "murky", "foul", "dirty"]
## The lake from the far shore to the near one: a share of its height, and the ramp's step
## (0 deep to 4 light). Shallow at both shores, deep in the middle, and the far bands thinner
## than the near ones, which is all the perspective flat water has.
const BANDS := [[0.08, 3], [0.12, 2], [0.18, 1], [0.28, 0], [0.18, 1], [0.10, 2], [0.06, 3]]
## From this state up the shore's foam line is the filthy foam.
const FOAM_DIRTY_FROM := 3
## Streaks: dashes one step up the ramp from the band they lie on, rolled once off a fixed
## seed. Longer towards the near shore.
const STREAKS := 110
const STREAK_LONG := Vector2(5.0, 34.0)
const STREAK_SEED := 4177
## What is drawn with no palette: the old room's wall.
const FALLBACK := Color(0.07, 0.13, 0.14)

## How much of the lake's filth is left, 0 to 1.
var filth := 1.0:
	set(value):
		filth = clampf(value, 0.0, 1.0)
		queue_redraw()
## Where the sun is along its day, 0 to 1 (`DayCycle.sun`), and the day's tint.
var sun := 0.3:
	set(value):
		sun = value
		queue_redraw()
var tint := Color.WHITE:
	set(value):
		tint = value
		modulate = Color(tint.r * DARKEN, tint.g * DARKEN, tint.b * DARKEN)

## How many dogs are in the player's pack, and the flock's sheet and birds (`Flock.kinds`).
## Lent by the room; with none there are simply no dogs or no pigeons.
var pack := 1
var bird_sheet: Texture2D
var bird_kinds: Array[Dictionary] = []
## The day's shadow as (lean, stretch, ink); nought draws none.
var shade := Vector3.ZERO
## How many ferries the fleet holds, and the lake's rubbish as `{sheet, region}` rows.
var fleet := 1
var rubbish: Array = []

var _bank: Texture2D
var _lawn: Texture2D
var _cloud_art: Texture2D
var _cloud_boxes: Array[Rect2] = []
var _palette: Palette
var _streaks: Array = []
var _clouds: Array = []
var _clock := 0.0
var _birds: Array[Bird] = []
var _dogs: Array[Hound] = []
var _puffs: Array = []
var _next_bird := 4.0
var _bark_in := 0.0
var _roll := RandomNumberGenerator.new()
var _hulls: Array[Hull] = []
var _flotsam: Array = []
var _boat_art := {}


class Hull:
	var lane := 0
	var x := 0.0
	var way := 1.0
	var wait := 0.0


class Bird:
	var kind: Dictionary
	var from := Vector2.ZERO
	var way := 1.0
	var pace := 140.0
	var arc := 20.0
	var along := 0.0
	var lift := 0.0
	var age := 0.0
	var startled := false


class Hound:
	var at := Vector2.ZERO
	var to := Vector2.ZERO
	var depth := 0.5
	var pose: StringName = &"idle"
	var rest := 0.0
	var age := 0.0
	var left := false
	var bolting := false
	## The pack slot this hound stands for, and so its breed and gait — `Dog.slot`'s rule.
	var slot := 0
	var breed := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(BANK_ART):
		_bank = load(BANK_ART)
	if ResourceLoader.exists(LAWN_ART):
		_lawn = load(LAWN_ART)
	_palette = Palette.master()
	_load_clouds()
	DogArt.ready()
	_roll.randomize()
	var roll := RandomNumberGenerator.new()
	roll.seed = STREAK_SEED
	for k in STREAKS:
		# Across as a share of the window, down as a share of the lake, length as a share of
		# the way from shortest to longest.
		_streaks.append(Vector3(roll.randf(), roll.randf(), roll.randf()))
	tint = tint


func _load_clouds() -> void:
	if not ResourceLoader.exists(CLOUD_ART):
		return
	var book = JSON.parse_string(FileAccess.get_file_as_string(CONTRACT))
	if not (book is Dictionary) or not (book as Dictionary).has("clouds"):
		return
	_cloud_art = load(CLOUD_ART)
	for box: Array in book["clouds"]:
		_cloud_boxes.append(Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])))
	var roll := RandomNumberGenerator.new()
	roll.seed = CLOUD_SEED
	for layer in CLOUD_LAYERS.size():
		var count := int(CLOUD_LAYERS[layer][0])
		for k in count:
			# Which picture, where across (a share of the lap, spread and then shoved), how
			# far down its layer's band.
			_clouds.append([
				layer, roll.randi() % _cloud_boxes.size(),
				(float(k) + roll.randf_range(-0.3, 0.3)) / float(count), roll.randf()
			])


## The room coming up or going away: the actors are dropped, and the pack is stood out on
## the lawn afresh.
func reset() -> void:
	_birds.clear()
	_puffs.clear()
	_dogs.clear()
	_next_bird = _roll.randf_range(2.0, BIRD_EVERY.x)
	_hulls.clear()
	for k in clampi(fleet, 0, 4):
		var hull := Hull.new()
		hull.lane = k % BOAT_LANES.size()
		hull.way = 1.0 if _roll.randf() < 0.5 else -1.0
		# Already out on the water when the room comes up, not all queueing at one edge.
		hull.x = _roll.randf_range(0.1, 0.9) * size.x
		_hulls.append(hull)
	_lay_flotsam()
	if not DogArt.has(&"run"):
		return
	for k in clampi(pack, 0, 4):
		var dog := Hound.new()
		dog.slot = k
		dog.breed = DogArt.breed_of(k)
		dog.depth = _roll.randf()
		dog.at = Vector2(_roll.randf_range(0.1, 0.9) * size.x, 0.0)
		_send(dog)
		_dogs.append(dog)


## The rubbish's places, rolled off one seed whatever the lake holds, so a cleaner lake
## shows the first so-many of the same pieces.
func _lay_flotsam() -> void:
	_flotsam.clear()
	if rubbish.is_empty():
		return
	var roll := RandomNumberGenerator.new()
	roll.seed = RUBBISH_SEED
	for k in RUBBISH_MOST:
		_flotsam.append({
			"across": roll.randf(), "deep": roll.randf(), "kind": roll.randi() % rubbish.size(),
			"flip": roll.randf() < 0.5, "beat": roll.randf(),
		})


## How many pieces are afloat for the filth that is left.
func flotsam_shown() -> int:
	return mini(int(round(float(RUBBISH_MOST) * filth)), _flotsam.size())


func hulls() -> Array[Hull]:
	return _hulls


## The picture of a ferry sailing `way` across the screen: the boat's own frame for it.
func hull_art(way: float) -> Dictionary:
	var key := int(signf(way))
	if not _boat_art.has(key):
		_boat_art[key] = Boat.art_frame(Boat.turn_sailing(Vector2(way, 0.0)))
	return _boat_art[key]


## What `Flock.stamp` is handed for a bird: the flock's own answer.
func bird_facing(bird: Bird) -> float:
	return Flock.facing_of(Vector2.ZERO, Vector2(bird.way, 0.0))


func birds() -> Array[Bird]:
	return _birds


func dogs() -> Array[Hound]:
	return _dogs


## The clock as the drawing reads it: stepped, so everything moves together and in jumps.
func stepped() -> float:
	return floorf(_clock * PIXEL_FPS) / PIXEL_FPS


func _process(delta: float) -> void:
	if is_visible_in_tree():
		step(delta)


## One frame. Its own function so a harness can run the clock by hand.
func step(delta: float) -> void:
	_clock += delta
	_bark_in = maxf(_bark_in - delta, 0.0)
	_drive_birds(delta)
	_drive_dogs(delta)
	_drive_hulls(delta)
	for puff: Array in _puffs:
		puff[1] = float(puff[1]) + delta
	_puffs = _puffs.filter(func(puff: Array) -> bool: return float(puff[1]) < PUFF_LIFE)
	queue_redraw()


## The jet is on and pointed here, off the find. Whatever is under it takes fright.
func sprayed_at(point: Vector2) -> void:
	for bird in _birds:
		if not bird.startled and _bird_at(bird).distance_to(point) < BIRD_NEAR:
			bird.startled = true
			_puffs.append([_bird_at(bird), 0.0, _roll.randi() % 100000])
			var sound := Sfx.main()
			if sound != null:
				sound.room_coo()
	for dog in _dogs:
		var reach := DOG_NEAR * _dog_tall(dog) / DOG_TALL.y
		if dog.bolting or (dog.at - Vector2(0.0, _dog_tall(dog) * 0.5)).distance_to(point) > reach:
			continue
		# Away from the jet, a good way, along the lawn.
		var away := -1.0 if point.x > dog.at.x else 1.0
		dog.bolting = true
		dog.rest = 0.0
		dog.pose = &"run"
		dog.to = Vector2(
			clampf(dog.at.x + away * maxf(BOLT_LEAST, size.x * 0.3), -80.0, size.x + 80.0),
			dog.at.y
		)
		dog.left = away < 0.0
		if _bark_in <= 0.0:
			_bark_in = BARK_GAP
			var sound := Sfx.main()
			if sound != null:
				sound.room_bark()


# --- Ferries -----------------------------------------------------------------------------

func _drive_hulls(delta: float) -> void:
	for hull in _hulls:
		if hull.wait > 0.0:
			hull.wait -= delta
			continue
		hull.x += hull.way * float(BOAT_LANES[hull.lane][2]) * delta
		if hull.x < -BOAT_MARGIN or hull.x > size.x + BOAT_MARGIN:
			hull.x = clampf(hull.x, -BOAT_MARGIN, size.x + BOAT_MARGIN)
			hull.way = -hull.way
			hull.wait = _roll.randf_range(BOAT_WAIT.x, BOAT_WAIT.y)


# --- Pigeons -----------------------------------------------------------------------------

## Send one across, for the clock below and for a harness. `high` is a share of the way from
## the top of the window down to the near waterline.
func send_bird(from_left: bool, high: float) -> Bird:
	if bird_sheet == null or bird_kinds.is_empty():
		return null
	var bird := Bird.new()
	bird.kind = bird_kinds[_roll.randi() % bird_kinds.size()]
	bird.way = 1.0 if from_left else -1.0
	bird.from = Vector2(-30.0 if from_left else size.x + 30.0, lake_box().end.y * high)
	bird.pace = _roll.randf_range(BIRD_PACE.x, BIRD_PACE.y)
	bird.arc = _roll.randf_range(BIRD_ARC.x, BIRD_ARC.y)
	_birds.append(bird)
	return bird


func _bird_at(bird: Bird) -> Vector2:
	var share := clampf(bird.along / (size.x + 60.0), 0.0, 1.0)
	return Vector2(
		bird.from.x + bird.way * bird.along,
		bird.from.y - sin(share * PI) * bird.arc - bird.lift
	)


## Where a bird is, for a harness to aim at.
func bird_at(bird: Bird) -> Vector2:
	return _bird_at(bird)


func _drive_birds(delta: float) -> void:
	_next_bird -= delta
	if _next_bird <= 0.0:
		_next_bird = _roll.randf_range(BIRD_EVERY.x, BIRD_EVERY.y)
		var from_left := _roll.randf() < 0.5
		var high := _roll.randf_range(0.12, 0.8)
		var lead := send_bird(from_left, high)
		if lead != null and _roll.randf() < BIRD_PAIR_ODDS:
			var mate := send_bird(from_left, high + 0.05)
			mate.pace = lead.pace
			mate.arc = lead.arc
			mate.along = -34.0
	for bird in _birds:
		bird.age += delta
		bird.along += bird.pace * delta * (BIRD_HURRY if bird.startled else 1.0)
		if bird.startled:
			bird.lift += BIRD_FLEE * delta
	var kept: Array[Bird] = []
	for bird in _birds:
		if bird.along < size.x + 80.0 and _bird_at(bird).y > -40.0:
			kept.append(bird)
	_birds = kept


# --- Dogs --------------------------------------------------------------------------------

func _dog_tall(dog: Hound) -> float:
	return lerpf(DOG_TALL.x, DOG_TALL.y, dog.depth)


func _lawn_y(depth: float) -> float:
	var near := lake_box().end.y
	return near + size.y * lerpf(DOG_BAND.x, DOG_BAND.y, depth)


## Somewhere new to trot to: mostly along the lawn, a little nearer or further.
func _send(dog: Hound) -> void:
	if dog.at.y == 0.0:
		dog.at.y = _lawn_y(dog.depth)
	var depth := clampf(dog.depth + _roll.randf_range(-0.3, 0.3), 0.0, 1.0)
	dog.to = Vector2(_roll.randf_range(0.04, 0.96) * size.x, _lawn_y(depth))
	dog.left = dog.to.x < dog.at.x
	dog.pose = DogArt.gait(dog.slot, false, dog.breed) if DogArt.has(&"run", dog.breed) else &"idle"
	dog.rest = 0.0
	dog.bolting = false


func _drive_dogs(delta: float) -> void:
	for dog in _dogs:
		dog.age += delta
		if dog.rest > 0.0:
			dog.rest -= delta
			if dog.rest <= 0.0:
				_send(dog)
			continue
		var pace := DOG_PACE * (DOG_BOLT if dog.bolting else 1.0) * _dog_tall(dog) / DOG_TALL.y
		dog.at = dog.at.move_toward(dog.to, pace * delta)
		# How big it draws follows where it is, all the way there.
		dog.depth = clampf(inverse_lerp(_lawn_y(0.0), _lawn_y(1.0), dog.at.y), 0.0, 1.0)
		if dog.at.distance_to(dog.to) < 1.0:
			dog.bolting = false
			dog.rest = _roll.randf_range(DOG_REST.x, DOG_REST.y)
			var pose: StringName = REST_POSES[_roll.randi() % REST_POSES.size()]
			dog.pose = pose if DogArt.has(pose, dog.breed) else &"idle"
			dog.age = 0.0


## Whether both strips loaded: without them it is the old flat wall.
func is_painted() -> bool:
	return _bank != null and _lawn != null and _palette != null


## Which of the five water states a share of filth left reads as: the lake's own cutoffs.
static func state_of(share: float) -> int:
	var state := 0
	for at: float in LakeGrid.FILTH_STATE_AT:
		state += int(share >= at)
	return state


## The five steps of a state's ramp, deep to light.
func ramp_of(state: int) -> Array[Color]:
	var name := STATE_NAMES[clampi(state, 0, STATE_NAMES.size() - 1)]
	var out: Array[Color] = []
	for step: String in ["_deep", "_mid", "", "_shallow", "_light"]:
		out.append(_palette.get("water_" + name + step) as Color)
	return out


## The sky's two steps, high and low, for where the sun is.
func sky_at(at: float) -> Array[Color]:
	var out: Array[Color] = []
	for step: String in ["_high", "_low"]:
		var morning := _palette.get("sky_morning" + step) as Color
		var noon := _palette.get("sky_noon" + step) as Color
		var late := _palette.get("sky_afternoon" + step) as Color
		if at < 0.5:
			out.append(morning.lerp(noon, clampf(at / 0.5, 0.0, 1.0)))
		else:
			out.append(noon.lerp(late, clampf((at - 0.5) / 0.5, 0.0, 1.0)))
	return out


## The lake's box in this control, far shore to near.
func lake_box() -> Rect2:
	var near := snappedf(size.y * HORIZON, PIXEL)
	var tall := LAKE_TALL * PIXEL
	return Rect2(0.0, near - tall, size.x, tall)


func _draw() -> void:
	if not is_painted():
		draw_rect(Rect2(Vector2.ZERO, size), FALLBACK)
		return
	var lake := lake_box()
	var bank_tall := _bank.get_height() * PIXEL
	# The sky: flat steps from the high swatch down to the low one, the last standing behind
	# the treetops — spread over what the crowns leave showing, or the trees hide the lot.
	var sky := sky_at(sun)
	var bank_top := lake.position.y - bank_tall
	var open := maxf(bank_top + bank_tall * CROWNS_AT, PIXEL * SKY_STEPS)
	for k in SKY_STEPS:
		var from := snappedf(open * float(k) / float(SKY_STEPS), PIXEL)
		var to := lake.position.y
		if k < SKY_STEPS - 1:
			to = snappedf(open * float(k + 1) / float(SKY_STEPS), PIXEL)
		draw_rect(
			Rect2(0.0, from, size.x, to - from),
			sky[0].lerp(sky[1], float(k) / float(SKY_STEPS - 1))
		)
	_draw_clouds(open)
	_draw_water(lake)
	_tile(_bank, bank_top)
	# Over the far bank, not under it: a mast on the far lane stands up in front of the
	# trees, and drawn under the strip the hull sailed with its sail behind the sand.
	_draw_afloat(lake)
	_tile(_lawn, lake.end.y)
	_draw_dogs()
	_draw_birds()
	# Whatever a tall window leaves under the lawn strip: its last row, carried down.
	var lawn_end := lake.end.y + _lawn.get_height() * PIXEL
	if lawn_end < size.y:
		draw_rect(Rect2(0.0, lawn_end, size.x, size.y - lawn_end), _palette.grass_light)


func _draw_water(lake: Rect2) -> void:
	var state := state_of(filth)
	var ramp := ramp_of(state)
	var rows: Array = []
	var y := lake.position.y
	for k in BANDS.size():
		var tall := snappedf(lake.size.y * float(BANDS[k][0]), PIXEL)
		if k == BANDS.size() - 1:
			tall = lake.end.y - y
		draw_rect(Rect2(0.0, y, size.x, tall), ramp[int(BANDS[k][1])])
		rows.append([y, y + tall, int(BANDS[k][1])])
		y += tall
	var now := stepped()
	for k in _streaks.size():
		var streak: Vector3 = _streaks[k]
		# Rolled again every `STREAK_HOLD`, each on its own beat: in whole, out whole.
		var beat := int((now + streak.z * STREAK_HOLD) / STREAK_HOLD)
		if _hash(k, beat) > STREAK_SHOWN:
			continue
		var at_y := snappedf(lake.position.y + streak.y * (lake.size.y - PIXEL), PIXEL)
		var step := 0
		for row: Array in rows:
			if at_y >= float(row[0]) and at_y < float(row[1]):
				step = int(row[2])
		# Longer the nearer it is, and nearer is further down.
		var long := lerpf(STREAK_LONG.x, STREAK_LONG.y, streak.z * (0.3 + 0.7 * streak.y))
		draw_rect(
			Rect2(
				snappedf(
					fposmod(
						streak.x * size.x + now * lerpf(STREAK_PACE.x, STREAK_PACE.y, streak.y),
						size.x + 80.0
					) - 80.0, PIXEL
				), at_y, snappedf(long * PIXEL, PIXEL), PIXEL
			),
			ramp[mini(step + 1, ramp.size() - 1)]
		)
	var foam := _palette.foam_dirty if state >= FOAM_DIRTY_FROM else _palette.foam
	draw_rect(Rect2(0.0, lake.position.y, size.x, PIXEL), foam)
	# The near line laps: stretch by stretch it rides a painted pixel up the sand and back.
	var x := 0.0
	var span := 0
	while x < size.x:
		var up := PIXEL if sin(now * LAP_PACE * TAU + float(span) * 1.7) > 0.2 else 0.0
		draw_rect(Rect2(x, lake.end.y - PIXEL + up, LAP_LONG, PIXEL), foam)
		if up > 0.0:
			draw_rect(Rect2(x, lake.end.y - PIXEL, LAP_LONG, PIXEL), ramp[3])
		x += LAP_LONG
		span += 1


func _draw_clouds(sky_tall: float) -> void:
	if _cloud_art == null:
		return
	var now := stepped()
	var lap := size.x + 260.0
	for cloud: Array in _clouds:
		var layer: Array = CLOUD_LAYERS[int(cloud[0])]
		var box: Rect2 = _cloud_boxes[int(cloud[1])]
		var band: Vector2 = layer[3]
		var x := fposmod(float(cloud[2]) * lap + now * float(layer[1]), lap) - 240.0
		var y := sky_tall * lerpf(band.x, band.y, float(cloud[3]))
		draw_texture_rect_region(
			_cloud_art,
			Rect2(
				Vector2(snappedf(x, PIXEL), snappedf(y, PIXEL)),
				box.size * PIXEL * float(layer[2])
			),
			box
		)


## What is on the water, far to near: the rubbish and the hulls sorted together by their
## waterlines.
func _draw_afloat(lake: Rect2) -> void:
	var now := stepped()
	var rows: Array = []
	for k in flotsam_shown():
		var piece: Dictionary = _flotsam[k]
		var deep := lerpf(RUBBISH_BAND.x, RUBBISH_BAND.y, float(piece["deep"]))
		rows.append([lake.position.y + lake.size.y * deep, piece, deep])
	for hull in _hulls:
		if hull.wait <= 0.0:
			rows.append([lake.position.y + lake.size.y * float(BOAT_LANES[hull.lane][0]), hull, 0.0])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for row: Array in rows:
		var line := snappedf(float(row[0]), PIXEL)
		if row[1] is Hull:
			_draw_hull(row[1] as Hull, line)
			continue
		var piece: Dictionary = row[1]
		var art: Dictionary = rubbish[int(piece["kind"])]
		var region: Rect2 = art["region"]
		var grain := PIXEL if float(row[2]) >= RUBBISH_NEAR_FROM else PIXEL * 0.5
		# The bottom of the picture is under the water: not drawn, the dog's own way.
		var kept := Rect2(region.position, Vector2(region.size.x, ceilf(region.size.y * (1.0 - RUBBISH_SUNK))))
		var bob := grain if sin((now * BOB_PACE + float(piece["beat"])) * TAU) > 0.0 else 0.0
		var span := kept.size * grain
		var at := Vector2(snappedf(float(piece["across"]) * size.x, PIXEL), line - span.y + bob)
		if bool(piece["flip"]):
			draw_set_transform(Vector2(at.x * 2.0 + span.x, 0.0), 0.0, Vector2(-1.0, 1.0))
		draw_texture_rect_region(art["sheet"], Rect2(at, span), kept)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_collar(at.x, at.x + span.x, at.y + span.y, grain, int(piece["kind"]) + int(at.x))


func _draw_hull(hull: Hull, line: float) -> void:
	var art := hull_art(hull.way)
	if art.is_empty():
		return
	var grain := float(BOAT_LANES[hull.lane][1])
	var region: Rect2 = art["region"]
	var anchor: Vector2 = art["anchor"]
	var corner := Vector2(snappedf(hull.x, PIXEL), line) - Vector2(anchor.x, region.size.y) * grain
	draw_texture_rect_region(art["sheet"], Rect2(corner, region.size * grain), region)
	# Along the hull, not the whole picture: the cut's own ends where the json has them.
	var from := corner.x
	var to := corner.x + region.size.x * grain
	if art.has("waterline"):
		var ends: Vector2 = art["waterline"]
		from = corner.x + ends.x * grain
		to = corner.x + ends.y * grain
	_draw_collar(from, to, line, grain, 977 + hull.lane)


## A foam collar from `from` to `to` along the waterline at `line`, in pixels of `grain`.
func _draw_collar(from: float, to: float, line: float, grain: float, seed_at: int) -> void:
	var foam := _palette.foam_dirty if state_of(filth) >= FOAM_DIRTY_FROM else _palette.foam
	var beat := int(stepped() * FOAM_BEATS)
	var cells := int((to - from) / grain) + FOAM_PAST * 2
	for row in FOAM_ROWS.size():
		for k in cells:
			# The second row is pulled in from the ends: a collar, not a bar.
			if row > 0 and (k < 2 or k >= cells - 2):
				continue
			if _hash(seed_at * 31 + k, beat + row * 7) > float(FOAM_ROWS[row]):
				continue
			draw_rect(
				Rect2(
					snappedf(from, grain) + float(k - FOAM_PAST) * grain,
					line - grain + float(row) * grain, grain, grain
				),
				foam
			)


func _draw_dogs() -> void:
	var order := _dogs.duplicate()
	order.sort_custom(func(a: Hound, b: Hound) -> bool: return a.at.y < b.at.y)
	if shade.z > 0.0:
		var ink := Shade.tint(minf(shade.z * DOG_SHADE_GAIN, 0.6))
		for dog: Hound in order:
			draw_set_transform_matrix(
				Shade.lying(dog.at.snapped(Vector2.ONE * PIXEL), shade.x, shade.y)
			)
			DogArt.stamp(
				self, dog.pose, DogArt.frame_at(dog.pose, dog.age, dog.breed), Vector2.ZERO,
				_dog_tall(dog), dog.left, 0.0, ink, dog.breed
			)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for dog: Hound in order:
		DogArt.stamp(
			self, dog.pose, DogArt.frame_at(dog.pose, dog.age, dog.breed),
			dog.at.snapped(Vector2.ONE * PIXEL), _dog_tall(dog), dog.left, 0.0, Color.WHITE,
			dog.breed
		)


func _draw_birds() -> void:
	for bird in _birds:
		var fly: Array = bird.kind["fly"]
		var frame: Rect2 = fly[int(bird.age / FLAP) % fly.size()]
		Flock.stamp(
			self, bird_sheet, frame, _bird_at(bird).snapped(Vector2.ONE * PIXEL),
			bird_facing(bird), Color.WHITE
		)
	for puff: Array in _puffs:
		var gone := float(puff[1]) / PUFF_LIFE
		for k in PUFF_BITS:
			# Each bit goes out on its own beat, whole until then.
			if _hash(int(puff[2]) + k, 7) < gone:
				continue
			var turn := TAU * float(k) / float(PUFF_BITS) + _hash(int(puff[2]), k) * 1.5
			var at: Vector2 = puff[0] + Vector2(cos(turn), sin(turn) * 0.6) * (4.0 + 22.0 * gone)
			draw_rect(
				Rect2(at.snapped(Vector2.ONE * PIXEL), Vector2.ONE * PIXEL * 2.0), _palette.foam
			)


static func _hash(a: int, b: int) -> float:
	var h := (a * 374761393 + b * 668265263) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


## A strip laid across the window at `top`, as many times as the window is wide.
func _tile(strip: Texture2D, top: float) -> void:
	var box := Vector2(strip.get_width(), strip.get_height()) * PIXEL
	var x := 0.0
	while x < size.x:
		draw_texture_rect(strip, Rect2(Vector2(x, top), box), false)
		x += box.x

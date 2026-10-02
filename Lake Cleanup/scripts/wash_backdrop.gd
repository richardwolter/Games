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
const SKY_STEPS := 8
## The clouds: how many ride each layer, each layer's pace in canvas pixels a second, how
## big it draws, how far down the sky (as a share of it) its clouds' tops may sit, and which
## of the builder's sets it draws from. Far, small and slow, then the wisps high up, then
## the big near clouds (2026-09-28, the reference pass). A cloud's foot is held clear of the
## trees (`CLOUD_FOOT`): tall ones drew their base down on the treeline.
const CLOUD_LAYERS := [
	# A bank low along the horizon, sitting behind the wood (2026-10-02, Richard: lower and
	# more prominent, covering the skyline): far ones first, then the near clouds' bank.
	[12, 2.0, 1.0, Vector2(0.72, 1.0), "far_clouds"],
	[9, 2.6, 1.0, Vector2(0.55, 0.9), "clouds"],
	[3, 3.0, 1.0, Vector2(0.2, 0.5), "far_clouds"],
	[7, 4.0, 1.0, Vector2(0.02, 0.3), "wisps"],
	[3, 6.0, 1.0, Vector2(0.0, 0.2), "clouds"],
	[9, 5.0, 1.0, Vector2(0.0, 0.3), "clouds", true],
	[9, 4.2, 1.0, Vector2(-0.25, 0.1), "clouds", true],
	[10, 3.5, 1.0, Vector2(0.15, 0.55), "far_clouds", true],
]
## A storm (2026-09-28, Richard): as the shower rises the clouds sink into their shade
## (`STORM_INK` at full rain, multiplied over the picture, so white goes to grey-blue and the
## shade goes darker), and the layers flagged `true` above come in one cloud at a time, so the
## sky fills. The flash still lights the lot through the backdrop's modulate.
const STORM_INK := Color(0.36, 0.4, 0.48)
## The sky behind a storm: its steps sink towards `STORM_SKY` by `STORM_SKY_MIX` at full rain.
const STORM_SKY := Color(0.26, 0.3, 0.38)
const STORM_SKY_MIX := 0.85
## A flash lights the clouds from inside: their ink is pushed past white by up to
## `FLASH_CLOUD` at the strike's peak, so the shade lights up as much as the tops; the sky
## behind lifts by `FLASH_SKY`, less, so the clouds stand out against it.
const FLASH_CLOUD := Color(1.05, 1.08, 1.2)
const FLASH_SKY := 0.35
## (0.86 until 2026-10-02: the horizon bank stands with its foot behind the trees.)
const CLOUD_FOOT := 1.06
## The clouds in the wash room's lake: their picture mirrored under the far shore, squashed
## by `REFLECT_SQUASH`, broken into dashed rows and laid over the water at `REFLECT_MIX`.
## Only on clean water, the main lake's rule.
const REFLECT_SQUASH := 0.5
const REFLECT_MIX := 0.5
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

## Dogs: how far away they keep, in tiles (far on the island's sand, near behind the stand),
## a standing dog's height times its distance (so its drawn height is `DOG_SIZE / d`), their
## trot at the near end, how long they stop, and the jet's reach. A bolt is `DOG_BOLT` times
## the trot and at least `BOLT_LEAST` long.
const DOG_D := Vector2(7.0, 3.0)
const DOG_SIZE := 400.0
## (95 until 2026-10-02, Richard: the trot read slow for the legs.)
const DOG_PACE := 140.0
const DOG_REST := Vector2(1.5, 6.0)
const DOG_NEAR := 40.0
const DOG_BOLT := 2.3
const BOLT_LEAST := 320.0
const BARK_GAP := 2.0
const REST_POSES: Array[StringName] = [&"idle", &"idle", &"sit", &"laid", &"sleep"]

## Rubbish afloat: how many on a full lake, how far down the lake (as shares of it) they
## lie, how much of each is under water. Its grain follows its distance (`_grain_at`).
const RUBBISH_MOST := 40
const RUBBISH_SEED := 2909
const RUBBISH_BAND := Vector2(0.12, 0.94)
const RUBBISH_SUNK := 0.3
const BOB_PACE := 0.35
## Ferries: each lane's distance in tiles, its canvas pixels to a painted one, and its pace
## in canvas px a second. A hull crosses, waits out of sight `BOAT_WAIT`, and comes back the
## other way. The far lane at half the near one's grain and pace: twice as far is half the
## size and half the speed on the screen. A ferry is about a tile and a half long; by
## `y_at`'s sums that is about a hundred canvas pixels twelve tiles out.
const BOAT_LANES := [[26.0, 1.0, 30.0], [12.0, 2.0, 60.0]]
## The foam collar where a piece or a hull meets the water (Richard, same look: "it lacks
## the objects' foams"): the lake's own collar said in this grain — a torn row of whole foam
## pixels along the waterline and a thinner one under it, re-torn `FOAM_BEATS` times a
## second, the filthy foam on filthy water. How much of each row is there, and how far past
## the picture's ends it runs, in its own pixels.
const FOAM_BEATS := 2.0
const FOAM_ROWS := [0.75, 0.35]
const FOAM_PAST := 1
## The dogs throw the sun's shadow (`Shade.lying`, the day's lean, stretch and ink lent by
## the room as `shade`), in the one ink every shadow on land takes (`Shade.On.LAND`, 2026-10-02,
## one sun). It used to carry a gain of its own over the darkened lawn; it does not any more.
const BOAT_WAIT := Vector2(6.0, 20.0)
const BOAT_MARGIN := 140.0

const PIXEL := 2.0
## The view is a first-person perspective (2026-10-02, Richard: "like you really went to a
## first person perspective"): a point on the ground `d` tiles away stands at
## `y_at(d)` = the eye line plus `(1 - EYE) * NEAR_D / d` of the window, the window's foot
## being `NEAR_D` tiles out. Every distance in the view is one of these, in tiles: the
## island's lawn gives way to its sand at `LAWN_D` (just past the pallet), the near waterline
## is `SHORE_D` (the island's beach is 3.5 tiles wide), the far one `FAR_D` across the lake,
## the far bank's sand and trees just past it. So the far bank is a thin line low under the
## sky and its trees are small, the lake narrows towards it, and the near beach is broad.
const EYE := 0.43
const NEAR_D := 1.6
const LAWN_D := 4.0
const SHORE_D := 7.5
const FAR_D := 33.5
## The far bank's strip is drawn at one canvas pixel a painted one, half the near grain:
## at that distance the pack's trees stand about a tenth of the window tall.
const FAR_PIXEL := 1.0
const DARKEN := 0.66
## The sky and its clouds are left out of `DARKEN` (2026-09-28, Richard): it was there for
## the grime against the lawn, and it greyed the clouds' white. The ground, the water and
## everything on them are darkened by a black veil laid over them in `_draw`, from the far
## waterline down, and the far bank's strip is drawn at `DARKEN`; the birds and the rain are drawn over it.
##
## **What is drawn is `darken`, and `DARKEN` is only its default** (2026-09-30, the hive
## room): the hive room stands this same view behind its steps, and its pieces are the
## thing being looked at rather than grime that has to read against the lawn, so it veils
## less (0.82). The wash room never sets it and looks exactly as it did. The constant stays
## as the wash room's own number, so what the wash room is tuned to is still written down.
var darken := DARKEN
## How far the far bank's strip is slid along, in canvas pixels (2026-09-30, the hive
## room): the same trees in the same order behind the hive room read as standing at the
## pump, so the hive room shifts them to be somewhere else on the shore. Nought is the wash
## room's own view. Stepped to whole painted pixels, like everything else here.
var bank_offset := 0.0
## How far down the bank strip the treetops are, as a share of it: where the sky ends.
const CROWNS_AT := 0.12

## The palette's name for each water state, clean to dirty — `LakeGrid.water_state`'s order.
const STATE_NAMES: Array[String] = ["clean", "hazy", "murky", "foul", "dirty"]
## The lake from the far shore to the near one: a share of its height, and the ramp's step
## (0 deep to 4 light). Shallow at both shores, deep in the middle, and the far bands thinner
## than the near ones, which is all the perspective flat water has.
const BANDS := [[0.04, 3], [0.07, 2], [0.14, 1], [0.30, 0], [0.22, 1], [0.14, 2], [0.09, 3]]
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
		modulate = Color(tint.r, tint.g, tint.b)

## How many dogs are in the player's pack, and the flock's sheet and birds (`Flock.kinds`).
## Lent by the room; with none there are simply no dogs or no pigeons.
var pack := 1
var bird_sheet: Texture2D
var bird_kinds: Array[Dictionary] = []
## The day's shadow as (lean, stretch, ink); nought draws none.
var shade := Vector3.ZERO
## The pallet's box in this control, which the dogs keep behind or go round (2026-10-01,
## Richard: "dogs are running under the pallet, they should be around and behind"). The
## backdrop is drawn under the stand, so a dog whose feet are inside it is drawn under the
## pallet. Set by the room every frame; empty keeps nothing out.
var keep_out := Rect2()
## How far clear of the pallet a dog's feet stay, across and behind, in canvas px.
const KEEP_SIDE := 44.0
const KEEP_BEHIND := 6.0
## How many ferries the fleet holds, and the lake's rubbish as `{sheet, region}` rows.
var fleet := 1
var rubbish: Array = []

var _bank: Texture2D
var _lawn: Texture2D
var _cloud_art: Texture2D
var _cloud_boxes := {}
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
	## A corner of the pallet to go round on the way to `to`, or INF for a straight line.
	var via := Vector2.INF


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
	for key: String in ["clouds", "far_clouds", "wisps"]:
		var boxes: Array[Rect2] = []
		for box: Array in book.get(key, []):
			boxes.append(Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3])))
		_cloud_boxes[key] = boxes
	var roll := RandomNumberGenerator.new()
	roll.seed = CLOUD_SEED
	for layer in CLOUD_LAYERS.size():
		var set: Array = _cloud_boxes[CLOUD_LAYERS[layer][4]]
		if set.is_empty():
			continue
		var count := int(CLOUD_LAYERS[layer][0])
		for k in count:
			# Which picture, where across (a share of the lap, spread and then shoved), how
			# far down its layer's band.
			_clouds.append([
				layer, roll.randi() % set.size(),
				(float(k) + roll.randf_range(-0.3, 0.3)) / float(count), roll.randf(), k
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


var _bolt_seed := 0
var _bolt_x := -1.0
var _bolt_age := INF
var _last_flash := 0.0


func _process(delta: float) -> void:
	if is_visible_in_tree():
		step(delta)


## Is a bolt up this frame, for the harness.
func bolt_shown() -> bool:
	return _bolt_x >= 0.0 and Weather.flash_now > 0.05


## A flash rising past BOLT_FROM strikes a new bolt, unless the last is still within its hold.
func _strike_bolt(delta: float) -> void:
	_bolt_age += delta
	var flash := Weather.flash_now
	if flash >= BOLT_FROM and _last_flash < BOLT_FROM and _bolt_age > BOLT_HOLD:
		_bolt_seed = randi()
		_bolt_x = randf_range(BOLT_ACROSS.x, BOLT_ACROSS.y)
		_bolt_age = 0.0
	_last_flash = flash


## One frame. Its own function so a harness can run the clock by hand.
func step(delta: float) -> void:
	_clock += delta
	_strike_bolt(delta)
	# The shower greys the view as it greys the lake; the flash whitens it.
	var grey := Color.WHITE.lerp(RAIN_TINT, Weather.now).lerp(Color(1.5, 1.5, 1.6), Weather.flash_now)
	modulate = Color(tint.r * grey.r, tint.g * grey.g, tint.b * grey.b)
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
		# Never less than the dog's own body: a far dog is small, but a jet on it is on it.
		var reach := maxf(DOG_NEAR * _dog_tall(dog) / (DOG_SIZE / DOG_D.y), _dog_tall(dog) * 0.6)
		if dog.bolting or (dog.at - Vector2(0.0, _dog_tall(dog) * 0.5)).distance_to(point) > reach:
			continue
		# Away from the jet, a good way, along the lawn.
		var away := -1.0 if point.x > dog.at.x else 1.0
		dog.bolting = true
		dog.rest = 0.0
		dog.pose = &"run"
		_aim(dog, Vector2(
			clampf(dog.at.x + away * maxf(BOLT_LEAST, size.x * 0.3), -80.0, size.x + 80.0),
			dog.at.y
		))
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
	return DOG_SIZE / lerpf(DOG_D.x, DOG_D.y, dog.depth)


func _lawn_y(depth: float) -> float:
	return y_at(lerpf(DOG_D.x, DOG_D.y, depth))


## Where the ground `d` tiles away stands down the window (see `EYE`).
func y_at(d: float) -> float:
	return size.y * (EYE + (1.0 - EYE) * NEAR_D / maxf(d, 0.01))


## How far away the ground at row `y` is, in tiles: `y_at` the other way.
func d_at(y: float) -> float:
	return (1.0 - EYE) * NEAR_D * size.y / maxf(y - EYE * size.y, 0.01)


## A thing on the water `d` tiles away is drawn at this many canvas pixels a painted one.
static func _grain_at(d: float) -> float:
	return PIXEL if d < 16.0 else 1.0


## Somewhere new to trot to: mostly along the lawn, a little nearer or further.
func _send(dog: Hound) -> void:
	if dog.at.y == 0.0:
		dog.at.y = _lawn_y(dog.depth)
	var depth := clampf(dog.depth + _roll.randf_range(-0.3, 0.3), 0.0, 1.0)
	_aim(dog, Vector2(_roll.randf_range(0.04, 0.96) * size.x, _lawn_y(depth)))
	dog.left = dog.to.x < dog.at.x
	dog.pose = DogArt.gait(dog.slot, false, dog.breed) if DogArt.has(&"run", dog.breed) else &"idle"
	dog.rest = 0.0
	dog.bolting = false


func _drive_dogs(delta: float) -> void:
	var out := _kept_out()
	for dog in _dogs:
		dog.age += delta
		# A dog laid out before the room knew where the pallet was stands behind it.
		if out.size.x > 0.0 and out.has_point(dog.at) and dog.via == Vector2.INF:
			dog.at.y = out.position.y
			if out.has_point(dog.to):
				dog.to.y = out.position.y
		if dog.rest > 0.0:
			dog.rest -= delta
			if dog.rest <= 0.0:
				_send(dog)
			continue
		var pace := DOG_PACE * (DOG_BOLT if dog.bolting else 1.0) * _dog_tall(dog) / (DOG_SIZE / DOG_D.y)
		var going := dog.to if dog.via == Vector2.INF else dog.via
		dog.at = dog.at.move_toward(going, pace * delta)
		if dog.via != Vector2.INF and dog.at.distance_to(dog.via) < 1.0:
			dog.via = Vector2.INF
			continue
		# How big it draws follows where it is, all the way there.
		dog.depth = clampf(inverse_lerp(_lawn_y(0.0), _lawn_y(1.0), dog.at.y), 0.0, 1.0)
		if dog.at.distance_to(dog.to) < 1.0:
			dog.bolting = false
			dog.rest = _roll.randf_range(DOG_REST.x, DOG_REST.y)
			var pose: StringName = REST_POSES[_roll.randi() % REST_POSES.size()]
			dog.pose = pose if DogArt.has(pose, dog.breed) else &"idle"
			dog.age = 0.0


## The pallet grown by a dog's clearance: behind it, and either side of it.
func _kept_out() -> Rect2:
	if keep_out.size.x <= 0.0:
		return Rect2()
	return keep_out.grow_individual(KEEP_SIDE, KEEP_BEHIND, KEEP_SIDE, size.y)


## Send a dog to `spot`, kept off the pallet: a spot inside it is moved behind it, and a
## straight line through it goes by the nearer of its two back corners instead.
func _aim(dog: Hound, spot: Vector2) -> void:
	dog.via = Vector2.INF
	var out := _kept_out()
	if out.size.x <= 0.0:
		dog.to = spot
		return
	if out.has_point(spot):
		spot.y = out.position.y
	dog.to = spot
	if _crosses(dog.at, spot, out):
		var left := Vector2(out.position.x, out.position.y)
		var right := Vector2(out.end.x, out.position.y)
		var by_left := dog.at.distance_to(left) + left.distance_to(spot)
		var by_right := dog.at.distance_to(right) + right.distance_to(spot)
		dog.via = left if by_left <= by_right else right
	dog.left = (dog.to if dog.via == Vector2.INF else dog.via).x < dog.at.x


## Whether the segment from `a` to `b` passes through the box (sampled: the box is big and
## the dogs' legs are short, so a handful of points is plenty).
static func _crosses(a: Vector2, b: Vector2, box: Rect2) -> bool:
	for k in range(1, 24):
		if box.has_point(a.lerp(b, float(k) / 24.0)):
			return true
	return false


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
	var near := snappedf(y_at(SHORE_D), PIXEL)
	var far := snappedf(y_at(FAR_D), PIXEL)
	return Rect2(0.0, far, size.x, near - far)


func _draw() -> void:
	if not is_painted():
		draw_rect(Rect2(Vector2.ZERO, size), FALLBACK)
		return
	var lake := lake_box()
	var bank_tall := _bank.get_height() * FAR_PIXEL
	# The sky: flat steps from the high swatch down to the low one, the last standing behind
	# the treetops — spread over what the crowns leave showing, or the trees hide the lot.
	var sky := sky_at(sun)
	var bank_top := lake.position.y - bank_tall
	var open := maxf(bank_top + bank_tall * CROWNS_AT, PIXEL * SKY_STEPS)
	var steps: Array[Color] = []
	var edges: Array[float] = []
	for k in SKY_STEPS:
		var from := snappedf(open * float(k) / float(SKY_STEPS), PIXEL)
		var to := lake.position.y
		if k < SKY_STEPS - 1:
			to = snappedf(open * float(k + 1) / float(SKY_STEPS), PIXEL)
		var step := sky[0].lerp(sky[1], float(k) / float(SKY_STEPS - 1))
		step = step.lerp(STORM_SKY, clampf(Weather.now, 0.0, 1.0) * STORM_SKY_MIX)
		step = step.lerp(Color(0.85, 0.87, 0.95), _flash_lit() * FLASH_SKY)
		draw_rect(Rect2(0.0, from, size.x, to - from), step)
		steps.append(step)
		edges.append(to)
	_blend_sky(steps, edges)
	_draw_clouds(open)
	_draw_bolt(bank_top + bank_tall * CROWNS_AT)
	_draw_water(lake)
	_draw_cloud_reflections(open, lake)
	_tile(_bank, bank_top, Color(darken, darken, darken), bank_offset, FAR_PIXEL)
	# Over the far bank, not under it: a mast on the far lane stands up in front of the
	# trees, and drawn under the strip the hull sailed with its sail behind the sand.
	_draw_afloat(lake)
	_tile(_lawn, lake.end.y)
	_draw_dogs()
	# The veil: `darken` over the ground and the water, not the sky.
	draw_rect(Rect2(0.0, lake.position.y, size.x, size.y - lake.position.y), Color(0.0, 0.0, 0.0, 1.0 - darken))
	_draw_birds()
	_draw_rain(lake)
	# Whatever a tall window leaves under the lawn strip: its last row, carried down.
	var lawn_end := lake.end.y + _lawn.get_height() * PIXEL
	if lawn_end < size.y:
		draw_rect(Rect2(0.0, lawn_end, size.x, size.y - lawn_end), _palette.grass_light * Color(darken, darken, darken))


## The sky's steps run into each other through a pixel-art dither (2026-10-02, Richard: "the
## seams on the skyline are too visible"): across every edge, `SKY_BLEND` bands of whole
## painted pixels, each the next step's colour laid at a quarter, a half and three quarters
## through a 2x2 ordered pattern, so a step gives way to the next in a run of checks rather
## than at a line. The pattern is a tiny texture tiled across the window, one draw a band.
const SKY_BLEND := 2
var _dither: Array[Texture2D] = []


func _dither_tile(level: int) -> Texture2D:
	if _dither.is_empty():
		# 2x2 Bayer cells, PIXEL canvas px each: which cells are lit at a quarter, a half,
		# three quarters.
		var lit := [[Vector2i(0, 0)], [Vector2i(0, 0), Vector2i(1, 1)],
				[Vector2i(0, 0), Vector2i(1, 1), Vector2i(1, 0)]]
		var cell := int(PIXEL)
		for cells: Array in lit:
			var image := Image.create(cell * 2, cell * 2, false, Image.FORMAT_RGBA8)
			for at: Vector2i in cells:
				image.fill_rect(Rect2i(at * cell, Vector2i(cell, cell)), Color.WHITE)
			_dither.append(ImageTexture.create_from_image(image))
	return _dither[level]


func _blend_sky(steps: Array[Color], edges: Array[float]) -> void:
	var band := PIXEL * 2.0
	for k in steps.size() - 1:
		var edge := edges[k]
		var upper := steps[k]
		var lower := steps[k + 1]
		# Above the edge: the lower colour coming in at a quarter, then a half.
		for b in SKY_BLEND:
			var y := edge - band * float(SKY_BLEND - b)
			draw_texture_rect(_dither_tile(b), Rect2(0.0, y, size.x, band), true, lower)
		# Below it: the upper colour going out at a half, then a quarter.
		for b in SKY_BLEND:
			var y := edge + band * float(b)
			draw_texture_rect(_dither_tile(SKY_BLEND - 1 - b), Rect2(0.0, y, size.x, band), true, upper)


## The rain over the view from the pump (2026-09-25, see `Weather`): it reads the lake's
## shower through `Weather.now` rather than being handed one, so the room needs no wiring.
## No drop is kept: each is a hash of its index and the clock, so the rain costs nothing but
## the drawing. Rings open on the water where drops land, on the stepped clock.
const RAIN_DROPS := 150
const RAIN_SPEED := 520.0
const RAIN_RINGS := 22
const RAIN_TINT := Color(0.66, 0.72, 0.82)

## A bolt of lightning over the far bank on each flash (2026-09-25, Richard: "if player is
## washing and it's raining, they should see lightning"). **The only bolt in the game**: the
## lake keeps its flash without one, by the rain pass's own decision. A jagged run of whole
## painted pixels from the top of the sky down to the treeline, with a branch or two, rolled
## once a strike and shown for as long as the flash lasts. The echo pulse relights the same
## bolt rather than rolling a second one (`BOLT_HOLD`).
const BOLT_INK := Color(0.96, 0.95, 1.0)
const BOLT_GLOW := Color(0.78, 0.8, 1.0, 0.45)
const BOLT_FROM := 0.25
const BOLT_HOLD := 0.6
const BOLT_STEPS := 14
const BOLT_ACROSS := Vector2(0.12, 0.88)


func _draw_bolt(foot: float) -> void:
	if not bolt_shown():
		return
	var lit := clampf(Weather.flash_now / Weather.FLASH_PEAK, 0.0, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = _bolt_seed
	var at := Vector2(snappedf(_bolt_x * size.x, PIXEL), 0.0)
	var drop := maxf(foot, PIXEL * 4.0) / float(BOLT_STEPS)
	var branches := 0
	for i in BOLT_STEPS:
		var to := Vector2(at.x + snappedf(rng.randf_range(-3.0, 3.0), 1.0) * PIXEL, snappedf(drop * float(i + 1), PIXEL))
		_bolt_run(at, to, lit, 2.0)
		if branches < 2 and i > 2 and i < BOLT_STEPS - 3 and rng.randf() < 0.22:
			branches += 1
			var b := to
			var way := -1.0 if rng.randf() < 0.5 else 1.0
			for k in rng.randi_range(2, 4):
				var bt := Vector2(b.x + way * snappedf(rng.randf_range(1.0, 3.0), 1.0) * PIXEL, b.y + snappedf(drop * 0.7, PIXEL))
				_bolt_run(b, bt, lit * 0.7, 1.0)
				b = bt
		at = to


## One leg of a bolt as whole painted pixels, a softer glow a pixel either side.
func _bolt_run(a: Vector2, b: Vector2, lit: float, wide: float) -> void:
	var n := maxi(int(maxf(absf(b.x - a.x), absf(b.y - a.y)) / PIXEL), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / float(n)).snapped(Vector2(PIXEL, PIXEL))
		draw_rect(Rect2(p - Vector2(PIXEL, 0.0), Vector2(PIXEL * (wide + 2.0), PIXEL)), Color(BOLT_GLOW, BOLT_GLOW.a * lit))
		draw_rect(Rect2(p, Vector2(PIXEL * wide, PIXEL)), Color(BOLT_INK, lit))


func _draw_rain(lake: Rect2) -> void:
	var rain := Weather.now
	if rain <= 0.0:
		return
	var pale := Color(_palette.foam_light, 0.55)
	var cell := Vector2(PIXEL, PIXEL)
	var drops := int(RAIN_DROPS * rain)
	var tall := size.y + 40.0
	for k in drops:
		var y := fposmod(_hash(k, 7) * tall + _clock * RAIN_SPEED * (0.8 + 0.4 * _hash(k, 9)), tall) - 20.0
		var x := fposmod(_hash(k, 8) * (size.x + 60.0) - y * 0.22, size.x + 60.0) - 30.0
		for step in 4:
			var at := Vector2(x + float(step) * PIXEL * 0.35, y - float(step) * PIXEL * 1.6)
			draw_rect(Rect2(at.snapped(cell), cell), pale if step < 2 else Color(pale, 0.25))
	var now := stepped()
	var ring_ink := Color(_palette.foam_light, 0.5)
	for k in int(RAIN_RINGS * rain):
		var beat := int(now * 2.5 + _hash(k, 3) * 4.0)
		var age := fposmod(now * 2.5 + _hash(k, 3) * 4.0, 1.0)
		var at := Vector2(
			_hash(k, beat) * size.x,
			lake.position.y + (0.25 + 0.75 * _hash(k, beat + 11)) * lake.size.y
		)
		var span := (2.0 + age * 5.0) * PIXEL
		for side in [-1.0, 1.0]:
			draw_rect(Rect2((at + Vector2(side * span, 0.0)).snapped(cell), cell),
				Color(ring_ink, ring_ink.a * (1.0 - age)))
		draw_rect(Rect2((at + Vector2(-span * 0.5, -PIXEL)).snapped(cell),
			Vector2(snappedf(span, PIXEL), PIXEL)), Color(ring_ink, ring_ink.a * 0.5 * (1.0 - age)))


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


## Where a cloud is drawn, and its picture's rectangle on the sheet.
func _cloud_rect(cloud: Array, sky_tall: float) -> Array:
	var layer: Array = CLOUD_LAYERS[int(cloud[0])]
	var box: Rect2 = (_cloud_boxes[layer[4]] as Array)[int(cloud[1])]
	var band: Vector2 = layer[3]
	var lap := size.x + 520.0
	var drawn := box.size * PIXEL * float(layer[2])
	var x := fposmod(float(cloud[2]) * lap + stepped() * float(layer[1]), lap) - 500.0
	var y := minf(sky_tall * lerpf(band.x, band.y, float(cloud[3])), sky_tall * CLOUD_FOOT - drawn.y)
	return [Rect2(Vector2(snappedf(x, PIXEL), snappedf(maxf(y, 0.0), PIXEL)), drawn), box]


func _draw_clouds(sky_tall: float) -> void:
	if _cloud_art == null:
		return
	var rain := clampf(Weather.now, 0.0, 1.0)
	var ink := Color.WHITE.lerp(STORM_INK, rain).lerp(FLASH_CLOUD, _flash_lit())
	for cloud: Array in _clouds:
		var shown := _cloud_shown(cloud, rain)
		if shown <= 0.0:
			continue
		var at := _cloud_rect(cloud, sky_tall)
		draw_texture_rect_region(_cloud_art, at[0], at[1], Color(ink, shown))


## How lit the storm is by lightning, 0 to 1.
func _flash_lit() -> float:
	return clampf(Weather.flash_now / Weather.FLASH_PEAK, 0.0, 1.0)


## How much of a cloud shows: fair-weather ones always, a storm layer's one at a time as the
## rain rises, each easing in over a slice of it.
func _cloud_shown(cloud: Array, rain: float) -> float:
	var layer: Array = CLOUD_LAYERS[int(cloud[0])]
	if layer.size() < 6 or not bool(layer[5]):
		return 1.0
	var count := float(layer[0])
	var k := float(cloud[4])
	return clampf((rain * count - k) * 1.5, 0.0, 1.0)


## The clouds in the lake: each near cloud's picture flipped under the far shore and cut
## into dashed rows, only while the water reads clean.
func _draw_cloud_reflections(sky_tall: float, lake: Rect2) -> void:
	if _cloud_art == null or state_of(filth) != 0:
		return
	var horizon := lake.position.y
	for cloud: Array in _clouds:
		if _cloud_shown(cloud, clampf(Weather.now, 0.0, 1.0)) <= 0.0:
			continue
		var at: Array = _cloud_rect(cloud, sky_tall)
		var drawn: Rect2 = at[0]
		var box: Rect2 = at[1]
		var from := horizon + (horizon - drawn.end.y) * REFLECT_SQUASH * 0.5
		var tall := drawn.size.y * REFLECT_SQUASH
		var rows := int(tall / PIXEL)
		for r in rows:
			if r % 2 == 1:
				continue
			var y := snappedf(from + float(r) * PIXEL, PIXEL)
			if y < horizon + PIXEL or y >= lake.end.y - PIXEL:
				continue
			# Bottom of the cloud first: a mirror turns it over.
			var src_y := box.end.y - 1.0 - floorf(float(r) / float(rows) * box.size.y)
			var seg := 0.0
			while seg < drawn.size.x:
				var long := PIXEL * 4.0
				if _hash(int(seg / long) + int(cloud[1]) * 97, int(y)) > 0.4:
					var src_x := box.position.x + floorf(seg / drawn.size.x * box.size.x)
					draw_texture_rect_region(
						_cloud_art,
						Rect2(drawn.position.x + seg, y, long, PIXEL),
						Rect2(src_x, src_y, maxf(box.size.x * long / drawn.size.x, 1.0), 1.0),
						Color(1, 1, 1, REFLECT_MIX)
					)
				seg += long


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
			rows.append([y_at(float(BOAT_LANES[hull.lane][0])), hull, 0.0])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for row: Array in rows:
		var line := snappedf(float(row[0]), PIXEL)
		if row[1] is Hull:
			_draw_hull(row[1] as Hull, line)
			continue
		var piece: Dictionary = row[1]
		var art: Dictionary = rubbish[int(piece["kind"])]
		var region: Rect2 = art["region"]
		var grain := _grain_at(d_at(float(row[0])))
		# The bottom of the picture is under the water: not drawn, the dog's own way.
		var kept := Rect2(region.position, Vector2(region.size.x, ceilf(region.size.y * (1.0 - RUBBISH_SUNK))))
		var bob := grain if sin((now * BOB_PACE + float(piece["beat"])) * TAU) > 0.0 else 0.0
		var span := kept.size * grain
		var at := Vector2(snappedf(float(piece["across"]) * size.x, PIXEL), line - span.y + snappedf(bob, 1.0))
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
		var ink := Shade.tint(Shade.ink_on(shade.z, Shade.On.LAND))
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


## A strip laid across the window at `top`, as many times as the window is wide, slid
## `offset` canvas pixels along (whole painted pixels; the strips wrap, so any slide is a
## seamless one).
func _tile(strip: Texture2D, top: float, ink := Color.WHITE, offset := 0.0, grain := PIXEL) -> void:
	var box := Vector2(strip.get_width(), strip.get_height()) * grain
	var x := -snappedf(fposmod(offset, box.x), grain)
	while x < size.x:
		draw_texture_rect(strip, Rect2(Vector2(x, top), box), false, ink)
		x += box.x

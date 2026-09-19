## The wash stand: one find under a coat of grime, and a jet to take the coat off with.
##
## Issue #37, `/grill-me` with Richard 2026-09-18. A find has to be washed before it can go in
## the shed, and this is the washing: the restored picture stands on a wooden stand, a coat of
## grime lies over it, and holding the button sprays water where the pointer is. The spray
## wears the coat away, what it loosens runs down the piece in dirty trickles, off along
## the stand and onto the floor, and once most of it is gone the rest rinses off by itself.
##
## **Drawn only, like the net's rope.** No bodies, no collision, no engine particles: the
## droplets, the spray and the trickles are lists of cells stepped by hand, and the only
## thing anything reads back out of here is how much grime is left. This is not the physics
## the project banned.
##
## **The grime is made, not painted**: a noise rolled off the find's own name, heavier low
## down and along the silhouette's edges, in the lake's own filthy swatches. The lake's dirty
## sprite is not used here at all — it is a different drawing at a different size from the
## restored one, and there is nothing to reveal one from under the other.
##
## **Nothing here knows about money, the queue or the save.** It is handed a piece, it says
## when the piece is clean. `tools/wash_spike.tscn` hosts it on its own for judging the feel.
class_name WashStand
extends Control

const Style := preload("res://scripts/style.gd")

## The piece has come clean: the rinse has run and the shine has started.
signal washed(piece: StringName)

## Grime cells to one painted pixel, each way. At 1 the coat comes off in the art's own
## pixels, which at seven or eight screen pixels apiece is a handful of blocks a second; at 2
## the jet has an edge worth looking at. **A knob for Richard's eye**: 2 mixes two pixel
## sizes on one picture, and 1 is the purist's answer.
const FINE := 2

## The room the piece is fitted into, as shares of this control, and how far down the stand's
## top stands. The zoom is the largest whole number of canvas pixels to a painted one that
## fits, held between the two ends.
const ROOM_WIDE := 0.46
## The stand came up from 0.72 (Richard, 2026-09-19: "a bit further away from the hose"),
## and the piece's room came in with it so a tall find still clears the top of the screen.
const ROOM_TALL := 0.5
const STAND_AT := 0.63
const ZOOM_LEAST := 2
const ZOOM_MOST := 14

## The jet, in painted pixels and grime a second. At the middle of the jet the thickest coat
## there is comes off in under half a second; at its edge, not at all.
const JET_RADIUS := 3.2
const JET_POWER := 2.6
## How long the water takes to get from the nozzle to where it is aimed, and to stop arriving
## once the button is let go. Short enough not to be a delay, long enough to be seen.
const JET_TRAVEL := 0.07

## A cell is drawn in one of four steps and these are the three lines between them: clear,
## a thin stain, a film, and solid scum. Hard steps, no dither, the water's own rule.
const THIN_AT := 0.14
const FILM_AT := 0.40
const SCUM_AT := 0.70
const THIN_ALPHA := 0.3
const FILM_ALPHA := 0.78

## The coat as it is rolled: nothing on the piece is cleaner than `COAT_LEAST`, which is a
## film already — grimier than the lake ever showed it, by decision.
const COAT_LEAST := 0.42
const COAT_MID := 0.66
const COAT_SWING := 0.5
const COAT_LOW := 0.2
const COAT_EDGE := 0.16
const COAT_GRAIN := 0.12

## Washed this far, the rest goes by itself. PowerWash's known pain is hunting the last two
## percent, and nobody is to be sent looking for a pixel.
const DONE_AT := 0.99
const RINSE_TIME := 0.7
const SHINE_TIME := 1.6

## Trickles. One dirty one is let go for every `RUN_PER` of grime the jet loosens; clear ones
## at `RUN_CLEAR` a second while the jet is on the piece at all. A trickle wears a little of
## what it runs over away, which is what cuts the clean streaks under a sprayed patch.
const RUN_PER := 2.2
const RUN_CLEAR := 5.0
const RUN_MOST := 110
const RUN_PACE := Vector2(16.0, 34.0)
const RUN_TRAIL := 6
const RUN_WASH := 0.07
const RUN_WANDER := 0.35
const RUN_LIFE := 7.0
const FALL_PULL := 190.0

## Spray, in cells a second. It comes off dirty while there is grime under the jet and white
## once there is not — the honest answer to "is this bit done".
const SPRAY_ON := 95.0
const SPRAY_OFF := 30.0
const SPRAY_MOST := 260
const SPRAY_SPEED := Vector2(18.0, 78.0)
const SPRAY_LIFE := Vector2(0.16, 0.46)
const SPRAY_PULL := 170.0
const SPRAY_DIRTY_OVER := 0.3

## The bubbles a cell leaves as it comes clean: the foam's own way of going, whole and then
## not there, rather than fading.
const BUBBLE_ODDS := 0.4
const BUBBLE_LIFE := Vector2(0.10, 0.28)
const BUBBLE_MOST := 220

## How far the stand's top runs past the piece each side, in cells, and how much faster a
## drop slides along the wood than it ran down the piece. **Nothing rests on the stand**
## (Richard, 2026-09-19: the puddle under the piece looked bad): a drop that lands runs to
## the nearer end, falls off it and is gone on the floor.
##
## **The table is one size whatever is on it** (Richard, 2026-09-19: "the table should be
## always the same size, not switch between different objects"). It was the piece's own
## width plus `STAND_PAD` cells each side, so it grew and shrank with every find put on it —
## furniture changing size between objects. Now `STAND_WIDE` of the window, a little over
## the `ROOM_WIDE` the widest find is fitted to, and the drops slide to *its* ends
## (`_stand_pad`), which is how far past the piece the wood runs for this piece, in cells.
const STAND_WIDE := 0.54
const SLIDE_PACE := 1.5
## And over the front of it (Richard, same day): some of what lands goes straight over the
## near edge, and a drop sliding along may turn over it at any cell. It creeps down the
## plank's face at `FRONT_CREEP` of its pace, then lets go and falls.
const FRONT_ON_LANDING := 0.35
const FRONT_A_CELL := 0.05
const FRONT_CREEP := 0.55
const STAND_TALL := 20.0
const FLOOR_AT := 0.9

## How many times a second the patterns step: the stream's dashes, the impact's froth, the
## nozzle's shake. The lake's foam runs on the same idea.
const PIXEL_FPS := 14.0

## The nozzle: a brass fireman's nozzle on an oak grip, **one baked picture per heading**
## (`tools/build_nozzle.py`, `assets/nozzle.json`), never a picture turned at runtime —
## Richard, 2026-09-19: the drawn one was "ugly and blocky, not pixel art", and what made it
## so was being rotated. The nearest heading to the aim is drawn, on whole art pixels.
## `NOZZLE_SCALE` canvas pixels to a painted one, whatever the piece's own zoom; the pivot
## stands `NOZZLE_RISE` painted pixels above the bottom of the screen, which is how much
## hose shows.
const NOZZLE_ART := "res://assets/nozzle.png"
const NOZZLE_CONTRACT := "res://assets/nozzle.json"
const NOZZLE_SCALE := 4.0
const NOZZLE_RISE := 17.0
## **One drawing, the straight one, and it glides** (Richard, 2026-09-19, second look: a
## picture that changed with every move read as a different nozzle each time, and the
## movement was stiff). So it never turns: it slides under the pointer, eased rather than
## pinned to it, rises a little when the aim is high, and moves between art pixels the way
## everything that moves on the lake does — by the lake's own decision, stepping a moving
## thing on the pixel grid is what reads as stiff.
const NOZZLE_FOLLOW := 0.5
const NOZZLE_EASE := 9.0
## **It points where it sprays**, eased, so it swings over rather than snapping: the same
## picture turned in fine baked steps (the builder's `turned`), never lit or cut afresh. It
## follows the pointer only half way across now, which is what gives it something to point at.
const NOZZLE_TURN_EASE := 11.0
const NOZZLE_LIFT := 3.0
const NOZZLE_KICK := 1.5
const NOZZLE_KICK_TIME := 0.05
const NOZZLE_SHAKE := 0.5
## Its life: back along its heading while it sprays, with a tremble on the pattern's
## clock; breathing up and down at rest; beads that hang on the lip when
## the button is let go, and fall; and a glint that runs the brass now and then when the
## button goes down, and once when the piece comes clean.
const NOZZLE_BOB := 1.4
const BEADS := Vector2i(1, 2)
const BEAD_HANGS := Vector2(0.22, 0.7)
const BEAD_PULL := 1500.0
const GLINT_TIME := 0.32
const GLINT_REST := 1.6
## The hose is not in the picture: **it is laid out every frame**, from the grip's foot to a
## point under the screen, so it curves with where the nozzle is held and its belly trails
## behind a nozzle that moves (Richard, 2026-09-19: the single straight picture "lost the
## curving", and the curve was the part with the life in it). Drawn only, the rope's own
## bargain: a curve walked in art pixels, each given the builder's own canvas tones by how
## far round towards the light it is, ringed in the builder's own edge colour. Its grid is
## the nozzle picture's own, so the two meet pixel on pixel.
## `HOSE_SIDE` is what keeps a curve in it when the nozzle is dead centre: the hose comes up
## from one side of the hand, not from straight under it. In painted pixels, like
## `HOSE_UNDER`, which is how far under the screen's edge it is anchored — shallow, so the
## bend happens where it can be seen.
const HOSE_UNDER := 10.0
const HOSE_SIDE := -17.0
const HOSE_ANCHOR := 0.25
const HOSE_REACH := 0.5
const HOSE_BELLY := 0.8
const HOSE_EASE := 3.5
const HOSE_LIT_OVER := 0.3
const HOSE_DARK_UNDER := -0.35
## What is drawn when the sheet is missing: the old line, so the jet still has a source.
const PLAIN_LONG := 120.0
const PLAIN_UNDER := 34.0
const PLAIN_METAL := Color(0.26, 0.29, 0.31)
const PLAIN_BRASS := Color(0.78, 0.60, 0.26)

## The room behind, **when nothing else is**: `WashRoom` lays a `WashBackdrop` under the
## stand and turns `bare_room` off; the stand on its own (`tools/wash_spike`) keeps the flat
## wall so it is never drawn over nothing.
const WALL := Color(0.07, 0.13, 0.14)
const FLOOR := Color(0.05, 0.09, 0.10)
const MUD := Color(0.24, 0.19, 0.12)

## The jet: Nuven's recording of a hose (2026-09-19), cut to a seamless loop and levelled by
## `tools/build_sfx.py` (`hose_spray`). Duller on the piece, brighter off it — the ear's
## version of "am I hitting it" — **but narrowly**: the code-built noise it replaces swung
## 0.92 to 1.22, and a real recording pitched that far is a different hose. By-ear knobs.
## The noise is still built when the file is missing, so the jet is never silent.
const HISS_TAKE := "res://assets/sfx/hose_spray.ogg"
const HISS_DB := -13.0
const HISS_RATE := 22050
const HISS_LENGTH := 1.2
const HISS_ON_PIECE := 0.96
const HISS_OFF_PIECE := 1.06

enum State { EMPTY, WASHING, RINSING, SHINING, CLEAN }


class Run:
	var at := Vector2i.ZERO
	var y := 0.0
	var pace := 24.0
	var bank := 0.0
	var dirt := 0.0
	var age := 0.0
	var falling := false
	var fall := 0.0
	## On the stand's top, and which way along it; and off its end, bound for the floor.
	var sliding := 0
	var off := false
	var trail: Array[Vector2i] = []


class Fleck:
	var at := Vector2.ZERO
	var going := Vector2.ZERO
	var age := 0.0
	var span := 0.3
	var dirty := false


var sheets: Sheets
var piece := &""
var state := State.EMPTY

var _art: Image
var _region := Rect2()
var _cols := 0
var _rows := 0
var _zoom := 4
var _cell := 2.0
var _origin := Vector2.ZERO

var _solid := PackedByteArray()
var _grime := PackedFloat32Array()
var _total := 0.0
var _left := 0.0
var _coat: Image
var _coat_tex: ImageTexture
var _coat_stale := false

var _firing := false
var _aim := Vector2.ZERO
var _reach := 0.0
var _tail := 1.0
var _hitting := false
var _under := 0.0
var _loosened := 0.0
var _clear_bank := 0.0
var _spray_bank := 0.0

## Whether the stand draws its own flat wall and floor. See `WALL`.
var bare_room := true
## **The stand belongs to the lawn it is on** (2026-09-19, Richard: "better integrate the
## stand to that point of view"; grounding it was picked over redrawing it as a table seen
## from above, which would have meant re-fitting every drip). Two things, both the hut's
## own: blades of grass grown over each leg's foot (`Skirt`'s idea, drawn here because a
## hem is measured off an image and the stand is drawn planks), and the sun's shadow of the
## stand and the find lying down the lawn (`Shade.lying`, leaning and stretching with the
## day). The room lends the lawn's tone — the backdrop is darkened and day-tinted and the
## stand is not, so blades in the palette's own greens would glow — and the day's shadow as
## (lean, stretch, ink). With neither, neither is drawn.
var ground_tone := Color.WHITE
var shade := Vector3.ZERO
const TUFT_PIXEL := 2.0
const TUFT_REACH := 9.0
const TUFT_BLADES := 9
const TUFT_TALL := Vector2i(2, 6)
const SHADE_GAIN := 1.6

var _runs: Array[Run] = []
var _flecks: Array[Fleck] = []
var _bubbles: Array = []
var _stars: Array = []

var _clock := 0.0
var _tick := 0
var _phase := 0.0
var _rinsed_to := 0
var _roll := RandomNumberGenerator.new()
var _hiss: AudioStreamPlayer
var _nozzle_art: Texture2D
var _nozzle_frames: Array = []
var _nozzle_step := 10.0
var _was_firing := false
var _beads: Array = []
var _glint := 1.0
var _glint_rest := 0.0
var _nozzle_pos := Vector2.ZERO
var _nozzle_set := false
var _kick := 0.0
var _hose_half := 3.6
var _hose_weave := 3.0
var _hose_inks: Array[Color] = []
var _hose_edge := Color.BLACK
var _hose_belly := 0.0
var _nozzle_turn := 0.0
var _nozzle_swing := 0.0
var _hiss_level := 0.0

var _ink_thin := Color.WHITE
var _ink_film := Color.WHITE
var _ink_scum: Array[Color] = []
var _ink_water: Array[Color] = []
var _ink_dirty: Array[Color] = []


## The stand's own size when nothing is on it, in painted pixels: a middling find's.
const BARE := Vector2(40.0, 30.0)


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_stand_bare()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pick_inks()
	_load_nozzle()
	_build_hiss()
	resized.connect(_fit)


## How much of the coat is gone, 0 to 1.
func share_clean() -> float:
	if _total <= 0.0:
		return 1.0
	return clampf(1.0 - _left / _total, 0.0, 1.0)


## Take whatever is on the stand off it, washed or not. The stand, the nozzle and the water
## stay: an empty stand can still be sprayed, it just has nothing on it.
func clear() -> void:
	piece = &""
	state = State.EMPTY
	_runs.clear()
	_bubbles.clear()
	_stars.clear()
	_stand_bare()


func _stand_bare() -> void:
	_region = Rect2(Vector2.ZERO, BARE)
	_cols = int(BARE.x) * FINE
	_rows = int(BARE.y) * FINE
	_solid.resize(_cols * _rows)
	_solid.fill(0)
	_grime.resize(_cols * _rows)
	_grime.fill(0.0)
	_total = 0.0
	_left = 0.0
	_fit()


## Stand a piece up under a fresh coat. The same piece gets the same coat every time: the
## roll is off its name, so walking away and coming back is the same job, not a new one.
func put(what: StringName) -> void:
	piece = what
	state = State.EMPTY
	_runs.clear()
	_flecks.clear()
	_bubbles.clear()
	_stars.clear()
	_firing = false
	_reach = 0.0
	_tail = 1.0
	if sheets == null or not sheets.has(what):
		return
	if _art == null:
		_art = sheets.atlas.get_image()
	_region = sheets.view_region_of(what, 0)
	_cols = int(_region.size.x) * FINE
	_rows = int(_region.size.y) * FINE
	_roll.seed = hash(String(what))
	_read_solid()
	_roll_coat()
	_fit()
	state = State.WASHING


func _pick_inks() -> void:
	var palette := Palette.master()
	if palette == null:
		_ink_thin = Color(0.2, 0.3, 0.2, THIN_ALPHA)
		_ink_film = Color(0.15, 0.25, 0.15, FILM_ALPHA)
		_ink_scum = [Color(0.1, 0.2, 0.1), Color(0.15, 0.25, 0.12), MUD]
		_ink_water = [Color.WHITE, Color(0.8, 0.9, 1.0), Color(0.6, 0.8, 0.95)]
		_ink_dirty = [Color(0.5, 0.55, 0.4), Color(0.35, 0.42, 0.28)]
		return
	_ink_thin = Color(palette.water_murky, THIN_ALPHA)
	_ink_film = Color(palette.water_foul_mid, FILM_ALPHA)
	_ink_scum = [palette.water_dirty_deep, palette.water_dirty_mid, palette.water_foul_deep, MUD]
	_ink_water = [palette.foam, palette.foam_light, palette.water_clean_light]
	_ink_dirty = [palette.foam_dirty, palette.water_dirty_shallow, palette.water_foul_shallow]


## Which cells have any of the piece in them. A cell is a quarter of a painted pixel at
## `FINE` 2, so this is the picture's own alpha asked `FINE` times a pixel.
func _read_solid() -> void:
	_solid.resize(_cols * _rows)
	for cy in _rows:
		for cx in _cols:
			# No picture to ask (a headless harness has no renderer to read one back from):
			# the whole box is the piece, which is enough to wash.
			if _art == null:
				_solid[cy * _cols + cx] = 1
				continue
			var px := int(_region.position.x) + cx / FINE
			var py := int(_region.position.y) + cy / FINE
			_solid[cy * _cols + cx] = 1 if _art.get_pixel(px, py).a > 0.5 else 0


func _roll_coat() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = int(_roll.randi() & 0x7fffffff)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.085 / float(FINE)
	noise.fractal_octaves = 2
	_grime.resize(_cols * _rows)
	_coat = Image.create_empty(_cols, _rows, false, Image.FORMAT_RGBA8)
	_coat.fill(Color(0.0, 0.0, 0.0, 0.0))
	_total = 0.0
	for cy in _rows:
		for cx in _cols:
			var i := cy * _cols + cx
			if _solid[i] == 0:
				_grime[i] = 0.0
				continue
			var amount := COAT_MID + COAT_SWING * noise.get_noise_2d(cx, cy)
			amount += COAT_LOW * (float(cy) / float(_rows) - 0.5)
			if _on_edge(cx, cy):
				amount += COAT_EDGE
			amount += COAT_GRAIN * (_hash(cx, cy, 7) - 0.5)
			amount = clampf(amount, COAT_LEAST, 1.0)
			_grime[i] = amount
			_total += amount
			_coat.set_pixel(cx, cy, _ink_of(amount, cx, cy))
	_left = _total
	_coat_tex = ImageTexture.create_from_image(_coat)
	_coat_stale = false


func _on_edge(cx: int, cy: int) -> bool:
	return (
		not _is_solid(cx - FINE, cy) or not _is_solid(cx + FINE, cy)
		or not _is_solid(cx, cy - FINE) or not _is_solid(cx, cy + FINE)
	)


func _is_solid(cx: int, cy: int) -> bool:
	if cx < 0 or cy < 0 or cx >= _cols or cy >= _rows:
		return false
	return _solid[cy * _cols + cx] == 1


func _step_of(amount: float) -> int:
	if amount <= THIN_AT:
		return 0
	if amount <= FILM_AT:
		return 1
	if amount <= SCUM_AT:
		return 2
	return 3


func _ink_of(amount: float, cx: int, cy: int) -> Color:
	match _step_of(amount):
		0:
			return Color(0.0, 0.0, 0.0, 0.0)
		1:
			return _ink_thin
		2:
			return _ink_film
	return _ink_scum[int(_hash(cx / FINE, cy / FINE, 3) * _ink_scum.size()) % _ink_scum.size()]


## Take `take` off one cell. Returns what actually came off, and repaints the cell only when
## it crossed one of the three lines — most of a wash changes no pixel at all.
func _wear(cx: int, cy: int, take: float) -> float:
	var i := cy * _cols + cx
	var before := _grime[i]
	if before <= 0.0:
		return 0.0
	var after := maxf(before - take, 0.0)
	# A cell that looks clean is clean. Left holding what is under the last line it was up
	# to a fifth of a coat nobody could see, and at `DONE_AT` that is grime the player is
	# sent looking for with nothing to look at.
	if after <= THIN_AT:
		after = 0.0
	_grime[i] = after
	_left -= before - after
	var step := _step_of(after)
	if step != _step_of(before):
		_coat.set_pixel(cx, cy, _ink_of(after, cx, cy))
		_coat_stale = true
		if step == 0 and _bubbles.size() < BUBBLE_MOST and _roll.randf() < BUBBLE_ODDS:
			_bubbles.append([Vector2i(cx, cy), _roll.randf_range(BUBBLE_LIFE.x, BUBBLE_LIFE.y)])
	return before - after


func _fit() -> void:
	if _cols == 0:
		return
	var wide := _region.size.x
	var tall := _region.size.y
	var zoom := int(floor(minf(size.x * ROOM_WIDE / wide, size.y * ROOM_TALL / tall)))
	zoom = clampi(zoom, ZOOM_LEAST, ZOOM_MOST)
	zoom = maxi(zoom - zoom % FINE, FINE)
	_zoom = zoom
	_cell = float(zoom) / float(FINE)
	_origin = Vector2(
		round(size.x * 0.5 - wide * zoom * 0.5),
		round(size.y * STAND_AT - tall * zoom)
	)


## Where the jet is landing when it is landing **off the find**, or `Vector2.INF`: what the
## room asks so the backdrop's birds and dogs can answer the water. On the find the jet is
## washing, and what is behind the piece is not being sprayed.
func jet_past_piece() -> Vector2:
	if not _firing or _hitting or _reach < 1.0:
		return Vector2.INF
	return _aim


## Where the piece stands, in this control's own coordinates.
func piece_box() -> Rect2:
	return Rect2(_origin, Vector2(_cols, _rows) * _cell)


## Point the jet, and turn it on or off. What the mouse does below, and what a harness or a
## probe does in its place.
func spray(at: Vector2, on: bool) -> void:
	_aim = at
	var was := _firing
	_firing = on and (state == State.WASHING or state == State.EMPTY)
	if _firing and not was:
		_tail = 0.0


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		spray(button.position, button.pressed)
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null:
		spray(motion.position, _firing)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		_firing = false
		_drive_hiss(delta)
		return
	_clock += delta
	_tick = int(_clock * PIXEL_FPS)
	_drive_jet(delta)
	_drive_runs(delta)
	_drive_flecks(delta)
	_drive_bubbles(delta)
	_drive_finish(delta)
	_drive_nozzle(delta)
	_drive_hiss(delta)
	if _coat_stale:
		_coat_tex.update(_coat)
		_coat_stale = false
	queue_redraw()


func _aim_cell() -> Vector2:
	return (_aim - _origin) / _cell


func _drive_jet(delta: float) -> void:
	if state != State.WASHING and state != State.EMPTY:
		_firing = false
	if _firing:
		_reach = minf(_reach + delta / JET_TRAVEL, 1.0)
	else:
		_tail = minf(_tail + delta / JET_TRAVEL, 1.0)
		if _tail >= 1.0:
			_reach = 0.0
	var landing := _reach >= 1.0 and _tail < 1.0
	_hitting = false
	if not landing:
		return
	var removed := _wash_at(_aim_cell(), JET_RADIUS * FINE, JET_POWER * delta)
	_loosened += removed
	while _loosened >= RUN_PER:
		_loosened -= RUN_PER
		_let_run(_aim_cell(), JET_RADIUS * FINE * 0.8, 1.0)
	if _hitting:
		_clear_bank += RUN_CLEAR * delta
		while _clear_bank >= 1.0:
			_clear_bank -= 1.0
			_let_run(_aim_cell(), JET_RADIUS * FINE * 0.6, 0.0)
	_spray_bank += (SPRAY_ON if _hitting else SPRAY_OFF) * delta
	while _spray_bank >= 1.0:
		_spray_bank -= 1.0
		_let_fleck(_aim_cell(), _under > SPRAY_DIRTY_OVER and _hitting)
	if state == State.WASHING and share_clean() >= DONE_AT:
		_begin_rinse()


## Wear the coat inside the jet. Also answers two things about the spot on the way: whether
## any of the piece is under the middle of the jet (`_hitting`), and how grimy that middle
## still is (`_under`), which is what colours the spray.
func _wash_at(centre: Vector2, radius: float, strength: float) -> float:
	var removed := 0.0
	var touched := 0
	var grime_seen := 0.0
	var x0 := maxi(int(floor(centre.x - radius)), 0)
	var x1 := mini(int(ceil(centre.x + radius)), _cols - 1)
	var y0 := maxi(int(floor(centre.y - radius)), 0)
	var y1 := mini(int(ceil(centre.y + radius)), _rows - 1)
	for cy in range(y0, y1 + 1):
		for cx in range(x0, x1 + 1):
			if _solid[cy * _cols + cx] == 0:
				continue
			var far := Vector2(cx + 0.5, cy + 0.5).distance_to(centre) / radius
			if far >= 1.0:
				continue
			if far < 0.55:
				touched += 1
				grime_seen += _grime[cy * _cols + cx]
			removed += _wear(cx, cy, strength * (1.0 - far * far))
	_hitting = touched > 0
	_under = grime_seen / float(touched) if touched > 0 else 0.0
	return removed


func _let_run(near: Vector2, within: float, dirt: float) -> void:
	if _runs.size() >= RUN_MOST:
		_runs.pop_front()
	for attempt in 6:
		var spot := near + Vector2.from_angle(_roll.randf() * TAU) * _roll.randf() * within
		var cell := Vector2i(int(spot.x), int(spot.y))
		if not _is_solid(cell.x, cell.y):
			continue
		var run := Run.new()
		run.at = cell
		run.dirt = dirt
		run.pace = _roll.randf_range(RUN_PACE.x, RUN_PACE.y)
		_runs.append(run)
		return


func _let_fleck(at: Vector2, dirty: bool) -> void:
	if _flecks.size() >= SPRAY_MOST:
		_flecks.pop_front()
	var fleck := Fleck.new()
	var way := Vector2.from_angle(_roll.randf() * TAU)
	# Lifted: what comes off a surface sprayed from below goes up and out more than down.
	way.y = way.y * 0.8 - 0.35
	fleck.at = at + way * _roll.randf() * 1.5
	fleck.going = way * _roll.randf_range(SPRAY_SPEED.x, SPRAY_SPEED.y)
	fleck.span = _roll.randf_range(SPRAY_LIFE.x, SPRAY_LIFE.y)
	fleck.dirty = dirty
	_flecks.append(fleck)


func _drive_runs(delta: float) -> void:
	var kept: Array[Run] = []
	for run: Run in _runs:
		run.age += delta
		if run.age > RUN_LIFE:
			continue
		if run.falling:
			if _fall(run, delta):
				kept.append(run)
			continue
		var pace := run.pace * (SLIDE_PACE if run.sliding != 0 else 1.0)
		run.bank += pace * delta
		var alive := true
		while run.bank >= 1.0 and alive and not run.falling:
			run.bank -= 1.0
			alive = _slide(run) if run.sliding != 0 else _step_run(run)
		if alive:
			kept.append(run)
	_runs = kept


## One cell down the piece. Straight down where it can, a cell to the side where the
## silhouette makes it, and off into the air where there is nothing under it at all.
func _step_run(run: Run) -> bool:
	var below := run.at + Vector2i(0, 1)
	var lean := 1 if _roll.randf() < 0.5 else -1
	var next := below
	if _is_solid(below.x, below.y):
		if _roll.randf() < RUN_WANDER and _is_solid(below.x + lean, below.y):
			next = below + Vector2i(lean, 0)
	elif _is_solid(below.x + lean, below.y):
		next = below + Vector2i(lean, 0)
	elif _is_solid(below.x - lean, below.y):
		next = below + Vector2i(-lean, 0)
	else:
		run.falling = true
		run.y = float(below.y)
		run.fall = run.pace
		return true
	run.trail.push_front(run.at)
	if run.trail.size() > RUN_TRAIL:
		run.trail.pop_back()
	run.at = next
	var took := _wear(next.x, next.y, RUN_WASH)
	run.dirt = minf(run.dirt + took * 3.0, 1.0)
	return true


## A drop in the air. It lands on the stand, or on the piece again if there is more of the
## piece under it — off a chair's seat and onto its rail. One that has come off the stand's
## end lands on nothing but the floor.
func _fall(run: Run, delta: float) -> bool:
	run.fall += FALL_PULL * delta
	run.y += run.fall * delta
	var row := int(run.y)
	if run.off:
		# Still on the plank's face: a creep, not a fall.
		if run.y < float(_rows) + STAND_TALL / _cell:
			run.fall = run.pace * FRONT_CREEP
		if run.y >= _floor_row():
			for splat in 2:
				_let_fleck(Vector2(run.at.x + 0.5, _floor_row() - 0.5), run.dirt > 0.5)
			return false
		run.at.y = row
		return true
	if row >= _rows:
		_land(run)
		return true
	if _is_solid(run.at.x, row):
		run.at = Vector2i(run.at.x, row)
		run.falling = false
		run.trail.clear()
		run.bank = 0.0
		return true
	run.at.y = row
	return true


## Onto the wood: a small splat, and off along it towards whichever end is nearer.
func _land(run: Run) -> void:
	run.at = Vector2i(run.at.x, _rows)
	run.falling = false
	run.sliding = -1 if run.at.x * 2 < _cols else 1
	run.trail.clear()
	run.bank = 0.0
	run.age = 0.0
	_let_fleck(Vector2(run.at.x + 0.5, float(_rows) - 0.5), run.dirt > 0.5)
	if _roll.randf() < FRONT_ON_LANDING:
		_go_over(run)


## One cell along the stand's top, and off its end into the air.
func _slide(run: Run) -> bool:
	run.trail.push_front(run.at)
	if run.trail.size() > RUN_TRAIL:
		run.trail.pop_back()
	run.at.x += run.sliding
	var pad := _stand_pad()
	var past_end := run.at.x < -pad or run.at.x >= _cols + pad
	if past_end or _roll.randf() < FRONT_A_CELL:
		_go_over(run)
	return true


## Off the wood: past an end, or over the near edge and down the plank's face.
func _go_over(run: Run) -> void:
	run.sliding = 0
	run.off = true
	run.falling = true
	run.y = float(_rows)
	run.fall = run.pace
	run.trail.clear()


func _floor_row() -> float:
	return (size.y * FLOOR_AT - _origin.y) / _cell


func _drive_flecks(delta: float) -> void:
	var kept: Array[Fleck] = []
	for fleck: Fleck in _flecks:
		fleck.age += delta
		if fleck.age >= fleck.span:
			continue
		fleck.going.y += SPRAY_PULL * delta
		fleck.at += fleck.going * delta
		kept.append(fleck)
	_flecks = kept


func _drive_bubbles(delta: float) -> void:
	var kept: Array = []
	for bubble: Array in _bubbles:
		bubble[1] = float(bubble[1]) - delta
		if float(bubble[1]) > 0.0:
			kept.append(bubble)
	_bubbles = kept


func _begin_rinse() -> void:
	state = State.RINSING
	_firing = false
	_phase = 0.0
	_rinsed_to = 0


## The rest goes by itself: a line sweeps down the piece taking whatever is left, then the
## piece shines, in the finds' own gold.
func _drive_finish(delta: float) -> void:
	if state == State.RINSING:
		_phase += delta / RINSE_TIME
		var to := mini(int(_phase * float(_rows)) + 1, _rows)
		for cy in range(_rinsed_to, to):
			for cx in _cols:
				if _grime[cy * _cols + cx] > 0.0:
					_wear(cx, cy, 2.0)
			if cy % (FINE * 3) == 0:
				_let_run(Vector2(_roll.randf() * _cols, cy), 2.0, 0.0)
		_rinsed_to = to
		if _phase >= 1.0:
			state = State.SHINING
			_phase = 0.0
			_left = 0.0
			washed.emit(piece)
			_glint = 0.0
			var sound := Sfx.main()
			if sound != null:
				sound.play_find_caught()
	elif state == State.SHINING:
		_phase += delta / SHINE_TIME
		if _roll.randf() < 16.0 * delta * (1.0 - _phase):
			var cx := _roll.randi_range(0, _cols - 1)
			var cy := _roll.randi_range(0, _rows - 1)
			if _is_solid(cx, cy):
				_stars.append([Vector2i(cx, cy), 0.0, _roll.randf() < 0.55])
		if _phase >= 1.0 and _stars.is_empty():
			state = State.CLEAN
	var kept: Array = []
	for star: Array in _stars:
		star[1] = float(star[1]) + delta / 0.5
		if float(star[1]) < 1.0:
			kept.append(star)
	_stars = kept


# --- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	var floor_y := size.y * FLOOR_AT
	if bare_room:
		draw_rect(Rect2(Vector2.ZERO, size), WALL)
		draw_rect(Rect2(0.0, floor_y, size.x, size.y - floor_y), FLOOR)
	else:
		_draw_shade(floor_y)
	_draw_stand(floor_y)
	if state != State.EMPTY:
		draw_texture_rect_region(
			sheets.atlas, Rect2(_origin, _region.size * float(_zoom)), _region
		)
		draw_texture_rect(_coat_tex, Rect2(_origin, Vector2(_cols, _rows) * _cell), false)
	if state == State.RINSING:
		_draw_rinse_line()
	_draw_runs()
	_draw_bubbles()
	_draw_impact()
	_draw_flecks()
	_draw_stream()
	_draw_stars()
	_draw_nozzle()


func _cell_box(cx: float, cy: float, cells: float = 1.0) -> Rect2:
	return Rect2(
		_origin + Vector2(floorf(cx), floorf(cy)) * _cell, Vector2.ONE * _cell * cells
	)


func _draw_stand(floor_y: float) -> void:
	var top := _stand_top()
	var leg_tall := floor_y - top.end.y + 6.0
	for side in 2:
		var x := top.position.x + 18.0 if side == 0 else top.end.x - 18.0 - 16.0
		Style.plank(self, Rect2(x, top.end.y - 2.0, 16.0, leg_tall), 11 + side)
	Style.plank(self, top, 5)
	if not bare_room:
		for side in 2:
			var x := top.position.x + 18.0 if side == 0 else top.end.x - 18.0 - 16.0
			_draw_tuft(Vector2(x + 8.0, top.end.y - 2.0 + leg_tall), 31 + side)


## Where the stand's top is, the one sum `_draw_stand` and `_draw_shade` share.
func _stand_top() -> Rect2:
	var wide := snappedf(size.x * STAND_WIDE, 2.0)
	return Rect2(
		round(size.x * 0.5 - wide * 0.5), _origin.y + _rows * _cell, wide, STAND_TALL
	)


## How far the top runs past the piece each side, in this piece's cells.
func _stand_pad() -> float:
	return maxf((size.x * STAND_WIDE - _cols * _cell) * 0.5 / maxf(_cell, 0.001), 1.0)


## Blades over a leg's foot: columns of whole painted pixels, tallest at the leg and cut
## down to either side, rolled off a fixed seed so they never move.
func _draw_tuft(foot: Vector2, seed_at: int) -> void:
	var palette := Palette.master()
	if palette == null:
		return
	var greens := [palette.grass_light, palette.leaf, palette.grass_dark]
	for k in TUFT_BLADES:
		var across := (_hash(seed_at, k) * 2.0 - 1.0) * TUFT_REACH
		var near := 1.0 - absf(across) / TUFT_REACH
		var tall := int(lerpf(TUFT_TALL.x, TUFT_TALL.y, near * _hash(seed_at, k, 3))) + 1
		var ink: Color = greens[int(_hash(seed_at, k, 5) * 2.99)] * ground_tone
		ink.a = 1.0
		var x := snappedf(foot.x + across * TUFT_PIXEL, TUFT_PIXEL)
		var down := snappedf(foot.y + TUFT_PIXEL * 2.0 * _hash(seed_at, k, 9), TUFT_PIXEL)
		draw_rect(Rect2(x, down - tall * TUFT_PIXEL, TUFT_PIXEL, tall * TUFT_PIXEL), ink)


## The sun's shadow of the stand and what is on it, lying down the lawn from the feet.
func _draw_shade(floor_y: float) -> void:
	if shade.z <= 0.0:
		return
	var top := _stand_top()
	var feet := Vector2(top.get_center().x, floor_y + 4.0)
	var ink := Shade.tint(minf(shade.z * SHADE_GAIN, 0.6))
	draw_set_transform_matrix(Shade.lying(feet, shade.x, shade.y))
	# In the shadow's own space the feet are the origin and up is up.
	var lift := Vector2(-feet.x, -feet.y)
	for side in 2:
		var x := top.position.x + 18.0 if side == 0 else top.end.x - 18.0 - 16.0
		draw_rect(Rect2(Vector2(x, top.end.y) + lift, Vector2(16.0, feet.y - top.end.y)), ink)
	draw_rect(Rect2(top.position + lift, top.size), ink)
	if state != State.EMPTY:
		draw_texture_rect_region(
			sheets.atlas, Rect2(_origin + lift, _region.size * float(_zoom)), _region, ink
		)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_rinse_line() -> void:
	var y := _origin.y + float(_rinsed_to) * _cell
	draw_rect(Rect2(_origin.x, y - _cell, _cols * _cell, _cell), Color(_ink_water[1], 0.85))
	draw_rect(Rect2(_origin.x, y, _cols * _cell, _cell), Color(_ink_water[0], 0.4))


func _draw_runs() -> void:
	for run: Run in _runs:
		var inks := _ink_dirty if run.dirt > 0.5 else _ink_water
		var head: Color = inks[0]
		var body: Color = inks[1]
		if run.falling:
			draw_rect(_cell_box(run.at.x, run.y), head)
			draw_rect(_cell_box(run.at.x, run.y - 1.0), Color(body, 0.6))
			continue
		draw_rect(_cell_box(run.at.x, run.at.y), head)
		for k in run.trail.size():
			# Whole, then a remnant, then nothing: three steps, the foam's own.
			var alpha := 0.75 if k < RUN_TRAIL / 2 else 0.35
			draw_rect(_cell_box(run.trail[k].x, run.trail[k].y), Color(body, alpha))


func _draw_bubbles() -> void:
	for bubble: Array in _bubbles:
		var at: Vector2i = bubble[0]
		draw_rect(_cell_box(at.x, at.y), _ink_water[1])


## The froth where the jet lands: a handful of cells picked again every tick.
func _draw_impact() -> void:
	if _reach < 1.0 or _tail >= 1.0:
		return
	var centre := _aim_cell()
	var inks := _ink_dirty if (_hitting and _under > SPRAY_DIRTY_OVER) else _ink_water
	var reach := JET_RADIUS * FINE * (0.7 if _hitting else 0.4)
	for k in 14:
		var turn := _hash(k, _tick, 1) * TAU
		var out := sqrt(_hash(k, _tick, 2)) * reach
		var at := centre + Vector2.from_angle(turn) * out
		var ink: Color = inks[k % inks.size()]
		draw_rect(_cell_box(at.x, at.y), Color(ink, 0.9 if out < reach * 0.6 else 0.55))


func _draw_flecks() -> void:
	for fleck: Fleck in _flecks:
		var inks := _ink_dirty if fleck.dirty else _ink_water
		var late := fleck.age / fleck.span > 0.66
		draw_rect(_cell_box(fleck.at.x, fleck.at.y), Color(inks[0], 0.45 if late else 0.95))


func _load_nozzle() -> void:
	var text := FileAccess.get_file_as_string(NOZZLE_CONTRACT)
	var contract: Variant = JSON.parse_string(text) if not text.is_empty() else null
	if not (contract is Dictionary) or not ResourceLoader.exists(NOZZLE_ART):
		return
	_nozzle_art = load(NOZZLE_ART) as Texture2D
	_nozzle_frames = (contract as Dictionary).get("frames", []) as Array
	_nozzle_step = float((contract as Dictionary).get("step", 10.0))
	_nozzle_swing = float((contract as Dictionary).get("swing", 0.0))
	var hose: Dictionary = (contract as Dictionary).get("hose", {}) as Dictionary
	_hose_half = float(hose.get("half", 3.6))
	_hose_weave = float(hose.get("weave", 3.0))
	_hose_edge = _rgb(hose.get("edge", [48, 37, 33]) as Array)
	_hose_inks.clear()
	for ink: Variant in hose.get("inks", []) as Array:
		_hose_inks.append(_rgb(ink as Array))
	if _nozzle_art == null:
		_nozzle_frames = []


static func _rgb(from: Array) -> Color:
	return Color(float(from[0]) / 255.0, float(from[1]) / 255.0, float(from[2]) / 255.0)


func _has_nozzle() -> bool:
	return not _nozzle_frames.is_empty()


## Where the nozzle is heading for: under the pointer, most of the way, and up a little
## when the aim is high.
func _nozzle_wants() -> Vector2:
	var high := clampf(1.0 - _aim.y / maxf(size.y, 1.0), 0.0, 1.0)
	return Vector2(
		size.x * 0.5 + (_aim.x - size.x * 0.5) * NOZZLE_FOLLOW,
		size.y - (NOZZLE_RISE + NOZZLE_LIFT * high) * NOZZLE_SCALE
	)


## Where the nozzle hangs from.
func _nozzle_pivot() -> Vector2:
	return _nozzle_pos if _nozzle_set else _nozzle_wants()


## Which baked heading is nearest the aim.
func _nozzle_frame() -> Dictionary:
	var last := _nozzle_frames.size() - 1
	var index := clampi(roundi(_nozzle_turn / _nozzle_step) + last / 2, 0, last)
	return _nozzle_frames[index] as Dictionary


## The heading the aim asks for, in degrees off straight up, inside what was baked.
func _turn_wanted() -> float:
	var to := _aim - _nozzle_pivot()
	var degrees := rad_to_deg(atan2(to.x, -to.y)) if to.y < 0.0 else signf(to.x) * 90.0
	return clampf(degrees, -_nozzle_swing, _nozzle_swing)


## How far the whole picture is moved this frame: pushed back along its heading while it
## sprays, with a tremble across it, and breathing up and down while it does not.
func _nozzle_shift(frame: Dictionary) -> Vector2:
	var turn := deg_to_rad(float(frame.get("heading", 0.0)))
	var along := Vector2(sin(turn), -cos(turn))
	var shift := -along * NOZZLE_KICK * _kick
	shift += along.orthogonal() * (_hash(_tick, 5, 1) - 0.5) * 2.0 * NOZZLE_SHAKE * _kick
	shift.y += sin(_clock * NOZZLE_BOB) * 0.6 * (1.0 - _kick)
	return shift * NOZZLE_SCALE


## A point the contract gives inside a frame, as a place on the screen.
func _nozzle_point(frame: Dictionary, key: String) -> Vector2:
	var spot: Array = frame.get(key, [0, 0]) as Array
	var pivot: Array = frame.get("pivot", [0, 0]) as Array
	var off := Vector2(float(spot[0]) - float(pivot[0]), float(spot[1]) - float(pivot[1]))
	return _nozzle_pivot() + _nozzle_shift(frame) + off * NOZZLE_SCALE


func _nozzle_tip() -> Vector2:
	if _has_nozzle():
		return _nozzle_point(_nozzle_frame(), "tip")
	var base := Vector2(
		size.x * 0.5 + (_aim.x - size.x * 0.5) * NOZZLE_FOLLOW, size.y + PLAIN_UNDER
	)
	return base + (_aim - base).normalized() * PLAIN_LONG


func _drive_nozzle(delta: float) -> void:
	var kept: Array = []
	for bead: Array in _beads:
		bead[1] = float(bead[1]) - delta
		if float(bead[1]) <= 0.0:
			bead[2] = float(bead[2]) + BEAD_PULL * delta
			bead[0] = (bead[0] as Vector2) + Vector2(0.0, float(bead[2]) * delta)
		if (bead[0] as Vector2).y < size.y + NOZZLE_SCALE:
			kept.append(bead)
	_beads = kept
	_glint = minf(_glint + delta / GLINT_TIME, 1.0)
	_glint_rest = maxf(_glint_rest - delta, 0.0)
	_kick = move_toward(_kick, 1.0 if _firing else 0.0, delta / NOZZLE_KICK_TIME)
	if _nozzle_set:
		_nozzle_pos = _nozzle_pos.lerp(_nozzle_wants(), 1.0 - exp(-NOZZLE_EASE * delta))
		_hose_belly = lerpf(_hose_belly, _nozzle_pos.x, 1.0 - exp(-HOSE_EASE * delta))
		_nozzle_turn = lerpf(_nozzle_turn, _turn_wanted(), 1.0 - exp(-NOZZLE_TURN_EASE * delta))
	else:
		_nozzle_pos = _nozzle_wants()
		_nozzle_set = true
		_hose_belly = _nozzle_pos.x
	if not _has_nozzle():
		return
	var frame := _nozzle_frame()
	# Let go: what was in the nozzle hangs on its lip a moment and drops.
	if _firing and not _was_firing and _glint_rest <= 0.0:
		_glint = 0.0
		_glint_rest = GLINT_REST
	if _was_firing and not _firing:
		for k in _roll.randi_range(BEADS.x, BEADS.y):
			var hang := _roll.randf_range(BEAD_HANGS.x, BEAD_HANGS.y) * float(k + 1)
			_beads.append([_nozzle_point(frame, "bead"), hang, 0.0])
	_was_firing = _firing
	# A bead still hanging goes where the lip goes.
	for bead: Array in _beads:
		if float(bead[1]) > 0.0:
			bead[0] = _nozzle_point(frame, "bead")


## Dashes of water from the nozzle to the aim, flowing forwards, spreading as they go. From
## `_tail` to `_reach` of the way, so it grows out of the nozzle and lets go of it.
func _draw_stream() -> void:
	if _reach <= 0.0 or _tail >= 1.0:
		return
	var from := _nozzle_tip()
	var to := _aim
	var along := to - from
	var count := int(along.length() / _cell)
	if count <= 0:
		return
	var across := along.orthogonal().normalized()
	for i in count:
		var t := float(i) / float(count)
		if t < _tail or t > _reach:
			continue
		if _hash(i - _tick * 3, 9, 0) < 0.2:
			continue
		var spread := lerpf(0.2, 1.7, t) * _cell
		var at := from + along * t + across * (_hash(i, _tick, 4) - 0.5) * 2.0 * spread
		at = (at / _cell).floor() * _cell
		var ink: Color = _ink_water[int(_hash(i, _tick, 6) * 3.0) % 3]
		var wide := _cell * (2.0 if t > 0.55 else 1.0)
		draw_rect(Rect2(at, Vector2(wide, wide)), ink)


func _draw_nozzle() -> void:
	if not _has_nozzle():
		_draw_nozzle_plain()
		return
	var frame := _nozzle_frame()
	var box: Array = frame.get("rect", [0, 0, 1, 1]) as Array
	var cut := Rect2(float(box[0]), float(box[1]), float(box[2]), float(box[3]))
	var pivot: Array = frame.get("pivot", [0, 0]) as Array
	var corner := (
		_nozzle_pivot() + _nozzle_shift(frame)
		- Vector2(float(pivot[0]), float(pivot[1])) * NOZZLE_SCALE
	)
	_draw_hose(_nozzle_pivot() + _nozzle_shift(frame), corner, float(frame.get("heading", 0.0)))
	draw_texture_rect_region(_nozzle_art, Rect2(corner, cut.size * NOZZLE_SCALE), cut)
	var pixel := Vector2.ONE * NOZZLE_SCALE
	if _glint < 1.0:
		var from := _nozzle_point(frame, "glint_from")
		var to := _nozzle_point(frame, "glint_to")
		var at := (from.lerp(to, _glint) / NOZZLE_SCALE).floor() * NOZZLE_SCALE
		draw_rect(Rect2(at, pixel), LakeGrid.STAR_WHITE)
		draw_rect(Rect2(at - Vector2(0.0, NOZZLE_SCALE), pixel), Color(LakeGrid.GLINT_TINT, 0.7))
	for bead: Array in _beads:
		var spot := ((bead[0] as Vector2) / NOZZLE_SCALE).floor() * NOZZLE_SCALE
		draw_rect(Rect2(spot, pixel), _ink_water[1])
		if float(bead[1]) <= 0.0:
			draw_rect(Rect2(spot - Vector2(0.0, NOZZLE_SCALE), pixel), Color(_ink_water[2], 0.6))


## The hose, from the grip's foot to a point under the screen. `grid` is any corner of the
## nozzle picture's own pixel grid.
func _draw_hose(from: Vector2, grid: Vector2, heading: float) -> void:
	if _hose_inks.size() < 3:
		return
	var middle := size.x * 0.5
	# A pixel up inside the grip, so the wood's own outline closes over the join.
	# It leaves along the nozzle's own axis, whichever way that is pointing.
	var turn := deg_to_rad(heading)
	var back := Vector2(-sin(turn), cos(turn))
	var p0 := from - back * NOZZLE_SCALE
	var p3 := Vector2(
		from.x + HOSE_SIDE * NOZZLE_SCALE + (middle - from.x) * HOSE_ANCHOR,
		size.y + HOSE_UNDER * NOZZLE_SCALE
	)
	var reach := p0.distance_to(p3) * HOSE_REACH
	var p1 := p0 + back * reach + Vector2((_hose_belly - from.x) * HOSE_BELLY, 0.0)
	var p2 := p3 - Vector2(0.0, reach)
	var steps := maxi(int(p0.distance_to(p3) * 1.4 / NOZZLE_SCALE), 8)
	var light := Vector2(0.8, -0.6)
	var reach_cells := int(ceil(_hose_half))
	# Cell -> [how far from the line, how far along it, how lit]: the nearest bit of the
	# line decides a cell, so the weave does not smear where the curve doubles past itself.
	var cells := {}
	var walked := 0.0
	var last := p0
	for i in steps + 1:
		var t := float(i) / float(steps)
		var at := p0.bezier_interpolate(p1, p2, p3, t)
		var way := p0.bezier_derivative(p1, p2, p3, t).normalized()
		walked += at.distance_to(last) / NOZZLE_SCALE
		last = at
		var across := way.orthogonal()
		var facing := across.dot(light)
		var here := (at - grid) / NOZZLE_SCALE
		var cx := int(floor(here.x))
		var cy := int(floor(here.y))
		for y in range(cy - reach_cells, cy + reach_cells + 1):
			for x in range(cx - reach_cells, cx + reach_cells + 1):
				var off := Vector2(x + 0.5, y + 0.5) - here
				var far := off.length_squared()
				if far > _hose_half * _hose_half:
					continue
				var key := Vector2i(x, y)
				if cells.has(key) and float((cells[key] as Array)[0]) <= far:
					continue
				cells[key] = [far, walked, off.dot(across) / _hose_half * facing]
	var pixel := Vector2.ONE * NOZZLE_SCALE
	for key: Vector2i in cells:
		var cell: Array = cells[key]
		var lit := float(cell[2])
		var step := 2 if lit > HOSE_LIT_OVER else (0 if lit < HOSE_DARK_UNDER else 1)
		if int(float(cell[1]) / _hose_weave) % 2 == 0:
			step = maxi(step - 1, 0)
		draw_rect(Rect2(grid + Vector2(key) * NOZZLE_SCALE, pixel), _hose_inks[step])
		for side: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			if not cells.has(key + side):
				draw_rect(Rect2(grid + Vector2(key + side) * NOZZLE_SCALE, pixel), _hose_edge)


func _draw_nozzle_plain() -> void:
	var tip := _nozzle_tip()
	var base := Vector2(
		size.x * 0.5 + (_aim.x - size.x * 0.5) * NOZZLE_FOLLOW, size.y + PLAIN_UNDER
	)
	var way := (tip - base).normalized()
	draw_line(base, tip, Style.HOLE_RIM, 22.0)
	draw_line(base, tip, PLAIN_METAL, 18.0)
	draw_line(tip - way * 15.0, tip - way * 1.0, PLAIN_BRASS, 22.0)


func _draw_stars() -> void:
	for star: Array in _stars:
		var at: Vector2i = star[0]
		var bright := sin(float(star[1]) * PI)
		var ink := LakeGrid.GLINT_TINT.lerp(LakeGrid.STAR_WHITE, bright)
		draw_rect(_cell_box(at.x, at.y, float(FINE)), ink)
		if not bool(star[2]):
			continue
		var arms := int(round(bright * 3.0))
		for k in range(1, arms + 1):
			var dim := Color(ink, 1.0 - float(k - 1) / 4.0)
			for way: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var cell := at + way * k * FINE
				draw_rect(_cell_box(cell.x, cell.y, float(FINE)), dim)


# --- Sound -------------------------------------------------------------------------------

func _build_hiss() -> void:
	var stream: AudioStream = null
	if ResourceLoader.exists(HISS_TAKE):
		var take := load(HISS_TAKE) as AudioStreamOggVorbis
		if take != null:
			take.loop = true
			stream = take
	if stream == null:
		stream = _noise_hiss()
	_hiss = AudioStreamPlayer.new()
	_hiss.stream = stream
	_hiss.bus = Prefs.BUS_SFX
	_hiss.volume_db = Prefs.BUS_SILENT
	add_child(_hiss)


## Whether the jet is the recording rather than the fallback, for the harness.
func hiss_is_recorded() -> bool:
	return _hiss != null and _hiss.stream is AudioStreamOggVorbis


## The fallback: a second of shaped noise on a loop, its ends crossed over so the seam is
## not a tick.
func _noise_hiss() -> AudioStream:
	var count := int(HISS_LENGTH * HISS_RATE)
	var cross := int(0.12 * HISS_RATE)
	var raw := PackedFloat32Array()
	raw.resize(count + cross)
	var roll := RandomNumberGenerator.new()
	roll.seed = 37
	var low := 0.0
	var lower := 0.0
	for i in raw.size():
		var white := roll.randf() * 2.0 - 1.0
		# A band of it: the top taken off, then the bottom taken off what is left.
		low += (white - low) * 0.55
		lower += (low - lower) * 0.06
		raw[i] = low - lower
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var value := raw[i]
		if i < cross:
			var blend := float(i) / float(cross)
			value = raw[i] * blend + raw[count + i] * (1.0 - blend)
		data.encode_s16(i * 2, int(clampf(value * 0.8, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = HISS_RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = count
	stream.data = data
	return stream


func _drive_hiss(delta: float) -> void:
	if _hiss == null:
		return
	var want := 1.0 if _firing else 0.0
	_hiss_level = move_toward(_hiss_level, want, delta / 0.06)
	if _hiss_level <= 0.0:
		if _hiss.playing:
			_hiss.stop()
		return
	if not _hiss.playing:
		_hiss.play()
	_hiss.volume_db = lerpf(Prefs.BUS_SILENT, HISS_DB, sqrt(_hiss_level))
	var pitch := HISS_ON_PIECE if _hitting else HISS_OFF_PIECE
	_hiss.pitch_scale = lerpf(_hiss.pitch_scale, pitch, clampf(delta * 14.0, 0.0, 1.0))


static func _hash(a: int, b: int, c: int = 0) -> float:
	var h := (a * 374761393 + b * 668265263 + c * 1274126177) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1103515245) & 0x7fffffff
	return float(h ^ (h >> 16)) / 2147483648.0

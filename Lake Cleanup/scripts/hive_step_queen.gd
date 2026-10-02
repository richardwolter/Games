## The third step of a new colony: find the queen (2026-09-30, the beehive; the second pass,
## Richard, off `tools/hive_mockup2.py` `room_queen`).
##
## **No hands.** A brood frame stands upright in a pine uncapping rest (the builder's `rest`),
## and the comb is crowded: `WORKERS` workers crawl over it on slow, curving walks, packed the
## mockup's way. **The queen is only a subtly longer bee** (`queen_long`, no dot, no court), so
## she has to be looked for. **The pointer is a magnifying glass**: inside its brass rim the comb
## and its bees are drawn at twice the size.
##
## - **Click (pad A or RT) with her inside the inner half of the glass** finds her: a gold
##   halo round the rim, the glass settling onto her, a crown popping up over her with stars,
##   the workers slowing, `hive_crown`, and `finished` once that has landed (`PAYOFF_HOLD`).
## - **A click that misses**: the bee nearest the click buzzes off the frame and away, the
##   ones by it shuffle, and the glass wobbles. **No penalty**, no count.
## - **After `HINT_AFTER` seconds** a faint glint winks on her now and then.
## - **"Inside the inner half" is measured as it is seen** (`FIND_REACH`), plus `QUEEN_GRACE`
##   for her own body: input here is generous.
## - **The glass warms as she comes into it** (`_warm`), a faint gold glow round the rim.
##
## **The pad**: the stick moves the hidden pointer (`pad_move`) and the glass follows it, with
## **a gentle pull towards her within `PULL_REACH` radii** — `PadAim`'s own assist at the
## room's scale, kept as an offset of the glass from the pointer (`_pull`).
##
## **The magnification is a clip, not a copy of the screen**: `_glass` draws the disc in whole
## painted pixels with `clip_children` set to children only, and its one child draws the scene
## again under a canvas transform scaled twice about the glass's middle.
##
## **Harness hooks, never gated on `awake`**: `find_at(p)`, `queen_pos()`, `lens_pos()`,
## `aim(p)`, `miss_at(p)` (a miss, for the harness) and `settle()`. The walks are rolled off a
## fixed seed.
class_name HiveStepQueen
extends HiveStep

## Where the pieces stand, in painted pixels of the art grid, off the mockup: the frame's top
## left (`fx`, `fy` there, less the pixel the crop takes), and the opened hive's feet at the
## left edge. The frame's own anchors say where its comb and its ears are; these are the
## same numbers for a run with no json.
const FRAME_AT := Vector2(157.0, 44.0)
const COMB_TL := Vector2(20.0, 10.0)
const COMB_BR := Vector2(306.0, 175.0)
const EAR_L := Vector2(9.0, 5.0)
const EAR_R := Vector2(316.0, 5.0)
## The rest's shadow on the lawn under its feet: middle and half size.
const HIVE_SHADE_MID := Vector2(320.0, 297.0)
const HIVE_SHADE_HALF := Vector2(200.0, 6.0)
## The shadow on the lawn under what stands in this step: a contact ellipse in the one ink
## every shadow on land takes (`Shade.tint_on`, 2026-10-02, one sun), nudged along the sun
## (`Shade.drop`) as if from `CONTACT_RISE` painted px up, so it falls down and to the left
## like every other shadow on the island. Kept an ellipse and kept flat, by decision: the
## step is seen from eye height over the lawn, where a footprint is a thin band, and a
## silhouette cast off the close-up would be the one shadow in the room not lying on it.
const CONTACT_RISE := 4.0
## A faint glint winks on her after this long unfound, every `HINT_EVERY`.
const HINT_AFTER := 20.0
const HINT_EVERY := 2.4

## The walks are rolled off this, so every visit and every harness run is the same comb.
const SEED := 4
## The queen starts where the mockup put her, two thirds across and a little below the middle.
const QUEEN_START := Vector2(367.0, 150.0)

## The workers: how many, how close two may start (the mockup's box), how far they keep from
## her (measured with the height stretched 1.4, the court being wider than tall), their
## crawl in painted pixels a second, and their turning: a spin wanted anywhere up to
## `WORKER_SPIN` radians a second, rolled every `RETARGET` seconds and eased into
## (`SPIN_EASE`), so a walk curves rather than zigzags. Now and then one stops to look at a
## cell (`WORKER_REST_ODDS`, for `WORKER_REST` seconds).
const WORKERS := 330
const WORKER_SPACE := Vector2(7.0, 4.0)
const WORKER_CLEAR := 8.0
const WORKER_SPEED := Vector2(4.0, 8.0)
const WORKER_SPIN := 1.8
const RETARGET := Vector2(0.6, 1.8)
const SPIN_EASE := 3.0
const WORKER_REST_ODDS := 0.25
const WORKER_REST := Vector2(0.4, 1.6)
## How hard a walker off its patch is turned back to it, a share of the gap a second.
const TURN_HOME := 2.5
## A worker's patch is the comb less this much a side.
const ROAM_IN := 6.0

## The queen: slower, stopping more, turning less, and kept this far in from the comb's edges
## so the court round her stays on the comb.
const QUEEN_SPEED := 2.6
const QUEEN_SPIN := 0.9
const QUEEN_REST_ODDS := 0.45
const QUEEN_REST := Vector2(0.8, 2.4)
const QUEEN_MARGIN := Vector2(34.0, 22.0)

## Her court: eight bees on an ellipse round her (the mockup's 19 by 12), all facing in, the
## ring turning slowly and each bee easing after its place on it, so the court follows her
## with a lag rather than being carried. Drawn in when she is found (`COURT_TIGHT`).
const COURT := 0
const COURT_RING := Vector2(19.0, 12.0)
const COURT_TURN := 0.12
const COURT_EASE := 3.0
const COURT_TIGHT := 0.82

## A walker only changes which way it is drawn when the new way is this much more its heading
## than the old one, so a bee walking at forty-five degrees does not flicker between two.
const FACE_KEEP := 0.25
const FACE_R := 0
const FACE_L := 1
const FACE_U := 2
const FACE_D := 3

## The glass: its radius in painted pixels and how much it magnifies (the contract's 33 and
## two), how fast it eases after the pointer, and how fast it settles onto her once found.
const LENS_R := 33
const ZOOM := 2.0
const LENS_EASE := 24.0
const SETTLE_EASE := 6.0
## Found: she is within the inner `FIND_SHARE` of the glass as seen (so a quarter of its
## radius on the comb, at twice the size), plus `QUEEN_GRACE` painted pixels for her body.
const FIND_SHARE := 0.5
const QUEEN_GRACE := 4.0
const FIND_REACH := LENS_R * FIND_SHARE / ZOOM + QUEEN_GRACE
## Two clicks closer than this are one (a pad's A arrives as a click and as the action).
const TRY_GAP := 0.15

## The pad's pull, `PadAim`'s numbers: within `PULL_REACH` radii of the glass, at `PULL` of
## the speed the stick asks for, never towards her when she is behind the push (`AHEAD`),
## and `FRICTION` of the stick's move kept once she is under the middle. `PAD_SPEED` and
## `PAD_CURVE` mirror `Pad.CURSOR_SPEED`/`CURSOR_CURVE`, the pointer's own pace, which the
## pull is a share of; `PAD_DEAD` is a stick at rest.
const PULL_REACH := 1.5
const PULL := 0.3
const AHEAD := -0.2
const FRICTION := 0.55
const PAD_SPEED := 1.1
const PAD_CURVE := 1.8
const PAD_DEAD := 0.1

## A miss: the bees within `MISS_REACH` of the click (what the glass shows, and a little)
## are kicked away at `SCATTER` painted pixels a second, the kick dying away (`KICK_EASE`),
## their wings up for `BUZZ_TIME`; the glass shakes `SHAKE_PX` pixels, dying at `SHAKE_EASE`.
## The buzz is the swarm's own take, short and high (`MISS_DB`, `MISS_PITCH`).
const MISS_REACH := LENS_R / ZOOM + 6.0
const SCATTER := Vector2(26.0, 40.0)
const COURT_SCATTER := 0.5
const KICK_EASE := 5.0
const BUZZ_TIME := 0.55
const FLUTTER := 20.0
const SHAKE_PX := 2.0
const SHAKE_RATE := 38.0
const SHAKE_EASE := 7.0
const PRESS_EASE := 10.0
const MISS_DB := -9.0
const MISS_PITCH := 1.7

## She is under the glass: the rim warms towards `WARM_HALO` of the found halo.
const WARM_EASE := 6.0
const WARM_HALO := 0.3

## Found: the halo eases in, the workers slow to `CALM` of their pace, the crown rises
## `CROWN_UP` over her over `CROWN_RISE` seconds and pops to twice its size over
## `CROWN_POP` with an overshoot, stars burst (`BURST`: the mockup's five round her, then
## `RING_STARS` round the rim) and keep twinkling by the crown every `TWINKLE_EVERY`, and
## `finished` is said `PAYOFF_HOLD` seconds in.
const HALO_EASE := 8.0
const CALM := 0.35
const CALM_EASE := 2.0
const CROWN_UP := 56.0
const CROWN_RISE := 0.45
const CROWN_POP := 0.35
const CROWN_SCALE := 2.0
const STAR_LIFE := 0.8
const TWINKLE_EVERY := 0.22
const RING_STARS := 6
const BURST: Array[Vector3] = [
	Vector3(-30, -40, 2), Vector3(30, -42, 3), Vector3(44, -8, 2), Vector3(-46, -4, 1),
	Vector3(-24, 42, 1),
]
const PAYOFF_HOLD := 1.2

## The glass's colours: the builder's brass and dark wood (`tools/build_hive.py`), a faint
## tint over what the glass shows, the sheen on its upper left and the one bright glint.
const BRASS_LIT := Color(252 / 255.0, 222 / 255.0, 128 / 255.0)
const BRASS_BASE := Color(216 / 255.0, 166 / 255.0, 62 / 255.0)
const BRASS_SHADE := Color(160 / 255.0, 112 / 255.0, 38 / 255.0)
const WOOD_HI := Color(150 / 255.0, 110 / 255.0, 76 / 255.0)
const WOOD := Color(120 / 255.0, 84 / 255.0, 56 / 255.0)
const WOOD_LO := Color(90 / 255.0, 60 / 255.0, 40 / 255.0)
const GLASS_TINT := Color(0.86, 0.94, 1.0, 0.1)
const SHEEN := Color(248 / 255.0, 244 / 255.0, 232 / 255.0, 120 / 255.0)
const GLINT := Color(248 / 255.0, 244 / 255.0, 232 / 255.0, 200 / 255.0)

## What each child control draws.
const PART_GLASS := 0
const PART_ZOOM := 1
const PART_RIM := 2

## How many arguments `Sfx.play_hive` takes, asked once: -2 not asked yet.
static var _hive_args := -2

var _roll := RandomNumberGenerator.new()
var _queen := Crawler.new()
var _bees: Array[Crawler] = []
var _court: Array[Crawler] = []
var _court_spin := 0.0
var _court_ring := 1.0
var _calm := 1.0
## The comb on the art grid, the patches the workers and the queen keep to, and where the
## gloves hold the frame.
var _comb_box := Rect2()
var _roam := Rect2()
var _queen_roam := Rect2()
var _ear_l := FRAME_AT + EAR_L
var _ear_r := FRAME_AT + EAR_R
## The glass's middle, painted pixels, eased; the pad's offset of it from the pointer; the
## pointer last frame; whether a hook is holding it.
var _lens := Vector2.ZERO
var _pull := Vector2.ZERO
var _last_pointer := Vector2.ZERO
var _hold := false
var _since_try := 0.0
var _shake := 0.0
var _press := 0.0
var _warm := 0.0
var _found := false
var _found_age := 0.0
var _halo := 0.0
var _twinkle := 0.0
## `{at (painted px), age, life, arm}`.
var _stars: Array[Dictionary] = []
## Laid out once: runs of one colour along a row, `[Vector2i start, int long, Color]`,
## relative to the glass's middle pixel.
var _disc_runs: Array = []
var _rim_runs: Array = []
var _handle_runs: Array = []
var _halo_runs: Array = []
var _shade_rows: Array[Rect2] = []
var _glass: Part
var _zoom: Part
var _rim: Part


func _ready() -> void:
	_disc_runs = _disc()
	_rim_runs = _rim_pixels()
	_handle_runs = _handle_pixels()
	_halo_runs = _halo_pixels()
	_shade_rows = _hive_shade()
	# The disc is the clip; its child draws the scene magnified and is shown only inside it.
	# **A clip parent that draws nothing clips nothing** (the puddles' mirror, CLAUDE.md), so
	# the disc is drawn on every frame the glass is up.
	_glass = _part(PART_GLASS)
	_glass.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	add_child(_glass)
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_zoom = _part(PART_ZOOM)
	_glass.add_child(_zoom)
	_zoom.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rim = _part(PART_RIM)
	add_child(_rim)
	_rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _part(what: int) -> Part:
	var made := Part.new()
	made.name = StringName("Lens%d" % what)
	made.step = self
	made.what = what
	made.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return made


## Start over: the same comb off the same seed, nobody found, the glass at the pointer (or on
## the pad, over the middle of the comb, since the pointer is hidden and could be anywhere).
func begin() -> void:
	super.begin()
	_roll.seed = SEED
	_lay_comb()
	_found = false
	_found_age = 0.0
	_halo = 0.0
	_warm = 0.0
	_calm = 1.0
	_shake = 0.0
	_press = 0.0
	_since_try = TRY_GAP
	_hold = false
	_twinkle = 0.0
	_stars.clear()
	_pull = Vector2.ZERO
	_court_spin = 0.0
	_court_ring = 1.0
	_queen = Crawler.new()
	_queen.pos = QUEEN_START.clamp(_queen_roam.position, _queen_roam.end)
	_queen.dir = PI
	_queen.face = FACE_L
	_queen.retarget = 1.0
	_place_workers()
	_place_court()
	_lens = _comb_box.get_center()
	if is_inside_tree():
		_last_pointer = art_mouse()
		if Pad.is_pad():
			_pull = _lens - _last_pointer
		else:
			_lens = _last_pointer.clamp(Vector2.ZERO, HiveArt.GRID)


# --- the harness's hooks, never gated on `awake` -------------------------------------------

## Look for her with the glass's middle at `p` (painted pixels of the art grid). True when she
## is there — the payoff starts and `finished` follows `PAYOFF_HOLD` seconds later — or was
## found already. A miss scatters the bees round `p` and returns false.
func find_at(p: Vector2) -> bool:
	if _found:
		return true
	if p.distance_to(_queen.pos) <= FIND_REACH:
		_lens = p
		_find()
		return true
	_miss(p)
	return false


## Where she is now, painted pixels of the art grid: the middle of her picture.
func queen_pos() -> Vector2:
	return _queen.pos


## Where the glass's middle is now, painted pixels.
func lens_pos() -> Vector2:
	return _lens


## Put the glass at `p` and hold it there until the pointer or the stick moves: for a probe's
## picture, which has no hand on the mouse.
func aim(p: Vector2) -> void:
	_lens = p
	_hold = true


func is_found() -> bool:
	return _found


## Find her where she stands and say `finished` at once, the payoff cut short.
func settle() -> void:
	if not _found:
		find_at(_queen.pos)
	done_once()


# --- the player -----------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_attempt()


## A click, from the mouse or the pad: looked for where the glass is, as the player sees it.
func _attempt() -> void:
	if _found or not awake() or _since_try < TRY_GAP:
		return
	_since_try = 0.0
	_press = 1.0
	find_at(_lens)


func _process(delta: float) -> void:
	_since_try += delta
	_drive_lens(delta)
	if Pad.is_pad() and awake() and (
		Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"cast")
	):
		_attempt()
	_walk_queen(delta)
	_walk_court(delta)
	_walk_workers(delta)
	_drive_payoff(delta)
	if _glass != null:
		_glass.queue_redraw()
		_zoom.queue_redraw()
		_rim.queue_redraw()


## The glass after the pointer (eased), or onto her once she is found.
func _drive_lens(delta: float) -> void:
	var target := _lens
	var rate := LENS_EASE
	if _found:
		target = _queen.pos
		rate = SETTLE_EASE
	elif is_inside_tree():
		var pad := Pad.is_pad()
		if pad and awake():
			pad_move(delta)
		var pointer := art_mouse()
		var moved := pointer - _last_pointer
		_last_pointer = pointer
		if moved.length_squared() > 0.01 or (pad and _stick().length() > PAD_DEAD):
			_hold = false
		if pad:
			if awake():
				_assist(delta, moved)
		else:
			_pull = Vector2.ZERO
		if not _hold:
			target = (pointer + _pull).clamp(Vector2.ZERO, HiveArt.GRID)
			# Held at the grid's edge, the pull does not wind up past it.
			_pull = target - pointer
	_lens = _lens.lerp(target, 1.0 - exp(-rate * delta))


func _stick() -> Vector2:
	return Input.get_vector(&"walk_left", &"walk_right", &"walk_up", &"walk_down")


## The pad's gentle pull (see the header): only while the stick is pushed.
func _assist(delta: float, moved: Vector2) -> void:
	var stick := _stick()
	if stick.length() < PAD_DEAD:
		return
	var toward := _queen.pos - _lens
	var dist := toward.length()
	if dist <= FIND_REACH:
		_pull -= moved * (1.0 - FRICTION)
		return
	if dist > LENS_R * PULL_REACH or dist < 0.001:
		return
	if toward.normalized().dot(stick.normalized()) < AHEAD:
		return
	var push := pow(minf(stick.length(), 1.0), PAD_CURVE)
	var speed := push * PAD_SPEED * size.y / HiveArt.PIXEL
	_pull += toward.normalized() * minf(speed * PULL, dist / maxf(delta, 0.0001)) * delta


func _find() -> void:
	_found = true
	_found_age = 0.0
	var q := _queen.pos
	for k in BURST.size():
		var burst: Vector3 = BURST[k]
		_add_star(q + Vector2(burst.x, burst.y), int(burst.z), -0.04 * k)
	for k in RING_STARS:
		var angle := TAU * k / RING_STARS + _roll.randf_range(-0.3, 0.3)
		_add_star(
			q + Vector2.from_angle(angle) * (LENS_R + 9.0), 1 + _roll.randi() % 2,
			-_roll.randf_range(0.05, 0.3)
		)
	_hive_sound(&"hive_crown")


## A miss for the harness, as a click beside her would be.
func miss_at(p: Vector2) -> void:
	if not _found:
		_miss(p)


## How many workers have buzzed off the frame after a miss.
func flown() -> int:
	var n := 0
	for b: Crawler in _bees:
		if b.life >= 0.0:
			n += 1
	return n


func _miss(p: Vector2) -> void:
	_shake = 1.0
	var hit := 0
	var nearest: Crawler = null
	var near := MISS_REACH
	for b: Crawler in _bees:
		if b.life >= 0.0:
			continue
		var d := b.pos.distance_to(p)
		if d < near:
			near = d
			nearest = b
	if nearest != null:
		# That bee buzzes off the frame and away.
		var away := (nearest.pos - p).normalized() if near > 0.5 else Vector2.from_angle(_roll.randf() * TAU)
		nearest.kick = (away + Vector2(0.0, -0.8)).normalized() * 90.0
		nearest.life = 1.2
		nearest.buzz = 1.2
		hit += 1
	for b: Crawler in _bees:
		if b.life < 0.0 and _scatter(b, p, 0.35):
			hit += 1
	for b: Crawler in _court:
		if _scatter(b, p, COURT_SCATTER):
			hit += 1
	if hit > 0:
		_hive_sound(&"hive_swarm", MISS_DB, MISS_PITCH)


## Kick one bee away from `p` if it is under the glass there. True when it was.
func _scatter(b: Crawler, p: Vector2, share: float) -> bool:
	var off := b.pos - p
	if off.length() > MISS_REACH:
		return false
	var away := Vector2.from_angle(_roll.randf() * TAU)
	if off.length() > 0.01:
		away = off.normalized()
	away = away.rotated(_roll.randf_range(-0.5, 0.5))
	b.kick += away * _roll.randf_range(SCATTER.x, SCATTER.y) * share
	b.buzz = BUZZ_TIME
	b.rest = 0.0
	b.dir = away.angle()
	return true


func _add_star(at: Vector2, arm: int, age_now: float) -> void:
	_stars.append({"at": at, "age": age_now, "life": STAR_LIFE, "arm": arm})


## The eases that are not the walks: the shake and the press dying away, the warmth, the
## stars, and once she is found the halo, the twinkles and `finished`.
func _drive_payoff(delta: float) -> void:
	_shake *= exp(-SHAKE_EASE * delta)
	if _shake < 0.01:
		_shake = 0.0
	_press *= exp(-PRESS_EASE * delta)
	var sees := not _found and _lens.distance_to(_queen.pos) <= LENS_R / ZOOM
	_warm = lerpf(_warm, 1.0 if sees else 0.0, 1.0 - exp(-WARM_EASE * delta))
	var kept: Array[Dictionary] = []
	for star: Dictionary in _stars:
		star["age"] = float(star["age"]) + delta
		if float(star["age"]) < float(star["life"]):
			kept.append(star)
	_stars = kept
	if not _found:
		return
	_found_age += delta
	_halo = lerpf(_halo, 1.0, 1.0 - exp(-HALO_EASE * delta))
	_twinkle -= delta
	if _twinkle <= 0.0:
		_twinkle = TWINKLE_EVERY
		_add_star(
			_crown_at() + Vector2(_roll.randf_range(-14.0, 14.0), _roll.randf_range(-8.0, 8.0)),
			1, 0.0
		)
	if _found_age >= PAYOFF_HOLD and not is_done():
		done_once()


# --- the comb and its walkers ---------------------------------------------------------------

func _lay_comb() -> void:
	var marks := HiveArt.anchors(&"frame_brood")
	var tl: Vector2 = marks.get(&"inner_tl", COMB_TL)
	var br: Vector2 = marks.get(&"inner_br", COMB_BR)
	var ear_l: Vector2 = marks.get(&"ear_l", EAR_L)
	var ear_r: Vector2 = marks.get(&"ear_r", EAR_R)
	_comb_box = Rect2(FRAME_AT + tl, br - tl)
	_roam = _comb_box.grow(-ROAM_IN)
	_queen_roam = _comb_box.grow_individual(
		-QUEEN_MARGIN.x, -QUEEN_MARGIN.y, -QUEEN_MARGIN.x, -QUEEN_MARGIN.y
	)
	_ear_l = FRAME_AT + ear_l
	_ear_r = FRAME_AT + ear_r


## The mockup's rule: spread over the comb, clear of her court, no two in one box.
func _place_workers() -> void:
	_bees.clear()
	var taken := {}
	var tries := 0
	while _bees.size() < WORKERS and tries < 40000:
		tries += 1
		var at := Vector2(
			_roll.randf_range(_roam.position.x, _roam.end.x),
			_roll.randf_range(_roam.position.y, _roam.end.y)
		)
		var off := at - _queen.pos
		if Vector2(off.x, off.y * 1.4).length() < WORKER_CLEAR:
			continue
		var cell := Vector2i(floori(at.x / WORKER_SPACE.x), floori(at.y / WORKER_SPACE.y))
		var crowded := false
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				for other: Vector2 in taken.get(cell + Vector2i(dx, dy), []):
					if absf(other.x - at.x) < WORKER_SPACE.x and absf(other.y - at.y) < WORKER_SPACE.y:
						crowded = true
		if crowded:
			continue
		if not taken.has(cell):
			taken[cell] = []
		(taken[cell] as Array).append(at)
		var b := Crawler.new()
		b.pos = at
		b.life = -1.0
		b.dir = _roll.randf() * TAU
		b.speed = _roll.randf_range(WORKER_SPEED.x, WORKER_SPEED.y)
		b.retarget = _roll.randf_range(0.0, RETARGET.y)
		b.phase = _roll.randf() * 2.0
		b.face = _face_of(Vector2.from_angle(b.dir), FACE_R)
		_bees.append(b)


func _place_court() -> void:
	_court.clear()
	for k in COURT:
		var b := Crawler.new()
		b.phase = TAU * k / COURT
		b.pos = _queen.pos + Vector2(cos(b.phase) * COURT_RING.x, sin(b.phase) * COURT_RING.y)
		b.face = _face_of(_queen.pos - b.pos, FACE_R)
		_court.append(b)


func _walk_workers(delta: float) -> void:
	_calm = lerpf(_calm, CALM if _found else 1.0, 1.0 - exp(-CALM_EASE * delta))
	var settle_kick := 1.0 - exp(-KICK_EASE * delta)
	var ease_spin := 1.0 - exp(-SPIN_EASE * delta)
	var flying: Array[Crawler] = []
	for b: Crawler in _bees:
		if b.life >= 0.0:
			b.pos += b.kick * delta
			b.kick.y -= 30.0 * delta
			b.life -= delta
			b.buzz = 1.0
			b.face = FACE_L if b.kick.x < 0.0 else FACE_R
			if b.life < 0.0:
				flying.append(b)
				b.life = 0.0
			continue
		b.retarget -= delta
		if b.retarget <= 0.0:
			b.retarget = _roll.randf_range(RETARGET.x, RETARGET.y)
			b.spin_want = _roll.randf_range(-WORKER_SPIN, WORKER_SPIN)
			if _roll.randf() < WORKER_REST_ODDS:
				b.rest = _roll.randf_range(WORKER_REST.x, WORKER_REST.y)
		b.spin = lerpf(b.spin, b.spin_want, ease_spin)
		b.dir += b.spin * _calm * delta
		_steer_home(b, _roam, delta)
		var off := b.pos - _queen.pos
		if Vector2(off.x, off.y * 1.4).length() < WORKER_CLEAR:
			_steer_to(b, off.angle(), delta)
		var step := Vector2.ZERO
		if b.rest > 0.0:
			b.rest -= delta
		else:
			step = Vector2.from_angle(b.dir) * b.speed * _calm
		b.pos += (step + b.kick) * delta
		b.kick = b.kick.lerp(Vector2.ZERO, settle_kick)
		b.buzz = maxf(b.buzz - delta, 0.0)
		b.pos = b.pos.clamp(_roam.position - Vector2.ONE * 4.0, _roam.end + Vector2.ONE * 4.0)
		var heading := step + b.kick
		if heading.length_squared() < 0.0001:
			# Stopped at a cell, it still turns about on the spot.
			heading = Vector2.from_angle(b.dir)
		b.face = _face_of(heading, b.face)
	for b: Crawler in flying:
		_bees.erase(b)
	# Drawn back to front, so a bee lower on the frame is over one above it.
	_bees.sort_custom(func(a: Crawler, b: Crawler) -> bool: return a.pos.y < b.pos.y)


func _walk_queen(delta: float) -> void:
	var q := _queen
	if _found:
		return
	q.retarget -= delta
	if q.retarget <= 0.0:
		q.retarget = _roll.randf_range(RETARGET.x, RETARGET.y) * 1.5
		q.spin_want = _roll.randf_range(-QUEEN_SPIN, QUEEN_SPIN)
		if _roll.randf() < QUEEN_REST_ODDS:
			q.rest = _roll.randf_range(QUEEN_REST.x, QUEEN_REST.y)
	q.spin = lerpf(q.spin, q.spin_want, 1.0 - exp(-SPIN_EASE * delta))
	q.dir += q.spin * delta
	_steer_home(q, _queen_roam, delta)
	var step := Vector2.ZERO
	if q.rest > 0.0:
		q.rest -= delta
	else:
		step = Vector2.from_angle(q.dir) * QUEEN_SPEED
	q.pos += step * delta
	q.pos = q.pos.clamp(_queen_roam.position - Vector2.ONE * 3.0, _queen_roam.end + Vector2.ONE * 3.0)
	# She is drawn facing left or right only: the sheet has her side on.
	var across := cos(q.dir)
	if across > FACE_KEEP:
		q.face = FACE_R
	elif across < -FACE_KEEP:
		q.face = FACE_L


func _walk_court(delta: float) -> void:
	if not _found:
		_court_spin += COURT_TURN * delta
	_court_ring = lerpf(_court_ring, COURT_TIGHT if _found else 1.0, 1.0 - exp(-CALM_EASE * delta))
	var follow := 1.0 - exp(-COURT_EASE * delta)
	var settle_kick := 1.0 - exp(-KICK_EASE * delta)
	for k in _court.size():
		var b := _court[k]
		var angle := _court_spin + b.phase
		var wobble := Vector2(sin(age * 1.7 + k) * 1.0, cos(age * 1.3 + k * 2.0) * 0.6) * _calm
		var place := _queen.pos + Vector2(
			cos(angle) * COURT_RING.x, sin(angle) * COURT_RING.y
		) * _court_ring + wobble
		b.pos = b.pos.lerp(place, follow) + b.kick * delta
		b.kick = b.kick.lerp(Vector2.ZERO, settle_kick)
		b.buzz = maxf(b.buzz - delta, 0.0)
		b.face = _face_of(_queen.pos - b.pos, b.face)


## Off its patch, a walker turns back towards the patch's middle.
func _steer_home(b: Crawler, box: Rect2, delta: float) -> void:
	if box.has_point(b.pos):
		return
	_steer_to(b, (box.get_center() - b.pos).angle(), delta)


func _steer_to(b: Crawler, want: float, delta: float) -> void:
	b.dir += wrapf(want - b.dir, -PI, PI) * minf(TURN_HOME * delta, 1.0)


## Which way a walker heading `v` is drawn: right, left, up or down, kept as it was unless the
## new way is `FACE_KEEP` more its heading.
static func _face_of(v: Vector2, was: int) -> int:
	if v.length_squared() < 0.0001:
		return was
	var n := v.normalized()
	var scores: Array[float] = [n.x, -n.x, -n.y, n.y]
	var best := clampi(was, 0, 3)
	var top := scores[best] + FACE_KEEP
	for k in 4:
		if scores[k] > top:
			top = scores[k]
			best = k
	return best


func _crown_at() -> Vector2:
	var rise := _ease_out(clampf(_found_age / CROWN_RISE, 0.0, 1.0))
	var bob := 0.0
	if _found_age > CROWN_RISE:
		bob = roundf(sin((_found_age - CROWN_RISE) * 4.0))
	return _queen.pos + Vector2(0.0, -lerpf(4.0, CROWN_UP, rise) + bob)


static func _ease_out(t: float) -> float:
	return 1.0 - pow(1.0 - t, 3.0)


## Overshoots a little and comes back: a pop.
static func _back_out(t: float) -> float:
	var over := 1.70158
	var s := t - 1.0
	return 1.0 + (over + 1.0) * s * s * s + over * s * s


## A hive sound through `Sfx.play_hive` where the sounds have it, else straight through
## `Sfx.play`; nothing where there is no sound board at all.
static func _hive_sound(what: StringName, db := 0.0, pitch := 1.0) -> void:
	var sfx := Sfx.main()
	if sfx == null:
		return
	if not sfx.has_method(&"play_hive"):
		sfx.play(what, db, pitch)
		return
	if _hive_args == -2:
		_hive_args = 1
		for method: Dictionary in sfx.get_method_list():
			if String(method.get("name", "")) == "play_hive":
				_hive_args = (method.get("args", []) as Array).size()
				break
	match _hive_args:
		0:
			return
		1:
			sfx.call(&"play_hive", what)
		2:
			sfx.call(&"play_hive", what, db)
		_:
			sfx.call(&"play_hive", what, db, pitch)


# --- the pad --------------------------------------------------------------------------------

## The stick is the step's from start to end, the payoff included: the room's rule, so an A
## pressed while the crown pops does not land on the close cross.
func pad_free() -> bool:
	return true


## The glass, ringed while she is still to be found.
func pad_mark() -> Rect2:
	if _found:
		return Rect2()
	var middle := _lens_canvas() + Vector2.ONE * HiveArt.PIXEL * 0.5
	var half := (LENS_R + 6) * HiveArt.PIXEL
	return Rect2(middle - Vector2.ONE * half, Vector2.ONE * half * 2.0)


# --- drawing --------------------------------------------------------------------------------

## The glass's middle pixel, on the grid: shaken sideways by a miss, dipped a pixel by a press.
func _lens_px() -> Vector2:
	var at := _lens.floor()
	at.x += roundf(sin(age * SHAKE_RATE) * SHAKE_PX * _shake)
	if _press > 0.5:
		at.y += 1.0
	return at


func _lens_canvas() -> Vector2:
	return to_canvas(_lens_px())


func _draw() -> void:
	_draw_scene(self, Vector2.ZERO, 0.0)
	var at := _lens_canvas()
	var pulse := 0.85 + 0.15 * sin(age * 5.0)
	var glow := maxf(_halo * pulse, _warm * WARM_HALO)
	if glow > 0.01:
		_draw_runs(self, _halo_runs, at, glow)
	_draw_runs(self, _handle_runs, at)


## What the three children draw: the disc (the clip), the scene twice the size inside it,
## and over both the rim, the crown and the stars.
func _draw_part(ci: CanvasItem, what: int) -> void:
	var at := _lens_canvas()
	match what:
		PART_GLASS:
			_draw_runs(ci, _disc_runs, at)
		PART_ZOOM:
			var middle := at + Vector2.ONE * HiveArt.PIXEL * 0.5
			ci.draw_set_transform(middle * (1.0 - ZOOM), 0.0, Vector2(ZOOM, ZOOM))
			_draw_scene(ci, _lens_px(), LENS_R / ZOOM + 8.0)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			var half := (LENS_R + 1) * HiveArt.PIXEL
			ci.draw_rect(Rect2(middle - Vector2.ONE * half, Vector2.ONE * half * 2.0), GLASS_TINT)
		PART_RIM:
			_draw_runs(ci, _rim_runs, at)
			if _found:
				var grow := CROWN_SCALE * _back_out(clampf(_found_age / CROWN_POP, 0.0, 1.0))
				if grow > 0.05:
					HiveArt.draw(
						ci, &"crown", to_canvas(_crown_at().floor()), &"c", false,
						clampf(_found_age / 0.1, 0.0, 1.0), grow
					)
			for star: Dictionary in _stars:
				var star_age := float(star["age"])
				if star_age < 0.0:
					continue
				var t := clampf(star_age / float(star["life"]), 0.0, 1.0)
				var bright := sin(t * PI)
				HiveArt.star(ci, to_canvas(star["at"]), int(roundf(float(star["arm"]) * bright)), bright)


## The hive and its shadow, the frame, the workers, the court, the queen and the gloves. With
## a `reach`, only the bees within it of `near` are drawn (the magnified pass, where the rest
## would be clipped away anyway).
func _draw_scene(ci: CanvasItem, near: Vector2, reach: float) -> void:
	# Whole painted px along the sun, so the rows stay on the picture's grid.
	var nudge := Shade.drop(null, CONTACT_RISE).round()
	var shade_ink := Shade.tint_on(null, Shade.On.LAND)
	for row: Rect2 in _shade_rows:
		ci.draw_rect(Rect2(to_canvas(row.position + nudge), row.size * HiveArt.PIXEL), shade_ink)
	HiveArt.draw(ci, &"rest", to_canvas(FRAME_AT), &"frame_tl")
	if HiveArt.has(&"frame_brood"):
		HiveArt.draw(ci, &"frame_brood", to_canvas(FRAME_AT))
	else:
		var frame := Rect2(to_canvas(FRAME_AT), (COMB_BR + Vector2(20.0, 7.0)) * HiveArt.PIXEL)
		ci.draw_rect(frame, HiveArt.WAX_WALL)
		ci.draw_rect(Rect2(to_canvas(_comb_box.position), _comb_box.size * HiveArt.PIXEL), HiveArt.WAX)
	for b: Crawler in _bees:
		if reach > 0.0 and b.pos.distance_to(near) > reach:
			continue
		_draw_bee(ci, b)
	for b: Crawler in _court:
		if reach > 0.0 and b.pos.distance_to(near) > reach + COURT_RING.x:
			continue
		_draw_bee(ci, b)
	var queen_at := to_canvas(_queen.pos.floor())
	if HiveArt.has(&"queen_long"):
		HiveArt.draw(ci, &"queen_long", queen_at, &"c", _queen.face == FACE_L)
	else:
		ci.draw_rect(Rect2(queen_at - Vector2(5.0, 2.0) * HiveArt.PIXEL, Vector2(10.0, 4.0) * HiveArt.PIXEL), HiveArt.BEE_GOLD)
		ci.draw_rect(Rect2(queen_at, Vector2.ONE * HiveArt.PIXEL), HiveArt.TRIM)
	# Two workers always over her back, so she has to be looked for.
	for k in 2:
		var over := _queen.pos + Vector2(-3.0 + k * 6.0, -3.0 + k * 3.0)
		if reach <= 0.0 or over.distance_to(near) <= reach:
			HiveArt.draw(ci, &"bee_r_rest", to_canvas(over.floor()), &"c", k == 0)
	# Unfound long enough, a faint glint winks on her.
	if not _found and age > HINT_AFTER:
		var wink := fmod(age - HINT_AFTER, HINT_EVERY) / 0.6
		if wink < 1.0:
			HiveArt.star(ci, to_canvas(_queen.pos + Vector2(2.0, -4.0)), 1, 0.45 * sin(wink * PI))


## One bee on its whole painted pixel, drawn the way it faces; a scattered one side on with
## its wings fluttering, since only the side-on picture has wings to lift.
func _draw_bee(ci: CanvasItem, b: Crawler) -> void:
	var at := to_canvas(b.pos.floor())
	if b.life >= 0.0:
		var flap := &"bee_r" if fmod(age * FLUTTER, 2.0) < 1.0 else &"bee_r_rest"
		HiveArt.draw(ci, flap, at, &"c", b.face == FACE_L, clampf(b.life / 0.5, 0.0, 1.0))
		return
	var face := b.face
	if b.buzz > 0.0 and (face == FACE_U or face == FACE_D):
		face = FACE_L if b.kick.x < 0.0 else FACE_R
	var piece := &"bee_r_rest"
	if face == FACE_U:
		piece = &"bee_u"
	elif face == FACE_D:
		piece = &"bee_d"
	elif b.buzz > 0.0 and fmod(age * FLUTTER + b.phase, 2.0) < 1.0:
		piece = &"bee_r"
	if HiveArt.has(piece):
		HiveArt.draw(ci, piece, at, &"c", face == FACE_L)
		return
	var cell := Vector2.ONE * HiveArt.PIXEL
	ci.draw_rect(Rect2(at - Vector2(HiveArt.PIXEL, 0.0), Vector2(3.0, 2.0) * HiveArt.PIXEL), HiveArt.BEE_GOLD)
	ci.draw_rect(Rect2(at, cell), HiveArt.BEE_STRIPE)


## Runs laid out round the glass's middle pixel, its top left at `at` in canvas pixels.
static func _draw_runs(ci: CanvasItem, runs: Array, at: Vector2, alpha := 1.0) -> void:
	for run: Array in runs:
		var start: Vector2i = run[0]
		var long: int = run[1]
		var ink: Color = run[2]
		ci.draw_rect(
			Rect2(at + Vector2(start) * HiveArt.PIXEL, Vector2(long, 1.0) * HiveArt.PIXEL),
			Color(ink, ink.a * alpha)
		)


# --- the glass, laid out once: the mockup's `lens` pixel for pixel --------------------------

## A pixel map (`Vector2i` -> `Color`) as runs of one colour along each row.
static func _runs(pixels: Dictionary) -> Array:
	var keys: Array = pixels.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var out: Array = []
	var start := Vector2i.ZERO
	var run := 0
	var ink := Color()
	for key: Vector2i in keys:
		var color: Color = pixels[key]
		if run > 0 and key.y == start.y and key.x == start.x + run and color == ink:
			run += 1
			continue
		if run > 0:
			out.append([start, run, ink])
		start = key
		run = 1
		ink = color
	if run > 0:
		out.append([start, run, ink])
	return out


## The glass itself: every pixel within the rim's inner line. Its colour does not matter; it
## is the clip.
static func _disc() -> Array:
	var pixels := {}
	for y in range(-LENS_R, LENS_R + 1):
		for x in range(-LENS_R, LENS_R + 1):
			if sqrt(float(x * x + y * y)) <= LENS_R - 0.5:
				pixels[Vector2i(x, y)] = Color.WHITE
	return _runs(pixels)


## The brass rim between two outlines, lit on its upper left and shaded on its lower right,
## the sheen arc inside it, and the one glint.
static func _rim_pixels() -> Array:
	var pixels := {}
	var r := float(LENS_R)
	for y in range(-LENS_R - 6, LENS_R + 7):
		for x in range(-LENS_R - 6, LENS_R + 7):
			var q := sqrt(float(x * x + y * y))
			var lean := float(-x - y) / maxf(q, 1.0)
			if (q > r - 0.5 and q <= r + 0.5) or (q > r + 4.5 and q <= r + 5.5):
				pixels[Vector2i(x, y)] = HiveArt.OUT
			elif q > r + 0.5 and q <= r + 4.5:
				var brass := BRASS_BASE
				if lean > 0.45:
					brass = BRASS_LIT
				elif lean < -0.45:
					brass = BRASS_SHADE
				pixels[Vector2i(x, y)] = brass
			elif q > r - 9.0 and q < r - 5.0 and lean > 0.8:
				pixels[Vector2i(x, y)] = SHEEN
	var half := floori(r * 0.5)
	pixels[Vector2i(-half, -half - 4)] = GLINT
	return _runs(pixels)


## The handle, down and to the right at forty-five degrees: a brass collar, then dark wood,
## lit along its upper side, inked round, capped at its end. Worked out per pixel back along
## the handle's own axis, so the diagonal has no holes in it.
static func _handle_pixels() -> Array:
	var pixels := {}
	var r := float(LENS_R)
	var along := Vector2(cos(PI * 0.25), sin(PI * 0.25))
	var across := Vector2(-along.y, along.x)
	var reach := LENS_R + 48
	for y in range(0, reach):
		for x in range(0, reach):
			var p := Vector2(x, y)
			var k := p.dot(along)
			var w := p.dot(across)
			if absf(w) > 5.5 or k < r + 1.5 or k > r + 40.5:
				continue
			var ink := WOOD
			if absf(w) > 4.5 or k > r + 39.5:
				ink = HiveArt.OUT
			elif k < r + 10.0:
				ink = BRASS_LIT if w < -1.5 else (BRASS_BASE if w < 2.5 else BRASS_SHADE)
			else:
				ink = WOOD_HI if w < -1.5 else (WOOD if w < 2.5 else WOOD_LO)
			pixels[Vector2i(x, y)] = ink
	return _runs(pixels)


## The found halo: a band of gold outside the rim, fading outwards in six whole-pixel steps.
static func _halo_pixels() -> Array:
	var pixels := {}
	var r := float(LENS_R)
	for y in range(-LENS_R - 11, LENS_R + 12):
		for x in range(-LENS_R - 11, LENS_R + 12):
			var q := sqrt(float(x * x + y * y))
			if q <= r + 4.0 or q >= r + 10.0:
				continue
			var band := clampi(int(q - r - 4.0), 0, 5)
			pixels[Vector2i(x, y)] = Color(HiveArt.GOLD, 90.0 / 255.0 * (1.0 - (band + 0.5) / 6.0))
	return _runs(pixels)


## The hive's shadow on the lawn, as whole-pixel rows of the mockup's ellipse (painted px).
static func _hive_shade() -> Array[Rect2]:
	var rows: Array[Rect2] = []
	var top := floori(HIVE_SHADE_MID.y - HIVE_SHADE_HALF.y)
	var foot := ceili(HIVE_SHADE_MID.y + HIVE_SHADE_HALF.y)
	for y in range(top, foot):
		var dy := (y + 0.5 - HIVE_SHADE_MID.y) / HIVE_SHADE_HALF.y
		if absf(dy) >= 1.0:
			continue
		var half := HIVE_SHADE_HALF.x * sqrt(1.0 - dy * dy)
		var from := roundf(HIVE_SHADE_MID.x - half)
		var to := roundf(HIVE_SHADE_MID.x + half)
		if to > from:
			rows.append(Rect2(from, y, to - from, 1.0))
	return rows


## A bee on the comb, the queen included: where it is, which way it walks and how it turns,
## a stop at a cell, a scatter's kick, and which way it is drawn. `phase` is a court bee's
## place on the ring, and any bee's flutter offset.
class Crawler:
	extends RefCounted

	var pos := Vector2.ZERO
	var dir := 0.0
	var speed := 6.0
	var spin := 0.0
	var spin_want := 0.0
	var retarget := 0.0
	var rest := 0.0
	var kick := Vector2.ZERO
	var buzz := 0.0
	## Seconds left of a flight off the frame after a miss; negative while it is on the comb.
	var life := -1.0
	var face := 0
	var phase := 0.0


## One of the glass's three layers: a control over the whole step that ignores the mouse and
## asks the step to draw it.
class Part:
	extends Control

	var step: HiveStepQueen
	var what := 0

	func _draw() -> void:
		if step != null:
			step._draw_part(self, what)

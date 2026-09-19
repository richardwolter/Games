## A find held up to the player: the piece that just came out of the water, shining, with
## a line saying what it is.
##
## The shed is the only place a find is ever seen properly, and the shed is behind two
## clicks — so a player pulling a wardrobe out of a lake got a line of small text in the
## corner and nothing else. This is the moment that was missing: the thing itself, big, in
## the middle of the screen.
##
## **As it came up, grimy, and wearing the lake's own shine** (2026-09-19, issue #30,
## Richard: the card "feels generic" and the disc behind it was "blocky and doesn't blend in
## well with the style"). Two changes that go together:
##
## - The picture is the **dirty** sprite (`Sheets.region_of`), not the restored one. It used
##   to be the restored one, on the reasoning that the card should show what the find will
##   become. The pump changed what is true: a netted find goes to `unwashed` and the shed
##   will not have it until it is washed, so a card showing the clean picture was showing
##   the end of an errand the player has not run yet.
## - The light round it is the **finds' own** — the gold column, the four-point stars and
##   the gold rim that the lake and the net already put on a find (`LakeGrid.GlintBeam`,
##   `GlintTwinkle`, `shaders/rim.gdshader`). It used to be a wheel of rays, a dust of motes
##   and five stacked dark discs, which is a shape nothing else in this game draws.
##
## The rim is what makes the first change survive the second. A grimy picture drawn on a
## grimy lake is a picture lost in a field of bottles, which is exactly what the dark pool
## was there to prevent; a gold outline separates the piece from the water without laying a
## circle over the game. The retired disc's comment said so, and it was right about the
## problem and wrong about the answer.
##
## The three shine layers are copied from `CastNet`'s `CatchRim`/`CatchBeam`/`CatchStars`
## rather than reusing `LakeGrid`'s own `GlintBeam`/`GlintTwinkle`: those are tile-bound —
## every line of them indexes `grid.stacks[i]`, `grid.swing[i]`, `grid.surface_pos(i)` — and
## a card has no tile. Only the two static helpers and the two shaders travel. The net's
## `show_behind_parent` does **not** travel with them: there the net draws the catch itself,
## so behind the parent is behind the piece, while here the piece is a child, and the rim
## simply goes in before it.
##
## Drawn rather than built from nodes, like the farewell screen and the shop board. It
## never blocks the lake: the mouse goes straight through it, the angler keeps their legs,
## nothing is dimmed, and a second find arriving while one is up is queued behind it rather
## than lost. It sits low and small on purpose — this happens mid-cast, and a card that
## takes the middle of the screen takes the lake away from a player who is still fishing.
class_name Trophy
extends Control

const Style := preload("res://scripts/style.gd")

## The find's own gold, turned on by drawing in pure green. `CastNet.RIM_SHADER` is the same
## file; both are copies of the one rule, not two rules.
const RIM_SHADER := preload("res://shaders/rim.gdshader")

## What is always said. The name of the piece goes underneath it.
##
## It says where the find went, not what it is (2026-09-19, Richard): since the pump, a
## netted find waits at the pump and the shed will not take it until it has been washed.
## "You got a new decoration" was true and led nowhere.
const TITLE := "New decoration available to wash"

## The three parts of one showing, in seconds: the pop in, how long it is held, and the
## fade out. Short — this happens mid-cast, and a player who is fishing should not be made
## to wait for a card to leave.
const RISE := 0.42
const HOLD := 1.9
const LEAVE := 0.5

## Where the card sits, as a fraction of the window's height. Down in the open water under
## the island, clear of the HUD along the top and of the buttons in the corners.
const MIDDLE := 0.79

## The piece's height as a fraction of the window's, and the most it may be blown up from
## its own pixels. Furniture is cut small; past a point it stops being a picture of a chair
## and becomes a grid of squares.
const PIECE_HEIGHT := 0.13
const PIECE_ZOOM := 4.5

## The beam behind the piece: how wide the column is as a share of the drawn picture's
## larger side, and how far under its foot the column starts.
##
## The lake gives every find the same width, so a lamp and a sofa throw the same column
## (`LakeGrid.beam_width`). The card has no lake to ask and one piece on screen at a time,
## so it is sized to the picture instead — there is nothing beside it to be out of step
## with, and a fixed width would be a thumb's breadth behind a wardrobe.
const BEAM_WIDE := 0.55
const BEAM_SINK := 0.06

## How thick the gold rim is drawn, in screen pixels. The lake's `RIM_STEP` is one world
## pixel against sprites drawn at 2, so it is half an art pixel there; the card blows the
## picture up to `PIECE_ZOOM`, and a rim scaled with it would be a gold band. Held at a
## couple of screen pixels instead: it is an outline, not a frame.
const RIM_STEP := 2.0

## How much faster the rim fades than the picture in front of it. See `_draw_rim`.
const RIM_FADE := 3.0

## How big a star is drawn here, as a multiple of `LakeGrid.STAR_PIXEL`. The lake's stars
## are one art pixel against a piece drawn at 2; the card's piece is four or five times
## that, so a star left at its lake size is a speck on it.
const STAR_BIG := 2.5

## Emitted when the last queued find has left the screen, so the lake can hush whatever it
## turned on for it.
signal emptied

## The atlas the pieces are cut from. Set by the lake before anything is shown.
var sheets: Sheets

## What is waiting to be shown, each `{piece, title}`. The one being shown is the first.
var _queue: Array = []

## How far through the current showing, in seconds, and the font it is written in.
var _age: float = 0.0
var _font: Font

## Rolls the stars. Seeded per showing, so one find twinkles the same way every time it is
## held up and two finds in a row do not twinkle alike.
var _rng := RandomNumberGenerator.new()

## The find's own glitter: where a star may land (fractions of the picture's box, off the
## atlas's opaque pixels, the lake's own `sample_box`), the atlas read back as an `Image`
## to ask it, and what is alight now — each `[spot, born, star (true) or spark (false)]`.
##
## The image is read once and kept: a full-atlas readback per card, on a run that lands
## finds several at a time, is not a thing to do in `_draw`.
var _spots := PackedVector2Array()
var _image: Image
var _stars_lit: Array = []

## How big the picture is drawn and what rectangle of the atlas it is, worked out once a
## frame by `_draw` and read by the four shine layers. Every child stands at the picture's
## own middle, so all of them draw around their own origin.
var _box := Vector2.ZERO
var _region := Rect2()
var _solid: float = 0.0

## The card is five layers and they have to be drawn in this order: the words, the column
## of light, the gold rim, the piece, the glitter over it. So the four after the words are
## children — a child draws after its parent, and children draw in the order they were
## added.
##
## They are children for a second reason as well: each wants its own material. The beam is
## added to what is behind it rather than painted over it (light, not a pale wedge on the
## lake), the rim runs a shader that turns pure green to gold, and the words and the stars
## want neither. A material set here would reach all five.
var _beam: Node2D
var _rim: Node2D
var _art: Node2D
var _glitter: Node2D


func _ready() -> void:
	# Straight through: this is a card laid over a game that is still being played.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = Style.font()
	# The parent is a CanvasLayer, which lays out nobody, so the card keeps up with the
	# window itself the way the ending screen does.
	_fill()
	get_viewport().size_changed.connect(_fill)
	# The column of light. `beam.gdshader` declares `blend_add` itself, so there is no
	# CanvasItemMaterial on top of it — two additive passes on one node is twice the light.
	_beam = Node2D.new()
	_beam.name = &"Beam"
	var lit := ShaderMaterial.new()
	lit.shader = LakeGrid.BEAM_SHADER
	_beam.material = lit
	_beam.draw.connect(_draw_beam)
	add_child(_beam)
	# The gold outline, under the piece so the piece covers all but its edge.
	_rim = Node2D.new()
	_rim.name = &"Rim"
	var gold := ShaderMaterial.new()
	gold.shader = RIM_SHADER
	_rim.material = gold
	_rim.draw.connect(_draw_rim)
	add_child(_rim)
	# After the light and the rim, so the piece is lit from behind rather than through.
	_art = Node2D.new()
	_art.name = &"Piece"
	_art.draw.connect(_draw_piece)
	add_child(_art)
	# Over the picture: the glitter is on the find, not behind it.
	_glitter = Node2D.new()
	_glitter.name = &"Glitter"
	_glitter.draw.connect(_draw_stars)
	add_child(_glitter)
	set_process(false)
	visible = false


func _fill() -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size


## Hold a find up. `piece` is its catalogue name and `title` the name a person would call
## it. A find arriving while another is up waits its turn: two wardrobes in one cast is a
## rare thing, but it is not a reason to lose one of them.
func show_find(piece: StringName, title: String) -> void:
	_queue.append({"piece": piece, "title": title})
	if _queue.size() == 1:
		_begin()


## Take everything down at once, without the fade. For a scene that is about to go away, or
## a load that has just replaced the run the finds belonged to.
func clear() -> void:
	_queue.clear()
	set_process(false)
	visible = false
	_stars_lit.clear()
	_redraw_all()


func _begin() -> void:
	_age = 0.0
	_rng.seed = hash(String(_queue[0]["piece"]))
	_stars_lit.clear()
	_take_spots()
	visible = true
	set_process(true)
	_redraw_all()


## Where this find's glitter may land, off the atlas's own opaque pixels. Rolled per find,
## so the same piece twinkles the same way every time it is held up; the atlas is read back
## once for the life of the card and kept.
func _take_spots() -> void:
	_spots = PackedVector2Array()
	if sheets == null or sheets.atlas == null:
		return
	var piece: StringName = _queue[0]["piece"]
	if not sheets.has(piece):
		return
	if _image == null:
		_image = sheets.atlas.get_image()
	_spots = LakeGrid.GlintTwinkle.sample_box(
		_image, sheets.region_of(piece), int(hash(String(piece)) & 0xFFFF)
	)


func _process(delta: float) -> void:
	_age += delta
	if _age >= RISE + HOLD + LEAVE:
		_queue.pop_front()
		if _queue.is_empty():
			clear()
			emptied.emit()
			return
		_begin()
		return
	_tick_stars(delta)
	_redraw_all()


## The card and its four shine layers. None of them redraws itself — the card decides when
## anything on it has moved.
func _redraw_all() -> void:
	queue_redraw()
	for child in [_beam, _rim, _art, _glitter]:
		if child != null:
			child.queue_redraw()


## How solid the card is, 0 to 1: eased in, held, and cut away again.
func _fade() -> float:
	if _age < RISE:
		return 1.0 - pow(1.0 - clampf(_age / RISE, 0.0, 1.0), 3.0)
	var left := RISE + HOLD + LEAVE - _age
	if left < LEAVE:
		return clampf(left / LEAVE, 0.0, 1.0)
	return 1.0


## The pop: overshoots a little and settles back, which is what makes it read as landing on
## the screen rather than being switched on. Sits at 1 for the whole of the hold, and
## shrinks a touch on the way out.
func _swell() -> float:
	if _age < RISE:
		var step := clampf(_age / RISE, 0.0, 1.0)
		var eased := 1.0 - pow(1.0 - step, 3.0)
		return lerpf(0.55, 1.0, eased) + sin(step * PI) * 0.12
	var left := RISE + HOLD + LEAVE - _age
	if left < LEAVE:
		return lerpf(0.94, 1.0, clampf(left / LEAVE, 0.0, 1.0))
	return 1.0


func _draw() -> void:
	if _queue.is_empty() or _font == null:
		return
	var fade := _fade()
	if fade <= 0.0:
		return
	var piece: StringName = _queue[0]["piece"]
	var swell := _swell()
	var centre := Vector2(size.x * 0.5, size.y * MIDDLE)

	# The grimy picture, as it came out of the water — see the note at the top of the file.
	var region := Rect2()
	if sheets != null and sheets.has(piece):
		region = sheets.region_of(piece)
	var tall := size.y * PIECE_HEIGHT * swell
	var wide := tall
	if region.size.y > 0.0:
		wide = tall * (region.size.x / region.size.y)
		# Never past the point where the cut pixels stop being a picture.
		var most := region.size.y * PIECE_ZOOM * swell
		if tall > most:
			wide *= most / tall
			tall = most

	# Where the piece goes, worked out here once and read by all four children. They all
	# stand at the same point, so the beam's foot, the rim's offsets and the stars' spots
	# are in one frame and cannot drift from the picture.
	_box = Vector2(wide, tall)
	_region = region
	_solid = fade
	for child in [_beam, _rim, _art, _glitter]:
		child.position = centre

	var title := float(Style.TEXT_HEAD)
	var named := float(Style.TEXT_BODY)
	var ink := Color(Style.INK.r, Style.INK.g, Style.INK.b, fade)
	var shade := Color(Style.SHADE.r, Style.SHADE.g, Style.SHADE.b, Style.SHADE.a * fade)
	_line(TITLE, int(title), centre.y - tall * 0.5 - title * 0.7, ink, shade)
	# The piece's own name in gold, so the line that changes is the one the eye goes to.
	# Nothing at all for a piece that has not been named: the card is the picture, and a
	# card that says "Find 07" under it is worse than a card that says nothing.
	var named_title := String(_queue[0]["title"])
	if not named_title.is_empty():
		var named_ink := Style.GOLD.lerp(Style.INK, 0.4)
		_line(
			named_title, int(named), centre.y + tall * 0.5 + named * 1.3,
			Color(named_ink.r, named_ink.g, named_ink.b, fade), shade
		)


## The piece itself, over the light: its shadow first, so it sits on the shine rather than
## inside it. Drawn around the origin, because the node is moved to the middle of the card.
func _draw_piece() -> void:
	if not _showing():
		return
	var region := _region
	var span := _box
	var fade := _solid
	var box := Rect2(-span * 0.5, span)
	_art.draw_texture_rect_region(
		sheets.atlas, Rect2(box.position + Vector2(0.0, span.y * 0.04), box.size),
		region, Color(0.0, 0.0, 0.0, 0.35 * fade)
	)
	_art.draw_texture_rect_region(sheets.atlas, box, region, Color(1.0, 1.0, 1.0, fade))


## Is there a picture to draw right now? Asked by every shine layer, so none of them has to
## repeat the four conditions that make a card real.
func _showing() -> bool:
	return (
		not _queue.is_empty() and sheets != null and sheets.atlas != null
		and _region.size.x > 0.0 and _solid > 0.0
	)


## The column of gold light the find stands in, the lake's own (`shaders/beam.gdshader`):
## one rectangle, the shader doing the rest, its colour and brightness carried in the
## modulate. Straight up the screen from just under the picture's foot, so the piece looks
## like it is standing in the light rather than in front of it.
##
## Its own breath comes off `_age`, which the card already runs — no second clock, unlike
## the net's, which needs one because a landed net stops redrawing.
func _draw_beam() -> void:
	if not _showing():
		return
	var wide := maxf(_box.x, _box.y) * BEAM_WIDE
	var tall := maxf(_box.x, _box.y) * LakeGrid.BEAM_TALL
	var foot := _box.y * 0.5 + maxf(_box.x, _box.y) * BEAM_SINK
	var beat := 0.5 + 0.5 * sin(_age * LakeGrid.GLINT_BREATH)
	var glow := LakeGrid.GLINT_TINT
	glow.a = LakeGrid.BEAM_BRIGHT * (0.7 + 0.3 * beat) * _solid
	_beam.draw_rect(Rect2(Vector2(-wide * 0.5, foot - tall), Vector2(wide, tall)), glow)


## The gold outline: the picture stamped again a step out on each of four sides, in pure
## green, which `rim.gdshader` turns to gold. The net's own trick, and the reason the grimy
## sprite can be held up over a grimy lake at all.
##
## The step is in screen pixels rather than scaled with the picture — see `RIM_STEP`.
##
## Its own alpha is `RIM_FADE`'d: the rim is four whole copies of the picture and only their
## edges are meant to show, which holds while the piece over them is opaque and stops
## holding the moment the card starts fading. At the same alpha as the piece, a find on its
## way out went gold — the picture let the copies behind it through and what was left was a
## silhouette. Cubed, the gold is all but gone by the time the picture is see-through, and
## at full card it is still 0.8 of the way there.
func _draw_rim() -> void:
	if not _showing():
		return
	var box := Rect2(-_box * 0.5, _box)
	var gold := pow(_solid, RIM_FADE)
	for step: Vector2 in LakeGrid.RIM_OFFSETS:
		_rim.draw_texture_rect_region(
			sheets.atlas, Rect2(box.position + step * RIM_STEP, box.size), _region,
			Color(0.0, 1.0, 0.0, gold)
		)


## The glitter on the find: four-point stars and single sparks of whole art pixels, at
## spots taken off the picture's own opaque pixels so nothing lands on the water beside it.
## `LakeGrid.GlintTwinkle.draw_star` draws them, the same call the lake and the net make.
func _draw_stars() -> void:
	if not _showing():
		return
	for star: Array in _stars_lit:
		var spot: Vector2 = star[0]
		var big: bool = star[2]
		var span: float = LakeGrid.STAR_LIFE if big else LakeGrid.SPARK_LIFE
		var life := clampf((_age - float(star[1])) / span, 0.0, 1.0)
		var local := (spot - Vector2(0.5, 0.5)) * _box
		_glitter.draw_set_transform(local, 0.0, Vector2.ONE * STAR_BIG)
		LakeGrid.GlintTwinkle.draw_star(_glitter, big, sin(life * PI) * _solid)
	_glitter.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Light and put out the stars. Driven from `_process` rather than from `_draw`, because
## which stars are alight is state and a draw call must not make any.
func _tick_stars(delta: float) -> void:
	var kept: Array = []
	for star: Array in _stars_lit:
		var span: float = LakeGrid.STAR_LIFE if star[2] else LakeGrid.SPARK_LIFE
		if _age - float(star[1]) < span:
			kept.append(star)
	_stars_lit = kept
	if _spots.is_empty():
		return
	if _rng.randf() < LakeGrid.STAR_RATE * delta:
		_stars_lit.append([_spots[_rng.randi() % _spots.size()], _age, true])
	if _rng.randf() < LakeGrid.SPARK_RATE * delta:
		_stars_lit.append([_spots[_rng.randi() % _spots.size()], _age, false])


## One line, centred, with a shadow under it — the same treatment the ending gives its
## words, and for the same reason: pale text over bright water needs an edge, not a panel.
func _line(text: String, height: int, baseline: float, ink: Color, shade: Color) -> void:
	Style.write(
		self, text, height, Vector2(0.0, baseline),
		Color(ink.r, ink.g, ink.b, 1.0), HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(0.0, baseline, size.x, 1.0), ink.a
	)

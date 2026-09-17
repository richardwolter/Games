## Mockups of the upgrades shop, for choosing a layout by eye before anything is built.
##
## A probe, not a feature. It draws its own boards in `Style`'s own wood, over the real
## lake, with the real sprites the live `ShopSkin` was lent — so what is judged is the game's
## own carpentry and the game's own font, not a picture of them. Nothing in `scripts/`
## knows this exists and nothing here is wired to a purchase.
##
## Three layouts (`mode`), each drawn with the proposed names, the proposed one-line value
## grammar and the rows grouped by what they change:
##   four_up  — today's four boards side by side, with the text fixed
##   tabbed   — one board at a time behind four wooden tabs
##   two_up   — two boards a page, twice the row width, a pager at the foot
##
## `maxed` swaps in the worst case: every track at the top of its curve, six-figure prices
## and the longest names, which is the state a layout has to survive.
extends Control

const Style := preload("res://scripts/style.gd")
const DogArt := preload("res://scripts/dog_art.gd")
const HudButtons := preload("res://scripts/hud_buttons.gd")
const LakeGrid := preload("res://scripts/lake_grid.gd")

const BOARDS: Array[StringName] = [&"net", &"boat", &"dog", &"luck"]
## No "The": four boards standing side by side are already a list, and the article is a word
## every translation would have to carry for nothing.
const TITLES := {&"net": "Net", &"boat": "Boats", &"dog": "Dogs", &"luck": "Luck"}

## The wood, as the shop cuts it.
const FRAME := 12.0
const CHIPS := 3
const RIBBON_TALL := 36.0
const RIBBON_OVERHANG := 10.0
const BOARD_PAD := 14.0
const BOARD_GAP := 44.0
const SPRITE_TALL := 68.0
const HEAD_GAP := 8.0
const SPRITE_FILL := {&"net": 0.7, &"boat": 1.0, &"dog": 0.8, &"luck": 0.62}
const HALO_ALPHA := [0.006, 0.011, 0.017]
const HALO_GROW := 0.34
const NET_INK := Color(0.08, 0.07, 0.07, 0.92)

## How wide the whole thing stands, per layout. Four-up is the shop's own 1180; the other
## two spend the same table on fewer boards.
const WIDE := {&"four_up": 1180.0, &"tabbed": 900.0, &"two_up": 1180.0}

## A row, per layout: how tall, the gap under it, and how much of it the price tag may take.
const ROW_TALL := {&"four_up": 50.0, &"tabbed": 58.0, &"two_up": 54.0}
const ROW_GAP := 6.0
const TAG_SHARE := {&"four_up": 0.34, &"tabbed": 0.16, &"two_up": 0.22}

## The name's size per layout, and the value's under it. Four-up keeps the shop's ladder;
## the wider layouts spend their room on the rungs above it.
const NAME_SIZE := {&"four_up": Style.TEXT_BODY, &"tabbed": Style.TEXT_HEAD, &"two_up": Style.TEXT_BODY}
const VALUE_SIZE := {&"four_up": Style.TEXT_SMALL, &"tabbed": Style.TEXT_BODY, &"two_up": Style.TEXT_SMALL}

## The rail down the left of every row: a sunk gutter carrying the "?" over the level's
## figure. "Lvl 20" on the name line costs 47px of a four-up row's 108 — 43% of its
## writing — for something the shop's own comment calls a footnote, and the "?" hung on the
## corner is the smallest target on the board. Stacked in a rail they cost the row one
## narrow column and both grow a hit box.
const RAIL_WIDE := 26.0
const RAIL_GAP := 8.0

## What the mock proposes for an unaffordable row's writing, in place of `BOARD_INK_DIM`
## (2.19:1 on the off face, and 1.82:1 once the value's quarter-lerp towards the face is
## applied). This reads 5.01:1 for both lines, and the row's state is then carried by the
## price tag and the lit edge rather than by writing nobody can read.
const INK_DIM := Color(0.76, 0.83, 0.75)

## A group heading inside a board, and the carved rule under it.
const GROUP_TALL := 20.0
const GROUP_GAP := 4.0

## The tabs along the top of the tabbed layout.
const TAB_TALL := 40.0
const TAB_GAP := 6.0

## The pager under the two-up layout.
const PAGER_TALL := 30.0

## The pricing plate under the two middle boards: the gap over it, its padding, the leading
## between its lines, the gap between its parts, and the close cross's side.
const LEGEND_GAP := 22.0
const LEGEND_PAD := 12.0
const LEGEND_LINE := 4.0
const LEGEND_ROW_GAP := 6.0
const CLOSE_SIZE := 44.0

## The recycle bonus on the pricing plate. The plate is where it belongs: the bonus is a
## change to what one material pays, and the plate is the one place that says what materials
## pay. The `Bonus yard` row keeps the multiplier it sells; which yard has it, and for how
## long, is state, not an upgrade.
##
## The bonus line is reserved whether or not a bonus is live, and whether or not the track
## has been bought at all — a plate that grows a line every thirty seconds re-centres the
## whole shop every thirty seconds.
const BONUS_STARS := 5
const BONUS_STAR_SEED := 0x5eed
const BONUS_LIFT := 3.0

## Which rows sit under which heading, in reading order. A board with one group draws no
## heading: one heading over everything says nothing.
const GROUPS := {
	&"net": [
		["", [&"net_width", &"net_strength", &"net_range", &"reel", &"net_hold"]],
	],
	&"boat": [
		["The run", [&"boat_speed", &"cargo", &"boat_volley"]],
		["The fleet", [&"fleet"]],
	],
	&"dog": [
		["The pack", [&"dog_count", &"dog_strength"]],
		["The trip", [&"dog_fetch", &"dog_wait"]],
	],
	&"luck": [
		["On a cast", [&"lucky_haul", &"double_cast"]],
		["At the yards", [&"recycle_bonus", &"bird_worth"]],
	],
}

## Which layout, which board is fronted (tabbed), which page is up (two-up), and whether
## the worst case is drawn.
var mode: StringName = &"four_up"
var tab: StringName = &"net"
var page := 0
var maxed := false

## The sprites the live shop was lent, by board name: `{sheet, region}`.
var sprites := {}

## `{key, board, name, level, value, cost, afford}`, the mock's own, set by the probe.
var rows: Array = []

## What the pricing plate says, lent by the lake beside the sprites:
## `{yards: [[name, "$n"]...], rule}`.
var legend: Dictionary = {}

## The live recycle bonus: `{kind, pay, pct, seconds}` — which of `legend.yards` is boosted,
## what that material pays while it is, the multiplier and the time left. Empty for none.
var bonus: Dictionary = {}

## How the plate shows it: `star` (the world's own glitter over the boosted column),
## `plate` (the column lit, no glitter) or `line` (a line of its own under the rule).
var bonus_style: StringName = &"star"

var _dog_frame := 0
var _close: CloseButton = null


func _draw() -> void:
	if size.x <= 0.0:
		return
	Style.dim(self, Rect2(Vector2.ZERO, size), Style.SCRIM)
	match mode:
		&"tabbed":
			_draw_tabbed()
		&"two_up":
			_draw_two_up()
		_:
			_draw_four_up()


# ---------------------------------------------------------------------------------------
# The three layouts
# ---------------------------------------------------------------------------------------


## Today's geometry: four boards side by side, tops aligned, each as tall as its rows come
## to, with the pricing plate under the two middle ones and the close cross nailed to the
## last board's title plank.
##
## The one change to the arithmetic: the plate is no longer held inside the tallest board's
## height. It was, and that is why it fits today only while the net board is three rows
## taller than the middle two — a gap the grouping closes. It now hangs below that line and
## the whole block, boards and plate together, is what gets centred.
func _draw_four_up() -> void:
	var wide: float = minf(WIDE[&"four_up"], size.x - 40.0)
	var each := (wide - BOARD_GAP * 3.0) / 4.0
	var talls := {}
	var tallest := 0.0
	for board in BOARDS:
		talls[board] = _board_tall(board, &"four_up")
		tallest = maxf(tallest, float(talls[board]))
	var middle_foot: float = maxf(float(talls[BOARDS[1]]), float(talls[BOARDS[2]]))
	var plate := _legend_tall()
	var block := maxf(tallest, middle_foot + LEGEND_GAP + plate)
	var left := floorf((size.x - wide) * 0.5)
	var top := floorf((size.y - block) * 0.5)
	var boxes := {}
	for i in BOARDS.size():
		var board: StringName = BOARDS[i]
		boxes[board] = Rect2(
			floorf(left + (each + BOARD_GAP) * float(i)), top, floorf(each), float(talls[board])
		)
	# The plate first, so a board's own bitten frame is drawn over the join rather than under
	# it where the two meet.
	var one: Rect2 = boxes[BOARDS[1]]
	var two: Rect2 = boxes[BOARDS[2]]
	_draw_legend(Rect2(
		Vector2(one.position.x, top + middle_foot + LEGEND_GAP),
		Vector2(two.end.x - one.position.x, plate)
	))
	for i in BOARDS.size():
		var board: StringName = BOARDS[i]
		var last := i == BOARDS.size() - 1
		_draw_board(board, boxes[board], &"four_up", true, last)
	_place_close(_ribbon_of(boxes[BOARDS[BOARDS.size() - 1]]))


## One board at a time, behind four tabs. The board is as tall as the tallest of them, so
## the tabs do not make the furniture jump.
func _draw_tabbed() -> void:
	var wide: float = minf(WIDE[&"tabbed"], size.x - 40.0)
	var tallest := 0.0
	for board in BOARDS:
		tallest = maxf(tallest, _board_tall(board, &"tabbed"))
	var left := floorf((size.x - wide) * 0.5)
	var top := floorf((size.y - tallest - TAB_TALL) * 0.5) + TAB_TALL
	var box := Rect2(left, top, wide, tallest)
	# The tabs first, so the fronted one's foot is buried under the board's own top edge.
	var each := (wide - TAB_GAP * 3.0) / 4.0
	for i in BOARDS.size():
		var board: StringName = BOARDS[i]
		var here := Rect2(
			floorf(left + (each + TAB_GAP) * float(i)),
			top - TAB_TALL + (0.0 if board == tab else 4.0),
			floorf(each), TAB_TALL + RIBBON_TALL * 0.5
		)
		_draw_tab(board, here, board == tab)
	_draw_board(tab, box, &"tabbed", false)


## Two boards a page, so a row is two and a half times as wide as it is today.
func _draw_two_up() -> void:
	var wide: float = minf(WIDE[&"two_up"], size.x - 40.0)
	var each := (wide - BOARD_GAP) / 2.0
	var shown: Array[StringName] = [BOARDS[page * 2], BOARDS[page * 2 + 1]]
	var tallest := 0.0
	for board in shown:
		tallest = maxf(tallest, _board_tall(board, &"two_up"))
	var left := floorf((size.x - wide) * 0.5)
	var top := floorf((size.y - tallest - PAGER_TALL) * 0.5)
	for i in shown.size():
		var box := Rect2(
			floorf(left + (each + BOARD_GAP) * float(i)), top,
			floorf(each), _board_tall(shown[i], &"two_up")
		)
		_draw_board(shown[i], box, &"two_up")
	_draw_pager(Rect2(left, top + tallest + 10.0, wide, PAGER_TALL))


# ---------------------------------------------------------------------------------------
# The pieces
# ---------------------------------------------------------------------------------------


## How tall a board comes out: head, then a heading and a rule for every group that has
## one, then its rows.
func _board_tall(board: StringName, layout: StringName) -> float:
	var groups: Array = GROUPS.get(board, [])
	var tall := _head_tall(layout)
	for group: Array in groups:
		if not String(group[0]).is_empty():
			tall += GROUP_TALL + GROUP_GAP
		for key in group[1]:
			if _row_of(key).is_empty():
				continue
			tall += float(ROW_TALL[layout]) + ROW_GAP
	return tall - ROW_GAP + BOARD_PAD + FRAME


func _head_tall(layout: StringName) -> float:
	var one: float = WIDE[layout] / (4.0 if layout != &"tabbed" else 1.0)
	return Style.board_wood_tall(one, FRAME) * 0.5 + RIBBON_TALL * 0.5 + BOARD_PAD + SPRITE_TALL + HEAD_GAP


## A board's title plank, hung over its top edge and a little wider than the board.
func _ribbon_of(box: Rect2) -> Rect2:
	return Rect2(
		Vector2(box.position.x - RIBBON_OVERHANG, box.position.y - RIBBON_TALL * 0.5),
		Vector2(box.size.x + RIBBON_OVERHANG * 2.0, RIBBON_TALL)
	)


func _draw_board(
	board: StringName, box: Rect2, layout: StringName, ribbon := true, carries_close := false
) -> void:
	Style.board_wood(self, box, FRAME, CHIPS)
	var face := Style.board_face(box, FRAME)
	draw_rect(face.grow(1.0), Style.SEAM, true)
	draw_rect(face, Style.BOARD, true)
	if ribbon:
		# Only the board carrying the cross makes room for one, so the other three centre
		# their titles on the whole plank.
		var plank := _ribbon_of(box)
		var room := Style.title_room(plank, CLOSE_SIZE) if carries_close else Rect2()
		Style.board_ribbon(self, plank, String(TITLES.get(board, "")), CHIPS, Style.TEXT_HEAD, room)
	var slot := Rect2(
		Vector2(face.position.x, box.position.y + RIBBON_TALL * 0.5 + BOARD_PAD),
		Vector2(face.size.x, SPRITE_TALL)
	)
	_draw_head(board, slot)

	var left := face.position.x + BOARD_PAD
	var wide := face.size.x - BOARD_PAD * 2.0
	var y := slot.end.y + HEAD_GAP
	for group: Array in GROUPS.get(board, []):
		var heading := String(group[0])
		if not heading.is_empty():
			_draw_group(heading, Rect2(left, y, wide, GROUP_TALL))
			y += GROUP_TALL + GROUP_GAP
		for key in group[1]:
			var row := _row_of(key)
			if row.is_empty():
				continue
			_draw_row(row, Rect2(left, y, wide, float(ROW_TALL[layout])), layout)
			y += float(ROW_TALL[layout]) + ROW_GAP


## A group's heading: the words in the clean water's blue, and a carved rule running from
## them to the far edge, so the heading reads as a lid on what is under it.
func _draw_group(heading: String, box: Rect2) -> void:
	var base := box.position.y + box.size.y * 0.5 + float(Style.TEXT_SMALL) * 0.36
	var took := Style.write(
		self, heading.to_upper(), Style.TEXT_SMALL, Vector2(box.position.x, base),
		Style.LEVEL_INK
	)
	var from := box.position.x + took.x + 8.0
	if from < box.end.x - 4.0:
		var mid := box.position.y + box.size.y * 0.5
		draw_line(Vector2(from, mid), Vector2(box.end.x, mid), Style.SEAM, 2.0)
		draw_line(Vector2(from, mid + 1.0), Vector2(box.end.x, mid + 1.0), Style.BOARD_ROW, 1.0)


## One row. The "?" and the level stack down the left in their own gutter, the name and
## its value fill the middle, the price stands at the end.
func _draw_row(row: Dictionary, box: Rect2, layout: StringName) -> void:
	var afford := bool(row.get("afford", false))
	var face := Style.BOARD_ROW if afford else Style.BOARD_ROW_OFF
	var ink := Style.BOARD_INK if afford else INK_DIM
	Style.plate(self, box, face)
	# A row you can buy carries the lit edge along its top, one you cannot does not: the
	# state has to be legible to somebody who cannot tell the two faces apart by hue.
	if afford:
		Style.highlight(
			self, box.position + Vector2(Style.CLIP, 0.0),
			Vector2(box.size.x - Style.CLIP * 2.0, 0.0), int(box.position.x)
		)

	_draw_rail(Rect2(box.position, Vector2(RAIL_WIDE, box.size.y)), row, afford)
	var text_at := box.position.x + RAIL_WIDE + RAIL_GAP

	var cost := String(row.get("cost", ""))
	var tag_wide: float = box.size.x * float(TAG_SHARE[layout])
	var tag := _tag_box(box, tag_wide, cost)
	_draw_tag(tag, cost, afford)
	var room := (tag.position.x if tag.size.x > 0.0 else box.end.x) - 10.0 - text_at

	var name_size: int = NAME_SIZE[layout]
	var value_size: int = VALUE_SIZE[layout]
	var stack := float(name_size) * 0.62 + float(value_size) * 0.62 + 6.0
	var first := box.position.y + (box.size.y - stack) * 0.5 + float(name_size) * 0.62
	Style.write(self, String(row.get("name", "")), name_size, Vector2(text_at, first), ink)
	# The value is written in the row's own ink, not a quarter of the way back into the
	# face: that lerp is what puts the line under every contrast floor there is, and the
	# size ladder already says which of the two lines is the heading.
	Style.write(
		self, String(row.get("value", "")), value_size,
		Vector2(text_at, first + 6.0 + float(value_size) * 0.62), ink
	)
	# What a row over its room would do, drawn so it can be seen rather than described.
	var over := maxf(
		Style.measure(String(row.get("name", "")), name_size).x,
		Style.measure(String(row.get("value", "")), value_size).x
	)
	if over > room:
		draw_rect(Rect2(Vector2(text_at + room, box.position.y), Vector2(over - room, box.size.y)),
			Color(0.9, 0.2, 0.2, 0.22), true)


## The rail: one sunk column down the left of a row, the "?" in its top half and the level's
## figure in its bottom. The number alone — "Lvl" is a word the row does not need and a
## translation would have to carry, and the rail is what says the number is a level.
func _draw_rail(box: Rect2, row: Dictionary, afford: bool) -> void:
	Style.plate(self, box, Style.BOARD.lerp(Style.SEAM, 0.25), 2.0)
	var half := box.size.y * 0.5
	Style.write(
		self, "?", Style.TEXT_SMALL,
		Vector2(0.0, box.position.y + half * 0.5 + float(Style.TEXT_SMALL) * 0.36),
		Style.PRICE_INK if afford else Style.PRICE_INK.lerp(Style.FRAME_LOW, 0.35),
		HORIZONTAL_ALIGNMENT_CENTER, Rect2(box.position, Vector2(box.size.x, half))
	)
	var level := String(row.get("level", ""))
	if level.is_empty():
		return
	Style.write(
		self, level, Style.TEXT_TINY,
		Vector2(0.0, box.position.y + half * 1.5 + float(Style.TEXT_TINY) * 0.36),
		Style.LEVEL_INK, HORIZONTAL_ALIGNMENT_CENTER,
		Rect2(Vector2(box.position.x, box.position.y + half), Vector2(box.size.x, half))
	)


func _tag_box(box: Rect2, tag_wide: float, cost: String) -> Rect2:
	if cost.is_empty():
		return Rect2()
	var slot := Rect2(
		Vector2(box.end.x - tag_wide - 6.0, box.position.y + 8.0),
		Vector2(tag_wide, box.size.y - 16.0)
	)
	var wide := minf(Style.measure(cost, Style.TEXT_BODY).x + float(Style.TEXT_BODY) * 1.2, slot.size.x)
	return Rect2(slot.position + Vector2(slot.size.x - wide, 0.0), Vector2(wide, slot.size.y))


func _draw_tag(tag: Rect2, cost: String, afford: bool) -> void:
	if tag.size.x <= 0.0:
		return
	Style.plate(self, tag, Style.FRAME if afford else Style.FRAME_LOW)
	Style.write(
		self, cost, Style.TEXT_BODY,
		Vector2(0.0, tag.position.y + tag.size.y * 0.5 + float(Style.TEXT_BODY) * 0.34),
		Style.PRICE_INK if afford else Style.PRICE_INK.lerp(Style.FRAME_LOW, 0.45),
		HORIZONTAL_ALIGNMENT_CENTER, tag
	)


## A tab: the board's own plank with its name on it, the fronted one standing a little
## proud and in the ribbon's wood, the rest sunk and darker.
func _draw_tab(board: StringName, box: Rect2, fronted: bool) -> void:
	Style.board_ribbon(self, box, String(TITLES.get(board, "")), CHIPS, Style.TEXT_SMALL)
	if not fronted:
		Style.dim(self, box, 0.42)


## Which page of two the two-up layout is on, as two plates rather than words.
func _draw_pager(box: Rect2) -> void:
	var side := PAGER_TALL * 0.5
	var gap := 10.0
	var from := box.position.x + box.size.x * 0.5 - (side * 2.0 + gap) * 0.5
	for i in 2:
		var here := Rect2(Vector2(from + (side + gap) * float(i), box.position.y), Vector2.ONE * side)
		Style.plate(self, here, Style.FRAME if i == page else Style.FRAME_LOW, 2.0)
	Style.write(
		self, "The net and the ferry" if page == 0 else "The dog and the market",
		Style.TEXT_TINY, Vector2(0.0, box.position.y + side + 16.0),
		Style.BOARD_INK_DIM, HORIZONTAL_ALIGNMENT_CENTER, box
	)


# ---------------------------------------------------------------------------------------
# The heads
# ---------------------------------------------------------------------------------------


## The thing being sold, in its slot. Flat: the mock borrows the lake's sheets but not the
## shop's wake, collar or bob — this is a layout to look at, not the shop running.
func _draw_head(board: StringName, slot: Rect2) -> void:
	var fill := float(SPRITE_FILL.get(board, 1.0))
	var middle := slot.position + slot.size * 0.5
	if board == &"dog" and DogArt.has(&"idle"):
		var tall := slot.size.y * fill
		var span := DogArt.span(&"idle", tall)
		var foot := Vector2(middle.x, slot.end.y - (slot.size.y - span.y) * 0.5)
		_halo(Rect2(foot - Vector2(span.x * 0.5, span.y), span))
		DogArt.stamp(self, &"idle", _dog_frame, foot, tall, true)
		return
	if board == &"luck":
		var side := slot.size.y * fill
		var coin := Rect2(middle - Vector2.ONE * side * 0.5, Vector2.ONE * side)
		_halo(coin)
		HudButtons.coin(self, coin, Color.WHITE)
		return
	var lent: Dictionary = sprites.get(board, {})
	var sheet: Texture2D = lent.get("sheet")
	if sheet == null:
		return
	var region: Rect2 = lent["region"]
	var scale := minf(slot.size.x / region.size.x, slot.size.y / region.size.y) * fill
	if board == &"boat":
		scale = maxf(floor(scale), 1.0)
	var drawn := region.size * scale
	if drawn.x > slot.size.x:
		drawn *= slot.size.x / drawn.x
	var box := Rect2(middle - drawn * 0.5, drawn)
	_halo(box)
	draw_texture_rect_region(sheet, box, region, NET_INK if board == &"net" else Color.WHITE)


func _halo(box: Rect2) -> void:
	var middle := box.position + box.size * 0.5
	for i in HALO_ALPHA.size():
		var grow := 1.0 + HALO_GROW * (1.0 - float(i) / float(HALO_ALPHA.size()))
		var radius := box.size * 0.5 * grow
		var ring := PackedVector2Array()
		for k in 24:
			var a := TAU * float(k) / 24.0
			ring.append(middle + Vector2(cos(a) * radius.x, sin(a) * radius.y))
		draw_colored_polygon(ring, Color(1.0, 1.0, 1.0, float(HALO_ALPHA[i])))


## The pricing plate: what each material pays on average, and the rule under it. The lake
## works the figures out; this only lays them out.
func _draw_legend(box: Rect2) -> void:
	if box.size.y <= 0.0 or legend.is_empty():
		return
	var face := Style.board_wood(self, box, FRAME, CHIPS)
	var line := float(Style.TEXT_SMALL) + LEGEND_LINE
	var at := face.position + Vector2(LEGEND_PAD, LEGEND_PAD + float(Style.TEXT_SMALL) * 0.8)
	var wide := face.size.x - LEGEND_PAD * 2.0
	var yards: Array = legend.get("yards", [])
	var lit := int(bonus.get("kind", -1)) if bonus_style != &"line" else -1
	if not yards.is_empty():
		var step := wide / float(yards.size())
		for y in yards.size():
			var pair: Array = yards[y]
			var slot := Rect2(Vector2(at.x + step * float(y), 0.0), Vector2(step, 0.0))
			var boosted := y == lit
			if boosted:
				_light_column(Rect2(
					Vector2(slot.position.x + 4.0, at.y - float(Style.TEXT_SMALL) - LEGEND_PAD * 0.5),
					Vector2(step - 8.0, line * 2.0 + LEGEND_PAD * 0.6)
				))
			Style.write(self, String(pair[0]), Style.TEXT_SMALL, Vector2(0.0, at.y),
				Style.BOARD_INK, HORIZONTAL_ALIGNMENT_CENTER, slot)
			# While a material is boosted the plate says what it pays now, not what it pays
			# ordinarily: a figure the player cannot act on is the wrong figure to print.
			var pay := String(bonus.get("pay", "")) if boosted else String(pair[1])
			Style.write(self, pay, Style.TEXT_SMALL, Vector2(0.0, at.y + line),
				Style.PRICE_INK if not boosted else Style.PRICE_INK * Style.HOVER_WASH,
				HORIZONTAL_ALIGNMENT_CENTER, slot)
			if boosted and bonus_style == &"star":
				# Along the lit plate's top edge only. Scattered over the whole column the
				# stars land on the figures, and a star sitting in a price reads as a glyph.
				_bonus_glitter(Rect2(
					Vector2(slot.position.x + 4.0,
						at.y - float(Style.TEXT_SMALL) - LEGEND_PAD * 0.5 - BONUS_LIFT),
					Vector2(step - 8.0, BONUS_LIFT * 2.0 + 4.0)
				))
		at.y += line * 2.0 + LEGEND_ROW_GAP
	_draw_bonus_line(Rect2(Vector2(at.x, at.y - float(Style.TEXT_SMALL) * 0.8), Vector2(wide, line)))
	at.y += line
	for row in _wrap(String(legend.get("rule", "")), Style.TEXT_SMALL, wide):
		Style.write(self, row, Style.TEXT_SMALL, at, Style.BOARD_INK.lerp(Style.BOARD, 0.15))
		at.y += line


## The bonus's own line: what it is worth and how long it has left. The material's name is
## on it only in the `line` style, where nothing up in the columns is saying it.
func _draw_bonus_line(box: Rect2) -> void:
	if bonus.is_empty():
		return
	var base := box.position.y + float(Style.TEXT_SMALL) * 0.8
	var said := "%s for %ds" % [String(bonus.get("pct", "")), int(bonus.get("seconds", 0))]
	if bonus_style == &"line":
		var yards: Array = legend.get("yards", [])
		var which := int(bonus.get("kind", -1))
		var name: String = String((yards[which] as Array)[0]) if which >= 0 and which < yards.size() else ""
		# No glitter here, by decision: this style is words, and the other two are the
		# world's own signal. Mixing them makes the three impossible to tell apart.
		said = "%s  %s  %s" % [name.to_upper(), String(bonus.get("pay", "")), said]
	Style.write(
		self, "Bonus yard: " + said, Style.TEXT_SMALL, Vector2(0.0, base),
		Style.PRICE_INK, HORIZONTAL_ALIGNMENT_CENTER, box
	)


## The lit panel behind a boosted column: the row's own affordable face and the lit edge it
## carries, so "this one is live" is said in the language the rows already say it in.
func _light_column(box: Rect2) -> void:
	Style.plate(self, box, Style.BOARD_ROW, 2.0)
	Style.highlight(
		self, box.position + Vector2(Style.CLIP, 0.0),
		Vector2(box.size.x - Style.CLIP * 2.0, 0.0), int(box.position.x)
	)


## The world's own glitter, as the boosted yard's box wears it: the same four-point gold
## stars `Dropoff.Shine` draws out at the pier, so what the plate says and what the player
## can see across the lake are one thing. Fixed spots off one seed — the shop is a still
## picture here, and a plate that twinkles is a plate that redraws every frame.
func _bonus_glitter(box: Rect2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = BONUS_STAR_SEED
	for i in BONUS_STARS:
		var at := Vector2(
			box.position.x + rng.randf() * box.size.x,
			box.position.y - BONUS_LIFT + rng.randf() * (box.size.y + BONUS_LIFT)
		)
		draw_set_transform(at.floor(), 0.0, Vector2.ONE)
		LakeGrid.GlintTwinkle.draw_star(self, i % 2 == 0, 0.55 + rng.randf() * 0.45)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## How tall the plate comes out. Five lines: the materials over their prices, the bonus's
## own line, and two of rule. The bonus's line is counted whether or not one is live — a
## plate that grows a line every thirty seconds re-centres the whole shop every thirty
## seconds.
func _legend_tall() -> float:
	var line := float(Style.TEXT_SMALL) + LEGEND_LINE
	return LEGEND_PAD * 2.0 + line * 5.0 + LEGEND_ROW_GAP + Style.board_wood_tall(
		(WIDE[&"four_up"] - BOARD_GAP * 3.0) * 0.5, FRAME
	)


## Words folded onto lines no wider than `wide`. `Style.write` has no wrap of its own.
func _wrap(text: String, size_px: int, wide: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var line := ""
	for word in text.split(" ", false):
		var try := word if line.is_empty() else line + " " + word
		if Style.measure(try, size_px).x <= wide or line.is_empty():
			line = try
		else:
			out.append(line)
			line = word
	if not line.is_empty():
		out.append(line)
	return out


## The cross, nailed to the last board's title plank as every other menu in the game nails
## its own. A node rather than drawing: it is the game's `CloseButton`, so the mock cannot
## end up showing a cross the shop would not draw.
func _place_close(plank: Rect2) -> void:
	if _close == null:
		_close = CloseButton.new()
		add_child(_close)
	var at := Style.close_on(plank, CLOSE_SIZE)
	_close.position = at.position
	_close.size = at.size


func _row_of(key: StringName) -> Dictionary:
	for row: Dictionary in rows:
		if StringName(row.get("key", "")) == key:
			return row
	return {}

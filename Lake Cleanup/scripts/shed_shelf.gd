extends Control
## The shelf down the right of the shed: the finds that have been netted and not yet stood
## anywhere, on a board of the same oak as the upgrades shop and the settings.
##
## It is a Control of its own rather than another stretch of `ShedRoom._draw` for one
## reason: while a piece is being carried the whole shelf fades back so the floor under the
## cursor can be aimed at, and `modulate` fades a node in one move. Threading an alpha
## through `Style.plank`, `grain`, `highlight` and `chip` would have meant an extra argument
## on every shared drawing helper in the game for the sake of this one screen.
##
## It owns no state. `ShedRoom` fills the fields below each time it draws and the shelf
## paints exactly what it is handed — so the rows drawn and the rows hit-tested are the same
## rows, measured once, in the room.

const Style := preload("res://scripts/style.gd")

## The oak, matching the shop's boards.
var frame_thick := 10.0
var chips := 3
var row_gap := 4.0
var bar_wide := 8.0
var bar_gap := 4.0

## Everything the room measured for us, in the room's own coordinates — the shelf is laid
## over the room at the same size and origin, so no conversion is needed anywhere.
var board := Rect2()
var ribbon := Rect2()
var list := Rect2()
var title := ""
## Where the title is centred: the ribbon less whatever sits on it. The close cross is
## nailed to the right end of the plank, and a title centred on the whole plank ran under it.
var title_box := Rect2()

var atlas: Texture2D
## One entry per find on the shelf: `region` on the atlas, `title` to write beside it.
var rows: Array[Dictionary] = []
var row_height := 56.0
var scroll := 0.0
var hovered := -1

## How much of the sprite's square a row gives it, and where the name starts.
const SPRITE_PAD := 6.0
const NAME_AT := 56.0
const NAME_GAP := 8.0
const ELLIPSIS := "..."


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func _draw() -> void:
	if board.size.x <= 0.0:
		return
	draw_rect(Style.board_wood(self, board, frame_thick, chips), Style.PAPER, true)

	if rows.is_empty():
		Style.write(
			self,
			"Nothing kept yet.",
			Style.TEXT_SMALL,
			list.position + Vector2(2.0, float(Style.TEXT_SMALL) + 8.0),
			Style.PAPER_SOFT
		)
	else:
		_draw_rows()
		_draw_bar()

	# Dropped a size rather than cut short: the count is the half that would be lost, and a
	# shelf that will not say how full it is is worse than one that says it small.
	var head := Style.TEXT_BODY
	var room := title_box.size.x if title_box.size.x > 0.0 else ribbon.size.x
	if Style.measure(title, head).x > room:
		head = Style.TEXT_SMALL
	Style.board_ribbon(self, ribbon, title, chips, head, title_box)


## The rows, whole ones only. A row that starts inside the face and ends outside it used to
## be drawn in full, so the last one hung below the board with its name in mid-air.
func _draw_rows() -> void:
	for i in rows.size():
		var top := list.position.y + float(i) * row_height - scroll
		if top < list.position.y - 0.5 or top + row_height > list.end.y + 0.5:
			continue
		var box := Rect2(list.position.x, top, list.size.x, row_height - row_gap)
		var face := Style.BOARD_ROW
		if i == hovered:
			face = Color(
				face.r * Style.HOVER_WASH.r,
				face.g * Style.HOVER_WASH.g,
				face.b * Style.HOVER_WASH.b
			)
		Style.plate(self, box, face)
		_draw_thumb(rows[i].get("region", Rect2()) as Rect2, box)
		_draw_name(String(rows[i].get("title", "")), box)


## The find's clean picture, fitted into the row's left square. A wardrobe and a mug both
## have to read as one line of a list, so nothing is drawn at its own size.
func _draw_thumb(region: Rect2, box: Rect2) -> void:
	if atlas == null or region.size.x <= 0.0 or region.size.y <= 0.0:
		return
	var room := Vector2(NAME_AT - SPRITE_PAD * 2.0, box.size.y - SPRITE_PAD * 2.0)
	var fit := minf(room.x / region.size.x, room.y / region.size.y)
	var drawn := region.size * fit
	var at := box.position + Vector2(
		SPRITE_PAD + (room.x - drawn.x) * 0.5, SPRITE_PAD + (room.y - drawn.y) * 0.5
	)
	draw_texture_rect_region(atlas, Rect2(at.floor(), drawn), region)


## The name, cut with an ellipsis if it will not fit. There is no clip rectangle in
## `Style.write` and a title running off the wood reads as a bug, not as a long name.
func _draw_name(name: String, box: Rect2) -> void:
	if name.is_empty():
		return
	var room := box.size.x - NAME_AT - NAME_GAP
	var shown := name
	if Style.measure(shown, Style.TEXT_SMALL).x > room:
		while shown.length() > 1 and Style.measure(shown + ELLIPSIS, Style.TEXT_SMALL).x > room:
			shown = shown.substr(0, shown.length() - 1)
		shown = shown.strip_edges() + ELLIPSIS
	Style.write(
		self,
		shown,
		Style.TEXT_SMALL,
		Vector2(box.position.x + NAME_AT, box.position.y + (box.size.y + float(Style.TEXT_SMALL) * 0.62) * 0.5),
		Style.BOARD_INK
	)


## The scrollbar down the face's right edge: a sunken track with a plate riding it, sized to
## the share of the shelf on screen. It is a reading, not a handle — the wheel drives it.
func _draw_bar() -> void:
	var span := float(rows.size()) * row_height
	if span <= list.size.y + 0.5:
		return
	var track := Rect2(
		Vector2(list.end.x + bar_gap, list.position.y), Vector2(bar_wide, list.size.y)
	)
	Style.plate(self, track, Style.BOARD.darkened(0.35), 2.0)
	var share := clampf(list.size.y / span, 0.08, 1.0)
	var along := clampf(scroll / maxf(span - list.size.y, 1.0), 0.0, 1.0)
	var tall := maxf(track.size.y * share, 12.0)
	var thumb := Rect2(
		Vector2(track.position.x, track.position.y + (track.size.y - tall) * along),
		Vector2(track.size.x, tall)
	)
	Style.plate(self, thumb, Style.FRAME, 2.0)

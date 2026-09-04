## Draws the numbered picture of the pigeon sheet that the birds are chosen from.
##
## The cutting is done by tools/slice_pigeons.gd; this only lays the result out big enough
## to see, with a number against every bird, so a human can say which ones are in the game.
## Cutting art by rule is a thing you have to look at, and choosing art is a thing only a
## person can do.
##
## Needs a real window, like the boat bake — it draws through a viewport:
##   godot --path . --windowed res://tools/pigeon_contact.tscn
extends Node

const CATALOGUE := "res://assets/pigeons.json"
const SHEET := "res://assets/pigeons/Original Diminsions/Pigeon Sprite Sheet.png"
const OUT_PNG := "res://assets/pigeon_contact.png"

## How far up the birds are blown up, and how much room each row gets.
const ZOOM := 7
const ROW_HEIGHT := 84
const LEFT_MARGIN := 150
const FRAME_STEP := 110

var _shot: SubViewport
var _waited: int = 0


func _ready() -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	if book == null:
		printerr("no catalogue — run slice_pigeons.gd first")
		get_tree().quit(1)
		return
	var sheet := ImageTexture.create_from_image(
		Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	)

	# Rows of the catalogue, gathered as row -> block -> frames.
	var rows := {}
	for cell: Dictionary in book["cells"]:
		var row := int(cell["row"])
		if row == 0:
			continue  # the sheet's own title
		if not rows.has(row):
			rows[row] = {}
		var block := int(cell["block"])
		if not (rows[row] as Dictionary).has(block):
			(rows[row] as Dictionary)[block] = []
		((rows[row] as Dictionary)[block] as Array).append(cell)

	var order := rows.keys()
	order.sort()

	var page := Control.new()
	page.custom_minimum_size = Vector2(980, float(order.size() * ROW_HEIGHT + 60))
	page.size = page.custom_minimum_size

	var backing := ColorRect.new()
	backing.color = Color(0.16, 0.18, 0.18)
	backing.size = page.size
	page.add_child(backing)

	var title := Label.new()
	title.text = "Pigeons — pick the ones to use.  Left three frames are the animation."
	title.position = Vector2(16.0, 12.0)
	title.add_theme_font_size_override(&"font_size", 22)
	page.add_child(title)

	var y := 48.0
	for row: int in order:
		var label := Label.new()
		label.text = "%d" % row
		label.position = Vector2(20.0, y + 18.0)
		label.add_theme_font_size_override(&"font_size", 30)
		page.add_child(label)

		var blocks: Dictionary = rows[row]
		var block_order := blocks.keys()
		block_order.sort()
		var x := float(LEFT_MARGIN)
		for block: int in block_order:
			var frames: Array = blocks[block]
			frames.sort_custom(
				func(a: Dictionary, b: Dictionary) -> bool:
					return int(a["frame"]) < int(b["frame"])
			)
			for cell: Dictionary in frames:
				var box: Array = cell["region"]
				var shown := TextureRect.new()
				var cut := AtlasTexture.new()
				cut.atlas = sheet
				cut.region = Rect2(
					float(box[0]), float(box[1]), float(box[2]), float(box[3])
				)
				shown.texture = cut
				shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				shown.position = Vector2(x, y)
				shown.size = Vector2(float(box[2]) * ZOOM, float(box[3]) * ZOOM)
				page.add_child(shown)
				x += float(FRAME_STEP) * 0.62
			# A wider step between blocks than between frames, so the groups read apart.
			x += float(FRAME_STEP) * 0.45
		y += float(ROW_HEIGHT)

	_shot = SubViewport.new()
	_shot.size = Vector2i(page.size)
	_shot.transparent_bg = false
	_shot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_shot)
	_shot.add_child(page)


func _process(_delta: float) -> void:
	_waited += 1
	if _waited < 4:
		return
	_shot.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_PNG))
	printerr("wrote %s" % OUT_PNG)
	get_tree().quit(0)

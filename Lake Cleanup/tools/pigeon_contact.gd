## Draws the numbered picture of the pigeon sheet that the birds are chosen from.
##
## The cutting is done by tools/slice_pigeons.gd; this only lays the result out big enough
## to see, with a number against every bird, so a human can say which ones are in the game.
## Cutting art by rule is a thing you have to look at, and choosing art is a thing only a
## person can do.
##
## A row here is a **bird**, not a row of the sheet: its flap, then its standing and sitting
## pictures. The sheet is laid out by action instead — a row's first block is one bird's
## flap and its later blocks are three *other* birds' poses — so a picture laid out the
## sheet's way is the picture the wrong pairing was picked off. See assets/pigeon_birds.json.
## Birds not in use are drawn dimmed rather than left out, so the next pick sees all nine.
##
## Needs a real window, like the boat bake — it draws through a viewport:
##   godot --path . --windowed res://tools/pigeon_contact.tscn
extends Node

const CATALOGUE := "res://assets/pigeons.json"
const BIRDS := "res://assets/pigeon_birds.json"
const SHEET := "res://assets/pigeons/Original Diminsions/Pigeon Sprite Sheet.png"
const OUT_PNG := "res://assets/pigeon_contact.png"

## How far up the birds are blown up, and how much room each row gets.
const ZOOM := 7
const ROW_HEIGHT := 84
const LEFT_MARGIN := 270
const FRAME_STEP := 110

## How far a bird that is not in use is faded.
const UNUSED_FADE := 0.35

var _shot: SubViewport
var _waited: int = 0


func _ready() -> void:
	var book: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CATALOGUE))
	if book == null:
		printerr("no catalogue — run slice_pigeons.gd first")
		get_tree().quit(1)
		return
	var chosen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BIRDS))
	if chosen == null or not chosen.has("birds"):
		printerr("no %s — the birds are authored, not detected" % BIRDS)
		get_tree().quit(1)
		return
	var sheet := ImageTexture.create_from_image(
		Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	)

	var boxes := {}
	for cell: Dictionary in book["cells"]:
		var box: Array = cell["region"]
		boxes[String(cell["name"])] = Rect2(
			float(box[0]), float(box[1]), float(box[2]), float(box[3])
		)

	var flock: Array = chosen["birds"]
	var page := Control.new()
	page.custom_minimum_size = Vector2(1200, float(flock.size() * ROW_HEIGHT + 60))
	page.size = page.custom_minimum_size

	var backing := ColorRect.new()
	backing.color = Color(0.16, 0.18, 0.18)
	backing.size = page.size
	page.add_child(backing)

	var title := Label.new()
	title.text = "Pigeons — one row per bird: flap, then standing and sitting.  Dim = not in use."
	title.position = Vector2(16.0, 12.0)
	title.add_theme_font_size_override(&"font_size", 22)
	page.add_child(title)

	var y := 48.0
	for entry: Dictionary in flock:
		var used := bool(entry.get("use", true))
		var wash := Color(1.0, 1.0, 1.0, 1.0 if used else UNUSED_FADE)

		var label := Label.new()
		label.text = "%d %s" % [int(entry["bird"]), String(entry.get("name", ""))]
		label.position = Vector2(20.0, y + 18.0)
		label.add_theme_font_size_override(&"font_size", 26)
		label.modulate = wash
		page.add_child(label)

		# The flap, a gap, then the two poses — the gap is where a bird's action changes.
		var x := float(LEFT_MARGIN)
		for name: String in entry["fly"] as Array:
			_lay(page, sheet, boxes, name, Vector2(x, y), wash)
			x += float(FRAME_STEP) * 0.62
		x += float(FRAME_STEP) * 0.45
		for key: String in ["stand", "sit"]:
			_lay(page, sheet, boxes, String(entry.get(key, "")), Vector2(x, y), wash)
			x += float(FRAME_STEP) * 0.85
		y += float(ROW_HEIGHT)

	_shot = SubViewport.new()
	_shot.size = Vector2i(page.size)
	_shot.transparent_bg = false
	_shot.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_shot)
	_shot.add_child(page)


## One cut of the sheet, blown up, where it was asked for. A name the cut does not hold
## draws nothing rather than a rectangle — this picture is what a mis-authored file is
## spotted on, so a gap has to read as a gap.
func _lay(
	page: Control, sheet: Texture2D, boxes: Dictionary, name: String, at: Vector2, wash: Color
) -> void:
	if not boxes.has(name):
		return
	var box: Rect2 = boxes[name]
	var shown := TextureRect.new()
	var cut := AtlasTexture.new()
	cut.atlas = sheet
	cut.region = box
	shown.texture = cut
	shown.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shown.position = at
	shown.size = box.size * float(ZOOM)
	shown.modulate = wash
	page.add_child(shown)


func _process(_delta: float) -> void:
	_waited += 1
	if _waited < 4:
		return
	_shot.get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT_PNG))
	printerr("wrote %s" % OUT_PNG)
	get_tree().quit(0)

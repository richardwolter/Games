extends Node
## Issue #33: photographs every surface that shows a pad button, in pad mode, once with the
## PlayStation glyphs and once with the Xbox ones — the bind board (cells, the column head's
## chooser, the hint), a tour card with a glyph in its words, the letter's net card, the
## shed's shoulder chip, the lost-pad card, and the shop with a row picked (the focus halo,
## the blurb beside the board). `tools/last_glyphs_<shot>_<family>.png`.
##
## Desktop build, not --headless: nothing renders under the dummy driver. Under its own node
## and on a save of its own. The family is set on `Glyphs` directly, never through `Prefs`,
## so `user://settings.cfg` is not touched; the binds borrowed for the hint are put back.

const OUT := "res://tools/last_glyphs_%s_%s.png"
## Frames between shots, for a board to come up and draw.
const STEP := 8

var _main: Node
var _frames := 0
var _was_binds: Dictionary = {}
var _was_choice := Glyphs.Choice.AUTO
var _card: TourCard
var _family := "ps"


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", "user://probe_glyphs.save")
	add_child.call_deferred(_main)
	_was_choice = Glyphs.choice
	_was_binds = Binds.overrides()
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	var lap := 0 if _frames < 100 else 1
	var f := _frames - lap * 100
	if f == 4:
		_family = "ps" if lap == 0 else "xbox"
		Glyphs.choice = Glyphs.Choice.PLAYSTATION if lap == 0 else Glyphs.Choice.XBOX
		Pad.set_mode(Pad.Mode.PAD)
		Pad.family_moved()
		Binds.bind(&"interact", "key", "key:70")
		_main.call(&"_set_settings", true)
		_main.call(&"_set_controls", true)
	elif f == 4 + STEP:
		_save("controls")
		_main.call(&"_set_controls", false)
		_main.call(&"_set_settings", false)
		_card = TourCard.new()
		_card.pad = true
		_main.get_node(^"HUD").add_child(_card)
		var words: String = Text.TOUR_DECOR_SHELF_PAD % [
			Binds.shown(&"zoom_in", true), Binds.shown(&"interact", true), Binds.shown(&"shed_rotate", true),
		]
		_card.show_card(Rect2(1180, 260, 300, 400), words, 4, 5)
	elif f == 4 + STEP * 2:
		_save("tour")
		_card.queue_free()
		_main.call(&"_set_letter", true)
		_main.get(&"_letter").call(&"turn", 1)
	elif f == 4 + STEP * 3:
		_save("letter")
		_main.call(&"_set_letter", false)
		_main.call(&"_set_shed", true)
	elif f == 4 + STEP * 4:
		_save("shed")
		_main.call(&"_set_shed", false)
		_main.call(&"_show_pad_lost", true)
	elif f == 4 + STEP * 5:
		_save("lost")
		_main.call(&"_show_pad_lost", false)
		_main.call(&"_set_menu", true)
	elif f == 4 + STEP * 6:
		var skin := _main.get_node(^"HUD/ShopSkin")
		skin.set(&"_help_hovered", 1)
		skin.queue_redraw()
		for child in skin.get_children():
			if child is CanvasItem:
				(child as CanvasItem).queue_redraw()
	elif f == 4 + STEP * 7:
		# The shop with the stick on its first row: the halo, and the row's blurb beside the
		# board rather than over its column.
		_save("shop")
		_main.call(&"_set_menu", false)
		if lap == 1:
			_finish()


func _finish() -> void:
	Glyphs.choice = _was_choice
	Binds.take_overrides(_was_binds)
	Pad.set_mode(Pad.Mode.MOUSE)
	get_tree().quit()


func _save(shot: String) -> void:
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(OUT % [shot, _family]))

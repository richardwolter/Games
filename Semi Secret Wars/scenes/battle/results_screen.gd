class_name ResultsScreen
extends CanvasLayer
## Slim post-run results overlay: outcome + XP gained per hero, then back to the
## prep menu (where all upgrading/party setup now happens).

const UNLOCK_COLOR := Color("b08a3e")

var _panel: PanelContainer
var _title: Label
var _unlock_banner: Label
var _lines: Label

func _ready() -> void:
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f4efe1f0")
	style.border_color = Color("2c2c2c")
	style.set_border_width_all(3)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	_panel.add_child(box)
	_title = _label("", 44)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_unlock_banner = _label("STAGE 2 UNLOCKED!", 26)
	_unlock_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_banner.add_theme_color_override("font_color", UNLOCK_COLOR)
	_unlock_banner.visible = false
	box.add_child(_unlock_banner)
	_lines = _label("", 20)
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lines)
	var footer := _label("Press R to return to preparation", 18)
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(footer)

func show_results(win: bool, unlocked_stage: bool = false) -> void:
	_title.text = "VICTORY!  Stage cleared" if win else "DEFEAT"
	_unlock_banner.visible = unlocked_stage
	var lines := ""
	for hero_name in GameState.HERO_CATALOG:
		var gained := int(GameState.run_xp.get(hero_name, 0))
		if gained > 0 or GameState.party_of(hero_name).selected:
			lines += "%s  +%d XP   (banked: %d)\n" % [hero_name, gained, GameState.xp_of(hero_name)]
	_lines.text = lines.strip_edges()
	visible = true

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("2c2c2c"))
	return l

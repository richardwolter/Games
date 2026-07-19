class_name ResultsScreen
extends CanvasLayer
## Slim post-run results overlay: outcome + XP gained per hero, then back to the
## prep menu (where all upgrading/party setup now happens).

## Shared battle-overlay palette (also referenced by LevelUpScreen) so the
## in-battle overlays stay visually in sync from one place.
const PAGE_COLOR := Color("f4efe1f0")
const INK_COLOR := Color("2c2c2c")
const UNLOCK_COLOR := Color("b08a3e")

var _panel: PanelContainer
var _title: Label
var _unlock_banner: Label
var _lines: Label
var _footer: Label

func _ready() -> void:
	visible = false
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var style := StyleBoxFlat.new()
	style.bg_color = PAGE_COLOR
	style.border_color = INK_COLOR
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
	_footer = _label("Press R to return to preparation", 18)
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_footer)

## Outcome overlay. next_level > 0 means a chaining win (advance into that level
## on R, no payout shown); otherwise the run is over (loss or run complete) and
## the meta-currency payout is shown, with R returning to prep.
func show_results(win: bool, currency_awarded: int = 0, next_level: int = 0) -> void:
	var advancing := next_level > 0
	if advancing:
		_title.text = "LEVEL %d CLEARED!" % (next_level - 1)
		_unlock_banner.text = "Advancing to Level %d…" % next_level
		_unlock_banner.visible = true
	else:
		_title.text = "VICTORY!  Run complete" if win else "DEFEAT"
		_unlock_banner.visible = false
	var lines := ""
	if not advancing:
		lines += "Gold +%d\n\n" % currency_awarded
	for hero_name in GameState.HERO_CATALOG:
		var gained := int(GameState.run_xp.get(hero_name, 0))
		if gained > 0 or RunState.is_selected(hero_name):
			var tag := "  (fallen)" if RunState.is_dead(hero_name) else ""
			lines += "%s  +%d XP   (LV %d)%s\n" % [hero_name, gained, RunState.level_of(hero_name), tag]
	_lines.text = lines.strip_edges()
	_footer.text = "Press R for LEVEL %d" % next_level if advancing else "Press R to return to preparation"
	visible = true

func _label(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", INK_COLOR)
	return l

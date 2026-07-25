class_name ResultsScreen
extends CanvasLayer
## Slim post-run results overlay: outcome + XP gained per hero, then back to the
## prep menu (where all upgrading/party setup now happens).

## Shared battle-overlay palette (also referenced by LevelUpScreen) so the
## in-battle overlays stay visually in sync from one place. BORDER_COLOR
## matches the prep screens' card/ink borders (prep_menu.gd / PrepPage
## INK_COLOR) — overlays are modal notebook pages, same family as prep.
const PAGE_COLOR := UIStyle.PAGE
const INK_COLOR := UIStyle.INK
const BORDER_COLOR := UIStyle.INK
const UNLOCK_COLOR := UIStyle.GOLD

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
	_panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	_panel.add_child(box)
	_title = _label("", UIStyle.SIZE_TITLE)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_unlock_banner = _label("", UIStyle.SIZE_SUBHEAD)
	_unlock_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unlock_banner.add_theme_color_override("font_color", UNLOCK_COLOR)
	_unlock_banner.visible = false
	box.add_child(_unlock_banner)
	_lines = _label("", UIStyle.SIZE_BODY)
	_lines.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_lines)
	_footer = _label("Press R to return to preparation", UIStyle.SIZE_SMALL)
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
			lines += "%s  +%d XP%s\n" % [hero_name, gained, tag]
	# Boons are per-DUO now, not per-hero (2026-07-25 — the per-hero pool was
	# removed), so they're summarised by pairing underneath the XP lines
	# instead of as a count on each hero's row.
	var duo_lines := _duo_boon_lines()
	if duo_lines != "":
		lines += "\n" + duo_lines
	_lines.text = lines.strip_edges()
	_footer.text = "Press R for LEVEL %d" % next_level if advancing else "Press R to return to preparation"
	visible = true

## One line per Duo that picked at least one Ultimate boon this run, naming the
## boons rather than just counting them — with only one pick per Duo per level
## the list stays short, and the names are what the player actually chose.
func _duo_boon_lines() -> String:
	var out := ""
	for pair_id in RunState.duo_boons:
		var picked: Array = RunState.duo_boons[pair_id]
		if picked.is_empty():
			continue
		var names: Array[String] = []
		for id in picked:
			names.append(String(DuoUltimateBoons.def(id).get("name", id)))
		var ult: String = DuoUltimates.def(pair_id).get("name", "Ultimate")
		out += "%s — %s: %s\n" % [
			" + ".join(String(pair_id).split("|")), ult, ", ".join(names)]
	return out

func _label(text: String, size: int) -> Label:
	return UIStyle.label(text, size)

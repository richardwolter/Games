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

## Shown on the run-complete victory card. The demo ends after level 2, so this
## is the last thing a player reads — it's the ask for itch.io feedback.
const THANK_YOU_TEXT := "Thank you for playing. Please leave a comment and any criticism on the game, it is greatly appreciated."
const THANKS_WIDTH := 720.0

var _panel: PanelContainer
var _title: RichTextLabel
var _unlock_banner: RichTextLabel
var _thanks: RichTextLabel
## RichTextLabel, not Label (2026-07-26): the payout lines name both currencies,
## and gold/XP are supposed to look the same here as they do on every other
## screen — see UIStyle.gold_bbcode/xp_bbcode.
var _lines: RichTextLabel
var _footer: RichTextLabel

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
	# Title, banner and footer all name a LEVEL number, so all three are numeric
	# readouts rather than plain Labels (Designer, 2026-07-26).
	_title = UIStyle.numeric_label("", UIStyle.SIZE_TITLE, UIStyle.INK, true)
	box.add_child(_title)
	_unlock_banner = UIStyle.numeric_label("", UIStyle.SIZE_SUBHEAD, UNLOCK_COLOR, true)
	_unlock_banner.visible = false
	box.add_child(_unlock_banner)
	# Word-wrapped (unlike the numeric labels around it) because it's a sentence,
	# not a readout — left unwrapped it would stretch the panel off-screen.
	_thanks = UIStyle.numeric_label(THANK_YOU_TEXT, UIStyle.SIZE_SUBHEAD, UIStyle.INK, true)
	_thanks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_thanks.custom_minimum_size.x = THANKS_WIDTH
	_thanks.visible = false
	box.add_child(_thanks)
	_lines = UIStyle.rich_stat_label("", UIStyle.SIZE_BODY)
	box.add_child(_lines)
	_footer = UIStyle.numeric_label("Press R to return to preparation", UIStyle.SIZE_SMALL,
			UIStyle.INK, true)
	box.add_child(_footer)

## Outcome overlay. next_level > 0 means a chaining win (advance into that level
## on R, no payout shown); otherwise the run is over (loss or run complete) and
## the meta-currency payout is shown, with R returning to prep.
func show_results(win: bool, currency_awarded: int = 0, next_level: int = 0) -> void:
	var advancing := next_level > 0
	if advancing:
		UIStyle.set_numeric_text(_title, "LEVEL %d CLEARED!" % (next_level - 1))
		UIStyle.set_numeric_text(_unlock_banner, "Advancing to Level %d…" % next_level)
		_unlock_banner.visible = true
		_thanks.visible = false
	else:
		UIStyle.set_numeric_text(_title, "VICTORY!  Run complete" if win else "DEFEAT")
		# Demo build ends after level 2 (battle_manager.LAST_PLAYABLE_LEVEL), so
		# a run-complete win is the end of the game — thank the player and ask
		# for feedback right on the card (Designer, 2026-07-26).
		_unlock_banner.visible = false
		_thanks.visible = win
	var lines := ""
	if not advancing:
		lines += "%s\n\n" % UIStyle.gold_bbcode("GOLD +%d" % currency_awarded)
	for hero_name in GameState.HERO_CATALOG:
		var gained := int(GameState.run_xp.get(hero_name, 0))
		if gained > 0 or RunState.is_selected(hero_name):
			var tag := "  (fallen)" if RunState.is_dead(hero_name) else ""
			lines += "%s  %s%s\n" % [hero_name, UIStyle.xp_bbcode("+%d XP" % gained), tag]
	# The picked-boons summary that used to sit under the XP lines is gone
	# (Designer, 2026-07-26): by the results screen the run is over or rolling
	# on, and a list of what you already chose is a recap nobody acts on.
	# [center] re-applied per refresh: rich_stat_label only wraps the text it was
	# built with, and this label is rewritten on every result.
	_lines.text = "[center]%s[/center]" % lines.strip_edges()
	UIStyle.set_numeric_text(_footer, "Press R for LEVEL %d" % next_level if advancing else "Press R to return to preparation")
	visible = true

func _label(text: String, size: int) -> Label:
	return UIStyle.label(text, size)

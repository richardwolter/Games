class_name HeroPanelUI
extends PanelContainer
## Displays a single hero's status: name, level, HP bar, cooldown indicator.
## Clicking the panel asks the battle camera to lock onto this hero (via HUD).

signal clicked(hero_name: String)

const FOCUS_COLOR := UIStyle.GOLD

var hero_name := ""

var name_label: Label
## Hero art, mirrored to face the villain — see PORTRAIT_FACES_RIGHT.
var portrait: TextureRect
## Always hidden now: the old "LV n · intent" line was dropped on 2026-07-26 when
## the portrait moved into the card's top row, and its last remaining use — the
## second-wave arrival countdown — went with the timed-deploy mechanic on
## 2026-07-30. Kept wired up (the node still exists in hero_panel_ui.tscn) so the
## card has a spare row to reuse rather than needing the scene re-authored.
## RichTextLabel, like both cooldown rows below: every readout on this card that
## can show a number bolds its digits (see UIStyle.bold_numbers).
var level_label: RichTextLabel
var hp_bar: ProgressBar
var cooldown_indicator: RichTextLabel
var cooldown_bar: ProgressBar
var cooldown_indicator2: RichTextLabel
var cooldown_bar2: ProgressBar
var buff_label: RichTextLabel
## Was the live per-run KILLS/XP readout; hidden and unwritten since 2026-07-30
## (see _ready). Per-run totals still live in GameState.hero_kills_run/
## hero_xp_run and still show on the results screen; lifetime ones are on the
## prep screen's HERO DETAILS page.
var run_stats_label: RichTextLabel
var _ko := false
var _focused := false

## Heroes fight facing RIGHT: LaneField parks the villain at the right edge of
## the field (villain_pos.x well past every deploy band) and the hero art follows
## Combatant's face-left house convention, so the card mirrors it to match what
## the player sees on the battlefield.
##
## A still portrait always faces east (Designer, 2026-07-30), unlike the live
## unit, which turns to face what it is doing — see UIStyle.hero_portrait for the
## menu-side half of the same rule.
const PORTRAIT_FACES_RIGHT := true

## Font sizes the LevelLabel and the two cooldown rows carried in the .tscn
## before they became RichTextLabels. Text on this card is a step below the
## global scale — see the sizing note at the top of hero_panel_ui.tscn.
const LEVEL_FONT_SIZE := 21
const COOLDOWN_FONT_SIZE := 19

func _ready() -> void:
	name_label = find_child("NameLabel", true, false) as Label
	portrait = find_child("Portrait", true, false) as TextureRect
	if portrait != null:
		portrait.flip_h = PORTRAIT_FACES_RIGHT
	level_label = find_child("LevelLabel", true, false) as RichTextLabel
	hp_bar = find_child("HPBar", true, false) as ProgressBar
	cooldown_indicator = find_child("CooldownLabel", true, false) as RichTextLabel
	cooldown_bar = find_child("CooldownBar", true, false) as ProgressBar
	cooldown_indicator2 = find_child("CooldownLabel2", true, false) as RichTextLabel
	cooldown_bar2 = find_child("CooldownBar2", true, false) as ProgressBar
	buff_label = find_child("BuffLabel", true, false) as RichTextLabel
	run_stats_label = find_child("RunStatsLabel", true, false) as RichTextLabel
	# Sizes moved off the .tscn nodes and into code with the RichTextLabel swap —
	# a RichTextLabel needs them under normal_font_size/bold_font_size, plus the
	# bold face itself, which UIStyle.make_numeric does in one call. The values
	# are the ones those nodes carried as Labels.
	UIStyle.make_numeric(level_label, LEVEL_FONT_SIZE)
	UIStyle.make_numeric(cooldown_indicator, COOLDOWN_FONT_SIZE)
	UIStyle.make_numeric(cooldown_indicator2, COOLDOWN_FONT_SIZE)
	# The buff row and the KILLS/XP row are both hidden outright (Designer,
	# 2026-07-30). Hidden rather than deleted from hero_panel_ui.tscn so the nodes
	# are still there if either readout is ever wanted back; nothing writes to
	# either any more — see update_display.
	for dead_row in [buff_label, run_stats_label]:
		if dead_row != null:
			dead_row.text = ""
			dead_row.visible = false
	# The panel itself is the click target; children must not swallow the click.
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if hp_bar != null:
		hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in find_children("*", "Control", true, false):
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(hero_name)
		accept_event()

## Gold name while the camera is locked onto this hero.
func set_focused(focused: bool) -> void:
	if focused == _focused or name_label == null:
		return
	_focused = focused
	if _focused:
		name_label.add_theme_color_override("font_color", FOCUS_COLOR)
	else:
		name_label.remove_theme_color_override("font_color")

func update_display(hero_name_in: String, current_hp: int, max_hp: int, cooldown_remaining: float, cooldown_max: float = 1.0, _buffs: Array = [], ability_name: String = "", second_name: String = "", second_remaining: float = 0.0, second_max: float = 1.0, _kills: int = 0, _xp_gained: int = 0) -> void:
	if name_label == null or hp_bar == null or cooldown_indicator == null:
		return

	# Undo the grey-out set_ko() applies, so a card can never stay dimmed once
	# its hero is being displayed live again.
	modulate = Color.WHITE

	name_label.text = hero_name_in
	_set_portrait(hero_name_in)
	if level_label != null:
		level_label.visible = false
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	_tint_hp_bar(float(current_hp) / maxf(float(max_hp), 1.0))

	_set_cooldown_row(cooldown_indicator, cooldown_bar, ability_name, cooldown_remaining, cooldown_max)

	# Second ability row (LV20 Shockwave/Multishot); heroes without one hide it.
	if cooldown_indicator2 != null and cooldown_bar2 != null:
		var has_second := second_name != ""
		cooldown_indicator2.visible = has_second
		cooldown_bar2.visible = has_second
		if has_second:
			_set_cooldown_row(cooldown_indicator2, cooldown_bar2, second_name, second_remaining, second_max)

	# NOTE: the KILLS / XP run readout was removed from the card on 2026-07-30
	# (Designer) along with the buff row above — a battle card now carries the
	# hero, their HP and their ability cooldown, and nothing else. The per-run
	# totals are still tracked (GameState.hero_kills_run/hero_xp_run) and still
	# shown on the results screen; only this row is gone.

## The hero's own battlefield art on the card, cached so the every-frame HUD
## refresh isn't reassigning the same texture. Sourced from Hero.sprite_for so
## the card, the deploy ghost and the unit on the field can never disagree.
var _portrait_for := ""

func _set_portrait(hero_name_in: String) -> void:
	if portrait == null or hero_name_in == _portrait_for:
		return
	_portrait_for = hero_name_in
	portrait.texture = Hero.sprite_for(hero_name_in)

## HP bar fill, graded by how hurt the hero is (Designer, 2026-07-26): healthy
## green easing through yellow around half, into red when it's nearly gone.
##
## Two lerps rather than one green->red, so the midpoint is a real yellow — a
## straight interpolation between those two passes through a muddy olive and
## the "getting hurt" stage reads as no change at all. Colours are the sprite
## palette's own (UIStyle GOOD / CANARY / DANGER) so the bar belongs to the
## same box of pencils as everything else.
const HP_MID_FRAC := 0.5

func _tint_hp_bar(frac: float) -> void:
	if hp_bar == null:
		return
	frac = clampf(frac, 0.0, 1.0)
	var color: Color
	if frac >= HP_MID_FRAC:
		color = UIStyle.CANARY.lerp(UIStyle.GOOD, (frac - HP_MID_FRAC) / (1.0 - HP_MID_FRAC))
	else:
		color = UIStyle.DANGER.lerp(UIStyle.CANARY, frac / HP_MID_FRAC)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	hp_bar.add_theme_stylebox_override("fill", fill)

## Fills one ability cooldown label+bar: "NAME  READY" when up, "NAME  2.1"
## while cooling.
##
## The fill and the READY text are the ABILITY's own colour
## (UIStyle.ability_color), never green (Designer, 2026-07-26): these bars sit
## directly under the HP bar, which is green at full health, and the two used to
## read as one control. Cooling stays the shared GOLD — "waiting" means the same
## thing on every card, so it should not be four different colours.
func _set_cooldown_row(label: RichTextLabel, bar: ProgressBar, ability_name: String, remaining: float, cd_max: float) -> void:
	var prefix := ("%s  " % ability_name) if ability_name != "" else ""
	var accent := UIStyle.ability_color(ability_name)
	if bar != null:
		bar.value = 1.0 - clampf(remaining / maxf(cd_max, 0.001), 0.0, 1.0)
		_tint_bar(bar, accent)
	# default_color, not font_color: the colour key a RichTextLabel reads.
	if remaining > 0.0:
		UIStyle.set_numeric_text(label, "%s%.1f" % [prefix, remaining])
		label.add_theme_color_override("default_color", UIStyle.GOLD)
	else:
		UIStyle.set_numeric_text(label, "%sREADY" % prefix)
		label.add_theme_color_override("default_color", accent)

## Cooldown-bar fill, rebuilt only when the colour actually changes — this runs
## for two bars every HUD frame.
var _bar_tints: Dictionary = {}

func _tint_bar(bar: ProgressBar, color: Color) -> void:
	if _bar_tints.get(bar.name, Color.TRANSPARENT) == color:
		return
	_bar_tints[bar.name] = color
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("fill", fill)

func set_ko() -> void:
	if _ko or cooldown_indicator == null:
		return
	_ko = true
	hp_bar.value = 0
	if cooldown_bar != null:
		cooldown_bar.value = 0
	UIStyle.set_numeric_text(cooldown_indicator, "DOWN")

## The card as it looks during the deploy phase, before any Hero node exists
## (Designer, 2026-07-26: the pre-deployment cards must be the same cards as
## the in-battle ones). Deliberately routed through update_display rather than
## setting the labels itself — that is what guarantees "exact same card": one
## layout, one formatting path, no second version to keep in sync.
##
## HP is drawn as a FRACTION scaled to 100 rather than real numbers: max_hp
## isn't knowable until Hero._configure runs (base stats, skill tree, stat
## upgrades, the Artemis-leader bonus), and the bar only ever shows a fill, so
## a fraction renders identically. Abilities read READY because that is exactly
## how they spawn.
func set_predeploy(hero_name_in: String, hp_fraction: float,
		ability_name_in: String, kills: int, xp_gained: int) -> void:
	# kills/xp are passed through to keep BattleHUD's two call sites identical,
	# even though update_display no longer draws them (see its tail note).
	update_display(hero_name_in, int(round(clampf(hp_fraction, 0.0, 1.0) * 100.0)), 100,
			0.0, 1.0, [], ability_name_in, "", 0.0, 1.0,
			kills, xp_gained)

## NOTE: set_incoming() — the "ARRIVES IN Xs" state for a hero held back by the
## staggered second deploy wave — was removed on 2026-07-30 with the timed-deploy
## mechanic itself (see DeployController's class doc). Every placed hero is now on
## the field the moment the battle starts, so a card is only ever live, pre-deploy
## or KO.

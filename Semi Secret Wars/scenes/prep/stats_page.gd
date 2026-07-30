class_name StatsPage
extends Control
## The STATS page — spends the shared BANKED XP pool (GameState.banked_xp) on
## permanent, repeatable raw stat upgrades (StatUpgrades: HP/Damage/Attack
## Speed) for whichever hero the player chooses. Separate currency and
## separate page from ABILITIES (which spends gold) — Designer, 2026-07-19:
## "spend xp on raw stats for heroes," later shared across the roster like
## gold rather than siloed per hero.
##
## Unlike AbilityMods/AbilityTiers (bought once), each stat here can be bought
## repeatedly per hero; cost rises with prior purchases (StatUpgrades.cost_for).
## Modeled visually on AbilitiesPage (same card/column layout).

signal closed

## Per-stat colour (Designer, 2026-07-26: "give some colouring to stats menu as
## well, it's bland"). One pigment per axis, carried by that stat's card border,
## its title and its effect line, so three near-identical cards per hero become
## three distinguishable ones:
##   Max HP        GOOD    the same green the battle HP bar runs at full health
##   Damage        DANGER  the staff-gem red, already the game's "harm" colour
##   Attack Speed  INFO    the legible blue, for the one stat that is a rate
##
## Green is fine here, unlike on the battle cards' cooldown bars — nothing on
## this page is a bar, so there is no second green control to be confused with.
const STAT_COLORS := {
	"hp": UIStyle.GOOD,
	"damage": UIStyle.DANGER,
	"attack_speed": UIStyle.INFO,
}

static func _stat_color(stat_id: String) -> Color:
	return STAT_COLORS.get(stat_id, UIStyle.INK)

var _grid: HBoxContainer
var _xp_label: RichTextLabel

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_refresh()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 18)
	add_child(root)

	var title := _label("STATS", UIStyle.SIZE_HEADING)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	# The explanatory paragraph that sat here is gone (Designer, 2026-07-26) —
	# the page is three cards per hero with their costs on the buttons, and the
	# XP readout below says what pays for them.
	_xp_label = UIStyle.xp_label(0, "BANKED XP")
	root.add_child(_xp_label)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 28)
	cols.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(cols)
	_grid = cols

	var back := UIStyle.button("BACK", UIStyle.SIZE_SUBHEAD)
	back.pressed.connect(func() -> void: closed.emit())
	root.add_child(back)

func _rebuild_grid() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for hero_name in GameState.unlocked_heroes:
		_grid.add_child(_hero_column(hero_name))

func _hero_column(hero_name: String) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.custom_minimum_size = Vector2(310, 0)
	# Hero name in that hero's ability colour, the same one its cooldown bar and
	# its prep-menu Duo slot use — so a column is identifiable by colour before
	# the name is read.
	var head := UIStyle.centered_label(hero_name, UIStyle.SIZE_BODY,
			UIStyle.ability_color(Hero.ability_name_for(hero_name)))
	col.add_child(head)
	# Rich text, so each of the three current values carries its own stat colour
	# and reads as the card below it.
	col.add_child(UIStyle.rich_stat_label(_effective_stats_text(hero_name), UIStyle.SIZE_TINY))
	for id in StatUpgrades.ids():
		col.add_child(_stat_card(hero_name, id))
	return col

## Current effective HP/Damage/Attack Speed for `hero_name` — base stat (times
## the base multiplier, same as Hero._configure) with every purchased
## StatUpgrade level folded in, same formula as Hero._apply_stat_upgrades()
## uses at spawn. Ability mods (a separate, gold-spent currency/page) aren't
## included — this reflects only what THIS page's purchases changed.
func _effective_stats_text(hero_name: String) -> String:
	var stats: Dictionary = Hero.HERO_STATS.get(hero_name, {})
	var hp := float(stats.get("base_hp", 100.0))
	var dmg := float(stats.get("base_damage", 10.0))
	var atk_interval := float(stats.get("attack_interval", 0.5))
	hp *= Hero.BASE_HP_MULT
	dmg *= Hero.BASE_DAMAGE_MULT
	var hp_n := GameState.stat_purchase_count(hero_name, "hp")
	var dmg_n := GameState.stat_purchase_count(hero_name, "damage")
	var aspd_n := GameState.stat_purchase_count(hero_name, "attack_speed")
	hp += float(StatUpgrades.def("hp").get("effect_add", 0.0)) * hp_n
	dmg += float(StatUpgrades.def("damage").get("effect_add", 0.0)) * dmg_n
	if aspd_n > 0:
		atk_interval = maxf(atk_interval - float(StatUpgrades.def("attack_speed").get("effect_add", 0.0)) * aspd_n, 0.1)
	# BBCode for UIStyle.rich_stat_label: labels plain ink, values bold in their
	# own stat colour (see STAT_COLORS).
	return "HP [b][color=#%s]%d[/color][/b]   DMG [b][color=#%s]%.1f[/color][/b]   SPD [b][color=#%s]%.2f/s[/color][/b]" % [
		_stat_color("hp").to_html(false), roundi(hp),
		_stat_color("damage").to_html(false), dmg,
		_stat_color("attack_speed").to_html(false), 1.0 / atk_interval]

func _stat_card(hero_name: String, stat_id: String) -> PanelContainer:
	var d := StatUpgrades.def(stat_id)
	var count := GameState.stat_purchase_count(hero_name, stat_id)
	var cost := StatUpgrades.cost_for(hero_name, stat_id, count)
	var xp: int = GameState.banked_xp

	var accent := _stat_color(stat_id)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(accent, 10, stat_id.length()))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	# Title in the stat's colour; the level it is currently at stays ink, so the
	# colour reads as "which stat" rather than "how far along".
	box.add_child(UIStyle.numeric_label("%s (Lv %d)" % [d.get("label", stat_id), count],
			UIStyle.SIZE_SMALL, accent))
	var effect := float(d.get("effect_add", 0.0))
	var effect_text := "-%.2fs attack interval per level" % effect if stat_id == "attack_speed" \
			else "+%s per level" % (str(int(effect)) if effect == roundf(effect) else str(effect))
	box.add_child(UIStyle.numeric_label(effect_text, UIStyle.SIZE_TINY))

	# Compact so the label sits in its box with even breathing room instead of
	# being squeezed against the hand-drawn border — see UIStyle.compact_button.
	var buy := UIStyle.compact_button("Buy — %d XP" % cost, UIStyle.SIZE_SMALL,
			Callable(), stat_id.length())
	buy.disabled = xp < cost
	buy.pressed.connect(func() -> void:
		if GameState.buy_stat_upgrade(hero_name, stat_id):
			_refresh())
	box.add_child(buy)
	return card

func _refresh() -> void:
	UIStyle.set_numeric_text(_xp_label, "BANKED XP: %d" % GameState.banked_xp)
	_rebuild_grid()

func _label(text: String, font_size: int) -> Label:
	return UIStyle.label(text, font_size)

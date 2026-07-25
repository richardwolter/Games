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

var _grid: HBoxContainer
var _xp_label: Label

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

	var note := _label("Every point of XP any hero earns banks permanently into one shared pool — it never resets between runs. Spend it here on any hero's repeatable raw stat upgrades; cost rises each time.", UIStyle.SIZE_TINY)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.custom_minimum_size = Vector2(900, 0)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(note)

	_xp_label = _label("", UIStyle.SIZE_BODY)
	_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var head := _label(hero_name, UIStyle.SIZE_BODY)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(head)
	var stats_label := _label(_effective_stats_text(hero_name), UIStyle.SIZE_TINY)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(stats_label)
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
	return "HP %d   DMG %.1f   SPD %.2f/s" % [roundi(hp), dmg, 1.0 / atk_interval]

func _stat_card(hero_name: String, stat_id: String) -> PanelContainer:
	var d := StatUpgrades.def(stat_id)
	var count := GameState.stat_purchase_count(hero_name, stat_id)
	var cost := StatUpgrades.cost_for(hero_name, stat_id, count)
	var xp: int = GameState.banked_xp

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 10, stat_id.length()))

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	box.add_child(_label("%s (Lv %d)" % [d.get("label", stat_id), count], UIStyle.SIZE_SMALL))
	var effect := float(d.get("effect_add", 0.0))
	var effect_text := "-%.2fs attack interval per level" % effect if stat_id == "attack_speed" \
			else "+%s per level" % (str(int(effect)) if effect == roundf(effect) else str(effect))
	box.add_child(_label(effect_text, UIStyle.SIZE_TINY))

	var buy := UIStyle.button("Buy — %d XP" % cost, UIStyle.SIZE_SMALL)
	buy.disabled = xp < cost
	buy.pressed.connect(func() -> void:
		if GameState.buy_stat_upgrade(hero_name, stat_id):
			_refresh())
	box.add_child(buy)
	return card

func _refresh() -> void:
	_xp_label.text = "Shared Banked XP: %d" % GameState.banked_xp
	_rebuild_grid()

func _label(text: String, font_size: int) -> Label:
	return UIStyle.label(text, font_size)

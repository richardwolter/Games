class_name HeroDetailsPanel
extends CanvasLayer
## The HERO DETAILS modal (Designer, 2026-07-30): everything a hero IS, on one
## page you open when you want it.
##
## The prep roster card used to carry all of this inline — attack mode, ability,
## role blurb, effective stats, lifetime totals — which made four cards tall
## enough to crowd the pairing panel below them for information the player only
## reads while deciding. The card now shows the portrait and the name; this page
## holds the rest, reached from the DETAILS button on each card.
##
## Every number here is read from the SAME source the battlefield reads
## (Hero.HERO_STATS + the permanent StatUpgrades purchases, exactly as
## Hero._configure applies them), so what this page promises is what spawns.
##
## Same construction as HowToPlayPanel/SettingsPanel: scrim + UIStyle overlay
## panel, self-parented to the scene root, PROCESS_MODE_ALWAYS, Escape closes.
## Read SettingsPanel's doc for why these are hand-built rather than Godot
## dialogs.

## Above How To Play (207), below Settings (210): opened from prep, it is the
## page being read whenever it is up.
const LAYER := 208
const GROUP := "hero_details_panel"

const PANEL_WIDTH := 900.0
## Portrait on the detail page — bigger than the roster card's, since this is the
## page where the player actually looks at the hero.
const HERO_ART := Vector2(200, 150)

signal closed

## Which hero the page is currently showing. Switchable in-page via the hero tabs
## across the top, so a player comparing two heroes doesn't have to close and
## reopen from another card.
var _hero_name := ""
var _body: VBoxContainer

## Opens the page on `hero_name` unless one is already up (in which case it is
## simply switched to that hero — pressing DETAILS on another card behind the
## modal should show that hero, not be ignored).
##
## Parents itself to the scene root (not `host`) so a caller that frees itself —
## prep swapping to the battlefield, say — can't take the modal with it.
static func open(host: Node, hero_name: String) -> HeroDetailsPanel:
	var existing := _existing(host)
	if existing != null:
		existing.show_hero(hero_name)
		return existing
	var panel := HeroDetailsPanel.new()
	panel._hero_name = hero_name
	host.get_tree().root.add_child(panel)
	return panel

static func _existing(host: Node) -> HeroDetailsPanel:
	if host == null or not host.is_inside_tree():
		return null
	return host.get_tree().get_first_node_in_group(GROUP) as HeroDetailsPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	add_to_group(GROUP)
	_build()

func show_hero(hero_name: String) -> void:
	if hero_name == _hero_name:
		return
	_hero_name = hero_name
	_rebuild_body()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.1, 0.1, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	# Click-outside-to-close (Designer, 2026-07-30). The scrim covers everything
	# EXCEPT the panel (which is added after it, so it sits on top and eats its own
	# clicks), which makes "was this click outside the page?" the same question as
	# "did the scrim receive it?" — no hit-testing against the panel rect needed.
	scrim.gui_input.connect(_on_scrim_input)
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)

	col.add_child(UIStyle.centered_label("HERO DETAILS", UIStyle.SIZE_HEADING))
	col.add_child(_hero_tabs())

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(_body)
	_rebuild_body()

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	row.add_child(UIStyle.button("CLOSE", UIStyle.SIZE_SUBHEAD, close))

## One button per hero in the catalog — the whole roster, locked heroes included:
## this page is also where a player decides whether an unlock is worth chasing.
func _hero_tabs() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var variant := 0
	for hero_name in GameState.HERO_CATALOG:
		row.add_child(UIStyle.compact_button(hero_name, UIStyle.SIZE_TINY,
				show_hero.bind(hero_name), variant))
		variant += 1
	return row

func _rebuild_body() -> void:
	if _body == null:
		return
	for child in _body.get_children():
		_body.remove_child(child)
		child.free()

	# The hero's ABILITY colour still tints this page — the same pigment their
	# filled Duo slot and their in-battle cooldown bar take, so one hero reads as
	# one colour everywhere. Only the ability's NAME stopped being printed.
	var accent := UIStyle.ability_color(Hero.ability_name_for(_hero_name))

	# Portrait beside the identity block, so the top of the page answers "who is
	# this" before any numbers appear.
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 20)
	_body.add_child(head)
	head.add_child(UIStyle.hero_portrait(_hero_name, HERO_ART))

	var identity := VBoxContainer.new()
	identity.add_theme_constant_override("separation", 4)
	identity.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(identity)
	identity.add_child(UIStyle.label(_hero_name, UIStyle.SIZE_SUBHEAD))
	if not GameState.is_hero_unlocked(_hero_name):
		identity.add_child(UIStyle.label(_locked_text(), UIStyle.SIZE_SMALL, UIStyle.GOLD))
	# Role only here (Designer, 2026-07-30): the ability gets a section of its
	# own below, so repeating its name beside RANGED/MELEE — the way the compact
	# prep roster card has to — would say it twice on a page with room for the
	# full thing.
	identity.add_child(UIStyle.label(Hero.attack_mode_for(_hero_name),
			UIStyle.SIZE_SMALL, accent))

	_body.add_child(_section("ATTRIBUTES", accent))
	_body.add_child(_attributes_block())
	_body.add_child(_note("Attributes include every permanent STATS purchase you own — this is what spawns on the field."))

	_body.add_child(_section("ABILITY", UIStyle.GOLD))
	_body.add_child(_ability_card(accent))
	_body.add_child(_note("Abilities cast on their own cooldown, no input needed."))

	_body.add_child(_section("CAREER", UIStyle.INFO))
	_body.add_child(UIStyle.rich_stat_label(
			"KILLS [b]%d[/b]  ·  XP [b]%d[/b]" % [
				GameState.hero_kills_lifetime(_hero_name),
				GameState.hero_xp_lifetime(_hero_name)],
			UIStyle.SIZE_SMALL, UIStyle.INK_MUTED))

## Effective hero stats, one labelled chip each: base × the global base
## multipliers × permanent StatUpgrades purchases — the same formula
## Hero._configure/_apply_stat_upgrades uses at spawn, so this page, the STATS
## page and the battlefield agree.
func _attributes_block() -> HBoxContainer:
	var stats: Dictionary = Hero.HERO_STATS.get(_hero_name, {})
	var atk_interval: float = Hero.ARTEMIS_ATTACK_INTERVAL if _hero_name == "ARTEMIS" \
			else float(stats.get("attack_interval", 0.5))
	var hp: float = float(stats.get("base_hp", 100)) * Hero.BASE_HP_MULT \
			+ float(StatUpgrades.def("hp").get("effect_add", 0.0)) \
			* GameState.stat_purchase_count(_hero_name, "hp")
	var dmg: float = float(stats.get("base_damage", 10)) * Hero.BASE_DAMAGE_MULT \
			+ float(StatUpgrades.def("damage").get("effect_add", 0.0)) \
			* GameState.stat_purchase_count(_hero_name, "damage")
	atk_interval = maxf(atk_interval - float(StatUpgrades.def("attack_speed").get("effect_add", 0.0))
			* GameState.stat_purchase_count(_hero_name, "attack_speed"), 0.1)

	# Three chips, caption and number only (Designer, 2026-07-30). The per-stat
	# explanation line each carried is gone — HEALTH/DAMAGE/ATTACK SPEED explain
	# themselves — and so is the MOVE SPEED chip, which was the one number here
	# the player never acts on.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var entries := [
		["HEALTH", "%d" % int(round(hp))],
		["DAMAGE", "%d" % int(round(dmg))],
		["ATTACK SPEED", "%.2fs" % atk_interval],
	]
	var variant := 0
	for e in entries:
		row.add_child(_stat_chip(e[0], e[1], variant))
		variant += 1
	return row

func _stat_chip(caption: String, value: String, variant: int) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel",
			UIStyle.panel(Color(UIStyle.PAGE_SOLID, 0.55), UIStyle.INK_MUTED, 2, 10, variant))
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	chip.add_child(col)
	col.add_child(UIStyle.centered_label(caption, UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	col.add_child(UIStyle.numeric_label(value, UIStyle.SIZE_SUBHEAD, UIStyle.INK, true))
	return chip

## The hero's natural ability: its name, what it does, and how often it fires.
## One card, no upgrades — the skill-tree ranks bought for it belong to the shop
## that sells them (UPGRADE ABILITIES), not to the page that says what a hero IS.
func _ability_card(accent: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
			UIStyle.panel(Color(accent, 0.12), accent, 3, 10, _hero_name.length()))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	col.add_child(head)
	head.add_child(UIStyle.label(Hero.ability_name_for(_hero_name), UIStyle.SIZE_SMALL, accent))
	head.add_child(UIStyle.numeric_label("every %.0fs" % float(
			Hero.ABILITY_INFO.get(_hero_name, {}).get("cd", 0.0)),
			UIStyle.SIZE_TINY, UIStyle.INK_MUTED))

	col.add_child(UIStyle.wrapped_label(Hero.ROLE_DESCRIPTIONS.get(_hero_name, ""),
			780, UIStyle.SIZE_TINY))
	return card

## "LOCKED — <achievement name>" for a hero the player hasn't earned yet. The
## roster card already shows the live progress bar text; this page only needs to
## say why the hero isn't available.
func _locked_text() -> String:
	var ach_id := Achievements.for_hero(_hero_name)
	if ach_id == "":
		return "LOCKED"
	return "LOCKED — %s" % Achievements.def(ach_id).get("name", ach_id)

## Section heading: coloured label with a hairline under it, matching
## HowToPlayPanel so the two info pages read as the same book.
func _section(text: String, accent: Color) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(UIStyle.centered_label(text, UIStyle.SIZE_SUBHEAD, accent))
	var rule := ColorRect.new()
	rule.color = Color(accent, 0.5)
	rule.custom_minimum_size = Vector2(0, 2)
	rule.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(rule)
	return col

func _note(text: String) -> Label:
	var l := UIStyle.centered_label(text, UIStyle.SIZE_TINY, UIStyle.INK_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _on_scrim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		close()

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

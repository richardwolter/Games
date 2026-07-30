class_name HowToPlayPanel
extends CanvasLayer
## The HOW TO PLAY modal — the one place the game explains itself (Designer,
## 2026-07-28). Reachable from the title screen and from prep.
##
## Same construction as CreditsPanel (scrim + UIStyle overlay panel + scrolling
## body; read SettingsPanel's doc for why these are hand-built rather than
## Godot dialogs). Like Credits it does NOT pause the tree, and like both it
## runs PROCESS_MODE_ALWAYS so it stays usable if opened over a paused screen.
##
## Everything visual on this page is the REAL art — hero portraits come from
## Hero.sprite_for, minions/hazards preload the same textures the field and the
## spawners use. A player should recognise the thing on the field because they
## saw that exact drawing here, so when art is replaced these consts must be
## repointed with it (the same contract Minion.VARIANT_OVERRIDES documents).

## Above Credits (205), below Settings (210): if How To Play and Credits are
## somehow both up, this is the one being read.
const LAYER := 207
const GROUP := "how_to_play_panel"

const PANEL_WIDTH := 1000.0
## Height cap on the scrolling body. Sized so title + body + CLOSE clears the
## 1080 design canvas.
##
## Dropped 720 -> 580 with the 2026-07-28 trim: this is a MINIMUM as well as a
## cap (ScrollContainer.custom_minimum_size), so leaving it at 720 after cutting
## two enemy cards, two hazard cards and most of the prose would have padded the
## panel with dead paper instead of making it feel shorter.
const BODY_HEIGHT := 580.0

## Thumbnail boxes. Heroes get the larger one (their art is the most detailed
## and they're the row the player studies); enemies and hazards read fine
## smaller and there are more of them per row.
const HERO_ART := Vector2(120, 96)
const ENEMY_ART := Vector2(104, 84)
const HAZARD_ART := Vector2(96, 72)

## The run loop, in the order the player meets it. One line each (Designer,
## 2026-07-28: "the Run can be a little shorter on explanation") — this is a
## map of the loop, not a manual for each screen. The screens themselves carry
## their own hints.
const FLOW: Array[Array] = [
	["1. PAIR", "Drag heroes into DUO A and DUO B. Only a paired hero deploys."],
	["2. UPGRADE", "Spend GOLD on abilities and XP on stats. Both are permanent."],
	["3. DEPLOY", "Place each Duo in the deploy band, then press START BATTLE."],
	["4. FIGHT", "Heroes fight on their own. You choose where, when, and each Duo's Ultimate."],
	["5. CLEAR", "Kill the villain and destroy every spawn portal."],
]

## Abilities fire on their own cooldown, no input needed — worth saying once
## next to the cards rather than four times on them.
const ABILITY_FOOTNOTE := "Abilities cast automatically when their cooldown is up."

## What the player is up against. Deliberately NOT a bestiary (Designer,
## 2026-07-28): listing every minion variant taught the player to sort art into
## named buckets when the only thing they act on is "can it reach me from over
## there?". One card covers the whole swarm.
##
## The villain card shows a "?" instead of his sprite, on the same note — the
## boss reveal is worth more than the warning. `glyph` entries render as text in
## the thumbnail box; see _thumbnail.
const ENEMIES: Array[Dictionary] = [
	{"tex": preload("res://assets/sprites/Minion-Dark-Mage_Color.png"),
		"name": "THE SWARM", "desc": "Endless minions, melee or ranged. They hunt your heroes."},
	{"tex": preload("res://assets/sprites/Portal-Spawn_Color.png"),
		"name": "SPAWN PORTAL", "desc": "Feeds the swarm forever. Destroy every one to clear."},
	{"glyph": "?",
		"name": "VILLAIN", "desc": "Each stage has one. Find out for yourself."},
]

## Terrain the player has to read before choosing where to drop a Duo. Two
## entries, not four — the lane only ever asks one of two questions: does this
## hurt me, or is it in my way?
const HAZARDS: Array[Dictionary] = [
	{"tex": preload("res://assets/sprites/Spike_Hazard_Color.png"),
		"name": "HAZARDS", "desc": "Hurt anything that walks over them. Don't park a Duo on one."},
	{"tex": preload("res://assets/sprites/Rock-1_Color.png"),
		"name": "OBSTACLES", "desc": "Block movement and shots. Use them to funnel the swarm."},
]

const CLOSING := "Heroes that fall stay down. Lose them all and the run ends."

signal closed

## Opens the panel unless one is already up. Returns the live panel either way.
## Parents itself to the scene root (not `host`) so a caller that frees itself
## — prep swapping to the battlefield, say — can't take the modal with it.
static func open(host: Node) -> HowToPlayPanel:
	var existing := _existing(host)
	if existing != null:
		return existing
	var panel := HowToPlayPanel.new()
	host.get_tree().root.add_child(panel)
	return panel

## Button behavior: a second press on the thing that opened it closes it again.
static func toggle(host: Node) -> void:
	var existing := _existing(host)
	if existing != null:
		existing.close()
		return
	open(host)

static func _existing(host: Node) -> HowToPlayPanel:
	if host == null or not host.is_inside_tree():
		return null
	return host.get_tree().get_first_node_in_group(GROUP) as HowToPlayPanel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	add_to_group(GROUP)
	_build()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.color = Color(0.1, 0.1, 0.1, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.add_theme_stylebox_override("panel", UIStyle.overlay_panel())
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)

	box.add_child(UIStyle.centered_label("HOW TO PLAY", UIStyle.SIZE_HEADING))
	box.add_child(UIStyle.centered_label(
			"An autobattler. You build the team and choose the moment — the heroes do the fighting.",
			UIStyle.SIZE_SMALL, UIStyle.INK_MUTED))

	box.add_child(_build_body())

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(UIStyle.button("CLOSE", UIStyle.SIZE_SUBHEAD, close))

## Everything between the title and CLOSE, scrolling as one column — the page
## is well past a screen tall with the art rows on it.
func _build_body() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, BODY_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_section_title("THE RUN", UIStyle.GOLD))
	for step in FLOW:
		col.add_child(_flow_row(step[0], step[1]))

	col.add_child(_section_title("YOUR HEROES", UIStyle.INFO))
	col.add_child(_hero_row())
	col.add_child(_note(ABILITY_FOOTNOTE))

	col.add_child(_section_title("DUO ULTIMATES", UIStyle.GOLD))
	col.add_child(_note("Every pairing has its own Ultimate, shown on the Duo box in prep. Once per level, on your click."))

	col.add_child(_section_title("WHAT YOU'RE FIGHTING", UIStyle.VIOLET))
	col.add_child(_art_row(ENEMIES, ENEMY_ART, UIStyle.VIOLET))

	col.add_child(_section_title("THE LANE ITSELF", UIStyle.BARK))
	col.add_child(_art_row(HAZARDS, HAZARD_ART, UIStyle.BARK))

	col.add_child(_note(CLOSING))

	return scroll

## Section heading: coloured label with a hairline under it, so the page reads
## as chapters instead of one long wall on paper.
func _section_title(text: String, accent: Color) -> VBoxContainer:
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

## One step of THE RUN: numbered tag on the left, explanation filling the rest.
func _flow_row(tag: String, text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var tag_label := UIStyle.label(tag, UIStyle.SIZE_BODY, UIStyle.GOLD)
	tag_label.custom_minimum_size = Vector2(160, 0)
	tag_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(tag_label)

	var body := UIStyle.label(text, UIStyle.SIZE_SMALL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(body)
	return row

## The four hero cards, each tinted with that hero's ABILITY colour — the same
## pigment their cooldown bar, their filled Duo slot and their roster card all
## use, so this page joins the same colour language rather than inventing one.
func _hero_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	var variant := 0
	for hero_name in GameState.HERO_CATALOG:
		row.add_child(_hero_card(hero_name, variant))
		variant += 1
	return row

func _hero_card(hero_name: String, variant: int) -> PanelContainer:
	var ability := Hero.ability_name_for(hero_name)
	var accent := UIStyle.ability_color(ability)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(accent, 10, variant))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	col.add_child(UIStyle.hero_portrait(hero_name, HERO_ART))
	col.add_child(UIStyle.centered_label(hero_name, UIStyle.SIZE_SMALL))
	col.add_child(UIStyle.centered_label("%s  ·  %s" % [Hero.attack_mode_for(hero_name), ability],
			UIStyle.SIZE_TINY, accent))
	# Hero.ROLE_DESCRIPTIONS — the exact line the prep roster card shows
	# (Designer, 2026-07-28: "use only what we present on prep menu"). This page
	# used to carry its own longer ability write-up, which meant two strings to
	# keep in step and a hero described one way here and another way at draft.
	col.add_child(UIStyle.wrapped_label(Hero.ROLE_DESCRIPTIONS.get(hero_name, ""),
			200, UIStyle.SIZE_TINY))
	return card

## A row of art thumbnails with a name and a line of text — used for both the
## enemy and the hazard sections, which differ only in their entries and tint.
func _art_row(entries: Array[Dictionary], art_box: Vector2, accent: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	var variant := 0
	for entry in entries:
		row.add_child(_art_card(entry, art_box, accent, variant))
		variant += 1
	return row

func _art_card(entry: Dictionary, art_box: Vector2, accent: Color, variant: int) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel",
			UIStyle.panel(Color(UIStyle.PAGE_SOLID, 0.5), accent, 3, 8, variant))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	col.add_child(_thumbnail_for(entry, art_box, accent))
	col.add_child(UIStyle.centered_label(String(entry.get("name", "")), UIStyle.SIZE_TINY, accent))
	col.add_child(UIStyle.wrapped_label(String(entry.get("desc", "")), 170, UIStyle.SIZE_TINY))
	return card

## An entry draws either its art or, for a deliberately hidden one, its `glyph`
## as text in an identically-sized box — so a "?" card lines up in the row
## exactly like the drawn ones beside it.
func _thumbnail_for(entry: Dictionary, box: Vector2, accent: Color) -> Control:
	var glyph := String(entry.get("glyph", ""))
	if glyph == "":
		return _thumbnail(entry.get("tex"), box)
	var l := UIStyle.centered_label(glyph, UIStyle.SIZE_TITLE, accent)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.custom_minimum_size = box
	return l

## Same treatment UIStyle.hero_portrait gives a hero, for any texture — the
## field art is drawn at wildly different native sizes, so every thumbnail is
## aspect-fit into an identical box or the row reads as ragged.
func _thumbnail(texture: Variant, box: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = texture as Texture2D
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = box
	return t

## Aside text under a section — the rules that don't belong to any one card.
func _note(text: String) -> Label:
	var l := UIStyle.centered_label(text, UIStyle.SIZE_TINY, UIStyle.INK_MUTED)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func close() -> void:
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()

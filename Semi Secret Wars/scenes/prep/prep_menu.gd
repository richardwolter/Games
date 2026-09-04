class_name PrepMenu
extends Control
## The prep screen — party draft + gold/ability shop, then START into the
## lane battlefield. No priority/support-target pickers — heroes just push
## the lane.
##
## There is no separate "select party" checkbox — dragging a hero into a Duo
## slot IS the selection. A hero only deploys if it's paired (both slots of
## a Duo filled); an unplaced hero sits the run out. See _sync_party_from_slots.

var _start_button: TextureButton
var _currency_label: RichTextLabel
var _xp_label: RichTextLabel
var _hero_row: HBoxContainer
var _main: VBoxContainer
var _abilities_page: AbilitiesPage
var _stats_page: StatsPage

## Duo pairing panel state. _pairing_slots is a flat 4-slot array — indices
## 0/1 are Duo A, indices 2/3 are Duo B — populated by dragging a hero card
## from _hero_row onto a DuoSlot. Every change re-derives RunState.party and
## GameState.duo_pairings from whichever Duos are fully filled — see
## _sync_party_from_slots.
var _pairing_section: VBoxContainer
## Held for the tutorial tour, which reveals the page one section at a time —
## see _run_tutorial_tour.
var _gold_column: Control
var _xp_column: Control
var _back_button: Button
var _pairing_slots: Array = ["", "", "", ""]

## Hand-drawn texture replacing the plain "START RUN" button (Designer,
## 2026-07-25). Cropped tight to the drawn label's bounding box within the
## source PNG so the button isn't mostly transparent padding. Swapped to the
## coloured version 2026-07-26 — same 1590x1152 canvas, so START_RUN_REGION
## carries over; it assumes the redraw sits in the same place on that canvas.
const START_RUN_TEXTURE := preload("res://assets/Button_StartRun_Color.png")
const START_RUN_REGION := Rect2(60, 210, 1500, 640)
const START_RUN_WIDTH := 360.0
## Both Duo boxes are plain ink — border and title alike (Designer, 2026-07-26,
## reaffirmed 2026-07-30 after a one-round trial of the gold/navy pair). The Duo
## colour competed with the colour that actually means something on this panel:
## the hero's ability tint filling each occupied slot. UIStyle.DUO_A/DUO_B still
## paint the two Duos apart in BATTLE (hero-card groups, Hero Control rows,
## refocus markers); this screen just doesn't use them.
const DUO_A_COLOR := UIStyle.INK
const DUO_B_COLOR := UIStyle.INK
const SLOT_SIZE := Vector2(210, 100)
## Hero sprite inside a filled Duo slot. Sized to sit beside the name inside
## SLOT_SIZE's 100px height with the LEADER/FOLLOWER tag still above it — the
## row the Duo Ultimate caption gave up (see _build_ultimate_label) is what
## makes the box tall enough to carry it.
const PORTRAIT_SIZE := Vector2(52, 52)

## A hero card that can be dragged onto a DuoSlot. Only the drag affordance is
## added here — selection/unlock UI stays in _build_hero_card, which builds
## one of these instead of a plain PanelContainer.
class DraggableHeroCard extends PanelContainer:
	var hero_name: String = ""
	var swatch_color: Color = Color.WHITE

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if hero_name == "":
			return null
		var preview := PanelContainer.new()
		preview.add_theme_stylebox_override("panel",
				UIStyle.panel(Color(swatch_color, 0.85), UIStyle.INK, 3, 10))
		preview.add_child(UIStyle.label(hero_name, UIStyle.SIZE_BODY))
		set_drag_preview(preview)
		return {"hero_name": hero_name}

## One of the 4 drop targets inside the Duo A / Duo B boxes. Reports drops and
## clicks (to clear) back to PrepMenu via injected Callables — the panel is
## fully rebuilt after either, so this class holds no display state itself.
class DuoSlot extends PanelContainer:
	var duo_index: int = 0
	var slot_index: int = 0
	var on_drop: Callable
	var on_clear: Callable

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return data is Dictionary and data.has("hero_name")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		on_drop.call(String(data["hero_name"]), duo_index, slot_index)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			on_clear.call(duo_index, slot_index)

func _ready() -> void:
	_setup_music()
	RunState.roll_draft_offer()
	_seed_pairing_slots()
	_build_ui()
	_refresh()
	if Tutorial.phase == Tutorial.Phase.PREP:
		_run_tutorial_tour()

## The prep theme lives in prep_menu.tscn, so neither of these can be set in
## the inspector: the Music bus is created at runtime by AudioSettings, and the
## process mode matters because SettingsPanel pauses the tree — a PAUSABLE
## player would go silent the instant the player opened Settings to adjust the
## music volume (Designer, 2026-07-26: music should keep playing while you
## tweak, otherwise there's nothing to tune against).
func _setup_music() -> void:
	var music := get_node_or_null("AudioStreamPlayer2D") as AudioStreamPlayer2D
	if music == null:
		return
	music.bus = AudioSettings.BUS_MUSIC
	music.process_mode = Node.PROCESS_MODE_ALWAYS
	# Loop the theme rather than letting the screen fall silent after one pass —
	# prep is a screen players sit on. Safe to set directly on an MP3 stream;
	# only AudioStreamWAV needs the loop_begin/loop_end care BattleManager
	# documents.
	if music.stream is AudioStreamMP3:
		(music.stream as AudioStreamMP3).loop = true

## Restores the Duo layout from GameState.duo_pairings (persists across prep
## visits) into the flat slot array the drag UI reads.
func _seed_pairing_slots() -> void:
	_pairing_slots = ["", "", "", ""]
	var duos: Array = GameState.duo_pairings
	for d in range(mini(2, duos.size())):
		var duo: Array = duos[d]
		if duo.size() == 2:
			_pairing_slots[d * 2] = duo[0]
			_pairing_slots[d * 2 + 1] = duo[1]
	_sync_party_from_slots()

func _build_ui() -> void:
	var bg := PrepPage.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_CENTER)
	root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	root.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_theme_constant_override("separation", 16)
	add_child(root)
	_main = root

	# One header row instead of two stacked ones (Designer, 2026-07-30): HOW TO
	# PLAY and SETTINGS flank the logo, which buys back a whole row of vertical
	# space for the roster and Duo boxes below and puts the two buttons in the
	# empty margins beside the wordmark rather than under it.
	#
	# GOLD and BANKED XP are not up here at all any more — they moved down beside
	# the shops that spend them, see _build_shop_column.
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 28)
	header.add_child(_header_button("HOW TO PLAY", _open_how_to_play))
	header.add_child(_build_logo())
	header.add_child(_header_button("SETTINGS", _open_settings))
	root.add_child(header)

	# Centered (Designer, 2026-07-30): the roster is the row the eye starts on, and
	# left-aligned it sat off-axis from the Duo boxes and START RUN below it. Both
	# flags are needed — the VBox stretches this row to the widest child's width,
	# so the HBox has to centre its own cards inside that width.
	_hero_row = HBoxContainer.new()
	_hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_hero_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_row.add_theme_constant_override("separation", 24)
	root.add_child(_hero_row)
	_rebuild_hero_row()

	_pairing_section = VBoxContainer.new()
	_pairing_section.add_theme_constant_override("separation", 8)
	root.add_child(_pairing_section)
	_rebuild_pairing_panel()

	# The two upgrade shops flank START RUN (Designer, 2026-07-28) — they're the
	# meta-progression, not chrome, so they sit in the one row the player's eye
	# already ends on instead of hiding among GOLD/XP/SETTINGS up top.
	var launch_row := HBoxContainer.new()
	launch_row.alignment = BoxContainer.ALIGNMENT_CENTER
	launch_row.add_theme_constant_override("separation", 28)
	root.add_child(launch_row)

	_currency_label = UIStyle.gold_label(0)
	_gold_column = _build_shop_column(_currency_label, UIStyle.GOLD_COLOR,
			_upgrade_button("UPGRADE\nABILITIES", "spend GOLD", UIStyle.GOLD, 0, _open_abilities))
	launch_row.add_child(_gold_column)

	_start_button = _texture_button(START_RUN_TEXTURE, START_RUN_REGION, _on_start)
	_start_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	launch_row.add_child(_start_button)

	_xp_label = UIStyle.xp_label(0, "BANKED XP")
	_xp_column = _build_shop_column(_xp_label, UIStyle.XP_COLOR,
			_upgrade_button("UPGRADE\nSTATS", "spend XP", UIStyle.XP_COLOR, 1, _open_stats))
	launch_row.add_child(_xp_column)

	# Route back to the title screen (Designer, 2026-07-26). No confirmation
	# here: prep changes (purchases, pairings) all save as they're made, so
	# leaving this screen abandons nothing — unlike the battle's version.
	_back_button = _button("BACK TO MENU", UIStyle.SIZE_SMALL, _on_back_to_menu)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	root.add_child(_back_button)


## A big flanking shop button: accent-bordered card, two-line title, and a
## caption naming the currency it spends. Built as a bare Button with its own
## label stack parented inside (mouse-transparent) because Button.text is one
## line and can't colour the caption differently from the title.
## MINIMUM box, not the final one — _upgrade_button grows it to whatever the
## text actually needs (see _upgrade_button_size). It stayed a hard 230x116 until
## 2026-07-28, which is why the Caveat Brush switch broke it: three lines of that
## face measure 121px tall against the 92 this box leaves once its border margin
## is taken out, so "spend GOLD"/"spend XP" spilled through the bottom edge.
const UPGRADE_BUTTON_SIZE := Vector2(230, 116)
## Border inset on the upgrade cards, shared by the stylebox and the label stack
## laid inside it — they must agree or the text sits on the border.
const UPGRADE_BUTTON_PAD := 12

func _upgrade_button(title: String, caption: String, accent: Color, variant: int,
		cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = _upgrade_button_size(title, caption)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# Same paper card as the resource chips, in the currency's own colour, so the
	# button reads as "this is where that number goes".
	var pad := UPGRADE_BUTTON_PAD
	var style := UIStyle.panel(Color(accent, 0.14), accent, 4, pad, variant)
	b.add_theme_stylebox_override("normal", style)
	b.add_theme_stylebox_override("hover", UIStyle.panel(Color(accent, 0.3), accent, 4, pad, variant))
	b.add_theme_stylebox_override("pressed", UIStyle.panel(Color(accent, 0.42), accent, 4, pad, variant))
	b.add_theme_stylebox_override("focus", style)
	UIStyle.add_click_sound(b)
	UIStyle.add_hover_wiggle(b)
	if cb.is_valid():
		b.pressed.connect(cb)

	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Inset to match the stylebox's own content margin. A Button is not a
	# container, so an anchored child is laid out against the RAW rect and knows
	# nothing about that margin — without these offsets the text is free to sit
	# on top of the hand-drawn border.
	col.offset_left = UPGRADE_BUTTON_PAD
	col.offset_top = UPGRADE_BUTTON_PAD
	col.offset_right = -UPGRADE_BUTTON_PAD
	col.offset_bottom = -UPGRADE_BUTTON_PAD
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", UPGRADE_BUTTON_LINE_GAP)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for line in title.split("\n"):
		col.add_child(UIStyle.centered_label(line, UIStyle.SIZE_SUBHEAD, accent))
	col.add_child(UIStyle.centered_label(caption, UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	b.add_child(col)
	return b

## Gap between the title lines and the caption inside an upgrade button.
const UPGRADE_BUTTON_LINE_GAP := 2

## The box this button needs to hold its own text, never smaller than the
## authored UPGRADE_BUTTON_SIZE. Measured from the live font rather than
## hardcoded, so swapping the face again resizes these buttons instead of
## silently pushing their caption through the bottom border.
##
## Falls back to the authored size when UIStyle.font() is null (the .ttf not yet
## imported) — the engine default is narrower than the hand face, so the authored
## box is already generous in that case.
func _upgrade_button_size(title: String, caption: String) -> Vector2:
	var f := UIStyle.font()
	if f == null:
		return UPGRADE_BUTTON_SIZE
	var lines: PackedStringArray = title.split("\n")
	var text_w := 0.0
	var text_h := 0.0
	for line in lines:
		text_w = maxf(text_w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_CENTER,
				-1, UIStyle.SIZE_SUBHEAD).x)
		text_h += f.get_height(UIStyle.SIZE_SUBHEAD)
	text_w = maxf(text_w, f.get_string_size(caption, HORIZONTAL_ALIGNMENT_CENTER,
			-1, UIStyle.SIZE_TINY).x)
	text_h += f.get_height(UIStyle.SIZE_TINY)
	text_h += float(UPGRADE_BUTTON_LINE_GAP * lines.size())
	var pad := float(UPGRADE_BUTTON_PAD) * 2.0
	return Vector2(maxf(UPGRADE_BUTTON_SIZE.x, text_w + pad),
			maxf(UPGRADE_BUTTON_SIZE.y, text_h + pad))

## The hand-drawn wordmark at the top of prep (Designer, 2026-07-30), replacing
## the plain "SEMI-SECRET WARS" text heading — the same art the title screen
## opens on, so the two screens are visibly the same game.
##
## Much shorter than the title screen's 640x429 treatment: prep is a dense screen
## with a roster, four Duo slots and three shop controls to fit under this, so the
## logo is a banner here rather than the whole top half. Aspect-fit inside the
## box, so the two never disagree about the art's proportions.
const LOGO_TEXTURE := preload("res://assets/sprites/Logo_Semi-Secret-Wars.png")
const LOGO_SIZE := Vector2(360, 120)

## Width both header buttons are forced to. Without it the logo between them is
## NOT centred on screen (Designer, 2026-07-30): "HOW TO PLAY" is far wider than
## "SETTINGS", and an HBoxContainer centres its CONTENTS as a block — so the
## logo sat off-axis by half the difference, and off-axis from the hero cards and
## the Duo boxes below it, which are centred on the screen itself. Equal flanks
## put the middle of the row at the middle of the row's contents.
const HEADER_BUTTON_WIDTH := 260.0

## A header button beside the logo. Vertically centred against it, so the two
## sit on the wordmark's midline rather than on its top edge (an HBoxContainer
## would otherwise stretch them to the logo's full height).
func _header_button(text: String, cb: Callable) -> Button:
	var b := _button(text, UIStyle.SIZE_BODY, cb)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.custom_minimum_size = Vector2(HEADER_BUTTON_WIDTH, 0)
	return b

func _build_logo() -> TextureRect:
	var logo := TextureRect.new()
	logo.texture = LOGO_TEXTURE
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = LOGO_SIZE
	return logo

## A shop and the currency it spends, stacked as one unit (Designer, 2026-07-30):
## the GOLD / BANKED XP chips used to sit in the top row among HOW TO PLAY and
## SETTINGS, a screen away from the buttons that spend them, so "can I afford
## anything?" meant looking in two places. Same chip, same accent — it just sits
## directly above its own shop now, and the currency's colour ties the pair
## together.
func _build_shop_column(label: Control, accent: Color, shop: Button) -> VBoxContainer:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 8)
	var chip := _resource_chip(label, accent)
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(chip)
	shop.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(shop)
	return col

## Accent-bordered paper chip around a resource readout. The label is kept as
## a field by the caller (_refresh rewrites its text), so this only wraps it.
func _resource_chip(label: Control, accent: Color) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIStyle.card(accent, 10))
	chip.add_child(label)
	return chip

func _rebuild_hero_row() -> void:
	for child in _hero_row.get_children():
		child.queue_free()
	for hero_name in GameState.HERO_CATALOG:
		if GameState.is_hero_unlocked(hero_name):
			_hero_row.add_child(_build_hero_card(hero_name))
		else:
			_hero_row.add_child(_build_locked_hero_card(hero_name))

## Duo Pairings panel: two side-by-side boxes (Duo A / Duo B), each with 2
## drop slots. Drag a hero card down from the row above onto a slot to place
## it there — that's the only way a hero joins the run (see class doc). Only
## heroes in a fully-filled Duo (both slots occupied) actually deploy; a
## hero placed alone still needs a partner.
func _rebuild_pairing_panel() -> void:
	for child in _pairing_section.get_children():
		child.queue_free()

	var offered: Array = RunState.draft_offer.duplicate()

	# Drop any slot occupant that fell out of the offer (shouldn't normally
	# happen — offer only changes via unlocks — but keeps state sane).
	for i in _pairing_slots.size():
		if _pairing_slots[i] != "" and _pairing_slots[i] not in offered:
			_pairing_slots[i] = ""

	# The instruction callout on the left, the two Duo boxes in the middle — and a
	# blank spacer of the callout's exact width on the right (Designer, 2026-07-30:
	# the Duo boxes should be centred on the SCREEN). Without it the row centres
	# callout+boxes as one block, which pushes the boxes right of centre by half
	# the callout's width and leaves them off-axis from the logo, the hero row and
	# START RUN — every other thing on this screen is centred.
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	_pairing_section.add_child(row)

	row.add_child(_pairing_instruction())

	var boxes := HBoxContainer.new()
	boxes.alignment = BoxContainer.ALIGNMENT_CENTER
	boxes.add_theme_constant_override("separation", 32)
	row.add_child(boxes)
	boxes.add_child(_build_duo_box(0, "DUO A", DUO_A_COLOR))
	boxes.add_child(_build_duo_box(1, "DUO B", DUO_B_COLOR))

	var balance := Control.new()
	balance.custom_minimum_size = Vector2(PAIRING_CARD_WIDTH, 0)
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(balance)

## The pairing callout beside the Duo boxes: what to do, and why you would care.
##
## It reads as a control the screen is giving you rather than a caption in the
## margin — a new player would otherwise stare at two empty Duo boxes with no
## idea the hero row above was draggable (Designer, 2026-07-28).
##
## EMBER red, not the gold it used to be (Designer, 2026-07-30): gold on this
## screen already means "currency and the shop that spends it" (the GOLD chip,
## UPGRADE ABILITIES), and a gold callout sitting between them read as a third
## piece of that same UI. Red is unused on this screen and belongs to nothing
## else here, so the one instruction stands apart from the economy around it.
##
## The body sells the REASON to pair rather than restating the mechanic, with
## "ultimate abilities" emboldened in the same red as the payoff (Designer,
## 2026-07-30) — which is why it is a BBCode label rather than a plain one.
const PAIRING_ACCENT := UIStyle.EMBER
## Width of the callout — also the width of the blank spacer mirroring it on the
## far side of the Duo boxes, which is what keeps those boxes centred on screen
## (see _rebuild_pairing_panel). The two must stay equal.
const PAIRING_CARD_WIDTH := 280.0
##
## Two things that used to live here are gone (both Designer, 2026-07-30): the
## "Both DUOS must be filled" / "Still to place" status line (four empty slots
## and a dimmed START RUN say it without a sentence) and the CLEAR PAIRING button
## (clicking a filled slot already empties it — see DuoSlot._gui_input — so the
## button was a second way to do a thing the slots do).
func _pairing_instruction() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(PAIRING_ACCENT, 12, 2))
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.custom_minimum_size = Vector2(PAIRING_CARD_WIDTH, 0)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)

	col.add_child(UIStyle.centered_label("DRAG HEROES TO DUO", UIStyle.SIZE_SUBHEAD,
			PAIRING_ACCENT))
	var body := UIStyle.rich_stat_label(
			"Join heroes as a DUO and find out their [b][color=#%s]ultimate abilities[/color][/b]."
					% PAIRING_ACCENT.to_html(false),
			UIStyle.SIZE_SMALL)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD
	body.custom_minimum_size = Vector2(244, 0)
	col.add_child(body)
	return card

## NOTE: _pairing_hint_text — the "Both DUOS must be filled" / "Still to place:"
## status line — was removed on 2026-07-30 at the Designer's call. The empty
## FRONT/BACK slots and the dimmed START RUN carry that information without a
## sentence about it. _both_duos_ready below is unaffected; it is what actually
## gates the run.

## Whether the pairing is complete enough to launch: TWO fully-filled Duos.
##
## Checked against duo_pairings rather than the party roster or
## GameState.has_valid_duo_pairings(draft_offer): _sync_party_from_slots only ever
## appends a Duo once BOTH its slots are filled, so a size of 2 here is exactly
## "both Duos are ready" — and unlike the has_valid_duo_pairings form it does not
## additionally demand that the pairing cover the whole offered roster, which
## would break the moment a 5th hero is unlocked.
func _both_duos_ready() -> bool:
	return GameState.duo_pairings.size() == 2

## One Duo box: a colored-border panel labeled "DUO A"/"DUO B" containing its
## 2 DuoSlot drop targets side by side.
func _build_duo_box(duo_index: int, title: String, color: Color) -> PanelContainer:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIStyle.card(color, 10, duo_index))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)

	col.add_child(UIStyle.centered_label(title, UIStyle.SIZE_SMALL, color))

	var slots_row := HBoxContainer.new()
	slots_row.add_theme_constant_override("separation", 8)
	col.add_child(slots_row)
	slots_row.add_child(_build_duo_slot(duo_index, 0, color))
	slots_row.add_child(_build_duo_slot(duo_index, 1, color))

	col.add_child(_build_ultimate_label(duo_index))

	return box

## Duo Ultimate chip: only shown once both slots of this Duo are filled, since
## the Ultimate is a property of the PAIR (DuoUltimates — one exclusive entry
## per unordered hero pair). Shows the same name/desc the in-battle Duo
## Ultimate bar will show, so the player picks a pairing knowing what it
## unlocks (Designer, 2026-07-25).
##
## This replaced the named-synergy chip that used to sit here. That catalog
## (DuoSynergies) was deleted outright on 2026-07-26 once its last reader — the
## battlefield's "DUO A: <name>" banner — was removed too: the names were never
## used for anything, and all six shared one generic blurb. The generic Duo
## Bonus mechanic in Hero (DUO_* consts, _update_duo_bonus) is untouched; it
## never depended on that catalog.
func _build_ultimate_label(duo_index: int) -> Control:
	var hero_a: String = _pairing_slots[duo_index * 2]
	var hero_b: String = _pairing_slots[duo_index * 2 + 1]
	if hero_a == "" or hero_b == "":
		return Control.new()
	var d := DuoUltimates.def(DuoUltimates.id_for_heroes(hero_a, hero_b))
	if d.is_empty():
		return Control.new()
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	# Caption and name share one line (Designer, 2026-07-26) — three stacked rows
	# here is what was pushing the Duo box tall enough that the slots had no room
	# for a portrait. The caption is a label for the name, so sitting beside it
	# costs nothing and buys back a whole row.
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 8)
	head.add_child(UIStyle.label("DUO ULTIMATE", UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	head.add_child(UIStyle.label(d.get("name", ""), UIStyle.SIZE_SMALL, UIStyle.GOLD))
	col.add_child(head)
	col.add_child(UIStyle.wrapped_label(d.get("desc", ""), 400, UIStyle.SIZE_TINY, UIStyle.INK_MUTED))
	return col

func _build_duo_slot(duo_index: int, slot_index: int, color: Color) -> DuoSlot:
	var slot := DuoSlot.new()
	slot.duo_index = duo_index
	slot.slot_index = slot_index
	slot.on_drop = _on_slot_drop
	slot.on_clear = _on_slot_clear
	slot.custom_minimum_size = SLOT_SIZE
	slot.mouse_filter = Control.MOUSE_FILTER_STOP

	var hero_name: String = _pairing_slots[duo_index * 2 + slot_index]
	# Which slot leads is a pure player choice (Designer, 2026-07-20: "tank always
	# leads does not work anymore ... this should be a player decision") —
	# slot_index 0 (left/A) is always the leading slot, 1 (right/B) the following
	# one; GameState.is_duo_leader reads this same slot order back from
	# _sync_party_from_slots's [a, b] array, so this tag always matches what battle
	# will actually do. Shown on the SLOT itself (even empty), not derived from
	# which hero ends up there — labeling the slot up front is the whole point:
	# the player sees the assignment before they drag.
	#
	# Labelled FRONT/BACK rather than LEADER/FOLLOWER (Designer, 2026-07-30): that
	# is literally where the two heroes deploy and stand — the leader spawns to the
	# right, toward the villain, the follower behind them (DeployController.
	# _positions_for_group) — so the tag now names the thing the player can see.
	var is_leader_slot := slot_index == 0
	# Filled slots take the tint of that hero's ABILITY (Designer, 2026-07-26) —
	# the same colour its cooldown bar will run in battle, so the pairing screen
	# and the battle HUD agree on what each hero looks like. Empty ones are a
	# faint dashed-looking outline so the drop target reads as "not drawn in yet".
	var style := (UIStyle.panel(
					Color(UIStyle.ability_color(Hero.ability_name_for(hero_name)), 0.45),
					color, 3, 6, slot_index)
			if hero_name != ""
			else UIStyle.panel(Color(UIStyle.PAGE_SOLID, 0.35), Color(color, 0.4), 2, 6, slot_index))
	slot.add_theme_stylebox_override("panel", style)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var tag_row := CenterContainer.new()
	tag_row.add_child(UIStyle.label("FRONT" if is_leader_slot else "BACK",
			UIStyle.SIZE_TINY, UIStyle.INK if is_leader_slot else UIStyle.INK_MUTED))
	col.add_child(tag_row)

	# A filled slot shows the hero's own sprite next to their name (Designer,
	# 2026-07-26) — the same drawing the roster card above and the battle card
	# use, so the player drags a picture and gets that picture back. Unflipped,
	# matching the roster card: the battle card's mirror is about which way the
	# hero faces on the field, which this screen doesn't depict.
	var center := CenterContainer.new()
	if hero_name != "":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		row.add_child(UIStyle.hero_portrait(hero_name, PORTRAIT_SIZE))
		var name_label := UIStyle.label(hero_name, UIStyle.SIZE_SMALL)
		name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(name_label)
		center.add_child(row)
	else:
		center.add_child(UIStyle.label("drag hero here", UIStyle.SIZE_SMALL, UIStyle.INK_MUTED))
	col.add_child(center)

	slot.add_child(col)

	return slot

## Places `hero_name` into the target slot, first clearing it from wherever
## it currently sits (drag-to-reassign, not swap — the vacated slot just goes
## empty).
func _on_slot_drop(hero_name: String, duo_index: int, slot_index: int) -> void:
	if hero_name not in RunState.draft_offer:
		return
	for i in _pairing_slots.size():
		if _pairing_slots[i] == hero_name:
			_pairing_slots[i] = ""
	_pairing_slots[duo_index * 2 + slot_index] = hero_name
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

func _on_slot_clear(duo_index: int, slot_index: int) -> void:
	_pairing_slots[duo_index * 2 + slot_index] = ""
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

## Single source of truth: reads _pairing_slots, decides which heroes are
## actually deploying (only those in a *fully-filled* Duo — a lone hero in an
## otherwise-empty Duo isn't fielded, it's mid-pairing), and pushes that both
## to RunState.party (drives the run/deploy/results) and GameState.duo_pairings
## (persistent Duo identity, read by battle for synergy/ultimate/behavior).
func _sync_party_from_slots() -> void:
	var duos: Array = []
	var roster: Array = []
	for d in range(2):
		var a: String = _pairing_slots[d * 2]
		var b: String = _pairing_slots[d * 2 + 1]
		if a != "" and b != "":
			duos.append([a, b])
			roster.append(a)
			roster.append(b)
	RunState.party = roster
	GameState.set_duo_pairings(duos)

## NOTE: the CLEAR PAIRING button that called this was removed on 2026-07-30 —
## clicking a filled slot clears it (DuoSlot._gui_input -> _on_slot_clear), which
## is the same job one slot at a time. Kept as the one call that empties ALL four
## at once, for whatever next needs it.
func _on_reset_pairing() -> void:
	_pairing_slots = ["", "", "", ""]
	_sync_party_from_slots()
	_rebuild_pairing_panel()
	_refresh()

## The HERO DETAILS button every roster card carries (Designer, 2026-07-30).
##
## The attributes, kit line, role blurb and lifetime totals that used to be
## printed on the card itself now live behind it (HeroDetailsPanel) — the card is
## the thing you DRAG, so it only needs to be recognisable; the numbers are what
## you read once while deciding, not every time you look at the row.
##
## Kept out of the drag gesture's way: a Button consumes its own clicks, so
## pressing DETAILS never starts a drag, and dragging from anywhere else on the
## card still works.
func _build_details_row(hero_name: String) -> CenterContainer:
	var center := CenterContainer.new()
	center.add_child(UIStyle.compact_button("HERO DETAILS", UIStyle.SIZE_TINY,
			_open_hero_details.bind(hero_name), hero_name.length()))
	return center

## Self-parenting overlay, same contract as Settings and How To Play — it draws
## over the prep screen and frees itself, so there is nothing to hide or restore
## here. Pressing DETAILS on another card while it is open switches the page to
## that hero (see HeroDetailsPanel.open).
func _open_hero_details(hero_name: String) -> void:
	HeroDetailsPanel.open(self, hero_name)

func _build_hero_card(hero_name: String) -> PanelContainer:
	var offered := RunState.is_offered(hero_name)
	var card := DraggableHeroCard.new()
	card.hero_name = hero_name
	card.swatch_color = GameState.HERO_CATALOG[hero_name].color
	card.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 16, hero_name.length()))
	if not offered:
		card.modulate = UIStyle.DIM

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# The hero's real battlefield sprite, not a colour swatch — the roster and
	# the field now show literally the same drawing (UIStyle.hero_portrait).
	box.add_child(UIStyle.hero_portrait(hero_name, Vector2(110, 78)))

	box.add_child(UIStyle.centered_label(hero_name, UIStyle.SIZE_SUBHEAD))
	box.add_child(_build_kit_label(hero_name))
	box.add_child(_build_details_row(hero_name))

	return card

## "RANGED · CLONE" — how the hero fights and what their natural ability is
## (Designer, 2026-07-26; restored to the card 2026-07-30 after a round without
## it). It is the one line worth reading while you drag, which is why the STATS
## block that used to sit under it stayed behind the HERO DETAILS button and this
## did not.
##
## Coloured with that hero's ABILITY colour, the same one their filled Duo slot
## takes below, their details page takes, and their cooldown bar takes in battle
## — one hero, one colour, from the roster card into the fight.
func _build_kit_label(hero_name: String) -> Label:
	var ability := Hero.ability_name_for(hero_name)
	return UIStyle.centered_label("%s  ·  %s" % [Hero.attack_mode_for(hero_name), ability],
			UIStyle.SIZE_SMALL, UIStyle.ability_color(ability))

## NOTE: _build_stats_block and its two text builders (the effective-stat line
## and the lifetime KILLS/XP line) were removed from the card on 2026-07-30 —
## they moved, unchanged in substance, into HeroDetailsPanel behind the card's
## HERO DETAILS button; the effective-stat formula in particular now lives in
## HeroDetailsPanel._attributes_block.
##
## Card for a not-yet-unlocked hero: shows the achievement gating it (name +
## live career progress) instead of the draft/priority controls. Locked heroes
## already fall out of the draft automatically (RunState.roll_draft_offer reads
## GameState.unlocked_heroes) — this card is purely informational.
func _build_locked_hero_card(hero_name: String) -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UIStyle.card(UIStyle.INK, 16, hero_name.length()))
	card.modulate = UIStyle.DIM

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# Same portrait treatment as an unlocked card — the card-wide DIM modulate
	# above is what reads as "locked", so the silhouette still teases the art.
	box.add_child(UIStyle.hero_portrait(hero_name, Vector2(110, 78)))

	box.add_child(UIStyle.centered_label("%s — LOCKED" % hero_name, UIStyle.SIZE_BODY))
	box.add_child(_build_kit_label(hero_name))
	# Same DETAILS button an unlocked card gets: what a locked hero would bring is
	# exactly the thing worth knowing before chasing their achievement.
	box.add_child(_build_details_row(hero_name))

	var ach_id := Achievements.for_hero(hero_name)
	if ach_id != "":
		var d := Achievements.def(ach_id)
		box.add_child(UIStyle.centered_label(d.get("name", ach_id), UIStyle.SIZE_SMALL, UIStyle.GOLD))
		box.add_child(UIStyle.numeric_label(_achievement_progress_text(d), UIStyle.SIZE_TINY, UIStyle.INK, true))
	return card

## "84/150 minions" style progress line for a locked hero's achievement.
func _achievement_progress_text(d: Dictionary) -> String:
	var stat: String = d.get("stat", "")
	var threshold = d.get("threshold", 0)
	var current = GameState.career.get(stat, 0)
	if stat == "best_villain_damage_pct":
		return "%d%% / %d%% villain damage" % [int(float(current) * 100.0), int(float(threshold) * 100.0)]
	return "%d / %d %s" % [int(current), int(threshold), stat.replace("_", " ")]

## Settings is a self-parenting overlay (SettingsPanel.open adds itself to the
## scene root), so unlike the ABILITIES/STATS pages it doesn't hide _main or
## need a close handler here — it draws over the prep screen and frees itself.
func _open_settings() -> void:
	SettingsPanel.toggle(self)

## Same self-parenting overlay contract as Settings — see above.
func _open_how_to_play() -> void:
	HowToPlayPanel.toggle(self)

## Escape opens Settings, matching the title screen. Not wired to BACK TO MENU:
## Escape reaching for "leave the screen" while a player is mid-pairing would
## be the one destructive reading of the key.
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_open_settings()

func _open_abilities() -> void:
	_main.visible = false
	_abilities_page = AbilitiesPage.new()
	_abilities_page.closed.connect(_close_abilities)
	add_child(_abilities_page)

func _close_abilities() -> void:
	_abilities_page.queue_free()
	_abilities_page = null
	_main.visible = true
	_refresh()

func _open_stats() -> void:
	_main.visible = false
	_stats_page = StatsPage.new()
	_stats_page.closed.connect(_close_stats)
	add_child(_stats_page)

func _close_stats() -> void:
	_stats_page.queue_free()
	_stats_page = null
	_main.visible = true
	_rebuild_hero_row()  # banked XP may have changed — refresh the card display
	_refresh()

## -- Tutorial tour (Designer, 2026-07-31) -------------------------------------
##
## "Lets have the UI show to the player as we are explaining, so there isnt too
## much on the screen at first": the page builds in full, then everything below
## the header is hidden and revealed one section at a time, each with its own
## popup. The reveal order is the order a player will actually use them —
## who you have, what you can spend on them, then the pairing that gates START.
##
## Each step reveals its section BEFORE the popup opens, so the spotlight has
## something to land on (TutorialDirector re-measures every frame, which is what
## makes revealing and spotlighting in the same frame safe).
##
## Nothing here is bought: this is a tour, not a shopping trip (Designer). The
## one interactive step is the pairing, because START RUN is gated on it and the
## player would otherwise meet that gate with no explanation.
func _run_tutorial_tour() -> void:
	for section in [_hero_row, _gold_column, _xp_column, _pairing_section,
			_start_button, _back_button]:
		if section != null:
			section.visible = false
	_tour_heroes()

func _tour_heroes() -> void:
	_hero_row.visible = true
	TutorialDirector.run(self, [
		{
			"title": "YOUR HEROES",
			"body": "These are your heroes. Click on their details to learn more.",
			"focus": _hero_row,
		},
	], _tour_abilities)

func _tour_abilities() -> void:
	_gold_column.visible = true
	TutorialDirector.run(self, [
		{
			"title": "ABILITY UPGRADES",
			"body": "GOLD is earned by fighting, and spent here on permanent ability "
				+ "upgrades for your heroes.",
			"focus": _gold_column,
		},
	], _tour_stats)

func _tour_stats() -> void:
	_xp_column.visible = true
	TutorialDirector.run(self, [
		{
			"title": "STAT UPGRADES",
			"body": "XP is banked from every kill, shared across heroes, and spent "
				+ "here on permanent stats.",
			"focus": _xp_column,
		},
	], _tour_pairing)

func _tour_pairing() -> void:
	_pairing_section.visible = true
	_start_button.visible = true
	_back_button.visible = true
	TutorialDirector.run(self, [
		{
			"title": "BUILD YOUR DUOS",
			"body": "Thundaar and Artemis are already paired. Drag WARDEN and BEACON "
				+ "into the second DUO — every pair unlocks its own ULTIMATE, so who "
				+ "you put together decides what you can unleash.",
			"focus": _pairing_section,
		},
		{
			"title": "THEN START THE RUN",
			"body": "START RUN lights up once both DUOs are filled. Good luck.",
			"focus": _start_button,
		},
	])

func _on_back_to_menu() -> void:
	get_tree().change_scene_to_file(GameState.TITLE_SCREEN)

func _on_start() -> void:
	# Closing the tutorial: from here on this is a normal prep screen, and the
	# battle about to load owes the player only the two-lane explanation
	# (Tutorial.consume_two_lane_hint, read by BattleManager).
	if Tutorial.phase == Tutorial.Phase.PREP:
		Tutorial.complete()
	RunState.start_run()
	GameState.save_game()
	get_tree().change_scene_to_file(GameState.BATTLEFIELD)

func _refresh() -> void:
	# A run takes BOTH Duos (Designer, 2026-07-29: "new runs are allowing players
	# to deploy with only one DUO setup"). The old test was "party isn't empty",
	# which one filled Duo satisfies — the whole battle is built around two Duos
	# (staggered arrival waves, per-Duo Ultimates and refocus, the start-of-level
	# reshuffle, which all key off exactly two pairings), so launching with one
	# leaves half those systems with nothing to act on.
	_start_button.disabled = not _both_duos_ready()
	_start_button.modulate = UIStyle.DIM if _start_button.disabled else Color.WHITE
	if _currency_label != null:
		UIStyle.set_numeric_text(_currency_label, "GOLD: %d" % GameState.gold)
	if _xp_label != null:
		UIStyle.set_numeric_text(_xp_label, "BANKED XP: %d" % GameState.banked_xp)

func _label(text: String, font_size: int) -> Label:
	return UIStyle.label(text, font_size)

func _button(text: String, font_size: int, cb: Callable) -> Button:
	return UIStyle.button(text, font_size, cb)

## AtlasTexture crop of `texture` at `region`, scaled to a normal button size
## (see START_RUN_TEXTURE/START_RUN_REGION doc).
func _texture_button(texture: Texture2D, region: Rect2, cb: Callable) -> TextureButton:
	return UIStyle.texture_button(texture, region, START_RUN_WIDTH, cb)

class_name LineupSlot
extends PanelContainer

signal player_dropped(slot_index: int, player: Player)
## Emitted on click when select_mode is enabled (used by the live match
## Substitute panel to pick the outgoing player instead of drag-drop).
signal slot_selected(slot_index: int)

const CATEGORY_NAMES := {
	Formation.SlotCategory.GK: "GK",
	Formation.SlotCategory.DEF: "DEF",
	Formation.SlotCategory.MID: "MID",
	Formation.SlotCategory.FWD: "FWD",
}

var slot_index: int = -1
var category: Formation.SlotCategory = Formation.SlotCategory.GK
var player: Player = null
## When true, clicking selects the slot (emits slot_selected) instead of
## acting as a drag source — used by the live match Substitute panel.
var select_mode: bool = false
var selected: bool = false
## Overrides the displayed condition (live in-match value instead of
## Player.persistent_condition) — used by the live match Substitute panel.
var condition_override: float = -1.0
## When > 0, shows this queue position (e.g. "#1") — used by the live match
## Substitute panel to number queued-but-unconfirmed substitution pairs.
var queue_number: int = 0

var _label: Label
var _condition_label: Label

func _ready() -> void:
	custom_minimum_size = Vector2(150, 64)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 0)
	add_child(vbox)
	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_label)
	_condition_label = Label.new()
	_condition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_condition_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_condition_label)
	_refresh()

func set_slot(index: int, p_category: Formation.SlotCategory) -> void:
	slot_index = index
	category = p_category
	_refresh()

func set_player(p_player: Player) -> void:
	player = p_player
	_refresh()

func set_condition_override(value: float) -> void:
	condition_override = value
	_refresh()

func set_selected(value: bool) -> void:
	selected = value
	_refresh()

func set_queue_number(value: int) -> void:
	queue_number = value
	_refresh()

func _refresh() -> void:
	if _label == null:
		return
	var category_name: String = CATEGORY_NAMES.get(category, "?")
	if player:
		var multiplier: float = PositionCompatibility.get_best_multiplier(player, category)
		var queue_prefix: String = "#%d " % queue_number if queue_number > 0 else ""
		_label.text = "%s%s\n%s (x%.2f)" % [queue_prefix, category_name, player.player_name, multiplier]
		if multiplier >= 0.95:
			modulate = Color(0.75, 1.0, 0.75)
		elif multiplier >= 0.6:
			modulate = Color(1.0, 0.9, 0.6)
		else:
			modulate = Color(1.0, 0.65, 0.65)
		var condition: float = condition_override if condition_override >= 0.0 else player.persistent_condition
		_condition_label.text = "COND %.0f%%" % condition
		_condition_label.add_theme_color_override("font_color", _condition_color(condition))
	else:
		_label.text = "%s\nEmpty" % category_name
		modulate = Color(1, 1, 1)
		_condition_label.text = ""
	if queue_number > 0:
		add_theme_stylebox_override("panel", _queued_stylebox())
	elif selected:
		add_theme_stylebox_override("panel", _selected_stylebox())
	else:
		remove_theme_stylebox_override("panel")

func _selected_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.25, 0.45, 0.85, 0.5)
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Color(0.4, 0.7, 1.0)
	return box

func _queued_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.85, 0.55, 0.15, 0.5)
	box.border_width_left = 3
	box.border_width_top = 3
	box.border_width_right = 3
	box.border_width_bottom = 3
	box.border_color = Color(1.0, 0.7, 0.3)
	return box

func _gui_input(event: InputEvent) -> void:
	if not select_mode or player == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_selected.emit(slot_index)

static func _condition_color(condition: float) -> Color:
	if condition >= 70.0:
		return Color(0.55, 0.9, 0.55)
	elif condition >= 40.0:
		return Color(1.0, 0.85, 0.4)
	else:
		return Color(1.0, 0.5, 0.5)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if select_mode or player == null:
		return null
	var preview := Label.new()
	preview.text = player.player_name
	set_drag_preview(preview)
	return {"player": player, "source_slot": slot_index}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Designer decision: any player can be placed in any slot (off-position
	# penalties are shown via the multiplier/color cue, not enforced as a gate).
	return not select_mode and typeof(data) == TYPE_DICTIONARY and data.has("player")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	player_dropped.emit(slot_index, data["player"])

class_name PlayerChip
extends PanelContainer

## Bench card. Draggable onto lineup slots; also a valid drop target itself
## so dropping a lineup player back onto any bench card (not just empty
## bench space) returns that player to the bench.
signal player_returned(source_slot: int)
## Emitted on click when select_mode is enabled (used by the live match
## Substitute panel to pick the incoming player instead of drag-drop).
signal chip_selected(player: Player)

const POSITION_NAMES := {
	Player.Position.GK: "GK",
	Player.Position.CB: "CB",
	Player.Position.FB: "FB",
	Player.Position.DM: "DM",
	Player.Position.CM: "CM",
	Player.Position.CAM: "CAM",
	Player.Position.WING: "WING",
	Player.Position.ST: "ST",
}

var player: Player = null
## When true, clicking selects the chip (emits chip_selected) instead of
## acting as a drag source — used by the live match Substitute panel.
var select_mode: bool = false
var selected: bool = false
## Overrides the displayed condition (live in-match value instead of
## Player.persistent_condition) — used by the live match Substitute panel.
var condition_override: float = -1.0
## When set, shows this slot category's compatibility multiplier for the
## player — used by the live match Substitute panel to preview a sub target.
var compat_category = null
## When > 0, shows this queue position (e.g. "#1") — used by the live match
## Substitute panel to number queued-but-unconfirmed substitution pairs.
var queue_number: int = 0

func _ready() -> void:
	custom_minimum_size = Vector2(210, 72)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	add_child(vbox)

	var name_row := HBoxContainer.new()
	vbox.add_child(name_row)

	var name_label := Label.new()
	name_label.text = "#%d %s" % [queue_number, player.player_name] if queue_number > 0 else player.player_name
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.size_flags_horizontal = SIZE_EXPAND_FILL
	name_row.add_child(name_label)

	var overall_label := Label.new()
	overall_label.text = "OVR %.0f" % player.get_overall()
	overall_label.add_theme_font_size_override("font_size", 16)
	name_row.add_child(overall_label)

	var bottom_row := HBoxContainer.new()
	vbox.add_child(bottom_row)

	var position_text: String = _position_string(player.positions)
	if compat_category != null:
		var multiplier: float = PositionCompatibility.get_best_multiplier(player, compat_category)
		position_text += " (x%.2f)" % multiplier
	var position_label := Label.new()
	position_label.text = position_text
	position_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	position_label.size_flags_horizontal = SIZE_EXPAND_FILL
	bottom_row.add_child(position_label)

	var condition: float = condition_override if condition_override >= 0.0 else player.persistent_condition
	var condition_label := Label.new()
	condition_label.text = "COND %.0f%%" % condition
	condition_label.add_theme_font_size_override("font_size", 13)
	condition_label.add_theme_color_override("font_color", LineupSlot._condition_color(condition))
	bottom_row.add_child(condition_label)

	if queue_number > 0:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.85, 0.55, 0.15, 0.5)
		box.border_width_left = 3
		box.border_width_top = 3
		box.border_width_right = 3
		box.border_width_bottom = 3
		box.border_color = Color(1.0, 0.7, 0.3)
		add_theme_stylebox_override("panel", box)
	elif selected:
		var box := StyleBoxFlat.new()
		box.bg_color = Color(0.25, 0.45, 0.85, 0.5)
		box.border_width_left = 3
		box.border_width_top = 3
		box.border_width_right = 3
		box.border_width_bottom = 3
		box.border_color = Color(0.4, 0.7, 1.0)
		add_theme_stylebox_override("panel", box)

func _position_string(positions: Array) -> String:
	var names: Array[String] = []
	for position in positions:
		names.append(POSITION_NAMES.get(position, "?"))
	return "/".join(names)

func _gui_input(event: InputEvent) -> void:
	if not select_mode:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		chip_selected.emit(player)

func _get_drag_data(_at_position: Vector2) -> Variant:
	if select_mode:
		return null
	var preview := Label.new()
	preview.text = player.player_name
	set_drag_preview(preview)
	return {"player": player, "source_slot": -1}

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return not select_mode and typeof(data) == TYPE_DICTIONARY and data.has("source_slot") and data["source_slot"] != -1

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	player_returned.emit(data["source_slot"])

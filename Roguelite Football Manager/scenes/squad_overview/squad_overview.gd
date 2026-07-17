extends Control

@onready var title_label: Label = $MarginContainer/VBoxContainer/TitleLabel
@onready var list_container: VBoxContainer = $MarginContainer/VBoxContainer/ScrollContainer/ListContainer
@onready var new_club_button: Button = $MarginContainer/VBoxContainer/NewClubButton

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

const COLUMN_WIDTHS := [420, 200, 120, 120, 120, 120, 120, 120]

func _ready() -> void:
	new_club_button.pressed.connect(_on_back_pressed)
	if GameState.squad.is_empty():
		GameState.generate_squad()
	_populate()

func _populate() -> void:
	var club := GameState.club
	if club:
		title_label.text = "%s FC — Squad (%d players)" % [club.club_name, GameState.squad.size()]
	list_container.add_child(_build_row(
		["Name", "Position", "SPD", "STR", "KCK", "PAS", "STA", "OVR"], true
	))
	for player in GameState.squad:
		list_container.add_child(_build_row([
			player.player_name,
			_position_string(player.positions),
			str(player.speed),
			str(player.strength),
			str(player.kick),
			str(player.passing),
			str(player.stamina),
			"%.0f" % player.get_overall(),
		], false))

func _build_row(cells: Array, is_header: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	for i in range(cells.size()):
		var label := Label.new()
		label.text = str(cells[i])
		label.custom_minimum_size = Vector2(COLUMN_WIDTHS[i], 0)
		if is_header:
			label.add_theme_color_override("font_color", Color.GRAY)
		row.add_child(label)
	return row

func _position_string(player_positions: Array) -> String:
	var names: Array[String] = []
	for player_position in player_positions:
		names.append(POSITION_NAMES.get(player_position, "?"))
	return "/".join(names)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

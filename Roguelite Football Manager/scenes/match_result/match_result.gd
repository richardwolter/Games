extends Control

@onready var score_label: Label = $MarginContainer/VBoxContainer/ScoreLabel
@onready var continue_button: Button = $MarginContainer/VBoxContainer/ContinueButton

func _ready() -> void:
	continue_button.pressed.connect(_on_continue_pressed)
	var result: MatchResult = GameState.last_match_result
	if result == null:
		score_label.text = "No match played."
		return
	score_label.text = "%s %d - %d %s" % [result.home_name, result.home_score, result.away_score, result.away_name]
	_build_stats_table(result)

## Milestone 20: possession/shots/xG table under the score, built in code so
## no .tscn change is needed. Columns: home value | stat name | away value.
func _build_stats_table(result: MatchResult) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	_add_stat_row(grid, result.home_name, "", result.away_name, true)
	_add_stat_row(grid, "%d%%" % result.home_possession, "Possession", "%d%%" % result.away_possession, false)
	_add_stat_row(grid, str(result.home_shots), "Shots", str(result.away_shots), false)
	_add_stat_row(grid, str(result.home_shots_on_target), "On Target", str(result.away_shots_on_target), false)
	_add_stat_row(grid, "%.2f" % result.home_xg, "xG", "%.2f" % result.away_xg, false)

	## Insert the table between the score and the Continue button.
	score_label.add_sibling(grid)

func _add_stat_row(grid: GridContainer, home_text: String, stat_name: String, away_text: String, is_header: bool) -> void:
	var home_label := Label.new()
	home_label.text = home_text
	home_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	home_label.custom_minimum_size = Vector2(120, 0)

	var name_label := Label.new()
	name_label.text = stat_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.custom_minimum_size = Vector2(160, 0)

	var away_label := Label.new()
	away_label.text = away_text
	away_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	away_label.custom_minimum_size = Vector2(120, 0)

	if is_header:
		for label in [home_label, name_label, away_label]:
			label.add_theme_font_size_override("font_size", 20)

	grid.add_child(home_label)
	grid.add_child(name_label)
	grid.add_child(away_label)

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

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

func _on_continue_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

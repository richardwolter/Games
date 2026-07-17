extends Control

@onready var new_game_button: Button = $MarginContainer/VBoxContainer/NewGameButton
@onready var load_game_button: Button = $MarginContainer/VBoxContainer/LoadGameButton
@onready var close_button: Button = $MarginContainer/VBoxContainer/CloseButton

func _ready() -> void:
	new_game_button.pressed.connect(_on_new_game_pressed)
	load_game_button.pressed.connect(_on_load_game_pressed)
	close_button.pressed.connect(_on_close_pressed)
	load_game_button.disabled = not SaveManager.has_save()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_creation/club_creation.tscn")

func _on_load_game_pressed() -> void:
	if SaveManager.load_game():
		get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

func _on_close_pressed() -> void:
	get_tree().quit()

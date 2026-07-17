extends Control

@onready var title_label: Label = $MarginContainer/VBoxContainer/HeaderRow/TitleLabel
@onready var badge_preview: Control = $MarginContainer/VBoxContainer/HeaderRow/BadgePreview
@onready var squad_button: Button = $MarginContainer/VBoxContainer/SquadOverviewButton
@onready var pre_match_button: Button = $MarginContainer/VBoxContainer/PreMatchSetupButton
@onready var new_club_button: Button = $MarginContainer/VBoxContainer/NewClubButton

func _ready() -> void:
	squad_button.pressed.connect(_on_squad_overview_pressed)
	pre_match_button.pressed.connect(_on_pre_match_setup_pressed)
	new_club_button.pressed.connect(_on_new_club_pressed)
	_populate()

func _populate() -> void:
	var club := GameState.club
	if club == null:
		title_label.text = "No Club"
		return
	title_label.text = "%s FC" % club.club_name
	var initials := _get_initials(club.club_name)
	badge_preview.set_badge(club.primary_color, club.secondary_color, club.badge_shape, initials)

func _get_initials(club_name: String) -> String:
	var trimmed := club_name.strip_edges()
	if trimmed == "":
		return ""
	var words := trimmed.split(" ", false)
	var initials := ""
	for word in words:
		initials += word[0].to_upper()
		if initials.length() >= 3:
			break
	return initials

func _on_squad_overview_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/squad_overview/squad_overview.tscn")

func _on_pre_match_setup_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/pre_match_setup/pre_match_setup.tscn")

func _on_new_club_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/club_creation/club_creation.tscn")

extends Control

@onready var name_edit: LineEdit = $MarginContainer/VBoxContainer/NameRow/NameEdit
@onready var primary_picker: ColorPickerButton = $MarginContainer/VBoxContainer/ColorsRow/PrimaryColumn/PrimaryPicker
@onready var secondary_picker: ColorPickerButton = $MarginContainer/VBoxContainer/ColorsRow/SecondaryColumn/SecondaryPicker
@onready var badge_preview: Control = $MarginContainer/VBoxContainer/BadgeRow/BadgePreview
@onready var reroll_button: Button = $MarginContainer/VBoxContainer/BadgeRow/RerollButton
@onready var create_button: Button = $MarginContainer/VBoxContainer/CreateButton
@onready var status_label: Label = $MarginContainer/VBoxContainer/StatusLabel

var _badge_shape: ClubData.BadgeShape = ClubData.BadgeShape.SHIELD

func _ready() -> void:
	name_edit.text_changed.connect(_on_inputs_changed)
	primary_picker.color_changed.connect(_on_inputs_changed)
	secondary_picker.color_changed.connect(_on_inputs_changed)
	reroll_button.pressed.connect(_on_reroll_pressed)
	create_button.pressed.connect(_on_create_pressed)
	_refresh_badge()

func _on_inputs_changed(_value = null) -> void:
	_refresh_badge()

func _on_reroll_pressed() -> void:
	var shape_count: int = ClubData.BadgeShape.size()
	_badge_shape = ((_badge_shape + 1) % shape_count) as ClubData.BadgeShape
	_refresh_badge()

func _refresh_badge() -> void:
	var initials := _get_initials(name_edit.text)
	badge_preview.set_badge(primary_picker.color, secondary_picker.color, _badge_shape, initials)

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

func _on_create_pressed() -> void:
	var club_name := name_edit.text.strip_edges()
	if club_name == "":
		status_label.text = "Enter a club name first."
		return
	var club := GameState.create_club(club_name, primary_picker.color, secondary_picker.color, _badge_shape)
	status_label.text = "%s FC created! Starting in the 4th Division." % club.club_name
	GameState.generate_squad()
	get_tree().change_scene_to_file("res://scenes/club_management/club_management.tscn")

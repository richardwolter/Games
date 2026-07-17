extends CanvasLayer

@onready var menu_button: Button = $MenuButton
@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/VBoxContainer/SaveButton
@onready var close_button: Button = $Panel/VBoxContainer/CloseButton
@onready var status_label: Label = $Panel/VBoxContainer/StatusLabel
@onready var status_timer: Timer = $StatusTimer

func _ready() -> void:
	layer = 100
	panel.hide()
	status_label.hide()
	menu_button.pressed.connect(_on_menu_pressed)
	resume_button.pressed.connect(_on_resume_pressed)
	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(_on_close_pressed)
	status_timer.timeout.connect(_on_status_timeout)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_toggle_panel()
		get_viewport().set_input_as_handled()

func _toggle_panel() -> void:
	panel.visible = not panel.visible

func _on_menu_pressed() -> void:
	_toggle_panel()

func _on_resume_pressed() -> void:
	panel.hide()

func _on_save_pressed() -> void:
	SaveManager.save_game()
	status_label.text = "Game saved."
	status_label.show()
	status_timer.start()

func _on_close_pressed() -> void:
	get_tree().quit()

func _on_status_timeout() -> void:
	status_label.hide()

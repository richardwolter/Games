class_name GameHUD
extends CanvasLayer

@onready var battery_bar: ProgressBar = $Margin/VBox/BatteryBar
@onready var battery_label: Label = $Margin/VBox/BatteryBar/BatteryLabel
@onready var speed_label: Label = $Margin/VBox/SpeedLabel
@onready var timer_label: Label = $Margin/VBox/TimerLabel
@onready var checkpoint_label: Label = $Margin/VBox/CheckpointLabel
@onready var charging_prompt: Label = $Margin/VBox/ChargingPrompt
@onready var low_battery_warning: ColorRect = $LowBatteryWarning
@onready var results_panel: Panel = $ResultsPanel
@onready var results_label: Label = $ResultsPanel/VBox/ResultsLabel
@onready var restart_hint: Label = $ResultsPanel/VBox/RestartHint

var _warning_tween: Tween = null

func _ready() -> void:
	TrackState.battery_changed.connect(_on_battery_changed)
	TrackState.battery_critical.connect(_on_battery_critical)
	TrackState.speed_changed.connect(_on_speed_changed)
	TrackState.charging_started.connect(_on_charging_started)
	TrackState.charging_completed.connect(_on_charging_completed)
	TrackState.checkpoint_reached.connect(_on_checkpoint_reached)
	TrackState.course_finished.connect(_on_course_finished)

	charging_prompt.visible = false
	low_battery_warning.visible = false
	results_panel.visible = false

	_on_battery_changed(TrackState.battery_percent)
	_update_checkpoint_label()

func _process(_delta: float) -> void:
	var remaining := maxf(TrackState.time_limit - TrackState.time_elapsed, 0.0)
	timer_label.text = "Time Left: %.1fs" % remaining
	if remaining <= 5.0 and not TrackState.course_complete:
		timer_label.modulate = Color(1.0, 0.3, 0.3)
	else:
		timer_label.modulate = Color(1, 1, 1)

func _on_battery_changed(percent: float) -> void:
	battery_bar.value = percent
	battery_label.text = "%d%%" % int(percent)

	if percent > 50.0:
		battery_bar.modulate = Color(0.3, 1.0, 0.4)
	elif percent > 20.0:
		battery_bar.modulate = Color(1.0, 0.85, 0.2)
	else:
		battery_bar.modulate = Color(1.0, 0.3, 0.3)

func _on_battery_critical() -> void:
	low_battery_warning.visible = true
	if _warning_tween:
		_warning_tween.kill()
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(low_battery_warning, "modulate:a", 0.5, 0.4)
	_warning_tween.tween_property(low_battery_warning, "modulate:a", 0.0, 0.4)

func _on_speed_changed(mps: float) -> void:
	speed_label.text = "Speed: %d" % int(mps)

func _on_charging_started(_station_id: String) -> void:
	charging_prompt.visible = true
	charging_prompt.text = "Charging..."

func _on_charging_completed() -> void:
	charging_prompt.visible = false
	if _warning_tween and TrackState.battery_percent > 20.0:
		_warning_tween.kill()
		low_battery_warning.visible = false

func _on_checkpoint_reached(_index: int) -> void:
	_update_checkpoint_label()

func _update_checkpoint_label() -> void:
	checkpoint_label.text = "Checkpoints: %d/%d" % [TrackState.checkpoints_passed, TrackState.total_checkpoints]

func _on_course_finished(success: bool, time_elapsed: float, distance: float, stars: int) -> void:
	results_panel.visible = true
	if success:
		results_label.text = "Course Complete!\n%s\nTime: %.1fs\nSpark +%d" % [
			_star_string(stars), time_elapsed, TrackState.last_spark_awarded
		]
	else:
		results_label.text = "Time's Up!\nTry Again"
	restart_hint.text = "Press ESC to restart"

func _star_string(stars: int) -> String:
	var s := ""
	for i in range(3):
		s += "★" if i < stars else "☆"
	return s

class_name BattleHUD
extends CanvasLayer
## Displays live battle state: villain HP, hero panels, objective progress, farm XP.

@export var villain_hp_label_path: NodePath = "VillainHPLabel"
@export var villain_hp_bar_path: NodePath = "VillainHPBar"
@export var hero_panels_root_path: NodePath = "HeroPanelsRoot"
@export var objective_label_path: NodePath = "ObjectiveLabel"
@export var objective_bar_path: NodePath = "ObjectiveBar"
@export var run_xp_label_path: NodePath = "RunXPLabel"
@export var timer_label_path: NodePath = "TimerPanel/TimerLabel"
@export var buff_panel_path: NodePath = "ObjectiveBuffPanel"
@export var buff_label_path: NodePath = "ObjectiveBuffPanel/BuffLabel"
@export var back_button_path: NodePath = "BackButton"

const PREP_MENU := "res://scenes/prep/prep_menu.tscn"

var hero_panel_scene: PackedScene

var _villain_hp_label: Label
var _villain_hp_bar: ProgressBar
var _villain: Node
var _villain_seen := false
var _hero_panels_root: Node
var _objective_label: Label
var _objective_bar: ProgressBar
var _run_xp_label: Label
var _timer_label: Label
var _elapsed := 0.0
var _hero_panels: Dictionary = {}  # hero_name -> panel_node

var _buff_panel: Control
var _buff_label: Label
## Countdown driving the objective-buff banner; independent of the actual
## hero buff timers (which can be refreshed/stacked across heroes), so it
## always reflects the single reward just granted.
var _buff_text := ""
var _buff_color := Color.WHITE
var _buff_t := 0.0
var _buff_duration := 0.0

func _ready() -> void:
	_villain_hp_label = get_node(villain_hp_label_path)
	_villain_hp_bar = get_node(villain_hp_bar_path)
	_hero_panels_root = get_node(hero_panels_root_path)
	_objective_label = get_node(objective_label_path)
	_objective_bar = get_node(objective_bar_path)
	_run_xp_label = get_node(run_xp_label_path)
	_timer_label = get_node(timer_label_path)
	_buff_panel = get_node(buff_panel_path)
	_buff_label = get_node(buff_label_path)
	get_node(back_button_path).pressed.connect(_on_back_pressed)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(PREP_MENU)

func _process(delta: float) -> void:
	_update_villain_hp()
	_update_run_xp()
	_update_objective()
	_update_hero_panels()
	_update_timer(delta)
	_update_objective_buff(delta)

## Shows the objective-completion reward banner with a live countdown.
## `duration` <= 0 means an instant/permanent grant (e.g. the shield charges)
## shown briefly rather than counted down.
func show_objective_buff(text: String, color: Color, duration: float) -> void:
	_buff_text = text
	_buff_color = color
	_buff_duration = maxf(duration, 2.0)
	_buff_t = _buff_duration
	_buff_panel.visible = true
	_update_objective_buff(0.0)

func _update_objective_buff(delta: float) -> void:
	if _buff_t <= 0.0:
		return
	_buff_t = maxf(_buff_t - delta, 0.0)
	var secs := int(ceil(_buff_t))
	_buff_label.text = "BUFF: %s  %d:%02d" % [_buff_text, secs / 60, secs % 60]
	_buff_label.modulate = _buff_color
	if _buff_t <= 0.0:
		_buff_panel.visible = false

func setup_heroes(hero_names: PackedStringArray) -> void:
	for hero_name in hero_names:
		var panel = hero_panel_scene.instantiate()
		panel.hero_name = hero_name
		panel.clicked.connect(_on_hero_panel_clicked)
		_hero_panels_root.add_child(panel)
		_hero_panels[hero_name] = panel

## Panel click: toggle the battle camera's follow lock onto that hero.
func _on_hero_panel_clicked(hero_name: String) -> void:
	var cam = get_tree().get_first_node_in_group("battle_camera")
	if cam == null:
		return
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero and h.hero_name == hero_name:
			cam.focus_on(h)
			return

func _update_villain_hp() -> void:
	if not is_instance_valid(_villain):
		_villain = null
		var villains = get_tree().get_nodes_in_group("villains")
		if not villains.is_empty():
			_villain = villains[0]
			_villain_seen = true

	if _villain == null:
		if _villain_seen:
			_villain_hp_label.text = "VILLAIN: DEFEATED"
			_villain_hp_bar.value = 0.0
		return

	var pct = int(round(100.0 * _villain.hp / _villain.max_hp))
	var villain_name = _villain.label_text if _villain.label_text != "" else "VILLAIN"
	_villain_hp_label.text = "%s HP: %d%%" % [villain_name, pct]
	_villain_hp_bar.value = float(_villain.hp) / _villain.max_hp

func _update_run_xp() -> void:
	var total = 0
	for x in GameState.run_xp.values():
		total += int(x)
	_run_xp_label.text = "XP: %d" % total

func _update_objective() -> void:
	var objs = get_tree().get_nodes_in_group("objectives")
	if objs.is_empty():
		_objective_label.text = ""
		return

	# Bar tracks whichever objective is furthest along, so progress on any
	# one of them is visible even while the other sits untouched.
	var lead = objs[0]
	for o in objs:
		if o.progress > lead.progress:
			lead = o
	_objective_bar.value = lead.progress

	var lines: Array[String] = []
	for i in objs.size():
		var o = objs[i]
		var tag := "OBJ %d" % (i + 1) if objs.size() > 1 else "OBJECTIVE"
		if o.is_captured:
			lines.append("%s: CAPTURED" % tag)
		elif o.contested:
			lines.append("%s: CONTESTED %d%%" % [tag, int(o.progress * 100.0)])
		else:
			lines.append("%s: %d%%" % [tag, int(o.progress * 100.0)])
	_objective_label.text = "\n".join(lines)

## Wall-clock time spent on the battlefield this run, MM:SS.
func _update_timer(delta: float) -> void:
	_elapsed += delta
	var total_seconds := int(_elapsed)
	_timer_label.text = "%02d:%02d" % [total_seconds / 60, total_seconds % 60]

func _update_hero_panels() -> void:
	var alive := {}
	for h in get_tree().get_nodes_in_group("heroes"):
		if h is Hero:
			alive[h.hero_name] = h

	# Followed hero (if any) so panels can mirror the camera lock, including
	# when the lock is broken camera-side (manual pan, hero death).
	var followed: Node2D = null
	var cam = get_tree().get_first_node_in_group("battle_camera")
	if cam != null:
		followed = cam.follow_target()

	for hero_name in _hero_panels:
		var panel = _hero_panels[hero_name]
		if hero_name in alive:
			var h = alive[hero_name]
			panel.update_display(hero_name, GameState.level_of(hero_name), h.hp, h.max_hp, h.ability_cooldown, h.ability_cooldown_max(), h.active_buffs())
			panel.set_focused(followed == h)
		else:
			panel.set_ko()
			panel.set_focused(false)

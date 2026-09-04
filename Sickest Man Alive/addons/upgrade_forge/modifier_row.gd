@tool
extends VBoxContainer

## One effect inside one upgrade level: "add 2 to pierce count on the syringe".
##
## The row owns the three dropdowns and whatever widget the chosen stat's TYPE
## calls for, and it can hand back a finished StatModifier. It is not allowed to
## produce an invalid one: the stat list is the game's own properties, the
## operation list is filtered by the stat's type, and the pipeline phase is
## derived rather than offered.

signal changed
signal removed

const Catalog := preload("res://addons/upgrade_forge/stat_catalog.gd")
const ModScript := preload("res://src/stat_modifier.gd")

var _target: OptionButton
var _stat: OptionButton
var _op: OptionButton
var _value_host: HBoxContainer
var _sentence: Label

var _value_widget: Control
## Second half of a status entry ("poison" + how much). Only ever built for the
## Dictionary stats.
var _potency: SpinBox


var _built: bool = false


func _ready() -> void:
	_ensure_built()


## Builds the row's widgets, on demand rather than only on _ready.
##
## The dock fills a level's rows in while the level's container is still being
## assembled and therefore not in the tree yet, so `_ready` has not run and every
## dropdown would still be null. Anything that touches a widget goes through here
## first.
func _ensure_built() -> void:
	if _built:
		return
	_built = true
	add_theme_constant_override("separation", 2)

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	add_child(line)

	_target = OptionButton.new()
	for i in Catalog.TARGET_LABELS.size():
		_target.add_item(Catalog.TARGET_LABELS[i], i)
	_target.item_selected.connect(func(_i: int) -> void: _rebuild_stats())
	line.add_child(_target)

	_stat = OptionButton.new()
	_stat.item_selected.connect(func(_i: int) -> void: _rebuild_ops())
	line.add_child(_stat)

	_op = OptionButton.new()
	_op.item_selected.connect(func(_i: int) -> void: _rebuild_value())
	line.add_child(_op)

	_value_host = HBoxContainer.new()
	line.add_child(_value_host)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(gap)

	var kill := Button.new()
	kill.text = "remove"
	kill.pressed.connect(func() -> void: removed.emit())
	line.add_child(kill)

	_sentence = Label.new()
	_sentence.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sentence.add_theme_color_override("font_color", Color(0.65, 0.72, 0.65))
	add_child(_sentence)

	_rebuild_stats()


## Fills in an existing modifier. Called after the row is in the tree, so all the
## dropdowns exist.
func load_modifier(mod: StatModifier) -> void:
	_ensure_built()
	_target.select(clampi(mod.target, 0, Catalog.TARGET_LABELS.size() - 1))
	_rebuild_stats()
	for i in _stat.item_count:
		if _stat.get_item_metadata(i) == mod.stat:
			_stat.select(i)
			break
	_rebuild_ops()
	for i in _op.item_count:
		if int(_op.get_item_metadata(i)) == mod.op:
			_op.select(i)
			break
	_rebuild_value()
	_apply_value(mod.value)
	_update_sentence()


## The modifier this row describes, or null when the row is not usable (a stat
## with no editor). `id` is filled in by the dock, which is the only thing that
## can see the whole table and therefore the only thing that can keep ids unique.
func to_modifier() -> StatModifier:
	_ensure_built()
	var stat := _selected_stat()
	if stat.is_empty() or _op.item_count == 0:
		return null
	var mod := StatModifier.new()
	mod.stat = stat["name"]
	mod.target = _target.get_selected_id()
	mod.op = int(_op.get_selected_metadata())
	mod.phase = Catalog.phase_for(mod.op)
	mod.value = _read_value()
	return mod


# --- dropdown plumbing ---

func _selected_stat() -> Dictionary:
	if _stat.item_count == 0 or _stat.selected < 0:
		return {}
	return Catalog.find_stat(_target.get_selected_id(), _stat.get_selected_metadata())


func _rebuild_stats() -> void:
	var previous: StringName = _stat.get_selected_metadata() if _stat.selected >= 0 else &""
	_stat.clear()
	for s in Catalog.stats_for_target(_target.get_selected_id()):
		var reason: String = Catalog.unsupported_reason(s)
		var text := String(s["name"]).replace("_", " ")
		if reason != "":
			# Kept visible rather than hidden: "why can I not touch the sprite?"
			# deserves an answer on screen.
			text += "  (%s)" % reason
		_stat.add_item(text)
		_stat.set_item_metadata(_stat.item_count - 1, s["name"])
		_stat.set_item_disabled(_stat.item_count - 1, reason != "")
		if s["name"] == previous:
			_stat.select(_stat.item_count - 1)
	if _stat.selected < 0:
		_select_first_enabled(_stat)
	_rebuild_ops()


func _rebuild_ops() -> void:
	var previous: int = int(_op.get_selected_metadata()) if _op.selected >= 0 else -1
	_op.clear()
	for op in Catalog.ops_for(_selected_stat()):
		_op.add_item(Catalog.OP_LABELS[op])
		_op.set_item_metadata(_op.item_count - 1, op)
		if op == previous:
			_op.select(_op.item_count - 1)
	if _op.selected < 0 and _op.item_count > 0:
		_op.select(0)
	_rebuild_value()


## Swaps in the widget the stat's TYPE calls for. This is the whole reason the
## catalog reports types: a float gets a spinner, a colour gets a picker, and a
## status dictionary gets a pair of controls that can only produce a legal entry.
func _rebuild_value() -> void:
	for child in _value_host.get_children():
		child.queue_free()
	_value_widget = null
	_potency = null

	var stat := _selected_stat()
	if stat.is_empty():
		_update_sentence()
		return

	match int(stat["type"]):
		TYPE_FLOAT:
			var f := SpinBox.new()
			f.step = 0.01
			f.allow_greater = true
			f.allow_lesser = true
			f.custom_minimum_size = Vector2(110.0, 0.0)
			_value_widget = f
		TYPE_INT:
			var i := SpinBox.new()
			i.step = 1
			i.rounded = true
			i.allow_greater = true
			i.allow_lesser = true
			i.custom_minimum_size = Vector2(90.0, 0.0)
			_value_widget = i
		TYPE_BOOL:
			_value_widget = CheckBox.new()
			(_value_widget as CheckBox).text = "on"
		TYPE_COLOR:
			var c := ColorPickerButton.new()
			c.custom_minimum_size = Vector2(70.0, 0.0)
			c.color = Color.WHITE
			_value_widget = c
		TYPE_DICTIONARY:
			var which := OptionButton.new()
			for id in Catalog.STATUS_IDS:
				which.add_item(id)
			_value_widget = which
			_potency = SpinBox.new()
			_potency.step = 0.1
			_potency.allow_greater = true
			_potency.value = 1.0
			_potency.custom_minimum_size = Vector2(90.0, 0.0)

	if _value_widget != null:
		_value_host.add_child(_value_widget)
		_connect_value(_value_widget)
	if _potency != null:
		_value_host.add_child(Label.new())
		(_value_host.get_child(_value_host.get_child_count() - 1) as Label).text = "potency"
		_value_host.add_child(_potency)
		_connect_value(_potency)
	_update_sentence()


func _connect_value(w: Control) -> void:
	if w is SpinBox:
		(w as SpinBox).value_changed.connect(func(_v: float) -> void: _update_sentence())
	elif w is CheckBox:
		(w as CheckBox).toggled.connect(func(_v: bool) -> void: _update_sentence())
	elif w is ColorPickerButton:
		(w as ColorPickerButton).color_changed.connect(func(_c: Color) -> void: _update_sentence())
	elif w is OptionButton:
		(w as OptionButton).item_selected.connect(func(_i: int) -> void: _update_sentence())


func _read_value() -> Variant:
	if _value_widget == null:
		return 0.0
	if _potency != null and _value_widget is OptionButton:
		return {(_value_widget as OptionButton).get_item_text(
			(_value_widget as OptionButton).selected): _potency.value}
	if _value_widget is SpinBox:
		var stat := _selected_stat()
		if not stat.is_empty() and int(stat["type"]) == TYPE_INT:
			return int((_value_widget as SpinBox).value)
		return (_value_widget as SpinBox).value
	if _value_widget is CheckBox:
		return (_value_widget as CheckBox).button_pressed
	if _value_widget is ColorPickerButton:
		return (_value_widget as ColorPickerButton).color
	return 0.0


func _apply_value(value: Variant) -> void:
	if _value_widget == null:
		return
	if _potency != null and typeof(value) == TYPE_DICTIONARY:
		for k: String in (value as Dictionary):
			for i in (_value_widget as OptionButton).item_count:
				if (_value_widget as OptionButton).get_item_text(i) == k:
					(_value_widget as OptionButton).select(i)
			_potency.value = float((value as Dictionary)[k])
			break
	elif _value_widget is SpinBox:
		(_value_widget as SpinBox).value = float(value)
	elif _value_widget is CheckBox:
		(_value_widget as CheckBox).button_pressed = bool(value)
	elif _value_widget is ColorPickerButton and typeof(value) == TYPE_COLOR:
		(_value_widget as ColorPickerButton).color = value


func _update_sentence() -> void:
	var stat := _selected_stat()
	if stat.is_empty() or _op.item_count == 0:
		_sentence.text = "pick a stat this level should change."
	else:
		_sentence.text = Catalog.describe(stat["name"], _target.get_selected_id(),
			int(_op.get_selected_metadata()), _read_value())
	changed.emit()


func _select_first_enabled(list: OptionButton) -> void:
	for i in list.item_count:
		if not list.is_item_disabled(i):
			list.select(i)
			return

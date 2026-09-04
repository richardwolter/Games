@tool
extends VBoxContainer

## The Upgrade Forge: the screen where an item's upgrade levels are written.
##
## Pick an item, fill in what each of its levels does, press Save. What comes out
## is `config/upgrades.tres`, which the prep menu prices and the run merges into
## the item. Nothing about it needs to be edited by hand, and nothing in it can
## name a stat the game does not have -- see stat_catalog.gd.
##
## Editing is done against a WORKING COPY of the table held in memory. Switching
## items commits the open editors into it; Save writes the whole thing at once.
## That way a half-finished level can never be written to disk by some unrelated
## editor action, and Save is a single deliberate act.

const Catalog := preload("res://addons/upgrade_forge/stat_catalog.gd")
const RowScript := preload("res://addons/upgrade_forge/modifier_row.gd")
const RunManagerScript := preload("res://src/run_manager.gd")

const TABLE_PATH := "res://config/upgrades.tres"

var _table: UpgradeTable
## Path of the item currently open in the editors.
var _current: String = ""

var _item_picker: OptionButton
var _cost: SpinBox
var _max_level: SpinBox
var _levels_box: VBoxContainer
var _status: Label
## One entry per level on screen: {"summary": LineEdit, "rows": VBoxContainer}.
var _editors: Array[Dictionary] = []


func _ready() -> void:
	custom_minimum_size = Vector2(0.0, 320.0)
	add_theme_constant_override("separation", 6)
	_load_table()
	_build_header()
	_build_body()
	_open_item(_item_picker.get_item_metadata(0) if _item_picker.item_count > 0 else "")


func _load_table() -> void:
	if ResourceLoader.exists(TABLE_PATH):
		# Fresh from disk rather than the cache: the running game may be holding
		# the same resource, and the dock must not edit what it is playing with.
		_table = ResourceLoader.load(TABLE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as UpgradeTable
	if _table == null:
		_table = UpgradeTable.new()


func _build_header() -> void:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	add_child(head)

	head.add_child(_titled("Item"))
	_item_picker = OptionButton.new()
	# Straight off the run's own list, so the dock cannot offer upgrades for an
	# item the game never hands out.
	for path in RunManagerScript.ITEM_PATHS:
		var item := load(path) as Item
		_item_picker.add_item(item.display_name if item != null else path)
		_item_picker.set_item_metadata(_item_picker.item_count - 1, path)
	_item_picker.item_selected.connect(func(i: int) -> void:
		_open_item(_item_picker.get_item_metadata(i)))
	head.add_child(_item_picker)

	head.add_child(_titled("   DNA per upgrade"))
	_cost = SpinBox.new()
	# Stepped from zero, not from one: a SpinBox snaps to min + n*step, and a
	# min of 1 with a step of 5 makes 375 impossible to type.
	_cost.min_value = 0
	_cost.max_value = 100000
	_cost.step = 5
	_cost.value = _table.cost_per_level
	head.add_child(_cost)

	head.add_child(_titled("   Levels per item"))
	_max_level = SpinBox.new()
	_max_level.min_value = 1
	_max_level.max_value = 6
	_max_level.value = _table.max_level
	_max_level.value_changed.connect(func(_v: float) -> void: _open_item(_current))
	head.add_child(_max_level)

	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)

	var save := Button.new()
	save.text = "Save to config/upgrades.tres"
	save.pressed.connect(_on_save)
	head.add_child(save)

	_status = Label.new()
	head.add_child(_status)


func _build_body() -> void:
	var help := Label.new()
	help.text = "Each level is EXTRA on top of the ones below it: owning level 3 means levels 1, 2 and 3 are all applied. " \
		+ "One level should change one important thing, or add something the item did not do before."
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
	add_child(help)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_levels_box = VBoxContainer.new()
	_levels_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_levels_box.add_theme_constant_override("separation", 8)
	scroll.add_child(_levels_box)


# --- item editing ---

## Commits whatever is open, then rebuilds the editors for `path`.
func _open_item(path: String) -> void:
	if _current != "" and _current != path:
		_commit_current()
	_current = path
	for child in _levels_box.get_children():
		child.queue_free()
	_editors.clear()
	if path == "":
		return

	for i in _item_picker.item_count:
		if _item_picker.get_item_metadata(i) == path:
			_item_picker.select(i)
			break

	var entry := _table.for_item_path(path)
	for level in range(1, int(_max_level.value) + 1):
		_levels_box.add_child(_build_level(level, entry.level(level) if entry != null else null))


func _build_level(level: int, data: UpgradeLevel) -> Control:
	var panel := PanelContainer.new()
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	box.add_child(head)
	var title := Label.new()
	title.text = "LEVEL %d" % level
	head.add_child(title)
	var cost := Label.new()
	cost.text = "costs %d DNA" % int(_cost.value)
	cost.add_theme_color_override("font_color", Color(0.62, 1.0, 0.78))
	head.add_child(cost)

	box.add_child(_titled("What the player is told this does:"))
	var summary := LineEdit.new()
	summary.placeholder_text = "e.g. \"The needle goes through one more of them.\""
	summary.text = data.summary if data != null else ""
	box.add_child(summary)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 6)
	box.add_child(rows)

	var editor := {"summary": summary, "rows": rows, "level": level}
	_editors.append(editor)

	if data != null:
		for mod in data.modifiers:
			if mod != null:
				_add_row(rows, mod)

	var add := Button.new()
	add.text = "+ add an effect to level %d" % level
	add.pressed.connect(func() -> void: _add_row(rows, null))
	box.add_child(add)
	return panel


func _add_row(rows: VBoxContainer, mod: StatModifier) -> void:
	var row: VBoxContainer = RowScript.new()
	rows.add_child(row)
	row.removed.connect(func() -> void: row.queue_free())
	if mod != null:
		row.load_modifier(mod)


## Reads the open editors back into the working table.
func _commit_current() -> void:
	if _current == "":
		return
	var entry := _table.for_item_path(_current)
	if entry == null:
		entry = ItemUpgrades.new()
		entry.item_path = _current
		_table.entries.append(entry)

	var levels: Array[UpgradeLevel] = []
	for editor: Dictionary in _editors:
		var level := UpgradeLevel.new()
		level.summary = (editor["summary"] as LineEdit).text
		var mods: Array[StatModifier] = []
		for child in (editor["rows"] as VBoxContainer).get_children():
			if child.is_queued_for_deletion():
				continue
			var mod: StatModifier = child.to_modifier()
			if mod != null:
				mods.append(mod)
		level.modifiers = mods
		levels.append(level)

	# Trailing empty levels are dropped, so "level 3 not written yet" is a real
	# state the prep menu can report rather than a level that costs DNA and does
	# nothing.
	while not levels.is_empty() and levels[levels.size() - 1].modifiers.is_empty():
		levels.remove_at(levels.size() - 1)
	entry.levels = levels


# --- saving ---

func _on_save() -> void:
	_commit_current()
	_table.cost_per_level = int(_cost.value)
	_table.max_level = int(_max_level.value)

	# Ids are generated here rather than in the rows, because uniqueness is a
	# property of the WHOLE table and a row cannot see the whole table. The
	# pipeline breaks its sort ties on the id, so two modifiers sharing one is
	# how a build stops being reproducible.
	var seen := {}
	for entry in _table.entries:
		if entry == null:
			continue
		var stem := entry.item_path.get_file().get_basename()
		for n in entry.levels.size():
			var level := entry.levels[n]
			for i in level.modifiers.size():
				var mod := level.modifiers[i]
				mod.id = StringName("%s_u%d_%s_%d" % [stem, n + 1, mod.stat, i])
				if seen.has(mod.id):
					_say("Two effects ended up with the id %s -- not saved." % mod.id, true)
					return
				seen[mod.id] = true
				if mod.op == StatModifier.Op.APPEND \
						and not (String(mod.stat) in StatModifier.APPENDABLE):
					_say("%s cannot be added to as a list -- not saved." % mod.stat, true)
					return

	var err := ResourceSaver.save(_table, TABLE_PATH)
	if err != OK:
		_say("Could not write %s: %s" % [TABLE_PATH, error_string(err)], true)
		return
	if Engine.is_editor_hint() and EditorInterface.get_resource_filesystem() != null:
		EditorInterface.get_resource_filesystem().scan()
	_say("Saved at %s." % Time.get_time_string_from_system(), false)


func _say(text: String, bad: bool) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color",
		Color(1.0, 0.45, 0.4) if bad else Color(0.62, 1.0, 0.78))


func _titled(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.7, 0.7, 0.76))
	return l

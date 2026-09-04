class_name PrepMenu
extends Control

## Between runs: what you banked, what it buys, and the button that sends you
## back in.
##
## The whole screen is built here rather than in the scene file, so the layout
## and the data that drives it live in one place -- `scenes/prep.tscn` is a bare
## Control with this attached. This is the only screen in the game that is not
## the run, and it exists only while the run does not.

## Rows keyed by item path, so a purchase re-labels the row it happened on
## instead of rebuilding the list and throwing the scroll position away.
var _rows: Dictionary = {}
var _dna_label: Label
var _start: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(UIStyle.backdrop())

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, UIStyle.PAD * 3)
	add_child(margin)

	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	margin.add_child(page)

	page.add_child(UIStyle.label("SICKEST MAN ALIVE", UIStyle.SIZE_TITLE))
	_dna_label = UIStyle.label("", UIStyle.SIZE_HEAD, UIStyle.DNA)
	page.add_child(_dna_label)
	page.add_child(UIStyle.label(_last_run_line(), UIStyle.SIZE_SMALL, UIStyle.DIM))
	# Without this the carry is invisible between the results screen and the
	# moment it silently turns up in the run's readout.
	if MetaProgress.carried_item_path != "":
		var carried := load(MetaProgress.carried_item_path) as Item
		if carried != null:
			page.add_child(UIStyle.label("carrying in: %s" % carried.display_name,
				UIStyle.SIZE_SMALL, UIStyle.DNA))
	page.add_child(UIStyle.spacer(6))
	page.add_child(UIStyle.label(
		"Upgrades are permanent. They change the items you find inside him.",
		UIStyle.SIZE_SMALL, UIStyle.DIM))
	page.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	# Straight off the run's own pool, so the menu can never offer an upgrade for
	# an item the run does not hand out, or miss one that it does.
	for path in RunManager.ITEM_PATHS:
		var row := _build_row(path)
		if row != null:
			list.add_child(row)

	page.add_child(UIStyle.spacer(8))
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	page.add_child(buttons)

	_start = UIStyle.button("GO BACK IN", _on_start, UIStyle.SIZE_HEAD)
	buttons.add_child(_start)
	buttons.add_child(UIStyle.button("erase progress", _on_reset, UIStyle.SIZE_SMALL))

	MetaProgress.dna_changed.connect(func(_total: int) -> void: _refresh())
	MetaProgress.levels_changed.connect(_refresh)
	_refresh()
	_start.call_deferred("grab_focus")


## One item: colour chip, name and level, what the next level does, and the
## button that buys it.
func _build_row(path: String) -> Control:
	var item := load(path) as Item
	if item == null:
		return null

	var card := UIStyle.panel()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)

	var chip := ColorRect.new()
	chip.color = item.pedestal_color
	chip.custom_minimum_size = Vector2(20.0, 20.0)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(chip)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title := UIStyle.label("", UIStyle.SIZE_BODY)
	text.add_child(title)
	var detail := UIStyle.wrapped("")
	text.add_child(detail)

	var buy := UIStyle.button("", _on_buy.bind(path), UIStyle.SIZE_SMALL)
	buy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(buy)

	_rows[path] = {"title": title, "detail": detail, "buy": buy, "item": item}
	return card


func _refresh() -> void:
	_dna_label.text = "DNA  %d" % MetaProgress.dna
	for path: String in _rows:
		_refresh_row(path)


func _refresh_row(path: String) -> void:
	var row: Dictionary = _rows[path]
	var item: Item = row["item"]
	var level := MetaProgress.level_of(path)
	var cap := MetaProgress.max_level_of(path)
	var cost := MetaProgress.cost_of_next(path)

	(row["title"] as Label).text = "%s   ·   Lv %d / %d" % [item.display_name, level, cap]

	var detail := row["detail"] as Label
	var buy := row["buy"] as Button
	if cap <= 0:
		# The table has nothing for this item yet. Said outright rather than
		# shown as a dead button, because "nothing authored" is a fact about the
		# game's content, not about the player's DNA.
		detail.text = "no upgrades written for this one yet"
		buy.text = "--"
		buy.disabled = true
		return

	detail.text = MetaProgress.next_summary(path)
	if detail.text == "":
		detail.text = item.description
	if cost < 0:
		buy.text = "MAXED"
		buy.disabled = true
		return
	buy.text = "UPGRADE  %d" % cost
	buy.disabled = not MetaProgress.can_upgrade(path)


func _on_buy(path: String) -> void:
	MetaProgress.buy_upgrade(path)


func _on_start() -> void:
	get_tree().change_scene_to_file(MetaProgress.SCENE_RUN)


func _on_reset() -> void:
	MetaProgress.reset_progress()


## The one-line recap of however the last run went. Empty on a cold boot, which
## is the difference between "you have not played yet" and "you got nothing".
func _last_run_line() -> String:
	var r := MetaProgress.last_result
	if r.is_empty():
		return "the uncle is still sick."
	var escaped: bool = r.get("outcome", "died") == "escaped"
	return "last run: %s, %d/%d rooms, %s+%d DNA" % [
		"got out" if escaped else "died in the %s" % r.get("where", "body"),
		int(r.get("rooms_cleared", 0)), int(r.get("rooms_total", 0)),
		# Defaults on both halves: `last_result` is in-memory only, so a result
		# written by an older build in the same session would have neither key.
		"%d/%d infections, " % [int(r.get("bosses_killed", 0)),
			int(r.get("bosses_total", 0))],
		int(r.get("total", 0)),
	]

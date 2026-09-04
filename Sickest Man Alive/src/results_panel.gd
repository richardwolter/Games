class_name ResultsPanel
extends CanvasLayer

## What the run was worth, over the top of the run that just ended.
##
## Deliberately not a scene swap: the body is still there behind it, with the
## corpse where it fell and the blood where it was spilled. The run is already
## frozen by the time this appears -- the timer is stopped and the rampage is
## off -- so nothing here pauses the tree. The project has no pause mode and
## introducing one would mean auditing every `_process` in it.

signal continued
## The item the player chose to take into the next run, as a resource path.
##
## A signal rather than the panel writing MetaProgress itself: it already takes
## `banked` as an argument instead of reading it, and keeping save policy out of
## a CanvasLayer is what makes this thing testable.
signal carry_chosen(path: String)

## Which lines to print, in order, and what to call them. A run that did not
## escape shows no escape line at all rather than a zero -- a zero reads as
## "you got nothing for it" when the truth is "that did not happen".
const LINES: Array = [
	["motes", "DNA collected"],
	["room_bonus", "rooms cleared"],
	["boss_bonus", "infections killed"],
	["escape_bonus", "got out alive"],
	["made_up", "minimum for a real run"],
]


## `carry_options` is a list of `{path, name, color}`, empty on any run that did
## not earn a carry. Passed separately rather than folded into `result` because
## `result` is the payout document whose shape DnaPayout owns and
## tools/test_dna.gd asserts on -- a UI-only array does not belong in it.
func build(result: Dictionary, balance: int, carry_options: Array = []) -> void:
	layer = 10

	var dim := UIStyle.backdrop(Color(0.0, 0.0, 0.0, 0.62))
	add_child(dim)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)

	var card := UIStyle.panel(UIStyle.PANEL, UIStyle.BORDER, UIStyle.PAD * 2)
	card.custom_minimum_size = Vector2(520.0, 0.0)
	centre.add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	card.add_child(box)

	var escaped: bool = result.get("outcome", "died") == "escaped"
	box.add_child(UIStyle.label(
		("GOT OUT -- %s" % String(result.get("where", "")).to_upper()) if escaped
			else ("DIED IN THE %s" % String(result.get("where", "")).to_upper()),
		UIStyle.SIZE_HEAD, UIStyle.DNA if escaped else UIStyle.DANGER))

	var seconds := int(result.get("time", 0))
	box.add_child(UIStyle.label("%02d:%02d   ·   %d / %d rooms cleared   ·   %d / %d infections killed"
		% [seconds / 60, seconds % 60, int(result.get("rooms_cleared", 0)),
			int(result.get("rooms_total", 0)),
			int(result.get("bosses_killed", 0)), int(result.get("bosses_total", 0))],
		UIStyle.SIZE_SMALL, UIStyle.DIM))

	box.add_child(UIStyle.spacer(10))

	for entry: Array in LINES:
		var amount := int(result.get(entry[0], 0))
		if amount <= 0:
			continue
		box.add_child(_row(entry[1], "+%d" % amount, UIStyle.INK))

	box.add_child(HSeparator.new())
	box.add_child(_row("DNA EARNED", "%d" % int(result.get("total", 0)), UIStyle.DNA))
	box.add_child(_row("banked", "%d" % balance, UIStyle.DIM))

	var go := UIStyle.button("CONTINUE", func() -> void: continued.emit())
	if not carry_options.is_empty():
		_build_carry(box, carry_options, go)

	box.add_child(UIStyle.spacer(14))
	box.add_child(go)
	# Focused so the panel can be dismissed on a pad, and because the run behind
	# it no longer takes input.
	go.call_deferred("grab_focus")


## The carry picker: one row per item the player walked out with.
##
## Choosing does NOT dismiss the panel. The player should be able to read the
## payout, pick, and change their mind -- a button that both chooses and
## continues makes a misclick unrecoverable, and this is the only thing in the
## run they get to keep.
##
## Declining is the default: CONTINUE stays live and keeps the focus, so the
## panel is still dismissable on a pad without touching the picker at all.
func _build_carry(box: VBoxContainer, options: Array, go: Button) -> void:
	box.add_child(UIStyle.spacer(10))
	box.add_child(HSeparator.new())
	box.add_child(UIStyle.label("TAKE ONE THING WITH YOU", UIStyle.SIZE_BODY, UIStyle.DNA))
	# "once" is doing real work here: a player who thinks this is permanent will
	# feel robbed the run after next.
	box.add_child(UIStyle.label("it comes back in with you next run, once",
		UIStyle.SIZE_SMALL, UIStyle.DIM))

	var takes: Array[Button] = []
	for option: Dictionary in options:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		# Same chip-then-name shape the prep menu's upgrade rows use, so an item
		# is recognisable by colour in both places.
		var chip := ColorRect.new()
		chip.color = option.get("color", UIStyle.INK)
		chip.custom_minimum_size = Vector2(18.0, 18.0)
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(chip)

		row.add_child(UIStyle.label(String(option.get("name", "?")),
			UIStyle.SIZE_BODY, UIStyle.INK))
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)

		var path := String(option.get("path", ""))
		var name := String(option.get("name", "?"))
		var take := UIStyle.button("TAKE", func() -> void:
			carry_chosen.emit(path)
			# Every button goes dead, not just this one: the choice is one item,
			# and a second live TAKE would silently overwrite the first pick.
			for b: Button in takes:
				b.disabled = true
			go.text = "CONTINUE -- carrying %s" % name.to_upper()
		)
		takes.append(take)
		row.add_child(take)
		box.add_child(row)


## One "label ..... value" line. A HBox with an expanding spacer rather than
## padded text, so the numbers line up whatever the label says.
func _row(text: String, amount: String, color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_child(UIStyle.label(text, UIStyle.SIZE_BODY, color))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gap)
	var value := UIStyle.label(amount, UIStyle.SIZE_BODY, color)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row

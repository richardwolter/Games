extends "res://scripts/ui/board.gd"
## Who made it. Placeholder lines until Richard settles the credits.

const Text = preload("res://scripts/text.gd")


func _init() -> void:
	super(Text.CREDITS_TITLE, 380.0)
	for line in [Text.CREDITS_GAME, Text.CREDITS_ENGINE]:
		var l := Ink.label(line)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(l)
	var back := Button.new()
	back.text = Text.BACK
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(close)
	body.add_child(back)
	back.grab_focus.call_deferred()

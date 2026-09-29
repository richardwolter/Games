def patch(p, pairs, tail=""):
    s = open(p, encoding="utf-8", newline="").read()
    for a, b in pairs:
        assert a in s, (p, a[:70])
        s = s.replace(a, b, 1)
    if tail:
        s = s.rstrip("\n") + "\n" + tail
    open(p, "w", encoding="utf-8", newline="").write(s)

# --- main menu -------------------------------------------------------------------------
patch("scripts/menu.gd", [(
'''func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
''',
'''func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	add_to_group(Pad.FOCUS_GROUP)
''')], '''

## The doors for the pad's stick (scripts/pad.gd): the planks down the stack, the accented
## one picked first, and the flag in the corner. None while a board is over them — a board
## that knows the stick answers for itself, and one that does not yet is the pointer's.
func pad_focus() -> Array:
	if not live():
		return []
	for over: Control in [_settings, _controls, _credits, _letter, _languages, _confirm]:
		if over.visible:
			return []
	var out: Array = []
	for door: Dictionary in DOORS:
		var plank: PlankButton = _planks[door["key"]]
		if plank.visible:
			out.append({"box": plank.get_rect(), "key": door["key"], "first": plank.accent})
	out.append({"box": _flag.get_rect(), "key": &"language"})
	return out
''')

# --- confirm ---------------------------------------------------------------------------
patch("scripts/menu_confirm.gd", [(
'''func _ready() -> void:
''',
'''func _ready() -> void:
	add_to_group(Pad.FOCUS_GROUP)
''')], '''

## The two doors for the pad's stick, the one that keeps what is there picked first: a
## confirm that asks before throwing something away should not start on the throwing.
func pad_focus() -> Array:
	var out: Array = []
	for door: Dictionary in _doors:
		out.append({"box": door["box"], "key": door["key"], "first": door["key"] == &"no"})
	return out
''')
print("ok")

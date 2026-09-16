extends Node
## Rings the click's ripple over the main menu and saves it at three ages, so what the ring
## looks like opening, wide and going out can be looked at rather than guessed.
##
## A probe, not a test: `test_lake` guards that a click rings and that the ring dies on its
## own; whether it reads as water is a thing to look at. Run it with the desktop build, not
## --headless — nothing renders under the dummy driver — and with --fixed-fps 60, so the
## ages below are the ages that are drawn.
##
##   <godot> --path . --fixed-fps 60 res://tools/shot_ripple.tscn

## When to take each picture, in seconds after the ring is rung.
const SHOTS := {
	&"open": 0.06,
	&"wide": 0.18,
	&"going": 0.28,
}

## Where the ring is rung, **in canvas coordinates, not window pixels**: over the menu's
## planks, where a click actually lands, rather than out on the bare picture. The project
## stretches a 1280x720 canvas over the window, and the pointer, the ripple and every other
## drawn thing live in that canvas -- a point in window pixels is off the bottom of it, which
## is an afternoon's worth of looking for a ripple that was being drawn all along.
const AT := Vector2(200.0, 520.0)

## How long the menu is given to lay itself out before anything is drawn over it.
const SETTLE := 0.6

var _menu: Node
var _age := -SETTLE
var _rung := false
var _taken: Array[StringName] = []


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_menu = load("res://scenes/menu.tscn").instantiate()
	get_tree().root.add_child.call_deferred(_menu)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age < 0.0:
		return
	if not _rung:
		_rung = true
		Pad.ripples.splash(AT)
	for name: StringName in SHOTS:
		if name in _taken or _age < float(SHOTS[name]):
			continue
		_taken.append(name)
		var shot := get_viewport().get_texture().get_image()
		# The ring is a couple of dozen pixels across and the window is 1920 wide: the crop
		# is what makes the picture worth opening.
		# The picture is in window pixels and AT is in canvas ones, so the crop is scaled.
		var over: Vector2 = Vector2(shot.get_size()) / get_viewport().get_visible_rect().size
		var middle := Vector2i(AT * over)
		shot = shot.get_region(Rect2i(middle - Vector2i(90, 70), Vector2i(180, 140)))
		shot.save_png("res://tools/last_ripple_%s.png" % name)
	if _taken.size() >= SHOTS.size():
		get_tree().quit()

extends Node
## Opens the upgrades shop with a recycle bonus running and money in the purse, and saves
## `tools/last_shop_money.png` (2026-09-24): the purse over the shop and the bonus's lit
## panel on the pricing plate are the two things to look at. Desktop build, own save, under
## its own node.

const SHOT := "res://tools/last_shop_money.png"

var _main: Node
var _frames := 0


func _ready() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", "user://probe_shop_money.save")
	add_child.call_deferred(_main)
	set_physics_process(true)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 8:
		_main.set(&"sludge", 12345)
		_main.set(&"recycle_bonus_level", 3)
		_main.set(&"_shop_tour_done", true)
		_main.call(&"_move_bonus")
		_main.call(&"_set_menu", true)
	if _frames == 150:
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(SHOT))
	if _frames >= 154:
		get_tree().quit()

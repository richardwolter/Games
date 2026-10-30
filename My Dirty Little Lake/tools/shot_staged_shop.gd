extends Node
## The staged shop (2026-10-25, the mdll-staged-shop test branch), photographed: the first
## visit's three cards over the shut boards, the planks coming off the net after three boat
## levels, the net's card, and the shop with the net open and the dogs and luck still shut.
##
## Desktop build, not `--headless`: `<exe> --path . --fixed-fps 60 tools/shot_staged_shop.tscn`.
## Saves `tools/last_staged_{boats,locked,legend,unseal,net,open}.png` and
## `tools/last_staged.log`. Its own save, deleted first and after, and the lake under this node.

const SHOT := "res://tools/last_staged_%s.png"
const LOG := "res://tools/last_staged.log"
const SAVE := "user://probe_staged_shop.save"
const SETTLE := 60
const LOOK := 10
const QUIT_AFTER_MS := 60000

var _main: Node
var _skin: ShopSkin
var _log: FileAccess
var _frames := 0
var _at := 0
var _step := 0
var _busy := false
var _started_ms := 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	Lake.force_stages = true
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started_ms > QUIT_AFTER_MS:
		_say("wall clock ran out at step %d" % _step)
		_finish()
		return
	if _busy or _frames < SETTLE:
		return
	if _skin == null:
		_log = FileAccess.open(LOG, FileAccess.WRITE)
		_skin = _main.get(&"_shop_skin")
		_main.set(&"sludge", 5000.0)
		_main.set(&"_first_buy_done", true)
		_main.set(&"_shop_tours", 0)
		_main.set(&"_shop_tour_done", false)
		_main.call(&"_set_menu", true)
		_say("opened: tour %d, shut %s" % [_skin.tour, str(_main.call(&"_shut_boards"))])
		_at = _frames
		return
	if _frames - _at < LOOK:
		return
	match _step:
		0:
			_shoot("boats")
		1:
			_skin.tour_next()
			_wait()
		2:
			_say("locked card target %s" % str(_skin.tour_target()))
			_shoot("locked")
		3:
			_skin.tour_next()
			_wait()
		4:
			_shoot("legend")
		5:
			_skin.tour_next()
			for key: StringName in [&"cargo", &"boat_speed", &"boat_speed"]:
				_main.call(&"_buy", key)
			_say("bought three: shut %s, tour %d" % [str(_main.call(&"_shut_boards")), _skin.tour])
			# Half a second into the fall, where the planks reach the board's foot.
			_step += 1
			_at = _frames + 20
		6:
			_shoot("unseal")
		7:
			_at = _frames + 90
			_step += 1
		8:
			_say("net card: tour %d %s" % [_skin.tour, str(_skin.tour_cards)])
			_shoot("net")
		9:
			_skin.tour_next()
			_wait()
		10:
			_shoot("open")
		_:
			_say("shops tours %d" % int(_main.get(&"_shop_tours")))
			_finish()


func _wait() -> void:
	_step += 1
	_at = _frames


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % name_of)
	_say("shot %s" % name_of)
	_step += 1
	_at = _frames
	_busy = false


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _finish() -> void:
	set_physics_process(false)
	Lake.force_stages = false
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()

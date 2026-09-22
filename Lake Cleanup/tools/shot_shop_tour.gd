extends Node
## The shop's tour (`ShopSkin.tour`), photographed card by card.
##
## Desktop build, not `--headless`: `<exe> --path . --fixed-fps 60 tools/shot_shop_tour.tscn`.
## Saves `tools/last_shop_tour_{1..6,pad}.png` and `tools/last_shop_tour.log`. Its own save,
## deleted first and after, and the lake under this node (see `tools/shot_letter.gd`).

const SHOT := "res://tools/last_shop_tour_%s.png"
const LOG := "res://tools/last_shop_tour.log"
const SAVE := "user://lake_cleanup_shot_tour.save"
const SETTLE := 60
const LOOK := 8
const QUIT_AFTER_MS := 60000

var _main: Node
var _skin: ShopSkin
var _log: FileAccess
var _frames := 0
var _at := 0
var _card := 0
var _busy := false
var _ended := ""
var _started_ms := 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE)
	add_child(_main)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _started_ms > QUIT_AFTER_MS:
		_say("wall clock ran out at card %d" % _card)
		_finish()
		return
	if _busy or _frames < SETTLE:
		return
	if _skin == null:
		_log = FileAccess.open(LOG, FileAccess.WRITE)
		_skin = _main.get(&"_shop_skin")
		_skin.tour_ended.connect(func(skipped: bool) -> void: _ended = "skipped" if skipped else "read")
		_main.set(&"_shop_tour_done", false)
		_main.call(&"_set_menu", true)
		_say("tour %d on opening" % _skin.tour)
		_at = _frames
		return
	if _frames - _at < LOOK:
		return
	if _card < ShopSkin.TOUR.size():
		_say("card %d target %s" % [_skin.tour + 1, str(_skin.tour_target())])
		_shoot(str(_card + 1))
		return
	if _card == ShopSkin.TOUR.size():
		_skin.tour = 0
		Pad.set_mode(Pad.Mode.PAD)
		_card += 1
		_at = _frames
		return
	if _card == ShopSkin.TOUR.size() + 1:
		_shoot("pad")
		return
	Pad.set_mode(Pad.Mode.MOUSE)
	for i in ShopSkin.TOUR.size():
		_skin.tour_next()
	_say("ended %s, saved flag %s" % [_ended, str(_main.get(&"_shop_tour_done"))])
	_finish()


func _shoot(name_of: String) -> void:
	_busy = true
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOT % name_of)
	_say("shot %s" % name_of)
	if _card < ShopSkin.TOUR.size() - 1:
		_skin.tour_next()
	_card += 1
	_at = _frames
	_busy = false


func _say(line: String) -> void:
	if _log != null:
		_log.store_line(line)
		_log.flush()


func _finish() -> void:
	set_physics_process(false)
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	get_tree().quit()

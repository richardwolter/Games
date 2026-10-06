## The record player's menu (2026-09-28): the shed with a record player in it, its menu up,
## once with the lists apart and once synced, then just after a skip with the needle lifted.
## Desktop build, not --headless: saves tools/last_record_menu_{apart,synced,skip}.png and
## last_record_menu.log. Its own save and its own node, never the player's lake.
extends Node

const SAVE := "user://probe_record.save"
const LOG := "res://tools/last_record_menu.log"

var _lake: Node
var _frames := 0
var _log: FileAccess
var _started := 0


func _ready() -> void:
	_started = Time.get_ticks_msec()
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	_log = FileAccess.open(LOG, FileAccess.WRITE)
	_lake = load("res://scenes/main.tscn").instantiate()
	_lake.set(&"save_path", SAVE)
	_lake.set(&"autoload_save", false)
	add_child(_lake)


func _physics_process(_delta: float) -> void:
	_frames += 1
	# A wall clock as well: a probe's safety may not depend on the probe working.
	if Time.get_ticks_msec() - _started > 60000:
		get_tree().quit(1)
	if _lake == null or not _lake.is_inside_tree():
		return
	var room: ShedRoom = _lake.get_node(^"HUD/Shed/Pad/Lines/Room")
	var station := MusicStation.main()
	if _frames == 8:
		_lake.call(&"_set_shed", true)
		var decor: Array = _lake.get(&"decor")
		decor.clear()
		room.decor = decor
		room.place(&"decor_vynil_player", Vector2i(20, 8) * ShedRoom.CELL)
		station.take_picks({"lake": ["beatgucci", "save_me", "goin"], "shed": ["indie_boi"]})
	if _frames == 14:
		room.call(&"_open_record", 0)
	if _frames == 40:
		_shoot("apart", room, station)
		(room.get_node(^"RecordMenu") as RecordMenu).press(&"sync")
	if _frames == 70:
		_shoot("synced", room, station)
		var menu := room.get_node(^"RecordMenu") as RecordMenu
		menu.press(&"sync")
		menu.press(&"skip")
	if _frames == 88:
		_shoot("skip", room, station)
	if _frames == 96:
		(room.get_node(^"RecordMenu") as RecordMenu).close()
		_log.store_line("lid after close: view %d" % int(room.decor[0]["view"]))
		_log.flush()
		get_tree().quit()


func _shoot(tag: String, room: ShedRoom, station: MusicStation) -> void:
	get_viewport().get_texture().get_image().save_png("res://tools/last_record_menu_%s.png" % tag)
	_log.store_line("%s: up %s, lid view %d, picks %s, shed plays %s" % [
		tag, room.record_up(), int(room.decor[0]["view"]), station.picks(),
		station.playing_in(MusicStation.SHED)])
	_log.flush()

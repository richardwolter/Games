extends SceneTree

## Checks the two things about gore that are not visual and therefore testable:
## a dead creature leaves a pool that SURVIVES leaving the room, and a dead
## player goes down as a slide the enemies then gather around.
##
## Run: <godot> --headless --script tools/test_gore.gd

var _frames: int = 0
var _main: Node
var _player: Player
var _map: MapData
var _cell: Vector2i
var _blood_after_kill: int = -1
var _blood_after_return: int = -1
var _mourners: int = 0
var _slid: float = 0.0
var _death_pos: Vector2 = Vector2.ZERO


func _initialize() -> void:
	_main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_main)
	current_scene = _main
	_player = _main.get_node("Player") as Player


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		_map = _main.map
		_cell = _main.current_cell
		# Kill whatever the room happens to hold, plus a spawned-in test body so
		# the check does not depend on the room rolling a combat wave.
		var e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
		e.body_color = Color(0.2, 0.9, 0.3)
		e.position = Vector2(200.0, 200.0)
		_main.room.add_child(e)
		e.take_damage(9999.0, Vector2.ZERO, {}, false)

	if _frames == 10:
		_blood_after_kill = _map.blood_of(_cell).size()
		# Leave and come back: the room object is destroyed and rebuilt, which is
		# the whole thing the pools have to survive.
		var exits := _map.exits_of(_cell)
		if exits.is_empty():
			push_error("start room has no exits; cannot test persistence")
			return true
		_main._enter(exits[0]["to"], "")

	if _frames == 14:
		_main._enter(_cell, "")

	if _frames == 18:
		_blood_after_return = _map.blood_of(_cell).size()
		# Something to gather round the body.
		for i in 4:
			var e := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
			e.position = Vector2(300.0 + i * 40.0, 300.0)
			_main.room.add_child(e)
		_player.velocity = Vector2(260.0, 0.0)
		_death_pos = _player.global_position
		_player.take_damage(9999.0, Vector2(320.0, 0.0), {}, false)

	if _frames == 60:
		_slid = _player.global_position.distance_to(_death_pos)
		for e in get_nodes_in_group(&"enemy_bodies"):
			if (e as Enemy).is_mourning():
				_mourners += 1
		_report()
		return true
	return false


func _report() -> void:
	var ok := true
	if _blood_after_kill < 1:
		print("FAIL: a death left no blood (%d splats)" % _blood_after_kill)
		ok = false
	if _blood_after_return < _blood_after_kill:
		print("FAIL: blood lost on re-entering the room (%d -> %d)"
			% [_blood_after_kill, _blood_after_return])
		ok = false
	if not _player.is_dead():
		print("FAIL: player not marked dead")
		ok = false
	if _slid < 20.0:
		print("FAIL: player died without sliding (%.1f px)" % _slid)
		ok = false
	if _mourners < 1:
		print("FAIL: nothing gathered around the body")
		ok = false
	if ok:
		print("OK: %d splats kept across a room rebuild, body slid %.1f px, %d mourners."
			% [_blood_after_return, _slid, _mourners])

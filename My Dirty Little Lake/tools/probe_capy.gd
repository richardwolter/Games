extends Node
## Watches the capybara pairs walk, frame by frame, and counts what reads as jiggle: a
## follower or lead switching between moving and resting pictures within half a second (the
## old count, under six frames, missed the quarter-second cycle of a walk given up and taken
## again), turning round (facing) and back, the view swapping side/front/back and back, and a
## step that reverses the last; and how close a capybara comes to its own partner and to any
## other animal (land animals, turtles and frogs out of the water): frames spent touching and
## times it came in. Two phases, counted apart:
##
##   bank  the pairs where the lake put them, four dogs about (`PHASE_BANK` frames);
##   isle  every pair put on the island's lawn close together, among the peacock, the
##         island's bunnies and the dogs, the angler walked through them and stood still by
##         turns (`PHASE_ISLE` frames).
##
##   godot --headless --path . --fixed-fps 60 res://tools/probe_capy.tscn
##
## Own save, under its own node. `tools/last_probe_capy.log`.

const LOG := "res://tools/last_probe_capy.log"
const SAVE_PATH := "user://probe_capy.save"
const SETTLE := 2400
const PHASE_BANK := 1800
const PHASE_ISLE := 3600
## Nearer than this to its partner, or to another animal, counts as touching: world px on
## the ground's plane (the screen's y doubled, the iso tiles' 2:1), so a capybara a body
## behind another is as far from it as one a body beside it.
const PARTNER_CLOSE := 22.0
const OTHER_CLOSE := 22.0
var _main: Node
var _frames := 0
var _log: FileAccess
var _last := {}
var _counts := {}
var _start_ms := 0
var _phase := "bank"


func _ready() -> void:
	_start_ms = Time.get_ticks_msec()
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	add_child.call_deferred(_main)
	_log = FileAccess.open(LOG, FileAccess.WRITE)


func _physics_process(_delta: float) -> void:
	_frames += 1
	if Time.get_ticks_msec() - _start_ms > 900000:
		get_tree().quit(2)
		return
	if _main == null or not _main.is_inside_tree():
		return
	if _frames == 6:
		_clean()
	if _frames == 30:
		# Four dogs, so the island has a pack running about it.
		for n in 3:
			_main._add_dog()
	if _frames < SETTLE:
		return
	var wild: Wildlife = _main.get(&"_wildlife")
	var t := _frames - SETTLE
	if t == PHASE_BANK:
		_phase = "isle"
		_last.clear()
		_to_the_island(wild)
	if t >= PHASE_BANK + PHASE_ISLE:
		var keys := _counts.keys()
		keys.sort()
		for k in keys:
			_log.store_line("%s: %s" % [k, _counts[k]])
		_log.close()
		get_tree().quit()
		return
	if _phase == "isle":
		_walk_the_angler(t - PHASE_BANK, wild)
	var i := 0
	for c: Dictionary in wild.land_animals():
		if c["kind"] != &"capy":
			continue
		var who := "%s%d" % ["F" if c.has("lead") else "L", i]
		i += 1
		_watch(who, c, wild)


func _watch(who: String, c: Dictionary, wild: Wildlife) -> void:
	var frame: String = wild._land_frame(c)
	var moving := frame.contains("walk") or frame.contains("run")
	var at: Vector2 = c["at"]
	var was: Dictionary = _last.get(who, {})
	var role := who.substr(0, 1)
	if not was.is_empty():
		var step := at - (was["at"] as Vector2)
		var prev_step: Vector2 = was["step"]
		if step.length() > 0.01 and prev_step.length() > 0.01 and step.dot(prev_step) < 0.0:
			_bump(role, "step reversed")
		if bool(was["moving"]) != moving:
			if _frames - int(was["moving_at"]) < 30:
				_bump(role, "move/rest flip within 0.5 s")
			was["moving_at"] = _frames
		if float(was["facing"]) != float(c["facing"]):
			if _frames - int(was["facing_at"]) < 20:
				_bump(role, "facing flip within 20 frames")
			was["facing_at"] = _frames
		if String(was["view"]) != String(c["view"]):
			if _frames - int(was["view_at"]) < 20:
				_bump(role, "view flip within 20 frames")
			was["view_at"] = _frames
		was["step"] = step if step.length() > 0.01 else prev_step
	else:
		was = {"moving_at": 0, "facing_at": 0, "view_at": 0, "step": Vector2.ZERO,
			"near_mate": false, "near_other": false}
	# Its partner: a follower's lead, or a lead's follower.
	var mate: Dictionary = c.get("lead", {})
	if mate.is_empty():
		for o: Dictionary in wild.land_animals():
			if o.get("lead") == c:
				mate = o
	var near_mate: bool = not mate.is_empty() and _plane(at, mate["at"]) < PARTNER_CLOSE
	if near_mate:
		_bump(role, "frames touching its partner")
		if not bool(was["near_mate"]):
			_bump(role, "times it came onto its partner")
	var near_other := false
	for o: Dictionary in wild.land_animals():
		if o == c or o == mate:
			continue
		if _plane(at, o["at"]) < OTHER_CLOSE:
			near_other = true
			_bump(role, "frames touching a " + String(o["kind"]) + (" (other pair)" if o["kind"] == &"capy" else ""))
	for tt: Dictionary in wild._turtles:
		if int(tt["state"]) != Wildlife.Turtle.UNDER and _plane(at, tt["at"]) < OTHER_CLOSE:
			near_other = true
			_bump(role, "frames touching a turtle")
	for f: Dictionary in wild._frogs:
		if int(f["state"]) != Wildlife.Frog.SWIM and _plane(at, f["at"]) < OTHER_CLOSE:
			near_other = true
			_bump(role, "frames touching a frog")
	if near_other:
		_bump(role, "frames touching another animal")
		if not bool(was["near_other"]):
			_bump(role, "times it came onto another animal")
	if OS.get_environment("PROBE_TRACE") != "" and who.begins_with("F"):
		_log.store_line("%d %s at %s st %d %s face %.0f view %s pose %s mate %.1f other %s lead %s lst %d lface %.0f keys %s" % [_frames, who,
			at, int(c["state"]), frame, float(c["facing"]), c["view"], c["pose"],
			_plane(at, mate["at"]) if not mate.is_empty() else -1.0, near_other,
			mate.get("at", Vector2.ZERO), int(mate.get("state", -1)), float(mate.get("facing", 0.0)),
			str([c.get("round_mate"), c.get("round_others"), c.get("heading"), c.get("wait"), c.get("held_t"), c.get("side")])])
	was["near_mate"] = near_mate
	was["near_other"] = near_other
	was["at"] = at
	was["moving"] = moving
	was["facing"] = float(c["facing"])
	was["view"] = String(c["view"])
	_last[who] = was
	_bump(role, "frames watched")


static func _plane(a: Vector2, b: Vector2) -> float:
	return ((a - b) * Vector2(1.0, 2.0)).length()


func _bump(role: String, k: String) -> void:
	var key := "%s %s %s" % [_phase, "follower" if role == "F" else "lead", k]
	_counts[key] = int(_counts.get(key, 0)) + 1


## Every pair onto the island's lawn, a lawn spot each, the spots chosen close together, as
## if all three had swum over at once; staying for good.
func _to_the_island(wild: Wildlife) -> void:
	var lawn: Array = wild._isle_lawn
	if lawn.is_empty():
		return
	var first: Vector2 = lawn[0]
	var near := lawn.duplicate()
	near.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.distance_to(first) < b.distance_to(first))
	var k := 0
	for c: Dictionary in wild.land_animals():
		if c["kind"] != &"capy" or c.has("lead"):
			continue
		var spot: Vector2 = near[mini(k * 2, near.size() - 1)]
		k += 1
		c["zone"] = "isle"
		c["at"] = spot
		c["to"] = spot
		c["home"] = spot
		c["path"] = []
		c["trip"] = false
		c["arriving"] = false
		c["wet"] = false
		c["fade"] = 1.0
		c["stay"] = wild._now + 100000.0
		c["spot"] = wild._isle_shore_near(spot)
		wild._rest(c)
		for f: Dictionary in wild._followers_of(c):
			f["at"] = spot + Vector2(Wildlife.CAPY_GAP, 0.0)
			f["zone"] = "isle"
			f["wet"] = false
			f["fade"] = 1.0
			wild._rest(f)
	_log.store_line("pairs on the island: %d, lawn spots %d" % [k, lawn.size()])


## The angler walked through the pairs: a second's walk to the next capybara's home and a
## second standing there, by turns. Set on its position, which is what the lake reads.
func _walk_the_angler(t: int, wild: Wildlife) -> void:
	var angler: Node2D = _main.get(&"_angler")
	if angler == null:
		return
	var leads: Array = wild.land_animals().filter(func(c: Dictionary) -> bool:
		return c["kind"] == &"capy" and not c.has("lead"))
	if leads.is_empty():
		return
	var leg := t / 120
	if t % 120 >= 60:
		return
	var a: Vector2 = (leads[leg % leads.size()] as Dictionary)["home"]
	var b: Vector2 = (leads[(leg + 1) % leads.size()] as Dictionary)["home"]
	angler.position = a.lerp(b, float(t % 120) / 60.0) + Vector2(0.0, 6.0)


func _clean() -> void:
	var grid: LakeGrid = _main.get(&"_grid")
	for index in grid.stacks.size():
		if grid.stacks[index].is_empty():
			continue
		var tile := grid.tile_of(index)
		var h := sin(float(tile.x) * 12.9898 + float(tile.y) * 78.233) * 43758.5453
		if (h - floor(h)) >= 0.03:
			grid.stacks[index] = PackedInt32Array()
	grid._rebuild()
	_main._build_filth_map()
	var wild: Wildlife = _main.get(&"_wildlife")
	wild.refresh(_main.clean_share(), _main.get(&"_clean_tiles"), 0.95)
	wild._reckon()

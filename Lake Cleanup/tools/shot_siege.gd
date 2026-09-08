## Runs the siege for a moment and saves what it looks like.
##
## The headless harness can prove the swarm swims and the box fires in order; it cannot say
## whether a shield dome, a lit net and a ring of monsters read as anything at all. This
## opens the real second-lake scene in a real window, sets up one readable moment of it, and
## writes a frame.
##
##   godot --path . res://tools/shot_siege.tscn
extends Node

const SETTLE_FRAMES := 40
const OUT_PATH := "res://tools/shot_siege.png"

## A save of its own that is never written, so the shot is always of a fresh siege.
const SAVE_PATH := "user://shot_siege.save"

var _main: Node2D
var _frames: int = 0


func _ready() -> void:
	_main = load("res://scenes/siege.tscn").instantiate()
	_main.set(&"save_path", SAVE_PATH)
	_main.set(&"autoload_save", false)
	add_child(_main)


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2:
		_stage()
		return
	if _frames < SETTLE_FRAMES:
		return
	var shot := get_viewport().get_texture().get_image()
	shot.save_png(ProjectSettings.globalize_path(OUT_PATH))
	get_tree().quit()


## One moment of a siege, arranged rather than waited for: a ring of monsters at the
## island, a shield up, a charm of each kind on the water, and a lit net lying where it was
## thrown.
func _stage() -> void:
	var camera := _main.get_node(^"Camera") as Camera2D
	var angler := _main.get_node(^"Angler") as Angler
	var net := _main.get_node(^"Net") as CastNet
	var swarm := _main.get_node(^"Swarm") as SludgeSwarm
	var charms := _main.get_node(^"Charms") as CharmField
	var box := _main.get_node(^"Box") as CharmBox
	var laid := _main.get_node(^"LaidNets") as LaidNet
	var ward := _main.get_node(^"Ward") as Ward

	_main.set(&"_view_zoom", 0.95)
	camera.zoom = Vector2(0.95, 0.95)

	ward.add_shield(Ward.SHIELD_PER * 2.0)
	ward.health = Ward.HEALTH * 0.6
	for kind in 4:
		box.put(kind)
	box.running = false

	# Monsters round the island, one of them frozen and one of them burning, so all three
	# states of a blob are in the picture.
	for i in 7:
		var angle := TAU * float(i) / 7.0
		swarm.add_blob(2, angle)
		var blob: Dictionary = swarm.blobs[swarm.blobs.size() - 1]
		blob["tile"] = Iso.ISLAND_CENTRE + Vector2(cos(angle), sin(angle)) * 6.5
		if i == 1:
			blob["chill"] = 1.0
		if i == 2:
			blob["burn"] = 1.0
			blob["health"] = float(blob["whole"]) * 0.4

	# The four yards at work, each at a different point in its job: one nearly ready, one
	# halfway, and two charms caught mid-rise out of the water.
	charms.making = true
	var clocks := PackedFloat32Array([0.4, 2.2, 4.6, 6.4])
	charms.set(&"_next", clocks)
	# Two of them coming up in view. Their yards are out on the bank, well outside a shot
	# framed on the island, so these are started near it instead — what is being looked at
	# here is the rise itself.
	charms.add_charm(CharmField.Kind.SHIELD, Iso.ISLAND_CENTRE + Vector2(7.5, -1.0))
	charms.add_charm(CharmField.Kind.AMMO, Iso.ISLAND_CENTRE + Vector2(-2.0, 7.0))
	# Wound forward by hand so the shot catches them on the way up rather than settled.
	for i in charms.charms.size():
		var rising: Dictionary = charms.charms[i]
		rising["rise"] = 0.30 + 0.35 * float(i)
		var out: Vector2 = rising["drift"]
		rising["tile"] = (rising["born"] as Vector2) + out * float(rising["rise"])

	# The net is lit and in the angler's hands, and three casts of it are out on the water:
	# one burning, one freezing, one doing both. That is the picture the mechanic is for.
	net.enchant(CastNet.Charm.FIRE, 60.0)
	net.enchant(CastNet.Charm.ICE, 60.0)
	var out := (angler.tile_pos - Iso.ISLAND_CENTRE).normalized()
	if out.length() < 0.001:
		out = Vector2(0.0, 1.0)
	var reach := net.field_radius()
	laid.lay(angler.tile_pos + out * 3.5, reach, true, true)
	laid.lay(angler.tile_pos + out.rotated(2.1) * 5.0, reach, true, false)
	laid.lay(angler.tile_pos + out.rotated(-2.1) * 5.0, reach, false, true)

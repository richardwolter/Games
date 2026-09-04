extends SceneTree

## Headless smoke test for the items that carry BEHAVIOUR rather than just
## numbers -- the grafted arms, the thrown scalpel, the freeze status. The
## pipeline test proves they resolve; this one proves the code that reads the
## resolved channels does not crash when it actually runs.
##
## Run: <godot> --headless --script tools/test_items.gd

const BEHAVIOUR_ITEMS: PackedStringArray = [
	"res://items/arm_mutation.tres",
	"res://items/scalpelrang.tres",
	"res://items/broken_needle.tres",
	"res://items/liquid_nitrogen.tres",
]

var _frames: int = 0
var _player: Player


func _initialize() -> void:
	var main := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	# Weapons spawn their shots under current_scene. Adding a scene by hand does
	# not set that, and every fire would fail on a null parent.
	current_scene = main
	_player = main.get_node("Player") as Player


func _process(_delta: float) -> bool:
	_frames += 1

	# Two of everything, because the requirement is that they stack.
	if _frames == 5 or _frames == 10:
		for path in BEHAVIOUR_ITEMS:
			_player.grant(load(path) as Item)

	if _frames == 20:
		print(_player.loadout.describe())
		# The run starts in the entry wound, which is empty by design -- and a
		# melee weapon with nothing to hit never runs any of its own code. Put
		# something in front of him so the throw path is actually exercised.
		var dummy := (load("res://scenes/enemy.tscn") as PackedScene).instantiate() as Enemy
		dummy.max_health = 9999.0
		dummy.move_speed = 0.0
		dummy.contact_damage = 0.0
		dummy.global_position = _player.global_position + Vector2(150.0, 0.0)
		current_scene.add_child(dummy)

	if _frames == 120:
		var thrown := 0
		for n in current_scene.get_children():
			if n is ThrownBlade:
				thrown += 1
		print("blades in flight: %d" % thrown)
		assert(thrown > 0, "Scalpelrang never threw anything")

	if _frames >= 400:
		print("OK: behaviour items survived %d frames stacked twice." % _frames)
		return true
	return false

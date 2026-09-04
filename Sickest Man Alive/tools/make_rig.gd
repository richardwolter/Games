extends SceneTree

## Builds a cutout puppet scene from a parts.json produced by
## _pipeline/tools/split_parts.ps1. Run:
##   godot --headless --path . --script res://tools/make_rig.gd
##
## SceneTree, not EditorScript, to match tools/test_pipeline.gd and
## tools/print_body.gd -- and because an EditorScript can only be launched from
## the editor GUI, which makes it unrunnable from a script or a check.
##
## Regenerating is meant to be cheap and lossless: the art can be re-cut and the
## rig rebuilt without hand-fixing anything, which is the whole reason the rig is
## generated rather than assembled by hand in the editor. Anything you tweak by
## hand in the output scene WILL be lost on the next run -- put changes in
## parts.json or here.
##
## Why Sprite2D nodes and not Skeleton2D/Polygon2D: Polygon2D buys mesh
## deformation, paid for with hand-painted vertex weights per part per character,
## and that work is destroyed every time the art is regenerated. Rigid parts read
## the same for a paper-puppet cartoon and survive a re-cut. See ART_BIBLE.md.

const PARTS_JSON := "res://art/parts/kid/parts.json"
const PARTS_DIR := "res://art/parts/kid/"
const OUT_SCENE := "res://scenes/rigs/kid.tscn"
const SHADER := "res://src/rig_tint.gdshader"

## On-screen height in pixels. The sprite is generated at ~1000px; the game draws
## it at a fraction of that. Below ~96px the face stops reading -- see
## ART_BIBLE.md, "On-screen size, and why it is not the hurtbox". This is NOT
## Player.BASE_RADIUS (14): the hurtbox is tuned for how dodging feels and the
## art has no business changing it.
const TARGET_HEIGHT := 104.0


func _initialize() -> void:
	_build()
	quit()


func _build() -> void:
	var data := _load_parts()
	if data.is_empty():
		return

	var source_size: Vector2 = Vector2(data["source_size"][0], data["source_size"][1])
	# Origin at the feet, centred horizontally: the character stands ON its
	# position, so placing the rig at a floor point Just Works and the sprite
	# does not sink into geometry when scaled.
	var origin := Vector2(source_size.x * 0.5, source_size.y)

	var root := Node2D.new()
	root.name = "KidRig"
	root.scale = Vector2.ONE * (TARGET_HEIGHT / source_size.y)
	root.material = _make_material()

	var nodes := {}
	var anchors := {}
	var zs := {}

	# parts.json is ordered back-to-front, and z is explicit anyway, but parents
	# must exist before children. Two passes rather than assuming an order.
	for part: Dictionary in data["parts"]:
		anchors[part["name"]] = Vector2(part["anchor"][0], part["anchor"][1])
		zs[part["name"]] = int(part["z"])

	for part: Dictionary in data["parts"]:
		var name_: String = part["name"]
		var tex_path: String = PARTS_DIR + str(part["file"])
		var tex: Texture2D = load(tex_path)
		if tex == null:
			push_error("make_rig: missing texture %s (has Godot imported art/? open the editor once)" % tex_path)
			return

		# Each part is a transform node with its artwork as a CHILD, rather than a
		# Sprite2D doing both jobs. The two need to move independently: turning
		# the body flips the torso's picture horizontally, and if the picture and
		# the joint were the same node that flip would take the arms and legs
		# with it and swap which side he holds each weapon on.
		var joint := Node2D.new()
		joint.name = name_

		var spr := Sprite2D.new()
		spr.name = "art"
		spr.texture = tex
		# centered=false plus offset=-pivot puts the authored joint exactly on the
		# node's origin, so rotation happens about the joint instead of about the
		# middle of the image. This is the entire point of carrying pivots
		# through from the splitter.
		spr.centered = false
		spr.offset = -Vector2(part["pivot"][0], part["pivot"][1])
		# Inherit the root's ShaderMaterial so tint/status/flash are one uniform
		# write instead of six.
		spr.use_parent_material = true
		joint.add_child(spr)
		nodes[name_] = joint

	# Parent everything, positioning each part by the difference between its own
	# joint and its parent's, which reconstructs the source pose exactly.
	for part: Dictionary in data["parts"]:
		var name_: String = part["name"]
		var parent_name: String = str(part["parent"])
		var spr: Node2D = nodes[name_]
		if parent_name == "root":
			root.add_child(spr)
			spr.position = anchors[name_] - origin
			spr.z_index = zs[name_]
		else:
			if not nodes.has(parent_name):
				push_error("make_rig: part '%s' names unknown parent '%s'" % [name_, parent_name])
				return
			(nodes[parent_name] as Node2D).add_child(spr)
			spr.position = anchors[name_] - anchors[parent_name]
			# z_index is RELATIVE to the parent (z_as_relative defaults true), so
			# the absolute order in parts.json has to be rebased. Set it directly
			# and the legs -- z 0 and 1 under a torso at 3 -- resolve to 3 and 4
			# and draw in FRONT of the torso, which is the opposite of what the
			# paint order says. Anything meant to sit behind its parent needs a
			# negative index.
			spr.z_index = zs[name_] - zs[parent_name]

	_add_attachments(data, nodes)

	var anim := AnimationPlayer.new()
	anim.name = "AnimationPlayer"
	root.add_child(anim)
	var lib := AnimationLibrary.new()
	lib.add_animation("idle", _anim_idle(nodes))
	lib.add_animation("run", _anim_run(nodes))
	lib.add_animation("hit", _anim_hit(nodes))
	anim.add_animation_library("", lib)
	anim.autoplay = "idle"

	# Every node must be owned by the scene root or PackedScene silently drops it.
	_own_all(root, root)

	var packed := PackedScene.new()
	if packed.pack(root) != OK:
		push_error("make_rig: pack failed")
		return
	DirAccess.make_dir_recursive_absolute(OUT_SCENE.get_base_dir())
	var err := ResourceSaver.save(packed, OUT_SCENE)
	if err != OK:
		push_error("make_rig: save failed (%d)" % err)
		return
	print("make_rig: wrote %s  (%d parts, %.3f scale)" % [OUT_SCENE, nodes.size(), root.scale.x])
	# The tree was built by hand and never entered the SceneTree, so nothing else
	# will free it. Without this the run ends in a wall of leaked-RID errors that
	# would hide a real one.
	root.free()
	_verify(data)


## Loads what was just written and checks it. Packing can succeed while producing
## a scene that is wrong in ways the build code cannot see -- a track pointing at
## a node path that does not resolve, or a part left unowned and silently
## dropped. Cheap to check here, expensive to notice as a missing limb later.
func _verify(data: Dictionary) -> void:
	var packed: PackedScene = load(OUT_SCENE)
	if packed == null:
		push_error("make_rig: VERIFY failed - saved scene will not load")
		return
	var inst: Node = packed.instantiate()
	var problems: Array[String] = []

	var expected: int = (data["parts"] as Array).size()
	var found := 0
	for part: Dictionary in data["parts"]:
		if inst.find_child(str(part["name"]), true, false) == null:
			problems.append("part '%s' missing from the saved scene" % part["name"])
		else:
			found += 1

	var ap := inst.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if ap == null:
		problems.append("AnimationPlayer missing")
	else:
		for wanted in ["idle", "run", "hit"]:
			if not ap.has_animation(wanted):
				problems.append("animation '%s' missing" % wanted)
				continue
			# A track whose path does not resolve fails silently at runtime: the
			# animation plays and simply moves nothing.
			var a := ap.get_animation(wanted)
			for i in a.get_track_count():
				var p := a.track_get_path(i)
				var target := inst.get_node_or_null(NodePath(p.get_concatenated_names()))
				if target == null:
					problems.append("%s: track path '%s' does not resolve" % [wanted, p])

	inst.free()

	if problems.is_empty():
		print("make_rig: verified - %d/%d parts, 3 animations, all track paths resolve" % [found, expected])
	else:
		for p in problems:
			push_error("make_rig: VERIFY %s" % p)


## Held weapons. Separate art parented to a hand, because the arms swing a full
## 360 degrees to follow the aim and a weapon painted into the arm texture could
## never do that.
func _add_attachments(data: Dictionary, nodes: Dictionary) -> void:
	if not data.has("attachments"):
		return
	for att: Dictionary in data["attachments"]:
		var parent_name: String = str(att["parent"])
		if not nodes.has(parent_name):
			push_error("make_rig: attachment '%s' hangs off unknown part '%s'" % [att["name"], parent_name])
			continue
		var tex: Texture2D = load("res://" + str(att["file"]))
		if tex == null:
			push_error("make_rig: missing weapon texture res://%s" % att["file"])
			continue

		var spr := Sprite2D.new()
		spr.name = str(att["name"])
		spr.texture = tex
		spr.centered = false
		# pivot is normalised to the weapon image: the point on the grip that
		# sits in the hand.
		var piv := Vector2(float(att["pivot"][0]) * tex.get_width(),
			float(att["pivot"][1]) * tex.get_height())
		spr.offset = -piv
		spr.position = Vector2(att["grip"][0], att["grip"][1])
		# The art points RIGHT and the arms hang DOWN, so this is +PI/2. It is
		# authored rather than assumed, because a weapon drawn at any other
		# resting angle would otherwise be silently off by the difference.
		spr.rotation = float(att["rotation"])
		spr.scale = Vector2.ONE * float(att["scale"])
		spr.z_index = int(att["z"])
		spr.use_parent_material = true
		(nodes[parent_name] as Node2D).add_child(spr)

		# Children sit at the sprite's origin, which `offset` has already moved to
		# the grip -- so the muzzle is measured from there.
		if att.has("muzzle"):
			var m := Marker2D.new()
			m.name = "Muzzle"
			m.position = Vector2(float(att["muzzle"][0]) * tex.get_width(),
				float(att["muzzle"][1]) * tex.get_height()) - piv
			spr.add_child(m)


func _load_parts() -> Dictionary:
	if not FileAccess.file_exists(PARTS_JSON):
		push_error("make_rig: %s not found - run _pipeline/tools/split_parts.ps1 first" % PARTS_JSON)
		return {}
	var text := FileAccess.get_file_as_string(PARTS_JSON)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("make_rig: %s is not valid JSON" % PARTS_JSON)
		return {}
	return parsed as Dictionary


func _make_material() -> ShaderMaterial:
	var shader: Shader = load(SHADER)
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("tint", Color.WHITE)
	mat.set_shader_parameter("status_tint", Color(0.6, 0.2, 0.8))
	mat.set_shader_parameter("status_amount", 0.0)
	mat.set_shader_parameter("flash", 0.0)
	return mat


func _own_all(node: Node, owner_: Node) -> void:
	for child in node.get_children():
		child.owner = owner_
		_own_all(child, owner_)


## Node path from the rig root, which is what AnimationPlayer resolves against.
func _path_of(nodes: Dictionary, name_: String) -> String:
	var parts: Array[String] = []
	var n: Node = nodes[name_]
	while n != null and not (n is Node2D and n.name == "KidRig"):
		parts.push_front(str(n.name))
		n = n.get_parent()
	return "/".join(parts)


func _track(anim: Animation, path: String, keys: Array) -> void:
	var t := anim.add_track(Animation.TYPE_VALUE)
	anim.track_set_path(t, NodePath(path))
	anim.track_set_interpolation_type(t, Animation.INTERPOLATION_CUBIC)
	for k: Array in keys:
		anim.track_insert_key(t, k[0], k[1])


## Breathing sway. Offsets are in SOURCE pixels, not screen pixels -- the root is
## scaled by ~0.13, so a 2px screen bob needs ~15px here.
func _anim_idle(nodes: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = 1.6
	a.loop_mode = Animation.LOOP_LINEAR

	var torso: Node2D = nodes["torso"]
	var tp := torso.position
	_track(a, _path_of(nodes, "torso") + ":position",
		[[0.0, tp], [0.8, tp + Vector2(0, -14)], [1.6, tp]])
	_track(a, _path_of(nodes, "head") + ":rotation",
		[[0.0, 0.0], [0.8, -0.035], [1.6, 0.0]])
	# NO ARM TRACKS. Both arms are driven every frame by Player to follow the aim
	# through a full 360 degrees, and an animation writing the same property
	# would just be overwritten -- or worse, win intermittently and make the aim
	# jitter. Arms belong to gameplay code now, not to the animation.
	return a


## A run towards the camera, which is a different animation from a run across
## the screen -- see the leg tracks below for why rotation is the wrong tool
## here. The body drives up on each plant and rocks side to side, because
## running is not tidy. 0.5s per stride, about four steps a second.
func _anim_run(nodes: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = 0.5
	a.loop_mode = Animation.LOOP_LINEAR

	var torso: Node2D = nodes["torso"]
	var tp := torso.position
	var lp: Vector2 = (nodes["leg_l"] as Node2D).position
	var rp: Vector2 = (nodes["leg_r"] as Node2D).position

	# Body rises on each plant and sways across -- two bobs, one sway.
	_track(a, _path_of(nodes, "torso") + ":position",
		[[0.0, tp + Vector2(5, 0)], [0.125, tp + Vector2(0, -26)],
		 [0.25, tp + Vector2(-5, 0)], [0.375, tp + Vector2(0, -26)],
		 [0.5, tp + Vector2(5, 0)]])
	_track(a, _path_of(nodes, "torso") + ":rotation",
		[[0.0, 0.045], [0.25, -0.045], [0.5, 0.045]])

	# LEGS: lift and foreshorten, do not swing.
	#
	# This is a FRONT view. Rotating a leg about its hip moves it sideways across
	# the screen, which is why a big swing reads as shuffling sideways rather
	# than running -- the motion is at ninety degrees to the direction he is
	# supposed to be travelling, which is into the screen.
	#
	# A run towards the camera reads through three things instead:
	#   lift      the knee comes up, so the whole leg rises,
	#   shorten   a raised leg is angled towards the viewer, so it foreshortens
	#             -- scale.y is doing the job perspective would,
	#   settle    the planted leg takes the weight and stretches slightly.
	# Rotation stays small, just enough to stop it looking mechanical.
	# position:y, not position. Turning to face right swaps the legs across the
	# body's centreline, so their X belongs to Player -- an animation writing the
	# whole vector would drag them back every frame and they would cross over
	# instead of both pointing the same way.
	_track(a, _path_of(nodes, "leg_l") + ":position:y",
		[[0.0, lp.y - 44.0], [0.25, lp.y + 4.0], [0.5, lp.y - 44.0]])
	_track(a, _path_of(nodes, "leg_l") + ":scale",
		[[0.0, Vector2(0.94, 0.72)], [0.25, Vector2(1.02, 1.04)], [0.5, Vector2(0.94, 0.72)]])
	_track(a, _path_of(nodes, "leg_l") + ":rotation",
		[[0.0, 0.13], [0.25, -0.05], [0.5, 0.13]])

	_track(a, _path_of(nodes, "leg_r") + ":position:y",
		[[0.0, rp.y + 4.0], [0.25, rp.y - 44.0], [0.5, rp.y + 4.0]])
	_track(a, _path_of(nodes, "leg_r") + ":scale",
		[[0.0, Vector2(1.02, 1.04)], [0.25, Vector2(0.94, 0.72)], [0.5, Vector2(1.02, 1.04)]])
	_track(a, _path_of(nodes, "leg_r") + ":rotation",
		[[0.0, -0.05], [0.25, 0.13], [0.5, -0.05]])

	# No arm tracks -- see _anim_idle. Head counter-rotates against the rock,
	# which is what keeps the face level and reads as effort rather than wobble.
	_track(a, _path_of(nodes, "head") + ":rotation",
		[[0.0, -0.05], [0.25, 0.05], [0.5, -0.05]])
	return a


## Damage. Drives the shader uniform on the rig root rather than a modulate, so
## it survives being inherited by all six parts.
func _anim_hit(nodes: Dictionary) -> Animation:
	var a := Animation.new()
	a.length = 0.24
	a.loop_mode = Animation.LOOP_NONE
	_track(a, ".:material:shader_parameter/flash",
		[[0.0, 1.0], [0.08, 1.0], [0.24, 0.0]])
	# A squash sells the impact harder than colour alone. Applied to the torso,
	# never to the rig root: the root's scale is the sprite-size conversion and
	# Player also multiplies it by stats.size_scale, so animating it absolutely
	# would fight both.
	_track(a, _path_of(nodes, "torso") + ":scale",
		[[0.0, Vector2.ONE], [0.06, Vector2(1.12, 0.9)], [0.24, Vector2.ONE]])
	return a

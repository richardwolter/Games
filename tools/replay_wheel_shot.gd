## Runs a crossing, replays it, and photographs the puppet truck close up while
## checking its wheels against the recording.
##
##   godot --script tools/replay_wheel_shot.gd -- --sandbox=0 --money=9000
##
## The replay's wheels are the one part of the puppet truck that is neither
## simulated nor parented to what it follows: the chassis is written to directly,
## the wheels are written to separately, and the axles between them are cut. So
## this compares where they end up against the numbers in the recording rather
## than trusting the picture.
extends SceneTree


func _initialize() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	for i in 90:
		await process_frame

	var main := _find(get_root(), "main")
	var hud := _find(get_root(), "hud")
	var crossing: CrossingManager = main.get(&"_crossing")
	var spawner: Node = main.get(&"_spawner")
	var levels: LevelManager = main.get(&"_levels")
	var camera: Camera2D = main.get_node(^"World/Camera")
	var area: Rect2 = spawner.spawn_area

	var plank: ObjectDef = levels.level.shop_pool[0]
	for i in 26:
		spawner.spawn(plank, Vector2(area.get_center().x - 940.0 + i * 76.0, 150.0))
	for i in 240:
		await process_frame

	crossing.start_crossing()
	var guard := 0
	while crossing.is_running and guard < 2400:
		await process_frame
		guard += 1
	for i in 30:
		await process_frame

	var recorder: AttemptRecorder = main.get(&"_recorder")
	print("recorded %d frames, cast %d, car at %d" % [
		recorder.frames.size(), recorder.cast.size(), recorder.car_index()
	])

	hud.emit_signal(&"replay_requested", false)
	for i in 5:
		await process_frame

	var replay: ReplayPlayer = main.get(&"_replay")
	var car: Car = replay.get(&"_car")
	if car == null:
		printerr("replay built no truck")
		quit(1)
		return
	var back: Node2D = car.get_node(^"WheelBack")
	var front: Node2D = car.get_node(^"WheelFront")

	for shot in 4:
		for i in 26:
			camera.zoom = Vector2(2.2, 2.2)
			camera.position = car.chassis.global_position
			await process_frame
		# What the recording says the three bodies should be at, right now.
		var at := replay.elapsed * AttemptRecorder.SAMPLE_HZ
		var frame: PackedFloat32Array = recorder.frames[clampi(
			int(at), 0, recorder.frames.size() - 1
		)]
		var k := recorder.car_index() * AttemptRecorder.STRIDE
		print("shot %d  t=%.2f" % [shot, replay.elapsed])
		print("   chassis want (%.0f,%.0f) got (%.0f,%.0f)" % [
			frame[k], frame[k + 1],
			car.chassis.global_position.x, car.chassis.global_position.y])
		print("   back    want (%.0f,%.0f) got (%.0f,%.0f)  rot want %.2f got %.2f" % [
			frame[k + 4], frame[k + 5], back.global_position.x, back.global_position.y,
			frame[k + 6], back.global_rotation])
		print("   front   want (%.0f,%.0f) got (%.0f,%.0f)" % [
			frame[k + 8], frame[k + 9], front.global_position.x, front.global_position.y])
		get_root().get_texture().get_image().save_png(
			ProjectSettings.globalize_path("res://tools/_rwheel_%d.png" % shot)
		)
	quit()


func _find(node: Node, script_file: String) -> Node:
	var script := node.get_script() as Script
	if script != null and script.resource_path.get_file() == script_file + ".gd":
		return node
	for child: Node in node.get_children():
		var hit := _find(child, script_file)
		if hit != null:
			return hit
	return null

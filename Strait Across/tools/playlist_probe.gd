extends SceneTree

## Headless check that level 4 cycles its two tracks and other levels still
## play a single looping one. Run:
##   godot --headless --script tools/playlist_probe.gd
func _init() -> void:
	await process_frame
	var audio: Node = root.get_node("Audio")

	audio.set_level_music(3)
	print("level 4 first: ", audio._track)
	audio._on_finished(audio._active)
	print("level 4 second: ", audio._track)
	audio._on_finished(audio._active)
	print("level 4 wraps: ", audio._track)

	audio.set_level_music(4)
	print("level 5 first: ", audio._track)
	audio._on_finished(audio._active)
	print("level 5 second: ", audio._track)
	audio._on_finished(audio._active)
	print("level 5 wraps: ", audio._track)

	audio.set_level_music(5)
	print("level 6 first: ", audio._track)
	audio._on_finished(audio._active)
	print("level 6 second: ", audio._track)
	audio._on_finished(audio._active)
	print("level 6 wraps: ", audio._track)

	audio.set_level_music(2)
	print("level 3: ", audio._track, " playlist empty: ", audio._playlist.is_empty())

	# The join itself: seek to just before the end of a playlist track and check
	# that the next one is already playing before this one has run out. Both
	# players sounding at once is the whole point — that is the overlap.
	audio.set_level_music(5)
	var first: String = audio._track
	var outgoing: int = audio._active
	var player: AudioStreamPlayer = audio._players[outgoing]
	player.play(player.stream.get_length() - 0.3)
	await process_frame
	await process_frame
	print("join advanced: ", audio._track != first, " overlapping: ",
		player.playing and audio._players[audio._active].playing)
	quit()

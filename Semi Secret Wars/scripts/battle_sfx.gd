class_name BattleSfx
## Static one-shot SFX helpers, the audio counterpart to BattleFX.
##
## Every sound in this game had been hand-rolled at its call site (Hero's
## sword/death sounds, Projectile's hit sound) — always the same five lines:
## make an AudioStreamPlayer, set PROCESS_MODE_ALWAYS, parent it to root, play,
## free it when done. Three more ability sounds (Designer, 2026-07-25: Stomp
## shout, Verdant Break, Arrow Barrage) made that duplication worth collapsing.
##
## Two conventions matter and are easy to get wrong by hand:
##  * PROCESS_MODE_ALWAYS — the default PAUSABLE freezes a clip mid-playback if
##    a pick screen or results popup pauses the tree, and since the player is
##    parented to root (which survives scene changes) it would then resume
##    audibly in the NEXT scene (Designer, 2026-07-25: "death sound flowing to
##    prep menu").
##  * Parented to root, not the caster — abilities routinely outlive or free
##    the node that triggered them mid-clip.
##
## Nothing here plays during headless balance sweeps.

static func _headless() -> bool:
	return Engine.get_main_loop() == null or RunState.headless

## Creates the shared one-shot player. Returns null when headless / no tree.
static func _make_player(caller: Node, stream: AudioStream, volume_db := 0.0) -> AudioStreamPlayer:
	if stream == null or _headless() or caller == null or not caller.is_inside_tree():
		return null
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	caller.get_tree().root.add_child(player)
	return player

## Plays `stream` once from `start`, optionally stopping after `duration`
## seconds (duration <= 0 plays to the end of the file). Used for clips where
## only a slice of the source file is the sound we want — e.g. a shout that
## sits between two timestamps in a longer recording. `volume_db` is an offset
## from the file's own level (0 = as recorded, negative = quieter).
static func play_clip(caller: Node, stream: AudioStream, start := 0.0, duration := 0.0,
		volume_db := 0.0) -> void:
	var player := _make_player(caller, stream, volume_db)
	if player == null:
		return
	player.play(start)
	if duration <= 0.0:
		player.finished.connect(player.queue_free)
		return
	# Freed on the timer rather than on `finished`, since we're cutting the clip
	# short — `finished` would only fire at the end of the whole file.
	var t := caller.get_tree().create_timer(duration)
	t.timeout.connect(func():
		if is_instance_valid(player):
			player.stop()
			player.queue_free())

## Plays the whole of `stream` `times` times back to back (each repeat starts
## when the previous one ends, so this stretches over `times` * clip length).
static func play_repeats(caller: Node, stream: AudioStream, times: int, volume_db := 0.0) -> void:
	if times <= 0:
		return
	var player := _make_player(caller, stream, volume_db)
	if player == null:
		return
	# The remaining-plays counter lives in metadata, NOT a captured local:
	# GDScript lambdas capture by value, so reassigning a captured local never
	# reaches the outer variable — the counter would stay at its initial value
	# and the clip would repeat forever.
	player.set_meta("plays_left", times - 1)
	player.finished.connect(func():
		if not is_instance_valid(player):
			return
		var left: int = player.get_meta("plays_left", 0)
		if left > 0:
			player.set_meta("plays_left", left - 1)
			player.play()
		else:
			player.queue_free())
	player.play()

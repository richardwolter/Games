## Measures the silence at the front of each one-shot, and prints it.
##
##   godot --display-driver headless --script tools/find_sound_offsets.gd
##
## A sound cut with a little silence before the transient plays late: the click
## you hear happens some milliseconds after the button went down, which reads as
## the game being sluggish rather than as the file being padded. Nothing in the
## MP3 importer trims it, and there is no ffmpeg on this machine, so the fix is
## to start playback past the padding — which needs a number.
##
## This gets it by listening. The stream is played onto a bus carrying an
## AudioEffectCapture, the captured frames are scanned for the first one that is
## audibly above zero, and its position is the padding. Paste the printed value
## into Audio.SOUND_OFFSETS.
##
## Run it again if a sound is recut. It needs a real audio device — hence
## --display-driver headless rather than --headless, which has no mixer.
extends SceneTree

## Amplitude counted as the start of the sound. Above the noise floor of a quiet
## recording, below anything a listener would call audible.
const THRESHOLD := 0.02
## How long to listen before giving up on a file.
const LISTEN_SECONDS := 3.0
## Trimmed slightly shy of the measured transient, so the attack is never clipped
## — losing the first millisecond of a click is more noticeable than the delay.
const SAFETY := 0.008


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var audio := root.get_node_or_null(^"/root/Audio")
	if audio == null:
		print("no Audio autoload")
		quit()
		return

	var probe := _make_probe_bus()
	var capture: AudioEffectCapture = AudioServer.get_bus_effect(probe, 0)
	var player := AudioStreamPlayer.new()
	player.bus = &"Probe"
	root.add_child(player)

	for name: StringName in audio.SOUNDS:
		var path: String = audio.SOUNDS[name]
		if not ResourceLoader.exists(path):
			print("%-14s missing" % name)
			continue
		var offset := await _measure(player, capture, load(path) as AudioStream)
		if offset < 0.0:
			print("%-14s no audible transient found" % name)
		else:
			print("%-14s silence %.3f s  ->  offset %.3f" % [
				name, offset, maxf(offset - SAFETY, 0.0)
			])
	quit()


## A bus that exists only to be listened to. Its output still reaches Master, so
## the run is briefly audible; muting it would zero the capture as well.
func _make_probe_bus() -> int:
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, "Probe")
	AudioServer.add_bus_effect(index, AudioEffectCapture.new())
	return index


func _measure(
	player: AudioStreamPlayer, capture: AudioEffectCapture, stream: AudioStream
) -> float:
	capture.clear_buffer()
	player.stream = stream
	player.play()

	var rate := AudioServer.get_mix_rate()
	var scanned := 0
	var deadline := int(LISTEN_SECONDS * rate)
	while scanned < deadline:
		await process_frame
		var frames := capture.get_frames_available()
		if frames <= 0:
			if not player.playing:
				break
			continue
		var buffer := capture.get_buffer(frames)
		for i in buffer.size():
			var sample: Vector2 = buffer[i]
			if absf(sample.x) > THRESHOLD or absf(sample.y) > THRESHOLD:
				player.stop()
				return float(scanned + i) / rate
		scanned += buffer.size()
	player.stop()
	return -1.0

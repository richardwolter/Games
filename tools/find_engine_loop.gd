## Finds the frame the engine loop should restart from, and prints it.
##
##   godot --headless --script tools/find_engine_loop.gd
##
## Run this if the engine recording is ever replaced or its loop window moved,
## then paste the printed frame counts into Audio.ENGINE_LOOP_BEGIN_FRAMES and
## Audio.ENGINE_LOOP_END_FRAMES.
##
## Why this is a tool and not something audio.gd does on startup: it is a brute
## force search, it takes over twenty seconds in GDScript, and it produces the
## same number every time for a file that never changes. Doing it at load froze
## the game for those twenty seconds before the title screen appeared.
extends SceneTree

const ENGINE := "res://audio/Truck_Acceleration.wav"
## The window to loop, as read off the waveform. This search only refines where
## inside it the splice lands.
const LOOP_BEGIN := 0.77
const LOOP_END := 1.04
## How far either side of LOOP_BEGIN the splice may be nudged, and how much
## waveform either side of the join has to agree, both in seconds.
const SEARCH := 0.035
const WINDOW := 0.006


func _initialize() -> void:
	var sample := load(ENGINE) as AudioStreamWAV
	if sample == null:
		print("No sample at %s" % ENGINE)
		quit()
		return
	if sample.format != AudioStreamWAV.FORMAT_16_BITS:
		print("Sample is not 16-bit PCM (format %d) — set compress/mode=0 on the import."
			% sample.format)
		quit()
		return

	var rate := float(sample.mix_rate)
	var loop_end := int(LOOP_END * rate)
	var wanted := int(LOOP_BEGIN * rate)
	var frame := _best_loop_begin(sample, wanted, loop_end)

	print("engine loop: %d frames (%.5f s), moved %+.2f ms, loop is %.1f ms long" % [
		frame, float(frame) / rate,
		float(frame - wanted) * 1000.0 / rate,
		float(loop_end - frame) * 1000.0 / rate,
	])
	# Frames, not the seconds above. Seconds rounded to five decimals and turned
	# back into a frame with int() lands one frame short of this one, and that one
	# frame is the step in the waveform that is heard as a tick on every pass.
	print("  -> const ENGINE_LOOP_BEGIN_FRAMES := %d" % frame)
	print("  -> const ENGINE_LOOP_END_FRAMES := %d" % loop_end)
	quit()


## The candidate whose preceding few milliseconds best match the few before the
## join, which is the one that continues the waveform rather than interrupting
## it. A timestamp read off a display is accurate to a few milliseconds, and at
## engine frequencies that is most of a cycle — the resulting step in the signal
## is heard as a click on every pass.
func _best_loop_begin(sample: AudioStreamWAV, wanted: int, loop_end: int) -> int:
	var channels: int = 2 if sample.stereo else 1
	var stride: int = 2 * channels
	var frames: int = sample.data.size() / stride
	var window: int = int(WINDOW * float(sample.mix_rate))
	var search: int = int(SEARCH * float(sample.mix_rate))
	if loop_end >= frames or wanted - search - window < 0 or window <= 0:
		return wanted

	# The join's own run-up, pulled out once rather than re-decoded for every
	# candidate — that inner decode is most of what made this slow.
	#
	# EVERY channel, interleaved as stored. Matching only channel 0 was the tick:
	# the loop is one join for the whole sample, so the audio server jumps both
	# channels at the same frame, but a stereo recording's two channels are
	# different waveforms and are not in phase with each other. Aligning the left
	# one alone leaves the right one stepping at the join, which is heard on every
	# pass exactly like a misaligned mono loop would be.
	var target := PackedInt32Array()
	target.resize(window * channels)
	for i in window:
		for c in channels:
			target[i * channels + c] = sample.data.decode_s16(
				(loop_end - window + i) * stride + c * 2
			)

	var best: int = wanted
	var best_error: float = INF
	for offset in range(-search, search + 1):
		var candidate: int = wanted + offset
		if candidate <= 0 or candidate >= loop_end:
			continue
		var error: float = 0.0
		for i in window:
			for c in channels:
				var difference := float(
					target[i * channels + c] - sample.data.decode_s16(
						(candidate - window + i) * stride + c * 2
					)
				)
				error += difference * difference
			if error >= best_error:
				break
		if error < best_error:
			best_error = error
			best = candidate
	return best

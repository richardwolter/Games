## Finds a loopable slice inside Truck_Acceleration.wav, and prints it.
##
##   godot --headless --script tools/engine_loop_probe.gd
##
## The file is a one-shot acceleration take: a sweep that rises and then holds.
## Playing it whole gives two seconds of engine and then silence, so the engine
## sound is a slice of the held part, looped, with pitch doing the revving.
##
## Two things make that slice seamless. It has to sit where the recording is
## steady — a loop cut across the sweep re-rises every pass and reads as a siren
## — and the waveform either side of the seam has to line up, or the jump from
## one to the other is a step, which is a click.
##
## So: the file is scanned in windows for RMS and zero-crossing rate, the
## longest run at a steady level is taken as the held note, and the end of the
## loop is then chosen as the point whose surrounding waveform best matches the
## start — the loop length is whatever makes the seam disappear, not a round
## number. The residual mismatch is printed, so a bad cut shows up as a number
## here rather than as a click nobody can place.
##
## Level, not zero-crossing rate, decides where the held note is: an engine is
## broadband noise over a tone, and its raw crossing count jumps between 240 and
## 670 Hz from one window to the next even where the recording is plainly
## steady. It is printed because it shows the sweep, and ignored because it is
## far too noisy to threshold on.
##
## Paste the printed values into Audio.ENGINE_LOOP_BEGIN/ENGINE_LOOP_END. Run it
## again if the wav is recut.
##
## Unlike tools/find_sound_offsets.gd this reads the sample data rather than
## listening to it, so it needs no audio device and plain --headless is fine.
extends SceneTree

const SOURCE := "res://audio/Truck_Acceleration.wav"

## Analysis window. Short enough to see the sweep move, long enough that the
## zero-crossing count in one window means something.
const WINDOW := 0.05
## How far a window's level may sit from the run's average and still count as
## part of the same held note.
const LEVEL_TOLERANCE := 0.2
## Windows quieter than this are the fade-in and the tail, not the engine.
const FLOOR := 0.05
## How much waveform either side of the seam is matched when picking the loop
## end. Long enough to cover a couple of cycles of the engine's fundamental.
const MATCH := 0.01
## Bounds on the slice. Under 0.3s an engine reads as a buzz; over 0.8s the
## sweep has usually moved on to another pitch.
const MIN_LOOP := 0.3
const MAX_LOOP := 0.8


func _initialize() -> void:
	var stream: AudioStreamWAV = load(SOURCE)
	if stream == null:
		push_error("Could not load %s" % SOURCE)
		quit(1)
		return

	var rate := stream.mix_rate
	var left := _decode_left(stream)
	if left.is_empty():
		quit(1)
		return

	print("%s: %d frames, %d Hz, %.3f s, format %d, stereo %s" % [
		SOURCE, left.size(), rate, float(left.size()) / rate, stream.format, stream.stereo,
	])

	var window := int(WINDOW * rate)
	var windows := _profile(left, window, rate)
	_report(windows)

	var run := _steadiest_run(windows, window, rate)
	if run == Vector2i.ZERO:
		push_error("No steady run of at least %.2fs found." % MIN_LOOP)
		quit(1)
		return
	print("")
	print("steady from %.3fs to %.3fs" % [float(run.x) / rate, float(run.y) / rate])

	var begin := _snap_to_rising_zero(left, run.x, window)
	var end := _best_end(left, begin, run.y, rate)
	if end <= begin:
		push_error("Loop collapsed: %d..%d" % [begin, end])
		quit(1)
		return

	print("")
	print("const ENGINE_LOOP_BEGIN := %d" % begin)
	print("const ENGINE_LOOP_END := %d" % end)
	print("  = %.3fs .. %.3fs (%.3fs long)" % [
		float(begin) / rate, float(end) / rate, float(end - begin) / rate,
	])
	# The step is the last sample before the jump against the first one after it
	# — the discontinuity the mixer actually plays, and the thing to keep small.
	# The match error will always land near the signal's own level: an engine is
	# match error will always land near the signal's own level: an engine is
	# mostly broadband noise, and noise does not correlate with itself, so no
	# cut can bring it near zero. It is printed to keep that expectation honest
	# rather than as something to chase.
	print("  seam step: %.5f (loop end %.5f vs loop begin %.5f)" % [
		absf(left[end - 1] - left[begin]), left[end - 1], left[begin],
	])
	print("  seam match error: %.5f rms over %.0f ms, against signal rms %.5f" % [
		_seam_error(left, begin, end, rate), MATCH * 1000.0, _block_rms(left, begin, rate),
	])
	quit()


## The left channel as floats, whatever the importer decided to store.
func _decode_left(stream: AudioStreamWAV) -> PackedFloat32Array:
	var data := stream.data
	var stride := 2 if stream.stereo else 1
	var out := PackedFloat32Array()

	match stream.format:
		AudioStreamWAV.FORMAT_8_BITS:
			var count := data.size() / stride
			out.resize(count)
			for i: int in count:
				# Godot stores 8-bit samples signed.
				var raw := data[i * stride]
				out[i] = float(raw - 256 if raw > 127 else raw) / 128.0
		AudioStreamWAV.FORMAT_16_BITS:
			var count := data.size() / (2 * stride)
			out.resize(count)
			for i: int in count:
				out[i] = float(data.decode_s16(i * stride * 2)) / 32768.0
		_:
			# IMA-ADPCM and QOA would need decoding through the mixer, which is
			# what this tool exists to avoid. Re-import as PCM instead.
			push_error("Unsupported format %d — re-import with compress/mode=0." % stream.format)

	return out


## RMS and zero-crossing rate per window.
func _profile(left: PackedFloat32Array, window: int, rate: int) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var count := left.size() / window
	for w: int in count:
		var start := w * window
		var sum_squares := 0.0
		var crossings := 0
		for i: int in window:
			var sample := left[start + i]
			sum_squares += sample * sample
			if i > 0 and (left[start + i - 1] < 0.0) != (sample < 0.0):
				crossings += 1
		# Two crossings per cycle, so this is roughly a frequency in Hz.
		var pitch := float(crossings) * rate / float(window) / 2.0
		out.append(Vector3(sqrt(sum_squares / window), pitch, float(start)))
	return out


func _report(windows: Array[Vector3]) -> void:
	print("")
	print(" time    rms    ~Hz")
	for w: int in windows.size():
		print("%6.3f %6.4f %6.0f" % [w * WINDOW, windows[w].x, windows[w].y])


## The longest run of windows whose level stays near the run's own average.
## Returned as sample indices. Not capped at MAX_LOOP — the run is the held
## note, and the loop is then chosen inside it.
func _steadiest_run(windows: Array[Vector3], window: int, rate: int) -> Vector2i:
	var min_windows := int(ceil(MIN_LOOP * rate / window))
	var best := Vector2i.ZERO
	var best_length := 0

	for start: int in windows.size():
		if windows[start].x < FLOOR:
			continue
		var sum_level := 0.0
		var length := 0
		for i: int in range(start, windows.size()):
			var level: float = windows[i].x
			if level < FLOOR:
				break
			var mean := (sum_level + level) / (length + 1)
			if length > 0 and absf(level - mean) > mean * LEVEL_TOLERANCE:
				break
			sum_level += level
			length += 1

		if length >= min_windows and length > best_length:
			best_length = length
			best = Vector2i(start * window, (start + length) * window)

	return best


## Where to cut the loop so that the waveform running into the seam matches the
## waveform running into the start.
##
## Every candidate end inside the steady run and inside the length bounds is
## scored by how closely the MATCH seconds before it resemble the MATCH seconds
## before the loop start; the best is taken and then nudged to a rising zero
## crossing. Matching a whole block rather than a single sample is what keeps a
## seam inaudible: two samples can both be zero while the waves they belong to
## are heading opposite ways.
func _best_end(left: PackedFloat32Array, begin: int, limit: int, rate: int) -> int:
	var match_length := int(MATCH * rate)
	if begin < match_length:
		return limit

	var first := begin + int(MIN_LOOP * rate)
	var last := mini(limit, begin + int(MAX_LOOP * rate))
	var best := first
	var best_error := INF
	for end: int in range(first, last):
		var error := 0.0
		for i: int in match_length:
			var diff := left[end - match_length + i] - left[begin - match_length + i]
			error += diff * diff
		if error < best_error:
			best_error = error
			best = end

	# The match is phase-correct to within a sample or two already, so this only
	# ever moves the cut a hair — but a cut landing mid-slope is a step, and a
	# step is the click this whole tool exists to avoid.
	return _snap_to_rising_zero(left, best, match_length)


## Walks forward from an index to the next upward zero crossing, so both ends of
## the loop sit at the same phase of the waveform.
func _snap_to_rising_zero(left: PackedFloat32Array, from: int, limit: int) -> int:
	for i: int in range(from, mini(left.size() - 1, from + limit)):
		if left[i] <= 0.0 and left[i + 1] > 0.0:
			return i + 1
	return from


## RMS difference across the seam: the block before the loop end against the
## block before the loop start, which is what the mixer plays back to back.
func _seam_error(left: PackedFloat32Array, begin: int, end: int, rate: int) -> float:
	var match_length := int(MATCH * rate)
	if begin < match_length or end < match_length:
		return NAN
	var sum_squares := 0.0
	for i: int in match_length:
		var diff := left[end - match_length + i] - left[begin - match_length + i]
		sum_squares += diff * diff
	return sqrt(sum_squares / match_length)


## Level of the block before an index, as something to read the seam error
## against.
func _block_rms(left: PackedFloat32Array, at: int, rate: int) -> float:
	var match_length := int(MATCH * rate)
	if at < match_length:
		return NAN
	var sum_squares := 0.0
	for i: int in match_length:
		var sample := left[at - match_length + i]
		sum_squares += sample * sample
	return sqrt(sum_squares / match_length)

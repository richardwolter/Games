## The hive's sounds, built in code until they are recorded (2026-09-30, the beehive
## sidequest; `docs/hive/contract.md` section 7).
##
## Everything else the game says is a recording in `assets/sfx/`. The hive arrived before its
## recordings did, so its sounds are made here the way the placeholders were made before
## 2026-09-15 — resonators, one-pole filters, a seeded roll, peak-normalised — and each one
## goes under the name a recording will take. `Sfx` builds a name here only when no file of
## that name was found, and `loop_stream` loads a file before it builds, so dropping
## `assets/sfx/hive_puff_1.wav` (or `hive_whirr.ogg`) into the folder is all a recording
## needs to win.
##
## **Seeded, never rolled at boot.** `Sfx._rng` is randomised in its `_ready`, and a take drawn
## from it would be a different sound every session. Every builder makes its own generator off
## a fixed seed, so a take is the same take on every run and a harness hears what a player
## hears.
##
## **Cheap, because most of it runs at boot.** `Sfx` is an autoload and builds its seven hive
## names in its own `_ready`, while the engine is starting, with a budget of about 40 ms for
## all of them. Additive synthesis in GDScript costs about 23 ms a second of audio at eight
## partials (measured, map digest), so nothing here adds sines sample by sample: a buzz is
## three sawtooth phases through one resonator, a chime is a handful of struck resonators that
## each run only while they still ring (`_strike`), and the three low sounds — the hum, the
## swarm and the flourish — are made at `LOW_RATE`, where everything in them fits with room to
## spare and each costs half. The room's three loops are not built at boot at all: the step
## that wants one asks `loop_stream` for it, and it is kept once built.
##
## **Loops seam.** Every tone in a loop fits a whole number of cycles into it and so does every
## slow wobble; what cannot — noise, and the memory a filter carries — is crossfaded tail over
## head (`_seam`), the way `WashStand._noise_hiss` does it. A mono wave's loop points are in
## frames, which for mono 16-bit is samples. `Sfx`'s bed pass divides a file's bytes by four
## because its files are stereo, which is why nothing built here goes through it.
class_name HiveSounds
extends RefCounted

const DIR := "res://assets/sfx/"

## The house rate, for anything with brightness in it: the puff, the crackle, the pop, the
## crown and the room's loops.
const RATE := 22050
## Half of it, for the hum, the swarm and the flourish. Their highest content is a few
## kilohertz, well under this rate's 5.5, and the playback resamples for nothing; made at the
## house rate they cost twice as much at boot and sound the same.
const LOW_RATE := 11025
## Every take is scaled so its loudest sample is here. The mix is `Sfx.SOUNDS`'s job, not this.
const PEAK := 0.8
## Slow things — a gain, a wobble, a filter's sweep — are worked out once this many samples
## and eased between, rather than once a sample.
const BLOCK := 64
## How far a struck partial is run before it is dropped: e to the minus this is about a
## five-hundredth, under anything the tail of a chime can be heard at.
const RING_OUT := 6.2

## What `Sfx` builds at boot when no file stands in for it: the six one-shots and the hum bed.
const BOOT: Array[StringName] = [
	&"hive_swarm", &"hive_puff", &"hive_crackle", &"hive_pop", &"hive_crown", &"hive_done",
	&"hive_hum",
]
## The loops the room's steps own and play on their own players (`loop_stream`). Built on
## first asking, never at boot.
const ROOM_LOOPS: Array[StringName] = [&"hive_sizzle", &"hive_whirr", &"hive_pour"]
## How many takes a name is built in. `Sfx.next_step` never plays the same one twice in a row,
## so three is what stops a puff pumped five times from reading as one sound repeated.
const TAKES := {&"hive_puff": 3, &"hive_crackle": 3}

## One seed a sound, so a change to one never re-rolls another.
const SEED_COLONY := 6211
const SEED_PUFF := 6221
const SEED_CRACKLE := 6229
const SEED_POP := 6247
const SEED_CROWN := 6257
const SEED_SIZZLE := 6263
const SEED_WHIRR := 6269
const SEED_POUR := 6271

## The colony. Three workers a few hertz apart, so the hum beats slowly against itself the way
## a box of bees does rather than sitting on one note. Each is a multiple of half a hertz, so
## every one fits whole cycles into `HUM_LENGTH`.
const WORKERS := [226.5, 230.0, 235.5]
const HUM_LENGTH := 2.0
const HUM_CROSS := 0.12
## The throat of it: one wide resonator where the buzz is loudest, over a one-pole low pass of
## the same buzz for the body, with a breath of air through both.
const HUM_FORMANT := 480.0
const HUM_FORMANT_WIDE := 340.0
const HUM_RING := 0.05
const HUM_LOW_PULL := 0.1
const HUM_AIR := 0.08

## The swarm arriving: the colony's own buzz, two layers of it, the second coming in behind the
## first as more bees arrive, swelling, fluttering and brightening as it comes.
const SWARM_LENGTH := 1.4
const SWARM_OTHER := 0.9
const SWARM_FLUTTER := 9.0
const SWARM_BRIGHT := 1.6

## The bellows: a breath of band-limited noise, brighter at its start than its end (the air
## slowing as the bellows empty), over the soft knock of the boards closing.
const PUFF_LENGTH := Vector2(0.24, 0.32)

## Wax giving under the knife: a few dry snaps, the first at once and the rest thinning out.
const CRACKLE_LENGTH := 0.16
const CRACKLE_SNAPS := 11

## A lid going on: a cracked burst of air through two wide resonators, over the lid's own ring.
const POP_LENGTH := 0.12

## The crown: C6, E6, G6 struck one after another, each with a glassy partial that dies at once.
const CROWN_LENGTH := 0.62
const CROWN_NOTES := [[0.0, 1046.5], [0.085, 1318.51], [0.17, 1567.98]]

## The harvest done: G4, B4, D5 rising, then G5 held over a soft G3. Warm rather than bright,
## so it is made low and without the glass.
const DONE_LENGTH := 1.0
const DONE_NOTES := [
	# at, hz, bandwidth, loudness
	[0.0, 392.0, 4.0, 0.8],
	[0.075, 493.88, 4.0, 0.75],
	[0.15, 587.33, 4.0, 0.75],
	[0.24, 783.99, 2.4, 1.0],
	[0.24, 196.0, 3.0, 0.55],
]

## The room's loops. Lengths are whole seconds (or a whole number of every wobble in them).
const SIZZLE_LENGTH := 1.0
const SIZZLE_POPS := 0.006
const WHIRR_LENGTH := 1.0
const WHIRR_DRUM := 96.0
const WHIRR_TURNS := 4.0
const WHIRR_TEETH := 24.0
const POUR_LENGTH := 1.2
const POUR_GLUGS := [0.08, 0.31, 0.53, 0.79, 0.97]

## The loops built so far, by name, so a room opened twice builds nothing the second time.
static var _cache := {}
## The colony's buzz, kept: the hum is it on a loop and the swarm is made out of it.
static var _colony := PackedFloat32Array()


# --- What the game asks for ---------------------------------------------------------------

## Every take of a name, built. `Sfx` puts these in its `_streams` for a name with no file.
static func takes(name: StringName) -> Array[AudioStream]:
	var list: Array[AudioStream] = []
	for take in int(TAKES.get(name, 1)):
		var built := make(name, take)
		if built != null:
			list.append(built)
	return list


## One take of one sound, built. Null for a name this does not make.
static func make(name: StringName, take: int = 0) -> AudioStreamWAV:
	match name:
		&"hive_swarm":
			return _swarm()
		&"hive_puff":
			return _puff(take)
		&"hive_crackle":
			return _crackle(take)
		&"hive_pop":
			return _pop()
		&"hive_crown":
			return _crown()
		&"hive_done":
			return _done()
		&"hive_hum":
			return _wav(_colony_buzz(), true, LOW_RATE)
		&"hive_sizzle":
			return _sizzle()
		&"hive_whirr":
			return _whirr()
		&"hive_pour":
			return _pour()
	return null


## A loop for a room's own player: `assets/sfx/<name>.ogg` or `.wav` when one is there, set to
## loop on a copy (the file is a shared resource, and the next thing to load it is owed it as
## it was), else the built one, kept after the first time.
static func loop_stream(name: StringName) -> AudioStream:
	for ext: String in [".ogg", ".wav"]:
		var path := DIR + String(name) + ext
		if ResourceLoader.exists(path):
			var take := load(path) as AudioStream
			if take != null:
				return looped(take)
	if not _cache.has(name):
		_cache[name] = make(name)
	return _cache[name] as AudioStream


## Whether a name is a recording rather than built, for the harness and for a step that wants
## to know. A one-shot's numbered takes count.
static func is_recorded(name: StringName) -> bool:
	for path: String in [
		DIR + String(name) + ".ogg",
		DIR + String(name) + ".wav",
		DIR + String(name) + "_1.wav",
	]:
		if ResourceLoader.exists(path):
			return true
	return false


## A copy of `stream` set to loop over the whole of itself. A wave file's loop end is in frames:
## counted off its bytes where the format says how many a frame is, else off its length.
static func looped(stream: AudioStream) -> AudioStream:
	var copy := stream.duplicate() as AudioStream
	var wav := copy as AudioStreamWAV
	if wav != null:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = _frames(wav)
		return wav
	if copy != null and "loop" in copy:
		copy.set("loop", true)
	return copy


static func _frames(wav: AudioStreamWAV) -> int:
	var channels := 2 if wav.stereo else 1
	match wav.format:
		AudioStreamWAV.FORMAT_8_BITS:
			return wav.data.size() / channels
		AudioStreamWAV.FORMAT_16_BITS:
			return wav.data.size() / (2 * channels)
	return roundi(wav.get_length() * float(wav.mix_rate))


# --- The world's two ----------------------------------------------------------------------

## The colony's buzz, `HUM_LENGTH` seconds at `LOW_RATE`, seamless, before normalising. Made
## once and kept: the hum and the swarm are both this.
##
## Each worker is a sawtooth phase; the three are summed with gains that breathe at half a
## hertz, one and one and a half — whole cycles in the loop — and the sum goes through the
## throat resonator and a one-pole low pass. The gains are set once a `BLOCK` (under 6 ms here)
## and move by under two per cent a block, which a buzz hides completely.
static func _colony_buzz() -> PackedFloat32Array:
	if not _colony.is_empty():
		return _colony
	var count := int(HUM_LENGTH * LOW_RATE)
	var cross := int(HUM_CROSS * LOW_RATE)
	var total := count + cross
	var raw := PackedFloat32Array()
	raw.resize(total)
	var roll := _roll(SEED_COLONY)
	var step_a := float(WORKERS[0]) / LOW_RATE
	var step_b := float(WORKERS[1]) / LOW_RATE
	var step_c := float(WORKERS[2]) / LOW_RATE
	var phase_a := 0.0
	var phase_b := 0.37
	var phase_c := 0.71
	var throat := _pole(HUM_FORMANT, HUM_FORMANT_WIDE, LOW_RATE)
	var a1 := throat[0]
	var a2 := throat[1]
	var y1 := 0.0
	var y2 := 0.0
	var low := 0.0
	var i := 0
	while i < total:
		var t := float(i) / LOW_RATE
		var gain_a := 0.8 + 0.2 * sin(TAU * 0.5 * t)
		var gain_b := 0.7 + 0.3 * sin(TAU * 1.0 * t + 1.9)
		var gain_c := 0.6 + 0.35 * sin(TAU * 1.5 * t + 4.2)
		# The sawtooths run nought to one; this takes their middle off, so the sum swings
		# about nothing.
		var centre := 0.5 * (gain_a + gain_b + gain_c)
		var end := mini(i + BLOCK, total)
		while i < end:
			phase_a += step_a
			if phase_a >= 1.0:
				phase_a -= 1.0
			phase_b += step_b
			if phase_b >= 1.0:
				phase_b -= 1.0
			phase_c += step_c
			if phase_c >= 1.0:
				phase_c -= 1.0
			var x := (
				phase_a * gain_a + phase_b * gain_b + phase_c * gain_c - centre
				+ (roll.randf() - 0.5) * HUM_AIR
			)
			var y := x + a1 * y1 + a2 * y2
			y2 = y1
			y1 = y
			low += (x - low) * HUM_LOW_PULL
			raw[i] = y * HUM_RING + low
			i += 1
	_colony = _seam(raw, count, cross, false)
	return _colony


## The swarm arriving: two layers of the colony's own buzz, read `SWARM_OTHER` apart so they
## beat differently, the first swelling from a third, the second coming in behind it, both
## fluttering with the swell. What brightens it is the buzz's own slope (a sample less the one
## before), which is the high end of it and nothing new, turned up as it grows. Every gain is
## aimed once a block and eased there a sample at a time, so the 30 ms opening is a ramp and
## not a step.
static func _swarm() -> AudioStreamWAV:
	var colony := _colony_buzz()
	var loop := colony.size()
	var count := int(SWARM_LENGTH * LOW_RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var other := int(SWARM_OTHER * LOW_RATE)
	var near := 0.0
	var far := 0.0
	var edge := 0.0
	var before := colony[loop - 1]
	var i := 0
	while i < count:
		var end := mini(i + BLOCK, count)
		var t := float(end) / LOW_RATE
		var rise := smoothstep(0.0, 0.95, t)
		var join := smoothstep(0.25, 1.05, t)
		var shut := clampf((SWARM_LENGTH - t) / 0.35, 0.0, 1.0)
		var whole := shut * shut * clampf(t / 0.03, 0.0, 1.0)
		var flutter := 1.0 + 0.12 * sin(TAU * SWARM_FLUTTER * t) * rise
		var span := float(end - i)
		var near_step := (lerpf(0.3, 1.0, rise) * flutter * whole - near) / span
		var far_step := (join * 0.8 * flutter * whole - far) / span
		var edge_step := (SWARM_BRIGHT * rise * rise * whole - edge) / span
		while i < end:
			near += near_step
			far += far_step
			edge += edge_step
			var here := colony[i]
			var j := i + other
			if j >= loop:
				j -= loop
			out[i] = here * near + colony[j] * far + (here - before) * edge
			before = here
			i += 1
	return _wav(out, false, LOW_RATE)


# --- The room's one-shots -----------------------------------------------------------------

## A pump of the bellows. Noise between two one-pole filters is a band of air; its top is
## pulled down over the breath, so it starts as a "pff" and ends as a "whoo". It is up in
## 16 ms and dies away on its own curve, and the boards' knock is a low resonator struck once
## at the start. Each take rolls its own length, band, fall and knock.
static func _puff(take: int) -> AudioStreamWAV:
	var roll := _roll(SEED_PUFF + 97 * take)
	var count := int(roll.randf_range(PUFF_LENGTH.x, PUFF_LENGTH.y) * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var attack := int(0.016 * RATE)
	var fall := exp(-1.0 / (roll.randf_range(0.06, 0.085) * RATE))
	var top_from := roll.randf_range(0.3, 0.4)
	var top_to := top_from * 0.45
	var bottom_pull := 0.018
	var boards := _pole(roll.randf_range(95.0, 125.0), 20.0, RATE)
	var k1 := boards[0]
	var k2 := boards[1]
	var kick := 0.35 * boards[2]
	var knock1 := 0.0
	var knock2 := 0.0
	var top := 0.0
	var bottom := 0.0
	var level := 0.0
	var i := 0
	while i < count:
		var pull := lerpf(top_from, top_to, float(i) / float(count))
		var end := mini(i + BLOCK, count)
		while i < end:
			var white := roll.randf() * 2.0 - 1.0
			top += (white - top) * pull
			bottom += (top - bottom) * bottom_pull
			if i < attack:
				level = float(i) / float(attack)
			else:
				level *= fall
			var knock := kick + k1 * knock1 + k2 * knock2
			kick = 0.0
			knock2 = knock1
			knock1 = knock
			out[i] = (top - bottom) * level + knock
			i += 1
	return _wav(_faded(out, 0.02, RATE), false)


## A cell of wax giving under the hot knife. A handful of snaps, the first at once and hardest,
## the gaps after it widening; each strikes a small bright resonator (the snap) and a lower one
## (the wax it is in), and lifts a grit of noise that dies in a few milliseconds. Dry and
## short, because the uncap step fires one for every row the knife passes, up to twenty a
## second.
static func _crackle(take: int) -> AudioStreamWAV:
	var roll := _roll(SEED_CRACKLE + 131 * take)
	var count := int(CRACKLE_LENGTH * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var at := PackedInt32Array()
	var hard := PackedFloat32Array()
	var when := 0.0
	for k in CRACKLE_SNAPS:
		var sample := int(when * RATE)
		if sample >= count - 1:
			break
		at.append(sample)
		if k == 0:
			hard.append(1.0)
		else:
			var side := 1.0 if roll.randf() < 0.5 else -1.0
			hard.append(roll.randf_range(0.25, 0.9) * side)
		when += roll.randf_range(0.003, 0.016) * (1.0 + 0.3 * float(k))
	var snap := _pole(roll.randf_range(2700.0, 3600.0), 900.0, RATE)
	var wax := _pole(roll.randf_range(950.0, 1150.0), 420.0, RATE)
	var sa1 := snap[0]
	var sa2 := snap[1]
	var s_in := snap[2]
	var wa1 := wax[0]
	var wa2 := wax[1]
	var w_in := wax[2]
	var s1 := 0.0
	var s2 := 0.0
	var w1 := 0.0
	var w2 := 0.0
	var grit := 0.0
	var grit_fall := exp(-1.0 / (0.004 * RATE))
	var next := 0
	for i in count:
		var kick := 0.0
		while next < at.size() and at[next] <= i:
			kick += hard[next]
			grit = maxf(grit, absf(hard[next]))
			next += 1
		var s := kick * s_in + sa1 * s1 + sa2 * s2
		s2 = s1
		s1 = s
		var w := kick * w_in + wa1 * w1 + wa2 * w2
		w2 = w1
		w1 = w
		out[i] = s * 0.7 + w * 0.4 + (roll.randf() * 2.0 - 1.0) * grit * 0.3
		grit *= grit_fall
	return _wav(_faded(out, 0.01, RATE), false)


## A jar's lid going on: a burst of air cracked through two wide resonators (the pop), the thin
## ring of the lid itself and a higher shimmer over it, and a low knock for the jar under it.
## A millisecond and a half in and a curve out, so neither end is a step.
static func _pop() -> AudioStreamWAV:
	var roll := _roll(SEED_POP)
	var count := int(POP_LENGTH * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var crack := _pole(1500.0, 1000.0, RATE)
	var body := _pole(430.0, 380.0, RATE)
	var lid := _pole(3150.0, 70.0, RATE)
	var shine := _pole(4720.0, 110.0, RATE)
	var jar := _pole(170.0, 45.0, RATE)
	var c1 := 0.0
	var c2 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	var l1 := 0.0
	var l2 := 0.0
	var h1 := 0.0
	var h2 := 0.0
	var j1 := 0.0
	var j2 := 0.0
	var burst := 1.0
	var burst_fall := exp(-190.0 / RATE)
	for i in count:
		var t := float(i) / RATE
		var air := (roll.randf() * 2.0 - 1.0) * burst
		burst *= burst_fall
		var kick := 1.0 if i == 0 else 0.0
		var c := air * crack[3] + crack[0] * c1 + crack[1] * c2
		c2 = c1
		c1 = c
		var b := air * body[3] + body[0] * b1 + body[1] * b2
		b2 = b1
		b1 = b
		var l := kick * lid[2] + lid[0] * l1 + lid[1] * l2
		l2 = l1
		l1 = l
		var h := kick * shine[2] + shine[0] * h1 + shine[1] * h2
		h2 = h1
		h1 = h
		var j := kick * jar[2] + jar[0] * j1 + jar[1] * j2
		j2 = j1
		j1 = j
		var tail := 1.0 - t / POP_LENGTH
		var swell := minf(t / 0.0015, 1.0) * tail * tail
		out[i] = (c * 0.9 + b * 0.6 + l * 0.35 + h * 0.15 + j * 0.45) * swell
	return _wav(out, false)


## The crown popping: three bright notes rising, each struck (a click of noise on its front),
## ringing on and a glassy partial over it — at a ratio that does not divide, so it reads as a
## bell and not an organ — that is gone almost at once. The last note carries an octave and a
## sparkle two octaves up, and rings longest.
static func _crown() -> AudioStreamWAV:
	var roll := _roll(SEED_CROWN)
	var out := PackedFloat32Array()
	out.resize(int(CROWN_LENGTH * RATE))
	var last := CROWN_NOTES.size() - 1
	for n in CROWN_NOTES.size():
		var note: Array = CROWN_NOTES[n]
		var at := float(note[0])
		var hz := float(note[1])
		var top_note := n == last
		out = _strike(out, RATE, at, hz, 3.0 if top_note else 4.0, 1.1 if top_note else 1.0)
		out = _strike(out, RATE, at, hz * 2.76, 35.0, 0.22)
		out = _tick(out, RATE, at, 0.12, roll)
		if top_note:
			out = _strike(out, RATE, at, hz * 2.0, 12.0, 0.28)
			out = _strike(out, RATE, at + 0.02, hz * 2.0 * 2.0, 22.0, 0.12)
	return _wav(_faded(out, 0.05, RATE), false)


## The harvest done: a warm run up a G major chord and the top held over its root an octave
## down, each note with its octave dying fast under it for body. Soft and round, made low —
## there is nothing up where the crown's glass is.
static func _done() -> AudioStreamWAV:
	var out := PackedFloat32Array()
	out.resize(int(DONE_LENGTH * LOW_RATE))
	for note: Array in DONE_NOTES:
		var at := float(note[0])
		var hz := float(note[1])
		var loud := float(note[3])
		out = _strike(out, LOW_RATE, at, hz, float(note[2]), loud)
		out = _strike(out, LOW_RATE, at, hz * 2.0, 12.0, loud * 0.22)
	return _wav(_faded(out, 0.1, LOW_RATE), false, LOW_RATE)


# --- The room's loops ---------------------------------------------------------------------

## The hot knife on wax: a hiss with the bottom taken off, bubbling as its level wanders a
## block at a time, spattered with tiny pops rung through one bright resonator. All of it is
## noise, so the seam is an equal-power crossfade.
static func _sizzle() -> AudioStreamWAV:
	var roll := _roll(SEED_SIZZLE)
	var count := int(SIZZLE_LENGTH * RATE)
	var cross := int(0.1 * RATE)
	var total := count + cross
	var raw := PackedFloat32Array()
	raw.resize(total)
	var spit := _pole(3800.0, 2200.0, RATE)
	var p1 := 0.0
	var p2 := 0.0
	var low := 0.0
	var level := 0.6
	var i := 0
	while i < total:
		var end := mini(i + BLOCK, total)
		var level_step := (roll.randf_range(0.35, 1.0) - level) / float(end - i)
		while i < end:
			level += level_step
			var white := roll.randf() * 2.0 - 1.0
			low += (white - low) * 0.42
			var kick := 0.0
			if roll.randf() < SIZZLE_POPS:
				kick = roll.randf_range(-1.0, 1.0) * spit[2]
			var p := kick + spit[0] * p1 + spit[1] * p2
			p2 = p1
			p1 = p
			raw[i] = (white - low) * level * 0.5 + p * 0.8
			i += 1
	return _wav(_seam(raw, count, cross, true), true)


## The extractor's drum spinning: a low triangle hum at the drum's note, a whoosh of band
## noise swelling `WHIRR_TURNS` times a loop as the frames come round, a rumble under it, and
## the gears' teeth ticking `WHIRR_TEETH` times a loop through a small resonator. The room
## pitches it with the crank's speed. The hum and the ticks fit the loop whole, so they are
## laid on after the noise has been seamed; the noise alone is crossfaded.
static func _whirr() -> AudioStreamWAV:
	var roll := _roll(SEED_WHIRR)
	var count := int(WHIRR_LENGTH * RATE)
	var cross := int(0.08 * RATE)
	var total := count + cross
	var raw := PackedFloat32Array()
	raw.resize(total)
	var top := 0.0
	var bottom := 0.0
	var rumble := 0.0
	var i := 0
	while i < total:
		var t := float(i) / RATE
		var swirl := 0.5 + 0.5 * sin(TAU * WHIRR_TURNS / WHIRR_LENGTH * t)
		var whoosh := 0.35 + 0.65 * swirl * swirl
		var end := mini(i + BLOCK, total)
		while i < end:
			var white := roll.randf() * 2.0 - 1.0
			top += (white - top) * 0.2
			bottom += (top - bottom) * 0.03
			rumble += (white - rumble) * 0.012
			raw[i] = (top - bottom) * whoosh * 0.6 + rumble * 2.2
			i += 1
	var out := _seam(raw, count, cross, true)
	var step := WHIRR_DRUM / RATE
	var phase := 0.0
	var gear := _pole(1900.0, 600.0, RATE)
	var g1 := 0.0
	var g2 := 0.0
	var tooth := 0.0
	var tooth_every := float(count) / WHIRR_TEETH
	for n in count:
		phase += step
		if phase >= 1.0:
			phase -= 1.0
		var drum := 4.0 * phase - 1.0 if phase < 0.5 else 3.0 - 4.0 * phase
		var kick := 0.0
		if float(n) >= tooth:
			kick = 0.3 * gear[2]
			tooth += tooth_every
		var g := kick + gear[0] * g1 + gear[1] * g2
		g2 = g1
		g1 = g
		out[n] += drum * 0.22 + g * 0.6
	return _wav(out, true)


## Honey running thick out of a gate: a low rush of noise (the stream) breathing at a whole
## number of wobbles a loop, with a glug now and then — a bubble of air let go under the
## honey, its pitch climbing as it rises and gone in a tenth of a second. The glugs sit clear
## of the seam and are laid on after the rush has been crossfaded, so none is ever cut in two.
static func _pour() -> AudioStreamWAV:
	var roll := _roll(SEED_POUR)
	var count := int(POUR_LENGTH * RATE)
	var cross := int(0.06 * RATE)
	var total := count + cross
	var raw := PackedFloat32Array()
	raw.resize(total)
	var deep := 0.0
	var deeper := 0.0
	var mid := 0.0
	var under := 0.0
	var i := 0
	while i < total:
		var t := float(i) / RATE
		var breathe := 0.8 + 0.2 * sin(TAU * 2.5 * t)
		var end := mini(i + BLOCK, total)
		while i < end:
			var white := roll.randf() * 2.0 - 1.0
			deep += (white - deep) * 0.05
			deeper += (deep - deeper) * 0.008
			mid += (white - mid) * 0.15
			under += (mid - under) * 0.05
			raw[i] = ((deep - deeper) * 3.0 + (mid - under) * 0.5) * breathe
			i += 1
	var out := _seam(raw, count, cross, true)
	var window := int(0.12 * RATE)
	for when: float in POUR_GLUGS:
		var start := int((when + roll.randf_range(-0.02, 0.02)) * RATE)
		var from := roll.randf_range(140.0, 190.0)
		var loud := roll.randf_range(0.55, 0.8)
		var phase := 0.0
		for k in mini(window, count - start):
			var u := float(k) / RATE
			phase += TAU * from * (1.0 + 1.1 * minf(u / 0.07, 1.0)) / RATE
			var swell := minf(u / 0.006, 1.0) * exp(-u / 0.03)
			out[start + k] += sin(phase) * swell * loud
	return _wav(out, true)


# --- The workshop -------------------------------------------------------------------------

static func _roll(seed_value: int) -> RandomNumberGenerator:
	var roll := RandomNumberGenerator.new()
	roll.seed = seed_value
	return roll


## A two-pole resonator at `hz`, `bandwidth` hertz wide: its two feedback coefficients, then
## what to strike it with so an impulse of one rings at about one, then what to feed it with so
## a steady signal at its note comes out at about one. Wide means a dull, short ring — which is
## what turns noise into a knock — and narrow a long one. Kept in doubles: a bell's pole sits a
## few ten-thousandths inside the unit circle.
static func _pole(hz: float, bandwidth: float, rate: float) -> PackedFloat64Array:
	var decay := exp(-PI * bandwidth / rate)
	var turn := TAU * hz / rate
	return PackedFloat64Array([
		2.0 * decay * cos(turn),
		-decay * decay,
		sin(turn),
		(1.0 - decay) * 2.0 * sin(turn),
	])


## One struck partial added into `out`: a resonator hit once at `at` seconds, run only while it
## still rings (`RING_OUT`), so a note costs its own length and not the whole buffer's.
static func _strike(
	out: PackedFloat32Array, rate: int, at: float, hz: float, bandwidth: float, loud: float
) -> PackedFloat32Array:
	var start := int(at * rate)
	if start >= out.size():
		return out
	var pole := _pole(hz, bandwidth, rate)
	var a1 := pole[0]
	var a2 := pole[1]
	var kick := loud * pole[2]
	var end := mini(start + int(RING_OUT / (PI * bandwidth) * rate), out.size())
	var y1 := 0.0
	var y2 := 0.0
	for i in range(start, end):
		var y := kick + a1 * y1 + a2 * y2
		kick = 0.0
		y2 = y1
		y1 = y
		out[i] += y
	return out


## The click of a striker on the front of a note: three milliseconds of noise, dying.
static func _tick(
	out: PackedFloat32Array, rate: int, at: float, loud: float, roll: RandomNumberGenerator
) -> PackedFloat32Array:
	var start := int(at * rate)
	var end := mini(start + int(0.003 * rate), out.size())
	for i in range(start, end):
		var left := 1.0 - float(i - start) / float(end - start)
		out[i] += (roll.randf() * 2.0 - 1.0) * loud * left * left
	return out


## The last `seconds` of a one-shot faded out, so a tail cut at the buffer's end is not a step.
static func _faded(out: PackedFloat32Array, seconds: float, rate: int) -> PackedFloat32Array:
	var span := mini(int(seconds * rate), out.size())
	var from := out.size() - span
	for i in range(from, out.size()):
		out[i] *= float(out.size() - i) / float(span)
	return out


## `count` samples of a loop out of `count + cross`: the first `cross` of them crossed with the
## `cross` after the end, so the last sample runs straight on into the first. `power` crosses
## at equal power, for noise, whose halves do not add up like a tone's do; a tone the loop fits
## whole is the same sample either side of the seam and is crossed straight.
static func _seam(
	raw: PackedFloat32Array, count: int, cross: int, power: bool
) -> PackedFloat32Array:
	var out := raw.slice(0, count)
	for i in cross:
		var blend := float(i) / float(cross)
		var head := sqrt(blend) if power else blend
		var tail := sqrt(1.0 - blend) if power else 1.0 - blend
		out[i] = raw[i] * head + raw[count + i] * tail
	return out


## A float buffer as a 16-bit mono wave, its loudest sample at `PEAK`, looping over the whole
## of itself if asked (loop points in frames: one sample a frame in mono).
static func _wav(out: PackedFloat32Array, looping: bool, rate: int = RATE) -> AudioStreamWAV:
	var peak := 0.0
	for value: float in out:
		if value > peak:
			peak = value
		elif -value > peak:
			peak = -value
	var gain := PEAK * 32767.0 / peak if peak > 0.000001 else 0.0
	var bytes := PackedByteArray()
	bytes.resize(out.size() * 2)
	for i in out.size():
		bytes.encode_s16(i * 2, int(out[i] * gain))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = out.size()
	return wav

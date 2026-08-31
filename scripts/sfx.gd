## Every sound the lake makes that is not the music.
##
## There are no sound files in this project and there is not going to be a folder of them:
## the water is a shader and the splashes are drawn by hand, so the noises are built the
## same way — a few hundred lines of arithmetic into a buffer at startup. That keeps the
## game one download and lets a splash be a function of how big the thing that fell in was
## rather than a choice between three recordings of a rock.
##
## One node owns the lot. Short sounds are fired through a small pool of players so two
## splashes at once are two sounds; the engine is one looping player whose volume and pitch
## are steered by the boats.
class_name Sfx
extends Node

## Everything is generated at this rate. Low for a wave file and plenty for splashes and a
## diesel: the highest thing here is hiss, and hiss does not need forty-eight thousand
## samples a second.
const RATE := 22050

## How many short sounds can overlap. A cast sweeping a full net fires a splash per piece
## it lifts, so this wants to be more than a couple.
const VOICES := 8

## Loudness of each sound against the others, in decibels. These are a balance, not a
## volume: the player's setting rides on top of them.
## Loudness of each sound against the others, in decibels. These are a balance, not a
## volume: the player's setting rides on top of them.
##
## The angler's own noises are close and the lake's are far. Everything that happens at the
## rod — the splash, the catch — is at arm's length; the ferries and the crate are across the
## island and heard from a window, so they sit a long way under. They were all mixed as if
## they happened in the same place, and a crate being filled somewhere behind you should not
## be the loudest thing in the game.
const SPLASH_DB := -6.0
const CATCH_DB := -8.0
const POP_DB := -22.0
const HORN_DB := -12.0
const ENGINE_DB := -26.0
const DRAG_DB := -13.0
const WINGS_DB := -9.0
const CHIME_DB := -10.0

## What the player's slider means, in decibels, from all the way down to all the way up.
## The top is above unity because the mix has to carry over the music, and every sound here
## peaks around half of full scale by construction — the headroom is real, not borrowed.
## The bottom is a floor rather than a quiet murmur: turning the sound down should turn it
## off.
const LOUDEST := 6.0
const SILENT := -50.0

## How quickly a held sound fades in and out, in decibels a second. A boat that snaps to
## full volume the frame it undocks sounds like a switch rather than a motor, and a net
## that does it sounds like a tap.
const ENGINE_FADE := 26.0
const DRAG_FADE := 34.0
## Below this a held player is stopped outright, so a docked fleet and a stowed net cost
## nothing.
const ENGINE_FLOOR := -34.0

var _splashes: Array[AudioStreamWAV] = []
var _catch: AudioStreamWAV
var _pop: AudioStreamWAV
var _horn: AudioStreamWAV
var _engine: AudioStreamWAV
var _drag: AudioStreamWAV
var _wings: AudioStreamWAV
var _chime: AudioStreamWAV

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0

var _engine_player: AudioStreamPlayer
## Where the engine is heading, and where it is now, in decibels.
var _engine_want: float = ENGINE_FLOOR
var _engine_at: float = ENGINE_FLOOR
var _engine_pitch: float = 1.0

var _drag_player: AudioStreamPlayer
var _drag_want: float = ENGINE_FLOOR
var _drag_at: float = ENGINE_FLOOR
var _drag_pitch: float = 1.0

## The player's setting: how loud, and whether at all. Both come from the settings panel,
## and the level is remembered the same way the music's is.
var level: float = 0.8
var on: bool = true

var _rng := RandomNumberGenerator.new()


## The player's setting as decibels to add to every sound. Off is off rather than faint,
## which is what a mute switch has to mean.
func _trim() -> float:
	return lerpf(SILENT, LOUDEST, clampf(level, 0.0, 1.0)) if on else SILENT


## Set the level and whether the sound plays at all. The engine is already running when
## this changes, so it is pushed at once rather than waiting for the boat to do something.
func set_level(new_level: float, new_on: bool) -> void:
	level = new_level
	on = new_on
	if _engine_player != null and _engine_at > ENGINE_FLOOR:
		_engine_player.volume_db = _engine_at + _trim()
	if _drag_player != null and _drag_at > ENGINE_FLOOR:
		_drag_player.volume_db = _drag_at + _trim()


func _ready() -> void:
	_rng.seed = 9137
	_build()
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	_engine_player = AudioStreamPlayer.new()
	_engine_player.stream = _engine
	_engine_player.volume_db = ENGINE_FLOOR
	add_child(_engine_player)
	_drag_player = AudioStreamPlayer.new()
	_drag_player.stream = _drag
	_drag_player.volume_db = ENGINE_FLOOR
	add_child(_drag_player)


func _process(delta: float) -> void:
	_engine_at = _hold(
		_engine_player, _engine_at, _engine_want, _engine_pitch, ENGINE_FADE, delta
	)
	_drag_at = _hold(_drag_player, _drag_at, _drag_want, _drag_pitch, DRAG_FADE, delta)


## One frame of a held, looping sound: ease its level towards where it is wanted, glide its
## pitch, and stop it outright once it is inaudible so a quiet lake costs nothing. Returns
## the level it reached.
func _hold(
	player: AudioStreamPlayer,
	at: float,
	want: float,
	pitch: float,
	fade: float,
	delta: float
) -> float:
	if player == null:
		return at
	var now := move_toward(at, want, fade * delta)
	if now <= ENGINE_FLOOR + 0.01:
		if player.playing:
			player.stop()
		return now
	player.volume_db = now + _trim()
	player.pitch_scale = lerpf(player.pitch_scale, pitch, minf(delta * 4.0, 1.0))
	if not player.playing:
		player.play()
	return now


## The net hitting the water, or a piece of rubbish being pulled out of it. `strength` runs
## 0 to 1 and is the same number the drawn splash is given, so what is seen and what is
## heard are one event: a bigger splash is louder, lower and longer.
func play_splash(strength: float) -> void:
	var weight := clampf(strength, 0.0, 1.0)
	var stream := _splashes[mini(int(weight * _splashes.size()), _splashes.size() - 1)]
	_fire(stream, SPLASH_DB + lerpf(-5.0, 1.0, weight), _rng.randf_range(0.94, 1.08))


## The little wet knock of something coming up in the mesh. Fired alongside the splash of
## the piece itself, which is what makes a full sweep sound like a haul rather than rain.
func play_catch() -> void:
	_fire(_catch, CATCH_DB, _rng.randf_range(0.9, 1.12))


## A piece of rubbish leaving a hand or landing on a pile.
##
## One sound, always the same, at one pitch. It was four sizes shifted about by what was
## moving and how far it had fallen, and none of that read as anything — it is a tenth of a
## second long, and the ear hears a pop that keeps changing as a pop that is wrong. This is
## a sound the player will hear a thousand times, so it is one note, played straight.
func play_pop() -> void:
	_fire(_pop, POP_DB, 1.0)


## The departure horn. Two notes, soft-edged: this is a work boat leaving a jetty, not a
## liner leaving a port.
func play_horn() -> void:
	_fire(_horn, HORN_DB, _rng.randf_range(0.98, 1.03))


## What the fleet is doing, as one number and one flag. `effort` is how hard the boats are
## working — 0 is idle at the dock, 1 is a hull with its crane out over the island — and
## `moving` is whether anything is actually under way. Called every frame by the lake; the
## fade and the pitch glide are handled here so the caller can just describe the boats.
func set_engine(effort: float, moving: bool) -> void:
	var work := clampf(effort, 0.0, 1.0)
	if not moving and work <= 0.0:
		_engine_want = ENGINE_FLOOR
		return
	_engine_want = ENGINE_DB + lerpf(-6.0, 2.0, work)
	# Loading revs against the load; sailing settles into a cruise.
	_engine_pitch = lerpf(0.86, 1.14, work)


## The lake coming up clean: one struck note, and the only sound in the game that is not a
## thing happening at the water. Played once, at the end.
func play_chime() -> void:
	_fire(_chime, CHIME_DB, 1.0)


## A pigeon going over: three or four wingbeats, close enough to hear the air in them.
func play_wings() -> void:
	_fire(_wings, WINGS_DB, _rng.randf_range(0.92, 1.1))


## The net being hauled through the water. `effort` is how much water it is moving — a wide
## mouth full of junk against an empty one — and it is what the wash is pitched and levelled
## off. Zero stops it.
func set_drag(effort: float) -> void:
	var work := clampf(effort, 0.0, 1.0)
	if work <= 0.0:
		_drag_want = ENGINE_FLOOR
		return
	_drag_want = DRAG_DB + lerpf(-9.0, 1.0, work)
	_drag_pitch = lerpf(0.82, 1.12, work)


## Take the next player in the pool and let it go. Round-robin rather than "find a free
## one": with eight voices the oldest is always the right one to steal.
func _fire(stream: AudioStreamWAV, db: float, pitch: float) -> void:
	if stream == null or _voices.is_empty() or not on:
		return
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = db + _trim()
	voice.pitch_scale = pitch
	voice.play()


func _build() -> void:
	# Four weights of splash rather than one stretched about: a mug going in and a fridge
	# going in are different sounds, not the same sound at different speeds.
	for step in 4:
		_splashes.append(_make_splash(float(step) / 3.0))
	_catch = _make_catch()
	_pop = _make_pop()
	_horn = _make_horn()
	_engine = _make_engine()
	_drag = _make_drag()
	_wings = _make_wings()
	_chime = _make_chime()


## Water, as filtered noise: a bright spike of spray that dies almost at once over a low
## thump that rings a little, plus a tail of bubbles. The heavier the splash the lower and
## longer everything in it.
func _make_splash(weight: float) -> AudioStreamWAV:
	var length := lerpf(0.26, 0.52, weight)
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var thump := lerpf(210.0, 96.0, weight)
	# One-pole filters, kept between samples: the state is the whole point of them.
	var low := 0.0
	var band := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		# Spray: bright, and gone in a tenth of a second.
		low = lerpf(low, noise, 0.55)
		var spray := (noise - low) * exp(-t * lerpf(48.0, 30.0, weight))
		# Body: the same noise dragged well down, which is what water sounds like under
		# the surface.
		band = lerpf(band, noise, lerpf(0.10, 0.05, weight))
		var body := band * exp(-t * lerpf(20.0, 11.0, weight)) * 2.6
		# The knock of the surface being broken, falling in pitch as the hole closes.
		var knock := sin(TAU * thump * t * (1.0 + t * 1.6)) * exp(-t * 26.0) * 0.5
		out[i] = (spray * 0.55 + body * 0.5 + knock) * lerpf(0.6, 1.0, weight)
	return _to_wav(out, false)


## Something breaking the surface on the way out: a short bloop with a rising pitch, which
## is the same knock as a splash run backwards.
func _make_catch() -> AudioStreamWAV:
	var count := int(0.14 * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var wet := 0.0
	for i in count:
		var t := float(i) / RATE
		var pitch := lerpf(150.0, 430.0, minf(t / 0.09, 1.0))
		var tone := sin(TAU * pitch * t) * exp(-t * 22.0)
		wet = lerpf(wet, _rng.randf_range(-1.0, 1.0), 0.3)
		out[i] = tone * 0.7 + wet * exp(-t * 40.0) * 0.25
	return _to_wav(out, false)


## A pop: bubble wrap, not a bell.
##
## The last one was a tone, and a tone is a bloop however it is shaped — what makes a pop a
## pop is that it is a burst rather than a note. So: a very short crack of noise rung
## through two resonators, which is what a small pocket of air bursting actually is, over a
## low thump for the thing that was holding it. Forty milliseconds, all of it transient.
##
## Still built to survive repetition, which is a harder problem for a sharp sound than a
## soft one. The attack is a millisecond and a half rather than nothing — enough to take
## the digital edge off without blunting the crack — and the resonators are wide, so it
## reads as a pock rather than as a pitch, and there is no note for the ear to get tired of.
func _make_pop() -> AudioStreamWAV:
	var length := 0.075
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	# Two-pole resonators: one for the crack, one under it for the body of the pocket.
	# `ring` is how long each holds on, in hertz of bandwidth — wide, so they colour the
	# noise rather than singing it.
	var crack := _resonator(1650.0, 1100.0)
	var body := _resonator(520.0, 420.0)
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		# The burst itself: gone in a dozen milliseconds, which is the whole sound.
		var burst := _rng.randf_range(-1.0, 1.0) * exp(-t * 190.0)
		var voiced := _ring(crack, burst) * 0.9 + _ring(body, burst) * 0.7
		# The thump of the sheet snapping back, under everything and out almost at once.
		var thump := sin(TAU * 190.0 * t) * exp(-t * 130.0) * 0.22
		# A millisecond and a half in, and a curve out so the tail does not end on a step.
		var swell := minf(t / 0.0015, 1.0) * pow(1.0 - t / length, 1.8)
		out[i] = (voiced + thump) * swell
		peak = maxf(peak, absf(out[i]))
	# Resonator gain is not worth deriving: it depends on both poles and on what was fed
	# through them. Measured and scaled is exact, and it is done once at startup.
	if peak > 0.0001:
		for i in count:
			out[i] = out[i] / peak * 0.85
	return _to_wav(out, false)


## A two-pole resonator, as its coefficients and its two remembered samples. Wide bandwidth
## means a dull ring and a short one, which is what turns noise into a knock.
func _resonator(hz: float, bandwidth: float) -> Array:
	var decay := exp(-PI * bandwidth / RATE)
	return [2.0 * decay * cos(TAU * hz / RATE), -decay * decay, 0.0, 0.0]


## One sample through one resonator. The state lives in the array, which is the point of it.
func _ring(filter: Array, sample: float) -> float:
	var out: float = sample + filter[0] * filter[2] + filter[1] * filter[3]
	filter[3] = filter[2]
	filter[2] = out
	return out


## The horn: a low note with a fifth over it, both with a slow enough attack and release
## that it reads as air rather than a beep, and a slight wobble so it is not a test tone.
func _make_horn() -> AudioStreamWAV:
	var length := 1.15
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)
	var root := 174.0
	for i in count:
		var t := float(i) / RATE
		# Soft in, held, soft out. The long tail is most of why it sounds smooth.
		var swell := minf(t / 0.14, 1.0) * clampf((length - t) / 0.55, 0.0, 1.0)
		var drift := 1.0 + sin(TAU * 4.6 * t) * 0.004
		var tone := (
			sin(TAU * root * drift * t) * 0.6
			+ sin(TAU * root * 1.5 * drift * t) * 0.34
			+ sin(TAU * root * 2.0 * drift * t) * 0.12
			+ sin(TAU * root * 0.5 * t) * 0.2
		)
		# A breath of air over the note, which is what stops it sounding synthesised.
		var air := _rng.randf_range(-1.0, 1.0) * 0.03 * swell
		out[i] = (tone * 0.55 + air) * swell
	return _to_wav(out, false)


## The engine: a loop, so the length has to hold a whole number of every cycle in it or the
## seam clicks. Every frequency below is a multiple of two hertz, which over half a second
## is exactly that.
##
## It was three sine partials and it sounded like a bee, for the reason a bee sounds like a
## bee: nothing under a hundred hertz and nothing rough. A diesel is the opposite of both.
## So it is a full sawtooth from thirty-six hertz up — twenty-two partials, falling off
## slowly enough to keep the rasp — with a hard second harmonic under it for the bulk, and
## noise rung through a low resonator for the exhaust. The putt is shallower than it was and
## half the speed: an engine under load lugs, it does not flutter.
func _make_engine() -> AudioStreamWAV:
	var length := 0.5
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var root := 36.0
	var partials := 22
	# Precomputed: twenty-two sines a sample, times eleven thousand samples, is worth not
	# doing twice.
	var weights := PackedFloat32Array()
	weights.resize(partials)
	for n in partials:
		# A shade slower than a true sawtooth's 1/n, which is what keeps the top end
		# present enough to rasp instead of rolling off into a hum.
		weights[n] = 1.0 / pow(float(n + 1), 0.82)

	var rasp := _resonator(150.0, 260.0)
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		# Two putts a loop, and it never drops below two thirds: the gaps are what made the
		# old one flutter.
		var beat := 0.68 + 0.32 * pow(maxf(sin(TAU * 4.0 * t), 0.0), 0.5)
		var tone := 0.0
		for n in partials:
			tone += sin(TAU * root * float(n + 1) * t) * weights[n]
		# The exhaust: noise given a pitch by the resonator rather than left as hiss, and
		# faded across the seam because filtered noise does not loop on its own.
		var seam := clampf(t / 0.05, 0.0, 1.0) * clampf((length - t) / 0.05, 0.0, 1.0)
		var breath := _ring(rasp, _rng.randf_range(-1.0, 1.0)) * 0.05 * seam
		out[i] = tone * beat * 0.3 + breath
		peak = maxf(peak, absf(out[i]))
	if peak > 0.0001:
		for i in count:
			out[i] = out[i] / peak * 0.8
	return _to_wav(out, true)


## Water being pushed by something dragged through it.
##
## The first version was two one-pole filters and a swell, and it came out sounding like
## something being sanded. Two reasons, both fixed here. A single one-pole leaves a great
## deal of high end behind — six decibels an octave is barely a slope — so the hiss that
## should be under the water was sitting on top of it; this cascades four of them, which
## takes the top off properly and leaves a body of low noise that moves. And the old swell
## was two sine waves beating against each other at four and a bit hertz, which is slow
## enough to hear as a wobble and regular enough to hear as a machine. Water does not keep
## time, so the swell is now three waves at unrelated rates, none of them fast.
##
## Loops, and like the engine it is faded across the seam, because filtered noise never
## joins up with itself.
func _make_drag() -> AudioStreamWAV:
	var length := 0.9
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	# Four poles for the body, two for the surface just above it.
	var deep := [0.0, 0.0, 0.0, 0.0]
	var near := [0.0, 0.0]
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		var noise := _rng.randf_range(-1.0, 1.0)
		var body := noise
		for k in deep.size():
			deep[k] = lerpf(deep[k], body, 0.05)
			body = deep[k]
		var surface := noise
		for k in near.size():
			near[k] = lerpf(near[k], surface, 0.16)
			surface = near[k]

		# Three rates that do not divide into each other, so it never settles into a beat.
		var swell := (
			0.74
			+ 0.14 * sin(TAU * 1.111 * t)
			+ 0.08 * sin(TAU * 2.222 * t + 1.7)
			+ 0.04 * sin(TAU * 3.333 * t + 0.4)
		)
		var seam := clampf(t / 0.1, 0.0, 1.0) * clampf((length - t) / 0.1, 0.0, 1.0)
		out[i] = (body * 6.5 + surface * 0.9) * swell * seam
		peak = maxf(peak, absf(out[i]))
	if peak > 0.0001:
		for i in count:
			out[i] = out[i] / peak * 0.8
	return _to_wav(out, true)


## A pigeon overhead: wingbeats, which are pulses of air rather than notes. Each is a puff
## of low noise with a soft edge either side — a flap has no attack, which is exactly what
## separates it from a clap.
func _make_wings() -> AudioStreamWAV:
	var beats := 4
	var every := 0.135
	var length := every * float(beats) + 0.1
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var air := _resonator(320.0, 700.0)
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		var loud := 0.0
		for beat in beats:
			var since := t - float(beat) * every
			if since < 0.0 or since > 0.09:
				continue
			# A hump rather than a spike: up over thirty milliseconds and down again, which
			# is the shape of a wing moving air.
			var through := since / 0.09
			# Quieter each time, as the bird gets further away.
			loud += sin(through * PI) * lerpf(1.0, 0.45, float(beat) / float(beats))
		out[i] = _ring(air, _rng.randf_range(-1.0, 1.0)) * loud * 0.25
		peak = maxf(peak, absf(out[i]))
	if peak > 0.0001:
		for i in count:
			out[i] = out[i] / peak * 0.7
	return _to_wav(out, false)


## The chime: a bell rather than a horn, which is a matter of what is in it and how it
## leaves rather than of how it starts. The partials are not harmonics — a struck bar rings
## at ratios that do not divide, which is what stops a note sounding like an organ — and each
## one dies at its own rate, the high ones first, so the note darkens as it fades the way a
## real one does. Two seconds of tail, nearly all of it under the game.
func _make_chime() -> AudioStreamWAV:
	var length := 2.2
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	var root := 528.0
	# Ratio, how loud, and how fast it goes. The strike is in the top pair and the note that
	# is left after half a second is the bottom one.
	var partials := [
		[0.5, 0.42, 1.1],
		[1.0, 1.00, 1.5],
		[2.02, 0.44, 2.8],
		[2.98, 0.22, 4.2],
		[5.43, 0.10, 7.0],
	]
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		var note := 0.0
		for partial: Array in partials:
			note += (
				sin(TAU * root * float(partial[0]) * t)
				* float(partial[1])
				* exp(-t * float(partial[2]))
			)
		# Three milliseconds in. A bell has an attack; a bell with no attack is a sine wave
		# being turned up.
		var swell := minf(t / 0.003, 1.0) * clampf((length - t) / 0.35, 0.0, 1.0)
		# The knock of the striker, gone almost before it is there, and what makes it read
		# as hit rather than switched on.
		var strike := _rng.randf_range(-1.0, 1.0) * exp(-t * 220.0) * 0.16
		out[i] = (note * 0.5 + strike) * swell
		peak = maxf(peak, absf(out[i]))
	if peak > 0.0001:
		for i in count:
			out[i] = out[i] / peak * 0.8
	return _to_wav(out, false)


## Float buffer to a 16-bit mono wave, clipped rather than normalised so a sound that was
## built too loud is a mistake that can be heard and fixed.
func _to_wav(samples: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	if looping:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = samples.size()
	return wav

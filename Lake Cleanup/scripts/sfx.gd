## Every sound the game makes that is not the music.
##
## Recorded, mostly (2026-09-15, Richard): the sounds are files in `assets/sfx/`, cut from the
## recordings in `art_source/SFX` by `tools/build_sfx.py`. This header used to promise there
## would never be a folder of sound files; that was the placeholders talking. What has no
## recording yet — the lake coming clean and the siege's chime — is still built here, a few
## hundred lines of arithmetic into a buffer at startup.
##
## The knock of a piece coming up in the mesh is **cut, by decision** (2026-09-16): every
## place that played it already drew a splash, dropped a piece in the crate or knocked the
## box, so the knock under those was the same event sounded twice. Don't put it back.
##
## An autoload (`Sound` in project.godot), so the main menu has its clicks and the start sound
## carries across the change of scene into the lake. `Sfx.main()` finds it; a run without it
## (a `--script` tool) gets null and stays quiet. It reads its levels from `Prefs` itself.
##
## Short sounds are fired through a small pool of players so two splashes at once are two
## sounds, with a pool of its own for the interface so a sweep of catches cannot steal a
## click. The ambience and the fireplace are held loops, eased in and out.
class_name Sfx
extends Node

const DIR := "res://assets/sfx/"

## The built sounds are made at this rate. Low for a wave file and plenty for a pop and a
## diesel.
const RATE := 22050

## How many short sounds can overlap. A cast sweeping a full net fires a splash and a knock
## per piece it lifts, so this wants to be more than a couple.
const VOICES := 12
const UI_VOICES := 3

## Every recording: its loudness against the others in decibels, and how far its pitch is
## rolled either side of true on each play. A balance, not a volume — the player's setting
## rides on top.
##
## **The mix and nothing else** (2026-09-16, issue #1): `tools/build_sfx.py` now brings every
## cut to one loudness, so a number here no longer doubles as a rescue for a take that was
## recorded twenty decibels under the rest. Every figure was shifted by that file's own gain
## on the changeover, so what is written here is the balance Richard had tuned by ear, said
## over a level floor. A re-record shifts them again — the builder's report prints by how
## much, per name.
##
## The report's shift column reads the gain against the **raw cut**, which is what the old
## build wrote for most names. The footsteps, the sniffs, the wading and the boat's water
## were peak-normalised before, so for those five the changeover was worked out against a
## peak of 0.9 instead. Nothing in the pipeline does that any more, so the column is right
## from here on.
##
## The angler's own noises are close and the lake's far: the ferry's bell is across the
## island, the splash is at arm's length.
const SOUNDS := {
	&"ferry_bell": [-17.9, 0.02],
	&"boat_move": [-12.3, 0.05],
	&"net_throw": [-6.8, 0.06],
	&"net_splash": [-12.8, 0.04],
	&"piece_splash": [-13.9, 0.0],
	&"haul": [-13.0, 0.0],
	&"find_caught": [-2.5, 0.0],
	&"find_chime": [-19.7, 0.03],
	&"coin": [-10.8, 0.08],
	&"upgrade": [-7.0, 0.0],
	&"pigeon_fly": [-15.4, 0.08],
	&"pigeon_coo": [-3.0, 0.06],
	&"bark": [-5.3, 0.06],
	&"sniff": [-6.8, 0.05],
	&"step_grass": [-14.9, 0.08],
	&"step_sand": [-15.9, 0.08],
	&"wading": [-10.9, 0.04],
	&"ui_hover": [-18.6, 0.03],
	&"ui_click": [-3.0, 0.02],
	&"ui_close": [-12.4, 0.0],
	&"shed_open": [-10.5, 0.0],
	&"game_start": [-9.1, 0.0],
	&"drop_big": [-5.1, 0.05],
	&"drop_small": [-10.2, 0.08],
}

## Sounds with players of their own, and how many (2026-09-15, first playtest). Through the
## shared pool they were stolen: a sweep lifting a dozen pieces fires a knock each, twelve
## voices go round in a frame, and the net's splash, the haul, the bell and the chime were cut
## off a fraction of a second in.
const CHANNELS := {
	&"net_splash": 2,
	&"net_throw": 1,
	&"haul": 3,
	&"ferry_bell": 1,
	&"boat_move": 1,
	&"find_chime": 1,
	&"find_caught": 1,
	&"bark": 1,
	&"wading": 1,
	&"sniff": 1,
}
## Of those, the ones that are never cut: with every player busy, the new one is skipped
## rather than one playing being stopped. The haul always finishes; the chime rings out.
const NEVER_CUT := [&"haul", &"find_chime", &"ferry_bell", &"boat_move", &"wading"]

## What the lake is still allowed to make a noise with while the upgrades board is up
## (2026-09-15, Richard: "keep only music, ambient and money from lake sounds").
##
## The board covers the lake, and a dog barking, a ferry setting off or a pigeon going over
## behind it is a noise with nothing to look at. The money is the exception because it is
## what the board is about: a sale landing while the shop is open is the number on the plate
## moving. The ambience is a bed, not a sound, and keeps running — the lake is still there.
## Interface sounds come through `play_ui` and are not the lake's, so they are untouched.
const WHILE_SHOPPING := [&"coin", &"upgrade"]

## The same for the shed: the room covers the lake, so the lake is not heard from inside it —
## no ferry setting off, no water, no dog (2026-09-15, Richard). What the room itself makes goes
## on: its door, the pieces put down, the fire, and the interface.
const WHILE_INDOORS := [
	&"ui_hover", &"ui_click", &"ui_close", &"shed_open", &"drop_big", &"drop_small", &"upgrade"
]

## One take lands every cast, so it is dropped onto one of a few pitches rather than rolled
## about one (2026-09-15, Richard: "not too repetitive"). Never the pitch it landed on last,
## and SOUNDS' own small roll on top, so two casts at the same step are still not identical.
const NET_SPLASH_PITCHES: Array[float] = [0.72, 0.85, 0.98, 1.1]

## The same for the two sounds a long haul fires most often (2026-09-16, Richard: "not too
## repetitive and tiring"). The coin lands once a piece sold and the thud once a piece boxed,
## so both are heard dozens of times a minute; one take at one pitch turns into a metronome.
## The pop's steps multiply `POP_PITCH`, the coin's stand on their own.
const COIN_PITCHES: Array[float] = [0.88, 0.96, 1.04, 1.14]
const POP_PITCHES: Array[float] = [0.88, 0.96, 1.05, 1.14]

## A piece landing in a box: the shed's own wooden thud, a little under the pitch it was
## recorded at (2026-09-15, Richard: "wood on wood, bold"). The built pop it replaces was a
## filtered knock, and dropped in pitch it read as a shot heard from a long way off.
##
## Up from 0.85 (2026-09-16, Richard: still a bit muffled). Dropping the pitch is what makes
## it bold and also what makes it dull, so this went only half the way back and POP_DB took
## the rest of the answer.
const POP_PITCH := 0.90

## The find chime rings no more than once in this many seconds, from its start: the marker
## held over a find hears a ring now and then, not a peal.
const CHIME_GAP := 6.0

## The built sounds' balance, as before the recordings came.
## A piece landing in the crate: the moment work turns into stock. Up 4 dB over the level
## floor (2026-09-16, Richard: it is still a bit muffled) — this and POP_PITCH are the two
## knobs for it, and both want a pass by ear.
const POP_DB := -9.0
const CHIME_DB := -10.0
## The lake come clean.
const FOUND_DB := -10.0

## The two long beds. The lake's recording is quiet (it peaks at a fifth of full scale), so it
## sits up where the short sounds sit down.
const AMBIENCE_DB := -21.1
const FIRE_DB := -5.5
## How long the wading water is silent between plays. Held as one loop it was water running
## without a break; this is a wash, a pause, and another wash.
const WADE_EVERY := 1.0

## The held loops. Read from a file each, and each set to loop on the way in.
const BEDS: Array[StringName] = [&"lake_ambient", &"fireplace"]
## How far the lake goes under while the shed is open: heard through its wall.
const AMBIENCE_DUCK := -14.0

## Shortest gaps between repeats. A sweep lifting a dozen pieces in a second is a burst of
## splashes, not a pile of them; coins landing on the same frame are one chink; a pointer
## dragged across a board full of rows is not a drum roll.
const SPLASH_GAP := 0.08
const CHINK_GAP := 0.06
const HOVER_GAP := 0.05
## The fleet rings no more than once in this many seconds, however many hulls set off, and
## pushes water no more than once in this many: two hulls leaving together used to play the
## same take over itself, which is what read as a weird space sound.
const BELL_GAP := 25.0
const BOAT_MOVE_GAP := 2.5
## And the same for a hull coming home (2026-09-16, Richard: the ferry arriving should have
## water and bell too, sparsely). Longer than the departure's, so an arrival bell is the
## occasional one: leaving is an announcement, coming alongside is not.
const BERTH_BELL_GAP := 70.0

## The haul is played again this often while the net is being reeled, each time pitched and
## levelled off how hard it is working.
const HAUL_EVERY := 1.0
## And each repeat within one haul is this much quieter than the last, down to HAUL_SPENT: one
## cast is one pull losing its strength, not the same wash over and over.
const HAUL_FALLS := -4.0
const HAUL_SPENT := -16.0

## What the player's slider means, in decibels, from all the way down to all the way up.
## The bottom is a floor rather than a murmur: turning the sound down should turn it off.
const LOUDEST := 6.0
const SILENT := -50.0

## How quickly a held bed fades in and out, in decibels a second.
const BED_FADE := 18.0

## Loaded recordings, name to every variant of it (`step_sand_1`, `step_sand_2`... all go
## under `step_sand`).
var _streams := {}

var _chime: AudioStreamWAV
var _found: AudioStreamWAV

## When each gap-limited sound last played, in seconds.
var _last := {}

## Which step each of the pitched sounds last used, by name. See `_next_pitch`.
var _pitch_step := {}

## The coo and the start sound get players nobody else can take. The coo went through the
## pool once, and a cast closing on a pigeon closes on a dozen pieces in the same sweep: eight
## voices later its voice had been handed to a bottle.
var _coo_player: AudioStreamPlayer
var _start_player: AudioStreamPlayer

var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Name to its own players (see CHANNELS), and the next one of each to steal.
var _channels := {}
var _channel_next := {}
var _ui_voices: Array[AudioStreamPlayer] = []
var _next_ui: int = 0

var _haul_effort: float = 0.0
var _haul_wait: float = 0.0
## How many times the wash has been played since this haul started.
var _haul_plays: int = 0

## The beds: whether each is wanted, and the level each has eased to (before the trim).
var _ambience_player: AudioStreamPlayer
var _ambience_on: bool = false
var _ambience_duck: bool = false
var _ambience_at: float = SILENT
var _fire_player: AudioStreamPlayer
var _fire_on: bool = false
var _fire_at: float = SILENT
var _wade_on: bool = false
## Who is in the shallows: the angler and any dog, as a set. See `set_wading`.
var _wading: Dictionary = {}
var _wade_wait: float = 0.0

## The player's settings. `level` 0 to 1.
var level: float = 0.8
var on: bool = true
var ambience_level: float = 0.7
var ambience_on: bool = true

var _rng := RandomNumberGenerator.new()


## The autoload, or null in a run that has none.
static func main() -> Sfx:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(^"Sound") as Sfx


## An interface sound from anywhere, without every button holding a reference.
static func ui(name: StringName) -> void:
	var sound := main()
	if sound != null:
		sound.play_ui(name)


## Whether the upgrades board is up, and the lake's own sounds are therefore held (see
## `WHILE_SHOPPING`). The scene pushes it; `hush` lets it go with everything else.
var shopping: bool = false

## Whether the player is in the shed, where the lake is out of earshot (`WHILE_INDOORS`).
var indoors: bool = false


## The player's setting as decibels to add to every sound. Off is off rather than faint, and
## the travel between the two ends is `Prefs`' `volume_db`: the law every slider shares.
func _trim() -> float:
	return Prefs.volume_db(level, on, LOUDEST, SILENT)


func _ambience_trim() -> float:
	return Prefs.volume_db(ambience_level, ambience_on, LOUDEST, SILENT)


## Set the level and whether the sound plays at all. The held sounds are already running
## when this changes, so they are pushed at once.
func set_level(new_level: float, new_on: bool) -> void:
	level = new_level
	on = new_on


func _pull_prefs() -> void:
	var prefs := get_node_or_null(^"/root/Prefs")
	if prefs == null:
		return
	set_level(prefs.sfx_level, prefs.sfx_on)
	ambience_level = prefs.ambience_level
	ambience_on = prefs.ambience_on


func _ready() -> void:
	_rng.randomize()
	_build()
	_load_recordings()
	for i in VOICES:
		_voices.append(_player())
	for i in UI_VOICES:
		_ui_voices.append(_player())
	for name: StringName in CHANNELS:
		var own: Array[AudioStreamPlayer] = []
		for i in int(CHANNELS[name]):
			own.append(_player())
		_channels[name] = own
		_channel_next[name] = 0
	_coo_player = _player()
	_start_player = _player()
	_ambience_player = _player(_first(&"lake_ambient"))
	_fire_player = _player(_first(&"fireplace"))
	_pull_prefs()
	var prefs := get_node_or_null(^"/root/Prefs")
	if prefs != null:
		prefs.changed.connect(_pull_prefs)


func _player(stream: AudioStream = null) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	add_child(player)
	return player


## Every name in SOUNDS, plus the two beds, as one file or as numbered variants.
func _load_recordings() -> void:
	var names: Array = SOUNDS.keys()
	names.append_array(BEDS)
	# The barks and sniffs are numbered like the steps.
	for name: StringName in names:
		var found: Array[AudioStream] = []
		for ext: String in [".wav", ".ogg"]:
			var path := DIR + String(name) + ext
			if ResourceLoader.exists(path):
				found.append(load(path))
		var n := 1
		while ResourceLoader.exists(DIR + "%s_%d.wav" % [name, n]):
			found.append(load(DIR + "%s_%d.wav" % [name, n]))
			n += 1
		for stream in found:
			# The beds loop; a wave file has to be told where, since the cut has no loop point
			# written into it.
			if name not in BEDS:
				continue
			var ogg := stream as AudioStreamOggVorbis
			if ogg != null:
				ogg.loop = true
			var wav := stream as AudioStreamWAV
			if wav != null:
				wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				wav.loop_begin = 0
				wav.loop_end = wav.data.size() / 4
		_streams[name] = found


func _first(name: StringName) -> AudioStream:
	var list: Array = _streams.get(name, [])
	return list[0] if not list.is_empty() else null


func _process(delta: float) -> void:
	if _haul_effort > 0.0 and not shopping:
		_haul_wait -= delta
		if _haul_wait <= 0.0:
			_haul_wait = HAUL_EVERY
			var spent := maxf(HAUL_FALLS * float(_haul_plays), HAUL_SPENT)
			play(
				&"haul",
				lerpf(-8.0, 1.0, _haul_effort) + spent,
				lerpf(0.88, 1.1, _haul_effort)
			)
			_haul_plays += 1
	else:
		_haul_wait = 0.0
		_haul_plays = 0
	var ambience_want := SILENT
	if _ambience_on:
		ambience_want = AMBIENCE_DB + (AMBIENCE_DUCK if _ambience_duck else 0.0)
	_ambience_at = _bed(_ambience_player, _ambience_at, ambience_want, _ambience_trim(), delta)
	_fire_at = _bed(_fire_player, _fire_at, FIRE_DB if _fire_on else SILENT, _trim(), delta)
	# The held sounds go quiet with the rest of the lake while the board is up. The ambience
	# above does not: it is the bed the lake plays under everything, board or no board.
	# The wading wash: while the boots are moving water, play it, let it finish, wait
	# WADE_EVERY, play it again. Its own player, so nothing cuts it short.
	if _wade_on and not shopping:
		if is_playing(&"wading"):
			_wade_wait = WADE_EVERY
		else:
			_wade_wait -= delta
			if _wade_wait <= 0.0:
				_wade_wait = WADE_EVERY
				play(&"wading")
	else:
		_wade_wait = 0.0


## One frame of a bed: ease its level towards where it is wanted, and stop it outright once it
## is inaudible so a quiet lake costs nothing. A stopped bed starts again from the top.
func _bed(player: AudioStreamPlayer, at: float, want: float, trim: float, delta: float) -> float:
	if player == null or player.stream == null:
		return at
	var now := move_toward(at, want, BED_FADE * delta)
	if now <= SILENT + 0.01:
		if player.playing:
			player.stop()
		return now
	player.volume_db = now + trim
	if not player.playing:
		player.play()
	return now


## Stop everything held. The lake calls this on its way out, because this node outlives it
## and a haul or an ambience left running into the main menu is a ghost.
func hush() -> void:
	shopping = false
	indoors = false
	_haul_effort = 0.0
	_haul_plays = 0
	_ambience_on = false
	_ambience_duck = false
	_fire_on = false
	_wade_on = false
	_wade_wait = 0.0


## A recording by name, through the pool. `db` is added to its balance and `pitch` multiplies
## its roll. Any variant, picked at random.
func play(name: StringName, db: float = 0.0, pitch: float = 1.0) -> void:
	var list: Array = _streams.get(name, [])
	if list.is_empty() or not may_play(name):
		return
	var voice: AudioStreamPlayer
	if _channels.has(name):
		var own: Array[AudioStreamPlayer] = _channels[name]
		voice = _idle(own)
		if voice == null:
			if name in NEVER_CUT:
				return
			voice = own[_channel_next[name]]
			_channel_next[name] = (int(_channel_next[name]) + 1) % own.size()
	else:
		voice = _idle(_voices)
		if voice == null:
			voice = _voices[_next_voice]
			_next_voice = (_next_voice + 1) % _voices.size()
	var tune: Array = SOUNDS.get(name, [0.0, 0.0])
	var spread: float = tune[1]
	voice.stream = list[_rng.randi() % list.size()]
	voice.volume_db = float(tune[0]) + db + _trim()
	voice.pitch_scale = pitch * _rng.randf_range(1.0 - spread, 1.0 + spread)
	voice.play()


## Whether a sound of the lake's may be heard at all right now: the settings' switch, and
## the upgrades board holding everything but the money.
func may_play(name: StringName) -> bool:
	return (
		on
		and (not shopping or name in WHILE_SHOPPING)
		and (not indoors or name in WHILE_INDOORS)
	)


## The first player in a pool with nothing playing, or null.
func _idle(pool: Array[AudioStreamPlayer]) -> AudioStreamPlayer:
	for voice in pool:
		if not voice.playing:
			return voice
	return null


## Whether a sound with players of its own is still sounding.
func is_playing(name: StringName) -> bool:
	for voice: AudioStreamPlayer in _channels.get(name, []):
		if voice.playing:
			return true
	return false


## The same, through the interface's own voices.
func play_ui(name: StringName) -> void:
	if name == &"ui_hover" and not _gap(name, HOVER_GAP):
		return
	var list: Array = _streams.get(name, [])
	if list.is_empty() or _ui_voices.is_empty() or not on:
		return
	var voice := _ui_voices[_next_ui]
	_next_ui = (_next_ui + 1) % _ui_voices.size()
	var tune: Array = SOUNDS.get(name, [0.0, 0.0])
	var spread: float = tune[1]
	voice.stream = list[_rng.randi() % list.size()]
	voice.volume_db = float(tune[0]) + _trim()
	voice.pitch_scale = _rng.randf_range(1.0 - spread, 1.0 + spread)
	voice.play()


## Whether `gap` seconds have passed since `name` last got through, and if so, marks now.
func _gap(name: StringName, gap: float) -> bool:
	var now := float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last.get(name, -1000.0)) < gap:
		return false
	_last[name] = now
	return true


## A piece coming up out of the water. `strength` runs 0 to 1 and is the number the drawn
## splash is given: a heavier piece is louder and lower. No more than one every SPLASH_GAP.
func play_splash(strength: float) -> void:
	if not _gap(&"piece_splash", SPLASH_GAP):
		return
	var weight := clampf(strength, 0.0, 1.0)
	play(&"piece_splash", lerpf(-4.0, 2.0, weight), lerpf(1.15, 0.85, weight))


## The net coming down on the water, thrown or laid.
func play_net_splash() -> void:
	play(&"net_splash", 0.0, _next_pitch(&"net_splash", NET_SPLASH_PITCHES))


## One of `steps`, never the one this name used last, so two plays in a row are always a
## different pitch. SOUNDS' own small roll goes on top of it in `play`.
func _next_pitch(name: StringName, steps: Array[float]) -> float:
	var was := int(_pitch_step.get(name, -1))
	var step := _rng.randi() % steps.size()
	if step == was and steps.size() > 1:
		step = (step + 1 + _rng.randi() % (steps.size() - 1)) % steps.size()
	_pitch_step[name] = step
	return steps[step]


## The net leaving the angler's hands.
func play_throw() -> void:
	play(&"net_throw")


## A piece of rubbish leaving a hand or landing on a pile. One note, played straight: this
## is a sound the player hears a thousand times.
func play_pop() -> void:
	# The shed's own thud is what a piece landing in a box plays, so the room's allow-list
	# cannot tell the two apart: a yard filling while the player decorates is stopped here.
	if indoors:
		return
	play(
		&"drop_big",
		POP_DB - float(SOUNDS[&"drop_big"][0]),
		POP_PITCH * _next_pitch(&"pop", POP_PITCHES)
	)


## A ferry setting off from the island's dock.
func play_bell() -> void:
	# The water the hull pushes as it leaves, one hull at a time; the bell over it, now and then.
	if not is_playing(&"boat_move") and _gap(&"boat_move", BOAT_MOVE_GAP):
		play(&"boat_move")
	if not is_playing(&"ferry_bell") and _gap(&"ferry_bell", BELL_GAP):
		play(&"ferry_bell")


## A ferry coming alongside the island's dock. The water it pushes as it comes in, on the
## fleet's own gap; the bell over it far more rarely than on the way out.
##
## The pier end is silent, by decision (2026-09-16): it is across the lake from where the
## player stands, and the coins are what say a delivery landed.
func play_berth() -> void:
	if not is_playing(&"boat_move") and _gap(&"boat_move", BOAT_MOVE_GAP):
		play(&"boat_move")
	if not is_playing(&"ferry_bell") and _gap(&"ferry_bell", BERTH_BELL_GAP):
		play(&"ferry_bell")


## One struck note: the siege's.
func play_chime() -> void:
	_fire(_chime, CHIME_DB, 1.0)


## The lake coming up clean.
func play_found() -> void:
	_fire(_found, FOUND_DB, _rng.randf_range(0.98, 1.03))


## A find brought up in the net.
func play_find_caught() -> void:
	play(&"find_caught")


## A find shining at the player: one uncovered. Rung only if it is not already ringing.
func play_find_chime() -> void:
	_ring_chime()


## The aim marker over a shining find, or not, every frame. While it is over one the chime
## rings now and then, no more than once in CHIME_GAP; once it leaves, the one playing
## finishes and nothing more starts. Never restarted while it is still sounding.
func hover_find(over: bool) -> void:
	if over:
		_ring_chime()


func _ring_chime() -> void:
	if not is_playing(&"find_chime") and _gap(&"find_chime", CHIME_GAP):
		play(&"find_chime")


## An upgrade bought.
func play_bought() -> void:
	play(&"upgrade")


## A coin reaching the plate. No more than one every CHINK_GAP.
func play_chink() -> void:
	if _gap(&"coin", CHINK_GAP):
		play(&"coin", 0.0, _next_pitch(&"coin", COIN_PITCHES))


## A pigeon going over.
func play_wings() -> void:
	play(&"pigeon_fly")


## A pigeon lifted out of the lake, saying so. On its own player.
func play_coo() -> void:
	var list: Array = _streams.get(&"pigeon_coo", [])
	if _coo_player == null or list.is_empty() or not may_play(&"pigeon_coo"):
		return
	var tune: Array = SOUNDS[&"pigeon_coo"]
	_coo_player.stream = list[0]
	_coo_player.volume_db = float(tune[0]) + _trim()
	_coo_player.pitch_scale = _rng.randf_range(1.0 - tune[1], 1.0 + tune[1])
	_coo_player.play()


## The net being hauled. `effort` is how much water it is moving; zero stops the haul
## sound from being played again. Called every frame by the lake.
func set_drag(effort: float) -> void:
	_haul_effort = clampf(effort, 0.0, 1.0)


## One footstep. `surface` is &"grass" or &"sand"; the shallows are a held loop instead
## (`set_wading`), because what the recording has is water being moved, not a footfall.
func play_step(surface: StringName) -> void:
	play(StringName("step_" + String(surface)))


## Whether somebody is walking in the shallows, pushed every frame by each walker that can
## be in them — the angler and every dog (2026-09-16).
##
## Keyed by walker, because there is one wading loop and four dogs: a boolean set by
## whoever pushed last would be turned off by a dog on the lawn while the angler stood in
## the water. The loop runs if anybody is in it; the key is dropped when its walker leaves
## the tree, so a freed dog cannot hold it on for ever.
func set_wading(wading: bool, who: Object = null) -> void:
	if wading:
		_wading[who] = true
	else:
		_wading.erase(who)
	for walker: Variant in _wading.keys():
		if walker != null and not is_instance_valid(walker):
			_wading.erase(walker)
	_wade_on = not _wading.is_empty()


func play_bark() -> void:
	play(&"bark")


func play_sniff() -> void:
	play(&"sniff")


## A piece put down in the shed: a tap for a small thing or a painting, a thud for furniture.
func play_drop(small: bool) -> void:
	play(&"drop_small" if small else &"drop_big")


## Whether a lit fireplace is in the room the player is looking at.
func set_fireplace(lit: bool) -> void:
	_fire_on = lit


## Whether the lake is up, and whether it is being heard through the shed's wall.
func set_ambience(playing: bool, ducked: bool = false) -> void:
	_ambience_on = playing
	_ambience_duck = ducked


## New game or Continue, pressed on the menu. Its own player, on this node, so it carries on
## into the lake after the menu is gone.
func play_start() -> void:
	var list: Array = _streams.get(&"game_start", [])
	if _start_player == null or list.is_empty() or not on:
		return
	_start_player.stream = list[0]
	_start_player.volume_db = float(SOUNDS[&"game_start"][0]) + _trim()
	_start_player.play()


## Take the next player in the pool and let it go, for the built sounds.
func _fire(stream: AudioStreamWAV, db: float, pitch: float) -> void:
	# The built sounds are the siege's chime and the cleaned note; neither is money, so the
	# board holds both.
	if stream == null or _voices.is_empty() or not on or shopping:
		return
	var voice := _idle(_voices)
	if voice == null:
		voice = _voices[_next_voice]
		_next_voice = (_next_voice + 1) % _voices.size()
	voice.stream = stream
	voice.volume_db = db + _trim()
	voice.pitch_scale = pitch
	voice.play()


func _build() -> void:
	_chime = _make_chime()
	_found = _make_found()


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


## A find: a wooden knock with a metal glow growing out of it.
##
## The furniture in this lake is wood and metal, and both are in the sound. The wood is
## the front of it — a low box resonance with a knuckle of noise on the front, dead inside a
## third of a second, because wood does not ring. The metal is the opposite and is what the
## card is really doing: two close partials that swell in rather than being struck, beating
## slowly against each other, and still there a second later.
##
## The swell is the whole reason this is not the purchase sound. Money lands; a thing coming
## up out of a lake and catching the light does not land, it arrives.
func _make_found() -> AudioStreamWAV:
	var length := 1.5
	var count := int(length * RATE)
	var out := PackedFloat32Array()
	out.resize(count)

	# The box: a low fundamental with the two partials a struck plank actually has, none of
	# them ringing for long.
	var wood := [[196.0, 1.0, 13.0], [301.0, 0.5, 17.0], [452.0, 0.22, 24.0]]
	# The metal: a fifth apart, each detuned from its neighbour by a couple of hertz so the
	# pair drifts in and out of each other instead of sitting still.
	var metal := [[784.0, 0.55], [787.0, 0.42], [1176.0, 0.3], [1181.5, 0.22]]
	var peak := 0.0
	for i in count:
		var t := float(i) / RATE
		var sample := 0.0

		for part: Array in wood:
			sample += (
				sin(TAU * float(part[0]) * t) * float(part[1]) * exp(-t * float(part[2]))
			) * 0.5
		# The knuckle on the front of the knock. Gone in three milliseconds, and what makes
		# it wood being hit rather than a low note being played.
		sample += _rng.randf_range(-1.0, 1.0) * exp(-t * 320.0) * 0.35

		# Grows over a fifth of a second and then lets go slowly, so the metal is a light
		# coming up rather than a second thing being struck.
		var bloom := clampf(t / 0.2, 0.0, 1.0) * exp(-maxf(t - 0.2, 0.0) * 2.4)
		var ring := 0.0
		for part: Array in metal:
			ring += sin(TAU * float(part[0]) * t) * float(part[1])
		sample += ring * bloom * 0.3

		var swell := minf(t / 0.002, 1.0) * clampf((length - t) / 0.3, 0.0, 1.0)
		out[i] = sample * swell * 0.5
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

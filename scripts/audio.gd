## The soundtrack, and the volume setting that governs it.
##
## An autoload, because it has to outlive the scene it started in: the title
## screen and the game are separate scenes, and a player who presses START
## should not hear the music stop, restart, or skip. Nothing here is reloaded
## when the scene changes.
##
## Volume lives in its own file rather than in the save, so it survives New Game
## and is still right on a machine with no save at all. It is a preference about
## the program, not a fact about the run.
extends Node

## One track per level, by level index.
##
## A level past the end of this list keeps the last track rather than dropping
## back to the first: the music is meant to move forward with the run, and
## snapping back to the opening theme on level 3 would read as a mistake. Adding
## a track is adding a line here.
const TRACKS: Array[String] = [
	"res://audio/Sax_Level1.mp3",
	"res://audio/Song_Strait_Across.mp3",
	# Levels 3 and 4 share this one, level 4 by the clamp above — hence the name.
	"res://audio/Song_Level3_4.mp3",
]
## Background noise for a level, by level index. A level with no entry plays
## none, and the layer fades out when you leave one that had it.
##
## Ambience rides the MUSIC bus rather than the effects one. It is continuous
## background the same way the soundtrack is — somebody who turns the music down
## to work is asking for quiet, not for the traffic to keep going without the
## sax — and it keeps the balance between the two fixed at whatever AMBIENCE_DB
## says, instead of letting two sliders drift it.
const AMBIENCE: Dictionary[int, String] = {
	0: "res://audio/City_Noise.mp3",
}
## How far under the soundtrack the ambience sits. The track is the thing you are
## meant to hear; this is the room it is played in.
const AMBIENCE_DB := -22.0

## How long one track takes to give way to the next. Long enough that the change
## is a change of scene rather than an edit.
const CROSSFADE := 1.6
## Effectively silence for a fading track. -80 is Godot's floor.
const SILENT_DB := -60.0
## One-shot effects, by name. Loaded once at startup — these fire on a click, and
## a load() on the click is a hitch exactly when the game should feel immediate.
const SOUNDS: Dictionary = {
	&"piece_click": "res://audio/Piece_Click.wav",
	&"piece_release": "res://audio/Piece_Release.wav",
	&"ui_click": "res://audio/UI_Menu_Click.mp3",
	&"water_splash": "res://audio/Water_Splashes.wav",
}

## Usable splashes inside Water_Splashes.wav, as (start, length) in seconds.
##
## The file is one long recording of many splashes with dead air and unusable
## takes between them, so it is played as clips rather than as a sample: a
## splash picks one of these at random and the player is stopped again at the
## end of it. Three is enough that consecutive splashes rarely repeat, and with
## the pitch spread on top they do not read as a loop.
const SPLASH_CLIPS: Array[Vector2] = [
	Vector2(3.388, 0.470),
	Vector2(5.700, 0.300),
	Vector2(10.321, 0.579),
]
## Silence to skip at the front of each one-shot, in seconds.
##
## UI_Menu_Click.mp3 is padded with 156ms of nothing before the transient, so the
## click landed a sixth of a second after the button went down — which reads as
## the game being slow to respond rather than as the file being padded. Starting
## playback past the padding costs nothing and fixes it at the source.
##
## Measured, not guessed: tools/find_sound_offsets.gd plays each file through an
## AudioEffectCapture and reports where the sound actually starts. Re-run it if a
## sound is recut. Values are already backed off slightly from the measurement,
## since clipping the attack is worse than leaving a millisecond of silence.
const SOUND_OFFSETS: Dictionary = {
	&"ui_click": 0.148,
	&"piece_click": 0.011,
	&"piece_release": 0.0,
}

## The truck's engine.
const ENGINE := "res://audio/Truck_Acceleration.wav"

## The loopable slice of it, in samples.
##
## The file is a one-shot acceleration take: a sweep that rises for a second and
## a half and then dies away. Played whole it gives two seconds of engine and
## then a silent truck, so what actually plays is a slice of the steady part on
## repeat, with pitch doing the revving.
##
## Both numbers are measured, not chosen: tools/engine_loop_probe.gd finds the
## longest stretch at a steady level and then picks the cut whose waveform lines
## up with the start of it, so the join has no step in it to click. Re-run it if
## the file is ever recut — a loop cut by eye clicks once every half second,
## forever.
const ENGINE_LOOP_BEGIN := 15468
const ENGINE_LOOP_END := 39872

## Where the engine sits. Below the one-shots, because it is not a one-shot: a
## sound that plays continuously under everything for the length of a crossing
## has to sit further back than one that flashes past, or it is all you hear.
const ENGINE_DB := -14.0
## Pitch bounds. Below the lower one a truck sounds like a boat; above the upper
## one the sample's own noise floor starts whistling and it stops sounding like
## a recording of an engine at all.
const ENGINE_PITCH_MIN := 0.7
const ENGINE_PITCH_MAX := 1.6
## Ramps for the engine coming in and going out. Both short — the engine
## starting is a thing that happens, not a thing that fades in over a bar — but
## not zero: cutting a loop dead at full volume is a click at both ends.
const ENGINE_FADE_IN := 0.25
const ENGINE_FADE_OUT := 0.35

## How many one-shots can overlap. Four covered the clicks, but splashes share
## the same ring and a collapsing bridge puts several pieces through the water
## at once — at four, the splashes cut each other off and took the click the
## player had just made with them.
const SFX_VOICES := 8
const SFX_TRIM_DB := -8.0

const SETTINGS_PATH := "user://settings.cfg"

## Below this the slider is treated as off and the bus is muted outright —
## -60 dB is not silence, and a track left running at it still burns a decoder.
const SILENCE_THRESHOLD := 0.005

## The soundtrack is mixed well hot for a loop that plays under everything for
## the whole session, so it is trimmed on the player rather than by lowering the
## default slider value. Trimming here means the setting still reads "70%" and
## still goes all the way up — it is the track that sits back, not the volume
## control that lies about where it is.
const MUSIC_TRIM_DB := -11.0

## The two buses everything plays on, created at startup so there is no bus
## layout resource to keep in step with this file.
const MUSIC_BUS := &"Music"
const SFX_BUS := &"SFX"

## 0..1, what the sliders show. Stored linear because that is what a volume
## slider means to a person; the buses want decibels and get them on the way in.
##
## Two of them rather than one master, because the two want different settings
## far more often than they want the same one: the soundtrack is a long loop
## somebody may well turn off entirely, while the clicks and the engine are
## feedback they still need to hear. A single control could only ever mute both.
var music_volume: float = 0.7:
	set(value):
		music_volume = clampf(value, 0.0, 1.0)
		_apply_volume()
var sfx_volume: float = 0.9:
	set(value):
		sfx_volume = clampf(value, 0.0, 1.0)
		_apply_volume()

## Two music players, used alternately: one fades down while the other fades up.
## A single player cannot crossfade with itself, and fading one out before
## starting the next leaves a hole exactly where the handover should be.
var _players: Array[AudioStreamPlayer] = []
var _active: int = 0
## What the active player is playing, so asking for the same track twice is free
## rather than restarting it.
var _track: String = ""
var _fades: Array[Tween] = [null, null]

## A ring of one-shot players and the streams they play.
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
## Bumped every time a voice is handed out. A clip's stop timer carries the
## number it was started with and does nothing if it no longer matches, so a
## clip that has already been cut short by a later sound on the same voice
## cannot stop that later sound when its own timer comes round.
var _voice_gen: PackedInt32Array = PackedInt32Array()
var _sounds: Dictionary[StringName, AudioStream] = {}

## The ambience layer, and what it is playing so a level change to a level with
## the same noise doesn't restart it.
var _ambience: AudioStreamPlayer = null
var _ambience_path: String = ""
var _ambience_fade: Tween = null

## The engine, on its own player. It cannot go through the one-shot ring: that
## forces every stream it holds to LOOP_DISABLED, and it round-robins, so a
## collapsing bridge would put eight splashes through it and take the engine
## with them.
var _engine: AudioStreamPlayer = null
var _engine_fade: Tween = null


func _ready() -> void:
	# Keeps playing while the tree is paused, so a settings menu that pauses the
	# game doesn't cut the music the player is trying to set the level of.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_build_buses()
	_load_settings()
	_build_voices()
	_build_engine()

	_ambience = AudioStreamPlayer.new()
	_ambience.name = "Ambience"
	_ambience.bus = MUSIC_BUS
	_ambience.volume_db = SILENT_DB
	_ambience.process_mode = Node.PROCESS_MODE_ALWAYS
	# Same safety net the music players get, for a format that ignores its own
	# loop flag. Silence in the background is not obviously a bug, which is what
	# makes it worth catching.
	_ambience.finished.connect(func() -> void:
		if not _ambience_path.is_empty():
			_ambience.play()
	)
	add_child(_ambience)

	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		player.volume_db = SILENT_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		# Safety net for any format that ignores its own loop flag.
		player.finished.connect(_on_finished.bind(i))
		add_child(player)
		_players.append(player)

	_apply_volume()
	# Nothing plays until a scene says which level it is showing. Starting the
	# opening theme here and correcting it a frame later would mean a player
	# resuming at level 2 hears level 1's music fade in and straight back out.


## Adds the Music and SFX buses under Master if they aren't there already.
##
## Built in code rather than shipped as a bus layout resource: there are two of
## them, they have no effects on them, and the only thing that ever reads their
## names is this file. A .tres would be a second place to keep the same two
## strings, and the kind that fails silently — a missing bus makes every player
## that names it fall back to Master, which sounds fine and quietly ignores both
## volume sliders.
func _build_buses() -> void:
	for name: StringName in [MUSIC_BUS, SFX_BUS]:
		if AudioServer.get_bus_index(name) != -1:
			continue
		var index := AudioServer.bus_count
		AudioServer.add_bus(index)
		AudioServer.set_bus_name(index, name)
		AudioServer.set_bus_send(index, &"Master")


func _build_voices() -> void:
	for name: StringName in SOUNDS:
		# Missing files are survivable and silent rather than fatal: sound arrives
		# in this project one .wav at a time, and a half-populated folder must not
		# stop the game running.
		if not ResourceLoader.exists(SOUNDS[name]):
			push_warning("No sound at %s; that effect is silent." % SOUNDS[name])
			continue
		var stream := load(SOUNDS[name]) as AudioStream
		if stream == null:
			continue
		# A one-shot that loops never stops, and a sample can arrive with the flag
		# already set by whatever cut it. Both spellings, because these files turn
		# up as either .wav or .mp3 and the two formats carry the flag
		# differently.
		if stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_DISABLED
		elif &"loop" in stream:
			stream.set(&"loop", false)
		_sounds[name] = stream

	for i in SFX_VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		player.volume_db = SFX_TRIM_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)
		_voice_gen.append(0)


## Fire a one-shot.
##
## Round-robins the players rather than hunting for a free one, so a rapid burst
## of clicks cuts its own oldest tail instead of dropping the newest sound. For
## UI feedback that is the right trade: the click you just made must always be
## heard, and the one from four clicks ago need not be.
##
## `pitch_spread` detunes each shot slightly. The same sample at the same pitch
## twenty times in a row is what makes a click track sound mechanical, and this
## is most of the fix for a single-sample effect.
func play_sound(name: StringName, pitch_spread: float = 0.06) -> void:
	var stream: AudioStream = _sounds.get(name)
	if stream == null or _voices.is_empty():
		return
	var voice := _take_voice()
	var player := _voices[voice]
	player.stream = stream
	player.volume_db = SFX_TRIM_DB
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play(float(SOUND_OFFSETS.get(name, 0.0)))


## Play one region of a longer file: `length` seconds starting `from` seconds in.
##
## For samples that are a recording of several takes rather than a single
## effect — Water_Splashes.wav is one file of many splashes with dead air
## between them. Playing from an offset is built in; stopping again is not, so
## the player is stopped on a timer.
##
## `trim_db` is relative to the usual effects level, so a caller can make a
## small splash quieter than a large one without knowing what that level is.
func play_clip(name: StringName, from: float, length: float,
		trim_db: float = 0.0, pitch_spread: float = 0.06) -> void:
	var stream: AudioStream = _sounds.get(name)
	if stream == null or _voices.is_empty() or length <= 0.0:
		return
	var voice := _take_voice()
	var player := _voices[voice]
	var generation := _voice_gen[voice]
	player.stream = stream
	player.volume_db = SFX_TRIM_DB + trim_db
	var pitch := 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.pitch_scale = pitch
	player.play(from)
	# Pitch changes how long the region takes to play, so the timer is in real
	# seconds rather than in stream seconds — otherwise a shot pitched down runs
	# past its clip into whatever was recorded next.
	get_tree().create_timer(length / pitch, true, false, true).timeout.connect(
		func() -> void:
			if _voice_gen[voice] == generation and player.playing:
				player.stop()
	)


## Next player in the ring, with its generation bumped so any stop timer still
## pending for the sound it was last playing is now stale.
func _take_voice() -> int:
	var voice := _next_voice
	_next_voice = (_next_voice + 1) % _voices.size()
	_voice_gen[voice] += 1
	return voice


func _build_engine() -> void:
	if not ResourceLoader.exists(ENGINE):
		push_warning("No engine sound at %s; the truck drives silently." % ENGINE)
		return
	var stream := load(ENGINE) as AudioStreamWAV
	if stream == null:
		push_warning("%s is not a WAV; the truck drives silently." % ENGINE)
		return

	# Duplicated before the loop is set on it. load() hands out the one cached
	# copy of the resource, so setting a loop on it here would set it on every
	# other use of the same file — and this one is being turned into something
	# that never stops.
	stream = stream.duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = ENGINE_LOOP_BEGIN
	stream.loop_end = mini(ENGINE_LOOP_END, int(stream.get_length() * stream.mix_rate))

	_engine = AudioStreamPlayer.new()
	_engine.name = "Engine"
	_engine.bus = SFX_BUS
	_engine.stream = stream
	# Starts silent so the first fade has somewhere to come from. A looping
	# player brought up at full volume starts on the sample's own attack, which
	# is a click.
	_engine.volume_db = SILENT_DB
	add_child(_engine)


## Start the engine, or leave it running if it already is.
##
## The loop is left to the mixer rather than restarted from `finished`: a sample
## loop is sample-accurate inside the mix, while a restart on a signal happens
## whenever the main loop next gets round to it — which on web is at the
## browser's convenience and is exactly where a gap would open up.
func engine_start() -> void:
	if _engine == null:
		return
	if _engine_fade != null and _engine_fade.is_valid():
		_engine_fade.kill()
	if not _engine.playing:
		_engine.volume_db = SILENT_DB
		# From the loop's start rather than the file's, so the first pass is the
		# same steady note as every pass after it.
		_engine.play(float(ENGINE_LOOP_BEGIN) / _stream_rate())
	_engine_fade = create_tween()
	_engine_fade.tween_property(_engine, ^"volume_db", ENGINE_DB, ENGINE_FADE_IN)


## Fade the engine out and stop it.
func engine_stop() -> void:
	if _engine == null or not _engine.playing:
		return
	if _engine_fade != null and _engine_fade.is_valid():
		_engine_fade.kill()
	_engine_fade = create_tween()
	_engine_fade.tween_property(_engine, ^"volume_db", SILENT_DB, ENGINE_FADE_OUT)
	_engine_fade.tween_callback(_engine.stop)


## Set the revs. 1.0 is the recording's own pitch.
##
## Pitching a looped sample resamples the loop with it, so the join stays where
## it is and stays seamless at any speed — none of the correction play_clip has
## to do for its timers applies here.
func engine_pitch(pitch: float) -> void:
	if _engine == null:
		return
	_engine.pitch_scale = clampf(pitch, ENGINE_PITCH_MIN, ENGINE_PITCH_MAX)


func _stream_rate() -> float:
	var stream := _engine.stream as AudioStreamWAV
	return float(stream.mix_rate) if stream != null else 44100.0


## Play the track belonging to a level, crossfading from whatever is playing.
##
## Called by the game when a level loads, and by the title screen with the level
## the save is sitting on — so somebody who has beaten level 1 and comes back to
## Continue is met by the music they left off with rather than the opening theme.
func set_level_music(level_index: int) -> void:
	# Ambience is keyed on the real index, NOT the clamped one the track uses:
	# levels past the end of TRACKS deliberately keep the last track, and there is
	# no equivalent reading for noise — level 4 is not in the city.
	_set_ambience(String(AMBIENCE.get(level_index, "")))
	if TRACKS.is_empty():
		return
	play_track(TRACKS[clampi(level_index, 0, TRACKS.size() - 1)])


## Fade the background layer to `path`, or to silence when it is empty.
func _set_ambience(path: String) -> void:
	if _ambience == null or path == _ambience_path:
		return
	_ambience_path = path

	if _ambience_fade != null and _ambience_fade.is_valid():
		_ambience_fade.kill()
	_ambience_fade = create_tween()

	if path.is_empty():
		_ambience_fade.tween_property(_ambience, ^"volume_db", SILENT_DB, CROSSFADE)
		_ambience_fade.tween_callback(_ambience.stop)
		return

	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("No ambience at %s; the level runs without it." % path)
		return
	if &"loop" in stream:
		stream.set(&"loop", true)
	_ambience.stream = stream
	_ambience.volume_db = SILENT_DB
	_ambience.play()
	_ambience_fade.tween_property(_ambience, ^"volume_db", AMBIENCE_DB, CROSSFADE)


func play_track(path: String) -> void:
	if _players.size() < 2 or path == _track:
		return
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("No music at %s; the game runs silent." % path)
		return
	# MP3 and Ogg both carry their own loop flag, and setting it is what makes
	# the loop seamless — restarting from `finished` leaves an audible gap the
	# length of one frame.
	if &"loop" in stream:
		stream.set(&"loop", true)

	var outgoing := _active
	var incoming := 1 - _active
	_active = incoming
	_track = path

	var next := _players[incoming]
	next.stream = stream
	next.volume_db = SILENT_DB
	next.play()

	# First track of the session has nothing to fade from, so it comes up on its
	# own rather than waiting out a handover against silence.
	_fade(incoming, MUSIC_TRIM_DB, CROSSFADE)
	if _players[outgoing].playing:
		_fade(outgoing, SILENT_DB, CROSSFADE, true)


## Ramps one player's volume, replacing any ramp already running on it — two
## tweens on the same property fight, and the loser wins at random.
func _fade(index: int, to_db: float, seconds: float, stop_after: bool = false) -> void:
	var running := _fades[index]
	if running != null and running.is_valid():
		running.kill()
	var player := _players[index]
	var tween := create_tween()
	tween.tween_property(player, ^"volume_db", to_db, seconds)
	if stop_after:
		tween.tween_callback(player.stop)
	_fades[index] = tween


## Restart if the stream ever ends despite the loop flag. Only the track that is
## currently supposed to be playing — the other player finishing is just the tail
## of a crossfade.
func _on_finished(index: int) -> void:
	if index == _active:
		_players[index].play()


## KNOWN, HARMLESS EXIT NOISE. Quitting prints:
##
##   Leaked instance: AudioStreamPlaybackMP3 / AudioStreamMP3
##   Resource still in use: res://audio/Song_Strait_Across.mp3
##
## It is a teardown-order artefact of an autoload holding a playing stream: the
## audio server releases its playback after the object database has already been
## checked. Stopping the player and dropping the stream from _exit_tree, from
## NOTIFICATION_WM_CLOSE_REQUEST and from NOTIFICATION_PREDELETE were all tried
## and none of them move it, because by the time any of those run the playback
## has already been handed over. Nothing leaks while the game is running, and
## the smoke test's own output is unaffected — the lines appear after it has
## finished and passed. Left alone rather than papered over with teardown code
## that does not work.


func _apply_volume() -> void:
	_set_bus(MUSIC_BUS, music_volume)
	_set_bus(SFX_BUS, sfx_volume)


func _set_bus(name: StringName, level: float) -> void:
	var bus := AudioServer.get_bus_index(name)
	if bus == -1:
		return
	AudioServer.set_bus_mute(bus, level < SILENCE_THRESHOLD)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_volume()
		return
	# A file written before the split has only master_volume, and it is the level
	# the player last chose — so it seeds both rather than being thrown away and
	# resetting somebody's setting for them.
	var legacy: float = float(config.get_value("audio", "master_volume", -1.0))
	music_volume = float(config.get_value("audio", "music_volume",
		legacy if legacy >= 0.0 else music_volume))
	sfx_volume = float(config.get_value("audio", "sfx_volume",
		legacy if legacy >= 0.0 else sfx_volume))


## Called when the player lets go of a slider, not on every drag step — this
## writes a file, and a slider emits dozens of changes per second.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.save(SETTINGS_PATH)

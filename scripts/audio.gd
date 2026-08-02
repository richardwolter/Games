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
	"res://audio/Song_Strait_Across.mp3",
	"res://audio/Song_Level2.mp3",
]
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
}
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

## How many one-shots can overlap. Four is enough for the fastest a person can
## click and still leaves the tail of the last one audible; past that the extra
## players are silent most of the session.
const SFX_VOICES := 4
const SFX_TRIM_DB := -8.0

## The truck engine, played for as long as the car is pulling forward.
const ENGINE := "res://audio/Truck_Acceleration.wav"
## The stretch of the recording that repeats, picked by ear as the flattest part
## of the pull — past 1.04 the revs are already easing off towards the wind-down
## at 1.27, and it was that easing, replayed every cycle, that was audible as a
## dip rather than as a constant engine.
## Both loop points are in FRAMES, not seconds, and that is load-bearing.
##
## They were seconds, printed by the tool to five decimals and converted back
## with a truncating int() — which lands one frame short of the frame the tool
## actually chose. One frame is nothing in time and everything in signal: it is
## the difference between the waveform continuing across the join and stepping
## across it, and that step is the tick. Seconds cannot survive the round trip,
## so the number that matters is the one that is stored.
const ENGINE_LOOP_END_FRAMES := 45864
## Where the loop returns to — NOT the start of the file.
##
## Looping the whole file was the "up, cut, up" problem: every pass replayed the
## rev from idle, so instead of a truck driving you heard it pull away over and
## over. The recording is an attack followed by a sustain, and only the sustain
## may repeat: the file plays once from the top so the pull-away is heard
## properly, and from then on it cycles this stretch, which is already at revs.
##
## 0.77 s was the timestamp read off the waveform; a few milliseconds is most of
## a cycle at engine frequencies, so splicing there leaves a step that is heard
## as a click on every pass. This is that point nudged 19 ms to the frame where
## the waveform actually lines up with the join, across BOTH channels — found by
## tools/find_engine_loop.gd, which prints this figure ready to paste. Re-run it
## if the recording or the loop window ever changes.
const ENGINE_LOOP_BEGIN_FRAMES := 34802
## The engine is a foreground sound but it plays flat out for whole attempts, so
## it gets its own trim rather than sitting at whatever level the file was cut at.
## Well below the music's -11 in perceived terms: a rev held for thirty seconds
## wears far faster than a track does.
const ENGINE_TRIM_DB := -14.0
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

## 0..1, what the slider shows. Stored linear because that is what a volume
## slider means to a person; the bus wants decibels and gets them on the way in.
var master_volume: float = 0.7:
	set(value):
		master_volume = clampf(value, 0.0, 1.0)
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

var _engine: AudioStreamPlayer
## A ring of one-shot players and the streams they play.
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _sounds: Dictionary[StringName, AudioStream] = {}
## Our own copy of the engine sample, because the loop is switched on and off on
## the resource itself and that must not reach into the imported one.
var _engine_sample: AudioStreamWAV
## True once the loop has been released and the wind-down is playing out.
var _engine_releasing: bool = false


func _ready() -> void:
	# Keeps playing while the tree is paused, so a settings menu that pauses the
	# game doesn't cut the music the player is trying to set the level of.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_load_settings()
	_build_engine()
	_build_voices()

	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = &"Master"
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


## The engine, set up to loop the pulling half of the recording.
##
## The loop is set on the sample rather than by restarting the player from a
## timer: an AudioStreamWAV loops inside the audio server, sample-accurate and
## with no gap, whereas a `play()` called from _process lands on a frame boundary
## and puts an audible seam in a sound that is supposed to be continuous.
func _build_engine() -> void:
	var loaded := load(ENGINE) as AudioStreamWAV
	if loaded == null:
		push_warning("No engine sound at %s; crossings run quiet." % ENGINE)
		return
	# Duplicated because stop_engine() switches loop_mode on the resource, and
	# the imported sample is shared with anything else that ever loads it.
	var sample := loaded.duplicate() as AudioStreamWAV
	_engine_sample = sample
	# LOOP_FORWARD plays from the top of the file and only starts cycling once it
	# reaches loop_end, which is what gives the attack-then-sustain shape: the
	# rev-up is heard once, the held note repeats.
	sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	sample.loop_begin = ENGINE_LOOP_BEGIN_FRAMES
	sample.loop_end = ENGINE_LOOP_END_FRAMES

	_engine = AudioStreamPlayer.new()
	_engine.name = "Engine"
	_engine.bus = &"Master"
	_engine.stream = sample
	_engine.volume_db = ENGINE_TRIM_DB
	_engine.finished.connect(func() -> void: _engine_releasing = false)
	add_child(_engine)


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
		player.bus = &"Master"
		player.volume_db = SFX_TRIM_DB
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_voices.append(player)


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
	var player := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_spread, pitch_spread)
	player.play(float(SOUND_OFFSETS.get(name, 0.0)))


## Start the engine, or leave it alone if it is already running.
##
## Idempotent on purpose: this is called every physics frame the car is gaining
## ground, and a play() on each of those would restart the sample sixty times a
## second — the engine has to sound like one continuous pull, not a stutter.
##
## Catching it mid-wind-down restarts from the top rather than resuming, which
## is the right sound: a truck that has dropped its revs and then gets moving
## again pulls away again, it doesn't resume at speed.
func start_engine() -> void:
	if _engine == null or _engine_sample == null:
		return
	if _engine.playing and not _engine_releasing:
		return
	_engine_sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_engine_releasing = false
	_engine.play()


## Let the engine wind down instead of cutting it dead.
##
## The recording already contains the wind-down — it is everything after
## ENGINE_LOOP_END_FRAMES, which is why the loop had to be cut short of it in the first
## place. So releasing the engine is simply switching the loop off: playback
## carries straight on out of the loop region and into the truck slowing to a
## halt, then stops itself at the end of the file.
##
## Nothing is spliced and nothing is faded. The tail is the literal continuation
## of the samples already playing, so there is no join to hear — which is worth
## more than any crossfade between two clips would have been.
func stop_engine() -> void:
	if _engine == null or _engine_sample == null:
		return
	if not _engine.playing or _engine_releasing:
		return
	_engine_sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
	_engine_releasing = true


## Kill the engine outright, wind-down and all. For starting a fresh attempt,
## where a tail left over from the last one would play under the new pull-away.
func cut_engine() -> void:
	if _engine == null:
		return
	_engine.stop()
	_engine_releasing = false


## Play the track belonging to a level, crossfading from whatever is playing.
##
## Called by the game when a level loads, and by the title screen with the level
## the save is sitting on — so somebody who has beaten level 1 and comes back to
## Continue is met by the music they left off with rather than the opening theme.
func set_level_music(level_index: int) -> void:
	if TRACKS.is_empty():
		return
	play_track(TRACKS[clampi(level_index, 0, TRACKS.size() - 1)])


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
	var bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(bus, master_volume < SILENCE_THRESHOLD)
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		_apply_volume()
		return
	master_volume = float(config.get_value("audio", "master_volume", master_volume))


## Called when the player lets go of the slider, not on every drag step — this
## writes a file, and a slider emits dozens of changes per second.
func save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)

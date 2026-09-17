## The game's first scene: the loading screen with its bar cleaning, and then the lake.
##
## `run/main_scene` (2026-09-17, `/grill-me` with Richard). The engine's splash is a
## photograph of `LoadingScreen` with the bar filthy, so this scene's first frame is the
## splash's own picture and what follows is only the bar starting to move: filthy to clean
## over `SWEEP`, the clean water coming in from the right as it does on the HUD's meter, the
## game's whole promise as its loading bar. When it is
## clean the lake is put in — the screen stands still for the half second the lake takes to
## build, with the bar already full, which reads as a beat rather than a hang — and the
## lake comes up under its own curtain drawing this same picture (`Curtain.open_on`) and
## dissolves it onto the menu.
##
## **A timed sweep, not a reading, by decision** (Richard: "bring the loading meter
## anyways... It doesn't matter if it loads too quickly"). `main.tscn` is loaded on a thread
## while the bar moves, but that takes 20 ms (`tools/probe_boot.tscn`); the lake's build is
## main thread and nothing can be drawn during it. The sweep costs every boot its length,
## which was weighed and taken. Not skippable: it is under a second.
##
## A reload comes through here too (`Lake._reload_as`: New game over a run), off a curtain
## showing this same picture, so there is one loading screen in the game.
class_name Boot
extends Node

const LAKE := "res://scenes/main.tscn"
## How long the bar takes to clean, in seconds, and the beat it stands clean before the
## lake is put in — long enough to be drawn full at least once.
const SWEEP := 0.9
const FULL_BEAT := 0.08
## The longest step the clock takes in one frame. The first frame after the engine's own
## start can be a long one, and the sweep is not to lose its opening to it.
const STEP_MOST := 1.0 / 30.0

var _screen: LoadingScreen
var _age: float = 0.0
var _going: bool = false


func _ready() -> void:
	_screen = LoadingScreen.new()
	_screen.name = &"Loading"
	add_child(_screen)
	ResourceLoader.load_threaded_request(LAKE)


## How clean the bar reads `age` seconds in: eased at both ends, so it sets off and lands
## rather than starting and stopping.
static func sweep_at(age: float) -> float:
	var t := clampf(age / SWEEP, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


func _process(delta: float) -> void:
	if _going:
		return
	_age += minf(delta, STEP_MOST)
	_screen.progress = sweep_at(_age)
	if _age < SWEEP + FULL_BEAT:
		return
	match ResourceLoader.load_threaded_get_status(LAKE):
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		ResourceLoader.THREAD_LOAD_LOADED:
			_going = true
			get_tree().change_scene_to_packed(
				ResourceLoader.load_threaded_get(LAKE) as PackedScene
			)
		_:
			# The threaded load would not have it: the plain way, which says why on its own.
			_going = true
			get_tree().change_scene_to_file(LAKE)

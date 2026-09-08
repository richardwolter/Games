## Runs the real game in a real window and reports how long its frames take.
##
## The harness in test_lake.gd is headless, so it never draws, and a stutter is a drawing
## problem as often as a logic one. This opens the actual scene, throws away the first
## ninety frames while the atlas and the shaders warm up, and then times six hundred.
##
## What matters in the output is not the mean — vsync pins that near 16.7 ms whatever
## happens — but how many frames went over 20 ms. Those are the ones that missed the
## refresh and got shown twice, and a run of them is what "choppy" means.
##
## BENCH_OFF turns suspects off so their cost can be read off the difference:
##   BENCH_OFF=ripple   the ring layer under the floating junk
##   BENCH_OFF=water    every shader on the lake
##   BENCH_OFF="ripple water"
##
##   godot --path . res://tools/bench_frames.tscn
extends Node

const WARMUP := 90
const SAMPLES := 600

var _main: Node2D
var _n: int = 0
var _times: PackedFloat32Array = PackedFloat32Array()
var _last: int = 0

func _ready() -> void:
	_main = load("res://scenes/main.tscn").instantiate()
	_main.set(&"autoload_save", false)
	add_child(_main)
	var mode := OS.get_environment("BENCH_OFF")
	if mode.contains("ripple"):
		var r := _main.get_node(^"Grid").get_node(^"Ripples") as Node2D
		r.set_process(false)
		r.visible = false
	if mode.contains("water"):
		var fill := _main.get_node(^"Sky/Fill") as CanvasItem
		fill.material = null
		for child in _main.get_node(^"Grid").get_children():
			(child as CanvasItem).material = null
		(_main.get_node(^"Grid") as CanvasItem).material = null
	print("bench mode: ", mode)
	_last = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var ms := float(now - _last) / 1000.0
	_last = now
	_n += 1
	if _n <= WARMUP:
		return
	_times.append(ms)
	if _times.size() < SAMPLES:
		return
	var sorted := Array(_times)
	sorted.sort()
	var total := 0.0
	for t in sorted:
		total += t
	var spikes := 0
	for t in sorted:
		if t > 20.0:
			spikes += 1
	print("frames %d  mean %.2f ms  median %.2f  p95 %.2f  p99 %.2f  worst %.2f  over-20ms %d (%.1f%%)" % [
		sorted.size(), total / sorted.size(), sorted[sorted.size() / 2],
		sorted[int(sorted.size() * 0.95)], sorted[int(sorted.size() * 0.99)],
		sorted[sorted.size() - 1], spikes, 100.0 * float(spikes) / float(sorted.size())
	])
	print("grid rebuilds: ", (_main.get_node(^"Grid")).get("rebuilds"))
	get_tree().quit()

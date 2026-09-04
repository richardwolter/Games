## What shape a level's backdrop canvas has to be to come out undistorted.
##
##   godot --headless --script tools/backdrop_aspect.gd
##
## Backdrop.fit_to() scales x and y independently so that the painting always
## covers the camera's bounds with no edge to find. That is the right trade for
## the fit and the wrong one for the picture: whatever shape the bounds are, the
## painting is squashed into it. A level with a wide strait and a shallow one
## both get the same texture stretched by different amounts.
##
## There is exactly one canvas shape per level that comes out square: the one
## where fit_to()'s two scales agree. This prints it, per level, next to what the
## texture currently is — so a backdrop can be padded to the right shape with
## tools/pad_backdrop.gd --aspect=<printed value> instead of by eye.
##
## The arithmetic mirrors World._frame_camera() and Backdrop.fit_to(). If either
## changes, this drifts and every number it prints is wrong, so it re-derives
## from World's own constants rather than copying the numbers.
extends SceneTree

const LEVELS := "res://data/levels"


func _initialize() -> void:
	var world: GDScript = load("res://scripts/world.gd")
	var names := DirAccess.get_files_at(LEVELS)
	names.sort()
	for name: String in names:
		if not name.ends_with(".tres"):
			continue
		var level := load("%s/%s" % [LEVELS, name]) as LevelDef
		if level == null:
			continue
		_report(name, level, world)
	quit()


func _report(name: String, level: LevelDef, world: GDScript) -> void:
	var surface: float = world.get(&"SURFACE_Y")
	var headroom: float = world.get(&"HEADROOM")
	var deep_margin: float = world.get(&"DEEP_MARGIN")

	# The shore run, as World works it out: long enough for the slope and its
	# plateau, and for the near ramp plus its run-up.
	var shore_run: float = maxf(world.get(&"SHORE_RUN"),
		level.far_slope_run() + world.get(&"SLOPE_PLATEAU"))
	var near_run: float = level.near_ramp_run if level.near_ramp_rise > 0.0 else 0.0
	shore_run = maxf(shore_run, near_run + LevelDef.NEAR_RUNUP + 200.0)

	var high_ground: float = maxf(level.far_shore_lift, level.near_ramp_rise)
	# A cave's roof stands in for the headroom, and the camera is then let a
	# little past it so the rock is visible rather than being the top row.
	if level.cave_roof > 0.0:
		headroom = level.cave_roof + world.get(&"ROOF_VIEW")
	var ceiling: float = surface - high_ground - headroom
	var painted_bottom: float = surface + level.max_depth + 300.0

	var width: float = (level.half_width + shore_run) * 2.0
	# fit_to() takes whichever half needs the larger vertical scale, so the
	# canvas has to satisfy that one.
	var above: float = surface - ceiling
	var below: float = painted_bottom - surface
	var half: float = maxf(above, below)

	var texture := ""
	if level.backdrop != null:
		var size := level.backdrop.get_size()
		texture = "  texture %dx%d = %.3f" % [size.x, size.y, size.x / size.y]

	# `half` covers one side of the horizon; the canvas it is measured against is
	# horizon_frac of the texture, so the full-height equivalent is half / frac.
	var frac: float = clampf(level.backdrop_horizon, 0.05, 0.95)
	var canvas_height: float = half / minf(frac, 1.0 - frac)
	print("%-14s wanted aspect %.3f%s  (deep margin %d ignored)" % [
		name, width / canvas_height, texture, int(deep_margin)
	])

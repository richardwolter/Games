## How far the net has to throw to reach every shore: for each point round the outer bank's water
## edge, the shortest distance from anywhere the angler can stand, and the worst of those.
## The tree's last range node has to cover the worst, or some bank is out of reach for ever.
##
## Run: <godot> --headless --path . --script res://tools/probe_reach.gd --log-file tools/last_reach_engine.log
## Output: tools/last_reach.log.
extends SceneTree

const OUT := "res://tools/last_reach.log"
## How far past the waterline the angler may wade, in world px (Angler.WALK_LIMIT).
const WADE := 26.0


func _init() -> void:
	# Where the angler can stand: every point on a fine grid over the island that is not
	# further out than the wade.
	var stand: Array[Vector2] = []
	var span := Iso.ISLAND_RADIUS * 1.6
	var y := Iso.ISLAND_CENTRE.y - span.y
	while y <= Iso.ISLAND_CENTRE.y + span.y:
		var x := Iso.ISLAND_CENTRE.x - span.x
		while x <= Iso.ISLAND_CENTRE.x + span.x:
			var at := Vector2(x, y)
			if Iso.past_water(at) < WADE:
				stand.append(at)
			x += 0.25
		y += 0.25
	# The outer rim of where the angler stands is all that matters for distance.
	var rim: Array[Vector2] = []
	for at in stand:
		if Iso.past_water(at) > WADE - 12.0:
			rim.append(at)
	if rim.is_empty():
		rim = stand
	var lines: PackedStringArray = []
	var worst := 0.0
	var worst_at := Vector2.ZERO
	var steps := 720
	var total := 0.0
	for i in steps:
		var angle := TAU * float(i) / float(steps)
		# Walk out from the island along the bearing to the last water tile before the bank.
		var dir := Vector2(cos(angle), sin(angle))
		var edge := Vector2.INF
		var r := 1.0
		while r < 80.0:
			var p := Iso.ISLAND_CENTRE + dir * r
			if Iso.shore_fraction(p.x, p.y) >= 1.0:
				break
			edge = p
			r += 0.05
		if edge == Vector2.INF:
			continue
		var best := INF
		for s in rim:
			best = minf(best, s.distance_to(edge))
		total += best
		if best > worst:
			worst = best
			worst_at = edge
	lines.append("stand points %d, rim %d" % [stand.size(), rim.size()])
	lines.append("worst shore distance %.2f tiles at %s (bearing from island %.0f deg)" % [
		worst, str(worst_at), rad_to_deg((worst_at - Iso.ISLAND_CENTRE).angle())])
	lines.append("mean shore distance %.2f tiles" % (total / float(steps)))
	var f := FileAccess.open(OUT, FileAccess.WRITE)
	f.store_string("\n".join(lines) + "\n")
	f.close()
	quit()

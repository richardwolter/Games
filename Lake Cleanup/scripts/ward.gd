## The shed under siege: what is left of it, and what is standing between it and the lake.
##
## The hut itself is drawn by the lake, because it is scenery and it was there first. This
## is the part that only exists while something is trying to knock it down — the shield the
## player nets in, the damage that gets through it, and the dome over the roof that says
## which of those two is winning.
##
## It owns the numbers as well as the picture, because they are the same thing: a shield
## that is not visible is a stat, and a stat is not what the player is defending.
class_name Ward
extends Node2D

## What the shed can take, and what one netted shield charm adds to the pool in front of
## it. Shield accumulates rather than expiring — it is a wall being built, and it stands
## until something knocks it down.
const HEALTH := 120.0
const SHIELD_PER := 30.0
const SHIELD_MAX := 90.0

## How fast the dome settles to a new size, per second. Eased so a blow reads as the dome
## flexing rather than as a number changing.
const DOME_EASE := 6.0

## How long a hit flashes for, in seconds.
const FLASH := 0.35

## The dome's radii, in world pixels, at full shield.
const DOME := Vector2(96.0, 62.0)

var health: float = HEALTH
var shield: float = 0.0

## Emitted when the shield takes a blow and when the last of the health goes.
signal shielded(left: float)
signal hurt(left: float)
signal fell

var sfx: Sfx

var _dome: float = 0.0
var _flash: float = 0.0
var _flash_shield: bool = false
var _time: float = 0.0
var _down: bool = false


## Take a blow. Shield first, always: that is what makes netting a shield charm early
## worth more than netting one when the roof is already going.
func take(damage: float) -> void:
	if _down or damage <= 0.0:
		return
	_flash = FLASH
	_flash_shield = shield > 0.0
	if shield > 0.0:
		var stopped := minf(shield, damage)
		shield -= stopped
		damage -= stopped
		shielded.emit(shield)
		if sfx != null:
			sfx.play_pop()
	if damage <= 0.0:
		queue_redraw()
		return
	health = maxf(health - damage, 0.0)
	hurt.emit(health)
	if sfx != null:
		sfx.play_splash(0.8)
	if health <= 0.0:
		_down = true
		fell.emit()
	queue_redraw()


## Put another layer on the wall.
func add_shield(amount: float = SHIELD_PER) -> void:
	shield = minf(shield + amount, SHIELD_MAX)
	shielded.emit(shield)
	queue_redraw()


## Patch the roof. Bought at the shed counter, so it cannot exceed what a shed is.
func repair(amount: float) -> void:
	if _down:
		return
	health = minf(health + amount, HEALTH)
	queue_redraw()


func is_down() -> bool:
	return _down


## 0 to 1, for the HUD and for the dome.
func health_left() -> float:
	return clampf(health / HEALTH, 0.0, 1.0)


func shield_left() -> float:
	return clampf(shield / SHIELD_MAX, 0.0, 1.0)


func _process(delta: float) -> void:
	_time += delta
	_flash = maxf(_flash - delta, 0.0)
	var wants := shield_left()
	if absf(_dome - wants) > 0.001 or _flash > 0.0:
		_dome = lerpf(_dome, wants, clampf(DOME_EASE * delta, 0.0, 1.0))
		queue_redraw()


func _draw() -> void:
	if _dome > 0.001:
		_draw_dome()
	if health_left() < 1.0 and not _down:
		_draw_damage()
	if _flash > 0.0 and not _flash_shield:
		# A hit that got through, drawn as the ground under the hut lighting up: the shed's
		# own picture belongs to the lake, so this is the one mark that can be made on it
		# without two scripts drawing the same hut.
		var bite := _flash / FLASH
		draw_circle(Vector2.ZERO, 44.0, Color(0.9, 0.25, 0.18, 0.28 * bite))


## The shield over the roof: a dome, drawn as two arcs of the same flattened ellipse so it
## sits on the plane the way everything else here does. Brighter and larger the more of it
## there is, so the player reads the wall going up as they feed the box.
func _draw_dome() -> void:
	var extent := DOME * (0.55 + 0.45 * _dome)
	var lit := 0.20 + 0.30 * _dome
	if _flash > 0.0 and _flash_shield:
		lit += 0.35 * (_flash / FLASH)
	var shimmer := 0.04 * sin(_time * 2.6)

	var shell := PackedVector2Array()
	for i in 34:
		var angle := PI * float(i) / 33.0
		shell.append(Vector2(
			cos(angle) * extent.x * (1.0 + shimmer),
			-sin(angle) * extent.y * (1.0 + shimmer) - Iso.SHED_TALL * 0.25
		))
	# Closed along the ground so the dome is a solid the hut stands inside.
	var body := shell.duplicate()
	body.append(Vector2(extent.x, -Iso.SHED_TALL * 0.25))
	body.append(Vector2(-extent.x, -Iso.SHED_TALL * 0.25))
	draw_colored_polygon(body, Color(0.55, 0.85, 1.0, lit * 0.35))
	draw_polyline(shell, Color(0.78, 0.95, 1.0, lit + 0.25), 2.4)

	# The footprint it stands in, so the dome reads as resting on the island rather than
	# floating over it.
	var floor_ring := PackedVector2Array()
	for i in 30:
		var angle := TAU * float(i) / 29.0
		floor_ring.append(Vector2(cos(angle) * extent.x, sin(angle) * extent.y * 0.30))
	draw_polyline(floor_ring, Color(0.72, 0.92, 1.0, lit * 0.6), 1.6)


## What the blows have done: soot and splits on the ground around the hut, thickening as
## the health goes. Around it rather than on it, for the same reason as the flash.
func _draw_damage() -> void:
	var gone := 1.0 - health_left()
	var marks := int(gone * 9.0) + 1
	for i in marks:
		var angle := TAU * float(i) / float(marks) + 0.6
		var at := Vector2(cos(angle) * 40.0, sin(angle) * 22.0 - 4.0)
		draw_circle(at, 4.0 + 5.0 * gone, Color(0.10, 0.08, 0.07, 0.35 * gone))
		draw_line(
			at, at + Vector2(cos(angle), sin(angle) * 0.5) * (7.0 + 9.0 * gone),
			Color(0.16, 0.12, 0.10, 0.5 * gone), 1.8
		)

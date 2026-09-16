## The pad's reticle: where the net goes when the right stick is aiming it.
##
## Decided with `/grill-me` (issue #33, 2026-09-14):
## - **A free reticle.** The stick sets its speed, not its place, and it stays where it was
##   left — on the water, not on the angler, so walking does not carry it. Speed is in view
##   heights a second, so it crosses the screen at one pace at every zoom.
## - **The view edge pushes it** (`hold_in`). The lake leans the camera towards it
##   (`Lake._pad_framed`), but the angler is kept on screen first, so a player who walks away
##   from a pinned reticle drags it along by the edge of the window.
## - **The assist is subtle, and only acts while the stick is pushed.** Over a spot where
##   the marker is green the reticle slows (`FRICTION`), and short of one it drifts towards
##   the nearest green spot within `REACH` (`PULL`) — never one behind where it is being
##   pushed. A stick let go of leaves the reticle exactly where it is: nothing creeps, and
##   nothing locks on. Green is the marker's own verdict (`CastNet.would_catch`), so what the
##   assist favours is what the player is shown.
##
## Every number here is a first guess for Richard to retune in play.
class_name PadAim
extends RefCounted

## Full push, in view heights a second, and the curve on the push: over one, so a light push
## is fine placement and a full one crosses the screen in about a second.
const SPEED := 0.9
const CURVE := 1.8

## What of its speed the reticle keeps while it is over a green spot.
const FRICTION := 0.55

## How hard the reticle drifts towards a green spot, as a share of the speed the stick is
## asking for — so a gentle push is gently helped and a still stick is not helped at all.
const PULL := 0.3

## How far off a green spot may be and still pull: this many mouth widths (the open mouth's
## extent), but never under `REACH_LEAST` tiles, or the starting net, a few pixels wide,
## would help with nothing.
const REACH := 1.0
const REACH_LEAST := 1.0

## The cosine under which a spot counts as behind the push and is passed over. A little
## under zero, so a spot just to the side still bends the aim.
const AHEAD := -0.2

## How far inside the window's edge the reticle is held, in screen pixels.
const EDGE := 12.0

## World pixels, or INF when there is no reticle (the mouse is aiming).
var at := Vector2.INF

## What the last step found, for the harness and the curious: whether the reticle was over
## green, and the spot it was drifting to (INF for none).
var over_green: bool = false
var pulled_to := Vector2.INF


## One frame of aiming. `stick` is the right stick, `view` the world rectangle on screen.
func step(delta: float, stick: Vector2, view: Rect2, net: CastNet) -> void:
	over_green = false
	pulled_to = Vector2.INF
	if at == Vector2.INF or stick == Vector2.ZERO:
		return
	var push := pow(minf(stick.length(), 1.0), CURVE)
	var heading := stick.normalized()
	var speed := push * SPEED * view.size.y
	var move := heading * speed
	if net != null:
		over_green = net.would_catch(at)
		if over_green:
			move *= FRICTION
		else:
			var reach := maxf(net.open_extent() * REACH, Iso.tile_circle_extent(REACH_LEAST))
			var spot := net.nearest_catch(at, reach, heading, AHEAD)
			if spot != Vector2.INF:
				pulled_to = spot
				var toward := spot - at
				move += toward.normalized() * minf(speed * PULL, toward.length() / maxf(delta, 0.0001))
	at += move * delta


## Keep the reticle on screen. Run every frame, stick or no stick: this is the edge pushing
## a pinned reticle along when the view leaves it behind.
func hold_in(view: Rect2, zoom: float) -> void:
	if at == Vector2.INF:
		return
	var inset := minf(EDGE / maxf(zoom, 0.0001), minf(view.size.x, view.size.y) * 0.5)
	at = at.clamp(view.position + Vector2.ONE * inset, view.end - Vector2.ONE * inset)

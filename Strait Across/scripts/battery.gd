## The charge in an electric truck, for the length of one attempt.
##
## Two drains, and they are meant to feel completely different. The bleed is slow
## and predictable — it turns a crossing into something with a clock on it, so a
## bridge that works but takes a minute to crawl over is a different proposition
## from one that works in ten seconds. The splash is a punch: driving through the
## water is survivable once and fatal three times, which is exactly the choice the
## game wants a player weighing while they build.
##
## Plain data with a tick, made by SalvageUpgrades and ticked by Car. Nothing here
## is a node: a battery belongs to one truck and dies with it.
class_name Battery
extends RefCounted

## Water bobs. A chassis riding the surface crosses the Area2D boundary several
## times a second, and one splash per crossing empties a full battery in under a
## second — which reads as the feature being broken rather than as a hard dunk.
## The cooldown makes a splash mean "went in", not "touched the line".
const SPLASH_COOLDOWN := 0.6

var capacity: float = 100.0
var charge: float = 100.0
## Bleed per second while driving.
var drain_per_second: float = 3.0
## Taken off each time the chassis goes in the water.
var splash_drain: float = 25.0

var _splash_cooldown: float = 0.0


func _init(from_capacity: float, from_splash: float) -> void:
	capacity = maxf(from_capacity, 1.0)
	charge = capacity
	splash_drain = maxf(from_splash, 0.0)


func fraction() -> float:
	return clampf(charge / capacity, 0.0, 1.0)


func is_empty() -> bool:
	return charge <= 0.0


func tick(delta: float) -> void:
	_splash_cooldown = maxf(_splash_cooldown - delta, 0.0)
	charge = maxf(charge - drain_per_second * delta, 0.0)


func take_splash() -> void:
	if _splash_cooldown > 0.0:
		return
	_splash_cooldown = SPLASH_COOLDOWN
	charge = maxf(charge - splash_drain, 0.0)

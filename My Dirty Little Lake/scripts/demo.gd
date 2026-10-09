## The Steam demo (2026-10-09, `/grill-me` with Richard). One codebase: an export with the
## `demo` feature tag is the demo, and everything that differs asks here.
##
## The demo is the full game with every upgrade track capped short, so the net never reaches
## past the water round the island. Buying the last level the demo sells brings down one
## tornado; taming it, or letting it go, ends the demo with the thanks, the credits and a
## Wishlist door. No hive swarm, no scheduled tornado, its own save file.
class_name Demo
extends RefCounted

## The store page the Wishlist door opens.
const STORE_URL := "https://store.steampowered.com/app/5375170/"
## Its own save, so a demo run never meets a full game's file.
const SAVE_PATH := "user://my_dirty_little_lake_demo.save"

## Where each track stops in the demo. A track missing here is not sold at all (cap 0).
## First guesses, for the demo's economy pass and Richard's logged run.
const CAPS := {
	&"net_width": 6,
	&"net_strength": 1,
	&"net_range": 4,
	&"reel": 6,
	&"net_hold": 3,
	&"boat_speed": 5,
	&"cargo": 3,
	&"boat_volley": 1,
	&"fleet": 1,
	&"dog_fetch": 1,
	&"dog_wait": 1,
	&"dog_strength": 1,
	&"dog_count": 1,
	&"recycle_bonus": 2,
	&"bird_worth": 3,
	&"lucky_haul": 3,
	&"double_cast": 3,
}

## Finds are dealt only this many tiles past the island's shelf (the capped Range, from the
## beach) and only up to this tier (the capped Strength). First guesses.
const REACH := 9.0
const FIND_TIER := 1

## Prices the demo sets for itself, `track: [price_base, price_mult]`. A track missing here
## keeps the full game's price. Empty until the demo's economy pass.
const PRICES := {}

## A test may switch the demo on by hand; otherwise the export's feature tag decides.
static var forced := false


static func on() -> bool:
	return forced or OS.has_feature("demo")


## Where a track stops: the demo's cap, never past the full game's own.
static func cap(what: StringName, full: int) -> int:
	if not on():
		return full
	return mini(int(CAPS.get(what, 0)), full)


## What the next level costs, the demo's price where it sets one.
static func cost(what: StringName, track: UpgradeTrack, level: int) -> float:
	if on() and PRICES.has(what):
		var price: Array = PRICES[what]
		return float(price[0]) * pow(float(price[1]), float(level))
	return track.cost(level)

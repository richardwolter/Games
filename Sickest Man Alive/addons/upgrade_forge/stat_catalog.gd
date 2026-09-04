@tool
extends RefCounted

## What an upgrade is allowed to touch, worked out from the game rather than
## typed out here.
##
## Every stat in the dropdowns comes from asking a real AttackStats or
## PlayerStats what properties it has. Add `@export var lifesteal: float` to
## AttackStats and it appears in the dock, correctly typed, with no change here.
## The alternative -- a hand-kept list -- is a list that goes stale silently and
## lets someone author a modifier for a stat that does not exist.

const ModScript := preload("res://src/stat_modifier.gd")

## What each target is called on screen. The enum names mean nothing to anyone
## who has not read stat_modifier.gd.
const TARGET_LABELS: Array[String] = [
	"the syringe (ranged)",
	"the scalpel (melee)",
	"both weapons",
	"the kid himself",
]

## Operations, as verbs. `phase` is NOT offered anywhere: it is derived from the
## operation (see phase_for), because the one combination that breaks the
## pipeline's order-independence is an ADD and a MULTIPLY sharing a phase, and
## the surest way to prevent that is to make it unauthorable.
const OP_LABELS: Dictionary = {
	0: "add",
	1: "multiply by",
	2: "set to",
	3: "add to the list",
	4: "blend towards",
}

## Status effects the game actually implements. Poison ticks damage, freeze stops
## movement (see Enemy._tick_statuses and Enemy.chill_factor). Adding a third
## status means teaching Enemy about it first, so this list is deliberately not
## free text.
const STATUS_IDS: Array[String] = ["poison", "freeze"]


## Every stat that a modifier aimed at `target` could name, with its type.
static func stats_for_target(target: int) -> Array[Dictionary]:
	var probe: Resource = PlayerStats.new() if target == ModScript.Target.PLAYER \
		else AttackStats.new()
	var out: Array[Dictionary] = []
	for p: Dictionary in probe.get_property_list():
		if not (int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE):
			continue
		if not (int(p["usage"]) & PROPERTY_USAGE_EDITOR):
			continue
		out.append({
			"name": StringName(p["name"]),
			"type": int(p["type"]),
			"class": String(p.get("hint_string", "")),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]) < String(b["name"]))
	return out


static func find_stat(target: int, name: StringName) -> Dictionary:
	for s in stats_for_target(target):
		if s["name"] == name:
			return s
	return {}


## Which operations make sense for a stat of this type. This is where invalid
## data stops being possible: a bool has nothing to multiply, a colour has
## nothing to add, and APPEND is offered only where StatModifier will accept it.
static func ops_for(stat: Dictionary) -> Array[int]:
	if stat.is_empty():
		return []
	if String(stat["name"]) in ModScript.APPENDABLE:
		return [3]
	match int(stat["type"]):
		TYPE_FLOAT, TYPE_INT:
			return [0, 1, 2]
		TYPE_BOOL:
			return [2]
		TYPE_COLOR:
			return [2, 4]
		_:
			return []


## Why a stat cannot be edited, or "" when it can. Shown to the author instead of
## the row simply not working.
static func unsupported_reason(stat: Dictionary) -> String:
	if stat.is_empty():
		return "unknown stat"
	if not ops_for(stat).is_empty():
		return ""
	match int(stat["type"]):
		TYPE_OBJECT:
			return "swapping art from an upgrade is not wired up yet"
		TYPE_ARRAY:
			return "lists can only be added to, and this one is not on StatModifier.APPENDABLE"
		_:
			return "no editor for this kind of value yet"


## The pipeline phase an operation belongs in. Fixed by the operation so that
## everything ADDed resolves before anything MULTIPLIES, which is what makes the
## result independent of the order items were picked up in.
static func phase_for(op: int) -> int:
	match op:
		0:
			return ModScript.Phase.FLAT
		1:
			return ModScript.Phase.PERCENT
		4:
			return ModScript.Phase.VISUAL
		_:
			return ModScript.Phase.OVERRIDE


## The sentence under a row: what this modifier does, in English.
static func describe(stat_name: StringName, target: int, op: int, value: Variant) -> String:
	var readable := String(stat_name).replace("_", " ")
	var who: String = TARGET_LABELS[clampi(target, 0, TARGET_LABELS.size() - 1)]
	match op:
		0:
			return "adds %s to %s on %s." % [_value_text(value), readable, who]
		1:
			return "multiplies %s by %s on %s." % [readable, _value_text(value), who]
		2:
			return "sets %s to %s on %s." % [readable, _value_text(value), who]
		3:
			return "adds %s to %s on %s." % [_value_text(value), readable, who]
		4:
			return "blends %s towards %s on %s (mixed with every other tint in the build, not stacked)." \
				% [readable, _value_text(value), who]
	return ""


static func _value_text(value: Variant) -> String:
	match typeof(value):
		TYPE_DICTIONARY:
			var parts: Array[String] = []
			for k: String in (value as Dictionary):
				parts.append("%s %s" % [k, (value as Dictionary)[k]])
			return ", ".join(parts)
		TYPE_COLOR:
			return "that colour"
		TYPE_BOOL:
			return "on" if bool(value) else "off"
		TYPE_FLOAT:
			return String.num(float(value), 2)
	return str(value)

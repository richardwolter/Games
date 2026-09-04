@tool
class_name StatModifier
extends Resource

## One item = one or more StatModifiers.
## Items NEVER touch a weapon or the player. They only declare intent here.
##
## Order is explicit and total, so two items picked up in either order produce
## the SAME result. Three things are required for that to actually be true:
##   1. phase ordering (FLAT before PERCENT before OVERRIDE before VISUAL),
##   2. a deterministic tie-break, because Array.sort_custom is NOT stable,
##   3. commutative operators -- see the BLEND aggregation in apply_all().

enum Phase {
	FLAT,      ## +2 damage
	PERCENT,   ## +50% damage
	OVERRIDE,  ## set sprite, force homing
	VISUAL,    ## tint blends, trails, shaders
}

enum Op { ADD, MULTIPLY, SET, APPEND, BLEND }

## Which stat block this modifier is allowed to write to. With two weapons,
## "+2 damage" is meaningless without this.
enum Target { RANGED, MELEE, BOTH_WEAPONS, PLAYER }

## Only these stats may be APPENDed to. Everything else is a bug, not a
## clever trick -- APPEND on a scalar silently does nothing, which is worse
## than a crash. Keep this list short and make adding to it a decision.
const APPENDABLE: PackedStringArray = ["statuses", "impact_effects", "shader_flags"]

@export var stat: StringName = &"damage"
@export var target: Target = Target.RANGED
@export var phase: Phase = Phase.FLAT
@export var op: Op = Op.ADD
@export var value: Variant = 0.0
## Higher wins ties inside a phase. Legendary items sit high.
@export var priority: int = 0
## Stable, unique-per-item tie-break. Without it, two modifiers with the same
## phase and priority sort in arbitrary order and the same build can resolve
## differently between runs.
@export var id: StringName = &""


static func sort_pipeline(mods: Array[StatModifier]) -> Array[StatModifier]:
	var out := mods.duplicate()
	out.sort_custom(func(a: StatModifier, b: StatModifier) -> bool:
		if a.phase != b.phase:
			return a.phase < b.phase
		if a.priority != b.priority:
			return a.priority < b.priority
		if a.id != b.id:
			return String(a.id) < String(b.id)
		return String(a.stat) < String(b.stat)
	)
	return out


## `base` is an AttackStats or a PlayerStats. `mods` must already be filtered
## to the ones that target it -- see Loadout.
static func apply_all(base: Resource, mods: Array[StatModifier]) -> Resource:
	var s: Resource = base.duplicate_stats()

	# BLEND is a mean, not a chain. lerp(0.5) applied pairwise is not
	# associative, so chaining it would make pickup order matter for colour.
	# Collect every blend per stat and mix once against the base.
	var blends: Dictionary = {}
	var sequential: Array[StatModifier] = []
	for m in mods:
		if m.op == Op.BLEND:
			if not blends.has(m.stat):
				blends[m.stat] = [] as Array[Color]
			blends[m.stat].append(m.value as Color)
		else:
			sequential.append(m)

	for m in sort_pipeline(sequential):
		m.apply(s)

	for stat_name: StringName in blends:
		if not (stat_name in s):
			continue
		var acc: Color = s.get(stat_name)
		var list: Array = blends[stat_name]
		# Equal weight to the base and to every contributing item.
		var n := float(list.size() + 1)
		var r := acc.r / n
		var g := acc.g / n
		var b := acc.b / n
		for c: Color in list:
			r += c.r / n
			g += c.g / n
			b += c.b / n
		s.set(stat_name, Color(r, g, b, acc.a))

	return s


func applies_to(t: Target) -> bool:
	if target == Target.BOTH_WEAPONS:
		return t == Target.RANGED or t == Target.MELEE
	return target == t


func apply(s: Resource) -> void:
	if not (stat in s):
		push_warning("StatModifier '%s' targets unknown stat: %s" % [id, stat])
		return

	var current: Variant = s.get(stat)

	match op:
		Op.ADD:
			s.set(stat, current + value)
		Op.MULTIPLY:
			s.set(stat, current * value)
		Op.SET:
			s.set(stat, value)
		Op.APPEND:
			if not APPENDABLE.has(String(stat)):
				push_error("StatModifier '%s': APPEND is not allowed on '%s'. Add it to APPENDABLE deliberately or use a different Op." % [id, stat])
				return
			if current is Array:
				var arr: Array = (current as Array).duplicate()
				if not arr.has(value):
					arr.append(value)
				s.set(stat, arr)
			elif current is Dictionary:
				# Write back through set() like every other branch. Mutating
				# `current` in place happens to work because Dictionary is
				# reference-typed, and that inconsistency is exactly how this
				# escape hatch starts getting abused.
				var d: Dictionary = (current as Dictionary).duplicate(true)
				for k: Variant in (value as Dictionary):
					d[k] = d.get(k, 0.0) + value[k]
				s.set(stat, d)
			else:
				push_error("StatModifier '%s': APPEND on non-container stat '%s'." % [id, stat])
		Op.BLEND:
			# Handled in bulk by apply_all so the result is order-independent.
			# Reaching here means someone called apply() directly.
			if current is Color:
				s.set(stat, (current as Color).lerp(value, 0.5))

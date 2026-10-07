## The clones' traits, as data: every trait is a trade-off (docs/decisoes/2026-10-07-
## caracteristicas.md), written as a list of modifiers. A clone's numbers are recomputed from
## scratch from its whole trait list every time (no incremental apply, see the root
## CLAUDE.md), so the order traits were rolled in never matters.
##
## Modifiers (all optional):
##   move          multiplies walking speed
##   work          multiplies the speed of every task
##   task          {task: factor}, multiplies the speed of one task
##   skip          chance to finish a task's work time and not do it (the bed is left as it was)
##   careful       never makes mistakes: cancels every skip chance
##   harvest_bonus extra produção per harvest
##   grow_boost    multiplies how fast a bed grows once this clone planted or watered it
##   cheer_radius  other clones within this distance work faster...
##   cheer         ...by this factor
##   chat_every    seconds between stops to chat with a clone within cheer_radius...
##   chat_time     ...and how long each stop lasts
## Forte, Glutão, Beliscador and Preguiçoso wait for carrying and food, which they act on.
##
## The HUD text (stat_rows, role_rating) is computed from these same modifiers, never written
## by hand, so it stays right when a number or a trait changes.
class_name Traits
extends RefCounted

const LIST := {
	&"apressado": {
		"label": "Apressado",
		"move": 1.5,
		"work": 1.5,
		"skip": 0.25,
	},
	&"caprichoso": {
		"label": "Caprichoso",
		"work": 0.6,
		"careful": true,
		"harvest_bonus": 1,
	},
	&"dedo_verde": {
		"label": "Dedo Verde",
		"grow_boost": 2.0,
		"task": {Bed.HARVEST: 0.33},
	},
	&"animado": {
		"label": "Animado",
		"cheer_radius": 3.0,
		"cheer": 1.3,
		"chat_every": 8.0,
		"chat_time": 2.0,
	},
}


## `count` distinct traits picked at random.
static func roll(rng: RandomNumberGenerator, count: int) -> Array[StringName]:
	var pool: Array[StringName] = []
	for name: StringName in LIST:
		pool.append(name)
	var picked: Array[StringName] = []
	while picked.size() < count and not pool.is_empty():
		picked.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	return picked


## The numbers a clone with these traits works by, built from scratch.
static func combine(names: Array[StringName]) -> Dictionary:
	var s := {
		"move": 1.0, "work": 1.0, "task": {}, "skip": 0.0, "careful": false,
		"harvest_bonus": 0, "grow_boost": 1.0,
		"cheer_radius": 0.0, "cheer": 1.0, "chat_every": 0.0, "chat_time": 0.0,
	}
	for name in names:
		var t: Dictionary = LIST[name]
		s.move *= t.get("move", 1.0)
		s.work *= t.get("work", 1.0)
		var per_task: Dictionary = t.get("task", {})
		for task: StringName in per_task:
			s.task[task] = s.task.get(task, 1.0) * per_task[task]
		s.skip = maxf(s.skip, t.get("skip", 0.0))
		s.careful = s.careful or t.get("careful", false)
		s.harvest_bonus += t.get("harvest_bonus", 0)
		s.grow_boost *= t.get("grow_boost", 1.0)
		s.cheer_radius = maxf(s.cheer_radius, t.get("cheer_radius", 0.0))
		s.cheer = maxf(s.cheer, t.get("cheer", 1.0))
		s.chat_every = maxf(s.chat_every, t.get("chat_every", 0.0))
		s.chat_time = maxf(s.chat_time, t.get("chat_time", 0.0))
	if s.careful:
		s.skip = 0.0
	return s


static func labels(names: Array[StringName]) -> String:
	var out: PackedStringArray = []
	for name in names:
		out.append(LIST[name].label)
	return ", ".join(out)


const GOOD := "#8be07a"
const BAD := "#ff8a6a"

## Stat names, one per stat, used the same everywhere (panel, docs).
const MOVE_SPEED := "Vel. de movimento"
const WORK_SPEED := "Vel. de trabalho"
const FAIL_CHANCE := "Chance de falha"
const YIELD_BONUS := "Rendimento"
const GROWTH := "Crescimento"
const PAUSES := "Pausas"
const AURA := "Aura"

const ROLE_NAMES := {
	Bed.PLANT: "Plantar",
	Bed.WATER: "Regar",
	Bed.HARVEST: "Colher",
}
## Assumed walk between two tasks in the rating: one bed step (Bed.SIZE + the bed gap).
const RATING_WALK := 3.0


## The clone's stat sheet for the HUD: one row per stat its traits change, good in green,
## bad in red. Rows marked "fora da %" can't be folded into the role rating honestly.
static func stat_rows(stats: Dictionary, names: Array[StringName]) -> PackedStringArray:
	var rows: PackedStringArray = []
	if stats.move != 1.0:
		rows.append("%s  %s" % [MOVE_SPEED, _pct(stats.move)])
	var speeds := {}
	for role: StringName in ROLE_NAMES:
		speeds[role] = stats.work * stats.task.get(role, 1.0)
	var uniform: bool = speeds.values().all(func(v: float) -> bool:
		return is_equal_approx(v, speeds[Bed.PLANT]))
	if uniform and speeds[Bed.PLANT] != 1.0:
		rows.append("%s  %s" % [WORK_SPEED, _pct(speeds[Bed.PLANT])])
	elif not uniform:
		var parts: PackedStringArray = []
		for role: StringName in ROLE_NAMES:
			parts.append("%s %s" % [ROLE_NAMES[role], _pct(speeds[role])])
		rows.append("%s  %s" % [WORK_SPEED, "  ".join(parts)])
	if stats.skip > 0.0:
		rows.append("%s  %s" % [FAIL_CHANCE, _color(BAD, "%d%%" % roundi(stats.skip * 100.0))])
	elif stats.careful and names.any(func(n: StringName) -> bool: return LIST[n].has("skip")):
		rows.append("%s  %s" % [FAIL_CHANCE, _color(GOOD, "0% (nunca falha)")])
	if stats.harvest_bonus != 0:
		rows.append("%s  %s" % [YIELD_BONUS, _color(GOOD,
				"+%d produção por colheita" % stats.harvest_bonus)])
	if stats.grow_boost != 1.0:
		rows.append("%s  %s nos canteiros que ele planta ou rega" % [GROWTH,
				_pct(stats.grow_boost)])
	if stats.chat_every > 0.0:
		rows.append("%s  %s" % [PAUSES, _color(BAD, "para %s s a cada %s s (com clone perto)"
				% [_num(stats.chat_time), _num(stats.chat_every)])])
	if stats.cheer > 1.0:
		rows.append("%s  %s, fora da %%" % [AURA, _color(GOOD,
				"+%d%% %s dos clones a até %s m" % [roundi((stats.cheer - 1.0) * 100.0),
				WORK_SPEED.to_lower(), _num(stats.cheer_radius)])])
	return rows


## The farm's produção per minute with a clone of these stats in `role` and plain workers in
## the other two roles, as a fraction of the same farm with a plain clone in `role`.
## Steady-state model (docs/decisoes/2026-10-07-painel-do-clone.md):
##   time per finished task  T = (RATING_WALK / walk speed + work time / work speed)
##                               / (1 - fail chance) / (1 - pause share)
##   one bed's cycle         C = T_plant + T_water + T_harvest + GROW_TIME / growth
##   tasks per second        R = min(1/T_plant, 1/T_water, 1/T_harvest, beds / C)
##   produção per second       = R * yield per harvest
## Aura is left out: it depends on where the clones stand.
static func role_rating(stats: Dictionary, role: StringName, beds: int) -> float:
	return _farm_rate(stats, role, beds) / _farm_rate(combine([]), role, beds)


static func _farm_rate(stats: Dictionary, role: StringName, beds: int) -> float:
	var plain := combine([])
	var cycle := 0.0
	var rate := INF
	for r: StringName in ROLE_NAMES:
		var t := _task_time(stats if r == role else plain, r)
		cycle += t
		rate = minf(rate, 1.0 / t)
	var growth: float = stats.grow_boost if role != Bed.HARVEST else 1.0
	cycle += Bed.GROW_TIME / growth
	rate = minf(rate, beds / cycle)
	var per_harvest: int = Bed.YIELD + (stats.harvest_bonus if role == Bed.HARVEST else 0)
	return rate * per_harvest


static func _task_time(stats: Dictionary, role: StringName) -> float:
	var t: float = RATING_WALK / (Worker.SPEED * stats.move) \
			+ Bed.WORK_TIME[role] / (stats.work * stats.task.get(role, 1.0))
	t /= 1.0 - stats.skip
	if stats.chat_every > 0.0:
		t /= 1.0 - stats.chat_time / stats.chat_every
	return t


## "+50%" in green or "-40%" in red, from a multiplier.
static func _pct(factor: float) -> String:
	var pct := roundi((factor - 1.0) * 100.0)
	return _color(GOOD if pct > 0 else BAD, "%s%d%%" % ["+" if pct > 0 else "", pct])


static func _color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


## A number with a decimal comma and no trailing zeros (2, 1,5, 0,33).
static func _num(x: float) -> String:
	return String.num(x, 2).replace(".", ",")

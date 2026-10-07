## The clones' traits, as data: every trait is a trade-off (docs/decisoes/2026-10-07-
## caracteristicas.md), written as a list of modifiers. A clone's numbers are recomputed from
## scratch from its whole trait list every time (no incremental apply, see the root
## CLAUDE.md), so the order traits were rolled in never matters.
##
## Modifiers (all optional):
##   move             multiplies walking speed
##   work             multiplies the speed of every task
##   task             {task: factor}, multiplies the speed of one task
##   skip             chance to finish a bed task's work time and not do it
##   careful          never makes mistakes: cancels every skip chance
##   harvest_bonus    extra crates per harvest
##   grow_boost       multiplies how fast a bed grows once this clone planted or watered it
##   cheer_radius     other clones within this distance work faster...
##   cheer            ...by this factor
##   chat_every       seconds between stops to chat with a clone within cheer_radius...
##   chat_time        ...and how long each stop lasts
##   capacity_bonus   extra crates carried at once
##   tramples         walking over a plant destroys it (only the farmer fixes the bed)
##   consumption      multiplies the food it eats from the trough each meal
##   no_trough        feeds itself: never eats from the trough, never goes hungry
##   waste_every      eats 1 of every N crates it harvests or picks up (they're lost)
##   meal_boost       multiplies work speed for meal_boost_time seconds after each meal
##   nap_every        seconds between naps...
##   nap_time         ...and how long each nap lasts
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
	&"forte": {
		"label": "Forte",
		"capacity_bonus": 1,
		"tramples": true,
	},
	&"glutao": {
		"label": "Glutão",
		"meal_boost": 1.5,
		"meal_boost_time": 20.0,
		"consumption": 2.0,
	},
	&"beliscador": {
		"label": "Beliscador",
		"no_trough": true,
		"waste_every": 4,
	},
	&"preguicoso": {
		"label": "Preguiçoso",
		"consumption": 0.5,
		"nap_every": 15.0,
		"nap_time": 4.0,
	},
}

## Food: each clone eats `consumption` units from the trough every MEAL_EVERY seconds; with
## the trough short it goes hungry (work speed x HUNGRY_WORK) and tries again every
## MEAL_RETRY seconds.
const MEAL_EVERY := 60.0
const MEAL_RETRY := 10.0
const HUNGRY_WORK := 0.5

const CARRY := &"carry"


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
		"capacity_bonus": 0, "tramples": false, "consumption": 1.0, "no_trough": false,
		"waste_every": 0, "meal_boost": 1.0, "meal_boost_time": 0.0,
		"nap_every": 0.0, "nap_time": 0.0,
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
		s.capacity_bonus += t.get("capacity_bonus", 0)
		s.tramples = s.tramples or t.get("tramples", false)
		s.consumption *= t.get("consumption", 1.0)
		s.no_trough = s.no_trough or t.get("no_trough", false)
		s.waste_every = maxi(s.waste_every, t.get("waste_every", 0))
		s.meal_boost = maxf(s.meal_boost, t.get("meal_boost", 1.0))
		s.meal_boost_time = maxf(s.meal_boost_time, t.get("meal_boost_time", 0.0))
		s.nap_every = maxf(s.nap_every, t.get("nap_every", 0.0))
		s.nap_time = maxf(s.nap_time, t.get("nap_time", 0.0))
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
const CAPACITY := "Capacidade de carga"
const TRAMPLE := "Pisoteio"
const CONSUMPTION := "Consumo"
const WASTE := "Desperdício"
const MEAL_BOOST := "Pós-refeição"

const ROLE_NAMES := {
	Bed.PLANT: "Plantar",
	Bed.WATER: "Regar",
	Bed.HARVEST: "Colher",
}
## Assumed walk between two bed tasks, or between two crates, in the rating: one bed step
## (Bed.SIZE + the bed gap).
const RATING_WALK := 3.0
## Assumed walk from the crates to a destination in the rating.
const RATING_CARRY_WALK := 8.0


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
		rows.append("%s  %s  (Carregar %s)" % [WORK_SPEED, "  ".join(parts), _pct(stats.work)])
	if stats.meal_boost > 1.0:
		rows.append("%s  %s" % [MEAL_BOOST, _color(GOOD, "+%d%% %s por %s s depois de comer"
				% [roundi((stats.meal_boost - 1.0) * 100.0), WORK_SPEED.to_lower(),
				_num(stats.meal_boost_time)])])
	if stats.skip > 0.0:
		rows.append("%s  %s" % [FAIL_CHANCE, _color(BAD, "%d%% nos canteiros" % roundi(stats.skip * 100.0))])
	elif stats.careful and names.any(func(n: StringName) -> bool: return LIST[n].has("skip")):
		rows.append("%s  %s" % [FAIL_CHANCE, _color(GOOD, "0% (nunca falha)")])
	if stats.harvest_bonus != 0:
		rows.append("%s  %s" % [YIELD_BONUS, _color(GOOD,
				"+%d caixote por colheita" % stats.harvest_bonus)])
	if stats.grow_boost != 1.0:
		rows.append("%s  %s nos canteiros que ele planta ou rega" % [GROWTH,
				_pct(stats.grow_boost)])
	if stats.capacity_bonus != 0:
		rows.append("%s  %s" % [CAPACITY, _color(GOOD, "+%d caixote (leva %d)" % [
				stats.capacity_bonus, 1 + stats.capacity_bonus])])
	if stats.no_trough:
		rows.append("%s  %s" % [CONSUMPTION, _color(GOOD, "não usa o cocho")])
	elif stats.consumption != 1.0:
		rows.append("%s  %s" % [CONSUMPTION, _color(GOOD if stats.consumption < 1.0 else BAD,
				"x%s do cocho" % _num(stats.consumption))])
	if stats.waste_every > 0:
		rows.append("%s  %s" % [WASTE, _color(BAD,
				"come 1 a cada %d caixotes que colhe ou pega" % stats.waste_every)])
	var pauses: PackedStringArray = []
	if stats.chat_every > 0.0:
		pauses.append("conversa %s s a cada %s s com clone perto" % [_num(stats.chat_time),
				_num(stats.chat_every)])
	if stats.nap_every > 0.0:
		pauses.append("cochila %s s a cada %s s" % [_num(stats.nap_time), _num(stats.nap_every)])
	if not pauses.is_empty():
		rows.append("%s  %s" % [PAUSES, _color(BAD, ", ".join(pauses))])
	if stats.cheer > 1.0:
		rows.append("%s  %s, fora da %%" % [AURA, _color(GOOD,
				"+%d%% %s dos clones a até %s m" % [roundi((stats.cheer - 1.0) * 100.0),
				WORK_SPEED.to_lower(), _num(stats.cheer_radius)])])
	if stats.tramples:
		rows.append("%s  %s, fora da %%" % [TRAMPLE, _color(BAD,
				"destrói as plantas por onde anda")])
	return rows


## The farm's net produção per second (crates delivered, minus this clone's food) with a
## clone of these stats in `role`, as a fraction of the same with a plain clone in `role`.
## Steady-state model (docs/decisoes/2026-10-07-painel-do-clone.md); Aura, Pisoteio and the
## walks to eat are left out (they depend on where things are).
static func role_rating(stats: Dictionary, role: StringName, beds: int) -> float:
	return _net_rate(stats, role, beds) / _net_rate(combine([]), role, beds)


static func _net_rate(stats: Dictionary, role: StringName, beds: int) -> float:
	var crates: float
	if role == CARRY:
		crates = 1.0 / _carry_time(stats) * _kept(stats)
	else:
		# Bed roles: a plain worker in the other two, enough carriers.
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
		crates = rate * Bed.YIELD
		if role == Bed.HARVEST:
			crates = rate * (Bed.YIELD + stats.harvest_bonus) * _kept(stats)
	var food: float = 0.0 if stats.no_trough else stats.consumption / MEAL_EVERY
	return crates - food


## Seconds per finished bed task: walk + work, over the share it doesn't fail and the share
## of time it isn't pausing.
static func _task_time(stats: Dictionary, role: StringName) -> float:
	var t: float = RATING_WALK / (Worker.SPEED * stats.move) \
			+ _work_secs(stats, Bed.WORK_TIME[role], stats.work * stats.task.get(role, 1.0))
	t /= 1.0 - stats.skip
	return t / (1.0 - _pause_share(stats))


## Seconds per crate delivered: fill the hands (a walk and a pick-up per crate), one walk to
## the destination, one drop.
static func _carry_time(stats: Dictionary) -> float:
	var cap: int = 1 + stats.capacity_bonus
	var walk_speed: float = Worker.SPEED * stats.move
	var t: float = cap * (RATING_WALK / walk_speed + _work_secs(stats, Crate.WORK_TIME, stats.work)) \
			+ RATING_CARRY_WALK / walk_speed + _work_secs(stats, Depot.DELIVER_TIME, stats.work)
	return t / cap / (1.0 - _pause_share(stats))


## Work time of a task, averaged over the meal boost: boosted for meal_boost_time of every
## MEAL_EVERY seconds.
static func _work_secs(stats: Dictionary, base: float, speed: float) -> float:
	var f: float = stats.meal_boost_time / MEAL_EVERY if stats.meal_boost > 1.0 else 0.0
	return f * base / (speed * stats.meal_boost) + (1.0 - f) * base / speed


## Share of the time spent in pauses: each pause comes after `every` seconds of activity.
static func _pause_share(stats: Dictionary) -> float:
	var share := 0.0
	if stats.chat_every > 0.0:
		share += stats.chat_time / (stats.chat_every + stats.chat_time)
	if stats.nap_every > 0.0:
		share += stats.nap_time / (stats.nap_every + stats.nap_time)
	return share


## Share of crates that survive a Beliscador.
static func _kept(stats: Dictionary) -> float:
	return 1.0 - 1.0 / stats.waste_every if stats.waste_every > 0 else 1.0


## "+50%" in green or "-40%" in red, from a multiplier.
static func _pct(factor: float) -> String:
	var pct := roundi((factor - 1.0) * 100.0)
	return _color(GOOD if pct > 0 else BAD, "%s%d%%" % ["+" if pct > 0 else "", pct])


static func _color(color: String, text: String) -> String:
	return "[color=%s]%s[/color]" % [color, text]


## A number with a decimal comma and no trailing zeros (2, 1,5, 0,33).
static func _num(x: float) -> String:
	return String.num(x, 2).replace(".", ",")

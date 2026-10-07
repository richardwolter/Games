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

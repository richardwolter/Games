extends Node
## GameState autoload — persistent META progression for the hybrid-roguelite loop.
##
## Milestone 2: retired the old persistent per-hero stat grind (flat XP-bought
## upgrades + skill-tree ability nodes, saved to user://save.json). Runs no
## longer bank permanent stats — a hero always starts a run at its flat base
## stats (see Hero._configure) and grows only through in-run boons (RunState),
## which reset every run. What persists here instead is the META layer: a
## currency earned per run, spent (in a later milestone) to unlock new heroes
## and relics into the pool. See IMPLEMENTATION_PLAN.md M2 / DECISIONS.md.
##
## Dev helper: F12 does a full reset (save + in-run state + persisted fog) and
## returns to the prep menu — see full_reset().

const SAVE_PATH := "user://save.json"
const PREP_MENU := "res://scenes/prep/prep_menu.tscn"
## project.godot's run/main_scene — kept here too so the prep menu and the
## battle HUD can route BACK to it without hardcoding the path twice.
const TITLE_SCREEN := "res://scenes/title/title_screen.tscn"
const BATTLEFIELD := "res://scenes/battlefield/battlefield.tscn"
const FOG_DIR := "user://fog"

## Gold awarded at run end (spent on permanent ability mods at prep). Scales with
## levels cleared this run — deeper runs pay more — with a win bonus on top and a
## floor so even a level-1 wipe pays something. First pass, tune in BALANCE.md.
const GOLD_PER_LEVEL := 10
const GOLD_WIN_BONUS := 15
const GOLD_MIN := 5

## Fraction of a kill's XP every *other* living hero banks (killer gets 100%),
## so tanks/screeners progress even without landing killing blows.
const KILL_ASSIST_SHARE := 0.5

## Save schema version. v3 = hybrid roguelite (persistent stat grind removed).
## v4 = gameplay-loop rework (run = chain of levels; gold + owned ability mods;
## stage_1_won/stage select retired). v5 = V2 grind progression (career
## achievements + ability tiers). v6 = banked_xp changed from per-hero
## Dictionary to a single shared int pool (Designer, 2026-07-19: "XP shared
## between all heroes"). v7 = Duo system (duo_pairings added — see
## duo_of/set_duo_pairings). v8 = per-hero lifetime stat tracking (hero_stats:
## kills/xp/ability hit-rate — display-only, not spendable currency, separate
## from the shared banked_xp pool). v9 = skill trees (skill_ranks +
## duo_ultimate_ranks replace the three flat purchase lists).
##
## v9 is the FIRST version that migrates instead of wiping: a v8 save loads and
## has its ability purchases converted to tree ranks (Designer, 2026-07-26 —
## see _migrate_purchases_to_tree). MIN_LOADABLE_VERSION is the real discard
## floor; anything below it is still a clean break.
const SAVE_VERSION := 9
const MIN_LOADABLE_VERSION := 8

## Roster catalog: display order, colors. Grows as heroes are added.
## Each hero's identity colour — the swatch on its prep card, its deploy label,
## the Duo chain line, its teleport-in FX. Taken from the dominant pigment of
## that hero's own sprite (Designer, 2026-07-26), because these were invented
## before the art existed and had drifted badly: Artemis was pink but is drawn
## in forest green, Warden was teal but is drawn as brown bark. A hero's colour
## is now the colour the player actually sees walking around the field.
##
## All four are mutually distinct, and none is UIStyle.VIOLET — that pigment
## belongs to the Dark Mage and his minions, so nothing friendly wears it.
const HERO_CATALOG := {
	"THUNDAAR": {"color": UIStyle.EMBER},   # tunic
	"ARTEMIS": {"color": UIStyle.FOREST},   # scarf/hood
	"WARDEN": {"color": UIStyle.BARK},      # bark body
	"BEACON": {"color": UIStyle.LIME},      # robe
}

## XP gained per hero in the current run (for the results screen — display only,
## not currency; in-run power comes from RunState's level/boon track).
var run_xp := {}
## Kill count per hero in the current run — display only (hero cards), reset
## by start_run(). See record_hero_kill.
var run_kills := {}
## Special-ability cast attempts/successful-hits per hero in the current run —
## display only (hero cards), reset by start_run(). "Successful" means the
## cast actually affected an enemy (see record_ability_result); basic attacks
## are excluded since they have no miss mechanic and would always read 100%.
var run_ability_attempts := {}
var run_ability_hits := {}

## -- Meta progression ---------------------------------------------------------

## Persistent currency spent at the ability shop on permanent per-hero mods.
var gold := 0
## Ability-mod ids bought and owned forever (AbilityMods catalog). Applied at
## spawn in Hero._apply_owned_ability_mods.
var owned_mods: Array = []
## Ability-tier ids bought and owned forever (AbilityTiers catalog —
## "<HERO>_2"/"<HERO>_3"). Tier-gates the ability flags Hero._configure sets.
## See has_tier/buy_tier.
var owned_ability_tiers: Array = []
## Permanent Duo Ultimate upgrade ids bought and owned forever
## (DuoUltimateMods catalog; the id IS the pair id). Unlike owned_mods these
## are never applied to a Hero instance — they're summed at cast time by
## Hero._ultimate_param via duo_mod_total. See has_duo_mod/buy_duo_mod.
var owned_duo_ultimate_mods: Array = []

## SKILL TREE ranks (2026-07-26) — the gold shop's live data. Everything above
## (owned_mods / owned_ability_tiers / owned_duo_ultimate_mods) is now LEGACY:
## still loaded and still saved so an old save can be re-read, but converted
## once by _migrate_purchases_to_tree and never priced or applied again.
##
## hero_name -> {node_id: int rank}. Signature-ability nodes only.
var skill_ranks: Dictionary = {}
## pair_id -> int rank, for the 4-rank Ultimate nodes. Keyed by PAIR, not hero,
## because both heroes' trees show the same node and it must not be buyable
## twice (see SkillTree.ULTIMATE_RANKS).
var duo_ultimate_ranks: Dictionary = {}
## Heroes currently available for the party/draft. Starts with the full
## roster unlocked (Designer, 2026-07-20: need all 4 heroes day-one to test
## the Duo system — both pairing combinations and staggered deploy need 4
## live heroes). Achievement-gated unlocking (see _check_achievements) stays
## wired up underneath but is a no-op while everyone starts unlocked.
var unlocked_heroes: Array = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]
## Relic ids available for the run-boon pool (scaffolding for a later
## milestone — no relics exist yet, so this stays empty).
var unlocked_relics: Array = []

## Lifetime career counters (minions_killed, gates_destroyed,
## best_villain_damage_pct, runs_played), accumulated across every run, win
## or lose. Drives Achievements hero unlocks — see record_career/record_career_max.
var career := {}

## Persistent XP currency, shared across the whole roster like gold.
## Every point of XP any hero earns banks here permanently (see add_xp) — it is
## NEVER reset by a new run starting; the only two ways it changes are being
## earned or being spent (buy_stat_upgrade) on any hero's permanent raw stat
## upgrades (StatUpgrades). Separate pool from gold, which spends on abilities.
var banked_xp := 0
## hero_name -> {stat_id: purchases int} — how many times each stat has been
## bought for that hero. Drives both StatUpgrades.cost_for's scaling and the
## stat bonus applied at spawn (Hero._apply_stat_upgrades).
var stat_purchases: Dictionary = {}

## Lifetime per-hero stats, accumulated across every run (prep-menu display —
## "Total kills", "Total XP gained", "Ability effectiveness"). hero_name ->
## {"kills": int, "xp": int, "ability_attempts": int, "ability_hits": int}.
## `xp` here is a separate running total from banked_xp — banked_xp is the
## shared spendable currency (v6, per-hero tracking removed); this is purely
## a lifetime counter for display, never spent. See record_hero_kill,
## record_ability_result, add_xp.
var hero_stats: Dictionary = {}

func _hero_stat(hero_name: String) -> Dictionary:
	if not hero_stats.has(hero_name):
		hero_stats[hero_name] = {"kills": 0, "xp": 0, "ability_attempts": 0, "ability_hits": 0}
	return hero_stats[hero_name]

## Killing-blow credit only (matches award_kill_xp's killer-gets-full-XP rule
## — assists don't count as a kill). Fires per-kill against a swarm, so no
## save here (see record_career's same reasoning); persisted by the next
## save_game() (run end, or any other persistent-state change).
func record_hero_kill(hero_name: String) -> void:
	_hero_stat(hero_name)["kills"] += 1
	run_kills[hero_name] = int(run_kills.get(hero_name, 0)) + 1

## Tracks one special-ability cast attempt and whether it actually landed on
## an enemy (Hero._try_* already computes this locally — e.g. Ensnare's `hit`,
## Rally's `buffed` — this just records it). Only call for casts that got past
## the "nothing to aim at" guard; a cast that never fires at all isn't a miss,
## it's a no-op. No save — same high-frequency reasoning as record_hero_kill.
func record_ability_result(hero_name: String, success: bool) -> void:
	var stat := _hero_stat(hero_name)
	stat["ability_attempts"] += 1
	run_ability_attempts[hero_name] = int(run_ability_attempts.get(hero_name, 0)) + 1
	if success:
		stat["ability_hits"] += 1
		run_ability_hits[hero_name] = int(run_ability_hits.get(hero_name, 0)) + 1

## -- Hero stat readouts (prep card = lifetime, battle card = current run) ----

func hero_kills_lifetime(hero_name: String) -> int:
	return int(hero_stats.get(hero_name, {}).get("kills", 0))

func hero_kills_run(hero_name: String) -> int:
	return int(run_kills.get(hero_name, 0))

func hero_xp_lifetime(hero_name: String) -> int:
	return int(hero_stats.get(hero_name, {}).get("xp", 0))

func hero_xp_run(hero_name: String) -> int:
	return int(run_xp.get(hero_name, 0))

## -1.0 when no ability has been cast yet (nothing to divide) — callers should
## show "—" rather than a misleading 0%.
func hero_ability_pct_lifetime(hero_name: String) -> float:
	var stat: Dictionary = hero_stats.get(hero_name, {})
	var attempts := int(stat.get("ability_attempts", 0))
	if attempts <= 0:
		return -1.0
	return 100.0 * int(stat.get("ability_hits", 0)) / attempts

func hero_ability_pct_run(hero_name: String) -> float:
	var attempts := int(run_ability_attempts.get(hero_name, 0))
	if attempts <= 0:
		return -1.0
	return 100.0 * int(run_ability_hits.get(hero_name, 0)) / attempts

## -- Duo pairings ---------------------------------------------------------

## Persistent Duo pairing: an Array of exactly 2 Duos, each an Array of exactly
## 2 distinct hero names covering the current 4-hero roster with no overlap.
## Set from the prep screen's Pairings panel (PrepMenu._on_pairing_chip_pressed)
## and read at deploy time to sequence the two Duos onto the field
## (DeployController/BattleManager). Empty/invalid means "not paired yet" —
## callers must check has_valid_duo_pairings before relying on it.
var duo_pairings: Array = []

## How many seconds after the first-deployed Duo lands the second Duo
## arrives. Set (and remembered run-to-run) via the deploy screen's stepper
## (DeployController) so the player can tune arrival timing across attempts —
## "play with the timer to find the best moment" — rather than re-deciding it
## fresh every run. Persisted; not reset by start_run() or a new level.
const DUO_B_DELAY_MIN := 0.0
const DUO_B_DELAY_MAX := 30.0
const DUO_B_DELAY_DEFAULT := 10.0
var duo_b_delay_seconds: float = DUO_B_DELAY_DEFAULT

## Clamps and persists a new deploy-stagger value. Saves immediately, same as
## the other prep-screen dials (buy_mod/buy_tier/set_duo_pairings) — this one
## just changes via a stepper instead of a purchase.
func set_duo_b_delay(seconds: float) -> void:
	duo_b_delay_seconds = clampf(seconds, DUO_B_DELAY_MIN, DUO_B_DELAY_MAX)
	save_game()

func _ready() -> void:
	load_game()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F12:
		full_reset()

## -- Run flow ---------------------------------------------------------------

func start_run() -> void:
	run_xp.clear()
	run_kills.clear()
	run_ability_attempts.clear()
	run_ability_hits.clear()

## Kill XP: killer banks the full value; every other living hero banks the
## assist share (rounded up), so XP flows to the whole party (BALANCE.md).
func award_kill_xp(killer: Node, amount: int) -> void:
	add_xp(killer.hero_name, amount)
	var assist := int(ceil(amount * KILL_ASSIST_SHARE))
	for h in killer.get_tree().get_nodes_in_group("heroes"):
		if h != killer and h is Hero:
			add_xp(h.hero_name, assist)

## Single chokepoint for all run XP (kills + objectives): tracks this run's
## per-hero total for the results screen and feeds the in-run level track
## (RunState), which is what actually grows a hero's power now. Every point
## also banks permanently into the shared persistent currency (banked_xp) —
## unlike run_xp/RunState's level track (which reset every run by design,
## since in-run boons are meant to be temporary), banked_xp only ever changes
## by being earned here or spent (buy_stat_upgrade), and isn't tied to which
## hero earned it — the player spends it on any hero from the STATS shop.
func add_xp(hero_name: String, amount: int) -> void:
	if amount <= 0:
		return
	run_xp[hero_name] = int(run_xp.get(hero_name, 0)) + amount
	RunState.record_xp(hero_name, amount)
	banked_xp += amount
	_hero_stat(hero_name)["xp"] += amount

## -- Meta currency / unlocks --------------------------------------------------

func award_gold(amount: int) -> void:
	gold += amount
	save_game()

## Increments gold WITHOUT saving to disk — the per-kill/per-gate drip
## (LaneSpawner) against a 50-minion swarm would thrash file I/O if it saved
## every time like award_gold() does. Flushed by the save_game() inside the
## eventual award_gold() call at BattleManager._end().
func bank_gold(amount: int) -> void:
	gold += amount

## Gold payout for a finished run: scales with levels cleared, +bonus on a win,
## never below GOLD_MIN. `levels_cleared` is how many levels the run beat.
func gold_for_run(win: bool, levels_cleared: int) -> int:
	var payout := GOLD_PER_LEVEL * maxi(levels_cleared, 0) + (GOLD_WIN_BONUS if win else 0)
	return maxi(payout, GOLD_MIN)

# has_mod/buy_mod, has_duo_mod/buy_duo_mod and duo_mod_total were removed
# 2026-07-26 with the flat shop they served. Deleted rather than left dormant:
# a second live purchase path would spend the same gold into owned_mods, where
# the skill tree would never show it and _apply_skill_tree would never apply
# it. The owned_* arrays themselves survive as migration input only — see
# _migrate_purchases_to_tree. Their replacements: buy_skill_rank,
# skill_rank/skill_unlocked, skill_total and duo_ultimate_total.

## -- Skill tree ----------------------------------------------------------------

## Ranks owned of `id`. Ultimate nodes ignore `hero_name` — their ranks are
## per-PAIR and shared by both trees that show them.
func skill_rank(hero_name: String, id: String) -> int:
	if SkillTree.def(id).get("ultimate", false):
		return int(duo_ultimate_ranks.get(id, 0))
	return int(skill_ranks.get(hero_name, {}).get(id, 0))

## True when every prerequisite node of `id` has at least one rank. Ultimate
## nodes have no prerequisites (SkillTree._ultimate_def) — they're gated by
## price, not position.
func skill_unlocked(hero_name: String, id: String) -> bool:
	for req in SkillTree.def(id).get("requires", []):
		if skill_rank(hero_name, req) <= 0:
			return false
	return true

## Buys one rank of `id` for `hero_name` if it's unlocked, not maxed and
## affordable. Returns true on success. Saves immediately — a deliberate,
## infrequent player action, same as the buy_* calls it replaces.
func buy_skill_rank(hero_name: String, id: String) -> bool:
	var d := SkillTree.def(id)
	if d.is_empty() or not skill_unlocked(hero_name, id):
		return false
	var rank := skill_rank(hero_name, id)
	var cost := SkillTree.cost_for(id, rank)
	if cost < 0 or gold < cost:
		return false
	gold -= cost
	if d.get("ultimate", false):
		duo_ultimate_ranks[id] = rank + 1
	else:
		if not skill_ranks.has(hero_name):
			skill_ranks[hero_name] = {}
		skill_ranks[hero_name][id] = rank + 1
	save_game()
	return true

## Total effect of `kind` across every ranked signature node on this hero's
## tree — `value * rank`, summed. A node can carry a SECOND effect via
## kind_b/value_b (the capstones), counted here too. Read once at spawn by
## Hero._apply_skill_tree.
func skill_total(hero_name: String, kind: String) -> float:
	var total := 0.0
	for id in skill_ranks.get(hero_name, {}):
		var d := SkillTree.def(id)
		var rank: float = float(skill_ranks[hero_name][id])
		if d.get("kind", "") == kind:
			total += float(d.get("value", 0.0)) * rank
		if d.get("kind_b", "") == kind:
			total += float(d.get("value_b", 0.0)) * rank
	return total

## Permanent Ultimate upgrade total for a pair — the skill-tree replacement for
## duo_mod_total, read by Hero._ultimate_param on top of the base params and
## this run's boons. `value * rank`, so a maxed 4-rank node is 4x the old
## buy-once mod.
func duo_ultimate_total(pair_id: String, kind: String) -> float:
	var rank := int(duo_ultimate_ranks.get(pair_id, 0))
	if rank <= 0:
		return 0.0
	var d := SkillTree.def(pair_id)
	if d.get("kind", "") != kind:
		return 0.0
	return float(d.get("value", 0.0)) * float(rank)

## One-time conversion of a pre-skill-tree save's purchases into equivalent
## ranks (Designer, 2026-07-26: nobody loses power or gold). Runs on load and
## is idempotent — it only ever RAISES a rank to the level the old purchase
## bought, so re-running it can't stack.
##
## The legacy lists are deliberately left intact rather than cleared: they cost
## nothing to keep, and they're the only record of what a player owned if this
## mapping ever needs revisiting.
const LEGACY_MOD_TO_NODE := {
	# Old flat mod -> the node ranks reproducing its effect. Stomp radius +45
	# was one purchase; the tree sells it as 3 ranks of +15.
	"seismic_stomp": {"node": "thundaar_reach_1", "rank": 3},
	"rolling_quake": {"node": "thundaar_recover_1", "rank": 3},
	"twin_clone": {"node": "artemis_count_1", "rank": 1},
	"fleetfoot": {"node": "artemis_recover_1", "rank": 3},
	"wide_snare": {"node": "warden_reach_1", "rank": 3},
	"rapid_snare": {"node": "warden_recover_1", "rank": 3},
	"mass_rally": {"node": "beacon_reach_1", "rank": 3},
	"quick_rally": {"node": "beacon_recover_1", "rank": 3},
}
const LEGACY_TIER_TO_NODE := {
	"THUNDAAR_2": "thundaar_passive",
	"ARTEMIS_2": "artemis_passive",
	"WARDEN_2": "warden_passive",
	"BEACON_2": "beacon_passive",
}

func _migrate_purchases_to_tree() -> void:
	for mod_id in owned_mods:
		var m: Dictionary = LEGACY_MOD_TO_NODE.get(mod_id, {})
		if m.is_empty():
			continue
		var hero: String = SkillTree.def(m["node"]).get("hero", "")
		_raise_rank(hero, m["node"], int(m["rank"]))
	for tier_id in owned_ability_tiers:
		var node: String = LEGACY_TIER_TO_NODE.get(tier_id, "")
		if node != "":
			_raise_rank(SkillTree.def(node).get("hero", ""), node, 1)
	# A bought-once Duo mod becomes rank 1 of its 4-rank Ultimate node.
	for pair_id in owned_duo_ultimate_mods:
		if int(duo_ultimate_ranks.get(pair_id, 0)) < 1:
			duo_ultimate_ranks[pair_id] = 1

func _raise_rank(hero_name: String, id: String, rank: int) -> void:
	if hero_name == "":
		return
	if not skill_ranks.has(hero_name):
		skill_ranks[hero_name] = {}
	skill_ranks[hero_name][id] = maxi(int(skill_ranks[hero_name].get(id, 0)), rank)

func is_hero_unlocked(hero_name: String) -> bool:
	return hero_name in unlocked_heroes

func unlock_hero(hero_name: String) -> void:
	if hero_name not in unlocked_heroes:
		unlocked_heroes.append(hero_name)
		save_game()

func is_relic_unlocked(id: String) -> bool:
	return id in unlocked_relics

func unlock_relic(id: String) -> void:
	if id not in unlocked_relics:
		unlocked_relics.append(id)
		save_game()

## -- Career stats / achievements ----------------------------------------------

## Increments without saving to disk — this fires per-kill/per-gate against a
## 50-minion swarm, so a save here would thrash file I/O the same way a per-kill
## award_gold() would (see bank_gold). Persisted by the eventual save_game()
## at run end, or immediately the moment an achievement unlocks a hero.
func record_career(stat: String, amount: int) -> void:
	career[stat] = int(career.get(stat, 0)) + amount
	_check_achievements()

## Like record_career, but keeps the running maximum instead of summing (e.g.
## best_villain_damage_pct across every level/run attempted).
func record_career_max(stat: String, value: float) -> void:
	if value > float(career.get(stat, 0.0)):
		career[stat] = value
		_check_achievements()

func _check_achievements() -> void:
	for id in Achievements.ids():
		var d := Achievements.def(id)
		var hero_name: String = d.get("unlocks_hero", "")
		if hero_name == "" or is_hero_unlocked(hero_name):
			continue
		if float(career.get(d.get("stat", ""), 0)) >= float(d.get("threshold", 0)):
			unlock_hero(hero_name)  # saves immediately — the achievement is safe on crash

## -- Ability tiers -------------------------------------------------------------

## Tier 1 (the signature ability — Stomp/Clone/Ensnare/Rally) is free the
## moment a hero is unlocked; tier 2 is now the tree's PASSIVE node rather than an
## AbilityTiers purchase (2026-07-26). Kept as a function because Hero and the
## tier-2 effect sites all ask this question — only what answers it moved.
func has_tier(hero_name: String, tier: int) -> bool:
	if tier <= 1:
		return true
	if tier > 2:
		return false
	return skill_rank(hero_name, "%s_passive" % hero_name.to_lower()) > 0

# buy_tier was removed 2026-07-26 for the same reason as buy_mod above: the
# passive is now a tree node, bought through buy_skill_rank.

## -- Raw stat upgrades ---------------------------------------------------------

func stat_purchase_count(hero_name: String, stat_id: String) -> int:
	return int(stat_purchases.get(hero_name, {}).get(stat_id, 0))

## Buys one more level of a raw stat upgrade for a hero (cost rises with prior
## purchases — see StatUpgrades.cost_for). Returns true on success. Saves
## immediately, same as buy_mod/buy_tier.
func buy_stat_upgrade(hero_name: String, stat_id: String) -> bool:
	var count := stat_purchase_count(hero_name, stat_id)
	var cost := StatUpgrades.cost_for(hero_name, stat_id, count)
	if cost <= 0 or banked_xp < cost:
		return false
	banked_xp -= cost
	if not stat_purchases.has(hero_name):
		stat_purchases[hero_name] = {}
	stat_purchases[hero_name][stat_id] = count + 1
	save_game()
	return true

## -- Duo pairings -------------------------------------------------------------

## The paired partner of `hero_name`, or "" if unpaired/pairings invalid.
func duo_of(hero_name: String) -> String:
	for duo in duo_pairings:
		if not (duo is Array):
			continue
		if hero_name in duo:
			for h in duo:
				if h != hero_name:
					return h
	return ""

## Whether `hero_name` leads its Duo — a pure player choice (Designer,
## 2026-07-20: "tank always leads does not work anymore ... this should be a
## player decision"), NOT derived from role. Leader is whichever hero was
## dropped in that Duo's first (left/A) pairing slot — see
## PrepMenu._sync_party_from_slots, which builds each pair as [slot_0, slot_1]
## in drop order. False for an unpaired hero (matches Hero._duo_leader's
## "no partner = irrelevant" default).
func is_duo_leader(hero_name: String) -> bool:
	for duo in duo_pairings:
		if duo is Array and (duo as Array).size() == 2 and duo[0] == hero_name:
			return true
	return false

## True when duo_pairings is exactly 2 Duos of 2 distinct heroes each,
## together covering `roster` (order-independent) with no repeats.
func has_valid_duo_pairings(roster: Array) -> bool:
	if duo_pairings.size() != 2:
		return false
	var seen: Array = []
	for duo in duo_pairings:
		if not (duo is Array) or (duo as Array).size() != 2:
			return false
		for h in duo:
			if h in seen:
				return false
			seen.append(h)
	var sorted_seen: Array = seen.duplicate()
	sorted_seen.sort()
	var sorted_roster: Array = roster.duplicate()
	sorted_roster.sort()
	return sorted_seen == sorted_roster

## Sets the Duo pairing (see has_valid_duo_pairings for the expected shape)
## and saves immediately — a deliberate, infrequent player action, same as
## buy_mod/buy_tier. Pass [] to clear.
func set_duo_pairings(pairs: Array) -> void:
	duo_pairings = pairs
	save_game()

## -- Persistence -------------------------------------------------------------

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"version": SAVE_VERSION,
			"gold": gold,
			"owned_mods": owned_mods,
			"unlocked_heroes": unlocked_heroes,
			"unlocked_relics": unlocked_relics,
			"career": career,
			"owned_ability_tiers": owned_ability_tiers,
			"owned_duo_ultimate_mods": owned_duo_ultimate_mods,
			"banked_xp": banked_xp,
			"stat_purchases": stat_purchases,
			"duo_pairings": duo_pairings,
			"duo_b_delay_seconds": duo_b_delay_seconds,
			"hero_stats": hero_stats,
			"skill_ranks": skill_ranks,
			"duo_ultimate_ranks": duo_ultimate_ranks,
		}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data: Variant = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary):
		return
	if int(data.get("version", 1)) < MIN_LOADABLE_VERSION:
		# Pre-v3 save (the old persistent stat grind): a clean break, not a
		# migration — Designer-approved wipe (see DECISIONS.md). Leave every
		# var at its fresh-start default.
		return
	gold = int(data.get("gold", 0))
	owned_mods = data.get("owned_mods", [])
	var saved_heroes: Variant = data.get("unlocked_heroes", null)
	if saved_heroes is Array and not (saved_heroes as Array).is_empty():
		unlocked_heroes = saved_heroes
	unlocked_relics = data.get("unlocked_relics", [])
	career = data.get("career", {})
	owned_ability_tiers = data.get("owned_ability_tiers", [])
	owned_duo_ultimate_mods = data.get("owned_duo_ultimate_mods", [])
	banked_xp = int(data.get("banked_xp", 0))
	stat_purchases = data.get("stat_purchases", {})
	duo_pairings = data.get("duo_pairings", [])
	duo_b_delay_seconds = float(data.get("duo_b_delay_seconds", DUO_B_DELAY_DEFAULT))
	hero_stats = data.get("hero_stats", {})
	skill_ranks = data.get("skill_ranks", {})
	duo_ultimate_ranks = data.get("duo_ultimate_ranks", {})
	# A v8 save has no tree at all; a v9 save has one and this is a no-op
	# (_raise_rank only ever raises). Runs unconditionally so the mapping also
	# repairs a save written between a partial migration and now.
	_migrate_purchases_to_tree()

## Resets the in-memory persistent vars to fresh-start defaults WITHOUT deleting
## the save file.
func _reset_state_defaults() -> void:
	run_xp = {}
	run_kills = {}
	run_ability_attempts = {}
	run_ability_hits = {}
	gold = 0
	owned_mods = []
	owned_ability_tiers = []
	owned_duo_ultimate_mods = []
	skill_ranks = {}
	duo_ultimate_ranks = {}
	banked_xp = 0
	stat_purchases = {}
	duo_pairings = []
	duo_b_delay_seconds = DUO_B_DELAY_DEFAULT
	unlocked_heroes = ["THUNDAAR", "ARTEMIS", "WARDEN", "BEACON"]
	unlocked_relics = []
	career = {}
	hero_stats = {}

func reset_save() -> void:
	_reset_state_defaults()
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

## Full dev reset: wipes the save (this GameState autoload), the in-run chain
## state (RunState — current_level/hp_carry/dead/levels/boons/draft), and the
## persisted per-level fog-of-war ("progress is knowledge" — a stale fog PNG
## would make a "fresh" Level 1 open pre-explored), then returns to the prep
## menu so the player always lands somewhere clean regardless of where they
## pressed F12 (mid-battle, results screen, etc). reset_save() alone used to
## be wired to F12 but only wiped this autoload — RunState and fog survived,
## so a "reset" from mid-run silently kept the old level/HP/fog state.
func full_reset() -> void:
	reset_save()
	RunState.start_run()
	RunState.party.clear()
	RunState.draft_offer.clear()
	_clear_fog_dir()
	get_tree().paused = false
	get_tree().change_scene_to_file(PREP_MENU)

func _clear_fog_dir() -> void:
	var abs_path := ProjectSettings.globalize_path(FOG_DIR)
	var dir := DirAccess.open(abs_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir():
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

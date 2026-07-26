class_name SkillTree
extends RefCounted
## Per-hero SKILL TREE catalog — the gold shop's data model as of 2026-07-26
## (Designer: "have the ability shop be a skill tree, for each hero... distribute
## current ability upgrades to smaller and incremental nodes, that slowly the
## player will buy and augment heroes").
##
## Replaces three flat catalogs that the ABILITIES page used to list as columns
## of one-shot cards:
##     AbilityMods       8 buy-once upgrades  -> multi-rank nodes here
##     AbilityTiers      4 buy-once passives  -> the 1-rank PASSIVE node here
##     DuoUltimateMods   6 buy-once duo mods  -> the 4-rank ULTIMATE nodes here
## Those three files still exist, but ONLY as the mapping table
## GameState._migrate_purchases_to_tree reads to convert an existing save's
## purchases into equivalent ranks. Nothing at runtime prices or applies them
## anymore. DuoUltimateMods is the one exception that stays live data: its
## kind/value/name per Duo IS the Ultimate node's payload (see _ultimate_nodes),
## so the Ultimate effects have exactly one source of truth.
##
## Ranks, not purchases. Every node has `ranks` (how many times it can be
## bought) and a per-rank `value` — the effect is `value * rank`, flat additive
## like everything else in the game (Designer, 2026-07-21: no percentages).
## Splitting the old one-shot mods into 3 cheap ranks is the whole point: the
## first Stomp-radius buy costs 15g and lands after a single level instead of
## 45g and three.
##
## Costs rise per rank: `cost` for rank 1, +`cost_step` for each rank after
## (rank N costs cost + cost_step * (N-1)). First-pass numbers — flag for
## tuning in BALANCE.md.
##
## LAYOUT. `pos` is a GRID cell (column, row), not pixels — SkillTreePage
## multiplies it by its own spacing, so re-shaping a tree is an edit here and
## nowhere else. `requires` lists node ids that must have at least one rank
## before this node can be bought; the page draws a connector line along every
## requires edge. Keep a tree's roots (no requires) on row 0.
##
## ART. `icon` is a placeholder hook (Designer, 2026-07-26: "leave placeholders
## for each node, so I can provide art later"). Empty string = the page draws
## the node's `glyph` letter inside the hand-drawn hex instead. Dropping a PNG
## in assets/sprites/skills/ and setting this path is the only step needed
## later — no UI change.
##
## EFFECT KINDS map onto scalars Hero already reads, so no new mechanics were
## invented for this pass:
##     stomp_radius    -> Hero.stomp_radius_add
##     ensnare_radius  -> Hero.ensnare_radius_add
##     rally_radius    -> Hero.rally_radius_add
##     clone_count     -> Hero.clone_count
##     ability_cooldown-> Hero._ability_cooldown_reduction
##     passive         -> Hero._passive_unlocked (the old tier-2 unlock)
## Ultimate nodes use the DuoUltimates params keys instead (step_stun,
## trail_lifetime, ...) and are summed at cast time by Hero._ultimate_param.

## Ultimate nodes are shared between the two heroes of a pair — the node id IS
## the DuoUltimates pair id, and ranks live in GameState.duo_ultimate_ranks
## keyed by that id. Buying "Concussive Wave" from THUNDAAR's tree is the same
## purchase as buying it from BEACON's (Designer, 2026-07-26): a Duo Ultimate
## belongs to the pair, so it must not be buyable twice.
const ULTIMATE_RANKS := 4
const ULTIMATE_COST_STEP := 45

## Which signature ability each hero's tree upgrades — used only for node
## naming/description text, so the tree reads in the hero's own language.
const ABILITY_NAME := {
	"THUNDAAR": "Stomp",
	"ARTEMIS": "Clone",
	"WARDEN": "Ensnare",
	"BEACON": "Rally",
}

## The tier-2 passive each hero's PASSIVE node unlocks. Text mirrors the old
## AbilityTiers entries — the effects in hero.gd are unchanged, only what
## gates them moved.
const PASSIVE_NODES := {
	"THUNDAAR": {"name": "Aftershock", "desc": "Stomp also stuns enemies briefly"},
	"ARTEMIS": {"name": "Mirror Image", "desc": "Clone deals +50% damage"},
	"WARDEN": {"name": "Binding", "desc": "Ensnare vulnerability +3 and radius +25"},
	"BEACON": {"name": "Empower", "desc": "Rally also heals each ally +8 HP"},
}

## Signature-ability nodes, per hero. Three heroes share the same shape (a
## radius chain, a cooldown chain, the passive, a capstone that feeds both);
## ARTEMIS has no radius to grow, so her chain buys clone COUNT instead — the
## one place the trees differ structurally, because clone_count is the only
## geometry her ability has.
const CATALOG := {
	# THUNDAAR (TANK — Stomp) ------------------------------------------------
	"thundaar_reach_1": {
		"hero": "THUNDAAR", "name": "Tremor Reach", "glyph": "R",
		"desc": "Stomp radius +15", "kind": "stomp_radius", "value": 15.0,
		"ranks": 3, "cost": 15, "cost_step": 8, "pos": Vector2(0, 0), "requires": [],
		"icon": "",
	},
	"thundaar_reach_2": {
		"hero": "THUNDAAR", "name": "Fault Line", "glyph": "R",
		"desc": "Stomp radius +20", "kind": "stomp_radius", "value": 20.0,
		"ranks": 3, "cost": 30, "cost_step": 12, "pos": Vector2(0, 2),
		"requires": ["thundaar_reach_1"], "icon": "",
	},
	"thundaar_recover_1": {
		"hero": "THUNDAAR", "name": "Rolling Quake", "glyph": "C",
		"desc": "Stomp cooldown -0.4s", "kind": "ability_cooldown", "value": 0.4,
		"ranks": 3, "cost": 18, "cost_step": 9, "pos": Vector2(2, 0), "requires": [],
		"icon": "",
	},
	"thundaar_recover_2": {
		"hero": "THUNDAAR", "name": "Second Wind", "glyph": "C",
		"desc": "Stomp cooldown -0.5s", "kind": "ability_cooldown", "value": 0.5,
		"ranks": 2, "cost": 40, "cost_step": 15, "pos": Vector2(2, 2),
		"requires": ["thundaar_recover_1"], "icon": "",
	},
	"thundaar_passive": {
		"hero": "THUNDAAR", "name": "Aftershock", "glyph": "!",
		"desc": "Stomp also stuns enemies briefly", "kind": "passive", "value": 1.0,
		"ranks": 1, "cost": 40, "cost_step": 0, "pos": Vector2(1, 1),
		"requires": ["thundaar_reach_1", "thundaar_recover_1"], "icon": "",
	},
	"thundaar_capstone": {
		"hero": "THUNDAAR", "name": "Earthshaker", "glyph": "*",
		"desc": "Stomp radius +15 and cooldown -0.3s", "kind": "stomp_radius",
		"value": 15.0, "kind_b": "ability_cooldown", "value_b": 0.3,
		"ranks": 2, "cost": 55, "cost_step": 20, "pos": Vector2(1, 3),
		"requires": ["thundaar_passive"], "icon": "",
	},
	# ARTEMIS (BURST — Clone) ------------------------------------------------
	# No radius to grow: the clone chain buys COUNT, which is why her ranks are
	# fewer and pricier than the other three trees' geometry chains.
	"artemis_count_1": {
		"hero": "ARTEMIS", "name": "Twin Clone", "glyph": "2",
		"desc": "Clone count +1", "kind": "clone_count", "value": 1.0,
		"ranks": 2, "cost": 45, "cost_step": 30, "pos": Vector2(0, 0), "requires": [],
		"icon": "",
	},
	"artemis_count_2": {
		"hero": "ARTEMIS", "name": "Hall of Mirrors", "glyph": "3",
		"desc": "Clone count +1", "kind": "clone_count", "value": 1.0,
		"ranks": 2, "cost": 80, "cost_step": 40, "pos": Vector2(0, 2),
		"requires": ["artemis_count_1"], "icon": "",
	},
	"artemis_recover_1": {
		"hero": "ARTEMIS", "name": "Fleetfoot", "glyph": "C",
		"desc": "Clone cooldown -0.4s", "kind": "ability_cooldown", "value": 0.4,
		"ranks": 3, "cost": 18, "cost_step": 9, "pos": Vector2(2, 0), "requires": [],
		"icon": "",
	},
	"artemis_recover_2": {
		"hero": "ARTEMIS", "name": "Afterimage", "glyph": "C",
		"desc": "Clone cooldown -0.5s", "kind": "ability_cooldown", "value": 0.5,
		"ranks": 2, "cost": 40, "cost_step": 15, "pos": Vector2(2, 2),
		"requires": ["artemis_recover_1"], "icon": "",
	},
	"artemis_passive": {
		"hero": "ARTEMIS", "name": "Mirror Image", "glyph": "!",
		"desc": "Clone deals +50% damage", "kind": "passive", "value": 1.0,
		"ranks": 1, "cost": 40, "cost_step": 0, "pos": Vector2(1, 1),
		"requires": ["artemis_count_1", "artemis_recover_1"], "icon": "",
	},
	"artemis_capstone": {
		"hero": "ARTEMIS", "name": "Perfect Double", "glyph": "*",
		"desc": "Clone count +1 and cooldown -0.3s", "kind": "clone_count",
		"value": 1.0, "kind_b": "ability_cooldown", "value_b": 0.3,
		"ranks": 1, "cost": 110, "cost_step": 0, "pos": Vector2(1, 3),
		"requires": ["artemis_passive"], "icon": "",
	},
	# WARDEN (CONTROL — Ensnare) ---------------------------------------------
	"warden_reach_1": {
		"hero": "WARDEN", "name": "Wide Snare", "glyph": "R",
		"desc": "Ensnare radius +17", "kind": "ensnare_radius", "value": 17.0,
		"ranks": 3, "cost": 16, "cost_step": 8, "pos": Vector2(0, 0), "requires": [],
		"icon": "",
	},
	"warden_reach_2": {
		"hero": "WARDEN", "name": "Creeping Vines", "glyph": "R",
		"desc": "Ensnare radius +22", "kind": "ensnare_radius", "value": 22.0,
		"ranks": 3, "cost": 32, "cost_step": 12, "pos": Vector2(0, 2),
		"requires": ["warden_reach_1"], "icon": "",
	},
	"warden_recover_1": {
		"hero": "WARDEN", "name": "Rapid Snare", "glyph": "C",
		"desc": "Ensnare cooldown -0.4s", "kind": "ability_cooldown", "value": 0.4,
		"ranks": 3, "cost": 18, "cost_step": 9, "pos": Vector2(2, 0), "requires": [],
		"icon": "",
	},
	"warden_recover_2": {
		"hero": "WARDEN", "name": "Quick Roots", "glyph": "C",
		"desc": "Ensnare cooldown -0.5s", "kind": "ability_cooldown", "value": 0.5,
		"ranks": 2, "cost": 40, "cost_step": 15, "pos": Vector2(2, 2),
		"requires": ["warden_recover_1"], "icon": "",
	},
	"warden_passive": {
		"hero": "WARDEN", "name": "Binding", "glyph": "!",
		"desc": "Ensnare vulnerability +3 and radius +25", "kind": "passive", "value": 1.0,
		"ranks": 1, "cost": 40, "cost_step": 0, "pos": Vector2(1, 1),
		"requires": ["warden_reach_1", "warden_recover_1"], "icon": "",
	},
	"warden_capstone": {
		"hero": "WARDEN", "name": "Strangleroot", "glyph": "*",
		"desc": "Ensnare radius +17 and cooldown -0.3s", "kind": "ensnare_radius",
		"value": 17.0, "kind_b": "ability_cooldown", "value_b": 0.3,
		"ranks": 2, "cost": 55, "cost_step": 20, "pos": Vector2(1, 3),
		"requires": ["warden_passive"], "icon": "",
	},
	# BEACON (SUPPORT — Rally) -----------------------------------------------
	"beacon_reach_1": {
		"hero": "BEACON", "name": "Mass Rally", "glyph": "R",
		"desc": "Rally radius +30", "kind": "rally_radius", "value": 30.0,
		"ranks": 3, "cost": 18, "cost_step": 9, "pos": Vector2(0, 0), "requires": [],
		"icon": "",
	},
	"beacon_reach_2": {
		"hero": "BEACON", "name": "Banner Call", "glyph": "R",
		"desc": "Rally radius +35", "kind": "rally_radius", "value": 35.0,
		"ranks": 3, "cost": 34, "cost_step": 12, "pos": Vector2(0, 2),
		"requires": ["beacon_reach_1"], "icon": "",
	},
	"beacon_recover_1": {
		"hero": "BEACON", "name": "Quick Rally", "glyph": "C",
		"desc": "Rally cooldown -0.4s", "kind": "ability_cooldown", "value": 0.4,
		"ranks": 3, "cost": 18, "cost_step": 9, "pos": Vector2(2, 0), "requires": [],
		"icon": "",
	},
	"beacon_recover_2": {
		"hero": "BEACON", "name": "Ever Onward", "glyph": "C",
		"desc": "Rally cooldown -0.5s", "kind": "ability_cooldown", "value": 0.5,
		"ranks": 2, "cost": 40, "cost_step": 15, "pos": Vector2(2, 2),
		"requires": ["beacon_recover_1"], "icon": "",
	},
	"beacon_passive": {
		"hero": "BEACON", "name": "Empower", "glyph": "!",
		"desc": "Rally also heals each ally +8 HP", "kind": "passive", "value": 1.0,
		"ranks": 1, "cost": 40, "cost_step": 0, "pos": Vector2(1, 1),
		"requires": ["beacon_reach_1", "beacon_recover_1"], "icon": "",
	},
	"beacon_capstone": {
		"hero": "BEACON", "name": "Lightbearer", "glyph": "*",
		"desc": "Rally radius +30 and cooldown -0.3s", "kind": "rally_radius",
		"value": 30.0, "kind_b": "ability_cooldown", "value_b": 0.3,
		"ranks": 2, "cost": 55, "cost_step": 20, "pos": Vector2(1, 3),
		"requires": ["beacon_passive"], "icon": "",
	},
}

## Signature node ids for a hero, in catalog order.
static func for_hero(hero_name: String) -> Array:
	return CATALOG.keys().filter(func(id: String) -> bool:
		return CATALOG[id].get("hero", "") == hero_name)

## Definition for any node id — signature OR Ultimate. Ultimate defs are built
## on demand from DuoUltimateMods so their kind/value has one source of truth;
## they carry `ultimate = true`, which is what the page uses to draw them
## bigger and GameState uses to route ranks to the shared per-pair store.
static func def(id: String) -> Dictionary:
	if CATALOG.has(id):
		return CATALOG[id]
	var d := DuoUltimateMods.def(id)
	if d.is_empty():
		return {}
	return _ultimate_def(id, d)

static func _ultimate_def(pair_id: String, d: Dictionary) -> Dictionary:
	return {
		"ultimate": true,
		"duo": pair_id,
		"name": d.get("name", pair_id),
		"glyph": "U",
		"desc": d.get("desc", ""),
		"kind": d.get("kind", ""),
		"value": float(d.get("value", 0.0)),
		"ranks": ULTIMATE_RANKS,
		"cost": int(d.get("cost", 75)),
		"cost_step": ULTIMATE_COST_STEP,
		"requires": [],
		"icon": "",
	}

## The three Ultimate node ids on `hero_name`'s tree — one per Duo this hero
## can form (every OTHER hero in the catalog). Shared with the partner's tree,
## see the ULTIMATE_RANKS doc.
static func ultimates_for_hero(hero_name: String) -> Array:
	var out: Array = []
	for other in GameState.HERO_CATALOG:
		if other == hero_name:
			continue
		var pair_id := DuoUltimates.id_for_heroes(hero_name, other)
		if not DuoUltimateMods.def(pair_id).is_empty():
			out.append(pair_id)
	return out

## Grid row the Ultimate band sits on — below every signature node, so the
## expensive end of the tree is always the bottom of the panel.
const ULTIMATE_ROW := 5

## Grid cell for an Ultimate node on `hero_name`'s tree: the three spread
## across the same three columns the signature nodes use.
static func ultimate_pos(hero_name: String, pair_id: String) -> Vector2:
	var i: int = ultimates_for_hero(hero_name).find(pair_id)
	return Vector2(maxi(i, 0), ULTIMATE_ROW)

## Gold price of the NEXT rank of `id` given `rank` already owned, or -1 when
## the node is already maxed.
static func cost_for(id: String, rank: int) -> int:
	var d := def(id)
	if d.is_empty() or rank >= int(d.get("ranks", 1)):
		return -1
	return int(d.get("cost", 0)) + int(d.get("cost_step", 0)) * rank

## The partner hero of an Ultimate node, for display ("with BEACON").
static func ultimate_partner(hero_name: String, pair_id: String) -> String:
	for h in pair_id.split("|"):
		if h != hero_name:
			return h
	return ""

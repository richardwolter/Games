extends Node
## Tutorial autoload — owns the scripted first-time-player flow and the phase
## the player is currently in (Designer, 2026-07-31).
##
## The tutorial is one continuous sequence that crosses three scenes:
##
##   BATTLE       level 0 (config/level_0_layout.tres + stage_0_config.tres):
##                Thundaar + Artemis alone against one spawn gate. A scripted
##                LOSS — see TUTORIAL_GATE_HP_FLOOR in LaneSpawner.
##   PREP         the prep menu, revealed one section at a time (PrepMenu's
##                tour) now that Warden and Beacon have joined.
##   FIRST_BATTLE the real level 1, where the two-lane split is explained once.
##
## `phase` is transient (a session field, never saved). The single PERSISTENT
## bit is GameState.tutorial_done, which is what stops the tutorial running
## again on the next launch. Everything else here is derived from it.
##
## Roster note: a fresh save unlocks only THUNDAAR + ARTEMIS (see
## GameState.unlocked_heroes). Warden and Beacon are unlocked for real at the
## "let's summon some friends" beat — the reveal is a real progression event,
## not a UI trick, so a player who quits mid-tutorial and comes back cannot
## find a roster the fiction hasn't given them yet.

enum Phase {
	NONE,          ## Not in the tutorial (normal play, or already completed).
	BATTLE,        ## Level 0 is running.
	PREP,          ## The post-loss prep-menu tour.
	FIRST_BATTLE,  ## Level 1, owing the player the two-lane explanation.
}

## The tutorial's own level index. LaneField resolves layouts by
## RunState.current_level ("level_%d_layout.tres"), so level 0 needs no special
## loading path — only its two config files, which ship beside every other level's.
const LEVEL := 0

## The one Duo the tutorial fields, in leader-first order (Thundaar leads, so
## Artemis reads as the ranged support trailing him — see Hero._duo_follow_anchor).
const STARTING_DUO := ["THUNDAAR", "ARTEMIS"]
## Unlocked at the post-loss beat.
const FRIENDS := ["WARDEN", "BEACON"]

var phase: Phase = Phase.NONE

## One last explanation owed to the player, on the FIRST boon pick they ever see
## (which happens in the first real battle, after deploy — the tutorial level
## offers no boons at all). Kept as its own flag rather than a Phase because it
## outlives FIRST_BATTLE: the two-lane hint fires at deploy and clears the
## phase, while this one is still waiting for the pick that comes after it.
var boon_hint_pending := false

## True while the tutorial battle is the thing on screen — read by BattleManager
## (no villain, no boons, no results screen) and LaneField (single lane).
func in_battle() -> bool:
	return phase == Phase.BATTLE

## Whether a brand-new player still owes us the tutorial. GameState is the
## authority; this is just the readable form of it.
func pending() -> bool:
	return not GameState.tutorial_done

## Starts the tutorial and drops straight into level 0 — no prep menu first
## (Designer, 2026-07-31). Called from the title screen's NEW GAME and from
## GameState.full_reset(), the two routes that produce a fresh save.
##
## Seeds the run by hand rather than going through the prep screen: the party is
## the starting Duo, paired as ONE Duo. DeployController and DuoControlBar both
## handle a single pairing already (the second simply comes out empty), so
## nothing downstream needs a tutorial branch for the missing Duo B.
func begin() -> void:
	phase = Phase.BATTLE
	RunState.start_run()
	RunState.current_level = LEVEL
	RunState.draft_offer = STARTING_DUO.duplicate()
	RunState.party = STARTING_DUO.duplicate()
	# Not set_duo_pairings(): that saves, and this pairing is scaffolding for
	# level 0 only — the player pairs all four heroes themselves during the prep
	# tour, and complete() clears this one out before they get there.
	GameState.duo_pairings = [STARTING_DUO.duplicate()]
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.BATTLEFIELD)

## The "let's summon some friends" beat: Warden and Beacon join for real.
func unlock_friends() -> void:
	for hero_name in FRIENDS:
		GameState.unlock_hero(hero_name)

## Level 0 is over (the scripted loss). Hands off to the prep tour.
##
## start_run() here is what undoes the loss: the tutorial's casualties, XP and
## carried HP are wiped, so Thundaar and Artemis walk into level 1 alive and at
## full HP. Without it RunState.dead would still hold both of them and the real
## run would open with nobody to field.
func to_prep() -> void:
	phase = Phase.PREP
	RunState.start_run()
	RunState.current_level = 1
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.PREP_MENU)

## The player pressed START RUN at the end of the prep tour: the tutorial is
## done and level 1 is a normal battle, save for the one two-lane explanation
## FIRST_BATTLE still owes them.
func complete() -> void:
	phase = Phase.FIRST_BATTLE
	boon_hint_pending = true
	GameState.tutorial_done = true
	GameState.save_game()

## True once, at the start of the first real battle — the two-lane explanation.
func consume_two_lane_hint() -> bool:
	if phase != Phase.FIRST_BATTLE:
		return false
	phase = Phase.NONE
	return true

## True once, immediately before the player's first boon pick is put on screen.
func consume_boon_hint() -> bool:
	if not boon_hint_pending:
		return false
	boon_hint_pending = false
	return true

## Abandons the tutorial from any of its phases (the SKIP button on every
## popup, behind a confirm). Puts the player exactly where finishing would have:
## whole roster unlocked, tutorial marked done, fresh run, prep menu. Pairings
## are cleared rather than kept — a skipper never saw the pairing step, so the
## prep screen must ask them for it rather than launching with the tutorial's
## one-Duo scaffolding.
func skip() -> void:
	phase = Phase.NONE
	unlock_friends()
	GameState.tutorial_done = true
	GameState.duo_pairings = []
	GameState.save_game()
	RunState.start_run()
	RunState.current_level = 1
	get_tree().paused = false
	get_tree().change_scene_to_file(GameState.PREP_MENU)

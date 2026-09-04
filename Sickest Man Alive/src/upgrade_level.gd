@tool
class_name UpgradeLevel
extends Resource

## One level of one item's upgrade track.
##
## An upgrade is nothing but MORE MODIFIERS. Buying level 2 on the Rusty Needle
## does not run any new code: the modifiers below are appended to a copy of the
## item at the start of the run, and Loadout resolves them exactly as it resolves
## the item's own. That is why an upgrade can "add an ability" and not just a
## number -- a modifier can APPEND to `statuses`, `impact_effects` or
## `shader_flags`, which is how the base items already grant poison and freeze.
##
## Authored in the Upgrade Forge dock (Project > Tools, or the right-hand dock),
## which is where the enums and stat names come from dropdowns instead of being
## typed. Nothing here should ever need hand-editing.

## The line the player reads in the prep menu, e.g. "The needle pierces one more
## body." Written by the designer; the dock offers a plain-English default built
## from the modifiers themselves.
@export_multiline var summary: String = ""

@export var modifiers: Array[StatModifier] = []

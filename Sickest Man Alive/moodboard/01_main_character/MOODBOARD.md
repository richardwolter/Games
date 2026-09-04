# 01 — Main character

Sources: `Description.txt` and `Links.txt` (Richard's own notes, copied here
verbatim) plus the images in `ref/`.

The visual language for the game as a whole is still being worked out with the
artist. This brief is the only reference that counts for now.

**Status:** draft — no approved character art exists yet
**Owner:** unassigned
**Last updated:** 2026-08-10

## What they are

A teenager, around **16 years old**, in an "old tech" suit that reads as a mix
of **space exploration and medical equipment**. Liquid capsules ride on the back
and feed the syringe gun through tubes. They also carry an **oversized scalpel
as a sword**.

**Gender is the artist's call.** Male or female — decide it, draw it, no need to
pitch both.

The world around them is gross-out adventure comedy: slimy, toothy, faintly
ridiculous. See `ref/concept/`.

## Style: halfway between cartoon and realistic

Not the chunky big-headed cartoon of the key art, and not rendered realism
either. Land between them: **believable human proportions, stylised and
simplified surfaces.** Anatomy and the suit hardware behave like real objects
with real weight; the drawing of them is bold, clean and exaggerated where it
helps a shape read.

`ref/concept/` is the anchor for character, tone and colour — not for the suit
panelling, which is being redesigned. `ref/suit/` is the anchor for how hardware
sits on a body. The target sits between those two in rendering as well as in
proportion.

**The suit is already worn in.** Not damaged, not degrading during a run —
simply not new. Scuffed edges, chipped paint, stained fabric, worn straps and
scratched glass from the day it is first seen.

## Play the prototype first

A playable build ships alongside this brief — Windows, or a browser version, see
`_builds/HOW_TO_PLAY.txt`. It is **programmer art from top to bottom**,
including the character. The point is how the game moves, not how it looks.

| Control | |
| --- | --- |
| Move | WASD or arrow keys |
| Aim | Mouse, or the right stick |
| Fire | Hold left mouse while aiming — the right stick alone is enough on a gamepad |
| Fullscreen | F7 |
| Grant an item | Space — debug key, use it to stack items fast |

What to watch for: how big the character reads against the enemies and the room;
how much screen the weapons and their effects take up; whether a fight stays
readable with six things on screen; and where the eye goes — the character, or
the thing about to hit them.

## Headgear: partial coverage, ideally modular

The face does not have to be fully bare. **Some coverage is welcome**, and the
best answer is coverage that can come on and off — a breathing mask that hangs
at the chin and pulls up, goggles that sit on the forehead and drop over the
eyes, a hood, a filter, a visor on a hinge.

Design it as **separate modular pieces on their own layers**, so a piece can be
worn or stowed without redrawing the head. That also gives us an obvious place
to hang item upgrades later.

The one rule that survives: **the person stays readable.** Whatever is worn, the
player can still see who is inside it and read an expression. A fully sealed,
anonymous helmet is the failure — not coverage itself.

## Reads at a glance

At gameplay size these are the things that must survive.

1. **A readable face.** The face is the character. Partial coverage is welcome —
   see the headgear note below — but the person has to stay visible in it.
2. **The back capsules and the tubes running to the syringe gun.** This is the
   one piece of silhouette that explains the whole kit.
3. **Old tech, not sci-fi.** Bulky, patched, analogue — gauges, straps, buckles,
   rubber hose. Scuffed before the run starts.

## References

Every reference below is partly right and partly wrong. The **IGNORE** column is
the more important half — a reference with no instructions gets copied whole,
including the parts that are wrong.

### `ref/concept/Sickest Man Alive - Concept Art.png`

**TAKE:** the character concept — goggle cluster pushed up on the forehead with
the headlamp, a readable face beneath it, the glowing capsule and pressure gauge
worn on the back, syringe gun in one hand and the oversized scalpel in the
other. The colour story (teal-grey with orange). The tone the character has to
sit inside.

**IGNORE:**

- **The plated suit itself.** The armour panelling in the key art is not the
  design — it is a first pass. Redesign the suit; keep only the kit it carries.
- The chunky big-headed cartoon proportions. See the style target.
- The enemies and the environment. Those are other briefs.

### `ref/suit/Suit.webp`

**TAKE:** suit logic — layered kit over a soft under-suit, hoses, the
strapped-on back tank, goggle-style optics at the temple, the bulk of the
gloves, and the lived-in feel of gear that is used rather than issued. Also
**the headgear**: the face stays visible with the breathing rig strapped across
the lower half, which is exactly the partial coverage described above.

**IGNORE:**

- Its adult proportions and adult build.
- Its realism and its monochrome ink rendering. This is a hardware and shape
  reference, **never a style one**.

### `Links.txt`

External references on ArtStation. Not embedded — open them from the file.

External links (not embedded — open them from `Links.txt`):

**Character style**

- https://www.artstation.com/artwork/L2vlmR
- https://www.artstation.com/artwork/WBDxEX
- https://www.artstation.com/artwork/5vNx8z

**Suit**

- https://www.artstation.com/artwork/X16v6a
- https://www.artstation.com/artwork/YGlB6P

**Weapons**

- https://www.artstation.com/artwork/YKDeVP
- https://www.artstation.com/artwork/obLxyk
- https://www.artstation.com/artwork/K0W5G

## Do not

- **No fully sealed helmet or anonymous full-face mask** (`ref/avoid/Suit2.jpg`).
  Partial coverage is fine and wanted; coverage that hides the person is the
  difference between our character and a generic trooper, and every reference
  pulls toward the trooper.
- **No sleek modern powered armour** (`ref/avoid/Suit.jpg`). Moulded plates,
  clean panel lines, glowing inserts and gym-built anatomy are all the wrong
  century and the wrong body. Ours is improvised, softer, strapped together.
- **No adult heroic proportions.** They are sixteen — but proportions are
  believable, not cartoon-chibi either. See the style note above.
- **No factory-fresh suit.** It is worn in from the first frame.
- **No weapon painted into the body art.** Weapons are separate assets and the
  loadout changes them — see below.
- **No saturated colour on the character.** Items recolour the player through a
  tint that a saturated sprite would swallow.
- **No clean surfaces.** Scuffs, stains, chipped paint, worn straps.

## Weapons drive the art

The player picks their own loadout, and every combination has to be drawable
from the same body:

- two scalpel swords (melee only)
- scalpel sword + syringe gun (mixed)
- two syringe guns (ranged only)

So: **weapons in hand are interchangeable.** Both hands are generic grips, and
the character is authored holding nothing.

Item upgrades and modifiers change how the weapons look as well as what they do,
so **the weapons must be built modular**, with each of these an independently
swappable piece:

- fluid colour (in the capsules, the tubes, and the syringe)
- scalpel handle
- scalpel tip / blade

Tubes have to run from the back capsules to whichever weapon is held, so plan
the attachment path rather than drawing tubes into a fixed pose.

## Technical requirements

| Requirement | Detail |
| --- | --- |
| Layering | **Every body part on its own layer**, ready to be rigged to an animation skeleton. Delivered layered, not flattened. |
| Background | Transparent, with careful cropping — no stray pixels, no halo, no visual noise around the silhouette. |
| Format | PNG, straight (non-premultiplied) alpha, plus the layered source file. |
| View | Front-facing. Aim direction is carried by the weapon, not the body. |
| Weapons | Separate assets, with the grip point and the tube attachment point marked. |
| Modularity | Weapon pieces (fluid, handle, tip) on separate layers too, and any headgear — mask, goggles, visor — as its own layer in both its worn and its stowed position. |
| Rig contract | The engine puppet is six parts — `torso`, `head`, `arm_l`, `arm_r`, `leg_l`, `leg_r` — plus one weapon attachment per hand. Joints must be visible and unambiguous; limbs must not overlap each other, though limb-over-torso overlap is wanted because it hides the seam when the limb rotates. |

## Deliverables

- [ ] Character design, front-facing, empty hands — gender is the artist's call
- [ ] The design as layered source, one layer per body part, transparent
- [ ] Headgear in both positions — worn and stowed — on its own layer
- [ ] Syringe gun and scalpel sword as separate modular assets (fluid / handle /
      tip on their own layers), grip and tube points marked
- [ ] The character at final gameplay size before any detail work continues

## Settled

- **Gender:** the artist decides. No competing pitches.
- **Style:** between cartoon and realistic — believable proportions, stylised
  and simplified surfaces.
- **Wear:** the suit is worn in from the start. It does not degrade further
  during a run.

# Sickest Man Alive — Art Bible

Defines the visual language. Written 2026-08-09 from the concept art in
`art_ref/`. Expands as production grows.

## Premise, in one line

A kid in a shrinking powered suit fights bacteria, viruses and worse inside his
sick uncle's body. The tone is **gross-out adventure comedy**, not horror and
not cute. Things are slimy, toothy and faintly ridiculous.

## Art direction

Flat 2D cartoon with a **heavy dark ink outline**, cel-shaded fills, and grime
layered on top. The lineage is Earthworm Jim / Ren & Stimpy / Rick and Morty
grotesque, filtered through a modern game-art finish: clean shapes, confident
line weight, exaggerated features, everything dripping.

Five rules that carry the look:

1. **Outline everything.** A near-black outline (`#1a1418`), heaviest on the
   silhouette and lighter on interior detail. Nothing floats without a line.
2. **Slime is the connective tissue.** Drips, strings, wet highlights and
   puddles appear on almost every surface. It is what makes the world read as
   *inside a body* rather than a cave.
3. **Eyes and mouths sell everything.** Enemies are built around huge
   yellow-white eyes with small dark pupils, and mouths crowded with irregular
   teeth. Bodies are secondary.
4. **Bioluminescence is the light source.** Acid green, cyan and magenta glow
   from within the environment. There is no sun down here.
5. **Nothing is clean.** Every man-made object — the suit, the weapons, the
   swallowed debris — is scuffed, rusted, chipped and stained.

## The gap between concept art and game art

The concept art in `art_ref/` is **painterly hero art**: soft gradients, ambient
occlusion, dense texture, dozens of small details per character. A gameplay
sprite is a fraction of that size on screen and will lose all of it.

Generated game sprites must therefore **reduce**:

- Flat colour fills with at most two shading steps (a shadow and a highlight).
  No soft gradients, no rendered ambient occlusion.
- Detail count roughly a third of the concept art. Keep the two or three
  features that identify the character; delete the rest.
- Silhouette does the identifying. A `Virus Swarm` must be recognisable as a
  black shape: horns, humped back, cilia fringe.
- Contrast inside a character stays low so it does not compete with the outline.

Treat the concept art as the answer to *what is this thing*, never as the target
render quality.

## Camera and facing

**The floor is top-down. The characters are not.** Rooms, props and hazards are
drawn as if seen from above; characters are drawn straight-on, facing the viewer,
and the player reads the combination without complaint.

This is exactly what *Binding of Isaac* does, and it is a deliberate choice
rather than a compromise. It keeps the face — the kid's whole identity is his
expression under that goggle cluster, and every genuinely overhead camera hides
it behind the top of a helmet.

Practical consequences:

- One front-facing sprite per character. No left/right mirrored sets, no back
  view, no four-direction sets.
- Aim direction is communicated by the **weapon**, not the body. The player's
  twin-stick aim rotates the held syringe; the kid keeps facing the viewer.
- Movement reads through animation — lean, bob, stride — not through turning.
- Props and room geometry keep their overhead footprint, so collision shapes and
  the floor plan stay honest even though bodies do not.

**Tested and rejected, 2026-08-09:** generating a true 3/4 top-down character.
An OpenPose skeleton cannot express camera elevation — it carries 2D joint
positions only, so a foreshortened skeleton is ambiguous between *short person at
eye level* and *person seen from above*, and the model resolves it as a short
person every time. Five camera presets produced five straight-on front views.
Do not spend another day on this without a depth-conditioned model or a
hand-drawn overhead reference.

## Character proportions

The kid is roughly **four heads tall** — stocky, not chibi. Oversized head with
volume added by hair and the goggle cluster; short thick limbs; heavy boots and
gauntlets that read at small size. Enemies ignore human proportion entirely and
are built from one dominant mass plus appendages.

## On-screen size, and why it is not the hurtbox

Characters are generated at 1024px tall and drawn in game at roughly
**110–128px**. Below about 96px the face stops reading, and the face is the
character — verified 2026-08-09 with `art/_preview/size_check.png`, which shows
the same sprite at 64 / 96 / 128 / 192.

`Player.BASE_RADIUS` is **14**, so the collision circle is 28px across. That is
deliberately much smaller than the sprite and must stay that way: the hurtbox is
tuned for how the game feels to dodge in, and the art has no business changing
it. Sprite scale and hurtbox radius are independent numbers that happen to
describe the same character.

Detail should be authored for ~128px, not for 1024px. Anything that survives
only at full generation resolution is wasted work.

## The face is never covered

The goggle cluster sits **pushed up on his forehead**, and his face is bare
beneath it: eyes, eyebrows, mouth, all readable. This is not a detail — it is the
difference between a kid in a suit and a generic armoured trooper, and image
generation collapses toward the trooper at every opportunity. A sealed visor, a
full-face mask or a closed helmet is always wrong, however good the sprite looks
otherwise.

## Palette

Environments are **desaturated flesh** — the world is muted so that characters
and hazards read against it.

| Role | Colour | Where |
| --- | --- | --- |
| Flesh wall (deep) | `#3e2733` | far walls, vignette |
| Flesh wall (lit) | `#7a4a52` | near walls, muscle, vein casing |
| Membrane purple | `#5a3a5e` | neural tissue, cavity linings |
| Bile olive | `#6e6a35` | floors, sludge, older infection |
| Bone / cartilage | `#c9c2ad` | ribs, structural pale surfaces |
| Ink | `#1a1418` | every outline |

Characters and hazards are **saturated** against that:

| Role | Colour | Where |
| --- | --- | --- |
| Acid green | `#8fc93a` | virus swarm, spores, poison, glow |
| Infection purple | `#8e5aa8` | the larger virus forms |
| Alarm red | `#c4453c` | aggressive variants, danger tells |
| Turd brown | `#6b4f22` | bacteria phalanx, debris mounds |
| Suit teal-grey | `#4a5c60` | the kid's armour |
| Suit orange | `#d98a3a` | the kid's accents, fuel tank, energy |
| Skin warm | `#d9a077` | the kid's face |

`src/body_plan.gd` already carries a per-organ `color` for all 23 body parts.
Those are **map colours**, consumed by the minimap, and they are deliberately
brighter and more literal than this palette. Keep them as they are; do not
repaint room interiors to match them.

## Hard constraints from the code

These are not preferences. Breaking them breaks working systems.

- **Character art must stay desaturated.** `PlayerStats.tint` is a `BLEND`-op
  stat resolved by the item pipeline — items recolour the player. A fully
  saturated sprite makes those tints invisible. The suit's teal-grey is already
  correct; keep it that way.
- **Sprites must survive scaling.** `src/player.gd` sets
  `scale = Vector2.ONE * stats.size_scale`, because size is a stat. Art has to
  read at both ends of that range, which is another argument for low detail.
- **Enemy health has to stay readable without a HUD.** `src/enemy.gd` currently
  shows it with an inner core that shrinks as the enemy dies. Replacing the
  placeholder circle with a sprite deletes that channel, so a sprite-era
  replacement must be designed, not dropped.
- **Damage and status feedback are colour operations** — the iframe flash to
  white, the poison tint toward `#9933cc`. On a multi-part sprite these become a
  shader on the rig root, not a per-part colour swap.

## UI direction

The `Enemy File` concept pages set it: **aged parchment** panels with a printed
field-guide layout, framed by creeping tendrils. Menus, item pickups and the
pause screen read as pages from the kid's own case file on the infection. This
keeps UI diegetic without fighting the wet, dark battlefield for attention.

## Reference folder

`art_ref/` holds two kinds of image, and they are used differently.

**Concept art — style references.** `Sickest Man Alive - Concept Art.png`,
`Character Concept Art and Weapons.png`, `Boss Concept Art.png`, the three
`Enemies Concept Art*` sheets, both `Environments Concept Art*` sheets, and
`BindingofIsaac.jpg` for layout and camera. These are the img2img `ref` inputs
for generation, and the arbiter of whether a generated sprite is on-model.

**Photographs — research only.** `Bacteria.jpg`, `Blood Cells.jpg`,
`Human Skin.jpg`, `Human Vein.jpg`, `Microbes.jpg`, `Microorganisms.jpg`,
`Stomach.jpg`. Mine them for silhouette ideas, structural logic and colour
relationships — the tunnel-of-flesh perspective in `Human Vein.jpg`, the
absurd variety of body plans in `Microorganisms.jpg`.

**Never use a photograph as an img2img `ref`.** Two reasons, both sufficient:
photoreal detail fights the flat cartoon look and reintroduces exactly the
texture the style rejects, and these are third-party stock images whose content
should not be reproduced into shipped assets. Look at them, then draw the
cartoon version.

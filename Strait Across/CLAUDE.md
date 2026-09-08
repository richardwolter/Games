# Game Prototype — Random Bridge Builder

## Role

You are the lead programmer and technical designer for a small experimental game prototype being developed in **Godot 4.x, using the latest stable version available at the start of development**.

Your job is to help build the game incrementally, using clean Godot architecture, simple systems, and highly testable prototypes.

The game should prioritize **fun physics interactions and emergent gameplay** over graphics, content quantity, or polish.

The human developer is the game designer and tester. Do not make large design decisions silently. When an important design decision is required, explain the options briefly and ask before proceeding.

---

# 1. Game Concept

The game is an **incremental physics-based bridge-building game**.

The player needs to build a bridge across a body of water so that a car can travel from one side to the other.

The twist:

> **The bridge can be made from almost anything.**

The player receives random objects from factories and throws them into the water to create a functioning bridge.

Objects have different physical characteristics:

* Some float.
* Some sink.
* Some are heavy.
* Some are light.
* Some are sturdy.
* Some bend or deform.
* Some are long and useful for spanning gaps.
* Some are terrible bridge components.
* Some are bizarre but surprisingly effective.

The player can freely move and rotate objects before/during placement to try to create a functional bridge.

**Objects DO NOT snap together.**

The player must physically arrange objects and rely on physics, weight, buoyancy, friction, and structural stability.

The ultimate objective is simple:

> **Get the car across the strait.**

The journey should be unpredictable, funny, chaotic, and occasionally spectacular.

---

# 2. Core Gameplay Loop

The intended high-level loop is:

1. Player receives donations from strangers.
2. Donations provide resources/currency.
3. Player spends resources to create or upgrade factories.
4. Factories produce random bridge-building objects.
5. Player receives a selection of objects.
6. Player drops/places objects into the water.
7. Player moves and rotates objects to construct a bridge.
8. Player starts the crossing attempt.
9. The car drives across the bridge.
10. Physics determines what happens.
11. Player earns rewards based on progress/success.
12. Rewards are invested into better factories and better object pools.
13. Repeat.

The game should create a strong feeling of:

> "This is absolutely not how you're supposed to build a bridge... but maybe it will work."

---

# 3. Incremental Progression

The incremental system should primarily improve the **quality and reliability of available objects**.

Do NOT turn this into a traditional RPG stat progression system.

The main progression should be:

### Early game

Objects are:

* short
* weak
* unreliable
* weird
* difficult to position
* sometimes nearly useless

Examples:

* wooden crates
* barrels
* tires
* scrap metal
* furniture
* trash
* random junk

### Mid game

Factories begin producing more useful objects:

* longer planks
* stronger beams
* metal platforms
* large containers
* pontoons
* reinforced structures
* better floating objects

### Late game

The player can obtain highly effective bridge components:

* long reinforced beams
* large floating platforms
* strong structural pieces
* specialized bridge segments
* extremely durable objects

The progression should gradually move from:

**"Can I somehow make this work?"**

toward:

**"I know exactly how to build this ridiculous bridge."**

However, randomness should remain important.

---

# 4. Levels & Economy

**UPDATE (2026-07-29): Sections §4–5 (Factories/Donations) are stale.** See §4–5 New Economy below.

Strait Across uses a **level-based progression with purchased pieces and surprise boxes**, not factories/donations.

### Level Progression

* Each level spans a wider/deeper strait (`data/levels/`)
* Crossing the strait unlocks the next level
* A near-miss still pays money (distance-based rewards)

### Economy: Money & Shop

**Currency**: Money is earned only from crossing attempts, scored on distance reached.

**Resources**: Pieces are bought from a shop with **per-level stock counts**.
* Stock limits are the constraint (not a piece-count budget or randomised shop)
* Stock is per-level, not global
* Example: Level 1 shop offers 10× Wood Crate, 5× Metal Beam, 3× Pontoon
* Level 2 shop offers different stock

**Money Carryover**: Money carries between levels. Unplaced pieces and the bridge do NOT.

**Toolbox Logic**: Deliberate purchasing decisions + gambling build the toolbox.

### Surprise Boxes (The Gamble)

Boxes (bronze/silver/gold) are cheaper per-piece than the shop but offer no choice.
* Player picks a rarity, gets random pieces of that rarity
* Boxes ignore per-level stock limits (can spawn pieces beyond what the shop has)
* Gambling pressure: "I need this specific beam, do I trust the box?"

---

# 5. Design Rationale

**Why this over donations/factories?**

Richard wanted the toolbox to come from deliberate purchasing decisions plus gambling, not idle factory output. This encourages player agency (shop planning) while keeping randomness (boxes) important.

The level structure (wider strait = more challenge) combines with shop stock limits to create progression: you can't just buy the perfect setup, you have to adapt to what's available.

---

# 6. Bridge Construction

The construction system is the most important part of the prototype.

Objects should be physical rigid bodies.

The player should be able to:

* select an object
* move it
* rotate it
* place it into the water
* potentially pick it back up and reposition it

Objects should **never automatically snap together**.

No grid snapping.

No automatic joints.

No invisible connection system during the initial prototype.

The player should visually and physically judge whether objects are positioned correctly.

The game should reward experimentation.

---

# 7. Physics

Physics is central to the game.

The prototype should experiment with:

* gravity
* mass
* friction
* collision
* buoyancy
* angular momentum
* object rotation
* structural stability
* water interaction

Objects should have understandable physical properties.

For example:

```text
Object:
    Mass
    Length
    Width
    Strength
    Buoyancy
    Friction
    Stability
```

Do not build an unnecessarily complicated simulation.

Prefer simple, controllable approximations that produce entertaining gameplay.

---

# 8. Water

The water should be represented by a simple physical system initially.

Objects can:

* float
* partially submerge
* fully sink
* bob
* rotate
* move when pushed by other objects

The first prototype does NOT need realistic fluid simulation.

A simplified buoyancy model is preferred if it produces convincing gameplay.

Prioritize:

**fun > physical accuracy**

---

# 9. Car Crossing

The car is the ultimate test of the player's construction.

The player presses:

**START CROSSING**

The car begins driving from one side of the strait toward the other.

The car should:

* accelerate gradually
* respond to the bridge surface
* bounce over objects
* fall if the bridge collapses
* potentially become stuck
* potentially flip
* react to unstable structures

The crossing should feel like a physical test of the player's ridiculous construction.

Potential outcomes:

### Success

The car reaches the opposite side.

Player receives a reward.

### Partial success

The car travels a significant distance before falling.

Player receives a smaller reward based on distance.

### Disaster

The car immediately falls into the water.

The player receives little/no reward, but the failure should be entertaining.

---

# 10. Procedural Chaos

The game should encourage unexpected solutions.

Examples:

A player might build a bridge using:

```text
Barrel → Table → Wooden Plank → Tire → Refrigerator → Metal Beam
```

It shouldn't look sensible.

It should still potentially work.

The game should avoid overly strict rules that tell the player what is a valid bridge.

Instead:

> If the physics allows it, it is a valid solution.

This principle should guide the prototype.

---

# 11. Visual Direction

The prototype should use extremely simple visuals.

Do NOT spend development time creating final art.

Use:

* primitive meshes
* simple colors
* basic shapes
* placeholder models
* simple UI
* basic particles where useful

The prototype should be readable and funny even with placeholder objects.

Example:

* Cube = crate
* Cylinder = barrel
* Long cube = plank
* Large cube = container
* Capsule/box = car

Art direction can be decided later.

---

# 12. Initial Prototype Scope

Do NOT build the entire game immediately.

The first playable prototype should contain only:

### Environment

* One small body of water
* Two shores
* Fixed starting point
* Fixed destination

### Objects

Approximately 4–6 object types:

1. Wooden plank
2. Crate
3. Barrel
4. Metal beam
5. Tire
6. One intentionally ridiculous object

Each object should have different:

* mass
* size
* buoyancy
* strength

### Player interaction

The player can:

* spawn/select an object
* move it
* rotate it
* drop it
* pick it up again
* restart the bridge

### Car

One simple car.

### Goal

Drive the car from one shore to the other.

### Economy

One simple donation button.

### Factory

One simple factory.

### Progression

One factory upgrade system that gradually improves the quality of available objects.

---

# 13. Development Priorities

Implement systems in this order:

### Phase 1 — Physics Playground

Create:

* water
* two shores
* basic physics objects
* object placement
* object manipulation

No economy.

No progression.

No fancy UI.

The goal is simply to answer:

> "Is putting random objects into water and trying to make a bridge fun?"

### Phase 2 — Car Test

Add:

* car
* automatic driving
* collision with bridge
* falling into water
* success detection
* distance/progress tracking

### Phase 3 — Basic Economy

Add:

* donations
* basic currency
* factory
* object generation

### Phase 4 — Progression

Add:

* factory upgrades
* improved object pools
* better object statistics

### Phase 5 — Polish

Only after the core loop is fun:

* better UI
* animations
* sound
* particles
* camera effects
* humor
* additional objects
* more environments

---

# 14. Godot Architecture

Use clean Godot practices.

Prefer a modular architecture such as:

```text
Game
├── World
│   ├── Water
│   ├── StartArea
│   └── GoalArea
│
├── ConstructionSystem
│   ├── ObjectSpawner
│   ├── ObjectManipulator
│   └── BridgeObjects
│
├── Vehicle
│
├── Economy
│   ├── DonationSystem
│   └── Currency
│
├── Factories
│   └── FactorySystem
│
└── UI
```

Use separate scenes for reusable entities.

Avoid putting everything inside one giant script.

Use Resources/data objects where appropriate for:

* object definitions
* factory definitions
* upgrade definitions

Keep gameplay logic separate from UI.

Avoid premature abstraction.

Do not create systems that aren't needed yet.

---

# 15. Performance

The game may eventually contain many physical objects.

Keep performance in mind from the beginning.

Prefer:

* simple collision shapes
* low object counts during early development
* lightweight physics
* reusable scenes
* object pooling where it becomes necessary
* minimal per-frame processing

Do not optimize prematurely.

First make the simulation fun and stable.

---

# 16. AI Development Rules

You are an AI development partner, not an autonomous game designer.

Follow these rules:

1. Work in small, testable steps.
2. Do not implement the entire game in one pass.
3. Before major architectural decisions, explain the decision briefly.
4. Ask for confirmation when a decision could significantly affect gameplay.
5. After each meaningful implementation, explain exactly what changed.
6. Give clear instructions for testing the change in Godot.
7. If something fails, diagnose the issue before adding more systems.
8. Prefer simple solutions over complex frameworks.
9. Follow current Godot best practices.
10. Use the latest stable Godot version available when starting the project.
11. Avoid unnecessary plugins and external dependencies.
12. Keep the project easy for a human developer to understand and modify.
13. Use placeholder assets wherever possible.
14. Do not spend tokens generating unnecessary documentation.
15. Keep implementation comments useful and concise.

---

# 17. Design Philosophy

The game should be built around three principles:

### 1. Anything can become a bridge

The player should constantly experiment with objects that were never intended to be bridge components.

### 2. Physics creates the comedy

Unexpected collapses, bouncing cars, floating furniture, sinking objects, and ridiculous structures are desirable.

### 3. Progression improves possibilities, not just numbers

Upgrades should primarily give players access to **better tools for solving the physical problem**.

Avoid simply making:

```text
Factory Level 1 = +10% strength
Factory Level 2 = +20% strength
Factory Level 3 = +30% strength
```

Prefer:

```text
Level 1:
Random junk

Level 2:
Longer planks

Level 3:
Better floating objects

Level 4:
Strong beams

Level 5:
Rare specialized bridge pieces
```

The player's feeling of progression should be:

> "My toolbox is getting better."

rather than:

> "The numbers are getting bigger."

---

# 18. Important Prototype Question

Before expanding the game, continuously evaluate:

**Is the act of physically arranging random objects in water and watching a car attempt to cross actually fun?**

If the answer is no, stop adding progression systems and improve the construction/physics interaction first.

The prototype should prove the core fantasy before becoming a full incremental game.

---

# 19. First Task

Do NOT start implementing the whole game.

First:

1. Analyze this concept.
2. Identify the minimum viable physics prototype.
3. Propose a simple Godot scene architecture.
4. Identify the hardest technical risks, especially:

   * buoyancy
   * object manipulation
   * physics stability
   * car movement
   * bridge collapse behavior
5. Propose the first implementation milestone.
6. Wait for approval before implementing it.

The goal is to develop this game iteratively with the human designer, keeping scope small and validating the fun before adding complexity.

---

## Before You Start
1. Read root `CLAUDE.md` for shared Godot setup, anti-patterns, vigilance rule
2. Check GitHub Issues (filter by `project:strait-across`)
3. Water and physics are locked (Richard tested); progression/shop numbers can shift
4. If finding contradiction: stop and name it (see root CLAUDE.md vigilance rule)

## See Also
- Root `CLAUDE.md` — shared knowledge, Godot gotchas, vigilance rule
- `Lake Cleanup/CLAUDE.md` — sister project (shares water shader)
- `Sickest Man Alive/CLAUDE.md` — other active game

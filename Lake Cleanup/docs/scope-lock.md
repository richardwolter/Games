# Lake Cleanup — Scope Lock

Locked 2026-09-18 with issue #23 (`/grill-me` with Richard). **Nothing new is added after this.**
What is left is tuning numbers, polish already owed, and bugs. A new idea goes in a note for
the next game, not in this one.

## The game

One lake, cleaned once. **A run that only cleans is about 50 minutes and a first run about
65**; decorating, petting and looking round take a normal run past that (issue #23 first said
2-3 hours, then 70-80 focused; both superseded by the two logged runs). Cleaning the lake
triggers the ending and the credits; free play and decorating the shed carry on after it.
**The prices are frozen as played in the second logged run.**

## In

**The loop**: cast the net from the island, the catch goes to the crate, ferries carry the
crate to four material yards, the yards pay, the money buys upgrades, the water clears in
five shades as the rubbish goes, nature comes back where it is clean.

**The shop — 17 tracks on four boards, all kept:**

| Board | Track | Levels | What it does |
|---|---|---|---|
| Net | Width | 20 | mouth 0.6 to 4.8 tiles |
| Net | Strength | 4 | weight tier 0 to 4. **The game changer: about 10 / 20 / 30 / 40 min** |
| Net | Range | 20 | throw 4 to 36 tiles. Runs ahead of the clearing, finished by about 40 min |
| Net | Reel | 20 | 3 to 23 tiles/s |
| Net | Catch | 8 | 4 to 12 a cast. Few, dear levels: it is what paces the run |
| Boats | Sailing | 20 | 8 to 40 tiles/s |
| Boats | Hold | 8 | 8 to 32: **at least two casts at every level**, and cheaper than Catch |
| Boats | Fleet | 3 | 4 hulls at most, the first extra one 200 |
| Boats | Loading | 4 | volley gap x1.0 to x0.4 |
| Dogs | Pack | 3 | 4 dogs at most |
| Dogs | Fetch | 4 | 1 to 5 a trip |
| Dogs | Keenness | 3 | rests up to 6 s less |
| Dogs | Carry | 4 | tier and mouth width together |
| Luck | Lucky cast | 10 | to 40%: +1 tier and +4 in the bag, that cast. Early and steady, Strength's teaser |
| Luck | Double cast | 10 | to 35%: a second net beside the first |
| Luck | Bonus yard | 8 | one yard pays up to +200%, hops every 30 s |
| Luck | Pigeons | 8 | a netted bird pays up to x3.4 |

**The rule for the chain**: the boats stay slightly ahead of the net and the dogs for the
whole run. The HUD's *Waiting* figure sits under about two ferry loads, and a spike after a
big cast drains within a minute.

**Everything else that ships**: the finds (37) and the shed with free placement; the dogs'
bank runs and petting; the pigeons and the head that pops in; fish, flora and glints coming
back; the day without a night; the front (boot, curtain, menu over the live lake); the
ending with its credits roll; settings, the bind board and the gamepad; the music station
and the recorded sound.

## Out

| Cut | State |
|---|---|
| The upgrade tree (tree mode, `TreeScreen`, its save slot, its pricing scripts) | **deleted** 2026-09-18 |
| The skimmer | **deleted** 2026-09-18 |
| Sell-by-tier tracks (`sell_0`..`sell_4`) and the market board | **deleted** 2026-09-18 |
| The siege (level 2: charms, wards, sludge, laid nets, `siege.tscn`) | set aside, **still in the repo** — nothing routes to it. Its own cleanup before release |
| Idle machines and drones draining `pollution` | never part of the game (a stale line in CLAUDE.md, struck 2026-09-18); the ferries and the dogs are the idle layer |
| A second lake, prestige, offline earnings | not in this game |
| Hold-to-buy, tabbed or two-up shop layouts | decided against (The Shop Reads) |
| Web build | desktop only |

## The one exception to the lock

- **A find-cleaning machine**: a one-time machine that cleans a find before it goes in the
  shed, paid for out of the 43-56k a run ends with. Not an upgrade and not part of the
  balance (Richard, 2026-09-18). Its own issue. To settle there: whether it can be used
  mid-run, where it would compete with the upgrades for money.

## Still owed (not new scope)

- Turn the playtest log off before a release export (`Lake._logs_play`).
- `chime.wav`, the lake-cleaned note (the one sound still built in code).
- `BOARD_INK_DIM` on the shed's shelf and `MenuConfirm`'s pale doors (contrast).
- Localization (issue #28).
- Deleting the siege.

## Times

| | Sim (focused bot) | Sim (casual bot) | Real |
|---|---|---|---|
| 2026-09-14 pass | 69 min | — | about 70 min (tree run) |
| 2026-09-18 pass | 64 min | 110 min | **64.5 min** (logged run 1, `docs/progression/playtests/`) |
| 2026-09-18 tweaks (Strength 3500, Hold to 32, Range, Pigeons, dogs) | 60 min | — | **50.5 min** (logged run 2, cleaning only) |
| Recalibrated to both runs, prices frozen | 54 min | 95 min | replays: 65.5 for run 1, 52.9 for run 2 |

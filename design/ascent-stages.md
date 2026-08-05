# The Ascent — stages within the climb

Status: agreed 2026-08-05. Not built yet.

## Decision

The climb divides into five named stages. A stage covers a range of fathoms. Each stage owns its
own spawn rate, fog behaviour, scroll rate and faction. The run pacing moves from seconds to
fathoms.

This document is the source of truth for that work. Where the code and this document disagree,
this document is correct.

## Why

The `legdaybot` harness measured the current run on 2026-08-05. Three numbers set the problem.

| Measure | Value | Runs |
|---|---|---|
| Runs the game ended on its own | 0 of 30 | cold start, 900s cap |
| Sim time when the drafted deck ran dry | 131s median | 20 of 20 |
| Distinct card faces in a 150s run | 7 of 21 reachable | 20 runs |

A 150s run deals 10 cards and 13% of them come from Death's deck. A 900s run deals 65 cards and
84% of them come from Death's deck. The pool does not widen as a run lengthens. It narrows onto
the same three ink-spine cards.

The climb also has no shape. A run at 900 fathoms plays the same as a run at 90,000 fathoms.
Nothing marks progress except one number in the HUD.

## The stage model

A stage is data, not a type hierarchy. `AscentStage` carries an id, a name, the fathom at which
it starts, a spine, a faction, and four multipliers. `Ascent.stage(atFathoms:)` resolves the
current stage. The table is ordered and the last stage has no end.

The multipliers compose with the card modifiers already in `Mods`. A stage never replaces a card
effect. It scales the base rate before the card modifier applies.

## The table

Fathoms accrue at about 7.8 per second at the base scroll rate. The seconds column is the
approximate arrival time for a player who takes no scroll modifier.

| Stage | From | ≈ Time | Spine | Faction | Spawn | Fog creep | Scroll |
|---|---|---|---|---|---|---|---|
| THE LOW ROAD | 0 | 0s | rust | wild | 1.00 | 1.00 | 1.00 |
| THE ORCHARD | 280 | 36s | plague | plague | 1.15 | 1.05 | 1.00 |
| THE OSSUARY | 620 | 79s | grave | grave | 1.30 | 1.10 | 1.05 |
| THE SPIRE | 960 | 123s | gold | church | 1.50 | 1.20 | 1.10 |
| THE RECKONING | 1200 | 154s | inkspine | none | 1.70 | 1.30 | 1.15 |

THE RECKONING starts at 1200 fathoms, which is about 154s. The Finale fires at 150s today, so the
new boundary holds the current pacing. The balance does not move as a side effect of this change.

## Pacing moves to fathoms

Three timers become distances. Each one keeps its approximate current pacing.

| Rule | Today | After |
|---|---|---|
| Fork cadence | every 60s | every 450 fathoms |
| The Finale | at 150s | on entry to THE RECKONING |
| Death takes the deck | at 0.6 × finaleTime | on entry to THE SPIRE |

The Death gate becomes a stage rather than a fraction of a timer. A fraction is not legible to a
player. A named stage is. The player learns that Death deals in THE SPIRE.

`Tunables.finaleTime` stays in the file. The keep-running scroll ramp still measures from it.

## Each stage seeds its own card

On entry to a stage, the sim shuffles that stage's threat card into the remaining deck. THE
ORCHARD adds the plague threat. THE OSSUARY adds the grave threat. THE SPIRE adds the church
threat.

This is the variety fix. It raises the distinct faces in a 150s run without any new card content,
and it gives each stage an identity the player can name.

The existing hostility forecast stays. A stage card is an addition to the forecast, not a
replacement for it.

## The user interface

The HUD carries the stage name under the fathom count, in the muted scale at 12pt.

A stage boundary emits a `FrameEvent.stageEntered` case. The render layer shows the stage name
across the screen for about 2 seconds, then fades it. The world does not pause. A card interrupt
already owns the pause, and two pauses in one beat read as a stall.

The deck pips in the HUD mark the Death gate at THE SPIRE, which they already do for the old
time gate.

The obituary names the stage the run ended in. "THE FOG HAS YOU" gains a second line: "in THE
OSSUARY, at 812 fathoms".

## The harness

`legdaybot` gains three columns: the stage the run ended in, the fathom at each stage entry, and
the distinct faces per stage. The `--cap` flag stays.

The harness answers one question after this work lands: does a 150s run now show more than 7
distinct faces. The target is 11 or more.

## Build order

Each unit ends with a green test run. Build them in this order.

1. Add `AscentStage`, the table, and `Ascent.stage(atFathoms:)`. Add tests for the boundaries.
2. Apply the spawn, fog and scroll multipliers. Keep the graybox curve test green.
3. Move the fork cadence to fathoms. Update `ForkTests`.
4. Move the Finale and the Death gate to stages. Update `FinaleTests` and `CardTests`.
5. Seed the stage threat card on entry. Add a test for the deck contents.
6. Add the HUD stage name and the boundary event.
7. Add the stage columns to `legdaybot`. Run 30 cold-start runs and record the numbers here.

## Out of scope

This work does not add a route map between runs. It does not add a world map across runs. Both
were considered on 2026-08-05 and neither was chosen.

This work does not widen Death's deck. The 84% measure comes from a long run, and the stage gate
lands first. The harness re-measures after unit 7 and the decision follows that number.

This work adds no new player card content. The nine new player cards agreed earlier remain
outstanding.

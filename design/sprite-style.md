# Sprite style block

Use this block verbatim for every subject. Change only the subject sentence.
The eight colours match `design/foundations/palette.html`.

```
A single game sprite for "Legday", a gothic mobile game about a pilgrim
who climbs away from a rising fog and bargains with Death for passage.

Camera: three-quarter top-down, about 60 degrees. The camera looks down
at the figure. The figure faces the viewer, the feet sit on the floor,
and the top of the head and the shoulders read from slightly above.
This is not a side profile and not a straight overhead plan. Every
subject uses this one camera.

Art direction: hand-inked woodcut. Heavy black contour, sparse interior
detail, visible cross-hatching for shadow. It reads as a medieval
devotional woodcut, not as clean vector art and not as 3D. Weathered,
dry, restrained.

Palette — use only these:
  parchment #E9DCBC   ink #241C12       dried blood #7A2E1E
  gold #C99A2E        rust #C06430      grave violet #8A6FB3
  plague green #8FA03A                  pitch #050303

Format: ONE figure, alone, centred, filling the frame. No grid, no
second copy, no border, no frame number, no text, no ground line.

Fully transparent background, no ground shadow, no scene. Hard alpha
edges — no glow, no soft drop shadow, no gradient fade.
```

## Subjects, and the silhouette each must match

The design spec holds the figures to identical silhouettes. These are the sizes
the render layer draws today.

| Subject | Source | Size (pt) | Placeholder colour |
|---|---|---|---|
| Pilgrim | `PlaceholderAtlas.hero` | 18 × 26 | parchment |
| Pilgrim in fog | `PlaceholderAtlas.heroSubmerged` | 18 × 26 | grave violet |
| Foe | `PlaceholderAtlas.foe` | Ø 18 | drawn: `sprites/foe-base.png` |
| Elite foe | `PlaceholderAtlas.elite` | Ø 30 | drawn: `sprites/foe-elite.png` |
| Mote | `PlaceholderAtlas.mote` | Ø 10 | grave violet |
| Spark | `PlaceholderAtlas.spark` | Ø 6 | parchment |
| Card corner | `PlaceholderAtlas.cardCharge` | 46 × 66 | drawn: `sprites/card-back.png` |
| Reaper | `ReaperNode.body` | 34 × 84 | drawn: `sprites/reaper.png` |
| Herald | no node yet | 40 × 80 | drawn: `sprites/herald.png` |

Two more subjects are drawn that the table never listed, because no node draws
them today. Both are in the prototype.

| Subject | Sprite | Drawn how |
|---|---|---|
| Fog edge | `sprites/fog-tendril.png` | a row of tongues, mirrored and scaled, on the fog line |
| Ground slab | `sprites/ground-slab.png` | 9 scrolling slabs, each with its own turn and alpha |

Every subject now has art. `PlaceholderAtlas` is unchanged: the sprites live in
`design/sprites/` and the render layer still draws shapes.

`PlaceholderAtlas` still uses `#E6D8B8` for the Pilgrim and the spark. The
palette reconciled parchment to `#E9DCBC`. Sprites use `#E9DCBC`.

## The camera moved to overhead

The playfield camera is now a straight overhead plan view at 90 degrees. The
style block above keeps its art direction, its palette and its format rules,
but its camera paragraph is superseded. Prompts: [sprite-prompts.md](sprite-prompts.md).

Overhead is the only camera where the game can rotate one flat sprite to any
heading and be correct. Measured over 24 headings, the share of the silhouette
that a rotation puts in the wrong place is:

| Camera | Rotation error |
|---|---|
| 60 degrees | 67% |
| 75 degrees | 51% |
| 90 degrees | 4% |

The Reaper duel keeps a low camera. It is a separate scene, it stops the scroll,
and the Reaper needs a face at 34 x 84 pt.

Overhead costs the face. Silhouette, cloth and the lantern must carry the
register instead.

## Movement through 360 degrees

The Pilgrim moves in any direction. The camera in the style block cannot show
that direction by rotation. A figure at 60 degrees that faces the viewer tips
its head sideways if you rotate it. Only a true overhead view survives
`zRotation`, and the style block excludes that view.

Direction therefore costs art. Three options:

| Option | Drawings per subject | What it shows |
|---|---|---|
| One sprite, no transform | 1 | no direction |
| One sprite, horizontal flip | 1 | left and right |
| Five drawings, eight headings | 5 | full ring |

Eight headings need five drawings, not eight. The horizontal mirror is free, so
N, NE, E, SE and S cover the ring.

Four subjects move: Pilgrim, Pilgrim in fog, Reaper, Herald. Foes, motes and
sparks are round, so they never need a facing.

`RunScene.swift:190` applies no transform to the Pilgrim today.

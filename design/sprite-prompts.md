# Sprite generation prompts

Revision 2. Revision 1 asked for one 8-cell sheet and failed on six counts:
a 3x3 grid of 9, a front view, an opaque vignette, drop shadows, nine identical
cells, and off-palette colours. A cross-model review named the cause.

**The lore broke the camera.** "Pilgrim", "devotional woodcut" and "the dark
void where the face would be" are stronger visual priors than "90 degrees", and
all three pull the figure upright and frontal. The prompts below carry no lore.

Four rules follow from that failure:

1. Never ask for a grid. Generate one sprite, then edit it seven times.
2. Never ask for alpha. Generate on flat cyan and key it out.
3. Name a camera that exists. "Grand Theft Auto 1" beats "plan view".
4. Four colours, not eight. Models do not bind pixels to a long hex list.

Camera decision and subject list: [sprite-style.md](sprite-style.md).

## A. The canonical sprite

```
ONE isolated 2D game sprite. ONE character only. No sprite sheet, no
grid, no duplicate figures.

CAMERA IS THE PRIMARY REQUIREMENT:
Orthographic top-down camera identical to the camera in early Grand
Theft Auto 1 and Grand Theft Auto 2. The camera is directly above the
character's crown and looks vertically down along the direction of
gravity.

Show only the TOP surfaces of the hood, shoulders, arms, cloak and
boots. The crown of the hood completely hides the face and hood
opening. The chest is foreshortened and nearly invisible. The body
reads as a compact cloak-shaped footprint on the floor, not as an
upright person viewed from the front.

Automatic rejection if any face, hood opening, chest, frontal torso,
vertical body, horizon, or side-hanging lantern is visible. Not
isometric. Not three-quarter. Not frontal.

The figure travels toward the TOP edge of the canvas. The cloak forms a
top-down teardrop silhouette trailing toward the BOTTOM edge. The left
arm projects horizontally toward the LEFT edge and holds a small
lantern away from the body. The lantern is also viewed from its top
surface.

Pose: passing position, boots close together beneath the split lower
hem. Full character visible with clear space around it. Portrait canvas
with a 9:13 aspect ratio. Design it to remain readable when reduced to
54 x 78 pixels.

Style: a coarse hand-inked woodcut texture applied to a top-down
action-game sprite. Heavy near-black outer contour, sparse angular
interior cuts, limited cross-hatching. Dry, weathered ink. No smooth
painting, rendering, gradients, grey shading or 3D lighting.

COLOR ASSIGNMENT, this is not optional:
The hood and the whole cloak are PALE PARCHMENT BEIGE #E9DCBC. The
figure is a pale, bone-coloured shape. THE ROBE IS NOT RED. THE ROBE IS
NOT DARK.
All outlines and all interior cut lines are near-black ink #241C12.
The lantern is gold #C99A2E.
Dried-blood red #7A2E1E appears ONLY as a thin accent band at the hem,
no more than five percent of the figure.
Use no other colors. No greys, no olive, no orange, no brown, no second
gold.

BACKGROUND MATTE:
The entire background is one perfectly uniform, fully saturated chroma
cyan #00FFFF. Cyan is a removable production matte and must not occur
anywhere inside the sprite. No scenery, floor, texture, vignette,
scanlines, atmospheric lighting, ground shadow, cast shadow, halo, glow
or soft edge.
```

## B. The seven edits

Attach the approved canonical sprite. Run this eight times, once per phase.
Frame 3 or frame 7 may reuse the canonical sprite unchanged, since it is already
a passing pose.

```
Edit the supplied sprite; do not redraw or reinterpret it.

Preserve the exact camera, canvas, scale, position, top-down
silhouette, hood, shoulders, lantern, lantern arm, line weight,
cross-hatching, colors and cyan background.

Modify only the free arm, boots and bottom third of the cloak. Make the
requested walk phase visibly distinct and exaggerated enough to read at
54 x 78 pixels. Preserve the top-down camera. Do not reveal the face,
hood opening, chest or frontal torso. Add no shadow or new color.

Requested phase: [PHASE]
```

| # | `[PHASE]` |
|---|---|
| 1 | Left contact: left boot reaches toward the top edge; right boot trails toward the bottom; free arm swings backward; hem pulls diagonally behind the right boot. |
| 2 | Left down: left boot planted; knees slightly spread; cloak silhouette shortens and broadens; free arm reaches its rear extreme. |
| 3 | First passing: boots nearly overlap beneath the hem; right boot is lifting past the left; cloak hem narrows and centers. |
| 4 | First high: right boot advances toward the top; trailing left heel lifted; cloak hem lifts and flares distinctly to the left. |
| 5 | Right contact: right boot reaches toward the top edge; left boot trails toward the bottom; free arm swings forward; hem pulls diagonally behind the left boot. |
| 6 | Right down: right boot planted; knees slightly spread; cloak silhouette shortens and broadens; free arm reaches its forward extreme. |
| 7 | Second passing: boots nearly overlap beneath the hem; left boot is lifting past the right; cloak hem narrows and centers. |
| 8 | Second high: left boot advances toward the top; trailing right heel lifted; cloak hem lifts and flares distinctly to the right. |

## C. How to run the generation

Codex has a built-in `image_gen` tool on GPT Image 2. Its default sandbox is
read-only, so it cannot save the file without `--sandbox workspace-write`.

```
codex exec --skip-git-repo-check --cd "$DIR" \
  --sandbox workspace-write \
  -c 'sandbox_workspace_write.network_access=true' \
  -c 'mcp_servers={}' -c 'model_reasoning_effort=medium' \
  "$(cat brief.md)"
```

The brief must tell Codex to use `image_gen`, to save to a named path, and to
draw nothing itself. Without that last instruction it writes a script or hand
-draws an SVG substitute, which looks like generated art and is not.

## D. Remap, then key

**Remap before the key, never after.** `-remap` discards the alpha channel, so
a keyed image loses its transparency and composites on parchment. Put cyan in
the palette as a fifth entry, remap, then key the exact colour.

```
magick xc:'#E9DCBC' xc:'#241C12' xc:'#7A2E1E' xc:'#C99A2E' xc:'#00FFFF' \
  +append palette5.png
magick raw.png -remap palette5.png -transparent '#00FFFF' sprite.png
```

This also removes the whole class of colour failure. The model returned
`#911F1C` for `#7A2E1E`, `#E0C591` for `#E9DCBC` and `#110C0A` for `#241C12` --
not one exact value. Do not argue with the prompt about colour. Remap.

Confirm the result:

```
magick sprite.png -format %c histogram:info: | sort -rn | head -6
```

Four opaque colours, exact hex, plus transparent. Anything else failed.

## Checks before you accept a frame

1. Look for a face or a hood opening. There must be neither.
2. Look for a lantern that hangs down. It must lie flat, seen from above.
3. Look at the crown. Nothing may protrude from it.
4. Reduce to 54 pixels wide and put it on `#0F0C0A`. The silhouette must read.
5. Confirm four exact colours with the histogram command above.
6. **Rotate it to 8 headings and look at all 8.** This is the check that
   matters, because the game rotates the sprite at runtime. Everything else can
   pass while this fails.

```
for a in 0 45 90 135 180 225 270 315; do
  magick sprite.png -background none -virtual-pixel none -distort SRT "$a" \
    -resize 60x60 -gravity center -background '#0F0C0A' -extent 76x76 \
    -alpha remove -alpha off "r-$a.png"
done
magick r-*.png +append rotation.png
```

Rotate the FULL-RESOLUTION sprite and reduce after, which is what SpriteKit
does. Rotating an already-reduced sprite looks blurry and fails a good asset.

## What three rounds of failure taught

| Round | Failure | Cause |
|---|---|---|
| 1 | 9 front-facing figures, opaque, drop shadows | the lore. "Pilgrim", "devotional woodcut" and "the dark void where the face would be" beat "90 degrees" |
| 2 | Camera correct, robe dark red | four colours listed with no part assignment, so the model chose |
| 3 | Boot toes drawn on top of the hood, reading as ears | "the leading edge of the hem, pointing toward the TOP" was read as "at the top of the figure" |

Round 3 also settled a design question. Removing the feet made the figure read
far better at 54 pixels, and it costs nothing: the walk cycle then animates only
the hem, which the verlet cloth already does procedurally and better, because
cloth responds to real velocity instead of looping.

The accepted figure is `sprites/pilgrim-canonical.png`, 1092 x 997, a broad
rounded cloak shell with a scalloped hem, a clean crown dome, and the lantern
flat on the floor plane to the left.

## Effect sprites

Four effects are drawn: `fx-impact`, `fx-flare`, `fx-toll`, `fx-rot`. Each one
lies flat on the ground plane, so the overhead camera rule still applies. Each
one is radially arranged, so the game rotates and scales it freely and no
facing is needed.

All four came back correct on the first attempt. The base prompt is the same as
prompt A with three changes:

1. Say the shape is radially arranged around its own centre.
2. State the brightness rule. An effect drawn in ink on a near-black playfield
   is invisible. The body is parchment; ink is a thin contour only.
3. Give one accent colour per effect, so the palette is three colours plus cyan.

| Sprite | Accent | Used for |
|---|---|---|
| `fx-impact` | dried blood `#7A2E1E` | every bolt that lands |
| `fx-flare` | gold `#C99A2E` | the Thurible signature |
| `fx-toll` | grave violet `#8A6FB3` | the Passing Bell signature |
| `fx-rot` | plague green `#8FA03A` | the Censer-Rot signature |

Draw a signature burst UNDER the Pilgrim and an impact OVER its target. During a
signature the player is still dodging, so the figure has to stay readable.

## Foes: two drawings, four factions

`Combat.swift:41` gives foes one distinction, `elite: Bool`. So the whole foe
set is two drawings, not eight. Both are drawn in parchment and ink only, and
the four factions come from a runtime tint.

| Sprite | Size (pt) | Tint |
|---|---|---|
| `foe-base` | 18 | `colorBlendFactor` 0.55, faction colour |
| `foe-elite` | 30 | the same |

Three prompt changes carry the tint. State that the drawing carries **more**
cross-hatching than a clean sprite, because the hatching is what gives the tint
its texture. Allow two colours only. Say the shape is radial and has no front,
so runtime rotation stays correct.

`sprites/foe-tint-check.png` shows both sprites at game size, in gold, plague
green, grave violet and rust. The hatching survives all four.

Two rounds were needed, and the same failure appeared in both. The model drew
evenly spaced points around a large disc, which reads as a sunflower. Naming the
failure fixed it:

```
- Draw only SIX to NINE torn points, not twenty. Fewer, longer, thinner.
- Make the points WILDLY uneven. Some reach twice as far as others.
- Keep the central hump SMALL, about one third of the total width.
- Cut deep notches between the points, so the empty background reaches close
  to the hump. The shape must look bitten and rotted, never decorative.
```

One elite run stalled and wrote no file. The retry at
`model_reasoning_effort=low` finished in about 4 minutes.

## The card emblems invert three rules

Nine emblems, one per relic: `sprites/emblems/`. All nine came back correct on
the first attempt. The prompt inverts three things from the sprite prompt, and
each one is load bearing.

| Sprite prompt | Emblem prompt | Why |
|---|---|---|
| top-down camera | flat, straight-on | the card is held, not walked on |
| parchment body, ink contour | ink dominates | a pale object vanishes on a parchment card |
| readable at 54 px | readable at 64 px | the emblem is larger than a playfield sprite |

The frame stays procedural. A generated frame bitmap stretches badly at
different card sizes, so the drawn asset is the emblem alone.

## The last five

| Sprite | Camera | Body | Note |
|---|---|---|---|
| `fog-tendril` | flat, straight-on | pale | touches the bottom edge, so copies tile |
| `ground-slab` | top-down | pale | radial enough to turn at any angle |
| `reaper` | straight-on, standing | pale | the only subject with a face |
| `herald` | straight-on, standing | pale | a hood with nothing in it, holding out a card |
| `card-back` | flat, square on | parchment panel, ink rules | a knot, not a picture |

Two rules carried the whole set, and neither needed a second round:

1. **Name what must touch an edge.** The fog tendril says it touches the bottom
   edge across its full width and no other edge. That is what makes many copies
   read as one bank.
2. **Say which subject has a face.** Every other prompt rejects a face. The
   Reaper prompt says the skull IS visible, and says why: this figure is the
   only one the player meets up close.

## The world assets

Six more, one wave of three and then another, all correct on the first attempt.
Each one replaces a reused sprite that was standing in for it.

| Sprite | Used as | Replaced |
|---|---|---|
| `boulder` | THE LOW ROAD wall | the grave slab |
| `tree-canopy` | THE ORCHARD wall and floor | the briar bed |
| `bone-pile` | THE OSSUARY wall and floor | the ossuary card emblem |
| `ashlar` | THE SPIRE wall and floor | the grave slab |
| `rift` | THE RECKONING floor | the grave slab |
| `gate-arch` | the landmark at every zone boundary | nothing |

Two rules carried them, both about direction:

1. **A wall element must be radial.** The game turns it to follow the cliff, so
   a shape with a front looks wrong on one side of the gorge. Say "NO SINGLE
   DIRECTION" and "do not give it a front".
2. **A landmark must have one.** `gate-arch` is the only asset that says the
   opposite: it runs left to right, touches neither the top nor the bottom edge,
   and is drawn at a 2:1 aspect.

`ashlar` is the asset that changed the most. THE SPIRE is the only zone built
rather than broken, and one cut block laid in courses without rotation says that
faster than any colour does.

## The attack animation is the rig, not frames

The Pilgrim never swings. `autoAttack` emits `.attack(from:to:)` and
`RunScene.swift:260` draws a line that fades over 0.12 s. So the attack reads
through the rig instead, and every part of it is procedural:

| Cue | How |
|---|---|
| Recoil | an offset on a spring, kicked away from the target, springing home |
| Aim snap | 20% of the angle to the target, added to the body, decaying |
| Lantern jolt | an impulse on the free lantern particle |
| Cloak ripple | angular velocity added to the wedges facing the shot |

No attack frames exist and none are needed.

## If the camera still will not come out

Stop adding camera adjectives. Build a crude but unambiguous overhead guide --
a blocked-out silhouette or a simple 3D mannequin render -- and run
image-to-image at low strength over it. Geometry beats prose here. Apply the
woodcut treatment after the geometry is locked.

## The two floors, and why a substitute is not a floor

THE ORCHARD and THE RECKONING drew their floors with a borrowed asset. The
canopy stood in for roots and read as a snowflake. The rift stood in for ash
and read as scattered brackets. Both are now drawn on purpose:
`floor-roots.png` and `floor-ash.png`.

Two rules from earlier runs did the work again.

**Name the failure, not the goal.** The roots brief says "A previous attempt
failed as a snowflake, so this is not optional", then lists the snowflake, the
star, the burst and the even radial arm. The result has uneven arms and no
tidy centre.

**Say what the asset lies on.** Both briefs say "Show only what lies FLAT ON THE
GROUND". A floor and a wall take the same overhead camera, so the camera
sentence alone does not separate them.

One new rule. **A rotated asset must have no centre of symmetry.** The game
rotates each floor mark to a random angle, so the brief asks for a ragged and
off-centre density, and for two or three arms much longer than the rest.

### Codex could not save either file

`codex-run.sh` runs Codex with `sandbox: read-only`, so both images generated
and neither could be written. Codex reported `NO_IMAGE_CAPABILITY` for one run
and a save failure for the other, and both exited 0.

The images survive at `~/.codex/generated_images/<session-id>/`, and the
session id is printed in the run header. Recover from there rather than
re-running. Passing `--sandbox workspace-write` is the fix, and
`codex-run.sh` does not expose it.

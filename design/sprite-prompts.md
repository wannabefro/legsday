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
3. Reduce to 54 x 78 pixels. The silhouette must still read.
4. Sample the robe folds. Grey and olive are failures.
5. Put frame 1 beside frame 5. Hood and shoulders must be identical.

## If the camera still will not come out

Stop adding camera adjectives. Build a crude but unambiguous overhead guide --
a blocked-out silhouette or a simple 3D mannequin render -- and run
image-to-image at low strength over it. Geometry beats prose here. Apply the
woodcut treatment after the geometry is locked.

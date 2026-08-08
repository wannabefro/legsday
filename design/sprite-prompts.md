# Sprite generation prompts

Run prompt A first. It locks the figure. Then run prompt B, which repeats the
same figure eight times. Do not run B first: image models keep a figure
consistent inside one image, but not across separate runs.

Generate large, about 1024 pixels for each cell, then reduce. The Pilgrim ships
at 18 x 26 pt. Hard alpha edges survive that reduction; soft edges do not.

Related: [sprite-style.md](sprite-style.md) holds the camera decision and the
subject list.

## A. The key frame

```
A single game sprite for "Legday", a gothic mobile game about a pilgrim
who climbs away from a rising fog and bargains with Death for passage.

Camera: straight overhead plan view, 90 degrees, looking directly down
at the floor. You see the crown of the hood, the tops of the shoulders,
the cloak spread on the ground, and the feet. No face is visible. This
is NOT a three-quarter view and NOT a side view.

Subject: the Pilgrim. A hooded figure in a heavy travelling cloak,
seen from directly above, mid-stride. One arm reaches out to the
figure's left holding a small lantern. The cloak spreads and trails
behind the shoulders.

Orientation: the figure walks toward the TOP of the image. This is the
only orientation drawn; the game rotates it.

Art direction: hand-inked woodcut. Heavy black contour, sparse interior
detail, visible cross-hatching for shadow. It reads as a medieval
devotional woodcut, not as clean vector art and not as 3D. Weathered,
dry, restrained.

Palette - use only these:
  parchment #E9DCBC   ink #241C12       dried blood #7A2E1E
  gold #C99A2E        rust #C06430      grave violet #8A6FB3
  plague green #8FA03A                  pitch #050303

Format: ONE figure, alone, centred, filling the frame. No grid, no
second copy, no border, no frame number, no text, no ground line.

Fully transparent background, no ground shadow, no scene. Hard alpha
edges - no glow, no soft drop shadow, no gradient fade.
```

## B. The eight-frame walk cycle

Complete on its own. Attach the approved key frame as a reference image if you
ran prompt A. Without that reference the sheet needs more retries, but the eight
cells stay consistent with each other either way, because they are one image.

```
A game sprite sheet for "Legday", a gothic mobile game about a pilgrim
who climbs away from a rising fog and bargains with Death for passage.

Camera: straight overhead plan view, 90 degrees, looking directly down
at the floor. You see the crown of the hood, the tops of the shoulders,
the cloak spread on the ground, and the feet. No face is visible. This
is NOT a three-quarter view and NOT a side view.

Subject: the Pilgrim. A hooded figure in a heavy travelling cloak, seen
from directly above. One arm reaches out to the figure's left holding a
small lantern. The cloak spreads and trails behind the shoulders.

Orientation: in every cell the figure walks toward the TOP of the
image. This is the only orientation drawn; the game rotates it.

Art direction: hand-inked woodcut. Heavy black contour, sparse interior
detail, visible cross-hatching for shadow. It reads as a medieval
devotional woodcut, not as clean vector art and not as 3D. Weathered,
dry, restrained.

Palette - use only these:
  parchment #E9DCBC   ink #241C12       dried blood #7A2E1E
  gold #C99A2E        rust #C06430      grave violet #8A6FB3
  plague green #8FA03A                  pitch #050303

Format: ONE image holding EXACTLY 8 cells in a 4 x 2 grid, read left to
right, top row first. Every cell holds the same figure at the same
scale, centred in its own cell.

The 8 cells are one walk cycle that loops from cell 8 back to cell 1:
  1  left foot forward, contact
  2  weight down, body lowest
  3  legs passing, feet together
  4  body highest, cloak lifted
  5  right foot forward, contact
  6  weight down, body lowest
  7  legs passing, feet together
  8  body highest, cloak lifted

Only the legs, the arms and the cloak hem change between cells. The
hood, the shoulders, the lantern and the ink weight are IDENTICAL in
all 8 cells. No frame numbers, no borders or gutters drawn between
cells, no text, no ground line.

Fully transparent background, no ground shadow, no scene. Hard alpha
edges - no glow, no soft drop shadow, no gradient fade.
```

## Checks before you accept a sheet

1. Count the cells. There must be 8.
2. Put cell 1 and cell 5 side by side. The hood must be the same size.
3. Look for a face. There must not be one.
4. Check the alpha at the hem. A soft edge fails at 18 pt.
5. Confirm every colour is one of the eight.

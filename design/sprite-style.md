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
| Foe | `PlaceholderAtlas.foe` | Ø 18 | `#5E4B3D` |
| Elite foe | `PlaceholderAtlas.elite` | Ø 30 | `#4A3A30` |
| Mote | `PlaceholderAtlas.mote` | Ø 10 | grave violet |
| Spark | `PlaceholderAtlas.spark` | Ø 6 | parchment |
| Card corner | `PlaceholderAtlas.cardCharge` | 46 × 66 | `#CDBB92` |
| Reaper | `ReaperNode.body` | 34 × 84 | `#241C12` |
| Herald | no node yet | to set | per faction |

`PlaceholderAtlas` still uses `#E6D8B8` for the Pilgrim and the spark. The
palette reconciled parchment to `#E9DCBC`. Sprites use `#E9DCBC`.

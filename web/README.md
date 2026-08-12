# LEGDAY on the web

`./build.sh` writes `dist/legday.html`. That one file is the whole game: open
it in a browser, or host it anywhere.

The page runs the real `LegdaySim` compiled to WebAssembly. It is not a second
implementation. `Bridge.swift` exports a small C ABI, and `legday.js` draws
what comes back. The rules, the numbers and the random seed all live in Swift,
so a change to the sim changes the web build with no port.

## What you need

Xcode's Swift has no WebAssembly backend, so a swift.org toolchain is required.

```
curl -O https://download.swift.org/swiftly/darwin/swiftly.pkg
installer -pkg swiftly.pkg -target CurrentUserHomeDirectory
~/.swiftly/bin/swiftly init
~/.swiftly/bin/swiftly install 6.3.3
swift sdk install \
  https://download.swift.org/swift-6.3.3-release/wasm-sdk/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz \
  --checksum cabfa08b73bb8ac783927ecd15fa386e99d0c139c5f232445067bcf58379cae7
```

None of this needs `sudo`. To undo it, delete `~/.swiftly` and run
`swift sdk remove swift-6.3.3-RELEASE_wasm`.

## Keep the binary small

The build is 6 MB. It was 52 MB, and 45 MB of that was Foundation's
internationalization tables. Two calls pulled them in:

| call | replaced by |
|---|---|
| `JSONDecoder` | tunables cross as 13 raw doubles |
| `String.uppercased()` | `Fusions.shout`, ASCII only |

Both loaders are still there for iOS, behind `#if !os(WASI)`. Before you add a
Foundation call to `LegdaySim`, build for wasm and check the size.

## The render layer

`legday.js` is a port of `Legday/Run/*`, layer for layer: the floor and its
relic, the two cliffs with their courses, the channel's furniture, the air, the
carrion birds, the foes, the Pilgrim's twelve-wedge cloak rig, her lantern, the
fog surface, the strike forms, the HUD, the charge rail and the Fate Card.
`art.js` carries `SpriteAtlas`, `ZoneLook` and `AirNode` — the same 17 sprites
under the same partial-alpha wash.

Two things could not be copied, and both are canvas limits:

**Lighting.** SpriteKit lights each sprite. A canvas can only multiply a whole
layer, which forces two changes. Everything lit is drawn into **one opaque
layer** — canvas `multiply` against a transparent pixel returns the source, so
a sparse layer comes back as a full-screen copy of the light map. And the
ambient is `#332C40` rather than the iOS `#1B1822`: at 10% the cliff art fell
to rgb(5,4,3) and its cross-hatching vanished.

**Corpses.** The iOS build tumbles them on a physics body. Here a plain
ballistic step stands in. They are cosmetic in both.

## Two sources of truth disagree

`legday-full.jpeg` specifies an **edge HUD only** — essence, fathoms and pause
in the top safe area. `HudNode.swift` draws a torn parchment strip instead, and
this port follows the code so the two builds match. Worth settling.

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

## What the web build does not have

The renderer is plain canvas, so there is no lighting, no baked art and no
cloak or rope. The run itself is complete: the gorge, the fog, foes, motes,
Fate Cards, forks and the Ascent stages.

Card art aside, the two builds play the same run for the same seed.

#!/bin/bash
# Build the web game into one self-contained HTML file.
#
# The shipped tunables.json is read here and baked in, so the web build and the
# app take their numbers from the same file. Requires the swift.org toolchain
# (Xcode's has no WebAssembly backend) and the wasm SDK:
#   ~/.swiftly/bin/swiftly install 6.3.3
#   swift sdk install <swift-6.3.3-RELEASE_wasm.artifactbundle.tar.gz URL> --checksum <sum>
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
export PATH="$HOME/.swiftly/bin:$PATH"

swift build --package-path "$here" --swift-sdk swift-6.3.3-RELEASE_wasm \
    -c release -Xlinker --strip-all

mkdir -p "$here/dist"
python3 "$here/bundle.py" \
    --wasm "$here/.build/release/LegdayWasm.wasm" \
    --tunables "$here/../Legday/Resources/tunables.json" \
    --sprites "$here/../Legday/Resources/sprites" \
    --shell "$here/shell.html" \
    --js "$here/art.js" "$here/legday.js" "$here/main.js" \
    --out "$here/dist/legday.html"

#!/usr/bin/env python3
"""Inline the wasm, the tunables and the scripts into one HTML file.

A published artifact may not fetch anything, so the wasm ships base64 inside
the page. The tunables come from the shipped JSON, in the order the Swift
`Tunables` init declares, which is the order `legday_start` reads them back.
"""
import argparse, base64, json, pathlib

ORDER = ["scroll", "spawn", "shove", "iframes", "fogGrace", "fogGrip",
         "fogCreep", "fogCeiling", "killPush", "downBias", "cardSlow",
         "firstCardCost", "cardCostIncrement"]


def main() -> None:
    ap = argparse.ArgumentParser()
    for flag in ("--wasm", "--tunables", "--shell", "--out"):
        ap.add_argument(flag, required=True)
    ap.add_argument("--js", nargs="+", required=True)
    a = ap.parse_args()

    tunables = json.loads(pathlib.Path(a.tunables).read_text())
    missing = [k for k in ORDER if k not in tunables]
    if missing:
        raise SystemExit(f"tunables.json is missing {missing}; update ORDER in bundle.py")
    values = [tunables[k] for k in ORDER]

    wasm = pathlib.Path(a.wasm).read_bytes()
    b64 = base64.b64encode(wasm).decode()

    # The module graph is flattened by hand: strip import/export lines, since a
    # single inline <script type="module"> has no module resolver behind it.
    body = []
    for path in a.js:
        src = pathlib.Path(path).read_text()
        body.append("\n".join(
            line for line in src.splitlines()
            if not line.startswith("import ") and not line.startswith("export {")
        ).replace("export function ", "function ").replace("export async function ", "async function "))

    page = pathlib.Path(a.shell).read_text() + f"""
<script type="module">
const TUNABLES = {json.dumps(values)};
const WASM_BYTES = Uint8Array.from(atob("{b64}"), c => c.charCodeAt(0));
{"".join(body)}
</script>
"""
    out = pathlib.Path(a.out)
    out.write_text(page)
    print(f"{out}  {len(page) / 1e6:.1f} MB  (wasm {len(wasm) / 1e6:.1f} MB)")


if __name__ == "__main__":
    main()

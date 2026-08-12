#!/usr/bin/env python3
"""Inline the wasm, the sprites, the tunables and the scripts into one HTML file.

A published artifact may not fetch anything, so every asset ships base64 inside
the page. The tunables come from the shipped JSON, in the order the Swift
`Tunables` init declares, which is the order `legday_start` reads them back.
"""
import argparse, base64, json, mimetypes, pathlib, re

ORDER = ["scroll", "spawn", "shove", "iframes", "fogGrace", "fogGrip",
         "fogCreep", "fogCeiling", "killPush", "downBias", "cardSlow",
         "firstCardCost", "cardCostIncrement"]

# The scripts are ES modules on disk. One inline script has no resolver, so
# the graph is flattened here.
IMPORT = re.compile(r"^\s*import\s.*?;\s*$")
EXPORT_LIST = re.compile(r"^\s*export\s*\{.*?\}\s*;?\s*$")
EXPORT_KEYWORD = re.compile(r"^(\s*)export\s+")


def flatten(path: pathlib.Path) -> str:
    out = []
    for line in path.read_text().splitlines():
        if IMPORT.match(line) or EXPORT_LIST.match(line):
            continue
        out.append(EXPORT_KEYWORD.sub(r"\1", line))
    return "\n".join(out)


def data_uri(path: pathlib.Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    return f"data:{mime};base64,{base64.b64encode(path.read_bytes()).decode()}"


def main() -> None:
    ap = argparse.ArgumentParser()
    for flag in ("--wasm", "--tunables", "--shell", "--sprites", "--out"):
        ap.add_argument(flag, required=True)
    ap.add_argument("--js", nargs="+", required=True)
    a = ap.parse_args()

    tunables = json.loads(pathlib.Path(a.tunables).read_text())
    missing = [k for k in ORDER if k not in tunables]
    if missing:
        raise SystemExit(f"tunables.json is missing {missing}; update ORDER in bundle.py")
    values = [tunables[k] for k in ORDER]

    sprites = {p.stem: data_uri(p)
               for p in sorted(pathlib.Path(a.sprites).glob("*.png"))}
    if not sprites:
        raise SystemExit(f"no sprites found in {a.sprites}")

    wasm = pathlib.Path(a.wasm).read_bytes()
    body = "".join(flatten(pathlib.Path(p)) for p in a.js)

    page = pathlib.Path(a.shell).read_text() + f"""
<script type="module">
const TUNABLES = {json.dumps(values)};
const SPRITES = {json.dumps(sprites)};
const WASM_BYTES = Uint8Array.from(atob("{base64.b64encode(wasm).decode()}"), c => c.charCodeAt(0));
{body}
</script>
"""
    out = pathlib.Path(a.out)
    out.write_text(page)
    print(f"{out}  {len(page) / 1e6:.1f} MB  "
          f"(wasm {len(wasm) / 1e6:.1f} MB, {len(sprites)} sprites)")


if __name__ == "__main__":
    main()

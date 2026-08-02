#!/usr/bin/env bash
# Append a screenshot + note to dogfood/index.html.
# Usage: dogfood/log.sh "title" [image.png]   (note via stdin or second arg)
set -euo pipefail

LOG="$(dirname "$0")/index.html"
TITLE="$1"
IMAGE="${2:-}"
NOTE=""

if [ -n "$IMAGE" ]; then
  B64=$(base64 < "$IMAGE")
  IMG="<img src=\"data:image/png;base64,$B64\">"
fi

if [ ! -t 0 ]; then
  NOTE=$(cat)
fi

python3 - "$LOG" "$TITLE" "$IMG" "$NOTE" <<'EOF'
import html, sys, datetime
log, title, img, note = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
stamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
entry = (
    f'<div class="entry">\n'
    f'  <h2>{html.escape(title)}</h2>\n'
    f'  <div class="meta">{stamp}</div>\n'
    f'  {img}\n'
    f'  <pre>{html.escape(note)}</pre>\n'
    f'</div>\n'
)
src = open(log).read()
src = src.replace("<!-- ENTRIES -->", entry + "<!-- ENTRIES -->")
open(log, "w").write(src)
print(f"logged: {title}")
EOF

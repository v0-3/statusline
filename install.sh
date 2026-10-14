#!/usr/bin/env bash
# Installs the statusline: copies statusline.sh into ~/.claude and points
# "statusLine" in ~/.claude/settings.json at it (backing up the old file first).
set -euo pipefail

url=https://raw.githubusercontent.com/v0-3/statusline/main/statusline.sh
dir=${CLAUDE_CONFIG_DIR:-$HOME/.claude}
script=$dir/statusline.sh
settings=$dir/settings.json

command -v jq >/dev/null || { echo 'jq is required: https://jqlang.org/download/' >&2; exit 1; }
mkdir -p "$dir"

# Run from a clone: install the local copy. Run via `curl | bash`: download it.
if [ -f "${BASH_SOURCE[0]:-}" ]; then
  cp "$(dirname "${BASH_SOURCE[0]}")/statusline.sh" "$script"
else
  curl -fsSL "$url" -o "$script"
fi
chmod +x "$script"

if [ -s "$settings" ]; then cp "$settings" "$settings.bak.$(date +%s)"; else echo '{}' >"$settings"; fi
new=$(jq --arg cmd "$script" '.statusLine = {type: "command", command: $cmd}' "$settings")
printf '%s\n' "$new" >"$settings"

echo "Installed $script. Claude Code picks it up automatically."

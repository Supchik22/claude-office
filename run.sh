#!/usr/bin/env bash
# Starts the session monitor if needed, then the office. Pass -- --demo for fake data.
set -eu
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GODOT="$HOME/Data/SteamLibrary/steamapps/common/Godot Engine/godot.x11.opt.tools.64"

if ! curl -sf -o /dev/null http://127.0.0.1:8765/; then
  setsid nohup python3 "$HOME/Documents/projects/claude-monitor/monitor.py" >/dev/null 2>&1 </dev/null &
fi
if [ ! -f "$DIR/.godot/global_script_class_cache.cfg" ]; then
  steam-run "$GODOT" --headless --path "$DIR" --import
fi
exec steam-run "$GODOT" --path "$DIR" "$@"

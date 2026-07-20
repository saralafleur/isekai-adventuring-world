#!/bin/zsh
# Read-only audit of the full "dev environment up" state: Rojo live-sync
# server + Roblox Studio, both running.
# Prints one "KEY | STATUS | DETAIL" line per check; exits 0 always.
# Safe to run any time — changes nothing, never starts anything itself.

setopt null_glob

line() { printf '%-18s | %-8s | %s\n' "$1" "$2" "$3"; }

# Status vocabulary:
#   ok      — present / running
#   info    — informational, no action implied
#   MISSING — required and absent (blocks bringing the environment up)

# Project root: this script lives at <project>/.claude/skills/devops/scripts/
PROJECT_DIR="${0:A:h}/../../../.."
PROJECT_DIR="${PROJECT_DIR:A}"
ROKIT_BIN="$HOME/.rokit/bin"
PORT=34872
PLACE_FILE="$PROJECT_DIR/EchoesOfAetheria.rbxl"

# --- rojo binary ---
if [ -x "$ROKIT_BIN/rojo" ]; then
  line "rojo" "ok" "$("$ROKIT_BIN/rojo" --version 2>/dev/null | head -1)"
elif command -v rojo >/dev/null 2>&1; then
  line "rojo" "ok" "$(rojo --version 2>/dev/null | head -1) (on PATH)"
else
  line "rojo" "MISSING" "rojo not installed (run: /devops roblox-setup)"
fi

# --- project file the server binds to ---
if [ -f "$PROJECT_DIR/default.project.json" ]; then
  line "project-file" "ok" "default.project.json present"
else
  line "project-file" "MISSING" "default.project.json not found at $PROJECT_DIR"
fi

# --- is the live-sync server already listening? ---
if lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  pid=$(lsof -tiTCP:$PORT -sTCP:LISTEN 2>/dev/null | head -1)
  line "rojo-serve" "ok" "RUNNING on localhost:$PORT (pid $pid)"
else
  line "rojo-serve" "info" "not running (up will start it)"
fi

# --- Roblox Studio app installed? ---
if [ -d "/Applications/RobloxStudio.app" ]; then
  line "studio-app" "ok" "/Applications/RobloxStudio.app"
else
  line "studio-app" "MISSING" "Roblox Studio not installed (run: /devops roblox-setup)"
fi

# --- place file to open Studio with ---
if [ -f "$PLACE_FILE" ]; then
  line "place-file" "ok" "$(basename "$PLACE_FILE") ($(du -h "$PLACE_FILE" | awk '{print $1}'))"
else
  line "place-file" "info" "$(basename "$PLACE_FILE") absent (up will build it: rojo build)"
fi

# --- is Roblox Studio already running? ---
if pgrep -x "RobloxStudio" >/dev/null 2>&1; then
  pid=$(pgrep -x "RobloxStudio" | head -1)
  line "studio-running" "ok" "RUNNING (pid $pid)"
else
  line "studio-running" "info" "not running (up will launch it with the place file)"
fi

exit 0

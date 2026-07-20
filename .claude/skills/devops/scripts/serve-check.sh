#!/bin/zsh
# Read-only audit of the Rojo live-sync server for this project.
# Prints one "KEY | STATUS | DETAIL" line per check; exits 0 always.
# Safe to run any time — changes nothing, never starts or stops the server.

setopt null_glob

line() { printf '%-18s | %-8s | %s\n' "$1" "$2" "$3"; }

# Status vocabulary:
#   ok      — present / running
#   info    — informational, no action implied
#   MISSING — required and absent (blocks live sync)

# Project root: this script lives at <project>/.claude/skills/devops/scripts/
PROJECT_DIR="${0:A:h}/../../../.."
PROJECT_DIR="${PROJECT_DIR:A}"
ROKIT_BIN="$HOME/.rokit/bin"
PORT=34872

# --- rojo binary (the server itself) ---
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

# --- is a server already listening? (makes the command idempotent) ---
if lsof -iTCP:$PORT -sTCP:LISTEN >/dev/null 2>&1; then
  pid=$(lsof -tiTCP:$PORT -sTCP:LISTEN 2>/dev/null | head -1)
  line "rojo-serve" "ok" "RUNNING on localhost:$PORT (pid $pid)"
else
  line "rojo-serve" "info" "not running (start: /devops serve)"
fi

exit 0

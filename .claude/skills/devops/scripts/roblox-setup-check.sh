#!/bin/zsh
# Read-only audit of the Roblox/Rojo build environment for this project.
# Prints one "KEY | STATUS | DETAIL" line per check; exits 0 always.
# Safe to run any time — changes nothing.

setopt null_glob

line() { printf '%-18s | %-8s | %s\n' "$1" "$2" "$3"; }

# Status vocabulary:
#   ok      — present and usable
#   info    — informational, no action implied
#   MISSING — required and absent (blocks the environment)
#   WRONG   — present but misconfigured
#   NEEDED  — a one-time action is pending (license, init, login)
#   LOW     — a resource is under its threshold (disk, memory)
#   absent  — optional tool not installed (no action required)

# Project root: this script lives at <project>/.claude/skills/devops/scripts/
PROJECT_DIR="${0:A:h}/../../../.."
PROJECT_DIR="${PROJECT_DIR:A}"
ROKIT_BIN="$HOME/.rokit/bin"

# --- OS / hardware context ---
line "os" "info" "$(sw_vers -productVersion 2>/dev/null || uname -sr) ($(uname -m))"

avail_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ "$avail_gb" -ge 3 ]; then disk_status="ok"; else disk_status="LOW"; fi
line "disk-free" "$disk_status" "${avail_gb} GB free (full install needs ~3 GB free)"

# --- Homebrew (installs Roblox Studio) ---
if command -v brew >/dev/null 2>&1; then
  line "brew" "ok" "$(brew --version 2>/dev/null | head -1)"
else
  line "brew" "MISSING" "Homebrew — installs Roblox Studio (https://brew.sh)"
fi

# --- Rokit toolchain manager ---
if [ -x "$ROKIT_BIN/rokit" ]; then
  line "rokit" "ok" "$("$ROKIT_BIN/rokit" --version 2>/dev/null | head -1)"
else
  line "rokit" "MISSING" "Rokit toolchain manager (github.com/rojo-rbx/rokit release binary)"
fi

# --- PATH entry for rokit-managed tools ---
if grep -q '.rokit/bin' "$HOME/.zshrc" 2>/dev/null; then
  line "rokit-path" "ok" "~/.rokit/bin on PATH via ~/.zshrc"
else
  line "rokit-path" "WRONG" "~/.zshrc does not add ~/.rokit/bin to PATH"
fi

# --- Project tool manifest ---
if [ -f "$PROJECT_DIR/rokit.toml" ]; then
  line "rokit-toml" "ok" "rokit.toml present in project"
else
  line "rokit-toml" "MISSING" "rokit.toml manifest not found at $PROJECT_DIR"
fi

# --- Pinned tools: rojo, wally, luau-lsp ---
pinned_version() {
  grep -E "^$1 *=" "$PROJECT_DIR/rokit.toml" 2>/dev/null | sed -E 's/.*@([0-9.]+)".*/\1/'
}

for tool in rojo wally luau-lsp; do
  if [ -x "$ROKIT_BIN/$tool" ]; then
    installed="$("$ROKIT_BIN/$tool" --version 2>/dev/null | head -1)"
    pin="$(pinned_version "$tool")"
    if [ -n "$pin" ] && ! printf '%s' "$installed" | grep -q "$pin"; then
      line "$tool" "WRONG" "installed '$installed' but rokit.toml pins $pin (run: rokit install)"
    else
      line "$tool" "ok" "$installed"
    fi
  else
    line "$tool" "MISSING" "not in ~/.rokit/bin (run: rokit install, in the project dir)"
  fi
done

# --- Roblox Studio ---
if [ -d "/Applications/RobloxStudio.app" ]; then
  line "studio-app" "ok" "/Applications/RobloxStudio.app ($(du -sh /Applications/RobloxStudio.app 2>/dev/null | awk '{print $1}'))"
else
  line "studio-app" "MISSING" "Roblox Studio (brew install --cask robloxstudio, ~800 MB installed)"
fi

# --- Rojo Studio plugin ---
if [ -f "$HOME/Documents/Roblox/Plugins/RojoManagedPlugin.rbxm" ]; then
  line "rojo-plugin" "ok" "RojoManagedPlugin.rbxm in ~/Documents/Roblox/Plugins"
else
  line "rojo-plugin" "MISSING" "Rojo Studio plugin (run: rojo plugin install)"
fi

# --- Luau API type definitions (needed by luau-lsp analyze) ---
if [ -f "$PROJECT_DIR/globalTypes.d.luau" ]; then
  line "global-types" "ok" "globalTypes.d.luau present ($(du -h "$PROJECT_DIR/globalTypes.d.luau" | awk '{print $1}'))"
else
  line "global-types" "MISSING" "globalTypes.d.luau (curl from luau-lsp repo scripts/, ~1 MB)"
fi

# --- Informational: sourcemap + live sync server ---
if [ -f "$PROJECT_DIR/sourcemap.json" ]; then
  line "sourcemap" "info" "sourcemap.json present (regenerate: rojo sourcemap)"
else
  line "sourcemap" "info" "sourcemap.json absent (regenerable: rojo sourcemap default.project.json -o sourcemap.json)"
fi

if lsof -iTCP:34872 -sTCP:LISTEN >/dev/null 2>&1; then
  line "rojo-serve" "info" "rojo serve RUNNING on localhost:34872"
else
  line "rojo-serve" "info" "rojo serve not running (start when live-syncing to Studio)"
fi

exit 0

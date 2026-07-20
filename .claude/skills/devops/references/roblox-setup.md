# roblox-setup — Roblox/Rojo toolchain setup procedure

Goal: from any starting state, end with a machine that can build, analyze,
and live-sync this Roblox game, proven by a clean `luau-lsp analyze` and a
successful `rojo build` of the actual project.

## Phase 1 — Audit (always first, read-only)

Run the audit script (at `scripts/roblox-setup-check.sh` under this skill's
base directory) and show Sara the table:

```bash
zsh <skill-base-dir>/scripts/roblox-setup-check.sh
```

If every build-relevant row is `ok`, report "environment is already set up",
offer the Phase 4 smoke test as proof, and stop.

If invoked in status-only mode (bare `/devops`), stop after showing the table.

## Phase 2 — Plan

From the audit, list only the missing/wrong items, in dependency order, with
sizes. Sizes measured on this machine (2026-07):

| Step | Size / time | Interactive? |
|---|---|---|
| Install Homebrew | ~500 MB, ~5 min | Yes — sudo password |
| Install Rokit (release binary) | ~6 MB download, <1 min | No |
| Add ~/.rokit/bin to PATH in ~/.zshrc | trivial | No |
| `rokit install` (rojo, wally, luau-lsp per rokit.toml) | ~77 MB total in ~/.rokit, ~1 min | No (trust prompts handled via `rokit trust`) |
| Install Roblox Studio | ~800 MB installed (download ~400 MB), ~3 min | No (brew cask); first launch needs a Roblox account sign-in — Sara does that in the app |
| Install Rojo Studio plugin | ~500 KB, <1 min | No |
| Download globalTypes.d.luau | ~800 KB, <1 min | No |

Check disk space (~3 GB free covers everything). Confirm with Sara before
the Studio download.

## Phase 3 — Install

Only run the steps the audit flagged. Every step is idempotent.

### 3.1 Homebrew (if `brew` MISSING)

Interactive (needs sudo). Hand to Sara:

```
! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### 3.2 Rokit (if `rokit` MISSING)

Rokit was deprecated in Homebrew's core (aftman predecessor); install the
release binary directly:

```bash
cd <scratchpad>
curl -sL -o rokit.zip \
  "$(curl -s https://api.github.com/repos/rojo-rbx/rokit/releases/latest \
     | python3 -c "import json,sys; d=json.load(sys.stdin); print([a['browser_download_url'] for a in d['assets'] if 'macos-aarch64' in a['name']][0])")"
unzip -o rokit.zip -d rokit_extracted
chmod +x rokit_extracted/rokit
./rokit_extracted/rokit self-install
```

### 3.3 PATH entry (if `rokit-path` WRONG)

Append to `~/.zshrc` (only if the line is absent — check first):

```bash
grep -q '.rokit/bin' ~/.zshrc || {
  echo '' >> ~/.zshrc
  echo '# Added by Rokit' >> ~/.zshrc
  echo 'export PATH="$HOME/.rokit/bin:$PATH"' >> ~/.zshrc
}
```

Note: in this session's non-interactive shells, still prefix commands with
`export PATH="$HOME/.rokit/bin:$PATH"` — the .zshrc only covers new
interactive shells.

### 3.4 Pinned tools (if `rojo`/`wally`/`luau-lsp` MISSING or WRONG)

From the project directory (rokit.toml pins the versions):

```bash
cd <project-dir>
rokit trust rojo-rbx/rojo UpliftGames/wally JohnnyMorganz/luau-lsp
rokit install
```

### 3.5 Roblox Studio (if `studio-app` MISSING)

The cask name is `robloxstudio` (NOT `roblox-studio`):

```bash
brew install --cask robloxstudio
```

First launch requires a Roblox account sign-in — Sara does that in the app
itself; there is nothing to script.

### 3.6 Rojo Studio plugin (if `rojo-plugin` MISSING)

The plugins directory may not exist on a fresh machine (rojo errors with
"No such file or directory" if so):

```bash
mkdir -p ~/Documents/Roblox/Plugins
rojo plugin install
```

Studio only scans for plugins at launch — if Studio is open, it needs a
restart to see the plugin.

### 3.7 Luau API types (if `global-types` MISSING)

```bash
cd <project-dir>
curl -sL -o globalTypes.d.luau \
  https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
```

(gitignored on purpose — regenerable.)

## Phase 4 — Verify (smoke test)

Re-run the audit script — all build-relevant rows must be `ok`. Then prove
the environment with the real project:

1. **Version chain:** `rojo --version`, `wally --version`,
   `luau-lsp --version` all answer.
2. **Static analysis (real code):**
   ```bash
   cd <project-dir>
   rojo sourcemap default.project.json -o sourcemap.json
   luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
   ```
   Exit 0 = the entire game's Luau type-checks.
3. **Real build (best proof):**
   ```bash
   rojo build default.project.json -o EchoesOfAetheria.rbxl
   ```
   A `.rbxl` place file is produced from the actual game.
4. **Live-sync (only if Sara wants to playtest):** `rojo serve` in the
   background, then Sara opens the place in Studio and connects the Rojo
   plugin (localhost:34872).

Report the result plainly: what was proven, what wasn't (e.g. Studio
sign-in state can't be verified from the CLI).

## Notes

- Tool versions are pinned in `rokit.toml` (rojo 7.7.0, wally 0.3.2,
  luau-lsp 1.69.0 at time of writing) — `rokit install` respects the pins;
  don't `brew install rojo` (unpinned, drifts).
- `aftman` (Rokit's predecessor) was disabled in Homebrew 2026-07 — that's
  why Rokit comes from a GitHub release binary.
- Roblox Studio updates itself; the cask version only matters at first
  install.
- The Rojo plugin file is `RojoManagedPlugin.rbxm` — managed by
  `rojo plugin install`, safe to re-run for upgrades.
- CLAUDE.md documents the day-to-day verify loop (sourcemap → analyze →
  build); this skill owns machine setup, not that loop.

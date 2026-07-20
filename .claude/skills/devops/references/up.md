# up — bring the whole dev environment up

Goal: one command that gets Sara from a cold machine to "editing `.luau` files
live-updates Studio" — checks (and starts) the Rojo live-sync server, AND
checks (and launches) Roblox Studio with the game open. `serve` on its own
only handles the server half; `up` handles both. Four phases: audit → plan →
**launch** → verify.

## Phase 1 — Audit (always first, read-only)

```bash
zsh <skill-base-dir>/scripts/up-check.sh
```

- If `rojo` is `MISSING` or `studio-app` is `MISSING`, the toolchain isn't
  set up — send Sara to `/devops roblox-setup` and stop.
- Otherwise, note which of `rojo-serve` / `studio-running` are already `ok`
  — only act on the ones that aren't (idempotent: re-running `up` on a fully
  running environment changes nothing).

## Phase 2 — Plan

State plainly what's about to happen, e.g.:
- "Rojo server already running — leaving it alone."
- "Studio isn't running — launching it with `EchoesOfAetheria.rbxl`."
- If `place-file` is `info` (absent): "No place file yet — building one
  first (`rojo build`), then opening it."

Nothing destructive happens in this command; Studio launches are safe to
run any time.

## Phase 3 — Launch

Handle each piece independently — only the ones the audit flagged:

### 3.1 Rojo live-sync server (if `rojo-serve` is not `ok`)

Same as the `serve` command:

```bash
export PATH="$HOME/.rokit/bin:$PATH"
rojo serve default.project.json
```

Run via the Bash tool's `run_in_background` option (not a trailing `&`),
from the project directory. See `references/serve.md`'s durability note if
it keeps getting killed across turns — hand Sara the `!`-prefixed terminal
form to run herself instead.

### 3.2 Place file (if `place-file` is `info`, i.e. absent)

Build one so Studio has something to open:

```bash
export PATH="$HOME/.rokit/bin:$PATH"
rojo build default.project.json -o EchoesOfAetheria.rbxl
```

### 3.3 Roblox Studio (if `studio-running` is not `ok`)

Open the place file — macOS launches Studio automatically as the `.rbxl`
handler:

```bash
open EchoesOfAetheria.rbxl
```

This is a GUI launch; give it a few seconds to start before verifying.

## Phase 4 — Verify

Re-run the audit and confirm both pieces:

```bash
zsh <skill-base-dir>/scripts/up-check.sh
```

- `rojo-serve` should read `ok` / `RUNNING on localhost:34872`.
- `studio-running` should read `ok` / `RUNNING (pid ...)`.

Then tell Sara the last step is hers: in Studio, click **Connect** on the
Rojo plugin (address `localhost:34872`). The CLI can confirm the process
launched and the server is listening, but not that Studio finished loading
the place or that the plugin connected — that's a visual check only Sara
can make.

## Notes

- The place file opened is a snapshot from whenever it was last built; live
  sync (once Sara clicks Connect) brings it fully current, so a stale file
  is fine to open — it doesn't need rebuilding just because time passed,
  only when it's missing entirely.
- If Studio is already open with a different, unrelated place, `up` still
  launches a second Studio window for `EchoesOfAetheria.rbxl` rather than
  trying to detect or reuse the existing window — Studio itself handles
  multiple open places.
- To stop things: kill the `rojo serve` background job as in `serve.md`;
  quit Studio normally. `up` has no corresponding teardown command.

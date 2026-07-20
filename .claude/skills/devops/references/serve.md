# serve — Rojo live-sync server procedure

Goal: start (or confirm) the `rojo serve` server that live-syncs this project's
`.luau` files into Roblox Studio, so edits on disk update the open place as you
work. This command manages a running process rather than an install, so the
usual four phases map to: audit → plan → **launch** → verify.

## Phase 1 — Audit (always first, read-only)

```bash
zsh <skill-base-dir>/scripts/serve-check.sh
```

- If `rojo-serve` is already `ok` (RUNNING), report the address and pid and
  **stop** — do not launch a second server (the port is already bound; a second
  `rojo serve` just errors). This is what makes the command idempotent.
- If `rojo` is `MISSING`, the toolchain isn't set up — send Sara to
  `/devops roblox-setup` and stop.
- Otherwise proceed to launch.

## Phase 2 — Plan

State plainly what will happen: a background `rojo serve default.project.json`
on `localhost:34872`, which Sara then connects to from the Rojo Studio plugin.
Nothing is installed or written; the server can be stopped any time.

## Phase 3 — Launch

Start it as a background process so it outlives the current turn:

```bash
export PATH="$HOME/.rokit/bin:$PATH"
rojo serve default.project.json
```

Run this via the Bash tool's `run_in_background` option (not a trailing `&`),
from the project directory.

Durability note: the server has been seen to get killed when the surrounding
session's background job is torn down. If it will not stay up across turns, or
Sara wants it to survive this session entirely, hand her the terminal form to
run herself — it then lives independently of the agent session:

```
! rojo serve default.project.json
```

## Phase 4 — Verify

Read the background job's output and confirm the listening banner, or re-run
the audit and confirm `rojo-serve` is now `ok`:

```bash
zsh <skill-base-dir>/scripts/serve-check.sh
```

Then tell Sara the next step is hers: in Studio, open the place and click
**Connect** on the Rojo plugin (address `localhost:34872`). The CLI cannot
verify the Studio-side connection — only that the server is listening.

## Stopping

To stop it, kill the background job (or Ctrl-C the terminal form). A clean
alternative when only a one-off build is needed — no live sync — is
`rojo build default.project.json -o EchoesOfAetheria.rbxl` and opening that
place file directly; that needs no server at all.

## Notes

- Port 34872 is Rojo's default; the audit and the plugin both assume it.
- Live sync is one-way: disk → Studio. Changes made inside Studio are not
  written back to the `.luau` files.
- Studio only sees the plugin's connection after you click Connect; a place
  opened before the server started still just needs that click, not a restart.

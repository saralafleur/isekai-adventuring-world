---
name: devops
argument-hint: "[roblox-setup | roblox | setup | rojo | tts-setup | tts | voices | status]"
description: >
  Isekai in an Adventuring World (Roblox)'s DevOps toolbox — commands for
  setting up and verifying this project's build environments. Use when Sara
  types "/devops", or asks to set up, check, or repair the Roblox/Rojo build
  environment for this project. Current commands: `roblox-setup` (aliases
  `roblox`, `setup`, `rojo`) — installs and verifies the full Roblox
  development toolchain (Rokit, Rojo, Wally, luau-lsp, Roblox Studio, the
  Rojo Studio plugin, and Luau API types); `status` — read-only report of the
  current state of everything the devops skill manages. Invoking with no
  command lists available commands and runs the status report.
---

# DevOps Skill — Isekai in an Adventuring World (Roblox)

A command-based toolbox for build-environment setup. Each command follows the
same discipline:

1. **Audit first** — run the read-only check script and show current state.
2. **Plan** — list exactly what's missing, with download sizes and disk
   requirements, before installing anything.
3. **Install** — run non-interactive steps directly. For steps needing a
   login or `sudo`, give Sara the exact command prefixed with `!` so she can
   run it in-session (e.g. `! brew install --cask robloxstudio` if a prompt
   is expected).
4. **Verify** — prove the environment works end-to-end, don't just assume
   installs succeeded.

Never install anything before showing the audit and plan. All installs must be
idempotent — re-running a command on a healthy environment should report
"already set up" and change nothing.

## Command routing

Parse the argument after `/devops`:

| Argument | Command |
|---|---|
| `roblox-setup`, `roblox`, `setup`, `rojo` | Roblox toolchain setup — follow `references/roblox-setup.md` |
| `tts-setup`, `tts`, `voices` | Dialogue voice toolchain — follow `references/tts-setup.md` |
| `status` | Report current state of everything this skill manages — follow `references/status.md` |
| *(none)* | List commands, then run the `status` command |

Unknown argument → list available commands, suggest the closest match.

## Commands

### roblox-setup

Sets up the complete Roblox development environment for this project:
Homebrew, the Rokit toolchain manager, the project-pinned tools from
`rokit.toml` (Rojo, Wally, luau-lsp), Roblox Studio, the Rojo Studio plugin,
and the Luau API type definitions used for static analysis. Verified by a
clean `luau-lsp analyze` and a successful `rojo build` of the actual game.
Full procedure in `references/roblox-setup.md`; audit script at
`scripts/roblox-setup-check.sh` (run it relative to this skill's base
directory).

### tts-setup

Installs the local neural TTS (Kokoro) used to generate the spoken dialogue
lines: `uv`, an mp3 encoder, a python env, and the 353 MB model weights. The
generated clips and their Roblox asset ids ARE committed, so a fresh clone has
working voices without this — it's only needed to change or re-record
dialogue. Full procedure in `references/tts-setup.md`; audit script at
`scripts/tts-setup-check.sh`.

### status

Read-only report of the current state of everything the devops skill
manages. Runs every audit script in `scripts/` (so new commands are picked
up automatically) and gives a per-command verdict plus what to run to fix
anything unhealthy. Never installs or changes anything. Procedure in
`references/status.md`.

## Adding new commands

New commands get: a row in the routing table, a section here, a procedure doc
in `references/<command>.md`, an entry in the frontmatter `argument-hint`,
and a read-only audit script in `scripts/<command>-check.sh` — the audit
script is what makes the command show up in `status`. Keep the
audit/plan/install/verify structure. (A likely future addition: a `serve`
command managing the `rojo serve` live-sync server as a background process.)

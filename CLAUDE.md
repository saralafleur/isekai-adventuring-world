# test-game (Roblox)

A Roblox game built with Rojo. Sara describes what she wants; Claude writes the Luau code.

## Toolchain

Tools are pinned in `rokit.toml` and installed via [Rokit](https://github.com/rojo-rbx/rokit) (`rokit install`):
- **Rojo** — syncs this filesystem into Roblox Studio
- **Wally** — Roblox package manager (packages land in `Packages/`, gitignored — reproducible from `wally.lock`)

## Project layout

- `src/server/` → `ServerScriptService.Server` (server-only code; trusted, not visible to clients)
- `src/client/` → `StarterPlayer.StarterPlayerScripts.Client` (per-player local code)
- `src/shared/` → `ReplicatedStorage.Shared` (modules used by both client and server)
- `Packages/` → `ReplicatedStorage.Packages` (Wally dependencies)
- Each of `src/{client,server}` has an `init.client.luau` / `init.server.luau` entry point; that file's siblings/children become the folder's children in Studio. Add new modules as files alongside the entry point (e.g. `src/server/Systems/Combat.luau`).

## Workflow

1. `rojo serve` — starts the sync server
2. In Studio, open this place and click "Connect" on the Rojo plugin (install once via `rojo plugin install`)
3. Claude edits `.luau` files on disk; Studio updates live
4. `rojo build default.project.json -o test-game.rbxl` — produce a standalone place file (e.g. for CI or a one-off build) without Studio open

## Luau conventions

- All new scripts use `.luau` extension (not legacy `.lua`)
- Prefer strict typing (`--!strict`) for shared modules; server/client entry scripts can stay `--!nocheck` or nonstrict if that's where they end up naturally
- One module = one responsibility. Shared data structures/types live in `src/shared`
- Client and server never `require` across the client/server boundary directly — share through `src/shared`, and use RemoteEvents/RemoteFunctions (in `src/shared` or a dedicated `Remotes` module) for client↔server communication
- No dead/commented-out code left in place

## Verifying changes

Run both before considering any change done:

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build default.project.json -o /dev/null
```

(`globalTypes.d.luau` is gitignored; re-download from the luau-lsp repo's `scripts/globalTypes.d.luau` if missing.)

## The game

This repo builds **Echoes of Aetheria**, an isekai fantasy RPG — full design doc in `isekai_roblox_storyboard.md`. World geometry is currently procedurally greyboxed from `src/server/World/VillageBuilder.luau`; gameplay code finds world objects via CollectionService tags (`NPC`, `GatherNode`) and attributes (`NpcName`, `ItemId`), never geometry, so greybox can be replaced with real art without code changes.

## Notes for Claude

- This project has no automated test runner set up yet. Verify with the commands above, and describe manual Studio playtest steps when a change needs runtime verification.
- Don't invent gameplay systems that weren't asked for. Build exactly what the current request describes; ask before assuming scope on ambiguous requests.

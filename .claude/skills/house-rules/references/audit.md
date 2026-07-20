# audit — building audit procedure

Goal: one prioritized, evidence-backed correction plan for the village's
buildings, produced by a team of specialists rather than one pass of guessing.

## Phase 1 — Scope

- Bare `audit` → every builder in `src/server/World/`: `HouseBuilder`
  (the parametric generator all houses/shops flow through), `CottageBuilder`,
  `GuildBuilder`, `TownBuilder`, `DistrictBuilder`, `FarmBuilder`,
  `SmithyBuilder`.
- `audit <building>` → resolve the name to its builder and config. Numbered
  houses (`House N`) come from the `PLOTS` table in `TownBuilder` via
  `HouseBuilder`; named venues map to their builder by sign text.

State the scope in one line before spawning anything.

## Phase 2 — Fan out (parallel)

Spawn all seven specialists **in one message** so they run concurrently. Give
each the same scope and tell it to read the rulebook first:

| Agent | Owns |
|---|---|
| `house-geometry` | G-1…G-5 — z-fighting, floating, intersections, roof clearance |
| `house-circulation` | C-1…C-6, N-2 — doors, stairs, landings, hallways, reachability |
| `house-scale` | S-1…S-6 — ceilings, footprints, openings, furniture clearance |
| `house-furnishing` | F-1…F-4, N-1 — purpose, variety, lighting, staffing, facing |
| `house-exterior` | E-1…E-5 — facade, roof, signage, spacing, frontage |
| `house-stairs` | T-1…T-9 — every staircase end to end |
| `house-paths` | P-1…P-6 — routes around buildings, door service, network |

Each returns a findings list with rule IDs, file:line evidence, concrete
fixes, and severities.

## Phase 3 — Synthesize

Run `house-audit-lead` with all five reports. It de-duplicates overlapping
findings, ranks by player impact, groups by file, and produces a recommended
fix order plus a list of items needing Sara's visual judgment.

## Phase 4 — Report and gate

Present the lead's plan to Sara. Do **not** start fixing — `audit` ends at
the plan. Ask which items to fix; that's the `fix` command's job.

Keep the presented summary tight: blockers and majors in full, minors
collapsed to a count per category unless asked.

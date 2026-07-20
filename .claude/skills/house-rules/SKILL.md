---
name: house-rules
argument-hint: "[audit | audit <building> | rules | fix]"
description: >
  The building rulebook and audit team for Isekai in an Adventuring World.
  Use when Sara wants to check, critique, or clean up the village's buildings
  — "audit the houses", "what's wrong with House 3", "do the buildings follow
  our rules" — or when adding/changing any building builder. `rules` shows the
  canonical building rules; `audit` fans out a team of specialist agents
  (geometry, circulation, scale, furnishing, exterior) over the builders and
  returns one prioritized correction plan; `fix` applies approved corrections.
  Read the rules before writing any building code.
---

# House Rules — building standards and audit team

Two things live here:

1. **The rulebook** — `references/building-rules.md`, the canonical standards
   every building must meet (geometry, scale, circulation, furnishing,
   exterior, NPC integration). Read it before writing or changing any
   builder in `src/server/World/`.
2. **The audit team** — five specialist agents plus a lead that read the
   builder source, do the coordinate math, and report rule violations.

## What the audit can and cannot see

The agents read **code**, not pixels. They catch what's provable from
geometry: coplanar faces, floating parts, blocked openings, stairwell gaps,
cramped clearances, missing furnishing, spacing violations. They **cannot**
judge whether something simply looks good. Visual taste stays with Sara —
the lead's report flags anything it believes needs her eyes.

## Command routing

| Argument | Command |
|---|---|
| `audit` | Full audit of every building — follow `references/audit.md` |
| `audit <building>` | Same, scoped to one building (e.g. `audit House 3`, `audit The Green Flask`) |
| `rules` | Print/summarize `references/building-rules.md` |
| `fix` | Apply corrections from the most recent audit (see below) |
| *(none)* | List commands, then summarize the rulebook's sections |

## audit

Procedure in `references/audit.md`. In short: fan out the five specialists in
parallel over the scope, then run `house-audit-lead` to merge their findings
into one prioritized, de-duplicated plan grouped by file.

## fix

Never runs automatically. Show Sara the audit's plan, get explicit approval
on which items to fix, then apply them in the lead's recommended order —
smallest-blast-radius first, verifying after each batch:

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build default.project.json -o /dev/null
```

A fix that can't be verified isn't done. Re-run the relevant specialist after
a fix batch to confirm the finding is actually closed.

## Adding rules

New rules go in `references/building-rules.md` with a stable ID in the right
section, and get assigned to whichever specialist's scope covers them (edit
that agent's "Your scope"). Rules earn their place by having burned us once —
note the history inline so nobody "simplifies" the rule away later.

# Building Rules — Isekai in an Adventuring World

The canonical rules every building in this game must satisfy. Written for
both **authors** (read before adding or changing a builder) and **auditors**
(the specialist agents check compliance rule by rule).

Rule IDs are stable — cite them in findings (e.g. "violates G-3").

---

## G — Geometry integrity

**G-1. No coplanar surfaces.** Two visible faces must never occupy the same
plane; they z-fight (flicker as the camera moves). Any two parts that meet
must either overlap in volume or be offset by **≥ 0.1 studs**.
*History: floor vs foundation, window frames vs wall jambs, gable tops vs
roof slabs, well water vs stone ring — every one of these shipped broken.*

**G-2. Trim buries cut faces.** Frame pieces around an opening (window, door,
partition doorway) must overlap **into** the opening ~0.2 studs, so the wall
panels' cut faces are hidden inside the trim rather than flush with it.

**G-3. Nothing floats.** Every part rests on a floor, embeds into a wall, or
hangs from a chain/bracket that physically reaches its anchor surface.
Wall fixtures embed ≥ 0.1 into the wall. Hanging lights need a chain whose
top touches a rafter, ceiling, or floor plate above.

**G-4. Sloped roofs clear the walls.** A pitched roof loses height toward the
eaves; clearance must be computed at the wall's **outer face**, not its
centerline. Eave-side walls stop below the slope and an eave plate fills the
gap, sized so its top stays inside the slab across its full depth.

**G-5. Overlapping ground planes differ in thickness.** Roads, lanes, plazas
and paths that cross must have different heights so their top faces never
share a plane.

---

## S — Scale and proportion

**S-1. Ceilings are grand.** Story height ≥ **14 studs** for homes and shops
(≈2.5× character height). Purpose-built exceptions: guild halls ≥ 12, town
hall ≥ 10, barn/warehouse ≥ 12. An interior a player can nearly touch the
ceiling of is a bug.

**S-2. Doors are generous.** Exterior doors ≥ **6 wide × 10 tall**; interior
doorways ≥ 4 × 9. Big-purpose doors (barn, warehouse) ≥ 8 wide.

**S-3. Footprints fit purpose.** Homes ≥ **30 × 24**. Shops ≥ 26 × 20.
Sheds/storage may be smaller but then must use the storage interior, never a
cramped "home" layout.

**S-4. Windows are proportional.** ≥ 4 wide, sill and head placed for the
story's height (not left at ground-story values on upper floors).

**S-5. Furniture is proportional to the room.** A table/bed/cabinet must not
consume more than ~⅓ of a room's floor area, and must leave S-6 clearance.

**S-6. Walkable clearance.** ≥ **4 studs** of clear floor between any two
pieces of furniture, and between furniture and a wall on at least one
approach side. Hallways ≥ 4 wide; stair runs ≥ 3.5 wide.

---

## C — Circulation (getting around)

**C-1. Front doors are enterable.** Every building the player may enter has
an open doorway (no collidable slab) reachable from a road, lane or path.

**C-2. No blocked openings.** No beam, band, furniture, or fixture may cross
a doorway or window opening. *History: a mid-height wall plate once ran
straight through the cottage doorway at chest height.*

**C-3. Stairs are real and walkable.** Multi-story buildings use stepped runs
(solid risers, individual step ≤ 0.9 rise) with a handrail on each open side
— never a bare ramp.

**C-4. Stairwells land safely.** The floor plate above must leave a hole for
the run and **close flush against the top step** — no gap to fall through —
with guard railing around the open edges.

**C-5. Upper floors have circulation, not dormitories.** Above the ground
floor: a hallway serving separate rooms behind framed doorways. Exception:
inn/barracks lodging may be one uniform shared room by design.

**C-6. Furniture never occupies circulation space.** Nothing inside a stair
run's footprint, a stairwell hole, a doorway swing, or a hallway.

---

## T — Stairs

Stairs get their own family because they are the single most defect-prone
structure in the game — every audit round has found a new way for them to
trap, block, or drop a player.

**T-1. The approach is open.** ≥ **4 studs** of clear floor in front of the
bottom step, and ≥ 2 studs to either side of the run's mouth. Nothing —
furniture, hearth, crate, barrel, wall stub — inside that approach.

**T-2. The landing is real.** The floor above must extend ≥ **4.5 studs**
past the top step, at the top step's full width, and close **flush** with it
(no gap, no lip beyond 0.1).
*History: the six shops' landings computed to negative depth and were
silently discarded — you climbed into a sealed wall.*

**T-3. Risers are walkable and uniform.** Individual rise ≤ **0.9 studs**,
identical for every step in a run; tread ≥ 0.7.

**T-4. Runs are wide enough.** ≥ **3.5 studs**, 4.2 standard.

**T-5. Railings guard, never block.** A handrail on every open side of the
run and every open edge of the stairwell — but **never across the arrival or
the exit**. Rail bars sit ≥ 2.5 above their walking surface, and a rail must
never be the only thing between the top step and the floor it serves.
*History: both guild halls sealed their own upper floors this way.*

**T-6. Headroom the whole way up.** ≥ **7 studs** of clear space above every
step. Nothing may sit over a run — including another run.

**T-7. Successive runs never share a footprint.** A story's run must not
overlap the run below it in plan. Alternate side walls (or offset), and note
that merely reversing the climb direction does **not** move the footprint.

**T-8. The stairwell hole matches the run.** The opening in the floor above
covers the portion of the run where headroom would otherwise fail, and no
more — a hole that extends past that is an unguarded drop in walkable floor.

**T-9. Nothing lives in the run.** No furniture, fixture or prop inside the
run's footprint, its approach, or the stairwell hole.

---

## P — Paths and routes

**P-1. A path never crosses a building.** No road, lane, path or spur may
overlap any building's footprint, and it must clear the foundation skirt by
≥ **2 studs**. Routes go *around* buildings.
*History: the residential lanes were laid as smooth polylines with no regard
for the plots beside them and ran straight through houses.*

**P-2. Every door is served.** A building's door side connects to a path
whose near edge is within **10 studs** of the doorstep, with clear ground
between.

**P-3. The network connects.** Every path segment reaches the rest of the
network — no orphan strips. A player must be able to walk from any building
door to the plaza on surfaced ground.

**P-4. Wide enough to walk and pass.** Main roads ≥ 10 studs, lanes ≥ 6,
spurs ≥ 5.

**P-5. Junctions are continuous.** Where segments meet they overlap so no
grass gap shows through, and their thicknesses differ by ≥ 0.04 so the tops
never share a plane (see G-5).

**P-6. Paths avoid obstacles, not just buildings.** Fences, fields, water,
material piles and props are routed around as well.

---

## F — Furnishing and purpose

**F-1. Furnished to purpose.** A home has living space below and sleeping
space above; a shop has counter + stock + display; a workshop has its tools
and materials; storage has crates/barrels. An empty room is a bug.

**F-2. Rooms vary.** No two bedrooms in the same building are identical;
variants differ in furniture mix (chest/wardrobe/desk etc.).

**F-3. Lit.** Every enterable room has a light source (hanging lantern,
sconce, hearth, or candle) obeying G-3.

**F-4. Staffed venues have staff.** A shop/guild/workshop the player can
interact in has an NPC positioned **behind** its counter, facing the
customer side (see N-1).

---

## E — Exterior and site

**E-1. Identified.** Every building carries a sign above its door: houses a
stable number ("House N"), named venues their business name on a larger
framed board plus a perpendicular double-sided hanging sign.

**E-2. Spacing.** No building's footprint comes within **12 studs** of
another's. Buildings never intersect.

**E-3. Fronted on a route.** A building's door side faces a road, lane, or
path — never a blank field or another building's back wall.

**E-4. Detail the facade.** Timber studs/wainscot, shutters or frames,
corner posts, eave plates — a blank plaster box is unfinished.

**E-5. Roof completeness.** Ridge cap, gables closed at both ends, and eave
treatment on all four sides.

---

## N — NPC integration

**N-1. Facing.** A stationary NPC faces the space its visitors occupy.
*Careful: Roblox's `LookVector` is the CFrame's **−Z**; a stall built with
its front on +Z needs the negated vector.*

**N-2. Reachable destinations.** Any tagged NPC destination (`HouseDoor`,
`BrowseSpot`, `GatherSpot`, `FieldSpot`, `AnvilSpot`, `SmithyWatchSpot`)
must sit on navigable ground clear of walls and furniture, so pathfinding
can actually reach it.

**N-3. No dead-end pathing.** Never fall back to straight-line movement when
a path fails — that grinds NPCs into walls. Idle and re-plan instead.

---

## V — Verification (every change)

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src
rojo build default.project.json -o /dev/null
```

Both must pass before a building change is considered done.

# Cat gym layout rules

The spec for the planner that replaces the free-space fill in `theme-cattree.lua`. It merges
two independent drafts written on 2026-11-04 from the user's brief (`CATTREE-PLAN.md`, "Design
brief: intent"): one by a Fable agent grounded in the reference photos, one by Claude
(`scratch/cattree-rules-claude.md`). They agreed on the core (a graph of standing surfaces and
moves, connectors chosen by the vector between two landings, one rhythm per series, cat-sized
clearance, validation that rejects bad pages). The Fable draft is the base text below because it
goes further: each module *creates* its arrival landing, so nothing is joined afterwards; it has
backtracking, a fallback that always fits, scored composition and a motif catalogue. From the
Claude draft: the explicit "every piece is a node, an edge, a support or a dressing" test (R2)
and choosing route positions so the zigzag covers the column (R12).

User decisions (2026-11-04), which override the text below where they differ:
- **The lookout ends the page.** No dots or steps above the top perch.
- **Several ways up, interconnected.** Not one monotone route: two (sometimes three) routes from
  the tower to the top, joined by cross-links (short bridges, steps, a ladder) at one or two
  levels, so a cat can switch routes; loops are fine. Routes keep R5 apart from each other
  (≥ 60 cm horizontally, different kinds side by side), and every cross-link is a real module
  joining two landings. Beds and boxes still hang off the routes as dead ends.
- **Short rope bridges are common.** Door to door between boxes, shelf to shelf, as cross-links;
  any gap from about 40 cm. Long bridges stay occasional.
- **Never two ladders in a row.** One long ladder instead, with shelves stepping off to the sides
  at even spacing, so a cat can get off partway. A ladder may be followed by a gangway or another
  kind. (This replaces "ladders may chain".)
- **In the air.** A piece not standing on the floor or a post must visibly hang or mount: ropes up
  to the top edge (a swing, a slung hammock, a hanging basket, a hoop, a long toy), a ledge with a
  knee brace into a page edge, a bracket on the wall. Perches and ledges must be reachable (a jump
  of ≤ 50 up and ≤ 60 across from a landing, or a bridge). Only toys may hang anywhere.
- **Motif: the bridge line** (occasional, when the gap is long enough): a long level rope bridge
  across the column or the space under the text; a ladder rises from below to one end, and a
  ladder rises from the other end to the next level.

## 0. The idea

One **main route** from the floor to one **lookout**. A connector exists only as a segment of that
route or as the one link of a short branch to a destination; a **series** (steps, dots, pegs, zigzag
shelves) is made as one module with one pitch; everything else is attached to a landing or a post
by a port and is a dead end. The planner builds *data* (landings, edges, supports, leaves) from
`layout` alone, validates it, then draws; each piece forks `rng` in plan order, so the animation
contract holds and a change inside a piece moves nothing.

## 1. Data model

```
Landing  { id, kind, x0, x1, y, zone, job, mount, ends = { outer = edge|nil, inner = edge|nil },
           edges = {}, cushion, free = {x0, x1} }        -- a standing surface
Edge     { id, a, b, kind, p0 = {x, y}, p1 = {x, y}, n, pitch, elt, angle, stones = {},
           solid = {rects}, clear = {rects}, series = id|nil }   -- one move between two landings
Support  { id, kind = post|base|beam|bracket|box, x, y0, y1, d, bands = {}, carries = {ids} }
Leaf     { id, kind, job, host = landing|post|box, side, x, y, w, h, link = edge|nil }
Toy      { kind = ball|pompoms, host, x, y, L, swing }
Field    solid rects + clear rects, each tagged with its owner; fits(rect, exempt = {ids})
```

- `Landing.kind` ∈ floor, base, platform, pad, shelf, moon, hexfloor, boxtop, bridgehead.
  `job` ∈ hub (tower platform, ≥ 3 edges allowed), route, lookout, perch, bed, hide, pass (a hex
  the route walks through). `mount` ∈ wall, post:id, base, platform:id, box:id. `free` is the
  span not under any edge footprint: cats go there. `zone` ∈ floor (y < 150), wall (150–400),
  top (≥ 400).
- `Edge.kind` ∈ jump, ladder, climb (D-pole), steps, dots, pegs, stairs (gangway), ramp, bridge,
  run (zigzag shelves), hexpass. `stones` are the repeated elements of a series (each a tiny
  standing surface with its own clearance, exempt from the clearances of the same series).
  `p0` is a point on `a`'s edge, `p1` a point on `b`'s edge. Edges are undirected for
  reachability; `angle` is measured from `p0` to `p1`.
- `Leaf.kind` ∈ hammock, bowl, armbowl, bubble, condo, hex, ring, tube, wave, pad, moon(perch).
  A leaf with a standing top (condo, hex, moon) also registers a Landing with `job = hide|perch`.
- Every solid has a rect in `Field.solid`; every Landing and every stone has a clearance rect in
  `Field.clear`: width max(span, 45) centered on the surface (30 for stones), height 30
  (hammock, bowl, bubble: their own cavity). Cats are drawn inside clearances, never anywhere else.

## 2. Rules (H = hard, rejects; S = soft, scored)

**R1 Reachability (H).** The graph (landings, edges) is connected from `floor`. Every leaf is
either attached (bowl on a platform, hammock under it, box on a bracket by a shelf end within a
jump) or has exactly one `link` edge.

**R2 Purpose (H).** Every piece carries a `job`; a connector's `a` and `b` are landings; a series'
first and last stone are one `pitch` from `p0` and `p1`. A post exists only as a tower member, a
`climb` edge, or a scratcher (height 60–90, foot on floor/base, next to a route start or a bed).

**R3 Connector by vector (H).** With `rise = y_b − y_a` (≥ 0 on the main route) and `gap` the
horizontal distance between the nearest edges of `a` and `b`:

| rise | gap / angle | connector | geometry |
|---|---|---|---|
| ≤ 50 | gap ≤ 60 | jump | nothing drawn; counts in R9 |
| ≤ 0.27·gap | 55–220 (column), 80–300 (spill) | bridge | both ends y ≥ 100 and of kind shelf/moon/platform/boxtop; sag 10–18 %; ≤ 15° |
| 30–80 | 20–35° | ramp | from a tower platform or the base only; board 70–150 |
| 40–120 | 25–45° | stairs | board with step blocks every 20; n ≥ 3 blocks |
| 40–150 | 30–50° | steps | boards 22, stride 18/20/22; n ≥ 3 |
| 40–150 | 30–50° | dots | pucks 12, stride 22; n ≥ 3 |
| 30–120 | 20–40° | pegs | pegs 10, stride 30; n ≥ 3 (image 12) |
| 50–150 | vertical, x-overlap ≥ 26 | ladder | at `b`'s near end, flat on the wall, rungs every 15; foot on `a` (or the base), top at `b`'s underside or edge |
| 60–200 | vertical | climb | sisal pole, half-steps every 30 on its free side, foot on base/platform; `b`'s end sits on the pole top |
| 75–180 | 3–6 shelves | run | identical shelves w ∈ {35, 40}, rise ∈ {25, 30}, alternating columns 10 apart (width 2w + 10) |
| 52 | 0–60 sideways | hexpass | a hex ^ cluster entered low, left high (R8) |

Anything else (rise > 50 with no series, a slant steeper than 50° that is not a ladder/climb,
a bridge below 100 or from a stone) is invalid: the planner moves `b` or picks another kind.

**R4 Rhythm (H).** A series has one `pitch`, one `elt` size, n ≥ 3 (a run: ≥ 3 shelves), chosen
once from its kind's set and never changed to make it fit; if it does not fit, n shrinks (not
below 3) or the module is replaced. Different series on a page may differ. (S) At most two
slanted-series kinds on one page (steps and pegs, say), never steps, dots and pegs all together.

**R5 Exclusivity (H).** One edge per pair of landings. No two upward edges whose y-ranges overlap
by > 30 and whose x-ranges come within 60 of each other, unless one of them leaves a hub. A post
above the tower's top platform must be a `climb` edge. A tower post may run through platforms as
support; it is never drawn beside a series it duplicates.

**R6 Geometry (H).** Ladders and climbs are vertical (angle 90° ± 0). Steps, dots, pegs, stairs
are 20–50° from horizontal (table), never vertical, never horizontal (level is a jump, a shelf
or a bridge). A bridge is level ± 15°. Nothing passes through anything (no ladder through a
bubble, no cord through a landing).

**R7 Clearance (H).** `Field.clear` rects contain no solid except: the two edges of that landing
(and a series' own stones among themselves); a landing's own cushion; a cat. Landing solids are
pairwise disjoint with a 10 margin; a landing's underside keeps 20 free unless a toy or hammock
is hung there on purpose. A bridge's clearance is deck→deck + 35 along its sag.

**R8 Support and stacking (H).** Wall-mounted kinds (shelf, moon, steps, dots, pegs, stairs,
ladder, hex, bubble, condo-on-bracket, bridgehead) need nothing. Platform, pad, bowl, tube, ring,
condo, pompoms stand on a post top, a platform or the base (contact). Hammock: between two
existing posts, or under a platform spanning two posts. Armbowl: a post side. A box attached to
the side of another box needs no support. Stacks: 2 side by side; rarely (p = 0.15) 3 as an L or
a ^ (two below, one on top, centered or flush); never 3 straight up, never 4; boxes in a stack
touch. Two boxes 40–100 apart at the same bottom (± 15), both ≥ 100 up, may get a small rope
bridge door to door (counts as the page's bridge, R11). Bowls: at most one per post top, two on
a tower only on different posts.

**R9 Jump budget (H limits, S budget).** A jump is ≤ 50 up and ≤ 60 across. Main route: ≤ 2
jumps, never two in a row. Each leaf chain: ≤ 1. The steps inside a series are not jumps.

**R10 Zoning (H for the first three, S for the rest).** The lookout is the unique highest
landing (y ≥ 400, cushion, w ≥ 40). Scratchers: foot at y = 0 or the base top; sisal bands on
tower posts 20–60 above each landing a cat stands on. Nothing is drawn above the lookout.
Hides (condo, hex with a cushion) y ≤ 250 for condos, ≤ 350 for hexes. Beds 80–380. Bubbles
150–350, reached by a jump only. Toys hang from the underside of a landing beside a bed or from
a bridgehead, cord 20–30, swing radius 10, outside every clearance and footprint. Wave lounger,
base, floor condo: y = 0.

**R11 Bridges (H).** At most one in the column (W ≥ 120 only: moon 30 + gap ≥ 55 + moon 30) and
one in the spill. Never at ground level. Ends are landings of the same kind or shelf/box.

**R12 Composition (S, scored; the planner keeps the best of its attempts).** The route's top is
≥ 0.8·H. Modules on the route: n_mod = round(D·4) clamped to 2–5. Consecutive route landings
switch side ≥ 60 % of the time (the route zigzags, leaving pockets). Pockets (the side opposite
a module, at its height) hold ≤ 1 leaf of width ≤ W − module width − 10. No empty rectangle
larger than 100 × 120 in the wall zone that touches the route (a leaf or a perch goes there if a
job is still open, otherwise it stays empty: never a squeezed module). Heavy at the floor:
≥ 50 % of solid area below 150. Density D: D < 0.5 drops leaves beyond the tower's, D < 0.3 is
the tower alone with a single ladder stack to a low lookout.

## 3. Generation procedure (every draw from `layout`, in this order)

Deterministic: candidate lists are sorted by weight and sampled without replacement with
`layout`; each attempt forks `layout` once, so a failed attempt consumes a fixed number of draws.

**Stage 0, setup.** W, H from the column; zones; D; `Field` with the column, footer and spill as
rooms. Decide the page shape: `last` (spill ≥ 150 tall) or not. Reserve the head mark cats.

**Stage 1, tower (floor zone, 0–150).** Pick a template with weights: `L` (tall post outer, low
post inner, shared platform at the low post's top, 0.4), `U` (two posts, one platform across,
the hammock under it, 0.35), `trunk` (one 12 cm post, pads alternating sides at pitch 45–50:
a series, 0.25; image 4). Levels 50–60; 2–3 levels; base 60–110 wide in the corner. Place the
tower's condo (hide) on the base or a platform, a bowl or tube on a post top, sisal bands at
standing heights. Output: landings (base top, platforms, pads, condo top), posts, and the **exit
landing**: the highest platform, its free end chosen toward the opposite side.

**Stage 2, lookout target.** y_look = H − (40..70); its side = the side the route would reach
after an odd/even count of switches (computed after stage 3; it is only the *height* that is
fixed now). R = y_look − y_exit (≈ 280–380).

**Stage 3, route modules (module-driven growth with lookahead).** From the current landing
`cur` with remaining rise `rem`:
1. Candidates: every edge kind in R3 that can realize a rise r with `rem − r = 0` (finish) or
   `rem − r ≥ 60` (room for one more), with weights by zone: leaving the tower: ramp 3, stairs 3,
   steps 3, run 3, ladder 2, climb 1, pegs 2; in the wall zone: steps 3, run 3, ladder 3,
   pegs 2, dots 1, hexpass 1, climb 1, bridge 1 (when W ≥ 120 and `rem ≥ 60` after it, rise 0);
   last module: steps 2, run 2, ladder 3 (the stack ends on a moon).
2. For the chosen kind: choose the next side (opposite with p = 0.7; same side only for ladder,
   climb, run), the pitch from the kind's set, n from the geometry; compute `b` (kind: shelf 40,
   moon 35–45, hexfloor; the last one is the lookout, moon or cushioned shelf). Build the edge's
   solids and clearances.
3. `Field.fits` for all of it (solids against solids and foreign clearances, clearances against
   solids, exempt its own ids and `cur`'s). On failure: n − 1 (≥ 3), then the other side, then the
   next candidate; after 6 failures backtrack one module (depth ≤ 3); if that fails, lower
   y_look by 60 and retry once.
4. Repeat until `rem = 0`. Fallback that always fits (26 wide): a **ladder stack**, shelf 40,
   ladder 70–90, shelf on the other side, ... to the lookout.

**Stage 4, branches (leaves with a job).** Walk the open jobs in this order, each at most once
unless room remains: bed (wall zone), hide (low; skipped if the tower has a condo and D < 0.8),
perch, second bed, second hide (hex, preferably `hexpass` on the route), bubble. For each, the
host candidates are the route landings' free ends and pockets, the tower's posts and
platforms, in order of the largest pocket. Attach by the cheapest valid link: attachment (bowl
on a platform, hammock under a platform between posts, armbowl on a post side, condo on a
bracket flush with a shelf end), then a jump (R9), then 3 pegs/dots sideways (20–40°), then a
small door-to-door bridge (boxes, R8). A leaf whose link fails is dropped, not moved far.
Stacks: a condo placed by a shelf end may take a second box at its side (p = 0.4) and rarely a
third as an L/^ (R8).

**Stage 5, dressing.** A scratching post at the route's foot (the base's outer corner, h 60–80)
unless a tower post with bands is within 60. A tube on the post top the route crosses (the
run or steps pass over it). A ring on a post top only when a landing lies beyond it within a
jump. One ball under a landing beside a bed, or under a bridgehead; pompoms on the tower's top
platform only if no route leaves it. Cushions on beds, hides with a floor, and the lookout;
bare boards elsewhere. Count toys ≤ 2, scratchers ≤ 2.

**Stage 6, footer and spill.** Footer band: floor pieces only, standing on y = 0, 2–3 pieces
20–60 apart (wave, bowl, low condo, scratcher), no connectors, no bridge. Spill on a last page:
from the exit landing or the first wall landing (y 100–160) a bridge (R3, gap 80–300) to a
shelf; then one sideways module (steps or pegs at 20–30°, or a hexpass) ending at a bed or a
hex with a cushion; a condo on the floor below. A spill shorter than 150: the footer row
continues under the text instead.

**Stage 7, validate and score.** Run section 5; keep the plan if it passes, otherwise take the
next attempt (≤ 3 attempts, each from a fresh fork of `layout`), then the fallback (tower +
ladder stack + lookout), which passes by construction.

**Stage 8, cats** (visitor stream `seed·7919+103`, after the plan is final). n = 1, plus one
with p = 0.45; heading cats count toward the cap of 2. First cat: lookout (sit) 0.5, a bed
(curl) 0.3, walking on a bridge or steps 0.2. Second: a different job and module, ≥ 100 apart;
peek from a hole if a hide exists and no cat is in one. A cat needs `free` ≥ 45 (loaf, drape)
or ≥ 30 (sit) on its landing, and stands inside the clearance.

## 4. Motif catalogue (modules with their own rules)

1. **Zigzag shelf run** (the narrow-wall climber). 3–6 identical shelves, w 35/40, rise 25/30,
   two columns 10 apart, alternating; first shelf one step above `a`, `b` one step above the
   last. Width 2w + 10. No leaf in its own width; a pocket beside it fits a bubble or condo.
2. **Floating steps diagonal** (image 15). 4–8 boards of 22 at stride 18–22, 30–50°, from a
   shelf end to a moon. Lighter than stairs; the top zone's favorite. Dots are the same motif
   with pucks of 12 at stride 22, used at most once per page.
3. **Peg traverse** (image 12). 3–5 sisal pegs at stride 30, 20–40°, shelf end to shelf end,
   crossing the column; a cat walks it. Never vertical, never from a stone.
4. **Ladder stack** (rule 9). Shelf, ladder, shelf on the other side, ladder...; rise 60–90 per
   ladder, shelves 40, ladder flat on the wall at the upper shelf's near end, foot on the lower
   shelf. A ladder may end at a hex's edge or a condo's bracket underside. The all-weather
   fallback: fits any column ≥ 60 wide.
5. **Gangway off the tower** (images 5, 18). Stairs 25–45° (or a sisal ramp ≤ 35°) from the tower's
   top platform to the first wall shelf, 70–150 long, ≥ 3 step blocks; the only slanted board
   allowed from a platform.
6. **D-pole climb**. A sisal pole with half-steps on its free side from a platform or the base
   to a shelf 60–200 above whose end sits on the pole; a tube on the pole top when the route
   crosses it. No other upward edge within 60 of it (R5).
7. **Honeycomb pass-through** (image 10). Two hexes side by side (exit the far one) or three as
   a ^: the route enters the low outer hole and leaves the top hex's upper hole, a rise of 52;
   one cell has a cushion (a bed or hide). Wall zone only, w 60 flat-to-flat 52.
8. **Box cluster with a rope bridge** (rule 8). A condo on a bracket flush with a shelf end
   (hide, its top a perch); a second condo or hex 40–100 away at the same bottom, a small
   bridge door to door; the far box is a dead end. Uses the page's one column bridge.
9. **Bed branch**. A hammock under a two-post platform, or an armbowl off a post side at 80–130,
   or a bowl on a post top; a ball on a 25 cord from the platform's underside beside it, outside
   every clearance.
10. **Bubble lounge**. A bubble on the wall 30–50 beside or above a route shelf, reached by one
    jump (≤ 50 up, ≤ 60 across), 150–350 up; a dead end; a cat inside, seen from below.
11. **Lookout crown**. The last module ends on a moon 45 (or a cushioned shelf) at H − 40..70;
    cushion; nothing above; a toy below it only if no landing lies within 60 below; the first
    cat sits here. No tapering dots above it (they would go up into nothing).
12. **Mushroom trunk** (image 4, tower variant). One 12 cm post, pads of 40 alternating sides at
    pitch 45–50 (a series: one pitch), holes in the trunk as hides; the top pad is the exit.

## 5. Validation checklist (run on the finished plan; any H failure rejects the page)

| # | check | catches |
|---|---|---|
| V1 | every landing reachable from `floor` through edges; every leaf attached or linked | shelves stacked with nothing joining them; bowls on a post with no way up |
| V2 | every edge has landings at both ends; every series' first/last stone is one pitch from `p0`/`p1`; every piece has a job | steps, pegs, ladders ending in mid-air; stray blocks |
| V3 | every series has n ≥ 3 and one pitch, one element size (± 1 cm) | one-step gangway; runs of mixed shelf sizes and spacing |
| V4 | no landing pair joined twice; no two upward edges with overlapping y-range within 60 horizontally (hubs excepted); every post above the tower's top platform is a `climb` edge | a pole beside a shelf run doing the same job |
| V5 | ladders and climbs vertical; steps/dots/pegs/stairs/ramp within their angle ranges; bridge ≤ 15°, both ends ≥ 100, not from a stone | tilted ladders; pegs going straight up; ground-level or slanted bridges |
| V6 | landing solids pairwise disjoint (margin 10); no foreign solid in any clearance; toys outside all clearances and footprints; nothing passes through anything | overlapping walking platforms; a ball in a path; a ladder through a bubble |
| V7 | every non-wall piece has a support in contact; stacks are 2, or 3 as L/^; no 3 straight up | floating boxes; towers of bowls |
| V8 | jumps ≤ 50 up / ≤ 60 across; ≤ 2 on the main route, none consecutive; ≤ 1 per leaf chain | gyms held together by leaps |
| V9 | exactly one lookout, the highest landing, cushioned; nothing above it; hides/beds/bubbles/scratchers in their height bands | a hex perched above the lookout; a scratcher in the air |
| V10 | ≤ 1 bridge in the column and ≤ 1 in the spill; ≤ 2 toys; ≤ 2 scratchers; ≤ 2 slanted-series kinds | clutter of the same trick |
| V11 | cats ≤ 2 including heading cats, each on a different module, inside a clearance with `free` ≥ 30 | too many cats; a cat under a ladder |
| V12 | route top ≥ 0.8·H (D ≥ 0.5); ≥ 50 % of solid area below 150; no empty 100 × 120 rect touching the route in the wall zone (soft, scored) | half-empty columns; top-heavy pages |

Debug output: `stats = { modules = {kinds}, leaves, jumps, bridges, cats, score, attempts }`,
and in the explained animation a dashed rect per clearance and a dot per `p0`/`p1`.

## 6. Numbers in one place

cat 45 × 20 lying / 30 sitting; clearance 45 × 30 (stone 30 × 30); post 9 (12 heavy), level 50–60;
shelf 35/40/45 × 3.5; moon 30–45; pad 40; base 60–110 × 5; puck 24 / dot 12 / peg 10; strides:
steps 18–22, dots 22, pegs 30, stairs blocks 20; ladder 26 wide, rungs 15, rise 50–150; climb rise
60–200, half-steps 30; run rise 25/30, shelves 35/40, columns 10 apart; jump ≤ 50 up, ≤ 60
across; bridge gap 55–220 (column) / 80–300 (spill), ≤ 15°, ends ≥ 100, sag 10–18 %; hex 60 across
corners (52 flat), rise 52 in a ^; bubble 36–44; bowl 30–40; condo 42 × 36, hole 20; toy cord
20–30, swing 10; zones 0–150 / 150–400 / 400+; lookout H − 40..70; modules 2–5 (round(4D)).

## 7. Where the brief is thin or contradicts itself

- The old "sparse top ending in a tapering line of dots" (zone rule 3) breaks rule 11 (steps go
  somewhere). This system drops it: the lookout ends the page.
- "Pegs, dots: sideways only" cannot be literal in a 120 cm column: a sideways chain hits the edge
  after three pegs. They are slanted 20–50° here, which the user's later note allows.
- Rule 5 ("busy levels have two ways in or out") is satisfied automatically by a single route
  (in and out); only hubs get a third. No extra parallel ways are added to satisfy it, since
  they would collide with rule 2.
- A rope bridge in the column fits only at W ≥ 120 with 30 cm moons as ends; otherwise the
  bridge is the spill's connector. Small door-to-door bridges between boxes are the usual way to
  see one on an ordinary page.
- Left open by the brief: whether the main route may descend (here: monotone up; only leaves hang
  below their host); whether heading cats count toward "1–2 cats" (here: yes); what fills a
  spill shorter than 150 (here: the footer row of floor pieces).

# Cat trees in the margin: plan

A new florilegium theme. The same Delft-blue ink, but the margin grows a cat gym instead of a
plant: posts, shelves, bridges, hammocks, condos, toys. Cats come later, once the structure is
good enough to hold them.

Status (2026-11-03): a working theme. `theme=cattree` draws the margin through `page(g, grow)`:
the zone grammar (a denser floor tower: up to five posts, shared platforms, side perches, baskets on
arms; the wall; the sparse top), sideways rows into the space under the text on the last page, a
row of floor pieces along the footer, grow.lua's free-space fill (largest hole first, joined by a
chain a cat could climb), and ink cats where they fit. `\florilegiuminitial` on a cattree page puts
a cat on the letter (initial.lua's `decorate` hook; the flower initial is byte-identical). The
playground offers "a cat gym". Previews: `lua5.4 svg.lua --theme cattree --seed N`, the sheets
from `tools/cattree/specimen.lua`. Not yet run under LuaLaTeX (no TeX on this machine), no growth
animation (everything appears at once). Since then: connectors chosen by slope (steps level; dots, pegs, gangway stairs, ramps on a
slant; vertical ladders, D-step poles or a jump going up), a denser tower (extra platforms,
more perches), density thinning to the tower alone, one or two cats a page, cats at headings,
the growth animation (`tools/cattree/animate.lua`, `gallery/cattree-grow.gif`). Cats (phase 5, first real pass): outlined poses loaf, sit,
curl, walk, drape, peek; coats solid, blue, tabby, tux, pale; copper eyes with slits, whiskers when
large; sheet `build/cattree/cats.svg`. Initials put a cat curled in the letter's counter (O, D, P...)
or on top of the letter, scaled to stay inside the frame.

---

## Ground rules

- **Same brush, new subject.** Everything is drawn with `ink.lua` as it is: the OKLCH cobalt
  ramp, wash and `mottle`, white streaks clipped inside shapes, almost no outlines, copper only
  for fine accents. No new colors.
- **Flat elevation view.** We draw it like a wall diagram, not a product photo. Platforms
  get at most a thin top face, and boxes are rectangles. No real perspective.
- **Plausible, not physically correct.** Pieces have to connect horizontally and vertically,
  join each other, and come in several sizes. No load calculations.
- **Structure first, cats later.** Pieces mark the places where cats could go (cat spots) as
  they're built, so cats can be added without reworking the layout.
- **No plants in the first version.** Planters (images 7 and 8) can reuse `flora` later.
- **References are vocabulary, not models.** We take the kinds of parts (sisal bands, rope
  bridges, pucks, hex modules) from them, not any one product's design. The photos stay out
  of the repo.

### References (shared in chat, 2026-11-03; saved as `scratch/cattree-refs/N.png`, git-ignored)

| # | what | family | take from it |
|---|---|---|---|
| 1 | tall plush tower, condos, basket, fenced shelves | A tower | sisal bands on dark posts, condo with arched door, rope post, ball on cord |
| 2 | curving sisal trunk with woven cups | B tree | one curving trunk, branches ending in cups, pom-poms hanging |
| 3 | twin "palace" towers | A tower | condos with round and oval holes, hammock bowls, short ladder, rope |
| 4 | tree-trunk column with mushroom pads | B tree | pads stepping up a single trunk, holes in the trunk |
| 5 | big multi-post tower | A tower | hammocks, sisal ramps, many shelves, pom-poms on wire |
| 6 | three stacked carpet bowls | A tower | offset bowls on short posts, small sisal post at the base |
| 7 | wall system (**preferred**) | C wall | orthogonal shelf route, rope bridge, stepped diagonal ladder, round step pucks, sisal post |
| 8 | same as 7, in a room | C wall | confirms 7 |
| 9 | two castle towers joined by a bridge | C wall | tower + long bridge, a page layout idea (column + footer) |
| 10 | hexagon wall modules | C wall | modules that tile, round cut-outs |
| 11 | wall walkways and half-moon shelves | C wall | half-moon shelves on brackets, sagging slatted bridges |
| 12 | cat wall with pegs | C wall | sisal pegs sticking out of the wall, a sagging rope bridge |
| 13 | room-sized gym, ceiling shelf | A + C | long lateral shelves on brackets, a box at the ceiling, wall hex |
| 14 | spiral ramp, wall steps on a post | C wall | a spiral of steps round a post (not drawn yet) |
| 15 | floating stairs | C wall | many thin boards on a diagonal, half-moons at the ends |
| 16 | ceiling walkway | C wall | slatted bridges between open box frames |
| 17 | big symmetric tower | A tower | shared platforms, bubbles, hammock between posts, sisal tubes on post tops |
| 18 | towers with rings | A tower | plush rings on posts to climb through |

---

## How it maps onto the existing code

| florilegium today | cat-tree theme |
|---|---|
| `flora.lua` primitives (`flower`, `leaf`, …) | piece primitives (`post`, `shelf`, `bridge`, …) with **ports** |
| motif table in `grow.lua` (`r(s)`, `off(s)`, `w`, `max`) | piece table: size rules, ports, weights, caps |
| stems grown from a root | **skeleton**: a route (wall) or a set of posts (tower) |
| branch loop (largest free cell near a stem) | **assembly loop** (open port with free space nearby) |
| free-space grid `grow.field` | reused as is |
| regions (margin column, footer band, spill) | reused as is |
| visitors (snail on a stem, bird on a twig) | later: cats at **cat spots** |
| theme with `page(g, grow)` (`theme-math.lua`) | `theme-cattree.lua`, a composition of its own |

### Scale and real sizes

Decided 2026-11-03: everything is drawn at **1:20** (1 cm on the page = 20 cm), from real
sizes in centimeters (`M.DIM` in `theme-cattree.lua`; this table is the same). Every
preview carries a 0–50 cm scale bar and a gray reference cat (about 45 cm long); sheet 3
places reference cats where cats would go, to check that they fit.

| piece | real size |
|---|---|
| cat (body, no tail) | 45 cm long; 20 cm high lying, 30 cm sitting |
| post | 9 cm thick (12 cm for a heavy one), 50–70 cm between levels |
| shelf | 3.5 cm thick, 35–70 cm long |
| round pad | 30–50 cm across |
| base slab | 5 cm thick, 60–110 cm long |
| wall puck | 24 cm across, about 30 cm apart |
| stairs / ladder | a step every 20 cm; ladder 26 cm wide, a rung every 15 cm |
| rope bridge | hand rope 25 cm above the deck; only between raised points, level or sloped |
| condo | 42 × 36 cm, holes about 20 cm |
| hex module | 60 cm across |
| space bubble | 36–44 cm across |
| bowl / basket | 30–40 cm across |
| curved lounger | 40–50 cm wide, 15–20 cm deep |
| ball / pom-pom | 5 cm, on a 20–30 cm cord |

Rules learned from the first sheets: no rope bridge at ground level (ladders are fine there);
nothing passes through anything else (no ladder through a bubble).

### Variation model: how it differs from the flowers

Flowers vary by **scale** (a flower 0.75–1.3×, a sprig 1.2–2.8×). Cat furniture is sized to the
cat, so scaling a whole piece looks wrong. Instead:

- **Cat unit `u` per page**, from the margin width. All dimensions are multiples of `u`.
- **Fixed cross-sections**: shelf thickness, post diameter and step size come from 2–3
  standard sizes, like a modular kit.
- **Free lengths**: shelf runs, post heights, bridge spans and ramp lengths stretch to fit.
- **Discrete choices**: number of steps, hole shape, band pattern, cushion or not, bracket
  style, round or square pad.
- **Small wobble**: plush lumps, rope sag, unevenly wound sisal. This keeps the hand-drawn feel.
- **Layout carries most of the variety**: the route, which connector each gap gets, and
  where the pieces go.

---

## Phase 1: Specimen sheet (pieces only)

Goal: every piece drawn in ink, varied, on one labeled page, ready for critique.

### 1.1 Setup
- [ ] Branch `cattree`.
- [ ] `theme-cattree.lua` with a `flora`-style table of piece primitives (frame: origin at
      the base or attachment point, +y up, takes `rng`, sizes in `u`).
- [ ] `specimen-cattree.tex`: a grid where rows = pieces and columns = seeds/sizes, each cell
      labeled (`A1`, `C3`, …), with a cat-unit ruler.
- [ ] Makefile target, PNG in `gallery/specimen-cattree.png`.

### 1.2 Material treatments (shared helpers)
- [ ] **Plush**: tone wash + `mottle`, soft dark rim, no hard outline.
- [ ] **Sisal**: white wound lines (short diagonal streaks) over a light tone, with a darker edge
      on one side for roundness.
- [ ] **Sisal bands**: alternating plush/sisal segments (images 1 and 5); patterns: none, one, several,
      full.
- [ ] **Wood/brackets**: copper hairline outline and end caps (image 7's brown trim).
- [ ] **Rope/cord**: copper twisted hairline (two interleaved strokes).
- [ ] **Weave**: short crossing streaks for baskets and cups.
- [ ] **Cushion**: pale lumpy blob on top of a surface.

### 1.3 Pieces
Each piece lists its **ports** (where others attach) and **cat spots** (for later).

- [ ] **A. Posts**
  - [ ] A1 plain plush post
  - [ ] A2 sisal-banded post (band patterns)
  - [ ] A3 full sisal post
  - [ ] A4 rope-wrapped post
  - ports: top, sides at any height, bottom · cat spots: scratching (side)
- [ ] **B. Shelves and perches**
  - [ ] B1 plain shelf
  - [ ] B2 shelf with copper end brackets (image 7)
  - [ ] B3 cushioned perch
  - [ ] B4 round pad / mushroom pad (image 4)
  - [ ] B5 fenced shelf with railings (image 1)
  - ports: both ends, underside, top surface · cat spots: lounging, sitting, edge drape
- [ ] **C. Connectors**
  - [ ] C1 step pucks (round wall discs, image 7)
  - [ ] C2 stepped diagonal ladder (image 7), several angles
  - [ ] C3 rope bridge with catenary sag and slats, several spans (images 7, 9)
  - [ ] C4 sisal ramp (image 5)
  - [ ] C5 short ladder with rungs (image 3)
  - ports: two ends · cat spots: walking, crossing
- [ ] **D. Enclosures**
  - [ ] D1 condo cube; holes round, oval, arched; one or two holes
  - [ ] D2 hex module with round cut-outs (image 10); tiles with its neighbors
  - [ ] D3 space bubble (pale wash dome, white highlight arc, darker rim)
  - [ ] D4 castle tower segment with arched windows (image 9), optional
  - ports: top, bottom, sides · cat spots: peeking from a hole, inside
- [ ] **E. Loungers**
  - [ ] E1 bowl / basket (images 2, 6; woven or plush)
  - [ ] E2 hammock slung between two posts
  - [ ] E3 curved x = y² lounger / wave scratcher (cardboard edge striations)
  - [ ] E4 hammock bowl on a single arm (images 3, 5)
  - ports: mount point(s) · cat spots: curled up, lounging
- [ ] **F. Toys**
  - [ ] F1 ball on a cord (hangs straight down)
  - [ ] F2 pom-pom cluster on wires (image 5)
  - [ ] F3 small mouse/charm on a string (image 4), optional
  - ports: one hanging point · cat spots: batting (beside or below)
- [ ] **G. Bases**
  - [ ] G1 floor slab
  - [ ] G2 wall rail / mounting strip (for the wall family)

### 1.4 Critique loop
- [ ] I render at 300 dpi and check crops before sharing.
- [ ] You critique by cell (`C3: sag too deep`); I revise; repeat.
- [ ] Measure bytes per piece (`tools/bytes.lua`); keep within the size budget.

**Done when:** every row reads as what it is at margin size, and the ink matches the flowers.

---

## Phase 2: Connection system (ports)

Goal: pieces join cleanly in code, before any automatic layout.

### 2.1 Port model
- [ ] A port is `{ x, y, dir, kind }`, where `kind` ∈ `top`, `end`, `side`, `under`, `hang`, `mount`.
- [ ] Each primitive returns its ports in layout coordinates (or a function that computes them).
- [ ] Compatibility table: which kinds attach to which (shelf `end` ↔ post `side`, toy `hang`
      → shelf `under`, connector ends ↔ shelf ends / pucks).

### 2.2 Joints
- [ ] Shelf-to-post: shelf butts the post, with a small bracket.
- [ ] Post on shelf / post through a condo: the post stops at the surface.
- [ ] Bridge/ladder ends: copper caps lined up with the shelf surface.
- [ ] Hex modules sharing an edge.

### 2.3 Hand-built test page
- [ ] A small authored assembly (like `authored.lua`): pieces placed by hand and joined by
      ports, to prove the joints look right before anything is automatic.

**Done when:** a hand-placed gym looks like one connected object.

---

## Phase 3: Assembly (procedural layout)

Goal: each page builds its own gym in the margin.

### 3.1 Family C: wall route (first)
- [ ] **Route**: a path of horizontal runs and vertical risers through the margin column,
      from bottom to top, drawn from `layout`.
- [ ] **Gap rule**, a connector chosen by the shape of the gap:
  - short vertical → step pucks
  - diagonal → stepped ladder
  - long horizontal → rope bridge
  - tall run → sisal post with a perch
- [ ] **Extras** on the free ports: hammocks, condos, hex clusters, toys hanging from undersides.
- [ ] **Footer band**: a bridge or shelf run along the bottom (image 9's idea), with a hex cluster at
      the end.
- [ ] **Spill** (last page): the route continues under the text.

### 3.2 Assembly loop (shared by all families)
- [ ] Reuse `grow.field` / free-space grid and `grow.regions`.
- [ ] Repeat: pick the open port with the most free space nearby → pick a piece by weight and
      cap (compatible kinds only) → fit its **length** to the space (fixed cross-section) →
      place it, mark its space taken, add its ports.
- [ ] Stop when no piece fits.
- [ ] Layers: wall rail / back pieces, posts, shelves, connectors, enclosures, toys, accents.

### 3.3 Family A: post-and-platform tower
- [ ] Base slab in the bottom corner; 2–4 posts at staggered heights.
- [ ] Shelves, condos and bowls at post/height intersections; ramps and ladders between levels.
- [ ] Reuses most of the Phase 1 pieces.

### 3.4 Family B: organic tree (optional, cheapest)
- [ ] Curving sisal trunk (the existing stem logic) with branches ending in cups and pads; pom-poms
      hanging.
- [ ] Close to a primitive swap on `grow.lua`.

### 3.5 Per-page variety
- [ ] The family is chosen from the seed (or forced by an option).
- [ ] Later: mixing families (tower in the column, wall route along the footer).

**Done when:** ten seeds give ten different gyms that all look connected and sensible.

---

## Phase 4: Integration with the package

- [ ] `\usepackage[grown,theme=cattree]{florilegium}` / `\florilegiumtheme{cattree}`.
- [ ] **Mirror** for right-hand margins (`g.mirror`; brackets and bridges flip correctly).
- [ ] **Density**: fewer extras, shorter route; at 1 the arithmetic is unchanged.
- [ ] **Intensity**: works automatically through `ink.set_pale`.
- [ ] **Animation**: posts grow up, shelves slide in, bridges unroll, toys swing in; follow the
      animation contract (draw only from `rng`/`layout`); add to `tools/animcheck.lua`.
- [ ] **SVG/playground**: add `theme-cattree.lua` to `MODULES` in `web/worker.js`; the colophon
      offers only the controls this theme uses; run `tools/playcheck`.
- [ ] **Docs**: README, CLAUDE.md file table, a gallery image; copyright line in the new `.lua`.
- [ ] **Byte identity**: unthemed pages unchanged (`tools/ident.lua` before/after).

---

## Phase 5: Cats (later)

- [ ] Cats are visitors on their own rng stream, placed only at cat spots.
- [ ] Poses by spot: loaf / sitting on perches, curled in bowls and hammocks, draped over shelf
      edges (tail hanging), peeking from condo holes, walking on bridges, batting at toys,
      scratching posts.
- [ ] Drawing approach: start with hand-shaped outlines with jitter, like `flora.bird`;
      possibly move to a spine-based body so a pose is a few parameters.
- [ ] Coat in the ink: tabby stripes as clipped streaks, pale belly, copper eyes/nose.
- [ ] Their own specimen sheet and critique loop before they go on pages.

---

## The zone rule (from the first generated pages)

Heavy at the bottom, lighter as it rises, like the flowers thinning toward the top:
1. the floor tower, about the lower third: posts in whole levels (about 50 cm), shared platforms
   at the lower post's top (the taller one runs on through), crossbeams, hammocks, condos,
   bowls; rings, tubes, pads or cushions on the post tops;
2. the wall: a board route (run, riser, run), a shallow rope bridge (at most 15 degrees, only
   between raised points) to a half-moon, hexes, a bubble;
3. the top, sparse: one or two small half-moons joined by floating steps, pegs or dots, ending
   in a tapering line of dots.
Cats go where they fit: lying on platforms and moons, sitting on tubes and in hexes, curled in
hammocks, bowls, rings and bubbles, walking across bridges.

## Design brief: intent (2026-11-04)

The first generator placed pieces wherever they fit and joined them afterwards; pages had
no intent (a climbing pole beside shelves doing the same job, shelf runs of mixed sizes,
things going up into nothing). The rewrite plans **traversal first**: a few landings, each
with a job, joined the way a cat would get between them, then the pieces dressed on.

### What each piece is for

- **Getting around.** Shelf run: a staircase of identical shelves (a cat's jump is regular:
  about 25–30 cm up, 30–40 cm across). Ladder, D-pole: straight up where there is no room to
  go sideways (ladder easy, pole agile). Ramp, gangway: the gentle slanted climb. Bridge:
  crossing a gap at height between zones, a landing at each end. Pegs, dots: stepping stones
  along the wall, sideways only. Hex with side holes: a pass-through, so it can sit on a route.
  Tube: a tunnel to walk through or hide in.
- **Resting.** Hammock, basket, bowl, bed: sleep spots, cradled, a little high (dead ends are
  fine). Platform, perch: sitting and watching. The top lookout: one per gym, the highest,
  with a cushion. Bubble: lounging, seen from below; a destination off the route.
- **Hiding.** Condos, cubes: low to middle, ideally two openings.
- **Scratching.** Sisal posts and the base posts, at stretching height near the floor and
  near sleep spots.
- **Playing.** Toys dangling under platforms near rest spots, never into a path. The ring:
  a toy and a climb-through.

### Rules

1. Every piece has a job (getting around, resting, hiding, scratching, playing, watching);
   a piece without one is not drawn.
2. Getting-around pieces join two landings; nothing goes up into nothing. One way per
   segment: no pole beside shelves doing the same job.
3. A series keeps its rhythm: the same size and the same step. Another series elsewhere on
   the page may have its own size and rhythm.
4. Jumps have limits: about 50 cm up, 60 cm across between standing surfaces; more than
   that needs a ladder, a pole or a bridge.
5. Busy levels have two ways in or out; only rest spots are dead ends.
6. Height follows function: scratching, play, loungers at the floor; hiding low; sleeping in
   the middle; the lookout at the top.
7. Every walkway and standing surface keeps cat-sized room above it (about 45 × 30 cm);
   nothing else may enter it.
8. Support by attachment: a piece needs its own post or bracket only if nothing it is
   attached to carries it. Boxes may join side to side (two condos, a condo and a hex, two
   hexes) on one post or none of their own; a box fixed to the side of another needs no pole.
   Stacks stay small: two side by side, or rarely three as an L or a ^ pyramid (two below, one
   on top). Never more. Boxes near each other at about the same height but not touching
   may be joined by a short rope bridge, door to door (a small one, scaled to the gap).
9. Never two ladders in a row: one long ladder with shelves stepping off to the sides at even
   spacing, then another kind of module if the route goes on. A ladder may run from one surface up to the *underside* of another (through a hole, or to
   its edge): it need not end on top of something.
10. Cats show the function: asleep in beds, sitting at the lookout, walking on a route.
11. Steps always go somewhere: every shelf run, peg or dot chain ends at a landing, a box or
   at least a perch. No series stops in mid-air.
12. Jumps are allowed, sparingly: an occasional gap within the limits of rule 4 instead of
   a connector, not as the usual way between landings.

### The same thinking, carried on (from "etc etc etc")

Small touches that follow from the rules, used now and then, never all at once:
- A hammock slung between two posts that already exist, or under a platform that already
  spans two posts, never on posts of its own.
- A toy hung from the underside of a landing next to a bed (a cat batting it from the bed),
  or from the end of a bridge, never in a route's clearance.
- A scratching post at the foot of the climb that starts a route, where a cat would stretch
  before going up; sisal bands on the posts at the heights cats stand on.
- A pass-through hex placed so a route goes in one hole and out the other.
- A bed or bowl at the end of a short branch off the route, so resting spots are dead ends
  and the route itself never is.
- The lookout at the very top, reached by the last module of the main route.
- A tube on a post top where a route crosses over the post, so the cat goes through it.
- A rope bridge's two ends on landings of the same kind (two shelves, two boxes, a shelf and
  a box), never from a peg or a step.
- Cushions in sleep spots and on the lookout; bare boards on walkways and steps.
- On a page with little room, fewer landings and the same rules, never a squeezed module.

### The planner (to build)

The full spec is `CATTREE-RULES.md` (data model, rules R1–R12 with numbers, the generation
procedure, twelve motifs, a validation checklist). Summary:

Landings at heights by function → modules between them under rules 2–4, 7, 9 → boxes and
destinations attached under rule 8 → toys, scratching, cats. Kept from the first generator:
the floor tower (L and U shapes), the cats, the ink, the animation contract and the checks.
Replaced: the wall zone, the sparse top and the largest-hole fill.

## The browser app (decided 2026-11-04, after more directions and toys)

A browser tool in its own folder in this repo (monorepo style, not a separate project): paste a
post, pick a size (4:5 for Instagram, a PDF page), **draw arbitrary bounding boxes for the text on
a page; Pretext lays the text out inside them, and what does not fit goes to the next page**. Each
text box becomes a keep-out for the gym (`o.keepout`). Export PNGs for a carousel, or a PDF.
React is fine; the Lua stays, in wasmoon in a worker. Also possible: text flowing around the gym.
Test PDF export early (blend modes).

## Where it stopped (2026-11-04)

The route planner (`plan_wall` in `M.compose`, spec in `CATTREE-RULES.md`) replaced the wall, top
and fill; uncommitted on top of commit e0de2ea. Works: routes end at a lookout, vertical ladders
with step-offs and never two in a row, D-poles, zigzag runs, slanted steps, bridges. Next: pages
are too sparse and the second route and cross-links rarely fit, so let routes climb beside and
through the tower (maybe a shorter tower), shorter modules, boxes that read as attached (redraw the
peek cat's paws too). The user also wants more toys and accoutrements on the pieces: dangling
balls, pom-poms and the like, in the dressing step. `CATDEBUG=1|2` prints rejection reasons. Then re-run animcheck and playcheck.

## Where it stopped earlier (2026-11-03, evening)

Stopped mid-session to free the laptop's CPU. Nothing is committed: everything is on branch
`cattree` in the working tree (`theme-cattree.lua`, `tools/cattree/`, `cattree.tex`,
`gallery/cattree*.{gif,png}`, edits to `florilegium.lua`, `initial.lua`, `svg.lua`, `Makefile`,
`README.md`, `CLAUDE.md`, `web/app.js`, `web/worker.js`, `tools/animcheck.lua`).

Last state, checked: `tools/animcheck.lua` passes (last frame = page, every theme incl. cattree);
`tools/playcheck` 52/52; the default flower initial is byte-identical.

The user's latest calls: keep 1:20 with the denser layout (not 30% smaller); one or two cats per
page; ladders vertical and flat against the wall; slanted links are steps, dots, pegs, gangway
stairs or ramps; going up is a ladder, a D-step pole, or nothing (a jump).

To do next:
- Look at a few seeds again after the 1–2 cats change (pages, last pages, mirrored, densities).
- Short stray pieces: check for leftover tiny ladders or poles that reach nothing.
- The initials still use the decorated cat every time; vary them (and check Latin Modern under TeX).
- Run under LuaLaTeX (no TeX on this machine): `make cattree.pdf`, `\florilegiuminitial`, headings
  with `sections`, `\florilegiumframe` animation. Needs Docker (`tools/in-docker`) or another machine.
- `tools/ident.lua` before/after to confirm unthemed pages are byte-identical (needs texlua).
- Commit when the user says so; then maybe a PR.
- Later: trees with cats in them (below).

Preview without TeX: `lua5.4 svg.lua --theme cattree --seed N [--textend 100mm]`, sheets from
`lua5.4 tools/cattree/specimen.lua`, frames from `tools/cattree/animate.lua` (then ffmpeg),
PNGs via `tools/cattree/render.sh` / `montage.sh` (headless Chrome). Lua 5.4 is
`/opt/homebrew/opt/lua@5.4/bin/lua5.4`; fontTools is in `scratch/venv`.

## Pieces shown regularly (done 2026-11-04, uncommitted)

Stairs, ramps, rings, condo variety and cats in bubbles now appear often; a walkway's foot may rest on its
start. The user loves the busy zigzag climbs (keep them), wanted far fewer railings (capped at one a page,
two on wide pages), and is fine with fewer hexagons. Count with a wrapper over `C.stairs` etc. across seeds.

## Pinned: old cats (2026-11-04)

`theme-oldcats.lua` (poses, genes, styles fur / wash / gesture, tools/oldcats/) is kept but paused. The
user finds the cats "chunky": every cat is built from tubes. The proposed fix, not started: trace 20-40
generated or hand-made drawings into silhouette and region curves as templates, and drive the styles from
those. Do not trace the reference artists' work (scratch/oldcats-refs).

## Later (not started)

- **Trees with cats in them** (started 2026-11-04, `theme-oak.lua`): one huge oak first, later the baobab and the
  paper birch copse were cancelled by the user (2026-11-04). Character over species
  accuracy; very verdant, layered foliage, things peeking from behind it.
  Green is the default, blue one setting away. So far: `M.skeleton` (space colonization, pipe model),
  `M.limb` (lit plates, knots, burls in the bark), `M.clump`, `M.nest`, `M.sprig`, `M.tree`;
  `lua5.4 tools/trees/oak.lua NAME W H SEED [green|blue]`. To do: file size (about 10 MB of drawing,
  bark about half), roots below the ground line, back foliage's blobby edge, cat contrast, keep-outs
  and the studio.
- **Studio exports:** images, SVG and PDF, with selectable text in the PDF if possible.
- **Vector PDF from the studio:** ink.lua already writes PDF operators, so the gym's streams could
  go straight into a page with pdf-lib (ExtGState for opacity and multiply) instead of images.
  Not tried.

## Open questions

- Repo: a theme here (gets the playground, seeds and animation for free; recommended) or a
  separate project?
- Should the wall family show the wall (a faint rail or shadow), or should pieces float on the
  page?
- How many standard sizes for cross-sections (2 or 3)?
- Should the footer always be a bridge, or vary with the family?
- Cat colors (later): all cobalt, or tabby, black and calico in tones of blue?

## Oak settings

`scene.page{ grows = "oak", ... }`: `crown` = lush | open; `season` = spring | summer | autumn | winter | dead (each with its own extras: pumpkins, bats and wind; icicles, robins, holly, snow piles and a snowman; crows and bats); `spanishmoss`; `swing = false`, `heart = false`, `extras = false`, `stumps = n`. A cut limb is drawn side-on, like everything else: a rolled collar and a sliver of the cut, never rings facing the viewer.

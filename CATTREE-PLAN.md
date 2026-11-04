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

## Where it stopped (2026-11-03, evening)

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

## Later (not started)

- **Trees with cats in them** (noted 2026-11-03): after the cat gym is done, a new project of the
  same kind as florilegium, but real trees: bark, branches, foliage, cats in the branches.

## Open questions

- Repo: a theme here (gets the playground, seeds and animation for free; recommended) or a
  separate project?
- Should the wall family show the wall (a faint rail or shadow), or should pieces float on the
  page?
- How many standard sizes for cross-sections (2 or 3)?
- Should the footer always be a bridge, or vary with the family?
- Cat colors (later): all cobalt, or tabby, black and calico in tones of blue?

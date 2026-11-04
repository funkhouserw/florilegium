# florilegium — handoff notes

Procedurally generated Delft-blue floral page margins for LuaLaTeX. All geometry is
computed in Lua and written as raw PDF path operators; TeX does no arithmetic. Two
documents share one package: an **authored** composition (hand-placed stems, leaves and
branch targets, parameters sampled) and a **grown** one (layout computed by a greedy
space-filling loop). Same primitives, same motif table. No images, no assets. The grown
margin also reads the text (flowers at headings and marked lines, seasons over the
document), pages get visitors, and paragraphs can open with a decorated initial;
`showcase.tex` demonstrates all of it. A theme swaps primitives by name
(`theme-geometric.lua`: the same plant cut from flat, straight-edged shapes) or replaces
the whole composition (`theme-math.lua`: figures, TeX symbols and equations cascading down
the margin and along the bottom, from `figures.lua`; `theme-cattree.lua`: a cat gym at 1:20, with cats); `density` (down to a single vine at
0.05) and `intensity` turn any margin down; `\florilegiumornament` sets one primitive in the text (issue #4). The garden grows in
the wider side margin, mirrored when that is the right one (two-sided documents);
`spread.tex` shows that and a theme. `svg.lua` draws the same page without TeX, as SVG (byte for
byte the same drawing as LuaLaTeX's), and `web/` runs it in the browser: the playground,
published to GitHub Pages.

## Files

| file | what |
|---|---|
| `florilegium.sty` | thin TeX layer: options `authored` (default) / `grown`, `nomargin`, `novisitors`, `sections`, `aging`, and key=value `theme=<name>`, `density=<0..1>`, `intensity=<0..1>` (via `\DeclareOption*` and `\florilegium@set@<key>`); colors `ink` and `accent`; `\florilegiumdraw`, `\florilegiumtextend`, `\florilegiumbloom`, `\florilegiumage`, `\florilegiumtheme`, `\florilegiumornament` (pgfkeys `size ink accent angle seed`), `\florilegiuminitial`, `\florilegiuminitialfont`, `\florilegiumframe`; `\if@twoside` to Lua at each shipout; the shipout hook. LuaLaTeX only. |
| `florilegium.lua` | glue: page geometry from TeX dimens (odd/even side margin, mirror when the right margin is wider), colors, page seed, the TikZ transform (`\pgf@pt@aa..bb`, `\pgf@pt@x/y`), primitive dispatch (through the current theme), inline ornaments (`ORNAMENT` placement table), captions a composition returns (TikZ `\node`s, mirrored x mapped back), density/intensity (`ink.set_pale` around the margin), the header; text marks (whatsits) and the walk of `\ShipoutBox` that finds them (headings, blooms, theme changes); age; animation frames; the initial's placement and its invisible letter. |
| `ink.lua` | drawing core: mulberry32 rng, 1-D gradient noise/fbm, OKLCH tone ramp, affine transform stack (`page_transform(mirror)` = layout cm → page bp, reflected for a right margin), `set_pale` (option intensity: tones and accents toward white, detail unchanged), path building (`smooth` = Catmull-Rom as Béziers, `taper`, `ribbon`, `blade`, `blob`), fill/stroke/clip with ExtGState opacity + multiply, numbered layers, `flush()` into one `pdf_literal` node. |
| `flora.lua` | the primitives: `petal flower lily blossom floret bud bell leaf leaflet stem cyme sprig umbel seedhead tendril sparkle rosette hedera ghost`, the visitors `butterfly bee snail bird`, plus `branch_path`. |
| `grow.lua` | grown composition: regions, grid, stems, marks, visitors on the stems, leaves at nodes, branch loop, falling petals, filler, footer tail; seasons; animation events. Also exports the **motif table** (`M.motifs`) and layer numbers used by `authored.lua`, `M.regions(g, layout)` and `M.field(rects)` (the free-space grid, shared with theme-math), and `M.theme(name)`, which sets the primitives (`F`), motif rows and optional composition of the current theme. |
| `theme-geometric.lua` | the geometric theme: the grown plant with every primitive redrawn flat and straight-edged (`stem`: straight runs ~L/4 apart with mitered corners; `leaf`: kite or toothed polygon in a light and a dark facet, straight white veins; `flower`: rhombus rosette or layered star polygons; `lily bud bell blossom floret cyme sprig umbel tendril`(square spiral) `rosette hedera butterfly bee snail bird`), flat tones only; `motifs()` puts blossoms/budding/bells on straight stalks and adds a `crystal` row (flat-shaded Platonic solid). |
| `figures.lua` | the math figures: `figures` (14: `maurer hypotrochoid lissajous polyhedron knot gasket koch hilbert chords golden parabola petersen vogel fay`, each `pick(layout)` / `draw(rng, R, p)` / `caption(p)`), `families` (13 progressions: `values`, `label`, `title`, `pick`, `draw(rng, R, v, p)`), helpers `maurer phyllotaxis fay vogel hull_of` (faces from nearest-neighbor triples: uniform solids only) `truncate solid compass caption_width`. |
| `theme-math.lua` | the math theme, a composition of its own (`page(g, grow)`): regions = column, a footer band to 72% of the text width, spill; 1. a large corner figure, 2. one or two families down the column, each figure larger than the last, copper arrows, 3. equations (TeX, `EQUATIONS`, base LaTeX only) along the footer and in rows under the text, 4. largest hole first: figure / TeX glyph (`GLYPHS`, scaled, tilted, colored) / dot, proxies at k 0.5–0.62 so things overlap; a size gradient toward the corner. `density` scales the count. |
| `theme-cattree.lua` | the cat-gym theme (`CATTREE-PLAN.md`): pieces at real size, `M.DIM` in cm, `M.SCALE` 1:20 (`post shelf pad base puck pucks peg pegs dots moon stairs ramp ladder bridge beam route steps condo hex bubble ring tube bowl armbowl hammock wave ball pompoms`, each returning `ports` and cat `spots`), cats (`M.cat(rng, pose, facing, angle, {coat})`, poses `loaf sit curl walk stretch claw bat meow drape`, `M.peek`), `M.compose` (zones: floor tower in whole levels, an L/U under the text, the wall, the sparse top; then grow.field's fill; a box list `reg`/`free` with a 3 cm gap so nothing overlaps), `M.page(g, grow)` (animation: each piece an event, grown from its anchor; cats last), `M.initial` (initial.lua's `decorate` hook: a cat on the letter or curled in its counter). Flat 2D, no forced perspective. |
| `tools/cattree/` | `specimen.lua` (sheets of pieces, cats, initials, hand-placed and seeded pages → `build/cattree/*.svg`; initials need `scratch/glyphs.lua` from `glyphs.py`, fontTools), `render.sh` / `montage.sh` (headless Chrome → PNG), `animate.lua` (frames → `build/cattree/frames`, then ffmpeg → GIF). No TeX needed. |
| `scene.lua` | a cat gym on a whole page without TeX (`M.page{ w, h, seed, cats, size, density, keepouts, id, background }`): a slide or title page; keep-outs are boxes the gym stays out of. Used by `apps/studio` and `tools/cattree/scene.lua`. |
| `apps/studio/` | React + TypeScript app, "Cat gym studio" (`npm run dev`): draw text boxes on a page; `@chenglou/pretext` lays the post out in them (`src/flow.ts`), overflow makes new pages; `public/gym-worker.js` runs `scene.lua` in wasmoon; PNG and image-only PDF export (`src/exporter.ts`). `scripts/sync-lua.mjs` copies the Lua into `public/lua` (git-ignored). |
| `authored.lua` | authored composition: the hand-placed "score" (STEMS, LEAVES, BRANCHES, GHOSTS, VISITORS, SNAIL, ACCENTS, FOOT) for A4 with a 68 mm left margin. |
| `initial.lua` | decorated initials: glyph outline via `fonts.handlers.otf.readers.loadshapes`, even-odd inside test, clearance grid, the vine over/under the letter, leaflets, flowers in the gaps, tile frame. |
| `svg.lua` | a page as SVG without TeX (any Lua 5.3/5.4): `M.page(o)` stubs `tex` (`dimen`, `count`, `hoffset`), `node`, `luatexbase`, `texio` around `florilegium.grown`/`authored` and restores them, so `florilegium.geometry()` itself lays the page out; `M.sp` scans a length as TeX does, `html` converts a color as xcolor does (`\rdivide`, then `print_scaled`); `M.translate` turns ink's PDF operators into SVG (clip groups, opacity, multiply). Returns `svg, g, { streams, captions, stats }` (captions: the math theme's TeX, placed and mirrored as `florilegium.lua`'s `captions()` places it, from `florilegium.last_captions`; stats: what grew, from `florilegium.last_stats`, which `grow.page` returns as `{ stats = { motifs, counts, stems, cells } }`). CLI: `texlua svg.lua --help`. |
| `web/`, `.github/workflows/pages.yml` | the playground, "a proof and its colophon": `index.html` (the proof sheet with crop marks and the measured margin, the colophon slip, styles), `app.js` (state in the URL hash; the colophon sentence built from the state, each copper word a chooser, and the garden's alt text; the knob on the measure and the foot of the text as drag/arrow-key controls; page text written from `stats`; "seen by" filters and the measurements table, Machado 2009 + Oklab, `WEAK` 0.10; snippets), `worker.js` (wasmoon 1.16.0 from jsDelivr, mounts `MODULES`, calls `svg.page`, `setTop(0)` after each call), `captions.js` (MathJax 3.2.2 `tex2svg` with `fontCache: 'none'`, set at TikZ's anchor, size in pt, rotation, color, opacity, then spliced into the SVG), `fonts/` (WOFF2 subsets, licenses, README), `hedera.svg` and `sparkle.svg` (drawn by `tools/ornament.lua`). `pages.yml` checks `svg.lua` under `lua5.4`, then publishes `web/` + `*.lua` on pushes to main that touch them. |
| `tools/playcheck/` | `check.mjs` (puppeteer-core): operates every control of the playground and checks the garden, geometry, colophon, URL and snippets (44 checks); writes one all-settings-changed page and its CLI/LaTeX snippets for a `cmp` / PDF check. |
| `florilegium.tex` / `florilegium-grow.tex` | demo documents (authored / grown). Body text = `text-methods.tex` (+ `text-growth.tex` for grown) + `text-sharing.tex`; it describes the code, so **update it when the method changes**. |
| `showcase.tex` | "A year in the margin": `[grown,sections,aging]`, an initial, `\florilegiumbloom`; each section describes the feature it shows. Two passes. |
| `spread.tex` | "Two sides, two gardens": `twoside`, wide outer margin, `[grown,sections]`; page 3 switches to `\florilegiumtheme{geometric}` after a `\newpage`. `make preview` puts pages 2–3 side by side in `gallery/spread.png`. Its text describes the mirror and the themes; keep page 2 full (the `\newpage`) and page 3 short enough to spill. |
| `specimen.tex` / `specimen-geometric.tex` | one of every primitive, flora / geometric theme (`gallery/specimen-geometric.png`). |
| `ornaments.tex` | `\florilegiumornament` demo (`gallery/ornaments.png`). |
| `gallery.tex`, `tools/gallery.py` | one short page per variant (`\galleryink`, `\galleryage`, `\gallerytheme`) → `gallery/seeds.png` + `seeds.gif`, `inks.png`, `seasons.png`, `themes.png`, `dials.png` (`--options density=0.4,...`, via `\PassOptionsToPackage`). |
| `animation.tex`, `tools/animate.py` | growth animation: one page per frame (`\florilegiumframe`), parallel LuaLaTeX jobs, pdftoppm, ffmpeg → `build/grow-N.gif` + `.mp4`. `tools/animcheck.lua` checks that the last frame equals the page. |
| `tools/Dockerfile`, `tools/in-docker` | TeX Live 2023 image; `make RUN=tools/in-docker` when there's no local TeX. |
| `postscript/florilegium.ps` | the PostScript port: ink + flora + grow (no animation, initials, themes, mirror, density/intensity, ornaments or authored page) and a two-page text that describes itself, with heading marks and the spill. One file, run by Ghostscript (`make postscript`, local `gs`, not the Docker image) or a printer. Not kept in sync automatically: a change to a primitive or to `grow.lua` has to be made there too. |
| `PROCESS.md`, `process/` | the user's write-up of how the repo was made: `process/claude-ai.md` (the Claude.ai chat; the files it attached are in `process/claude-ai/`, and `response-final/florilegium-repo.zip` is the original repo) and `process/claude-code.md` (the first Claude Code session, up to v1.0). Historical: never update them along with the code. |

## Build

```sh
docker build -t florilegium-tex tools     # once, if there is no local TeX
make RUN=tools/in-docker                  # the four PDFs (showcase: two passes for aging)
make preview RUN=tools/in-docker          # + ornaments.pdf, specimen-geometric.pdf, build/{geometric,math}.pdf -> gallery/*.png
make seed-7 RUN=tools/in-docker           # one page for seed 7 -> build/seed-7.pdf
make gallery RUN=tools/in-docker          # seeds, inks and seasons sheets (~40 s)
make grow-6 RUN=tools/in-docker [EXPLAIN=1]            # ~45 s: build/grow-6.gif + .mp4
make animation RUN=tools/in-docker                     # both, copied to gallery/growth*.gif
tools/in-docker texlua tools/animcheck.lua 1 2 3       # last frame == page, byte for byte (also geometric, mirrored, density 0.4/0.05, math)
tools/in-docker texlua tools/ident.lua build/ident-a    # 45 content streams, to diff -r before/after a change
make preview                              # gallery/preview-*.png, spread.png, specimen-geometric.png, geometric.png, math.png
make postscript [SEED=7]                  # the PostScript port via local gs -> build/postscript-7.pdf + gallery/preview-postscript.png
make svg [SEED=7] RUN=tools/in-docker     # build/svg-7.svg: the drawing on page 1 of florilegium-grow.tex, without TeX
make playground                           # web/ at http://localhost:8000/web/ (the Lua is fetched from ../)
cd tools/playcheck && npm install && node check.mjs http://localhost:8000/web/ ../../build   # every control, 44 checks
```

Fixed seed: `lualatex "\def\florilegiumseed{7}\input{florilegium-grow.tex}"`. Any
positive integer works.

Look at output with `pdftoppm -png -r 100 file.pdf page` and read the PNG; for fine detail
use `-r 300` with `-x -y -W -H` crops. Always look before declaring a change good. For a
quick sheet of every primitive, `scratch/` (git-ignored) is the place for test documents.

Bytes per primitive: `tools/in-docker texlua tools/bytes.lua` (stubs out TeX). A flower
is ~70 KB of path operators, a page ~3 MB uncompressed, ~0.7 MB in the PDF.

## Conventions and traps

- **US spelling everywhere** (color, center, gray, meter) — code, comments, docs.
- **Credits and licenses.** Every file a user copies (`florilegium.sty`, the ten `.lua`,
  `postscript/florilegium.ps`) carries the copyright line; the `.sty` and the `.ps` (which
  travels alone) carry the full MIT text. A borrowed algorithm or published constant gets a
  credit where it is used and a line under README's Credits (Ottosson's Oklab, Ettinger's
  mulberry32, Wong et al.). Trademarks stay out of user-facing names (`hypotrochoid`, not
  Spirograph); data with a license of its own stays out of the package (MSC2020 is
  CC BY-NC-SA: bare codes only).
- **Raw literals bypass TikZ transforms.** A primitive called inside a TikZ scope must
  read pgf's matrix itself (`florilegium.lua: sync_transform`). Inside the margin picture
  the transform is just cm→bp from the page's lower-left corner.
- **Lua truncates multiple returns** in the middle of a table constructor:
  `{x0, y0, f(t), x1}` keeps only the first value of `f(t)`. Assign to locals first.
- **Line widths are absolute bp** (we transform points in Lua, not with `cm`). Anything
  that should scale with a motif is a filled shape (`taper`, `ribbon`); `flora.stem`
  switches to a stroke below ~0.7 bp.
- **Opacity/blend** need ExtGState resources: `ink.lua: gs()` registers `/floaNN` and
  `/flomNN` (multiply) through `\pgfutil@addpdfresource@extgs` once per document.
- **Size budget.** Output, not time, is the constraint. Coordinates are printed `%.1f` bp;
  a path used for fill and clip is emitted once (`clip()` then `flood()`); streaks are
  `taper` (2 Béziers); florets below 0.7 mm are a 10-point polygon. Measure before adding
  per-petal detail.
- **Level of detail**: primitives check `ink.unit()` (cm per local unit) and
  `ink.get_lift()` (ghost) and skip specks/veins when small or pale.
- **Determinism**: every primitive takes an rng; layout code draws from `layout` and
  hands primitives `rng.fork()`, so a change inside a primitive does not move the layout.
  Never iterate a string-keyed table with `pairs()` where the order feeds an rng (Lua's
  order changes from run to run); `authored.lua` uses a fixed stem order for this reason.
- **Animation replays draws.** With `g.anim`, `grow.lua: place()` calls each closure
  several times (smaller scales first) and restores `rng` and `layout` with
  `save()`/`load()` in between. A closure may only draw from those two (fork inside the
  closure, not before it), or the last frame stops matching the page; run
  `tools/animcheck.lua` after touching `grow.lua`.
- **Separate streams keep old pages stable.** Visitors draw from `ink.rng(seed*7919+101)`,
  the season's additions from `+211`, the authored visitors from `+103`. With no visitors,
  no age and no marks a grown page is byte-identical to before those features (check by
  comparing against `git show HEAD:grow.lua` etc. in a texlua harness with stubbed TeX).
- **The last animation frame uses t = ∞**: for the event that ends last,
  `(t0+dur-t0)/dur` can round just below 1 and leave a 95% bloom.
- **Text end, one pass**: `\florilegiumtextend` records `\pagetotal+\pagedepth` and the
  page number; the shipout hook of that same page reads them, in the same run.
- **Marks, one pass**: `florilegium.mark` writes a `user_defined` whatsit (user_id
  0x464C4F); in the shipout/background hook `\ShipoutBox` is complete, and walking it
  (heights, depths, `node.effective_glue`) gives each mark's y; the box's origin is 1 in
  (+`\voffset`) below the top of the paper. Option `sections` wraps `\@sect` at
  `\begin{document}` and puts the mark into the typeset title (#8), so standard classes only.
- **Aging needs the .aux**: `\flo@lastpage` is written at the end and read on the next run;
  until then every page is summer and LaTeX asks for a rerun.
- **Themes**: every primitive in `grow.lua` and `authored.lua` is called through `F` (never
  `flora.` directly), and the motif rows' `draw` functions use the module-level `F` upvalue
  that `M.theme()` reassigns. A theme's `motifs(rows, F)` gets copies of the base rows: keep
  their names (`counts.flower`, `counts.lily` and the marks look them up), set `w = 0` to
  retire one. `M.theme(nil)` must stay exactly the old path: check unthemed pages are
  byte-identical (harness below) after touching it.
- **Theme compositions**: a theme with `page(g, grow)` gets the whole page (grow.page and
  authored.page hand it over). It must follow the animation contract (record with tags,
  replay closures from `rng`/`layout` only, return `{ rec, total }`) and may return
  `captions = { {x, y, text, event, anchor, small, scale, rotate, color, opacity} }` in
  layout cm; florilegium.lua sets them as TikZ nodes (scaled 10 pt with `transform shape`,
  so any size works), swapping east/west anchors and negating rotations on mirrored pages.
  Text that reads left to right must run in `-x` in layout coordinates on a mirrored page
  (`fwd` in theme-math). Choose parameters with `layout` *before* `place`. TeX in captions
  must not need packages the user may not load (no `\mathbb`, `\binom`).
- **Density** must reduce to the old arithmetic at 1: only multiply/divide by `D` (or use
  `2 - D`, `sqrt(D)`, `D ^ 0.6`), never add rng draws on the D = 1 path. Low on the dial the
  structure itself thins (`NSTEM`, `FOOTER`, no ghosts < 0.4, no snail/bird < 0.3,
  `NBMAX = 40 D` branches); florilegium.lua clamps at 0.03. **Intensity** is `ink.set_pale` around
  the margin only (not initials or ornaments); `get_lift` (level of detail) ignores it.
- **Ornaments** are numbered in document order for their seed; `seed=random` (os.time) is
  the only non-deterministic path in the package, and it is opt-in.
- **Mirror**: `g.mirror` means the layout is in mirrored coordinates (text edges swapped);
  only `ink.page_transform(g.mirror and g.pw)` reflects. Anything that hands a position back
  in page coordinates (`ink.to_page`, e.g. `flora.hedera`'s stem end) is already reflected and
  must be mapped back (`pw - x`) before it is drawn again in layout coordinates.
- **Byte-identity harness**: `tools/ident.lua <dir>` writes 45 content streams (5 seeds ×
  spill × summer/novisitors/spring/autumn-marks, + authored) to a directory (~170 MB); run it
  before and after a change that should move nothing (`build/ident-before`, `-after`) and
  `diff -r`.
- **Never wrap typeset text in `q`…`Q` page literals**: `Q` drops the `Tf` LuaTeX set
  inside and the rest of the page's text disappears. The initial's invisible letter uses
  `3 Tr` / `0 Tr` instead. (ActualText on a path-only span is ignored by poppler.)
- This container's TeX Live lacks luaotfload's font database for system fonts; the
  documents pin Computer Modern. Harmless to remove on a full install.
- **SVG** (`svg.lua`) translates only what `ink.lua` writes (`m l c h f S W n q Q rg RG w d J j`,
  `gs` with `/floaNN` `/flomNN`) and errors on anything else: a new operator in ink needs a case
  there. Anything new that the page path of `florilegium.lua` reads from TeX (`tex.dimen`, `token`)
  needs a stub in `M.page`. Byte identity with LuaLaTeX rests on the length scan and the xcolor
  conversion; check it by building with `\pdfvariable compresslevel=0` and finding the streams
  (`svg.page`'s third return) in the PDF. The math theme's text is TeX: the CLI leaves it out with
  a warning, the playground sets it with MathJax (close to TeX's setting, not identical). Chromium
  draws hairlines thinner than a pixel heavier than PDF renderers do (a Maurer rose's chords); the
  SVG itself is right (Typst's svg2pdf, then poppler, matches the LuaLaTeX page).
- **Playground**: `worker.js` mounts only the modules in `MODULES`, so a new theme or module the
  page requires goes there too (`pages.yml` copies every `*.lua`). The browser runs Lua 5.4 and
  LuaTeX 5.3: keep the Lua to both. Seeds have matched byte for byte across texlua, lua5.3,
  lua5.4 and wasmoon (18 varied pages). Every control that differs from its default is in the
  URL hash; the LaTeX and command-line snippets give the same garden (checked: the CLI output is
  the download byte for byte, and the compiled LaTeX contains its garden and head rule). wasmoon
  keeps whatever `doString` returns on the Lua stack: without `lua.global.setTop(0)` after each
  call every page stays in memory and WebAssembly fails after ~35 pages ("attempt to index a nil
  value", "memory access out of bounds"). Run `tools/playcheck` after touching `web/`.
- **Playground design** (the user's direction, 2026-10-31): a printer's proof and its colophon, not
  a sidebar of sliders. Cobalt is what is printed, copper what can be taken hold of; a choice is
  never told by color alone (a manicule ☞ and an underline). The colophon is generated from the
  state, so it cannot disagree with the page, and it offers only what the style uses: the math
  page has no season and no visitors (they change nothing there), its density ends "pared down to
  a few figures" and its head rule starts with a circle, not an ivy leaf; a seed that no visitor
  came to says so. Each density is a whole phrase, so the sentence reads at every value. Fell for the table and slip, Latin Modern (renamed
  Florilegium Roman/Mono, as GUST asks of modified fonts) for the page; fonts are self-hosted.
- **PostScript port** (`postscript/florilegium.ps`, `make postscript [SEED=7]`, ~2.5 s):
  callbacks (spines, half-widths) see their caller's variables by dynamic scoping, so a
  helper that takes a procedure keeps its own names under `_` (`_p`, `_n`), and the growth
  helpers use prefixes (`d.` disc, `a.` addstem…). Nothing is painted while it grows:
  `ifill`/`istroke`/`iclip` capture the path with `pathforall` into numbered layers and
  `paintlayers` replays them. Angles are degrees (PostScript's `sin`/`cos`/`atan`); the rng
  is Park-Miller (Schrage), not mulberry32. Literal arrays in a procedure body are shared
  between calls; build fresh ones before mutating.
- **Ghostscript traps** (10.05): the PS transparency operators exist only with
  `-dALLOWPSTRANSPARENCY`; a raster device also needs `0 .pushpdf14devicefilter` per page;
  a PS `stroke` takes the *fill* alpha when rasterized and the stroke alpha in pdfwrite, so
  set both; a banded second page with the compositor pushed segfaults (hence `/MaxBitmap`
  in `setpagedevice`); Adobe's `ISOLatin1Encoding` has `/minus` at 45, not `/hyphen`.

## How the growth works (grow.lua)

1. Regions: margin column, a footer band along the bottom (to ~45% of the text width),
   and on the last page the rectangle under the text.
2. Stems: three from a root near the bottom-left corner; x(y) = c + A·fbm(y/λ + φ), blended
   into the root over 4 cm. Tops at the page top (hero flower), 60–72% (lily), 36–48%
   (flower). A spiral scroll at the root; a footer stem to the right. On the last page,
   Bézier arcs from a main stem into the spill, each ending in a flower.
3. Ghosts (1–2 pale flowers, layer 1) get a weak proxy so the growth leaves them some room.
4. Leaves at nodes of every "leafy" stem (alternating, 35–60°, smaller toward the top; the
   footer gets leaflets that thin out), only where `free` allows.
5. Grid (2 mm), `free` = largest disc that fits (proxies count at κ=0.85 of their radius;
   stems are chains of small discs) and `sdist` = distance to the nearest stem point.
   Updates only visit lattice cells near the new disc.
6. Branch loop: cell with the largest `free·U(0.85,1.15)` within REACH (3 cm) of a stem;
   pick a motif by weight `w/(1+count/cap)` (hard caps only for flower, lily, umbel,
   bells); scale so r(s) ≈ 0.95·free; axis = away from the nearest stem point + `upright`
   lean; `flora.branch_path` from that stem point; the branch's points become stem points.
   Stop below SMALLEST (3.6 mm).
7. Filler: holes ≥ 1.7 mm within 7.5 mm of a stem get a leaflet pair, a bud or a floret
   cluster (capped); far holes get at most 6 copper accents; no dust.
8. Footer tail: copper hairline + sparkle. Layers: 1 ghost, 2 stems, 3 leaves, 4 airy,
   5 blooms, 6 accents (7 overlay, animation only); a safety clip a little outside the regions.
9. Marks (before the leaves, right after the ghosts): a flower beside each heading
   (copper, via `ink.in_accent`) or `\florilegiumbloom[motif]`, at the column's edge,
   shrunk or left out where there's no room. Then visitors on the stems: a snail on a
   main stem (40% of pages), a bird on its own twig (22%). Butterflies and bees are motif
   rows with `fly = true` (no branch, fixed caps of 2), allowed per page by the visitor stream.
10. Seasons (`g.age`; nil = summer, unchanged): `season(spring, summer, autumn)` blends a
   value; motif rows carry `spring`/`summer`/`autumn` weight multipliers (`budding` only in
   spring, `seedhead` only in autumn); the shorter stems end in buds or seed heads; young
   leaves are smaller and paler (ghost lift); autumn turns some leaves copper and drops
   petals below the flowers (`blooms`).
11. Animation (`g.anim`, set by `\florilegiumframe`): every step is an `event` (a stem
   that grows or a motif that opens), either in a phase (stems, ghost, marks, branch,
   fall, fill, accent, tail) or starting at a fraction `at` of its parent's growth. Output is tagged
   `{event, from, to}` (`ink.tag`); stems are also drawn as prefixes every GROWSTEP with a
   pointed tip, motifs at the BLOOM scales. `schedule()` times the events (T_* constants,
   ~13 s); `florilegium.lua` records once per garden and `ink.emit`s the visible pieces of
   each frame in painting order. The explained version adds a dashed disc per branch.
   `place(..., path, steps)` moves a motif along `path(e)` instead of opening it (visitors
   fly in, petals fall, the snail crawls with `till_end`).

To add a motif: write the primitive in `flora.lua` (origin at its base or center, axis
+y, takes `rng`), then add a row to `motifs` in `grow.lua` with `r(s)` (proxy radius),
`off(s)` (center back to the origin along the axis), `upright`, `layer`, `w`, `max`,
optionally `hard`/`hang`/`fly` and season multipliers, and `draw(rng, s)`. `authored.lua`
can then place it by name, and `\florilegiumbloom[name]` can ask for it.

To add a theme: write `theme-<name>.lua` returning `{ flora = { name = fn, ... },
motifs = function(rows, F) ... return rows end }` (see `theme-geometric.lua`), or with
`page = function(g, grow)` for a composition of its own (see `theme-math.lua`). Its primitives
replace flora's by name with the same signature and frame (`flower(rng, s)` centered,
`sprig(rng, L)` from its base along +y, ...); `motifs` may reweight rows and append new
ones (their `draw` should call `F.x`). Then `\usepackage[grown,theme=name]` or
`\florilegiumtheme{name}`; add the theme to a case in `tools/animcheck.lua`, and look at a
page and a specimen sheet.

## Ideas not done

- Proxies of 2–3 discs for long motifs (leaves, cymes) instead of one disc.
- Read free space on every page (floats, display equations), not just the last.
- Leaf tips that curl over and show a paler underside, as in the reference image.
- Section flowers for KOMA/titlesec headings (only `\@sect`-based classes now).
- Initials in the authored composition's style for the first page, and a bigger, framed
  title-page tile.
- More themes: knots, fractals (Koch, Julia), graphs; a theme chosen from `\subjclass` /
  `\keywords` (MSC code → theme), or per section (blackboard #4941 and its subtasks).
- Form XObjects for repeated sub-shapes (florets) to cut the PDF size further.
- Plate: figures traced by a pen in the animation (they only scale in now); more figures
  (Möbius strip, torus, Penrose tiles, Sierpiński); the footer band is left empty.

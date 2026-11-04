-- specimen sheets for theme-cattree.lua, as SVG, without TeX.
--   lua5.4 tools/cattree/specimen.lua [--marks] [outdir]
-- Every cell is labeled (A2a ...). Every sheet carries the scale (1:20) and a
-- gray reference cat; sheet 3 puts reference cats where cats would go. With
-- --marks, gray rings show ports (tick = outward) and gray diamonds cat spots.
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path

local marks_on, outdir = false, root .. "/build/cattree"
for _, a in ipairs(arg) do if a == "--marks" then marks_on = true else outdir = a end end
os.execute("mkdir -p '" .. outdir .. "'")

local streams = {}
tex = { sprint = function() end }
luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }

local ink = require("ink")
local svg = require("svg")
local C = require("theme-cattree")
C.warn = function(m) io.stderr:write("warning: " .. m .. "\n") end
local real, u = C.real, C.U
local fmt = string.format
local CM = 72 / 2.54
local W, H = 21, 29.7
local GRAY = { 0.45, 0.45, 0.45 }

-- ---------------------------------------------------------------- the reference cat
-- A plain gray silhouette at true size (body about 45 cm), standing on the
-- origin: pose loaf | sit | curl, facing +x (facing = -1 turns it round).
-- Only for checking sizes; the real cats come later.
local function ears(hx, hy, r)
  ink.poly({ { hx - 0.75 * r, hy + 0.45 * r }, { hx - 0.55 * r, hy + 1.35 * r }, { hx - 0.1 * r, hy + 0.85 * r } }, true)
  ink.poly({ { hx + 0.75 * r, hy + 0.45 * r }, { hx + 0.55 * r, hy + 1.35 * r }, { hx + 0.1 * r, hy + 0.85 * r } }, true)
end
local function ell(cx, cy, rx, ry)
  local p = {}
  for k = 0, 23 do local a = 2 * math.pi * k / 24 p[#p + 1] = { cx + rx * math.cos(a), cy + ry * math.sin(a) } end
  ink.smooth(p, true)
end
local function scalecat(pose, facing, angle)
  ink.push() if angle then ink.rotate(angle) end ink.scale((facing or 1) * C.SCALE, C.SCALE)
  local function shape()
    if pose == "walk" then
      ell(0, 15, 19, 7.5) ink.circle(19, 22, 6) ears(19, 22, 6)
      for _, x in ipairs({ -13, -8, 8, 13 }) do ink.poly({ { x - 1.8, 0 }, { x + 1.8, 0 }, { x + 2, 13 }, { x - 2, 13 } }, true) end
      ink.poly({ { -16, 18 }, { -18, 13 }, { -29, 20 }, { -30, 25 } }, true)
    elseif pose == "sit" then
      ell(0, 10, 12, 10) ell(4, 19, 7.5, 11) ink.circle(5, 31, 6.5) ears(5, 31, 6.5)
      ell(-9, 2, 9, 2.5)                                 -- the tail, wrapped round the feet
    elseif pose == "curl" then
      ell(0, 8, 19, 8) ink.circle(11, 9, 6) ears(11, 9, 6)
    else                                                 -- loaf
      ell(-2, 9.5, 20, 9.5) ink.circle(16, 16, 6.5) ears(16, 16, 6.5)
      ell(-14, 2.5, 10, 2.5)
    end
  end
  shape() ink.fill(GRAY, 0.3)
  ink.pop()
end

-- ---------------------------------------------------------------- a sheet
-- cells = { { label, x, y, fn(rng) -> {ports, spots}, lx=, ly= } }; notes = { {x, y, text, size} };
-- cats = { { x, y, pose, facing } } (page cm)
local function sheet(name, title, cells, notes, cats)
  streams = {}
  ink.set_transform(ink.page_transform())
  local marks = {}
  for i, c in ipairs(cells) do
    ink.push() ink.translate(c[2], c[3])
    local r = c[4](ink.rng(1000 + 37 * i)) or {}
    ink.pop()
    for _, p in pairs(r.ports or {}) do marks[#marks + 1] = { "port", c[2] + p[1], c[3] + p[2], p[3], p[4] } end
    for _, s in ipairs(r.spots or {}) do marks[#marks + 1] = { "spot", c[2] + s[1], c[3] + s[2], s[3] } end
  end
  -- the scale: a bar 0..50 cm and a reference cat, top right
  local bx, by = 13.6, H - 1.6
  for k = 0, 5 do
    ink.moveto(bx + real(10 * k), by) ink.lineto(bx + real(10 * k), by + (k % 5 == 0 and 0.22 or 0.12))
  end
  ink.moveto(bx, by) ink.lineto(bx + real(50), by) ink.stroke(GRAY, 0.5)
  ink.push() ink.translate(bx + real(50) + 1.6, by) scalecat("loaf") ink.pop()
  for _, c in ipairs(cats or {}) do ink.push() ink.translate(c[1], c[2]) scalecat(c[3], c[4], c[5]) ink.pop() end
  ink.flush()

  local out = { fmt('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fmm" height="%.2fmm" viewBox="0 0 %.2f %.2f">',
    W * 10, H * 10, W * CM, H * CM) }
  out[#out + 1] = fmt('<rect width="%.2f" height="%.2f" fill="#fefdfb"/>', W * CM, H * CM)
  out[#out + 1] = fmt('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', H * CM)
  for i, s in ipairs(streams) do svg.translate(s, out, name .. i) end
  out[#out + 1] = "</g>"
  local function X(x) return x * CM end
  local function Y(y) return (H - y) * CM end
  local txt = 'font-family="Helvetica, Arial, sans-serif" fill="#8a8a8a"'
  out[#out + 1] = fmt('<text x="%.1f" y="%.1f" font-size="11" %s>%s</text>', X(1), Y(H - 1.1), txt, title)
  out[#out + 1] = fmt('<text x="%.1f" y="%.1f" font-size="6" %s>1:20 · 0–50 cm · gray cat ≈ 45 cm, for scale</text>', X(bx), Y(by - 0.4), txt)
  for _, c in ipairs(cells) do
    if c[1] ~= "" then
      out[#out + 1] = fmt('<text x="%.1f" y="%.1f" font-size="6" text-anchor="middle" %s>%s</text>', X(c[2] + (c.lx or 0)), Y(c[3] + (c.ly or -0.45)), txt, c[1])
    end
  end
  for _, n in ipairs(notes or {}) do
    out[#out + 1] = fmt('<text x="%.1f" y="%.1f" font-size="%s" %s>%s</text>', X(n[1]), Y(n[2]), n[4] or 7, txt, n[3])
  end
  if marks_on then
    for _, m in ipairs(marks) do
      if m[1] == "port" then
        local L = math.sqrt(m[4] ^ 2 + m[5] ^ 2) + 1e-9
        out[#out + 1] = fmt('<circle cx="%.1f" cy="%.1f" r="1.3" fill="none" stroke="#999" stroke-width="0.4"/>', X(m[2]), Y(m[3]))
        out[#out + 1] = fmt('<line x1="%.1f" y1="%.1f" x2="%.1f" y2="%.1f" stroke="#999" stroke-width="0.4"/>',
          X(m[2]), Y(m[3]), X(m[2] + m[4] / L * 0.15), Y(m[3] + m[5] / L * 0.15))
      else
        out[#out + 1] = fmt('<path d="M%.1f %.1fl1.3 1.3l-1.3 1.3l-1.3 -1.3z" fill="#999" fill-opacity="0.7"/>', X(m[2]), Y(m[3]) - 1.3)
      end
    end
  end
  out[#out + 1] = "</svg>\n"
  local f = assert(io.open(outdir .. "/" .. name .. ".svg", "w"))
  f:write(table.concat(out, "\n"))
  f:close()
  local bytes = 0
  for _, s in ipairs(streams) do bytes = bytes + #s end
  io.write(fmt("%s: %d cells, %.0f KB of path operators\n", name, #cells, bytes / 1024))
end

local cells
local function add(label, x, y, fn, o) local c = { label, x, y, fn } for k, v in pairs(o or {}) do c[k] = v end cells[#cells + 1] = c end
local function conn(fn, x0, y0, x1, y1, o) return function(rng) return fn(rng, x0, y0, x1, y1, o) end end
local function at(x, y, fn) return function(rng) ink.push() ink.translate(x, y) local r = fn(rng) ink.pop() return r end end
local function letter(j) return string.char(96 + j) end

-- ---------------------------------------------------------------- sheet 1: structure
cells = {}
local posts = {
  { "A1a", { kind = "plush", h = real(50) } }, { "A1b", { kind = "plush", h = real(70) } },
  { "A2a", { kind = "banded", bands = 1, h = real(50) } }, { "A2b", { kind = "banded", bands = 2, h = real(70) } },
  { "A2c", { kind = "banded", bands = 3, h = real(70) } },
  { "A3a", { kind = "sisal", h = real(50) } }, { "A3b", { kind = "sisal", h = real(70), d = real(12) } },
  { "A4a", { kind = "rope", h = real(50) } }, { "A4b", { kind = "rope", h = real(70), d = real(12) } },
}
for i, p in ipairs(posts) do add(p[1], 1.6 + (i - 1) * 2.1, 22.9, function(rng) return C.post(rng, p[2]) end) end

local kinds = { { "B1", "plain" }, { "B2", "bracket" }, { "B3", "cushion" }, { "B5", "fence" } }
for i, k in ipairs(kinds) do
  for j, L in ipairs({ 35, 50, 70 }) do
    add(k[1] .. letter(j), 2.4 + (i - 1) * 4.1, 20.0 - (j - 1) * 1.6, function(rng) return C.shelf(rng, { kind = k[2], w = real(L) }) end)
  end
end
for j, L in ipairs({ 30, 40, 50 }) do
  add("B4" .. letter(j), 18.6, 20.0 - (j - 1) * 1.6, function(rng) return C.pad(rng, { w = real(L), stalk = j == 3 }) end)
end

local cx = { 0.8, 4.6, 8.6, 12.9, 17.2 }
local rows = { 12.2, 8.6, 5.0 }
add("C1a", cx[1] + 1.2, rows[1], conn(C.pucks, -0.6, 0.6, 1.0, 2.4), { lx = 0.2 })
add("C1b", cx[1] + 1.2, rows[2], conn(C.pucks, -0.8, 0.6, 1.8, 1.4), { lx = 0.5 })
add("C1c", cx[1] + 1.2, rows[3], conn(C.pucks, 0.2, 0.6, 0.2, 2.4), { lx = 0.2 })
add("C2a", cx[2] + 0.2, rows[1], conn(C.stairs, 0, 0, 2.8, 2.2), { lx = 1.4 })
add("C2b", cx[2] + 0.2, rows[2], conn(C.stairs, 0, 0, 3.2, 1.2), { lx = 1.6 })
add("C2c", cx[2] + 0.2, rows[3], conn(C.stairs, 0, 2.2, 3.0, 0), { lx = 1.5 })
add("C3a", cx[3], rows[1] + 0.6, conn(C.bridge, 0, 0, 3.6, 0), { lx = 1.8, ly = -1.0 })
add("C3b", cx[3], rows[2] + 0.4, conn(C.bridge, 0, 0, 3.6, 1.0, { sag = 0.7 }), { lx = 1.8, ly = -0.9 })
add("C3c", cx[3], rows[3] + 0.9, conn(C.bridge, 0, 0.8, 3.6, 0, { sag = 0.3 }), { lx = 1.8, ly = -1.0 })
add("C4a", cx[4], rows[1], conn(C.ramp, 0, 0, 3.0, 2.2), { lx = 1.5 })
add("C4b", cx[4], rows[2], conn(C.ramp, 0, 0, 3.4, 1.0), { lx = 1.7 })
add("C4c", cx[4], rows[3], conn(C.ramp, 0, 2.3, 2.2, 0), { lx = 1.1 })
add("C5a", cx[5] + 1, rows[1], conn(C.ladder, 0, 0, 0, 2.4))
add("C5b", cx[5] + 1, rows[2], conn(C.ladder, -0.4, 0, 0.6, 2.2))
add("C5c", cx[5] + 1, rows[3], conn(C.ladder, -0.8, 0, 1.2, 1.6))

add("G1a", 3.2, 1.9, function(rng) return C.base(rng, { w = real(60) }) end)
add("G1b", 9.0, 1.9, function(rng) return C.base(rng, { w = real(90) }) end)

sheet("specimen-1", "cat tree specimens · 1 · structure", cells, {
  { 1, 26.6, "A  posts: plush, banded, sisal, rope (50 and 70 cm tall; 9 and 12 cm thick)", 7 },
  { 1, 21.4, "B  shelves (columns: plain, bracket, cushion, fence; rows: 35, 50, 70 cm)  ·  B4 round pads (30, 40, 50 cm)", 7 },
  { 1, 15.3, "C  connectors, only between raised points (C1 pucks · C2 stairs · C3 rope bridge, level or sloped · C4 sisal ramp · C5 ladder)", 7 },
  { 1, 3.4, "G  base slabs (60, 90 cm)", 7 },
}, { { 14.6, 1.9 + real(5), "sit" }, { 17.0, 1.9 + real(5), "loaf", -1 } })

-- ---------------------------------------------------------------- sheet 2: furnishings
cells = {}
local condos = {
  { "D1a", { holes = { "round" } } }, { "D1b", { holes = { "oval" } } }, { "D1c", { holes = { "arch" } } },
  { "D1d", { holes = { "round", "round" }, w = real(55) } }, { "D1e", { holes = { "oval", "round" }, skin = "sisal", w = real(55) } },
}
for i, c in ipairs(condos) do add(c[1], 2.0 + (i - 1) * 4.2, 23.4, function(rng) return C.condo(rng, c[2]) end) end

local R = real(C.DIM.hex_w) / 2
add("D2a", 2.3, 18.4, function(rng) return C.hex(rng, {}) end, { ly = -1.8 })
add("D2b (three, sharing edges)", 8.0, 18.4, function(rng)
  for _, p in ipairs({ { 0, 0 }, { 1.5 * R, 0.866 * R }, { 3 * R, 0 } }) do
    ink.push() ink.translate(p[1], p[2]) C.hex(rng, {}) ink.pop()
  end
  return {}
end, { lx = 1.5 * R, ly = -1.8 })
add("D3a", 16.2, 19.6, function(rng) return C.bubble(rng, {}) end, { ly = -1.9 })
add("D3b", 19.2, 19.6, function(rng) return C.bubble(rng, { r = real(18) }) end, { ly = -1.6 })

local bowls = { { "E1a", { kind = "plush" } }, { "E1b", { kind = "basket" } }, { "E1c", { kind = "basket", scallop = true } },
  { "E1d", { kind = "plush", r = real(15) } } }
for i, b in ipairs(bowls) do add(b[1], 2.0 + (i - 1) * 3.0, 12.6, function(rng) return C.bowl(rng, b[2]) end) end
add("E4a", 13.4, 11.4, function(rng)
  C.post(rng, { kind = "banded", bands = 1, h = real(50) })
  at(real(4.5), real(38), function(r) return C.armbowl(r, { kind = "plush" }) end)(rng)
  return {}
end, { lx = 1.0 })
add("E4b", 17.4, 11.4, function(rng)
  C.post(rng, { kind = "sisal", h = real(50) })
  at(real(4.5), real(38), function(r) return C.armbowl(r, { kind = "basket", scallop = true }) end)(rng)
  return {}
end, { lx = 1.0 })

for i, L in ipairs({ 45, 60 }) do
  add("E2" .. letter(i), 1.2 + (i - 1) * 4.6, 6.6, function(rng)
    local h = real(55)
    C.post(rng, { kind = "banded", bands = 1, h = h })
    at(real(L), 0, function(r) return C.post(r, { kind = "banded", bands = 1, h = h }) end)(rng)
    return C.hammock(rng, real(4.5), h * 0.85, real(L) - real(4.5), h * 0.85)
  end, { lx = real(L) / 2 })
end
add("E3a", 12.6, 6.6, function(rng) return C.wave(rng, {}) end)
add("E3b", 16.8, 6.6, function(rng) return C.wave(rng, { w = real(40), h = real(20) }) end)

local toys = { { "F1a", { kind = "pom" } }, { "F1b", { kind = "dark" } }, { "F1c", { kind = "sisal" } },
  { "F1d", { kind = "pom", spring = true } } }
for i, t in ipairs(toys) do add(t[1], 1.5 + (i - 1) * 2.0, 4.0, function(rng) return C.ball(rng, t[2]) end, { ly = -2.2 }) end
add("F2a", 11.5, 1.0, function(rng) C.post(rng, { kind = "plush", h = real(30) }) at(0, real(31), function(r) return C.pompoms(r, { n = 2 }) end)(rng) return {} end)
add("F2b", 15.5, 1.0, function(rng) C.post(rng, { kind = "plush", h = real(30) }) at(0, real(31), function(r) return C.pompoms(r, { n = 3 }) end)(rng) return {} end)

sheet("specimen-2", "cat tree specimens · 2 · furnishings", cells, {
  { 1, 26.6, "D1 condos (42 × 36 cm, holes about 20 cm: round, oval, arch, two holes, sisal skin)", 7 },
  { 1, 21.3, "D2 hex modules (60 cm across) · D3 space bubbles (44, 36 cm)", 7 },
  { 1, 14.8, "E1 bowls (40 cm: plush, basket, scalloped basket; 30 cm) · E4 bowls on arms", 7 },
  { 1, 9.9, "E2 hammocks (45, 60 cm between posts) · E3 curved loungers (y = a x², 50 and 40 cm)", 7 },
  { 1, 4.9, "F1 toys (pom-pom, dark pom-pom, sisal ball, on a spring) · F2 pom-poms on wires", 7 },
}, {
  { 2.3, 18.4 - real(30) * 0.866 + real(3.5), "sit" },           -- a cat in a hex
  { 2.0, 12.6 + real(7), "curl" },                               -- a cat in a bowl
  { 12.6, 6.6 + real(3) + real(5), "curl", -1 },                  -- in the lounger
  { 2.0, 23.4 + real(36) + real(4), "loaf" },                     -- on a condo
})

-- ---------------------------------------------------------------- sheet 4: connectors and newer pieces
cells = {}
-- H. sideways connectors
add("H1a beam", 2.2, 22.0, function(rng)
  C.beam(rng, 0, 1.2, 2.6, 1.2)
  C.post(rng, { kind = "banded", bands = 1, h = real(40) })
  at(2.6, 0, function(r) return C.post(r, { kind = "sisal", h = real(40) }) end)(rng)
  return {}
end, { lx = 1.3 })
add("H1b shared platform", 7.4, 22.0, function(rng)
  C.post(rng, { kind = "sisal", h = real(60) })
  at(2.6, 0, function(r) return C.post(r, { kind = "banded", bands = 1, h = real(40) }) end)(rng)
  at(1.3, real(40), function(r) return C.shelf(r, { kind = "plain", w = real(70) }) end)(rng)
  return {}
end, { lx = 1.3 })
add("H2 wall route (runs, risers)", 12.8, 21.4, function(rng)
  return C.route(rng, { { 0, 0 }, { 2.4, 0 }, { 2.4, 1.8 }, { 4.6, 1.8 } })
end, { lx = 2.3 })
-- pegs, steps, moons
add("C6 pegs", 1.4, 15.2, function(rng) return C.pegs(rng, 0, 0, 2.4, 2.6) end, { lx = 1.2, ly = -0.9 })
add("C7a floating steps", 6.2, 15.2, function(rng) return C.steps(rng, 0, 0, 3.0, 2.6) end, { lx = 1.5 })
add("C7b", 10.8, 15.2, function(rng) return C.steps(rng, 0, 0, 3.4, 0.9) end, { lx = 1.7 })
add("B6a half-moon", 16.0, 17.0, function(rng) return C.moon(rng, {}) end)
add("B6b", 19.0, 17.0, function(rng) return C.moon(rng, { w = real(32), carpet = false }) end)
add("B6c", 16.0, 15.2, function(rng) return C.moon(rng, { w = real(55) }) end)
-- rings and tubes on posts
add("D4a ring", 2.0, 7.0, function(rng)
  C.post(rng, { kind = "banded", bands = 1, h = real(35) })
  at(0, real(35), function(r) return C.ring(r, {}) end)(rng)
  return {}
end)
add("D4b", 5.6, 7.0, function(rng)
  C.post(rng, { kind = "plush", h = real(50) })
  at(0, real(50), function(r) return C.ring(r, { d = real(40) }) end)(rng)
  return {}
end)
add("D5a sisal tube", 9.6, 7.0, function(rng)
  C.post(rng, { kind = "sisal", h = real(45) })
  at(0, real(45), function(r) return C.tube(r, {}) end)(rng)
  return {}
end)
add("D5b", 13.6, 7.0, function(rng)
  C.post(rng, { kind = "sisal", h = real(35) })
  at(0, real(35), function(r) return C.tube(r, { w = real(50), d = real(26) }) end)(rng)
  return {}
end)
sheet("specimen-4", "cat tree specimens · 4 · connectors and newer pieces", cells, {
  { 1, 26.6, "H  sideways connectors: crossbeam, shared platform, wall route (boards and risers, copper corners)", 7 },
  { 1, 19.8, "C6 pegs (sisal, out of the wall) · C7 floating steps · B6 half-moon shelves", 7 },
  { 1, 11.4, "D4 rings (46, 40 cm) · D5 sisal tubes on posts", 7 },
}, {
  { 7.4 + 1.3, 22.0 + real(40) + real(3.5), "loaf" },
  { 2.0, 7.0 + real(35) + real(3), "curl" },
  { 9.6, 7.0 + real(45) + real(22), "loaf", -1 },
  { 16.0, 15.2 + real(3) + real(4.5) * 0.4, "loaf" },
})

-- ---------------------------------------------------------------- sheet 3: a hand-placed gym in the margin
-- The column of florilegium-grow.tex (A4, 68 mm left margin): x 0.3 .. 6.3 cm (1.2 m at 1:20),
-- text from 6.8 cm, the footer band below 1.75 cm. Three zones, heavy to light as it rises:
-- the floor tower (wide, posts, condo, hammock), the wall (shelves, bridge, hexes, bubble),
-- and the top (sparse: a pad, a small shelf, chains of dot steps thinning out).
cells = {}
local pr = real(C.DIM.post_d) / 2
local cats = {}
-- a cat walking at spot s = { x, y, "walk", angle }: it faces the way the chain or bridge climbs
local function walker(s, back)
  local a, f = s[4], 1
  if back then a = a + 180 end
  if a > 90 or a < -90 then a, f = a - 180, -1 end
  cats[#cats + 1] = { s[1], s[2], "walk", f, a }
end
add("", 0, 0, function()
  for y = 26.6, 3.2, -0.52 do
    local x1 = (math.floor(y * 7) % 9 == 0) and 15.5 or 18.9
    ink.moveto(6.8, y) ink.lineto(x1, y) ink.stroke({ 0.86, 0.86, 0.86 }, 2.6)
  end
  return {}
end)
add("", 0, 0, function(rng)
  local fy = 0.6
  local top = fy + real(C.DIM.base_t)
  local st = real(C.DIM.shelf_t)
  -- 1. the floor tower: three posts tied together by crossbeams and shared platforms;
  -- the middle post runs up through the platforms
  local P1, P2, P3 = 0.85, 3.0, 5.3
  local yL1, yL2 = top + 3.3, top + 6.0                  -- platform heights
  C.beam(rng, P1, 2.75, P2, 2.75)
  C.beam(rng, P2, 1.9, P3, 1.9)
  at(P1, top, function(r) return C.post(r, { kind = "banded", bands = 3, h = 8.8 }) end)(rng)
  at(P2, top, function(r) return C.post(r, { kind = "sisal", h = 7.75 }) end)(rng)
  at(P3, top, function(r) return C.post(r, { kind = "banded", bands = 1, h = 3.3 }) end)(rng)
  at(3.15, fy, function(r) return C.base(r, { w = real(112) }) end)(rng)
  C.hammock(rng, P1 + pr, yL2 - 1.9, P2 - pr, yL2 - 1.9)
  at(4.27, yL1, function(r) return C.shelf(r, { kind = "plain", w = real(67) }) end)(rng)
  at(1.95, yL2, function(r) return C.shelf(r, { kind = "plain", w = real(66) }) end)(rng)
  at(5.0, yL1 + st, function(r) return C.condo(r, { holes = { "arch" } }) end)(rng)
  at(5.0, yL1 + st + real(36) + real(1), function(r) return C.bowl(r, { kind = "basket", scallop = true, r = real(17) }) end)(rng)
  at(3.0, top + 7.75, function(r) return C.ring(r, { d = real(42) }) end)(rng)
  at(1.1, top + 8.8, function(r) return C.tube(r, { w = real(30) }) end)(rng)
  at(5.75, yL1, function(r) return C.ball(r, { kind = "pom", L = real(26) }) end)(rng)
  cats[#cats + 1] = { 1.95, yL2 - 1.9 - 0.75, "curl" }                       -- in the hammock
  cats[#cats + 1] = { 4.2, top, "sit" }                                       -- under the platform
  cats[#cats + 1] = { 1.9, yL2 + st, "loaf", -1 }                             -- on the upper platform
  cats[#cats + 1] = { 5.0, yL1 + st + real(36) + real(9), "curl", -1 }        -- in the basket on the condo
  cats[#cats + 1] = { 1.0, top + 8.8 + real(22), "sit" }                     -- on the tube
  cats[#cats + 1] = { 3.0, top + 7.75 + real(3), "curl", -1 }               -- in the ring
  -- 2. the wall: a board route from beside the pad (run, riser, run), a hex on a short post
  -- on the upper run, a shallow rope bridge left to a half-moon shelf, a bubble, a second hex
  local yR1, yR2 = 9.9, 12.2
  local rt = C.route(rng, { { 4.3, yR1 }, { 5.9, yR1 }, { 5.9, yR2 }, { 4.35, yR2 } })
  cats[#cats + 1] = { 4.75, yR1, "sit", -1 }
  at(5.2, yR2, function(r) return C.post(r, { kind = "sisal", h = 1.65 }) end)(rng)
  local R = real(C.DIM.hex_w) / 2
  local hA = { 4.85, yR2 + 1.65 + 0.866 * R }
  local hB = { hA[1] - 1.5 * R, hA[2] + 0.866 * R }
  at(hA[1], hA[2], function(r) return C.hex(r, {}) end)(rng)
  at(hB[1], hB[2], function(r) return C.hex(r, {}) end)(rng)
  cats[#cats + 1] = { hB[1], hB[2] - 0.866 * R + real(3.5), "sit", -1 }
  at(1.3, 12.0, function(r) return C.moon(r, { w = real(40) }) end)(rng)
  local br = C.bridge(rng, 2.25, 12.0 + real(12), 3.95, yR2, { sag = 0.3 })
  walker(br.spots[2], true)
  cats[#cats + 1] = { 1.4, 12.0 + real(7.5), "loaf" }
  at(1.35, 14.95, function(r) return C.bubble(r, { r = real(18) }) end)(rng)
  cats[#cats + 1] = { 1.35, 14.95 - real(4) - real(14), "curl" }
  -- 3. the top, sparse and light: pegs and small half-moons, thinning out
  local hBtop = hB[2] + 0.866 * R
  local m1 = { 4.5, 20.6 }
  C.steps(rng, hB[1] + 1.0, hBtop + 0.3, m1[1] - 1.1, m1[2] + 0.2)
  at(m1[1], m1[2], function(r) return C.moon(r, { w = real(34) }) end)(rng)
  at(m1[1] + 0.55, m1[2], function(r) return C.ball(r, { kind = "sisal", L = real(22) }) end)(rng)
  cats[#cats + 1] = { m1[1] - 0.1, m1[2] + real(8), "sit", -1 }
  local m2 = { 1.7, 23.9 }
  C.pegs(rng, m1[1] - 1.2, m1[2] + 1.2, m2[1] + 0.9, m2[2] + 0.2)
  at(m2[1], m2[2], function(r) return C.moon(r, { w = real(30), carpet = false }) end)(rng)
  C.dots(rng, m2[1] + 0.5, m2[2] + 1.0, 3.3, 27.9, { taper = true, d = real(10) })
  -- the footer, on the floor: a long base, a curved lounger, a short scratching post with a pad
  at(10.0, fy, function(r) return C.base(r, { w = real(110) }) end)(rng)
  at(9.2, top, function(r) return C.wave(r, { w = real(48) }) end)(rng)
  at(11.8, top, function(r) return C.post(r, { kind = "sisal", h = real(22) }) end)(rng)
  at(11.8, top + real(22), function(r) return C.pad(r, { w = real(30) }) end)(rng)
  cats[#cats + 1] = { 9.2, top + real(3) + real(5), "curl", -1 }
  return {}
end)
sheet("specimen-3", "", cells, { { 0.3, 28.8, "hand-placed test at margin size (A4, 68 mm margin, 1:20) — floor tower, wall, sparse top", 7 } }, cats)

-- ---------------------------------------------------------------- generated pages, one per seed
local compose = dofile(root .. "/tools/cattree/compose.lua")
for seed = 1, 6 do
  cells = {}
  add("", 0, 0, function()
    for y = 26.6, 3.2, -0.52 do
      local xe = (math.floor(y * 7) % 9 == 0) and 15.5 or 18.9
      ink.moveto(6.8, y) ink.lineto(xe, y) ink.stroke({ 0.86, 0.86, 0.86 }, 2.6)
    end
    return {}
  end)
  local gen = {}
  add("", 0, 0, function()
    local c = compose.compose(C, ink, seed, { 0.3, 0.6, 6.3, 28.6 })
    for _, x in ipairs(c) do gen[#gen + 1] = x end
    return {}
  end)
  sheet("seed-" .. seed, "", cells, { { 0.3, 28.9, "generated (faked grammar), seed " .. seed, 7 } }, gen)
end

-- ---------------------------------------------------------------- initials (outlines from a system font: no TeX here)
do
  local gfile = root .. "/scratch/glyphs.lua"
  local f = io.open(gfile)
  if f then
    f:close()
    kpse = { find_file = function(n) return n end }
    fonts = { handlers = { otf = { readers = { loadshapes = function() return dofile(gfile) end } } } }
    local initial = require("initial")
    cells = {}
    local letters = { "A", "T", "C", "M", "H", "W", "S", "O" }
    for i, L in ipairs(letters) do
      local S = 4.0
      local col_, row = (i - 1) % 4, (i - 1) // 4
      add(L, 1.0 + col_ * 4.9, 18.5 - row * 6.0, function(rng)
        local ok, err = initial.draw(rng, S, L, { font = "georgia", decorate = C.initial })
        if not ok then io.stderr:write(tostring(err) .. "\n") end
        return {}
      end, { lx = S / 2, ly = -0.5 })
    end
    add("the flower initial, for comparison", 1.0, 5.0, function(rng) initial.draw(rng, 4.0, "A", { font = "georgia" }) return {} end, { lx = 2.0, ly = -0.5 })
    add("at text size (2 lines)", 7.5, 7.0, function(rng) initial.draw(rng, 1.4, "T", { font = "georgia", decorate = C.initial }) return {} end, { lx = 0.7, ly = -0.5 })
    sheet("initials", "cat initials (outlines from Georgia Bold for this preview; LaTeX uses Latin Modern)", cells, {})
  end
end

-- ---------------------------------------------------------------- cats
cells = {}
local coats = { "solid", "tabby", "tux", "pale" }
local K = 1.8                                          -- 1.8 x margin size
local rows_ = { { "sit", 23.8 }, { "walk", 19.6 }, { "loaf", 16.4 }, { "curl", 13.9 } }
for _, rw in ipairs(rows_) do
  for c_, coat in ipairs(coats) do
    add(rw[1] .. " · " .. coat, 3.0 + (c_ - 1) * 4.9, rw[2], function(rng)
      ink.push() ink.scale(K) C.cat(rng, rw[1], 1, nil, { coat = coat }) ink.pop() return {}
    end, { ly = -0.4 })
  end
end
-- the lively ones, on their pieces
add("meow (on a pad)", 2.6, 7.6, function(rng)
  ink.push() ink.scale(K) C.pad(rng, { w = real(34) }) ink.translate(0, real(7)) C.cat(rng, "meow", 1, nil, { coat = "tabby" }) ink.pop() return {}
end, { ly = -0.5 })
add("bat (at a toy)", 7.0, 7.6, function(rng)
  ink.push() ink.scale(K)
  ink.push() ink.translate(real(14), real(52)) C.ball(rng, { kind = "pom", L = real(16) }) ink.pop()
  ink.moveto(real(4), real(52)) ink.lineto(real(24), real(52)) ink.stroke(ink.tone(0.3), 0.6)
  C.cat(rng, "bat", 1, nil, { coat = "solid" }) ink.pop() return {}
end, { ly = -0.5 })
add("stretch", 12.0, 7.6, function(rng)
  ink.push() ink.scale(K) C.cat(rng, "stretch", 1, nil, { coat = "tux" }) ink.pop() return {}
end, { ly = -0.5 })
add("claw (at a post)", 17.4, 7.6, function(rng)
  ink.push() ink.scale(K)
  ink.push() ink.translate(real(12) + real(4.5), 0) C.post(rng, { kind = "sisal", h = real(55) }) ink.pop()
  C.cat(rng, "claw", 1, nil, { coat = "blue" }) ink.pop() return {}
end, { ly = -0.5 })
add("drape (over a shelf's end)", 3.6, 3.0, function(rng)
  ink.push() ink.scale(K)
  C.shelf(rng, { kind = "plain", w = real(50) })
  ink.push() ink.translate(real(25) - real(14), real(3.5)) C.cat(rng, "drape", 1, nil, { coat = "tabby" }) ink.pop()
  ink.pop() return {}
end, { ly = -1.3 })
add("peek (from a condo's hole)", 10.0, 1.6, function(rng)
  ink.push() ink.scale(K)
  C.condo(rng, { holes = { "round" } })
  ink.push() ink.translate(0, real(36) * 0.5 - real(10) + real(1)) C.peek(rng, { coat = "solid" }) ink.pop()
  ink.pop() return {}
end, { ly = -0.4 })
local poses = { "sit", "walk", "meow", "stretch", "loaf", "claw" }
local coats2 = { "blue", "solid", "tux", "tabby", "pale", "solid" }
for i, pz in ipairs(poses) do
  add(i == 1 and "at margin size (1:20)" or "", 14.6 + ((i - 1) % 3) * 2.2, 3.4 - ((i - 1) // 3) * 2.0, function(rng)
    C.cat(rng, pz, 1, nil, { coat = coats2[i] }) return {}
  end, { lx = 2.2, ly = -0.45 })
end
sheet("cats", "cats · poses × coats (1.8 × margin size), lively poses on their pieces, and at margin size", cells, {})

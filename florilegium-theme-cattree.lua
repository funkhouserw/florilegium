-- florilegium-theme-cattree.lua -- a theme for florilegium: a cat gym instead of a plant.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- Work in progress (CATTREE-PLAN.md, phase 1): the pieces only, drawn with the
-- same ink as the flowers (wash, mottle, lifted white, pooled edges, copper for
-- fine accents). There is no composition yet; specimen-cattree.lua lays the
-- pieces out on a sheet.
--
-- Sizes are real: every piece is given in real centimeters (DIM) and drawn at
-- M.SCALE (1:20 by default, 1 cm on the page = 20 cm), not scaled like a flower
-- to fill a hole: a shelf is as thick as any other shelf, only its length changes.
-- u is 10 real cm on the page, for small details. Every piece draws in its
-- own frame (cm, +y up, origin at its base or mounting point) and returns
--   { ports = { name = { x, y, dx, dy [, span = {a, b}] } }, spots = { { x, y, kind } } }
-- ports: where another piece may attach, with the outward direction; spots:
-- where a cat could be drawn later. Connectors (stairs, bridge, ramp, ladder,
-- pucks, hammock) take their two end points in the caller's frame and return
-- ports in it.

local ink = require("florilegium-ink")
local flora = require("florilegium-flora")
local M = {}
M.version = "2.0.0"

local sin, cos, sqrt, pi, abs, floor, max, min = math.sin, math.cos, math.sqrt, math.pi, math.abs, math.floor, math.max, math.min
local fmt = string.format
local tone, white = ink.tone, ink.white
local mottle, streak3 = flora.mottle, flora.streak3
local rad = pi / 180
local function lerp(a, b, t) return a + (b - a) * t end

M.SCALE = 1 / 20                            -- page cm per real cm
M.U = 10 * M.SCALE                          -- 10 real cm on the page (cm)
-- the real sizes, in cm (CATTREE-PLAN.md has the same table)
M.DIM = {
  cat = 45, cat_loaf_h = 20, cat_sit_h = 30,     -- body length without the tail
  post_d = 9, post_h = 50,
  shelf_w = 45, shelf_t = 3.5,
  pad_d = 40, base_w = 60, base_t = 5,
  puck_d = 24, puck_stride = 30,
  step_pitch = 20, rung_pitch = 15, ladder_w = 26,
  bridge_rail = 25,
  condo_w = 42, condo_h = 36, hole = 20,
  hex_w = 60,                                    -- across the corners
  bubble_d = 44, bowl_d = 40,
  wave_w = 50, wave_h = 15,
  ball_d = 9,
}
local function real(cm) return cm * M.SCALE end
M.real = real

-- ---------------------------------------------------------------- shapes
-- a rounded rectangle, counterclockwise, n points per side, the sides jittered by wob
local function rrect(rng, x0, y0, x1, y1, r, wob, n)
  n, wob = n or 6, wob or 0
  r = max(0.004, min(r, (x1 - x0) / 2, (y1 - y0) / 2))
  local pts = {}
  local function side(ax, ay, bx, by, nx, ny)
    for i = 0, n - 1 do
      local t, j = i / n, i == 0 and 0 or rng.sym(wob)
      pts[#pts + 1] = { ax + (bx - ax) * t + nx * j, ay + (by - ay) * t + ny * j }
    end
  end
  local function corner(cx, cy, a0)
    for k = 1, 2 do local a = (a0 + 30 * k) * rad pts[#pts + 1] = { cx + r * cos(a), cy + r * sin(a) } end
  end
  side(x0 + r, y0, x1 - r, y0, 0, -1) corner(x1 - r, y0 + r, -90)
  side(x1, y0 + r, x1, y1 - r, 1, 0) corner(x1 - r, y1 - r, 0)
  side(x1 - r, y1, x0 + r, y1, 0, 1) corner(x0 + r, y1 - r, 90)
  side(x0, y1 - r, x0, y0 + r, -1, 0) corner(x0 + r, y0 + r, 180)
  return pts
end

local function ellipse(cx, cy, rx, ry, n, a0, a1)
  a0, a1 = a0 or 0, a1 or 2 * pi
  local pts, full = {}, a1 - a0 >= 2 * pi - 1e-9
  local last = full and n - 1 or n
  for i = 0, last do
    local a = a0 + (a1 - a0) * i / n
    pts[#pts + 1] = { cx + rx * cos(a), cy + ry * sin(a) }
  end
  return pts
end

-- an irregular blob like ink.blob, but upright (cushions lie flat)
local function soft(rng, x, y, rx, ry, rough, n)
  n = n or 14
  local ph, ph2, out = rng.range(0, 2 * pi), rng.range(0, 2 * pi), {}
  for i = 0, n - 1 do
    local a = 2 * pi * i / n
    local k = 1 + rough * (0.6 * sin(2 * a + ph) + 0.4 * sin(3 * a + ph2)) + rough * 0.4 * rng.sym(1)
    out[#out + 1] = { x + rx * k * cos(a), y + ry * k * sin(a) }
  end
  return out
end

local function reversed(p) local o = {} for i = #p, 1, -1 do o[#o + 1] = p[i] end return o end

-- a shape is one outline {{x,y},...} or several (holes wound the other way)
local function multi(s) return type(s[1][1]) == "table" end
local function trace(s, smooth)
  for _, p in ipairs(multi(s) and s or { s }) do
    if smooth then ink.smooth(p, true, 0.6) else ink.poly(p, true) end
  end
end
local function bbox(s)
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, p in ipairs(multi(s) and s or { s }) do
    for _, q in ipairs(p) do
      x0, y0, x1, y1 = min(x0, q[1]), min(y0, q[2]), max(x1, q[1]), max(y1, q[2])
    end
  end
  return x0, y0, x1, y1
end
local function band(x0, x1, y0, y1) ink.poly({ { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }, true) end

-- ---------------------------------------------------------------- materials
-- Light falls from the upper left: round things are darker down their right
-- side and have a lifted streak on the left; flat things a pale top edge.

-- a cylinder's shading over the box x0..x1 (inside a clip), its axis along y
local function roundness(rng, x0, y0, x1, y1, k)
  k = k or 1
  local w = x1 - x0
  band(x0 + 0.6 * w, x1 + 1, y0 - 1, y1 + 1) ink.fill(tone(0.1), 0.18 * k, true)
  band(x0 + 0.8 * w, x1 + 1, y0 - 1, y1 + 1) ink.fill(tone(0.1), 0.22 * k, true)
  local xh = x0 + 0.3 * w
  streak3(xh, y0, xh + rng.sym(0.01), lerp(y0, y1, 0.33), xh + rng.sym(0.01), lerp(y0, y1, 0.66), xh, y1,
    w * 0.34, w * 0.3, white, 0.12 * k)
  streak3(xh, y0, xh + rng.sym(0.008), lerp(y0, y1, 0.33), xh + rng.sym(0.008), lerp(y0, y1, 0.66), xh, y1,
    w * 0.12, w * 0.09, white, 0.16 * k)
end

-- Plush (carpet, faux fur): a wash, granulated, pooled at the edge.
-- o: smooth (default true), size (blotch), round (a post), top (a pale top edge)
local function plush(rng, s, t0, o)
  o = o or {}
  local sm = o.smooth ~= false
  local x0, y0, x1, y1 = bbox(s)
  local sz = o.size or min(x1 - x0, y1 - y0) * 0.4
  trace(s, sm) ink.fill(tone(t0))
  trace(s, sm) ink.clip()
    local n = max(4, min(26, floor((x1 - x0) * (y1 - y0) / (sz * sz) * 0.9)))
    mottle(rng, x0, y0, x1, y1, n, sz, t0 - 0.18, t0 + 0.2, min(40, 2 * n))
    if o.round then roundness(rng, x0, y0, x1, y1) end
    if o.top then
      local h = min(0.05, (y1 - y0) * 0.25)
      streak3(x0, y1 - h * 0.6, lerp(x0, x1, 0.33), y1 - h * 0.5, lerp(x0, x1, 0.66), y1 - h * 0.6, x1, y1 - h * 0.7,
        h, h * 0.4, white, 0.4)
    end
    trace(s, sm) ink.stroke(tone(0.06), 1.3, 0.3, true)
  ink.unclip()
end

-- Sisal over a box: a pale wash wound with fine lines. o: tone, step (cm),
-- dir "h" (the turns run across x: posts) or "v" (across y: a ramp's face),
-- round (a post: cylinder shading), coarse (rope)
local function sisal(rng, x0, y0, x1, y1, o)
  o = o or {}
  local t0 = o.tone or 0.78
  local step = o.step or 0.03
  local box = { { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }
  ink.poly(box, true) ink.fill(tone(t0))
  ink.poly(box, true) ink.clip()
    local w, h = x1 - x0, y1 - y0
    mottle(rng, x0, y0, x1, y1, max(3, min(14, floor(w * h / 0.04))), min(w, h) * 0.6, t0 - 0.2, t0 + 0.1, 0)
    local function turns(off, slant)
      if o.dir == "v" then
        local x = x0 - 2 * step + off
        while x < x1 + step do
          local j = rng.sym(step * 0.2)
          ink.moveto(x + j, y0) ink.lineto(x + j + slant, y1)
          x = x + step
        end
      else
        local y = y0 - 2 * step + off
        while y < y1 + step do
          local j = rng.sym(step * 0.2)
          ink.moveto(x0, y + j) ink.lineto(x1, y + j + slant)
          y = y + step
        end
      end
    end
    local slant = (o.dir == "v" and h or w) * (o.coarse and 0.45 or 0.18)
    turns(0, slant) ink.stroke(tone(t0 - 0.5), o.coarse and 0.35 or 0.22, 0.5, true)
    turns(step * 0.5, slant) ink.stroke(white, o.coarse and 0.4 or 0.25, 0.55)
    if o.round then roundness(rng, x0, y0, x1, y1, 1.2) end
    ink.poly(box, true) ink.stroke(tone(0.08), 1.0, 0.3, true)
  ink.unclip()
end

-- copper (wood trim, brackets): plush painted on the accent's own ramp
local function copper(rng, s, t0, o)
  ink.in_accent(function() plush(rng, s, t0 or 0.42, o) end)
end

-- a rope along points: a copper core with a lighter twist
local function rope(pts, w, o)
  o = o or {}
  ink.smooth(pts, false) ink.stroke(o.color or ink.accent(-0.2), w)
  ink.smooth(pts, false) ink.stroke(ink.accent(0.45), w * 0.4, 0.8, false, fmt("[%.2f %.2f] 0", w * 0.7, w * 1.1))
end

local function hw(c, x0, y0, x1, y1, w, op) ink.moveto(x0, y0) ink.lineto(x1, y1) ink.stroke(c, w, op) end

-- ---------------------------------------------------------------- A. posts
-- A post standing on the origin. o: h (height), d (diameter), kind = plush |
-- banded | sisal | rope, bands (banded: how many), tone
function M.post(rng, o)
  o = o or {}
  local u = M.U
  local h = o.h or real(M.DIM.post_h)
  local r = (o.d or real(M.DIM.post_d)) / 2
  local kind = o.kind or "plush"
  local body = rrect(rng, -r, 0, r, h, 0.03, 0.005, max(4, floor(h / 0.12)))
  if kind == "sisal" then
    sisal(rng, -r, 0, r, h, { round = true })
  elseif kind == "rope" then
    sisal(rng, -r, 0, r, h, { round = true, coarse = true, step = 0.075, tone = 0.72 })
  else
    plush(rng, body, o.tone or rng.range(0.3, 0.38), { round = true, size = r * 1.2 })
    if kind == "banded" then
      local nb = o.bands or rng.int(1, 3)
      for k = 1, nb do
        local c = h * (k - 0.45) / nb + rng.sym(h * 0.04)
        local bh = min(h / nb * 0.5, rng.range(1.0, 1.4) * u)
        sisal(rng, -r * 0.98, c - bh / 2, r * 0.98, c + bh / 2, { round = true })
      end
    end
  end
  -- a plush cap on top
  plush(rng, rrect(rng, -r * 1.12, h - 0.06, r * 1.12, h + 0.02, 0.03, 0, 3), 0.3, { smooth = true, size = r })
  return {
    ports = { top = { 0, h, 0, 1 }, bottom = { 0, 0, 0, -1 },
      left = { -r, h / 2, -1, 0, span = { 0, h } }, right = { r, h / 2, 1, 0, span = { 0, h } } },
    spots = { { r, h * 0.5, "scratch" } },
  }
end

-- ---------------------------------------------------------------- B. shelves
-- A shelf whose underside is centered on the origin. o: w, t (thickness),
-- kind = plain | bracket | cushion | fence, tone
function M.shelf(rng, o)
  o = o or {}
  local u = M.U
  local w = o.w or real(M.DIM.shelf_w)
  local t = o.t or real(M.DIM.shelf_t)
  local x = w / 2
  local kind = o.kind or "plain"
  local t0 = o.tone or rng.range(0.32, 0.4)
  local spots = { { 0, t, "lounge" }, { x * 0.8 * (rng.chance(0.5) and 1 or -1), t, "drape" } }
  if kind == "bracket" then
    -- a pale board with copper blocks at its ends (a wall system's shelf)
    local face = rrect(rng, -x, t, x, t + 0.15 * u, 0.01, 0, 3)
    plush(rng, face, 0.88, { smooth = false, size = t })
    plush(rng, rrect(rng, -x, 0, x, t, 0.01, 0, 6), 0.78, { smooth = false, size = t, top = true })
    local bw = 0.45 * u
    for s = -1, 1, 2 do
      local a, b = s * x - s * bw, s * x + s * 0.02
      copper(rng, rrect(rng, min(a, b), -0.25 * t, max(a, b), 1.3 * t, 0.015, 0, 3), 0.55, { smooth = false, size = t })
    end
  else
    -- the top face, seen a little from above
    plush(rng, rrect(rng, -x * 0.98, t * 0.5, x * 0.98, t + 0.18 * u, 0.04, 0.004, 8), t0 + 0.28, { size = t })
    if kind == "cushion" then
      local ch = 0.6 * u
      local c = soft(rng, 0, t + ch * 0.42, x * 0.84, ch * 0.62, 0.05, 16)
      plush(rng, c, 0.74, { size = ch * 0.7 })
      ink.smooth(ink.sample(ink.bezier3(-x * 0.6, t + ch * 0.85, -x * 0.2, t + ch * 1.0, x * 0.2, t + ch * 0.98, x * 0.55, t + ch * 0.8), 8), false)
      ink.stroke(white, 0.6, 0.6)
      spots[1] = { 0, t + ch * 0.8, "lounge" }
    elseif kind == "fence" then
      -- a railing panel along the back with square windows (cut out of the panel)
      local ph = 1.2 * u
      local outer = rrect(rng, -x * 0.92, t, x * 0.92, t + ph, 0.03, 0, 4)
      local s = { outer }
      local n = max(2, floor(w / (0.6 * u)))
      local cw = w * 0.92 / n
      for k = 1, n do
        local cx = -x * 0.92 + cw * (k - 0.5)
        s[#s + 1] = reversed(rrect(rng, cx - cw * 0.22, t + ph * 0.28, cx + cw * 0.22, t + ph * 0.78, 0.01, 0, 2))
      end
      plush(rng, s, 0.84, { smooth = false, size = ph * 0.5, top = true })
    end
    plush(rng, rrect(rng, -x, 0, x, t, 0.05, 0.006, max(6, floor(w / 0.15))), t0, { size = t * 1.2 })
  end
  return {
    ports = { top = { 0, t, 0, 1, span = { -x, x } }, under = { 0, 0, 0, -1, span = { -x, x } },
      left = { -x, t / 2, -1, 0 }, right = { x, t / 2, 1, 0 } },
    spots = spots,
  }
end

-- A round pad (a perch, or a mushroom on a trunk): underside center at the origin.
-- o: w (diameter), tone, stalk (a short stalk below)
function M.pad(rng, o)
  o = o or {}
  local u = M.U
  local rx = (o.w or real(M.DIM.pad_d)) / 2
  local t = 0.4 * u
  local t0 = o.tone or rng.range(0.28, 0.36)
  if o.stalk then
    plush(rng, rrect(rng, -0.45 * u, -0.8 * u, 0.45 * u, 0.1, 0.05, 0.004, 4), t0 - 0.06, { round = true, size = 0.2 * u })
  end
  -- flat, seen straight on: a round-ended plush slab with a pale fluffy top
  plush(rng, rrect(rng, -rx, 0, rx, t, t * 0.5, 0.004, max(6, floor(rx / 0.1))), t0, { size = t })
  local top = {}
  for k = 0, 16 do
    local x = -rx * 0.94 + 2 * rx * 0.94 * k / 16
    top[#top + 1] = { x, t + 0.02 + rng.range(0, 0.035) + 0.06 * sin(pi * k / 16) }
  end
  top[#top + 1] = { rx * 0.94, t - 0.06 } top[#top + 1] = { -rx * 0.94, t - 0.06 }
  plush(rng, top, t0 + 0.4, { size = t, top = true })
  return {
    ports = { under = { 0, 0, 0, -1 }, top = { 0, t, 0, 1, span = { -rx, rx } },
      left = { -rx, t * 0.6, -1, 0 }, right = { rx, t * 0.6, 1, 0 } },
    spots = { { 0, t + rx * 0.1, "lounge" } },
  }
end

-- A floor slab (the base of a tower): top surface at y = t.
function M.base(rng, o)
  o = o or {}
  local u = M.U
  local w, t = o.w or real(M.DIM.base_w), o.t or real(M.DIM.base_t)
  local x = w / 2
  plush(rng, rrect(rng, -x * 0.97, t * 0.6, x * 0.97, t + 0.2 * u, 0.05, 0.004, 10), 0.6, { size = t })
  plush(rng, rrect(rng, -x, 0, x, t, 0.06, 0.006, max(8, floor(w / 0.15))), o.tone or 0.28, { size = t })
  return { ports = { top = { 0, t, 0, 1, span = { -x, x } } }, spots = {} }
end

-- ---------------------------------------------------------------- C. connectors
-- in a frame along the segment (x0,y0)-(x1,y1): fn(L) draws along +x from 0 to L
local function along(x0, y0, x1, y1, fn)
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  ink.push() ink.translate(x0, y0) ink.rotate(math.atan(dy, dx) / rad)
  fn(L)
  ink.pop()
  return L
end
local function ends(x0, y0, x1, y1, extra)
  local r = { ports = { a = { x0, y0, x0 - x1, y0 - y1 }, b = { x1, y1, x1 - x0, y1 - y0 } }, spots = extra or {} }
  return r
end

-- one wall step: a round sisal puck seen face on, centered at the origin
function M.puck(rng, o)
  o = o or {}
  local r = (o.d or real(M.DIM.puck_d)) / 2
  local t0 = 0.78
  ink.circle(0, 0, r) ink.fill(tone(t0))
  ink.circle(0, 0, r) ink.clip()
    mottle(rng, -r, -r, r, r, 5, r * 0.6, t0 - 0.2, t0 + 0.1, 0)
    local k = r - 0.02
    while k > 0.02 do ink.circle(rng.sym(0.004), rng.sym(0.004), k) k = k - 0.028 end
    ink.stroke(tone(0.3), 0.22, 0.45, true)
    -- the disc's edge: a darker rim, heavier at the lower right
    ink.circle(0, 0, r) ink.stroke(tone(0.12), 2.2, 0.35, true)
    ink.circle(r * 0.05, -r * 0.05, r) ink.stroke(tone(0.1), 1.4, 0.3, true)
  ink.unclip()
  return { ports = { top = { 0, r, 0, 1 } }, spots = { { 0, r, "perch" } } }
end

-- A peg: a sisal cylinder sticking straight out of the wall at the origin, seen
-- end on, so only its round face shows (with the winding coiled on it), and a
-- soft shadow on the wall below it. o: d (diameter, 10 cm)
function M.peg(rng, o)
  o = o or {}
  local r = (o.d or real(10)) / 2
  ink.smooth(ellipse(r * 0.15, -r * 0.35, r * 1.05, r * 0.9, 16), true) ink.fill(tone(0.4), 0.18, true)
  M.puck(rng, { d = 2 * r })
  return { ports = { mount = { 0, 0, 0, 0 } }, spots = { { 0, r, "perch" } } }
end

-- a chain of pegs (or wall pucks: o.kind = "puck") from one point to another
function M.pegs(rng, x0, y0, x1, y1, o)
  o = o or {}
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local n = max(2, floor(L / (o.stride or real(30)) + 0.5) + 1)
  local spots, pts = {}, {}
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local j = (i > 0 and i < n - 1) and real(4) or 0
    pts[#pts + 1] = { x0 + dx * t + rng.sym(j), y0 + dy * t + rng.sym(j) }
  end
  for _, p in ipairs(pts) do
    ink.push() ink.translate(p[1], p[2])
    local r = M.peg(rng, { facing = o.facing or (dx >= 0 and 1 or -1) })
    ink.pop()
    spots[#spots + 1] = { p[1] + r.spots[1][1], p[2] + r.spots[1][2], "perch" }
  end
  return ends(x0, y0, x1, y1, spots)
end

-- A half-moon shelf (image 11): a rounded board on the wall, its top seen a
-- little from above, a carpet patch, a copper rib under it. Underside center at
-- the origin. o: w (45 cm), carpet
function M.moon(rng, o)
  o = o or {}
  local x = (o.w or real(45)) / 2
  local t = real(3)
  local ry = real(4.5)
  local face = { { -x, t + ry }, { x, t + ry } }
  for k = 1, 15 do local a = -pi * k / 16 face[#face + 1] = { x * cos(a), t + ry + ry * sin(a) } end
  local edge = {}
  for k = 0, 16 do local a = -pi * k / 16 edge[#edge + 1] = { x * cos(a), t + ry * 0.0 + ry * (1 + sin(a)) } end
  for k = 16, 0, -1 do local a = -pi * k / 16 edge[#edge + 1] = { x * cos(a), ry * (1 + sin(a)) } end
  -- the rib under the middle, and its wall plate
  ink.in_accent(function()                              -- a small bracket under the middle
    ink.poly({ { -real(1.2), real(1) }, { real(1.2), real(1) }, { real(1.2), -real(5) }, { -real(1.2), -real(1.5) } }, true)
    ink.fill(tone(0.5))
  end)
  plush(rng, edge, 0.6, { smooth = false, size = t * 2 })
  plush(rng, face, 0.86, { smooth = false, size = ry, top = true })
  if o.carpet ~= false then
    local c = {}
    for _, p in ipairs(face) do c[#c + 1] = { p[1] * 0.78, t + ry + (p[2] - t - ry) * 0.7 - real(0.5) } end
    plush(rng, c, 0.42, { smooth = false, size = ry * 0.5 })
  end
  return {
    ports = { top = { 0, t, 0, 1, span = { -x, x } }, left = { -x, t + ry, -1, 0 }, right = { x, t + ry, 1, 0 } },
    spots = { { 0, t + ry * 0.4, "lounge" } },
  }
end

-- Dot steps: small pucks (12 cm) in a chain from one point to another, a short
-- stride apart, that join pieces visually as the dotted chains join the
-- flowers' ornaments. Spots: a cat can step from dot to dot ("walk", with the
-- chain's angle, between two dots).
function M.dots(rng, x0, y0, x1, y1, o)
  o = o or {}
  local d = o.d or real(12)
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local n = max(2, floor(L / (o.stride or real(22)) + 0.5) + 1)
  local pts, spots = {}, {}
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local j = (i > 0 and i < n - 1) and real(3) or 0
    pts[#pts + 1] = { x0 + dx * t + rng.sym(j), y0 + dy * t + rng.sym(j) }
  end
  for i, p in ipairs(pts) do
    ink.push() ink.translate(p[1], p[2]) M.puck(rng, { d = d * (o.taper and (1 - 0.35 * (i - 1) / (n - 1)) or 1) }) ink.pop()
  end
  for i = 1, n - 1 do
    local a, b = pts[i], pts[i + 1]
    spots[#spots + 1] = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 + d / 2, "walk", math.atan(b[2] - a[2], b[1] - a[1]) / rad }
  end
  return ends(x0, y0, x1, y1, spots)
end

-- a row of pucks from one point to another, about a cat's stride apart
function M.pucks(rng, x0, y0, x1, y1, o)
  o = o or {}
  local u = M.U
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local n = max(2, floor(L / (o.stride or real(M.DIM.puck_stride))) + 1)
  local spots = {}
  for i = 0, n - 1 do
    local t = i / (n - 1)
    local x, y = x0 + dx * t + (i > 0 and i < n - 1 and rng.sym(0.4 * u) or 0), y0 + dy * t + rng.sym(0.15 * u)
    ink.push() ink.translate(x, y) M.puck(rng, o) ink.pop()
    spots[#spots + 1] = { x, y + real(M.DIM.puck_d) / 2, "perch" }
  end
  return ends(x0, y0, x1, y1, spots)
end

-- stairs (a wall system's diagonal): a pale board with copper step blocks on it
function M.stairs(rng, x0, y0, x1, y1, o)
  local u = M.U
  local t = 0.3 * u
  along(x0, y0, x1, y1, function(L)
    plush(rng, rrect(rng, 0, -t, L, 0, 0.01, 0, max(4, floor(L / 0.2))), 0.8, { smooth = false, size = t, top = true })
    local n = max(2, floor(L / real(M.DIM.step_pitch)))
    for k = 1, n do
      local c = L * (k - 0.5) / n
      copper(rng, rrect(rng, c - 0.25 * u, -0.02, c + 0.25 * u, 0.3 * u, 0.012, 0, 2), 0.55, { smooth = false, size = 0.1 })
    end
  end)
  return ends(x0, y0, x1, y1)
end

-- a sisal ramp: a plush board with a sisal face on top
function M.ramp(rng, x0, y0, x1, y1, o)
  local u = M.U
  local t = 0.35 * u
  along(x0, y0, x1, y1, function(L)
    plush(rng, rrect(rng, 0, -t, L, 0.02, 0.04, 0.004, max(4, floor(L / 0.15))), 0.28, { size = t })
    sisal(rng, 0.06, -0.02, L - 0.06, 0.15 * u, { dir = "v", step = 0.035 })
  end)
  return ends(x0, y0, x1, y1, { { (x0 + x1) / 2, (y0 + y1) / 2 + 0.3 * u, "climb" } })
end

-- a ladder: two plush rails and sisal rungs
-- A ladder hangs flat against the wall, so it is always vertical: at the upper
-- end's x, from the lower end's height to the upper end's.
function M.ladder(rng, x0, y0, x1, y1, o)
  local u = M.U
  local half = real(M.DIM.ladder_w) / 2
  local x = (y1 >= y0) and x1 or x0
  local ya, yb = min(y0, y1), max(y0, y1)
  x0, y0, x1, y1 = x, ya, x, yb
  along(x0, y0, x1, y1, function(L)
    local n = max(2, floor(L / real(M.DIM.rung_pitch)))
    for k = 1, n do
      local c = L * (k - 0.5) / n
      sisal(rng, c - 0.15 * u, -half, c + 0.15 * u, half, { dir = "v", step = 0.03 })
    end
    for s = -1, 1, 2 do
      plush(rng, rrect(rng, 0, s * half - 0.15 * u, L, s * half + 0.15 * u, 0.03, 0.003, max(4, floor(L / 0.15))), 0.26,
        { size = 0.1 * u })
    end
  end)
  return ends(x0, y0, x1, y1)
end

-- A climbing pole: a vertical sisal post from y0 to y1 at x, with half-round steps
-- up one side (side = +1 right, -1 left) about 30 cm apart, the last at the top.
function M.climb(rng, x, y0, y1, o)
  o = o or {}
  local side = o.side or 1
  local h = y1 - y0
  local r = real(M.DIM.post_d) / 2
  ink.push() ink.translate(x, y0) M.post(rng, { kind = "sisal", h = h }) ink.pop()
  local n = max(1, floor(h / real(30) + 0.5))
  local spots = {}
  for k = 1, n do
    local y = y0 + h * k / n - real(3)
    local w = real(18)
    ink.push() ink.translate(x + side * (r + w / 2 - 0.02), y) M.moon(rng, { w = w, carpet = false }) ink.pop()
    spots[#spots + 1] = { x + side * (r + w / 2), y + real(7.5), "perch" }
  end
  return { ports = { bottom = { x, y0, 0, -1 }, top = { x, y1, 0, 1 } }, spots = spots }
end

-- a rope bridge: a sagging deck of slats on two ropes, a hand rope above it, a
-- net of thin rope between them, and a copper block at each end
function M.bridge(rng, x0, y0, x1, y1, o)
  o = o or {}
  local u = M.U
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local sag = o.sag or rng.range(0.1, 0.18) * L
  if abs(dy) > 0.45 * abs(dx) and M.warn then M.warn(fmt("bridge too steep: %.0f degrees", math.atan(abs(dy), abs(dx)) / rad)) end
  local rail = real(M.DIM.bridge_rail)
  local function deck(t) return x0 + dx * t, y0 + dy * t - 4 * sag * t * (1 - t) end
  local function hand(t) return x0 + dx * t, y0 + dy * t + rail - 4 * sag * 0.55 * t * (1 - t) end
  local n = max(6, floor(L / (0.5 * u)))
  -- the net: a zigzag between the hand rope and the deck
  local nz = max(3, floor(L / (1.2 * u)))
  local zz = {}
  for k = 0, 2 * nz do
    local t = k / (2 * nz)
    local px, py
    if k % 2 == 0 then px, py = deck(t) else px, py = hand(t) end
    zz[#zz + 1] = { px, py }
  end
  ink.poly(zz, false) ink.stroke(ink.accent(0.15), 0.4, 0.85)
  -- the slats, seen edge on
  for k = 1, n - 1 do
    local px, py = deck(k / n)
    ink.push() ink.translate(px, py)
    plush(rng, rrect(rng, -0.14 * u, -0.16 * u, 0.14 * u, 0.1 * u, 0.012, 0, 2), 0.84, { smooth = false, size = 0.05 })
    ink.pop()
  end
  local dp, hp = {}, {}
  for k = 0, 24 do
    local a, b = deck(k / 24) dp[#dp + 1] = { a, b }
    local c, d = hand(k / 24) hp[#hp + 1] = { c, d }
  end
  rope(dp, 0.9) rope(hp, 0.8)
  for _, e in ipairs({ { x0, y0 }, { x1, y1 } }) do
    copper(rng, rrect(rng, e[1] - 0.2 * u, e[2] - 0.35 * u, e[1] + 0.2 * u, e[2] + rail + 0.2 * u, 0.02, 0, 3), 0.55,
      { smooth = false, size = 0.1 })
  end
  -- where a cat walks: points on the deck with the deck's slope there (degrees)
  local spots = {}
  for _, t in ipairs({ 0.3, 0.5, 0.7 }) do
    local px, py = deck(t)
    spots[#spots + 1] = { px, py, "walk", math.atan(dy - 4 * sag * (1 - 2 * t), dx) / rad }
  end
  return ends(x0, y0, x1, y1, spots)
end

-- A crossbeam between two posts (a sideways connector): a plush bar 7 cm thick,
-- centered on the line between (x0,y0) and (x1,y1). Draw it before the posts.
function M.beam(rng, x0, y0, x1, y1, o)
  o = o or {}
  local t = (o.t or real(7)) / 2
  along(x0, y0, x1, y1, function(L)
    plush(rng, rrect(rng, 0, -t, L, t, 0.03, 0.003, max(4, floor(L / 0.15))), o.tone or 0.34, { size = t * 2, top = true })
  end)
  local mx, my = (x0 + x1) / 2, (y0 + y1) / 2
  return ends(x0, y0, x1, y1, { { mx, my + t, "walk", math.atan(y1 - y0, x1 - x0) / rad } })
end

-- A wall route (image 7's system): pale boards along an orthogonal path
-- pts = {{x,y}, ...}. Horizontal runs are shelves a cat walks on (their top at
-- the path); vertical runs are risers, wider panels on the wall; copper blocks
-- at the corners and the ends. Returns the runs' spots ("walk").
function M.route(rng, pts, o)
  o = o or {}
  local t = real(3.5)
  local rw = (o.riser or real(16)) / 2
  local spots = {}
  for i = 1, #pts - 1 do
    local a, b = pts[i], pts[i + 1]
    if abs(a[2] - b[2]) < 1e-6 then                       -- a run
      local x0, x1 = min(a[1], b[1]), max(a[1], b[1])
      plush(rng, rrect(rng, x0 - rw, a[2], x1 + rw, a[2] + real(1.5), 0.01, 0, 3), 0.88, { smooth = false, size = t })
      plush(rng, rrect(rng, x0 - rw, a[2] - t, x1 + rw, a[2], 0.01, 0, max(4, floor((x1 - x0) / 0.2))), 0.78,
        { smooth = false, size = t, top = true })
      spots[#spots + 1] = { (x0 + x1) / 2, a[2], "walk", 0 }
    else                                                  -- a riser
      local y0, y1 = min(a[2], b[2]), max(a[2], b[2])
      plush(rng, rrect(rng, a[1] - rw, y0 - t, a[1] + rw, y1, 0.01, 0, max(4, floor((y1 - y0) / 0.2))), 0.84,
        { smooth = false, size = rw })
      ink.moveto(a[1] + rw * 0.6, y0) ink.lineto(a[1] + rw * 0.6, y1 - t) ink.stroke(tone(0.4), 0.3, 0.4)
    end
  end
  -- copper blocks at the corners and the ends
  for i, p in ipairs(pts) do
    copper(rng, rrect(rng, p[1] - rw * 0.45, p[2] - t * 1.2, p[1] + rw * 0.45, p[2] + t * 0.2, 0.01, 0, 2), 0.62,
      { smooth = false, size = 0.1 })
  end
  return { ports = { a = { pts[1][1], pts[1][2], -1, 0 }, b = { pts[#pts][1], pts[#pts][2], 1, 0 } }, spots = spots }
end

-- Floating steps (images 15, 19): short boards stepping along a line, each one
-- level, about a stride apart; lighter than stairs. Spots: "walk" on each step.
function M.steps(rng, x0, y0, x1, y1, o)
  o = o or {}
  local w, t = o.w or real(22), real(2.5)
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local n = max(2, floor(L / (o.stride or real(18)) + 0.5) + 1)
  local spots = {}
  for i = 0, n - 1 do
    local x, y = x0 + dx * i / (n - 1), y0 + dy * i / (n - 1)
    plush(rng, rrect(rng, x - w / 2, y - t, x + w / 2, y + real(1.2), 0.01, 0, 3), 0.84, { smooth = false, size = t, top = true })
    ink.moveto(x - w / 2, y - t) ink.lineto(x + w / 2, y - t) ink.stroke(tone(0.2), 0.3, 0.5)
    spots[#spots + 1] = { x, y + real(1.2), "walk", math.atan(dy, dx) / rad }
  end
  return ends(x0, y0, x1, y1, spots)
end

-- ---------------------------------------------------------------- D. enclosures
-- the dark inside of a hole with a plush lip around it; s = the hole's outline
local function hole(rng, s, lip)
  local x0, y0, x1, y1 = bbox(s)
  local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
  local big = {}
  for _, p in ipairs(s) do
    local dx, dy = p[1] - cx, p[2] - cy
    local d = sqrt(dx * dx + dy * dy) + 1e-9
    big[#big + 1] = { p[1] + dx / d * lip, p[2] + dy / d * lip }
  end
  plush(rng, big, 0.48, { size = lip * 2 })
  ink.smooth(s, true, 0.6) ink.fill(tone(0.05))
  ink.smooth(s, true, 0.6) ink.clip()
    mottle(rng, x0, y0, x1, y1, 4, (x1 - x0) * 0.4, 0.0, 0.16, 0)
    -- the far wall, a little lighter low down
    ink.smooth(ink.blob(rng, cx + (x1 - x0) * 0.15, y0, (x1 - x0) * 0.5, (y1 - y0) * 0.35, 0.2, 9), true)
    ink.fill(tone(0.2), 0.5)
  ink.unclip()
end

local function hole_shape(kind, cx, cy, w, h)
  if kind == "arch" then
    local p = { { cx + w / 2, cy - h / 2 } }
    for _, q in ipairs(ellipse(cx, cy + h / 2 - w / 2, w / 2, w / 2, 8, 0, pi)) do p[#p + 1] = q end
    p[#p + 1] = { cx - w / 2, cy - h / 2 }
    return p
  end
  return ellipse(cx, cy, w / 2, h / 2, 14)
end

-- A condo: a plush (or sisal-covered) box standing on the origin, with one or two
-- holes. o: w, h, holes = { "round" | "oval" | "arch", ... }, skin = plush | sisal
function M.condo(rng, o)
  o = o or {}
  local u = M.U
  local w, h = o.w or real(M.DIM.condo_w), o.h or real(M.DIM.condo_h)
  local x = w / 2
  local holes = o.holes or { rng.pick({ "round", "oval", "arch" }) }
  plush(rng, rrect(rng, -x * 0.97, h - 0.1 * u, x * 0.97, h + 0.2 * u, 0.04, 0.004, 10), 0.58, { size = 0.2 })
  if o.skin == "sisal" then
    local inset = 0.2 * u
    plush(rng, rrect(rng, -x, 0, x, h, 0.06, 0.005, 12), 0.62, { size = 0.2 })
    sisal(rng, -x + inset, inset, x - inset, h - inset, { step = 0.03, tone = 0.84 })
  else
    plush(rng, rrect(rng, -x, 0, x, h, 0.06, 0.006, 12), o.tone or rng.range(0.32, 0.4), { size = 0.25 * u })
  end
  local spots = {}
  for i, kind in ipairs(holes) do
    local hw_, hh = real(M.DIM.hole), real(M.DIM.hole)
    if kind == "oval" then hw_, hh = 1.2 * real(M.DIM.hole), 0.9 * real(M.DIM.hole) end
    if kind == "arch" then hw_, hh = real(M.DIM.hole), 1.3 * real(M.DIM.hole) end
    if #holes > 1 then hw_, hh = hw_ * 0.75, hh * 0.75 end
    local cx = #holes == 1 and rng.sym(0.12 * w) or (i == 1 and -0.22 * w or 0.24 * w)
    local cy = kind == "arch" and (hh / 2 + 0.06 * u) or h * (#holes > 1 and (i == 1 and 0.48 or 0.62) or 0.5)
    hole(rng, hole_shape(kind, cx, cy, hw_, hh), 0.15 * u)
    spots[#spots + 1] = { cx, cy, "peek" }
  end
  return {
    ports = { top = { 0, h, 0, 1, span = { -x, x } }, bottom = { 0, 0, 0, -1, span = { -x, x } },
      left = { -x, h / 2, -1, 0, span = { 0, h } }, right = { x, h / 2, 1, 0, span = { 0, h } } },
    spots = spots,
  }
end

-- A hexagonal wall module centered on the origin (flat top and bottom), seen
-- straight on: a pale front frame, six walls running back to a smaller back
-- hexagon (lit from the upper left: the top in shadow, the floor light), round
-- cut-outs in two opposite walls, a cushion on the floor.
local function hexpts(R)
  local p = {}
  for k = 0, 5 do local a = k * 60 * rad p[#p + 1] = { R * cos(a), R * sin(a) } end
  return p
end
-- half the width of a doorway between hexagons: wide enough for a cat
function M.hexdoor() return real(7.5) end
-- The hexagons of a cluster, sh = { {x, y}, ... }: for number i, the walls it shares with its
-- neighbors (a door in each, so a cat can walk the whole cluster) and one way out on a free side wall.
function M.hex_ways(sh, i, Rh)
  local doors, c = {}, sh[i]
  for j, q in ipairs(sh) do
    if j ~= i then
      local dx, dy = q[1] - c[1], q[2] - c[2]
      if dx * dx + dy * dy < (1.8 * Rh) ^ 2 * 1.05 then
        doors[floor(((math.atan(dy, dx) / rad - 30) % 360) / 60 + 0.5) % 6] = true
      end
    end
  end
  local exits, best, score = {}, nil, -1
  for k = 0, 5 do
    if not doors[k] and k ~= 1 and k ~= 4 then
      local clear = 9
      for d = 0, 5 do
        if doors[d] then clear = min(clear, min((k - d) % 6, (d - k) % 6)) end
      end
      if clear > score then best, score = k, clear end
    end
  end
  if best then exits[best] = true end
  return doors, exits
end
local WALL = { [0] = 0.64, 0.46, 0.52, 0.6, 0.8, 0.72 }   -- wall k runs from vertex k to k+1 (k=1 top, k=4 floor)
function M.hex(rng, o)
  o = o or {}
  local u = M.U
  local R = o.r or real(M.DIM.hex_w) / 2
  local b = 0.3 * u
  local Ri = R - b / 0.866
  local Rb = Ri * (o.depth or 0.6)
  local fi, bk = hexpts(Ri), hexpts(Rb)
  plush(rng, bk, 0.86, { smooth = false, size = Rb * 0.5 })
  local cuts = rng.chance(0.5) and { [0] = true, [3] = true } or { [2] = true, [5] = true }
  local doors = o.doors or {}
  if o.doors then cuts = o.exits or {} end
  for k = 0, 5 do
    local i, j = k + 1, (k + 1) % 6 + 1
    local quad = { fi[i], fi[j], bk[j], bk[i] }
    plush(rng, quad, WALL[k] + rng.sym(0.03), { smooth = false, size = (Ri - Rb) * 0.6 })
    if doors[k] then
      -- a doorway into the next hexagon: drawn with the frame, below (the wall only darkens toward it)
    elseif cuts[k] then
      local cx = (fi[i][1] + fi[j][1] + bk[i][1] + bk[j][1]) / 4
      local cy = (fi[i][2] + fi[j][2] + bk[i][2] + bk[j][2]) / 4
      local ex, ey = fi[j][1] - fi[i][1], fi[j][2] - fi[i][2]
      local el = sqrt(ex * ex + ey * ey)
      ink.push() ink.translate(cx, cy) ink.rotate(math.atan(ey, ex) / rad) ink.scale(0.3 * el, 0.3 * (Ri - Rb))
      ink.circle(0, 0, 1) ink.fill(ink.paper)
      ink.circle(0.04, -0.06, 1) ink.stroke(tone(0.3), 0.9, 0.55)
      ink.pop()
    end
  end
  -- the cushion, along the floor near the back (not over a way down)
  local fy = (fi[5][2] + bk[5][2]) / 2
  if not doors[4] then plush(rng, soft(rng, 0, fy + 0.04 * u, (Ri + Rb) / 2 * 0.62, 0.25 * u, 0.05, 14), 0.93, { size = 0.1 * u }) end
  -- the front frame (the inner hexagon wound backward: a ring)
  plush(rng, { hexpts(R), reversed(fi) }, o.tone or 0.66, { smooth = false, size = b * 2, top = true })
  ink.poly(hexpts(R), true) ink.stroke(tone(0.12), 0.35, 0.6)
  -- each doorway goes on through the frame, to the shared edge, where the neighbor's half meets it
  for k = 0, 5 do
    if doors[k] then
      local a = (k * 60 + 30) * rad
      local nx, ny, tx, ty = cos(a), sin(a), -sin(a), cos(a)
      local d0, d1 = 0.866 * (Ri - (Ri - Rb) * 0.22), 0.866 * R + 0.01
      local hw = M.hexdoor()
      local function P(d, t) return { nx * d + tx * t, ny * d + ty * t } end
      local dr = (Ri - Rb) * 0.26
      -- the rounded inner end of the opening, on the wall
      ink.push() ink.translate(nx * d0, ny * d0) ink.rotate(a / rad + 90) ink.scale(hw, dr)
      ink.circle(0, 0, 1) ink.fill(tone(0.36))
      ink.pop()
      ink.poly({ P(d0, -hw), P(d1, -hw), P(d1, hw), P(d0, hw) }, true) ink.fill(tone(0.36))
      -- the thickness of the wall: dark on the shaded side, catching the light on the other
      local lit = (tx * -0.6 + ty * 0.8) > 0 and -hw or hw
      ink.poly({ P(d0, lit), P(d1, lit), P(d1, lit * 0.8), P(d0, lit * 0.8) }, true) ink.fill(tone(0.62))
      ink.poly({ P(d0, -lit), P(d1, -lit), P(d1, -lit * 0.86), P(d0, -lit * 0.86) }, true) ink.fill(tone(0.2))
      ink.moveto(P(d0, -hw)[1], P(d0, -hw)[2]) ink.lineto(P(d1, -hw)[1], P(d1, -hw)[2])
      ink.moveto(P(d0, hw)[1], P(d0, hw)[2]) ink.lineto(P(d1, hw)[1], P(d1, hw)[2])
      ink.stroke(tone(0.12), 0.3, 0.6)
    end
  end
  local ports = {}
  for k = 0, 5 do
    local a = (k * 60 + 30) * rad
    ports["e" .. k] = { R * 0.866 * cos(a), R * 0.866 * sin(a), cos(a), sin(a) }
  end
  return { ports = ports, spots = { { 0, fy + 0.1 * u, "inside" } } }
end

-- A space bubble: a clear dome hanging under a plush ring; the ring's top is at the origin.
function M.bubble(rng, o)
  o = o or {}
  local u = M.U
  local R = o.r or real(M.DIM.bubble_d) / 2
  local t = 0.4 * u
  local x = R + 0.6 * u
  -- the dome (behind the ring)
  local dome = ellipse(0, -t, R, R, 20, pi, 2 * pi)
  dome[#dome + 1] = { R, -t + 0.02 } dome[#dome + 1] = { -R, -t + 0.02 }
  ink.smooth(dome, true, 0.6) ink.fill(tone(0.93), 0.55)
  ink.smooth(dome, true, 0.6) ink.clip()
    if o.cat then
      -- curled along the bottom of the dome, or lying with its head up, looking out
      local k = (o.cat.pose == "curl" and 0.86 or 0.68) * (R / real(19))
      ink.push() ink.translate(0, -t - R * 0.97) ink.scale(k)
      M.cat(rng.fork(), o.cat.pose, o.cat.facing, nil, { coat = o.cat.coat })
      ink.pop()
    end
    ink.smooth(ellipse(R * 0.25, -t - R * 0.95, R * 0.9, R * 0.4, 14), true) ink.fill(tone(0.55), 0.18, true)
    ink.smooth(ellipse(0, -t, R * 0.98, R * 0.2, 16), true) ink.fill(tone(0.4), 0.2, true)
    ink.smooth(dome, true, 0.6) ink.stroke(tone(0.2), 1.6, 0.3, true)
  ink.unclip()
  -- reflections: a long arc and a dot
  local arc = {}
  for k = 0, 10 do local a = (200 + 5 * k) * rad arc[#arc + 1] = { R * 0.78 * cos(a), -t + R * 0.78 * sin(a) } end
  ink.smooth(arc, false) ink.stroke(white, 1.6, 0.85)
  ink.circle(-R * 0.25, -t - R * 0.82, 0.03) ink.fill(white, 0.9)
  ink.smooth(dome, true, 0.6) ink.stroke(tone(0.25), 0.3, 0.55)
  -- the ring
  plush(rng, rrect(rng, -x * 0.97, -t * 0.4, x * 0.97, 0.18 * u, 0.04, 0.003, 8), 0.6, { size = t })
  plush(rng, rrect(rng, -x, -t, x, 0, 0.05, 0.005, 10), o.tone or 0.3, { size = t })
  return {
    ports = { top = { 0, 0, 0, 1, span = { -x, x } }, left = { -x, -t / 2, -1, 0 }, right = { x, -t / 2, 1, 0 } },
    spots = { { 0, -t - R * 0.55, "inside" } },
  }
end

-- A ring (image 18): a plush tube bent into a circle, seen face on, standing on
-- the origin (a post's top) or hung from a post's side. The hole shows the paper,
-- with the inside of the tube in shadow along its lower edge. o: d (outer, 40 cm), tube (11 cm)
function M.ring(rng, o)
  o = o or {}
  local Ro = (o.d or real(46)) / 2
  local Ri = Ro - (o.tube or real(8.5))
  local cy = Ro
  local outer = ellipse(0, cy, Ro, Ro, 28)
  local inner = reversed(ellipse(0, cy, Ri, Ri, 24))
  plush(rng, { outer, inner }, o.tone or rng.range(0.32, 0.4), { size = (Ro - Ri) * 0.8 })
  -- the inside of the tube, seen through the hole: a darker crescent at the bottom
  ink.smooth(ellipse(0, cy, Ri, Ri, 24), true) ink.clip()
    ink.smooth(ellipse(0, cy - Ri * 0.95, Ri * 1.2, Ri * 0.42, 20), true) ink.fill(tone(0.3), 0.5)
  ink.unclip()
  ink.smooth(ellipse(0, cy, Ri, Ri, 24), true) ink.stroke(tone(0.08), 0.4, 0.5)
  -- a lifted highlight on the upper left of the tube
  local hl = {}
  for k = 0, 8 do local a = (110 + 10 * k) * rad hl[#hl + 1] = { (Ro + Ri) / 2 * cos(a), cy + (Ro + Ri) / 2 * sin(a) } end
  ink.smooth(hl, false) ink.stroke(white, 1.2, 0.35)
  return { ports = { bottom = { 0, 0, 0, -1 }, top = { 0, 2 * Ro, 0, 1 } }, spots = { { 0, cy - Ri, "inside" } } }
end

-- A sisal tube lying across the top of a post (image 17): a horizontal cylinder,
-- pale wooden rings at its ends, the near end open. Its underside center at the origin.
function M.tube(rng, o)
  o = o or {}
  local x = (o.w or real(40)) / 2
  local r = (o.d or real(22)) / 2
  sisal(rng, -x, 0, x, 2 * r, { dir = "v", step = 0.03, tone = 0.8 })
  ink.poly({ { -x, 0 }, { x, 0 }, { x, r * 0.6 }, { -x, r * 0.6 } }, true) ink.fill(tone(0.12), 0.2, true)
  for s = -1, 1, 2 do
    local e = ellipse(s * x, r, r * 0.32, r, 18)
    plush(rng, e, 0.82, { size = r * 0.4 })
    if s < 0 then ink.smooth(ellipse(s * x, r, r * 0.2, r * 0.72, 16), true) ink.fill(tone(0.1)) end
  end
  return { ports = { bottom = { 0, 0, 0, -1 }, top = { 0, 2 * r, 0, 1, span = { -x, x } } },
    spots = { { 0, 2 * r, "lounge" } } }
end

-- ---------------------------------------------------------------- E. loungers
-- A bowl standing on the origin, open at the top. o: r (rim radius), kind =
-- plush | basket, scallop (a wavy rim, like a flower cup)
function M.bowl(rng, o)
  o = o or {}
  local u = M.U
  local r = o.r or real(M.DIM.bowl_d) / 2
  local d = o.depth or 0.78 * r
  local ry = 0.24 * r
  local kind = o.kind or "plush"
  local t0 = kind == "basket" and 0.72 or (o.tone or rng.range(0.28, 0.34))
  local sc = o.scallop and 0.2 * u or 0
  local function rimy(a) return d + ry * sin(a) + sc * abs(sin(3 * a)) end   -- the far rim, a > 0
  local function neary(a) return d + ry * sin(a) + sc * abs(sin(3 * a)) end  -- the near rim, a < 0
  -- the inside (the far half of the rim) in shadow
  local inside = {}
  for k = 0, 20 do local a = pi * k / 20 inside[#inside + 1] = { r * cos(a), rimy(a) } end
  for k = 1, 19 do local a = pi + pi * k / 20 inside[#inside + 1] = { r * cos(a), d + ry * 0.6 * sin(a) } end
  if kind == "basket" then
    plush(rng, inside, 0.9, { size = r * 0.3 })   -- a pale cushion inside
  else
    ink.smooth(inside, true, 0.6) ink.fill(tone(0.2))
  end
  -- the body: down from the rim's near edge and round the bottom
  local body = {}
  for k = 0, 20 do local a = pi + pi * k / 20 body[#body + 1] = { r * cos(a), neary(a) } end
  for k = 1, 19 do local a = -pi * k / 20 body[#body + 1] = { r * cos(a) * (1 - 0.1 * sin(-a)), d + d * sin(a) } end
  body = reversed(body)
  local x0, y0, x1, y1 = bbox(body)
  if kind == "basket" then
    ink.smooth(body, true, 0.6) ink.fill(tone(t0))
    ink.smooth(body, true, 0.6) ink.clip()
      mottle(rng, x0, y0, x1, y1, 6, r * 0.4, t0 - 0.2, t0 + 0.1, 0)
      -- weave: rows of short slanted strokes, alternating
      local row = 0.075
      local y, i = y0, 0
      while y < y1 + row do
        local x = x0 + (i % 2) * 0.05
        while x < x1 do ink.moveto(x, y) ink.lineto(x + 0.05, y + row * 0.8) x = x + 0.1 end
        y, i = y + row, i + 1
      end
      ink.stroke(tone(0.3), 0.35, 0.45, true)
      y, i = y0, 0
      while y < y1 + row do
        local x = x0 + ((i + 1) % 2) * 0.05
        while x < x1 do ink.moveto(x + 0.008, y + 0.01) ink.lineto(x + 0.045, y + row * 0.65) x = x + 0.1 end
        y, i = y + row, i + 1
      end
      ink.stroke(white, 0.3, 0.6)
      roundness(rng, x0, y0, x1, y1, 0.8)
      ink.smooth(body, true, 0.6) ink.stroke(tone(0.08), 1.2, 0.3, true)
    ink.unclip()
  else
    plush(rng, body, t0, { size = r * 0.35 })
  end
  -- the near lip, lifted
  local lip = {}
  for k = 0, 16 do local a = pi + pi * k / 16 lip[#lip + 1] = { r * 0.96 * cos(a), neary(a) - 0.015 } end
  ink.smooth(lip, false) ink.stroke(white, 0.9, 0.45)
  return {
    ports = { bottom = { 0, 0, 0, -1 }, left = { -r, d, -1, 0 }, right = { r, d, 1, 0 } },
    spots = { { 0, d, "curl" } },
  }
end

-- a bowl on a short arm: the arm starts at the origin (on a post's side) and runs along +x
function M.armbowl(rng, o)
  o = o or {}
  local u = M.U
  local a = o.arm or 1.5 * u
  local r = o.r or 0.9 * real(M.DIM.bowl_d) / 2
  plush(rng, rrect(rng, -0.05, -0.3 * u, a + 0.1, 0.3 * u, 0.06, 0.003, 6), 0.28, { size = 0.15 * u })
  ink.push() ink.translate(a - r * 0.15, 0.2 * u)
  local b = M.bowl(rng, { r = r, kind = o.kind, scallop = o.scallop })
  ink.pop()
  return { ports = { mount = { 0, 0, -1, 0 } }, spots = { { a - r * 0.15, b.spots[1][2], "curl" } } }
end

-- A hammock slung between two points: cloth sagging, its inside showing pale
-- along the top, copper rings at the corners.
function M.hammock(rng, x0, y0, x1, y1, o)
  o = o or {}
  local u = M.U
  local dx, dy = x1 - x0, y1 - y0
  local L = sqrt(dx * dx + dy * dy)
  local s1 = o.sag or rng.range(0.22, 0.32) * L
  local s2 = s1 + 0.8 * u
  local function c(t, s) return x0 + dx * t, y0 + dy * t - 4 * s * t * (1 - t) end
  local top, bot = {}, {}
  for k = 0, 20 do
    local t = k / 20
    local a, b = c(t, s1) top[#top + 1] = { a, b }
    local e, f = c(t, s2 * (1 - 0.15 * (1 - 4 * t * (1 - t)))) bot[#bot + 1] = { e, f }
  end
  local cloth = {}
  for _, p in ipairs(bot) do cloth[#cloth + 1] = p end
  for i = #top, 1, -1 do cloth[#cloth + 1] = top[i] end
  -- the inside, seen over the near edge
  local inner = {}
  for _, p in ipairs(top) do inner[#inner + 1] = p end
  for k = 20, 0, -1 do local t = k / 20 local a, b = c(t, s1 * 0.55) inner[#inner + 1] = { a, b + 0.04 } end
  plush(rng, inner, 0.62, { size = 0.2 })
  plush(rng, cloth, o.tone or 0.3, { size = 0.25 * u })
  ink.smooth(top, false) ink.stroke(white, 0.7, 0.5)
  for _, e in ipairs({ { x0, y0 }, { x1, y1 } }) do
    ink.circle(e[1], e[2], 0.15 * u) ink.stroke(ink.accent(-0.1), 0.7)
  end
  local mx, my = c(0.5, s1)
  return ends(x0, y0, x1, y1, { { mx, my, "curl" } })
end

-- A curved lounger (y = a x^2): a cardboard cradle, its edge striped with the
-- layers, on a low foot. The lowest point of the curve is at (0, foot).
function M.wave(rng, o)
  o = o or {}
  local u = M.U
  local w = o.w or real(M.DIM.wave_w)
  local h = o.h or real(M.DIM.wave_h)
  local T = 0.5 * u
  local foot = 0.3 * u
  local x = w / 2
  local function f(px) return foot + h * (px / x) ^ 2 end
  -- the foot
  plush(rng, rrect(rng, -x * 0.55, 0, x * 0.55, foot + 0.1 * u, 0.03, 0, 6), 0.3, { size = 0.1 })
  local n = 24
  local lower, upper = {}, {}
  for k = 0, n do local px = -x + w * k / n lower[#lower + 1] = { px, f(px) } upper[#upper + 1] = { px, f(px) + T } end
  local s = {}
  for _, p in ipairs(lower) do s[#s + 1] = p end
  for i = #upper, 1, -1 do s[#s + 1] = upper[i] end
  local t0 = 0.74
  ink.poly(s, true) ink.fill(tone(t0))
  ink.poly(s, true) ink.clip()
    mottle(rng, -x, foot, x, foot + h + T, 8, 0.25 * u, t0 - 0.2, t0 + 0.1, 0)
    for k = 1, 7 do
      local off = T * k / 8 + rng.sym(0.01)
      ink.moveto(-x, f(-x) + off)
      for j = 1, n do local px = -x + w * j / n ink.lineto(px, f(px) + off) end
    end
    ink.stroke(tone(0.3), 0.25, 0.45, true)
    for k = 1, 7 do
      local off = T * (k - 0.5) / 8
      ink.moveto(-x, f(-x) + off)
      for j = 1, n do local px = -x + w * j / n ink.lineto(px, f(px) + off) end
    end
    ink.stroke(white, 0.25, 0.5)
    ink.poly(s, true) ink.stroke(tone(0.08), 1.2, 0.35, true)
  ink.unclip()
  return { ports = { bottom = { 0, 0, 0, -1 } }, spots = { { 0, f(0) + T, "lounge" } } }
end

-- ---------------------------------------------------------------- F. toys
-- the ball itself, centered at the origin: a pom-pom (fringed) or a sisal ball
local function ball(rng, r, kind)
  if kind == "sisal" then
    ink.circle(0, 0, r) ink.fill(tone(0.76))
    ink.circle(0, 0, r) ink.clip()
      for k = -4, 4 do
        local y = k * r / 4.5
        ink.smooth(ink.sample(function(v) local a = pi * v return r * cos(a + pi), y + 0.25 * r * sin(a) end, 8), false)
      end
      ink.stroke(tone(0.3), 0.25, 0.5, true)
      roundness(rng, -r, -r, r, r, 1)
    ink.unclip()
    return
  end
  local c = soft(rng, 0, 0, r, r, 0.1, 14)
  plush(rng, c, kind == "dark" and 0.3 or 0.86, { size = r * 0.6 })
  for k = 1, 22 do
    local a = rng.range(0, 2 * pi)
    local x, y = r * 0.85 * cos(a), r * 0.85 * sin(a)
    ink.moveto(x, y) ink.lineto(x * 1.32, y * 1.32)
  end
  ink.stroke(tone(kind == "dark" and 0.2 or 0.55), 0.35, 0.7)
end

-- a ball hanging from the origin on a cord (or a spring). o: L, r, kind =
-- pom | dark | sisal, spring
-- a little mouse on a string, nose down: a body, an ear, a tail curling up
local function mouse(rng, r)
  plush(rng, ellipse(0, -r * 0.6, r * 0.7, r * 1.25, 14), 0.5, { size = r * 0.5 })
  ink.circle(r * 0.5, -r * 0.05, r * 0.32) ink.fill(tone(0.62))
  ink.circle(-r * 0.5, -r * 0.05, r * 0.32) ink.fill(tone(0.62))
  ink.circle(0, -r * 1.85, r * 0.13) ink.fill(ink.accent(0.2))
end
-- a feather: a blade with a white rib, a copper quill
local function feather(rng, r)
  local L_ = r * 4.2
  local pts = ink.blade(function(v) return r * 0.5 * sin(pi * v), -L_ * v end, 12,
    function(v) return r * 0.75 * sin(pi * v ^ 0.7) end, function(v) return r * 0.75 * sin(pi * v ^ 0.7) end)
  ink.smooth(pts, true) ink.fill(tone(0.55))
  ink.smooth(pts, true) ink.clip()
    mottle(rng, -r, -L_, r * 1.5, 0, 4, r * 0.6, 0.35, 0.72, 0)
    for k = 1, 6 do
      local v = k / 7
      local x, y = r * 0.5 * sin(pi * v), -L_ * v
      ink.moveto(x, y) ink.lineto(x + r * 0.9, y + r * 0.35)
      ink.moveto(x, y) ink.lineto(x - r * 0.9, y + r * 0.35)
    end
    ink.stroke(white, 0.2, 0.6)
  ink.unclip()
  ink.moveto(0, 0) ink.curveto(r * 0.2, -L_ * 0.3, r * 0.7, -L_ * 0.6, r * 0.2, -L_ * 0.98) ink.stroke(ink.accent(-0.05), 0.35)
end

function M.ball(rng, o)
  o = o or {}
  local u = M.U
  local L = o.L or rng.range(2.0, 3.0) * u
  local r = o.r or real(M.DIM.ball_d) / 2
  local sway = rng.sym(0.12 * u)
  local cord = {}
  for k = 0, 16 do
    local v = k / 16
    local x = sway * v * v
    if o.spring then x = x + 0.05 * sin(v * 2 * pi * 7) * (v < 0.6 and 1 or 0) end
    cord[#cord + 1] = { x, -L * v }
  end
  ink.smooth(cord, false) ink.stroke(ink.accent(-0.1), o.spring and 0.35 or 0.4)
  if o.kind == "knots" then                            -- a sisal rope with knots
    for k = 1, 3 do
      ink.push() ink.translate(sway * (k / 3) ^ 2, -L * (0.45 + 0.27 * k))
      ink.smooth(soft(rng, 0, 0, r * 0.62, r * 0.5, 0.12, 10), true) ink.fill(ink.accent(0.2))
      ink.smooth(soft(rng, 0, 0, r * 0.62, r * 0.5, 0.12, 10), true) ink.stroke(ink.accent(-0.3), 0.3, 0.7)
      ink.pop()
    end
  elseif o.kind == "bell" then                         -- a little copper bell
    ink.push() ink.translate(sway, -L)
    ink.smooth({ { -r * 0.2, 0 }, { r * 0.2, 0 }, { r * 0.5, -r * 0.8 }, { r * 0.75, -r * 1.25 }, { -r * 0.75, -r * 1.25 }, { -r * 0.5, -r * 0.8 } }, true, 0.7)
    ink.fill(ink.accent(0.05))
    ink.moveto(-r * 0.45, -r * 0.5) ink.curveto(-r * 0.4, -r * 0.8, -r * 0.5, -r, -r * 0.55, -r * 1.1) ink.stroke(white, 0.3, 0.6)
    ink.circle(0, -r * 1.38, r * 0.2) ink.fill(ink.accent(-0.35))
    ink.pop()
  elseif o.kind == "mouse" then ink.push() ink.translate(sway, -L) mouse(rng, r * 1.1) ink.pop()
  elseif o.kind == "feather" then ink.push() ink.translate(sway, -L) feather(rng, r * 0.8) ink.pop()
  else ink.push() ink.translate(sway, -L - r * 0.9) ball(rng, r, o.kind) ink.pop() end
  return { ports = { hang = { 0, 0, 0, 1 } }, spots = { { sway, -L - r, "bat" } } }
end

-- pom-poms on splaying wires (a tower's top): wires from the origin, each with a ball hanging
function M.pompoms(rng, o)
  o = o or {}
  local u = M.U
  local n = o.n or rng.int(2, 3)
  for k = 1, n do
    local a = (lerp(-55, 55, n == 1 and 0.5 or (k - 1) / (n - 1)) + rng.sym(8)) * rad
    local L = rng.range(1.8, 2.4) * u
    local ex, ey = L * sin(a), L * cos(a)
    ink.moveto(0, 0) ink.curveto(ex * 0.2, ey * 0.5, ex * 0.6, ey * 1.05, ex, ey) ink.stroke(tone(0.25), 0.35, 0.8)
    ink.push() ink.translate(ex, ey) M.ball(rng, { L = rng.range(0.6, 1.0) * u, r = 0.2 * u }) ink.pop()
  end
  return { ports = { mount = { 0, 0, 0, -1 } }, spots = {} }
end

-- A ball of yarn lying on a surface: the origin is under the ball; its strand runs along the
-- surface for run (signed: toward the edge) and hangs over the edge for drop.
function M.yarn(rng, r, run, drop, copperish)
  local sd = run >= 0 and 1 or -1
  local c = copperish and ink.accent(0.05) or tone(0.42)
  local dark = copperish and ink.accent(-0.3) or tone(0.2)
  local light = copperish and ink.accent(0.55) or tone(0.72)
  ink.smooth({ { 0, 0.01 }, { run * 0.5, 0.012 }, { run, 0.005 }, { run + sd * real(1), -drop * 0.3 },
    { run + sd * real(0.2), -drop * 0.7 }, { run + sd * real(1.8), -drop } }, false)
  ink.stroke(c, 0.5)
  ink.circle(0, r, r) ink.fill(c)
  ink.circle(0, r, r) ink.clip()
    for k = -3, 3 do
      local y = r + k * r / 3.4
      ink.moveto(-r, y - r * 0.35) ink.curveto(-r * 0.3, y + r * 0.3, r * 0.3, y + r * 0.1, r, y + r * 0.45)
    end
    ink.stroke(dark, 0.3, 0.7)
    for k = -2, 2 do
      local x = k * r / 2.6
      ink.moveto(x - r * 0.4, 0) ink.curveto(x + r * 0.15, r * 0.5, x - r * 0.1, r * 1.5, x + r * 0.45, 2 * r)
    end
    ink.stroke(light, 0.3, 0.8)
  ink.unclip()
end

-- A fishing-pole toy stuck in at an angle: a flexible wand from the origin to (dx, dy), a line
-- hanging from its tip for drop, and feathers at the end of the line.
function M.wand(rng, dx, dy, drop)
  local sd = dx >= 0 and 1 or -1
  local mx, my = dx * 0.55, dy * 0.72
  ink.taper(0, 0, mx * 0.5, my * 0.55, mx, my, dx, dy, real(1.5), real(0.5))
  ink.fill(ink.accent(-0.1))
  ink.smooth(ellipse(0, 0, real(2), real(1.2), 10), true) ink.fill(ink.accent(-0.35))
  ink.smooth({ { dx, dy }, { dx + sd * real(1.5), dy - drop * 0.35 }, { dx + sd * real(0.5), dy - drop * 0.7 }, { dx + sd * real(1.2), dy - drop } }, false)
  ink.stroke(ink.accent(0.15), 0.3)
  ink.push() ink.translate(dx + sd * real(1.2), dy - drop)
  for _, a in ipairs({ -28, 4, 34 }) do
    ink.push() ink.rotate(a + rng.sym(6)) feather(rng, real(2.1)) ink.pop()
  end
  ink.circle(0, 0, real(0.9)) ink.fill(ink.accent(-0.2))
  ink.pop()
end

-- ---------------------------------------------------------------- in the air
-- Hung from above: the origin is the piece, top = how far up the ropes run (the page's top
-- edge). swing: a plank on two ropes (origin at its top surface). sling: a hammock on two
-- ropes (origin at the middle of its top edge). basket: a bowl on three cords gathered
-- into one rope (origin at its foot). hoop: a ring on one rope (origin at its foot).
function M.hang(rng, kind, top, o)
  o = o or {}
  local u = M.U
  if kind == "swing" then
    local w = o.w or real(40)
    local t = real(3.5)
    for _, sd in ipairs({ -1, 1 }) do
      local x = sd * (w / 2 - real(3))
      rope({ { x, 0 }, { x + sd * real(0.5), top / 2 }, { x, top } }, 0.6)
    end
    plush(rng, rrect(rng, -w / 2, -t, w / 2, 0, 0.03, 0.003, 6), 0.3, { size = t })
    plush(rng, soft(rng, 0, real(1), w * 0.42, real(1.6), 0.06, 12), 0.8, { size = real(1.5) })
    for _, sd in ipairs({ -1, 1 }) do
      ink.circle(sd * (w / 2 - real(3)), -t / 2, real(1)) ink.fill(ink.accent(-0.1))
    end
  elseif kind == "sling" then
    local w = o.w or real(55)
    for _, sd in ipairs({ -1, 1 }) do rope({ { sd * w / 2, 0 }, { sd * w / 2, top / 2 }, { sd * w / 2, top } }, 0.6) end
    M.hammock(rng, -w / 2, 0, w / 2, 0, { sag = o.sag or real(13) })
  elseif kind == "basket" then
    local r = o.r or real(17)
    local d = 0.78 * r
    local kn = d + real(26)
    for _, x in ipairs({ -r * 0.92, 0, r * 0.92 }) do ink.moveto(x, d) ink.lineto(0, kn) end
    ink.stroke(ink.accent(-0.1), 0.45)
    rope({ { 0, kn }, { 0, (kn + top) / 2 }, { 0, top } }, 0.6)
    ink.circle(0, kn, real(1.2)) ink.fill(ink.accent(-0.2))
    M.bowl(rng, { kind = "basket", r = r })
  else
    local d = o.d or real(38)
    rope({ { 0, d }, { 0, (d + top) / 2 }, { 0, top } }, 0.6)
    M.ring(rng, { d = d })
  end
end

-- A ledge out of a page edge: a shelf with a copper knee brace into the edge. The origin is
-- at the wall end of its top surface; it runs w along side (+1 right, -1 left).
function M.ledge(rng, w, side)
  local t = real(3.5)
  ink.push() ink.scale(side, 1)
  -- the brace: a slim copper strut from under the shelf back to the edge, and a small wall plate
  local reach = min(w * 0.42, real(26))
  ink.taper(reach, -t, reach * 0.66, -t - reach * 0.34, reach * 0.33, -t - reach * 0.66, 0, -t - reach, real(1.6), real(2))
  ink.fill(ink.accent(-0.05))
  ink.poly({ { -0.1, -t }, { real(1.8), -t }, { real(1.8), -t - reach - real(1.5) }, { -0.1, -t - reach - real(1.5) } }, true)
  ink.fill(ink.accent(-0.1))
  plush(rng, rrect(rng, -0.1, -t, w, 0, 0.02, 0.003, 6), 0.78, { smooth = false, size = t, top = true })
  ink.pop()
end

-- A sisal mat on the wall, to scratch: origin at its foot.
function M.mat(rng, w, h)
  sisal(rng, -w / 2, 0, w / 2, h, { step = 0.03, tone = 0.8 })
  local bar = real(2)
  copper(rng, rrect(rng, -w / 2 - real(1), h - bar / 2, w / 2 + real(1), h + bar / 2, 0.01, 0, 2), 0.5, { smooth = false, size = 0.1 })
end

-- ---------------------------------------------------------------- the composition
-- A grammar in three zones, heavy to light as it rises (CATTREE-PLAN.md, "The zone
-- rule"), then florilegium-grow.lua's free-space fill: largest hole first, a piece joined by a
-- chain to somewhere a cat can already get to. Draws the gym (ink set up) and
-- returns the cats: { { x, y, pose, facing, angle } }.
-- col = { x0, y0, x1, y1 } page cm; o: foot (the footer band), field (grow.field
-- over the regions, for the fill), D (density), head (x, y of the header's fleuron)
function M.compose(C, ink, seed, col, o)
  o = o or {}
  local real = C.real
  local rng = ink.rng(seed * 7919 + 17)
  local x0, y0, x1, y1 = col[1], col[2], col[3], col[4]
  local mid = (x0 + x1) / 2
  local pr = real(C.DIM.post_d) / 2
  local st = real(C.DIM.shelf_t)
  local boxes, cats = {}, {}
  local layers = { {}, {}, {}, {}, {} }               -- 1 behind, 2 posts, 3 platforms, 4 on them, 5 front
  -- Animation (o.anim): every piece is an event, in the order the gym was built
  -- (bottom up); it grows from its anchor (its base), taller faster than wider. A
  -- closure is replayed at each scale with its own rng and the composition's rng
  -- restored, so the last frame is exactly the page.
  local ANCH = setmetatable({}, { __mode = "k" })
  local events, nev = o.events or {}, 0
  local GROW = { 0.25, 0.5, 0.75, 0.92 }
  local function draw(layer, fn)
    local r = rng.fork()
    nev = nev + 1
    local e = o.anim and { t0 = 0.3 + 0.11 * nev, dur = 0.4 } or nil
    if e then events[#events + 1] = e end
    local a = ANCH[fn]
    layers[layer][#layers[layer] + 1] = function()
      if not e then fn(r) return end
      local s_out, s_r = rng.save(), r.save()
      for k = 1, #GROW do
        rng.load(s_out) r.load(s_r)
        ink.tag({ e, (k - 1) / #GROW, k / #GROW })
        if a then
          local v = GROW[k]
          ink.push() ink.translate(a[1], a[2]) ink.scale(0.55 + 0.45 * v, v) ink.translate(-a[1], -a[2])
          fn(r)
          ink.pop()
        end
      end
      rng.load(s_out) r.load(s_r)
      ink.tag({ e, 1 })
      fn(r)
      ink.tag(nil)
    end
  end
  local function at(x, y, fn)
    local f = function(r) ink.push() ink.translate(x, y) fn(r) ink.pop() end
    ANCH[f] = { x, y }
    return f
  end
  local fld = o.field
  local function reg(a, b, c, d, tag)
    a, b, c, d = min(a, c), min(b, d), max(a, c), max(b, d)
    boxes[#boxes + 1] = { a, b, c, d, tag }
    if fld then                                       -- cover the box with discs
      local w, h = c - a, d - b
      local r = min(w, h) / 2
      if w >= h then for x = a + r, c - r + 1e-9, max(r, 0.1) do fld.disc(x, (b + d) / 2, r * 1.15, 1) end
      else for y = b + r, d - r + 1e-9, max(r, 0.1) do fld.disc((a + c) / 2, y, r * 1.15, 1) end end
    end
  end
  local bound = { x0, -1e9, x1, 1e9 }                 -- free() keeps to this rectangle
  local function free(a, b, c, d, m, ignore)
    m = m or 0.05
    a, b, c, d = min(a, c), min(b, d), max(a, c), max(b, d)
    if a < bound[1] - 0.05 or c > bound[3] + 0.05 or b < bound[2] - 0.05 or d > bound[4] + 0.05 then return false end
    if o.spill and c > x1 + 0.05 and d > o.spill[4] then return false end
    for _, q in ipairs(boxes) do
      if q[5] ~= ignore and a < q[3] - m and c > q[1] + m and b < q[4] - m and d > q[2] + m then LASTHIT = string.format("%s[%.2f,%.2f,%.2f,%.2f]vs[%.2f,%.2f,%.2f,%.2f]", q[5], q[1], q[2], q[3], q[4], a, b, c, d) return false end
    end
    return true
  end
  -- what is added after the structure keeps a gap from everything (3 cm real)
  local GAP = real(3)
  -- a chain (steps, pegs, dots) as a row of small boxes along it; free() over its
  -- middle (its ends touch what it joins)
  local function chain_boxes(ax, ay, bx, by, hw, hh)
    local L = sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
    local n = max(2, floor(L / 0.25))
    local out = {}
    for k = 0, n do
      local u = k / n
      local x, y = ax + (bx - ax) * u, ay + (by - ay) * u
      out[#out + 1] = { x - hw, y - hh, x + hw, y + hh, min(u, 1 - u) * L }
    end
    return out
  end
  local function chain_free(bs)
    for _, q in ipairs(bs) do
      if q[5] > 0.35 and not free(q[1], q[2], q[3], q[4], -GAP * 0.5) then return false end
    end
    return true
  end
  local function chain_reg(bs) for _, q in ipairs(bs) do reg(q[1], q[2], q[3], q[4], "chain") end end
  local CHW = { steps = { real(12), real(3) }, pegs = { real(6), real(6) }, dots = { real(6), real(6) }, ladder = { real(15), real(4) } }
  -- what joins two points: floating steps when nearly level, dots or pegs on a slant,
  -- a ladder when steep (dots and pegs never go straight up)
  -- by its angle: nearly level, floating steps; slanted, dots, pegs or a side-on
  -- walkway (gangway stairs, a sisal ramp); steep, nothing (a jump between staggered
  -- shelves), a pole with half-round steps or a ladder, both vertical, under the upper end
  local function chain_kind(ax, ay, bx, by)
    local a = math.deg(math.atan(abs(by - ay), abs(bx - ax)))
    if a < 22 then return "steps" end
    if a < 50 then return rng.pick({ "dots", "pegs", "stairs", "ramp", "stairs", "ramp" }) end
    if abs(by - ay) < real(50) and rng.chance(0.6) then return nil end
    return rng.chance(0.65) and "climb" or "ladder"
  end
  CHW.stairs, CHW.ramp, CHW.climb = { real(9), real(9) }, { real(9), real(9) }, { real(16), real(4) }
  -- a chain as a plan: its kind, its boxes, and how to draw it
  local function plan_chain(ax, ay, bx, by, kind)
    kind = kind or chain_kind(ax, ay, bx, by)
    local p = { kind = kind, boxes = {} }
    if not kind then return p end
    if kind == "climb" or kind == "ladder" then
      local lx, ly, hx, hy = ax, ay, bx, by
      if ay > by then lx, ly, hx, hy = bx, by, ax, ay end
      p.x, p.y0, p.y1 = hx, ly - real(4), hy + 0.35          -- up to the piece it climbs to
      p.side = lx < hx and -1 or 1
      p.boxes = chain_boxes(p.x, p.y0, p.x, p.y1, CHW[kind][1], CHW[kind][2])
    else
      p.ax, p.ay, p.bx, p.by = ax, ay, bx, by
      p.boxes = chain_boxes(ax, ay, bx, by, CHW[kind][1], CHW[kind][2])
    end
    return p
  end
  local function draw_chain(p)
    if not p.kind then return end
    if p.kind == "climb" then
      draw(5, function(r) C.climb(r, p.x, p.y0, p.y1, { side = p.side }) end)
    elseif p.kind == "ladder" then
      draw(1, function(r) C.ladder(r, p.x, p.y0, p.x, p.y1) end)
    else
      local k = p.kind
      draw(5, function(r) C[k](r, p.ax, p.ay, p.bx, p.by, { d = real(10) }) end)
    end
    chain_reg(p.boxes)
  end

  -- a reference cat: pose sizes (page cm) for the overlap test
  local CAT = { loaf = { 2.2, 1.0 }, sit = { 1.2, 1.9 }, curl = { 1.9, 0.85 }, walk = { 2.4, 1.45 },
    meow = { 1.4, 2.0 }, stretch = { 2.6, 1.3 }, bat = { 1.4, 2.0 }, drape = { 2.2, 1.0 } }
  local function cat(x, y, pose, facing, angle, inside)
    local w, h = CAT[pose][1], CAT[pose][2]
    if not inside and not free(x - w / 2, y + 0.03, x + w / 2, y + h, 0.02) then return false end
    if not inside then reg(x - w / 2, y, x + w / 2, y + h, "cat") end
    cats[#cats + 1] = { x, y, pose, facing or (rng.chance(0.5) and 1 or -1), angle }
    return true
  end
  local spots = {}                                    -- candidate cat places, chosen at the end
  if o.head then reg(o.head[1] - 1.0, o.head[2] - 0.5, o.head[1] + 1.5, o.head[2] + 1.5, "head") end
  local function spot(x, y, poses, inside, angle) spots[#spots + 1] = { x, y, poses, inside, angle } end

  -- ---------------------------------------------------------------- 1. the floor tower
  local fy = y0
  local top = fy + real(C.DIM.base_t)
  local cw = x1 - x0
  local DD = o.D or 1                                  -- density: less of everything; at 0.1 and below, the tower alone
  local wide = cw > 9                                  -- a whole page or a panorama, not a margin column
  local n = wide and floor(cw / rng.range(1.5, 1.9)) or max(3, min(5, floor(cw / 1.8) + (rng.chance(0.5) and 1 or 0)))
  if DD < 0.5 then n = max(2, n - 1) end
  local xs = {}
  local a, b = x0 + 0.5 + rng.range(0, 0.2), x1 - 0.55 - rng.range(0, 0.25)
  for i = 1, n do
    xs[i] = a + (b - a) * (i - 1) / (n - 1) + ((i > 1 and i < n) and rng.sym(0.2) or 0)
  end
  local step = real(rng.range(48, 56))
  local ncol = n
  local spine = rng.int(1, ncol)
  local claws = {}                                    -- posts a cat could scratch, at their foot
  -- the L: on a last page with room under the text, the tower carries on along the
  -- floor under it, on posts of its own (clear of the page number), as far as the space goes
  local SP = o.spill
  local Lmode = SP and SP[3] - x1 > 3.0 and SP[4] - SP[2] > 2.5
  if Lmode then
    local xL = xs[n] + rng.range(1.7, 2.3)
    while xL < SP[3] - 0.6 do
      if not (o.pnum and abs(xL - o.pnum[1]) < 1.0) then xs[#xs + 1] = xL end
      xL = xL + rng.range(1.7, 2.3)
    end
    n = #xs
    bound = { x0, -1e9, SP[3], 1e9 }
  end
  -- a little more than the box: outlines, sway and strokes reach past what they reserve
  for _, ko in ipairs(o.keepout or {}) do reg(ko[1] - real(5), ko[2] - real(5), ko[3] + real(5), ko[4] + real(5), "head") end
  if o.pnum then reg(o.pnum[1] - 0.6, o.pnum[2] - 0.25, o.pnum[1] + 0.6, o.pnum[2] + 0.45, "head") end
  local lv = {}
  -- the tower takes about half to two thirds of the column
  local maxlv = max(4, floor((y1 - top) * rng.range(0.5, 0.62) / step))
  local maxL = Lmode and max(1, floor((SP[4] - 0.9 - top) / step)) or 1
  for i = 1, n do
    if i <= ncol then lv[i] = i == spine and maxlv or rng.int(1, maxlv - 1)
    else lv[i] = rng.int(max(1, maxL - 2), maxL) end
    if wide and i % 4 == 1 then lv[i] = maxlv end       -- a tall post every so often
    for _, ko in ipairs(o.keepout or {}) do             -- no post through what must stay clear
      if xs[i] > ko[1] - 0.4 and xs[i] < ko[3] + 0.4 then
        lv[i] = min(lv[i], floor((ko[2] - top - 0.5) / step))
      end
    end
  end
  -- a post with no room under a keep-out is not built
  if o.keepout and #o.keepout > 0 then
    local xs_, lv_, ncol_ = {}, {}, 0
    for i = 1, n do
      if lv[i] >= 1 then
        xs_[#xs_ + 1], lv_[#lv_ + 1] = xs[i], lv[i]
        if i <= ncol then ncol_ = ncol_ + 1 end
      end
    end
    xs, lv, n, ncol = xs_, lv_, #xs_, ncol_
    spine = 1
    for i = 1, ncol do if lv[i] > lv[spine] then spine = i end end
  end
  -- does a level surface from xa to xb at y cross a keep-out?
  local function crosses_keepout(xa, xb, y)
    for _, ko in ipairs(o.keepout or {}) do
      if xa < ko[3] + 0.15 and xb > ko[1] - 0.15 and y + real(C.DIM.shelf_t) + real(6) > ko[2] - 0.15 and y - real(4) < ko[4] + 0.15 then return true end
    end
    return false
  end
  -- the U: tall at both ends, walked across at the top
  local U = Lmode and n > ncol + 1 and maxL >= 2 and rng.chance(0.8)
  if U and n > 0 then
    lv[n] = min(maxL, lv[spine] - 1)
    if lv[n] < 2 then U = false end
  end
  if n == 3 and lv[1] == lv[2] and lv[2] == lv[3] then lv[2] = lv[2] - 1 end
  -- platforms between neighbors, at the lower one's top; neighbors at the same level merge
  -- railings are an accent: one on a page, two on a wide one
  local nrail, maxrail = 0, wide and 2 or 1
  local function rail_ok(chance)
    if nrail < maxrail and rng.chance(chance) then nrail = nrail + 1 return true end
    return false
  end
  local plats = {}
  for i = 1, n - 1 do
    local L = min(lv[i], lv[i + 1])
    local last = plats[#plats]
    if last and last.L == L and last.j == i then
      last.j = i + 1
    else
      plats[#plats + 1] = { L = L, i = i, j = i + 1 }
    end
  end
  local ptop = {}                                     -- which posts end at a platform
  for _, p in ipairs(plats) do
    p.y = top + p.L * step
    p.xa = max(x0 + 0.02, xs[p.i] - rng.range(0.3, 0.5))
    p.xb = min(bound[3] - 0.02, xs[p.j] + rng.range(0.3, 0.5))
  end
  -- platforms keep out of the keep-outs: trim the overhang, or leave the platform out
  if o.keepout and #o.keepout > 0 then
    local kept = {}
    for _, p in ipairs(plats) do
      if crosses_keepout(p.xa, p.xb, p.y) then p.xa, p.xb = max(x0 + 0.02, xs[p.i] - pr), min(bound[3] - 0.02, xs[p.j] + pr) end
      if not crosses_keepout(p.xa, p.xb, p.y) then kept[#kept + 1] = p end
    end
    plats = kept
  end
  for _, p in ipairs(plats) do
    for k = p.i, p.j do if lv[k] == p.L then ptop[k] = true end end
  end
  -- base and posts
  local bxa, bxb = n > 0 and max(x0, xs[1] - 0.5) or x0, n > 0 and (Lmode and bound[3] or min(bound[3], xs[n] + 0.5)) or bound[3]
  -- the base, in pieces if a keep-out comes down to the floor
  local segs = { { bxa, bxb } }
  for _, ko in ipairs(o.keepout or {}) do
    if ko[2] < top + real(8) then
      local out = {}
      for _, g in ipairs(segs) do
        if ko[1] - 0.15 > g[1] then out[#out + 1] = { g[1], min(g[2], ko[1] - 0.15) } end
        if ko[3] + 0.15 < g[2] then out[#out + 1] = { max(g[1], ko[3] + 0.15), g[2] } end
      end
      segs = out
    end
  end
  for _, g in ipairs(segs) do
    if g[2] - g[1] > 0.6 then
      draw(2, at((g[1] + g[2]) / 2, fy, function(r) C.base(r, { w = g[2] - g[1] }) end))
      reg(g[1], fy, g[2], top, "base")
    end
  end
  if n >= 2 then spot(xs[1] + (xs[2] - xs[1]) / 2, top, { "sit", "loaf" }) end
  local kinds = { "banded", "sisal", "banded", "plush" }
  local posth, postbox = {}, {}                       -- each post's height and its box: a post ending alone may
  for i = 1, n do                                     -- still stop a third of a level off its level (the tops, below)
    posth[i] = lv[i] * step
    local kind = kinds[rng.int(1, #kinds)]
    if kind == "sisal" or kind == "banded" then claws[#claws + 1] = xs[i] end
    draw(2, at(xs[i], top, function(r) C.post(r, { kind = kind, bands = rng.int(1, 3), h = posth[i] }) end))
    reg(xs[i] - pr, top, xs[i] + pr, top + posth[i], "post")
    postbox[i] = boxes[#boxes]
  end
  -- more platforms between neighbors, at levels below their shared top, where they
  -- clear the platforms already there (the posts run through them)
  local more = {}
  for i = 1, n - 1 do
    for L = 1, min(lv[i], lv[i + 1]) - 1 do
      if rng.chance(0.5 * min(1, DD * 1.4)) then
        local y = top + L * step + (rng.chance(0.5) and -0.5 or 0) * step
        local xa, xb = xs[i] - rng.range(0.2, 0.4), xs[i + 1] + rng.range(0.2, 0.4)
        local ok = y > top + 1.2 and not crosses_keepout(xa, xb, y)
        for _, q in ipairs(plats) do if xa < q.xb and xb > q.xa and abs(q.y - y) < 1.0 then ok = false end end
        for _, q in ipairs(more) do if xa < q.xb and xb > q.xa and abs(q.y - y) < 1.0 then ok = false end end
        if ok then more[#more + 1] = { L = L, i = i, j = i + 1, y = y, xa = max(x0 + 0.02, xa), xb = min(bound[3] - 0.02, xb), mid = true } end
      end
    end
  end
  for _, q in ipairs(more) do plats[#plats + 1] = q end
  for _, p in ipairs(plats) do
    draw(3, at((p.xa + p.xb) / 2, p.y, function(r) C.shelf(r, { kind = p.rail and "fence" or "plain", w = p.xb - p.xa }) end))
    reg(p.xa, p.y, p.xb, p.y + st, "plat")
  end
  -- crossbeams, below the lowest platform between each pair
  for i = 1, n - 1 do
    if rng.chance(0.75) then
      local y = top + rng.range(0.9, 1.7)
      if free(xs[i] + pr, y - 0.2, xs[i + 1] - pr, y + 0.2) then
        draw(1, function(r) C.beam(r, xs[i], y, xs[i + 1], y) end)
        reg(xs[i], y - 0.18, xs[i + 1], y + 0.18, "beam")
      end
    end
  end
  -- hammocks under the high platforms
  local nham
  for _, p in ipairs(plats) do
    if p.L >= 2 and rng.chance(0.7) then
      local a, b = xs[p.i] + pr, xs[p.i + 1] - pr
      local y = p.y - rng.range(0.9, 1.3)
      -- a real hammock's size: a cat's length or two across, a cat's depth down
      local sag_ = min(real(17), 0.28 * (b - a))
      local deep = sag_ + 0.8 * C.U + real(1)
      if b - a > 1.4 and b - a < real(115) and free(a, y - deep, b, y) then
        draw(1, function(r) C.hammock(r, a, y, b, y, { sag = sag_ }) end)
        reg(a, y - deep, b, y, "hammock")
        spot((a + b) / 2, y - sag_ - real(2), { "curl" }, true)
        nham = (nham or 0) + 1
        if nham >= 2 then break end
      end
    end
  end
  -- what stands on each platform: the free stretches of its top, between the posts that run on up
  for _, p in ipairs(plats) do
    local cuts = { p.xa }
    for k = p.i, p.j do if not ptop[k] then cuts[#cuts + 1] = xs[k] - pr cuts[#cuts + 1] = xs[k] + pr end end
    cuts[#cuts + 1] = p.xb
    local best, ba, bb = 0, nil, nil
    for k = 1, #cuts - 1, 2 do
      if cuts[k + 1] - cuts[k] > best then best, ba, bb = cuts[k + 1] - cuts[k], cuts[k], cuts[k + 1] end
    end
    local py = p.y + st
    local cw, ch = real(C.DIM.condo_w), real(C.DIM.condo_h) + 0.2
    local placed = false
    if best >= cw + 0.1 and rng.chance(0.65) then
      local cx = rng.chance(0.5) and (ba + cw / 2 + 0.05) or (bb - cw / 2 - 0.05)
      if free(cx - cw / 2, py, cx + cw / 2, py + ch) then
        local holes = ({ { "round" }, { "arch" }, { "oval" }, { "round", "round" }, { "oval", "round" } })[rng.int(1, 5)]
        local skin = rng.chance(0.3) and "sisal" or nil
        draw(4, at(cx, py, function(r) C.condo(r, { holes = holes, skin = skin }) end))
        reg(cx - cw / 2, py, cx + cw / 2, py + ch, "condo")
        spot(cx, py + ch, { "loaf", "sit", "meow" })
        -- a cat peeking out of the condo's hole
        spot(cx, py + ch * 0.5, { "peek" }, true)
        placed = true
        -- a basket on the condo, sometimes
        if rng.chance(0.4) and free(cx - 0.9, py + ch, cx + 0.9, py + ch + 0.9) then
          draw(4, at(cx, py + ch, function(r) C.bowl(r, { kind = "basket", scallop = rng.chance(0.5), r = real(17) }) end))
          reg(cx - 0.9, py + ch, cx + 0.9, py + ch + 0.85, "bowl")
          spot(cx, py + ch + real(9), { "curl" }, true)
        end
      end
    end
    if not placed and best >= 1.4 and rail_ok(0.25) then p.rail = true end
    if not placed and best >= 1.4 then
      spot((ba + bb) / 2, py, { "loaf", "sit", "stretch", "meow" })
    end
    -- a cat draped over a platform's end, if nothing is right under it
    local dx_ = rng.chance(0.5) and p.xb or p.xa
    spot(dx_, p.y + st, { "drape" }, false, dx_ == p.xb and 1 or -1)
    -- a toy under one end
    if rng.chance(0.7) then
      local tx = rng.chance(0.5) and p.xa + 0.25 or p.xb - 0.25
      if free(tx - 0.15, p.y - 1.5, tx + 0.15, p.y - 0.05) then
        draw(5, at(tx, p.y, function(r) C.ball(r, { kind = rng.pick({ "pom", "sisal", "dark", "mouse", "feather", "knots", "bell" }), spring = rng.chance(0.2), L = real(rng.range(20, 28)) }) end))
        reg(tx - 0.15, p.y - 1.5, tx + 0.15, p.y, "toy")
      end
    end
  end
  -- the U's walkway, before anything else claims the space: a cushion on the far
  -- post's top (leaning toward the tower), a shelf on the side of the rightmost
  -- column post tall enough, and a level rope bridge between them
  local Udone
  local tower_bridges = {}
  if U then
    local yb = top + lv[n] * step
    local w = real(42)
    local cx = xs[n] - w / 2 + 0.35
    local k
    for i = ncol, 1, -1 do if top + lv[i] * step >= yb + 0.4 then k = i break end end
    if k and free(cx - w / 2, yb, cx + w / 2, yb + 0.45) then
      local wS = real(30)
      local sx0 = xs[k] + pr
      local bx0, bx1 = sx0 + wS, cx - w / 2 - 0.03
      if bx1 - bx0 > 1.4 and free(sx0, yb - 0.3, bx0, yb + 0.45) and free(bx0 + 0.4, yb - 0.25, bx1 - 0.4, yb + real(30), -GAP * 0.3) then
        draw(4, at(cx, yb, function(r) C.shelf(r, { kind = "cushion", w = w }) end))
        reg(cx - w / 2, yb, cx + w / 2, yb + 0.45, "cushion")
        spot(cx + 0.2, yb + real(10), { "loaf", "sit" })
        draw(3, at(sx0 + wS / 2 - 0.03, yb, function(r) C.shelf(r, { kind = "bracket", w = wS }) end))
        reg(sx0, yb - 0.3, bx0, yb + 0.45, "shelf")
        local sag = min(0.5, (bx1 - bx0) * 0.06)
        draw(5, function(r) C.bridge(r, bx0, yb + st, bx1, yb + st, { sag = sag }) end)
        tower_bridges[#tower_bridges + 1] = { bx0, yb + st, bx1, yb + st, sag }
        reg(bx0 + 0.3, yb - sag - 0.2, bx1 - 0.3, yb + real(30), "bridge")
        spot((bx0 + bx1) / 2, yb + st - sag, { "walk" }, true, 0)
        Udone = true
      end
    end
  end

  -- the tops of the posts that do not end at a platform
  local rings_, nrings = false, 0
  local cluster_ = false
  local R_sit = real(3.5)
  local tops = {}
  local function shuffle(t) for k = #t, 2, -1 do local j = rng.int(1, k) t[k], t[j] = t[j], t[k] end end
  for i = 1, n do
    local before = #tops
    if not ptop[i] and not (Udone and i == n) then
      local y = top + lv[i] * step
      -- three hexagons sharing edges, on a post, before the routes take the room: one stack and a
      -- third beside it (either way), or on a wide page a row with one up
      local clustered = false
      if not cluster_ and DD >= 0.5 and lv[i] >= 2 and rng.chance(0.7) then
        local Rh = real(C.DIM.hex_w) / 2
        local h_ = 0.866 * Rh
        local SH = {}
        for _, sd in ipairs(rng.chance(0.5) and { 1, -1 } or { -1, 1 }) do
          if bound[3] - bound[1] > 9 then SH[#SH + 1] = { { 0, 0 }, { sd * 1.5 * Rh, h_ }, { sd * 3 * Rh, 0 } } end
          SH[#SH + 1] = { { 0, 0 }, { 0, 2 * h_ }, { sd * 1.5 * Rh, h_ } }
        end
        for _, sh in ipairs(SH) do
          if clustered then break end
          local xa, xb, ya = math.huge, -math.huge, -math.huge
          for _, c_ in ipairs(sh) do xa, xb, ya = min(xa, c_[1] - Rh), max(xb, c_[1] + Rh), max(ya, c_[2] + h_) end
          local yb = y + st
          if free(xs[i] + xa, y, xs[i] + xb, yb + h_ + ya, 0.02) then
            draw(4, at(xs[i], y, function(r) C.shelf(r, { kind = "bracket", w = 1.3 * Rh }) end))
            for ci_, c_ in ipairs(sh) do
              local doors_, exits_ = C.hex_ways(sh, ci_, Rh)
              draw(4, at(xs[i] + c_[1], yb + h_ + c_[2], function(r) C.hex(r, { doors = doors_, exits = exits_ }) end))
              spot(xs[i] + c_[1], yb + c_[2] + R_sit, { "sit" }, true)
            end
            reg(xs[i] + xa, y, xs[i] + xb, yb + h_ + ya, "hex")
            tops[#tops + 1] = { xs[i], yb + h_ + ya }
            clustered, cluster_ = true, true
          end
        end
      end
      -- one topper at height y; true if it fitted. A house w wide shifts in from the page's edge as far as the
      -- post stays under it (an end post stands half a centimeter from the edge)
      local function inward(w)
        local cx = min(bound[3] - w / 2 - 0.02, max(x0 + w / 2 + 0.02, xs[i]))
        return abs(cx - xs[i]) <= w / 2 - pr - 0.05 and cx or nil
      end
      local function topper(c, y)
        if c == "pompoms" then
          if free(xs[i] - 0.8, y, xs[i] + 0.8, y + 1.3) then
            draw(4, at(xs[i], y, function(r) C.pompoms(r, {}) end))
            reg(xs[i] - 0.8, y, xs[i] + 0.8, y + 1.3, "toy")
            tops[#tops + 1] = { xs[i], y + 0.05, noroute = true } return true
          end
        elseif c == "hex" then
          -- a hexagon resting on the post's top, on a short bracket shelf
          local R = real(C.DIM.hex_w) / 2
          local cx = inward(2 * R)
          if cx and free(cx - R, y, cx + R, y + st + 1.732 * R) then
            draw(4, at(cx, y, function(r) C.shelf(r, { kind = "bracket", w = 1.3 * R }) end))
            draw(4, at(cx, y + st + 0.866 * R, function(r) C.hex(r, {}) end))
            reg(cx - R, y, cx + R, y + st + 1.732 * R, "hex")
            spot(cx, y + st + real(3.5) + 0.05, { "sit" }, true)
            tops[#tops + 1] = { cx, y + st + 1.732 * R } return true
          end
        elseif c == "ring" then
          local d = real(42)
          if nrings < 2 and free(xs[i] - d / 2, y, xs[i] + d / 2, y + d) then
            rings_, nrings = true, nrings + 1
            draw(4, at(xs[i], y, function(r) C.ring(r, { d = d }) end))
            reg(xs[i] - d / 2, y, xs[i] + d / 2, y + d, "ring")
            spot(xs[i], y + real(3), { "curl" }, true)
            tops[#tops + 1] = { xs[i], y + d } return true
          end
        elseif c == "bowl" then
          -- a basket or a plush bowl on the post's top: low, so it fits under what's above
          local cx = inward(1.8)
          if cx and free(cx - 0.9, y, cx + 0.9, y + 0.9) then
            draw(4, at(cx, y, function(r) C.bowl(r, { kind = rng.pick({ "basket", "plush" }), scallop = rng.chance(0.5), r = real(17) }) end))
            reg(cx - 0.9, y, cx + 0.9, y + 0.85, "bowl")
            spot(cx, y + real(9), { "curl" }, true)
            tops[#tops + 1] = { cx, y + 0.85 } return true
          end
        elseif c == "condo" then
          local cw, ch = real(C.DIM.condo_w), real(C.DIM.condo_h) + 0.2
          local cx = inward(cw)
          if cx and free(cx - cw / 2, y, cx + cw / 2, y + ch) then
            local holes = ({ { "round" }, { "arch" }, { "oval" } })[rng.int(1, 3)]
            draw(4, at(cx, y, function(r) C.condo(r, { holes = holes }) end))
            reg(cx - cw / 2, y, cx + cw / 2, y + ch, "condo")
            spot(cx, y + ch, { "loaf", "sit", "meow" })
            spot(cx, y + ch * 0.5, { "peek" }, true)
            tops[#tops + 1] = { cx, y + ch } return true
          end
        elseif c == "tube" then
          local w = real(30)
          if free(xs[i] - w / 2 - 0.15, y, xs[i] + w / 2 + 0.15, y + real(22)) then
            draw(4, at(xs[i], y, function(r) C.tube(r, { w = w }) end))
            reg(xs[i] - w / 2 - 0.15, y, xs[i] + w / 2 + 0.15, y + real(22), "tube")
            spot(xs[i], y + real(22), { "sit", "loaf", "meow" })
            tops[#tops + 1] = { xs[i], y + real(22) } return true
          end
        else
          local w = real(c == "pad" and 34 or 42)
          local cx = min(bound[3] - w / 2, max(x0 + w / 2, xs[i] + rng.sym(0.3)))
          if free(cx - w / 2, y, cx + w / 2, y + 0.45) then
            if c == "pad" then draw(4, at(cx, y, function(r) C.pad(r, { w = w }) end))
            else draw(4, at(cx, y, function(r) C.shelf(r, { kind = "cushion", w = w }) end)) end
            reg(cx - w / 2, y, cx + w / 2, y + 0.45, c)
            spot(cx, y + (c == "pad" and real(4) or real(10)), { "loaf", "curl", "sit" })
            tops[#tops + 1] = { cx, y + 0.45 } return true
          end
        end
        return false
      end
      -- the post may stop up to two thirds of a level lower (never below what it already carries) or higher
      -- (where the length it gains is clear), so a house fits between its neighbors and what is above
      local pb = postbox[i]
      local low = top + step / 3
      for _, q in ipairs(boxes) do
        if q ~= pb and q[5] ~= "base" and q[1] < xs[i] + pr + 0.06 and q[3] > xs[i] - pr - 0.06 and q[4] <= y + 0.01 and q[4] > top + 0.01 then low = max(low, q[4] + 0.1) end
      end
      local function at_height(f)
        local y2 = y + f * step
        if y2 < low then return nil end
        if f > 0 and not free(xs[i] - pr, y, xs[i] + pr, y2, 0.02) then return nil end
        pb[4] = y2
        return y2
      end
      local houses = { "hex", "hex", "ring", "condo", "bowl", "bowl", "tube" }
      shuffle(houses)
      if not rings_ then for k, c in ipairs(houses) do if c == "ring" then table.remove(houses, k) table.insert(houses, 1, "ring") break end end end
      -- each house in turn, at the height nearest the post's level where it fits: so a ring or a hexagon
      -- gets its chance a level's fraction down before a small tube takes the top as it stands
      local fitted = clustered
      for _, c in ipairs(clustered and {} or houses) do
        for _, f in ipairs({ 0, -1 / 3, 1 / 3, -2 / 3, 2 / 3 }) do
          local y2 = at_height(f)
          if y2 and topper(c, y2) then posth[i], fitted = y2 - top, true break end
        end
        if fitted then break end
      end
      pb[4] = top + posth[i]
      if not fitted then                              -- no house anywhere: something flat, at its level
        local flats = { "pad", "cushion", "pompoms", "tube" }
        shuffle(flats)
        for _, c in ipairs(flats) do if topper(c, y) then break end end
      end
      if #tops == before then                         -- nothing fitted: a small pad, if that fits
        local y = top + lv[i] * step
        local w = real(26)
        if free(xs[i] - w / 2, y, xs[i] + w / 2, y + 0.4) then
          draw(4, at(xs[i], y, function(r) C.pad(r, { w = w }) end))
          reg(xs[i] - w / 2, y, xs[i] + w / 2, y + 0.4, "pad")
        end
      end
    end
  end
  -- stubby posts: a third or half a level, standing on a platform or the base where it has room, each with
  -- a house on top (a hexagon, a condo, a basket or a tube), so open stretches get somewhere more to sit
  do
    local nstub, maxstub = 0, wide and 3 or 1
    local floors = { { y = top, xa = bxa, xb = bxb, base = true } }
    for _, p in ipairs(plats) do floors[#floors + 1] = { y = p.y + st, xa = p.xa, xb = p.xb } end
    for _, p in ipairs(more) do floors[#floors + 1] = { y = p.y + st, xa = p.xa, xb = p.xb } end
    local order = {}
    for k = 1, #floors do order[k] = k end
    shuffle(order)
    local R = real(C.DIM.hex_w) / 2
    local HOUSE = {                                   -- width, height of each house on a stub
      hex = { 2 * R, st + 1.732 * R }, condo = { real(C.DIM.condo_w), real(C.DIM.condo_h) + 0.2 },
      bowl = { 1.8, 0.9 }, tube = { real(30) + 0.3, real(22) },
    }
    for _, k in ipairs(order) do
      if nstub >= maxstub or DD < 0.4 then break end
      local f_ = floors[k]
      -- the free stretches of this floor, between the posts standing on it or running through it
      local cuts = { f_.xa }
      for i = 1, n do if xs[i] > f_.xa and xs[i] < f_.xb then cuts[#cuts + 1] = xs[i] - pr cuts[#cuts + 1] = xs[i] + pr end end
      cuts[#cuts + 1] = f_.xb
      local done = false
      for c = 1, #cuts - 1, 2 do
        if done then break end
        local a_, b_ = cuts[c], cuts[c + 1]
        local kinds_ = { "hex", "condo", "bowl", "tube" }
        shuffle(kinds_)
        for _, kind in ipairs(kinds_) do
          local w, hh = HOUSE[kind][1], HOUSE[kind][2]
          if b_ - a_ >= w + 0.2 and rng.chance(0.7) then
            local x = a_ + 0.1 + w / 2 + rng.range(0, b_ - a_ - w - 0.2)
            local h = step * (rng.chance(0.5) and 1 / 3 or 1 / 2)
            if free(x - w / 2, f_.y, x + w / 2, f_.y + h + hh, 0.05) then
              local y = f_.y + h
              draw(2, at(x, f_.y, function(r) C.post(r, { kind = "banded", bands = 1, h = h }) end))
              reg(x - pr, f_.y, x + pr, y, "post")
              if kind == "hex" then
                draw(4, at(x, y, function(r) C.shelf(r, { kind = "bracket", w = 1.3 * R }) end))
                draw(4, at(x, y + st + 0.866 * R, function(r) C.hex(r, {}) end))
                spot(x, y + st + real(3.5) + 0.05, { "sit" }, true)
              elseif kind == "condo" then
                local holes = ({ { "round" }, { "arch" }, { "oval" } })[rng.int(1, 3)]
                draw(4, at(x, y, function(r) C.condo(r, { holes = holes }) end))
                spot(x, y + hh, { "loaf", "sit", "meow" })
                spot(x, y + hh * 0.5, { "peek" }, true)
              elseif kind == "bowl" then
                draw(4, at(x, y, function(r) C.bowl(r, { kind = rng.pick({ "basket", "plush" }), r = real(17) }) end))
                spot(x, y + real(9), { "curl" }, true)
              else
                draw(4, at(x, y, function(r) C.tube(r, { w = real(30) }) end))
                spot(x, y + hh, { "sit", "loaf", "meow" })
              end
              reg(x - w / 2, y, x + w / 2, y + hh, kind)
              tops[#tops + 1] = { x, y + hh }
              nstub, done = nstub + 1, true
              break
            end
          end
        end
      end
    end
  end
  -- side perches on the posts at the in-between levels: a short shelf, a basket on
  -- an arm or a round pad, reaching out on whichever side has room (after the tops and stubs, so a house
  -- on a post's top gets the room first), below each post's top
  for i = 1, n do
    for k = 1, lv[i] * 2 - 1 do
      local y = top + k * step / 2 + rng.sym(0.15)
      if y > top + posth[i] - 0.3 then break end      -- a post stopped short of its level
      if rng.chance(0.75 * min(1, DD * 1.5)) then
        local sides = rng.chance(0.5) and { 1, -1 } or { -1, 1 }
        for _, sd in ipairs(sides) do
          local kind = rng.pick({ "shelf", "armbowl", "pad", "shelf" })
          local done = false
          if kind == "armbowl" then
            local r = real(17)
            local ax0, ax1 = xs[i] + sd * pr, xs[i] + sd * (pr + 0.9 + r)
            if free(min(ax0, ax1), y - 0.2, max(ax0, ax1) + (sd > 0 and r * 0.3 or 0), y + 1.0) then
              draw(4, function(r_) ink.push() ink.translate(xs[i] + sd * pr, y) ink.scale(sd, 1) C.armbowl(r_, { kind = rng.pick({ "basket", "plush" }), arm = 0.75, r = r }) ink.pop() end)
              reg(min(ax0, ax1), y - 0.2, max(ax0, ax1), y + 1.0, "armbowl")
              spot(xs[i] + sd * (pr + 0.6 + r * 0.6), y + 0.55, { "curl" }, true)
              done = true
            end
          else
            local w = real(kind == "pad" and rng.range(28, 34) or rng.range(30, 40))
            local cx = xs[i] + sd * (pr + w / 2 - 0.1)
            if free(cx - w / 2, y - 0.25, cx + w / 2, y + 0.45) then
              if kind == "pad" then draw(3, at(cx, y, function(r_) C.pad(r_, { w = w }) end))
              else
                local kd_ = rail_ok(0.12) and "fence" or rng.pick({ "plain", "cushion" })
                draw(3, at(cx, y, function(r_) C.shelf(r_, { kind = kd_, w = w }) end))
              end
              reg(cx - w / 2, y - 0.25, cx + w / 2, y + 0.45, kind)
              spot(cx, y + (kind == "pad" and real(4) or real(9)), { "loaf", "sit", "curl" })
              done = true
            end
          end
          if done then break end
        end
      end
    end
  end

  bound = { x0, -1e9, Lmode and SP[3] or x1, 1e9 }
  local T = top
  for _, q in ipairs(boxes) do if q[5] ~= "head" and q[1] < x1 then T = max(T, q[4]) end end

  -- ---------------------------------------------------------------- marks
  -- beside each heading (and \florilegiumbloom), at the column's edge: a half-moon
  -- shelf with a cat on it, meowing (a sitting cat at a bloom); left out where there
  -- is no room. These cats always come.
  local marked = {}
  for _, mk in ipairs(o.marks or {}) do
    local w = real(32)
    local x = x1 - w / 2 - 0.15
    local y = mk.y - 0.25
    for _, dy in ipairs({ 0, -0.6, 0.6, -1.2 }) do
      if free(x - w / 2, y + dy - 0.3, x + w / 2, y + dy + 2.3, -GAP) then
        y = y + dy
        draw(3, at(x, y, function(r) C.moon(r, { w = w }) end))
        reg(x - w / 2, y - 0.3, x + w / 2, y + real(7.5), "moon")
        marked[#marked + 1] = { x - 0.1, y + real(7.5), mk.kind == "heading" and "meow" or "sit" }
        break
      end
    end
  end

  -- ---------------------------------------------------------------- 2. the wall: routes
  -- CATTREE-RULES.md. Traversal first: routes up from the tower, each a chain of modules
  -- (a ladder, a D-pole, a zigzag run of identical shelves, a diagonal of steps, dots or
  -- pegs, a gangway, a level rope bridge), every module creating the landing it arrives
  -- at; the first route ends at the lookout, nothing above it; a second route and short
  -- bridges between the routes make it a network; boxes, hexes and a bubble hang off the
  -- landings as dead ends. Planned as data first, checked, then drawn in the order built.
  local in_bubbles = 0
  local function plan_wall()
    local R = real
    local mid_ = (x0 + x1) / 2
    local clears = {}                                 -- { a, b, c, d, owner landing id }
    local ups = {}                                    -- the extents of the upward modules
    local plan = {}                                   -- accepted modules, in order
    local lands = {}
    local nid = 0
    local function hits_clear(q, exempt)
      for _, c in ipairs(clears) do
        if not exempt[c[5]] and q[1] < c[3] and q[3] > c[1] and q[2] < c[4] and q[4] > c[2] then return true end
      end
      return false
    end
    local function landing(kind, cx, ytop, w)
      nid = nid + 1
      local L = { id = nid, kind = kind, cx = cx, w = w, x0 = cx - w / 2, x1 = cx + w / 2, y = ytop }
      if kind == "moon" then L.solid = { cx - w / 2, ytop - R(13), cx + w / 2, ytop }
      else L.solid = { cx - w / 2, ytop - st - R(3), cx + w / 2, ytop } end
      local cw = max(w, R(45))
      L.clear = { cx - cw / 2, ytop + 0.01, cx + cw / 2, ytop + R(30) }
      return L
    end
    -- does a module fit: its solids and its landings, against everything placed and every
    -- clearance (but the one it starts from), its landings' clearances against everything
    local DBG = os.getenv("CATDEBUG") and {} or nil
    local function why(r) if DBG then DBG[r] = (DBG[r] or 0) + 1 if os.getenv("CATDEBUG") == "2" then io.stderr:write(r .. "\n") end end return false end
    local function fits(m, cur)
      local ex = { [cur.id or -1] = true }
      local function ok(q, isclear)
        -- the column, or below the last line of text the whole width
        local xmax = (Lmode and q[4] <= SP[4]) and SP[3] or x1
        if q[1] < x0 + 0.02 or q[3] > xmax - 0.02 or q[4] > y1 + 0.05 then return why(m.kind .. ":bounds") end
        if not free(q[1], q[2], q[3], q[4], 0.02) then return why(m.kind .. (isclear and ":clear-vs-" or ":hits-") .. tostring(LASTHIT)) end
        if not isclear and hits_clear(q, ex) then return why(m.kind .. ":in-clear") end
        return true
      end
      for _, q in ipairs(m.solids) do if not ok(q) then return false end end
      for _, L in ipairs(m.land) do
        if not ok(L.solid) or not ok(L.clear, true) then return false end
        for _, q in ipairs(m.solids) do                 -- its own pieces stay out of its landings' room
          if q[1] < L.clear[3] and q[3] > L.clear[1] and q[2] < L.clear[4] - 0.05 and q[4] > L.clear[2] + 0.05 then return false end
        end
      end
      -- one way up per stretch: no two upward modules of the same kind side by side
      if m.up then
        for _, u in ipairs(ups) do
          local oy = min(m.up[4], u[4]) - max(m.up[2], u[2])
          local gx = max(u[1] - m.up[3], m.up[1] - u[3])
          if oy > R(8) and gx < R(40) and (u.kind == m.kind or gx < R(10)) then return false end
        end
      end
      return true
    end
    local function accept(m)
      -- what a walkway touches keeps clear of railings
      if m.from_ then
        m.from_.walk = true
        if m.from_.plat then m.from_.plat.rail = false end
        for _, L in ipairs(m.land) do L.walk = true end
      end
      for _, q in ipairs(m.solids) do reg(q[1], q[2], q[3], q[4], "pl") end
      for _, L in ipairs(m.land) do
        reg(L.solid[1], L.solid[2], L.solid[3], L.solid[4], "pl")
        clears[#clears + 1] = { L.clear[1], L.clear[2], L.clear[3], L.clear[4], L.id }
        lands[#lands + 1] = L
      end
      if m.up then m.up.kind = m.kind ups[#ups + 1] = m.up end
      plan[#plan + 1] = m
    end
    local function edge_x(cur, s) return s > 0 and cur.x1 or cur.x0 end
    local function inside_col(cx, w) return cx - w / 2 >= x0 + 0.03 and cx + w / 2 <= (Lmode and SP[3] or x1) - 0.03 end

    -- the modules: each builds from landing cur toward side s (+1 right, -1 left)
    local M_ = {}
    local route_target = y1
    -- One long ladder, vertical and flat on the wall, up to the next landing's underside;
    -- never two in a row. Where it is long, shelves step off it to the side at even spacing.
    function M_.ladder(cur, s, ex)
      local lx = ex - s * R(16)
      local w = R(rng.pick({ 36, 40, 44 }))
      local cx = lx - s * R(12) + s * w / 2
      if not inside_col(cx, w) then return nil end
      local rise = R(rng.range(70, 200))
      local rem = route_target - cur.y
      if rem < rise + R(60) then rise = rem end        -- a ladder that would stop just short goes all the way
      if rise < R(50) then return nil end
      local A = landing(rng.chance(0.5) and "moon" or "shelf", cx, cur.y + rise, w)
      local y1_ = A.solid[2]
      local land, half = {}, R(14)
      -- the step-offs: identical shelves, one rhythm, on one side or alternating
      local no = floor(rise / R(55)) - 1
      if no > 0 then
        local wo = R(rng.pick({ 30, 34, 38 }))
        local alt = rng.chance(0.5)
        local side = rng.chance(0.5) and 1 or -1
        for k = 1, no do
          local sd = (alt and k % 2 == 0) and -side or side
          local ox = lx + sd * (half + wo / 2 - R(1))
          if not inside_col(ox, wo) then sd = -sd ox = lx + sd * (half + wo / 2 - R(1)) end
          if inside_col(ox, wo) then
            local O = landing("shelf", ox, cur.y + rise * k / (no + 1), wo)
            O.stepoff = true
            -- its room is beside the ladder, not over it
            local c0 = sd > 0 and (lx + half + R(1)) or (lx - half - R(1) - R(45))
            O.clear = { c0, O.y + 0.01, c0 + R(45), O.y + R(30) }
            land[#land + 1] = O
          end
        end
      end
      land[#land + 1] = A
      return { kind = "ladder", land = land, solids = { { lx - half, cur.y, lx + half, y1_ } },
        up = { lx - half, cur.y, lx + half, A.y },
        draw = function() draw(1, function(r) C.ladder(r, lx, cur.y, lx, y1_) end) end }
    end
    function M_.climb(cur, s, ex)                        -- a sisal pole with half-steps, standing on the tower
      if not cur.ground then return nil end
      local px = ex - s * R(10)
      local w = R(rng.pick({ 36, 40 }))
      local cx = px - s * R(8) + s * w / 2
      if not inside_col(cx, w) then return nil end
      local A = landing("shelf", cx, cur.y + R(rng.range(65, 100)), w)
      local y1_ = A.solid[2]
      local a_, b_ = min(px - s * R(5), px - s * R(30)), max(px - s * R(5), px - s * R(30))
      return { kind = "climb", land = { A }, solids = { { min(a_, px - R(5)), cur.y, max(b_, px + R(5)), y1_ } },
        up = { min(a_, px - R(5)), cur.y, max(b_, px + R(5)), A.y },
        draw = function() draw(2, function(r) C.climb(r, px, cur.y, y1_, { side = -s }) end) end }
    end
    function M_.run(cur, s, ex)                          -- zigzag: identical shelves, one rise, two columns
      local n = rng.int(3, 4)
      local w = R(rng.pick({ 35, 40 }))
      local rise = R(rng.pick({ 25, 30 }))
      local ca = ex + s * (w / 2 + R(4))
      local cb = ca - s * (w + R(10))
      local land, ys = {}, {}
      for k = 1, n do
        local cx = (k % 2 == 1) and ca or cb
        if not inside_col(cx, w) then return nil end
        land[k] = landing("shelf", cx, cur.y + k * rise, w)
        land[k].series = true
      end
      local lo, hi = min(ca, cb) - w / 2, max(ca, cb) + w / 2
      return { kind = "run", land = land, solids = {}, up = { lo, cur.y, hi, cur.y + n * rise }, draw = function() end }
    end
    local DIAG = { steps = { { 18, 20, 22 }, 30, 48, 11, 1.2 }, dots = { { 22 }, 30, 48, 6, 6 }, pegs = { { 30 }, 22, 40, 5, 5 } }
    local function diag(kind)
      return function(cur, s, ex)
        local P = DIAG[kind]
        local stride = R(rng.pick(P[1]))
        local a = math.rad(rng.range(P[2], P[3]))
        local dx, dy = s * stride * cos(a), stride * sin(a)
        local w = R(rng.pick({ 35, 40, 45 }))
        local n
        for nn = rng.int(4, 6), 3, -1 do
          local cx = ex + (nn + 1) * dx + s * w / 2
          if inside_col(cx, w) then n = nn break end
        end
        if not n then return nil end
        local A = landing("moon", ex + (n + 1) * dx + s * w / 2, cur.y + (n + 1) * dy, w)
        local solids, pts = {}, {}
        for k = 1, n do
          local x, y = ex + k * dx, cur.y + k * dy
          pts[k] = { x, y }
          solids[#solids + 1] = { x - R(P[4]), y - R(P[5] + 2), x + R(P[4]), y + R(1.5) }
        end
        local lo, hi = min(ex, A.x0, A.x1), max(ex, A.x0, A.x1)
        return { kind = kind, from_ = cur, land = { A }, solids = solids, up = { lo, cur.y, hi, A.y },
          draw = function()
            local f, l = pts[1], pts[n]
            if kind == "steps" then draw(5, function(r) C.steps(r, f[1], f[2], l[1], l[2], { stride = stride }) end)
            elseif kind == "dots" then draw(5, function(r) C.dots(r, f[1], f[2] - R(6), l[1], l[2] - R(6), { stride = stride, d = R(12) }) end)
            else draw(5, function(r) C.pegs(r, f[1], f[2] - R(5), l[1], l[2] - R(5), { stride = stride }) end) end
          end }
      end
    end
    M_.steps, M_.dots, M_.pegs = diag("steps"), diag("dots"), diag("pegs")
    function M_.gangway(cur, s, ex)                      -- a slanted board with step blocks
      local a = math.rad(rng.range(28, 48))
      local L = R(rng.range(60, 100))
      local dx, dy = s * L * cos(a), L * sin(a)
      local w = R(rng.pick({ 36, 40 }))
      local cx = ex + dx + s * w / 2
      if not inside_col(cx, w) then return nil end
      local A = landing("shelf", cx, cur.y + dy, w)
      local solids = {}
      for k = 2, 5 do                                -- its foot rests on the landing it leaves
        local u = (k - 0.5) / 5
        local x, y = ex + dx * u, cur.y + dy * u
        solids[#solids + 1] = { x - abs(dx) / 10 - R(2), y - R(7), x + abs(dx) / 10 + R(2), y + R(5) }
      end
      return { kind = "gangway", from_ = cur, land = { A }, solids = solids, up = { min(ex, ex + dx), cur.y, max(ex, ex + dx), A.y },
        draw = function() draw(5, function(r) C.stairs(r, ex, cur.y, ex + dx, cur.y + dy) end) end,
        draw_ramp = function() draw(5, function(r) C.ramp(r, ex, cur.y, ex + dx, cur.y + dy) end) end }
    end
    function M_.ramp(cur, s, ex)                     -- a sisal ramp: the gentle climb
      local m = M_.gangway(cur, s, ex)
      if not m then return nil end
      m.kind = "ramp"
      m.draw = function() m.draw_ramp() end
      return m
    end
    function M_.bridge(cur, s, ex, gap)                  -- level rope bridge to a shelf; never low
      if cur.y - fy < R(100) then return nil end
      if abs(ex - edge_x(cur, s)) > 0.01 then return nil end   -- a bridge leaves from the end it faces
      local w = R(rng.pick({ 30, 36, 40 }))
      gap = gap or R(rng.range(40, 120))
      local cx = ex + s * (gap + w / 2)
      if not inside_col(cx, w) then return nil end
      local A = landing("shelf", cx, cur.y + R(rng.range(-6, 6)), w)
      local sag = min(R(14), gap * 0.12)
      local bx1 = ex + s * gap
      return { kind = "bridge", from_ = cur, land = { A }, bridge = true, br = { ex, cur.y, bx1, A.y, sag },
        solids = { { min(ex, bx1) + R(4), min(cur.y, A.y) - sag - R(6), max(ex, bx1) - R(4), max(cur.y, A.y) + R(27) } },
        draw = function()
          local sg = sag
          draw(5, function(r) C.bridge(r, ex, cur.y, bx1, A.y, { sag = sg }) end)
          spot((ex + bx1) / 2, (cur.y + A.y) / 2 - sag, { "walk" }, true, 0)
        end }
    end

    -- the series used on this page: two of the three slanted kinds at most
    local series = ({ { "steps", "pegs" }, { "steps", "dots" }, { "pegs", "steps" } })[rng.int(1, 3)]
    local function kinds_for(cur)
      local k = { { "run", 3 }, { "ladder", 3 }, { series[1], 3 }, { series[2], 2 }, { "gangway", 4 }, { "ramp", 4 } }
      if cur.ground then k[#k + 1] = { "climb", 2 } end
      if cur.y - fy > R(100) then k[#k + 1] = { "bridge", 1 } end
      -- weighted order, without replacement
      local out = {}
      while #k > 0 do
        local tot = 0
        for _, e in ipairs(k) do tot = tot + e[2] end
        local u, i = rng.u() * tot, 1
        while u > k[i][2] do u = u - k[i][2] i = i + 1 end
        out[#out + 1] = table.remove(k, i)[1]
      end
      -- a page's first climbs are the walkways it has not used yet
      local has = {}
      for _, m in ipairs(plan) do if m.kind then has[m.kind] = true end end
      for _, kd in ipairs(rng.chance(0.5) and { "gangway", "ramp" } or { "ramp", "gangway" }) do
        if not has[kd] then
          for i, v in ipairs(out) do if v == kd then table.remove(out, i) break end end
          table.insert(out, 1, kd)
        end
      end
      return out
    end

    -- grow a route from a landing up to about y_target; returns its landings
    local function route(start, y_target, maxmods)
      local cur, out = start, {}
      route_target = y_target
      local s = (start.cx < mid_) and 1 or -1
      local nm, lastkind, jumps_ = 0, nil, 0
      while cur.y < y_target - R(40) and nm < maxmods do
        local done = false
        for _, kind in ipairs(kinds_for(cur)) do
          if kind ~= lastkind then
            local tries_ = {}
            for _, sd in ipairs(rng.chance(0.7) and { s, -s } or { -s, s }) do
              for v = 1, 3 do                                -- three sizes of each
                tries_[#tries_ + 1] = { sd, edge_x(cur, sd) }          -- out from the near end
                tries_[#tries_ + 1] = { sd, edge_x(cur, -sd) + sd * R(6) }   -- or back across from the far end
                if cur.x1 - cur.x0 > R(60) then tries_[#tries_ + 1] = { sd, (cur.x0 + cur.x1) / 2 } end
              end
            end
            for _, tr in ipairs(tries_) do
              local sd = tr[1]
              local m = M_[kind](cur, sd, tr[2])
              if m then
                local top_ = m.land[#m.land].y
                if top_ <= y_target + R(25) and fits(m, cur) then
                  accept(m)
                  m.from = cur
                  for _, L in ipairs(m.land) do out[#out + 1] = L end
                  cur = m.land[#m.land]
                  s = -sd
                  lastkind = kind
                  done = true
                  break
                end
              end
            end
          end
          if done then break end
        end
        -- stuck: a jump (at most two per route), to a staggered shelf past whatever is in the way
        if not done and jumps_ < 2 then
          for _, dy in ipairs({ 45, 35, 25 }) do
            for _, gp in ipairs({ 25, 40, 55 }) do
              for _, sd in ipairs({ s, -s }) do
                local w = R(rng.pick({ 36, 40 }))
                local cx = edge_x(cur, sd) + sd * (R(gp) + w / 2)
                if inside_col(cx, w) then
                  local A = landing("moon", cx, cur.y + R(dy), w)
                  local m = { kind = "jump", land = { A }, solids = {}, draw = function() end }
                  if fits(m, cur) then
                    accept(m)
                    out[#out + 1] = A
                    cur, s, lastkind, done = A, -sd, "jump", true
                    jumps_ = jumps_ + 1
                    break
                  end
                end
              end
              if done then break end
            end
            if done then break end
          end
        end
        if not done then break end
        nm = nm + 1
      end
      return out, cur
    end

    -- the starts: the tower's landings in the column, highest first
    local starts = {}
    for _, p in ipairs(plats) do
      local a_, b_ = max(p.xa, x0), min(p.xb, x1)
      if b_ - a_ > 0.6 then starts[#starts + 1] = { id = -1, cx = (a_ + b_) / 2, x0 = a_, x1 = b_, y = p.y + st, ground = true, plat = p } end
    end
    for _, t in ipairs(tops) do
      if t[1] > x0 and t[1] < x1 and not t.noroute then starts[#starts + 1] = { id = -1, cx = t[1], x0 = t[1] - 0.45, x1 = t[1] + 0.45, y = t[2], ground = true } end
    end
    if #starts == 0 then                              -- no tower: the routes leave from the floor
      for _, g in ipairs(segs) do
        if g[2] - g[1] > 0.6 then starts[#starts + 1] = { id = -1, cx = (g[1] + g[2]) / 2, x0 = g[1], x1 = g[2], y = top } end
      end
    end
    if #starts == 0 then return end
    table.sort(starts, function(a, b) return a.y > b.y end)
    local nroutes = wide and max(2, floor((x1 - x0) / 3.5)) or (DD >= 0.6 and 2 or 1)
    local D_ = max(0.3, DD)
    local y_look = y1 - R(rng.range(30, 60))
    if DBG then io.stderr:write(string.format("start y=%.2f x=%.2f..%.2f  y_look=%.2f y1=%.2f col=%.2f..%.2f\n", starts[1].y, starts[1].x0, starts[1].x1, y_look, y1, x0, x1)) end
    -- the main route: from the highest start it can leave
    local r1, top1 = {}, nil
    for si = 1, #starts do
      r1, top1 = route(starts[si], y_look, floor(8 * D_ + 0.5))
      if #r1 > 0 then
        if si > 1 then starts[1], starts[si] = starts[si], starts[1] end
        break
      end
    end
    if top1 and top1 ~= starts[1] then top1.lookout = true top1.kind = "moon" end
    local routes = { r1 }
    if nroutes > 1 then
      -- the second start: the highest tower landing well away from the first
      -- the second start: the tower landing farthest across from the first, at any height
      -- the highest landing on the other side of the column with open sky above it
      local best
      for i = 2, #starts do
        local st_ = starts[i]
        if abs(st_.cx - starts[1].cx) > R(30) and (st_.cx - mid_) * (starts[1].cx - mid_) <= 0.05
          and free(st_.x0, st_.y + 0.05, st_.x1, st_.y + R(70), 0.02) then best = st_ break end
      end
      if best and not wide then
        local r2 = route(best, (top1 and top1.y or y_look) - R(rng.range(40, 90)), floor(6 * D_ + 0.5))
        routes[#routes + 1] = r2
      end
      if wide then                                    -- spaced across the frame, each to its own perch
        local used = { starts[1] }
        for i = 2, #starts do
          local st_ = starts[i]
          local far = true
          for _, u in ipairs(used) do if abs(u.cx - st_.cx) < R(70) then far = false end end
          if far and #routes < nroutes and free(st_.x0, st_.y + 0.05, st_.x1, st_.y + R(50), 0.02) then
            used[#used + 1] = st_
            local rn, tn = route(st_, y_look - R(rng.range(0, 120)), floor(7 * D_ + 0.5))
            if tn and tn ~= st_ then tn.lookout = true tn.kind = "moon" end
            routes[#routes + 1] = rn
          end
        end
      end
    end

    -- ledges out of the page's edges, reached by a jump or a short bridge; on a wide frame
    -- a route goes on up from them
    local edges = o.edges or {}
    local nledge = wide and floor((y1 - fy) / 7) or 1
    for side, ex_ in pairs({ edges[1] or false, edges[2] or false }) do
      if ex_ then
        local sd = side == 1 and 1 or -1
        local made = 0
        for _ = 1, 10 do
          if made >= nledge then break end
          local w = R(rng.range(45, 75))
          local yy = rng.range(top + R(110), y1 - R(70))
          local inner = ex_ + sd * w
          local a_, b_ = min(ex_, inner), max(ex_, inner)
          a_, b_ = max(a_, x0 + 0.03), min(b_, x1 - 0.03)
          local q = { a_, yy - R(4) - w * 0.4, b_, yy }
          local cq = { a_, yy + 0.01, b_, yy + R(30) }
          if b_ - a_ > R(30) and free(q[1], q[2], q[3], q[4], 0.02) and free(cq[1], cq[2], cq[3], cq[4], 0.02) and not hits_clear(q, {}) then
            -- how a cat gets there: a jump from a landing, or a short level bridge
            local tip = sd > 0 and b_ or a_
            local via, viagap
            for _, L in ipairs(lands) do
              if not L.series then
                local near = sd > 0 and L.x0 or L.x1
                local gap = (near - tip) * sd
                local dy = abs(L.y - yy)
                if gap > 0 and gap <= R(60) and dy <= R(50) then via, viagap = L, nil break end
                if gap > R(35) and gap < R(wide and 240 or 120) and dy <= R(14) and yy - fy > R(100) then via, viagap = L, gap end
              end
            end
            if via then
              local brq
              local okb = true
              if viagap then
                local nearx = sd > 0 and via.x0 or via.x1
                brq = { min(tip, nearx) + R(4), min(yy, via.y) - R(16), max(tip, nearx) - R(4), max(yy, via.y) + R(27) }
                okb = free(brq[1], brq[2], brq[3], brq[4], 0.02) and not hits_clear(brq, { [via.id] = true })
              end
              if okb then
                local LL = landing("shelf", (a_ + b_) / 2, yy, b_ - a_)
                LL.solid = q LL.clear = cq
                reg(q[1], q[2], q[3], q[4], "pl")
                clears[#clears + 1] = { cq[1], cq[2], cq[3], cq[4], LL.id }
                lands[#lands + 1] = LL
                local lw, le = abs(inner - ex_), ex_
                local function drawledge()
                  draw(3, at(le, yy, function(r) C.ledge(r, lw, sd) end))
                  spot(LL.cx, yy, { "loaf", "sit" })
                end
                local m = { kind = "ledge", land = {}, solids = {}, draw = drawledge }
                plan[#plan + 1] = m
                if viagap then
                  reg(brq[1], brq[2], brq[3], brq[4], "pl")
                  local nearx, vy = sd > 0 and via.x0 or via.x1, via.y
                  local sag = min(R(12), viagap * 0.12)
                  plan[#plan + 1] = { br = { tip, yy, nearx, vy, sag }, draw = function()
                    draw(5, function(r) C.bridge(r, tip, yy, nearx, vy, { sag = sag }) end)
                    spot((tip + nearx) / 2, (yy + vy) / 2 - sag, { "walk" }, true, 0)
                  end }
                end
                if wide and y_look - yy > R(90) then
                  local rl, tl = route(LL, y_look - R(rng.range(20, 100)), 2)
                  if tl and tl ~= LL then tl.lookout = true tl.kind = "moon" end
                  routes[#routes + 1] = rl
                end
                made = made + 1
              end
            end
          end
        end
      end
    end

    -- under the text the gym climbs too: a route from each tower out there, spaced apart, up toward the
    -- last line, each ending at a perch
    if Lmode then
      local st2 = {}
      for _, p in ipairs(plats) do
        local a_, b_ = p.xa, p.xb
        if b_ > x1 + 0.3 and b_ - a_ > 0.6 then st2[#st2 + 1] = { id = -1, cx = (max(a_, x1) + b_) / 2, x0 = max(a_, x1 - 0.2), x1 = b_, y = p.y + st, ground = true } end
      end
      for _, t in ipairs(tops) do
        if not t.noroute and t[1] > x1 then st2[#st2 + 1] = { id = -1, cx = t[1], x0 = t[1] - 0.45, x1 = t[1] + 0.45, y = t[2], ground = true } end
      end
      table.sort(st2, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.cx < b.cx end)
      local used, want_ = {}, max(1, floor((SP[3] - x1) / 3.2))
      for _, st_ in ipairs(st2) do
        if #used >= want_ then break end
        local far = true
        for _, u in ipairs(used) do if abs(u.cx - st_.cx) < R(60) then far = false end end
        if far and st_.y < SP[4] - R(45) then
          local rn, tn = route(st_, SP[4] - R(rng.range(4, 28)), 5)
          if #rn > 0 then
            used[#used + 1] = st_
            tn.lookout = true tn.kind = "moon"
            routes[#routes + 1] = rn
          end
        end
      end
    end

    -- a gangway and a ramp on every page that has room: from any landing, across to a new one
    do
      local tiptop = top1 and top1.y or y_look
      local froms = {}
      for _, L in ipairs(lands) do if not L.series and not L.lookout then froms[#froms + 1] = L end end
      for _, st_ in ipairs(starts) do froms[#froms + 1] = st_ end
      for i = #froms, 2, -1 do local j = rng.int(1, i) froms[i], froms[j] = froms[j], froms[i] end
      for _, kind in ipairs({ "gangway", "ramp" }) do
        local have = false
        for _, m in ipairs(plan) do if m.kind == kind then have = true end end
        for _ = 1, 3 do
          if have then break end
          for _, L in ipairs(froms) do
            for _, sd in ipairs({ 1, -1 }) do
              for _, ex in ipairs({ edge_x(L, sd), edge_x(L, -sd) + sd * R(6) }) do
                if not have then
                  local m = M_[kind](L, sd, ex)
                  if m and m.land[1].y < tiptop - R(25) and fits(m, L) then accept(m) have = true end
                end
              end
            end
            if have then break end
          end
        end
      end
    end

    if DBG then io.stderr:write(string.format("routes: %d; landings r1=%d r2=%s; top1 y=%s\n", #routes, #routes[1], routes[2] and #routes[2] or "-", top1 and string.format("%.2f", top1.y) or "-")) end
    -- cross-links between the routes: short level bridges where two landings face each other
    local links = 0
    local maxlinks = (wide or Lmode) and 2 * #routes or 2
    for ri = 1, #routes - 1 do for rj = ri + 1, #routes do
      for _, a in ipairs(routes[ri]) do
        for _, b in ipairs(routes[rj]) do
          if links < maxlinks and not a.lookout and abs(a.y - b.y) < R(wide and 30 or 20) then
            local s = b.cx > a.cx and 1 or -1
            local gap = s > 0 and (b.x0 - a.x1) or (a.x0 - b.x1)
            if gap > R(35) and gap < R((wide or Lmode) and 320 or 160) and a.y - fy > R(100) then
              local ex, bx1 = edge_x(a, s), edge_x(b, -s)
              local sag = min(R(12), gap * 0.12)
              local m = { kind = "link", land = {}, bridge = true, br = { ex, a.y, bx1, b.y, sag },
                solids = { { min(ex, bx1) + R(4), min(a.y, b.y) - sag - R(6), max(ex, bx1) - R(4), max(a.y, b.y) + R(27) } },
                draw = function()
                  draw(5, function(r) C.bridge(r, ex, a.y, bx1, b.y, { sag = sag }) end)
                  spot((ex + bx1) / 2, (a.y + b.y) / 2 - sag, { "walk" }, true, 0)
                end }
              local ex_ = { [a.id] = true, [b.id] = true }
              local okk = true
              for _, q in ipairs(m.solids) do
                if not free(q[1], q[2], q[3], q[4], 0.02) or hits_clear(q, ex_) then okk = false end
              end
              if okk then accept(m) links = links + 1 end
            end
          end
        end
      end
    end end

    -- dead ends off the landings: a condo on a bracket (a second box beside it, now and then,
    -- or a short bridge to it), a hex with a cushion, a clear bubble a jump above a shelf
    local hosts = {}
    for _, L in ipairs(lands) do if not L.lookout and not L.series then hosts[#hosts + 1] = L end end
    for i = #hosts, 2, -1 do local j = rng.int(1, i) hosts[i], hosts[j] = hosts[j], hosts[i] end
    local jobs = DD >= 0.5 and { "cluster", "bubble", "hide", "bed" } or { "bed" }
    if wide or Lmode then
      local base = jobs
      jobs = {}
      for _ = 1, floor(((Lmode and SP[3] or x1) - x0) / 3.5) do for _, jb in ipairs(base) do jobs[#jobs + 1] = jb end end
    end
    local function try_leaf(job, L, s)
      local ex = edge_x(L, s)
      if job == "cluster" then
        -- three hexagons sharing edges, by a landing: a row with one up (^), or an L in a narrow column
        local Rh = real(C.DIM.hex_w) / 2
        local h_ = 0.866 * Rh
        local SHAPES = (x1 - x0) > 5 * Rh + 0.2
          and { { { 0, 0 }, { 1.5 * Rh, h_ }, { 3 * Rh, 0 } }, { { 0, 0 }, { 0, 2 * h_ }, { 1.5 * Rh, h_ } } }
          or { { { 0, 0 }, { 0, 2 * h_ }, { 1.5 * Rh, h_ } } }
        local tiptop = top1 and top1.y or y1
        for _, sh in ipairs(SHAPES) do
          local xa, xb, ya = math.huge, -math.huge, -math.huge
          for _, c_ in ipairs(sh) do xa, xb, ya = min(xa, c_[1] - Rh), max(xb, c_[1] + Rh), max(ya, c_[2] + h_) end
          local W_ = xb - xa
          for _, off in ipairs({ 2, 12, 24, -20, -50 }) do
            for _, lift in ipairs({ 0, 15, 30, 45 }) do
              local left = s > 0 and ex + R(off) or ex - R(off) - W_
              local by = L.y - st + R(lift)
              local q = { left, by, left + W_, by + h_ + ya }
              if inside_col((q[1] + q[3]) / 2, W_) and q[4] <= tiptop - R(10) and free(q[1], q[2], q[3], q[4], 0.02) and not hits_clear(q, { [L.id] = true }) then
                reg(q[1], q[2], q[3], q[4], "pl")
                local ox, oy = left - xa, by + h_
                plan[#plan + 1] = { kind = "cluster", draw = function()
                  for ci_, c_ in ipairs(sh) do
                    local doors_, exits_ = C.hex_ways(sh, ci_, Rh)
                    draw(3, at(ox + c_[1], oy + c_[2], function(r) C.hex(r, { doors = doors_, exits = exits_ }) end))
                    spot(ox + c_[1], oy + c_[2] - h_ + R(3.5), { "sit" }, true)
                  end
                end }
                return true
              end
            end
          end
        end
        return false
      end
      if job == "hide" or job == "bed" then
        local box = job == "hide" and "condo" or "hex"
        local w = box == "condo" and real(C.DIM.condo_w) or real(C.DIM.hex_w)
        local h = box == "condo" and real(C.DIM.condo_h) + R(4) or 0.866 * real(C.DIM.hex_w)
        local cx = ex + s * (w / 2 + R(2))
        local by = L.y - st
        local q = { cx - w / 2, by, cx + w / 2, by + h }
        if not inside_col(cx, w) or not free(q[1], q[2], q[3], q[4], 0.02) or hits_clear(q, { [L.id] = true }) then return false end
        local top_ = landing("shelf", cx, by + h, w * 0.8)
        if not free(top_.clear[1], top_.clear[2], top_.clear[3], top_.clear[4], 0.02) then return false end
        reg(q[1], q[2], q[3], q[4], "pl")
        if box == "condo" then
          local holes = ({ { "round" }, { "arch" }, { "oval" }, { "round", "round" }, { "oval", "round" } })[rng.int(1, 5)]
          local skin = rng.chance(0.3) and "sisal" or nil
          plan[#plan + 1] = { draw = function()
            draw(3, at(cx, by, function(r) C.condo(r, { holes = holes, skin = skin }) end))
          end }
          spot(cx, by + h - R(4), { "loaf", "sit" })
          spot(cx, by + real(C.DIM.condo_h) * 0.5, { "peek" }, true)
        else
          plan[#plan + 1] = { draw = function()
            draw(3, at(cx, by + 0.866 * w / 2, function(r) C.hex(r, {}) end))
          end }
          spot(cx, by + real(3.5) + R(3), { "sit" }, true)
        end
        clears[#clears + 1] = { top_.clear[1], top_.clear[2], top_.clear[3], top_.clear[4], top_.id }
        return true
      else                                            -- the bubble: hung a jump above and beside the shelf
        local br = R(rng.range(17, 20))
        local bw = br + R(12)
        -- beside the landing or over it: a jump up to its ring, in whichever spot is free
        local cx, ty, q
        local tiptop = top1 and top1.y or y1
        for _, off in ipairs({ 6, 0, -14, -30, -50, -70 }) do
          for _, up in ipairs({ 32, 42, 52, 62 }) do
            local cx_ = ex + s * (bw + R(off))
            local ty_ = L.y + R(up)
            local q_ = { cx_ - bw, ty_ - R(4) - br - 0.05, cx_ + bw, ty_ + 0.15 }
            if not cx and inside_col(cx_, 2 * bw) and ty_ <= tiptop - R(10) and free(q_[1], q_[2], q_[3], q_[4], 0.02) and not hits_clear(q_, { [L.id] = true }) then
              cx, ty, q = cx_, ty_, q_
            end
          end
        end
        if not cx then return false end
        reg(q[1], q[2], q[3], q[4], "pl")
        -- most bubbles have someone in them; that cat counts among the page's cats
        local who
        if o.cats ~= 0 and not o.nocats and rng.chance(0.75) then
          who = { pose = rng.chance(0.55) and "curl" or "loaf", facing = rng.chance(0.5) and 1 or -1, coat = rng.pick({ "tabby", "tux", "solid", "pale" }) }
          in_bubbles = in_bubbles + 1
        end
        plan[#plan + 1] = { draw = function() draw(4, at(cx, ty, function(r) C.bubble(r, { r = br, cat = who }) end)) end }
        return true
      end
    end
    for _, job in ipairs(jobs) do
      local placed = false
      for _, L in ipairs(hosts) do
        for _, s in ipairs({ 1, -1 }) do
          if try_leaf(job, L, s) then placed = true break end
        end
        if placed then break end
      end
    end

    -- from above: perches and beds on ropes to the page's top edge, within a jump of a landing
    local ceil_ = o.ceil
    if ceil_ then
      local nhang = wide and floor((x1 - x0) / 3) or 2
      local shuffled = {}
      for _, L in ipairs(lands) do if not L.series then shuffled[#shuffled + 1] = L end end
      for _, st_ in ipairs(starts) do shuffled[#shuffled + 1] = st_ end
      for i = #shuffled, 2, -1 do local j = rng.int(1, i) shuffled[i], shuffled[j] = shuffled[j], shuffled[i] end
      local KIND = rings_ and { "swing", "sling", "basket", "hoop", "swing", "basket" } or { "hoop", "swing", "sling", "basket", "swing", "basket" }
      local made = 0
      for _, L in ipairs(shuffled) do
        if made >= nhang then break end
        local kd = KIND[made % #KIND + 1]
        local w = kd == "swing" and R(rng.range(34, 44)) or kd == "sling" and R(rng.range(50, 60)) or kd == "basket" and R(34) or R(38)
        for _, sd in ipairs(rng.chance(0.5) and { 1, -1 } or { -1, 1 }) do
          local ex = sd > 0 and L.x1 or L.x0
          local cx = ex + sd * (w / 2 + R(rng.range(14, 50)))
          local yy = L.y + R(rng.range(5, 42))
          local q = kd == "swing" and { cx - w / 2, yy - R(5), cx + w / 2, yy + R(28) }
            or kd == "sling" and { cx - w / 2, yy - R(24), cx + w / 2, yy + R(4) }
            or { cx - w / 2, yy, cx + w / 2, yy + R(36) }
          local ropes = kd == "swing" and { cx - w / 2 + R(3), cx + w / 2 - R(3) }
            or kd == "sling" and { cx - w / 2, cx + w / 2 } or { cx }
          local ok = inside_col(cx, w) and yy < y1 - R(50) and free(q[1], q[2], q[3], q[4], 0.02) and not hits_clear(q, {})
          for _, rx in ipairs(ropes) do
            ok = ok and free(rx - R(1), q[4], rx + R(1), ceil_, 0.02) and not hits_clear({ rx - R(1), q[4], rx + R(1), ceil_ }, {})
          end
          if ok then
            reg(q[1], q[2], q[3], q[4], "pl")
            for _, rx in ipairs(ropes) do reg(rx - R(1), q[4], rx + R(1), ceil_, "rope") end
            clears[#clears + 1] = { q[1], q[2], q[3], q[4], -2 }
            local top_ = ceil_ - yy
            plan[#plan + 1] = { draw = function()
              draw(4, at(cx, yy, function(r) C.hang(r, kd, top_, { w = w, r = w / 2, d = w }) end))
              if kd == "swing" then spot(cx, yy + R(2), { "loaf", "sit" }, true)
              elseif kd == "sling" then spot(cx, yy - R(17), { "curl" }, true)
              elseif kd == "basket" then spot(cx, yy + R(8), { "curl" }, true) end
            end }
            made = made + 1
            break
          end
        end
      end
      -- long toys from the top edge, anywhere there is air
      local ntoys = wide and floor((x1 - x0) / 2.2) or 3
      local LONG = { "pom", "feather", "knots", "bell", "mouse", "sisal", "dark" }
      local placed = 0
      for _ = 1, ntoys * 6 do
        if placed >= ntoys then break end
        local tx = rng.range(x0 + 0.2, x1 - 0.2)
        local L_ = R(rng.range(35, 170))
        local q = { tx - R(7), ceil_ - L_ - R(16), tx + R(7), ceil_ }
        if q[2] > fy + 1 and free(q[1], q[2], q[3], q[4], 0.05) and not hits_clear(q, {}) then
          reg(q[1], q[2], q[3], q[4], "toy")
          local kd = LONG[rng.int(1, #LONG)]
          plan[#plan + 1] = { draw = function()
            draw(5, at(tx, ceil_, function(r) C.ball(r, { kind = kd, L = L_ }) end))
          end }
          placed = placed + 1
        end
      end
    end

    -- sisal mats on the wall beside a landing: somewhere to scratch
    do
      local nm_, tried = 0, 0
      for _, L in ipairs(lands) do
        if nm_ >= (wide and 3 or 1) or tried > 12 then break end
        if not L.series and not L.lookout then
          tried = tried + 1
          local sd = rng.chance(0.5) and 1 or -1
          local w_, h_ = R(20), R(42)
          local cx = (sd > 0 and L.x1 or L.x0) + sd * (w_ / 2 + R(5))
          local by = L.y - R(6)
          local q = { cx - w_ / 2 - R(1), by, cx + w_ / 2 + R(1), by + h_ + R(2) }
          if inside_col(cx, w_) and free(q[1], q[2], q[3], q[4], 0.02) and not hits_clear(q, { [L.id] = true }) then
            reg(q[1], q[2], q[3], q[4], "pl")
            plan[#plan + 1] = { draw = function() draw(2, at(cx, by, function(r) C.mat(r, w_, h_) end)) end }
            nm_ = nm_ + 1
          end
        end
      end
    end

    -- toys off the bridges: hung from the deck, a few along each
    do
      local KINDS = { "pom", "mouse", "feather", "knots", "bell", "sisal", "dark" }
      local brs = {}
      for _, m in ipairs(plan) do if m.br then brs[#brs + 1] = m.br end end
      for _, b in ipairs(tower_bridges) do brs[#brs + 1] = b end
      for _, b in ipairs(brs) do
        local ax, ay, bx, by, sag = b[1], b[2], b[3], b[4], b[5]
        local span = abs(bx - ax)
        local want_ = max(1, min(4, floor(span / R(45))))
        local lane = min(ay, by) - sag - R(8)
        for k = 1, want_ do
          local t = (k - 0.5) / want_ + rng.sym(0.3 / want_)
          local tx, dy_ = ax + (bx - ax) * t, ay + (by - ay) * t - 4 * sag * t * (1 - t)
          local cord = R(rng.range(14, 34))
          local q = { tx - R(7), dy_ - cord - R(16), tx + R(7), lane }
          if q[4] > q[2] and free(q[1], q[2], q[3], q[4], 0.02) and not hits_clear(q, {}) then
            reg(q[1], q[2], q[3], q[4], "toy")
            local kd = KINDS[rng.int(1, #KINDS)]
            plan[#plan + 1] = { draw = function()
              draw(5, at(tx, dy_ - R(1), function(r) C.ball(r, { kind = kd, L = cord }) end))
            end }
          end
        end
      end
    end

    -- the flat places a cat lies on, for yarn and wands: wall landings and tower platforms
    local flats = {}
    for _, L in ipairs(lands) do
      if not L.series and not L.lookout and L.kind == "shelf" then flats[#flats + 1] = { x0 = L.x0, x1 = L.x1, y = L.y, id = L.id } end
    end
    for _, p_ in ipairs(plats) do flats[#flats + 1] = { x0 = max(p_.xa, x0), x1 = min(p_.xb, x1), y = p_.y + st, id = -1 } end
    for i = #flats, 2, -1 do local j = rng.int(1, i) flats[i], flats[j] = flats[j], flats[i] end

    -- yarn on the perches, its strand over the edge
    do
      local nyarn, maxyarn = 0, wide and floor((x1 - x0) / 3.5) or 2
      for _, F in ipairs(flats) do
        if nyarn >= maxyarn then break end
        local sd = rng.chance(0.5) and 1 or -1
        local edge = sd > 0 and F.x1 or F.x0
        local r_ = R(rng.range(4, 5.5))
        local run = R(rng.range(10, 20))
        local bx = edge - sd * run
        local drop = R(rng.range(15, 40))
        local qb = { bx - r_, F.y + 0.01, bx + r_, F.y + 2 * r_ }
        local qs = { edge - R(1), F.y - st - drop, edge + sd * R(4), F.y }
        qs[1], qs[3] = min(qs[1], qs[3]), max(qs[1], qs[3])
        if F.x1 - F.x0 > R(30) and free(qb[1], qb[2], qb[3], qb[4], 0.02) and free(qs[1], qs[2], qs[3], qs[4], 0.02) and not hits_clear(qs, {}) then
          reg(qb[1], qb[2], qb[3], qb[4], "toy")
          reg(qs[1], qs[2], qs[3], qs[4], "toy")
          local cp = rng.chance(0.5)
          plan[#plan + 1] = { draw = function()
            draw(5, at(bx, F.y, function(r) C.yarn(r, r_, sd * run, drop, cp) end))
          end }
          nyarn = nyarn + 1
        end
      end
    end

    -- fishing-pole wands, stuck in at an angle at a perch's end, the line hanging clear
    do
      local nw, maxw = 0, wide and floor((x1 - x0) / 4) or 2
      for _, F in ipairs(flats) do
        if nw >= maxw then break end
        local sd = rng.chance(0.5) and 1 or -1
        local L_ = R(rng.range(42, 62))
        local a_ = math.rad(rng.range(42, 66))
        local dx, dy = sd * L_ * cos(a_), L_ * sin(a_)
        local ox = (sd > 0 and F.x1 or F.x0) - sd * R(3)
        local drop = R(rng.range(14, 26))
        local ok = true
        for u = 0.25, 1.001, 0.25 do
          local x, y = ox + dx * u, F.y + dy * u
          local q = { x - R(3), y - R(3), x + R(3), y + R(3) }
          if not free(q[1], q[2], q[3], q[4], 0.02) or hits_clear(q, { [F.id] = true }) then ok = false end
        end
        local tx, ty = ox + dx, F.y + dy
        local qs = { tx + sd * R(1) - R(9), ty - drop - R(13), tx + sd * R(1) + R(9), ty - R(3) }
        if ok and inside_col(tx, R(18)) and ty < y1 and free(qs[1], qs[2], qs[3], qs[4], 0.02) and not hits_clear(qs, { [F.id] = true }) then
          reg(min(ox, tx), F.y + R(2), max(ox, tx), ty, "toy")
          reg(qs[1], qs[2], qs[3], qs[4], "toy")
          plan[#plan + 1] = { draw = function()
            draw(5, at(ox, F.y, function(r) C.wand(r, dx, dy, drop) end))
          end }
          nw = nw + 1
        end
      end
    end

    -- toys: hung under a landing's end, never into a path
    local TOYS = { "pom", "pom", "sisal", "dark", "spring", "mouse", "feather", "knots", "bell" }
    for _, L in ipairs(lands) do
      if not L.series and rng.chance(0.6) then
        local tx = rng.chance(0.5) and L.x0 or L.x1
        tx = tx + (tx == L.x0 and R(5) or -R(5))
        local cord = R(rng.range(18, 34))
        local yb = L.solid[2]
        local q = { tx - R(6), yb - cord - R(10), tx + R(6), yb - R(1) }
        if free(q[1], q[2], q[3], q[4], 0.02) and not hits_clear(q, {}) then
          reg(q[1], q[2], q[3], q[4], "toy")
          local kd = TOYS[rng.int(1, #TOYS)]
          plan[#plan + 1] = { draw = function()
            draw(5, at(tx, yb, function(r)
              C.ball(r, { kind = kd == "spring" and "pom" or kd, spring = kd == "spring", L = cord })
            end))
          end }
        end
      end
    end

    if DBG then
      local ks = {} for k, v in pairs(DBG) do ks[#ks + 1] = k .. "=" .. v end table.sort(ks)
      io.stderr:write("plan: " .. #plan .. " items; starts " .. #starts .. "; " .. table.concat(ks, " ") .. "\n")
    end
    -- draw, in the order planned: each module, then the landings it made
    for _, m in ipairs(plan) do
      m.draw()
      for _, L in ipairs(m.land or {}) do
        local L_ = L
        if L_.kind == "moon" then
          draw(3, at(L_.cx, L_.y - R(7.5), function(r) C.moon(r, { w = L_.w, carpet = L_.lookout or rng.chance(0.3) }) end))
        else
          local kd_ = (not L_.series and not L_.stepoff and not L_.walk and L_.w >= R(34) and rail_ok(0.3)) and "fence" or "bracket"
          draw(3, at(L_.cx, L_.y - st - R(1.5), function(r) C.shelf(r, { kind = kd_, w = L_.w }) end))
        end
        if L_.lookout then spot(L_.cx, L_.y, { "sit", "loaf" })
        elseif not L_.series then spot(L_.cx, L_.y, { "loaf", "sit" }) end
      end
    end
  end
  local placed_hex = {}
  if DD > 0.1 then plan_wall() end


  -- ---------------------------------------------------------------- 3b. under the text (the last page)
  -- rows of raised wall pieces reaching sideways out of the column: a shelf at the
  -- column's edge, then rope bridges (shallow) and floating steps to half-moons,
  -- hexes and shelves, as far as the space goes
  if o.spill and not Lmode then
    local sp = o.spill
    bound = { sp[1] - 0.6, sp[2], sp[3], sp[4] }
    local H = sp[4] - sp[2]
    local rows = max(1, min(3, floor(H / 3.6)))
    local R = real(C.DIM.hex_w) / 2
    for row = 1, rows do
      local y = sp[2] + H * (row - 0.55) / rows + rng.sym(0.3)
      local w0 = real(rng.range(36, 46))
      local x = sp[1] - 0.2
      if free(x, y - 0.3, x + w0, y + 0.45) then
        draw(3, at(x + w0 / 2, y, function(r) C.shelf(r, { kind = "bracket", w = w0 }) end))
        reg(x, y - 0.3, x + w0, y + 0.45, "shelf")
        spot(x + w0 / 2, y + st, { "loaf", "sit" })
        x = x + w0
        local ytop = y + st
        for _ = 1, 8 do
          if x > sp[3] - 2.5 then break end
          local kind = rng.pick({ "moon", "moon", "hex", "shelf" })
          local span = rng.range(1.8, 2.8)
          local ny = y + rng.sym(0.35)
          local nx = x + span
          local pw, ptop, box
          if kind == "hex" then
            pw = 2 * R + 0.3
            ptop = ny + st
            box = { nx, ny - 0.3, nx + pw, ny + 1.732 * R + 0.2 }
          elseif kind == "moon" then
            pw = real(rng.range(34, 44)) ptop = ny + real(7.5)
            box = { nx, ny - 0.3, nx + pw, ny + 0.45 }
          else
            pw = real(rng.range(36, 50)) ptop = ny + st
            box = { nx, ny - 0.3, nx + pw, ny + 0.45 }
          end
          if box[3] > sp[3] or not free(box[1], box[2], box[3], box[4], -GAP) then break end
          local bridge = span >= 2.2 and rng.chance(0.65)
          local cb = { x + 0.3, min(ytop, ptop) - 0.5, nx - 0.3, max(ytop, ptop) + (bridge and real(28) or 0.3) }
          if not free(cb[1], cb[2], cb[3], cb[4]) then break end
          local ax, ay, bx2, by2 = x, ytop, nx, ptop
          if bridge then
            local sag = rng.range(0.15, 0.3)
            draw(5, function(r) C.bridge(r, ax, ay, bx2, by2, { sag = sag }) end)
            local ang = math.deg(math.atan(by2 - ay, bx2 - ax))
            spot((ax + bx2) / 2, (ay + by2) / 2 - sag, { "walk" }, true, ang)
          else
            draw(5, function(r) C.steps(r, ax + 0.3, ay, bx2 - 0.3, by2, {}) end)
          end
          reg(cb[1], cb[2], cb[3], cb[4], bridge and "bridge" or "chain")
          if kind == "hex" then
            -- the hex on a short bracket shelf, its lower corner clear of the bridge's post
            draw(3, at(nx + 0.3 + R, ny + st + 0.866 * R, function(r) C.hex(r, {}) end))
            draw(3, at(nx + 0.3 + R, ny, function(r) C.shelf(r, { kind = "bracket", w = 1.2 * R }) end))
            spot(nx + 0.3 + R, ny + st + real(3.5) + 0.05, { "sit" }, true)
          elseif kind == "moon" then
            draw(3, at(nx + pw / 2, ny, function(r) C.moon(r, { w = pw, carpet = rng.chance(0.6) }) end))
            spot(nx + pw / 2, ptop, { "loaf", "sit" })
            if rng.chance(0.4) and free(nx + pw - 0.4, ny - 1.4, nx + pw - 0.1, ny - 0.1, -GAP) then
              draw(5, at(nx + pw - 0.25, ny, function(r) C.ball(r, { kind = rng.pick({ "pom", "sisal" }), L = real(22) }) end))
              reg(nx + pw - 0.4, ny - 1.4, nx + pw - 0.1, ny, "toy")
            end
          else
            draw(3, at(nx + pw / 2, ny, function(r) C.shelf(r, { kind = rng.pick({ "bracket", "cushion" }), w = pw }) end))
            spot(nx + pw / 2, ptop + real(4), { "loaf", "sit", "curl" })
          end
          reg(box[1], box[2], box[3], box[4], kind)
          x, y, ytop = box[3], ny, ptop
        end
      end
    end
    bound = { x0, -1e9, o.spill[3], 1e9 }
  end

  -- ---------------------------------------------------------------- the footer
  if Lmode then o.foot = nil end
  if not o.nofoot then
  local fx0 = o.foot and (o.foot[1] + 0.5) or (x1 + 0.9)
  local fx1 = o.foot and (o.foot[3] - 0.2) or (fx0 + 5.4)
  local fh = o.foot and (o.foot[4] - top + 0.5) or 1.4       -- the height the band allows above the base
  draw(2, at((fx0 + fx1) / 2, fy, function(r) C.base(r, { w = fx1 - fx0 }) end))
  -- a row of floor pieces: loungers, short posts with a pad or a tube, baskets, a low
  -- ramp; a toy from a post's pad
  local fx = fx0 + 0.2
  local last
  for _ = 1, 16 do
    if fx > fx1 - real(30) then break end
    local kind = rng.pick({ "wave", "post", "bowl", "post", "wave" })
    if kind == last then kind = rng.pick({ "post", "bowl" }) end
    local w
    if kind == "wave" then
      w = real(rng.range(40, 50))
      local wh = min(real(15), fh - 0.5)
      if fx + w > fx1 or wh < real(6) then kind = "bowl" else
      local cx = fx + w / 2
      draw(4, at(cx, top, function(r) C.wave(r, { w = w, h = wh }) end))
      spot(cx, top + real(8), { "curl" }, true)
      end
    end
    if kind == "bowl" then
      w = real(rng.range(30, 38))
      if fx + w > fx1 then w = 0 else
      local cx = fx + w / 2
      draw(4, at(cx, top, function(r) C.bowl(r, { kind = rng.pick({ "basket", "plush" }), r = w / 2 }) end))
      spot(cx, top + real(8), { "curl" }, true)
      end
    elseif kind == "post" then
      w = real(30)
      local sh = min(fh - 0.5, real(rng.range(16, 26)))
      if fx + w > fx1 or sh < 0.3 then w = 0 else
      local cx = fx + w / 2
      draw(2, at(cx, top, function(r) C.post(r, { kind = rng.pick({ "sisal", "banded" }), bands = 1, h = sh }) end))
      if rng.chance(0.5) then
        draw(4, at(cx, top + sh, function(r) C.pad(r, { w = real(30) }) end))
        spot(cx, top + sh + real(4), { "loaf", "sit" })
      else
        draw(4, at(cx, top + sh, function(r) C.tube(r, { w = real(28), d = real(18) }) end))
        spot(cx, top + sh + real(18), { "sit" })
      end
      end
    end
    if w and w > 0 then fx, last = fx + w + rng.range(0.15, 0.5), kind else fx = fx + 0.3 end
  end

  end
  -- draw, back to front
  for _, L in ipairs(layers) do for _, fn in ipairs(L) do fn() end end

  -- cats: about seven, from the candidate spots, none overlapping
  local order = {}
  for i = 1, #spots do order[i] = i end
  for i = #order, 2, -1 do local j = rng.int(1, i) order[i], order[j] = order[j], order[i] end
  -- one or two cats a page; a heading's cat counts among them
  local want = max(0, (o.cats or rng.int(1, 2)) - in_bubbles)
  for _, mc in ipairs(marked) do if #cats < 2 then cat(mc[1], mc[2], mc[3], 1, nil, true) want = max(want, #cats) end end
  if #claws > 0 and #cats < want and rng.chance(0.35) then
    local px = claws[rng.int(1, #claws)]
    local f = rng.chance(0.5) and 1 or -1
    local x = px - f * (real(12) + pr)
    if free(min(x, px) - 0.6, top + 0.03, max(x, px), top + 2.2, 0.02) then
      reg(min(x, px) - 0.6, top, max(x, px), top + 2.2, "cat")
      cats[#cats + 1] = { x, top, "claw", f }
    end
  end
  for _, i in ipairs(order) do
    if #cats >= want then break end
    local s = spots[i]
    local pose = s[3][rng.int(1, #s[3])]
    -- a cat is drawn larger than its box in some poses: well clear of the keep-outs, or not at all
    for _, ko in ipairs(o.keepout or {}) do
      if s[1] + real(38) > ko[1] and s[1] - real(38) < ko[3] and s[2] + real(52) > ko[2] and s[2] - real(30) < ko[4] then pose = nil break end
    end
    if pose == nil then
    elseif pose == "peek" then
      if rng.chance(0.6) then cats[#cats + 1] = { s[1], s[2] - real(10) + real(1), "peek" } end
    elseif pose == "drape" then
      -- the cat lies on the end with its paw and tail over the edge: the body back from the edge
      local f = s[5]
      local x = s[1] - f * real(14)
      if free(x - 1.2, s[2] + 0.03, x + 1.2, s[2] + 1.0, 0.02) and free(s[1] - 0.25, s[2] - 1.1, s[1] + 0.25, s[2] - 0.15, 0.02) then
        reg(x - 1.2, s[2], x + 1.2, s[2] + 1.0, "cat")
        cats[#cats + 1] = { x, s[2], "drape", f }
      end
    elseif pose == "walk" then
      local w, h = CAT.walk[1], CAT.walk[2]
      if free(s[1] - w / 2, s[2] + 0.2, s[1] + w / 2, s[2] + h, 0.02, "bridge") then
        reg(s[1] - w / 2, s[2], s[1] + w / 2, s[2] + h, "cat")
        cats[#cats + 1] = { s[1], s[2], "walk", 1, s[5] }
      end
    else
      cat(s[1], s[2], pose, nil, nil, s[4])
    end
  end
  return cats
end



-- ---------------------------------------------------------------- cats
-- A cat in the ink, real size (a body of about 45 cm), standing on the origin and
-- facing +x. Every pose is a hand-drawn outline (cm), smoothed: the body and legs,
-- the head with pointed ears, the tail as a tapered stroke. Painted like the rest:
-- a wash, granulated, darker pooling at the edge, a paler belly, lifted light
-- along the back; copper eyes with a slit, a small nose, white whiskers when large
-- enough to see. pose: loaf | sit | curl | walk | drape | peek. o.coat: solid |
-- blue | tabby | tux | pale (or chosen from rng). facing -1 turns it, angle tilts it.
local CATS = {
  loaf = {
    body = { { -22, 0.5 }, { -24, 3.8 }, { -23, 9 }, { -18.5, 13.2 }, { -10, 15.6 }, { 0, 16.2 }, { 7.5, 15.3 }, { 11.5, 12.8 }, { 13.8, 8.5 }, { 15, 3.5 }, { 13.8, 0.6 }, { 4, 0 }, { -12, 0 } },
    paws = { { 14.8, 1.3, 3.8, 1.3 } },
    head = { 15.5, 14.8, 5.4, 4.9, 0 }, face = "front",
    tail = { -21.5, 3.2, -27, 0.2, -14, -0.6, -2, 0.8, 3.0, 1.6 },
    belly = { -6, 1.6, 15, 3.0 }, back = { -20, 11.5, -10, 15.2, 1, 15.8, 9, 14 },
    lines = { { 2, 1, 7, 3.5, 9, 7, 10, 11 } },
  },
  sit = {
    body = { { -10.5, 0.5 }, { -12.8, 4 }, { -12.6, 10 }, { -10, 15 }, { -5.5, 19.5 }, { -1, 23.5 }, { 2.8, 27 }, { 7, 27.3 }, { 9, 24 }, { 9.2, 18 }, { 8.4, 10 }, { 8.6, 3.5 }, { 10, 1.3 }, { 9.6, 0 }, { 6, 0 }, { 5.4, 6.5 }, { 3.5, 4 }, { 0, 1.4 }, { -5, 0 } },
    paws = { { 9.6, 0.9, 2.7, 1.1 } },
    head = { 6.6, 31.2, 5.3, 4.8, 0 }, face = "front",
    tail = { -10.5, 2.4, -17.5, 1.2, -7, -1, 5, 0.6, 2.8, 1.4 },
    belly = { 3, 17.5, 5.5, 5.5 }, back = { -12, 8, -10.5, 14, -5, 19.5, 0, 24 },
    lines = { { -0.5, 1.2, -7.5, 3.5, -9, 10.5, -4.5, 15.5 }, { 5.6, 6.5, 5.3, 11, 6, 15, 7.5, 18 } },
  },
  curl = {
    body = { { -18, 5.5 }, { -16.5, 11 }, { -9.5, 14.5 }, { 0, 15.3 }, { 9.5, 14 }, { 16, 10.8 }, { 18.5, 5.8 }, { 16.5, 1.1 }, { 8, 0 }, { -9, 0 }, { -16, 1.4 } },
    paws = {},
    head = { 10.5, 7, 5.6, 4.9, -10 }, face = "asleep",
    tail = { -17, 3.5, -18, -0.5, 0, -0.8, 14, 1.4, 3.2, 2.0 },
    back = { -15, 9.5, -8, 13.8, 2, 14.6, 10, 13.4 },
    lines = { { -6, 1, -12, 4, -12, 10, -6, 12.5 } },
  },
  walk = {
    body = { { -18, 14 }, { -18.5, 18 }, { -14, 21 }, { -5, 21.6 }, { 5, 21.2 }, { 12, 20.6 }, { 16, 22.8 }, { 18, 19.8 }, { 16, 14.5 }, { 11, 11.8 }, { 0, 12.2 }, { -10, 12.2 }, { -15.5, 12.6 } },
    thighs = { { -13.5, 15, 5.2, 5.8 }, { 11.5, 15.5, 3.8, 4.6 } },
    legs = { { -15, 13.5, -16, 0.6, 4.6, 2.2 }, { -10, 13, -8, 0.6, 3.9, 2.1 }, { 10.2, 13, 9, 0.6, 3.4, 2.0 }, { 13.8, 13.5, 15.6, 0.6, 3.2, 2.0 } },
    paws = { { -16, 0.8, 2.0, 0.9 }, { -8, 0.8, 1.9, 0.9 }, { 9, 0.8, 1.8, 0.9 }, { 15.6, 0.8, 1.8, 0.9 } },
    head = { 21, 24.2, 5.3, 4.7, 5 }, face = "side",
    tail = { -18, 18.5, -23.5, 19.5, -26.5, 25, -24.5, 31.5, 2.8, 1.4 },
    belly = { -11, 11.8, 13, 2.2 }, back = { -16.5, 19.5, -7, 21.8, 4, 21.8, 12, 21 },
  },
  stretch = {
    body = { { -17, 9 }, { -18.5, 14 }, { -17, 19.5 }, { -12.5, 22 }, { -6.5, 20.5 }, { 0, 15.5 }, { 6, 10 }, { 12, 6.8 }, { 18, 5 }, { 21, 3.2 }, { 20, 1.6 }, { 13, 2.4 }, { 5, 3.4 }, { -3, 5.6 }, { -9, 6.8 }, { -13.5, 7 } },
    thighs = { { -13.5, 13, 5.2, 6.2 } },
    legs = { { -15.5, 11, -16.5, 0.6, 4.4, 2.1 }, { -10.5, 10, -9, 0.6, 3.8, 2.0 }, { 12, 5, 24, 1.0, 3.2, 1.9 }, { 9, 4.6, 21.5, 0.8, 3.0, 1.8 } },
    paws = { { -16.5, 0.8, 2.0, 0.9 }, { -9, 0.8, 1.9, 0.9 }, { 24.5, 1.0, 2.2, 1.0 }, { 22, 0.8, 2.0, 0.9 } },
    head = { 18.5, 8.8, 5.1, 4.6, -6 }, face = "side",
    tail = { -17.5, 17, -23, 18, -26, 23, -24, 27, 2.8, 1.4 },
    back = { -16, 18, -11, 21.5, -3, 18, 6, 11 },
  },
  claw = {                                             -- up on its hind legs, front paws on a post at x = 12
    body = { { -6, 4 }, { -8.5, 9 }, { -8.5, 16 }, { -6.5, 23 }, { -3.5, 29.5 }, { 0, 34 }, { 4, 35.5 }, { 6.5, 33 }, { 6, 27 }, { 4.5, 20 }, { 3.5, 12 }, { 4, 6 }, { 2, 3.5 }, { -2, 3 } },
    thighs = { { -4, 7.5, 5.4, 6.5 } },
    legs = { { -5, 6, -6.5, 0.6, 4.5, 2.2 }, { 0, 6, 2, 0.6, 4, 2.1 }, { 3.5, 31, 11.5, 40, 3.4, 2.0 }, { 4.5, 27.5, 12, 34, 3.2, 1.9 } },
    paws = { { -6.5, 0.8, 2.1, 0.9 }, { 2.2, 0.8, 2.0, 0.9 }, { 12, 40.5, 1.4, 1.8 }, { 12.5, 34.5, 1.4, 1.8 } },
    head = { 3.5, 39.5, 5.1, 4.6, 14 }, face = "side",
    tail = { -7, 7, -13, 5, -17, 9, -18, 15, 2.8, 1.4 },
    back = { -8, 10, -7.5, 18, -5, 26, -1, 32 },
  },
}
CATS.bat = {                                           -- sitting, one front paw raised at something above
  body = CATS.sit.body, paws = { { 9.6, 0.9, 2.7, 1.1 }, { 14.6, 34.6, 1.6, 1.8 } },
  legs = { { 6.5, 21, 14.3, 33.6, 3.0, 1.9 } },
  head = { 6.4, 31.2, 5.3, 4.8, 14 }, face = "side",
  tail = CATS.sit.tail, belly = CATS.sit.belly, back = CATS.sit.back, lines = CATS.sit.lines,
}
CATS.meow = {                                          -- sitting, head up, mouth open
  body = CATS.sit.body, paws = CATS.sit.paws,
  head = { 6.8, 31.6, 5.3, 4.8, 16 }, face = "meow",
  tail = CATS.sit.tail, belly = CATS.sit.belly, back = CATS.sit.back, lines = CATS.sit.lines,
}
CATS.drape = {                                         -- lying on an edge, a paw and the tail hanging over it
  body = CATS.loaf.body, paws = { { 14.6, -9.4, 1.6, 1.4 } }, head = CATS.loaf.head, face = "front",
  legs = { { 12.5, 5, 14.5, -9, 3.6, 2.2 } },
  tail = { -21, 4, -25, -2, -24, -12, -22, -20, 3.0, 1.6 },
  belly = CATS.loaf.belly, back = CATS.loaf.back, lines = CATS.loaf.lines,
}
local COATS = { "solid", "solid", "blue", "tabby", "tabby", "tux", "pale" }
-- every part of a cat is wound counterclockwise, so overlapping parts add up
-- instead of cancelling (nonzero fill)
local function ccw(p)
  local a = 0
  for i = 1, #p do local q, r = p[i], p[i % #p + 1] a = a + q[1] * r[2] - r[1] * q[2] end
  return a >= 0 and p or reversed(p)
end
-- a leg: a blade from (x0,y0) to (x1,y1), w0 wide at the top, w1 at the paw
local function leg_pts(l)
  local x0, y0, x1, y1, w0, w1 = l[1], l[2], l[3], l[4], l[5], l[6]
  local pts = ink.blade(function(v) return x0 + (x1 - x0) * v + 0.8 * sin(pi * v), y0 + (y1 - y0) * v end, 10,
    function(v) return lerp(w0, w1, v ^ 0.7) / 2 end, function(v) return lerp(w0, w1, v ^ 0.7) / 2 end)
  return ccw(pts)
end
local COAT_TONE = { solid = 0.12, blue = 0.3, tabby = 0.36, tux = 0.1, pale = 0.62 }

local function head_outline(h)
  local cx, cy, rx, ry = h[1], h[2], h[3], h[4]
  local p = {}
  for k = 0, 15 do
    local a = 2 * pi * k / 16
    local s_ = 1 + 0.1 * cos(2 * a) - (sin(a) < -0.5 and 0.06 or 0)   -- wider at the cheeks
    p[#p + 1] = { cx + rx * s_ * cos(a), cy + ry * sin(a) }
  end
  return p
end
local function ear_pts(h, side, front)
  local cx, cy, rx, ry = h[1], h[2], h[3], h[4]
  local bx = cx + side * rx * 0.62
  local tipx = cx + side * rx * (front and 0.95 or 0.72)
  return ccw({ { bx - side * rx * 0.42, cy + ry * 0.6 }, { tipx, cy + ry * 1.75 }, { bx + side * rx * 0.38, cy + ry * 0.42 } })
end

function M.cat(rng, pose, facing, angle, o)
  o = o or {}
  local P = CATS[pose] or CATS.loaf
  local coat = o.coat or COATS[rng.int(1, #COATS)]
  local t0 = o.tone or COAT_TONE[coat] + rng.sym(0.03)
  local fine = ink.unit() * 45 * M.SCALE > 3          -- whiskers and specks only when the cat is large
  ink.push()
  if angle then ink.rotate(angle) end
  ink.scale((facing or 1) * M.SCALE, M.SCALE)
  local edge = tone(max(0, t0 - 0.12))
  -- the tail, behind
  local tl = P.tail
  ink.taper(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9], tl[10])
  ink.fill(tone(t0 - 0.03))
  if coat == "tabby" then
    local bz = ink.bezier3(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8])
    ink.taper(tl[1], tl[2], tl[3], tl[4], tl[5], tl[6], tl[7], tl[8], tl[9], tl[10]) ink.clip()
      for k = 1, 5 do
        local u = 0.17 * k
        local x, y = bz(u)
        local x2, y2 = bz(u + 0.01)
        local dx, dy = x2 - x, y2 - y
        local L = sqrt(dx * dx + dy * dy) + 1e-9
        local nx, ny = -dy / L * 3, dx / L * 3
        ink.moveto(x - nx, y - ny) ink.lineto(x + nx, y + ny)
      end
      ink.stroke(tone(t0 - 0.24), 2.0 * ink.unit() * ink.CM, 0.7, true)
    ink.unclip()
  end
  -- body and legs: one silhouette
  P.body = ccw(P.body)
  local function silhouette()
    ink.smooth(P.body, true, 0.9)
    for _, t in ipairs(P.thighs or {}) do ink.smooth(ellipse(t[1], t[2], t[3], t[4], 16), true) end
    for _, l in ipairs(P.legs or {}) do ink.smooth(leg_pts(l), true, 0.8) end
    for _, pw in ipairs(P.paws) do ink.smooth(ellipse(pw[1], pw[2], pw[3], pw[4], 12), true) end
  end
  silhouette() ink.fill(tone(t0))
  silhouette() ink.clip()
    mottle(rng, -30, -12, 30, 32, 9, 5, t0 - 0.1, t0 + 0.18, fine and 12 or 0)
    if P.belly then                                    -- a paler belly
      local b = P.belly
      ink.smooth(ellipse(b[1] + b[3] / 2, b[2], b[3] / 2 + 2, b[4], 16), true)
      ink.fill(tone(min(0.95, t0 + 0.25)), coat == "tux" and 0.12 or 0.3)
    end
    if coat == "tux" then                              -- a white bib under the chin
      local h = P.head
      local bx, by = h[1] - (P.face == "side" and 1.5 or 0.5), h[2] - h[4] - 2.5
      ink.smooth({ { bx - 2.6, by + 2.5 }, { bx + 2.6, by + 2.5 }, { bx + 2, by - 2 }, { bx, by - 5 }, { bx - 2, by - 2 } }, true)
      ink.fill(white, 0.92)
    end
    local bk = P.back
    if coat == "tabby" then                            -- stripes from the back line inward
      local bz = ink.bezier3(bk[1], bk[2], bk[3], bk[4], bk[5], bk[6], bk[7], bk[8])
      for k = 0, 6 do
        local u = 0.08 + 0.13 * k
        local x, y = bz(u)
        local x2, y2 = bz(u + 0.02)
        local dx, dy = x2 - x, y2 - y
        local L = sqrt(dx * dx + dy * dy) + 1e-9
        local nx, ny = dy / L, -dx / L               -- toward the inside of the body
        streak3(x - nx, y - ny, x + nx * 3, y + ny * 3 + 0.4, x + nx * 6, y + ny * 6, x + nx * 8.5 + dx / L, y + ny * 8.5 + dy / L,
          2.0, 0.3, tone(t0 - 0.24), 0.6, true)
      end
    end
    for _, ln in ipairs(P.lines or {}) do                -- a few darker lines: the haunch, the leg
      streak3(ln[1], ln[2], ln[3], ln[4], ln[5], ln[6], ln[7], ln[8], 0.9, 0.3, tone(max(0, t0 - 0.12)), 0.45, true)
    end
    if coat == "tux" then                              -- white paws
      for _, l in ipairs(P.legs or {}) do ink.smooth(ellipse(l[3], l[4] + 1.3, l[6] * 0.75, 1.8, 10), true) ink.fill(white, 0.9) end
      for _, pw in ipairs(P.paws) do ink.smooth(ellipse(pw[1] + 0.5, pw[2], pw[3] * 0.85, pw[4] * 1.05, 10), true) ink.fill(white, 0.9) end
    end
    streak3(bk[1], bk[2], bk[3], bk[4], bk[5], bk[6], bk[7], bk[8], 1.6, 0.4, white, coat == "pale" and 0.4 or 0.26)
    ink.smooth(P.body, true, 0.9) ink.stroke(edge, 1.4, 0.35, true)
  ink.unclip()
  -- the head, turned by h[5] degrees about its center
  local h = P.head
  local ho = head_outline(h)
  ink.push() ink.translate(h[1], h[2]) ink.rotate(h[5] or 0) ink.translate(-h[1], -h[2])
  local function headshape()
    ink.smooth(ho, true)
    ink.smooth(ear_pts(h, -1, P.face == "side"), true, 0.3)
    ink.smooth(ear_pts(h, 1, P.face == "side"), true, 0.3)
  end
  headshape() ink.fill(tone(t0))
  headshape() ink.clip()
    mottle(rng, h[1] - 9, h[2] - 8, h[1] + 9, h[2] + 12, 4, 3, t0 - 0.1, t0 + 0.16, 0)
    if coat == "tabby" then
      for k = -1, 1 do streak3(h[1] + k * 1.8, h[2] + h[4] * 0.95, h[1] + k * 1.6, h[2] + h[4] * 0.7, h[1] + k * 1.2, h[2] + h[4] * 0.5, h[1] + k * 1.0, h[2] + h[4] * 0.35, 1.1, 0.3, tone(t0 - 0.25), 0.6, true) end
    end
    if coat == "tux" and P.face ~= "asleep" then
      ink.smooth(ellipse(h[1] + (P.face == "side" and h[3] * 0.45 or 0), h[2] - h[4] * 0.5, h[3] * 0.55, h[4] * 0.42, 12), true)
      ink.fill(white, 0.92)
    end
    ink.smooth(ho, true) ink.stroke(edge, 1.2, 0.3, true)
  ink.unclip()
  -- inner ears, pale
  for _, sd in ipairs({ -1, 1 }) do
    local e = ear_pts(h, sd, P.face == "side")
    local cx_, cy_ = (e[1][1] + e[2][1] + e[3][1]) / 3, (e[1][2] + e[2][2] + e[3][2]) / 3
    local inner = {}
    for _, q in ipairs(e) do inner[#inner + 1] = { cx_ + (q[1] - cx_) * 0.5, cy_ + (q[2] - cy_) * 0.5 - 0.3 } end
    ink.smooth(inner, true, 0.3) ink.fill(tone(min(0.9, t0 + 0.32)), 0.75)
  end
  -- the face
  local function eye(x, y, r)
    ink.smooth({ { x - r, y }, { x, y + r * 0.62 }, { x + r, y }, { x, y - r * 0.62 } }, true, 0.9)
    ink.fill(ink.accent(0.15))
    ink.smooth({ { x, y + r * 0.55 }, { x + r * 0.2, y }, { x, y - r * 0.55 }, { x - r * 0.2, y } }, true, 0.6)
    ink.fill(tone(0.03))
    ink.circle(x - r * 0.3, y + r * 0.2, r * 0.13) ink.fill(white, 0.9)
  end
  local nose_c = ink.accent(0.45)
  if P.face == "asleep" then
    for _, dx in ipairs({ -2.2, 2.2 }) do
      ink.moveto(h[1] + dx - 1.4, h[2] + 0.4) ink.curveto(h[1] + dx - 0.6, h[2] - 0.5, h[1] + dx + 0.6, h[2] - 0.5, h[1] + dx + 1.4, h[2] + 0.4)
      ink.stroke(coat == "pale" and tone(0.1) or ink.accent(0.3), 0.4)
    end
  elseif P.face == "meow" then
    -- eyes half shut, the mouth open, three copper marks for the sound
    for _, sx in ipairs({ -1, 1 }) do
      local x, y = h[1] + sx * h[3] * 0.38, h[2] + h[4] * 0.12
      ink.moveto(x - 1.3, y - 0.1) ink.curveto(x - 0.5, y + 0.7, x + 0.5, y + 0.7, x + 1.3, y - 0.1)
      ink.stroke(ink.accent(0.15), 0.6)
    end
    ink.poly({ { h[1] - 0.7, h[2] - h[4] * 0.18 }, { h[1] + 0.7, h[2] - h[4] * 0.18 }, { h[1], h[2] - h[4] * 0.3 } }, true)
    ink.fill(nose_c, 0.95)
    ink.smooth(ellipse(h[1], h[2] - h[4] * 0.55, 1.1, 1.3, 12), true) ink.fill(tone(0.04))
    ink.smooth(ellipse(h[1], h[2] - h[4] * 0.66, 0.6, 0.45, 10), true) ink.fill(ink.accent(0.4))
    for k = 1, 3 do
      local r = h[3] + 1.5 + k * 1.6
      local arc = {}
      for a = -25, 25, 10 do arc[#arc + 1] = { h[1] + r * cos(a * rad), h[2] + r * sin(a * rad) } end
      ink.smooth(arc, false) ink.stroke(ink.accent(0), 0.45, 0.85)
    end
  elseif P.face == "side" then
    eye(h[1] + h[3] * 0.42, h[2] + h[4] * 0.12, 1.25)
    ink.poly({ { h[1] + h[3] * 1.02, h[2] - h[4] * 0.12 }, { h[1] + h[3] * 0.86, h[2] - h[4] * 0.02 }, { h[1] + h[3] * 0.88, h[2] - h[4] * 0.28 } }, true)
    ink.fill(nose_c, 0.9)
  else
    eye(h[1] - h[3] * 0.38, h[2] + h[4] * 0.1, 1.3)
    eye(h[1] + h[3] * 0.38, h[2] + h[4] * 0.1, 1.3)
    ink.poly({ { h[1] - 0.8, h[2] - h[4] * 0.22 }, { h[1] + 0.8, h[2] - h[4] * 0.22 }, { h[1], h[2] - h[4] * 0.36 } }, true)
    ink.fill(nose_c, 0.95)
  end
  if fine and P.face ~= "asleep" and P.face ~= "meow" then   -- whiskers
    local wx = P.face == "side" and h[1] + h[3] * 0.8 or h[1]
    local wy = h[2] - h[4] * 0.32
    for _, sd in ipairs(P.face == "side" and { 1 } or { -1, 1 }) do
      for k = -1, 1 do
        ink.moveto(wx + sd * 1.2, wy + k * 0.5) ink.curveto(wx + sd * 4, wy + k * 0.9 + 0.3, wx + sd * 6.5, wy + k * 1.4, wx + sd * 8.5, wy + k * 1.9 - 0.4)
      end
    end
    ink.stroke(coat == "pale" and tone(0.2) or white, 0.25, 0.7)
  end
  ink.pop()                                            -- the head's turn
  ink.pop()
end

-- A cat peeking out of a hole: the head and two paws on the hole's lower edge at the origin.
function M.peek(rng, o)
  o = o or {}
  local coat = o.coat or COATS[rng.int(1, #COATS)]
  local t0 = COAT_TONE[coat]
  ink.push() ink.scale(M.SCALE)
  local h = { 0, 5.5, 6.2, 5.6 }
  local ho = head_outline(h)
  local function shape() ink.smooth(ho, true) ink.smooth(ear_pts(h, -1), true, 0.3) ink.smooth(ear_pts(h, 1), true, 0.3) end
  shape() ink.fill(tone(t0))
  shape() ink.clip() mottle(rng, -8, -2, 8, 14, 3, 3, t0 - 0.1, t0 + 0.16, 0) ink.unclip()
  for _, dx in ipairs({ -3.4, 3.4 }) do
    ink.smooth(ellipse(dx, 0.2, 2.6, 1.6, 10), true) ink.fill(coat == "tux" and white or tone(t0 + 0.05))
  end
  for _, dx in ipairs({ -2.3, 2.3 }) do
    local x, y, r = dx, 6, 1.25
    ink.smooth({ { x - r, y }, { x, y + r * 0.62 }, { x + r, y }, { x, y - r * 0.62 } }, true, 0.9) ink.fill(ink.accent(0.15))
    ink.smooth({ { x, y + r * 0.55 }, { x + r * 0.2, y }, { x, y - r * 0.55 }, { x - r * 0.2, y } }, true, 0.6) ink.fill(tone(0.03))
  end
  ink.poly({ { -0.8, 4.1 }, { 0.8, 4.1 }, { 0, 3.3 } }, true) ink.fill(ink.accent(0.45))
  ink.pop()
end

-- ---------------------------------------------------------------- the page
-- grow.page hands the page over (a theme with its own composition, like theme-math).
function M.page(g, grow)
  local rng = ink.rng(g.seed * 7919 + 61)
  ink.set_transform(ink.page_transform(g.mirror and g.pw))
  local layout = rng.fork()
  local regions, col, foot, spill = grow.regions(g, layout)
  local fld = grow.field({ col, foot, spill })
  local anim = g.anim
  if anim then ink.record(true) end
  ink.layer(5)
  local events = {}
  local cats = M.compose(M, ink, g.seed, { col[1], col[2] + 0.15, col[3], g.headrule - 0.9 },
    { foot = foot, spill = spill, field = fld, D = g.density or 1, head = { g.colright - 0.5, g.headrule + 0.1 },
      pnum = { (g.textleft + g.textright) / 2, g.footy }, anim = anim, events = events, marks = g.marks, nocats = g.visitors == false, ceil = g.ph + 0.2, edges = { 0, nil } })
  local crng = ink.rng(g.seed * 7919 + 103)
  -- the cats come last, one after another, each growing in from its feet
  local tcat = 0.3
  for _, e in ipairs(events) do tcat = max(tcat, e.t0 + e.dur) end
  if g.visitors ~= false then
    for i, c in ipairs(cats) do
      local r = crng.fork()
      local function one()
        ink.push() ink.translate(c[1], c[2])
        if c[3] == "peek" then M.peek(r) else M.cat(r, c[3], c[4], c[5]) end
        ink.pop()
      end
      if anim then
        local e = { t0 = tcat + 0.25 * (i - 1), dur = 0.5 }
        events[#events + 1] = e
        local s0 = r.save()
        for k, v in ipairs({ 0.4, 0.7, 0.9 }) do
          r.load(s0)
          ink.tag({ e, (k - 1) / 3, k / 3 })
          ink.push() ink.translate(c[1], c[2]) ink.scale(v) ink.translate(-c[1], -c[2]) one() ink.pop()
        end
        r.load(s0)
        ink.tag({ e, 1 })
        one()
        ink.tag(nil)
      else
        one()
      end
    end
  end
  if anim then
    local total = 0.5
    for _, e in ipairs(events) do total = max(total, e.t0 + e.dur) end
    return { rec = ink.take_recording(), total = total }
  end
  ink.flush()
  return {}
end


-- ---------------------------------------------------------------- the initial
-- florilegium-initial.lua's tile with a cat instead of a vine (o.decorate): the letter, a cat
-- lying on its flattest top (or sitting, if there is little room) with its tail
-- hanging over the edge, a toy on a cord from the frame, a small scratching post
-- in the widest gap at the bottom, copper paw prints trotting across.
local function paw(x, y, r, a)
  ink.push() ink.translate(x, y) ink.rotate(a)
  ink.smooth({ { -r, -0.2 * r }, { -0.6 * r, 0.45 * r }, { 0, 0.55 * r }, { 0.6 * r, 0.45 * r }, { r, -0.2 * r }, { 0.5 * r, -0.65 * r }, { -0.5 * r, -0.65 * r } }, true)
  for _, t in ipairs({ { -1.05, 0.75 }, { -0.4, 1.2 }, { 0.4, 1.2 }, { 1.05, 0.75 } }) do
    ink.smooth(ellipse(t[1] * r, t[2] * r, r * 0.3, r * 0.38, 10), true)
  end
  ink.fill(ink.accent(0.05), 0.85)
  ink.pop()
end
function M.initial(c)
  local rng, S, m, cell = c.rng, c.S, c.m, c.cell
  -- the letter's top profile: for each column, the highest point inside it
  local cols = {}
  for i = 0, 35 do
    local x = (i + 0.5) * cell
    local yt
    for j = 35, 0, -1 do
      local y = (j + 0.5) * cell
      if c.inside(x, y) then yt = y break end
    end
    cols[#cols + 1] = { x, yt }
  end
  -- the widest flat stretch of that top
  local best, ba, bb = 0, 1, 1
  for a = 1, #cols do
    if cols[a][2] then
      local b = a
      while b < #cols and cols[b + 1][2] and abs(cols[b + 1][2] - cols[a][2]) < 0.03 * S do b = b + 1 end
      local w = cols[b][1] - cols[a][1]
      if w > best then best, ba, bb = w, a, b end
    end
  end
  local k = S / (M.SCALE * 100) * 0.95                  -- the cat's scale in the tile: 45 cm -> about 0.4 S
  -- the letter's counters: free cells that cannot be reached from the tile's edge
  local N = 36
  local reach, q = {}, {}
  local function key(i, j) return i * 64 + j end
  local function open_(i, j) return i >= 0 and j >= 0 and i < N and j < N and not c.inside((i + 0.5) * cell, (j + 0.5) * cell) end
  for i = 0, N - 1 do for _, j in ipairs({ 0, N - 1 }) do if open_(i, j) then reach[key(i, j)] = true q[#q + 1] = { i, j } end if open_(j, i) then reach[key(j, i)] = true q[#q + 1] = { j, i } end end end
  while #q > 0 do
    local cc = table.remove(q)
    for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local i, j = cc[1] + d[1], cc[2] + d[2]
      if open_(i, j) and not reach[key(i, j)] then reach[key(i, j)] = true q[#q + 1] = { i, j } end
    end
  end
  -- the widest counter: its cells' bounding box
  local cx0, cy0, cx1, cy1, ncell = math.huge, math.huge, -math.huge, -math.huge, 0
  for i = 0, N - 1 do for j = 0, N - 1 do
    if open_(i, j) and not reach[key(i, j)] then
      local x, y = (i + 0.5) * cell, (j + 0.5) * cell
      cx0, cy0, cx1, cy1, ncell = min(cx0, x), min(cy0, y), max(cx1, x), max(cy1, y), ncell + 1
    end
  end end
  local incounter = ncell > 0 and (cx1 - cx0) > 0.2 * S and (cy1 - cy0) > 0.12 * S and rng.chance(0.85)
  local cx = (cols[ba][1] + cols[bb][1]) / 2
  local cy = max(cols[ba][2], cols[bb][2]) + cell * 0.4
  -- face toward the wider side of the tile
  local facing = cx < S / 2 and 1 or -1
  -- wide tops: lying, stretching or draped over the end; narrow ones: sitting, meowing, batting the toy
  local pose = best >= 0.3 * S and rng.pick({ "loaf", "stretch", "drape" }) or rng.pick({ "sit", "meow", "bat" })
  -- the toy, from the top of the frame, on the side the cat faces
  ink.layer(4)
  local tx = facing > 0 and S - m - 0.16 * S or m + 0.16 * S
  local ty = S - m
  if pose == "bat" then                                -- right over the raised paw
    local kk = min(k, (S - m * 0.7 - cy) / (40 * M.SCALE))
    tx = cx + facing * 14.6 * M.SCALE * kk
  end
  local by = ty - 0.22 * S
  for _ = 1, 20 do
    if c.clearance(tx, by) > 0.05 * S then break end
    by = by + 0.01 * S
  end
  if by < ty - 0.06 * S then
    ink.moveto(tx, ty) ink.curveto(tx, ty - 0.05 * S, tx - 0.01 * S, by + 0.05 * S, tx, by + 0.03 * S)
    ink.stroke(ink.accent(-0.1), 0.35)
    ink.push() ink.translate(tx, by) ink.scale(S / 2.2)
    local r = 0.09
    plush(rng, soft(rng, 0, 0, r, r, 0.1, 14), 0.86, { size = r * 0.6 })
    for _ = 1, 16 do
      local a = rng.range(0, 2 * pi)
      ink.moveto(r * 0.85 * cos(a), r * 0.85 * sin(a)) ink.lineto(r * 1.3 * cos(a), r * 1.3 * sin(a))
    end
    ink.stroke(tone(0.55), 0.3, 0.7)
    ink.pop()
  end
  -- a small scratching post in the widest gap along the bottom, beside the letter
  local px, pw = nil, 0
  for _, q in ipairs(cols) do
    local cl = c.clearance(q[1], m + 0.2 * S)
    if cl > pw and not c.inside(q[1], m + 0.05 * S) then px, pw = q[1], cl end
  end
  if px and pw > 0.05 * S then
    local h = min(0.42 * S, 0.2 * S + pw * 2)
    local r = 0.045 * S
    for y = m + 0.02 * S, m + h, 0.02 * S do
      if c.clearance(px, y) < r * 1.2 then h = y - m - 0.03 * S break end
    end
    if h > 0.12 * S then
      ink.layer(2)
      sisal(rng, px - r, m * 1.1, px + r, m * 1.1 + h, { round = true, step = 0.012 * S })
      plush(rng, rrect(rng, px - r * 2.4, m * 1.1 + h, px + r * 2.4, m * 1.1 + h + 0.035 * S, 0.01, 0, 4), 0.32, { size = r })
      plush(rng, rrect(rng, px - r * 2.2, m * 1.05, px + r * 2.2, m * 1.1 + 0.02 * S, 0.01, 0, 4), 0.3, { size = r })
    end
  end
  -- paw prints across the bottom, where they do not fall on the letter
  ink.layer(5)
  local pr = 0.02 * S
  local x, up = m + 0.12 * S, 1
  while x < S - m - 0.08 * S do
    local y = m + 0.09 * S + up * 0.025 * S
    if c.clearance(x, y) > pr * 1.6 then paw(x, y, pr, -90 + 8 * up) end
    x, up = x + 0.085 * S, -up
  end
  -- the cat: curled up in the letter's counter, or on top of the letter, its tail
  -- hanging over the edge
  ink.layer(6)
  local crng = rng.fork()
  if incounter then
    -- as large as fits the counter: a curled cat is about 39 x 17 cm (with its ears)
    local kk = min((cx1 - cx0 + cell * 1.5) / (40 * M.SCALE), (cy1 - cy0 + cell) / (17 * M.SCALE))
    ink.push() ink.translate((cx0 + cx1) / 2, cy0 - cell * 0.05) ink.scale(kk)
    M.cat(crng, "curl", facing, nil, { coat = rng.pick({ "solid", "tabby", "tux", "blue" }) })
    ink.pop()
    ink.push() ink.translate(facing > 0 and m * 2.2 or S - m * 2.2, m * 2.2) flora.sparkle(rng, 0.04 * S) ink.pop()
    return
  end
  -- no taller than the room above the letter (a sitting cat is about 47 cm with its ears)
  local HT = { sit = 40, meow = 41, bat = 40, loaf = 24, drape = 24, stretch = 30 }
  k = min(k, (S - m * 0.7 - cy) / ((HT[pose] or 30) * M.SCALE))
  -- a drape at the edge of the flat top it lies on, toward where the cat faces
  if pose == "drape" then cx = (facing > 0 and cols[bb][1] or cols[ba][1]) - facing * 14 * M.SCALE * k end
  -- a stretching cat is long: keep it inside the frame
  if pose == "stretch" then k = min(k, (S - 2 * m) / (46 * M.SCALE)) cx = min(max(cx, m + 22 * M.SCALE * k), S - m - 22 * M.SCALE * k) end
  ink.push() ink.translate(cx, cy) ink.scale(k)
  if pose == "loaf" and rng.chance(0.6) then
    -- the tail, hanging down behind it, drawn first
    local tx0 = -facing * 0.9 * M.SCALE * 18
    local hang = 0.22 * S / k
    ink.push() ink.scale(facing, 1)
    ink.taper(-0.9, 0.2, -1.05, -hang * 0.3, -0.95, -hang * 0.7, -0.75, -hang, 0.16, 0.09)
    ink.pop()
    ink.fill(tone(0.15))
  end
  M.cat(crng, pose, facing, nil, { coat = rng.pick({ "solid", "tabby", "tux", "solid" }) })
  ink.pop()
  -- a copper sparkle in the far corner
  ink.layer(6)
  ink.push() ink.translate(facing > 0 and m * 2.2 or S - m * 2.2, m * 2.2) flora.sparkle(rng, 0.04 * S) ink.pop()
end

return M

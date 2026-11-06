-- florilegium-theme-kelp.lua -- a theme for florilegium: the margin as a kelp bed. The garden grows as it
-- always does (stems up the column from a root, branches into the holes, fillers, visitors), drawn as
-- seaweed and the things that live in it.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- What each of florilegium's primitives becomes:
--   stem      a kelp stipe; a main stem's root grips a rock with a holdfast (haptera)
--   leaf      a kelp blade, ruffled and wrinkled, a gas float at its base, leaning with the current
--   leaflet   a small blade with its float
--   flower    a sea anemone seen from above          lily     a bull kelp float, a fountain of blades
--   blossom   a sea star                            floret   a bubble
--   bud       a gas float on its stalk              bell     a jellyfish (it hangs, as a bell does)
--   cyme      feather boa kelp: a strap of small blades ending in a curl
--   sprig     a red seaweed, forking flat fronds    umbel    a sea palm: a stalk and a drooping crown
--   seedhead  a sea urchin                          tendril  a kelp tip curling (florilegium's spiral)
--   butterfly a fish (copper: a garibaldi now and then)
--   bee       a sea otter on its back, a shell on its chest, wrapped in a strand of kelp (M.otters a page)
--   snail     a shrimp clinging to the stipe       bird     a crab on its twig
--   sparkle   a few bubbles in copper
-- The current runs one way across the page (M.current, +1 to the right): blades and blade fountains lean
-- with it, fish and otters lie level whatever their branch, so the whole bed sways together.
-- Use: \usepackage[grown,theme=kelp]{florilegium}; Felilegium's "Kelp".

local ink = require("florilegium-ink")
local flora = require("florilegium-flora")
local M = {}
M.version = "2.0.0"

local sin, cos, sqrt, pi, abs, max, min, atan, floor = math.sin, math.cos, math.sqrt, math.pi, math.abs, math.max, math.min, math.atan, math.floor
local tone, white = ink.tone, ink.white
local rad = pi / 180
local function lerp(a, b, t) return a + (b - a) * t end
local function ghost() return ink.get_lift() > 0.3 end
local function fine(u) return ink.unit() > (u or 0.25) and not ghost() end

M.current = 1                  -- the current: +1 flows to the right of the page, -1 to the left
M.otters = 1                   -- otters a page, at most
local otter_row
function M.set_otters(n)
  M.otters = n
  if otter_row then otter_row.max, otter_row.w = n, n > 0 and 2 or 0 end
end

-- a page direction (px, py) in the local frame: the inverse of ink's transform, normalized
local function page_dir(px, py)
  local T = ink.get_transform()
  local det = T[1] * T[4] - T[2] * T[3]
  if abs(det) < 1e-12 then return 0, 1 end
  local x, y = (T[4] * px - T[3] * py) / det, (-T[2] * px + T[1] * py) / det
  local L = sqrt(x * x + y * y)
  return x / L, y / L
end
-- how far the current leans the local +y axis toward its local +x side (-1..1)
local function drift() local x = page_dir(M.current, 0) return x end
-- turn the frame so +y is the page's up and +x the way the current flows; returns nothing
local function level()
  local ux, uy = page_dir(0, 1)
  ink.rotate(atan(-ux, uy) / rad)
  local fx = page_dir(M.current, 0)
  if fx < 0 then ink.scale(-1, 1) end
end
local function ellipse(cx, cy, rx, ry, n, a0)
  local out = {}
  n = n or 14
  for k = 0, n - 1 do local a = (a0 or 0) + 2 * pi * k / n out[#out + 1] = { cx + rx * cos(a), cy + ry * sin(a) } end
  return out
end

-- ---------------------------------------------------------------- the rock and its holdfast
local rooted, rooted_on = {}, nil        -- roots already given a rock on this page
local function holdfast(rng, x, y, w)
  -- the rock: a boulder, a flat slab, or a heap of cobbles
  local kind = rng.pick({ "boulder", "slab", "cobbles", "boulder" })
  local rocks = {}
  if kind == "slab" then rocks[1] = { x + rng.sym(0.2), y - 0.18, rng.range(1.0, 1.4), rng.range(0.22, 0.32) }
  elseif kind == "cobbles" then
    for k = 1, rng.int(3, 4) do rocks[#rocks + 1] = { x + rng.sym(0.9), y - rng.range(0.1, 0.35), rng.range(0.3, 0.5), rng.range(0.22, 0.34) } end
  else rocks[1] = { x + rng.sym(0.25), y - 0.28, rng.range(0.7, 1.0), rng.range(0.42, 0.58) } end
  for _, r in ipairs(rocks) do
    local b = ink.blob(rng, r[1], r[2], r[3], r[4], 0.12, 12)
    ink.smooth(b, true) ink.fill(tone(rng.range(0.18, 0.26)))
    if fine(0.2) then
      ink.smooth(ink.blob(rng, r[1] - r[3] * 0.2, r[2] + r[4] * 0.25, r[3] * 0.55, r[4] * 0.45, 0.15, 9), true) ink.fill(tone(0.42), 0.55)
      for _ = 1, rng.int(4, 9) do                   -- pits and barnacles
        ink.circle(r[1] + rng.sym(r[3] * 0.7), r[2] + rng.sym(r[4] * 0.6), rng.range(0.015, 0.04)) ink.fill(tone(0.1), 0.7)
      end
    end
  end
  -- the haptera: little branching claws from the stipe's foot down over the rock
  local n = rng.int(7, 11)
  for k = 1, n do
    local a = lerp(-160, -20, (k - 0.5) / n) * rad + rng.sym(0.12)
    local L = rng.range(0.25, 0.5) * (0.6 + 0.6 * sin(-a))
    local ex, ey = x + L * cos(a), y + L * sin(a) * 0.7
    local mx, my = x + L * 0.5 * cos(a) + rng.sym(0.06), y + L * 0.2
    ink.smooth(ink.ribbon({ { x, y + 0.05 }, { mx, my }, { ex, ey } }, function(t) return w * lerp(0.55, 0.12, t) end), true)
    ink.fill(tone(0.12))
    if rng.chance(0.5) then                          -- a fork near the tip
      local fa = a + rng.sym(0.6)
      ink.moveto(lerp(mx, ex, 0.6), lerp(my, ey, 0.6)) ink.lineto(ex + 0.12 * cos(fa), ey + 0.12 * sin(fa) * 0.7)
      ink.stroke(tone(0.12), 0.4)
    end
  end
end

-- ---------------------------------------------------------------- stipes
-- a kelp stipe: florilegium's stem, darker and leaner; a stem rising from near the page's foot is a main
-- stem from the root, so its foot gets a rock and a holdfast (one for the stems sharing a root)
function M.stem(pts, w0, w1, c, op, tip)
  local T = ink.get_transform()
  if T ~= rooted_on then rooted, rooted_on = {}, T end
  local p = pts[1]
  if p and p[2] < 1.3 and not ghost() then            -- the root, at the foot of the margin
    local near = false
    for _, q in ipairs(rooted) do if abs(q[1] - p[1]) < 1.4 and abs(q[2] - p[2]) < 1.0 then near = true end end
    if not near then
      rooted[#rooted + 1] = { p[1], p[2] }
      holdfast(ink.rng(floor(p[1] * 1000 + p[2] * 37) + 7), p[1], p[2], max(w0, 0.06))
    end
  end
  flora.stem(pts, w0 * 0.85, w1 * 0.8, c or tone(0.14), op, tip)
end

-- ---------------------------------------------------------------- blades
-- a kelp blade along +y, length 1: narrow at the float, broad, ruffled at the edges and wrinkled across,
-- bending with the current; o.w its half-width, o.float false for none
local function blade(rng, o)
  o = o or {}
  local W = min(o.w or 1, rng.range(0.075, 0.115))     -- kelp is narrow, whatever leaf it stands in for
  local b = 0.32 * drift() + rng.sym(0.08) + (o.bend or 0) * 0.3
  local wave = rng.range(0.02, 0.05)
  local ph = rng.range(0, 2 * pi)
  local spine = function(v) return b * v ^ 1.7 + wave * sin(v * 7 + ph) * v, v end
  local hw = function(v) return W * sin(pi * min(1, v * 1.05) ^ 0.6) ^ 0.9 * (1 - 0.25 * v) end
  local ruff = function(v, side) return W * 0.1 * sin(v * 46 + side * 1.7 + ph) * sin(pi * v) end
  local out, c = ink.blade(spine, 26, hw, hw, fine(0.15) and ruff or nil)
  local t0 = o.tone or rng.range(0.36, 0.5)
  ink.smooth(out, true) ink.fill(tone(t0))
  if fine(0.25) then
    -- the darker side of the twist, and the wrinkles across the blade
    local half = {}
    for i = 1, #c do half[#half + 1] = { c[i][1], c[i][2] } end
    for i = #c, 1, -1 do local v = (i - 1) / (#c - 1) half[#half + 1] = { c[i][1] + hw(v) * 0.9, c[i][2] - 0.01 } end
    ink.smooth(half, true) ink.fill(tone(t0 - 0.12), 0.45)
    for k = 1, rng.int(3, 6) do
      local v = rng.range(0.15, 0.9)
      local x, y = spine(v)
      local w_ = hw(v) * rng.range(0.4, 0.8)
      ink.moveto(x - w_, y - 0.01) ink.curveto(x - w_ * 0.3, y + 0.02, x + w_ * 0.3, y - 0.02, x + w_, y + 0.01)
      ink.stroke(tone(t0 - 0.14), 0.25, 0.35)
    end
    ink.smooth({ { spine(0.06) }, { spine(0.5) }, { spine(0.92) } }, false) ink.stroke(white, 0.35, 0.35)
  end
  if o.float ~= false then                          -- the gas float at the blade's base
    ink.smooth(ellipse(0, -0.02, 0.045, 0.07, 12), true) ink.fill(tone(t0 - 0.1))
    if fine(0.2) then ink.circle(-0.015, 0.0, 0.015) ink.fill(white, 0.6) end
  end
end
M.leaf = blade
function M.leaflet(rng, o) blade(rng, { w = 0.17, bend = o and o.bend, tone = rng.range(0.32, 0.45) }) end

-- ---------------------------------------------------------------- the sea's blossoms
-- a sea anemone from above: a ring of tentacles round an oral disc; s = tentacle length (cm), centered
function M.flower(rng, s, o)
  local n = rng.int(16, 24)
  local R = s * 0.3
  for ring = 1, 2 do
    local L = s * (ring == 1 and 1 or 0.72)
    for k = 1, n do
      local a = 2 * pi * (k + (ring == 2 and 0.5 or 0)) / n + rng.sym(0.06)
      local curl = rng.sym(0.35)
      local x0, y0 = R * cos(a), R * sin(a)
      local x1, y1 = (R + L * 0.55) * cos(a + curl * 0.3), (R + L * 0.55) * sin(a + curl * 0.3)
      local x2, y2 = (R + L) * cos(a + curl), (R + L) * sin(a + curl)
      ink.smooth(ink.ribbon({ { x0, y0 }, { x1, y1 }, { x2, y2 } }, function(t) return s * lerp(0.11, 0.03, t) end), true)
      ink.fill(tone(ring == 1 and rng.range(0.36, 0.46) or rng.range(0.2, 0.3)))
      if fine(0.3) then ink.circle(x2, y2, s * 0.025) ink.fill(white, 0.7) end
    end
  end
  ink.circle(0, 0, R * 1.05) ink.fill(tone(0.16))
  if fine(0.25) then
    for k = 1, 12 do local a = 2 * pi * k / 12 ink.moveto(R * 0.35 * cos(a), R * 0.35 * sin(a)) ink.lineto(R * cos(a), R * sin(a)) end
    ink.stroke(tone(0.4), 0.3, 0.7)
  end
  ink.smooth(ellipse(0, 0, R * 0.35, R * 0.18, 10, rng.range(0, pi)), true) ink.fill(tone(0.04))
end

-- bull kelp: a stalk up from the origin to one round float, and a fountain of long blades streaming from
-- it with the current; s = the fountain's reach (cm), facing +y
function M.lily(rng, s, o)
  local fx, fy = 0.05 * s * drift(), 0.32 * s
  flora.stem({ { 0, -0.15 * s }, { fx * 0.5, fy * 0.5 }, { fx, fy - 0.08 * s } }, 0.06 * s, 0.09 * s, tone(0.14))
  local n = rng.int(6, 10)
  local d = drift()
  for k = 1, n do
    local spread = (k - (n + 1) / 2) / n
    ink.push() ink.translate(fx, fy + 0.04 * s) ink.rotate(-spread * 70 - d * 25 + rng.sym(8))
    ink.scale(s * rng.range(0.6, 0.85))
    blade(rng, { w = rng.range(0.06, 0.09), float = false, bend = d * 0.6 })
    ink.pop()
  end
  ink.circle(fx, fy, 0.11 * s) ink.fill(tone(0.18))
  if fine(0.25) then ink.circle(fx - 0.035 * s, fy + 0.035 * s, 0.035 * s) ink.fill(white, 0.5) end
end

-- a sea star, five arms; r = radius (cm), centered
function M.blossom(rng, r, o)
  local a0 = rng.range(0, 2 * pi)
  local pts = {}
  for k = 0, 9 do
    local a = a0 + pi * k / 5
    local rr = (k % 2 == 0) and r * rng.range(0.92, 1.05) or r * 0.38
    pts[#pts + 1] = { rr * cos(a), rr * sin(a) }
  end
  ink.smooth(pts, true, 0.35) ink.fill(tone(rng.range(0.24, 0.36)))
  if fine(0.3) then
    for k = 0, 4 do
      local a = a0 + 2 * pi * k / 5
      for j = 1, 4 do ink.circle(r * 0.2 * j * cos(a), r * 0.2 * j * sin(a), r * 0.045) end
    end
    ink.fill(tone(0.55), 0.9)
  end
end

-- a bubble: r = radius (cm)
function M.floret(rng, r, o)
  ink.circle(0, 0, r) ink.stroke(tone(0.3), max(0.25, r * 6), 0.8)
  ink.circle(-r * 0.35, r * 0.35, r * 0.25) ink.fill(tone(0.3), 0.7)
end

-- a gas float on its stalk: base at the origin, +y; s = length (cm)
function M.bud(rng, s, o)
  flora.stem({ { 0, 0 }, { 0.04 * s * drift(), 0.3 * s }, { 0.06 * s * drift(), 0.5 * s } }, 0.05 * s, 0.035 * s, tone(0.14))
  ink.smooth(ellipse(0.06 * s * drift(), 0.72 * s, 0.17 * s, 0.26 * s, 14), true) ink.fill(tone(0.22))
  if fine(0.2) then ink.circle(0.06 * s * drift() - 0.06 * s, 0.8 * s, 0.05 * s) ink.fill(white, 0.55) end
end

-- a jellyfish, hanging from the origin along -y: a bell, frilled arms and trailing tentacles; s = length
function M.bell(rng, s, o)
  local W, H = 0.36 * s, 0.32 * s
  local d = drift() * 0.15 * s
  for k = 1, rng.int(6, 9) do                       -- tentacles, trailing with the current
    local x0 = lerp(-W * 0.85, W * 0.85, (k - 0.5) / 8)
    local L = s * rng.range(0.7, 1.1)
    ink.smooth({ { x0, -H }, { x0 + d * 0.5 + rng.sym(0.05 * s), -H - L * 0.4 }, { x0 + d + rng.sym(0.08 * s), -H - L * 0.75 }, { x0 + d * 1.3, -H - L } }, false)
    ink.stroke(tone(0.3), 0.3, 0.75)
  end
  for k = 1, 4 do                                    -- the frilled oral arms
    local x0 = lerp(-W * 0.35, W * 0.35, (k - 0.5) / 4)
    local pts = {}
    for j = 0, 8 do local t = j / 8 pts[#pts + 1] = { x0 + d * t + 0.03 * s * sin(t * 12 + k), -H - s * 0.5 * t } end
    ink.smooth(ink.ribbon(pts, function(t) return s * lerp(0.07, 0.02, t) end), true) ink.fill(tone(0.38), 0.75)
  end
  local bell = {}
  for j = 0, 16 do
    local a = pi * j / 16
    bell[#bell + 1] = { W * cos(a), -H + H * 1.0 * sin(a) ^ 0.8 }
  end
  for j = 1, 9 do local t = j / 10 bell[#bell + 1] = { lerp(-W, W, t), -H - 0.03 * s * abs(sin(t * pi * 6)) } end
  ink.smooth(bell, true) ink.fill(tone(0.5), 0.7)
  if fine(0.25) then
    for k = 1, 4 do                                  -- the four rings seen through the bell
      local a = pi * (k - 0.5) / 4
      ink.smooth(ellipse(W * 0.5 * cos(a), -H * 0.45, W * 0.12, H * 0.14, 10), true)
      ink.stroke(tone(0.3), 0.35, 0.8)
    end
    ink.smooth({ { -W * 0.6, -H * 0.2 }, { -W * 0.2, -H * 0.02 }, { W * 0.2, -H * 0.05 } }, false) ink.stroke(white, 0.5, 0.6)
  end
end

-- feather boa kelp: a strap along +y set with small blades both sides, ending in a curl; L = length (cm)
function M.cyme(rng, L, o)
  local d = drift()
  local pts = {}
  for j = 0, 14 do local t = j / 14 pts[#pts + 1] = { L * (0.25 * d * t * t + 0.03 * sin(t * 9)), L * t * 0.92 } end
  flora.stem(pts, 0.05, 0.03, tone(0.14))
  for j = 2, 13 do
    local t = j / 14
    local p = pts[j + 1]
    for _, sd in ipairs({ -1, 1 }) do
      ink.push() ink.translate(p[1], p[2]) ink.rotate(sd * rng.range(50, 75) - d * 15) ink.scale(L * rng.range(0.1, 0.15) * (1 - 0.5 * t))
      blade(rng, { w = 0.2, float = false })
      ink.pop()
    end
  end
  local e = pts[#pts]
  ink.push() ink.translate(e[1], e[2]) ink.rotate(d > 0 and -20 or 200) flora.tendril(rng, 0.2 * L) ink.pop()
end

-- a red seaweed: flat fronds forking again and again; L = height (cm), from the origin along +y
function M.sprig(rng, L, o)
  local function frond(x, y, a, len, w, depth)
    local ex, ey = x + len * sin(a), y + len * cos(a)
    ink.smooth(ink.ribbon({ { x, y }, { lerp(x, ex, 0.5) + rng.sym(0.02), lerp(y, ey, 0.5) }, { ex, ey } }, function(t) return w * lerp(1, 0.75, t) end), true)
    ink.fill(tone(lerp(0.22, 0.4, (4 - depth) / 4)))
    if depth == 0 or len < 0.12 then
      ink.circle(ex, ey, w * 0.6) ink.fill(tone(0.4))
      return
    end
    local sp = rng.range(0.35, 0.6)
    frond(ex, ey, a - sp + rng.sym(0.1), len * rng.range(0.62, 0.8), w * 0.8, depth - 1)
    frond(ex, ey, a + sp + rng.sym(0.1), len * rng.range(0.62, 0.8), w * 0.8, depth - 1)
  end
  frond(0, 0, 0.1 * drift(), L * 0.3, max(0.035, L * 0.045), rng.int(3, 4))
end

-- a sea palm: a rubbery stalk, a crown of narrow blades drooping all round; R = height (cm)
function M.umbel(rng, R, o)
  local d = drift()
  local top = { 0.12 * R * d, R * 0.68 }
  flora.stem({ { 0, 0 }, { 0.03 * R * d, R * 0.35 }, top }, 0.11 * R, 0.07 * R, tone(0.16))
  local n = rng.int(9, 14)
  for k = 1, n do
    local a = lerp(-75, 75, (k - 0.5) / n) + rng.sym(6) - d * 12
    ink.push() ink.translate(top[1], top[2]) ink.rotate(a) ink.scale(R * rng.range(0.38, 0.5))
    blade(rng, { w = 0.07, float = false, bend = (a > 0 and 1 or -1) * 0.9 })
    ink.pop()
  end
end

-- a sea urchin: a dark ball bristling with spines; r = radius (cm), centered
function M.seedhead(rng, r, o)
  local n = fine(0.2) and 46 or 20
  for k = 1, n do
    local a = 2 * pi * k / n + rng.sym(0.05)
    local L = r * rng.range(0.95, 1.25)
    ink.moveto(0.45 * r * cos(a), 0.45 * r * sin(a)) ink.lineto(L * cos(a), L * sin(a))
  end
  ink.stroke(tone(0.12), max(0.3, r * 2.2))
  ink.circle(0, 0, r * 0.55) ink.fill(tone(0.08))
  if fine(0.25) then ink.circle(-r * 0.18, r * 0.18, r * 0.15) ink.fill(tone(0.4), 0.6) end
end

-- ---------------------------------------------------------------- visitors
-- a fish swimming with the current, level whatever its branch; s = length (cm). Now and then a garibaldi
-- in copper; else a rockfish or a striped perch in the ink
function M.butterfly(rng, s, o)
  level()
  local kind = rng.pick({ "garibaldi", "rockfish", "perch", "rockfish" })
  local paint = function()
    local L, H = s * 0.5, s * (kind == "garibaldi" and 0.24 or 0.19)
    local body = {}
    for j = 0, 18 do
      local a = 2 * pi * j / 18
      local x = L * cos(a)
      local y = H * sin(a) * (x > 0 and 1 or (0.55 + 0.45 * (1 + x / L)))
      body[#body + 1] = { x, y }
    end
    -- the tail, then the fins, then the body over them
    ink.poly({ { -L * 0.85, 0 }, { -L * 1.35, H * 0.95 }, { -L * 1.22, 0 }, { -L * 1.35, -H * 0.95 } }, true) ink.fill(tone(0.3))
    ink.smooth({ { -L * 0.3, H * 0.8 }, { L * 0.05, H * 1.55 }, { L * 0.35, H * 0.85 } }, true) ink.fill(tone(0.3))
    ink.smooth({ { -L * 0.2, -H * 0.8 }, { L * 0.0, -H * 1.3 }, { L * 0.2, -H * 0.8 } }, true) ink.fill(tone(0.32))
    ink.smooth(body, true) ink.fill(tone(kind == "garibaldi" and 0.45 or 0.38))
    if fine(0.2) then
      ink.smooth({ { -L * 0.9, -H * 0.1 }, { -L * 0.2, -H * 0.55 }, { L * 0.6, -H * 0.45 }, { L * 0.95, -H * 0.05 }, { L * 0.4, -H * 0.85 }, { -L * 0.5, -H * 0.75 } }, true)
      ink.fill(white, 0.35)                           -- the pale belly
      if kind == "perch" then
        for k = 1, 4 do local x = lerp(-L * 0.55, L * 0.4, k / 4) ink.moveto(x, H * 0.85) ink.lineto(x - L * 0.05, -H * 0.7) end
        ink.stroke(tone(0.14), max(0.35, s * 1.4), 0.75)
      elseif kind == "rockfish" then
        for _ = 1, 7 do ink.circle(rng.range(-L * 0.6, L * 0.5), rng.range(-H * 0.4, H * 0.7), s * 0.025) end
        ink.fill(tone(0.16), 0.8)
      end
      ink.smooth({ { L * 0.45, H * 0.65 }, { L * 0.35, 0 }, { L * 0.45, -H * 0.6 } }, false) ink.stroke(tone(0.16), max(0.3, s * 0.8), 0.7)
      ink.circle(L * 0.66, H * 0.2, s * 0.05) ink.fill(white)
      ink.circle(L * 0.67, H * 0.2, s * 0.028) ink.fill(tone(0.05))
    end
  end
  if kind == "garibaldi" then ink.in_accent(paint) else paint() end
end

-- a sea otter floating on its back, belly up, a shell held on its chest, a strand of kelp wrapped over it so
-- it doesn't drift; level, head toward the current. s = length nose to tail (cm), centered
function M.bee(rng, s, o)
  level()
  local L, H = s * 0.5, s * 0.15
  -- the strand of kelp it holds itself to, across the page under it
  ink.smooth({ { -L * 1.3, -H * 0.3 }, { -L * 0.4, -H * 0.9 }, { L * 0.4, H * 0.2 }, { L * 1.3, -H * 0.5 } }, false)
  ink.stroke(tone(0.16), max(0.5, s * 2.2))
  -- tail, body, belly, head
  ink.smooth({ { -L * 0.78, -H * 0.1 }, { -L * 1.1, H * 0.15 }, { -L * 1.32, H * 0.05 }, { -L * 1.12, -H * 0.25 } }, true) ink.fill(tone(0.16))
  local body = {}
  for j = 0, 20 do
    local a = 2 * pi * j / 20
    body[#body + 1] = { L * 0.82 * cos(a), H * sin(a) * (sin(a) > 0 and 1.15 or 0.9) }
  end
  ink.smooth(body, true) ink.fill(tone(0.2))
  if fine(0.2) then ink.smooth(ellipse(L * 0.05, H * 0.45, L * 0.6, H * 0.4, 16), true) ink.fill(tone(0.42), 0.8) end
  -- the hind feet up in the air, the head lifted, pale face
  ink.smooth({ { -L * 0.6, H * 0.7 }, { -L * 0.75, H * 1.5 }, { -L * 0.5, H * 1.65 }, { -L * 0.45, H * 0.9 } }, true) ink.fill(tone(0.16))
  ink.smooth(ellipse(L * 0.9, H * 0.55, L * 0.24, H * 0.95, 16, 0.2), true) ink.fill(tone(0.24))
  if fine(0.2) then
    ink.smooth(ellipse(L * 0.98, H * 0.65, L * 0.15, H * 0.62, 14, 0.2), true) ink.fill(tone(0.62))
    ink.circle(L * 1.05, H * 1.05, s * 0.018) ink.circle(L * 0.92, H * 1.15, s * 0.018) ink.fill(tone(0.04))
    ink.circle(L * 1.12, H * 0.72, s * 0.022) ink.fill(tone(0.04))
    ink.circle(L * 0.8, H * 1.38, s * 0.03) ink.fill(tone(0.18))   -- an ear
    for k = -1, 1 do ink.moveto(L * 1.12, H * 0.65) ink.lineto(L * 1.32, H * (0.6 + k * 0.18)) end
    ink.stroke(tone(0.1), 0.25, 0.7)
  end
  -- the shell on its chest, held in its forepaws
  ink.in_accent(function()
    local sx, sy = L * 0.45, H * 1.05
    local sh = {}
    for j = 0, 12 do local a = pi * j / 12 sh[#sh + 1] = { sx + s * 0.08 * cos(a), sy + s * 0.06 * sin(a) } end
    ink.smooth(sh, true) ink.fill(tone(0.42))
    if fine(0.2) then for k = 1, 5 do local a = pi * k / 6 ink.moveto(sx, sy) ink.lineto(sx + s * 0.075 * cos(a), sy + s * 0.055 * sin(a)) end ink.stroke(tone(0.2), 0.3) end
  end)
  ink.smooth(ellipse(L * 0.32, H * 1.0, s * 0.035, s * 0.05, 10), true) ink.smooth(ellipse(L * 0.6, H * 1.05, s * 0.035, s * 0.05, 10), true)
  ink.fill(tone(0.16))
end

-- a shrimp clinging to the stipe, head up along +y, its legs on the y axis; s = size (cm)
function M.snail(rng, s, o)
  local L = s * 1.1
  local seg = {}
  for j = 0, 7 do                                    -- the curled body, segment by segment
    local t = j / 7
    local a = lerp(1.35, -0.2, t)
    seg[#seg + 1] = { L * 0.35 * cos(a) + L * 0.1, L * (0.9 - 0.95 * t) }
  end
  for j = #seg, 1, -1 do
    local p = seg[j]
    local r = L * lerp(0.07, 0.13, (j - 1) / 7)
    ink.circle(p[1], p[2], r) ink.fill(tone(lerp(0.42, 0.32, (j - 1) / 7)), 0.95)
  end
  ink.poly({ { seg[8][1] - L * 0.05, seg[8][2] }, { seg[8][1] - L * 0.2, seg[8][2] - L * 0.12 }, { seg[8][1] + L * 0.12, seg[8][2] - L * 0.12 } }, true) ink.fill(tone(0.3))
  if fine(0.2) then
    for j = 2, 6 do ink.moveto(seg[j][1] - L * 0.05, seg[j][2]) ink.lineto(L * 0.0, seg[j][2] - L * 0.04) end
    ink.stroke(tone(0.15), 0.35)
    local h = seg[1]
    ink.moveto(h[1], h[2]) ink.curveto(h[1] - L * 0.1, h[2] + L * 0.4, h[1] - L * 0.5, h[2] + L * 0.5, h[1] - L * 0.7, h[2] + L * 0.3)
    ink.moveto(h[1], h[2]) ink.curveto(h[1] + L * 0.1, h[2] + L * 0.45, h[1] + L * 0.4, h[2] + L * 0.6, h[1] + L * 0.55, h[2] + L * 0.45)
    ink.stroke(tone(0.2), 0.3)
    ink.circle(h[1] + L * 0.06, h[2] + L * 0.02, L * 0.035) ink.fill(tone(0.04))
  end
end

-- a crab on its twig, side on, claws up; feet at the origin, s = width (cm)
function M.bird(rng, s, o)
  local W, H = s * 0.5, s * 0.28
  local base = H * 0.6
  for _, sd in ipairs({ -1, 1 }) do                   -- three walking legs a side, jointed, splayed out
    for k = 1, 3 do
      local x0 = sd * W * lerp(0.3, 0.7, k / 3)
      local kx, ky = x0 + sd * W * lerp(0.45, 0.7, k / 3), base + H * lerp(0.9, 0.55, k / 3)
      ink.moveto(x0, base + H * 0.3) ink.lineto(kx, ky) ink.lineto(kx + sd * W * 0.18, 0)
    end
  end
  ink.stroke(tone(0.2), max(0.35, s * 1.1))
  for _, sd in ipairs({ -1, 1 }) do                   -- the claws, raised
    local cx, cy = sd * W * 0.85, base + H * 1.6
    ink.moveto(sd * W * 0.6, base + H * 0.6) ink.lineto(cx, cy - H * 0.4) ink.stroke(tone(0.2), max(0.5, s * 2.5))
    ink.smooth({ { cx - W * 0.16, cy - H * 0.35 }, { cx - W * 0.2, cy + H * 0.3 }, { cx + sd * W * 0.05, cy + H * 0.55 }, { cx + W * 0.18, cy + H * 0.1 }, { cx + W * 0.12, cy - H * 0.3 } }, true)
    ink.fill(tone(0.28))
    if fine(0.2) then ink.moveto(cx, cy + H * 0.05) ink.lineto(cx + sd * W * 0.12, cy + H * 0.5) ink.stroke(white, 0.4, 0.7) end
  end
  local shell = {}
  for j = 0, 16 do local a = pi * j / 16 shell[#shell + 1] = { W * 0.78 * cos(a), base + H * 1.05 * sin(a) } end
  ink.smooth(shell, true) ink.fill(tone(0.3))
  if fine(0.2) then
    ink.smooth(ellipse(-W * 0.2, base + H * 0.6, W * 0.32, H * 0.28, 12), true) ink.fill(tone(0.5), 0.5)
    for _, sd in ipairs({ -1, 1 }) do
      ink.moveto(sd * W * 0.15, base + H * 0.95) ink.lineto(sd * W * 0.2, base + H * 1.35) ink.stroke(tone(0.15), 0.4)
      ink.circle(sd * W * 0.2, base + H * 1.38, s * 0.03) ink.fill(tone(0.04))
    end
  end
end

-- a few bubbles in copper, rising: r = size (cm), centered
function M.sparkle(rng, r, o)
  ink.in_accent(function()
    for k = 1, 3 do
      local rr = r * (0.55 - 0.12 * k)
      ink.circle(rng.sym(r * 0.25), (k - 2) * r * 0.9, rr) ink.stroke(tone(0.35), 0.35)
    end
  end)
end

-- ---------------------------------------------------------------- the theme
M.flora = {
  stem = M.stem, leaf = M.leaf, leaflet = M.leaflet,
  flower = M.flower, lily = M.lily, blossom = M.blossom, floret = M.floret, bud = M.bud, bell = M.bell,
  cyme = M.cyme, sprig = M.sprig, umbel = M.umbel, seedhead = M.seedhead,
  butterfly = M.butterfly, bee = M.bee, snail = M.snail, bird = M.bird, sparkle = M.sparkle,
}

function M.motifs(rows, F)
  local by = {}                     -- luacheck: ignore 241 (the rows are changed through it)
  for _, m in ipairs(rows) do by[m.name] = m end
  local up = function(rng, s, n, fn)               -- things rising in a loose column, the way bubbles go
    for k = 1, n do
      local y = s * (k - 1) * rng.range(0.38, 0.5)
      ink.push() ink.translate(rng.sym(s * 0.15), y) fn(k) ink.pop()
    end
  end
  -- blossoms: a column of bubbles rising off a blade
  by.blossoms.draw = function(rng, s)
    up(rng, s, rng.int(3, 6), function(k) F.floret(rng, s * rng.range(0.07, 0.16) * (1 + 0.15 * k)) end)
  end
  by.blossoms.upright = 1.0
  -- the bells: one jellyfish, or two drifting together
  by.bells.draw = function(rng, s)
    F.bell(rng, s)
    if rng.chance(0.4) then ink.push() ink.translate(0.6 * s, -0.25 * s) F.bell(rng, 0.6 * s) ink.pop() end
  end
  by.bells.w, by.bells.max = 1.2, 2
  -- more sea stars and urchins than flora has seed heads; fewer anemones than flowers
  by.seedhead.spring, by.seedhead.summer, by.seedhead.autumn, by.seedhead.max = 0.3, 0.3, 0.3, 2
  by.flower.w, by.flower.smin, by.flower.smax, by.flower.max = 0.8, 0.55, 0.85, 1
  -- sea stars: a row of their own, on the blades and stipes as they climb kelp
  rows[#rows + 1] = { name = "star", w = 1.6, smin = 0.3, smax = 0.55, max = 3, hard = true, layer = by.bud.layer, upright = 0.2,
    r = function(s) return 1.0 * s end, off = function(s) return 0.6 * s end,
    draw = function(rng, s) ink.translate(0, 0.6 * s) F.blossom(rng, s) end }
  -- the otter: the bee's place, larger, as many as M.otters a page (M.set_otters changes it later: the
  -- rows are made once a document)
  by.bee.smin, by.bee.smax = 2.0, 2.6
  by.bee.r = function(s) return 0.62 * s end
  otter_row = by.bee
  M.set_otters(M.otters)
  -- the fish: a little more often than butterflies
  by.butterfly.w, by.butterfly.max = 1.2, 3
  return rows
end

return M

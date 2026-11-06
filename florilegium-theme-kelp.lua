-- florilegium-theme-kelp.lua -- a kelp forest on a whole page, without TeX (Felilegium's "Kelp forest").
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- M.forest(rng, o): o = { w, h (cm), keepouts = { {x0, y0, x1, y1}, ... } (page cm, y up), otters (a page),
-- current (+1: the water runs to the right) }. Painted back to front:
--   1. the far bunches, pale (behind everything else)
--   2. the seafloor: sand with ripples and pebbles; rocks (boulders, slabs, cobbles, a reef ledge)
--   3. the near bunches: each on a rock, a holdfast gripping it, stipes rising to the surface in a slow
--      wave, steering round the text, then lying over into the canopy with the current; blades along each
--      stipe, a gas float at the foot of each, leaning downstream; now and then a bull kelp instead
--   4. the understory between the rocks: sea palms, red seaweed, eelgrass
--   5. what lives there: fish in open water (a school, a garibaldi, a rockfish, a kelp bass), otters on their
--      backs at the surface, jellyfish, a shrimp, and on the rocks and the sand crabs, sea stars, urchins,
--      anemones, a whelk, a skate's egg case caught in a holdfast; bubbles rising
-- Everything keeps clear of the keep-outs. Delft blue (the ink's ramp); the garibaldi in the accent.

local ink = require("florilegium-ink")
local M = {}
M.version = "2.0.0"

local sin, cos, pi, abs, max, min, floor = math.sin, math.cos, math.pi, math.abs, math.max, math.min, math.floor
local tone, white = ink.tone, ink.white
local rad = pi / 180
local function lerp(a, b, t) return a + (b - a) * t end
local function clamp(v, a, b) return max(a, min(b, v)) end
local function fine() return ink.get_lift() < 0.3 end
local function ellipse(cx, cy, rx, ry, n, a0)
  local out = {}
  n = n or 16
  for k = 0, n - 1 do local a = (a0 or 0) + 2 * pi * k / n out[#out + 1] = { cx + rx * cos(a), cy + ry * sin(a) } end
  return out
end
local function fill(pts, c, op) ink.smooth(pts, true) ink.fill(c, op) end

-- ---------------------------------------------------------------- kelp
-- one blade from (x, y), its axis at `ang` (degrees from up, + toward the current), L long: narrow at the
-- float, broad, ruffled, trailing with the current as it goes
function M.blade(rng, x, y, ang, L, W, cur, t0)
  local a = ang * rad
  local trail = (0.3 + rng.range(0, 0.45)) * cur
  local ph = rng.range(0, 2 * pi)
  local spine = function(v)
    local s = v * L
    local bend = trail * v * v * L                 -- the far end swings downstream
    local wob = 0.05 * L * sin(v * 6 + ph) * v
    local lx, ly = bend + wob, s
    return x + lx * cos(a) + ly * sin(a), y - lx * sin(a) + ly * cos(a)
  end
  local hw = function(v) return W * sin(pi * min(1, v * 1.04) ^ 0.55) ^ 0.85 * (1 - 0.3 * v) end
  local ruff = function(v, side) return W * 0.13 * sin(v * L * 26 + side * 1.9 + ph) * sin(pi * v) end
  local out = ink.blade(spine, max(10, floor(L * 12)), hw, hw, fine() and ruff or nil)
  ink.smooth(out, true) ink.fill(tone(t0))
  if fine() then
    local mid = {}
    for k = 1, 5 do mid[k] = { spine(0.1 + 0.18 * (k - 1)) } end
    ink.smooth(mid, false) ink.stroke(tone(t0 - 0.12), 0.35, 0.5)   -- the fold down the blade
  end
  -- the float at its foot
  local da, db = sin(a), cos(a)
  local pear = {}
  for k = 0, 13 do
    local th = 2 * pi * k / 14
    local u = (1 - cos(th)) / 2                     -- 0 at the neck, 1 at the round end
    local sw = sin(th) * W * 0.62 * u ^ 0.7
    local l = u * W * 1.5
    pear[#pear + 1] = { x + l * da + sw * db, y + l * db - sw * da }
  end
  fill(pear, tone(t0 - 0.12))
  if fine() then ink.circle(x + W * 1.05 * da - W * 0.18 * db, y + W * 1.05 * db + W * 0.18 * da, W * 0.17) ink.fill(white, 0.45) end
end

-- the holdfast: a low cone of fine, branching haptera, from the stipes' foot at (x, y + w * 0.45) spreading
-- out and down over the rock, w wide at the rock; no knob, the roots themselves make its shape
local function holdfast(rng, x, y, w, t0)
  local apex = y + w * 0.45
  local n = max(14, floor(w * 22))
  for k = 1, n do
    local u = (k - 0.5) / n
    local ex = x + (u - 0.5) * w * rng.range(1.0, 1.25)
    local ey = y + rng.range(-0.04, 0.06) - abs(u - 0.5) * w * 0.15
    local sx = x + (u - 0.5) * w * 0.18
    local c1x, c1y = lerp(sx, ex, 0.25), lerp(apex, ey, 0.6)
    local pts = {}
    for j = 0, 6 do
      local t = j / 6
      local a, b = 1 - t, t
      pts[#pts + 1] = { a * a * sx + 2 * a * b * c1x + b * b * ex, a * a * apex + 2 * a * b * c1y + b * b * ey }
    end
    ink.smooth(ink.ribbon(pts, function(t) return lerp(0.05, 0.018, t) end), true)
    ink.fill(tone(t0 + rng.range(-0.06, 0.06)))
    if rng.chance(0.55) then                         -- a fork near the foot
      local m = pts[5]
      ink.moveto(m[1], m[2]) ink.lineto(m[1] + (u - 0.5) * w * 0.3 + rng.sym(0.06), ey - rng.range(0.0, 0.06))
      ink.stroke(tone(t0), 0.45)
    end
  end
end

-- ---------------------------------------------------------------- the floor
-- a lump: an irregular round outline, upright (never turned), flattened where it sits on the sand
local function lump(rng, x, y, rx, ry, rough, n)
  n = n or 14
  local ph, ph2 = rng.range(0, 2 * pi), rng.range(0, 2 * pi)
  local out = {}
  for i = 0, n - 1 do
    local a = 2 * pi * i / n
    local k = 1 + rough * (0.6 * sin(2 * a + ph) + 0.4 * sin(3 * a + ph2)) + rough * 0.4 * rng.sym(1)
    local py = ry * k * sin(a)
    if py < 0 then py = py * 0.55 end                  -- a flatter underside
    out[#out + 1] = { x + rx * k * cos(a), y + py }
  end
  return out
end
-- one stone: an angular outline (chipped, not round), sitting on the sand at y, cx its middle, w wide, h high
local function stone(rng, cx, y, w, h, sharp)
  local n = rng.int(7, 10)
  local pts = {}
  for i = 0, n - 1 do
    local a = pi * i / (n - 1)                          -- the top half, left to right... then the flat foot
    local k = 1 + rng.sym(sharp)
    pts[#pts + 1] = { cx - w / 2 * cos(a) * k, y + h * sin(a) ^ 0.7 * k }
  end
  pts[#pts + 1] = { cx + w / 2 + w * 0.04, y - h * 0.08 }
  pts[#pts + 1] = { cx - w / 2 - w * 0.04, y - h * 0.08 }
  return pts
end
-- a rock at (x, y) on the floor, w wide: stones of its kind, each with a lit top face and a shaded side
-- split along a ridge, cracks, pale crusts of coralline and a few tufts; a shadow and a lip of sand at the
-- foot. Returns its top (where kelp holds)
local function rock(rng, x, y, w, kind, t0)
  local parts = {}
  if kind == "slab" then parts[1] = { x, w, w * rng.range(0.2, 0.28), 0.1 }
  elseif kind == "cobbles" then
    for _ = 1, rng.int(3, 5) do local s_ = w * rng.range(0.25, 0.42) parts[#parts + 1] = { x + rng.sym(w * 0.32), s_, s_ * rng.range(0.55, 0.8), 0.12 } end
  elseif kind == "ledge" then
    parts[1] = { x, w, w * rng.range(0.32, 0.42), 0.14 }
    parts[2] = { x + w * rng.sym(0.18), w * 0.55, w * 0.25, 0.16 }
  else parts[1] = { x, w, w * rng.range(0.45, 0.6), 0.12 } end
  -- the shadow on the sand, then each stone back to front
  fill(ellipse(x + w * 0.08, y + 0.02, w * 0.6, w * 0.07, 16), tone(0.62), 0.7)
  local top = y
  local base = y
  for pi_, p in ipairs(parts) do
    local cx, sw, sh = p[1], p[2], p[3]
    local by = base + (pi_ > 1 and parts[1][3] * 0.55 or 0)   -- a second stone of a ledge sits on the first
    local out = stone(rng, cx, by, sw, sh, p[4])
    ink.poly(out, true) ink.fill(tone(t0))
    top = max(top, by + sh)
    if fine() then
      -- the lit face: the upper left part of the outline, down to a ridge across the stone
      local ridge = { cx + sw * rng.range(0.05, 0.25), by + sh * rng.range(0.35, 0.55) }
      local lit = {}
      for i = 1, floor(#out * 0.55) do lit[#lit + 1] = out[i] end
      lit[#lit + 1] = ridge
      lit[#lit + 1] = { cx - sw * 0.35, by + sh * 0.2 }
      ink.poly(lit, true) ink.fill(tone(t0 + 0.16), 0.85)
      -- the shaded side, low on the right
      ink.poly({ ridge, out[#out - 2], { cx + sw * 0.5, by }, { cx + sw * 0.1, by } }, true) ink.fill(tone(t0 - 0.08), 0.7)
      -- a crack or two from the ridge
      for _ = 1, rng.int(1, 2) do
        local ax, ay = ridge[1] + rng.sym(sw * 0.15), ridge[2] + rng.sym(sh * 0.1)
        ink.moveto(ax, ay) ink.lineto(ax + rng.sym(sw * 0.12), ay - sh * rng.range(0.2, 0.4)) ink.lineto(ax + rng.sym(sw * 0.2), ay - sh * rng.range(0.4, 0.6))
        ink.stroke(tone(t0 - 0.12), 0.45, 0.8)
      end
      -- pale crusts of coralline on the lit face, barnacles as specks
      for _ = 1, rng.int(1, 3) do
        fill(ellipse(cx + rng.sym(sw * 0.3), by + sh * rng.range(0.55, 0.85), sw * rng.range(0.06, 0.12), sh * rng.range(0.04, 0.08), 9, rng.sym(0.4)), tone(0.7), 0.8)
      end
      for _ = 1, floor(sw * 6) do ink.circle(cx + rng.sym(sw * 0.4), by + rng.range(sh * 0.1, sh * 0.8), rng.range(0.012, 0.03)) end
      ink.fill(tone(t0 + 0.25), 0.8)
    end
  end
  -- a lip of sand against the foot
  fill({ { x - w * 0.62, y - 0.06 }, { x - w * 0.3, y + 0.07 }, { x, y + 0.04 }, { x + w * 0.35, y + 0.08 }, { x + w * 0.62, y - 0.06 } }, tone(0.86))
  return top
end

-- the sand along the floor, `top` high, with ripples and pebbles
local function sand(rng, W, top)
  local edge = { { -0.2, -0.2 } }
  for k = 0, 40 do local x = W * k / 40 edge[#edge + 1] = { x, top + 0.12 * sin(x * 1.3 + 1) + 0.06 * sin(x * 3.7) } end
  edge[#edge + 1] = { W + 0.2, -0.2 }
  ink.smooth(edge, true) ink.fill(tone(0.88))
  if not fine() then return end
  for _ = 1, floor(W * 1.6) do                        -- ripples
    local x, y = rng.range(0, W), rng.range(0.1, top - 0.1)
    local L = rng.range(0.4, 1.1)
    ink.moveto(x, y) ink.curveto(x + L * 0.3, y + 0.06, x + L * 0.7, y + 0.06, x + L, y) ink.stroke(tone(0.7), 0.4, 0.8)
  end
  for _ = 1, floor(W * 3) do                          -- pebbles and bits of shell
    local x, y = rng.range(0, W), rng.range(0.05, top - 0.05)
    fill(ellipse(x, y, rng.range(0.03, 0.08), rng.range(0.02, 0.05), 8, rng.range(0, pi)), tone(rng.range(0.5, 0.75)))
  end
end

-- ---------------------------------------------------------------- the creatures
-- each draws at the origin, in cm; side views face +x unless flipped by the caller

-- a fish, side on, facing +x; kind: garibaldi (deep, rounded), rockfish (spiny, mottled), bass (spotted),
-- senorita (slender, for schools); L = length nose to tail
function M.fish(rng, kind, L)
  local H = L * ({ garibaldi = 0.42, rockfish = 0.33, bass = 0.28, senorita = 0.18 })[kind]
  local t0 = kind == "garibaldi" and 0.45 or kind == "senorita" and 0.5 or 0.36
  local nose, tail = L * 0.5, -L * 0.32
  -- the body: a deep front, a narrowing to the tail stalk
  local top, bot = {}, {}
  for k = 0, 12 do
    local u = k / 12                                   -- 0 nose .. 1 tail stalk
    local x = lerp(nose, tail, u)
    local d = sin(pi * min(1, (u + 0.05) * 0.95) ^ 0.75)
    top[#top + 1] = { x, H * 0.5 * d * (kind == "garibaldi" and 1.05 or 1) + H * 0.04 }
    bot[#bot + 1] = { x, -H * 0.5 * d * 0.92 }
  end
  local body = {}
  for k = 1, #top do body[#body + 1] = top[k] end
  for k = #bot, 1, -1 do body[#body + 1] = bot[k] end
  local fin = tone(t0 - 0.08)
  -- tail: forked, or rounded for a garibaldi
  if kind == "garibaldi" then fill({ { tail + L * 0.02, H * 0.1 }, { tail - L * 0.18, H * 0.38 }, { tail - L * 0.24, 0 }, { tail - L * 0.18, -H * 0.38 }, { tail + L * 0.02, -H * 0.1 } }, fin)
  else
    ink.poly({ { tail + L * 0.03, H * 0.08 }, { tail - L * 0.2, H * 0.42 }, { tail - L * 0.13, 0 }, { tail - L * 0.2, -H * 0.42 }, { tail + L * 0.03, -H * 0.08 } }, true) ink.fill(fin)
  end
  -- dorsal fin: spiny for a rockfish or a bass, a long soft one for the others
  local dors = {}
  local spiny = kind == "rockfish" or kind == "bass"
  local n = spiny and 11 or 6
  for k = 0, n do
    local u = k / n
    local x = lerp(L * 0.18, -L * 0.28, u)
    local base = H * 0.5 * sin(pi * min(1, ((nose - x) / (nose - tail) + 0.05) * 0.95) ^ 0.75) + H * 0.02
    local up = H * (spiny and (k % 2 == 0 and 0.42 or 0.24) * (1 - 0.4 * u) or 0.3 * sin(pi * u) + 0.06)
    dors[#dors + 1] = { x, base + up }
  end
  dors[#dors + 1] = { -L * 0.28, H * 0.2 } dors[#dors + 1] = { L * 0.18, H * 0.3 }
  if spiny then ink.poly(dors, true) else ink.smooth(dors, true) end
  ink.fill(fin)
  -- anal fin
  fill({ { -L * 0.02, -H * 0.38 }, { -L * 0.14, -H * 0.62 }, { -L * 0.24, -H * 0.28 } }, fin)
  -- the body over the fins
  fill(body, tone(t0))
  if fine() then
    -- countershading: a paler belly
    local belly = {}
    for k = 2, #bot - 1 do belly[#belly + 1] = { bot[k][1], bot[k][2] * 0.95 } end
    for k = #bot - 1, 2, -1 do belly[#belly + 1] = { bot[k][1], bot[k][2] * 0.2 } end
    fill(belly, white, kind == "garibaldi" and 0.15 or 0.4)
    if kind == "rockfish" then for _ = 1, 9 do fill(ellipse(rng.range(tail * 0.8, nose * 0.6), rng.range(-H * 0.1, H * 0.35), L * 0.04, L * 0.025, 8), tone(t0 - 0.16), 0.7) end end
    if kind == "bass" then for _ = 1, 14 do ink.circle(rng.range(tail * 0.8, nose * 0.5), rng.range(-H * 0.2, H * 0.35), L * 0.014) end ink.fill(tone(0.9), 0.8) end
    if kind == "senorita" then ink.smooth({ { nose * 0.8, 0 }, { 0, H * 0.02 }, { tail, 0 } }, false) ink.stroke(tone(t0 - 0.2), max(0.3, L * 0.6), 0.6) end
    -- scales: a few rows of arcs
    for r = -1, 1 do
      for k = 1, 6 do
        local x, y = lerp(nose * 0.45, tail * 0.75, k / 6), r * H * 0.18
        ink.moveto(x, y + L * 0.025) ink.curveto(x - L * 0.025, y + L * 0.02, x - L * 0.025, y - L * 0.02, x, y - L * 0.025)
      end
    end
    ink.stroke(tone(t0 - 0.12), 0.25, 0.5)
    -- gill cover, pectoral fin, mouth, eye
    ink.smooth({ { nose - L * 0.2, H * 0.38 }, { nose - L * 0.25, 0 }, { nose - L * 0.2, -H * 0.36 } }, false) ink.stroke(tone(t0 - 0.16), 0.4, 0.8)
    fill({ { nose - L * 0.27, -H * 0.02 }, { nose - L * 0.45, H * 0.08 }, { nose - L * 0.43, -H * 0.18 } }, tone(t0 - 0.1), 0.85)
    ink.moveto(nose, -H * 0.06) ink.lineto(nose - L * 0.05, -H * 0.1) ink.stroke(tone(t0 - 0.25), 0.35)
    local ex, ey, er = nose - L * 0.11, H * 0.12, L * 0.045
    ink.circle(ex, ey, er) ink.fill(tone(0.95))
    ink.circle(ex + er * 0.15, ey, er * 0.62) ink.fill(tone(0.05))
    ink.circle(ex - er * 0.15, ey + er * 0.25, er * 0.2) ink.fill(white)
  end
end

-- the sea otter, a rig of a spine with radius profiles, a head frame, flippers and paws that each pose fills in
-- (by marginalia-partner): o.pose "clam", "asleep", "pup" or "dive", o.age 0..1, o.water (a waterline at y = 0).
-- Drawn at the origin, head toward +x, L = nose to tail tip, in cm.
local OT = (function()
  local M = {}

  local sin, cos, pi, abs, max, min, sqrt, floor = math.sin, math.cos, math.pi, math.abs, math.max, math.min, math.sqrt, math.floor
  local tone, white = ink.tone, ink.white
  local rad = pi / 180
  local CM = 72 / 2.54
  local function lerp(a, b, t) return a + (b - a) * t end
  local function clamp(v, a, b) return max(a, min(b, v)) end

  -- ---------------------------------------------------------------- helpers
  local function area(p)
    local s = 0
    for i = 1, #p do local a, b = p[i], p[i % #p + 1] s = s + a[1] * b[2] - b[1] * a[2] end
    return s
  end
  local function ccw(p)
    if area(p) >= 0 then return p end
    local r = {}
    for i = #p, 1, -1 do r[#r + 1] = p[i] end
    return r
  end
  local function ellipse(cx, cy, rx, ry, n, a0)
    local out = {}
    n = n or 16
    local ca, sa = cos(a0 or 0), sin(a0 or 0)
    for k = 0, n - 1 do
      local a = 2 * pi * k / n
      local x, y = rx * cos(a), ry * sin(a)
      out[#out + 1] = { cx + x * ca - y * sa, cy + x * sa + y * ca }
    end
    return out
  end
  -- a smooth curve through pts, as f(v) -> x, y by arclength, and its length
  local function curve(pts)
    local c = ink.catmull(pts, 10)
    local s = { 0 }
    for i = 2, #c do s[i] = s[i - 1] + sqrt((c[i][1] - c[i - 1][1]) ^ 2 + (c[i][2] - c[i - 1][2]) ^ 2) end
    local T = s[#c]
    return function(v)
      local t = clamp(v, 0, 1) * T
      local lo, hi = 1, #c
      while hi - lo > 1 do local m = (lo + hi) // 2 if s[m] <= t then lo = m else hi = m end end
      local f = (t - s[lo]) / max(1e-9, s[hi] - s[lo])
      return lerp(c[lo][1], c[hi][1], f), lerp(c[lo][2], c[hi][2], f)
    end, T
  end
  -- a piecewise-linear profile from { {v, value}, ... }, eased
  local function profile(t)
    return function(v)
      for i = 2, #t do
        if v <= t[i][1] then
          local f = (v - t[i - 1][1]) / (t[i][1] - t[i - 1][1])
          f = f * f * (3 - 2 * f)
          return lerp(t[i - 1][2], t[i][2], f)
        end
      end
      return t[#t][2]
    end
  end
  -- a frame: local (u, w) -> rig (x, y), at (x, y) turned by a degrees, scaled s, mirrored by m (-1 flips w)
  local function frame(x, y, a, s, m)
    local c, sn = cos(a * rad), sin(a * rad)
    m = m or 1
    return function(u, w) u = u * m return x + s * (u * c - w * sn), y + s * (u * sn + w * c) end
  end
  local function mapped(F, pts) local out = {} for i, p in ipairs(pts) do out[i] = { F(p[1], p[2]) } end return out end

  -- ---------------------------------------------------------------- poses: each fills in a rig, in units of L
  local POSES = {}

  local function floatrig(rng)
    local lift = rng.range(6, 28)                      -- the head held up off the water, degrees
    local girth = rng.range(0.9, 1.12)                 -- a lean animal or a stout one
    local ch = rng.range(-0.012, 0.016)                -- how high the chest rides
    local r = {
      up = true, water = 0,
      -- tail tip to base, flat on the water; the spine from the rump through the hips, belly and chest to
      -- the neck (inside the head): the chest rides highest, the hips at the waterline
      tail = { { -0.5, 0.022 + rng.sym(0.01) }, { -0.38, 0.012 }, { -0.21, 0.004 } },
      tailw = 0.034,
      spine = { { -0.29, -0.004 }, { -0.16, 0.002 }, { -0.02, 0.024 + ch * 0.4 }, { 0.1, 0.052 + ch * 0.8 }, { 0.2, 0.083 + ch }, { 0.27, 0.118 + ch }, { 0.33, 0.15 + ch } },
      top = profile({ { 0, 0.0 }, { 0.05, 0.036 }, { 0.2, 0.064 }, { 0.5, 0.094 }, { 0.66, 0.1 }, { 0.82, 0.088 }, { 1, 0.04 } }),
      bot = profile({ { 0, 0.0 }, { 0.05, 0.032 }, { 0.25, 0.058 }, { 0.55, 0.074 }, { 0.78, 0.07 }, { 1, 0.04 } }),
      head = { 0.352, 0.155 + ch, lift, 0.09 },
      -- hind flippers: hip (where the leg leaves the body), heel, angle of the foot (degrees from +x), length, far?
      feet = {
        { -0.17, 0.045, -0.2, 0.1, 104 + rng.sym(14), 0.105 * rng.range(0.9, 1.1), true, rng.range(0.78, 1.15) },
        { -0.13, 0.05, -0.155, 0.105, 88 + rng.sym(14), 0.11 * rng.range(0.9, 1.1), false, rng.range(0.78, 1.15) },
      },
    }
    local t, b = r.top, r.bot
    r.top = function(v) return t(v) * girth end
    r.bot = function(v) return b(v) * girth end
    if rng.chance(0.25) then table.remove(r.feet, 1) end   -- one foot down in the water
    r.ch = ch
    return r
  end

  local function lift(r, dy, rng)                       -- arms ride with the chest; paws a little this way or that
    for _, a in ipairs(r.arms or {}) do
      a[2], a[4] = a[2] + dy, a[4] + dy
      if rng then a[3], a[4] = a[3] + rng.sym(0.012), a[4] + rng.sym(0.008) end
    end
  end
  POSES.clam = function(rng)
    local r = floatrig(rng)
    r.arms = { { 0.21, 0.12, 0.105, 0.172, true }, { 0.2, 0.115, 0.2, 0.19, false } }
    r.prop = "clam"
    r.clam = { 0.15, 0.192 + r.ch }
    lift(r, r.ch, rng)
    return r
  end
  -- a head-frame point in rig units, for paws that reach the face
  local function onhead(r, u, w) local h = r.head return frame(h[1], h[2], h[3], h[4])(u, w) end
  POSES.asleep = function(rng, o)
    local r = floatrig(rng)
    r.head[3] = rng.range(0, 6)                        -- the head back on the water
    r.face = "asleep"
    r.prop = "kelp"
    local cover = o.cover
    if cover == nil then cover = rng.chance(0.4) end
    if cover then                                      -- paws over its eyes, as sea otters sleep in the light
      local nx, ny = onhead(r, 0.5, 0.3)
      local fx, fy = onhead(r, 0.22, 0.5)
      r.arms = { { 0.26, 0.15 + r.ch, fx, fy, true, 0.035 }, { 0.25, 0.145 + r.ch, nx, ny, false, 0.035 } }
      r.late = true
    else                                               -- paws folded on the chest
      r.arms = { { 0.21, 0.12, 0.14, 0.168, true }, { 0.2, 0.115, 0.205, 0.178, false } }
      lift(r, r.ch, rng)
    end
    return r
  end
  POSES.groom = function(rng)
    local r = floatrig(rng)
    r.head[3] = rng.range(24, 36)                      -- the chin up, rubbing its face with both paws
    if rng.chance(0.5) then r.face = "asleep" end      -- eyes screwed shut
    local nx, ny = onhead(r, rng.range(0.6, 0.85), rng.range(-0.55, -0.35))
    local fx, fy = onhead(r, rng.range(0.15, 0.4), rng.range(-0.75, -0.5))
    r.arms = { { 0.26, 0.15 + r.ch, fx, fy, true, 0.035 }, { 0.25, 0.145 + r.ch, nx, ny, false, 0.035 } }
    r.late = true
    return r
  end
  POSES.pup = function(rng)
    local r = floatrig(rng)
    r.arms = { { 0.21, 0.12, 0.04, 0.2, true }, { 0.2, 0.115, 0.1, 0.215, false } }    -- holding the pup
    r.prop = "pup"
    lift(r, r.ch, rng)
    return r
  end
  POSES.dive = function(rng)
    local b = rng.range(0.9, 1.15)                     -- how steeply it goes down
    return {
      up = false, water = nil, taper = 0.5,
      tail = { { -0.47, 0.16 * b + rng.sym(0.02) }, { -0.36, 0.1 * b }, { -0.23, 0.058 * b } },
      tailw = 0.038,
      spine = { { -0.25, 0.064 * b }, { -0.14, 0.036 * b }, { -0.02, 0.0 }, { 0.1, -0.048 * b }, { 0.19, -0.1 * b }, { 0.27, -0.17 * b } },
      top = profile({ { 0, 0.0 }, { 0.06, 0.034 }, { 0.15, 0.05 }, { 0.45, 0.065 }, { 0.75, 0.062 }, { 1, 0.04 } }),   -- the back
      bot = profile({ { 0, 0.0 }, { 0.06, 0.035 }, { 0.2, 0.055 }, { 0.5, 0.07 }, { 0.8, 0.062 }, { 1, 0.04 } }),         -- the belly
      head = { 0.315, -0.205 * b, -38 * b, 0.082 },
      feet = {
        { -0.18, 0.03 * b, -0.25, 0.0 * b, 190 + rng.sym(14), 0.12, true, rng.range(0.85, 1.2) },
        { -0.14, 0.02 * b, -0.22, -0.03 * b, 202 + rng.sym(14), 0.125, false, rng.range(0.85, 1.2) },
      },
      arms = { { 0.15, -0.1 * b, 0.2, -0.17 * b, true }, { 0.14, -0.11 * b, 0.19, -0.18 * b, false } },   -- tucked to the chest
    }
  end

  -- ---------------------------------------------------------------- the otter
  function M.otter(rng, L, o)
    o = o or {}
    local pose = POSES[o.pose] and o.pose or "clam"
    local R = POSES[pose](rng, o)
    local age = o.age or rng.range(0, 1)
    local t0 = (o.tone or 0.24) + rng.sym(0.03)
    ink.push()
    ink.scale(L)
    local D = ink.unit()                                -- the otter's length on the page, cm
    local fine = D > 3.2 and ink.get_lift() < 0.3       -- fur, whiskers, toe lines
    local bp = function(f) return f * D * CM end        -- a width as a fraction of L, in bp
    local water = R.water
    if o.water == false then water = nil end

    -- the body's outline: a blade along the spine, tufted on top when fine
    local sp = curve(R.spine)
    local ph = rng.range(0, 2 * pi)
    local tuft = fine and function(v, side) local q = (v * 46 + ph + side * 0.5) % 1 return 0.004 * (q < 0.25 and q / 0.25 or 1 - (q - 0.25) / 0.75) ^ 2 * sin(pi * v) end or nil
    local body = ccw((ink.blade(sp, 40, R.top, R.bot, tuft)))
    local tl = curve(R.tail)
    local tw = R.tailw
    local tp = R.taper or 0                             -- the tail narrowing toward its tip (0: parallel-sided)
    local tws = function(v) return tw * (0.6 + 0.4 * sin(pi * min(1, v * 1.08)) ^ 0.35) * (1 - tp * (1 - v)) end
    local tail = ccw((ink.blade(tl, 20, function(v) return tws(v) * (1.05 - 0.25 * abs(v - 0.55)) end,
      function(v) return tws(v) * 0.8 end)))

    -- the head, in its own frame: nose toward +u, r its radius
    local h = R.head
    local hr = h[4] * rng.range(0.96, 1.06)
    local H = frame(h[1], h[2], h[3], hr)
    local skull = ccw(mapped(H, ellipse(0, 0, 1, 0.9, 18)))
    local pads = ccw(mapped(H, ellipse(0.72, -0.28, 0.56, 0.46, 14)))        -- the wide whisker pads
    local jowl = ccw(mapped(H, ellipse(0.25, -0.5, 0.65, 0.42, 14)))
    local ear = ccw(mapped(H, ellipse(-0.42, 0.8, 0.2, 0.13, 10, 0.5)))

    local function silhouette()
      ink.smooth(tail, true)
      ink.smooth(body, true)
      ink.smooth(skull, true) ink.smooth(pads, true) ink.smooth(jowl, true) ink.smooth(ear, true, 0.5)
    end

    -- hind flipper from its heel (hx, hy), pointing at a (degrees), length f: a broad webbed fan,
    -- five toes, the outer one longest
    local function flipper(hip_x, hip_y, hx, hy, a, f, far, spread)
      spread = spread or 1
      local c = tone(t0 - (far and 0.08 or 0.0))
      -- the leg, short and thick
      ink.smooth(ink.ribbon({ { hip_x, hip_y }, { lerp(hip_x, hx, 0.5), lerp(hip_y, hy, 0.5) + 0.005 }, { hx, hy } }, function(u) return lerp(0.06, 0.04, u) end), true)
      ink.fill(c)
      local F = frame(hx, hy, a - 90, f, R.up and 1 or -1)
      local pts = { { 0.16, 0.02 }, { 0.3, 0.45 } }
      local toes = { 0.86, 0.93, 0.97, 1.0, 1.05 }        -- inner to outer
      for k = 1, 5 do
        local u = lerp(0.34, -0.4, (k - 1) / 4) * spread
        local tip = toes[k]
        pts[#pts + 1] = { u + 0.06, tip - 0.035 }
        pts[#pts + 1] = { u, tip }
        pts[#pts + 1] = { u - 0.06, tip - 0.035 }
        if k < 5 then pts[#pts + 1] = { u - 0.092, tip - 0.06 } end   -- the web between toes, shallow
      end
      pts[#pts + 1] = { -0.42 * spread, 0.45 }
      pts[#pts + 1] = { -0.14, 0.02 }
      local P = mapped(F, pts)
      ink.smooth(P, true, 0.8) ink.fill(c)
      if fine then
        for k = 1, 5 do
          local u = lerp(0.34, -0.4, (k - 1) / 4) * spread
          local a1, b1 = F(u * 0.4, 0.35)
          local a2, b2 = F(u, toes[k] - 0.12)
          ink.moveto(a1, b1) ink.lineto(a2, b2)
        end
        ink.stroke(tone(t0 + 0.14), bp(0.0035), 0.6)
        -- a lit edge on the outer toe
        local e = {}
        for _, q in ipairs({ { -0.14, 0.05 }, { -0.36, 0.45 }, { -0.36, 0.95 } }) do e[#e + 1] = { F(q[1], q[2]) } end
        ink.smooth(e, false) ink.stroke(white, bp(0.004), 0.25)
      end
    end

    -- forearm from the shoulder (sx, sy) to the paw (px, py): short, ending in a round mitten
    local function arm(sx, sy, px, py, far, elbow)
      local c = tone(t0 - (far and 0.09 or 0.02))
      local mx, my = lerp(sx, px, 0.5), lerp(sy, py, 0.5) + (elbow or 0.012)
      local w0 = elbow and 0.042 or 0.05
      ink.smooth(ink.ribbon({ { sx, sy }, { mx, my }, { px, py } }, function(u) return lerp(w0, 0.032, u) end), true)
      ink.fill(c)
      ink.smooth(ellipse(px, py, 0.026, 0.021, 12, 0.3), true) ink.fill(tone(t0 - (far and 0.13 or 0.08)))
      if fine and not far then
        ink.moveto(mx - 0.01, my + 0.016) ink.lineto(px - 0.006, py + 0.02)
        ink.stroke(white, bp(0.004), 0.22)
      end
    end

    -- ---------------------------------------------------------------- painting, back to front
    for _, f in ipairs(R.feet) do if f[7] then flipper(f[1], f[2], f[3], f[4], f[5], f[6], true, f[8]) end end
    if R.arms then for _, a in ipairs(R.arms) do if a[5] and pose == "dive" then arm(a[1], a[2], a[3], a[4], true) end end end

    silhouette() ink.stroke(tone(t0 - 0.14), bp(0.007))
    silhouette() ink.fill(tone(t0))
    silhouette() ink.clip()
      -- the side away from the light: the back when floating, the belly's far side when diving
      local under = ink.blade(sp, 30, function() return 0 end, function(v) return R.bot(v) * 1.2 end)
      ink.smooth(under, true) ink.fill(tone(t0 - 0.1), 0.6)
      ink.smooth(ink.blade(tl, 16, function() return 0 end, function() return tw * 1.2 end), true) ink.fill(tone(t0 - 0.1), 0.5)
      -- the chest and belly paler on a float (the fur is lighter there, and lit)
      for b = 1, 3 do                                 -- the lit side in three soft bands
        local k = ({ 0.0, 0.35, 0.62 })[b]
        ink.smooth(ink.blade(sp, 30, function(v) return R.top(v) * 1.1 end, function(v) return -R.top(v) * k end), true)
        ink.fill(tone(t0 + (R.up and 0.1 or 0.06)), 0.32)
      end
      -- fur: short ticks along the spine, dark and light
      local n = fine and floor(12 + 8 * D) or 0
      for pass = 1, 2 do
        for _ = 1, n do
          local v = rng.range(0.02, 0.98)
          local x, y = sp(v)
          local x2, y2 = sp(v + 0.02)
          local dx, dy = x2 - x, y2 - y
          local l = sqrt(dx * dx + dy * dy) + 1e-9
          dx, dy = dx / l, dy / l
          local off = (rng.chance(0.5) and R.top(v) or -R.bot(v)) * rng.range(0.55, 0.92)
          local px, py = x - dy * off, y + dx * off
          local k = 0.014 * rng.range(0.6, 1.2)
          ink.moveto(px, py) ink.curveto(px - dx * k * 0.4, py - dy * k * 0.4 + 0.003, px - dx * k * 0.8, py - dy * k * 0.8 + 0.003, px - dx * k, py - dy * k)
        end
        if pass == 1 then ink.stroke(tone(t0 - 0.12), bp(0.0028), 0.4) else ink.stroke(tone(t0 + 0.24), bp(0.0024), 0.35) end
      end
      -- the lit streak along the top of the body
      local streak = {}
      for k = 0, 8 do
        local v = 0.08 + 0.8 * k / 8
        local x, y = sp(v)
        streak[#streak + 1] = { x, y + R.top(v) * 0.72 }
      end
      ink.smooth(streak, false) ink.stroke(white, bp(R.up and 0.012 or 0.008), R.up and 0.22 or 0.16)
      -- the face: pale, more so with age, grizzled
      local pale = tone(lerp(0.55, 0.88, age))
      for b = 1, 6 do
        local g = 1.02 - 0.08 * b
        ink.smooth(mapped(H, ellipse(0.66 - 0.12 * g, -0.12 + 0.05 * g, 0.86 * g, 0.8 * g, 18, -0.2)), true)
        ink.fill(pale, lerp(0.1, 0.24, age))
      end
      if age > 0.4 then                               -- an old animal's pale reaches the chest
        local cx, cy = H(0.05, -0.8)
        ink.smooth(ellipse(cx, cy, 0.07, 0.04, 12, h[3] * rad), true) ink.fill(tone(0.75), (age - 0.4) * 0.45)
      end
      if fine and age > 0.1 then
        local spots = { { 0.35, 0.45, 0.28 }, { 0.75, -0.15, 0.22 }, { 0.2, -0.35, 0.3 }, { -0.15, 0.2, 0.3 } }
        for _, c in ipairs(spots) do
          for _ = 1, floor(4 + 16 * age * c[3] / 0.3) do
            local a, d = rng.range(0, 2 * pi), c[3] * rng.range(0, 1) ^ 1.6
            local x, y = H(c[1] + d * cos(a), c[2] + d * sin(a) * 0.8)
            ink.circle(x, y, hr * rng.range(0.012, 0.022) * (0.7 + 0.5 * age))
          end
        end
        ink.fill(white, 0.35 + 0.4 * age)
      end
    ink.unclip()

    -- the near flipper, then the water over what is below it
    for _, f in ipairs(R.feet) do if not f[7] then flipper(f[1], f[2], f[3], f[4], f[5], f[6], false, f[8]) end end

    -- props behind the paws
    if R.prop == "kelp" then
      local sx = rng.range(-0.04, 0.04)
      local strap = { { sx - 0.11, -0.05 }, { sx - 0.07, 0.04 }, { sx - 0.03, 0.115 }, { sx + 0.03, 0.15 }, { sx + 0.09, 0.14 }, { sx + 0.12, 0.08 }, { sx + 0.14, -0.02 } }
      local kc = curve(strap)
      local wob = function(v, s_) return fine and 0.0025 * sin(v * 80 + s_) or 0 end
      local k = ink.blade(kc, 36, function(v) return 0.014 + 0.003 * sin(v * 19) end, function(v) return 0.014 + 0.003 * sin(v * 15 + 1) end, wob)
      ink.smooth(k, true) ink.fill(tone(0.5))
      local mid = {}
      for q = 1, 9 do mid[#mid + 1] = { kc(q / 10) } end
      ink.smooth(mid, false) ink.stroke(tone(0.34), bp(0.003), 0.7)
      -- a blade of it floating on the water by the hips, and its float
      local bl = curve({ { sx - 0.1, 0.0 }, { sx - 0.2, 0.012 }, { sx - 0.3, 0.004 }, { sx - 0.38, 0.016 } })
      ink.smooth(ink.blade(bl, 24, function(v) return 0.012 * sin(pi * v) ^ 0.6 end, function(v) return 0.006 * sin(pi * v) ^ 0.6 end, wob), true)
      ink.fill(tone(0.4))
      ink.circle(sx - 0.1, 0.004, 0.012) ink.fill(tone(0.34))
      if fine then ink.circle(sx - 0.104, 0.009, 0.004) ink.fill(white, 0.5) end
    end
    if R.prop == "pup" then
      -- a pup on the chest, head toward +x as its mother's: rounder, fluffier, paler, a big head
      local px, py = 0.06, 0.19 + R.ch
      local pt = min(0.62, t0 + 0.3)
      local function fluff(cx, cy, rx, ry, n)
        local out = {}
        for q = 0, n - 1 do
          local a = 2 * pi * q / n
          local rr = 1 + 0.035 * (q % 2 == 0 and 1 or -1)
          out[#out + 1] = { cx + rx * rr * cos(a), cy + ry * rr * sin(a) }
        end
        return ccw(out)
      end
      local pb = fluff(px, py, 0.1, 0.048, 40)
      local phd = fluff(px + 0.115, py + 0.03, 0.058, 0.054, 30)
      ink.smooth(pb, true) ink.smooth(phd, true) ink.stroke(tone(pt - 0.2), bp(0.006))
      ink.smooth(pb, true) ink.smooth(phd, true) ink.fill(tone(pt))
      ink.smooth(ellipse(px - 0.01, py + 0.02, 0.07, 0.018, 12), true) ink.fill(white, 0.3)
      ink.smooth(ellipse(px + 0.135, py + 0.025, 0.04, 0.036, 14), true) ink.fill(tone(min(0.9, pt + 0.18)), 0.8)
      -- the pup's face
      ink.circle(px + 0.135, py + 0.045, 0.0075) ink.fill(tone(0.06))
      ink.smooth(ellipse(px + 0.168, py + 0.026, 0.011, 0.008, 8), true) ink.fill(tone(0.08))
      if fine then ink.circle(px + 0.133, py + 0.047, 0.0024) ink.fill(white, 0.9) end
      -- its tiny hind feet sticking up at the back
      ink.smooth(ellipse(px - 0.085, py + 0.045, 0.011, 0.022, 10, 0.4), true) ink.fill(tone(pt - 0.15))
    end

    -- the forepaws
    local function forepaws() if R.arms then for _, a in ipairs(R.arms) do if not (a[5] and pose == "dive") then arm(a[1], a[2], a[3], a[4], a[5], a[6]) end end end end
    if not R.late then forepaws() end
    if R.prop == "clam" then
      local cx, cy = R.clam[1], R.clam[2]
      ink.in_accent(function()
        local sh = {}
        for k = 0, 14 do local a = pi * (0.05 + 0.9 * k / 14) sh[#sh + 1] = { cx + 0.04 * cos(a), cy - 0.012 + 0.034 * sin(a) } end
        sh[#sh + 1] = { cx + 0.012, cy - 0.022 } sh[#sh + 1] = { cx - 0.012, cy - 0.022 }
        ink.smooth(sh, true, 0.8) ink.fill(tone(0.42))
        if D > 2.5 then
          for k = 1, 6 do local a = pi * (0.12 + 0.76 * k / 7) ink.moveto(cx, cy - 0.016) ink.lineto(cx + 0.037 * cos(a), cy - 0.014 + 0.031 * sin(a)) end
          ink.stroke(tone(0.22), bp(0.003), 0.8)
          ink.moveto(cx - 0.03, cy + 0.01) ink.curveto(cx - 0.01, cy + 0.024, cx + 0.01, cy + 0.024, cx + 0.03, cy + 0.01)
          ink.stroke(white, bp(0.004), 0.4)
        end
      end)
      -- the near paw over the front of the shell
      local a = R.arms[2]
      ink.smooth(ellipse(a[3] - 0.012, a[4] - 0.004, 0.022, 0.018, 12, 0.3), true) ink.fill(tone(t0 - 0.06))
    end

    -- the face's features, in the head frame
    do
      -- the nose: big, dark, a rounded triangle
      local nose = mapped(H, { { 1.12, 0.06 }, { 1.38, 0.0 }, { 1.36, -0.2 }, { 1.2, -0.3 }, { 1.06, -0.16 } })
      ink.smooth(nose, true, 0.8) ink.fill(tone(0.05))
      if D > 2.5 then
        local x, y = H(1.22, -0.02)
        ink.circle(x, y, hr * 0.05) ink.fill(white, 0.45)
      end
      -- the mouth, under the pads
      local m = mapped(H, { { 1.18, -0.32 }, { 1.1, -0.56 }, { 0.9, -0.66 }, { 0.68, -0.6 } })
      ink.smooth(m, false) ink.stroke(tone(t0 - 0.1), bp(0.004), 0.8)
      -- the eye, small and dark
      local ex, ey = H(0.52, 0.28)
      if R.face == "asleep" then
        local a1, b1 = H(0.38, 0.32) local a2, b2 = H(0.52, 0.22) local a3, b3 = H(0.66, 0.3)
        ink.moveto(a1, b1) ink.curveto(a2, b2, a2, b2, a3, b3) ink.stroke(tone(0.05), bp(0.005))
      else
        ink.circle(ex, ey, hr * 0.13) ink.fill(tone(0.03))
        ink.circle(ex - hr * 0.035, ey + hr * 0.045, hr * 0.045) ink.fill(white, 0.9)
      end
      -- the ear's opening
      local ax, ay = H(-0.4, 0.78)
      ink.circle(ax, ay, hr * 0.07) ink.fill(tone(0.06), 0.8)
      if fine then
        -- whisker rows on the pads, and the whiskers, long and pale
        for q = 1, 9 do local x, y = H(0.62 + 0.09 * (q % 3), -0.12 - 0.11 * (q // 3)) ink.circle(x, y, hr * 0.02) end
        ink.fill(tone(t0 - 0.05), 0.8)
        for q = 0, 3 do                             -- from the pads, forward and down past the chin
          local x0, y0 = H(0.84 - q * 0.04, -0.34 - q * 0.08)
          local x1, y1 = H(1.2 - q * 0.04, -0.52 - q * 0.14)
          local x2, y2 = H(1.5 - q * 0.1, -0.78 - q * 0.24)
          ink.moveto(x0, y0) ink.curveto(x1, y1, x1, y1, x2, y2)
        end
        ink.stroke(white, bp(0.002), 0.8)
        for q = 0, 1 do                             -- two back along the cheek
          local x0, y0 = H(0.66, -0.4 - q * 0.08)
          local x1, y1 = H(0.35, -0.62 - q * 0.12)
          local x2, y2 = H(0.08, -0.72 - q * 0.2)
          ink.moveto(x0, y0) ink.curveto(x1, y1, x1, y1, x2, y2)
        end
        ink.stroke(white, bp(0.0017), 0.55)
        -- eyebrow whiskers
        local b0x, b0y = H(0.5, 0.42) local b1x, b1y = H(0.7, 0.8)
        ink.moveto(b0x, b0y) ink.lineto(b1x, b1y) ink.stroke(white, bp(0.002), 0.7)
      end
    end
    if R.late then forepaws() end                      -- paws over the face

    -- the water across a float: what lies under it paled, and a broken line of ripples
    if water then
      silhouette() ink.clip()
        ink.poly({ { -0.6, water - 0.3 }, { 0.6, water - 0.3 }, { 0.6, water }, { -0.6, water } }, true) ink.fill(tone(0.88), 0.55)
      ink.unclip()
      local w0 = water
      for k = 0, 9 do
        local x = lerp(-0.58, 0.55, k / 9) + rng.sym(0.02)
        local l = rng.range(0.05, 0.1)
        ink.moveto(x, w0 + rng.sym(0.004)) ink.curveto(x + l * 0.3, w0 + 0.008, x + l * 0.7, w0 + 0.008, x + l, w0)
      end
      ink.stroke(tone(0.55), bp(0.004), 0.8)
    end
    ink.pop()
  end

  M.POSES = { "clam", "asleep", "pup", "groom", "dive" }
  return M
end)()
function M.otter(rng, L, o) return OT.otter(rng, L, o) end
M.OTTER_POSES = OT.POSES

-- a crab seen head on, standing at the origin: a wide shell, eyes on stalks, both claws raised, four jointed
-- legs a side splayed out and down to the ground; s = shell width
function M.crab(rng, s)
  local W, H = s * 0.5, s * 0.26
  local by = s * 0.28                                  -- the shell's lower rim, above the ground
  for _, sd in ipairs({ -1, 1 }) do
    for k = 1, 4 do                                    -- the legs: out from under the rim to a knee, then down
      local u = (k - 1) / 3
      local x0 = sd * W * lerp(0.45, 0.8, u)
      local kx, ky = sd * W * lerp(1.0, 1.75, u), by + H * lerp(0.9, 0.3, u)
      local fx = sd * W * lerp(1.15, 2.25, u)
      local c = tone(lerp(0.3, 0.2, u))
      ink.smooth(ink.ribbon({ { x0, by + H * 0.2 }, { kx, ky } }, function(t) return s * lerp(0.08, 0.065, t) end), true) ink.fill(c)
      ink.smooth(ink.ribbon({ { kx, ky }, { lerp(kx, fx, 0.7), ky * 0.45 }, { fx, 0 } }, function(t) return s * lerp(0.065, 0.02, t) end), true) ink.fill(c)
    end
    -- the claw: an arm up and out from the shell's front, a broad palm, two fingers opening
    local ax, ay = sd * W * 0.55, by + H * 0.5
    local px, py = sd * W * 1.1, by + H * 2.3
    ink.smooth(ink.ribbon({ { ax, ay }, { sd * W * 0.95, by + H * 1.2 }, { px, py - H * 0.4 } }, function(t) return s * lerp(0.1, 0.12, t) end), true) ink.fill(tone(0.28))
    fill(ellipse(px, py, s * 0.17, s * 0.12, 14, sd * 0.5), tone(0.3))
    fill({ { px + sd * s * 0.02, py + s * 0.08 }, { px + sd * s * 0.06, py + s * 0.32 }, { px + sd * s * 0.12, py + s * 0.3 }, { px + sd * s * 0.12, py + s * 0.08 } }, tone(0.3))
    fill({ { px - sd * s * 0.08, py + s * 0.06 }, { px - sd * s * 0.1, py + s * 0.26 }, { px - sd * s * 0.03, py + s * 0.26 }, { px, py + s * 0.08 } }, tone(0.25))
    if fine() then ink.moveto(px - sd * s * 0.08, py - s * 0.03) ink.lineto(px + sd * s * 0.05, py + s * 0.03) ink.stroke(white, 0.4, 0.6) end
  end
  -- the shell: wide, its front edge toothed
  local shell = {}
  for k = 0, 18 do
    local a = pi * k / 18
    local r = 1 + (k % 2 == 0 and 0.04 or 0) * (abs(cos(a)) > 0.3 and 1 or 0)
    shell[#shell + 1] = { W * r * cos(a), by + H * r * sin(a) ^ 0.9 }
  end
  shell[#shell + 1] = { -W * 0.8, by - H * 0.3 } shell[#shell + 1] = { W * 0.8, by - H * 0.3 }
  ink.poly(shell, true) ink.fill(tone(0.3))
  if fine() then
    fill(ellipse(-W * 0.15, by + H * 0.6, W * 0.5, H * 0.3, 14), tone(0.48), 0.6)        -- light on its back
    ink.moveto(-W * 0.3, by - H * 0.05) ink.curveto(-W * 0.1, by - H * 0.2, W * 0.1, by - H * 0.2, W * 0.3, by - H * 0.05) ink.stroke(tone(0.15), 0.45)   -- the mouth's edge
  end
  for _, sd in ipairs({ -1, 1 }) do                   -- eyes on stalks
    ink.moveto(sd * W * 0.18, by + H * 0.85) ink.lineto(sd * W * 0.24, by + H * 1.45) ink.stroke(tone(0.2), max(0.45, s * 2.2))
    ink.circle(sd * W * 0.24, by + H * 1.5, s * 0.045) ink.fill(tone(0.04))
    if fine() then ink.circle(sd * W * 0.24 - s * 0.012, by + H * 1.52, s * 0.013) ink.fill(white) end
  end
end

-- a sea star: five tapering arms, a little curled, studded; r = arm length
function M.star(rng, r, t0)
  local a0 = rng.range(0, 2 * pi)
  local pts = {}
  for k = 0, 4 do
    local a = a0 + 2 * pi * k / 5
    local curl = rng.sym(0.18)
    local L = r * rng.range(0.88, 1.06)
    local arm = function(u, side)
      local w = (r * 0.24 * (1 - u) ^ 0.8 + r * 0.03) * side
      local aa = a + curl * u * u
      local d = r * 0.2 + L * u
      return { d * cos(aa) - w * sin(aa), d * sin(aa) + w * cos(aa) }
    end
    for j = 0, 6 do pts[#pts + 1] = arm(j / 6, 1) end
    for j = 5, 0, -1 do pts[#pts + 1] = arm(j / 6, -1) end
  end
  fill(pts, tone(t0))
  if fine() then
    for k = 0, 4 do                                    -- a ridge of studs down each arm
      local a = a0 + 2 * pi * k / 5
      for j = 1, 5 do local u = j / 6 ink.circle((r * 0.2 + r * u) * cos(a), (r * 0.2 + r * u) * sin(a), r * 0.04 * (1 - u * 0.5)) end
    end
    ink.fill(tone(t0 + 0.25))
    ink.circle(0, 0, r * 0.08) ink.fill(tone(t0 + 0.3))
  end
end

-- a sea urchin: a dark test bristling with long spines; r = radius of the spines
function M.urchin(rng, r)
  for layer = 1, 2 do
    local n = layer == 1 and 40 or 26
    for k = 1, n do
      local a = 2 * pi * (k + layer * 0.5) / n + rng.sym(0.06)
      if layer == 1 or sin(a) > -0.3 then
        local L = r * rng.range(0.8, 1.05) * (layer == 1 and 1 or 0.75)
        ink.moveto(r * 0.3 * cos(a), r * 0.3 * sin(a)) ink.lineto(L * cos(a), L * sin(a))
      end
    end
    ink.stroke(tone(layer == 1 and 0.1 or 0.18), max(0.35, r * (layer == 1 and 1.3 or 1.6)))
  end
  fill(ellipse(0, 0, r * 0.36, r * 0.3, 14), tone(0.08))
  if fine() then ink.circle(-r * 0.1, r * 0.1, r * 0.08) ink.fill(tone(0.4), 0.6) end
end

-- an anemone on a rock, side on: a column and a crown of tentacles; h = height
function M.anemone(rng, h)
  fill({ { -h * 0.22, 0 }, { -h * 0.18, h * 0.55 }, { -h * 0.3, h * 0.68 }, { h * 0.3, h * 0.68 }, { h * 0.18, h * 0.55 }, { h * 0.22, 0 } }, tone(0.3))
  local n = 15
  for k = 1, n do
    local u = (k - 0.5) / n
    local x0 = lerp(-h * 0.3, h * 0.3, u)
    local a = lerp(-70, 70, u) * rad + rng.sym(0.12)
    local L = h * rng.range(0.35, 0.55)
    ink.smooth(ink.ribbon({ { x0, h * 0.66 }, { x0 + L * 0.5 * sin(a), h * 0.66 + L * 0.55 * cos(a) }, { x0 + L * sin(a * 1.3), h * 0.66 + L * cos(a * 1.3) * 0.9 } },
      function(t) return h * lerp(0.07, 0.025, t) end), true)
    ink.fill(tone(rng.range(0.45, 0.6)))
  end
  if fine() then for k = 1, 4 do local y = h * k * 0.12 ink.moveto(-h * 0.2, y) ink.lineto(h * 0.2, y) end ink.stroke(tone(0.22), 0.3, 0.6) end
end

-- a whelk shell lying on the sand, its axis tilted: a pointed spire of whorls stacked toward the apex, the
-- big body whorl, the aperture with its pale lip and the siphon canal at the other end; s = length
function M.whelk(rng, s)
  local tilt = rng.range(0.35, 0.6)                      -- the axis, from the canal (lower right) to the apex
  local ax, ay = cos(pi - tilt), sin(pi - tilt)          -- toward the apex
  local nx, ny = -ay, ax                                 -- across the shell
  local P = function(u, v) return u * ax + v * nx, u * ay + v * ny end   -- u along the axis, v across
  -- the outline: canal tip, the body whorl's swell, the spire narrowing in steps to the apex
  local out = {}
  local prof = { { -0.5, 0.02 }, { -0.36, 0.1 }, { -0.2, 0.26 }, { 0.0, 0.3 }, { 0.14, 0.24 }, { 0.2, 0.17 }, { 0.28, 0.15 }, { 0.33, 0.1 }, { 0.4, 0.08 }, { 0.45, 0.05 }, { 0.5, 0.0 } }
  for _, q in ipairs(prof) do out[#out + 1] = { P(q[1] * s, q[2] * s) } end
  for i = #prof - 1, 1, -1 do local q = prof[i] out[#out + 1] = { P(q[1] * s, -q[2] * s * 0.95) } end
  fill(out, tone(0.5))
  if fine() then
    -- the lit upper flank
    local lit = {}
    for i = 2, #prof - 1 do lit[#lit + 1] = { P(prof[i][1] * s, prof[i][2] * s * 0.95) } end
    for i = #prof - 1, 2, -1 do lit[#lit + 1] = { P(prof[i][1] * s, prof[i][2] * s * 0.35) } end
    fill(lit, tone(0.66), 0.8)
    -- sutures between the whorls: arcs across the spire
    for _, u in ipairs({ 0.16, 0.27, 0.355, 0.43 }) do
      local w = 0.0
      for _, q in ipairs(prof) do if q[1] <= u then w = q[2] end end
      ink.smooth({ { P((u - 0.02) * s, -w * s * 0.9) }, { P((u + 0.015) * s, 0) }, { P((u - 0.02) * s, w * s * 0.9) } }, false)
      ink.stroke(tone(0.3), 0.4, 0.8)
    end
    -- spiral ridges on the body whorl
    for k = 1, 4 do
      local v = lerp(-0.2, 0.22, k / 5)
      ink.smooth({ { P(-0.34 * s, v * s * 0.4) }, { P(-0.12 * s, v * s) }, { P(0.1 * s, v * s * 0.85) } }, false)
    end
    ink.stroke(tone(0.38), 0.3, 0.6)
    -- the aperture and its lip, on the body whorl's lower side
    fill({ { P(-0.32 * s, -0.04 * s) }, { P(-0.12 * s, -0.2 * s) }, { P(0.05 * s, -0.17 * s) }, { P(0.02 * s, -0.06 * s) }, { P(-0.2 * s, 0.0) } }, tone(0.15))
    ink.smooth({ { P(-0.36 * s, -0.03 * s) }, { P(-0.12 * s, -0.23 * s) }, { P(0.08 * s, -0.19 * s) } }, false) ink.stroke(tone(0.85), 0.7, 0.9)
  end
end

-- a skate's egg case (a mermaid's purse): a pillow with four curling horns; s = length
function M.eggcase(rng, s)
  fill({ { -s * 0.3, -s * 0.18 }, { -s * 0.34, s * 0.0 }, { -s * 0.3, s * 0.18 }, { s * 0.3, s * 0.18 }, { s * 0.34, 0 }, { s * 0.3, -s * 0.18 } }, tone(0.16))
  for _, cx in ipairs({ -1, 1 }) do
    for _, cy in ipairs({ -1, 1 }) do
      local x0, y0 = cx * s * 0.3, cy * s * 0.16
      ink.moveto(x0, y0) ink.curveto(x0 + cx * s * 0.25, y0 + cy * s * 0.05, x0 + cx * s * 0.3, y0 + cy * s * 0.25, x0 + cx * s * 0.15, y0 + cy * s * 0.3)
      ink.stroke(tone(0.16), max(0.4, s * 1.5))
    end
  end
  if fine() then ink.smooth({ { -s * 0.25, 0.02 * s }, { 0, s * 0.05 }, { s * 0.25, 0.02 * s } }, false) ink.stroke(tone(0.4), 0.3, 0.6) end
end

-- a moon jelly drifting: a clear bell, four rings seen through it, a fringe and frilled arms; s = bell width
function M.jelly(rng, s, cur)
  local W, H = s * 0.5, s * 0.32
  for k = 1, 16 do                                     -- the fringe of fine tentacles, trailing
    local x0 = lerp(-W, W, (k - 0.5) / 16)
    local L = s * rng.range(0.3, 0.6)
    ink.smooth({ { x0, 0 }, { x0 - cur * s * 0.05, -L * 0.5 }, { x0 - cur * s * 0.12, -L } }, false)
  end
  ink.stroke(tone(0.55), 0.25, 0.8)
  for k = 1, 4 do                                      -- frilled oral arms
    local x0 = lerp(-W * 0.3, W * 0.3, (k - 0.5) / 4)
    local pts = {}
    for j = 0, 8 do local t = j / 8 pts[#pts + 1] = { x0 - cur * s * 0.15 * t + s * 0.03 * sin(t * 10 + k), -s * 0.75 * t } end
    ink.smooth(ink.ribbon(pts, function(t) return s * lerp(0.07, 0.025, t) end), true) ink.fill(tone(0.5), 0.7)
  end
  local bell = {}
  for k = 0, 18 do local a = pi * k / 18 bell[#bell + 1] = { W * cos(a), H * sin(a) ^ 0.75 } end
  for k = 1, 11 do local t = k / 12 bell[#bell + 1] = { lerp(-W, W, t), -s * 0.03 * abs(sin(t * pi * 7)) } end
  fill(bell, tone(0.68), 0.75)
  if fine() then
    for k = 1, 4 do                                    -- the four horseshoe rings
      local a = pi * (k - 0.5) / 4
      ink.smooth(ellipse(W * 0.48 * cos(a), H * 0.38, W * 0.13, H * 0.17, 12), true) ink.stroke(tone(0.4), 0.4, 0.8)
    end
    ink.smooth({ { -W * 0.65, H * 0.45 }, { -W * 0.25, H * 0.8 }, { W * 0.15, H * 0.85 } }, false) ink.stroke(white, 0.6, 0.7)
  end
end

-- a by-the-wind sailor (Velella) at the surface: a blue oval float with its rings, a clear sail standing
-- diagonally across it, a fringe of short tentacles hanging below; s = float length; the waterline at y = 0
function M.sailor(rng, s)
  for k = 1, 9 do                                      -- the tentacles, below the water
    local x = lerp(-s * 0.4, s * 0.4, (k - 0.5) / 9)
    ink.moveto(x, -s * 0.05) ink.lineto(x + rng.sym(s * 0.04), -s * rng.range(0.15, 0.3))
  end
  ink.stroke(tone(0.4), max(0.3, s * 1.5), 0.8)
  fill(ellipse(0, 0, s * 0.5, s * 0.14, 18), tone(0.3))           -- the float, seen a little from the side
  if fine() then
    for k = 1, 3 do ink.smooth(ellipse(0, s * 0.01, s * 0.5 * (1 - 0.25 * k), s * 0.14 * (1 - 0.25 * k), 16), true) ink.stroke(tone(0.55), 0.35, 0.8) end
  end
  -- the sail: a thin triangle rising off the float, set diagonally
  fill({ { -s * 0.35, s * 0.06 }, { s * 0.1, s * 0.62 }, { s * 0.35, s * 0.06 } }, tone(0.72), 0.75)
  if fine() then
    ink.moveto(-s * 0.35, s * 0.06) ink.lineto(s * 0.1, s * 0.62) ink.lineto(s * 0.35, s * 0.06) ink.stroke(tone(0.4), 0.4, 0.9)
    for k = 1, 3 do local t = k / 4 ink.moveto(lerp(-s * 0.35, s * 0.35, t), s * 0.06) ink.lineto(s * 0.1, s * 0.62) end
    ink.stroke(tone(0.55), 0.25, 0.7)
  end
end

-- a shrimp side on, facing +x: a smooth body curving down from the head to the tail fan, segment lines,
-- a rostrum, legs and swimmerets below, two long antennae; s = length
function M.shrimp(rng, s)
  -- the spine: from the rostrum's base, back along the carapace, then curling down into the tail
  local spine = function(v)
    local a = lerp(0.1, -2.1, v ^ 1.3)
    return s * 0.1 + s * 0.42 * (cos(a) - 1) + s * 0.02, s * 0.32 * sin(a) + s * 0.12
  end
  local hw = function(v) return s * (0.11 * (1 - v) ^ 0.6 + 0.025) end
  local body, c = ink.blade(spine, 24, hw, hw)
  fill(body, tone(0.5))
  -- the tail fan at the end
  local ex, ey = c[#c][1], c[#c][2]
  local px, py = c[#c - 1][1], c[#c - 1][2]
  local dx, dy = ex - px, ey - py
  local l = math.sqrt(dx * dx + dy * dy)
  dx, dy = dx / l, dy / l
  for _, sd in ipairs({ -1, 0, 1 }) do
    local ax, ay = dx * 0.25 * s + sd * -dy * 0.1 * s, dy * 0.25 * s + sd * dx * 0.1 * s
    fill({ { ex, ey }, { ex + ax - dy * s * 0.04, ey + ay + dx * s * 0.04 }, { ex + ax * 1.05, ey + ay * 1.05 }, { ex + ax + dy * s * 0.04, ey + ay - dx * s * 0.04 } }, tone(0.44))
  end
  -- the rostrum, toothed, and the head's eye
  fill({ { s * 0.08, s * 0.2 }, { s * 0.42, s * 0.2 }, { s * 0.1, s * 0.14 } }, tone(0.42))
  if fine() then
    for k = 1, 6 do                                    -- segment lines across the body
      local v = 0.3 + 0.1 * k
      local x, y = spine(v)
      local x2, y2 = spine(v + 0.01)
      local nx, ny = -(y2 - y), x2 - x
      local L = math.sqrt(nx * nx + ny * ny) nx, ny = nx / L, ny / L
      local w = hw(v)
      ink.moveto(x + nx * w, y + ny * w) ink.lineto(x - nx * w * 0.7, y - ny * w * 0.7)
    end
    ink.stroke(tone(0.32), 0.35, 0.8)
    fill(ellipse(-s * 0.05, s * 0.17, s * 0.12, s * 0.05, 12), tone(0.7), 0.6)    -- light on the carapace
    for k = 1, 5 do                                    -- walking legs under the carapace, swimmerets behind
      local x = lerp(s * 0.05, -s * 0.18, k / 5)
      ink.moveto(x, s * 0.04) ink.lineto(x + s * 0.03, -s * 0.06) ink.lineto(x + s * 0.07, -s * 0.1)
    end
    for k = 1, 4 do local x, y = spine(0.35 + 0.1 * k) ink.moveto(x, y - hw(0.35 + 0.1 * k) * 0.8) ink.lineto(x + s * 0.02, y - hw(0.35) * 1.4) end
    ink.stroke(tone(0.34), 0.35)
    ink.moveto(s * 0.12, s * 0.16) ink.curveto(s * 0.5, s * 0.45, s * 0.8, s * 0.35, s * 1.05, s * 0.05)
    ink.moveto(s * 0.13, s * 0.18) ink.curveto(s * 0.4, s * 0.55, s * 0.7, s * 0.6, s * 0.95, s * 0.5)
    ink.stroke(tone(0.35), 0.25)
    ink.circle(s * 0.08, s * 0.2, s * 0.032) ink.fill(tone(0.04))
  end
end

-- a sea palm: a rubbery stalk and a drooping crown; h = height
function M.seapalm(rng, h, cur)
  local tx, ty = h * 0.08 * cur, h * 0.7
  ink.smooth(ink.ribbon({ { 0, 0 }, { h * 0.03 * cur, h * 0.35 }, { tx, ty } }, function(t) return h * lerp(0.07, 0.045, t) end), true) ink.fill(tone(0.22))
  for k = 1, 11 do
    local u = (k - 0.5) / 11
    local a = lerp(-80, 80, u) - cur * 10
    M.blade(rng, tx, ty, a, h * rng.range(0.32, 0.45), h * 0.035, (a > 0 and 1 or -1) * 1.4, rng.range(0.32, 0.45))
  end
end

-- a red seaweed: flat fronds forking again and again; h = height
function M.redweed(rng, h, t0)
  local function frond(x, y, a, len, w, depth)
    local ex, ey = x + len * sin(a), y + len * cos(a)
    ink.smooth(ink.ribbon({ { x, y }, { lerp(x, ex, 0.5) + rng.sym(0.02), lerp(y, ey, 0.5) }, { ex, ey } }, function(t) return w * lerp(1, 0.8, t) end), true)
    ink.fill(tone(t0))
    if depth == 0 or len < 0.1 then ink.circle(ex, ey, w * 0.55) ink.fill(tone(t0 + 0.05)) return end
    local sp = rng.range(0.3, 0.55)
    frond(ex, ey, a - sp, len * rng.range(0.65, 0.82), w * 0.82, depth - 1)
    frond(ex, ey, a + sp, len * rng.range(0.65, 0.82), w * 0.82, depth - 1)
  end
  frond(0, 0, rng.sym(0.15), h * 0.3, h * 0.05, rng.int(3, 4))
end

-- eelgrass: a tuft of long ribbons swaying with the current; h = height
function M.eelgrass(rng, h, cur)
  for _ = 1, rng.int(5, 9) do
    local x0 = rng.sym(h * 0.08)
    local L = h * rng.range(0.6, 1)
    local pts = {}
    for k = 0, 10 do local t = k / 10 pts[#pts + 1] = { x0 + cur * L * 0.35 * t * t + h * 0.04 * sin(t * 5 + x0 * 9), L * t } end
    ink.smooth(ink.ribbon(pts, function(t) return h * lerp(0.035, 0.02, t) end), true) ink.fill(tone(rng.range(0.3, 0.42)))
  end
end

-- a lens-shaped leaflet from (x, y) along angle a (radians from up), l long, w half wide
local function leaflet(x, y, a, l, w, c)
  local ca, sa = cos(a), sin(a)
  local pts = {}
  for k = 0, 9 do
    local th = 2 * pi * k / 10
    local u = (1 - cos(th)) / 2
    local s = sin(th) * w * (1 - u * 0.3)
    pts[#pts + 1] = { x + u * l * sa + s * ca, y + u * l * ca - s * sa }
  end
  fill(pts, c)
end

-- oarweed (Laminaria): a stout stipe and one blade split into straps that fan out and trail
function M.oarweed(rng, h, cur)
  local sx, sy = h * 0.05 * cur, h * 0.36
  ink.smooth(ink.ribbon({ { 0, 0 }, { sx * 0.4, sy * 0.5 }, { sx, sy } }, function(t) return h * lerp(0.045, 0.03, t) end), true) ink.fill(tone(0.2))
  fill(ellipse(sx, sy + h * 0.05, h * 0.08, h * 0.07, 14), tone(0.28))
  local n = rng.int(5, 8)
  for k = 1, n do
    local u = (k - 0.5) / n
    local a = (lerp(-30, 30, u) + cur * 14) * rad
    local L = h * rng.range(0.42, 0.62)
    local tr = cur * rng.range(0.15, 0.4)
    local ph = rng.range(0, 6)
    local x0, y0 = sx + lerp(-h * 0.06, h * 0.06, u), sy + h * 0.05
    local spine = function(v)
      local sv, lx = v * L, tr * v * v * L + 0.03 * L * sin(v * 5 + ph) * v
      return x0 + lx * cos(a) + sv * sin(a), y0 - lx * sin(a) + sv * cos(a)
    end
    local hw = function(v) return h * 0.022 * (1 - 0.5 * v) * min(1, (1 - v) * 7 + 0.05) end
    ink.smooth(ink.blade(spine, 14, hw, hw), true) ink.fill(tone(0.24 + 0.12 * rng.range(0, 1)))
  end
end

-- feather boa (Egregia): a long flat strap fringed both sides with little blades and floats
function M.boa(rng, h, cur)
  local ph = rng.range(0, 6)
  local spine = function(t) return cur * h * 0.32 * t * t + h * 0.05 * sin(t * 4 + ph), h * t end
  local pts = {}
  for k = 0, 16 do pts[#pts + 1] = { spine(k / 16) } end
  ink.smooth(ink.ribbon(pts, function(t) return h * lerp(0.018, 0.01, t) end), true) ink.fill(tone(0.18))
  local n = floor(h * 22)
  for k = 2, n do
    local t = k / (n + 1)
    local x, y = spine(t)
    for side = -1, 1, 2 do
      if rng.chance(0.85) then
        if rng.chance(0.12) then
          ink.circle(x + side * h * 0.018, y, h * 0.011) ink.fill(tone(0.16))
        else
          leaflet(x, y, (side * rng.range(40, 75) + cur * 25) * rad, h * rng.range(0.045, 0.08) * (1 - 0.4 * t), h * 0.011, tone(0.26 + rng.range(0, 0.1)))
        end
      end
    end
  end
end

-- sargassum: a bushy, branching weed of small toothed leaflets and berry-like floats
function M.sargassum(rng, h, cur)
  local function branch(x, y, a, len, depth)
    local n = 8
    local pts, cx, cy, ca = { { x, y } }, x, y, a
    for _ = 1, n do
      ca = ca + (cur * 4 + rng.sym(7)) * rad
      cx, cy = cx + len / n * sin(ca), cy + len / n * cos(ca)
      pts[#pts + 1] = { cx, cy }
    end
    ink.smooth(ink.ribbon(pts, function(t) return h * lerp(0.011, 0.006, t) * (depth == 0 and 1.4 or 1) end), true) ink.fill(tone(0.2))
    for k = 2, n + 1 do
      local p, q = pts[k], pts[k - 1]
      local side = (k % 2 == 0) and 1 or -1
      local la = math.atan(p[1] - q[1], p[2] - q[2]) + side * rng.range(35, 70) * rad
      if depth < 2 and k % 3 == 0 and len > h * 0.15 then
        branch(p[1], p[2], a + (side * rng.range(30, 55) + cur * 10) * rad, len * rng.range(0.4, 0.6), depth + 1)
      elseif rng.chance(0.3) then
        local ex, ey = p[1] + h * 0.025 * sin(la), p[2] + h * 0.025 * cos(la)
        ink.circle(ex, ey, h * 0.013) ink.fill(tone(0.15))
        if fine() then ink.circle(ex - h * 0.004, ey + h * 0.004, h * 0.004) ink.fill(white, 0.5) end
      else
        leaflet(p[1], p[2], la, h * rng.range(0.05, 0.08), h * 0.012, tone(0.3 + rng.range(0, 0.12)))
      end
    end
    leaflet(cx, cy, ca, h * 0.06, h * 0.012, tone(0.34))
  end
  branch(0, 0, rng.sym(8) * rad, h * 0.9, 0)
end

-- bladder wrack (Fucus): flat fronds with a midrib, forking, paired air bladders, swollen speckled tips
function M.wrack(rng, h)
  local function frond(x, y, a, len, w, depth)
    local ex, ey = x + len * sin(a), y + len * cos(a)
    local mx, my = lerp(x, ex, 0.5) + rng.sym(0.02), lerp(y, ey, 0.5)
    ink.smooth(ink.ribbon({ { x, y }, { mx, my }, { ex, ey } }, function() return w end), true) ink.fill(tone(0.24))
    if fine() then ink.smooth({ { x, y }, { mx, my }, { ex, ey } }, false) ink.stroke(tone(0.13), 0.4) end
    if rng.chance(0.55) and len > w * 3 then
      local px, py = lerp(x, ex, 0.45), lerp(y, ey, 0.45)
      for sd = -1, 1, 2 do
        local bx, by = px + sd * w * 0.9 * cos(a), py - sd * w * 0.9 * sin(a)
        fill(ellipse(bx, by, w * 0.75, w * 1.1, 10), tone(0.19))
        if fine() then ink.circle(bx - w * 0.2, by + w * 0.3, w * 0.25) ink.fill(white, 0.4) end
      end
    end
    if depth == 0 or len < 0.08 then
      local tx, ty = ex + w * 0.7 * sin(a), ey + w * 0.7 * cos(a)
      leaflet(ex, ey, a, w * 3, w * 1.1, tone(0.3))
      if fine() then for _ = 1, 4 do ink.circle(tx + rng.sym(w * 0.5), ty + rng.sym(w * 0.9), w * 0.13) ink.fill(tone(0.17)) end end
      return
    end
    local sp = rng.range(0.25, 0.45)
    frond(ex, ey, a - sp, len * rng.range(0.7, 0.85), w * 0.85, depth - 1)
    frond(ex, ey, a + sp, len * rng.range(0.7, 0.85), w * 0.85, depth - 1)
  end
  frond(0, 0, rng.sym(0.1), h * 0.25, h * 0.03, rng.int(3, 4))
end

-- Neptune's necklace (Hormosira): chains of hollow beads that arch over and fork
function M.beads(rng, h)
  local function chain(x, y, a, n, r, depth)
    local bend = (a >= 0 and 1 or -1) * rng.range(3, 7) * rad
    for k = 1, n do
      local rr = r * rng.range(0.85, 1.15)
      x, y = x + rr * 1.65 * sin(a), y + rr * 1.65 * cos(a)
      fill(ellipse(x, y, rr * 0.82, rr, 10), tone(0.24 + rng.range(0, 0.12)))
      if fine() then ink.circle(x - rr * 0.3, y + rr * 0.3, rr * 0.25) ink.fill(white, 0.45) end
      a = a + bend + rng.sym(8) * rad
      if depth < 2 and k >= 2 and rng.chance(0.18) then chain(x, y, a + rng.pick({ -1, 1 }) * rng.range(30, 50) * rad, floor(n * 0.6), r * 0.85, depth + 1) end
    end
  end
  for _ = 1, rng.int(1, 3) do chain(rng.sym(h * 0.05), 0, rng.sym(35) * rad, rng.int(8, 13), h * 0.027, 0) end
end

-- Padina, the peacock's tail: thin fans on short stalks, banded in rings
function M.padina(rng, h)
  for _ = 1, rng.int(2, 4) do
    local a = rng.sym(40) * rad
    local R = h * rng.range(0.32, 0.5)
    local bx = rng.sym(h * 0.08)
    local spread = rng.range(50, 80) * rad
    local ph = rng.range(0, 6)
    local fx, fy = bx + h * 0.12 * sin(a), h * 0.12 * cos(a)
    ink.smooth(ink.ribbon({ { bx, 0 }, { lerp(bx, fx, 0.5), fy * 0.5 }, { fx, fy } }, function() return h * 0.014 end), true) ink.fill(tone(0.22))
    local edge = function(th, rr) return fx + rr * sin(a + th), fy + rr * cos(a + th) end
    local pts = { { fx, fy } }
    for k = 0, 24 do pts[#pts + 1] = { edge(lerp(-spread, spread, k / 24), R * (1 + 0.08 * sin(k * 1.7 + ph))) } end
    fill(pts, tone(rng.range(0.36, 0.46)))
    if fine() then
      for b = 1, 4 do
        local arc = {}
        for k = 0, 16 do arc[#arc + 1] = { edge(lerp(-spread, spread, k / 16) * 0.96, R * b / 5 * (1 + 0.05 * sin(k * 1.7 + ph))) } end
        ink.smooth(arc, false) ink.stroke(tone(0.26), 0.45, 0.7)
      end
    end
  end
end

-- Halimeda: chains of flat, kidney-shaped discs, now and then forking
function M.halimeda(rng, h)
  local function seg(x, y, a, r, depth)
    if r < h * 0.02 or depth > 9 then return end
    local cx, cy = x + r * 0.8 * sin(a), y + r * 0.8 * cos(a)
    fill(ellipse(cx, cy, r, r * 0.78, 12), tone(0.3 + 0.025 * depth))
    local tx, ty = x + r * 1.35 * sin(a), y + r * 1.35 * cos(a)
    if rng.chance(depth < 3 and 0.3 or 0.06) then
      seg(tx, ty, a - rng.range(20, 40) * rad, r * rng.range(0.82, 0.94), depth + 1)
      seg(tx, ty, a + rng.range(20, 40) * rad, r * rng.range(0.82, 0.94), depth + 1)
    else seg(tx, ty, a + rng.sym(15) * rad, r * rng.range(0.85, 0.96), depth + 1) end
  end
  for i = 1, rng.int(2, 3) do seg(rng.sym(h * 0.03), 0, (lerp(-35, 35, rng.range(0, 1)) + rng.sym(8)) * rad, h * rng.range(0.045, 0.06), 0) end
end

-- sea grapes (Caulerpa racemosa): a runner on the sand, upright stalks crowded with little spheres
function M.grapes(rng, h)
  local w = h * 0.7
  local st = {}
  for k = 0, 8 do st[#st + 1] = { lerp(-w / 2, w / 2, k / 8), h * 0.02 * sin(k * 1.3) } end
  ink.smooth(ink.ribbon(st, function() return h * 0.012 end), true) ink.fill(tone(0.28))
  for k = 1, rng.int(3, 5) do
    local x = lerp(-w / 2, w / 2, (k - 0.5) / 5) + rng.sym(h * 0.04)
    local ht = h * rng.range(0.3, 0.6)
    local tx = x + rng.sym(h * 0.04)
    ink.smooth(ink.ribbon({ { x, 0 }, { lerp(x, tx, 0.5), ht * 0.5 }, { tx, ht } }, function() return h * 0.01 end), true) ink.fill(tone(0.28))
    local y, side = ht * 0.25, 1
    while y <= ht do
      local gx = lerp(x, tx, y / ht) + side * h * 0.02
      ink.circle(gx, y, h * 0.022) ink.fill(tone(0.34 + rng.range(0, 0.08)))
      if fine() then ink.circle(gx - h * 0.007, y + h * 0.007, h * 0.007) ink.fill(white, 0.5) end
      y, side = y + h * 0.03, -side
    end
    ink.circle(tx, ht + h * 0.01, h * 0.024) ink.fill(tone(0.36))
  end
end

-- sugar kelp (Saccharina): one long blade on a short stipe, its edges frilled, its middle a smooth band
function M.sugarkelp(rng, h, cur)
  local ph = rng.range(0, 6)
  local sy = h * 0.12
  ink.smooth(ink.ribbon({ { 0, 0 }, { 0, sy } }, function(t) return h * 0.02 end), true) ink.fill(tone(0.2))
  local tr = cur * rng.range(0.25, 0.5)
  local spine = function(v) return tr * v * v * h + 0.04 * h * sin(v * 5 + ph) * v, sy + v * h * 0.88 end
  local hw = function(v) return h * 0.08 * sin(pi * min(1, v * 1.1) ^ 0.4) * (1 - 0.3 * v) + h * 0.004 end
  local frill = fine() and function(v, side) return h * 0.008 * sin(v * 40 + side * 2 + ph) * min(1, v * 4) end or nil
  ink.smooth(ink.blade(spine, max(16, floor(h * 14)), hw, hw, frill), true) ink.fill(tone(rng.range(0.38, 0.48)))
  if fine() then
    local band = function(v) return hw(v) * 0.35 end
    ink.smooth(ink.blade(spine, max(12, floor(h * 10)), band, band), true) ink.fill(tone(0.22), 0.6)
  end
end

-- thongweed (Himanthalia): a little button on the rock and long thin straps that fork two or three times
function M.thongweed(rng, h, cur)
  local function thong(x, y, a, len, w, depth)
    local pts, cx, cy, ca = { { x, y } }, x, y, a
    for _ = 1, 8 do
      ca = ca + (cur * 3 + rng.sym(5)) * rad
      cx, cy = cx + len / 8 * sin(ca), cy + len / 8 * cos(ca)
      pts[#pts + 1] = { cx, cy }
    end
    ink.smooth(ink.ribbon(pts, function(t) return w * lerp(1, 0.75, t) end), true) ink.fill(tone(0.22 + 0.04 * depth))
    if depth < 2 then
      thong(cx, cy, ca - rng.range(6, 14) * rad, len * rng.range(0.6, 0.9), w * 0.85, depth + 1)
      thong(cx, cy, ca + rng.range(6, 14) * rad, len * rng.range(0.6, 0.9), w * 0.85, depth + 1)
    end
  end
  fill(ellipse(0, h * 0.04, h * 0.09, h * 0.05, 12), tone(0.24))
  for _ = 1, rng.int(1, 2) do thong(rng.sym(h * 0.03), h * 0.05, rng.sym(8) * rad, h * rng.range(0.4, 0.5), h * 0.017, 0) end
end

-- dulse: a dark, flat, fan of a frond, splitting into broad lobes with small leaflets at the edges
function M.dulse(rng, h)
  local function lobe(x, y, a, len, w, depth)
    local ex, ey = x + len * sin(a), y + len * cos(a)
    local hw = function(t) return w * (1 + 0.6 * t) * min(1, (1 - t) * 4 + 0.25) end
    ink.smooth(ink.ribbon({ { x, y }, { lerp(x, ex, 0.5) + rng.sym(len * 0.08), lerp(y, ey, 0.5) }, { ex, ey } }, hw), true) ink.fill(tone(0.12 + 0.03 * depth))
    if fine() and depth > 0 then for _ = 1, rng.int(0, 2) do
      local t = rng.range(0.3, 0.8)
      local sd = rng.pick({ -1, 1 })
      leaflet(lerp(x, ex, t), lerp(y, ey, t), a + sd * rng.range(50, 80) * rad, len * 0.35, w * 0.3, tone(0.16))
    end end
    if depth >= 3 or len < 0.12 then return end
    for i = 1, rng.int(2, 3) do lobe(ex, ey, a + rng.range(-40, 40) * rad, len * rng.range(0.6, 0.8), w * 0.85, depth + 1) end
  end
  lobe(0, 0, rng.sym(0.1), h * 0.38, h * 0.06, 0)
end

-- sea lettuce (Ulva): a thin, crumpled sheet, paler, its edge rippled
function M.lettuce(rng, h)
  for k = 1, rng.int(2, 3) do
    local pts = {}
    local cx, cy, R = rng.sym(h * 0.15), h * rng.range(0.25, 0.4), h * rng.range(0.22, 0.32)
    local ph = rng.range(0, 6)
    for j = 0, 27 do
      local a = 2 * pi * j / 28
      local r = R * (1 + 0.18 * sin(a * 3 + ph) + 0.08 * sin(a * 9 + ph * 2))
      pts[#pts + 1] = { cx + r * cos(a) * 0.8, max(0, cy + r * sin(a) * 1.1) }
    end
    fill(pts, tone(rng.range(0.46, 0.56)))
    if fine() then for _ = 1, 3 do
      local a = rng.range(0, 2 * pi)
      ink.smooth({ { cx + R * 0.2 * cos(a), cy + R * 0.2 * sin(a) }, { cx + R * 0.55 * cos(a + 0.3), cy + R * 0.6 * sin(a + 0.3) }, { cx + R * 0.8 * cos(a), cy + R * 0.9 * sin(a) } }, false)
      ink.stroke(tone(0.38), 0.4, 0.6)
    end end
  end
end

-- a chain of bubbles rising from (x, y); r = the first bubble's size
local function bubbles(rng, x, y, r, n)
  for k = 1, n do
    local rr = r * (1 - 0.06 * k) * rng.range(0.6, 1.1)
    local by = y + (k - 1) * r * 2.6 * rng.range(0.8, 1.2)
    local bx = x + rng.sym(r * 0.6) + 0.15 * sin(k * 1.3)
    ink.circle(bx, by, rr) ink.stroke(tone(0.45), max(0.3, rr * 6), 0.8)
    ink.circle(bx - rr * 0.35, by + rr * 0.35, rr * 0.25) ink.fill(white, 0.9)
  end
end

-- the open water's animals, redrawn as rigs (by marginalia-partner): each fish kind a build of its own on a
-- swimming spine with fins as ray fans; moon jellies and sea nettles; the by-the-wind sailor; a jointed shrimp.
-- They replace the first sketches above, with the same signatures.
local SW = (function()
  local ink = require("florilegium-ink")
  local M = {}
  -- scratch/kelp/sealife-water.lua -- the kelp forest's open-water animals, a prototype (procedural, nothing traced):
  -- M.fish(rng, kind, L), M.jelly(rng, s, cur), M.sailor(rng, s), M.shrimp(rng, s), with the theme's frames.
  -- Each is a rig (a spine with a radius profile above and below it, fins as rays off its edges) painted as the
  -- otter is: a union silhouette with its outline stroked twice as wide under the fill, tonal layers in its clip
  -- (the back darker, the belly paler, a lit streak), detail by the size on the page (D, cm).

  local sin, cos, pi, abs, max, min, sqrt, floor = math.sin, math.cos, math.pi, math.abs, math.max, math.min, math.sqrt, math.floor
  local tone, white = ink.tone, ink.white
  local CM = 72 / 2.54
  local function lerp(a, b, t) return a + (b - a) * t end
  local function clamp(v, a, b) return max(a, min(b, v)) end
  local function lifted() return ink.get_lift() < 0.3 end
  local function area(p) local s = 0 for i = 1, #p do local a, b = p[i], p[i % #p + 1] s = s + a[1] * b[2] - b[1] * a[2] end return s end
  local function ccw(p) if area(p) >= 0 then return p end local r = {} for i = #p, 1, -1 do r[#r + 1] = p[i] end return r end
  local function ellipse(cx, cy, rx, ry, n, a0)
    local out, ca, sa = {}, cos(a0 or 0), sin(a0 or 0)
    for k = 0, (n or 16) - 1 do local a = 2 * pi * k / (n or 16) local x, y = rx * cos(a), ry * sin(a) out[#out + 1] = { cx + x * ca - y * sa, cy + x * sa + y * ca } end
    return out
  end
  local function profile(t)
    return function(v)
      for i = 2, #t do
        if v <= t[i][1] then local f = (v - t[i - 1][1]) / (t[i][1] - t[i - 1][1]) f = f * f * (3 - 2 * f) return lerp(t[i - 1][2], t[i][2], f) end
      end
      return t[#t][2]
    end
  end
  function M._curve(pts)
    local c = ink.catmull(pts, 10)
    local s = { 0 }
    for i = 2, #c do s[i] = s[i - 1] + sqrt((c[i][1] - c[i - 1][1]) ^ 2 + (c[i][2] - c[i - 1][2]) ^ 2) end
    local T = s[#c]
    return function(v)
      local t = clamp(v, 0, 1) * T
      local lo, hi = 1, #c
      while hi - lo > 1 do local m = (lo + hi) // 2 if s[m] <= t then lo = m else hi = m end end
      local f = (t - s[lo]) / max(1e-9, s[hi] - s[lo])
      return lerp(c[lo][1], c[hi][1], f), lerp(c[lo][2], c[hi][2], f)
    end
  end
  local function fillp(pts, c, op) ink.smooth(pts, true) ink.fill(c, op) end

  -- ---------------------------------------------------------------- fish
  -- in units of L: the nose at x = 0.5, the tail stalk ending at `ped`, the tail fin past it; u runs 0 at
  -- the nose to 1 at the stalk. Fins: { u0, u1, height, spiny?, notch? }
  local FISH = {
    senorita = { t0 = 0.52, ped = -0.32,       -- a slim cigar, a long low dorsal, a black crescent at the tail's base
      top = { { 0, 0 }, { 0.04, 0.028 }, { 0.16, 0.058 }, { 0.45, 0.068 }, { 0.75, 0.054 }, { 1, 0.03 } },
      bot = { { 0, 0.004 }, { 0.05, 0.026 }, { 0.2, 0.05 }, { 0.5, 0.058 }, { 0.8, 0.045 }, { 1, 0.028 } },
      dorsal = { { 0.26, 0.88, 0.035, false } }, anal = { 0.56, 0.88, 0.03 }, tail = "truncate", th = 0.095, cl = 0.17,
      eye = { 0.1, 0.022 }, mouth = 0.05, pect = 0.07 },
    garibaldi = { t0 = 0.5, ped = -0.24,       -- deep and oval, a blunt head, small mouth, big round soft fins, a notched tail
      top = { { 0, 0.0 }, { 0.03, 0.07 }, { 0.14, 0.17 }, { 0.38, 0.225 }, { 0.65, 0.19 }, { 0.88, 0.1 }, { 1, 0.06 } },
      bot = { { 0, 0.02 }, { 0.05, 0.08 }, { 0.22, 0.16 }, { 0.48, 0.19 }, { 0.75, 0.14 }, { 1, 0.06 } },
      dorsal = { { 0.22, 0.56, 0.045, true }, { 0.56, 0.92, 0.13, false } }, anal = { 0.6, 0.92, 0.12 }, tail = "forked", th = 0.17, cl = 0.18,
      eye = { 0.12, 0.034 }, mouth = 0.05, pect = 0.11 },
    rockfish = { t0 = 0.3, ped = -0.3,         -- a big head and eye, a deeply notched spiny dorsal, mottled, a square tail
      top = { { 0, 0.0 }, { 0.05, 0.075 }, { 0.2, 0.15 }, { 0.42, 0.165 }, { 0.72, 0.115 }, { 1, 0.05 } },
      bot = { { 0, 0.012 }, { 0.06, 0.07 }, { 0.3, 0.13 }, { 0.55, 0.12 }, { 1, 0.05 } },
      dorsal = { { 0.24, 0.6, 0.12, true, true }, { 0.61, 0.86, 0.085, false } }, anal = { 0.6, 0.82, 0.09, 3 }, tail = "truncate", th = 0.15, cl = 0.18,
      eye = { 0.13, 0.043 }, mouth = 0.14, pect = 0.13, mottle = true },
    bass = { t0 = 0.36, ped = -0.31,           -- longer, a pointed head, the lower jaw jutting, spines 3-5 tallest, pale blotches
      top = { { 0, 0 }, { 0.06, 0.05 }, { 0.25, 0.12 }, { 0.45, 0.13 }, { 0.75, 0.09 }, { 1, 0.045 } },
      bot = { { 0, 0.014 }, { 0.08, 0.05 }, { 0.35, 0.105 }, { 0.6, 0.098 }, { 1, 0.045 } },
      dorsal = { { 0.26, 0.6, 0.11, true }, { 0.6, 0.86, 0.075, false } }, anal = { 0.6, 0.82, 0.075, 3 }, tail = "square", th = 0.14, cl = 0.17,
      eye = { 0.12, 0.03 }, mouth = 0.16, pect = 0.11, blotch = true },
  }

  function M.fish(rng, kind, L)
    local F = FISH[kind] or FISH.senorita
    local top, bot = profile(F.top), profile(F.bot)
    local gt = rng.range(0.94, 1.08)                    -- a lean fish or a fat one
    local tp = function(u) return top(u) * gt end
    local bt = function(u) return bot(u) * gt end
    local bend = rng.sym(0.06)                          -- the swimming curve of the rear half
    local t0 = F.t0 + rng.sym(0.03)
    ink.push() ink.scale(L)
    local D = ink.unit()
    local fine, finer = lifted() and D > 1.6, lifted() and D > 3.5
    local bp = function(f) return f * D * CM end
    -- the spine: u 0 at the nose, 1 at the stalk's end
    local function S(u) local x = lerp(0.5, F.ped, u) local q = max(0, u - 0.3) return x, bend * q * q * 2 end
    local function T(u) local a, b = S(clamp(u - 0.01, 0, 1)) local c, d = S(clamp(u + 0.01, 0, 1)) local dx, dy = a - c, b - d local l = sqrt(dx * dx + dy * dy) return dx / l, dy / l end   -- toward the nose
    local function E(u, side, k)                        -- a point k of the way to the top (side 1) or bottom edge
      local x, y = S(u) local tx, ty = T(u)
      local w = side > 0 and tp(u) or bt(u)
      return x - ty * w * k * side, y + tx * w * k * side
    end
    local spine = function(v) return S(1 - v) end
    local body = ccw((ink.blade(spine, 36, function(v) return tp(1 - v) end, function(v) return bt(1 - v) end)))
    -- fins: rays off an edge, leaning back; spiny ones pointed with the membrane dipping between the spines
    local rays = {}
    local function fin(u0, u1, h, side, spiny, notch, nspines)
      local pts, n = {}, spiny and 10 or 8
      for k = 0, n do
        local t = k / n
        local u = lerp(u0, u1, t)
        local bx, by = E(u, side, 0.86)
        local tx, ty = T(u)
        local hh = h * rng.range(0.93, 1.07)
        if spiny then hh = hh * (notch and (0.75 + 0.5 * sin(pi * min(1, t * 1.6))) * (1 - 0.45 * t) or (0.6 + 0.4 * sin(pi * min(1, t * 2.2 + 0.1)))) else hh = hh * (0.35 + 0.65 * sin(pi * (0.15 + 0.85 * t)) ^ 0.7) end
        if nspines and k > nspines and side < 0 then hh = hh * 1.1 end
        local nx, ny = -ty * side, tx * side
        local px, py = bx + (nx * 0.92 - tx * 0.4) * hh, by + (ny * 0.92 - ty * 0.4) * hh
        pts[#pts + 1] = { px, py }
        rays[#rays + 1] = { bx, by, px, py }
        if spiny and k < n then
          local u2 = lerp(u0, u1, t + 0.5 / n) local mx, my = E(u2, side, 0.86)
          pts[#pts + 1] = { mx + (nx * 0.92 - tx * 0.4) * hh * 0.62, my + (ny * 0.92 - ty * 0.4) * hh * 0.62 }
        end
      end
      for k = 6, 0, -1 do pts[#pts + 1] = { E(lerp(u0, u1, k / 6), side, 0.7) } end
      if spiny then ink.smooth(pts, true, 0.35) else ink.smooth(pts, true, 0.9) end
      ink.fill(tone(t0 - 0.06), 0.82)
    end
    -- the tail fin, from the stalk's end
    local function tailfin()
      local px, py = S(1) local tx, ty = T(1)
      local nx, ny = -ty, tx
      local cl, th = F.cl * rng.range(0.92, 1.06), F.th * rng.range(0.92, 1.08)
      local w = tp(1)
      local function at(a, b) return { px - tx * a + nx * b, py - ty * a + ny * b } end
      local P
      if F.tail == "forked" then P = { at(0, w), at(cl * 0.55, th * 0.75), at(cl * 1.02, th * 1.02), at(cl * 0.92, th * 0.55), at(cl * 0.55, 0), at(cl * 0.92, -th * 0.55), at(cl * 1.02, -th * 1.02), at(cl * 0.55, -th * 0.75), at(0, -w) }
      elseif F.tail == "square" then P = { at(0, w), at(cl * 0.7, th * 0.85), at(cl, th), at(cl * 0.96, 0), at(cl, -th), at(cl * 0.7, -th * 0.85), at(0, -w) }
      else P = { at(0, w), at(cl * 0.7, th * 0.9), at(cl * 1.02, th * 0.75), at(cl * 1.05, 0), at(cl * 1.02, -th * 0.75), at(cl * 0.7, -th * 0.9), at(0, -w) } end
      ink.smooth(P, true, F.tail == "forked" and 0.7 or 0.55) ink.fill(tone(t0 - 0.06), 0.85)
      for k = 0, 8 do local b = lerp(-0.9, 0.9, k / 8) local q = at(cl * (F.tail == "forked" and (0.6 + 0.4 * abs(b)) or 0.95), th * b) rays[#rays + 1] = { px, py, q[1], q[2] } end
      return P
    end
    -- painting: fins behind, the body, its shading, the head, the pectoral fin over it
    local tf = tailfin()
    for _, d in ipairs(F.dorsal) do fin(d[1], d[2], d[3], 1, d[4], d[5]) end
    local a = F.anal
    fin(a[1], a[2], a[3], -1, false, false, a[4])
    local pvx, pvy = E(0.3, -1, 0.9)                     -- the pelvic fin
    fillp({ { pvx + 0.02, pvy }, { pvx - 0.07, pvy - F.pect * 0.6 }, { pvx - 0.05, pvy + 0.01 } }, tone(t0 - 0.08), 0.85)
    if fine then
      for _, r in ipairs(rays) do ink.moveto(r[1], r[2]) ink.lineto(r[3], r[4]) end
      ink.stroke(tone(t0 - 0.2), bp(0.0028), 0.55)
    end
    ink.smooth(body, true) ink.stroke(tone(t0 - 0.2), bp(0.008))
    ink.smooth(body, true) ink.fill(tone(t0))
    ink.smooth(body, true) ink.clip()
      -- the back darker, the belly pale, a lit streak along the upper flank
      ink.smooth(ink.blade(spine, 24, function(v) return tp(1 - v) * 1.1 end, function(v) return -tp(1 - v) * 0.25 end), true) ink.fill(tone(t0 - 0.12), 0.55)
      ink.smooth(ink.blade(spine, 24, function(v) return -bt(1 - v) * 0.15 end, function(v) return bt(1 - v) * 1.1 end), true) ink.fill(white, kind == "garibaldi" and 0.12 or 0.42)
      if F.mottle then                                   -- a rockfish's blotches
        for _ = 1, 9 do local u = rng.range(0.25, 0.95) local x, y = E(u, 1, rng.range(-0.3, 0.7)) ink.smooth(ink.blob(rng, x, y, tp(u) * 0.35, tp(u) * 0.25, 0.3, 8), true) ink.fill(tone(t0 - 0.14), 0.6) end
        for _ = 1, 5 do local u = rng.range(0.3, 0.9) local x, y = E(u, -1, rng.range(0.1, 0.6)) ink.circle(x, y, bt(u) * 0.16) ink.fill(tone(t0 + 0.25), 0.4) end
      end
      if F.blotch then                                   -- a kelp bass's pale squares in two rows on the back
        for row = 1, 2 do
          for k = 1, 6 do
            local u = 0.24 + 0.115 * k + (row == 2 and 0.05 or 0) + rng.sym(0.015)
            local x, y = E(u, 1, row == 1 and 0.5 or 0.05)
            local r = tp(u) * 0.2
            ink.smooth({ { x - r, y - r * 0.8 }, { x + r, y - r * 0.9 }, { x + r * 1.05, y + r * 0.8 }, { x - r * 0.9, y + r } }, true, 0.6)
          end
        end
        ink.fill(tone(t0 + 0.32), 0.6)
      end
      if kind == "senorita" then                         -- the black crescent at the tail's base
        local x, y = S(0.95)
        ink.smooth(ellipse(x, y, 0.03, tp(0.95) * 0.95, 12), true) ink.fill(tone(0.04))
      end
      if finer then                                      -- scales: rows of arcs open to the nose
        for row = -2, 3 do
          for k = 1, 13 do
            local u = 0.3 + 0.052 * k + (row % 2) * 0.026
            if u < 0.98 then
              local x, y = E(u, row >= 0 and 1 or -1, abs(row) / 3.6)
              local r = tp(u) * 0.14
              ink.moveto(x, y + r) ink.curveto(x - r, y + r * 0.6, x - r, y - r * 0.6, x, y - r)
            end
          end
        end
        ink.stroke(tone(t0 - 0.14), bp(0.0024), 0.45)
      end
      if fine then                                       -- the lateral line, following the back
        local ll = {}
        for k = 0, 8 do ll[#ll + 1] = { E(lerp(0.27, 0.98, k / 8), 1, 0.48 - 0.3 * k / 8) } end
        ink.smooth(ll, false) ink.stroke(tone(t0 - 0.16), bp(0.003), 0.6)
      end
      local lt = {}
      for k = 0, 8 do lt[#lt + 1] = { E(lerp(0.12, 0.85, k / 8), 1, 0.68) } end
      ink.smooth(lt, false) ink.stroke(white, bp(0.012), kind == "garibaldi" and 0.25 or 0.2)
      -- the gill cover's edge, a rockfish's spines on it
      local uo = F.eye[1] + 0.13
      local o1 = { E(uo, 1, 0.65) } local o2x, o2y = E(uo + 0.04, 1, 0.0) local o3 = { E(uo - 0.02, -1, 0.75) }
      ink.smooth({ o1, { o2x, o2y }, o3 }, false) ink.stroke(tone(t0 - 0.2), bp(kind == "senorita" and 0.005 or 0.007), 0.8)
      if kind == "rockfish" and fine then
        for k = 1, 3 do local x, y = E(uo - 0.04 + 0.01 * k, 1, 0.5 - 0.25 * k) ink.moveto(x, y) ink.lineto(x - 0.035, y - 0.005) end
        ink.stroke(tone(t0 - 0.2), bp(0.004), 0.8)
      end
      ink.smooth(body, true) ink.stroke(tone(t0 - 0.2), bp(0.005), 0.5)
    ink.unclip()
    -- the mouth: a line from the snout back toward the eye; a bass's lower jaw juts
    do
      local nx_, ny_ = S(0)
      local mx, my = E(F.mouth, -1, 0.1)
      ink.moveto(nx_ - 0.004, ny_ - 0.004) ink.lineto(mx, my) ink.stroke(tone(t0 - 0.28), bp(kind == "senorita" and 0.006 or 0.009))
      if kind == "bass" or kind == "rockfish" then
        local jx, jy = E(0.02, -1, 0.6)
        fillp({ { nx_ + 0.008, ny_ - 0.006 }, { jx, jy }, { mx, my - 0.01 }, { mx + 0.02, my + 0.004 } }, tone(t0 - 0.04))
      end
    end
    -- the pectoral fin, over the flank behind the gill cover
    do
      local px, py = E(F.eye[1] + 0.16, -1, 0.25)
      local tx, ty = T(F.eye[1] + 0.16)
      local l = F.pect * rng.range(0.9, 1.1)
      local a = rng.range(-0.5, -0.15)                  -- spread down and back
      local P = { { px, py } }
      for k = 0, 6 do
        local an = a + (k - 3) * 0.12
        local dx, dy = -tx * cos(an) + ty * sin(an), -ty * cos(an) - tx * sin(an)
        P[#P + 1] = { px + dx * l * (0.8 + 0.2 * sin(pi * k / 6)), py + dy * l * (0.8 + 0.2 * sin(pi * k / 6)) }
      end
      ink.smooth(P, true, 0.8) ink.fill(tone(t0 - 0.02), 0.8)
      if fine then for k = 2, #P - 1 do ink.moveto(px, py) ink.lineto(P[k][1], P[k][2]) end ink.stroke(tone(t0 - 0.18), bp(0.0024), 0.5) end
    end
    -- the eye: a pale iris, a dark pupil, a highlight
    do
      local ex, ey = E(F.eye[1], 1, 0.32)
      local r = F.eye[2]
      if D * r > 0.05 then ink.circle(ex, ey, r) ink.fill(tone(kind == "garibaldi" and 0.3 or 0.82)) end
      ink.circle(ex + r * 0.08, ey, r * (D * r > 0.05 and 0.62 or 0.8)) ink.fill(tone(0.03))
      ink.circle(ex - r * 0.18, ey + r * 0.22, r * 0.2) ink.fill(white, 0.9)
    end
    ink.pop()
  end

  -- ---------------------------------------------------------------- jelly
  -- a jelly drifting, the bell above the origin (s wide), its arms and tentacles trailing against the current:
  -- a moon jelly (a shallow clear dome, four horseshoe gonads, a fringe of short tentacles, four short frilly arms)
  -- or a sea nettle (a deeper bell striped by its radial bands, long ribbon arms spiraling, long tentacles)
  function M.jelly(rng, s, cur)
    local nettle = rng.chance(0.5)
    cur = cur or 1
    ink.push() ink.scale(s)
    local D = ink.unit()
    local fine = lifted() and D > 0.9
    local bp = function(f) return f * D * CM end
    local pulse = rng.range(0.85, 1.15)                -- relaxed and wide, or contracted and tall
    local W, H = 0.5 / pulse ^ 0.3, (nettle and 0.4 or 0.28) * pulse
    local lean = rng.sym(8) * pi / 180
    local function bellpts(k)                           -- the dome, and its scalloped rim
      local out = {}
      for j = 0, 20 do local a = pi * j / 20 out[#out + 1] = { W * k * cos(a), H * k * sin(a) ^ (nettle and 0.6 or 0.8) } end
      local nl = nettle and 16 or 24
      for j = 1, nl - 1 do local t = j / nl out[#out + 1] = { lerp(-W, W, t) * k, -0.025 * abs(sin(t * pi * nl / 2)) * k } end
      return out
    end
    local tent = tone(nettle and 0.42 or 0.55)
    -- tentacles: from the rim, trailing against the current in a slow wave
    local nt = nettle and 18 or 30
    for k = 1, nt do
      local x0 = lerp(-W * 0.95, W * 0.95, (k - 0.5) / nt)
      local Lt = (nettle and rng.range(0.55, 0.9) or rng.range(0.12, 0.28))
      local pts = {}
      for j = 0, 6 do local t = j / 6 pts[#pts + 1] = { x0 - cur * Lt * 0.35 * t * t + 0.025 * sin(t * 7 + k), -0.02 - Lt * t } end
      ink.smooth(pts, false)
    end
    ink.stroke(tent, bp(nettle and 0.004 or 0.003), 0.75)
    -- oral arms
    local na = 4
    for k = 1, na do
      local x0 = lerp(-W * 0.22, W * 0.22, (k - 0.5) / na)
      local La = nettle and rng.range(0.6, 0.95) or rng.range(0.22, 0.32)
      local ph = rng.range(0, 2 * pi)
      local spine = function(v) return x0 - cur * La * 0.3 * v * v + (nettle and 0.05 or 0.02) * sin(v * 9 + ph) * v, -0.03 - La * v end
      local wf = function(v) return (nettle and 0.045 or 0.05) * (1 - 0.7 * v) end
      local frill = fine and function(v, sd) return 0.008 * sin(v * 26 + sd * 2 + ph) end or nil
      local P = ink.blade(spine, 28, wf, wf, frill)
      ink.smooth(P, true) ink.fill(tone(nettle and 0.5 or 0.6), 0.75)
      if fine then local mid = {} for j = 0, 8 do mid[#mid + 1] = { spine(j / 8) } end ink.smooth(mid, false) ink.stroke(tone(0.4), bp(0.003), 0.6) end
    end
    -- the bell: the far inside darker, then the clear dome over everything
    ink.push() ink.rotate(lean * 180 / pi * -cur)
    ink.smooth(ellipse(0, -0.01, W * 0.8, 0.05, 16), true) ink.fill(tone(0.45), 0.5)
    local bell = ccw(bellpts(1))
    ink.smooth(bell, true) ink.stroke(tone(0.42), bp(0.006), 0.7)
    ink.smooth(bell, true) ink.fill(tone(nettle and 0.62 or 0.74), 0.72)
    ink.smooth(bell, true) ink.clip()
      if nettle then                                   -- the radial bands, curving with the dome
        for k = 1, 15 do
          local t = (k - 0.5) / 15
          local x0 = lerp(-W, W, t)
          ink.moveto(x0, -0.02) ink.curveto(x0 * 0.9, H * 0.5, x0 * 0.5, H * 0.9, x0 * 0.2, H * 1.05)
        end
        ink.stroke(tone(0.38), bp(0.02), 0.45)
      else                                             -- four horseshoe gonads seen through the top
        for k = 1, 4 do
          local cx = lerp(-W * 0.55, W * 0.55, (k - 0.5) / 4)
          ink.smooth(ellipse(cx, H * 0.38, W * 0.12, H * 0.2, 14), true) ink.stroke(tone(0.4), bp(0.012), 0.75)
        end
        if fine then for k = 1, 12 do local t = (k - 0.5) / 12 local x0 = lerp(-W, W, t) ink.moveto(x0, 0) ink.lineto(x0 * 0.35, H * 0.92) end ink.stroke(tone(0.55), bp(0.003), 0.5) end
      end
      ink.smooth(ink.blade(function(v) local a = pi * (0.85 - 0.5 * v) return W * 0.82 * cos(a), H * 0.82 * sin(a) ^ 0.7 end, 12, function() return 0.03 end, function() return 0.03 end), true)
      ink.fill(white, 0.45)                             -- the light on the dome
      ink.smooth(bell, true) ink.stroke(white, bp(0.01), 0.35)
    ink.unclip()
    ink.pop()
    ink.pop()
  end

  -- ---------------------------------------------------------------- by-the-wind sailor
  -- Velella at the surface (waterline y = 0): a deep blue oval float seen a little from the side, ringed,
  -- with a pale mantle edge; a thin clear sail standing across it on the diagonal, its top edge an S; a short
  -- dark fringe of tentacles below the water. s = float length
  function M.sailor(rng, s)
    ink.push() ink.scale(s)
    local D = ink.unit()
    local fine = lifted() and D > 0.6
    local bp = function(f) return f * D * CM end
    local tilt = rng.sym(0.06)
    -- the tentacles, short, under the water
    for k = 1, 14 do
      local x = lerp(-0.4, 0.4, (k - 0.5) / 14)
      ink.moveto(x, -0.04) ink.lineto(x + rng.sym(0.03), -rng.range(0.12, 0.2))
    end
    ink.stroke(tone(0.25), bp(0.012), 0.85)
    -- the float
    local fl = ellipse(0, 0, 0.5, 0.13, 22, tilt)
    ink.smooth(fl, true) ink.stroke(tone(0.12), bp(0.012))
    ink.smooth(fl, true) ink.fill(tone(0.22))
    ink.smooth(fl, true) ink.clip()
      ink.smooth(ellipse(0, 0.02, 0.4, 0.085, 20, tilt), true) ink.fill(tone(0.4), 0.8)   -- the float's top, paler
      if fine then for k = 1, 3 do ink.smooth(ellipse(0, 0.02, 0.4 - 0.1 * k, 0.085 - 0.02 * k, 18, tilt), true) end ink.stroke(tone(0.62), bp(0.008), 0.8) end
      ink.smooth(ellipse(0, -0.11, 0.5, 0.05, 18), true) ink.fill(tone(0.12), 0.6)
    ink.unclip()
    -- the sail: a thin blade, edge on toward its ends, standing on a diagonal of the float
    local x0, x1 = -0.3, 0.3
    x0, x1 = -0.22, 0.16
    local h = rng.range(0.5, 0.62)
    local top = { { x0, 0.02 }, { x0 + 0.06, h * 0.35 }, { -0.06, h * 0.82 }, { 0.0, h }, { 0.035, h * 0.8 }, { 0.09, h * 0.35 }, { x1, 0.03 } }
    local sail = {}
    for _, q in ipairs(top) do sail[#sail + 1] = q end
    sail[#sail + 1] = { 0.0, 0.05 }
    ink.smooth(sail, true, 0.7) ink.fill(tone(0.84), 0.5)
    ink.smooth(top, false)
    ink.stroke(tone(0.35), bp(0.008), 0.9)
    if fine then                                        -- the sail's growth lines
      for k = 1, 3 do local t = k / 4 ink.moveto(lerp(x0, x1, t), 0.03) ink.curveto(lerp(x0, x1, t) * 0.8, h * 0.4, lerp(-0.05, 0.03, t), h * 0.7, lerp(-0.04, 0.03, t), h * 0.85) end
      ink.stroke(tone(0.5), bp(0.004), 0.6)
    end
    ink.pop()
  end

  -- ---------------------------------------------------------------- shrimp
  -- a shrimp side on, facing +x: the carapace ending in a toothed rostrum, a stalked eye, the abdomen's six
  -- segments curving down, each a plate over the next, a fan of uropods and telson; five pairs of jointed
  -- walking legs, swimmerets under the abdomen, long antennae and short antennules; s = length
  function M.shrimp(rng, s)
    ink.push() ink.scale(s)
    local D = ink.unit()
    local fine = lifted() and D > 0.6
    local bp = function(f) return f * D * CM end
    local t0 = rng.range(0.46, 0.56)
    local curl = rng.range(1.7, 2.3)                    -- how far the tail curls under
    -- the spine: from the rostrum's base (v 0) back along the carapace and down into the tail (v 1)
    local c = (curl - 1.7) / 0.6                        -- 0..1
    local spine = M._curve({ { 0.13, 0.15 }, { -0.04, 0.165 }, { -0.19, 0.155 }, { -0.31, 0.11 }, { -0.39 - 0.02 * c, 0.03 - 0.03 * c }, { -0.39 + 0.02 * c, -0.05 - 0.03 * c } })
    local hw = function(v) return (0.045 + 0.045 * min(1, v * 5) ^ 0.5) * (1 - v) ^ 0.6 + 0.02 end
    local function at(v, k) local x, y = spine(v) local x2, y2 = spine(min(1, v + 0.01)) local dx, dy = x2 - x, y2 - y local l = sqrt(dx * dx + dy * dy) + 1e-9 return x + dy / l * hw(v) * k, y - dx / l * hw(v) * k, dx / l, dy / l end   -- k > 0: the back
    -- legs first, behind the body: five walking legs under the carapace, jointed
    local legc = tone(t0 - 0.08)
    for k = 1, 5 do
      local x0, y0 = at(0.04 + 0.05 * k, -0.85)
      local kx, ky = x0 + 0.03 - 0.01 * k, y0 - 0.06
      ink.moveto(x0, y0) ink.lineto(kx, ky) ink.lineto(kx + 0.05 - 0.01 * k, ky - 0.065)
    end
    ink.stroke(legc, bp(0.008), 0.9)
    -- swimmerets under the abdomen
    for k = 1, 4 do local x0, y0, tx, ty = at(0.36 + 0.1 * k, -0.9) ink.moveto(x0, y0) ink.lineto(x0 - ty * 0.05 - tx * 0.02, y0 + tx * 0.05 - ty * 0.02) end
    ink.stroke(legc, bp(0.01), 0.8)
    -- the tail fan
    local ex, ey = at(1, 0)
    local qx, qy = at(0.96, 0)
    local tx, ty = ex - qx, ey - qy                     -- the end tangent (at(1) has none: its step is clamped)
    local tl = sqrt(tx * tx + ty * ty) + 1e-9
    tx, ty = tx / tl, ty / tl
    ex, ey = ex + tx * 0.008, ey + ty * 0.008           -- the fan starts at the last segment, out along its tangent
    for _, sd in ipairs({ -1, 0, 1 }) do
      local ax, ay = tx * 0.2 + sd * -ty * 0.075, ty * 0.2 + sd * tx * 0.075
      fillp({ { ex, ey }, { ex + ax - ty * 0.035, ey + ay + tx * 0.035 }, { ex + ax * 1.08, ey + ay * 1.08 }, { ex + ax + ty * 0.035, ey + ay - tx * 0.035 } }, tone(t0 - 0.04), 0.9)
    end
    -- the body: carapace and abdomen, one outline
    local body = ccw((ink.blade(spine, 30, hw, hw)))
    local ros = { { 0.06, 0.22 }, { 0.36, 0.215 }, { 0.3, 0.2 }, { 0.12, 0.15 } }   -- the rostrum
    ink.smooth(body, true) ink.poly(ros, true) ink.stroke(tone(t0 - 0.2), bp(0.012))
    ink.smooth(body, true) ink.poly(ros, true) ink.fill(tone(t0))
    ink.smooth(body, true) ink.clip()
      ink.smooth(ink.blade(spine, 20, function(v) return hw(v) * 1.1 end, function(v) return -hw(v) * 0.3 end), true) ink.fill(tone(t0 - 0.1), 0.5)
      ink.smooth(ink.blade(spine, 20, function(v) return -hw(v) * 0.2 end, function(v) return hw(v) * 1.1 end), true) ink.fill(white, 0.3)
      -- segment plates: each overlaps the next, a line and a shade behind it
      for k = 1, 6 do
        local v = 0.36 + 0.095 * (k - 1)
        local a1, b1 = at(v, 1.1) local a2, b2 = at(v + 0.02, 0) local a3, b3 = at(v, -1.1)
        ink.moveto(a1, b1) ink.curveto(a2, b2, a2, b2, a3, b3)
      end
      ink.stroke(tone(t0 - 0.2), bp(0.006), 0.8)
      if fine then                                       -- a red rock shrimp's stripes along the body
        for _, k in ipairs({ 0.55, 0.05, -0.45 }) do local ln = {} for j = 0, 10 do ln[#ln + 1] = { at(0.02 + 0.09 * j, k) } end ink.smooth(ln, false) end
        ink.stroke(tone(t0 - 0.22), bp(0.008), 0.55)
      end
      ink.smooth(ellipse(-0.02, 0.2, 0.12, 0.03, 12), true) ink.fill(white, 0.4)   -- light on the carapace
    ink.unclip()
    -- the eye on its stalk, the antennae and antennules
    ink.moveto(0.1, 0.18) ink.lineto(0.13, 0.215) ink.stroke(tone(t0 - 0.15), bp(0.012))
    ink.circle(0.135, 0.22, 0.026) ink.fill(tone(0.04))
    if fine then ink.circle(0.128, 0.227, 0.008) ink.fill(white, 0.9) end
    local w1 = rng.sym(0.08)
    ink.moveto(0.12, 0.16) ink.curveto(0.35, 0.36 + w1, 0.55, 0.34, 0.72, 0.1 + w1)
    ink.moveto(0.13, 0.18) ink.curveto(0.32, 0.45, 0.52, 0.5 - w1, 0.7, 0.42 - w1)
    ink.stroke(tone(t0 - 0.12), bp(0.005), 0.9)
    ink.moveto(0.15, 0.19) ink.curveto(0.25, 0.28, 0.32, 0.3, 0.4, 0.28)
    ink.moveto(0.15, 0.19) ink.curveto(0.24, 0.25, 0.32, 0.25, 0.38, 0.22)
    ink.stroke(tone(t0 - 0.12), bp(0.006), 0.9)
    ink.pop()
  end

  return M
end)()
M.fish, M.jelly, M.sailor, M.shrimp = SW.fish, SW.jelly, SW.sailor, SW.shrimp

-- the seafloor's animals, redrawn (by marginalia-partner): a red rock crab head on, ochre and bat stars, giant green
-- and strawberry anemones, a Kellet's whelk, a skate's egg case, a round spiny urchin
local SF = (function()
  local ink = require("florilegium-ink")
  -- scratch/kelp/sealife-floor.lua -- the kelp forest's floor animals, a prototype (procedural, nothing traced).
  -- Same signatures and frames as florilegium-theme-kelp.lua's:
  --   crab(rng, s)       a red rock crab head on, standing at the origin; s = shell width
  --   star(rng, r, t0)   an ochre or a bat star from above, centered; r = arm length, t0 = tone
  --   urchin(rng, r)     a purple urchin side on, its test centered at the origin; r = spine radius
  --   anemone(rng, h)    a giant green anemone, or a cluster of strawberry anemones, side on, foot at the origin
  --   whelk(rng, s)      a Kellet's whelk lying tilted, centered; s = length
  --   eggcase(rng, s)    a skate's egg case, centered, along x; s = length
  -- Each: a union silhouette (outline = a double-width stroke under the fill), tonal layers inside a clip (lit
  -- from the upper left), detail by the size on the page (D, cm: mid above 0.55, fine above 1.8).
  local M = {}

  local sin, cos, pi, abs, max, min, sqrt, floor, atan = math.sin, math.cos, math.pi, math.abs, math.max, math.min, math.sqrt, math.floor, math.atan
  local tone, white = ink.tone, ink.white
  local CM = 72 / 2.54
  local function lerp(a, b, t) return a + (b - a) * t end
  local function area(p) local s = 0 for i = 1, #p do local a, b = p[i], p[i % #p + 1] s = s + a[1] * b[2] - b[1] * a[2] end return s end
  local function ccw(p) if area(p) >= 0 then return p end local r = {} for i = #p, 1, -1 do r[#r + 1] = p[i] end return r end
  local function ellipse(cx, cy, rx, ry, n, a0)
    local out, ca, sa = {}, cos(a0 or 0), sin(a0 or 0)
    for k = 0, (n or 16) - 1 do
      local a = 2 * pi * k / (n or 16)
      local x, y = rx * cos(a), ry * sin(a)
      out[#out + 1] = { cx + x * ca - y * sa, cy + x * sa + y * ca }
    end
    return out
  end
  -- detail from the size on the page: D cm; mid, fine; bp(f): a width f (in the animal's units) in bp
  local function sizing(s)
    local D = ink.unit() * s
    local lift = ink.get_lift()
    return D, D > 0.55 and lift < 0.5, D > 1.8 and lift < 0.3, function(f) return max(0.15, f * ink.unit() * CM) end
  end
  -- a limb: a ribbon through pts (smoothed), full width w0 -> w1
  local function limb(pts, w0, w1)
    return ccw(ink.ribbon(#pts > 2 and ink.catmull(pts, 6) or pts, function(u) return lerp(w0, w1, u) end))
  end
  -- paint shapes as one silhouette: the edge first at twice its width, then the fill
  local function solid(shapes, c, edge, w)
    for _, p in ipairs(shapes) do ink.smooth(p, true) end
    ink.stroke(edge, w * 2)
    for _, p in ipairs(shapes) do ink.smooth(p, true) end
    ink.fill(c)
  end
  local function clipto(shapes) for _, p in ipairs(shapes) do ink.smooth(p, true) end ink.clip() end

  -- ---------------------------------------------------------------- crab
  -- red rock crab, head on: a broad dome of a shell with toothed sides, eyes on short stalks between, the big
  -- claws (black-tipped fingers) raised or folded in front of the mouth, four jointed legs a side, the back
  -- ones behind; standing at the origin, s = shell width
  function M.crab(rng, s)
    local D, mid, fine, bp = sizing(s)
    local W, Hs = s * 0.5, s * 0.3
    local by = s * rng.range(0.28, 0.36)                  -- the shell's lower rim, above the ground
    local t0 = rng.range(0.26, 0.34)
    local raised = rng.chance(0.55)
    local edge = tone(t0 - 0.16)
    -- legs, back pair first
    for k = 4, 1, -1 do
      local u = (k - 1) / 3
      local legs = {}
      for _, sd in ipairs({ -1, 1 }) do
        local j = rng.sym(0.06)
        local c0 = { sd * W * lerp(0.5, 0.8, u), by + Hs * 0.15 }
        local kn = { sd * W * (lerp(1.05, 1.55, u) + j), by + Hs * lerp(0.95, 0.5, u) + s * rng.sym(0.03) }
        local an = { sd * W * (lerp(1.45, 2.05, u) + j), by * lerp(0.6, 0.45, u) }
        local tp = { sd * W * (lerp(1.55, 2.2, u) + j * 1.3), 0 }
        legs[#legs + 1] = limb({ c0, { lerp(c0[1], kn[1], 0.5), lerp(c0[2], kn[2], 0.6) }, kn }, s * 0.09, s * 0.075)
        legs[#legs + 1] = limb({ kn, { lerp(kn[1], an[1], 0.5) + sd * s * 0.02, lerp(kn[2], an[2], 0.5) }, an }, s * 0.07, s * 0.052)
        legs[#legs + 1] = limb({ an, tp }, s * 0.05, s * 0.006)
        legs[#legs + 1] = ellipse(kn[1], kn[2], s * 0.045, s * 0.04, 10)
      end
      solid(legs, tone(t0 - lerp(0.0, 0.08, u)), edge, bp(0.012))
      if mid then                                         -- a lit top edge on each leg
        for _, sd in ipairs({ -1, 1 }) do
          ink.moveto(sd * W * lerp(0.65, 0.95, u), by + Hs * 0.35) ink.lineto(sd * W * lerp(1.0, 1.5, u), by + Hs * lerp(1.0, 0.56, u))
        end
        ink.stroke(white, bp(0.018), 0.28)
      end
    end
    -- shell and body
    local shell = {}
    local nt = 5                                          -- teeth along each side
    for k = 0, 40 do
      local a = pi * k / 40
      local x, y = W * cos(a), Hs * sin(a) ^ 0.75
      local side = abs(cos(a))
      if side > 0.35 and mid then                         -- the anterolateral teeth, pointing out
        local q = (side - 0.35) / 0.65 * nt
        local f = q - floor(q)
        local bump = (f < 0.5 and f / 0.5 or (1 - f) / 0.5) * 0.06
        x, y = x * (1 + bump), y * (1 + bump * 0.6)
      end
      shell[#shell + 1] = { x, by + y }
    end
    shell[#shell + 1] = { -W * 0.85, by - Hs * 0.12 }
    shell[#shell + 1] = { 0, by - Hs * 0.22 }
    shell[#shell + 1] = { W * 0.85, by - Hs * 0.12 }
    shell = ccw(shell)
    -- the claws: arm, wrist, a broad palm, the fixed finger and the movable one, tips dark
    local claws, tips = {}, {}
    local big = rng.chance(0.5) and 1 or -1               -- one claw a little bigger
    for _, sd in ipairs({ -1, 1 }) do
      local k = sd == big and 1.12 or 0.95
      local sh = { sd * W * 0.55, by + Hs * 0.05 }
      local el, wr, pa, ang
      if raised then
        el = { sd * W * 1.05, by + Hs * 0.75 }
        wr = { sd * W * 1.0, by + Hs * 1.55 }
        ang = (90 + sd * 25) * pi / 180                 -- the palm up, leaning in
      else
        el = { sd * W * 0.95, by - Hs * 0.2 }
        wr = { sd * W * 0.55, by - Hs * 0.35 }
        ang = (sd > 0 and 180 or 0) * pi / 180 + sd * 0.15   -- the palm across the mouth
      end
      local cx, cy = cos(ang), sin(ang)
      pa = { wr[1] + cx * s * 0.2 * k, wr[2] + cy * s * 0.2 * k }
      claws[#claws + 1] = limb({ sh, el }, s * 0.12, s * 0.1)
      claws[#claws + 1] = limb({ el, wr }, s * 0.1, s * 0.11)
      claws[#claws + 1] = ellipse(el[1], el[2], s * 0.055, s * 0.05, 10)
      claws[#claws + 1] = ellipse((wr[1] + pa[1]) / 2, (wr[2] + pa[2]) / 2, s * 0.15 * k, s * 0.1 * k, 16, ang)
      -- fingers: from the palm's end, the fixed one straight on, the movable one hinged on the outer side
      local open = rng.range(0.25, 0.6)
      local nx, ny = -cy * sd, cx * sd                   -- toward the claw's outer side
      local f1 = { pa[1] + cx * s * 0.16 * k - nx * s * 0.02, pa[2] + cy * s * 0.16 * k - ny * s * 0.02 }
      local f2 = { pa[1] + (cx * cos(open) + nx * sin(open)) * s * 0.17 * k, pa[2] + (cy * cos(open) + ny * sin(open)) * s * 0.17 * k }
      local b1 = { pa[1] - nx * s * 0.035, pa[2] - ny * s * 0.035 }
      local b2 = { pa[1] + nx * s * 0.04, pa[2] + ny * s * 0.04 }
      claws[#claws + 1] = limb({ b1, { lerp(b1[1], f1[1], 0.55), lerp(b1[2], f1[2], 0.55) }, f1 }, s * 0.075 * k, s * 0.012)
      claws[#claws + 1] = limb({ b2, { lerp(b2[1], f2[1], 0.55), lerp(b2[2], f2[2], 0.55) }, f2 }, s * 0.07 * k, s * 0.012)
      tips[#tips + 1] = { f1, b1, cx, cy } tips[#tips + 1] = { f2, b2, cx, cy }
    end
    solid({ shell }, tone(t0), edge, bp(0.012))
    clipto({ shell })
      for b = 1, 3 do                                     -- lit dome, in bands
        local g = 1 - 0.22 * (b - 1)
        ink.smooth(ellipse(-W * 0.15, by + Hs * 0.95, W * 0.85 * g, Hs * 0.75 * g, 18), true) ink.fill(tone(t0 + 0.22), 0.28)
      end
      ink.poly({ { -W * 1.2, by - Hs }, { W * 1.2, by - Hs }, { W * 1.2, by + Hs * 0.08 }, { -W * 1.2, by + Hs * 0.08 } }, true) ink.fill(tone(t0 - 0.12), 0.7)
      if fine then                                        -- granules on the dome
        for _ = 1, 40 do local a, d = rng.range(0.1, pi - 0.1), rng.range(0.25, 0.9) ink.circle(W * d * cos(a), by + Hs * d * sin(a) ^ 0.75, s * 0.008) end
        ink.fill(tone(t0 + 0.3), 0.5)
      end
    ink.unclip()
    if mid then                                           -- the frontal margin and the mouth's frame
      ink.moveto(-W * 0.7, by + Hs * 0.12) ink.curveto(-W * 0.3, by + Hs * 0.3, W * 0.3, by + Hs * 0.3, W * 0.7, by + Hs * 0.12)
      ink.stroke(tone(t0 - 0.14), bp(0.012), 0.8)
      ink.poly({ { -W * 0.22, by + Hs * 0.08 }, { W * 0.22, by + Hs * 0.08 }, { W * 0.16, by - Hs * 0.15 }, { -W * 0.16, by - Hs * 0.15 } }, true)
      ink.fill(tone(t0 - 0.12), 0.9)
    end
    -- eyes on stalks, between them the little antennules
    for _, sd in ipairs({ -1, 1 }) do
      local ex, ey = sd * W * 0.2, by + Hs * 0.62
      ink.moveto(sd * W * 0.14, by + Hs * 0.22) ink.lineto(ex, ey) ink.stroke(tone(t0 - 0.06), max(0.35, bp(0.04)))
      ink.circle(ex, ey, s * 0.045) ink.fill(tone(0.04))
      if mid then ink.circle(ex - s * 0.013, ey + s * 0.014, s * 0.014) ink.fill(white, 0.9) end
    end
    if mid then
      for _, sd in ipairs({ -1, 1 }) do ink.moveto(sd * W * 0.05, by + Hs * 0.25) ink.lineto(sd * W * 0.08, by + Hs * 0.5) end
      ink.stroke(tone(t0 - 0.1), bp(0.012))
    end
    -- claws over the front
    solid(claws, tone(t0 + 0.02), edge, bp(0.012))
    clipto(claws)
      for _, t in ipairs(tips) do                         -- the dark tips of the fingers
        local f, b = t[1], t[2]
        ink.smooth(ellipse(lerp(b[1], f[1], 0.85), lerp(b[2], f[2], 0.85), s * 0.07, s * 0.05, 10, atan(f[2] - b[2], f[1] - b[1])), true)
      end
      ink.fill(tone(0.04))
      if mid then
        for _, t in ipairs(tips) do ink.moveto(t[2][1] - t[3] * s * 0.12, t[2][2] - t[4] * s * 0.12 + s * 0.03) ink.lineto(t[2][1], t[2][2] + s * 0.03) end
        ink.stroke(white, bp(0.02), 0.3)
      end
    ink.unclip()
  end

  -- ---------------------------------------------------------------- sea star
  -- from above, centered: an ochre star (thick tapering arms, a net of white studs) or a bat star (short webbed
  -- arms, a fine scaly skin, an orange madreporite); arms curl a little; tube feet at the tips when large
  function M.star(rng, r, t0)
    local D, mid, fine, bp = sizing(r)
    local bat = rng.chance(0.4)
    local n = (bat and rng.chance(0.2)) and rng.pick({ 4, 6 }) or 5
    local a0 = rng.range(0, 2 * pi)
    local arms, shapes = {}, {}
    for k = 0, n - 1 do
      local a = a0 + 2 * pi * k / n + rng.sym(0.12)
      local L = r * rng.range(0.85, 1.08)
      local curl = rng.sym(bat and 0.15 or 0.4)
      local wb = r * (bat and 0.36 or 0.18) * rng.range(0.9, 1.1)
      local spine = function(u) local aa = a + curl * u * u local d = L * u return d * cos(aa), d * sin(aa) end
      local hw = function(u)
        local w = bat and lerp(wb, r * 0.07, u ^ 0.8) or lerp(wb, r * 0.045, u ^ 0.9)
        if u > 0.86 then w = w * sqrt(max(0, 1 - ((u - 0.86) / 0.14) ^ 2)) end
        return w
      end
      local out, c, nrm = ink.blade(spine, 24, hw, hw)
      shapes[#shapes + 1] = ccw(out)
      arms[#arms + 1] = { spine = spine, hw = hw, a = a, L = L }
    end
    local disc = ellipse(0, 0, r * (bat and 0.48 or 0.24), r * (bat and 0.48 or 0.24), 20)
    shapes[#shapes + 1] = disc
    solid(shapes, tone(t0), tone(t0 - 0.14), bp(0.01))
    clipto(shapes)
      -- each arm's ridge lit, its far side shaded
      for _, A in ipairs(arms) do
        local ridge = ink.blade(A.spine, 16, function(u) return A.hw(u) * 0.55 end, function(u) return A.hw(u) * 0.05 end)
        ink.smooth(ridge, true) ink.fill(tone(t0 + 0.12), 0.55)
      end
      ink.smooth(ellipse(-r * 0.15, r * 0.15, r * 0.3, r * 0.3, 16), true) ink.fill(tone(t0 + 0.12), 0.5)
      if bat then                                         -- the thin rim, curled up and lit
        for _, p in ipairs(shapes) do ink.smooth(p, true) end
        ink.stroke(tone(t0 + 0.25), bp(0.025), 0.5)
      end
      if mid and not bat then                             -- the net of studs: rows down each arm, linked
        local studs = {}
        for _, A in ipairs(arms) do
          local rows = fine and { -0.55, 0, 0.55 } or { 0 }
          for _, v in ipairs(rows) do
            local m = fine and 9 or 5
            for j = 1, m do
              local u = (j - 0.3) / (m + 0.5)
              local x, y = A.spine(u)
              local x2, y2 = A.spine(u + 0.01)
              local dx, dy = x2 - x, y2 - y local l = sqrt(dx * dx + dy * dy) + 1e-9
              local w = A.hw(u) * v
              studs[#studs + 1] = { x - dy / l * w, y + dx / l * w, r * (fine and 0.022 or 0.035) * (1 - 0.5 * u) }
            end
          end
        end
        if fine then                                      -- the net linking them
          for i = 2, #studs do
            local p, q = studs[i - 1], studs[i]
            if (p[1] - q[1]) ^ 2 + (p[2] - q[2]) ^ 2 < (r * 0.16) ^ 2 then ink.moveto(p[1], p[2]) ink.lineto(q[1], q[2]) end
          end
          ink.stroke(tone(t0 + 0.3), bp(0.008), 0.6)
        end
        for _, p in ipairs(studs) do ink.circle(p[1], p[2], p[3]) end
        ink.fill(tone(min(0.95, t0 + 0.45)), 0.9)
        for k = 0, 4 do local a = a0 + 2 * pi * (k + 0.5) / 5 ink.circle(r * 0.13 * cos(a), r * 0.13 * sin(a), r * 0.03) end
        ink.fill(tone(min(0.95, t0 + 0.45)), 0.9)
      end
      if mid and bat then                                 -- scales: rows of small arcs on the arms and disc
        local m = fine and 110 or 40
        for _ = 1, m do
          local A = arms[rng.int(1, #arms)]
          local u = rng.range(0, 0.9) ^ 0.8
          local x, y = A.spine(u)
          local w = A.hw(u) * rng.sym(0.85)
          local x2, y2 = A.spine(u + 0.01)
          local dx, dy = x2 - x, y2 - y local l = sqrt(dx * dx + dy * dy) + 1e-9
          local px, py = x - dy / l * w, y + dx / l * w
          local q = r * 0.025
          ink.moveto(px - q, py) ink.curveto(px - q, py + q, px + q, py + q, px + q, py)
        end
        ink.stroke(tone(t0 - 0.12), bp(fine and 0.008 or 0.014), 0.6)
      end
    ink.unclip()
    if mid then                                           -- the madreporite, off center
      local a = a0 + pi / n
      local x, y = r * (bat and 0.2 or 0.12) * cos(a), r * (bat and 0.2 or 0.12) * sin(a)
      if bat then ink.in_accent(function() ink.circle(x, y, r * 0.05) ink.fill(tone(0.45)) end)
      else ink.circle(x, y, r * 0.04) ink.fill(tone(min(0.95, t0 + 0.4))) end
    end
    if fine then                                          -- tube feet feeling out past the tips
      for _, A in ipairs(arms) do
        for q = -1, 1 do
          local x, y = A.spine(0.97)
          local a = A.a + q * 0.35
          local l = r * rng.range(0.05, 0.09)
          ink.moveto(x, y) ink.lineto(x + l * cos(a), y + l * sin(a))
        end
      end
      ink.stroke(tone(t0 + 0.2), bp(0.012), 0.8)
    end
  end

  -- ---------------------------------------------------------------- urchin
  -- a purple urchin side on: a squat test packed with spines, longest at its equator (the ambitus), shorter
  -- on top, splayed where it rests; the face's spines foreshortened toward us; tube feet reaching past them
  function M.urchin(rng, r)
    local D, mid, fine, bp = sizing(r)
    local rt = r * 0.58                                   -- the test; spines 0.6-0.8 of its radius reach about r
    local lit = function(dx, dy) return (dx * -0.55 + dy * 0.83 + 1) / 2 end
    local function ring(m, d0, tones, wb, k)            -- spines from a ring at d0 of the radius, radiating
      local bins = {}
      for i = 1, #tones do bins[i] = {} end
      for q = 1, m do
        local a = 2 * pi * (q + k) / m + rng.sym(0.06)
        local dx, dy = cos(a), sin(a)
        local L = rt * rng.range(0.6, 0.8)
        local bx, by = rt * d0 * dx, rt * d0 * dy
        local reach = rt * (1 - d0) + L * (d0 > 0.9 and 1 or (0.35 + 0.65 * d0))
        local b = min(#tones, 1 + floor(lit(dx, dy) * #tones))
        local l = bins[b]
        l[#l + 1] = { bx + -dy * wb, by + dx * wb, bx + dx * reach, by + dy * reach, bx + dy * wb, by - dx * wb }
      end
      for i, l in ipairs(bins) do
        for _, t in ipairs(l) do ink.poly({ { t[1], t[2] }, { t[3], t[4] }, { t[5], t[6] } }, true) end
        if #l > 0 then ink.fill(tone(tones[i])) end
      end
    end
    local m = mid and (fine and 80 or 54) or 34
    ring(m, 0.95, { 0.06, 0.1, 0.16 }, r * 0.03, 0.5)    -- the outer ring, all round
    ink.circle(0, 0, rt) ink.fill(tone(0.1))
    ink.circle(0, 0, rt) ink.clip()
      for b = 1, 3 do ink.circle(-rt * 0.25, rt * 0.3, rt * (0.85 - 0.2 * b)) ink.fill(tone(0.32), 0.3) end
    ink.unclip()
    ring(floor(m * 0.75), 0.7, { 0.12, 0.2, 0.32 }, r * 0.028, 0)   -- inner rings, foreshortened toward us
    ring(floor(m * 0.5), 0.4, { 0.16, 0.26, 0.4 }, r * 0.026, 0.3)
    if mid then                                           -- the lit side's spine tips
      for _ = 1, fine and 24 or 12 do
        local a = rng.range(0.35 * pi, 0.95 * pi)
        local d = rng.range(0.75, 1.25)
        ink.moveto(rt * d * cos(a), rt * d * sin(a)) ink.lineto(rt * (d + 0.25) * cos(a), rt * (d + 0.25) * sin(a))
      end
      ink.stroke(tone(0.55), bp(fine and 0.01 or 0.018), 0.7)
    end
    if fine then                                          -- tube feet reaching past the spines
      for _ = 1, rng.int(5, 9) do
        local a = rng.range(-0.2, pi + 0.2)
        local L = r * rng.range(1.0, 1.15)
        local x1, y1 = L * cos(a), L * sin(a)
        ink.moveto(rt * 0.9 * cos(a), rt * 0.9 * sin(a)) ink.curveto(L * 0.75 * cos(a + 0.1), L * 0.75 * sin(a + 0.1), L * 0.9 * cos(a - 0.06), L * 0.9 * sin(a - 0.06), x1, y1)
        ink.stroke(tone(0.62), bp(0.01), 0.75)
        ink.circle(x1, y1, r * 0.018) ink.fill(tone(0.72), 0.9)
      end
    end
    if rng.chance(0.3) then                               -- a scrap of kelp held on top, as they do
      local x = rng.sym(rt * 0.3)
      local bl = ink.blade(function(u) return x + lerp(-r * 0.3, r * 0.3, u), rt + r * 0.08 + r * 0.05 * sin(u * 5) end, 14,
        function(u) return r * 0.06 * sin(pi * u) end, function(u) return r * 0.04 * sin(pi * u) end)
      ink.smooth(bl, true) ink.fill(tone(0.48))
    end
  end

  -- ---------------------------------------------------------------- anemone
  -- side on, foot at the origin: a giant green anemone (a stout column, an oral disc seen a little from above,
  -- stout conical tentacles in rings round it, the back ones behind the disc) or a cluster of strawberry
  -- anemones (small polyps, thin tentacles with white knobbed tips)
  local function polyp(rng, x0, h, o, D, mid, fine, bp)
    local yd = h * o.col
    local rx = h * o.disc
    local ry = rx * 0.3
    local bw = rx * o.foot
    -- tentacles: rings, each tentacle radial in 3D, raised by its ring's angle, seen from a little above
    local back, front = {}, {}
    for ring = 1, #o.rings do
      local R = o.rings[ring]
      local nn = fine and R.n or max(4, floor(R.n * 0.5))
      for k = 1, nn do
        local phi = 2 * pi * (k + ring * 0.37) / nn + rng.sym(0.08)
        local e = (R.e + rng.sym(10)) * pi / 180
        local L = h * R.L * rng.range(0.8, 1.15)
        local bx, by = x0 + rx * R.at * cos(phi), yd + ry * R.at * sin(phi)
        local dx = cos(phi) * cos(e)
        local dy = sin(e) + sin(phi) * cos(e) * 0.3
        local droop = o.droop * L
        local tip = { bx + dx * L, by + dy * L - droop }
        local midp = { bx + dx * L * 0.55, by + dy * L * 0.6 }
        local t = { pts = { { bx, by }, midp, tip }, w0 = h * o.tw, w1 = h * o.tw * o.taper, z = sin(phi), tip = tip }
        if sin(phi) > 0 then back[#back + 1] = t else front[#front + 1] = t end
      end
    end
    local function draw(list, c, lit)
      if #list == 0 then return end
      local shapes = {}
      for _, t in ipairs(list) do shapes[#shapes + 1] = limb(t.pts, t.w0, t.w1) end
      solid(shapes, c, tone(o.t0 - 0.16), bp(0.008))
      if o.knob then
        for _, t in ipairs(list) do ink.circle(t.tip[1], t.tip[2], h * o.tw * 0.9) end
        ink.fill(tone(lit and 0.96 or 0.82))
      elseif mid then
        for _, t in ipairs(list) do
          local p = t.pts
          ink.moveto(lerp(p[1][1], p[3][1], 0.25), lerp(p[1][2], p[3][2], 0.25) + h * 0.008) ink.lineto(lerp(p[1][1], p[3][1], 0.85), lerp(p[1][2], p[3][2], 0.85) + h * 0.004)
        end
        ink.stroke(white, bp(o.tw * 0.35), lit and 0.4 or 0.2)
      end
    end
    draw(back, tone(o.t0 + 0.04), false)
    -- the column, flaring at foot and top, and the disc
    local col = {}
    for k = 0, 10 do
      local u = k / 10
      local w = lerp(bw, rx * 0.95, u) * (1 - 0.12 * sin(pi * u))
      col[#col + 1] = { x0 - w, yd * u }
    end
    for k = 10, 0, -1 do
      local u = k / 10
      local w = lerp(bw, rx * 0.95, u) * (1 - 0.12 * sin(pi * u))
      col[#col + 1] = { x0 + w, yd * u }
    end
    col = ccw(col)
    local disc = ellipse(x0, yd, rx, ry, 20)
    solid({ col, disc }, tone(o.t0), tone(o.t0 - 0.16), bp(0.008))
    clipto({ col })
      ink.poly({ { x0 + rx * 0.15, -h }, { x0 + rx * 2, -h }, { x0 + rx * 2, yd + h }, { x0 + rx * 0.15, yd + h } }, true) ink.fill(tone(o.t0 - 0.1), 0.55)
      ink.poly({ { x0 - rx * 2, -h }, { x0 - rx * 0.55, -h }, { x0 - rx * 0.55, yd + h }, { x0 - rx * 2, yd + h } }, true) ink.fill(tone(o.t0 + 0.12), 0.45)
      if mid and o.warts then                             -- rows of verrucae on the column
        for row = 1, fine and 6 or 3 do
          local y = yd * (row - 0.3) / (fine and 6.4 or 3.4)
          for j = -3, 3 do ink.circle(x0 + j * rx * 0.26 + (row % 2) * rx * 0.13, y, h * 0.012) end
        end
        ink.fill(tone(o.t0 + 0.2), 0.7)
      end
    ink.unclip()
    -- the oral disc: pale, radial lines, the mouth
    ink.smooth(ellipse(x0, yd, rx * 0.92, ry * 0.85, 20), true) ink.fill(tone(o.disct))
    if mid then
      if fine then
        for k = 0, 15 do local a = 2 * pi * k / 16 ink.moveto(x0 + rx * 0.2 * cos(a), yd + ry * 0.2 * sin(a)) ink.lineto(x0 + rx * 0.85 * cos(a), yd + ry * 0.82 * sin(a)) end
        ink.stroke(tone(o.disct - 0.12), bp(0.005), 0.7)
      end
      ink.smooth(ellipse(x0, yd, rx * 0.2, ry * 0.25, 10), true) ink.fill(tone(o.t0 - 0.1))
    end
    draw(front, tone(o.t0 + 0.14), true)
  end
  function M.anemone(rng, h)
    local D, mid, fine, bp = sizing(h)
    if rng.chance(0.35) then                              -- strawberry anemones: a few small polyps
      local n = rng.int(2, 4)
      local xs = {}
      for k = 1, n do xs[k] = lerp(-h * 0.35, h * 0.35, (k - 0.5) / n) + rng.sym(h * 0.06) end
      for k = 1, n do
        local hk = h * rng.range(0.38, 0.55)
        polyp(rng, xs[k], hk, { col = 0.5, disc = 0.38, foot = 0.85, droop = 0.05, tw = 0.035, taper = 0.6, knob = true, warts = false, t0 = 0.42, disct = 0.7,
          rings = { { n = 14, at = 1.0, e = 25, L = 0.42 }, { n = 10, at = 0.65, e = 55, L = 0.34 } } }, ink.unit() * hk, mid, fine, bp)
      end
    else
      polyp(rng, 0, h, { col = 0.5, disc = 0.33, foot = 1.05, droop = 0.03, tw = 0.07, taper = 0.32, knob = false, warts = true, t0 = rng.range(0.3, 0.38), disct = 0.62,
        rings = { { n = 16, at = 1.0, e = 22, L = 0.34 }, { n = 13, at = 0.8, e = 48, L = 0.3 }, { n = 10, at = 0.6, e = 72, L = 0.24 } } }, D, mid, fine, bp)
    end
  end

  -- ---------------------------------------------------------------- whelk
  -- a Kellet's whelk lying tilted (the apex up toward -x as the theme's): whorls stacked up a pointed spire,
  -- each with a row of knobs on its shoulder, the big body whorl with spiral cords, the oval aperture with
  -- its pale lip on the lower side, the siphonal canal; centered, s = length
  function M.whelk(rng, s)
    local D, mid, fine, bp = sizing(s)
    local tilt = rng.range(0.35, 0.6)
    local ax, ay = cos(pi - tilt), sin(pi - tilt)          -- toward the apex
    local nx, ny = -ay, ax
    local P = function(u, v) return (u * ax + v * nx) * s, (u * ay + v * ny) * s end
    local function curve3(u1, v1, u2, v2, u3, v3)
      local x1, y1 = P(u1, v1) local x2, y2 = P(u2, v2) local x3, y3 = P(u3, v3)
      ink.curveto(x1, y1, x2, y2, x3, y3)
    end
    local up = ny > 0 and 1 or -1                         -- v toward the top of the page
    local t0 = rng.range(0.46, 0.56)
    -- whorls: the body whorl, then the spire's, each g of the last
    local g = rng.range(0.74, 0.8)
    local wh = { { lo = -0.3, hi = 0.06, w = 0.24 * rng.range(0.93, 1.07) } }
    local u, h, w = 0.06, 0.12, 0.17
    while u < 0.49 do
      local hi = min(0.5, u + h)
      wh[#wh + 1] = { lo = u, hi = hi, w = w }
      u, h, w = hi, h * g, w * g
    end
    local function shape(i, t)                            -- a whorl's half-width at t (0 base, 1 suture), in s
      local q = wh[i]
      if i == 1 then
        if t < 0.72 then return lerp(0.08, q.w, sin(pi / 2 * t / 0.72) ^ 0.8) end
        return q.w * (1 - (t - 0.72) / 0.28 * 0.3)
      end
      if t < 0.7 then return q.w * (0.78 + 0.22 * sin(pi / 2 * t / 0.7)) end
      return q.w * (1 - (t - 0.7) / 0.3 * 0.24)
    end
    local function hw(uu)                                  -- the profile along the axis, canal to apex
      if uu < -0.3 then return lerp(0.03, 0.08, ((uu + 0.5) / 0.2) ^ 1.4) end
      for i, q in ipairs(wh) do if uu <= q.hi then return shape(i, (uu - q.lo) / (q.hi - q.lo)) end end
      return 0.005
    end
    local bend = rng.sym(0.04)                            -- the canal turned a little
    local out = {}
    local N = 80
    local knob = function(uu)
      for i, q in ipairs(wh) do
        local t = (uu - q.lo) / (q.hi - q.lo)
        if t >= 0 and t <= 1 then return (t > 0.6 and t < 0.84) and q.w * 0.035 * sin(pi * (t - 0.6) / 0.24) or 0 end
      end
      return 0
    end
    for k = 0, N do
      local uu = lerp(-0.5, 0.5, k / N)
      local off = uu < -0.3 and bend * ((-0.3 - uu) / 0.2) ^ 2 or 0
      out[#out + 1] = { P(uu, off + hw(uu) + (mid and knob(uu) or 0)) }
    end
    for k = N - 1, 1, -1 do
      local uu = lerp(-0.5, 0.5, k / N)
      local off = uu < -0.3 and bend * ((-0.3 - uu) / 0.2) ^ 2 or 0
      out[#out + 1] = { P(uu, off - hw(uu) * 0.96 - (mid and knob(uu) or 0)) }
    end
    out = ccw(out)
    solid({ out }, tone(t0), tone(t0 - 0.3), bp(0.012))
    clipto({ out })
      -- the lower flank in shadow, the upper lit, in bands
      ink.poly({ { P(-0.6, -up * 0.02) }, { P(0.6, -up * 0.02) }, { P(0.6, -up * 0.5) }, { P(-0.6, -up * 0.5) } }, true) ink.fill(tone(t0 - 0.16), 0.6)
      for b = 1, 2 do
        ink.poly({ { P(-0.6, up * (0.06 + 0.06 * b)) }, { P(0.6, up * (0.06 + 0.06 * b)) }, { P(0.6, up * 0.5) }, { P(-0.6, up * 0.5) } }, true) ink.fill(tone(t0 + 0.2), 0.35)
      end
      -- sutures, slanted with the coil; knobs on each shoulder
      local sl = 0.035
      for i, q in ipairs(wh) do
        if i > 1 or true then
          local w0 = hw(q.hi - 0.001) * 1.1
          ink.moveto(P(q.hi + sl, -w0)) curve3(q.hi + sl * 0.3, -w0 * 0.3, q.hi - sl * 0.3, w0 * 0.3, q.hi - sl, w0)
        end
      end
      ink.stroke(tone(t0 - 0.3), bp(0.012), 0.9)
      if mid then
        local ph = rng.range(0, 2 * pi)
        for i, q in ipairs(wh) do
          local uu = lerp(q.lo, q.hi, 0.72)
          local m = 9
          for j = 0, m - 1 do
            local a = ph + 2 * pi * j / m + i * 0.9
            if cos(a) > 0.15 then
              local v = sin(a) * hw(uu) * 0.95
              local ku, kv = P(uu - v * 0.12, v)
              ink.smooth(ellipse(ku, kv, q.w * s * 0.1, q.w * s * 0.13, 10, tilt), true) ink.fill(tone(t0 + 0.28), 0.85)
              local du, dv = P(uu - v * 0.12 - q.w * 0.12, v)
              ink.circle(du, dv, q.w * s * 0.05) ink.fill(tone(t0 - 0.2), 0.6)
            end
          end
        end
        for k = 1, fine and 9 or 4 do                    -- spiral cords on the body whorl, with the coil's slant
          local uu = lerp(-0.28, 0.02, k / ((fine and 9 or 4) + 1))
          local w0 = hw(uu) * 1.1
          ink.moveto(P(uu + sl, -w0)) curve3(uu + sl * 0.3, -w0 * 0.3, uu - sl * 0.3, w0 * 0.3, uu - sl, w0)
        end
        ink.stroke(tone(t0 - 0.12), bp(0.008), 0.6)
      end
      if rng.chance(0.35) and mid then                    -- a patch of encrusting life
        local cu, cv = rng.range(-0.2, 0.05), rng.sym(0.1)
        for _ = 1, 12 do local x, y = P(cu + rng.sym(0.06), cv + rng.sym(0.06)) ink.circle(x, y, s * 0.008) end
        ink.fill(tone(0.85), 0.8)
      end
    ink.unclip()
    -- the aperture on the lower side, running into the canal's groove; its pale lip, crenulated
    local ap = {}
    local lo = -up
    for k = 0, 16 do
      local a = 2 * pi * k / 16
      local uu = -0.13 + 0.12 * cos(a)
      local vv = lo * (0.11 + 0.075 * sin(a))
      ap[#ap + 1] = { P(uu, vv) }
    end
    ink.smooth(ap, true) ink.fill(tone(0.1))
    ink.moveto(P(-0.24, lo * 0.1)) ink.lineto(P(-0.45, lo * 0.03)) ink.stroke(tone(0.12), bp(0.022))
    if mid then
      local lip = {}
      for k = 0, 10 do
        local a = pi * (0.05 + 0.9 * k / 10)
        lip[#lip + 1] = { P(-0.13 + 0.13 * cos(a), lo * (0.11 + 0.085 * sin(a))) }
      end
      ink.smooth(lip, false) ink.stroke(tone(0.92), bp(0.028), 0.95)
      ink.moveto(P(0.02, lo * 0.08)) curve3(-0.1, lo * 0.05, -0.25, lo * 0.08, -0.4, lo * 0.04) ink.stroke(tone(0.88), bp(0.016), 0.8)   -- the columella
    end
  end

  -- ---------------------------------------------------------------- egg case
  -- a skate's egg case: a leathery pouch, its ends a little hollow, a thin keel along each side, horns at the
  -- corners (the back pair longer, their tips curled), glossy, fine ridges along it; sometimes split where
  -- the young skate left; centered, along x, s = length
  function M.eggcase(rng, s)
    local D, mid, fine, bp = sizing(s)
    local a, b = s * 0.3, s * rng.range(0.15, 0.19)
    local t0 = rng.range(0.12, 0.2)
    local pouch = {}
    for k = 0, 12 do local u = k / 12 pouch[#pouch + 1] = { lerp(-a, a, u), -b * (1 + 0.08 * sin(pi * u)) } end
    for k = 0, 8 do local u = k / 8 pouch[#pouch + 1] = { a - s * 0.04 * sin(pi * u), lerp(-b, b, u) } end
    for k = 12, 0, -1 do local u = k / 12 pouch[#pouch + 1] = { lerp(-a, a, u), b * (1 + 0.08 * sin(pi * u)) } end
    for k = 8, 0, -1 do local u = k / 8 pouch[#pouch + 1] = { -a + s * 0.05 * sin(pi * u), lerp(-b, b, u) } end
    pouch = ccw(pouch)
    local keels = {}
    for _, sd in ipairs({ -1, 1 }) do
      local k = {}
      for j = 0, 10 do local u = j / 10 k[#k + 1] = { lerp(-a * 0.95, a * 0.95, u), sd * b * (1 + 0.08 * sin(pi * u)) } end
      keels[#keels + 1] = limb(k, s * 0.05, s * 0.05)
    end
    local horns = {}
    for _, cx in ipairs({ -1, 1 }) do
      for _, cy in ipairs({ -1, 1 }) do
        local back = cx < 0
        local L = s * (back and rng.range(0.34, 0.42) or rng.range(0.16, 0.22))
        local turn = (back and rng.range(3.2, 4.2) or rng.range(1.0, 1.5)) * -cy * cx   -- curling in, toward the case
        local x, y = cx * a * 0.98, cy * b * 0.9
        local ang = atan(cy * 0.45, cx)
        local pts = { { x, y } }
        local n = 14
        for j = 1, n do
          local u = j / n
          ang = ang + turn / n * (0.3 + 1.4 * u)          -- tighter toward the tip
          x, y = x + cos(ang) * L / n, y + sin(ang) * L / n
          pts[#pts + 1] = { x, y }
        end
        horns[#horns + 1] = ccw(ink.ribbon(pts, function(u) return s * lerp(0.07, 0.014, u ^ 0.8) end))
      end
    end
    local all = { pouch }
    for _, k in ipairs(keels) do all[#all + 1] = k end
    for _, h in ipairs(horns) do all[#all + 1] = h end
    solid(all, tone(t0), tone(max(0, t0 - 0.12)), bp(0.01))
    -- the keels a little paler and thinner
    for _, k in ipairs(keels) do ink.smooth(k, true) end ink.fill(tone(t0 + 0.12), 0.7)
    ink.smooth(pouch, true) ink.fill(tone(t0))
    clipto({ pouch })
      ink.smooth(ellipse(-a * 0.1, b * 0.25, a * 0.85, b * 0.55, 16), true) ink.fill(tone(t0 + 0.12), 0.6)   -- the raised middle
      ink.moveto(-a * 0.7, b * 0.45) ink.curveto(-a * 0.2, b * 0.62, a * 0.3, b * 0.62, a * 0.75, b * 0.42)
      ink.stroke(white, bp(fine and 0.03 or 0.045), 0.35)                                        -- gloss
      if mid then                                         -- fine ridges along it
        for k = 1, fine and 7 or 3 do
          local y = lerp(-b * 0.8, b * 0.8, k / ((fine and 7 or 3) + 1))
          ink.moveto(-a * 0.9, y) ink.curveto(-a * 0.3, y * 1.06, a * 0.3, y * 1.06, a * 0.9, y)
        end
        ink.stroke(tone(t0 + 0.16), bp(0.006), 0.6)
      end
    ink.unclip()
    if mid and rng.chance(0.35) then                      -- split at the front end: hatched
      ink.moveto(a * 0.97, -b * 0.55) ink.lineto(a * 0.85, -b * 0.2) ink.lineto(a * 0.92, b * 0.1) ink.lineto(a * 0.84, b * 0.45)
      ink.stroke(tone(0.85), bp(0.02), 0.9)
    end
  end

  return M
end)()
M.crab, M.star, M.anemone, M.whelk, M.eggcase, M.urchin = SF.crab, SF.star, SF.anemone, SF.whelk, SF.eggcase, SF.urchin

-- ---------------------------------------------------------------- the forest
-- the understory's mix (a kind twice is twice as likely), and how much taller than the rest a kind grows
local WEEDS = { "palm", "red", "eel", "red", "eel", "oar", "oar", "boa", "sarg", "sarg", "wrack", "wrack", "beads", "padina", "hali", "grapes", "sugar", "sugar", "thong", "dulse", "dulse", "lettuce" }
local TALL = { sugar = 1.8, thong = 2.4, dulse = 0.9, lettuce = 0.6, boa = 2.6, sarg = 1.5, oar = 1.3, beads = 0.7, grapes = 0.6, padina = 0.7, hali = 0.8 }

function M.forest(rng, o)
  local W, H = o.w, o.h
  local cur = o.current or 1
  local keeps = {}
  for i, q in ipairs(o.keepouts or {}) do keeps[i] = { q[1] - 0.25, q[2] - 0.25, q[3] + 0.25, q[4] + 0.25 } end
  local boxes = {}                                     -- what's been placed, for free()
  local function reg(a, b, c, d, tag) boxes[#boxes + 1] = { a, b, c, d, tag } end
  local function blocked(x, y, m)
    m = m or 0
    for _, q in ipairs(keeps) do if x > q[1] - m and x < q[3] + m and y > q[2] - m and y < q[4] + m then return q end end
    return nil
  end
  local function free(a, b, c, d)
    if a < 0.1 or c > W - 0.1 or b < 0.05 or d > H - 0.05 then return false end
    for _, q in ipairs(keeps) do if a < q[3] and c > q[1] and b < q[4] and d > q[2] then return false end end
    for _, q in ipairs(boxes) do if a < q[3] and c > q[1] and b < q[4] and d > q[2] then return false end end
    return true
  end
  local L_FAR, L_FLOOR, L_KELP, L_UNDER, L_LIFE, L_TOP = 1, 2, 3, 4, 5, 6
  local sandtop = rng.range(0.7, 1.1)

  -- the water: one current across the page, the same way for everything, and a slow wave travelling across
  -- it, so neighbors sway together; a little turbulence on top of both, so no two are alike
  local FL = {
    lean = cur * rng.range(0.05, 0.11),            -- how far a stipe leans downstream per cm of height
    amp = rng.range(0.35, 0.7), lam = rng.range(2.6, 4.2), across = rng.range(5, 9), ph = rng.range(0, 2 * pi),
    blade = cur * rng.range(48, 62),               -- a blade's angle from up, downstream
  }
  local n1, n2 = ink.noise1(rng.fork()), ink.noise1(rng.fork())
  local function turb(x, y) return 0.6 * n1(x * 0.45 + y * 0.21) + 0.4 * n2(y * 0.38 - x * 0.17 + 40) end   -- about -1..1
  -- an eddy or two: small places where the water turns, and blades there swing hard against the current
  local eddies = {}
  for _ = 1, rng.int(1, 2) do eddies[#eddies + 1] = { rng.range(W * 0.15, W * 0.85), rng.range(H * 0.2, H * 0.7), rng.range(1.2, 2.2), rng.chance(0.5) and 1 or -1 } end
  local function eddy(x, y)
    local a = 0
    for _, e in ipairs(eddies) do
      local d = math.sqrt((x - e[1]) ^ 2 + (y - e[2]) ^ 2)
      if d < e[3] then a = a + e[4] * 70 * (1 - d / e[3]) ^ 1.5 end
    end
    return a
  end
  -- the wave's sideways offset at (x0, y): it travels across the page, so a stipe further downstream is a
  -- little behind its neighbor
  local function wave(x0, y) return FL.amp * sin(y / FL.lam - x0 / FL.across * cur + FL.ph) end
  -- the blades crowd no cell more than twice (cells half a centimeter across)
  local crowd = {}
  local function cell(x, y) return floor(x / 0.5) * 1000 + floor(y / 0.5) end

  -- the rocks along the floor, left to right, of varying kinds and sizes
  local rocks = {}
  do
    local x = rng.range(-0.3, 0.6)
    while x < W + 0.3 do
      local w = rng.range(1.4, 3.6)
      local kind = rng.pick({ "boulder", "boulder", "slab", "cobbles", "ledge" })
      local cx = x + w / 2
      local q = blocked(cx, sandtop + 0.5) or blocked(cx, sandtop + 1.6) or blocked(cx, sandtop + 2.8)
      if not q then rocks[#rocks + 1] = { x = cx, w = w, kind = kind }
      elseif q[2] < sandtop + 3 and q[4] < H * 0.6 and cx - w / 2 > q[1] and cx + w / 2 < q[3] then
        -- a caption along the floor: a reef ledge rests on top of it, and the kelp grows from there
        rocks[#rocks + 1] = { x = cx, w = w, kind = rng.chance(0.5) and "ledge" or "slab", base = q[4] + 0.05 }
      end
      x = x + w + rng.range(0.3, 2.4)
    end
  end

  -- a stipe from (x0, y0) toward the surface, with the current and a slow wave, steering round the text;
  -- returns its points (the last ones lie over into the canopy)
  local surface = H - rng.range(0.3, 0.8)
  local function stipe(x0, y0, srng, spread)
    local pts = { { x0, y0 } }
    local x, y = x0, y0
    local lean = FL.lean + srng.sym(0.015) + (spread or 0)
    local w0 = wave(x0, y0)
    -- its own height: kelp of every age grows side by side, so a stipe ends anywhere from a quarter of the way
    -- up to the surface, more of them high than low; only one that reaches the surface (or text it can't get
    -- round) lies over into the canopy
    local reach = 0.22 + 0.78 * srng.range(0, 1) ^ 0.55
    local top_ = surface - srng.range(0.3, 1.2)
    local stop = y0 + (top_ - y0) * reach
    local capped = reach > 0.94
    local dy = 0.22
    while y < stop do
      local ny = y + dy
      local tx = x0 + lean * (ny - y0) + (wave(x0, ny) - w0) * min(1, (ny - y0) / 3) + 0.12 * turb(x0, ny)
      -- look ahead: a text box above turns the stipe to its nearer side
      for la = 0.3, 2.4, 0.7 do
        local q = blocked(tx, ny + la, 0.15)
        if q then
          local side = (x < (q[1] + q[3]) / 2) and q[1] - 0.3 or q[3] + 0.3
          -- round it, if there is room beside it and the stipe is near that side; else it stops short under
          -- the text and lies over there, a little below it
          -- (it can only get as far sideways as it climbs: a little under three quarters of its rise)
          if side > 2.5 and side < W - 2.5 and abs(side - x) < la / dy * 0.15 then tx = side
          else
            local under = q[2] - 0.4 - (q[2] - y0) * 0.8 * srng.range(0, 1) ^ 0.9   -- anywhere below it, not a ceiling   -- anywhere from just under it to well below
            if under < stop then stop, capped = under, true end
          end
          break
        end
      end
      local nx = x + clamp(tx - x, -0.16, 0.16)
      if blocked(nx, ny, 0.05) or nx < -0.5 or nx > W + 0.5 then break end
      x, y = nx, ny
      pts[#pts + 1] = { x, y }
    end
    -- the canopy: lying over with the current, drifting down a little (under the surface, or under a text
    -- box it couldn't get round, which it treats the same)
    if #pts > 8 and capped then
      local L = srng.range(1.0, 3.0)
      local droop = srng.range(0.02, 0.07)
      for k = 1, floor(L / 0.2) do
        local t = min(1, k / 6)                          -- it turns over gradually, not at a corner
        local nx, ny = x + cur * 0.2 * t, y + 0.2 * (1 - t) + 0.04 * t - droop * t * k ^ 0.7
        if blocked(nx, ny, 0.1) then break end
        x, y = nx, ny
        pts[#pts + 1] = { x, y }
      end
    end
    return pts
  end
  -- a bunch on a rock: stipes, then their blades; far ones paler and smaller
  local function bunch(x, y, w, n, far, brng, layer)
    local t0 = far and 0.55 or brng.range(0.32, 0.42)
    local old = far and ink.set_lift(0.55) or nil
    ink.layer(layer or (far and L_FAR or L_KELP))
    local stipes = {}
    local hw = max(0.45, min(1.1, w * 0.45))           -- the holdfast's spread on the rock
    for k = 1, n do
      local u = n > 1 and (k - 1) / (n - 1) - 0.5 or 0      -- a bunch fans out from its holdfast as it rises
      local sx = x + u * min(0.3, w * 0.25) + brng.sym(0.05)
      local st = stipe(sx, y + hw * 0.42, brng.fork(), u * brng.range(0.08, 0.2))
      stipes[#stipes + 1] = st
      -- giant kelp forks near its foot: now and then a second stipe leaves this one, leaning the other way
      if #st > 12 and brng.chance(far and 0.2 or 0.45) then
        local j = brng.int(4, min(#st - 4, 14))
        local b = stipe(st[j][1], st[j][2], brng.fork(), (u >= 0 and -1 or 1) * brng.range(0.06, 0.14))
        if #b > 6 then
          local joined = {}
          for q = 1, j - 1 do joined[q] = st[q] end
          for q = 1, #b do joined[#joined + 1] = b[q] end
          stipes[#stipes + 1] = joined
        end
      end
    end
    -- the blades are planned first, so each stipe is drawn only a little past its last blade (a bare stipe
    -- running on round a text box would trace its outline)
    local plan = {}
    for si, pts in ipairs(stipes) do
      local side = brng.chance(0.5) and 1 or -1
      local i = brng.int(3, 5)
      local last = 1
      while i <= #pts do
        local p = pts[i]
        local canopy = p[2] > surface - 2.6 or (i > 3 and abs(pts[i][2] - pts[i - 1][2]) < 0.1)
        -- downstream, at the field's angle here, give or take its turbulence; the upstream side's blades
        -- swing round with the rest, a little higher
        local ang = (canopy and cur * 98 or FL.blade) + 16 * turb(p[1], p[2]) + eddy(p[1], p[2]) + brng.sym(7) + ((side > 0) == (cur > 0) and 0 or -cur * 18)
        local L = (canopy and brng.range(2.0, 3.4) or brng.range(1.5, 3.0)) * (far and 0.8 or 1)
        -- a blade that would reach into text swings up toward the stipe first (beside a text box, the
        -- current would push every blade into it)
        local ex, ey, mx, my
        for _, swing in ipairs({ 0, -35, -65 }) do
          local a2 = ang + cur * swing
          ex, ey = p[1] + L * sin(a2 * rad), p[2] + L * cos(a2 * rad)
          mx, my = lerp(p[1], ex, 0.5), lerp(p[2], ey, 0.5)
          if not blocked(ex, ey, 0.25) and not blocked(mx, my, 0.25) then ang = a2 break end
        end
        local c0, c1 = cell(p[1], p[2]), cell(mx, my)
        local cap = canopy and 2 or 1
        if not blocked(ex, ey, 0.25) and not blocked(mx, my, 0.25) and (crowd[c0] or 0) < cap and (crowd[c1] or 0) < cap then
          crowd[c0], crowd[c1] = (crowd[c0] or 0) + 1, (crowd[c1] or 0) + 1
          plan[#plan + 1] = { brng.fork(), p[1], p[2], ang, L, brng.range(0.16, 0.26) * (far and 0.8 or 1), t0 + brng.range(-0.06, 0.1) }
          last = i
        end
        side = -side
        -- sparse low on the stipe, crowded toward its top, where the canopy is
        local v = (p[2] - pts[1][2]) / max(0.5, pts[#pts][2] - pts[1][2])
        i = i + max(2, floor(lerp(8, 2, v) + brng.sym(1.2) + 0.5))
      end
      stipes[si] = { table.unpack(pts, 1, min(#pts, last + 3)) }
      -- the growing tip: a curved, scimitar-shaped blade at the end of the stipe, curling with the current
      local tp = stipes[si]
      if #tp >= 4 then
        local e, f = tp[#tp], tp[#tp - 2]
        local dir = math.atan(e[1] - f[1], e[2] - f[2]) / rad
        local ex, ey = e[1] + 1.4 * sin(dir * rad), e[2] + 1.4 * cos(dir * rad)
        if not blocked(ex, ey, 0.05) then
          plan[#plan + 1] = { brng.fork(), e[1], e[2], dir + cur * 15, brng.range(1.0, 1.6), brng.range(0.2, 0.3) * (far and 0.8 or 1), t0 + 0.04, 2.4 }
        end
      end
    end
    for _, pts in ipairs(stipes) do
      if #pts >= 3 then
        ink.smooth(ink.ribbon(pts, function(t) return lerp(0.08, 0.04, t) end), true) ink.fill(tone(t0 - 0.16))
      end
    end
    holdfast(brng, x, y, hw, t0 - 0.08)
    for _, b in ipairs(plan) do M.blade(b[1], b[2], b[3], b[4], b[5], b[6], cur * (b[8] or 1), b[7]) end
    if far then ink.set_lift(old) end
  end

  -- 0. light coming down from the surface: a few faint shafts, slanting with the sun, behind everything
  ink.layer(L_FAR)
  do
    local slant = rng.sym(0.25)
    for _ = 1, rng.int(3, 5) do
      local x = rng.range(-0.1 * W, W * 1.0)
      local w0, w1 = rng.range(0.4, 1.1), rng.range(1.2, 2.6)
      local yb = rng.range(H * 0.15, H * 0.45)
      local dx = slant * (H - yb)
      ink.poly({ { x - w0 / 2, H }, { x + w0 / 2, H }, { x + dx + w1 / 2, yb }, { x + dx - w1 / 2, yb } }, true)
      ink.fill(tone(0.82), rng.range(0.1, 0.18))
    end
  end
  -- 0b. fish far off in the blue, small and pale, behind the kelp (they don't need to keep clear of much)
  do
    local old = ink.set_lift(0.62)
    for _ = 1, rng.int(3, 6) do
      local L = rng.range(0.5, 0.9)
      local x, y = rng.range(1, W - 1), rng.range(H * 0.3, H * 0.9)
      if not blocked(x, y, 0.4) then
        ink.push() ink.translate(x, y) ink.scale(cur, 1) ink.rotate(rng.sym(8)) M.fish(rng.fork(), rng.pick({ "senorita", "rockfish", "bass" }), L) ink.pop()
      end
    end
    ink.set_lift(old)
  end
  -- a column: a tight bundle of two to four stipes leaning together on one slant downstream, thick with short
  -- blades all the way up, hanging out to both sides and drooping a little; isolated, with open water round it
  local function column(x, y, w, brng, lift_)
    local old = lift_ and ink.set_lift(lift_) or nil
    ink.layer(lift_ and L_FAR or L_KELP)
    local t0 = lift_ and 0.5 or brng.range(0.3, 0.4)
    local slant = math.tan(brng.range(6, 20) * rad) * cur
    local n = brng.int(2, 4)
    local hw = max(0.4, min(0.9, w * 0.35))
    local stipes = {}
    for k = 1, n do
      local u = n > 1 and (k - 1) / (n - 1) - 0.5 or 0
      stipes[k] = stipe(x + u * 0.14, y + hw * 0.42, brng.fork(), slant - FL.lean + u * 0.015)
    end
    local plan = {}
    for _, pts in ipairs(stipes) do
      local side = brng.chance(0.5) and 1 or -1
      local i = 3
      while i <= #pts do
        local p = pts[i]
        local q = pts[min(#pts, i + 1)]
        local axis = math.atan(q[1] - p[1], q[2] - p[2]) / rad
        -- out to its side, drooping: further down on the upstream side, the current pushes both a bit downstream
        local ang = axis + side * brng.range(55, 105) + cur * brng.range(5, 25) + 10 * turb(p[1], p[2])
        local v = (p[2] - pts[1][2]) / max(0.5, pts[#pts][2] - pts[1][2])
        -- the blades lengthen up the stipe, the top ones long and broad, as in the canopy
        local L = brng.range(0.6, 1.4) * lerp(0.75, 1.35, v * v) * (lift_ and 0.85 or 1)
        local Wb = brng.range(0.1, 0.16) * lerp(0.9, 1.3, v * v)
        local ex, ey = p[1] + L * sin(ang * rad), p[2] + L * cos(ang * rad)
        if not blocked(ex, ey, 0.25) and not blocked(lerp(p[1], ex, 0.5), lerp(p[2], ey, 0.5), 0.25) then
          plan[#plan + 1] = { brng.fork(), p[1], p[2], ang, L, Wb, t0 + brng.range(-0.06, 0.1) }
        end
        side = -side
        i = i + max(1, floor(lerp(5, 1, v) + brng.sym(0.8) + 0.5))   -- thin near the foot, thick near the top
      end
    end
    for _, pts in ipairs(stipes) do
      if #pts >= 3 then ink.smooth(ink.ribbon(pts, function(t) return lerp(0.07, 0.045, t) end), true) ink.fill(tone(t0 - 0.16)) end
    end
    holdfast(brng, x, y, hw, t0 - 0.08)
    for _, b in ipairs(plan) do M.blade(b[1], b[2], b[3], b[4], b[5], b[6], cur * 0.6, b[7]) end
    if lift_ then ink.set_lift(old) end
  end

  -- 1. the far bunches, between and behind the near rocks
  for _ = 1, floor(W / 4.5) + 1 do
    local x = rng.range(0, W)
    if not blocked(x, sandtop + 1) then bunch(x, sandtop + 0.2, 0.6, rng.int(1, 3), true, rng.fork()) end
  end
  -- 1b. a middle row of kelp, nearer than the far one, behind the near rocks: fuller and less regular
  for _ = 1, floor(W / 4.5) + 1 do
    local x = rng.range(0.5, W - 0.5)
    if not blocked(x, sandtop + 1.5) then
      local old = ink.set_lift(0.28)
      if rng.chance(0.5) then column(x, sandtop + 0.1, 1.0, rng.fork(), 0.3)
      else bunch(x, sandtop + 0.1, rng.range(0.7, 1.4), rng.int(1, 3), false, rng.fork(), L_FAR) end
      ink.set_lift(old)
    end
  end
  -- 2. the floor and the rocks
  ink.layer(L_FLOOR)
  sand(rng.fork(), W, sandtop)
  for _, r in ipairs(rocks) do
    r.top = rock(rng.fork(), r.x, r.base or (sandtop - 0.12), r.w, r.kind, rng.range(0.16, 0.24))
    reg(r.x - r.w / 2, r.base or 0, r.x + r.w / 2, r.top, "rock")
  end
  -- 3. the near bunches: most big rocks carry one, from a couple of stipes to nine; now and then a bull kelp
  for _, r in ipairs(rocks) do
    if r.w > 1.2 and rng.chance(0.85) then
      local brng = rng.fork()
      local clear = true
      for yy = r.top, H, 0.5 do if blocked(r.x, yy, 0.8) then clear = false break end end
      if clear and rng.chance(0.2) then
        -- bull kelp: one long whip to a float, a fountain of blades streaming from it
        ink.layer(L_KELP)
        local pts = stipe(r.x, r.top - 0.05, brng.fork())
        if #pts > 10 then
          local fpt = pts[#pts]
          ink.smooth(ink.ribbon(pts, function(t) return lerp(0.1, 0.065, t) end), true) ink.fill(tone(0.2))   -- a bull kelp's whip, hollow and thick
          for _ = 1, brng.int(6, 10) do M.blade(brng, fpt[1], fpt[2], cur * brng.range(40, 110), brng.range(1.6, 2.8), 0.09, cur * 1.3, brng.range(0.3, 0.42)) end
          ink.circle(fpt[1], fpt[2], 0.2) ink.fill(tone(0.16))
          if fine() then ink.circle(fpt[1] - 0.06, fpt[2] + 0.06, 0.06) ink.fill(white, 0.5) end
          holdfast(brng, r.x, r.top - 0.05, 0.4, 0.22)
        end
      else
        if brng.chance(0.6) then column(r.x + brng.sym(r.w * 0.15), r.top - 0.08, r.w, brng)
        else bunch(r.x + brng.sym(r.w * 0.15), r.top - 0.08, r.w, clamp(floor(r.w * brng.range(1.0, 2.2)), 2, 6), false, brng) end
      end
      r.kelp = true
    end
  end
  -- 4. the understory: in the gaps between the rocks, on the sand
  ink.layer(L_UNDER)
  local function weed(kind, x, y, h)
    ink.push() ink.translate(x, y)
    local wr = rng.fork()
    if kind == "palm" then M.seapalm(wr, h, cur) elseif kind == "red" then M.redweed(wr, h, rng.range(0.25, 0.4))
    elseif kind == "eel" then M.eelgrass(wr, h, cur) elseif kind == "oar" then M.oarweed(wr, h, cur)
    elseif kind == "boa" then M.boa(wr, h, cur) elseif kind == "sarg" then M.sargassum(wr, h, cur)
    elseif kind == "wrack" then M.wrack(wr, h) elseif kind == "beads" then M.beads(wr, h)
    elseif kind == "sugar" then M.sugarkelp(wr, h, cur) elseif kind == "thong" then M.thongweed(wr, h, cur)
    elseif kind == "dulse" then M.dulse(wr, h) elseif kind == "lettuce" then M.lettuce(wr, h)
    elseif kind == "padina" then M.padina(wr, h) elseif kind == "hali" then M.halimeda(wr, h) else M.grapes(wr, h) end
    ink.pop()
  end
  for _ = 1, floor(W * 2.4) do
    local x = rng.range(0.3, W - 0.3)
    local kind = rng.pick(WEEDS)
    local h = rng.range(1.3, 2.8) * (TALL[kind] or 1)
    if free(x - h * 0.3, sandtop - 0.2, x + h * 0.3, sandtop + h * 0.8) then
      weed(kind, x, sandtop - 0.1, h)
      reg(x - h * 0.3, sandtop - 0.2, x + h * 0.3, sandtop + h * 0.6, "weed")
    end
  end
  -- the taller weeds among the kelp: feather boas, sugar kelp, thongweed, sargassum, oarweed, each a
  -- different shape at the scale of the stipes, so the forest is more than one plant
  ink.layer(L_KELP)
  local TALLW = { "boa", "sugar", "thong", "sarg", "oar", "sugar", "boa", "wrack", "dulse" }
  for _ = 1, floor(W * rng.range(0.3, 0.5)) do
    local x = rng.range(0.6, W - 0.6)
    local kind = rng.pick(TALLW)
    local h = rng.range(2.2, 4.2) * (TALL[kind] or 1)
    if not blocked(x, sandtop + h * 0.5, 0.4) and not blocked(x + cur * h * 0.3, sandtop + h, 0.4) and sandtop + h < H - 1 then
      weed(kind, x, sandtop - 0.1, h)
    end
  end
  ink.layer(L_UNDER)
  -- and on the rocks' shoulders, in front of the kelp's holdfasts: a weed or two on most stones
  for _, r in ipairs(rocks) do
    if r.top then
      for _ = 1, rng.int(0, 2) do
        local u = rng.sym(0.8)
        local x = r.x + u * r.w * 0.45
        local y = r.top - 0.12 - (r.top - (r.base or sandtop)) * 0.35 * u * u
        local kind = rng.pick(WEEDS)
        local h = rng.range(1.0, 2.2) * (TALL[kind] or 1)
        if not blocked(x, y + h * 0.5, 0.3) and not blocked(x, y + h, 0.3) and y + h < H - 0.5 then weed(kind, x, y, h) end
      end
    end
  end

  -- 5. what lives there
  ink.layer(L_LIFE)
  local function place(w, h, ylo, yhi, tries, fn)
    for _ = 1, tries do
      local x, y = rng.range(w / 2 + 0.2, W - w / 2 - 0.2), rng.range(ylo, yhi)
      if free(x - w / 2, y - h / 2, x + w / 2, y + h / 2) then
        reg(x - w / 2, y - h / 2, x + w / 2, y + h / 2, "life")
        fn(x, y)
        return true
      end
    end
    return false
  end
  -- on the rocks: sea stars, urchins, an anemone, a crab
  for _, r in ipairs(rocks) do
    local x, y = r.x + rng.sym(r.w * 0.3), r.top - 0.05
    local what = rng.pick({ "star", "urchin", "anemone", "crab", "none", "star", "urchin" })
    if what ~= "none" and not blocked(x, y + 0.6) then
      ink.push() ink.translate(x, y)
      if what == "star" then ink.translate(0, -0.1) M.star(rng.fork(), rng.range(0.5, 0.75), rng.range(0.25, 0.45))
      elseif what == "urchin" then M.urchin(rng.fork(), rng.range(0.4, 0.6))
      elseif what == "anemone" then M.anemone(rng.fork(), rng.range(0.8, 1.2))
      else M.crab(rng.fork(), rng.range(0.7, 1.0)) end
      ink.pop()
    end
  end
  -- on the sand: a whelk, a sea star, a crab
  for _ = 1, 2 do
    local what = rng.pick({ "whelk", "star", "crab" })
    place(1.3, 0.7, sandtop * 0.45, sandtop * 0.7, 20, function(x, y)
      ink.push() ink.translate(x, y)
      if what == "whelk" then ink.scale(cur, 1) M.whelk(rng.fork(), rng.range(0.9, 1.2))
      elseif what == "star" then M.star(rng.fork(), rng.range(0.45, 0.65), 0.35)
      else M.crab(rng.fork(), rng.range(0.7, 0.9)) end
      ink.pop()
    end)
  end
  -- a skate's egg case caught in a holdfast
  for _, r in ipairs(rocks) do
    if r.kelp and rng.chance(0.3) then
      ink.push() ink.translate(r.x + rng.sym(0.3), r.top + 0.1) ink.rotate(rng.sym(25)) M.eggcase(rng.fork(), rng.range(0.8, 1.0)) ink.pop()
      break
    end
  end
  -- in open water: a school of small fish, a few big ones, jellyfish, a shrimp
  local mid_lo, mid_hi = sandtop + 2.0, surface - 2.0
  if mid_hi > mid_lo then
    local sx, sy = rng.range(W * 0.2, W * 0.8), rng.range(mid_lo, mid_hi)
    for _ = 1, rng.int(7, 13) do                       -- the school: senoritas swimming with the current
      local L = rng.range(0.7, 0.95)
      local x, y = sx + rng.sym(2.2), sy + rng.sym(1.0)
      if free(x - L / 2, y - 0.1, x + L / 2, y + 0.1) then
        reg(x - L / 2, y - 0.12, x + L / 2, y + 0.12, "fish")
        ink.push() ink.translate(x, y) ink.scale(cur, 1) ink.rotate(rng.sym(6)) M.fish(rng.fork(), "senorita", L) ink.pop()
      end
    end
    for _, kind in ipairs({ "garibaldi", "rockfish", "bass", rng.pick({ "garibaldi", "rockfish", "bass" }) }) do
      local L = ({ garibaldi = 1.9, rockfish = 2.4, bass = 2.6 })[kind] * rng.range(0.85, 1.1)
      place(L * 1.2, L * 0.6, mid_lo, mid_hi, 30, function(x, y)
        local face = rng.chance(0.7) and cur or -cur
        ink.push() ink.translate(x, y) ink.scale(face, 1) ink.rotate(rng.sym(8))
        if kind == "garibaldi" then ink.in_accent(function() M.fish(rng.fork(), kind, L) end) else M.fish(rng.fork(), kind, L) end
        ink.pop()
      end)
    end
    for _ = 1, rng.int(1, 3) do
      local s = rng.range(1.0, 1.6)
      place(s * 1.1, s * 1.2, mid_lo + 1, mid_hi + 1, 25, function(x, y) ink.push() ink.translate(x, y + s * 0.2) M.jelly(rng.fork(), s, cur) ink.pop() end)
    end
    place(1.0, 0.5, sandtop + 0.6, mid_lo + 1.5, 25, function(x, y) ink.push() ink.translate(x, y) ink.scale(rng.chance(0.5) and 1 or -1, 1) M.shrimp(rng.fork(), rng.range(0.8, 1.1)) ink.pop() end)
  end
  -- otters at the surface, on their backs in the canopy
  ink.layer(L_TOP)
  for _ = 1, o.otters or 1 do
    -- an otter floats at the surface itself, its back just under it, so it may break the top of the page a
    -- little; it only needs the water to be clear of text and of other otters
    local L = rng.range(4.0, 5.0)
    for _ = 1, 60 do
      -- its waterline (y) low enough that the head, paws and flippers above it stay on the page
      local x, y = rng.range(L * 0.55, W - L * 0.55), H - L * rng.range(0.3, 0.36)
      local a, b, c, d = x - L * 0.55, y - L * 0.1, x + L * 0.55, y + L * 0.3
      local ok = true
      for _, q in ipairs(keeps) do if a < q[3] and c > q[1] and b < q[4] and d > q[2] then ok = false end end
      for _, q in ipairs(boxes) do if q[5] == "otter" and a < q[3] and c > q[1] then ok = false end end
      if ok then
        reg(a, b, c, d, "otter")
        ink.push() ink.translate(x, y) ink.scale(rng.chance(0.5) and 1 or -1, 1)
        M.otter(rng.fork(), L, { pose = rng.pick({ "clam", "clam", "asleep", "pup", "groom" }), age = rng.range(0, 0.8) })
        ink.pop()
        bubbles(rng, x + rng.sym(L * 0.3), y - L * 0.15, 0.05, 3)
        break
      end
    end
  end
  -- by-the-wind sailors drifting at the surface
  for _ = 1, rng.int(1, 3) do
    local sz = rng.range(0.7, 1.0)
    for _ = 1, 30 do
      local x, y = rng.range(0.6, W - 0.6), H - sz * rng.range(0.7, 0.8)
      local a, b, c, d = x - sz * 0.55, y - sz * 0.35, x + sz * 0.55, y + sz * 0.65
      local ok = true
      for _, q in ipairs(keeps) do if a < q[3] and c > q[1] and b < q[4] and d > q[2] then ok = false end end
      for _, q in ipairs(boxes) do if (q[5] == "otter" or q[5] == "sailor") and a < q[3] and c > q[1] and b < q[4] and d > q[2] then ok = false end end
      if ok then
        reg(a, b, c, d, "sailor")
        ink.push() ink.translate(x, y) ink.scale(rng.chance(0.5) and 1 or -1, 1) M.sailor(rng.fork(), sz) ink.pop()
        break
      end
    end
  end
  -- now and then an otter diving through the open water, head down, a trail of bubbles from its nose
  if (o.otters or 1) > 0 and rng.chance(0.4) then
    local L = rng.range(3.4, 4.2)
    place(L * 0.95, L * 0.55, sandtop + 3, surface - 3, 40, function(x, y)
      local face = rng.chance(0.5) and 1 or -1
      ink.push() ink.translate(x - face * L * 0.1, y + L * 0.12) ink.scale(face, 1) M.otter(rng.fork(), L, { pose = "dive", water = false, age = rng.range(0, 0.6) }) ink.pop()
      bubbles(rng, x - face * L * 0.25, y + L * 0.3, 0.05, 5)
    end)
  end
  -- bubbles rising from the rocks
  for _ = 1, rng.int(2, 5) do
    local r = rocks[rng.int(1, max(1, #rocks))]
    if r then
      local x, y = r.x + rng.sym(r.w * 0.3), (r.top or sandtop) + 0.3
      local n = rng.int(4, 8)
      if free(x - 0.2, y, x + 0.2, y + n * 0.25) then bubbles(rng, x, y, rng.range(0.04, 0.08), n) end
    end
  end
end

return M

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
  ink.smooth(ellipse(x, y, W * 0.45, W * 0.7, 10, a), true) ink.fill(tone(t0 - 0.1))
  if fine() then ink.circle(x - W * 0.12, y + W * 0.15, W * 0.15) ink.fill(white, 0.5) end
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

-- a sea otter on its back at the surface, head toward +x, a clam held on its chest in its forepaws, hind
-- feet up; L = length nose to tail tip
function M.otter(rng, L)
  local fur, dark, pale = tone(0.22), tone(0.12), tone(0.72)
  -- tail, flat and tapering
  fill({ { -L * 0.3, -L * 0.02 }, { -L * 0.48, L * 0.03 }, { -L * 0.55, L * 0.0 }, { -L * 0.48, -L * 0.06 }, { -L * 0.3, -L * 0.08 } }, dark)
  -- the body, lying on its back
  local body = {}
  for k = 0, 22 do
    local a = 2 * pi * k / 22
    local x, y = L * 0.33 * cos(a), L * 0.085 * sin(a)
    if y > 0 then y = y * 1.2 end
    body[#body + 1] = { x - L * 0.02, y }
  end
  fill(body, fur)
  -- hind feet, webbed, up out of the water
  for _, dx in ipairs({ -0.24, -0.17 }) do
    local fx = L * dx
    fill({ { fx, L * 0.06 }, { fx - L * 0.05, L * 0.16 }, { fx - L * 0.02, L * 0.2 }, { fx + L * 0.02, L * 0.19 }, { fx + L * 0.04, L * 0.16 }, { fx + L * 0.02, L * 0.06 } }, dark)
    if fine() then for k = -1, 1 do ink.moveto(fx, L * 0.1) ink.lineto(fx + k * L * 0.025, L * 0.185) end ink.stroke(tone(0.3), 0.25) end
  end
  if fine() then
    fill(ellipse(L * 0.05, L * 0.045, L * 0.24, L * 0.045, 16), tone(0.32), 0.9)   -- the lighter chest
    for _ = 1, 30 do                                   -- fur
      local x, y = rng.range(-L * 0.3, L * 0.28), rng.range(-L * 0.06, L * 0.08)
      ink.moveto(x, y) ink.lineto(x - L * 0.02, y + rng.sym(L * 0.01))
    end
    ink.stroke(tone(0.14), 0.25, 0.6)
  end
  -- the head, lifted toward +x: round, a pale whiskered face, small ears
  local hx, hy = L * 0.36, L * 0.07
  fill(ellipse(hx, hy, L * 0.09, L * 0.085, 16), fur)
  fill(ellipse(hx + L * 0.035, hy - L * 0.01, L * 0.065, L * 0.06, 14), pale)
  fill(ellipse(hx - L * 0.05, hy + L * 0.07, L * 0.02, L * 0.018, 8), dark)       -- ear
  ink.circle(hx + L * 0.02, hy + L * 0.025, L * 0.011) ink.circle(hx + L * 0.06, hy + L * 0.03, L * 0.011) ink.fill(tone(0.04))
  fill(ellipse(hx + L * 0.085, hy - L * 0.002, L * 0.016, L * 0.012, 8), tone(0.04))  -- nose
  if fine() then
    ink.moveto(hx + L * 0.08, hy - L * 0.025) ink.curveto(hx + L * 0.07, hy - L * 0.04, hx + L * 0.05, hy - L * 0.04, hx + L * 0.045, hy - L * 0.03)
    ink.stroke(tone(0.1), 0.3)
    for k = -1, 1 do
      ink.moveto(hx + L * 0.08, hy - L * 0.012) ink.lineto(hx + L * 0.15, hy - L * 0.012 + k * L * 0.018)
      ink.moveto(hx + L * 0.05, hy - L * 0.015) ink.lineto(hx - L * 0.0, hy - L * 0.035 + k * L * 0.012)
    end
    ink.stroke(tone(0.3), 0.2, 0.8)
  end
  -- the clam on its chest, the forepaws round it
  ink.in_accent(function()
    local cx, cy = L * 0.17, L * 0.12
    local sh = {}
    for k = 0, 12 do local a = pi * k / 12 sh[#sh + 1] = { cx + L * 0.045 * cos(a), cy + L * 0.035 * sin(a) } end
    fill(sh, tone(0.45))
    if fine() then for k = 1, 5 do local a = pi * k / 6 ink.moveto(cx, cy) ink.lineto(cx + L * 0.042 * cos(a), cy + L * 0.033 * sin(a)) end ink.stroke(tone(0.25), 0.25) end
  end)
  fill(ellipse(L * 0.12, L * 0.11, L * 0.022, L * 0.03, 10, 0.4), dark)
  fill(ellipse(L * 0.22, L * 0.11, L * 0.022, L * 0.03, 10, -0.4), dark)
end

-- a crab from above, facing +y; s = carapace width
function M.crab(rng, s)
  local c = tone(0.3)
  for _, sd in ipairs({ -1, 1 }) do
    for k = 1, 4 do                                    -- walking legs, jointed
      local y0 = s * lerp(0.12, -0.22, (k - 1) / 3)
      local a = lerp(30, -40, (k - 1) / 3) * rad
      local kx, ky = sd * (s * 0.45 + s * 0.35 * cos(a)), y0 + s * 0.35 * sin(a)
      local ex, ey = kx + sd * s * 0.12, ky - s * 0.3
      ink.moveto(sd * s * 0.35, y0) ink.lineto(kx, ky) ink.lineto(ex, ey)
    end
    ink.stroke(tone(0.24), max(0.4, s * 2.2))
    -- the claw on its arm
    local ax, ay = sd * s * 0.55, s * 0.4
    ink.moveto(sd * s * 0.3, s * 0.2) ink.lineto(ax, ay) ink.stroke(tone(0.24), max(0.5, s * 3))
    fill({ { ax - s * 0.1, ay - s * 0.05 }, { ax - sd * s * 0.02, ay + s * 0.32 }, { ax + s * 0.1, ay + s * 0.2 }, { ax + s * 0.08, ay - s * 0.06 } }, tone(0.26))
    ink.moveto(ax, ay + s * 0.12) ink.lineto(ax + sd * s * 0.1, ay + s * 0.3) ink.stroke(tone(0.26), max(0.4, s * 2))
  end
  local shell = {}
  for k = 0, 20 do
    local a = 2 * pi * k / 20
    local r = 1 + 0.08 * cos(2 * a) - (sin(a) > 0.7 and 0.05 or 0)
    shell[#shell + 1] = { s * 0.42 * r * cos(a), s * 0.34 * r * sin(a) - s * 0.02 }
  end
  fill(shell, c)
  if fine() then
    fill(ellipse(-s * 0.08, s * 0.08, s * 0.22, s * 0.14, 12), tone(0.48), 0.6)
    ink.moveto(-s * 0.18, 0) ink.curveto(-s * 0.05, -s * 0.08, s * 0.05, -s * 0.08, s * 0.18, 0) ink.stroke(tone(0.18), 0.35, 0.8)
    for _, sd in ipairs({ -1, 1 }) do
      ink.moveto(sd * s * 0.07, s * 0.28) ink.lineto(sd * s * 0.1, s * 0.4) ink.stroke(tone(0.18), 0.45)
      ink.circle(sd * s * 0.1, s * 0.41, s * 0.03) ink.fill(tone(0.04))
    end
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

-- a whelk shell on the sand, side on, spire up and to the left; s = length
function M.whelk(rng, s)
  fill(ellipse(0, 0, s * 0.32, s * 0.22, 16, 0.5), tone(0.55))
  for k = 1, 4 do                                      -- the spire's whorls, each smaller
    local f = 0.75 ^ k
    local w = ellipse(-s * 0.2 * (1 - f) * 1.6, s * 0.18 * (1 - f) * 1.6, s * 0.3 * f, s * 0.2 * f, 14, 0.5)
    fill(w, tone(0.55 - 0.04 * k))
    if fine() then ink.smooth(w, true) ink.stroke(tone(0.3), 0.3, 0.7) end
  end
  fill(ellipse(s * 0.1, -s * 0.05, s * 0.12, s * 0.08, 12, 0.5), tone(0.82))   -- the aperture
  fill({ { s * 0.22, -s * 0.12 }, { s * 0.38, -s * 0.2 }, { s * 0.3, -s * 0.08 } }, tone(0.5))   -- the siphon canal
  if fine() then for k = 1, 5 do local a = 0.5 + k * 0.4 ink.moveto(s * 0.05 * cos(a), s * 0.05 * sin(a)) ink.lineto(s * 0.3 * cos(a), s * 0.2 * sin(a)) end ink.stroke(tone(0.4), 0.3, 0.6) end
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

-- a shrimp, side on, facing +x; s = length
function M.shrimp(rng, s)
  local seg = {}
  for k = 0, 6 do                                      -- the abdomen arching back from the carapace
    local t = k / 6
    local a = lerp(0.2, -2.3, t)
    seg[#seg + 1] = { -s * 0.18 + s * 0.28 * cos(a) - s * 0.28, s * 0.25 * sin(a) + s * 0.05 }
  end
  fill({ { s * 0.1, s * 0.12 }, { s * 0.42, s * 0.05 }, { s * 0.1, -s * 0.06 }, { -s * 0.2, -s * 0.02 }, { -s * 0.2, s * 0.14 } }, tone(0.5))
  for k = 1, #seg do ink.circle(seg[k][1], seg[k][2], s * lerp(0.1, 0.05, (k - 1) / 6)) ink.fill(tone(lerp(0.52, 0.45, (k - 1) / 6))) end
  local e = seg[#seg]
  fill({ { e[1], e[2] }, { e[1] + s * 0.14, e[2] - s * 0.1 }, { e[1] - s * 0.05, e[2] - s * 0.14 } }, tone(0.42))
  if fine() then
    for k = 1, 5 do local x = lerp(s * 0.05, -s * 0.35, k / 5) ink.moveto(x, -s * 0.02) ink.lineto(x + s * 0.05, -s * 0.16) end
    ink.stroke(tone(0.3), 0.3)
    ink.moveto(s * 0.4, s * 0.08) ink.curveto(s * 0.7, s * 0.25, s * 0.85, s * 0.1, s * 1.0, -s * 0.05)
    ink.moveto(s * 0.38, s * 0.1) ink.curveto(s * 0.55, s * 0.35, s * 0.7, s * 0.4, s * 0.85, s * 0.35)
    ink.stroke(tone(0.35), 0.25)
    ink.circle(s * 0.3, s * 0.1, s * 0.03) ink.fill(tone(0.04))
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

-- ---------------------------------------------------------------- the forest
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
      if not blocked(cx, sandtop + 0.5) then rocks[#rocks + 1] = { x = cx, w = w, kind = kind } end
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
    local stop = surface - srng.range(0.4, 2.5)
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
          if side > 2.5 and side < W - 2.5 and abs(side - x) < 1.6 then tx = side
          else stop = min(stop, q[2] - srng.range(0.6, 3.0)) end
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
    if #pts > 8 then
      local L = srng.range(1.0, 3.0)
      local droop = srng.range(0.02, 0.07)
      for k = 1, floor(L / 0.2) do
        local nx, ny = x + cur * 0.2, y + 0.04 - droop * k ^ 0.7
        if blocked(nx, ny, 0.1) then break end
        x, y = nx, ny
        pts[#pts + 1] = { x, y }
      end
    end
    return pts
  end
  -- a bunch on a rock: stipes, then their blades; far ones paler and smaller
  local function bunch(x, y, w, n, far, brng)
    local t0 = far and 0.55 or brng.range(0.32, 0.42)
    local old = far and ink.set_lift(0.45) or nil
    ink.layer(far and L_FAR or L_KELP)
    local stipes = {}
    local hw = max(0.45, min(1.1, w * 0.45))           -- the holdfast's spread on the rock
    for k = 1, n do
      local u = n > 1 and (k - 1) / (n - 1) - 0.5 or 0      -- a bunch fans out from its holdfast as it rises
      local sx = x + u * min(0.3, w * 0.25) + brng.sym(0.05)
      stipes[#stipes + 1] = stipe(sx, y + hw * 0.42, brng.fork(), u * brng.range(0.08, 0.2))
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
        local ang = (canopy and cur * 98 or FL.blade) + 16 * turb(p[1], p[2]) + brng.sym(7) + ((side > 0) == (cur > 0) and 0 or -cur * 18)
        local L = (canopy and brng.range(2.0, 3.4) or brng.range(1.5, 3.0)) * (far and 0.8 or 1)
        local ex, ey = p[1] + L * sin(ang * rad), p[2] + L * cos(ang * rad)
        local mx, my = lerp(p[1], ex, 0.5), lerp(p[2], ey, 0.5)
        local c0, c1 = cell(p[1], p[2]), cell(mx, my)
        local cap = canopy and 3 or 2
        if not blocked(ex, ey, 0.05) and not blocked(mx, my, 0.05) and (crowd[c0] or 0) < cap and (crowd[c1] or 0) < cap then
          crowd[c0], crowd[c1] = (crowd[c0] or 0) + 1, (crowd[c1] or 0) + 1
          plan[#plan + 1] = { brng.fork(), p[1], p[2], ang, L, brng.range(0.16, 0.26) * (far and 0.8 or 1), t0 + brng.range(-0.06, 0.1) }
          last = i
        end
        side = -side
        i = i + brng.int(4, 7)
      end
      stipes[si] = { table.unpack(pts, 1, min(#pts, last + 3)) }
    end
    for _, pts in ipairs(stipes) do
      if #pts >= 3 then
        ink.smooth(ink.ribbon(pts, function(t) return lerp(0.08, 0.04, t) end), true) ink.fill(tone(t0 - 0.16))
      end
    end
    holdfast(brng, x, y, hw, t0 - 0.08)
    for _, b in ipairs(plan) do M.blade(b[1], b[2], b[3], b[4], b[5], b[6], cur, b[7]) end
    if far then ink.set_lift(old) end
  end

  -- 1. the far bunches, between and behind the near rocks
  for _ = 1, floor(W / 3.2) + 1 do
    local x = rng.range(0, W)
    if not blocked(x, sandtop + 1) then bunch(x, sandtop + 0.2, 0.6, rng.int(1, 3), true, rng.fork()) end
  end
  -- 2. the floor and the rocks
  ink.layer(L_FLOOR)
  sand(rng.fork(), W, sandtop)
  for _, r in ipairs(rocks) do
    r.top = rock(rng.fork(), r.x, sandtop - 0.12, r.w, r.kind, rng.range(0.16, 0.24))
    reg(r.x - r.w / 2, 0, r.x + r.w / 2, r.top, "rock")
  end
  -- 3. the near bunches: most big rocks carry one, from a couple of stipes to nine; now and then a bull kelp
  for _, r in ipairs(rocks) do
    if r.w > 1.2 and rng.chance(0.85) then
      local brng = rng.fork()
      local clear = true
      for yy = r.top, H, 0.5 do if blocked(r.x, yy, 0.8) then clear = false break end end
      if clear and rng.chance(0.3) then
        -- bull kelp: one long whip to a float, a fountain of blades streaming from it
        ink.layer(L_KELP)
        local pts = stipe(r.x, r.top - 0.05, brng.fork())
        if #pts > 10 then
          local fpt = pts[#pts]
          ink.smooth(ink.ribbon(pts, function(t) return lerp(0.06, 0.03, t) end), true) ink.fill(tone(0.2))
          for _ = 1, brng.int(6, 10) do M.blade(brng, fpt[1], fpt[2], cur * brng.range(40, 110), brng.range(1.6, 2.8), 0.09, cur * 1.3, brng.range(0.3, 0.42)) end
          ink.circle(fpt[1], fpt[2], 0.2) ink.fill(tone(0.16))
          if fine() then ink.circle(fpt[1] - 0.06, fpt[2] + 0.06, 0.06) ink.fill(white, 0.5) end
          holdfast(brng, r.x, r.top - 0.05, 0.4, 0.22)
        end
      else
        bunch(r.x + brng.sym(r.w * 0.15), r.top - 0.08, r.w, clamp(floor(r.w * brng.range(1.0, 2.2)), 2, 6), false, brng)
      end
      r.kelp = true
    end
  end
  -- 4. the understory: in the gaps between the rocks, on the sand
  ink.layer(L_UNDER)
  for _ = 1, floor(W * 0.9) do
    local x = rng.range(0.3, W - 0.3)
    local h = rng.range(0.6, 1.4)
    if free(x - h * 0.35, sandtop - 0.2, x + h * 0.35, sandtop + h) then
      ink.push() ink.translate(x, sandtop - 0.1)
      local kind = rng.pick({ "palm", "red", "eel", "red", "eel" })
      if kind == "palm" then M.seapalm(rng.fork(), h, cur) elseif kind == "red" then M.redweed(rng.fork(), h, rng.range(0.25, 0.4)) else M.eelgrass(rng.fork(), h, cur) end
      ink.pop()
      reg(x - h * 0.3, sandtop - 0.2, x + h * 0.3, sandtop + h * 0.6, "weed")
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
    local L = rng.range(4.0, 5.0)
    place(L * 1.1, L * 0.45, surface - 0.8, surface + 0.2, 60, function(x, y)
      ink.push() ink.translate(x, y - L * 0.05) ink.scale(rng.chance(0.5) and 1 or -1, 1) M.otter(rng.fork(), L) ink.pop()
      bubbles(rng, x + rng.sym(L * 0.3), y + L * 0.2, 0.05, 3)
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

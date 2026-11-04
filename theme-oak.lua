-- theme-oak.lua -- a theme for florilegium: one huge old oak, verdant, with things in it.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- Work in progress: the primitives only (tools/trees/specimen.lua). Character over botany:
-- a limb is a tube along a spine, its bark furrows flowing along it and around knots;
-- foliage is built in masses, not leaf by leaf, with real leaves at the edges. Depth comes
-- from painting order: pale masses, limbs, dark masses, then cats and birds, then bright
-- masses over them, so whatever sits in the third layer is partly hidden.

local ink = require("ink")
local flora = require("flora")
local M = {}

local sin, cos, sqrt, pi, abs, floor, max, min = math.sin, math.cos, math.sqrt, math.pi, math.abs, math.floor, math.max, math.min
local exp = math.exp
local tone, white = ink.tone, ink.white
local mottle, streak3 = flora.mottle, flora.streak3
local rad = pi / 180
local function lerp(a, b, t) return a + (b - a) * t end

-- ---------------------------------------------------------------- the tube
-- A tube: spine = control points {x, y}, width(v) the full width at v in 0..1. Returns a
-- function P(u, v) -> x, y, with u in -1..1 across the tube, foreshortened like a cylinder
-- (furrows crowd toward the edges), plus the outline.
local function tube(rng, spine, width, rough, torn)
  local pts = ink.catmull(spine, 10)
  local s, total = ink.arclen(pts)
  local nrm = ink.normals(pts)
  local n = #pts
  local wob = ink.fbm1(rng, 3)
  local function at(v)
    local d = v * total
    local i = 1
    while i < n - 1 and s[i + 1] < d do i = i + 1 end
    local f = (s[i + 1] > s[i]) and (d - s[i]) / (s[i + 1] - s[i]) or 0
    return lerp(pts[i][1], pts[i + 1][1], f), lerp(pts[i][2], pts[i + 1][2], f),
      lerp(nrm[i][1], nrm[i + 1][1], f), lerp(nrm[i][2], nrm[i + 1][2], f)
  end
  local function P(u, v)
    local x, y, nx, ny = at(max(0, min(1, v)))
    local h = width(v) / 2
    local a = sin(u * pi / 2)
    return x + nx * h * a, y + ny * h * a
  end
  local outline, back = {}, {}
  local steps = max(14, floor(total / 0.14))
  for k = 0, steps do
    local v = k / steps
    local x, y, nx, ny = at(v)
    local h = width(v) / 2
    local e1 = rough * h * (wob(v * total * 0.9) + 0.45 * wob(v * total * 2.3))
    local e2 = rough * h * (wob(v * total * 0.9 + 40) + 0.45 * wob(v * total * 2.3 + 70))
    outline[#outline + 1] = { x + nx * (h + e1), y + ny * (h + e1) }
    back[#back + 1] = { x - nx * (h + e2), y - ny * (h + e2) }
  end
  for i = #back, 1, -1 do outline[#outline + 1] = back[i] end
  if torn then                                         -- teeth a plate long, not a straight cut
    local k = torn.teeth
    for t_ = 1, k - 1 do
      local u = -1 + 2 * t_ / k
      local x, y = P(u, (t_ % 2 == 1 and rng.range(0.7, 1) or rng.range(0, 0.25)) * min(0.45, torn.len / total))
      outline[#outline + 1] = { x, y }
    end
  end
  return P, outline, total
end

-- ---------------------------------------------------------------- plates
-- Bark is plates split apart by growth: a Voronoi net of jittered seeds, stretched along the
-- limb, each cell shrunk to leave a dark groove and its edges broken. In a grid where one unit
-- is a plate's width across and its length along.
local function clip_half(poly, ax, ay, bx, by)         -- keep the side of the bisector nearer (ax, ay)
  local mx, my, nx, ny = (ax + bx) / 2, (ay + by) / 2, bx - ax, by - ay
  local out = {}
  local n = #poly
  for i = 1, n do
    local p, q = poly[i], poly[i % n + 1]
    local dp = (p[1] - mx) * nx + (p[2] - my) * ny
    local dq = (q[1] - mx) * nx + (q[2] - my) * ny
    if dp <= 0 then out[#out + 1] = p end
    if (dp < 0 and dq > 0) or (dp > 0 and dq < 0) then
      local t = dp / (dp - dq)
      out[#out + 1] = { p[1] + (q[1] - p[1]) * t, p[2] + (q[2] - p[2]) * t }
    end
  end
  return out
end
-- the Voronoi cell of each seed, within a box around it (seeds: {x, y}); cheap with a coarse grid
local function cells(seeds, reach)
  local buckets = {}
  local function key(x, y) return floor(x / reach) * 100000 + floor(y / reach) end
  for i, s in ipairs(seeds) do
    local k = key(s[1], s[2])
    buckets[k] = buckets[k] or {}
    table.insert(buckets[k], i)
  end
  local out = {}
  for i, s in ipairs(seeds) do
    local x, y = s[1], s[2]
    local poly = { { x - reach, y - reach }, { x + reach, y - reach }, { x + reach, y + reach }, { x - reach, y + reach } }
    for gx = -1, 1 do for gy = -1, 1 do
      local b = buckets[key(x + gx * reach, y + gy * reach)]
      if b then
        for _, j in ipairs(b) do
          if j ~= i and #poly > 2 then poly = clip_half(poly, x, y, seeds[j][1], seeds[j][2]) end
        end
      end
    end end
    if #poly > 2 then out[#out + 1] = { poly = poly, seed = s } end
  end
  return out
end
-- a plate: shrunk toward its middle for the groove, its edges broken; returns grid points
local function plate_outline(rng, poly, shrink, plain)
  local cx, cy = 0, 0
  for _, p in ipairs(poly) do cx, cy = cx + p[1], cy + p[2] end
  cx, cy = cx / #poly, cy / #poly
  local out = {}
  local n = #poly
  for i = 1, n do
    local p, q = poly[i], poly[i % n + 1]
    local px, py = cx + (p[1] - cx) * shrink, cy + (p[2] - cy) * shrink
    local qx, qy = cx + (q[1] - cx) * shrink, cy + (q[2] - cy) * shrink
    out[#out + 1] = { px, py }
    local dx, dy = qx - px, qy - py
    local len = sqrt(dx * dx + dy * dy)
    if len > 0.2 and not plain then
      local parts = len > 0.8 and 4 or len > 0.45 and 3 or 2
      for k = 1, parts - 1 do
        local t = k / parts + rng.sym(0.1)
        local j = rng.sym(0.055)
        out[#out + 1] = { px + dx * t - dy / len * j, py + dy * t + dx / len * j }
      end
    end
  end
  return out, cx, cy
end
-- paint one plate from its page outline: the dark body, a lit face moved toward the light, ticks
local function paint_plate(rng, pts, t, big, maxdim, flat)
  local cx, cy, x0, x1, y0, y1 = 0, 0, math.huge, -math.huge, math.huge, -math.huge
  for _, p in ipairs(pts) do
    cx, cy = cx + p[1], cy + p[2]
    x0, x1, y0, y1 = min(x0, p[1]), max(x1, p[1]), min(y0, p[2]), max(y1, p[2])
  end
  cx, cy = cx / #pts, cy / #pts
  if maxdim and max(x1 - x0, y1 - y0) > maxdim then return end   -- squashed against the end of the tube
  if flat then                                         -- far away: still lit on one side, in fewer shapes
    ink.poly(pts, true) ink.fill(tone(min(0.95, t)))
    if t > 0.14 then
      ink.moveto(x0 + (x1 - x0) * 0.2, y1 - (y1 - y0) * 0.15) ink.lineto(x0 + (x1 - x0) * 0.2, y0 + (y1 - y0) * 0.15)
      ink.stroke(white, max(0.25, min(x1 - x0, y1 - y0) * 0.15 * ink.unit() * ink.CM), 0.3)
    end
    return
  end
  ink.poly(pts, true) ink.fill(tone(max(0.03, t - 0.13)))
  local ox, oy = -(x1 - x0) * 0.09, (y1 - y0) * 0.05
  local face = {}
  for i, p in ipairs(pts) do face[i] = { cx + (p[1] - cx) * 0.74 + ox, cy + (p[2] - cy) * 0.8 + oy } end
  ink.poly(face, true) ink.fill(tone(min(0.95, t + 0.03)))
  if big then
    -- a lifted edge on the lit side, cracks and ticks down the plate
    local tall = (y1 - y0) >= (x1 - x0)
    if t > 0.14 then
      if tall then streak3(x0 + (x1 - x0) * 0.16, y1 - (y1 - y0) * 0.2, x0 + (x1 - x0) * 0.1, cy + (y1 - y0) * 0.1, x0 + (x1 - x0) * 0.13, cy - (y1 - y0) * 0.1, x0 + (x1 - x0) * 0.2, y0 + (y1 - y0) * 0.2, (x1 - x0) * 0.13, (x1 - x0) * 0.03, white, rng.range(0.2, 0.46))
      else streak3(x0 + (x1 - x0) * 0.2, y1 - (y1 - y0) * 0.16, cx - (x1 - x0) * 0.1, y1 - (y1 - y0) * 0.1, cx + (x1 - x0) * 0.1, y1 - (y1 - y0) * 0.12, x1 - (x1 - x0) * 0.2, y1 - (y1 - y0) * 0.2, (y1 - y0) * 0.13, (y1 - y0) * 0.03, white, rng.range(0.2, 0.46)) end
    end
    for _ = 1, rng.int(1, 3) do
      local x, y = rng.range(x0 + (x1 - x0) * 0.25, x1 - (x1 - x0) * 0.2), rng.range(y0 + (y1 - y0) * 0.25, y1 - (y1 - y0) * 0.25)
      local dx, dy
      if tall then dx, dy = rng.sym((x1 - x0) * 0.08), (y1 - y0) * rng.range(0.1, 0.24)
      else dx, dy = (x1 - x0) * rng.range(0.1, 0.24), rng.sym((y1 - y0) * 0.08) end
      ink.moveto(x - dx, y - dy) ink.curveto(x - dx * 0.3 + dy * 0.1, y - dy * 0.3, x + dx * 0.3 - dy * 0.1, y + dy * 0.3, x + dx, y + dy)
    end
    ink.stroke(tone(0.04), 0.4, 0.55, true)
  end
end

-- ---------------------------------------------------------------- limbs and bark
local LIGHT = { -0.52, 0.7, 0.49 }                     -- toward the light: upper left, and toward us
-- Bark on a tube. o: width(v); tone (how light its lit side is); plate (a plate's width, cm); knots
-- = { {u, v, r} } (r in plates: the net opens around them, plates crowding as they wrap); moss
-- (0..1, on the shaded side); collar (wrinkled rings where a limb leaves its parent).
function M.limb(rng, spine, width, o)
  o = o or {}
  local lit_t = o.tone or 0.5
  local wm = width(0.5)
  local pw = o.plate or max(0.1, min(0.24, wm * 0.075))
  local P, outline, total = tube(rng, spine, width, o.rough or 0.055,
    o.torn and { teeth = max(4, floor(width(0) / pw * 0.75)), len = pw * (o.stretch or 5.5) * 1.1 } or nil)
  local cols = max(4, floor(wm * 1.15 / pw + 0.5))     -- the foreshortening makes the middle ones broader
  local plen = pw * (o.stretch or 5.5)
  local rows = max(3, floor(total / plen + 0.5))
  local seeds = {}
  -- ridges of many lengths: a run along a column is one long ridge, its neighbors offset, so
  -- that fissures split and rejoin down the trunk instead of making a tidy net
  local wander = ink.fbm1(rng, 2)
  for c = -1, cols + 1 do
    local r = rng.range(-2, 0)
    while r < rows + 2 do
      local x = c + 0.42 * wander(r * 0.3 + c * 7.3) + rng.sym(0.22)
      seeds[#seeds + 1] = { x, r }
      r = r + (rng.chance(0.2) and rng.range(1.5, 2.1) or rng.range(0.55, 1.1))
    end
  end
  -- grid -> page: a knot opens the net (d' = sqrt(d^2 + r^2)), so plates crowd around it
  local knots = {}
  for _, kn in ipairs(o.knots or {}) do
    knots[#knots + 1] = { (kn[1] + 1) / 2 * cols, kn[2] * rows, kn[3] }
  end
  local function warp(x, y)
    for _, k in ipairs(knots) do
      local dx, dy = x - k[1], y - k[2]
      local d = sqrt(dx * dx + dy * dy) + 1e-6
      local nd = sqrt(d * d + k[3] * k[3])
      x, y = k[1] + dx / d * nd, k[2] + dy / d * nd
    end
    return x, y
  end
  -- burls: swellings in the bark, not things on it. Extra small plates crowd there, and the
  -- light falls on them as on a ball
  local burls = {}
  for _, b in ipairs(o.burls or {}) do
    local bx, by, bR = (b[1] + 1) / 2 * cols, b[2] * rows, b[3]
    burls[#burls + 1] = { bx, by, bR }
    for _ = 1, floor(bR * bR * 5) do
      local a_, d_ = rng.range(0, 2 * pi), bR * sqrt(rng.u())
      seeds[#seeds + 1] = { bx + d_ * cos(a_), by + d_ * sin(a_) * 0.8 }
    end
  end
  local function G(x, y, nowarp)
    if not nowarp then x, y = warp(x, y) end
    return P(max(-1.08, min(1.08, x / cols * 2 - 1)), y / rows)
  end
  ink.smooth(outline, true, 0.8) ink.fill(tone(0.03))
  ink.smooth(outline, true, 0.8) ink.clip()
    local big = pw * ink.unit() > (o.detail or 0.16)
    for _, cl in ipairs(cells(seeds, 2.8)) do
      local g, gx = plate_outline(rng, cl.poly, rng.range(0.72, 0.86), o.flat)
      local wx = warp(gx, cl.seed[2])
      local u = wx / cols * 2 - 1
      if u > -1.3 and u < 1.3 then
        local pts = {}
        for i, q in ipairs(g) do local x, y = G(q[1], q[2]) pts[i] = { x, y } end
        -- the plate's surface on a cylinder, in real directions, lit from the upper left and front
        local vv = cl.seed[2] / rows
        local ax_, ay_ = P(1, vv)
        local bx_, by_ = P(-1, vv)
        local dx_, dy_ = ax_ - bx_, ay_ - by_
        local dl = sqrt(dx_ * dx_ + dy_ * dy_) + 1e-9
        local sn, cs = sin(max(-1, min(1, u)) * pi / 2), cos(max(-1, min(1, u)) * pi / 2)
        local l = (dx_ / dl * sn * LIGHT[1] + dy_ / dl * sn * LIGHT[2] + cs * LIGHT[3])
        for _, b in ipairs(burls) do
          local ddx, ddy = (gx - b[1]) / b[3], (cl.seed[2] - b[2]) / (b[3] * 0.8)
          local f = ddx * ddx + ddy * ddy
          if f < 1 then
            local ex_, ey_ = G(gx + 0.5, cl.seed[2])
            local fx_, fy_ = G(gx, cl.seed[2])
            local gx_, gy_ = G(gx, cl.seed[2] + 0.5)
            local a1, a2 = ex_ - fx_, ey_ - fy_
            local c1, c2 = gx_ - fx_, gy_ - fy_
            local la, lc = sqrt(a1 * a1 + a2 * a2) + 1e-9, sqrt(c1 * c1 + c2 * c2) + 1e-9
            local wx_, wy_ = ddx * a1 / la + ddy * c1 / lc, ddx * a2 / la + ddy * c2 / lc
            l = l * (1 - f * 0.3) + (wx_ * LIGHT[1] + wy_ * LIGHT[2]) * 0.85 * (1 - (1 - sqrt(f)) ^ 2) * (1 - f * f)
          end
        end
        l = max(0, min(1, l))
        paint_plate(rng, pts, max(0.05, (lit_t * l + 0.05) * rng.range(0.78, 1.14)), big, max(pw, plen) * 3.2, o.flat)
      end
    end
    for _, b in ipairs(burls) do
      local out = {}
      for i = 0, 11 do
        local a = pi * 1.1 + pi * 1.25 * i / 11
        local x, y = G(b[1] + b[3] * 1.05 * cos(a), b[2] + b[3] * 0.88 * sin(a))
        out[#out + 1] = { x, y }
      end
      ink.smooth(out, false) ink.stroke(tone(0.02), 1.6 + 0.6 * b[3], 0.55, true)
    end
    -- knots: an old wound healed over, a dark eye with rolled lips
    for _, k in ipairs(knots) do
      local function ring(f, wob_)
        local a0, out = rng.range(0, 6), {}
        for i = 0, 13 do
          local a = 2 * pi * i / 14
          local rr = k[3] * f * (1 + wob_ * (0.6 * sin(3 * a + a0) + 0.4 * sin(5 * a + a0 * 2)))
          local x, y = G(k[1] + rr * cos(a), k[2] + rr * sin(a), true)
          out[#out + 1] = { x, y }
        end
        return out
      end
      ink.smooth(ring(1.05, 0.07), true) ink.fill(tone(0.04))
      ink.smooth(ring(0.98, 0.08), true) ink.fill(tone(max(0.14, lit_t * 0.55)))
      ink.smooth(ring(0.82, 0.08), true) ink.fill(tone(0.08))
      ink.smooth(ring(0.68, 0.07), true) ink.fill(tone(max(0.2, lit_t * 0.7)))
      ink.smooth(ring(0.5, 0.1), true) ink.fill(tone(0.03))
      local rim = ring(0.92, 0.03)
      ink.smooth({ rim[6], rim[7], rim[8], rim[9], rim[10] }, false) ink.stroke(white, 0.6, 0.5)
    end
    -- the round of it, in soft steps, so the plates sit on a cylinder
    local shaded = 1                                   -- which side of the tube the shade falls on
    do
      local ax_, ay_ = P(1, 0.5)
      local bx_, by_ = P(-1, 0.5)
      if (ax_ - bx_) * LIGHT[1] + (ay_ - by_) * LIGHT[2] > 0 then shaded = -1 end
    end
    for s = 0, 5 do
      local u0 = (0.2 + 0.16 * s) * shaded
      local poly = {}
      for j = 0, 12 do local x, y = P(u0, j / 12) poly[#poly + 1] = { x, y } end
      for j = 12, 0, -1 do local x, y = P(1.3 * shaded, j / 12) poly[#poly + 1] = { x, y } end
      ink.poly(poly, true) ink.fill(tone(0.03), 0.1, true)
    end
    for j = 0, 1 do
      local poly = {}
      for i = 0, 12 do local x, y = P(j == 0 and -1.3 or 1.3, i / 12) poly[#poly + 1] = { x, y } end
      for i = 12, 0, -1 do local x, y = P(j == 0 and -0.86 or 0.8, i / 12) poly[#poly + 1] = { x, y } end
      ink.poly(poly, true) ink.fill(tone(0.03), 0.28, true)
    end
    -- a collar where it leaves its parent: wrinkles round it, crowded together
    if o.collar then
      for k = 1, 5 do
        local v = (k - 0.5) * o.collar / 5 + rng.sym(0.004)
        local pts = {}
        for i = 0, 8 do local x, y = P(-1 + i / 4, v + 0.02 * o.collar * sin(i * 1.3 + k) + 0.05 * o.collar * (1 - (i / 4 - 1) ^ 2)) pts[#pts + 1] = { x, y } end
        ink.smooth(pts, false) ink.stroke(tone(0.03), 0.7, 0.6, true)
      end
    end
    -- moss up the shaded side: clusters of tiny specks
    if o.moss and o.moss > 0 then
      for _ = 1, floor(total * 4 * o.moss) do
        local cx, cy = P(rng.range(0.1, 0.95) * shaded, rng.u())
        local rr = rng.range(0.08, 0.22) * (0.6 + wm * 0.25)
        for _ = 1, 10 do
          local a_, d_ = rng.range(0, 2 * pi), rr * sqrt(rng.u())
          ink.circle(cx + d_ * cos(a_), cy + d_ * sin(a_) * 1.4, rng.range(0.012, 0.03))
        end
        ink.fill(tone(rng.range(0.58, 0.8)), rng.range(0.55, 0.85))
      end
    end
  ink.unclip()
  return P
end

-- A burl: a great round growth on the bark, centered on the origin, radius R. Tight small plates
-- wrap a ball, lit on the upper left, in shadow below and on the far side.
function M.burl(rng, R, o)
  o = o or {}
  local a0, a1, outline = rng.range(0, 6), rng.range(0, 6), {}
  for i = 0, 17 do
    local a = 2 * pi * i / 18
    local rr = R * (1 + 0.09 * sin(3 * a + a0) + 0.05 * sin(7 * a + a1) + rng.sym(0.018))
    outline[#outline + 1] = { rr * cos(a) * 1.08, rr * sin(a) * 0.94 }
  end
  -- the shadow it throws on the trunk
  local shadow = {}
  for i, p in ipairs(outline) do shadow[i] = { p[1] + R * 0.12, p[2] - R * 0.16 } end
  ink.smooth(shadow, true) ink.fill(tone(0.03), 0.55, true)
  ink.smooth(outline, true) ink.fill(tone(0.03))
  ink.smooth(outline, true) ink.clip()
    local n = o.plates or 8
    local seeds = {}
    for r = -1, n + 1 do for c = -1, n + 1 do
      seeds[#seeds + 1] = { c + (r % 2) * 0.5 + rng.sym(0.4), r + rng.sym(0.4) }
    end end
    local big = 2 * R / n * ink.unit() > 0.1
    for _, cl in ipairs(cells(seeds, 2)) do
      local g, gx, gy = plate_outline(rng, cl.poly, rng.range(0.74, 0.86))
      local cu, cv = gx / n * 2 - 1, gy / n * 2 - 1
      local d = sqrt(cu * cu + cv * cv)
      if d < 1.2 then
        -- on a ball: the grid bends over toward the rim
        local function map(x, y)
          local u, v = x / n * 2 - 1, y / n * 2 - 1
          local e = sqrt(u * u + v * v) + 1e-6
          local b = sin(min(e, 1.3) * pi / 2 * 0.77) / 0.94
          return u / e * b * R * 1.1, v / e * b * R
        end
        local pts = {}
        for i, q in ipairs(g) do local x, y = map(q[1], q[2]) pts[i] = { x, y } end
        local l = max(0, (-cu * 0.55 + cv * 0.65 + 0.62) / 1.5) * max(0, 1 - d * d * 0.55)
        paint_plate(rng, pts, max(0.06, (o.tone or 0.78) * l * rng.range(0.85, 1.15) + 0.07), big)
      end
    end
    ink.smooth(outline, true) ink.stroke(tone(0.02), 1.4, 0.55, true)
  ink.unclip()
end

-- ---------------------------------------------------------------- leaves
-- An oak leaf from the origin along +y, length L: rounded lobes along a stalked blade.
local LOBE = { { 0.1, 0.07 }, { 0.26, 0.24 }, { 0.38, 0.13 }, { 0.54, 0.32 }, { 0.67, 0.17 }, { 0.82, 0.25 }, { 1, 0.03 } }
local LOBE_SMALL = { { 0.2, 0.18 }, { 0.33, 0.24 }, { 0.44, 0.13 }, { 0.58, 0.26 }, { 0.72, 0.25 }, { 0.84, 0.12 }, { 0.97, 0.05 } }
local function leaf_outline(rng, L, small)
  local left, right = {}, {}
  for _, q in ipairs(small and LOBE_SMALL or LOBE) do
    local j = 1 + rng.sym(0.08)
    left[#left + 1] = { -q[2] * L * j, q[1] * L }
    right[#right + 1] = { q[2] * L * (1 + rng.sym(0.08)), q[1] * L }
  end
  local out = { { 0, 0 } }
  for _, p in ipairs(right) do out[#out + 1] = p end
  for i = #left - 1, 1, -1 do out[#out + 1] = left[i] end
  return out
end
function M.leaf(rng, L, o)
  o = o or {}
  local t0 = o.tone or rng.range(0.3, 0.45)
  local out = leaf_outline(rng, L, L * ink.unit() < 0.62)
  if L * ink.unit() < 0.62 then ink.poly(out, true) else ink.smooth(out, true, 1) end
  ink.fill(tone(t0), o.op)
  if L * ink.unit() > 0.42 then
    streak3(0, 0, 0, L * 0.3, rng.sym(L * 0.03), L * 0.6, rng.sym(L * 0.03), L * 0.93, L * 0.035, L * 0.008, o.rib or white, 0.55)
  end
end

-- an acorn, hanging from the origin: a cap in dark and a copper nut
function M.acorn(rng, s)
  local nut = { { -0.3, -0.25 }, { -0.32, -0.6 }, { -0.14, -0.92 }, { 0, -1.02 }, { 0.14, -0.92 }, { 0.32, -0.6 }, { 0.3, -0.25 } }
  for _, p in ipairs(nut) do p[1], p[2] = p[1] * s, p[2] * s end
  ink.smooth(nut, true) ink.fill(ink.accent(0.1))
  ink.moveto(-0.14 * s, -0.4 * s) ink.curveto(-0.16 * s, -0.6 * s, -0.1 * s, -0.75 * s, -0.04 * s, -0.85 * s) ink.stroke(white, 0.3, 0.6)
  ink.smooth({ { -0.36 * s, -0.3 * s }, { -0.3 * s, -0.06 * s }, { 0, 0 }, { 0.3 * s, -0.06 * s }, { 0.36 * s, -0.3 * s }, { 0, -0.36 * s } }, true)
  ink.fill(tone(0.15))
  ink.moveto(0, 0) ink.lineto(rng.sym(0.06) * s, 0.16 * s) ink.stroke(tone(0.1), 0.5)
end

-- ---------------------------------------------------------------- foliage
-- A mass of foliage around (0,0), radius R, built of billows, each a cluster of leaves lit from
-- above: no outline of its own, its edge is leaves. depth: "back" (pale and soft), "mid" (dark, the
-- shade inside the crown: only a few lit leaves) or "front" (bright, with a shadow under each
-- billow). o.n scales the number of leaves, o.leaf their length.
local DEPTH = {
  back = { core = 0.8, lo = 0.68, hi = 0.86, op = 0.85, n = 0.55, shade = 0, small = true },
  mid = { core = 0.09, lo = 0.08, hi = 0.28, op = 1, n = 1.05, shade = 0 },
  front = { core = 0.2, lo = 0.17, hi = 0.68, op = 1, n = 1.1, shade = 0.22 },
}
function M.clump(rng, R, depth, o)
  o = o or {}
  local D = DEPTH[depth or "front"]
  local L = o.leaf or 0.34
  -- the billows: a heap, wider than tall, the low ones last so they overlap the ones behind
  local nb = floor(3 + R * R * 5)
  local bs = {}
  for k = 1, nb do
    local a, d = rng.range(0, 2 * pi), R * sqrt(rng.u()) * 0.82
    bs[k] = { d * cos(a) * 1.12, d * sin(a) * 0.82, rng.range(0.28, 0.46) * max(R, 0.9) * (k == 1 and 1.2 or 1) }
  end
  table.sort(bs, function(p, q) return p[2] > q[2] end)
  for _, b in ipairs(bs) do
    local bx, by, r = b[1], b[2], b[3]
    -- the shade inside it, well inside the leaves, soft-edged
    if D.small then ink.smooth(ink.blob(rng, bx, by, r * 0.66, r * 0.58, 0.2, 9), true) ink.fill(tone(0.84), 0.8)
    else ink.smooth(ink.blob(rng, bx, by - r * 0.04, r * 0.62, r * 0.56, 0.2, 9), true) ink.fill(tone(D.core), D.op) end
    if D.shade > 0 then
      ink.smooth(ink.blob(rng, bx, by - r * 0.5, r * 0.6, r * 0.22, 0.2, 8), true) ink.fill(tone(0.03), D.shade, true)
    end
    -- leaves from the dark low side up to the lit top, each pointing out and drooping a little
    local count = floor((o.n or 1) * D.n * (8 + 4 * r * r / (L * L)))
    local ls = {}
    for k = 1, count do
      local a = rng.range(0, 2 * pi)
      local d = r * (rng.chance(0.55) and rng.range(0.72, 1.02) or sqrt(rng.u()) * 0.8)
      ls[k] = { bx + d * cos(a) * 1.08, by + d * sin(a), a, d / r }
    end
    table.sort(ls, function(p, q) return p[2] < q[2] end)
    for _, q in ipairs(ls) do
      local lit = (q[2] - by) / r                       -- -1 below .. +1 above
      local t = lerp(D.lo, D.hi, max(0, min(1, (lit + 0.75) / 1.6 + rng.sym(0.14))))
      local ang = q[3] / rad - 90 + rng.sym(32)
      if abs(ang % 360 - 180) < 70 then ang = ang + (rng.chance(0.5) and 40 or -40) end
      ink.push() ink.translate(q[1], q[2]) ink.rotate(ang)
      M.leaf(rng, L * rng.range(0.8, 1.2), { tone = t, op = D.op < 1 and D.op or nil })
      ink.pop()
    end
  end
end

local function ellipse_(cx, cy, rx, ry)
  local p = {}
  for k = 0, 9 do local a = 2 * pi * k / 10 p[#p + 1] = { cx + rx * cos(a), cy + ry * sin(a) } end
  return p
end

-- A spray of acorns: a twig hanging from the origin along -y (or out along o.dir), with leaves
-- and two or three acorns on short stalks.
function M.sprig(rng, s, o)
  o = o or {}
  local n = o.acorns or rng.int(2, 3)
  ink.smooth({ { 0, 0 }, { 0.12 * s, -0.5 * s }, { -0.05 * s, -1.05 * s }, { 0.08 * s, -1.6 * s } }, false)
  ink.stroke(tone(0.08), 0.9)
  for k = 1, 5 do
    local a = (k % 2 == 0 and 70 or -70) + 180 + rng.sym(25)
    ink.push() ink.translate(rng.sym(0.08) * s, -k * 0.3 * s) ink.rotate(a)
    M.leaf(rng, s * rng.range(0.7, 0.95), { tone = rng.range(0.28, 0.52) })
    ink.pop()
  end
  for k = 1, n do
    local dx = (k - (n + 1) / 2) * 0.32 * s
    local y = -1.6 * s
    ink.moveto(0.08 * s, y) ink.curveto(dx * 0.4, y - 0.05 * s, dx, y - 0.1 * s, dx, y - 0.24 * s)
    ink.stroke(tone(0.1), 0.6)
    ink.push() ink.translate(dx, y - 0.24 * s) M.acorn(rng, s * 0.42) ink.pop()
  end
end

-- A bird's nest sitting on the origin, width s: short twigs woven round a cup, following its curve,
-- with pale eggs, or a chick's open mouth, showing over the front rim.
function M.nest(rng, s, o)
  o = o or {}
  local w, h = s / 2, s * 0.44
  local cy = h * 0.72
  -- a twig along the bowl: an arc of the ellipse at fraction f of the way out from the middle
  local function twig(a0, a1, f)
    local dr = rng.sym(0.08)
    local function pt(a, e) return w * f * (1 + e) * cos(a), cy + cy * f * (1 + e) * sin(a) * 1.02 end
    local x0, y0 = pt(a0, dr + rng.sym(0.05))
    local x1, y1 = pt(lerp(a0, a1, 0.33), dr)
    local x2, y2 = pt(lerp(a0, a1, 0.66), dr)
    local x3, y3 = pt(a1, dr + rng.sym(0.05))
    ink.moveto(x0, y0) ink.curveto(x1, y1, x2, y2, x3, y3)
  end
  local function weave(n, lo, hi, f0, f1, c, wd, op)
    for _ = 1, n do
      local a = rng.range(lo, hi)
      twig(a, a + rng.range(0.35, 0.95) * (rng.chance(0.5) and 1 or -1), rng.range(f0, f1))
    end
    ink.stroke(c, wd, op)
  end
  -- the far rim, seen over the cup: flattened, behind what is in it
  local function far(n, c, wd)
    for _ = 1, n do
      local a = rng.range(0.1, pi - 0.1)
      local da = rng.range(0.3, 0.7)
      local dr = rng.range(0.85, 1.06)
      local x0, x3 = w * dr * cos(a), w * dr * cos(a + da)
      local y0, y3 = cy + h * 0.2 * sin(a) + rng.sym(0.02 * s), cy + h * 0.2 * sin(a + da) + rng.sym(0.02 * s)
      ink.moveto(x0, y0) ink.lineto(x3, y3)
    end
    ink.stroke(c, wd)
  end
  ink.smooth(ellipse_(0, cy, w * 0.98, h * 0.26), true) ink.fill(tone(0.05))
  far(22, tone(0.16), 0.6)
  far(14, tone(0.45), 0.4)
  if o.chick then
    for _, x in ipairs({ -0.13, 0.15 }) do
      local bx, by = x * s, cy
      ink.smooth({ { bx - s * 0.08, by }, { bx - s * 0.07, by + s * 0.14 }, { bx, by + s * 0.2 }, { bx + s * 0.07, by + s * 0.14 }, { bx + s * 0.08, by } }, true)
      ink.fill(tone(0.7))
      ink.poly({ { bx - s * 0.05, by + s * 0.17 }, { bx, by + s * 0.34 }, { bx + s * 0.05, by + s * 0.17 }, { bx, by + s * 0.11 } }, true)
      ink.fill(ink.accent(0.05))
      ink.circle(bx - s * 0.04, by + s * 0.12, s * 0.014) ink.fill(tone(0.03))
      ink.circle(bx + s * 0.04, by + s * 0.12, s * 0.014) ink.fill(tone(0.03))
    end
  else
    for _, x in ipairs({ -0.19, 0.01, 0.21 }) do
      local ex, ey = x * s + rng.sym(0.012) * s, cy + s * 0.03 + rng.sym(0.012) * s
      ink.smooth(ellipse_(ex, ey, s * 0.095, s * 0.115), true) ink.fill(tone(0.94))
      ink.smooth(ellipse_(ex + s * 0.03, ey - s * 0.03, s * 0.05, s * 0.06), true) ink.fill(tone(0.68), 0.5)
      for _ = 1, 6 do ink.circle(ex + rng.sym(s * 0.07), ey + rng.sym(s * 0.085), s * 0.006) end
      ink.fill(ink.accent(-0.05), 0.85)
    end
  end
  -- the near wall: a dark cup, then twigs round it, the top ones catching the light
  local cup = {}
  for k = 0, 16 do local a = pi + pi * k / 16 cup[#cup + 1] = { w * cos(a), cy + cy * sin(a) } end
  ink.smooth(cup, true) ink.fill(tone(0.05))
  weave(30, pi + 0.15, 2 * pi - 0.15, 0.35, 1.02, tone(0.06), 0.8)
  weave(26, pi + 0.1, 2 * pi - 0.1, 0.45, 1.04, tone(0.24), 0.6)
  weave(18, pi + 0.1, pi + 1.5, 0.75, 1.05, tone(0.5), 0.45)
  -- the rim, thick with twigs lying along it
  for _ = 1, 20 do
    local a = rng.range(pi - 0.1, 2 * pi + 0.1)
    local da = rng.range(0.3, 0.7)
    local e = rng.range(0.94, 1.08)
    ink.moveto(w * e * cos(a), cy + h * 0.1 * sin(a) + rng.sym(0.015 * s))
    ink.lineto(w * e * cos(a + da), cy + h * 0.1 * sin(a + da) + rng.sym(0.015 * s))
  end
  ink.stroke(tone(0.3), 0.6)
  for _ = 1, 10 do
    local a = rng.range(pi, 2 * pi)
    ink.moveto(w * cos(a), cy + h * 0.08 * sin(a)) ink.lineto(w * cos(a + 0.4), cy + h * 0.08 * sin(a + 0.4))
  end
  ink.stroke(white, 0.3, 0.6)
  -- a few stray ends
  for _ = 1, 7 do
    local a = rng.range(0, 2 * pi)
    local x, y = w * cos(a), cy + cy * sin(a)
    ink.moveto(x, y) ink.lineto(x + cos(a) * s * 0.11, y + sin(a) * s * 0.05)
  end
  ink.stroke(tone(0.14), 0.5)
end

-- ---------------------------------------------------------------- the skeleton
-- Space colonization (Runions, Lane & Prusinkiewicz, "Modeling Trees with a Space Colonization
-- Algorithm", 2007): attraction points fill the crown; each influences its nearest node within
-- di; each influenced node grows a step D along the mean direction to its points, plus a bias
-- (eq. 3); points within dk of a node die. In 3D, drawn from the front, so limbs cross. A small di
-- relative to D makes it gnarled, a wide envelope makes it spread, as an old oak does.
-- Returns nodes { x, y, z, parent, kids = {}, r }, with r from the pipe model (r^n = sum of r_i^n).
function M.skeleton(rng, o)
  local D, di, dk = o.D or 0.5, o.di or 4.2, o.dk or 1.0
  local pts = {}
  local keep = o.keepouts or {}
  local function allowed(x, y)
    local m = o.margin or 0
    for _, q in ipairs(keep) do if x > q[1] - m and x < q[3] + m and y > q[2] - m and y < q[4] + m then return false end end
    return true
  end
  local e = o.envelope                                 -- { cx, cy, rx, ry, rz }
  while #pts < (o.N or 900) do
    local x, y, z = rng.sym(1), rng.sym(1), rng.sym(1)
    -- denser near the surface of the crown; the underside flattened
    if x * x + y * y + z * z <= 1 and x * x + y * y + z * z > 0.04 + rng.u() * 0.32 then
      if y < 0 then y = y * (#keep > 0 and 0.95 or 0.62) end
      local px, py = e[1] + x * e[3], e[2] + y * e[4]
      if allowed(px, py) then pts[#pts + 1] = { px, py, z * e[5], near = nil, dist = di } end
    end
  end
  local nodes = {}
  local function add(x, y, z, parent)
    local n = { x = x, y = y, z = z, parent = parent, kids = {}, r = 0 }
    nodes[#nodes + 1] = n
    if parent then table.insert(parent.kids, n) end
    return n
  end
  -- the trunk: short, massive, leaning and bending once or twice
  local prev = add(o.base[1], o.base[2], 0, nil)
  local tilt, bend = rng.sym(0.22), rng.sym(0.4)
  local steps = floor((o.trunk or 6) / D)
  for k = 1, steps do
    local t = k / steps
    prev = add(prev.x + D * (tilt + bend * sin(t * 3.4)), prev.y + D, rng.sym(0.05), prev)
  end
  local function reach(list)
    for _, p in ipairs(pts) do
      if not p.dead then
        for _, n in ipairs(list) do
          local dx, dy, dz = p[1] - n.x, p[2] - n.y, p[3] - n.z
          local d2 = dx * dx + dy * dy + dz * dz
          if d2 < dk * dk then p.dead = true break end
          if d2 < p.dist * p.dist then p.dist, p.near = sqrt(d2), n end
        end
      end
    end
  end
  reach(nodes)
  -- the trunk climbs until the crown can reach it
  local function reached() for _, p in ipairs(pts) do if p.near and not p.dead then return true end end return false end
  for _ = 1, 200 do
    if reached() then break end
    if not allowed(prev.x, prev.y + D) then break end
    prev = add(prev.x + D * (e[1] - prev.x) / e[3] * 0.25 + D * rng.sym(0.2), prev.y + D, rng.sym(0.05), prev)
    reach({ prev })
  end
  local gx, gy = o.bias and o.bias[1] or 0, o.bias and o.bias[2] or -0.1
  for _ = 1, o.iters or 70 do
    local pull = {}
    local any = false
    for _, p in ipairs(pts) do
      if not p.dead and p.near then
        any = true
        local n = p.near
        local dx, dy, dz = p[1] - n.x, p[2] - n.y, p[3] - n.z
        local d = sqrt(dx * dx + dy * dy + dz * dz) + 1e-9
        local a = pull[n]
        if not a then a = { 0, 0, 0, n = n } pull[n] = a pull[#pull + 1] = a end
        a[1], a[2], a[3] = a[1] + dx / d, a[2] + dy / d, a[3] + dz / d
      end
    end
    if not any then break end
    local new = {}
    for _, a in ipairs(pull) do                        -- in insertion order, never pairs()
      local L = sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3]) + 1e-9
      local x, y, z = a[1] / L + gx + rng.sym(0.06), a[2] / L + gy + rng.sym(0.06), a[3] / L + rng.sym(0.06)
      local L2 = sqrt(x * x + y * y + z * z) + 1e-9
      local n = a.n
      -- a node with this direction already: stop a stuck tip growing on the spot
      local nx_, ny_ = n.x + D * x / L2, n.y + D * y / L2
      if #n.kids < 3 and allowed(nx_, ny_) then new[#new + 1] = add(nx_, ny_, n.z + D * z / L2, n) end
    end
    if #new == 0 then break end
    reach(new)
  end
  -- the pipe model, tips to base
  local en = o.pipe or 2.1
  for i = #nodes, 1, -1 do
    local n = nodes[i]
    if #n.kids == 0 then n.r = 1
    else
      local sum = 0
      for _, k in ipairs(n.kids) do sum = sum + k.r ^ en end
      n.r = sum ^ (1 / en)
    end
  end
  return nodes
end

-- The chains: from the root follow the thickest child; every other child starts a chain of its own,
-- which begins back inside its parent, so that it grows out of it. In parent-first order.
local function chains(nodes)
  local out = {}
  local function walk(start, parent_prev)
    local chain = { parent_prev = parent_prev, start = start }
    local n = start
    local list = { n }
    while #n.kids > 0 do
      table.sort(n.kids, function(p, q) return p.r > q.r end)
      for i = 2, #n.kids do chain[#chain + 1] = { n, n.kids[i] } end
      n = n.kids[1]
      list[#list + 1] = n
    end
    chain.list = list
    out[#out + 1] = chain
    for i = 1, #chain do walk(chain[i][2], chain[i][1]) end
  end
  walk(nodes[1], nil)
  return out
end

-- a root running out from the flare, sinking into the ground
local function O_root(M_, rng, x, y, sd, L, w)
  local spine = { { x, y + w * 0.5 }, { x + sd * L * 0.35, y + w * 0.1 }, { x + sd * L * 0.7, y - w * 0.15 }, { x + sd * L, y - w * 0.3 } }
  M_.limb(rng, spine, function(v) return w * (1 - 0.82 * v) end, { rough = 0.08, plate = 0.11, stretch = 3, moss = 0.3 })
end

-- ---------------------------------------------------------------- one huge oak
-- Painted back to front: pale crown, limbs, dark crown, then what lives in it, then bright crown.
-- o: w, h (cm), seed, cats, keepouts, nests. Layers: 1 back, 2 limbs, 3 mid, 4 life, 5 front, 6 ground.
function M.tree(rng, o)
  local W, H = o.w, o.h
  M.cat_ = require("theme-cattree").cat
  M.peek_ = require("theme-cattree").peek
  local layout = rng.fork()
  local groundy = o.ground or 1.0
  -- the trunk stands where the text boxes leave it most room
  local trunkw_ = o.trunkw or W * 0.2
  local basex = W * (0.46 + layout.sym(0.05))
  do
    local function room(x)
      local h = H
      for _, q in ipairs(o.keepouts or {}) do
        if x + trunkw_ * 0.75 > q[1] and x - trunkw_ * 0.75 < q[3] then h = min(h, q[2]) end
      end
      return h - abs(x - W * 0.46) * 0.25
    end
    local best = room(basex)
    if best < H * 0.5 then
      for k = 1, 12 do
        local x = W * (0.12 + 0.76 * (k - 1) / 11)
        local r_ = room(x)
        if r_ > best then best, basex = r_, x end
      end
    end
  end
  local nodes = M.skeleton(layout, {
    margin = trunkw_ * 0.12,
    envelope = { W * 0.5, H * 0.6, W * 0.6, H * 0.36, W * 0.3 },
    base = { basex, groundy }, trunk = (o.keepouts and #o.keepouts > 0) and H * 0.14 or H * 0.2, N = o.N or 700, D = 0.6, di = 5, dk = 1.3,
    keepouts = o.keepouts, iters = 80, pipe = 1.8,
  })
  local trunkw = trunkw_
  local rmax = nodes[1].r
  local function W_of(n)
    local w = trunkw * (n.r / rmax)
    -- the last few nodes of a branch run out to a point
    local up = n
    for k = 0, 2 do
      if #up.kids == 0 then return w * (0.35 + 0.22 * k) end
      up = up.kids[1]
    end
    return w
  end
  local chs = chains(nodes)
  local stats = { nodes = #nodes, chains = #chs }
  -- nothing below the ground, nothing in the text: every layer is clipped, keep-outs as holes
  local function holes()
    local pts = { { -2, groundy - 0.12 } }
    local nw = 40
    local gr = rng.fork()
    for i = 0, nw do pts[#pts + 1] = { W * i / nw, groundy - 0.12 + gr.sym(0.05) } end
    pts[#pts + 1] = { W + 2, groundy - 0.12 } pts[#pts + 1] = { W + 2, H + 2 } pts[#pts + 1] = { -2, H + 2 }
    ink.poly(pts, true)
    for _, q in ipairs(o.keepouts or {}) do
      ink.poly({ { q[1], q[2] }, { q[1], q[4] }, { q[3], q[4] }, { q[3], q[2] } }, true)
    end
  end
  for _, ly in ipairs({ 1, 2, 3, 4, 5 }) do
    ink.layer(ly) holes() ink.clip()
  end
  local forks = {}
  local perches = {}                                   -- thick, nearly level stretches: where a cat lies
  ink.layer(2)
  -- a stretch of limb; a chain whose width changes a lot is painted in stretches, so that plates
  -- keep their size up a tapering trunk
  local function stretch(sp, ws, isroot, joined, first)
    local dist = { 0 }
    for i = 2, #sp do dist[i] = dist[i - 1] + sqrt((sp[i][1] - sp[i - 1][1]) ^ 2 + (sp[i][2] - sp[i - 1][2]) ^ 2) end
    local total = dist[#dist]
    if total < 1e-3 then return end
    local function width(v)
      local d = v * total
      local i = 1
      while i < #sp - 1 and dist[i + 1] < d do i = i + 1 end
      local f = dist[i + 1] > dist[i] and (d - dist[i]) / (dist[i + 1] - dist[i]) or 0
      local w = lerp(ws[i], ws[i + 1], f)
      if isroot then w = w * (1 + 0.6 * exp(-d / 1.1)) + 0.5 * exp(-d / 0.5) end   -- the root flare
      return w
    end
    local wm = width(0.5)
    if wm >= 0.3 then
      local kn, bl = {}, {}
      if wm > 0.8 and layout.chance(0.7) then kn[1] = { layout.range(-0.5, 0.45), layout.range(0.2, 0.8), layout.range(0.55, 0.95) } end
      if isroot then bl[1] = { -0.42 + layout.sym(0.15), 0.42, 2.6 } kn = { { 0.42, 0.66, 1.05 } } end
      if wm > 1.3 and not isroot and layout.chance(0.5) then bl[1] = { layout.range(-0.5, 0.5), layout.range(0.3, 0.7), 1.7 } end
      M.limb(rng.fork(), sp, width, { knots = kn, burls = bl, moss = wm > 1.25 and 0.5 or 0.08, rough = 0.05,
        plate = max(0.14, min(0.21, wm * 0.15)), stretch = wm > 1 and 4.6 or 3, detail = wm > 1.8 and 0.16 or 9, flat = wm < 1.25, torn = not isroot })
      -- level enough to lie on?
      if wm > 0.42 and wm < 1.7 then
        for i = 1, #sp - 1 do
          local dx, dy = sp[i + 1][1] - sp[i][1], sp[i + 1][2] - sp[i][2]
          if abs(dx) > 1e-6 and abs(dy / dx) < 0.62 then
            perches[#perches + 1] = { x = (sp[i][1] + sp[i + 1][1]) / 2, y = (sp[i][2] + sp[i + 1][2]) / 2, w = lerp(ws[i], ws[i + 1], 0.5), a = math.atan(dy / dx) / rad }
          end
        end
      end
    elseif wm >= 0.07 then
      local _, outline = tube(rng.fork(), sp, width, 0.04)
      ink.poly(outline, true) ink.fill(tone(0.14))
    else
      ink.smooth(sp, false) ink.stroke(tone(0.12), max(0.3, wm * ink.CM * 0.8))
    end
  end
  for ci, ch in ipairs(chs) do
    local list = ch.list
    local sp, ws = {}, {}
    if ch.parent_prev then
      local pp = ch.parent_prev
      local back = pp.parent or pp
      local wp = W_of(pp)
      -- start back inside the parent, along its direction, as wide as the parent will take, so
      -- that the bark flows from one into the other
      sp[1] = { lerp(pp.x, back.x, 0.8), lerp(pp.y, back.y, 0.8) } ws[1] = min(wp * 0.8, W_of(list[1]) * 2.1)
      sp[2] = { pp.x, pp.y } ws[2] = min(wp * 0.82, W_of(list[1]) * 1.55)
      if W_of(list[1]) > 0.45 then forks[#forks + 1] = { x = pp.x, y = pp.y, w = W_of(list[1]), dx = list[1].x - pp.x, dy = list[1].y - pp.y } end
    end
    for i = 1, #list do
      if i % 2 == 1 or i == #list then
        local n = list[i]
        sp[#sp + 1] = { n.x, n.y }
        ws[#ws + 1] = W_of(n)
      end
    end
    if #sp >= 3 then
      -- split where the width has fallen far; each stretch shares a point with the next
      local a, first = 1, true
      while a < #sp do
        local b = a + 2
        while b < #sp and ws[b] > ws[a] * 0.62 do b = b + 1 end
        b = min(b, #sp)
        if #sp - b < 2 then b = #sp end
        local ss, ww = {}, {}
        for i = a, b do ss[#ss + 1] = sp[i] ww[#ww + 1] = ws[i] end
        if #ss >= 3 then stretch(ss, ww, ci == 1 and first, ch.parent_prev ~= nil, first)
        elseif #ss == 2 then ink.smooth(ss, false) ink.stroke(tone(0.12), max(0.3, ww[1] * ink.CM * 0.8)) end
        first = false
        a = b
      end
    end
  end
  -- what lives in it: chosen before the foliage, which then leaves them room, not too much
  ink.layer(4)
  local windows = {}
  local life = rng.fork()
  local function window(x, y, r) windows[#windows + 1] = { x, y, r } end
  local function far_from(x, y, d, list)
    for _, q in ipairs(list) do if (q.x - x) ^ 2 + (q.y - y) ^ 2 < d * d then return false end end
    return true
  end
  local taken = {}
  local crown_y = (o.groundy or groundy) + H * 0.28
  for i = #perches, 2, -1 do local j = layout.int(1, i) perches[i], perches[j] = perches[j], perches[i] end
  local ncat = o.cats or 2
  local POSES = { "loaf", "sit", "drape", "loaf" }
  for _, p_ in ipairs(perches) do
    if ncat <= 0 then break end
    local inbox = false
    for _, q in ipairs(o.keepouts or {}) do
      if p_.x + 2 > q[1] and p_.x - 2 < q[3] and p_.y + 3 > q[2] and p_.y - 1 < q[4] then inbox = true end
    end
    if not inbox and p_.y > crown_y and p_.x > 1.5 and p_.x < W - 1.5 and p_.y < H - 3 and far_from(p_.x, p_.y, 6, taken) then
      taken[#taken + 1] = p_
      ncat = ncat - 1
      local pose = POSES[(#taken - 1) % #POSES + 1]
      local c_ = cos(p_.a * rad)
      local yy = p_.y + p_.w * 0.5 * c_ - 0.1
      local f = layout.chance(0.5) and 1 or -1
      local rc = life.fork()
      local coat_ = ({ "ginger", "tux", "ginger", "tabby" })[(#taken - 1) % 4 + 1]
      ink.push() ink.translate(p_.x, yy) ink.scale(o.catscale or 1.25)
      if coat_ == "ginger" then ink.in_accent(function() M.cat_(rc, pose, f, p_.a * 0.75, { coat = "tabby", tone = 0.5 }) end)
      else M.cat_(rc, pose, f, p_.a * 0.75, { coat = coat_ }) end
      ink.pop()
      window(p_.x, yy + 1.0, pose == "sit" and 1.45 or 1.6)
    end
  end
  -- nests in the forks
  local nnest = o.nests or 2
  for i = #forks, 2, -1 do local j = layout.int(1, i) forks[i], forks[j] = forks[j], forks[i] end
  for _, fk in ipairs(forks) do
    if nnest <= 0 then break end
    local inbox = false
    for _, q in ipairs(o.keepouts or {}) do
      if fk.x + 1 > q[1] and fk.x - 1 < q[3] and fk.y + 1.6 > q[2] and fk.y - 0.5 < q[4] then inbox = true end
    end
    if not inbox and fk.y > crown_y and fk.x > 1.5 and fk.x < W - 1.5 and fk.y < H - 2.5 and far_from(fk.x, fk.y, 4.5, taken) then
      taken[#taken + 1] = fk
      nnest = nnest - 1
      local ns = life.range(1.25, 1.6)
      ink.push() ink.translate(fk.x, fk.y + fk.w * 0.25) M.nest(life.fork(), ns, { chick = nnest % 2 == 0 }) ink.pop()
      window(fk.x, fk.y + 0.7, 1.25)
    end
  end
  stats.life = #taken
  -- the foliage: masses around the tips, gathered on a coarse grid, by depth
  local tips = {}
  local cell = o.cell or 2
  local seen = {}
  for _, n in ipairs(nodes) do
    if #n.kids == 0 or W_of(n) < trunkw * 0.05 then
      local k = floor(n.x / cell) * 1000 + floor(n.y / cell)
      local b = seen[k]
      if not b then b = { x = 0, y = 0, z = 0, n = 0 } seen[k] = b tips[#tips + 1] = b end
      b.x, b.y, b.z, b.n = b.x + n.x, b.y + n.y, b.z + n.z, b.n + 1
    end
  end
  for _, b in ipairs(tips) do b.x, b.y, b.z = b.x / b.n, b.y / b.n, b.z / b.n end
  table.sort(tips, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.x < b.x end)
  local placed = { back = 0, mid = 0, front = 0 }
  local function blocked(x, y, R, depth)
    for _, q in ipairs(o.keepouts or {}) do
      if x + R > q[1] and x - R < q[3] and y + R > q[2] and y - R < q[4] then return true end
    end
    if depth ~= "back" then
      for _, q in ipairs(windows) do
        if (q[1] - x) ^ 2 + (q[2] - y) ^ 2 < (q[3] + R * 0.45) ^ 2 then return true end
      end
    end
    return false
  end
  local forky = nodes[1].y                             -- where the trunk first divides
  do
    local n = nodes[1]
    while n and #n.kids == 1 do n = n.kids[1] end
    if n then forky = n.y end
  end
  local tx0 = nodes[1].x
  local function clump_at(layer, depth, x, y, R, n)
    if depth ~= "back" and y - R * 0.7 < forky and abs(x - tx0) < trunkw * 0.7 + R then return end
    if blocked(x, y, R * 1.1, depth) then
      R = R * 0.62                                     -- a small mass still clothes a branch near a box
      if blocked(x, y, R * 1.1, depth) then return end
    end
    local old = ink.layer(layer)
    ink.push() ink.translate(x, y) M.clump(rng.fork(), R, depth, { n = n, leaf = o.leaf or 0.36 }) ink.pop()
    ink.layer(old)
    placed[depth] = placed[depth] + 1
  end
  for _, b in ipairs(tips) do
    clump_at(1, "back", b.x + layout.sym(1.2), b.y + layout.range(0.3, 1.6), layout.range(1.5, 2.2), 0.3)
    clump_at(3, "mid", b.x + layout.sym(0.7), b.y + layout.sym(0.5), layout.range(1.2, 1.75), 0.42)
    -- bright masses only part-way round, so limbs and what sits on them show between them
    if layout.chance(0.78) then
      clump_at(5, "front", b.x + layout.sym(0.6), b.y + layout.range(0, 0.7), layout.range(1, 1.5), 0.8)
    end
  end
  -- no bare ends: a branch tip with no mass near it gets a small one
  do
    local done_ = {}
    for _, n in ipairs(nodes) do
      if #n.kids == 0 and n.y > forky then
        local near = false
        for _, b in ipairs(tips) do if (b.x - n.x) ^ 2 + (b.y - n.y) ^ 2 < 0.6 and not b.blocked then near = true break end end
        for _, q in ipairs(done_) do if (q[1] - n.x) ^ 2 + (q[2] - n.y) ^ 2 < 0.8 then near = true break end end
        local clear = not blocked(n.x, n.y, 0.45)
        for _, q in ipairs(windows) do if (q[1] - n.x) ^ 2 + (q[2] - n.y) ^ 2 < (q[3] * 0.75) ^ 2 then clear = false end end
        if clear and not near then
          done_[#done_ + 1] = { n.x, n.y }
          local old = ink.layer(5)
          ink.push() ink.translate(n.x, n.y) M.clump(rng.fork(), 0.5, "front", { n = 0.8, leaf = o.leaf or 0.36 }) ink.pop()
          ink.layer(old)
        end
      end
    end
    stats.endtufts = #done_
  end
  stats.clumps = placed
  -- eyes in the dark of a mid mass, between the bright ones
  ink.layer(4)
  local neyes = o.eyes or 1
  for _, b in ipairs(tips) do
    if neyes <= 0 then break end
    if b.y > crown_y + 2 and b.y < H - 2 and b.x > 2 and b.x < W - 2 and b.z < 0.2 and far_from(b.x, b.y, 3.5, taken) and not blocked(b.x, b.y, 0.6) then
      taken[#taken + 1] = b
      ink.push() ink.translate(b.x, b.y - 0.1) ink.scale(1.2) M.peek_(life.fork(), { coat = "solid" }) ink.pop()
      neyes = neyes - 1
    end
  end
  -- acorn sprigs hanging from the underside of the crown, over everything
  ink.layer(5)
  local under = {}
  for _, b in ipairs(tips) do under[#under + 1] = b end
  table.sort(under, function(a, b) if a.y ~= b.y then return a.y < b.y end return a.x < b.x end)
  for i = 1, min(o.sprigs or 7, #under), 1 do
    local b = under[i * 2 - 1] or under[i]
    if b and not blocked(b.x, b.y - 1.1, 0.7) then
      ink.push() ink.translate(b.x + life.sym(0.4), b.y - 0.35) ink.rotate(life.sym(18)) M.sprig(life.fork(), life.range(0.42, 0.58)) ink.pop()
    end
  end
  -- the ground: roots going out from the flare, grass, fallen acorns, mushrooms
  ink.layer(2)
  local bx = nodes[1].x
  for _, sd in ipairs({ -1, 1, -1, 1 }) do
    local L_, w_ = layout.range(2.4, 4.6), layout.range(0.5, 0.95)
    local off = layout.range(0.5, trunkw * 0.5)
    O_root(M, rng.fork(), bx + sd * off, groundy + layout.range(0.05, 0.5), sd, L_, w_)
  end
  for _, ly in ipairs({ 1, 2, 3, 4, 5 }) do ink.layer(ly) ink.unclip() end
  ink.layer(6)
  local ground = rng.fork()
  -- a soft pool of shade under the crown
  for k = 1, 3 do
    local pool = {}
    for a_ = 0, 15 do
      local an = 2 * pi * a_ / 16
      pool[#pool + 1] = { bx + W * (0.2 + 0.09 * k) * cos(an) * (1 + ground.sym(0.05)), groundy - 0.08 + (0.32 - 0.06 * k) * sin(an) }
    end
    ink.smooth(pool, true) ink.fill(tone(0.62), 0.22, true)
  end
  for _ = 1, floor(W * 3.4) do
    local x = ground.range(0, W)
    if not blocked(x, groundy, 0.5) then
      for _ = 1, 3 do
        local h, lean = ground.range(0.14, 0.42), ground.sym(0.16)
        streak3(x, groundy - 0.12, x + lean * 0.2, groundy + h * 0.4, x + lean * 0.6, groundy + h * 0.75, x + lean, groundy + h, 0.05, 0.006, tone(ground.range(0.2, 0.62)))
        x = x + ground.sym(0.13)
      end
    end
  end
  for _ = 1, floor(W / 3) do
    local x = ground.range(0.6, W - 0.6)
    if abs(x - bx) > trunkw * 0.7 and not blocked(x, groundy, 0.5) then
      if ground.chance(0.5) then
        ink.push() ink.translate(x, groundy + 0.08) ink.rotate(ground.range(70, 110)) M.acorn(ground, 0.36) ink.pop()
      else
        local h, r_ = ground.range(0.32, 0.5), ground.range(0.16, 0.26)
        ink.smooth({ { x - r_ * 0.26, groundy }, { x - r_ * 0.2, groundy + h }, { x + r_ * 0.2, groundy + h }, { x + r_ * 0.26, groundy } }, true) ink.fill(tone(0.88))
        ink.smooth({ { x - r_, groundy + h }, { x - r_ * 0.7, groundy + h + r_ * 0.65 }, { x, groundy + h + r_ * 0.9 }, { x + r_ * 0.7, groundy + h + r_ * 0.65 }, { x + r_, groundy + h }, { x, groundy + h - r_ * 0.1 } }, true)
        ink.fill(ink.accent(0.05))
        ink.circle(x - r_ * 0.25, groundy + h + r_ * 0.45, r_ * 0.1) ink.fill(white, 0.9)
        ink.circle(x + r_ * 0.3, groundy + h + r_ * 0.3, r_ * 0.08) ink.fill(white, 0.9)
      end
    end
  end
  stats.forks = #forks
  return stats, forks, nodes, W_of
end

return M

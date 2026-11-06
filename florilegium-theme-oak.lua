-- florilegium-theme-oak.lua -- a theme for florilegium: one huge old oak, verdant, with things in it.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- Work in progress: the primitives only (tools/trees/specimen.lua). Character over botany:
-- a limb is a tube along a spine, its bark furrows flowing along it and around knots;
-- foliage is built in masses, not leaf by leaf, with real leaves at the edges. Depth comes
-- from painting order: pale masses, limbs, dark masses, then cats and birds, then bright
-- masses over them, so whatever sits in the third layer is partly hidden.

local ink = require("florilegium-ink")
local flora = require("florilegium-flora")
local M = {}
M.version = "2.0.0"

local sin, cos, sqrt, pi, abs, floor, max, min = math.sin, math.cos, math.sqrt, math.pi, math.abs, math.floor, math.max, math.min
local exp = math.exp
local tone, white = ink.tone, ink.white
local streak3 = flora.streak3
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
      -- along the plate's own length, on its lit side: on a slanted limb it slants too
      local pa, pb, far = pts[1], pts[1], -1
      for i = 1, #pts do for j = i + 1, #pts do
        local d = (pts[i][1] - pts[j][1]) ^ 2 + (pts[i][2] - pts[j][2]) ^ 2
        if d > far then far, pa, pb = d, pts[i], pts[j] end
      end end
      local ox, oy = -(y1 - y0) * 0.1 - (x1 - x0) * 0.1, (y1 - y0) * 0.08 + (x1 - x0) * 0.08
      ink.moveto(lerp(cx, pa[1], 0.42) + ox, lerp(cy, pa[2], 0.42) + oy) ink.lineto(lerp(cx, pb[1], 0.42) + ox, lerp(cy, pb[2], 0.42) + oy)
      ink.stroke(white, max(0.2, min(x1 - x0, y1 - y0) * 0.08 * ink.unit() * ink.CM), 0.2)
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
    -- v2: now and then a fine crack partway across the plate, breaking it into blocks
    for _ = 1, (rng.chance(0.45) and 1 or 0) + (rng.chance(0.12) and 1 or 0) do
      local f = rng.range(0.3, 0.7)
      local a_, b_ = rng.range(0.08, 0.4), rng.range(0.55, 0.92)
      local pts_ = {}
      for k = 0, 4 do
        local u = lerp(a_, b_, k / 4)
        if tall then pts_[#pts_ + 1] = { lerp(x0, x1, u), lerp(y0, y1, f) + rng.sym((y1 - y0) * 0.07) }
        else pts_[#pts_ + 1] = { lerp(x0, x1, f) + rng.sym((x1 - x0) * 0.07), lerp(y0, y1, u) } end
      end
      ink.smooth(pts_, false, 0.6) ink.stroke(tone(0.03), 0.25, 0.5, true)
    end
  end
end

-- ---------------------------------------------------------------- limbs and bark
local LIGHT = { -0.52, 0.7, 0.49 }                     -- toward the light: upper left, and toward us
-- Bark on a tube. o: width(v); tone (how light its lit side is); plate (a plate's width, cm); knots
-- = { {u, v, r} } (r in plates: the net opens around them, plates crowding as they wrap); moss
-- (0..1, on the shaded side); collar (wrinkled rings where a limb leaves its parent).
local SIL = false                                      -- every limb a solid silhouette (set true to check silhouettes)
local FLARE = true                                     -- the base of a limb eases into its parent
local ends = {}                                        -- v2: where the stretches painted so far end
function M.limb(rng, spine, width, o)
  o = o or {}
  -- v2: a fillet where a limb leaves its parent. A chain's first stretch starts back inside its parent,
  -- behind it; past the parent's edge its width eases down to its own over about its own width, so its
  -- outline runs into the parent's instead of meeting it at a corner. (A later stretch of the same chain
  -- starts where the last one ended, and is left alone.)
  do
    local sx, sy = spine[1][1], spine[1][2]
    local cont = false
    for _, e_ in ipairs(ends) do if (e_[1] - sx) ^ 2 + (e_[2] - sy) ^ 2 < (0.5 * e_[3] + 0.05) ^ 2 then cont = true break end end
    local acc, sl = 0, { 0 }
    for i = 2, #spine do acc = acc + sqrt((spine[i][1] - spine[i - 1][1]) ^ 2 + (spine[i][2] - spine[i - 1][2]) ^ 2) sl[i] = acc end
    ends[#ends + 1] = { spine[#spine][1], spine[#spine][2], width(1) }
    if FLARE and o.torn and not cont and #spine >= 3 and acc > 0 then
      local w0 = width(sl[2] / acc)                      -- as wide as it is at the parent's middle
      local de = sl[2] + 0.42 * w0                         -- where it comes out past the parent's edge
      local wc = width(min(1, sl[3] / acc))
      local base = width
      width = function(v)
        local d = v * acc
        local w = base(v)
        if d > sl[2] then w = w + max(0, w0 * 0.6 - w) * exp(-max(0, d - de) / (0.75 * wc)) end
        return w
      end
    end
  end
  local lit_t = o.tone or 0.5
  local wm = width(0.5)
  local pw = (o.plate or max(0.1, min(0.24, wm * 0.075))) * lerp(0.92, 1.35, max(0, min(1, ((o.pwm or wm) - 0.6) / 1.4)))   -- v2: plates grow smoothly with the limb
  local P, outline, total = tube(rng, spine, width, o.rough or 0.055,
    o.torn and { teeth = max(4, floor(width(0) / pw * 0.75)), len = pw * (o.stretch or 5.5) * 0.6 } or nil)
  if SIL then ink.smooth(outline, true, 0.8) ink.fill(tone(0.12)) return P end
  local cols = max(4, floor(wm * 1.15 / pw + 0.5))     -- the foreshortening makes the middle ones broader
  local plen = pw * (o.stretch or 5.5) * lerp(1, 0.74, max(0, min(1, ((o.pwm or wm) - 0.3) / 0.4)))   -- v2: and shorter: oak bark is blocks, broken across
  local rows = max(3, floor(total / plen + 0.5))
  local seeds = {}
  -- ridges of many lengths: a run along a column is one long ridge, its neighbors offset, so
  -- that fissures split and rejoin down the trunk instead of making a tidy net
  local wander = ink.fbm1(rng, 2)
  -- v2: a twisted limb's ridges run round it in a slow spiral (columns per row); straight on a trunk's foot
  local twist = o.twist or (wm > 0.35 and rng.sym(0.16) or 0)
  -- v2: the bends: where the limb turns, the bark on the inside of the turn is pushed together
  -- into small crowded plates and creases; on the outside it is stretched (plates as they were)
  local bends = {}
  do
    local sl, acc = { 0 }, 0
    for i = 2, #spine do acc = acc + sqrt((spine[i][1] - spine[i - 1][1]) ^ 2 + (spine[i][2] - spine[i - 1][2]) ^ 2) sl[i] = acc end
    for i = 2, #spine - 1 do
      local ax, ay = spine[i][1] - spine[i - 1][1], spine[i][2] - spine[i - 1][2]
      local bx, by = spine[i + 1][1] - spine[i][1], spine[i + 1][2] - spine[i][2]
      local la, lb = sqrt(ax * ax + ay * ay) + 1e-9, sqrt(bx * bx + by * by) + 1e-9
      local cr = (ax * by - ay * bx) / (la * lb)        -- sin of the turn, + to the left
      local ang = math.asin(max(-1, min(1, cr)))
      local reach_ = (la + lb) / 2                       -- over how much length it turns
      local kappa = abs(ang) / max(1e-6, reach_) * wm      -- turning per limb width
      if kappa > 0.22 and acc > 0 then bends[#bends + 1] = { sl[i] / acc, ang > 0 and 1 or -1, min(1, kappa) } end
    end
  end
  for c = -1, cols + 1 do
    local r = rng.range(-2, 0)
    while r < rows + 2 do
      local x = c + 0.42 * wander(r * 0.3 + c * 7.3) + rng.sym(0.22) + twist * r   -- v2: the ridges spiral round a twisted limb
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
  for _, b in ipairs(bends) do
    local vy = b[1] * rows
    local n_ = floor(cols * 1.6 * b[3])
    for _ = 1, n_ do
      local side = b[2] > 0 and rng.range(0.55, 1.05) or rng.range(-0.05, 0.45)   -- u > 0 is the left side
      seeds[#seeds + 1] = { side * cols, vy + rng.sym(0.9) * (0.6 + b[3]) }
    end
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
  ink.smooth(outline, true, 0.8) ink.fill(tone(o.peel and 0.66 or 0.03))
  ink.smooth(outline, true, 0.8) ink.clip()
  local pa_, pb_ = rng.range(0, 6), rng.range(0, 6)    -- where the bark has fallen away
    local big = pw * ink.unit() > (o.detail or 0.16)
    for _, cl in ipairs(cells(seeds, 2.8)) do
      local g, gx = plate_outline(rng, cl.poly, rng.range(0.8, 0.94) - (rng.chance(0.15) and 0.08 or 0), o.flat)   -- v2: narrower furrows, some wider
      local wx = warp(gx, cl.seed[2])
      local u = wx / cols * 2 - 1
      local gone = o.peel and sin(gx * 0.9 + pa_) + sin(cl.seed[2] * 0.55 + pb_) > 1 - 2 * o.peel
      if u > -1.3 and u < 1.3 and not gone then
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
    -- v2: creases across the inside of a hard bend, the bark folded there (the furrows bunch, as on an elbow)
    if not o.flat then
      for _, bd in ipairs(bends) do
        if bd[3] > 0.35 then
          local dv = plen / total * 0.45
          for k = -1, 1 do
            local v = bd[1] + k * dv * (0.8 + 0.2 * rng.u())
            if v > 0.02 and v < 0.98 then
              local line = {}
              for i = 0, 6 do
                local u = bd[2] * lerp(0.98, 0.25 + 0.15 * rng.u(), i / 6)
                local x, y = P(u, v + 0.25 * dv * sin(i * 1.1 + k))
                line[#line + 1] = { x, y }
              end
              ink.smooth(line, false) ink.stroke(tone(0.02), 0.5 * bd[3] + 0.3, 0.45, true)
            end
          end
        end
      end
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

-- ---------------------------------------------------------------- the skeleton
-- Space colonization (Runions, Lane & Prusinkiewicz, "Modeling Trees with a Space Colonization
-- Algorithm", 2007): attraction points fill the crown; each influences its nearest node within
-- di; each influenced node grows a step D along the mean direction to its points, plus a bias
-- (eq. 3); points within dk of a node die. In 3D, drawn from the front, so limbs cross. A small di
-- relative to D makes it gnarled, a wide envelope makes it spread, as an old oak does.
-- Returns nodes { x, y, z, parent, kids = {}, r }, with r from the pipe model (r^n = sum of r_i^n).
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
local LOBE_SMALL = { { 0.34, 0.23 }, { 0.55, 0.13 }, { 0.78, 0.2 }, { 1, 0.01 } }
local LOBE_PLAIN = { { 0.42, 0.22 }, { 0.8, 0.17 }, { 1, 0.01 } }   -- inside a mass, where edges hardly show
local function leaf_outline(rng, L, small, plain)
  local left, right = {}, {}
  for _, q in ipairs(plain and LOBE_PLAIN or small and LOBE_SMALL or LOBE) do
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
  local out = leaf_outline(rng, L, o.small or L * ink.unit() < 0.62, o.plain)
  ink.smooth(out, true, 1)
  ink.fill(tone(t0), o.op)
  if L * ink.unit() > 0.6 and not o.plain and not o.small then
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
  back = { core = 0.8, lo = 0.68, hi = 0.86, op = 0.85, n = 1.05, shade = 0, small = true },
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
    local solid = not o.clear or o.clear(bx, by) > r * 2 + 0.6   -- no shape cut off by a text box
    -- the shade inside it, well inside the leaves, soft-edged
    if solid and not D.small then                       -- (not solid: leaves only) the back foliage is leaves alone: a shade behind it reads as a blob
      -- a little shade at its heart, broken up so it never reads as a smooth shape
      for _ = 1, 2 do
        ink.smooth(ink.blob(rng, bx + rng.sym(r * 0.2), by + rng.sym(r * 0.18), r * 0.34, r * 0.3, 0.35, 6), true)
        ink.fill(tone(D.core), D.op)
      end
    end
    if D.shade > 0 and solid then
      ink.smooth(ink.blob(rng, bx, by - r * 0.5, r * 0.6, r * 0.22, 0.2, 6), true) ink.fill(tone(0.03), D.shade, true)
    end
    -- leaves from the dark low side up to the lit top, each pointing out and drooping a little
    local count = floor((o.n or 1) * D.n * 0.8 * (9 + 4.6 * r * r / (L * L)))   -- most of the inside of a mass is hidden
    local ls = {}
    for k = 1, count do
      local a = rng.range(0, 2 * pi)
      local d = r * (rng.chance(0.69) and rng.range(0.72, 1.02) or sqrt(rng.u()) * 0.8)
      ls[k] = { bx + d * cos(a) * 1.08, by + d * sin(a), a, d / r }
    end
    table.sort(ls, function(p, q) return p[2] < q[2] end)
    for _, q in ipairs(ls) do
      -- near a text box the leaves thin out, so it has a fringe and not a cut edge
      local gap = o.clear and o.clear(q[1], q[2]) or 9
      if gap > 0.5 and (gap > 1.2 or rng.u() < (gap - 0.5) / 0.7) then
      local lit = (q[2] - by) / r                       -- -1 below .. +1 above
      local t = lerp(D.lo, D.hi, max(0, min(1, (lit + 0.75) / 1.6 + rng.sym(0.14))))
      local ang = q[3] / rad - 90 + rng.sym(32)
      if abs(ang % 360 - 180) < 70 then ang = ang + (rng.chance(0.5) and 40 or -40) end
      ink.push() ink.translate(q[1], q[2]) ink.rotate(ang)
      M.leaf(rng, L * rng.range(0.8, 1.2), { tone = t, op = D.op < 1 and D.op or nil, small = D.small, plain = not D.small and q[4] < 0.72 })
      ink.pop()
      end
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
  if e and not o.fill then e = { e[1], e[2] * 0.88, e[3] * 1.08, e[4] * 0.72, e[5] } end   -- v2: wider than tall
  if o.fill then
    -- around text: the crown is whatever free space the tree can reach, not an ellipse. A flood over a
    -- coarse grid from the top of the trunk finds it; attractors are scattered evenly through it.
    local F = o.fill
    local c = 0.7
    local seen, queue = {}, {}
    local function key(i, j) return i * 10000 + j end
    local i0, j0 = floor(o.base[1] / c), floor((o.base[2] + (o.trunk or 6)) / c)
    seen[key(i0, j0)] = 0 queue[1] = { i0, j0 }
    local ncells, head = 0, 1
    local reach_ = F.reach / c                         -- no limb walks further than this around the text
    while head <= #queue do
      local q = queue[head] head = head + 1
      if (q[2] + 0.5) * c >= F.ylo then ncells = ncells + 1 end
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local i, j = q[1] + d[1], q[2] + d[2]
        local x_, y_ = (i + 0.5) * c, (j + 0.5) * c
        local steps_ = seen[key(q[1], q[2])] + 1
        if not seen[key(i, j)] and steps_ <= reach_ and x_ > -1 and x_ < F.w + 1 and y_ > o.base[2] + 1 and y_ < F.h and allowed(x_, y_) then
          seen[key(i, j)] = steps_ queue[#queue + 1] = { i, j }
        end
      end
    end
    local acc_ = ink.rng(floor(o.base[1] * 211) + 41)
    local want = floor(min(o.N or 1100, floor(ncells * c * c * 3)) * 0.7)   -- v2: the scaffolds feed their own
    local tries = 0
    while #pts < want and tries < want * 60 do
      tries = tries + 1
      local x_, y_ = rng.range(-0.8, F.w + 0.8), rng.range(F.ylo, F.h - 0.2)
      local hf_ = max(0, min(1, (y_ - F.ylo) / max(1, F.h - F.ylo)))
      if seen[key(floor(x_ / c), floor(y_ / c))] and allowed(x_, y_) and acc_.u() < 0.3 + 0.7 * hf_ ^ 0.9 then   -- v2: fuller toward the top
        pts[#pts + 1] = { x_, y_, rng.sym(1) * e[5], near = nil, dist = di }
      end
    end
  end
  while not o.fill and #pts < floor((o.N or 900) * 0.8) do   -- v2: the scaffolds feed their own
    local x, y, z = rng.sym(1), rng.sym(1), rng.sym(1)
    -- denser near the surface of the crown; the underside flattened
    if x * x + y * y + z * z <= 1 and x * x + y * y + z * z > 0.04 + rng.u() * 0.32 and rng.u() < 0.35 + 0.65 * ((y + 1) / 2) ^ 0.9 then   -- v2: fuller toward the top
      if y < 0 then y = y * (#keep > 0 and 0.95 or 0.62) end
      local px, py = e[1] + x * e[3], e[2] + y * e[4]
      if allowed(px, py) then pts[#pts + 1] = { px, py, z * e[5], near = nil, dist = di } end
    end
  end
  do                                                   -- v2: an open middle, the weight out on the limbs
    local kept, cut = {}, ink.rng(floor(o.base[1] * 131) + 17)
    local span = (o.fill and o.fill.w or e[1] * 2) * 0.17
    for _, p in ipairs(pts) do
      local dx = abs(p[1] - o.base[1])
      local keep_ = o.fill and 0.3 or 0.6                -- a free-standing crown stays closed at the top
      if dx > span or p[2] < o.base[2] + 6 or cut.chance(keep_ + (1 - keep_) * dx / span) then kept[#kept + 1] = p end
    end
    pts = kept
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
  if not o.fill then tilt, bend = tilt * 0.4, bend * 0.5 end   -- v2: a free-standing oak stands up, its crown even on both sides
  -- v2: the trunk. As the theme grows it (a short trunk, 0.7 of the theme's), unless text sits over it
  -- or the leader would run into text: then, on about one seed in three, it stops at a height chosen
  -- for it, 1.0 to 1.3 trunk widths above the flare, either cut flat there or forking into a Y whose one
  -- arm is cut short. A stream of its own.
  local tm = ink.rng(floor(o.base[1] * 313 + o.base[2] * 71) + 29)
  local tw = o.trunkw or 3
  local over = nil                                     -- the lowest text over the trunk
  for _, q in ipairs(keep) do
    if q[1] < o.base[1] + tw * 0.8 and q[3] > o.base[1] - tw * 0.8 and q[2] > o.base[2] then over = min(over or 1e9, q[2]) end
  end
  local mode = nil
  if over and tm.chance(0.34) then mode = tm.chance(0.5) and "cut" or "y" end
  local steps = floor((o.trunk or 6) * 0.7 / D)
  if mode then
    local th_ = min(1.0 + tw * tm.range(1.0, 1.3), over - o.base[2] - tw * 0.6)
    steps = max(4, floor(th_ / D))
  end
  for k = 1, steps do
    local t = k / steps
    prev = add(prev.x + D * (tilt + bend * sin(t * 3.4)), prev.y + D, rng.sym(0.05), prev)
    prev.trunk = true
  end
  local cut_top = nil
  if mode == "cut" then
    prev.cuttop, prev.closed, cut_top = true, true, prev
    if prev.parent then prev.parent.closed = true if prev.parent.parent then prev.parent.parent.closed = true end end
  end
  -- Sweep limbs: where the page leaves a wide space beside the trunk (a short text, a text high on the
  -- page), long limbs reach out nearly level from low on the trunk, sag a little and lift at the end,
  -- as an oak in the open does. Planned before the growth, which then branches off them, and fed
  -- with points of their own, so that leaves fill the underhang. Their own stream: a page with no
  -- room for one draws nothing from the layout's.
  -- v2: the scaffolds. An old open-grown oak splits low into a few massive limbs that run out long and
  -- nearly level, sagging under their own weight, bending where a leader was lost, now and then coming
  -- down to rest an elbow on the ground and rising again; vertical sprouts stand on their tops. Planned
  -- before the growth on a stream of their own, flagged `sweep` (0 at the trunk, 1 at the tip) so the tree
  -- keeps them thick, leaves them out of the hook cut and the pruning, and starts them behind the trunk.
  do
    local sw = o.sweep
    if not sw then local st = rng.save() sw = ink.rng(rng.int(1, 1073741823)) rng.load(st) end
    local PW = o.fill and o.fill.w or e[1] * 2
    local PH = o.fill and o.fill.h or e[2] / 0.6
    local trunk_nodes = {}
    for i_, n in ipairs(nodes) do trunk_nodes[i_] = n end
    local ground = o.base[2]
    local meander = ink.fbm1(sw, 2)
    local function feed(x, y, spread, up)
      for _ = 1, 3 do
        local px, py = x + sw.sym(spread), y + sw.range(-0.6, up)
        if py > ground + 1.0 and allowed(px, py) then
          pts[#pts + 1] = { px, py, sw.sym(1.5), near = nil, dist = di, sweep = true }
        end
      end
    end
    -- a sprout: a young leader straight up off the top of a level limb, a little sinuous
    local function sprout(from, len)
      local n_ = floor(len / D)
      local prev_, th = from, pi / 2 + sw.sym(0.22)
      local ph = sw.range(0, 50)
      local placed = 0
      for k = 1, n_ do
        th = pi / 2 + (th - pi / 2) * 0.8 + 0.3 * meander(ph + k * 0.35)
        local x, y = prev_.x + D * cos(th), prev_.y + D * sin(th)
        if not allowed(x, y) or y > PH - 0.3 then break end
        local nn = add(x, y, sw.sym(0.05), prev_)
        nn.sweep = 0.72 + 0.28 * k / n_
        if k < 3 or k % 4 ~= 0 then nn.closed = true end
        prev_ = nn
        placed = placed + 1
        if k == n_ then feed(x, y, 1.2, 1.4) end
      end
      return placed
    end
    -- a scaffold: serpentine, two or three S-bends along it (its heading swings about a falling trend),
    -- a kink now and then where a leader was lost; an elbow comes down to rest on the ground and rises
    -- from there into a second column, as thick as the limb was at the elbow
    local function scaffold(from, dir, e0, L, elbow, low)
      local n_ = floor(L / D)
      local th = e0                                    -- elevation above level, radians, outward in dir
      local prev_ = from
      local m = sw.range(1.0, 1.6)                     -- periods of the swing along it: 2 to 3 bends
      local A = sw.range(0.42, 0.68)
      local phi = sw.range(0, 2 * pi)
      local sag = sw.range(0.35, 0.7) * (elbow and 1.8 or 1)
      local kink = 0
      local next_, lastsp = sw.int(4, 7), 0
      local rested, column, colw = false, 0, nil
      local placed = 0
      local mine = {}
      for k = 1, n_ do
        local t = k / n_
        if k > 4 and sw.chance(0.06) then kink = kink + sw.sym(0.5) end
        local target = e0 - sag * t + A * sin(2 * pi * m * t + phi) * (0.4 + 0.6 * min(1, t * 4)) + kink
        if column > 0 then target = 1.3 + 0.12 * sin(k * 0.5) column = column - 1
        elseif rested then target = max(target, 0.35) end
        th = lerp(th, target, 0.3)
        local x, y = prev_.x + dir * D * cos(th), prev_.y + D * sin(th)
        local rest = ground + (elbow and 0.42 or 1.3)
        if y < rest then
          y = rest
          if elbow and not rested then
            rested = true
            column = floor(sw.range(3, 7) / D)        -- the second column
            colw = lerp(low and -0.75 or -0.45, 1, t ^ 0.85)
          else th = max(th, 0.12) end
        end
        if x < 0.4 or x > PW - 0.4 then th = th + 0.25 end   -- the page's edge: it turns up, not out
        if x < -0.6 or x > PW + 0.6 or y > PH - 0.3 then break end
        if not allowed(x, y) then
          local ok = false
          for _, turn in ipairs({ -0.35, 0.35, -0.7, 0.7, -1.0, 1.0 }) do
            local th2 = th + turn
            local x2, y2 = prev_.x + dir * D * cos(th2), prev_.y + D * sin(th2)
            if allowed(x2, y2) and y2 > rest - 0.01 then x, y, th, ok = x2, y2, th2, true break end
          end
          if not ok then break end
        end
        th = max(-1.0, min(1.45, th))
        local nn = add(x, y, sw.sym(0.05), prev_)
        local sv = lerp(low and -0.75 or -0.45, 1, t ^ 0.85)   -- the tree's floor width: massive near the trunk
        if colw then sv = min(sv, colw + 0.25 * (1 - column / 12)) end   -- the column stays thick
        nn.sweep = sv
        mine[#mine + 1] = { nn, sv, colw }
        if k >= next_ then next_ = k + sw.int(4, 8) else nn.closed = true end
        prev_ = nn
        placed = placed + 1
        if t > 0.15 then feed(x, y, 2.4, 2.0) end
        -- now and then a sprout off the top of a level stretch
        if abs(th) < 0.3 and t > 0.15 and t < 0.85 and k - lastsp > 7 and column == 0 and sw.chance(low and 0.06 or 0.04) then
          local up = sprout(nn, sw.range(1.6, 3.4) * (1 - 0.4 * t))
          if up > 2 then lastsp = k end
        end
      end
      -- a limb that had to stop early (text, the page's edge) still tapers over the length it got
      if placed > 0 and placed < n_ then
        local lo = low and -0.75 or -0.45
        for i_, q in ipairs(mine) do
          if not q[3] then q[1].sweep = lerp(lo, 1, (i_ / placed) ^ 0.85) end
        end
      end
      return placed
    end
    local count = o.fill and sw.int(2, 4) or (sw.chance(0.5) and 2 or 4)   -- a free-standing tree: as many each side
    local d0 = sw.chance(0.5) and 1 or -1
    for i_ = 1, count do
      local dir = (i_ % 2 == 1) and d0 or -d0
      if i_ == 3 and o.fill and sw.chance(0.5) then dir = d0 end   -- two on one side: they cross over and under
      local f = count > 1 and (i_ - 1) / (count - 1) or 0.5
      f = max(0, min(1, f + sw.sym(0.14)))             -- v2: each limb leaves at a height of its own, not in levels
      local from = trunk_nodes[max(2, floor(#trunk_nodes * (cut_top and lerp(0.4, 0.8, f) or lerp(0.5, 1, f)) + 0.5))]
      local room = dir > 0 and (PW - from.x) or from.x
      local L = room * sw.range(1.0, 1.35) + sw.range(1, 3)
      local low = f < 0.5
      local e0 = low and sw.range(0.1, 0.4) or sw.range(0.35, 0.75)
      local elbow = low and sw.chance(0.5)
      scaffold(from, dir, e0, L, elbow, low)
    end
  end
  local function reach(list)
    for _, p in ipairs(pts) do
      if not p.dead then
        for _, n in ipairs(list) do
          local dx, dy, dz = p[1] - n.x, p[2] - n.y, p[3] - n.z
          local d2 = dx * dx + dy * dy + dz * dz
          if d2 < dk * dk then p.dead = true break end
          if d2 < p.dist * p.dist and not n.closed then p.dist, p.near = sqrt(d2), n end
        end
      end
    end
  end
  if mode == "y" then                                  -- v2: one arm of the Y, cut short
    local sd = tm.chance(0.5) and 1 or -1
    local a = (90 - sd * tm.range(28, 42)) * rad
    local n_ = max(2, floor(tw * tm.range(1.0, 1.8) / D))
    local p_ = prev
    for k = 1, n_ do
      local x, y = p_.x + D * cos(a), p_.y + D * sin(a)
      if not allowed(x, y) then break end
      p_ = add(x, y, 0, p_)
      p_.sweep, p_.closed, p_.yarm = -1.4, true, true
    end
    if p_ ~= prev then p_.cuttop = true end
    -- and the leader leans the other way
    local lx, ly = prev.x - sd * D * 0.45, prev.y + D * 0.9
    if allowed(lx, ly) then prev = add(lx, ly, 0, prev) end
  end
  reach(nodes)
  -- the trunk climbs until the crown can reach it
  local function reached() for _, p in ipairs(pts) do if p.near and not p.dead and not p.sweep and not p.near.sweep then return true end end return false end
  for _ = 1, cut_top and 0 or 200 do
    if reached() then break end
    if not allowed(prev.x, prev.y + D) then break end
    local pull = o.fill and 0 or D * (e[1] - prev.x) / e[3] * 0.25
    prev = add(prev.x + pull + D * rng.sym(o.fill and 0.08 or 0.2), prev.y + D, rng.sym(0.05), prev)
    prev.leader = true
    reach({ prev })
  end
  local gx, gy = o.bias and o.bias[1] or 0, o.bias and o.bias[2] or -0.1
  gy = gy - 0.22                                       -- v2: heavier limbs, spreading rather than climbing
  local inertia, outward = o.inertia or 0, (o.outward or 0) + 0.25
  local kinks = ink.rng(floor(o.base[1] * 977) + 5)   -- v2: sympodial kinks, on a stream of their own
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
      local n = a.n
      -- a limb keeps going the way it was going, and outward from the trunk: no hoops, no S-bends
      local up = n.parent
      if up then
        local px, py, pz = n.x - up.x, n.y - up.y, n.z - up.z
        local pL = sqrt(px * px + py * py + pz * pz) + 1e-9
        x, y, z = x + inertia * px / pL, y + inertia * py / pL, z + inertia * pz / pL
      end
      local ox = n.x - o.base[1]
      x = x + outward * ox / (abs(ox) + 1)
      -- v2: now and then a bud takes over from a lost leader, and the branch turns at an angle there
      if not n.sweep and kinks.chance(0.22) then
        local tk = kinks.sym(0.8)
        x, y = x * cos(tk) - y * sin(tk), x * sin(tk) + y * cos(tk)
      end
      do                                               -- v2: an oak's branches reach out, not straight up
        local h_ = sqrt(x * x + y * y) + 1e-9
        if y > 0 and abs(x) / h_ < 0.25 then
          local sd = (n.x - o.base[1]) >= 0 and 1 or -1
          if abs(x) > 0.05 then sd = x > 0 and 1 or -1 end
          x = x + sd * 0.22 * h_
        end
      end
      local L2 = sqrt(x * x + y * y + z * z) + 1e-9
      -- a node with this direction already: stop a stuck tip growing on the spot
      local nx_, ny_ = n.x + D * x / L2, n.y + D * y / L2
      -- a branch that meets a text box slides along it, it does not just stop
      if o.fill and not allowed(nx_, ny_) then
        local dx0, dy0 = x / L2, y / L2
        for _, turn in ipairs({ 0.6, -0.6, 1.1, -1.1, 1.6, -1.6 }) do
          local dx1, dy1 = dx0 * cos(turn) - dy0 * sin(turn), dx0 * sin(turn) + dy0 * cos(turn)
          if allowed(n.x + D * dx1, n.y + D * dy1) then nx_, ny_ = n.x + D * dx1, n.y + D * dy1 break end
        end
      end
      local hf_ = (n.y - o.base[2]) / max(1, (o.fill and o.fill.h or e[2] + e[4]) - o.base[2])
      if #n.kids < (hf_ > 0.6 and 4 or 3) and allowed(nx_, ny_) then new[#new + 1] = add(nx_, ny_, n.z + D * z / L2, n) end
    end
    if #new == 0 then break end
    reach(new)
  end
  -- no hooks: a branch that has turned back on itself within a few steps stops where it turned
  do
    local function back(n, k) for _ = 1, k do n = n.parent or n end return n end
    for _, n in ipairs(nodes) do
      if n.parent and n.parent.cut then n.cut = true
      elseif not n.sweep then                         -- a planned long limb leaves the trunk at a right angle on purpose
        local a, b = back(n, 2), back(n, 8)
        local c = back(b, 2)
        local dx, dy, ex, ey = n.x - a.x, n.y - a.y, b.x - c.x, b.y - c.y
        if c ~= b and dx * ex + dy * ey < 0.1 * sqrt((dx * dx + dy * dy) * (ex * ex + ey * ey)) then n.cut = true end
      end
    end
    local out = {}
    for _, n in ipairs(nodes) do
      if n.cut then
        local kept = {}
        for _, k in ipairs(n.parent.kids) do if k ~= n then kept[#kept + 1] = k end end
        n.parent.kids = kept
      else out[#out + 1] = n end
    end
    nodes = out
  end
  -- no stubs: a side branch of only a node or two is not a branch
  do
    local size = {}
    for i = #nodes, 1, -1 do
      local n = nodes[i]
      local c = 1
      for _, k in ipairs(n.kids) do c = c + (size[k] or 1) end
      size[n] = c
    end
    for _, n in ipairs(nodes) do
      if #n.kids > 1 then
        local kept = {}
        local biggest = 0
        for _, k in ipairs(n.kids) do biggest = max(biggest, size[k]) end
        for _, k in ipairs(n.kids) do
          -- nor a weak shoot off a great limb: it would only loop around it
          local weak = size[n] > 150 and size[k] < size[n] * 0.05 and not k.sweep   -- a planned long limb is meant to be bare
          local hk = max(0, min(1, (k.y - o.base[2]) / max(1, (o.fill and o.fill.h or e[2] + e[4]) - o.base[2])))
          if (size[k] >= lerp(max(14, o.minbranch or 4), 6, hk) and not weak) or size[k] == biggest or k.cuttop or k.yarm or k.trunk then kept[#kept + 1] = k else k.pruned = true end
        end
        n.kids = kept
      end
    end
    local out = {}
    for _, n in ipairs(nodes) do
      if not n.pruned and not (n.parent and n.parent.pruned) then out[#out + 1] = n else n.pruned = true end
    end
    nodes = out
  end
  -- relax the path: each node eases toward the line between its neighbors, so limbs sweep instead of wriggling
  for _ = 1, o.relax or 2 do                         -- v2: fewer passes, the bends stay
    local px, py = {}, {}
    for _, n in ipairs(nodes) do
      if n.parent and #n.kids == 1 then
        local a, b = n.parent, n.kids[1]
        px[n], py[n] = lerp(n.x, (a.x + b.x) / 2, 0.6), lerp(n.y, (a.y + b.y) / 2, 0.6)
      elseif n.parent and #n.kids == 0 then
        local a = n.parent
        local g = a.parent or a
        px[n], py[n] = lerp(n.x, a.x + (a.x - g.x), 0.5), lerp(n.y, a.y + (a.y - g.y), 0.5)
      end
    end
    for _, n in ipairs(nodes) do if px[n] then n.x, n.y = px[n], py[n] end end
  end
  -- the pipe model, tips to base
  local en = o.pipe or 2.1
  local function pipe(floor_)
    for i = #nodes, 1, -1 do
      local n = nodes[i]
      if #n.kids == 0 then n.r = 1
      else
        local sum = 0
        for _, k in ipairs(n.kids) do sum = sum + k.r ^ en end
        n.r = sum ^ (1 / en)
      end
      if floor_ and n.sweep then n.r = max(n.r, floor_ * (0.05 + 0.25 * (1 - n.sweep))) end
    end
  end
  pipe()
  -- v2: the scaffolds are thicker than their twigs would make them (the tree keeps them so); the trunk
  -- has to carry them, so their width goes into the pipe too, and the trunk swells where they leave it
  for _ = 1, 2 do pipe(nodes[1].r * 0.6) end
  return nodes
end

-- The chains: from the root follow the thickest child; every other child starts a chain of its own,

-- v2: copied from the theme so its widths, flare, trunk end and ground props can change
local function chains(nodes)
  local out = {}
  local function walk(start, parent_prev)
    local chain = { parent_prev = parent_prev, start = start }
    local n = start
    local list = { n }
    while #n.kids > 0 do
      -- the stem goes on the straightest way among the thick ones, so a trunk does not turn into a limb
      local up = n.parent or n
      local ax, ay = n.x - up.x, n.y - up.y
      if up == n then ax, ay = 0, 1 end
      local aL = sqrt(ax * ax + ay * ay) + 1e-9
      local function score(k)
        local dx, dy = k.x - n.x, k.y - n.y
        local d = sqrt(dx * dx + dy * dy) + 1e-9
        local v = k.r * (1 + 0.9 * (dx * ax + dy * ay) / (d * aL))
        if k.sweep and not n.sweep then v = v * 0.01 end   -- a sweep limb leaves the trunk from behind it
        if (n.trunk or n.leader) and (k.trunk or k.leader) then v = v * 100 end
        if k.stub then v = v * 1000 end   -- v2: the trunk goes on up, painted over what leaves it
        return v
      end
      table.sort(n.kids, function(p, q)
        local a_, b_ = score(p), score(q)
        if a_ ~= b_ then return a_ > b_ end
        return p.r > q.r
      end)
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

M.SEASONS = {
  summer = { butterflies = 2, bees = 2 },
  spring = { leaves = { { 0x5F, 0x9A, 0x3F }, { 0x74, 0xA8, 0x46 }, { 0x4F, 0x8C, 0x4A } }, size = 0.82, fill = 0.62, leaf = 0.8, flowers = true, butterflies = 4 },
  autumn = { bark = { 0x54, 0x3C, 0x2E }, leaves = { { 0xB0, 0x68, 0x22 }, { 0xC4, 0x88, 0x20 }, { 0xA0, 0x58, 0x1C }, { 0xBC, 0x9C, 0x30 }, { 0x6B, 0x70, 0x3A } }, fill = 0.8, fall = 1.1, litter = 7, wind = true, sway = 0.9, pumpkins = true, bats = 7 },
  winter = { bark = { 0x4E, 0x48, 0x42 }, bare = true, twigs = 0.8, snow = true, grass = 0.12, props = 0, birds = "robin", nbirds = 3, icicles = true, holly = true, snowman = true },
  dead = { bark = { 0x5A, 0x54, 0x4C }, bare = true, twigs = 0.2, snap = true, peel = 0.42, grass = 0.5, props = 0.5, birds = "crow", nbirds = 4, bats = 3 },
}

-- The end of a limb cut long ago, at x, y, its axis at ang: a roll of wound wood around old heartwood,
-- seen a little from the side. snap: a limb broken off, all splinters.
-- ---------------------------------------------------------------- stumps
--
-- M.stump(rng, x, y, ang, w, o): at (x, y), the limb's axis at ang degrees (0: pointing up, as the theme's
-- stump_end: local +y runs out of the limb), w its width there (cm). o.snap: broken, not sawn; o.fungus,
-- o.hollow, o.sprouts: true/false to force them (else by chance, more on wide ones); o.fresh: a recent cut
-- (pale wood, no lip). M.stump_end(rng, x, y, ang, w, snap) has the theme's signature.
--
-- Sawn: the cut is seen edge-on from a little above, so it is a thin oval exactly as wide as the limb.
-- Around it the wound wood has rolled over the rim for years: a lumpy lip of bark, thicker in places, lit
-- on its upper left, that swells the limb's outline just below the cut. On the face: weathered gray wood,
-- growth rings round an off-center pith, drying checks opening toward the rim, sometimes a rotted hollow.
-- Shelf fungi now and then on the shaded side; a few water sprouts from the lip.
-- Snapped: the wood tore along its grain: long splinters, highest at the hinge side, pale raw wood with
-- darker clefts between, and the bark torn ragged below them.
M.stump = (function()

  -- A sawn end, drawn from a real cross-section seen edge-on from a little above:
  --   the bark's outer edge, scalloped where its furrows cut in; a band of bark (dark outside, a paler
  --   inner bark); pale sapwood; darker heartwood with growth rings round an off-center pith, crowding
  --   toward the bark; oak's medullary rays as fine silver flecks; drying checks opening from the rim.
  -- kind "healing" (a living tree): woundwood has rolled in from the rim as a rounded bark bead, so the
  -- face sits a little lower and smaller inside it. "weathered": gray, checked, sometimes a rotted hollow.
  -- "fresh": pale and crisp. The outline never reaches past the limb's own width (no lid).
  local function sawn(rng, w, o, fine, bp, D)
    local rx = w * 0.5
    local ry = w * max(0.065, min(0.13, 0.15 - 0.025 * D))   -- wide trunks are seen nearly edge-on
    local kind = o.kind or (o.fresh and "fresh") or (rng.chance(o.live == false and 0.15 or 0.6) and "healing" or "weathered")
    local m = floor(w / 0.12 * 0.9) + 6                  -- the bark's ridges round the rim, as its plates
    local ph = rng.range(0, 2 * pi)
    local function rim(f, n, notch, dy, lift)
      local p = {}
      n = n or 48
      for k = 0, n - 1 do
        local a = 2 * pi * k / n
        local nt = notch and notch * abs(sin(a * m / 2 + ph)) ^ 6 or 0
        local up = (lift and sin(a) > 0) and lift * sin(a) or 0
        local side = (f > 1) and 0.04 * cos(a) ^ 4 or 0   -- the outer edge covers the limb's rough corners
        p[#p + 1] = { rx * (f + side) * (1 - nt) * cos(a), (dy or 0) + ry * f * (1 - nt * 2) * sin(a) + up }
      end
      return p
    end
    local bead = kind == "healing" and w * rng.range(0.025, 0.045) or 0
    -- 1. the bark: the whole end, its far edge scalloped by the furrows
    local outer = rim(1.012, 64, fine and 0.06 or 0.03, 0, bead)
    ink.smooth(outer, true) ink.fill(tone(0.2))
    local bt = rng.range(0.07, 0.1)                       -- bark thickness, of the radius
    ink.smooth(rim(1 - bt * 0.45, 48, nil, 0, bead * 0.6), true) ink.fill(tone(kind == "fresh" and 0.42 or 0.32), 0.8)   -- inner bark
    -- 2. the wood
    local wf = 1 - bt                                     -- the wood's radius, of rx
    local face, dy = wf, 0
    if kind == "healing" then
      face = wf * rng.range(0.72, 0.86)                   -- the roll has crept in over the rim
      dy = -ry * 0.12                                     -- and the face sits a little below its crest
      -- the bead: bark-colored, lit along its crest on the far left, its inner slope facing us beyond the face
      ink.smooth(rim(wf + 0.01, 48, nil, 0, bead * 0.8), true) ink.fill(tone(0.3))
      local crest = {}
      for k = 0, 20 do
        local a = pi * (0.15 + 0.85 * k / 20)
        crest[#crest + 1] = { rx * wf * 0.96 * cos(a), ry * wf * 0.96 * sin(a) + bead * 0.75 * sin(a) }
      end
      ink.smooth(crest, false) ink.stroke(tone(0.55), bp(0.018), 0.75)
      if fine then                                        -- the roll's wrinkles, concentric
        for k = 1, 2 do
          local f = lerp(wf, face, k / 3)
          local arc = {}
          for q = 0, 16 do local a = pi * (0.1 + 0.8 * q / 16) arc[#arc + 1] = { rx * f * cos(a), dy * k / 3 + ry * f * sin(a) + bead * 0.4 * sin(a) } end
          ink.smooth(arc, false)
        end
        ink.stroke(tone(0.18), bp(0.007), 0.6)
      end
    end
    local sap = kind == "fresh" and 0.8 or (kind == "healing" and 0.66 or 0.6)
    local heart = sap - (kind == "fresh" and 0.12 or 0.08)
    local wood = rim(face, 40, nil, dy)
    ink.smooth(wood, true) ink.fill(tone(sap))
    ink.smooth(wood, true) ink.clip()
      local px, py = rng.sym(rx * face * 0.2), dy + rng.sym(ry * face * 0.25)
      local function ring(f, wob)
        local p = {}
        for k = 0, 31 do
          local a = 2 * pi * k / 32
          local e = 1 + (wob and rng.sym(wob) or 0)
          p[#p + 1] = { lerp(px, 0, f) + rx * face * f * e * cos(a), lerp(py, dy, f) + ry * face * f * e * sin(a) }
        end
        return p
      end
      -- heartwood
      ink.smooth(ring(rng.range(0.68, 0.82), 0.02), true) ink.fill(tone(heart))
      -- growth rings, crowding toward the bark
      local nr = fine and rng.int(8, 13) or rng.int(3, 4)
      for k = 1, nr do ink.smooth(ring((k / (nr + 0.4)) ^ 0.72, fine and 0.012 or nil), true) end
      ink.stroke(tone(heart - 0.12), bp(0.0045), 0.55)
      -- the light: the far half catches the sky, the near half darker
      ink.smooth({ { -rx, dy }, { -rx * 0.3, dy + ry }, { rx * 0.4, dy + ry }, { rx * 0.2, dy + ry * 0.2 }, { -rx * 0.5, dy - ry * 0.1 } }, true)
      ink.fill(white, kind == "fresh" and 0.2 or 0.12)
      ink.poly({ { -rx, dy - ry * 0.25 }, { rx, dy - ry * 0.25 }, { rx, dy - ry * 2 }, { -rx, dy - ry * 2 } }, true) ink.fill(tone(0.1), 0.22)
      -- oak's rays: fine silver flecks along the radii
      if fine then
        for _ = 1, floor(18 + 10 * D) do
          local a = rng.range(0, 2 * pi)
          local r0 = rng.range(0.15, 0.85)
          local r1 = r0 + rng.range(0.05, 0.14)
          ink.moveto(px + rx * face * r0 * cos(a), py + ry * face * r0 * sin(a))
          ink.lineto(px + rx * face * r1 * cos(a), py + ry * face * r1 * sin(a))
        end
        ink.stroke(tone(min(0.95, sap + 0.15)), bp(0.004), 0.7)
      end
      -- drying checks: V cracks from the rim toward the pith, widest at the rim
      if kind ~= "fresh" then
        for _ = 1, rng.int(kind == "weathered" and 3 or 1, kind == "weathered" and (fine and 6 or 3) or 2) do
          local a = rng.range(0, 2 * pi)
          local r0 = rng.range(0.1, 0.5)
          local wv = rng.range(0.02, 0.05)
          local function at(r, da) return px + rx * face * r * cos(a + da), py + ry * face * r * sin(a + da) end
          local x0, y0 = at(r0, 0)
          local x1, y1 = at(1.1, -wv)
          local x2, y2 = at(1.1, wv)
          local xm, ym = at((r0 + 1.1) / 2, rng.sym(0.02))
          ink.poly({ { x0, y0 }, { xm + (x1 - x2) * 0.15, ym + (y1 - y2) * 0.15 }, { x1, y1 }, { x2, y2 }, { xm - (x1 - x2) * 0.15, ym - (y1 - y2) * 0.15 } }, true)
        end
        ink.fill(tone(0.1), 0.85)
      end
      -- a hollow where the heartwood rotted: dark, its far inner wall catching a little light
      local hollow = o.hollow
      if hollow == nil then hollow = kind == "weathered" and w > 1.2 and rng.chance(0.4) end
      if hollow then
        local hr = rng.range(0.3, 0.5)
        local hp = {}
        for k = 0, 23 do
          local a = 2 * pi * k / 24
          local e = 1 + 0.12 * sin(a * 3 + ph) + rng.sym(0.05)
          hp[#hp + 1] = { px * 0.8 + rx * face * hr * e * cos(a), py * 0.8 + ry * face * hr * e * sin(a) }
        end
        ink.smooth(hp, true) ink.fill(tone(0.06))
        ink.smooth(hp, true) ink.clip()
          local wall = {}
          for k = 0, 16 do local a = pi * k / 16 wall[#wall + 1] = { px * 0.8 + rx * face * hr * cos(a), py * 0.8 + ry * face * hr * (0.2 + 0.85 * sin(a)) } end
          for k = 16, 0, -1 do local a = pi * k / 16 wall[#wall + 1] = { px * 0.8 + rx * face * hr * 1.1 * cos(a), py * 0.8 + ry * face * hr * 1.3 * sin(a) } end
          ink.smooth(wall, true) ink.fill(tone(0.3), 0.8)
        ink.unclip()
      end
    ink.unclip()
    -- the crease where the face meets the bark or the roll
    ink.smooth(wood, true) ink.stroke(tone(0.1), bp(0.008), 0.7)
    -- the bark's far edge catches the light on the left
    local hi = {}
    for k = 0, 14 do
      local a = pi * (0.5 + 0.45 * k / 14)
      hi[#hi + 1] = { rx * 0.995 * cos(a), ry * sin(a) + bead * sin(a) }
    end
    ink.smooth(hi, false) ink.stroke(tone(0.5), bp(0.012), 0.6)
    -- lichen on an old cut
    if fine and kind == "weathered" then
      for _ = 1, rng.int(2, 4) do
        local a = rng.range(0.2, 0.8) * pi * (rng.chance(0.5) and 1 or -1)
        local x0, y0 = rx * 0.9 * cos(a), ry * 0.9 * sin(a)
        for _ = 1, 4 do ink.circle(x0 + rng.sym(w * 0.03), y0 + rng.sym(ry * 0.15), w * rng.range(0.006, 0.014)) end
      end
      ink.fill(tone(0.82), 0.8)
    end
    return ry + bead
  end

  local function snapped(rng, w, o, fine, bp)
    local rx = w * 0.5
    local hinge = rng.chance(0.5) and 1 or -1            -- the side that held longest
    local top = {}
    local n = fine and rng.int(8, 11) or rng.int(5, 7)
    -- the break runs on a slant, highest at the hinge, with a fringe of short fibers along it and one or two
    -- longer slivers near the hinge, not a crown of spikes
    local lo, hi = w * rng.range(0.05, 0.15), w * rng.range(0.45, 0.7)
    local long1 = rng.int(math.floor(n * 0.55), math.floor(n * 0.9))
    top[#top + 1] = { -rx, -w * 0.02 }
    -- fibers of uneven widths, some torn square, some to a point, the valleys between them uneven too
    local xs, x = {}, -rx
    while x < rx do xs[#xs + 1] = x x = x + 2 * rx / n * rng.range(0.4, 1.8) end
    xs[#xs + 1] = rx
    for k = 1, #xs - 1 do
      local x0, x1 = xs[k], xs[k + 1]
      local u = (((x0 + x1) / 2) / rx * hinge + 1) / 2   -- 0 far side .. 1 hinge
      local base = lerp(lo, hi, u ^ 1.3) + rng.sym(w * 0.04)
      local fib = w * rng.range(0.02, 0.14) * (0.5 + u)
      if k == long1 then fib = fib + w * rng.range(0.12, 0.22) end
      top[#top + 1] = { x0, base - w * rng.range(0.0, 0.06) }
      if rng.chance(0.35) and x1 - x0 > rx / n then      -- torn square: a ragged flat top
        top[#top + 1] = { lerp(x0, x1, 0.25), base + fib * 0.8 }
        top[#top + 1] = { lerp(x0, x1, 0.55), base + fib * rng.range(0.6, 0.9) }
        top[#top + 1] = { lerp(x0, x1, 0.8), base + fib }
      else
        top[#top + 1] = { lerp(x0, x1, rng.range(0.35, 0.65)), base + fib }
      end
    end
    top[#top + 1] = { rx, lerp(lo, hi, (hinge + 1) / 2) - w * 0.03 }
    top[#top + 1] = { rx, -w * 0.02 }
    -- the raw wood, one shape; the clefts between fibers are drawn as grooves on it
    local inner = top
    ink.poly(inner, true) ink.stroke(tone(0.16), bp(0.012), 0.8)
    ink.poly(inner, true) ink.fill(tone(0.7))
    ink.poly(inner, true) ink.clip()
      -- the raw wood: lit on the left, in shade on the right, grain running up each splinter
      ink.poly({ { 0, -w }, { rx * 1.2, -w }, { rx * 1.2, w }, { 0, w } }, true) ink.fill(tone(0.4), 0.35)
      if fine then
        for k = 1, #top - 2, 2 do
          local p = top[k + 1]
          if p and p[2] > w * 0.15 then
            for j = -1, 1 do
              local x0 = p[1] + j * rx / n * 0.5
              ink.moveto(x0, -w * 0.05) ink.curveto(x0 + j * w * 0.01, p[2] * 0.4, p[1] + j * w * 0.008, p[2] * 0.75, p[1] + j * w * 0.004, p[2] * 0.95)
            end
          end
        end
        ink.stroke(tone(0.46), bp(0.006), 0.7)
      end
      for k = 2, #top - 1 do
        local p, q = top[k], top[k + 1]
        if q and q[2] < p[2] - w * 0.03 then          -- a valley after a peak: a dark cleft running down
          ink.moveto(q[1], q[2]) ink.lineto(q[1] + rng.sym(w * 0.01), q[2] - w * rng.range(0.08, 0.2))
        end
      end
      ink.stroke(tone(0.22), bp(0.014), 0.8)
    ink.unclip()
    -- the bark torn ragged at the foot of the splinters, strips of it peeled up on the edges
    -- the bark torn ragged below: an uneven edge, a strip or two peeled up at the sides
    local tear = {}
    local m = fine and 10 or 6
    for k = 0, m do
      local tx = -rx * 1.01 + 2.02 * rx * k / m + (k > 0 and k < m and rng.sym(rx / m * 0.5) or 0)
      tear[#tear + 1] = { tx, w * rng.range(-0.05, 0.03) }
    end
    for _, sd in ipairs({ -1, 1 }) do
      if rng.chance(0.6) then                           -- a peeled strip, standing up from the edge
        local x0 = sd * rx * rng.range(0.6, 0.85)
        local k = sd < 0 and 2 or m
        table.insert(tear, k, { x0 - sd * w * 0.03, w * rng.range(0.15, 0.3) })
        table.insert(tear, k, { x0 - sd * w * 0.07, w * 0.0 })
      end
    end
    for k = m, 0, -1 do tear[#tear + 1] = { -rx * 1.01 + 2.02 * rx * k / m, -w * 0.1 } end
    ink.poly(tear, true) ink.fill(tone(0.22))
    return w * 0.5
  end

  -- shelf fungi on the shaded side of the trunk below the end: brackets seen side-on, stacked
  local function fungi(rng, w, side, fine, bp)
    local k = rng.int(2, 3)
    local y = -w * rng.range(0.5, 0.9)
    for i = 1, k do
      local s = w * rng.range(0.1, 0.17) * (1 - 0.2 * (i - 1))
      local x0 = side * w * 0.5
      local br = {}
      for j = 0, 10 do
        local a = pi * j / 10
        br[#br + 1] = { x0 + side * s * 1.3 * sin(a), y + s * 0.42 * cos(a) - s * 0.1 * sin(a) }
      end
      br[#br + 1] = { x0 - side * s * 0.15, y - s * 0.4 }
      br[#br + 1] = { x0 - side * s * 0.15, y + s * 0.4 }
      ink.smooth(br, true, 0.7) ink.fill(tone(0.55))
      -- pale underside, concentric bands on top
      ink.moveto(x0, y - s * 0.3) ink.curveto(x0 + side * s * 0.6, y - s * 0.42, x0 + side * s * 1.1, y - s * 0.3, x0 + side * s * 1.3, y - s * 0.05)
      ink.stroke(tone(0.85), bp(0.01), 0.8)
      if fine then
        for b = 1, 2 do
          local f = 1 - 0.3 * b
          ink.moveto(x0, y + s * 0.38 * f) ink.curveto(x0 + side * s * 0.7 * f, y + s * 0.4 * f, x0 + side * s * 1.2 * f, y + s * 0.2 * f, x0 + side * s * 1.28 * f, y - s * 0.02)
        end
        ink.stroke(tone(0.35), bp(0.006), 0.7)
      end
      y = y - s * rng.range(0.8, 1.1)
    end
  end

  -- water sprouts from the lip: thin shoots rising and leaning out
  local function sprouts(rng, w, top, fine, bp)
    for _ = 1, rng.int(2, 4) do
      local x0 = rng.sym(w * 0.42)
      local L = w * rng.range(0.35, 0.7)
      local lean = (x0 / (w * 0.5)) * 0.5 + rng.sym(0.2)
      local x1, y1 = x0 + L * lean * 0.4, top + L * 0.5
      local x2, y2 = x0 + L * lean, top + L
      ink.taper(x0, top * 0.6, x1 - lean * L * 0.1, y1, x1, y1 + L * 0.2, x2, y2, w * 0.075, w * 0.02)
      ink.fill(tone(0.24))
      local sx, sy = lerp(x0, x2, 0.55), lerp(top, y2, 0.55)   -- a side twig
      local sd = rng.chance(0.5) and 1 or -1
      ink.taper(sx, sy, sx + sd * L * 0.12, sy + L * 0.1, sx + sd * L * 0.22, sy + L * 0.2, sx + sd * L * 0.3, sy + L * 0.32, w * 0.03, w * 0.01)
      ink.fill(tone(0.24))
      if fine then
        ink.taper(x0 - w * 0.008, top * 0.6, x1 - lean * L * 0.1 - w * 0.008, y1, x1 - w * 0.006, y1 + L * 0.2, x2, y2, w * 0.016, w * 0.004)
        ink.fill(tone(0.5), 0.5)
      end
    end
  end

  local function stump(rng, x, y, ang, w, o)
    o = o or {}
    ink.push() ink.translate(x, y) ink.rotate(ang)
    local D = w * ink.unit()                              -- the end's width on the page, cm
    local fine = D > 0.45 and ink.get_lift() < 0.3
    local bp = function(f) return max(0.2, f * D * 28.3465) end
    local top
    if o.snap then top = snapped(rng, w, o, fine, bp) else top = sawn(rng, w, o, fine, bp, D) end
    local fg = o.fungus
    if fg == nil then fg = w > 0.9 and rng.chance(0.25) end
    if fg and D > 0.3 then fungi(rng, w, rng.chance(0.5) and 1 or -1, fine, bp) end
    local sp = o.sprouts
    if sp == nil then sp = not o.snap and w > 0.6 and rng.chance(0.35) end
    if sp then sprouts(rng, w, top, fine, bp) end
    ink.pop()
  end


  return stump
end)()

-- the theme's old entry point: every cut and break is drawn by M.stump
function M.stump_end(rng, x, y, ang, w, snap) return M.stump(rng, x, y, ang, w, { snap = snap }) end

function M.swing(rng, x, y, w, seat_y, a, sway, snow)
  sway = sway or 0
  local gap = 0.8
  for _, sd in ipairs({ -1, 1 }) do
    local rx = x + sd * gap
    local ty = y + sd * gap * math.tan(a)
    -- the turns around the limb
    for k = -1, 1 do
      ink.moveto(rx + k * 0.09 - 0.03, ty + w * 0.5) ink.lineto(rx + k * 0.09 + 0.03, ty - w * 0.5)
      ink.stroke(tone(0.8), 0.9)
      ink.moveto(rx + k * 0.09 - 0.03, ty + w * 0.5) ink.lineto(rx + k * 0.09 + 0.03, ty - w * 0.5)
      ink.stroke(tone(0.35), 0.25)
    end
    -- the rope: dark edge, light twist
    ink.moveto(rx, ty - w * 0.5) ink.lineto(rx + sway, seat_y + 0.04)
    ink.stroke(tone(0.2), 1.1)
    ink.moveto(rx, ty - w * 0.5) ink.lineto(rx + sway, seat_y + 0.04)
    ink.stroke(tone(0.82), 0.5, 1, false, "[1.2 1.2] 0")
  end
  -- the seat, a plank seen on edge with its grain
  x = x + sway
  local hw = gap + 0.42
  ink.smooth({ { x - hw, seat_y + 0.11 }, { x + hw, seat_y + 0.11 }, { x + hw + 0.02, seat_y }, { x + hw, seat_y - 0.1 }, { x - hw, seat_y - 0.1 }, { x - hw - 0.02, seat_y } }, true, 0.3)
  ink.fill(ink.accent(-0.12))
  ink.moveto(x - hw + 0.04, seat_y + 0.06) ink.lineto(x + hw - 0.04, seat_y + 0.06)
  ink.stroke(ink.accent(0.25), 0.5)
  ink.moveto(x - hw + 0.1, seat_y - 0.05) ink.lineto(x + hw - 0.1, seat_y - 0.05)
  ink.stroke(ink.accent(-0.45), 0.3)
  if snow then
    local top = { { x - hw * 0.95, seat_y + 0.1 }, { x - hw * 0.6, seat_y + 0.24 }, { x, seat_y + 0.3 }, { x + hw * 0.6, seat_y + 0.24 }, { x + hw * 0.95, seat_y + 0.1 } }
    ink.smooth(top, true) ink.fill(white)
    ink.smooth(top, false) ink.stroke(tone(0.72), 0.3)
    M.icicles(rng, x - hw * 0.8, x + hw * 0.8, seat_y - 0.1, 0.32)
  end
end

local ICE, ICE_EDGE = { 0.8, 0.88, 0.94 }, { 0.42, 0.56, 0.68 }
-- icicles hanging from a level edge at y, from x0 to x1
function M.icicles(rng, x0, x1, y, L)
  local x = x0
  while x < x1 do
    local w_, l = rng.range(0.018, 0.04), L * rng.range(0.35, 1)
    ink.poly({ { x - w_, y + 0.02 }, { x + w_, y + 0.02 }, { x + rng.sym(0.01), y - l } }, true) ink.fill(ICE)
    ink.poly({ { x - w_, y + 0.02 }, { x + rng.sym(0.01), y - l }, { x + w_, y + 0.02 } }, false) ink.stroke(ICE_EDGE, 0.2)
    x = x + rng.range(0.1, 0.3)
  end
end

-- A pumpkin on the ground at the origin, radius r; call it in an orange ramp. Lit from the upper left.
function M.pumpkin(rng, r, carved)
  local h = r * rng.range(0.74, 0.88)
  ink.poly(ellipse_(0, h * 0.9, r * 1.02, h * 0.98), true) ink.fill(tone(0.1))
  for _, i in ipairs({ -2, 2, -1, 1, 0 }) do
    local cx = i * r * 0.36
    local rx = r * (0.34 - 0.03 * abs(i))
    local lit = 0.5 - 0.09 * i
    ink.smooth(ellipse_(cx, h * 0.92, rx, h * (0.96 - 0.05 * abs(i))), true) ink.fill(tone(lit - 0.14))
    ink.smooth(ellipse_(cx - rx * 0.16, h * 1.02, rx * 0.68, h * (0.74 - 0.05 * abs(i))), true) ink.fill(tone(lit))
    streak3(cx - rx * 0.42, h * 1.5, cx - rx * 0.55, h * 1.25, cx - rx * 0.55, h * 0.95, cx - rx * 0.42, h * 0.65, r * 0.035, r * 0.008, white, 0.3)
  end
  if carved then
    local face = function(p) ink.poly(p, true) ink.fill({ 0.12, 0.07, 0.03 }) end
    face({ { -r * 0.42, h * 1.06 }, { -r * 0.14, h * 1.06 }, { -r * 0.28, h * 1.36 } })
    face({ { r * 0.14, h * 1.06 }, { r * 0.42, h * 1.06 }, { r * 0.28, h * 1.36 } })
    face({ { -r * 0.55, h * 0.74 }, { -r * 0.3, h * 0.56 }, { -r * 0.18, h * 0.7 }, { 0, h * 0.5 }, { r * 0.18, h * 0.7 }, { r * 0.3, h * 0.56 }, { r * 0.55, h * 0.74 }, { r * 0.2, h * 0.34 }, { -r * 0.2, h * 0.34 } })
  end
  ink.smooth({ { -r * 0.1, h * 1.82 }, { -r * 0.06, h * 2.2 }, { r * 0.16, h * 2.34 }, { r * 0.12, h * 1.82 } }, true) ink.fill(tone(0.1))
end

-- A bat in the air, centered, wings s across: flat black, flap -1..1.
function M.bat(rng, s, flap)
  local f = (flap or 0) * 0.2
  -- one wing, from the shoulder out along its top edge to the tip, then scalloped back between the fingers
  local wing = { { 0.07, 0.1 }, { 0.2, 0.17 + f * 0.3 }, { 0.36, 0.28 + f * 0.8 }, { 0.42, 0.33 + f } }  -- to the wrist
  for t = 1, 4 do wing[#wing + 1] = { 0.42 + 0.58 * t / 4, 0.33 + f + (0.02 - f * 0.15) * t - 0.02 * t * t } end
  local tips_ = { { 1, 0.31 + f * 0.4 }, { 0.72, 0.02 + f * 0.5 }, { 0.48, -0.1 + f * 0.5 }, { 0.26, -0.18 + f * 0.2 }, { 0.06, -0.3 } }
  for i = 1, #tips_ - 1 do
    local a_, b_ = tips_[i], tips_[i + 1]
    for t = 1, 5 do
      local u = t / 5
      local sag = 0.09 * sin(u * pi)
      wing[#wing + 1] = { lerp(a_[1], b_[1], u), lerp(a_[2], b_[2], u) + sag }
    end
  end
  local pts = {}
  -- the head, with two small ears, between the wings
  pts[#pts + 1] = { -0.07, 0.1 } pts[#pts + 1] = { -0.075, 0.25 } pts[#pts + 1] = { -0.035, 0.19 } pts[#pts + 1] = { 0.035, 0.19 } pts[#pts + 1] = { 0.075, 0.25 }
  for i = 1, #wing do pts[#pts + 1] = wing[i] end
  pts[#pts + 1] = { 0, -0.36 }
  for i = #wing, 1, -1 do pts[#pts + 1] = { -wing[i][1], wing[i][2] } end
  for _, q in ipairs(pts) do q[1], q[2] = q[1] * s * 0.5, q[2] * s * 0.5 end
  ink.poly(pts, true) ink.fill(tone(0.03))
end

-- A small bird standing at the origin, s about 1 cm long. kind: "robin" or "crow". Side on.
function M.perched(rng, s, facing, kind)
  ink.push() ink.scale(facing * s, s)
  local crow = kind == "crow"
  local back = crow and tone(0.04) or tone(0.3)
  ink.moveto(0.05, 0.14) ink.lineto(0.06, 0) ink.moveto(-0.07, 0.14) ink.lineto(-0.07, 0) ink.stroke(tone(0.08), 0.4)
  ink.smooth({ { -0.28, 0.3 }, { -0.62, 0.12 }, { -0.72, 0.15 }, { -0.42, 0.42 } }, true) ink.fill(back)           -- tail
  ink.smooth(ellipse_(0, 0.36, 0.33, 0.25), true) ink.fill(back)                                                     -- body
  ink.smooth(ellipse_(0.24, 0.6, 0.16, 0.15), true) ink.fill(back)                                                   -- head
  if not crow then
    ink.smooth({ { 0.34, 0.62 }, { 0.38, 0.45 }, { 0.3, 0.2 }, { 0.06, 0.12 }, { 0.1, 0.32 }, { 0.2, 0.5 } }, true) ink.fill(ink.accent(-0.02))
    ink.smooth({ { -0.28, 0.44 }, { 0.02, 0.5 }, { 0.08, 0.34 }, { -0.2, 0.28 } }, true) ink.fill(tone(0.18))
  else
    ink.smooth({ { -0.3, 0.44 }, { 0.06, 0.52 }, { 0.1, 0.32 }, { -0.28, 0.24 } }, true) ink.fill(tone(0.14))
  end
  local bl = crow and 0.24 or 0.12
  ink.poly({ { 0.36, 0.65 }, { 0.38 + bl, 0.59 }, { 0.36, 0.55 } }, true) ink.fill(tone(0.08))
  ink.circle(0.28, 0.63, 0.028) ink.fill(crow and tone(0.5) or tone(0.02))
  ink.pop()
end

-- A holly bush on the ground, about r wide each way: spiny glossy leaves, red berries.
function M.holly(rng, r, berry)
  local function leaf(x, y, ang, L)
    ink.push() ink.translate(x, y) ink.rotate(ang)
    local w_ = L * 0.34
    local pts = { { 0, 0 } }
    for _, q in ipairs({ { 0.12, 1 }, { 0.3, 0.55 }, { 0.46, 1 }, { 0.62, 0.5 }, { 0.78, 0.8 } }) do pts[#pts + 1] = { w_ * q[2], L * q[1] } end
    pts[#pts + 1] = { 0, L }
    for _, q in ipairs({ { 0.78, 0.8 }, { 0.62, 0.5 }, { 0.46, 1 }, { 0.3, 0.55 }, { 0.12, 1 } }) do pts[#pts + 1] = { -w_ * q[2], L * q[1] } end
    local t = rng.range(0.1, 0.2)
    ink.poly(pts, true) ink.fill(tone(t))
    local half = { { 0, 0 } }
    for i = 12, 7, -1 do half[#half + 1] = pts[i] end
    ink.poly(half, true) ink.fill(tone(t + 0.14))
    ink.moveto(0, 0) ink.lineto(0, L * 0.95) ink.stroke(tone(0.5), 0.2)
    ink.pop()
  end
  local n = floor(30 + r * 34)
  local ps = {}
  for k = 1, n do
    local a, d = rng.range(0, pi), rng.u() ^ 0.6
    ps[k] = { d * r * cos(a), d * r * 0.95 * sin(a), a }
  end
  table.sort(ps, function(p, q) return p[2] > q[2] end)
  for _, q in ipairs(ps) do leaf(q[1], q[2], rng.range(-60, 60) + (q[1] > 0 and -40 or 40), rng.range(0.34, 0.48)) end
  for _ = 1, floor(5 + r * 5) do
    local a, d = rng.range(0.1, pi - 0.1), rng.range(0.15, 0.85)
    local x, y = d * r * cos(a), d * r * 0.9 * sin(a)
    ink.circle(x, y, 0.065) ink.fill(berry)
    ink.circle(x - 0.02, y + 0.02, 0.018) ink.fill(white, 0.8)
  end
end

-- A snowman on the ground, h tall.
function M.snowman(rng, h, scarf)
  local rs = { h * 0.25, h * 0.19, h * 0.14 }
  local y = rs[1] * 0.85
  local at = {}
  for i, r in ipairs(rs) do
    at[i] = y
    ink.smooth(ellipse_(rng.sym(0.02), y, r, r * 0.96), true) ink.fill(white)
    ink.smooth(ellipse_(0, y, r, r * 0.96), true) ink.stroke(tone(0.62), 0.4)
    local cres = {}
    for k = 0, 8 do local a = -1.25 + 1.5 * k / 8 cres[#cres + 1] = { r * 0.97 * cos(a), y + r * 0.93 * sin(a) } end
    for k = 8, 0, -1 do local a = -1.25 + 1.5 * k / 8 cres[#cres + 1] = { r * 0.97 * cos(a) - r * 0.2 * cos(a * 0.5) * (1 - ((k - 4) / 4) ^ 2), y + r * 0.93 * sin(a) + r * 0.08 * (1 - ((k - 4) / 4) ^ 2) } end
    ink.smooth(cres, true) ink.fill(tone(0.9), 0.75)
    y = y + r + (rs[i + 1] or 0) * 0.82
  end
  local hy = at[3]
  local r3 = rs[3]
  ink.circle(-r3 * 0.35, hy + r3 * 0.2, 0.035) ink.fill(tone(0.03))
  ink.circle(r3 * 0.25, hy + r3 * 0.2, 0.035) ink.fill(tone(0.03))
  ink.poly({ { -r3 * 0.05, hy + r3 * 0.05 }, { r3 * 1.15, hy - r3 * 0.05 }, { -r3 * 0.05, hy - r3 * 0.18 } }, true) ink.fill(ink.accent(0))
  ink.smooth({ { -r3 * 0.85, hy - r3 * 0.72 }, { 0, hy - r3 * 1.02 }, { r3 * 0.85, hy - r3 * 0.72 }, { r3 * 0.85, hy - r3 * 0.98 }, { 0, hy - r3 * 1.28 }, { -r3 * 0.85, hy - r3 * 0.98 } }, true) ink.fill(scarf)
  ink.poly({ { r3 * 0.3, hy - r3 * 1.05 }, { r3 * 0.65, hy - r3 * 1.05 }, { r3 * 0.72, hy - r3 * 1.95 }, { r3 * 0.34, hy - r3 * 1.95 } }, true) ink.fill(scarf)
  for _, sd in ipairs({ -1, 1 }) do
    local ax, ay = sd * rs[2] * 0.9, at[2] + rs[2] * 0.2
    local tx, ty = ax + sd * h * 0.26, ay + h * 0.14
    ink.moveto(ax, ay) ink.lineto(tx, ty)
    ink.moveto(lerp(ax, tx, 0.65), lerp(ay, ty, 0.65)) ink.lineto(tx + sd * 0.02, ty + 0.13)
    ink.stroke(tone(0.12), 0.65)
  end
end

-- A wind line: a long easy curve ending in a curl. dir = +1 blows left to right.
function M.gust(x, y, L, dir, op)
  local pts = {}
  for k = 0, 10 do
    local t = k / 10
    pts[#pts + 1] = { x + dir * L * t, y + 0.25 * sin(t * pi * 1.3) }
  end
  local ex, ey = pts[#pts][1], pts[#pts][2]
  local r0 = L * 0.05
  for k = 1, 9 do
    local a = -pi / 2 + k * 0.72
    local r_ = r0 * (1 - k / 11)
    pts[#pts + 1] = { ex + dir * r_ * cos(a), ey + r0 + r_ * sin(a) }
  end
  ink.smooth(pts, false) ink.stroke(tone(0.62), 0.4, op or 0.55)
end

-- A heart cut into bark with a knife, I + C inside it, centered on the origin. s about 1: 2 cm wide.
-- Each cut: a dark groove, its far side catching the light, the wood showing pale where it is fresh.
function M.heart(rng, s)
  local function cut(pts, wide)
    local p = {}
    for i, q in ipairs(pts) do p[i] = { q[1] * s + rng.sym(0.012), q[2] * s + rng.sym(0.012) } end
    ink.poly(p, false) ink.stroke(tone(0.02), wide)
    local lit = {}
    for i, q in ipairs(p) do lit[i] = { q[1] + 0.022, q[2] - 0.022 } end
    ink.poly(lit, false) ink.stroke(tone(0.82), wide * 0.42)
  end
  local outline = {}
  for k = 0, 28 do
    local t = 2 * pi * k / 28
    -- the classic heart curve, squared up a little by a knife that goes in straight runs
    local hx = 16 * sin(t) ^ 3
    local hy = 13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t)
    outline[#outline + 1] = { hx * 0.062, hy * 0.062 + 0.1 }
  end
  -- years of growth have smoothed the bark inside
  local inner = {}
  for i, q in ipairs(outline) do inner[i] = { q[1] * s * 0.99, q[2] * s * 0.99 } end
  ink.poly(inner, true) ink.fill(tone(0.24), 0.92)
  cut(outline, 1.5)
  -- I
  local lx, ly = -0.48, 0.16
  cut({ { lx, ly + 0.25 }, { lx, ly - 0.25 } }, 1.2)
  cut({ { lx - 0.09, ly + 0.25 }, { lx + 0.09, ly + 0.25 } }, 0.9)
  cut({ { lx - 0.09, ly - 0.25 }, { lx + 0.09, ly - 0.25 } }, 0.9)
  -- +
  cut({ { 0, ly + 0.14 }, { 0, ly - 0.14 } }, 1)
  cut({ { -0.14, ly }, { 0.14, ly } }, 1)
  -- C
  local c = {}
  for k = 0, 9 do
    local t = (45 + 270 * k / 9) * rad
    c[#c + 1] = { 0.48 + 0.2 * cos(t), ly + 0.26 * sin(t) }
  end
  cut(c, 1.2)
end

-- A beard of Spanish moss hanging from x, y: fine gray strands, length L, wide w.
function M.beard(rng, x, y, L, w)
  -- strands gather toward a few points, so it hangs in locks and not in straight lines
  local locks = {}
  for k = 1, rng.int(2, 4) do locks[k] = { x + rng.sym(w * 0.9), L * rng.range(0.5, 1) } end
  local n = floor(12 + L * 9)
  for _ = 1, n do
    local lk = locks[rng.int(1, #locks)]
    local x0 = x + rng.sym(w)
    local l = lk[2] * rng.range(0.55, 1)
    local tx = lk[1] + rng.sym(0.05)
    local sw = rng.sym(0.14)
    streak3(x0, y + rng.sym(0.06), lerp(x0, tx, 0.45) + sw, y - l * 0.35, lerp(x0, tx, 0.8) - sw, y - l * 0.7, tx + sw * 0.5, y - l,
      0.03, 0.006, tone(rng.range(0.45, 0.82)), rng.range(0.6, 0.95))
  end
end

-- ---------------------------------------------------------------- seasonal letters
-- Set the ink for a season (a blue page stays blue). Call it before initial.draw, so tile and letter agree.
function M.season_ink(season, blue)
  local S = M.SEASONS[season or "summer"] or M.SEASONS.summer
  local c = S.bark and not blue and S.bark or (blue and { 0x24, 0x56, 0xC4 } or { 0x2F, 0x6B, 0x4F })
  ink.set_ink(c[1] / 255, c[2] / 255, c[3] / 255)
end
-- A decorate hook for initial.draw: the letter is the tree. Its shape is filled with the oak's bark,
-- a crown (or bare twigs) grows from its top, and the season dresses it as it dresses the big tree.
-- o: blue, moss.
function M.initial_for(season, o)
  o = o or {}
  season = season or "summer"
  local S = M.SEASONS[season] or M.SEASONS.summer
  return function(c)
    local rng, TS, m, cell = c.rng, c.S, c.m, c.cell
    local function U(k) return k * TS end
    local bark_ramp = ink.get_ramp()
    local function ramp_of(col)
      ink.use_ramp(ink.get_ramp())
      ink.set_ink(col[1] / 255, col[2] / 255, col[3] / 255)
      local r = ink.get_ramp()
      ink.use_ramp(bark_ramp)
      return r
    end
    local hues = {}
    if not o.blue or season == "autumn" then
      for i, col in ipairs(S.leaves or {}) do hues[i] = ramp_of(col) end
    end
    local function leaf_ramp() if hues[1] then ink.use_ramp(hues[rng.int(1, #hues)]) end end
    local old = ink.layer(5)
    -- bark, inside the letter
    c.trace() ink.clip()
    M.limb(rng.fork(), { { U(0.5), -U(0.1) }, { U(0.5), U(0.5) }, { U(0.5), U(1.1) } }, function() return U(1.3) end,
      { plate = U(0.034), stretch = 3.2, rough = 0.01, moss = 0.04, detail = 9, tone = 0.5, peel = S.peel, flat = false })
    ink.unclip()
    c.trace() ink.stroke(tone(0.04), 0.5, 0.85)
    -- the letter's top edge, column by column, and the undersides of its strokes
    local cols, under = {}, {}
    local N = 36
    for i = 0, N - 1 do
      local x = (i + 0.5) * cell
      local was = false
      for j = N - 1, 0, -1 do
        local y = (j + 0.5) * cell
        local now = c.inside(x, y)
        if now and not was and not cols[i] then cols[i] = y + cell * 0.5 end
        if was and not now then under[#under + 1] = { x, y + cell * 0.5, i } end
        was = now
      end
    end
    local tops = {}
    for i = 0, N - 1 do if cols[i] then tops[#tops + 1] = { (i + 0.5) * cell, cols[i], i } end end
    -- stay inside the tile's frame
    local f = m * 0.5
    ink.poly({ { f, f }, { TS - f, f }, { TS - f, TS - f }, { f, TS - f } }, true) ink.clip()
    local foot = U(0.135)
    -- twigs from the top of the letter, up into the crown
    local function twig(x, y, a, L, w, depth)
      local x1, y1 = x + L * cos(a), y + L * sin(a)
      local b = rng.sym(L * 0.14)
      streak3(x, y, x + L * 0.33 * cos(a) - b * sin(a), y + L * 0.33 * sin(a) + b * cos(a), x + L * 0.66 * cos(a) + b * sin(a), y + L * 0.66 * sin(a) - b * cos(a), x1, y1, w, w * 0.5, tone(0.12))
      if depth > 0 then
        twig(x1, y1, a + rng.range(0.25, 0.6), L * rng.range(0.6, 0.8), w * 0.62, depth - 1)
        twig(x1, y1, a - rng.range(0.25, 0.6), L * rng.range(0.6, 0.8), w * 0.62, depth - 1)
      end
    end
    local leafless = S.bare
    local nt = #tops
    if nt > 0 then
      local groups = {}
      for k = 1, 5 do groups[k] = tops[max(1, min(nt, floor(nt * (k - 0.5) / 5) + 1))] end
      for k, q in ipairs(groups) do
        local a = pi / 2 + (k - 3) * 0.26 + rng.sym(0.12)
        local depth = S.snap and 1 or (leafless and 3 or 2)
        twig(q[1], q[2] - U(0.01), a, U(rng.range(0.06, 0.09)), U(0.012), depth)
      end
      if not leafless then
        -- the crown: masses over the letter, back to front
        local xs0, xs1 = tops[1][1], tops[nt][1]
        local yt = 0
        for _, q in ipairs(tops) do yt = max(yt, q[2]) end
        for _, depth in ipairs({ "back", "mid", "front" }) do
          local k_ = depth == "back" and 5 or (depth == "mid" and 5 or 4)
          for i = 1, k_ do
            local x_ = lerp(max(f + U(0.06), xs0 - U(0.06)), min(TS - f - U(0.06), xs1 + U(0.06)), (i - 0.5) / k_) + rng.sym(U(0.03))
            local y_ = yt + U(depth == "back" and 0.16 or (depth == "mid" and 0.135 or 0.145)) + rng.sym(U(0.025))
            leaf_ramp()
            ink.push() ink.translate(x_, y_)
            M.clump(rng.fork(), U(0.075) * (S.size or 1), depth, { clear = function(x, y)     -- the leaves stop at the letter's top edge, so that it can be read
                local top_ = cols[floor((x_ + x) / cell)] or foot
                return 0.5 + 0.7 * (y_ + y - top_ - U(0.012)) / U(0.03)
              end, n = (depth == "back" and 0.5 or 0.72) * (S.fill or 1), leaf = U(0.042) * (S.leaf or 1) })
            ink.pop()
            ink.use_ramp(bark_ramp)
          end
        end
      end
    end
    -- the ground at the foot
    if not S.snow then
      for _ = 1, floor(26 * (S.grass or 1)) do
        local x = rng.range(f, TS - f)
        local h = U(rng.range(0.012, 0.035))
        streak3(x, foot - U(0.02), x, foot - U(0.02) + h * 0.4, x + rng.sym(U(0.006)), foot - U(0.02) + h * 0.8, x + rng.sym(U(0.012)), foot - U(0.02) + h, U(0.006), U(0.0012), tone(rng.range(0.22, 0.6)))
      end
    end
    -- a spot on the ground either side of the letter, if there is one
    local function beside(r)
      local xa, xb = TS, 0
      for _, q in ipairs(tops) do xa, xb = min(xa, q[1]), max(xb, q[1]) end
      local opts = {}
      local xl = f + r + U(0.01)
      local xr_ = TS - f - r - U(0.01)
      if not c.inside(xl + r, foot + r) and not c.inside(xl, foot + r) then opts[#opts + 1] = xl end
      if not c.inside(xr_ - r, foot + r) and not c.inside(xr_, foot + r) then opts[#opts + 1] = xr_ end
      if #opts == 0 then return nil end
      return opts[rng.int(1, #opts)]
    end
    if season == "spring" then
      for _ = 1, 8 do
        local x = rng.range(f + U(0.02), TS - f - U(0.02))
        local h = U(rng.range(0.03, 0.055))
        streak3(x, foot - U(0.02), x, foot, x, foot + h * 0.5, x, foot - U(0.02) + h, U(0.006), U(0.002), tone(0.3))
        local col = rng.chance(0.5) and white or { 0.86, 0.72, 0.26 }
        for k = 1, 5 do
          local a = 2 * pi * k / 5
          ink.circle(x + U(0.009) * cos(a), foot - U(0.02) + h + U(0.009) * sin(a), U(0.008)) ink.fill(col)
          ink.circle(x + U(0.009) * cos(a), foot - U(0.02) + h + U(0.009) * sin(a), U(0.008)) ink.stroke(tone(0.4), 0.12)
        end
      end
    elseif season == "summer" then
      local q = rng.pick(tops)
      for k = -1, 1 do
        ink.push() ink.translate(q[1] + k * U(0.1), TS * 0.74) ink.rotate(rng.sym(14)) M.sprig(rng.fork(), U(0.05), { acorns = 2 }) ink.pop()
      end
    elseif season == "autumn" then
      -- leaves on the ground and in the air, a pumpkin
      for _ = 1, 16 do
        leaf_ramp()
        ink.push() ink.translate(rng.range(f, TS - f), foot - U(0.012) + rng.sym(U(0.008))) ink.rotate(rng.range(60, 120)) M.leaf(rng, U(0.038), { tone = rng.range(0.3, 0.62) }) ink.pop()
        ink.use_ramp(bark_ramp)
      end
      for _ = 1, 8 do
        local x_, y_ = rng.range(f + U(0.03), TS - f - U(0.03)), rng.range(foot + U(0.05), U(0.66))
        if not c.inside(x_, y_) then
          leaf_ramp()
          ink.push() ink.translate(x_, y_) ink.rotate(rng.range(0, 360)) M.leaf(rng, U(0.036), { tone = rng.range(0.3, 0.62) }) ink.pop()
          ink.use_ramp(bark_ramp)
        end
      end
      local px = beside(U(0.055))
      if px then
        local orange = ramp_of({ 0xCC, 0x6E, 0x1C })
        ink.use_ramp(orange)
        ink.push() ink.translate(px, foot - U(0.03)) M.pumpkin(rng, U(0.055), rng.chance(0.6)) ink.pop()
        ink.use_ramp(bark_ramp)
      end
    elseif season == "winter" then
      -- snow along every level run of the letter's top, icicles under its strokes
      local run = {}
      local function flush_()
        if #run >= 3 then
          local top = {}
          for i, q in ipairs(run) do
            local e = max(0, sin(pi * (i - 1) / (#run - 1))) ^ 0.6
            top[#top + 1] = { q[1], q[2] + U(0.03) * e }
          end
          local out = {}
          for _, q in ipairs(top) do out[#out + 1] = q end
          for i = #run, 1, -1 do out[#out + 1] = { run[i][1], run[i][2] - U(0.006) } end
          ink.poly(out, true) ink.fill(white)
          ink.smooth(top, false) ink.stroke(tone(0.62), 0.3)
        end
        run = {}
      end
      for i, q in ipairs(tops) do
        if tops[i - 1] and abs(q[2] - tops[i - 1][2]) > cell * 1.4 then flush_() end
        run[#run + 1] = q
      end
      flush_()
      for _, q in ipairs(under) do
        if q[2] > foot + U(0.03) and rng.chance(0.5) then
          M.icicles(rng, q[1] - U(0.006), q[1] + U(0.006), q[2], U(0.05))
        end
      end
      local top = {}
      for i = 0, 16 do top[#top + 1] = { f + (TS - 2 * f) * i / 16, foot + U(0.012) * sin(i * 0.9) } end
      local out = { { f, f } }
      for _, q in ipairs(top) do out[#out + 1] = q end
      out[#out + 1] = { TS - f, f }
      ink.smooth(out, true) ink.fill(white)
      ink.smooth(top, false) ink.stroke(tone(0.6), 0.35)
      local hx = beside(U(0.075))
      if hx then
        local leafy = o.blue and bark_ramp or ramp_of({ 0x1F, 0x5C, 0x3A })
        ink.use_ramp(leafy)
        ink.push() ink.translate(hx, foot - U(0.005)) M.holly(rng, U(0.07), o.blue and ink.accent(0) or { 0.73, 0.1, 0.12 }) ink.pop()
        ink.use_ramp(bark_ramp)
      end
      local q = tops[max(1, floor(nt * rng.range(0.25, 0.75)))]
      if q then ink.push() ink.translate(q[1], q[2] + U(0.03)) M.perched(rng, U(0.13), rng.chance(0.5) and 1 or -1, "robin") ink.pop() end
    elseif season == "dead" then
      local q = tops[max(1, floor(nt * rng.range(0.25, 0.75)))]
      if q then ink.push() ink.translate(q[1], q[2]) M.perched(rng, U(0.15), rng.chance(0.5) and 1 or -1, "crow") ink.pop() end
      for _ = 1, 2 do
        ink.push() ink.translate(rng.range(f + U(0.1), TS - f - U(0.1)), rng.range(U(0.8), TS - f - U(0.05))) ink.rotate(rng.sym(18)) M.bat(rng, U(0.11), rng.sym(1)) ink.pop()
      end
    end
    -- Spanish moss from the undersides of the strokes
    if o.moss then
      local gm = ramp_of(o.blue and { 0x24, 0x56, 0xC4 } or { 0x6F, 0x7E, 0x70 })
      ink.use_ramp(gm)
      for _, q in ipairs(under) do
        if q[2] > U(0.25) and rng.chance(0.55) then M.beard(rng, q[1], q[2], U(rng.range(0.08, 0.17)), U(0.022)) end
      end
      ink.use_ramp(bark_ramp)
    end
    ink.unclip()
    ink.layer(old)
    ink.use_ramp(bark_ramp)
  end
end

-- a root running out from the flare, sinking into the ground
local function O_root(M_, rng, x, y, sd, L, w, y0_, peel)
  local g_ = y0_ or y
  local spine = { { x, y + w * 0.5 }, { x + sd * L * 0.35, lerp(y, g_, 0.5) + w * 0.12 }, { x + sd * L * 0.7, g_ + w * 0.02 }, { x + sd * L, g_ - 0.4 } }
  M_.limb(rng, spine, function(v) return w * (1 - 0.7 * v) end, { rough = 0.08, plate = 0.11, stretch = 3, moss = 0.3, peel = peel })
end

-- ---------------------------------------------------------------- one huge oak
-- Painted back to front: pale crown, limbs, dark crown, then what lives in it, then bright crown.
-- o: w, h (cm), seed, cats, keepouts, nests. Layers: 1 back, 2 limbs, 3 mid, 4 life, 5 front, 6 ground.
function M.tree(rng, o)
  ends = {}                                            -- where the stretches painted so far end
  local W, H = o.w, o.h
  M.cat_ = require("florilegium-theme-cattree").cat
  M.peek_ = require("florilegium-theme-cattree").peek
  local layout = rng.fork()
  local groundy = o.ground or 1.0
  local season = o.season or "summer"
  local S = M.SEASONS[season] or M.SEASONS.summer
  local leafless = S.bare or o.bare
  local blue = o.ink == "blue"
  if S.bark and not blue then ink.set_ink(S.bark[1] / 255, S.bark[2] / 255, S.bark[3] / 255) end
  local bark_ramp = ink.get_ramp()
  -- a color of its own, then back to the bark's
  local function ramp_of(c)
    ink.use_ramp(ink.get_ramp())                       -- so that set_ink leaves the bark's alone
    ink.set_ink(c[1] / 255, c[2] / 255, c[3] / 255)
    local r = ink.get_ramp()
    ink.use_ramp(bark_ramp)
    return r
  end
  local hues = {}
  if not blue or season == "autumn" then
    for i, c in ipairs(S.leaves or {}) do hues[i] = ramp_of(c) end
  end
  -- the trunk stands where the text boxes leave it most room, and is as thick as that room allows;
  -- if a box runs across the foot of the page, the ground is on top of that box
  local keeps = o.keepouts or {}
  local trunkw_ = o.trunkw or W * 0.2
  local basex = W * (0.46 + layout.sym(0.05))
  local filling = #keeps > 0
  if filling then
    local noise = {}
    for k = 1, 25 do noise[k] = layout.range(0, 1.2) end
    local function best_at(g)
      local avail = H - g
      local top_x, top_w, top_h, top_s
      for k = 1, 25 do
        local x = W * (0.08 + 0.84 * (k - 1) / 24)
        for _, zone in ipairs({ 0.3, 0.5 }) do
          local lo, hi = 0, W
          for _, q in ipairs(keeps) do
            if q[4] > g and q[2] < g + avail * zone then
              if q[3] <= x then lo = max(lo, q[3])
              elseif q[1] >= x then hi = min(hi, q[1]) end
            end
          end
          local gap = hi - lo
          local tw = o.trunkw or min(W * 0.2, gap * 0.42, avail * 0.25)
          local h = avail
          for _, q in ipairs(keeps) do
            if q[4] > g and x + tw * 0.75 > q[1] and x - tw * 0.75 < q[3] then h = min(h, q[2] - g) end
          end
          if x - lo > tw * 0.6 and hi - x > tw * 0.6 then
            local sc = h + tw * 3.5 - abs(x - W * 0.46) * 0.25 + noise[k] - (tw < W * 0.1 and 4 or 0)
            if h > 2 and (not top_s or sc > top_s) then top_x, top_w, top_h, top_s = x, tw, h, sc end
          end
        end
      end
      return top_x, top_w, top_h
    end
    local x0, w0, h0 = best_at(groundy)
    local lowest
    for _, q in ipairs(keeps) do
      if q[3] - q[1] > W * 0.5 and q[2] < H * 0.45 and (not lowest or q[4] > lowest) then lowest = q[4] end
    end
    if lowest and (not x0 or w0 < W * 0.1 or h0 < (H - groundy) * 0.3) then
      local g1 = lowest + 0.9
      local x1, w1, h1 = best_at(g1)
      if x1 and h1 > H * 0.3 and (not w0 or w1 > w0) then
        groundy, x0, w0 = g1, x1, w1
      end
    end
    if x0 then basex, trunkw_ = x0, w0 end
  end
  local sweep
  if filling and o.sweeps ~= false then
    local st = layout.save()
    sweep = ink.rng(layout.int(1, 1073741823))
    layout.load(st)
  end
  local nodes = M.skeleton(layout, {
    sweep = sweep,
    margin = filling and 0.45 or trunkw_ * 0.12,
    fill = filling and { w = W, h = H, ylo = groundy + max(3, (H - groundy) * 0.3), reach = o.reach or max(W, H) * 0.84 } or nil,
    envelope = { W * 0.5, H * 0.6, W * 0.6, H * 0.36, W * 0.3 },
    trunkw = trunkw_, base = { basex, groundy }, trunk = filling and (H - groundy) * 0.16 or H * 0.2, N = o.N or 1100, D = 0.6, di = 5, dk = 1.0, minbranch = 7,
    keepouts = o.keepouts, iters = 80, pipe = 1.55, inertia = o.inertia or 1.4, outward = o.outward or 0.25,
  })
  local trunkw = trunkw_
  local rmax = nodes[1].r
  -- v2: widths, by the pipe model over the whole tree, tips to base: a tip is a twig; along a run without
  -- forks a limb thickens gently toward its base; at a fork the parent is the root of the sum of its
  -- children's squares, and at least 1/0.8 of the biggest when the fork is a real one (so a child is
  -- always clearly thinner); a planned limb has its floor. The whole tree is then scaled so the trunk is
  -- as wide as the page gives it: the trunk never grows, the limbs shrink.
  -- Where a big limb or the trunk would pinch (every child of a fork under 0.7 of it), it does not narrow:
  -- it goes on a little at its full width and ends there in a cut, its children leaving below the cut.
  local WW = {}
  local function floor_of(n) return n.sweep and trunkw * (0.05 + 0.25 * (1 - n.sweep)) or 0 end
  local function widths(fl)
    for i = #nodes, 1, -1 do
      local n = nodes[i]
      local w
      if #n.kids == 0 then w = 0.06
      elseif #n.kids == 1 and not n.kids[1].stub then w = WW[n.kids[1]] + 0.022 * 0.6
      else
        local sum, big, second = 0, 0, 0
        for _, k in ipairs(n.kids) do
          if not k.stub then
            local wk = WW[k]
            sum = sum + wk * wk
            if wk > big then big, second = wk, big elseif wk > second then second = wk end
          end
        end
        w = sqrt(sum)
        if second > 0.3 * big then w = max(w, big / 0.8) end
      end
      if fl then w = max(w, floor_of(n) * fl) end
      WW[n] = w
    end
    for _, n in ipairs(nodes) do if n.stub then WW[n] = WW[n.parent] end end
  end
  widths()
  local s0 = trunkw / WW[nodes[1]]
  widths(1 / s0)
  -- v2: what leaves a stem just under a cut must leave its side: a child running within 50 degrees of the
  -- stem's axis (the old leader, a steep limb) is turned out to 50 degrees, or dropped if that would put it
  -- in text or off the page
  local function turnout(n, dx, dy, skip)
    do
      local keep_ = {}
      for _, k in ipairs(n.kids) do
        local far = k                                  -- the way it goes over its first few steps, not its first one
        for _ = 1, 5 do if far.kids[1] then far = far.kids[1] end end
        local kx, ky = far.x - n.x, far.y - n.y
        local kl = sqrt(kx * kx + ky * ky) + 1e-9
        local cs = (kx * dx + ky * dy) / kl
        local ok = true
        if cs > cos(50 * rad) and k ~= skip and not k.stub and not k.cuttop then
          local cr = dx * ky - dy * kx
          local turn = (math.acos(min(1, cs)) - 50 * rad) * (cr >= 0 and -1 or 1)
          local c_, s_ = cos(turn), sin(turn)
          local moved = {}
          local function walk(q) moved[#moved + 1] = q for _, c in ipairs(q.kids) do walk(c) end end
          walk(k)
          for _, q in ipairs(moved) do
            local rx, ry = q.x - n.x, q.y - n.y
            local nx_, ny_ = n.x + rx * c_ - ry * s_, n.y + rx * s_ + ry * c_
            for _, b in ipairs(keeps) do if nx_ > b[1] - 0.3 and nx_ < b[3] + 0.3 and ny_ > b[2] - 0.3 and ny_ < b[4] + 0.3 then ok = false end end
            if nx_ < -1 or nx_ > W + 1 or ny_ < groundy + 0.3 then ok = false end
          end
          if ok then
            for _, q in ipairs(moved) do
              local rx, ry = q.x - n.x, q.y - n.y
              q.x, q.y = n.x + rx * c_ - ry * s_, n.y + rx * s_ + ry * c_
            end
          else
            for _, q in ipairs(moved) do q.gone = true end
          end
        end
        if ok then keep_[#keep_ + 1] = k end
      end
      n.kids = keep_
    end

  end
  -- the pinches: from the trunk up, then the big limbs, at most three
  do
    local cuts = 0
    local sc_ = trunkw / WW[nodes[1]]
    local order = {}
    for _, n in ipairs(nodes) do order[#order + 1] = n end
    table.sort(order, function(a, b)
      local ta, tb = (a.trunk or a.leader) and 1 or 0, (b.trunk or b.leader) and 1 or 0
      if ta ~= tb then return ta > tb end
      if WW[a] ~= WW[b] then return WW[a] > WW[b] end
      return a.y < b.y
    end)
    local trunk_done = false
    for _, n in ipairs(order) do
      if cuts >= 3 then break end
      local wn = WW[n] * sc_
      local onstem = n.trunk or n.leader
      if wn >= 1.0 and #n.kids >= 1 and not n.stub and not n.cuttop and n.parent and not (onstem and trunk_done) then
        local big, side, cont, nbig = 0, 0, nil, 0
        for _, k in ipairs(n.kids) do
          big = max(big, WW[k]) side = max(side, WW[k] * sc_)
          if WW[k] >= 0.55 * WW[n] then nbig = nbig + 1 end
          if (k.trunk or k.leader) and (not cont or WW[k] > WW[cont]) then cont = k end
        end
        -- the trunk pinches where the stem going on is under 0.7 of it (unless it forks into a Y of two
        -- big arms); a limb, where every child is under 0.7 of it
        local pinch = big < 0.7 * WW[n]
        if onstem then pinch = (cont and WW[cont] < 0.7 * WW[n] or not cont) and nbig < 2 end
        if pinch then
          if onstem then trunk_done = true end
          local dx, dy = n.x - n.parent.x, n.y - n.parent.y
          local dl = sqrt(dx * dx + dy * dy) + 1e-9
          dx, dy = dx / dl, dy / dl
          turnout(n, dx, dy)
          local L = max(side * 1.0, wn * 0.5) + 0.5
          local prev_, d = n, 0
          local stubs = {}
          while d < L do
            d = d + 0.6
            local x, y = n.x + dx * d, n.y + dy * d
            local ok = true
            for _, q in ipairs(keeps) do if x > q[1] - 0.4 and x < q[3] + 0.4 and y > q[2] - 0.4 and y < q[4] + 0.4 then ok = false end end
            if not ok then break end
            local nn = { x = x, y = y, z = n.z, parent = prev_, kids = {}, r = n.r, stub = true, leader = n.trunk or n.leader }
            if prev_ == n then table.insert(n.kids, 1, nn) else prev_.kids = { nn } end
            nodes[#nodes + 1] = nn
            stubs[#stubs + 1] = nn
            prev_ = nn
          end
          if #stubs > 0 then prev_.cuttop = true cuts = cuts + 1 end
        end
      end
    end
    widths(1 / s0)
    for _, c in ipairs(nodes) do                     -- under every cut, not only those made here
      if c.cuttop and c.parent then
        local dx, dy = c.x - c.parent.x, c.y - c.parent.y
        local dl = sqrt(dx * dx + dy * dy) + 1e-9
        dx, dy = dx / dl, dy / dl
        local reach_ = 1.5 * WW[c] * trunkw / WW[nodes[1]]
        local m, below = c.parent, c
        while m and (c.y - m.y) < reach_ do turnout(m, dx, dy, below) below, m = m, m.parent end
      end
    end
    widths(1 / s0)
    local sc2 = trunkw / WW[nodes[1]]
    for _, n in ipairs(nodes) do WW[n] = WW[n] * sc2 end
  end
  local function W_of(n)
    local w = WW[n] or trunkw * (n.r / rmax)
    if n.stub then return w end
    if filling then                                    -- a limb near a text box narrows, it is not cut off by it
      if not n.room_ then
        local best = 99
        for _, q in ipairs(keeps) do
          local dx, dy = max(q[1] - n.x, 0, n.x - q[3]), max(q[2] - n.y, 0, n.y - q[4])
          best = min(best, sqrt(dx * dx + dy * dy))
        end
        n.room_ = best
      end
      w = min(w, max(0.1, n.room_ * 1.7))
    end
    if n.stump then return w * 1.14 end                -- a little swollen where it was cut
    -- the last few nodes of a branch run out to a point
    local up = n
    for k = 0, 3 do
      if up.stump then return w end
      if #up.kids == 0 then return w * (0.3 + 0.175 * k) end
      up = up.kids[1]
    end
    return w
  end
  -- a limb cut long ago: it ends in a roll of wound wood, and shoots go straight up from it.
  -- On the dead tree limbs have snapped instead, and nothing grows.
  local stumps = {}
  do
    local size = {}
    for i = #nodes, 1, -1 do
      local n = nodes[i]
      local c = 1
      for _, k in ipairs(n.kids) do c = c + size[k] end
      size[n] = c
    end
    local top_ = nodes[1]
    while #top_.kids == 1 do top_ = top_.kids[1] end
    local cand = {}
    local lo_w = S.snap and 0.35 or 0.45
    for _, n in ipairs(nodes) do
      local w = W_of(n)
      if n.parent and not n.sweep and not n.trunk and not n.leader and w > lo_w and w < 1.3 and size[n] > (S.snap and 6 or 18) and size[n] < #nodes * (S.snap and 0.2 or 0.1)
        and (n.x - top_.x) ^ 2 + (n.y - top_.y) ^ 2 > 9 then
        cand[#cand + 1] = n
      end
    end
    for i = #cand, 2, -1 do local j = layout.int(1, i) cand[i], cand[j] = cand[j], cand[i] end
    -- a cut limb is a sight: low in the crown, where it can be seen, unless the tree is falling apart
    if not S.snap then
      local low, high = {}, {}
      for _, n in ipairs(cand) do
        if n.y < top_.y + 5.5 and abs(n.x - top_.x) > 3 then low[#low + 1] = n else high[#high + 1] = n end
      end
      for _, n in ipairs(high) do low[#low + 1] = n end
      cand = low
    end
    local want = o.stumps or (S.snap and 16 or layout.int(1, 2))
    for _, n in ipairs(cand) do
      if #stumps >= want then break end
      local ok = not n.gone
      for _, q in ipairs(stumps) do if (q.x - n.x) ^ 2 + (q.y - n.y) ^ 2 < (S.snap and 4 or 25) then ok = false end end
      local up = n.parent
      while up and ok do if up.stump then ok = false end up = up.parent end
      if ok then
        local w = W_of(n)
        local function drop(k) k.gone = true for _, c in ipairs(k.kids) do drop(c) end end
        for _, k in ipairs(n.kids) do drop(k) end
        n.kids = {}
        n.stump = true
        n.stump_w = w
        stumps[#stumps + 1] = n
        n.stump_i = #stumps
      end
    end
    local out = {}
    for _, n in ipairs(nodes) do if not n.gone then out[#out + 1] = n end end
    nodes = out
    for _, n in ipairs(nodes) do                       -- v2: where the trunk (or one arm of its Y) was cut
      if n.cuttop and not n.stump and n.parent then
        n.stump, n.stump_w, n.kids = true, W_of(n), {}
        stumps[#stumps + 1] = n
        n.stump_i = #stumps
      end
    end
    -- the shoots: thin, nearly straight, straight up
    if not S.snap then
      for _, n in ipairs(stumps) do
        n.shoots = {}
        local w = n.stump_w
        local count = layout.int(3, 6)                 -- v2: short sprouts on every stump, no long whips
        if leafless then count = 0 end                 -- v2: bare: the stump grows its own, rooted in its lip
        for i = 1, count do
          local sprout, prev_ = {}, nil
          -- from all along the roll, fanning a little: some long whips, some barely started
          local f = (i - 0.5) / count * 2 - 1
          -- the draws of the old whips, kept so the layout's stream (and every page) stays as it was
          layout.range(0.1, 0.9) layout.sym(0.05)
          if layout.chance(0.35) then layout.int(2, 4) else layout.int(5, 11) end
          layout.range(0.1, 0.17)
          local x_, y_, lean, steps_, stepy, base_w, thin
          do                                           -- v2: short water sprouts leaning out, leafy all along, rooted in
            steps_ = layout.int(3, 5)                  -- the lip: from just under the rim across the cut, tapering to a twig
            stepy = w * layout.range(0.3, 0.8) / steps_
            lean = (f * 0.9 + layout.sym(0.15)) * stepy
            local ax_, ay_ = n.x - n.parent.x, n.y - n.parent.y
            local al_ = sqrt(ax_ * ax_ + ay_ * ay_) + 1e-9
            ax_, ay_ = ax_ / al_, ay_ / al_
            local dn = layout.range(0.02, 0.12)
            x_, y_ = n.x - ay_ * f * w * 0.36 - ax_ * dn, n.y + ax_ * f * w * 0.36 - ay_ * dn
            base_w, thin = w * layout.range(0.06, 0.09), 0.85
          end
          local bow_ = layout.sym(1)
          local zz = 0
          for k = 0, steps_ do
            local nearbox = false
            for _, q in ipairs(keeps) do
              local px, py = x_ + k * lean, y_ + k * stepy
              if px > q[1] - 0.5 and px < q[3] + 0.5 and py > q[2] - 0.5 and py < q[4] + 0.5 then nearbox = true end
            end
            if nearbox then break end
            zz = zz + (k % 2 == 0 and 1 or -1) * layout.range(0.02, 0.09) * stepy / 0.55   -- v2: a zig-zag, not a straight stick
            local nw = { x = x_ + k * lean * 1.4 + zz + 0.03 * bow_ * sin(k * 0.6) * k, y = y_ + k * stepy, z = 0, kids = {}, sprout = true, parent = prev_ or n, r = base_w * (1 - thin * k / steps_) * rmax / trunkw }
            if prev_ then prev_.kids[1] = nw end
            sprout[#sprout + 1] = nw
            prev_ = nw
          end
          if #sprout >= 3 then n.shoots[#n.shoots + 1] = sprout end
        end
      end
    end
  end
  local chs = chains(nodes)
  M.last_stumps = stumps
  local stats = { nodes = #nodes, chains = #chs }
  -- nothing below the ground, nothing in the text: every layer is clipped, keep-outs as holes
  local function holes()
    local pts = { { -2, groundy - 0.12 } }
    local nw = 40
    local gr = rng.fork()
    for i = 0, nw do pts[#pts + 1] = { W * i / nw, groundy - 0.12 + gr.sym(0.05) } end
    pts[#pts + 1] = { W + 2, groundy - 0.12 } pts[#pts + 1] = { W + 2, H + 2 } pts[#pts + 1] = { -2, H + 2 }
    ink.poly(pts, true)
    -- a hole winds the other way, so it must lie inside the region: a box under the ground is no hole
    for _, q in ipairs(o.keepouts or {}) do
      local y0 = max(q[2], groundy - 0.05)
      if q[4] > y0 then ink.poly({ { q[1], y0 }, { q[1], q[4] }, { q[3], q[4] }, { q[3], y0 } }, true) end
    end
  end
  for _, ly in ipairs({ 1, 2, 3, 4, 5 }) do
    ink.layer(ly) holes() ink.clip()
  end
  local forks = {}
  local lowbox = {}                                    -- v2: limbs lying near the ground: nothing stands in front of them
  local perches = {}                                   -- thick, nearly level stretches: where a cat lies
  ink.layer(2)
  -- a stretch of limb; a chain whose width changes a lot is painted in stretches, so that plates
  -- keep their size up a tapering trunk
  local cur_chain
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
      if isroot then                                    -- v2: the root flare, a long concave curve from the ground up
        local e = max(0, d - 1.5)
        local fl = min(1, e / (1.3 * ws[1]))
        w = w * (1 + 0.6 * (1 - fl) ^ 2.2) + 0.35 * (1 - fl) ^ 3
      end
      return w
    end
    local wm = width(0.5)
    local pwm = isroot and lerp(ws[1], ws[#ws], 0.5) or wm   -- v2: the limb's own width, not its flare: one texture all up a trunk
    for i = 1, #sp do
      if sp[i][2] - ws[i] * 0.5 < groundy + 4.0 and ws[i] > 0.12 then   -- up to a snowman's height
        lowbox[#lowbox + 1] = { sp[i][1] - ws[i] * 0.7, groundy - 0.3, sp[i][1] + ws[i] * 0.7, sp[i][2] + ws[i] * 0.6 }
      end
    end
    if wm >= 0.16 then                                  -- thin limbs too, or the bark stops short along a limb
      local kn, bl = {}, {}
      if wm > 0.8 and layout.chance(0.7) and not (cur_chain and cur_chain.list[1].sweep) then kn[1] = { layout.range(-0.5, 0.45), layout.range(0.2, 0.8), layout.range(0.55, 0.95) } end
      if isroot then bl[1] = { -0.42 + layout.sym(0.15), 0.42, 2.6 } kn = { { 0.42, 0.66, 1.05 } } end
      if wm > 1.3 and not isroot and layout.chance(0.5) then bl[1] = { layout.range(-0.5, 0.5), layout.range(0.3, 0.7), 1.7 } end
      -- a branch does not grow out of a knot, and bark near a cut runs straight
      if cur_chain then
        local function near_fork(v)
          local d, i = v * total, 1
          while i < #sp - 1 and dist[i + 1] < d do i = i + 1 end
          for k = 1, #cur_chain do
            local q = cur_chain[k][1]
            if (q.x - sp[i][1]) ^ 2 + (q.y - sp[i][2]) ^ 2 < (wm * 1.3 + 0.8) ^ 2 then return true end
          end
          return false
        end
        local kept = {}
        for _, q in ipairs(kn) do if not near_fork(q[2]) then kept[#kept + 1] = q end end
        kn = kept
        local tip_ = cur_chain.list and cur_chain.list[#cur_chain.list]
        if tip_ and tip_.stump then
          local e_ = sp[#sp]
          if (e_[1] - tip_.x) ^ 2 + (e_[2] - tip_.y) ^ 2 < 0.01 then kn, bl = {}, {} end
        end
      end
      M.limb(rng.fork(), sp, width, { knots = kn, burls = bl, moss = wm > 1.1 and 0.5 or 0.08, rough = 0.05,
        plate = pwm < 0.3 and 0.07 or max(0.1, min(0.21, pwm * 0.14)), stretch = 4.2 + 0.4 * max(0, min(1, (pwm - 0.8) / 0.5)), detail = pwm > 1.8 and 0.16 or 9, flat = pwm < 0.7, pwm = pwm, torn = not isroot, peel = S.peel })
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
      local P_, outline = tube(rng.fork(), sp, width, 0.03)
      ink.smooth(outline, true, 0.8) ink.fill(tone(0.16))
      local a_, b_ = P_(1, 0.5), select(1, P_(-1, 0.5))
      local side = (a_ < b_) and 0.45 or -0.45          -- the side toward the light
      local lit = {}
      for j = 0, 8 do local x, y = P_(side, j / 8) lit[#lit + 1] = { x, y } end
      ink.smooth(lit, false) ink.stroke(tone(0.28), max(0.2, wm * 0.2 * ink.unit() * ink.CM), 0.7)
    else
      ink.smooth(sp, false) ink.stroke(tone(0.12), max(0.3, wm * ink.CM * 0.8))
    end
  end
  -- winter: snow along the true top edge of a limb, where it is level enough to hold any;
  -- painted with the limb, so that what is in front of the limb is in front of its snow too
  local function snow_on(sp, ws)
    local pts = ink.catmull(sp, 6)
    local n = #pts
    local function flush_(run)
      if #run < 5 then return end
      local top, under = {}, {}
      for i, q in ipairs(run) do
        local f = max(0, sin(pi * (i - 1) / (#run - 1))) ^ 0.7
        top[i] = { q.x + q.nx * (q.w * 0.5 + q.t * f), q.y + q.ny * (q.w * 0.5 + q.t * f) }
        under[i] = { q.x + q.nx * (q.w * 0.5 - 0.015), q.y + q.ny * (q.w * 0.5 - 0.015) }
      end
      local out = {}
      for _, p_ in ipairs(top) do out[#out + 1] = p_ end
      for i = #under, 1, -1 do out[#out + 1] = under[i] end
      ink.poly(out, true) ink.fill(white)
      if run[1].w > 0.6 then ink.smooth(top, false) ink.stroke(tone(0.78), 0.2) end
    end
    local run = {}
    for i = 1, n do
      local p_, q_ = pts[max(1, i - 1)], pts[min(n, i + 1)]
      local tx, ty = q_[1] - p_[1], q_[2] - p_[2]
      local L = sqrt(tx * tx + ty * ty) + 1e-9
      local nx, ny = -ty / L, tx / L
      if ny < 0 then nx, ny = -nx, -ny end
      local fr = (i - 1) / max(1, n - 1) * (#sp - 1) + 1
      local k = min(#ws - 1, floor(fr))
      local w = lerp(ws[k], ws[k + 1], fr - k)
      local slope = abs(ty) / (abs(tx) + 1e-6)
      if w > 0.3 and slope < 0.9 then   -- v2: a thinner cap, and none on thin twigs, where on a white sky it reads as a stray line
        run[#run + 1] = { x = pts[i][1], y = pts[i][2], nx = nx, ny = ny, w = w, t = min(0.18, 0.02 + w * 0.2) * (1.15 - slope * 0.75) }
      else flush_(run) run = {} end
    end
    flush_(run)
  end
  -- children first: a limb comes out from behind its parent, so the parent's bark and outline stay whole
  -- more roots, drawn first, so they leave the trunk from behind it, in its own bark, and run out
  -- along the ground. Below the ground line nothing shows.
  if o.roots ~= false then
    local rr = layout.fork()
    local bx_ = nodes[1].x
    local npe = #perches
    for i = 1, rr.int(3, 5) do
      local side = i % 2 == 0 and 1 or -1
      local x0 = bx_ + side * trunkw * rr.range(0.12, 0.62)
      local L = trunkw * rr.range(0.8, 1.9)
      local sp_ = { { x0, groundy + 0.8 }, { x0 + side * L * 0.35, groundy + 0.2 }, { x0 + side * L * 0.7, groundy + 0.02 }, { x0 + side * L, groundy + 0.03 } }
      local w0 = trunkw * rr.range(0.13, 0.22)
      local clear_ = true
      for _, q in ipairs(keeps) do
        for _, p in ipairs(sp_) do
          if p[1] > q[1] - 0.2 and p[1] < q[3] + 0.2 and p[2] > q[2] - 0.2 and p[2] < q[4] + 0.2 then clear_ = false end
        end
      end
      if clear_ then stretch(sp_, { w0, w0 * 0.68, w0 * 0.3, w0 * 0.05 }, false, true, true) end
    end
    for k = #perches, npe + 1, -1 do perches[k] = nil end                  -- no cat lies on a root
  end
  for ci = #chs, 1, -1 do
    local ch = chs[ci]
    local list = ch.list
    local sp, ws = {}, {}
    cur_chain = ch
    if ch.parent_prev then
      local pp = ch.parent_prev
      local back = pp.parent or pp
      local wp = W_of(pp)
      -- start back inside the parent, along its direction, as wide as the parent will take, so
      -- that the bark flows from one into the other
      sp[1] = { lerp(pp.x, back.x, 0.45), lerp(pp.y, back.y, 0.45) } ws[1] = min(wp * 0.8, W_of(list[1]) * 2.1)
      sp[2] = { pp.x, pp.y } ws[2] = min(wp * 0.82, W_of(list[1]) * 1.55)
      if W_of(list[1]) < 0.3 then ws[1], ws[2] = W_of(list[1]) * 0.4, W_of(list[1]) * 1.2 end   -- a thin one grows out to a point inside it
      if W_of(list[1]) > 0.45 then forks[#forks + 1] = { x = pp.x, y = pp.y, w = W_of(list[1]), dx = list[1].x - pp.x, dy = list[1].y - pp.y } end
    end
    for i = 1, #list do
      if i % 2 == 1 or i == #list then
        local n = list[i]
        sp[#sp + 1] = { n.x, n.y }
        ws[#ws + 1] = W_of(n)
      end
    end
    -- a bend in thick wood is wide: the inner edge must not fold over itself
    for _ = 1, 4 do
      local s2 = {}
      for i = 2, #sp - 1 do
        local mx_, my_ = (sp[i - 1][1] + sp[i + 1][1]) / 2, (sp[i - 1][2] + sp[i + 1][2]) / 2
        local dev = sqrt((sp[i][1] - mx_) ^ 2 + (sp[i][2] - my_) ^ 2)
        local chord = sqrt((sp[i + 1][1] - sp[i - 1][1]) ^ 2 + (sp[i + 1][2] - sp[i - 1][2]) ^ 2) * 0.5 + 1e-6
        local radius = (chord * chord + dev * dev) / (2 * dev + 1e-6)
        if radius < ws[i] * 1.1 then s2[i] = { lerp(sp[i][1], mx_, 0.6), lerp(sp[i][2], my_, 0.6) } end
      end
      for i = 2, #sp - 1 do if s2[i] then sp[i] = s2[i] end end
    end
    -- a limb narrows gradually past a fork, not all at once
    for _ = 1, 3 do
      local w2 = {}
      for i = 2, #ws - 1 do w2[i] = (ws[i - 1] + 2 * ws[i] + ws[i + 1]) / 4 end
      for i = 2, #ws - 1 do ws[i] = w2[i] end
    end
    -- the trunk starts below the ground, so its cut end never shows
    if ci == 1 and #sp >= 2 then
      table.insert(sp, 1, { sp[1][1] - (sp[2][1] - sp[1][1]) * 0.5, sp[1][2] - 1.5 })
      table.insert(ws, 1, ws[1])
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
        local b2 = min(#sp, b + 2)
        for i = a, b2 do ss[#ss + 1] = sp[i] ww[#ww + 1] = ws[i] end
        if #ss >= 3 then stretch(ss, ww, ci == 1 and first, ch.parent_prev ~= nil, first)
        elseif #ss == 2 then ink.smooth(ss, false) ink.stroke(tone(0.12), max(0.3, ww[1] * ink.CM * 0.8)) end
        first = false
        a = b
      end
      if S.snow then                                   -- v2: not on the part of a limb hidden inside its parent
        if ch.parent_prev and #sp > 4 then
          local sp2, ws2 = {}, {}
          for i = 3, #sp do sp2[#sp2 + 1] = sp[i] ws2[#ws2 + 1] = ws[i] end
          snow_on(sp2, ws2)
        else snow_on(sp, ws) end
      end
    end
  end
  -- the ends of the cut limbs
  for _, n in ipairs(stumps) do
    local up = n.parent.parent or n.parent
    local ang = math.atan(n.y - up.y, n.x - up.x) / rad - 90
    local w = S.snap and n.stump_w or W_of(n)
    for _, sprout in ipairs(n.shoots or {}) do
      local sp, ws = {}, {}
      for _, q in ipairs(sprout) do sp[#sp + 1] = { q.x, q.y } ws[#ws + 1] = W_of(q) end
      stretch(sp, ws, false, true, true)
    end
    -- v2: every cut in every season is the coordinator's stump; where leafy sprouts of ours grow, none of its own
    M.stump(rng.fork(), n.x, n.y, ang, WW[n] or w, { snap = S.snap, live = not S.snap, sprouts = (#(n.shoots or {}) == 0) and ((leafless and not S.snap) and true or nil) or false })
  end
  -- bare branches end in fine twigs
  if S.twigs then
    local function twig(rg, x, y, a, L, w, depth)
      local x1, y1 = x + L * cos(a), y + L * sin(a)
      local bend = rg.sym(L * 0.18)
      streak3(x, y, x + L * 0.33 * cos(a) - bend * sin(a), y + L * 0.33 * sin(a) + bend * cos(a), x + L * 0.66 * cos(a) + bend * sin(a), y + L * 0.66 * sin(a) - bend * cos(a), x1, y1, w, w * 0.45, tone(0.14))
      if depth > 0 then
        twig(rg, x1, y1, a + rg.range(0.25, 0.6), L * rg.range(0.55, 0.8), w * 0.6, depth - 1)
        if rg.chance(S.twigs) then twig(rg, x1, y1, a - rg.range(0.25, 0.6), L * rg.range(0.55, 0.8), w * 0.6, depth - 1) end
      end
    end
    local rg = rng.fork()
    for _, n in ipairs(nodes) do
      if n.parent and not n.stump and not n.sprout then
        local w = W_of(n)
        local tip = #n.kids == 0
        if tip or (w < trunkw * 0.08 and rg.chance(0.5 * S.twigs)) then
          local a = math.atan(n.y - n.parent.y, n.x - n.parent.x) + (tip and rg.sym(0.2) or (rg.chance(0.5) and 0.7 or -0.7))
          twig(rg, n.x, n.y, a, rg.range(0.35, 0.8), max(0.025, min(0.05, w * 0.6)), tip and 3 or 2)
          if tip then twig(rg, n.x, n.y, a + rg.sym(0.9), rg.range(0.3, 0.6), 0.03, 2) end
        end
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
  for _, n in ipairs(stumps) do                        -- the leaves leave a cut limb in view
    if n.shoots then window(n.x, n.y + 1.5, 2.2) window(n.x, n.y, n.stump_w + 1)
    else window(n.x, n.y, n.stump_w + 0.5) end
  end
  -- a swing, from a limb level and low enough, with room under it
  local swing
  if o.swing ~= false then
    local seat_y = groundy + 1.5
    local best
    for _, p_ in ipairs(perches) do
      local dx = abs(p_.x - nodes[1].x)
      local h = p_.y - seat_y
      if dx > trunkw * 0.5 + 1.8 and p_.x > 2 and p_.x < W - 2 and h > 4 and abs(p_.a) < 16 then
        local clear = true
        for _, q in ipairs(o.keepouts or {}) do
          if p_.x + 1.5 > q[1] and p_.x - 1.5 < q[3] and p_.y + 0.5 > q[2] and seat_y - 0.8 < q[4] then clear = false end
        end
        if clear then
          for _, n in ipairs(nodes) do
            if abs(n.x - p_.x) < 1.3 and n.y < p_.y - p_.w * 0.5 - 0.1 and n.y > seat_y - 0.5 and W_of(n) > 0.04 then clear = false break end
          end
        end
        if clear and (not best or h < best.y - seat_y) then best = p_ end
      end
    end
    if best then
      swing = best
      window(best.x, best.y, 1.5)
      taken[#taken + 1] = best
      for i = #perches, 1, -1 do
        if (perches[i].x - best.x) ^ 2 + (perches[i].y - best.y) ^ 2 < 9 then table.remove(perches, i) end
      end
      stats.swing = true
      local a_ = best.a * rad
      local old = ink.layer(4)
      local away = best.x > nodes[1].x and 1 or -1
      M.swing(life.fork(), best.x, best.y, best.w, seat_y, a_, (S.sway or 0) * away, S.snow)
      ink.layer(old)
    end
  end
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
  -- crown: "lush" (default) closes over the limbs; "open" thins the leaves so they read through
  local open = o.crown == "open"
  for _, n in ipairs(nodes) do
    if not n.stump and not n.sprout and (#n.kids == 0 or W_of(n) < trunkw * (open and 0.05 or 0.11)) then
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
    for _, q in ipairs(y - R < groundy + 0.8 and lowbox or {}) do   -- v2: things standing on the ground
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
  -- distance from a point of a clump to the nearest text box
  local function clear_of(cx, cy)
    if not o.keepouts or #o.keepouts == 0 then return nil end
    return function(lx, ly)
      local px, py, best = cx + lx, cy + ly, 99
      for _, q in ipairs(o.keepouts) do
        local dx, dy = max(q[1] - px, 0, px - q[3]), max(q[2] - py, 0, py - q[4])
        best = min(best, sqrt(dx * dx + dy * dy))
      end
      return best
    end
  end
  local bough = {}                                     -- open crown: the limbs the leaves stay off
  if open then
    for _, n in ipairs(nodes) do
      if W_of(n) > trunkw * 0.15 then bough[#bough + 1] = { n.x, n.y, W_of(n) } end
    end
  end
  local function on_bough(x, y, R)
    for _, q in ipairs(bough) do
      if (q[1] - x) ^ 2 + (q[2] - y) ^ 2 < (q[3] + R * 0.6) ^ 2 then return true end
    end
    return false
  end
  local function clump_at(layer, depth, x, y, R, n)
    if leafless then return end
    R, n = R * (S.size or 1), n * (S.fill or 1)
    if open and depth ~= "back" and on_bough(x, y, R) then return end
    if depth ~= "back" and y - R * 0.7 < forky and abs(x - tx0) < trunkw * 0.7 + R then return end
    if blocked(x, y, R * 1.1, depth) then
      R = R * 0.62                                     -- a small mass still clothes a branch near a box
      if blocked(x, y, R * 1.1, depth) then return end
    end
    local old = ink.layer(layer)
    if hues[1] then ink.use_ramp(hues[layout.int(1, #hues)]) end
    ink.push() ink.translate(x, y) M.clump(rng.fork(), R, depth, { n = n, leaf = (o.leaf or 0.42) * (S.leaf or 1), clear = clear_of(x, y) }) ink.pop()
    ink.use_ramp(bark_ramp)
    ink.layer(old)
    placed[depth] = placed[depth] + 1
    return true
  end
  -- v2: the crown is fuller toward its top: low down, inside, a few masses; at the top, many and full
  local topy_ = forky
  for _, b in ipairs(tips) do topy_ = max(topy_, b.y) end
  for _, b in ipairs(tips) do
    local hf = max(0, min(1, (b.y - forky) / max(1, topy_ - forky)))
    local g = lerp(0.82, 1.1, hf)
    if layout.chance(0.3 + 0.7 * hf) then clump_at(1, "back", b.x + layout.sym(1.2), b.y + layout.range(0.3, 1.6), layout.range(1.5, 2.2) * g, 0.3) end
    b.shown = clump_at(3, "mid", b.x + layout.sym(0.7), b.y + layout.sym(0.5), layout.range(1.2, 1.75) * g, 0.42)
    -- bright masses only part-way round, so limbs and what sits on them show between them
    if layout.chance((open and 0.55 or 0.78) * lerp(0.55, 1.2, hf)) then
      b.shown = clump_at(5, "front", b.x + layout.sym(0.6), b.y + layout.range(0, 0.7), layout.range(1, 1.5) * g, 0.8) or b.shown
    end
    if hf > 0.7 and layout.chance(0.5) then           -- a dome over the top
      clump_at(5, "front", b.x + layout.sym(0.9), b.y + layout.range(0.6, 1.3), layout.range(0.8, 1.2), 0.7)
    end
  end
  -- no bare ends: a branch tip with no mass near it gets a small one
  do
    local done_ = {}
    for _, n in ipairs(nodes) do
      if #n.kids == 0 and n.y > forky then
        local near = false
        for _, b in ipairs(tips) do if (b.x - n.x) ^ 2 + (b.y - n.y) ^ 2 < 0.6 and (b.shown or not open) then near = true break end end
        for _, q in ipairs(done_) do if (q[1] - n.x) ^ 2 + (q[2] - n.y) ^ 2 < 0.8 then near = true break end end
        local clear = not blocked(n.x, n.y, open and 0.72 or 0.45)
        for _, q in ipairs(windows) do if (q[1] - n.x) ^ 2 + (q[2] - n.y) ^ 2 < (q[3] * 0.75) ^ 2 then clear = false end end
        if clear and not near and not leafless and not n.stump then
          done_[#done_ + 1] = { n.x, n.y }
          local old = ink.layer(5)
          if hues[1] then ink.use_ramp(hues[layout.int(1, #hues)]) end
          ink.push() ink.translate(n.x, n.y) M.clump(rng.fork(), open and 0.8 or 0.5, "front", { n = 0.8, leaf = (o.leaf or 0.42) * (S.leaf or 1), clear = clear_of(n.x, n.y) }) ink.pop()
          ink.use_ramp(bark_ramp)
          ink.layer(old)
        end
      end
    end
    stats.endtufts = #done_
  end
  stats.clumps = placed
  -- leaves on the shoots
  if not leafless then
    for _, n in ipairs(stumps) do
      for _, sprout in ipairs(n.shoots or {}) do
        local start = 2
        for i = start, #sprout do
          local q = sprout[i]
          if not blocked(q.x, q.y, 0.5, "back") then
            local old = ink.layer(5)
            if hues[1] then ink.use_ramp(hues[layout.int(1, #hues)]) end
            ink.push() ink.translate(q.x, q.y) M.clump(rng.fork(), 0.22, "front", { n = 0.45, leaf = (o.leaf or 0.42) * 0.8 * (S.leaf or 1), clear = clear_of(q.x, q.y) }) ink.pop()
            ink.use_ramp(bark_ramp)
            ink.layer(old)
          end
        end
      end
    end
  end
  -- the heart: I + C, cut into the trunk years ago. o.heart true: always; false: never; else now and then
  -- (one tree in twelve). It is never wider than about half the wood it is cut into, and left out when that
  -- would make it too small to read
  if o.heart == true or (o.heart == nil and layout.chance(0.08)) then
    local hy = layout.range(groundy + 3.2, groundy + 3.2 + max(0.1, trunkw * 0.9))
    local hx, hn
    -- on the trunk: with sweep limbs, a node at this height may be far out along one
    local swept = false
    for _, n in ipairs(nodes) do if n.sweep then swept = true break end end
    for _, n in ipairs(swept and chs[1].list or nodes) do
      if n.y >= hy then hx, hn = n.x, n break end
    end
    if hx then
      local wood = W_of(hn)
      hx = hx + layout.range(-0.12, 0.12) * min(trunkw, wood)
      local hs = min(layout.range(0.72, 0.9) * trunkw / 4.3, wood * 0.5 / 2)      -- M.heart is 2 cm wide at s 1
      if hs >= 0.22 and not blocked(hx, hy, 1.4) then
        local old = ink.layer(2)
        ink.push() ink.translate(hx, hy) ink.rotate(layout.sym(11)) M.heart(layout.fork(), hs) ink.pop()
        ink.layer(old)
        stats.heart = true
      end
    end
  end
  -- Spanish moss: gray beards from the limbs
  if o.spanishmoss then
    local gm = ramp_of(blue and { 0x24, 0x56, 0xC4 } or { 0x6F, 0x7E, 0x70 })
    local rg = rng.fork()
    local old = ink.layer(5)
    ink.use_ramp(gm)
    local beards = 0
    for _, n in ipairs(nodes) do
      local w = W_of(n)
      if n.parent and w > 0.05 and w < 1.4 and n.y > groundy + 5 and rg.chance(leafless and 0.4 or 0.15) then
        local x_, y_ = n.x, n.y - w * 0.3
        local L = rg.range(0.9, 2.8)
        if not blocked(x_, y_ - L * 0.5, L * 0.55) then
          beards = beards + 1
          M.beard(rg, x_, y_, L, max(0.25, min(0.75, w * 0.8)))
        end
      end
    end
    ink.use_ramp(bark_ramp)
    ink.layer(old)
    stats.beards = beards
  end
  -- where the trunk is at a height, and whether a point is on it
  local trunk_list = chs[1].list
  local function trunk_at(y_)
    for _, n in ipairs(trunk_list) do
      if n.y >= y_ then
        local flare = y_ < groundy + 3 and (groundy + 3 - y_) * 0.8 or 0
        return n.x, W_of(n) * 0.5 + 0.35 + flare
      end
    end
    local n = trunk_list[#trunk_list]
    return n.x, W_of(n) * 0.5 + 0.35
  end
  local function on_trunk(x_, y_)
    local c_, h_ = trunk_at(y_)
    return abs(x_ - c_) < h_
  end
  -- autumn: leaves in the air, on their way down
  if S.fall then
    local rg = rng.fork()
    local old = ink.layer(5)
    for _ = 1, floor(W * S.fall) do
      local x_, y_ = rg.range(0.5, W - 0.5), rg.range(groundy + 0.6, H * 0.55)
      if not blocked(x_, y_, 0.4) and not on_trunk(x_, y_) then
        ink.use_ramp(hues[rg.int(1, #hues)])
        ink.push() ink.translate(x_, y_) ink.rotate(rg.range(0, 360)) M.leaf(rg, 0.34, { tone = rg.range(0.3, 0.6) }) ink.pop()
        ink.use_ramp(bark_ramp)
      end
    end
    ink.layer(old)
  end
  local extras = o.extras ~= false
  local xr = rng.fork()
  -- open air: clear of limbs, trunk, leaves and text
  local function open_air(x_, y_, r)
    if blocked(x_, y_, r, "back") then return false end
    if swing and abs(x_ - swing.x - (S.sway or 0) * 0.5 * (swing.x > nodes[1].x and 1 or -1)) < 1.3 + (S.sway or 0) * 0.5 + r then return false end
    for _, n in ipairs(nodes) do
      local d = W_of(n) * 0.5 + r
      if (n.x - x_) ^ 2 + (n.y - y_) ^ 2 < d * d then return false end
    end
    if not leafless then
      for _, b in ipairs(tips) do if (b.x - x_) ^ 2 + (b.y - y_) ^ 2 < (2.4 + r) ^ 2 then return false end end
    end
    return true
  end
  -- wind: lines in the air, leaves strung along them
  if extras and S.wind then
    local dir = xr.chance(0.5) and 1 or -1
    local old = ink.layer(5)
    for g_ = 1, 3 do
      local gy = groundy + xr.range(1.5, H * 0.32)
      local L = xr.range(5, 9)
      if dir > 0 then xr.range(0.5, W * 0.4) else xr.range(W * 0.6, W - 0.5) end   -- an old draw, kept for the stream
      -- all on one side of the trunk, the wider one at this height
      local tc, th = trunk_at(gy)
      local x0_, x1_
      if tc > W / 2 then x0_, x1_ = 0.4, tc - th - 0.6 else x0_, x1_ = tc + th + 0.6, W - 0.4 end
      L = min(L, (x1_ - x0_) / 1.12)
      local gx = dir > 0 and x0_ or x1_
      if L > 3 and not blocked(gx + dir * L * 0.5, gy, L * 0.55) then
        M.gust(gx, gy, L, dir)
        for _ = 1, xr.int(6, 11) do
          local t = xr.u()
          local lx, ly = gx + dir * L * t, gy + 0.25 * sin(t * pi * 1.3) + xr.sym(0.35)
          if not on_trunk(lx, ly) then
          ink.use_ramp(hues[xr.int(1, #hues)])
          ink.push() ink.translate(lx, ly) ink.rotate(-90 * dir + xr.sym(45)) M.leaf(xr, 0.32, { tone = xr.range(0.3, 0.6) }) ink.pop()
          ink.use_ramp(bark_ramp)
          end
        end
      end
    end
    ink.layer(old)
  end
  -- bats, a loose flock below and beside the crown
  if extras and S.bats then
    local old = ink.layer(5)
    local cx, cy = xr.range(W * 0.2, W * 0.8), xr.range(H * 0.3, H * 0.6)
    local flock = {}
    for _ = 1, S.bats do
      for _ = 1, 40 do
        local x_, y_ = cx + xr.sym(W * 0.5), cy + xr.sym(H * 0.32)
        local ok = x_ > 0.6 and x_ < W - 0.6 and y_ < H - 0.6 and y_ > groundy + 3 and open_air(x_, y_, 0.55)
        for _, q in ipairs(flock) do if (q[1] - x_) ^ 2 + (q[2] - y_) ^ 2 < 1.2 then ok = false end end
        if ok then
          flock[#flock + 1] = { x_, y_ }
          ink.push() ink.translate(x_, y_) ink.rotate(xr.sym(22)) M.bat(xr, xr.range(0.75, 1.15), xr.sym(1)) ink.pop()
          break
        end
      end
    end
    ink.layer(old)
  end
  -- birds on level limbs
  if extras and S.birds then
    local spots = {}
    for _, n in ipairs(nodes) do
      local w = W_of(n)
      if n.parent and not n.stump and not n.sprout and w > 0.14 and w < 1 and n.y > groundy + 5 and n.x > 1 and n.x < W - 1 then
        local slope = abs(n.y - n.parent.y) / (abs(n.x - n.parent.x) + 1e-6)
        if slope < 0.45 and not blocked(n.x, n.y + 0.5, 0.6, "back") then spots[#spots + 1] = { n.x, n.y + w * 0.48 } end
      end
    end
    for i = #spots, 2, -1 do local j = xr.int(1, i) spots[i], spots[j] = spots[j], spots[i] end
    local got = {}
    local old = ink.layer(4)
    for _, q in ipairs(spots) do
      if #got >= S.nbirds then break end
      local ok = true
      for _, g_ in ipairs(got) do if (g_[1] - q[1]) ^ 2 + (g_[2] - q[2]) ^ 2 < 16 then ok = false end end
      if ok then
        got[#got + 1] = q
        ink.push() ink.translate(q[1], q[2]) M.perched(xr, S.birds == "crow" and xr.range(1, 1.25) or xr.range(0.9, 1.1), xr.chance(0.5) and 1 or -1, S.birds) ink.pop()
      end
    end
    ink.layer(old)
    stats.birds = #got
  end
  -- icicles under the limbs
  if extras and S.icicles then
    local old = ink.layer(4)
    for _, n in ipairs(nodes) do
      local w = W_of(n)
      if n.parent and not n.sprout and w > 0.16 and n.y > groundy + 3 and xr.chance(0.32) then
        local slope = abs(n.y - n.parent.y) / (abs(n.x - n.parent.x) + 1e-6)
        if slope < 0.5 then
          local yy = n.y - w * 0.47
          local air_below = not blocked(n.x, yy - 0.3, 0.45, "back")
          for _, m in ipairs(nodes) do
            if m ~= n and abs(m.x - n.x) < 0.5 + W_of(m) * 0.5 and m.y < yy + W_of(m) * 0.5 and m.y > yy - 1 then air_below = false break end
          end
          if air_below then M.icicles(xr, n.x - 0.25, n.x + 0.25, yy, min(0.42, 0.18 + w * 0.25)) end
        end
      end
    end
    ink.layer(old)
  end
  -- butterflies and bees, in the open air
  if extras and (S.butterflies or S.bees) then
    local old = ink.layer(5)
    local function air()
      for _ = 1, 12 do
        local x_, y_ = xr.range(1, W - 1), xr.range(groundy + 0.8, groundy + 7)
        if abs(x_ - nodes[1].x) > trunkw * 0.8 + 0.5 and open_air(x_, y_, 0.5) then return x_, y_ end
      end
    end
    for _ = 1, S.butterflies or 0 do
      local x_, y_ = air()
      if x_ then
        local f = xr.fork()
        ink.push() ink.translate(x_, y_) ink.rotate(xr.sym(35))
        ink.in_accent(function() flora.butterfly(f, xr.range(0.42, 0.6)) end)
        ink.pop()
      end
    end
    for _ = 1, S.bees or 0 do
      local x_, y_ = air()
      if x_ then ink.push() ink.translate(x_, y_) ink.rotate(xr.sym(35)) flora.bee(xr.fork(), xr.range(0.3, 0.42)) ink.pop() end
    end
    ink.layer(old)
  end
  -- the dead tree: shelf fungus up the trunk
  if season == "dead" then
    local rg = rng.fork()
    local old = ink.layer(2)
    for _ = 1, 5 do
      local fy = rg.range(groundy + 1.5, groundy + 7)
      local sd = rg.chance(0.5) and 1 or -1
      local fx
      for _, n in ipairs(nodes) do if n.y >= fy then fx = n.x break end end
      if fx then
        local r_ = rg.range(0.28, 0.6)
        local px, py = fx + sd * trunkw * 0.42, fy
        ink.smooth({ { px - r_ * 0.1 * sd, py + r_ * 0.3 }, { px + sd * r_ * 0.7, py + r_ * 0.26 }, { px + sd * r_, py }, { px + sd * r_ * 0.5, py - r_ * 0.1 }, { px - r_ * 0.1 * sd, py - r_ * 0.08 } }, true)
        ink.fill(ink.accent(0.1))
        ink.smooth({ { px, py + r_ * 0.08 }, { px + sd * r_ * 0.6, py + r_ * 0.08 }, { px + sd * r_ * 0.9, py - r_ * 0.02 } }, false)
        ink.stroke(ink.accent(-0.3), 0.4, 0.7)
      end
    end
    ink.layer(old)
  end
  -- eyes in the dark of a mid mass, between the bright ones
  ink.layer(4)
  local neyes = o.eyes or (leafless and 0 or 1)
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
  for i = 1, min(o.sprigs or (leafless and 0 or 7), #under), 1 do
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
    O_root(M, rng.fork(), bx + sd * off, groundy + layout.range(0.05, 0.5), sd, L_, w_, groundy, S.peel)
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
  for _ = 1, floor(W * 3.4 * (S.grass or 1)) do
    local x = ground.range(0, W)
    if not blocked(x, groundy, 0.5) then
      for _ = 1, 3 do
        local h, lean = ground.range(0.14, 0.42), ground.sym(0.16)
        streak3(x, groundy - 0.12, x + lean * 0.2, groundy + h * 0.4, x + lean * 0.6, groundy + h * 0.75, x + lean, groundy + h, 0.05, 0.006, tone(ground.range(0.2, 0.62)))
        x = x + ground.sym(0.13)
      end
    end
  end
  -- autumn's fallen leaves, on the grass
  if S.litter then
    for _ = 1, floor(W * S.litter) do
      local x = ground.range(0, W)
      if not blocked(x, groundy, 0.4) then
        ink.use_ramp(hues[ground.int(1, #hues)])
        ink.push() ink.translate(x, groundy - 0.08 + ground.sym(0.1)) ink.rotate(ground.range(60, 120) * (ground.chance(0.5) and 1 or -1)) M.leaf(ground, 0.3, { tone = ground.range(0.3, 0.62) }) ink.pop()
        ink.use_ramp(bark_ramp)
      end
    end
  end
  -- winter's snow, over the roots and the grass
  if S.snow then
    local top = {}
    local nw = 40
    for i = 0, nw do
      local x = W * i / nw
      local hump = 0.28 * exp(-((x - bx) / (trunkw * 1.3)) ^ 2)
      top[#top + 1] = { x, groundy + 0.12 + hump + ground.sym(0.035) + 0.05 * sin(i * 0.7) }
    end
    local out = { { -1, groundy - 0.5 } }
    for _, p in ipairs(top) do out[#out + 1] = p end
    out[#out + 1] = { W + 1, groundy - 0.5 }
    ink.smooth(out, true) ink.fill(white)
    ink.smooth(top, false) ink.stroke(tone(0.72), 0.45)
    -- a few flakes, seen only where there is something behind them
    for _ = 1, floor(W * H * 0.14) do
      local x, y = ground.range(0, W), ground.range(groundy + 0.5, H)
      if not blocked(x, y, 0.15) then ink.circle(x, y, ground.range(0.018, 0.034)) ink.fill(tone(0.86)) end
    end
  end
  local props_x = {}
  for _ = 1, floor(W / 3 * (S.props or 1)) do
    local x = ground.range(0.6, W - 0.6)
    if abs(x - bx) > trunkw * 0.7 and not blocked(x, groundy, 0.5) then
      props_x[#props_x + 1] = x
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
  -- what stands on the ground, each where nothing else is
  if extras then
    local held = {}
    for _, x in ipairs(props_x) do held[#held + 1] = { x, 0.35 } end
    local function spot(r, h)
      for _ = 1, 30 do
        local x = ground.range(r + 0.3, W - r - 0.3)
        local ok = abs(x - bx) > trunkw * 0.75 + r + 0.3 and not blocked(x, groundy + h / 2, max(r, h / 2) + 0.2, "back")
        if swing and abs(x - swing.x - (S.sway or 0) * (swing.x > bx and 1 or -1)) < r + 1.8 then ok = false end
        for _, q in ipairs(held) do if abs(q[1] - x) < q[2] + r + 0.25 then ok = false end end
        if ok then held[#held + 1] = { x, r } return x end
      end
    end
    if S.pumpkins then
      local orange = ramp_of({ 0xCC, 0x6E, 0x1C })
      for i = 1, ground.int(3, 5) do
        local r = ground.range(0.55, 1.05)
        local x = spot(r, r * 2)
        if x then
          ink.use_ramp(orange)
          ink.push() ink.translate(x, groundy - 0.1) M.pumpkin(ground, r, i == 1) ink.pop()
          ink.use_ramp(bark_ramp)
        end
      end
    end
    if S.flowers then
      for _ = 1, floor(W * 2.2) do
        local x = ground.range(0, W)
        if not blocked(x, groundy, 0.5) and abs(x - bx) > trunkw * 0.6 then
          local h = ground.range(0.3, 0.7)
          streak3(x, groundy - 0.1, x, groundy + h * 0.4, x, groundy + h * 0.7, x + ground.sym(0.05), groundy + h, 0.03, 0.012, tone(0.3))
          local c = ground.chance(0.3) and ink.accent(0.1) or (ground.chance(0.5) and white or { 0.86, 0.72, 0.26 })
          for k = 1, 5 do
            local a = 2 * pi * k / 5
            ink.circle(x + 0.075 * cos(a), groundy + h + 0.075 * sin(a), 0.06) ink.fill(c)
            ink.circle(x + 0.075 * cos(a), groundy + h + 0.075 * sin(a), 0.06) ink.stroke(tone(0.4), 0.15)
          end
          ink.circle(x, groundy + h, 0.04) ink.fill({ 0.86, 0.6, 0.15 })
        end
      end
    end
    if S.snow then
      -- piles: drifts against the trunk and along the ground
      local function pile(cx, r, h)
        local top = {}
        for k = 0, 10 do
          local t = k / 10
          top[#top + 1] = { cx - r + 2 * r * t, groundy + 0.08 + h * max(0, sin(t * pi)) ^ 1.3 * (1 + ground.sym(0.06)) }
        end
        local out = { { cx - r, groundy - 0.1 } }
        for _, q in ipairs(top) do out[#out + 1] = q end
        out[#out + 1] = { cx + r, groundy - 0.1 }
        ink.smooth(out, true) ink.fill(white)
        ink.smooth(top, false) ink.stroke(tone(0.68), 0.4)
        ink.smooth({ top[4], top[6], top[8] }, false) ink.stroke(tone(0.86), 0.9, 0.7)
      end
      pile(bx - trunkw * 0.52, trunkw * 0.42, 0.55)
      pile(bx + trunkw * 0.6, trunkw * 0.5, 0.75)
      for _ = 1, ground.int(3, 5) do
        local r = ground.range(1, 2.4)
        local x = ground.range(0, W)
        if not blocked(x, groundy + 0.3, r) then pile(x, r, ground.range(0.25, 0.6)) end
      end
    end
    if S.snowman then
      local h = ground.range(2.8, 3.6)
      local x = spot(h * 0.5, h)
      if x then
        local berry = blue and ink.accent(0) or { 0.73, 0.1, 0.12 }
        ink.push() ink.translate(x, groundy - 0.02) M.snowman(ground, h, berry) ink.pop()
        stats.snowman = true
      end
    end
    if S.holly then
      local leafy = blue and bark_ramp or ramp_of({ 0x1F, 0x5C, 0x3A })
      local berry = blue and ink.accent(0) or { 0.73, 0.1, 0.12 }
      for _ = 1, ground.int(2, 3) do
        local r = ground.range(0.8, 1.35)
        local x = spot(r, r * 1.2)
        if x then
          ink.use_ramp(leafy)
          ink.push() ink.translate(x, groundy) M.holly(ground, r, berry) ink.pop()
          ink.use_ramp(bark_ramp)
          -- snow settled on it
          for _ = 1, 4 do                              -- snow settled on it, in patches
            local a_ = ground.range(0.5, pi - 0.5)
            local px, py = x + r * 0.8 * cos(a_), groundy + r * 0.84 * sin(a_) + 0.08
            ink.smooth(ellipse_(px, py, r * ground.range(0.14, 0.24), r * 0.07), true) ink.fill(white)
          end
        end
      end
    end
  end
  stats.forks = #forks
  return stats, forks, nodes, W_of
end

-- ---------------------------------------------------------------- the theme
-- \usepackage[grown,theme=oak]{florilegium}: every page a whole oak, grown around the text
-- block the way a tree grows around a wall. The oak has its own greens and browns unless the
-- document sets an ink of its own (\definecolor{ink}...), which then paints the bark and the
-- summer leaves. \florilegiumage picks the season: 0 spring, 0.5 summer, 1 autumn, and past
-- the package's usual range 1.5 winter, 2 a dead tree. The option aging runs spring to autumn.
local DELFT = { 0x24 / 255, 0x56 / 255, 0xC4 / 255 }
local function same_ramp(a, b)                 -- xcolor's rounding moves a color a little on its way here
  for i = 0, 100 do
    for k = 1, 3 do if math.abs(a[i][k] - b[i][k]) > 0.01 then return false end end
  end
  return true
end
local function own_ink()                       -- has the document chosen an ink?
  local now = ink.get_ramp()
  ink.set_ink(DELFT[1], DELFT[2], DELFT[3])
  local delft = ink.get_ramp()
  ink.use_ramp(now)
  return not same_ramp(now, delft)
end
local function season_of(age)
  if not age then return "summer" end
  if age < 0.25 then return "spring" elseif age < 0.75 then return "summer"
  elseif age < 1.25 then return "autumn" elseif age < 1.75 then return "winter" end
  return "dead"
end

-- A composition of its own (florilegium-grow.lua hands it the page). In layout coordinates, so
-- a mirrored page is only the last transform. Keep-outs: the text, from the head rule down to
-- the last line, and the page number.
function M.page(g, _, force_ink)
  local season = season_of(g.age)
  local ramp, blue = ink.get_ramp(), force_ink or own_ink()
  if not blue then M.season_ink(season) end
  ink.set_transform(ink.page_transform(g.mirror and g.pw))
  local bottom = g.ybot
  if g.spill == 1 and g.spilly > g.ybot then bottom = g.spilly - 0.5 end
  local mid = (g.textleft + g.textright) / 2
  local keepouts = { { g.textleft - 0.25, bottom, g.textright + 0.25, g.headrule + 0.7 } }
  keepouts[#keepouts + 1] = { g.colright - 0.5, g.headrule - 0.6, g.textleft, g.headrule + 0.7 }   -- the head rule's leaf
  if bottom == g.ybot then keepouts[#keepouts + 1] = { mid - 0.8, g.footy - 0.4, mid + 0.8, g.footy + 0.5 } end
  local D, visitors = g.density or 1, g.visitors ~= false
  local e = { t0 = 0, dur = 1 }
  if g.anim then ink.record(true) ink.tag({ e, 0 }) end
  M.tree(ink.rng(g.seed * 7919 + 13), { w = g.pw, h = g.ph, keepouts = keepouts, season = season, ink = blue and "blue" or nil,
    crown = D < 0.7 and "open" or nil, bare = D < 0.25 or nil,
    cats = visitors and (D < 0.5 and 1 or 2) or 0, eyes = (not visitors) and 0 or nil, extras = visitors })
  local r = {}
  if g.anim then
    ink.tag(nil)
    r = { rec = ink.take_recording(), total = 1 }
  else
    ink.flush()
  end
  ink.use_ramp(ramp)
  return r
end

-- The initial: the letter is the tree, in the season of the page. florilegium.lua calls
-- before_initial first, because the letter itself is painted before M.initial decorates it.
local initial_opts
function M.before_initial(age, force_ink)
  local season = season_of(age)
  local ramp, blue = ink.get_ramp(), force_ink or own_ink()
  if not blue then M.season_ink(season) end
  initial_opts = { season, { blue = blue } }
  return function() ink.use_ramp(ramp) end
end
function M.initial(c) return M.initial_for(initial_opts[1], initial_opts[2])(c) end

return M

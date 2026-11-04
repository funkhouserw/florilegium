-- theme-oldcats.lua -- a theme for florilegium: old cats filling the page.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
-- A cat is a template (a pose: spine, limbs, tail, head, as a skeleton with widths) and genes (a
-- coat, a build, a face, its age). Any template takes any genes, so a page never repeats.
-- Coats follow how cats are actually patterned: a base color (dilute or not), tabby stripes across
-- the spine or blotches, tortoiseshell patches, calico (patches on white), tuxedo, van (white
-- with color on the head and tail), colorpoint. Age shows as a grey muzzle and brow, a cloudy eye,
-- hips and shoulders under thin fur or a sagging belly, a torn ear, scruffy fur.
-- Use: \usepackage[grown,theme=oldcats]{florilegium}, or scene.lua (grows = "cats").

local ink = require("ink")
local flora = require("flora")
local M = {}

local sin, cos, sqrt, pi, abs, floor, max, min = math.sin, math.cos, math.sqrt, math.pi, math.abs, math.floor, math.max, math.min
local atan = math.atan
local tone, white = ink.tone, ink.white
local streak3 = flora.streak3
local rad = pi / 180
local function lerp(a, b, t) return a + (b - a) * t end
local LIGHT = { -0.6, 0.8 }                            -- toward the light, in the page

-- ---------------------------------------------------------------- color
local function mix(a, b, t) return { lerp(a[1], b[1], t), lerp(a[2], b[2], t), lerp(a[3], b[3], t) } end
local PIGMENT = {
  black = { 0.15, 0.15, 0.19 }, blue = { 0.43, 0.47, 0.55 }, brown = { 0.36, 0.26, 0.2 }, lilac = { 0.65, 0.61, 0.62 },
  ginger = { 0.8, 0.47, 0.19 }, cream = { 0.92, 0.79, 0.58 }, sand = { 0.72, 0.6, 0.44 }, grey = { 0.56, 0.56, 0.56 },
  white = { 0.97, 0.95, 0.91 }, seal = { 0.27, 0.2, 0.17 },
}
local PAPERWHITE = { 1, 1, 1 }
-- in the ink: every pigment becomes the tone of its lightness
local function c_of(g, name, k)
  local p = type(name) == "table" and name or PIGMENT[name]
  if k then p = k < 0 and mix(p, { 0, 0, 0.04 }, -k) or mix(p, PAPERWHITE, k) end
  local pale = ink.get_pale()
  if g.inked then
    return tone(max(0.02, min(0.97, (0.3 * p[1] + 0.55 * p[2] + 0.15 * p[3]) ^ 1.15)))
  end
  if pale > 0 then return mix(p, PAPERWHITE, pale) end
  return p
end

-- ---------------------------------------------------------------- genes
local COATS = {
  { "solid", 3 }, { "tabby", 6 }, { "blotched", 2 }, { "tortie", 3 }, { "calico", 3 }, { "tuxedo", 3 }, { "van", 1.5 }, { "point", 1.5 }, { "smoke", 1 },
}
local function pick_w(rng, t)
  local tot = 0
  for _, e in ipairs(t) do tot = tot + e[2] end
  local u, i = rng.u() * tot, 1
  while i < #t and u > t[i][2] do u = u - t[i][2] i = i + 1 end
  return t[i][1]
end
function M.genes(rng, o)
  o = o or {}
  local coat = o.coat or pick_w(rng, COATS)
  local g = { coat = coat, inked = o.inked }
  local dilute = rng.chance(0.3)
  if coat == "solid" then g.base = rng.pick({ "black", "black", dilute and "blue" or "brown", "ginger", "cream", "white", "grey", "blue" })
  elseif coat == "tabby" or coat == "blotched" then
    local k = rng.u()
    if k < 0.45 then g.base, g.mark = "sand", "brown"
    elseif k < 0.7 then g.base, g.mark = "ginger", { 0.6, 0.29, 0.08 }
    elseif k < 0.88 then g.base, g.mark = "lilac", "blue"
    else g.base, g.mark = "cream", "ginger" end
    g.white = rng.chance(0.3)
  elseif coat == "tortie" then
    if dilute then g.base, g.a, g.b = "blue", "cream", "lilac" else g.base, g.a, g.b = "black", "ginger", { 0.55, 0.3, 0.13 } end
  elseif coat == "calico" then
    g.base = "white"
    if dilute then g.a, g.b = "cream", "blue" else g.a, g.b = "ginger", "black" end
  elseif coat == "tuxedo" then g.base = rng.pick({ "black", "black", "blue", "brown" }) g.white = true
  elseif coat == "van" then g.base, g.a = "white", rng.pick({ "ginger", "black", "blue", "cream" })
  elseif coat == "point" then g.base, g.a = rng.pick({ "cream", "white" }), rng.pick({ "seal", "seal", "blue", "lilac", "ginger" })
  else g.base, g.under = rng.pick({ "black", "blue" }), "lilac" end
  -- the build: an old cat goes one way or the other
  g.fat = o.fat or (rng.chance(0.5) and rng.range(1.12, 1.42) or rng.range(0.74, 0.98))
  g.bony = g.fat < 0.92
  g.sag = g.fat > 1.08 and rng.range(0.4, 1) or rng.range(0, 0.3)
  g.head = rng.range(0.9, 1.1) * (g.bony and 1.06 or 1)
  g.ear = rng.range(0.82, 1.14)
  g.leg = rng.range(0.85, 1.1)
  g.tail = rng.range(0.82, 1.14)
  g.tailw = rng.range(0.85, 1.3)
  g.fluff = rng.chance(0.2)
  -- the face
  g.age = o.age or rng.range(0.45, 1)                 -- how grey
  g.eye = rng.pick({ { 0.8, 0.62, 0.2 }, { 0.75, 0.56, 0.15 }, { 0.52, 0.66, 0.36 }, { 0.42, 0.6, 0.55 }, { 0.46, 0.62, 0.74 } })
  if coat == "point" then g.eye = { 0.36, 0.56, 0.78 } end
  g.cloudy = rng.chance(0.35) and rng.int(1, 2) or nil  -- which eye has clouded
  g.torn = rng.chance(0.28) and (rng.chance(0.5) and 1 or -1) or nil
  g.nose = (g.base == "black" or g.base == "seal") and { 0.25, 0.2, 0.22 } or { 0.82, 0.52, 0.5 }
  g.nosey = rng.range(0.9, 1.12)
  g.muzzle = rng.range(0.9, 1.15)
  g.whisk = rng.range(0.8, 1.2)
  g.fang = rng.chance(0.14)
  g.tongue = rng.chance(0.12)
  g.seed = rng.int(1, 1 << 30)
  return g
end

-- ---------------------------------------------------------------- templates
-- Units: about 100 to a cat. spine: {x, y, width}, rump to shoulders. back: which side of the
-- spine the back is on (+1 left of its direction). limbs: {{x, y, w}, ...} shoulder to paw; far ones
-- are behind the body. head: x, y, r, rot (degrees), eyes, turn (-1..1), tail: root to tip.
-- lobes: haunch and shoulder {x, y, rx, ry}. box: extents; props in M.prop.
local T = {}
T.curl = {
  spine = { { -22, 8, 32 }, { -27, 24, 40 }, { -14, 40, 44 }, { 8, 42, 44 }, { 24, 28, 38 }, { 26, 14, 30 } },
  back = 1,
  lobes = { { -22, 16, 22, 18 } },
  near = { { { 16, 8, 13 }, { 4, 3, 11 }, { -8, 3, 9 } } },
  tail = { front = true, { -30, 8, 12 }, { -26, -1, 11 }, { -4, -3, 10 }, { 16, -1, 9 }, { 30, 2, 8 } },
  head = { 19, 17, 18, -28, "shut", 0.2 },
  box = { -50, -6, 46, 66 },
}
T.stretch = {
  spine = { { -46, 15, 28 }, { -26, 19, 36 }, { 0, 20, 38 }, { 22, 21, 32 }, { 40, 26, 24 } },
  back = 1,
  lobes = { { -40, 14, 18, 15 } },
  far = { { { 36, 18, 11 }, { 58, 18, 8 }, { 78, 22, 7 } }, { { -34, 8, 13 }, { -52, 9, 9 }, { -72, 7, 7 } } },
  near = { { { 38, 14, 11 }, { 58, 6, 8 }, { 73, 6, 7 } }, { { -42, 8, 15 }, { -56, 2, 10 }, { -76, 2, 7 } } },
  tail = { { -56, 18, 10 }, { -72, 26, 9 }, { -90, 20, 8 }, { -102, 27, 6 } },
  head = { 54, 31, 17, -14, "shut", 0.3 },
  box = { -106, -6, 84, 54 },
}
T.side = {
  spine = { { -44, 20, 30 }, { -22, 21, 42 }, { 4, 21, 44 }, { 26, 22, 34 }, { 40, 25, 24 } },
  back = 1,
  lobes = { { -36, 15, 20, 17 } },
  near = { { { 34, 12, 11 }, { 42, 0, 8 }, { 54, 2, 7 } }, { { -38, 6, 15 }, { -28, -2, 10 }, { -16, 1, 8 } } },
  far = { { { 40, 14, 10 }, { 54, 10, 8 }, { 66, 12, 7 } }, { { -46, 8, 13 }, { -60, 4, 9 }, { -70, 8, 7 } } },
  tail = { { -56, 18, 10 }, { -72, 12, 9 }, { -86, 5, 8 }, { -102, 5, 6 } },
  head = { 56, 25, 18, -82, "shut", 0 },
  box = { -106, -6, 76, 52 },
}
T.tum = {
  spine = { { -38, 14, 26 }, { -18, 18, 36 }, { 6, 19, 36 }, { 26, 16, 28 } },
  back = 1,
  lobes = { { -34, 13, 19, 15 } },
  far = { { { 28, 8, 11 }, { 48, 8, 8 }, { 62, 10, 7 } } },
  near = { { { 26, 6, 12 }, { 44, 2, 9 }, { 58, 3, 8 } }, { { -30, 5, 13 }, { -14, 2, 10 }, { 2, 2, 8 } } },
  tail = { front = true, { -48, 8, 10 }, { -56, 2, 9 }, { -38, -1, 8 }, { -20, -2, 7 } },
  head = { 44, 20, 18, -6, "half", 0.45 },
  box = { -62, -7, 66, 44 },
}
T.up = {
  spine = { { -40, 18, 28 }, { -18, 15, 40 }, { 10, 15, 40 }, { 32, 20, 30 } },
  back = -1,
  lobes = { { -36, 22, 16, 13 } },
  far = { { { 36, 28, 10 }, { 46, 44, 8 }, { 40, 56, 7 } }, { { -42, 28, 12 }, { -54, 42, 9 }, { -58, 54, 7 } } },
  near = { { { 28, 28, 11 }, { 34, 46, 8 }, { 24, 58, 7 } }, { { -32, 30, 13 }, { -30, 50, 9 }, { -18, 60, 7 } } },
  tail = { { -48, 14, 10 }, { -62, 6, 9 }, { -78, 6, 8 }, { -90, 14, 6 } },
  head = { 50, 16, 18, 168, "half", 0.1 },
  box = { -94, -6, 72, 66 },
}
T.loaf = {
  spine = { { -32, 16, 30 }, { -14, 21, 38 }, { 8, 21, 36 }, { 22, 22, 28 } },
  back = 1,
  lobes = { { -28, 15, 20, 17 } },
  near = { { { 20, 5, 12 }, { 30, 3, 10 } } },
  tail = { front = true, { -46, 8, 10 }, { -44, 0, 9 }, { -26, -1, 8 }, { -10, 0, 7 } },
  head = { 32, 34, 18, 0, "half", 0.35 },
  box = { -54, -6, 54, 62 },
}
T.sit = {                                              -- hunched, as an old cat sits
  spine = { { -14, 14, 34 }, { -14, 34, 34 }, { -2, 52, 28 }, { 9, 64, 22 } },
  back = 1,
  lobes = { { -14, 16, 22, 18 } },
  near = { { { 6, 48, 13 }, { 10, 24, 10 }, { 13, 3, 8 } }, { { -14, 8, 14 }, { 2, 3, 11 }, { 13, 2, 8 } } },
  far = { { { 14, 46, 11 }, { 20, 24, 9 }, { 22, 3, 7 } } },
  tail = { front = true, { -26, 6, 10 }, { -30, -1, 9 }, { -10, -2, 8 }, { 14, -2, 7 } },
  head = { 14, 78, 17, 8, "half", 0.3 },
  box = { -38, -6, 36, 108 },
}
T.bowl = {
  spine = { { -19, 22, 26 }, { -22, 34, 34 }, { -10, 46, 36 }, { 8, 47, 36 }, { 19, 38, 30 }, { 20, 26, 24 } },
  back = 1,
  lobes = { { -17, 26, 17, 14 } },
  near = { { { 20, 28, 11 }, { 34, 26, 8 }, { 43, 22, 7 } } },
  tail = { { -28, 32, 10 }, { -42, 30, 8 }, { -50, 18, 7 } },
  head = { 15, 32, 17, -18, "shut", 0.2 },
  prop = "bowl", box = { -52, -2, 52, 70 },
}
T.hammock = {
  spine = { { -40, 26, 26 }, { -18, 15, 36 }, { 12, 15, 36 }, { 34, 25, 26 } },
  back = 1,
  lobes = { { -30, 17, 17, 14 } },
  dangle = { { { 30, 8, 11 }, { 33, -5, 8 }, { 35, -17, 7 } }, { { -26, 2, 13 }, { -29, -8, 9 }, { -27, -16, 7 } } },
  tail = { { -46, 18, 10 }, { -56, 2, 8 }, { -53, -18, 7 } },
  head = { 44, 32, 17, 18, "shut", 0.3 },
  prop = "hammock", box = { -72, -36, 72, 56 },
}
T.scratch = {
  spine = { { -8, 22, 30 }, { -2, 44, 28 }, { 8, 66, 25 }, { 15, 82, 20 } },
  back = 1,
  lobes = { { -8, 20, 19, 18 } },
  far = { { { 16, 80, 10 }, { 30, 88, 8 }, { 37, 96, 7 } }, { { 0, 14, 12 }, { 3, 6, 10 }, { 12, 2, 7 } } },
  near = { { { 14, 76, 11 }, { 28, 76, 8 }, { 37, 82, 7 } }, { { -10, 14, 15 }, { -14, 6, 10 }, { -4, 2, 8 } } },
  tail = { { -20, 18, 10 }, { -36, 12, 9 }, { -48, 24, 8 }, { -44, 42, 6 } },
  head = { 12, 99, 16, -14, "shut", 0.4 },
  prop = "post", box = { -52, -4, 56, 126 },
}
T.dangle = {
  spine = { { -52, 17, 28 }, { -30, 21, 36 }, { -6, 20, 34 }, { 12, 14, 26 } },
  back = 1,
  lobes = { { -46, 16, 18, 15 } },
  dangle = { { { 12, 8, 11 }, { 15, -10, 8 }, { 16, -26, 7 } }, { { 1, 8, 12 }, { 3, -8, 9 }, { 2, -21, 7 } } },
  tail = { { -62, 12, 10 }, { -69, -8, 8 }, { -66, -32, 7 } },
  head = { 27, 13, 18, -30, "shut", 0.3 },
  prop = "ledge", box = { -74, -42, 46, 42 },
}
T.yawn = {
  spine = { { -30, 15, 32 }, { -12, 22, 38 }, { 8, 28, 32 }, { 18, 38, 24 } },
  back = 1,
  lobes = { { -28, 15, 20, 17 } },
  far = { { { 18, 20, 11 }, { 28, 10, 9 }, { 36, 3, 7 } } },
  near = { { { 12, 16, 12 }, { 20, 8, 9 }, { 26, 2, 8 } } },
  tail = { front = true, { -44, 8, 10 }, { -50, 1, 9 }, { -28, -1, 8 }, { -6, -1, 7 } },
  head = { 26, 52, 18, 18, "yawn", 0.25 },
  box = { -56, -6, 48, 80 },
}
M.templates = T
M.template_order = { "curl", "stretch", "side", "tum", "up", "loaf", "sit", "bowl", "hammock", "scratch", "dangle", "yawn" }

-- ---------------------------------------------------------------- shapes
local function ell(cx, cy, rx, ry, n, a0)
  local p = {}
  n = n or 12
  for k = 0, n - 1 do
    local a = 2 * pi * k / n + (a0 or 0)
    p[#p + 1] = { cx + rx * cos(a), cy + ry * sin(a) }
  end
  return p
end
local function ccw(p)
  local a = 0
  for i = 1, #p do local q, r = p[i], p[i % #p + 1] a = a + q[1] * r[2] - r[1] * q[2] end
  if a >= 0 then return p end
  local o = {}
  for i = #p, 1, -1 do o[#o + 1] = p[i] end
  return o
end
-- a smooth run through {x, y, w}: points, widths and normals, sampled
local function run(ctrl, per)
  local xy = {}
  for i, c in ipairs(ctrl) do xy[i] = { c[1], c[2] } end
  local pts = #xy >= 3 and ink.catmull(xy, per or 5) or xy
  local n = #ctrl - 1
  local nrm = ink.normals(pts)
  local ws = {}
  for i = 1, #pts do
    local t = (i - 1) / max(1, #pts - 1) * n
    local k = min(n - 1, floor(t))
    local f = t - k
    local a, b = ctrl[k + 1][3], ctrl[k + 2][3]
    local fs = f * f * (3 - 2 * f)
    ws[i] = lerp(a, b, fs)
  end
  return pts, ws, nrm
end
local function ribbon_of(pts, ws, nrm, sc)
  local left, right = {}, {}
  sc = sc or 1
  for i, p in ipairs(pts) do
    local h = ws[i] * sc / 2
    left[#left + 1] = { p[1] + nrm[i][1] * h, p[2] + nrm[i][2] * h }
    right[#right + 1] = { p[1] - nrm[i][1] * h, p[2] - nrm[i][2] * h }
  end
  for i = #right, 1, -1 do left[#left + 1] = right[i] end
  return ccw(left)
end
local function shapes(list) for _, p in ipairs(list) do ink.smooth(p, true, 0.85) end end

-- light and shade down a run, in the page's direction of the light, so that every part is lit on one
-- side, whichever way it lies. flip: the cat is drawn mirrored
local function round_part(pts, ws, nrm, flip, k, ge)
  k = k or 1
  local Lx, Ly = LIGHT[1] * flip, LIGHT[2]
  local n = #pts
  local i = 1
  while i <= n do
    -- a stretch whose same side faces the light
    local d0 = nrm[i][1] * Lx + nrm[i][2] * Ly
    local sd = d0 >= 0 and 1 or -1
    local j_ = i
    local sum = abs(d0)
    while j_ < n and (nrm[j_ + 1][1] * Lx + nrm[j_ + 1][2] * Ly) * sd >= 0 do
      j_ = j_ + 1
      sum = sum + abs(nrm[j_][1] * Lx + nrm[j_][2] * Ly)
    end
    local avg = sum / (j_ - i + 1)
    if j_ > i and avg > 0.1 then
      for pass = 1, 2 do                               -- two soft steps of shade, on the far side
        local inner = pass == 1 and 0.12 or 0.34
        local out, back = {}, {}
        for q = i, j_ do
          local h = ws[q] / 2
          out[#out + 1] = { pts[q][1] - sd * nrm[q][1] * h * 1.3, pts[q][2] - sd * nrm[q][2] * h * 1.3 }
          back[#back + 1] = { pts[q][1] - sd * nrm[q][1] * h * inner, pts[q][2] - sd * nrm[q][2] * h * inner }
        end
        for q = #back, 1, -1 do out[#out + 1] = back[q] end
        ink.smooth(out, true, 0.8) ink.fill(ge.shade, 0.13 * k * avg, true)
      end
      local m = {}
      for q = i, j_ do
        local h = ws[q] / 2
        m[#m + 1] = { pts[q][1] + sd * nrm[q][1] * h * 0.55, pts[q][2] + sd * nrm[q][2] * h * 0.55 }
      end
      local hw_ = {}
      for q = i, j_ do hw_[#hw_ + 1] = ws[q] * 0.2 * sin(pi * (q - i + 0.5) / (j_ - i + 1)) end
      local mn = ink.normals(m)
      local rb = {}
      for q = 1, #m do rb[#rb + 1] = { m[q][1] + mn[q][1] * hw_[q] / 2, m[q][2] + mn[q][2] * hw_[q] / 2 } end
      for q = #m, 1, -1 do rb[#rb + 1] = { m[q][1] - mn[q][1] * hw_[q] / 2, m[q][2] - mn[q][2] * hw_[q] / 2 } end
      ink.smooth(rb, true, 0.8) ink.fill(white, 0.16 * k * avg)
    end
    i = j_ + 1
  end
end

-- blotches in a color, inside the current clip: the watercolor
local function wash(rng, g, x0, y0, x1, y1, n, sz, dark)
  for _ = 1, n do
    local x, y = rng.range(x0, x1), rng.range(y0, y1)
    local r = sz * rng.range(0.5, 1.3)
    ink.smooth(ink.blob(rng, x, y, r, r * rng.range(0.55, 1), 0.3, 7), true)
    if rng.chance(0.55) then ink.fill(dark, rng.range(0.07, 0.17), true)
    else ink.fill(white, rng.range(0.05, 0.13)) end
  end
end
-- patches of a pigment with soft, irregular edges
local function patch(rng, x, y, rx, ry, c, op)
  ink.smooth(ink.blob(rng, x, y, rx, ry, 0.34, 10), true) ink.fill(c, op)
  ink.smooth(ink.blob(rng, x + rng.sym(rx * 0.5), y + rng.sym(ry * 0.5), rx * 0.5, ry * 0.5, 0.4, 7), true) ink.fill(c, op)
end

-- ---------------------------------------------------------------- props
-- the things cats lie on, in the document's ink, as the cat gym draws them
local function prop_back(rng, kind, s)
  if kind == "bowl" then
    local p = {}
    for k = 0, 16 do local a = pi * k / 16 p[#p + 1] = { 50 * cos(a), 33 + 8 * sin(a) } end
    for k = 1, 15 do local a = pi + pi * k / 16 p[#p + 1] = { 50 * cos(a), 33 + 5 * sin(a) } end
    ink.smooth(p, true) ink.fill(tone(0.14))
  elseif kind == "post" then
    ink.poly({ { 38, -4 }, { 54, -4 }, { 54, 126 }, { 38, 126 } }, true) ink.fill(tone(0.76))
    ink.poly({ { 38, -4 }, { 54, -4 }, { 54, 126 }, { 38, 126 } }, true) ink.clip()
      for y = -6, 128, 2.6 do ink.moveto(38, y) ink.lineto(54, y + 2.4) end
      ink.stroke(tone(0.28), 0.22, 0.5, true)
      for y = -5, 128, 2.6 do ink.moveto(38, y) ink.lineto(54, y + 2.4) end
      ink.stroke(white, 0.25, 0.55)
      ink.poly({ { 47, -6 }, { 56, -6 }, { 56, 128 }, { 47, 128 } }, true) ink.fill(tone(0.1), 0.28, true)
    ink.unclip()
    ink.poly({ { -46, -6 }, { 62, -6 }, { 62, -1 }, { -46, -1 } }, true) ink.fill(tone(0.22))
    ink.poly({ { 36, 124 }, { 56, 124 }, { 56, 128 }, { 36, 128 } }, true) ink.fill(tone(0.2))
  elseif kind == "ledge" then
    ink.poly({ { -78, -7 }, { 22, -7 }, { 22, 0 }, { -78, 0 } }, true) ink.fill(tone(0.32))
    ink.moveto(-78, -0.5) ink.lineto(22, -0.5) ink.stroke(white, 0.5, 0.45)
    ink.poly({ { -78, -7 }, { 22, -7 }, { 22, -5 }, { -78, -5 } }, true) ink.fill(tone(0.1), 0.45, true)
  elseif kind == "hammock" then
    for _, x in ipairs({ -70, 70 }) do ink.moveto(x, 44) ink.lineto(x * 0.9, 25) end
    ink.stroke(ink.accent(-0.1), 0.5)
  end
end
local function prop_front(rng, kind, s)
  if kind == "bowl" then
    local p = {}
    for k = 0, 16 do local a = pi + pi * k / 16 p[#p + 1] = { 50 * cos(a), 33 + 5 * sin(a) } end
    for k = 1, 15 do local a = -pi * k / 16 p[#p + 1] = { 50 * cos(a) * (1 - 0.1 * sin(-a)), 33 + 33 * sin(a) } end
    ink.smooth(p, true) ink.fill(tone(0.3))
    ink.smooth(p, true) ink.clip()
      for y = 0, 36, 4.4 do
        local x = -56 + (floor(y / 4.4) % 2) * 3
        while x < 56 do ink.moveto(x, y) ink.lineto(x + 3, y + 3.4) x = x + 6 end
      end
      ink.stroke(white, 0.3, 0.55)
      ink.poly({ { 10, -2 }, { 54, -2 }, { 54, 36 }, { 10, 36 } }, true) ink.fill(tone(0.08), 0.25, true)
    ink.unclip()
    local lip = {}
    for k = 0, 16 do local a = pi + pi * k / 16 lip[#lip + 1] = { 49 * cos(a), 32 + 5 * sin(a) } end
    ink.smooth(lip, false) ink.stroke(white, 0.9, 0.5)
  elseif kind == "hammock" then
    local top, bot = {}, {}
    for k = 0, 20 do
      local t = k / 20
      local x = -64 + 128 * t
      local sag = 4 * t * (1 - t)
      top[#top + 1] = { x, 25 - sag * 13 }
      bot[#bot + 1] = { x, 25 - sag * 27 }
    end
    local cloth = {}
    for _, p in ipairs(bot) do cloth[#cloth + 1] = p end
    for i = #top, 1, -1 do cloth[#cloth + 1] = top[i] end
    ink.smooth(cloth, true) ink.fill(tone(0.34))
    ink.smooth(cloth, true) ink.clip()
      for k = 1, 3 do
        local y0 = 25 - k * 4
        ink.smooth({ { -64, y0 + 4 }, { -20, y0 - 11 }, { 20, y0 - 11 }, { 64, y0 + 4 } }, false)
      end
      ink.stroke(white, 0.35, 0.4)
      ink.poly({ { 10, -10 }, { 70, -10 }, { 70, 30 }, { 10, 30 } }, true) ink.fill(tone(0.08), 0.22, true)
    ink.unclip()
    ink.smooth(top, false) ink.stroke(white, 0.7, 0.5)
    for _, x in ipairs({ -64, 64 }) do ink.circle(x, 25, 2.4) ink.stroke(ink.accent(-0.1), 0.6) end
  end
end

-- ---------------------------------------------------------------- the head
local function head(rng, g, H, ge, flip)
  local x, y, r, rot, eyes, turn = H[1], H[2], H[3] * g.head, H[4] or 0, H[5] or "shut", H[6] or 0
  local base, dark = ge.base, ge.shade
  ink.push() ink.translate(x, y) ink.rotate(rot)
  local tx = turn * r * 0.22                           -- the features, turned toward the near side
  -- ears
  local function ear(sd)
    local sc = g.ear * (1 - (sd == (turn > 0 and -1 or 1) and abs(turn) * 0.16 or 0))
    local bx, tipx = sd * r * 0.56 + tx * 0.5, sd * r * 0.8 + tx * 0.5
    local pts = { { bx - sd * r * 0.42, r * 0.66 }, { tipx, r * (0.8 + 0.72 * sc) }, { bx + sd * r * 0.42, r * 0.42 } }
    if g.torn == sd then pts = { pts[1], { tipx - sd * r * 0.06, r * (0.8 + 0.62 * sc) }, { lerp(tipx, pts[3][1], 0.4), r * (0.74 + 0.5 * sc) }, { lerp(tipx, pts[3][1], 0.5) + sd * r * 0.03, r * (0.86 + 0.42 * sc) }, pts[3] } end
    return ccw(pts), bx, tipx, sc
  end
  local eL, lbx, ltip, ls = ear(-1)
  local eR, rbx, rtip, rs = ear(1)
  local ho = ccw({ { -r * 1.02, -r * 0.1 }, { -r * 0.86, r * 0.46 }, { -r * 0.42, r * 0.84 }, { 0, r * 0.9 }, { r * 0.42, r * 0.84 }, { r * 0.86, r * 0.46 }, { r * 1.02, -r * 0.1 }, { r * 0.76, -r * 0.6 }, { r * 0.3, -r * 0.84 }, { -r * 0.3, -r * 0.84 }, { -r * 0.76, -r * 0.6 } })
  local function sil()
    ink.poly(eL, true) ink.poly(eR, true)
    ink.smooth(ho, true, 0.95)
  end
  sil() ink.fill(ge.headbase or base)
  sil() ink.clip()
    if ink.unit() * 100 > 1.2 then wash(rng, g, -r, -r, r, r * 1.6, 5, r * 0.34, dark) end
    if g.coat == "tabby" or g.coat == "blotched" then
      -- the M on the forehead, stripes on the cheeks and crown
      for _, sd in ipairs({ -1, -0.45, 0, 0.45, 1 }) do
        local xx = tx * 0.6 + sd * r * 0.3
        streak3(xx, r * 0.96, xx + sd * r * 0.05, r * 0.8, xx - sd * r * 0.08, r * 0.62, xx - sd * r * 0.12, r * 0.44, r * 0.1, r * 0.03, ge.mark, 0.8)
      end
      for _, sd in ipairs({ -1, 1 }) do
        for k = 0, 1 do
          local yy = -r * (0.06 + k * 0.26)
          streak3(sd * r * 1.04, yy, sd * r * 0.86, yy + r * 0.04, sd * r * 0.66, yy + r * 0.02, sd * r * 0.5, yy + r * 0.06, r * 0.1, r * 0.03, ge.mark, 0.75)
        end
      end
    elseif g.coat == "tortie" or g.coat == "calico" then
      local sd = (g.seed % 2 == 0) and 1 or -1
      ink.poly({ { tx, -r * 1.2 }, { sd * r * 1.5, -r * 1.2 }, { sd * r * 1.5, r * 1.9 }, { tx, r * 1.9 } }, true)
      ink.fill(ge.a, 0.95)
      patch(rng, -sd * r * 0.6, r * 0.7, r * 0.5, r * 0.4, ge.b, 0.92)
      if g.coat == "tortie" then patch(rng, sd * r * 0.5, -r * 0.1, r * 0.3, r * 0.26, ge.b, 0.85) end
    elseif g.coat == "van" then
      ink.poly({ { -r * 1.5, r * 0.3 }, { tx - r * 0.1, r * 0.34 }, { tx, r * 0.1 }, { tx + r * 0.1, r * 0.34 }, { r * 1.5, r * 0.3 }, { r * 1.5, r * 1.9 }, { -r * 1.5, r * 1.9 } }, true)
      ink.fill(ge.a, 0.95)
    elseif g.coat == "point" then
      ink.smooth(ell(tx, -r * 0.2, r * 0.76, r * 0.74, 10), true) ink.fill(ge.a, 0.85)
      ink.poly(eL, true) ink.poly(eR, true) ink.fill(ge.a)
    end
    -- the blaze and bib of white
    if g.coat == "tuxedo" or g.coat == "calico" or g.coat == "van" or g.white then
      if g.coat ~= "van" then
        ink.smooth({ { tx - r * 0.1, r * 0.7 }, { tx + r * 0.1, r * 0.7 }, { tx + r * 0.3, r * 0.1 }, { tx + r * 0.62, -r * 0.5 }, { tx, -r * 1 }, { tx - r * 0.62, -r * 0.5 }, { tx - r * 0.3, r * 0.1 } }, true)
        ink.fill(ge.white, 0.96)
      end
    end
    -- age: frost on the brow and muzzle, more with the years
    local gy = g.age
    local fc = ge.frost
    for k = 1, 3 do
      ink.smooth(ell(tx, -r * 0.46, r * (0.34 + 0.11 * k) * g.muzzle, r * (0.26 + 0.09 * k), 9), true) ink.fill(fc, 0.12 + 0.2 * gy)
    end
    for k = 1, floor(3 + 7 * gy) do
      local a, d = rng.range(0, 2 * pi), r * rng.range(0.42, 0.9)
      local xx, yy = tx + d * cos(a), -r * 0.3 + d * sin(a) * 0.8
      local an = atan(yy + r * 0.3, xx - tx)
      streak3(xx, yy, xx + cos(an) * r * 0.05, yy + sin(an) * r * 0.05, xx + cos(an) * r * 0.1, yy + sin(an) * r * 0.1, xx + cos(an) * r * 0.16, yy + sin(an) * r * 0.16, r * 0.05, r * 0.01, fc, 0.65)
    end
    for _, sd in ipairs({ -1, 1 }) do
      ink.smooth(ell(tx + sd * r * 0.42, r * 0.34, r * 0.28, r * 0.1, 7), true) ink.fill(fc, 0.42 * gy)
    end
    -- bony: the cheeks fall in
    if g.bony then
      for _, sd in ipairs({ -1, 1 }) do
        streak3(sd * r * 0.72 + tx * 0.3, r * 0.04, sd * r * 0.62, -r * 0.1, sd * r * 0.56, -r * 0.24, sd * r * 0.5, -r * 0.34, r * 0.16, r * 0.03, dark, 0.22, true)
      end
    end
    -- the round of the head
    local Lx, Ly = LIGHT[1] * flip, LIGHT[2]
    local c_, s_ = cos(-rot * rad), sin(-rot * rad)
    local lx, ly = Lx * c_ - Ly * s_, Lx * s_ + Ly * c_
    ink.smooth(ell(-lx * r * 1.15, -ly * r * 1.15, r * 1.05, r, 10), true) ink.fill(dark, 0.2, true)
    ink.smooth(ell(lx * r * 0.42, ly * r * 0.42, r * 0.36, r * 0.3, 8), true) ink.fill(white, 0.08)
  ink.unclip()
  -- inner ears
  for _, q in ipairs({ { eL, -1 }, { eR, 1 } }) do
    local e = q[1]
    local cx, cy = 0, 0
    for _, p in ipairs(e) do cx, cy = cx + p[1], cy + p[2] end
    cx, cy = cx / #e, cy / #e
    local inner = {}
    for i, p in ipairs(e) do inner[i] = { cx + (p[1] - cx) * 0.58, cy + (p[2] - cy) * 0.58 - r * 0.03 } end
    ink.poly(inner, true) ink.fill(ge.ear, 0.85)
    for k = 1, 2 do
      local sx = cx + q[2] * r * (k - 1.5) * 0.14
      streak3(sx, cy - r * 0.2, sx, cy - r * 0.08, sx + q[2] * r * 0.02, cy + r * 0.03, sx + q[2] * r * 0.03, cy + r * 0.13, r * 0.06, r * 0.01, ge.tuft, 0.8)
    end
  end
  -- eyes
  local ex, ey = r * 0.42, r * 0.13
  local big = r * ink.unit() > 0.1
  local line = ge.line
  for i, sd in ipairs({ -1, 1 }) do
    local xx, yy = tx + sd * ex, ey
    local e_ = r * 0.2
    if eyes == "shut" then
      -- a closed lid curves down; a little tuck at the corner
      ink.moveto(xx - e_, yy + e_ * 0.12) ink.curveto(xx - e_ * 0.4, yy - e_ * 0.5, xx + e_ * 0.4, yy - e_ * 0.5, xx + e_, yy + e_ * 0.12)
      ink.stroke(line, max(0.4, r * 0.05 * ink.unit() * ink.CM), 0.95)
    elseif eyes == "yawn" then
      ink.moveto(xx - e_, yy - e_ * 0.2) ink.curveto(xx - e_ * 0.4, yy + e_ * 0.3, xx + e_ * 0.4, yy + e_ * 0.3, xx + e_, yy - e_ * 0.2)
      ink.stroke(line, max(0.4, r * 0.05 * ink.unit() * ink.CM), 0.95)
    else
      -- half open: the heavy lid of an old cat
      local h_ = e_ * 0.56
      local eyep = ccw({ { xx - e_, yy }, { xx - e_ * 0.3, yy - h_ * 0.75 }, { xx + e_ * 0.3, yy - h_ * 0.75 }, { xx + e_, yy }, { xx + e_ * 0.3, yy + h_ * 0.55 }, { xx - e_ * 0.3, yy + h_ * 0.55 } })
      local cloud = g.cloudy == i
      ink.smooth(eyep, true, 0.9) ink.fill(cloud and mix(g.eye, { 0.82, 0.86, 0.88 }, 0.72) or g.eye)
      ink.smooth(ell(xx, yy - e_ * 0.03, e_ * 0.17, h_ * 0.78, 8), true) ink.fill(cloud and { 0.5, 0.54, 0.58 } or { 0.05, 0.05, 0.07 })
      ink.moveto(xx - e_ * 1.05, yy + h_ * 0.42) ink.curveto(xx - e_ * 0.3, yy + h_ * 0.95, xx + e_ * 0.3, yy + h_ * 0.95, xx + e_ * 1.05, yy + h_ * 0.42)
      ink.stroke(line, max(0.35, r * 0.05 * ink.unit() * ink.CM), 0.95)
      if big then ink.circle(xx - e_ * 0.3, yy + h_ * 0.1, e_ * 0.09) ink.fill(white, 0.95) end
    end
  end
  -- nose and mouth
  local ny = -r * 0.26
  local ns = r * 0.12 * g.nosey
  if eyes == "yawn" then
    local my = -r * 0.46
    ink.smooth(ell(tx, my, r * 0.3, r * 0.34, 10), true) ink.fill({ 0.34, 0.1, 0.13 })
    ink.smooth(ell(tx, my - r * 0.14, r * 0.2, r * 0.14, 8), true) ink.fill({ 0.86, 0.5, 0.52 })
    if not g.fang then
      for _, sd in ipairs({ -1, 1 }) do ink.poly({ { tx + sd * r * 0.2, my + r * 0.26 }, { tx + sd * r * 0.13, my + r * 0.28 }, { tx + sd * r * 0.17, my + r * 0.1 } }, true) end
      ink.fill(white)
    end
    ny = -r * 0.04
  end
  ink.smooth(ccw({ { tx - ns, ny + ns * 0.5 }, { tx + ns, ny + ns * 0.5 }, { tx, ny - ns * 0.5 } }), true, 0.5)
  ink.fill(ge.nose)
  if eyes ~= "yawn" and big then
    ink.moveto(tx, ny - ns * 0.5) ink.lineto(tx, ny - ns * 1.3)
    ink.moveto(tx - r * 0.2, ny - ns * 1.8) ink.curveto(tx - r * 0.1, ny - ns * 2.4, tx - r * 0.02, ny - ns * 2.1, tx, ny - ns * 1.3)
    ink.curveto(tx + r * 0.02, ny - ns * 2.1, tx + r * 0.1, ny - ns * 2.4, tx + r * 0.2, ny - ns * 1.8)
    ink.stroke(line, 0.35, 0.8)
    if g.fang then ink.poly({ { tx + r * 0.09, ny - ns * 2 }, { tx + r * 0.16, ny - ns * 2.05 }, { tx + r * 0.12, ny - ns * 2.9 } }, true) ink.fill(white) end
    if g.tongue then ink.smooth(ell(tx - r * 0.02, ny - ns * 2.5, r * 0.07, r * 0.06, 7), true) ink.fill({ 0.86, 0.5, 0.52 }) end
    -- whiskers: white even on the blackest cat
    for _, sd in ipairs({ -1, 1 }) do
      for k = -1, 1 do
        local w0x, w0y = tx + sd * r * 0.3, ny - ns * 0.6 + k * r * 0.06
        ink.moveto(w0x, w0y)
        ink.curveto(w0x + sd * r * 0.4, w0y + k * r * 0.04, w0x + sd * r * 0.8 * g.whisk, w0y + k * r * 0.08 - r * 0.1, w0x + sd * r * 1.15 * g.whisk, w0y + k * r * 0.2 - r * 0.14)
      end
    end
    ink.stroke(ge.whisker, 0.28, 0.85)
  end
  ink.pop()
end

-- ---------------------------------------------------------------- a cat
-- Draws template name with genes g, the origin at the template's origin, 100 units = s cm. o.flip
-- turns it round. No template is drawn the same twice: its joints wander.
function M.cat(rng, name, g, s, o)
  o = o or {}
  local Tm = T[name] or T.curl
  local flip = o.flip and -1 or 1
  ink.push()
  ink.scale(flip * s / 100, s / 100)
  local lod = ink.unit() * 100
  local fine = lod > 2.2
  -- the colors of this cat
  local ge = {
    base = c_of(g, g.base), shade = c_of(g, g.base, -0.55), line = c_of(g, g.base == "black" and "grey" or "black", g.base == "black" and -0.3 or nil),
    white = c_of(g, "white"), frost = c_of(g, (g.base == "white" or g.base == "cream") and { 0.86, 0.84, 0.82 } or { 0.82, 0.8, 0.78 }),
    mark = g.mark and c_of(g, g.mark), a = g.a and c_of(g, g.a), b = g.b and c_of(g, g.b),
    ear = c_of(g, { 0.88, 0.66, 0.62 }), tuft = c_of(g, "white"), nose = c_of(g, g.nose), whisker = c_of(g, "white"),
  }
  if g.base == "white" or g.base == "cream" then ge.whisker = c_of(g, "grey") ge.line = c_of(g, "seal") end
  if g.coat == "point" then ge.headbase = ge.base end
  -- a skeleton with a little life in it: joints wander, the build changes the widths
  local function J(p, k) return { p[1] + rng.sym(k), p[2] + rng.sym(k), p[3] } end
  local spine = {}
  local ns = #Tm.spine
  for i, p in ipairs(Tm.spine) do
    local q = J(p, 1.2)
    local mid = 1 - abs((i - 1) / max(1, ns - 1) * 2 - 1)
    q[3] = p[3] * lerp(1, g.fat, 0.45 + 0.55 * mid)
    -- the belly hangs: the spine's width grows toward the ground
    if g.sag > 0 then q[3] = q[3] + g.sag * 5 * mid end
    spine[i] = q
  end
  local sp, sw, sn = run(spine, 5)
  -- the torso: the spine's ribbon and the haunches
  local torso = { ribbon_of(sp, sw, sn) }
  for _, l in ipairs(Tm.lobes or {}) do torso[#torso + 1] = ccw(ell(l[1], l[2], l[3] * lerp(1, g.fat, 0.7), l[4] * lerp(1, g.fat, 0.7), 12)) end
  local function paint_limb(ctrl, far, region)
    local c2 = {}
    for i, p in ipairs(ctrl) do
      c2[i] = { p[1] + (i > 1 and rng.sym(1.6) or 0), p[2] + (i > 1 and rng.sym(1.6) or 0), p[3] * g.leg * (g.bony and 0.86 or lerp(1, g.fat, 0.3)) }
    end
    local lp, lw, ln = run(c2, 4)
    local end_ = lp[#lp]
    local a_ = atan(end_[2] - lp[#lp - 1][2], end_[1] - lp[#lp - 1][1])
    local pr = lw[#lw] * 0.62
    local px, py = end_[1] + cos(a_) * pr * 0.35, end_[2] + sin(a_) * pr * 0.35
    local outl = { ribbon_of(lp, lw, ln), ccw(ell(px, py, pr * 1.28, pr, 9, a_)), ccw(ell(lp[1][1], lp[1][2], lw[1] * 0.5, lw[1] * 0.5, 9)) }
    shapes(outl) ink.fill(ge.base)
    shapes(outl) ink.clip()
      if g.coat == "tabby" or g.coat == "blotched" then
        for u = 0.3, 0.86, 0.17 do
          local i = 1 + floor(u * (#lp - 1))
          local p, nn, w = lp[i], ln[i], lw[i]
          streak3(p[1] + nn[1] * w * 0.6, p[2] + nn[2] * w * 0.6, p[1] + nn[1] * w * 0.2, p[2] + nn[2] * w * 0.2, p[1] - nn[1] * w * 0.2, p[2] - nn[2] * w * 0.2, p[1] - nn[1] * w * 0.5, p[2] - nn[2] * w * 0.5, w * 0.3, w * 0.1, ge.mark, 0.85)
        end
      elseif g.coat == "point" then
        for pass = 0, 2 do
          for u = 0.3 + pass * 0.2, 1.01, 0.1 do
            local i = 1 + floor(u * (#lp - 1))
            ink.circle(lp[i][1], lp[i][2], lw[i] * 0.9)
          end
          ink.circle(px, py, pr * 1.4)
          ink.fill(ge.a, 0.34)
        end
      elseif g.coat == "calico" and rng.chance(0.4) then
        patch(rng, lp[1][1], lp[1][2], lw[1] * 1.2, lw[1] * 1.3, rng.chance(0.5) and ge.a or ge.b, 0.95)
      elseif g.coat == "van" or g.coat == "tortie" then
        if g.coat == "tortie" then patch(rng, lp[2][1], lp[2][2], lw[2], lw[2] * 1.6, ge.a, 0.9) end
      end
      -- socks: white paws
      if g.white or g.coat == "tuxedo" then
        local keep_ = g.coat == "tuxedo" and 1.5 or 1.3
        ink.circle(px, py, pr * keep_ * 1.45) ink.fill(ge.white, 0.97)
      end
      round_part(lp, lw, ln, flip, 0.85, ge)
      if far then shapes(outl) ink.fill(ge.shade, 0.28, true) end
      -- the toes
      if fine then
        for k = -1, 1 do
          local tx_ = px + cos(a_) * pr * 0.9 - sin(a_) * k * pr * 0.5
          local ty_ = py + sin(a_) * pr * 0.9 + cos(a_) * k * pr * 0.5
          ink.moveto(tx_, ty_) ink.lineto(tx_ - cos(a_) * pr * 0.6, ty_ - sin(a_) * pr * 0.6)
        end
        ink.stroke(ge.shade, 0.3, 0.6)
      end
    ink.unclip()
    return lp, lw
  end
  local function paint_tail()
    if not Tm.tail then return end
    local c2 = {}
    local n = #Tm.tail
    local r0 = Tm.tail[1]
    for i, p in ipairs(Tm.tail) do
      local x, y = r0[1] + (p[1] - r0[1]) * g.tail, r0[2] + (p[2] - r0[2]) * g.tail
      c2[i] = { x + (i > 1 and rng.sym(2.4) or 0), y + (i > 1 and rng.sym(2.4) or 0), p[3] * g.tailw * (g.fluff and 1.32 or 1) }
    end
    local lp, lw, ln = run(c2, 5)
    local tip = lp[#lp]
    local outl = { ribbon_of(lp, lw, ln), ccw(ell(tip[1], tip[2], lw[#lw] * 0.5, lw[#lw] * 0.5, 8)) }
    shapes(outl) ink.fill(ge.base)
    shapes(outl) ink.clip()
      if g.coat == "tabby" or g.coat == "blotched" then
        for i = 3, #lp, 3 do
          local p, nn, w = lp[i], ln[i], lw[i]
          ink.moveto(p[1] + nn[1] * w, p[2] + nn[2] * w) ink.lineto(p[1] - nn[1] * w, p[2] - nn[2] * w)
          ink.stroke(ge.mark, max(0.4, w * 0.42 * ink.unit() * ink.CM), 0.9)
        end
      elseif g.coat == "van" or g.coat == "point" then
        ink.circle(tip[1], tip[2], 400) ink.fill(ge.a, g.coat == "point" and 0.85 or 0.95)
      elseif g.coat == "calico" or g.coat == "tortie" then
        for i = 2, #lp, 4 do patch(rng, lp[i][1], lp[i][2], lw[i] * 1.4, lw[i] * 1.2, (i % 8 == 2) and ge.a or ge.b, 0.95) end
      end
      if g.coat == "tuxedo" or g.white then ink.circle(tip[1], tip[2], lw[#lw] * 1.5) ink.fill(ge.white, g.coat == "tuxedo" and 0.95 or 0) end
      round_part(lp, lw, ln, flip, 0.8, ge)
    ink.unclip()
  end

  -- painting order: prop, far limbs, tail, body, near limbs, head
  if Tm.prop then prop_back(rng, Tm.prop, s) end
  for _, l in ipairs(Tm.far or {}) do paint_limb(l, true) end
  if not (Tm.tail and Tm.tail.front) then paint_tail() end
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, sh in ipairs(torso) do for _, p in ipairs(sh) do x0, y0, x1, y1 = min(x0, p[1]), min(y0, p[2]), max(x1, p[1]), max(y1, p[2]) end end
  -- bones: an old thin cat's hips and shoulders show; added to the outline at the back
  if g.bony then
    local bk = Tm.back or 1
    for _, u in ipairs({ 0.14, 0.72 }) do
      local i = 1 + floor(u * (#sp - 1))
      local a_, b_ = max(1, i - 3), min(#sp, i + 3)
      local rid = {}
      for q = a_, b_ do
        local f_ = sin(pi * (q - a_ + 0.5) / (b_ - a_ + 1))
        rid[#rid + 1] = { sp[q][1] + sn[q][1] * bk * sw[q] * (0.46 + 0.1 * f_), sp[q][2] + sn[q][2] * bk * sw[q] * (0.46 + 0.1 * f_) }
      end
      for q = b_, a_, -1 do rid[#rid + 1] = { sp[q][1], sp[q][2] } end
      torso[#torso + 1] = ccw(rid)
    end
  end
  shapes(torso) ink.fill(ge.base)
  shapes(torso) ink.clip()
    local bk = Tm.back or 1
    if lod > 1.2 then wash(rng, g, x0, y0, x1, y1, fine and 10 or 5, (x1 - x0) * 0.13, ge.shade) end
    local n = #sp
    if g.coat == "tabby" then
      -- stripes across the spine, from the back down the flank
      local step = max(2, floor(n / rng.int(6, 8)))
      for i = 2, n, step do
        local p, nn, w = sp[i], sn[i], sw[i]
        local bx, by = p[1] + nn[1] * bk * w * 0.56, p[2] + nn[2] * bk * w * 0.56
        local reach = w * rng.range(0.62, 0.94)
        local kink = rng.sym(w * 0.1)
        local dx, dy = -nn[1] * bk, -nn[2] * bk
        local tx_, ty_ = -dy, dx
        streak3(bx, by, bx + dx * reach * 0.33 + tx_ * kink, by + dy * reach * 0.33 + ty_ * kink, bx + dx * reach * 0.66 - tx_ * kink, by + dy * reach * 0.66 - ty_ * kink, bx + dx * reach, by + dy * reach, w * 0.13, w * 0.03, ge.mark, 0.88)
      end
      -- and a dark line along the spine itself
      local ln = {}
      for i = 1, n do ln[i] = { sp[i][1] + sn[i][1] * bk * sw[i] * 0.47, sp[i][2] + sn[i][2] * bk * sw[i] * 0.47 } end
      ink.smooth(ln, false) ink.stroke(ge.mark, max(0.5, 6 * ink.unit() * ink.CM), 0.75)
    elseif g.coat == "blotched" then
      -- classic: broad curves over the flank, a bullseye
      for _, u in ipairs({ 0.25, 0.68 }) do
        local i = 1 + floor(u * (n - 1))
        local p, w = sp[i], sw[i]
        for k = 1, 2 do
          local rr = w * (0.17 + 0.17 * k)
          local cc = {}
          for a = 0, 9 do local an = (a / 9) * 2 * pi * 0.82 + u * 3 cc[#cc + 1] = { p[1] + rr * cos(an) * 1.12, p[2] + rr * sin(an) * 0.85 } end
          ink.smooth(cc, false) ink.stroke(ge.mark, max(0.6, w * 0.13 * ink.unit() * ink.CM), 0.86)
        end
      end
    elseif g.coat == "tortie" then
      for _ = 1, 7 do patch(rng, rng.range(x0, x1), rng.range(y0, y1), (x1 - x0) * rng.range(0.07, 0.17), (y1 - y0) * rng.range(0.1, 0.24), rng.chance(0.65) and ge.a or ge.b, 0.94) end
      for _ = 1, fine and 40 or 12 do
        local x, y = rng.range(x0, x1), rng.range(y0, y1)
        ink.circle(x, y, rng.range(0.6, 1.6))
      end
      ink.fill(ge.a, 0.8)
    elseif g.coat == "calico" then
      for k = 1, 4 do
        local i = 1 + floor((k - 0.6) / 4 * (n - 1))
        local p, nn, w = sp[i], sn[i], sw[i]
        patch(rng, p[1] + nn[1] * bk * w * 0.2, p[2] + nn[2] * bk * w * 0.2, w * rng.range(0.4, 0.64), w * rng.range(0.3, 0.56), k % 2 == 1 and ge.a or ge.b, 0.96)
      end
    elseif g.coat == "van" then
      local p = sp[1]
      patch(rng, p[1], p[2], sw[1] * 0.5, sw[1] * 0.4, ge.a, 0.95)
    elseif g.coat == "point" then
      -- darker along the back and toward the face
      local ln = {}
      for i = 1, n do ln[i] = { sp[i][1] + sn[i][1] * bk * sw[i] * 0.42, sp[i][2] + sn[i][2] * bk * sw[i] * 0.42 } end
      ink.smooth(ln, false) ink.stroke(ge.a, max(0.6, 14 * ink.unit() * ink.CM), 0.22)
    elseif g.coat == "smoke" then
      local und = c_of(g, g.under)
      for i = 1, n, 2 do ink.circle(sp[i][1] - sn[i][1] * bk * sw[i] * 0.36, sp[i][2] - sn[i][2] * bk * sw[i] * 0.36, sw[i] * 0.3) end
      ink.fill(und, 0.28)
    end
    -- white below: bib and belly
    if g.coat == "tuxedo" or g.white or g.coat == "calico" then
      local bel = {}
      for i = 1, n do bel[#bel + 1] = { sp[i][1] - sn[i][1] * bk * sw[i] * 0.72, sp[i][2] - sn[i][2] * bk * sw[i] * 0.72 } end
      local reach = g.coat == "tuxedo" and 0.2 or 0.05
      for i = n, 1, -2 do
        local r_ = reach + rng.sym(0.12)
        bel[#bel + 1] = { sp[i][1] - sn[i][1] * bk * sw[i] * r_, sp[i][2] - sn[i][2] * bk * sw[i] * r_ }
      end
      if g.coat ~= "calico" then ink.smooth(bel, true) ink.fill(ge.white, 0.96) end
      -- and the chest
      local p, w = sp[n], sw[n]
      ink.smooth(ink.blob(rng, p[1] - sn[n][1] * bk * w * 0.3, p[2] - sn[n][2] * bk * w * 0.3, w * 0.56, w * 0.64, 0.2, 8), true) ink.fill(ge.white, 0.96)
    end
    if Tm.back == -1 then                              -- belly up: the pale belly fur faces us
      local bel = {}
      for i = 1, n do bel[#bel + 1] = { sp[i][1] + sn[i][1] * sw[i] * 0.48, sp[i][2] + sn[i][2] * sw[i] * 0.48 } end
      for i = n, 1, -1 do bel[#bel + 1] = { sp[i][1] - sn[i][1] * sw[i] * 0.06, sp[i][2] - sn[i][2] * sw[i] * 0.06 } end
      ink.smooth(bel, true) ink.fill(mix(ge.base, ge.white, 0.72), 0.86)
    end
    -- old bones and a slack belly
    if g.bony then
      for _, u in ipairs({ 0.14, 0.72 }) do
        local i = 1 + floor(u * (n - 1))
        local p, nn, w = sp[i], sn[i], sw[i]
        local bx, by = p[1] + nn[1] * bk * w * 0.22, p[2] + nn[2] * bk * w * 0.22
        ink.moveto(bx - nn[2] * w * 0.22, by + nn[1] * w * 0.22)
        ink.curveto(bx - nn[1] * bk * w * 0.14, by - nn[2] * bk * w * 0.14, bx - nn[1] * bk * w * 0.14, by - nn[2] * bk * w * 0.14, bx + nn[2] * w * 0.22, by - nn[1] * w * 0.22)
        ink.stroke(ge.shade, max(0.4, 1.8 * ink.unit() * ink.CM), 0.32, true)
      end
      -- ribs, just
      if fine then
        local i0 = 1 + floor(0.42 * (n - 1))
        for k = 0, 2 do
          local i = i0 + k * 2
          if i <= n then
            local p, nn, w = sp[i], sn[i], sw[i]
            streak3(p[1] + nn[1] * bk * w * 0.3, p[2] + nn[2] * bk * w * 0.3, p[1] + nn[1] * bk * w * 0.14, p[2] + nn[2] * bk * w * 0.14, p[1], p[2], p[1] - nn[1] * bk * w * 0.12, p[2] - nn[2] * bk * w * 0.12, 1.8, 0.5, ge.shade, 0.2, true)
          end
        end
      end
    elseif g.sag > 0.4 then
      local i = 1 + floor(0.38 * (n - 1))
      local j = 1 + floor(0.72 * (n - 1))
      local a, b = sp[i], sp[j]
      local nx, ny = -sn[i][1] * bk, -sn[i][2] * bk
      ink.moveto(a[1] + nx * sw[i] * 0.2, a[2] + ny * sw[i] * 0.2)
      ink.curveto(a[1] + nx * sw[i] * 0.34, a[2] + ny * sw[i] * 0.34, b[1] + nx * sw[j] * 0.34, b[2] + ny * sw[j] * 0.34, b[1] + nx * sw[j] * 0.2, b[2] + ny * sw[j] * 0.2)
      ink.stroke(ge.shade, max(0.4, 1.8 * ink.unit() * ink.CM), 0.28, true)
    end
    round_part(sp, sw, sn, flip, 1.15, ge)
    for _, l in ipairs(Tm.lobes or {}) do
      local rx, ry = l[3] * lerp(1, g.fat, 0.7), l[4] * lerp(1, g.fat, 0.7)
      local dir_ = (sp[n][1] >= sp[1][1]) and 1 or -1
      local arc = {}
      for a = -55, 65, 15 do arc[#arc + 1] = { l[1] + dir_ * rx * cos(a * rad), l[2] + ry * sin(a * rad) } end
      ink.smooth(arc, false) ink.stroke(ge.shade, max(0.4, 1.8 * ink.unit() * ink.CM), 0.3, true)
    end
    -- age: pale hairs through the coat
    if fine then
      local nh = floor(10 + 20 * g.age)
      for _ = 1, nh do
        local i = rng.int(1, n)
        local a_ = rng.sym(sw[i] * 0.42)
        local x, y = sp[i][1] + sn[i][1] * a_, sp[i][2] + sn[i][2] * a_
        local tx_, ty_ = -sn[i][2], sn[i][1]
        local dir = (bk or 1)
        ink.moveto(x, y) ink.lineto(x + dir * tx_ * 2.4 + rng.sym(0.6), y + dir * ty_ * 2.4 + rng.sym(0.6))
      end
      ink.stroke(ge.frost, 0.25, 0.55)
    end
    -- scruff: the coat of a cat who has stopped grooming so well
    ink.smooth(torso[1], true, 0.85) ink.stroke(ge.shade, max(0.5, 2.4 * ink.unit() * ink.CM), 0.2, true)
  ink.unclip()
  -- fur tufts along the back and belly
  if fine then
    for i = 2, n - 1, 2 do
      for _, sd in ipairs({ 1, -1 }) do
        if rng.chance(g.bony and 0.8 or 0.5) then
          local p, nn, w = sp[i], sn[i], sw[i]
          local x, y = p[1] + nn[1] * sd * w * 0.49, p[2] + nn[2] * sd * w * 0.49
          local tx_, ty_ = -nn[2] * bk, nn[1] * bk
          streak3(x, y, x + tx_ * 1 + nn[1] * sd, y + ty_ * 1 + nn[2] * sd, x + tx_ * 2 + nn[1] * sd * 1.4, y + ty_ * 2 + nn[2] * sd * 1.4, x + tx_ * 3.4 + nn[1] * sd * 1.6, y + ty_ * 3.4 + nn[2] * sd * 1.6, 2.2, 0.3, ge.base)
        end
      end
    end
  end
  if Tm.prop == "hammock" then prop_front(rng, "hammock", s) end
  for _, l in ipairs(Tm.dangle or {}) do paint_limb(l, false) end
  for _, l in ipairs(Tm.near or {}) do paint_limb(l, false) end
  if Tm.tail and Tm.tail.front then paint_tail() end
  head(rng, g, Tm.head, ge, flip)
  if Tm.prop == "bowl" then prop_front(rng, "bowl", s) end
  ink.pop()
end

-- ---------------------------------------------------------------- the skeleton of one cat
-- One cat's parts, in painting order, from a template and genes: every style draws from this.
-- part: kind (far, tail, torso, near, dangle), pts, ws, nrm (with the fur's direction along pts)
local function lum(p) p = type(p) == "table" and p or PIGMENT[p] return 0.3 * p[1] + 0.55 * p[2] + 0.15 * p[3] end
local function bones(rng, Tm, g)
  local parts = {}
  local function limb(ctrl, kind)
    local c2 = {}
    for i, p in ipairs(ctrl) do
      c2[i] = { p[1] + (i > 1 and rng.sym(1.6) or 0), p[2] + (i > 1 and rng.sym(1.6) or 0), p[3] * g.leg * (g.bony and 0.9 or lerp(1, g.fat, 0.35)) }
    end
    local a, b, c = run(c2, 4)
    return { kind = kind, pts = a, ws = b, nrm = c }
  end
  for _, l in ipairs(Tm.far or {}) do parts[#parts + 1] = limb(l, "far") end
  local function tail()
    local c2 = {}
    local r0 = Tm.tail[1]
    for i, p in ipairs(Tm.tail) do
      c2[i] = { r0[1] + (p[1] - r0[1]) * g.tail + (i > 1 and rng.sym(2.4) or 0), r0[2] + (p[2] - r0[2]) * g.tail + (i > 1 and rng.sym(2.4) or 0), p[3] * g.tailw * (g.fluff and 1.4 or 1.08) }
    end
    local a, b, c = run(c2, 5)
    return { kind = "tail", pts = a, ws = b, nrm = c }
  end
  if Tm.tail and not Tm.tail.front then parts[#parts + 1] = tail() end
  local spine = {}
  local ns = #Tm.spine
  for i, p in ipairs(Tm.spine) do
    local mid = 1 - abs((i - 1) / max(1, ns - 1) * 2 - 1)
    spine[i] = { p[1] + rng.sym(1.2), p[2] + rng.sym(1.2), p[3] * lerp(1, g.fat, 0.45 + 0.55 * mid) + (g.sag > 0 and g.sag * 5 * mid or 0) }
  end
  local a, b, c = run(spine, 5)
  local torso = { kind = "torso", pts = a, ws = b, nrm = c, back = Tm.back or 1, lobes = {} }
  for _, l in ipairs(Tm.lobes or {}) do torso.lobes[#torso.lobes + 1] = { l[1], l[2], l[3] * lerp(1, g.fat, 0.7), l[4] * lerp(1, g.fat, 0.7) } end
  parts[#parts + 1] = torso
  for _, l in ipairs(Tm.dangle or {}) do parts[#parts + 1] = limb(l, "dangle") end
  for _, l in ipairs(Tm.near or {}) do parts[#parts + 1] = limb(l, "near") end
  if Tm.tail and Tm.tail.front then parts[#parts + 1] = tail() end
  return parts, torso
end
-- a little noise in two dimensions
local function noise2(rng)
  local f1, f2 = ink.fbm1(rng, 2), ink.fbm1(rng, 2)
  return function(x, y) return f1(x + 2.3 * f2(y)) end
end
-- how dark the coat is at a point: u across the part (-1 belly side .. 1 back side), t along it
local function coat_dark(g, part, t, u, x, y, nz)
  local c = g.coat
  local base = 1 - lum(g.base)
  if c == "tabby" or c == "blotched" then
    local mk = 1 - lum(g.mark)
    local band
    if c == "tabby" then band = sin(t * (part.kind == "torso" and 34 or 16) + u * 1.2 + nz(x * 0.02, y * 0.02) * 2)
    else band = sin(sqrt(x * x * 0.8 + y * y) * 0.34 + nz(x * 0.03, y * 0.03) * 2.5) end
    if band > 0.3 then base = mk * 1.25 end
    if g.white and u < -0.35 and part.kind == "torso" then base = 0.06 end
  elseif c == "tortie" then
    local n = nz(x * 0.05, y * 0.05)
    base = n > 0.08 and 1 - lum(g.a) or n < -0.1 and 1 - lum(g.b) or base
  elseif c == "calico" then
    local n = nz(x * 0.035, y * 0.035)
    base = n > 0.22 and 1 - lum(g.a) or n < -0.22 and 1 - lum(g.b) or 0.05
  elseif c == "tuxedo" then
    if part.kind == "torso" and u * (part.back or 1) < -0.3 then base = 0.05 end
    if (part.kind == "near" or part.kind == "far" or part.kind == "dangle") and t > 0.72 then base = 0.05 end
  elseif c == "van" then
    base = part.kind == "tail" and 1 - lum(g.a) or 0.05
  elseif c == "point" then
    if part.kind == "torso" then base = 0.14 + 0.2 * max(0, u) else base = lerp(0.16, 1 - lum(g.a), min(1, t * 1.8)) end
  elseif c == "smoke" then
    base = base * (0.55 + 0.45 * max(0, u))
  end
  return max(0.03, min(1, base))
end
local function outline_of(part)
  local list = { ribbon_of(part.pts, part.ws, part.nrm) }
  for _, l in ipairs(part.lobes or {}) do list[#list + 1] = ccw(ell(l[1], l[2], l[3], l[4], 12)) end
  if part.kind ~= "torso" then
    local e, w = part.pts[#part.pts], part.ws[#part.ws]
    list[#list + 1] = ccw(ell(e[1], e[2], w * 0.56, w * 0.56, 8))
    local b, w0 = part.pts[1], part.ws[1]
    list[#list + 1] = ccw(ell(b[1], b[2], w0 * 0.5, w0 * 0.5, 8))
  end
  return list
end

-- ---------------------------------------------------------------- style: fur
-- Nothing but thousands of short pen strokes: density is the tone. Strokes follow the lie of the
-- coat, shoulders to rump and out at the edges, overhanging the silhouette so that it has no line;
-- each part first hides what is behind it with paper, and its edge goes dark where it lies over another.
local function fur_head(rng, g, H, flip, hairs)
  local x, y, r, rot, eyes, turn = H[1], H[2], H[3] * g.head * 1.04, H[4] or 0, H[5] or "shut", H[6] or 0
  local dens = hairs.dens
  ink.push() ink.translate(x, y) ink.rotate(rot)
  local tx = turn * r * 0.2
  local dhead = max(0.55, (1 - lum(g.base)) * 0.7 + 0.45)
  if g.coat == "point" then dhead = 1 end
  if g.coat == "van" or g.coat == "calico" then dhead = 0.85 end
  -- the ears and head: paper, then fur
  local eL = { { -r * 0.92, r * 0.42 }, { -r * 0.72 + tx * 0.4, r * (0.86 + 0.8 * g.ear) }, { -r * 0.12, r * 0.86 } }
  local eR = { { r * 0.12, r * 0.86 }, { r * 0.72 + tx * 0.4, r * (0.86 + 0.8 * g.ear) }, { r * 0.92, r * 0.42 } }
  ink.smooth(ell(0, 0, r * 1.02, r * 0.92, 12), true, 1) ink.fill(ink.paper)
  ink.poly(eL, true) ink.poly(eR, true) ink.fill(ink.paper)
  local nz = hairs.nz
  local N = floor(pi * r * r * dens * 1.8)
  local L = hairs.len
  for _ = 1, N do
    local a, d = rng.range(0, 2 * pi), sqrt(rng.u())
    local px, py = d * cos(a) * r * 1.02, d * sin(a) * r * 0.92
    local dk = dhead * (0.55 + 0.45 * d)
    -- the old pale muzzle, a blaze on white-marked cats
    local mx, my = (px - tx) / (r * 0.62), (py + r * 0.42) / (r * 0.55)
    if mx * mx + my * my < 1 then dk = dk * (1 - 0.82 * g.age) end
    if (g.coat == "tuxedo" or g.white) and abs(px - tx) < r * 0.22 * (1 - py / r) and py < r * 0.6 then dk = 0.04 end
    if g.coat == "tabby" and py > r * 0.3 and sin((px - tx) / r * 9) > 0.2 then dk = min(1, dk * 1.8) end
    if rng.u() < dk then
      local out = atan(py + r * 0.3, px - tx)
      local aa = out + rng.sym(0.32)
      ink.moveto(px, py) ink.lineto(px + cos(aa) * L * rng.range(0.55, 1), py + sin(aa) * L * rng.range(0.55, 1))
    end
  end
  for _, e in ipairs({ eL, eR }) do
    local nE = floor(r * r * 0.55 * dens)
    for _ = 1, nE do
      local a_, b_ = rng.u(), rng.u()
      if a_ + b_ > 1 then a_, b_ = 1 - a_, 1 - b_ end
      local px = e[1][1] + (e[2][1] - e[1][1]) * a_ + (e[3][1] - e[1][1]) * b_
      local py = e[1][2] + (e[2][2] - e[1][2]) * a_ + (e[3][2] - e[1][2]) * b_
      local dirx, diry = e[2][1] - px, e[2][2] - py
      local l_ = sqrt(dirx * dirx + diry * diry) + 1e-6
      local ll = min(L * 0.7, l_)
      ink.moveto(px, py) ink.lineto(px + dirx / l_ * ll + rng.sym(0.2), py + diry / l_ * ll + rng.sym(0.2))
    end
  end
  ink.stroke(tone(0.08), hairs.w, 0.9)
  -- eyes: paper, cut out of the dark
  local ex, ey = r * 0.4, r * 0.1
  local er = r * 0.2
  local cc = dhead > 0.35 and ink.paper or tone(0.06)
  for i, sd in ipairs({ -1, 1 }) do
    local xx, yy = tx + sd * ex, ey
    if eyes == "shut" or eyes == "yawn" then
      ink.moveto(xx - er, yy + er * 0.15) ink.curveto(xx - er * 0.4, yy - er * 0.55, xx + er * 0.4, yy - er * 0.55, xx + er, yy + er * 0.15)
      ink.stroke(cc, max(0.5, r * 0.07 * ink.unit() * ink.CM))
    else
      -- a heavy-lidded old eye: paper with a dark pupil, its top cut level
      local eye_ = {}
      for k = 0, 12 do local a = pi + pi * k / 12 eye_[#eye_ + 1] = { xx + er * cos(a), yy + er * 0.95 * sin(a) * 0.9 } end
      eye_[#eye_ + 1] = { xx + er, yy + er * 0.2 } eye_[#eye_ + 1] = { xx - er, yy + er * 0.2 }
      ink.smooth(eye_, true, 0.8) ink.fill(g.cloudy == i and tone(0.86) or ink.paper)
      ink.smooth(ell(xx + turn * er * 0.25, yy - er * 0.25, er * 0.42, er * 0.5, 8), true) ink.fill(g.cloudy == i and tone(0.55) or tone(0.04))
    end
  end
  if eyes == "yawn" then
    ink.smooth(ell(tx, -r * 0.44, r * 0.26, r * 0.28, 9), true) ink.fill(tone(0.06))
    ink.smooth(ell(tx, -r * 0.54, r * 0.15, r * 0.1, 7), true) ink.fill(tone(0.5))
  else
    ink.smooth(ccw({ { tx - r * 0.09, -r * 0.2 }, { tx + r * 0.09, -r * 0.2 }, { tx, -r * 0.31 } }), true, 0.5) ink.fill(tone(0.1))
  end
  -- whiskers
  for _, sd in ipairs({ -1, 1 }) do
    for k = -1, 1 do
      local w0x, w0y = tx + sd * r * 0.3, -r * 0.36 + k * r * 0.07
      ink.moveto(w0x, w0y) ink.curveto(w0x + sd * r * 0.5, w0y + k * r * 0.03, w0x + sd * r * 0.95 * g.whisk, w0y - r * 0.05, w0x + sd * r * 1.45 * g.whisk, w0y + k * r * 0.24 - r * 0.2)
    end
  end
  ink.stroke(dhead > 0.5 and ink.paper or tone(0.12), 0.25, 0.9)
  ink.pop()
end
local function draw_fur(rng, Tm, g, s, flip)
  local parts = bones(rng, Tm, g)
  local nz = noise2(rng)
  local unit = 100 / s                                 -- units per cm
  local hairs = { dens = 720 / (unit * unit) * (g.density or 1), len = min(6.5, 0.125 * unit), w = 0.2, nz = nz }
  local Lx, Ly = LIGHT[1] * flip, LIGHT[2]
  local L = hairs.len
  if Tm.prop then prop_back(rng, Tm.prop, s) end
  local function part_fur(part)
    local outl = outline_of(part)
    shapes(outl) ink.fill(ink.paper)
    local pts, ws, nrm = part.pts, part.ws, part.nrm
    local n = #pts
    local s_, total = ink.arclen(pts)
    local far = part.kind == "far"
    for i = 1, n - 1 do
      local seg = s_[i + 1] - s_[i]
      local w = (ws[i] + ws[i + 1]) / 2
      -- by the quad's real area: a bend has more outside than in
      local ax_, ay_ = pts[i + 1][1] + nrm[i + 1][1] * ws[i + 1] / 2 - pts[i][1] - nrm[i][1] * ws[i] / 2, pts[i + 1][2] + nrm[i + 1][2] * ws[i + 1] / 2 - pts[i][2] - nrm[i][2] * ws[i] / 2
      local bx_, by_ = pts[i + 1][1] - nrm[i + 1][1] * ws[i + 1] / 2 - pts[i][1] + nrm[i][1] * ws[i] / 2, pts[i + 1][2] - nrm[i + 1][2] * ws[i + 1] / 2 - pts[i][2] + nrm[i][2] * ws[i] / 2
      local seglen_ = (sqrt(ax_ * ax_ + ay_ * ay_) + sqrt(bx_ * bx_ + by_ * by_)) / 2
      local N = floor(seglen_ * w * hairs.dens * 1.7 + rng.u())
      local tx_, ty_ = -nrm[i][2], nrm[i][1]         -- along the part, toward its end
      local dirf = part.kind == "torso" and -1 or 1    -- fur runs shoulders to rump, shoulders to paws
      for _ = 1, N do
        local f = rng.u()
        local u = rng.range(-1, 1)
        local nx_, ny_ = lerp(nrm[i][1], nrm[i + 1][1], f), lerp(nrm[i][2], nrm[i + 1][2], f)
        local wf = lerp(ws[i], ws[i + 1], f)
        local px = lerp(pts[i][1], pts[i + 1][1], f) + nx_ * u * wf / 2 * 1.02
        local py = lerp(pts[i][2], pts[i + 1][2], f) + ny_ * u * wf / 2 * 1.02
        local t = (s_[i] + f * seg) / max(total, 1e-6)
        local ub = part.kind == "torso" and u * (part.back or 1) or u
        -- the form: lit on one side, dark at the far edge and in the creases
        local dl = nx_ * Lx + ny_ * Ly
        local shade = 0.5 - 0.42 * dl * u + 0.5 * max(0, abs(u) - 0.72) / 0.28 * (dl * u < 0 and 1 or 0.35)
        local dk = coat_dark(g, part, t, ub, px, py, nz)
        local v = dk * (0.5 + shade * 0.95)
        if far then v = v * 1.3 end
        if part.kind == "tail" then v = v * (0.75 + 0.6 * t) end
        if (part.kind == "near" or part.kind == "dangle") and t < 0.14 then v = v * 0.4 end
        -- pale coats keep their form: an edge of hairs round them, and a thin tone everywhere
        local rim = abs(u) > 0.82 and 0.42 or 0
        v = max(rim, 0.13 + 0.87 * v)
        if rng.u() < v then
          local spread = u * (0.5 + 0.9 * u * u)
          local tx2, ty2 = -ny_, nx_
          local dx = dirf * tx2 + nx_ * spread + rng.sym(0.26)
          local dy = dirf * ty2 + ny_ * spread + rng.sym(0.26)
          local dn = sqrt(dx * dx + dy * dy) + 1e-6
          local ll = L * rng.range(0.6, 1.1) * (abs(u) > 0.8 and 1.5 or 1)
          ink.moveto(px, py) ink.lineto(px + dx / dn * ll, py + dy / dn * ll)
        end
      end
    end
    ink.stroke(tone(0.08), hairs.w, 0.9)
    -- old cat: a few long stray hairs; a crease under the belly and at the haunch
    for _, l in ipairs(part.lobes or {}) do
      local dir_ = (pts[n][1] >= pts[1][1]) and 1 or -1
      for _ = 1, floor((l[3] + l[4]) * 2 * hairs.dens * 3) do
        local an = rng.range(-55, 70) * rad
        local rr = rng.range(0.9, 1.04)
        local px, py = l[1] + dir_ * l[3] * rr * cos(an), l[2] + l[4] * rr * sin(an)
        local aa = an + dir_ * pi / 2 + rng.sym(0.4)
        ink.moveto(px, py) ink.lineto(px + cos(aa) * L * 0.8, py + sin(aa) * L * 0.8)
      end
      ink.stroke(tone(0.05), hairs.w, 0.75)
    end
  end
  for _, part in ipairs(parts) do
    if Tm.prop == "hammock" and part.kind == "dangle" and not parts.cloth then prop_front(rng, "hammock", s) parts.cloth = true end
    part_fur(part)
  end
  if Tm.prop == "hammock" and not parts.cloth then prop_front(rng, "hammock", s) end
  fur_head(rng, g, Tm.head, flip, hairs)
  if Tm.prop == "bowl" then prop_front(rng, "bowl", s) end
end

-- ---------------------------------------------------------------- style: wash
-- Marching squares: closed loops around everything above level, the higher side on the left, so
-- that holes wind the other way and a nonzero fill keeps them open.
local function contours(F, nx, ny, x0, y0, h, level)
  local nextp = {}
  local function key(i, j, e) return (i * 4096 + j) * 4 + e end   -- e: 0 bottom, 1 right, 2 top, 3 left of a cell
  local pos = {}
  local function cross(a, b) return (level - a) / (b - a) end
  for j = 0, ny - 2 do
    for i = 0, nx - 2 do
      local a, b, c, d = F[j * nx + i + 1], F[j * nx + i + 2], F[(j + 1) * nx + i + 2], F[(j + 1) * nx + i + 1]
      local code = (a > level and 1 or 0) + (b > level and 2 or 0) + (c > level and 4 or 0) + (d > level and 8 or 0)
      if code ~= 0 and code ~= 15 then
        local function P(e)
          if e == 0 then return x0 + (i + cross(a, b)) * h, y0 + j * h
          elseif e == 1 then return x0 + (i + 1) * h, y0 + (j + cross(b, c)) * h
          elseif e == 2 then return x0 + (i + cross(d, c)) * h, y0 + (j + 1) * h
          else return x0 + i * h, y0 + (j + cross(a, d)) * h end
        end
        -- edges are shared with neighbors: name them the same from both sides
        local function E(e)
          if e == 0 then return key(i, j, 0)
          elseif e == 1 then return key(i + 1, j, 3)
          elseif e == 2 then return key(i, j + 1, 0)
          else return key(i, j, 3) end
        end
        local function seg(e0, e1)
          local k0, k1 = E(e0), E(e1)
          nextp[k0] = k1
          if not pos[k0] then local x, y = P(e0) pos[k0] = { x, y } end
          if not pos[k1] then local x, y = P(e1) pos[k1] = { x, y } end
        end
        -- higher on the left of the direction of travel
        if code == 1 then seg(3, 0) elseif code == 2 then seg(0, 1) elseif code == 3 then seg(3, 1)
        elseif code == 4 then seg(1, 2) elseif code == 5 then seg(3, 2) seg(1, 0) elseif code == 6 then seg(0, 2)
        elseif code == 7 then seg(3, 2) elseif code == 8 then seg(2, 3) elseif code == 9 then seg(2, 0)
        elseif code == 10 then seg(0, 3) seg(2, 1) elseif code == 11 then seg(2, 1) elseif code == 12 then seg(1, 3)
        elseif code == 13 then seg(1, 0) elseif code == 14 then seg(0, 3) end
      end
    end
  end
  -- in a fixed order: never pairs() where it feeds the output
  local keys = {}
  for k in pairs(nextp) do keys[#keys + 1] = k end
  table.sort(keys)
  local loops = {}
  for _, k0 in ipairs(keys) do
    if nextp[k0] then
      local loop, k = {}, k0
      while k and nextp[k] do
        loop[#loop + 1] = pos[k]
        local nx_ = nextp[k]
        nextp[k] = nil
        k = nx_
      end
      if #loop >= 4 then loops[#loops + 1] = loop end
    end
  end
  return loops
end

-- Wet paper, simulated. Pigment is put down on a grid in the shape of the cat, heavier where its coat is
-- dark; the water carries it outward through paper whose grain makes some paths easier than others,
-- so edges feather; then the result is traced at many levels and painted from pale to dark, which is
-- still only paths. Faces are lifted out before the water moves; eyes and whiskers are drawn dry.
local function draw_wash(rng, Tm, g, s, flip)
  local parts = bones(rng, Tm, g)
  if Tm.prop then prop_back(rng, Tm.prop, s) end
  local b = Tm.box
  local H_ = Tm.head
  local hr = H_[3] * g.head * 1.04
  -- the grid: a step in units that keeps a steady size on the page
  local cm = 100 / s                                   -- units per cm
  local h = max(0.065 * cm, (b[3] - b[1]) / 110)
  local pad = 18
  local x0, y0 = b[1] - pad, b[2] - pad
  local nx = floor((b[3] - b[1] + 2 * pad) / h) + 2
  local ny = floor((b[4] - b[2] + 2 * pad + hr) / h) + 2
  local F, G = {}, {}
  for i = 1, nx * ny do F[i] = 0 end
  local nz = noise2(rng)
  local function stamp(x, y, r, v)
    local ri = floor(r / h) + 2
    local cx, cy = floor((x - x0) / h), floor((y - y0) / h)
    for j = max(0, cy - ri), min(ny - 1, cy + ri) do
      for i = max(0, cx - ri), min(nx - 1, cx + ri) do
        local dx, dy = x0 + i * h - x, y0 + j * h - y
        local d = sqrt(dx * dx + dy * dy) / r
        if d < 1 then
          local q = j * nx + i + 1
          local f_ = v * min(1, (1 - d) * 3.2)
          if f_ > F[q] then F[q] = f_ end
        end
      end
    end
  end
  -- every part: discs along it, the coat deciding how much pigment
  for _, part in ipairs(parts) do
    local n = #part.pts
    local sp_, total = ink.arclen(part.pts)
    for i = 1, n do
      local p, nn, w = part.pts[i], part.nrm[i], part.ws[i]
      local t = sp_[i] / max(total, 1e-6)
      local steps = 3
      for k = -steps, steps do
        local u = k / steps * 0.72
        local x, y = p[1] + nn[1] * u * w / 2, p[2] + nn[2] * u * w / 2
        local ub = part.kind == "torso" and u * (part.back or 1) or u
        local v = 0.08 + 0.8 * coat_dark(g, part, t, ub, x, y, nz) ^ 1.2
        stamp(x, y, w * 0.34, v)
      end
    end
    for _, l in ipairs(part.lobes or {}) do stamp(l[1], l[2], (l[3] + l[4]) / 2, 0.14 + 0.86 * (1 - lum(g.base)) * 0.9) end
  end
  -- the head, and a gap of light around it, so that it stands off the body
  local hx, hy = H_[1], H_[2]
  local rot = (H_[4] or 0) * rad
  local tx = (H_[6] or 0) * hr * 0.2
  local function H2(u, v) return hx + u * cos(rot) - v * sin(rot), hy + u * sin(rot) + v * cos(rot) end
  local ring = hr * 1.14
  do
    local ri = floor(ring / h) + 2
    local cx, cy = floor((hx - x0) / h), floor((hy - y0) / h)
    for j = max(0, cy - ri), min(ny - 1, cy + ri) do
      for i = max(0, cx - ri), min(nx - 1, cx + ri) do
        local dx, dy = x0 + i * h - hx, y0 + j * h - hy
        if dx * dx + dy * dy < ring * ring then
          local q = j * nx + i + 1
          F[q] = F[q] * 0.3
        end
      end
    end
  end
  local hdark = g.coat == "van" and 0.8 or g.coat == "point" and 1 or (g.coat == "tabby" or g.coat == "blotched") and 0.6 or (g.coat == "calico" or g.coat == "tortie") and 0.75 or (1 - lum(g.base))
  stamp(hx, hy, hr, 0.16 + 0.84 * hdark)
  -- a darker cap, the crown
  local cx_, cy_ = H2(0, hr * 0.42)
  stamp(cx_, cy_, hr * 0.74, 0.3 + 0.7 * hdark)
  -- the muzzle lifted out, more with age; around the eyes on the dark ones
  local function lift(x, y, r, k)
    local ri = floor(r / h) + 2
    local cx, cy = floor((x - x0) / h), floor((y - y0) / h)
    for j = max(0, cy - ri), min(ny - 1, cy + ri) do
      for i = max(0, cx - ri), min(nx - 1, cx + ri) do
        local dx, dy = x0 + i * h - x, y0 + j * h - y
        local d = sqrt(dx * dx + dy * dy) / r
        if d < 1 then
          local q = j * nx + i + 1
          F[q] = F[q] * (1 - k * min(1, (1 - d) * 2))
        end
      end
    end
  end
  local mx_, my_ = H2(tx, -hr * 0.46)
  lift(mx_, my_, hr * 0.62, 0.55 + 0.4 * g.age)
  local eyes = H_[5] or "shut"
  if eyes ~= "shut" and hdark > 0.5 then
    for _, sd in ipairs({ -1, 1 }) do
      local ex_, ey_ = H2(tx + sd * hr * 0.4, hr * 0.1)
      lift(ex_, ey_, hr * 0.36, 0.78)
    end
  end
  if g.coat == "tuxedo" or g.white then
    local bx_, by_ = H2(tx, -hr * 1.1)
    lift(bx_, by_, hr * 0.7, 0.7)
  end
  -- the paper's grain: how readily water crosses each point
  local C_ = {}
  for j = 0, ny - 1 do
    for i = 0, nx - 1 do
      local x, y = x0 + i * h, y0 + j * h
      C_[j * nx + i + 1] = 0.4 + 0.22 * nz(x * 0.09, y * 0.09) + 0.3 * rng.sym(1)
    end
  end
  -- the water moves
  local iters = g.wet or 20
  for _ = 1, iters do
    for j = 0, ny - 1 do
      for i = 0, nx - 1 do
        local q = j * nx + i + 1
        local v = F[q]
        local sum = v
        local cnt = 1
        if i > 0 then sum = sum + F[q - 1] cnt = cnt + 1 end
        if i < nx - 1 then sum = sum + F[q + 1] cnt = cnt + 1 end
        if j > 0 then sum = sum + F[q - nx] cnt = cnt + 1 end
        if j < ny - 1 then sum = sum + F[q + nx] cnt = cnt + 1 end
        local m = sum / cnt
        local c_ = C_[q]
        if c_ < 0 then c_ = 0 end
        G[q] = v + (m - v) * min(0.95, c_ * 1.5)
      end
    end
    F, G = G, F
  end
  -- feathers: grain at the fading edge of the wash
  for q = 1, nx * ny do
    local v = F[q]
    if v > 0.012 and v < 0.26 then F[q] = v * (1 + rng.sym(1.05) * (1 - v / 0.26)) end
  end
  for j = 0, ny - 1 do F[j * nx + 1], F[j * nx + nx] = 0, 0 end
  for i = 1, nx do F[i], F[(ny - 1) * nx + i] = 0, 0 end
  -- traced at many levels, pale to dark
  local lv = { 0.03, 0.05, 0.08, 0.11, 0.15, 0.19, 0.24, 0.3, 0.36, 0.43, 0.5, 0.57, 0.64, 0.71, 0.78, 0.85 }
  local lod = ink.unit() * 100
  for li, level in ipairs(lv) do
    if lod > 2.5 or li % 2 == 0 then
      local loops = contours(F, nx, ny, x0, y0, h, level)
      if #loops > 0 then
        for _, loop in ipairs(loops) do
          local kept = {}
          local stepk = (#loop > 60 and lod <= 2.5) and 2 or 1
          for k = 1, #loop, stepk do kept[#kept + 1] = loop[k] end
          if #kept >= 3 then ink.poly(kept, true) end
        end
        -- tone follows pigment: pale water to the near black of a loaded brush
        ink.fill(tone(max(0.03, 0.97 - 1.12 * level ^ 0.95)))
      end
    end
  end
  if Tm.prop == "hammock" then prop_front(rng, "hammock", s) end
  -- dry: the ears' crisp edges, the eyes, whiskers
  ink.push() ink.translate(hx, hy) ink.rotate(H_[4] or 0)
  local r = hr
  local eL = { { -r * 0.92, r * 0.44 }, { -r * 0.72 + tx * 0.4, r * (0.86 + 0.8 * g.ear) }, { -r * 0.14, r * 0.82 } }
  local eR = { { r * 0.14, r * 0.82 }, { r * 0.72 + tx * 0.4, r * (0.86 + 0.8 * g.ear) }, { r * 0.92, r * 0.44 } }
  local ec = tone(lerp(0.62, 0.05, hdark))
  for _, e in ipairs({ eL, eR }) do
    ink.smooth({ e[1], { (e[1][1] + e[2][1]) / 2, (e[1][2] + e[2][2]) / 2 }, e[2], { (e[2][1] + e[3][1]) / 2, (e[2][2] + e[3][2]) / 2 }, e[3], { (e[1][1] + e[3][1]) / 2, (e[1][2] + e[3][2]) / 2 - r * 0.08 } }, true, 0.3)
    ink.fill(ec)
    ink.moveto(e[1][1], e[1][2]) ink.lineto(e[2][1], e[2][2]) ink.lineto(e[3][1], e[3][2])
    ink.stroke(tone(0.05), 0.4, 0.8)
  end
  local line = tone(0.05)
  local er = r * 0.19
  for i, sd in ipairs({ -1, 1 }) do
    local xx, yy = tx + sd * r * 0.4, r * 0.1
    if eyes == "shut" or eyes == "yawn" then
      ink.moveto(xx - er, yy + er * 0.15) ink.curveto(xx - er * 0.4, yy - er * 0.55, xx + er * 0.4, yy - er * 0.55, xx + er, yy + er * 0.15)
      ink.stroke(hdark > 0.72 and ink.paper or line, max(0.4, r * 0.05 * ink.unit() * ink.CM))
    else
      ink.smooth(ell(xx, yy - er * 0.1, er, er * 0.68, 10), true) ink.fill(g.cloudy == i and tone(0.82) or ink.paper)
      ink.smooth(ell(xx, yy - er * 0.1, er, er * 0.68, 10), true) ink.stroke(line, 0.35)
      ink.smooth(ell(xx, yy - er * 0.1, er * 0.27, er * 0.62, 8), true) ink.fill(g.cloudy == i and tone(0.5) or line)
    end
  end
  ink.smooth(ccw({ { tx - r * 0.08, -r * 0.22 }, { tx + r * 0.08, -r * 0.22 }, { tx, -r * 0.32 } }), true, 0.5) ink.fill(line)
  if eyes == "yawn" then ink.smooth(ell(tx, -r * 0.54, r * 0.2, r * 0.22, 8), true) ink.fill(line) end
  for _, sd in ipairs({ -1, 1 }) do
    for k = -1, 1 do
      local w0x, w0y = tx + sd * r * 0.28, -r * 0.34 + k * r * 0.07
      ink.moveto(w0x, w0y) ink.curveto(w0x + sd * r * 0.5, w0y, w0x + sd * r * 0.9 * g.whisk, w0y - r * 0.05, w0x + sd * r * 1.45 * g.whisk, w0y + k * r * 0.24 - r * 0.22)
    end
  end
  ink.stroke(hdark > 0.8 and ink.paper or line, 0.24, 0.9)
  ink.pop()
  if Tm.prop == "bowl" then prop_front(rng, "bowl", s) end
end

-- ---------------------------------------------------------------- style: gesture
-- How one draws a cat from life: faint circles for the masses, one sweep for the line of action, then
-- the contour, again and again: strokes that swell and thin with the pressure of the hand, overshoot
-- their ends, restate each other, heavier on the side away from the light. Nothing is filled in.
local function pencil(rng, pts, wmax, c, op, restate)
  -- a stroke through pts, pressure swelling in the middle, wandering
  local n = #pts
  if n < 2 then return end
  local wob = ink.fbm1(rng, 2)
  local ph = rng.range(0, 100)
  for pass = 1, restate or 1 do
    local left, right = {}, {}
    local nr = ink.normals(pts)
    local off = (pass - 1) * rng.sym(1.5)
    for i = 1, n do
      local t = (i - 1) / (n - 1)
      local press = wmax * (0.12 + 0.88 * sin(pi * t) ^ 0.7) * (0.75 + 0.4 * wob(t * 3 + ph + pass)) * (pass == 1 and 1 or 0.55)
      local dr = off + wob(t * 4 + ph * 2) * 0.7
      local x, y = pts[i][1] + nr[i][1] * dr, pts[i][2] + nr[i][2] * dr
      left[i] = { x + nr[i][1] * press / 2, y + nr[i][2] * press / 2 }
      right[i] = { x - nr[i][1] * press / 2, y - nr[i][2] * press / 2 }
    end
    for i = n, 1, -1 do left[#left + 1] = right[i] end
    ink.smooth(left, true, 0.9) ink.fill(c, op)
  end
end
local function draw_gesture(rng, Tm, g, s, flip)
  local parts, torso = bones(rng, Tm, g)
  local lod = ink.unit() * 100
  local bold = 6.2 / max(lod, 0.5)                     -- line widths in units: a steady pen on the page
  local c, faint = tone(0.1), tone(0.42)
  local Lx, Ly = LIGHT[1] * flip, LIGHT[2]
  if Tm.prop then prop_back(rng, Tm.prop, s) end
  -- the masses: ribcage, pelvis, in a faint quick line, more than once round
  local function circle_stroke(cx, cy, rx, ry, op)
    local a0 = rng.range(0, 6)
    local p = {}
    local turns = rng.range(1.05, 1.5)
    for k = 0, 22 do
      local a = a0 + 2 * pi * turns * k / 22
      local q = 1 + rng.sym(0.018)
      p[#p + 1] = { cx + rx * q * cos(a), cy + ry * q * sin(a) }
    end
    ink.smooth(p, false) ink.stroke(faint, 0.3, op)
  end
  local n = #torso.pts
  local i1, i2 = 1 + floor(0.14 * (n - 1)), 1 + floor(0.74 * (n - 1))
  circle_stroke(torso.pts[i1][1], torso.pts[i1][2], torso.ws[i1] * 0.5, torso.ws[i1] * 0.46, 0.55)
  circle_stroke(torso.pts[i2][1], torso.pts[i2][2], torso.ws[i2] * 0.52, torso.ws[i2] * 0.5, 0.55)
  -- the line of action, through the spine and on down the tail
  ink.smooth(torso.pts, false) ink.stroke(faint, 0.25, 0.45)
  local function edge(part, sd, i0, i1_, w, op, restate)
    local pts = {}
    for i = i0, i1_ do
      local p, nn, h = part.pts[i], part.nrm[i], part.ws[i] / 2
      pts[#pts + 1] = { p[1] + nn[1] * sd * h, p[2] + nn[2] * sd * h }
    end
    if #pts >= 2 then
      -- overshoot the ends, a little
      local a, b = pts[1], pts[2]
      table.insert(pts, 1, { a[1] + (a[1] - b[1]) * 0.6, a[2] + (a[2] - b[2]) * 0.6 })
      local y_, z = pts[#pts], pts[#pts - 1]
      pts[#pts + 1] = { y_[1] + (y_[1] - z[1]) * 0.6, y_[2] + (y_[2] - z[2]) * 0.6 }
      pencil(rng, pts, w, c, op, restate)
    end
  end
  for _, part in ipairs(parts) do
    local m = #part.pts
    local far = part.kind == "far"
    local k = far and 0.55 or 1
    local dl = part.nrm[floor(m / 2) + 1][1] * Lx + part.nrm[floor(m / 2) + 1][2] * Ly
    local darkside = dl > 0 and -1 or 1
    -- a light faint pass along each side, then the weight on the shadow side, in broken runs
    edge(part, -darkside, 1, m, bold * 0.5 * k, far and 0.55 or 0.8, 1)
    local cut = rng.int(floor(m * 0.4), max(floor(m * 0.4), floor(m * 0.65)))
    edge(part, darkside, 1, cut, bold * 1.25 * k, far and 0.6 or 0.92, part.kind == "torso" and 2 or 1)
    edge(part, darkside, max(1, cut - 1), m, bold * 1.0 * k, far and 0.6 or 0.92, 1)
    if part.kind ~= "torso" then
      local e = part.pts[m]
      local w = part.ws[m]
      local a_ = atan(e[2] - part.pts[m - 1][2], e[1] - part.pts[m - 1][1])
      if part.kind == "tail" then
        local cap = {}
        for q = -90, 90, 30 do cap[#cap + 1] = { e[1] + cos(a_ + q * rad) * w * 0.5, e[2] + sin(a_ + q * rad) * w * 0.5 } end
        pencil(rng, cap, bold * 0.8 * k, c, 0.9)
      else
        -- a paw: an oval, two strokes for toes
        local cap = {}
        for q = -120, 120, 30 do cap[#cap + 1] = { e[1] + cos(a_ + q * rad) * w * 0.68, e[2] + sin(a_ + q * rad) * w * 0.62 } end
        pencil(rng, cap, bold * 0.85 * k, c, 0.9)
        for q = -1, 1, 2 do
          local tx_ = e[1] + cos(a_ + q * 0.5) * w * 0.66
          local ty_ = e[2] + sin(a_ + q * 0.5) * w * 0.62
          ink.moveto(tx_, ty_) ink.lineto(tx_ - cos(a_) * w * 0.3, ty_ - sin(a_) * w * 0.3)
        end
        ink.stroke(c, 0.3, 0.7)
      end
    end
    -- the coat, only suggested: a few marks
    if part.kind == "torso" then
      local bk = part.back or 1
      for _, l in ipairs(part.lobes or {}) do
        local dir_ = (part.pts[m][1] >= part.pts[1][1]) and 1 or -1
        local arc = {}
        for q = -70, 75, 18 do arc[#arc + 1] = { l[1] + dir_ * l[3] * cos(q * rad), l[2] + l[4] * sin(q * rad) } end
        pencil(rng, arc, bold * 0.8, c, 0.85)
      end
      if g.coat == "tabby" or g.coat == "blotched" then
        for i = 3, m - 1, max(2, floor(m / 7)) do
          local p, nn, w = part.pts[i], part.nrm[i], part.ws[i]
          local a = { p[1] + nn[1] * bk * w * 0.46, p[2] + nn[2] * bk * w * 0.46 }
          local b = { p[1] + nn[1] * bk * w * 0.05, p[2] + nn[2] * bk * w * 0.05 }
          local mid_ = { (a[1] + b[1]) / 2 + rng.sym(1.5), (a[2] + b[2]) / 2 + rng.sym(1.5) }
          pencil(rng, { a, mid_, b }, bold * 1.1, c, 0.65)
        end
      elseif (1 - lum(g.base)) > 0.55 or g.coat == "tortie" or g.coat == "calico" then
        -- a dark coat: loose hatching along the shadow side
        local dl2 = part.nrm[floor(m / 2) + 1][1] * Lx + part.nrm[floor(m / 2) + 1][2] * Ly
        local ds = dl2 > 0 and -1 or 1
        for i = 2, m - 1 do
          local p, nn, w = part.pts[i], part.nrm[i], part.ws[i]
          local x_, y_ = p[1] + nn[1] * ds * w * rng.range(0.14, 0.42), p[2] + nn[2] * ds * w * rng.range(0.14, 0.42)
          local tx_, ty_ = -nn[2], nn[1]
          local ll = rng.range(2, 6)
          ink.moveto(x_ - tx_ * ll + nn[1] * ll * 0.5, y_ - ty_ * ll + nn[2] * ll * 0.5) ink.lineto(x_ + tx_ * ll - nn[1] * ll * 0.5, y_ + ty_ * ll - nn[2] * ll * 0.5)
        end
        ink.stroke(tone(0.22), 0.3, 0.6)
      end
    end
  end
  if Tm.prop == "hammock" then prop_front(rng, "hammock", s) end
  -- the head: a circle, a cross for the features, ears, the few marks of the face
  local H = Tm.head
  local x, y, r, rot, eyes, turn = H[1], H[2], H[3] * g.head, H[4] or 0, H[5] or "shut", H[6] or 0
  ink.push() ink.translate(x, y) ink.rotate(rot)
  local tx = turn * r * 0.22
  circle_stroke(0, 0, r, r * 0.92, 0.6)
  ink.moveto(tx * 2 - r * 0.1, r * 0.92) ink.curveto(tx * 2.2, r * 0.3, tx * 2.2, -r * 0.3, tx * 2 - r * 0.1, -r * 0.92) ink.stroke(faint, 0.22, 0.4)
  ink.moveto(-r, r * 0.08) ink.curveto(-r * 0.3, -r * 0.08, r * 0.3, -r * 0.08, r, r * 0.08) ink.stroke(faint, 0.22, 0.4)
  local jaw = {}
  for a = 170, 370, 18 do jaw[#jaw + 1] = { r * cos(a * rad) * 1.03, r * sin(a * rad) * 0.9 } end
  pencil(rng, jaw, bold * 1.0, c, 0.92)
  local topp = {}
  for a = 62, 118, 8 do topp[#topp + 1] = { r * cos(a * rad) * 0.96, r * sin(a * rad) * 0.92 } end
  pencil(rng, topp, bold * 0.7, c, 0.85)
  local function earstroke(sd)
    local base1 = { sd * r * 0.92, r * 0.34 }
    local tip = { sd * r * 0.72 + tx * 0.4, r * (0.86 + 0.8 * g.ear) }
    local base2 = { sd * r * 0.2, r * 0.84 }
    if g.torn == sd then tip = { sd * r * 0.66 + tx * 0.4, r * (0.8 + 0.66 * g.ear) } end
    pencil(rng, { base1, { (base1[1] + tip[1]) / 2 + sd * r * 0.03, (base1[2] + tip[2]) / 2 }, tip }, bold * 1.15, c, 0.92)
    pencil(rng, { tip, { (tip[1] + base2[1]) / 2 - sd * r * 0.03, (tip[2] + base2[2]) / 2 }, base2 }, bold * 0.95, c, 0.92)
  end
  earstroke(-1) earstroke(1)
  local er = r * 0.2
  for i, sd in ipairs({ -1, 1 }) do
    local xx, yy = tx + sd * r * 0.4, r * 0.08
    if eyes == "shut" or eyes == "yawn" then
      pencil(rng, { { xx - er, yy + er * 0.12 }, { xx - er * 0.3, yy - er * 0.4 }, { xx + er * 0.3, yy - er * 0.4 }, { xx + er, yy + er * 0.12 } }, bold * 0.9, c, 0.95)
    else
      pencil(rng, { { xx - er * 1.1, yy + er * 0.2 }, { xx - er * 0.3, yy + er * 0.5 }, { xx + er * 0.3, yy + er * 0.5 }, { xx + er * 1.1, yy + er * 0.2 } }, bold * 1, c, 0.95)
      pencil(rng, { { xx - er * 0.9, yy + er * 0.1 }, { xx, yy - er * 0.5 }, { xx + er * 0.9, yy + er * 0.1 } }, bold * 0.5, c, 0.8)
      ink.smooth(ell(xx, yy - er * 0.02, er * 0.26, er * 0.46, 7), true) ink.fill(g.cloudy == i and tone(0.55) or c)
    end
  end
  ink.smooth(ccw({ { tx - r * 0.08, -r * 0.24 }, { tx + r * 0.08, -r * 0.24 }, { tx, -r * 0.33 } }), true, 0.5) ink.fill(c)
  if eyes == "yawn" then
    pencil(rng, ell(tx, -r * 0.54, r * 0.2, r * 0.22, 9), bold * 0.9, c, 0.9)
  else
    pencil(rng, { { tx - r * 0.2, -r * 0.42 }, { tx - r * 0.06, -r * 0.48 }, { tx, -r * 0.37 }, { tx + r * 0.06, -r * 0.48 }, { tx + r * 0.2, -r * 0.42 } }, bold * 0.55, c, 0.85)
  end
  for _, sd in ipairs({ -1, 1 }) do
    for k = -1, 1 do
      local w0x, w0y = tx + sd * r * 0.3, -r * 0.34 + k * r * 0.07
      ink.moveto(w0x, w0y) ink.curveto(w0x + sd * r * 0.5, w0y, w0x + sd * r * 0.9 * g.whisk, w0y - r * 0.05, w0x + sd * r * 1.4 * g.whisk, w0y + k * r * 0.22 - r * 0.2)
    end
  end
  ink.stroke(c, 0.22, 0.65)
  ink.pop()
  if Tm.prop == "bowl" then prop_front(rng, "bowl", s) end
end

-- draw a cat in a style: "fur" (default), "wash", "gesture" (or "cutout": the first flat one)
function M.draw(rng, name, g, s, o)
  o = o or {}
  local style = o.style or M.style or "fur"
  if style == "cutout" then return M.cat(rng, name, g, s, o) end
  local Tm = T[name] or T.curl
  local flip = o.flip and -1 or 1
  ink.push()
  ink.scale(flip * s / 100, s / 100)
  if style == "wash" then draw_wash(rng, Tm, g, s, flip)
  elseif style == "gesture" then draw_gesture(rng, Tm, g, s, flip)
  else draw_fur(rng, Tm, g, s, flip) end
  ink.pop()
end

-- the extents of a template at scale s: half width, half height, and the middle (cm)
function M.extent(name, s)
  local b = T[name].box
  return (b[3] - b[1]) / 2 * s / 100, (b[4] - b[2]) / 2 * s / 100, (b[1] + b[3]) / 2 * s / 100, (b[2] + b[4]) / 2 * s / 100
end

-- ---------------------------------------------------------------- small things in the gaps
local function paw(c, r)
  ink.smooth(ccw({ { -r, -0.2 * r }, { -0.6 * r, 0.45 * r }, { 0, 0.55 * r }, { 0.6 * r, 0.45 * r }, { r, -0.2 * r }, { 0.5 * r, -0.65 * r }, { -0.5 * r, -0.65 * r } }), true)
  for _, t in ipairs({ { -1.05, 0.75 }, { -0.4, 1.2 }, { 0.4, 1.2 }, { 1.05, 0.75 } }) do
    ink.smooth(ccw(ell(t[1] * r, t[2] * r, r * 0.3, r * 0.38, 8)), true)
  end
  ink.fill(c, 0.75)
end
local function yarn(rng, r, c, dark)
  ink.moveto(0, -r) ink.curveto(r * 1.2, -r * 1.5, r * 1.4, -r * 0.6, r * 2.4, -r * 1.2) ink.stroke(c, 0.45)
  ink.circle(0, 0, r) ink.fill(c)
  ink.circle(0, 0, r) ink.clip()
    for k = -3, 3 do
      local y = k * r / 3.4
      ink.moveto(-r, y - r * 0.35) ink.curveto(-r * 0.3, y + r * 0.3, r * 0.3, y + r * 0.1, r, y + r * 0.45)
    end
    ink.stroke(dark, 0.28, 0.7)
    for k = -2, 2 do
      local x = k * r / 2.6
      ink.moveto(x - r * 0.4, -r) ink.curveto(x + r * 0.15, -r * 0.5, x - r * 0.1, r * 0.5, x + r * 0.45, r)
    end
    ink.stroke(white, 0.28, 0.7)
  ink.unclip()
end

-- Fill the field with cats, largest hole first, the way the garden and the mathematics fill theirs.
-- o: fld (grow.field), layout, rng, smax, smin, D, keepouts, inked, marks, place(event, x, y, fn), event()
function M.fill(o)
  local fld, layout, rng = o.fld, o.layout, o.rng
  local D = o.D or 1
  local keep = o.keepouts or {}
  local free_at = fld.free_at
  local counts = {}
  local n_cats, n_small = 0, 0
  local bag = {}
  local function next_pose()
    if #bag == 0 then
      for _, nm in ipairs(M.template_order) do bag[#bag + 1] = nm end
      for _, nm in ipairs({ "curl", "loaf", "stretch", "tum", "side" }) do bag[#bag + 1] = nm end   -- old cats mostly sleep
      for i = #bag, 2, -1 do local j = layout.int(1, i) bag[i], bag[j] = bag[j], bag[i] end
    end
    return table.remove(bag)
  end
  local function outside(a, b, c, d)
    for _, q in ipairs(keep) do
      if a < q[3] + 0.15 and c > q[1] - 0.15 and b < q[4] + 0.15 and d > q[2] - 0.15 then return true end
    end
    return false
  end
  -- will this pose fit the hole around (x, y) at size s? its box may lean on what is there, a little
  local function fits(name, x, y, s, slack)
    local hw, hh = M.extent(name, s)
    if outside(x - hw, y - hh, x + hw, y + hh) then return false end
    for _, u in ipairs({ -1, -0.5, 0, 0.5, 1 }) do
      for _, v in ipairs({ -1, 0, 1 }) do
        if free_at(x + u * hw, y + v * hh) < -slack then return false end
      end
    end
    for _, v in ipairs({ -0.5, 0.5 }) do
      if free_at(x - hw, y + v * hh) < -slack or free_at(x + hw, y + v * hh) < -slack then return false end
    end
    return true
  end
  local function put(name, x, y, s, flip, tilt)
    local g = M.genes(layout, { inked = true })
    local _, _, mx, my = M.extent(name, s)
    local fl = flip and -1 or 1
    o.place(o.event(), x, y, function()
      ink.rotate(tilt or 0) ink.translate(-fl * mx, -my)
      M.draw(rng.fork(), name, g, s, { flip = flip, style = o.style })
    end)
    local hw, hh = M.extent(name, s)
    -- what it takes up: a row of discs along its long side
    local long, short = max(hw, hh), min(hw, hh)
    local m = max(1, floor(long / short + 0.5))
    for k = 1, m do
      local t = m == 1 and 0 or (k - 0.5) / m * 2 - 1
      local dx, dy = hw >= hh and t * (long - short * 0.3) or 0, hh > hw and t * (long - short * 0.3) or 0
      fld.disc(x + dx, y + dy, short * 1.02, o.overlap or 0.95)
    end
    -- and the corners of its box, lightly: small cats may tuck in there, not on top of it
    for _, sx in ipairs({ -1, 1 }) do for _, sy in ipairs({ -1, 1 }) do
      fld.disc(x + sx * hw * 0.72, y + sy * hh * 0.72, short * 0.42, 0.9)
    end end
    counts[name] = (counts[name] or 0) + 1
    n_cats = n_cats + 1
  end
  -- a cat beside each heading
  for _, mk in ipairs(o.marks or {}) do
    local name = mk.kind == "heading" and "yawn" or "sit"
    local s = mk.arg == 1 and 1.5 or 1.2
    local hw, hh = M.extent(name, s)
    local x, y = o.markx - hw, mk.y + 0.1
    if free_at(x, y) > 0 and fits(name, x, y, s, 0.2) then put(name, x, y, s, false) end
  end
  -- the first, a large one, where the page begins: bottom corner
  if o.corner then
    local name = layout.chance(0.5) and "curl" or "bowl"
    local s = o.smax
    local hw, hh = M.extent(name, s)
    local x, y = o.corner[1] + hw + 0.05, o.corner[2] + hh + 0.05
    if not outside(x - hw, y - hh, x + hw, y + hh) then put(name, x, y, s, layout.chance(0.5)) end
  end
  local NMAX = floor((o.nmax or 400) * D + 0.5)
  local MINF = (o.minf or 0.42) / sqrt(max(D, 0.05))
  for _ = 1, NMAX do
    local best, bi = -1, nil
    local gx, gy, fr = fld.x, fld.y, fld.free
    for i = 1, #gx do
      local v = fr[i] * layout.range(0.85, 1.15)
      if v > best then best, bi = v, i end
    end
    if not bi or fr[bi] < MINF then break end
    local f, x, y = fr[bi], gx[bi], gy[bi]
    local placed = false
    -- try poses until one sits well in this hole: as large as the hole allows
    for _ = 1, 7 do
      local name = next_pose()
      local hw1, hh1 = M.extent(name, 1)
      local s = min(o.smax, f * layout.range(1.15, 1.45) / sqrt(hw1 * hh1))
      for _ = 1, 4 do
        if s < (o.smin or 0.9) then break end
        if fits(name, x, y, s, 0.1 * f) then
          local prop = T[name].prop
          put(name, x, y, s, layout.chance(0.5), prop and layout.sym(4) or layout.sym(13))
          placed = true
          break
        end
        s = s * 0.8
      end
      if placed then break end
      bag[#bag + 1] = name
      table.insert(bag, 1, table.remove(bag))
    end
    if not placed then
      -- too small for a cat: paw prints, a ball of yarn
      local r = min(f, 0.6)
      local kind = layout.chance(0.3) and "yarn" or "paw"
      local rot, gg = layout.range(0, 360), M.genes(layout, { inked = true })
      if not outside(x - r, y - r, x + r, y + r) then
        o.place(o.event(), x, y, function()
          if kind == "paw" then
            ink.rotate(rot)
            local c = ink.accent(0.1)
            paw(c, r * 0.42)
            ink.translate(r * 0.1, r * 1.2) ink.rotate(-14) ink.scale(0.92) paw(c, r * 0.42)
          else
            yarn(rng.fork(), r * 0.55, c_of(gg, gg.a or gg.base == "white" and "ginger" or gg.base), c_of(gg, gg.base == "white" and "ginger" or gg.base, -0.5))
          end
        end)
        n_small = n_small + 1
      end
      fld.disc(x, y, max(f * 0.9, 0.3), 1)
    end
  end
  return { cats = n_cats, small = n_small, counts = counts }
end

local BLOOM = { 0.35, 0.65, 0.88 }
local function placer(rng, layout, anim)
  local events = {}
  local function event()
    local e = { t0 = 0.3 + 0.16 * #events, dur = 0.45 }
    events[#events + 1] = e
    return e
  end
  local function place(e, x, y, fn)
    ink.layer(5)
    if anim then
      local r0, l0 = rng.save(), layout.save()
      for k = 1, #BLOOM do
        ink.tag({ e, (k - 1) / #BLOOM, k / #BLOOM })
        ink.push() ink.translate(x, y) ink.scale(BLOOM[k]) fn() ink.pop()
        rng.load(r0) layout.load(l0)
      end
      ink.tag({ e, 1 })
    end
    ink.push() ink.translate(x, y) fn() ink.pop()
    if anim then ink.tag({ e, 0 }) ink.tag(nil) end
  end
  return event, place, events
end

-- the page: the margin column, a band along the foot, the space under the text
function M.page(g, grow)
  local rng = ink.rng(g.seed * 7919 + 71)
  local layout = rng.fork()
  ink.set_transform(ink.page_transform(g.mirror and g.pw))
  local anim = g.anim
  if anim then ink.record(true) end
  local _, col, foot, spill = grow.regions(g, layout)
  foot = { foot[1], foot[2], g.textleft + (g.textright - g.textleft) * 0.72, foot[4] }
  local fld = grow.field({ col, foot, spill })
  fld.disc(g.colright - 0.5, g.headrule + 0.1, 0.7, 1)
  local event, place, events = placer(rng, layout, anim)
  local st = M.fill({ fld = fld, layout = layout, rng = rng, D = g.density or 1, event = event, place = place,
    style = M.style, smax = min(5.2, (col[3] - col[1]) * 0.85), corner = { col[1], col[2] }, marks = g.marks, markx = g.colright, nmax = 160, smin = 0.95 })
  if texio then texio.write_nl(string.format("florilegium: %d old cats", st.cats)) end
  if anim then
    local total = 0.5
    for _, e in ipairs(events) do total = max(total, e.t0 + e.dur) end
    return { rec = ink.take_recording(), total = total }
  end
  ink.flush()
  return {}
end

-- a whole page of cats (scene.lua): w, h in cm, boxes kept clear
function M.scene(rng, grow, w, h, o)
  o = o or {}
  local layout = rng.fork()
  local fld = grow.field({ { 0.15, 0.15, w - 0.15, h - 0.15 } })
  for _, q in ipairs(o.keepouts or {}) do
    local r = 0.5
    local x = q[1] + r
    while x <= q[3] do
      local y = q[2] + r
      while y <= q[4] do fld.disc(x, y, r * 1.5, 1) y = y + r end
      fld.disc(x, q[4], r, 1)
      x = x + r
    end
    fld.disc(q[3], q[2], r, 1) fld.disc(q[3], q[4], r, 1)
  end
  local event, place = placer(rng, layout, false)
  return M.fill({ fld = fld, layout = layout, rng = rng, D = o.density or 1, event = event, place = place, keepouts = o.keepouts, style = o.style,
    smax = o.smax or min(w, h) * 0.3, smin = o.smin or 1.15, corner = { 0.2, 0.2 }, nmax = o.nmax or 400, minf = o.minf or 0.55, inked = o.inked })
end

return M

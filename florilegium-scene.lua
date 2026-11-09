-- florilegium-scene.lua -- a cat gym on a whole page, without TeX: a slide, a title page, a carousel
-- panel, with text boxes it grows around. Used by apps/studio (in wasmoon) and
-- tools/cattree/scene.lua (the command line).
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
--   local svg = require("florilegium-scene").page{ w = 21, h = 26.25, seed = 3, cats = 3, size = 1,
--     keepouts = { { x0, y0, x1, y1 }, ... }, id = "p1-" }
-- w, h: the page in cm; keepouts: boxes the gym stays out of, in page cm, y up; size: how
-- large the pieces are (the gym is planned in a frame 1/size as large and scaled up, so
-- larger pieces also mean fewer of them); density 0..1; background "rrggbb", or none;
-- grows: "gym" (default), "oak" (one huge oak), "kelp" (a kelp forest), "flowers" (florilegium's species garden) or "cats" (old cats, filling it); ink: "green" or "blue" (oak: green by default); crown: "lush" (default) or "open" (oak: limbs show); season: "spring", "summer", "autumn", "winter" or "dead"; spanishmoss; swing, heart = false to leave out; stumps: how many cut limbs.
local M = {}
M.version = "2.0.0"

-- grows "flowers": florilegium's own species garden (florilegium-svg.lua's page), the keep-outs
-- standing in for the text block. The box round them is the text block, so the garden takes the
-- wider side of the page and, as on a document's last page, the space under the text; with no
-- keep-outs it takes nearly the whole page. Planned in a frame 1/k as large, then scaled by k.
-- o.seed is the work's seed (its plants), o.page the page's garden (0 based; o.index without it). The SVG's paths are
-- in the small frame; the streams are scaled by a `cm` of their own.
local function flowers(o, w, h, k)
  local fw, fh = w / k, h / k
  local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
  for _, q in ipairs(o.keepouts or {}) do
    x0, y0 = math.min(x0, q[1] / k), math.min(y0, q[2] / k)
    x1, y1 = math.max(x1, q[3] / k), math.max(y1, q[4] / k)
  end
  if x0 > x1 then x0, y0, x1, y1 = fw * 0.55, fh - 1.2, fw - 1, fh - 1 end
  local L, R = math.max(0.2, x0), math.max(0.2, fw - x1)
  if fw - L - R < 0.5 then L = math.max(0.2, fw - R - 0.5) R = fw - L - 0.5 end   -- a box at the paper's edge
  local T = math.min(fh - 1.5, math.max(0.2, fh - y1))
  local B = 0.5                                      -- the text block reaches the foot: no footer band, the
  local cm = function(v) return string.format("%.3fcm", v) end   -- spill runs under the text to the paper
  local SEASON = { spring = "spring", summer = "summer", autumn = "autumn", winter = "autumn", dead = "autumn" }
  local INK = { green = "2F6B4F", blue = "2456C4" }
  local svg = require("florilegium-svg")
  local _, _, extra = svg.page{ paper = { cm(fw), cm(fh) }, left = cm(L), right = cm(R), top = cm(T), bottom = cm(B),
    headheight = "0pt", headsep = "0pt", footskip = "0pt", head = false,
    seed = math.max(1, math.floor(o.seed or 1)), page = math.floor(o.page or o.index or 0) + 1,
    textend = cm(math.max(0, (fh - T) - math.max(B, y0))),
    density = o.density or 1, ink = INK[o.ink] or INK.blue, season = SEASON[o.season] or "summer" }
  local streams = {}
  for i, st in ipairs(extra.streams) do streams[i] = k == 1 and st or string.format("q %.4f 0 0 %.4f 0 0 cm\n%s\nQ", k, k, st) end
  return extra.streams, streams
end

function M.page(o)
  local w, h, k = o.w, o.h, o.size or 1
  if o.grows == "flowers" then
    local drawn, scaled = flowers(o, w, h, k)
    M.last_streams = scaled
    local svg = require("florilegium-svg")
    local CM = 72 / 2.54
    local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="%.2f" viewBox="0 0 %.2f %.2f">', w * CM, h * CM, w * CM, h * CM) }
    if o.background then out[#out + 1] = string.format('<rect width="100%%" height="100%%" fill="#%s"/>', o.background) end
    out[#out + 1] = string.format('<g transform="matrix(%.4f 0 0 %.4f 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', k, -k, h * CM)
    for i, st in ipairs(drawn) do svg.translate(st, out, (o.id or "s-") .. i) end
    out[#out + 1] = "</g></svg>"
    return table.concat(out, "\n")
  end
  local streams = {}
  local saved = { tex = tex, node = node, luatexbase = luatexbase }
  tex = { sprint = function() end }
  luatexbase = { registernumber = function() return 0 end }
  node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
  local ok, err = pcall(function()
    local ink, C = require("florilegium-ink"), require("florilegium-theme-cattree")
    local INK = { green = { 0x2F, 0x6B, 0x4F }, blue = { 0x24, 0x56, 0xC4 } }
    local c_ = INK[o.ink or (o.grows == "oak" and "green" or "blue")] or INK.blue
    ink.set_ink(c_[1] / 255, c_[2] / 255, c_[3] / 255)
    ink.set_transform(ink.page_transform())
    ink.scale(k)
    ink.layer(5)
    local fw, fh = w / k, h / k
    local keep = {}
    for i, q in ipairs(o.keepouts or {}) do keep[i] = { q[1] / k, q[2] / k, q[3] / k, q[4] / k } end
    if o.grows == "cats" then
      local grow_ = require("florilegium-grow")
      require("florilegium-theme-oldcats").scene(ink.rng((o.seed or 1) * 7919 + 71), grow_, fw, fh, { keepouts = keep, density = o.density, style = o.style, smax = o.smax })
      ink.flush()
      return
    end
    if o.grows == "kelp" then                         -- a kelp forest, the floor to the surface
      require("florilegium-theme-kelp").forest(ink.rng((o.seed or 1) * 7919 + 29), { w = fw, h = fh, keepouts = keep, otters = o.cats or 1 })
      ink.flush()
      return
    end
    if o.grows == "oak" then
      require("florilegium-theme-oak").tree(ink.rng((o.seed or 1) * 7919 + 13), { w = fw, h = fh, keepouts = keep, cats = o.cats, eyes = o.cats == 0 and 0 or nil, crown = o.crown, season = o.season, spanishmoss = o.spanishmoss, extras = o.extras, swing = o.swing, heart = o.heart, stumps = o.stumps, ink = o.ink })
      ink.flush()
      return
    end
    local cats = C.compose(C, ink, o.seed or 1, { 0.5, 0.6, fw - 0.5, fh - 0.6 },
      { nofoot = true, keepout = keep, cats = o.cats or 2, D = o.density or 1, ceil = fh + 0.2, edges = { 0, fw } })
    local crng = ink.rng((o.seed or 1) * 7919 + 103)
    for _, c in ipairs(cats) do
      ink.push() ink.translate(c[1], c[2])
      if c[3] == "peek" then C.peek(crng.fork()) else C.cat(crng.fork(), c[3], c[4], c[5]) end
      ink.pop()
    end
    ink.flush()
  end)
  tex, node, luatexbase = saved.tex, saved.node, saved.luatexbase
  if not ok then error(err, 0) end
  M.last_streams = streams                             -- the drawing as PDF operators (the studio's PDF)
  local svg = require("florilegium-svg")
  local CM = 72 / 2.54
  local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="%.2f" viewBox="0 0 %.2f %.2f">', w * CM, h * CM, w * CM, h * CM) }
  if o.background then out[#out + 1] = string.format('<rect width="100%%" height="100%%" fill="#%s"/>', o.background) end
  out[#out + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', h * CM)
  for i, st in ipairs(streams) do svg.translate(st, out, (o.id or "s-") .. i) end
  out[#out + 1] = "</g></svg>"
  return table.concat(out, "\n")
end

-- A decorated initial, a tile of side o.size cm (florilegium-initial.lua's), in the hand of what grows:
-- oak the letter made a tree in o.season, gym a cat on the letter, otherwise the vine. o.letter one
-- character, o.glyph its outline { units, boundingbox = { x0, y0, x1, y1 }, segments = { ... } } in
-- font units (luaotfload's form). Returns the SVG; M.last_streams holds it as PDF operators in cm.
function M.initial(o)
  local S = o.size or 2
  local streams = {}
  local saved = { tex = tex, node = node, luatexbase = luatexbase }
  tex = { sprint = function() end }
  luatexbase = { registernumber = function() return 0 end }
  node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
  local ok, err = pcall(function()
    local ink = require("florilegium-ink")
    local INK = { green = { 0x2F, 0x6B, 0x4F }, blue = { 0x24, 0x56, 0xC4 } }
    local c_ = INK[o.ink or "blue"] or INK.blue
    ink.set_ink(c_[1] / 255, c_[2] / 255, c_[3] / 255)
    ink.set_transform(ink.page_transform())
    ink.layer(5)
    local deco
    if o.grows == "oak" then
      local O = require("florilegium-theme-oak")
      local blue = o.ink == "blue"
      if not blue then O.season_ink(o.season) end
      deco = O.initial_for(o.season or "summer", { blue = blue })
    elseif o.grows == "gym" then
      deco = require("florilegium-theme-cattree").initial
    end
    local cp = utf8.codepoint(o.letter)
    local font = { units = o.glyph.units or 1000, byuni = { [cp] = o.glyph } }
    local drew, why = require("florilegium-initial").draw(ink.rng((o.seed or 1) * 7919 + 17), S, o.letter, { font = font, decorate = deco })
    if not drew then error(why, 0) end
    ink.flush()
  end)
  tex, node, luatexbase = saved.tex, saved.node, saved.luatexbase
  if not ok then error(err, 0) end
  M.last_streams = streams
  local svg = require("florilegium-svg")
  local CM = 72 / 2.54
  local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="%.2f" viewBox="0 0 %.2f %.2f">', S * CM, S * CM, S * CM, S * CM) }
  out[#out + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', S * CM)
  for i, st in ipairs(streams) do svg.translate(st, out, (o.id or "i-") .. i) end
  out[#out + 1] = "</g></svg>"
  return table.concat(out, "\n")
end

return M

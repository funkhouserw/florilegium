-- scene.lua -- a cat gym on a whole page, without TeX: a slide, a title page, a carousel
-- panel, with text boxes it grows around. Used by apps/studio (in wasmoon) and
-- tools/cattree/scene.lua (the command line).
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
--
--   local svg = require("scene").page{ w = 21, h = 26.25, seed = 3, cats = 3, size = 1,
--     keepouts = { { x0, y0, x1, y1 }, ... }, id = "p1-" }
-- w, h: the page in cm; keepouts: boxes the gym stays out of, in page cm, y up; size: how
-- large the pieces are (the gym is planned in a frame 1/size as large and scaled up, so
-- larger pieces also mean fewer of them); density 0..1; background "rrggbb", or none;
-- grows: "gym" (default), "oak" (one huge oak) or "cats" (old cats, filling it); ink: "green" or "blue" (oak: green by default); crown: "lush" (default) or "open" (oak: limbs show).
local M = {}

function M.page(o)
  local w, h, k = o.w, o.h, o.size or 1
  local streams = {}
  local saved = { tex = tex, node = node, luatexbase = luatexbase }
  tex = { sprint = function() end }
  luatexbase = { registernumber = function() return 0 end }
  node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
  local ok, err = pcall(function()
    local ink, C = require("ink"), require("theme-cattree")
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
      local grow_ = require("grow")
      require("theme-oldcats").scene(ink.rng((o.seed or 1) * 7919 + 71), grow_, fw, fh, { keepouts = keep, density = o.density, style = o.style, smax = o.smax })
      ink.flush()
      return
    end
    if o.grows == "oak" then
      require("theme-oak").tree(ink.rng((o.seed or 1) * 7919 + 13), { w = fw, h = fh, keepouts = keep, cats = o.cats, eyes = o.cats == 0 and 0 or nil, crown = o.crown })
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
  local svg = require("svg")
  local CM = 72 / 2.54
  local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2f" height="%.2f" viewBox="0 0 %.2f %.2f">', w * CM, h * CM, w * CM, h * CM) }
  if o.background then out[#out + 1] = string.format('<rect width="100%%" height="100%%" fill="#%s"/>', o.background) end
  out[#out + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', h * CM)
  for i, st in ipairs(streams) do svg.translate(st, out, (o.id or "s-") .. i) end
  out[#out + 1] = "</g></svg>"
  return table.concat(out, "\n")
end

return M

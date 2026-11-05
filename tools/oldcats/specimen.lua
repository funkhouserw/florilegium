-- the template cats on a sheet, without TeX.
--   lua5.4 tools/oldcats/specimen.lua  -> build/oldcats/templates.svg, faces.svg
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
local ink, svg, C = require("florilegium-ink"), require("florilegium-svg"), require("florilegium-theme-oldcats")
local CM, W, H = 72 / 2.54, 21, 29.7
local function write(name, labels)
  ink.flush()
  local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fmm" height="%.2fmm" viewBox="0 0 %.2f %.2f"><rect width="100%%" height="100%%" fill="#fefdfb"/>', W * 10, H * 10, W * CM, H * CM) }
  o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', H * CM)
  for i, s in ipairs(streams) do svg.translate(s, o, name .. i) end
  o[#o + 1] = "</g>"
  for _, l in ipairs(labels) do o[#o + 1] = string.format('<text x="%.1f" y="%.1f" font-size="7" font-family="Helvetica" fill="#888" text-anchor="middle">%s</text>', l[1] * CM, (H - l[2]) * CM, l[3]) end
  o[#o + 1] = "</svg>"
  local f = assert(io.open(root .. "/build/oldcats/" .. name .. ".svg", "w")) f:write(table.concat(o, "\n")) f:close()
  print(name, #streams[1] // 1024 .. " KB")
  streams = {}
end
-- every pose, large, in three different cats
ink.set_transform(ink.page_transform())
local rng = ink.rng(77)
local labels = {}
local order = C.template_order
local cols, rows = 3, 4
local COATS = { "tabby", "calico", "tuxedo", "solid", "tortie", "van", "point", "blotched", "smoke", "tabby", "tuxedo", "calico" }
for i, name in ipairs(order) do
  local c, r = (i - 1) % cols, (i - 1) // cols
  local cx, cy = 3.6 + c * 7, 24.2 - r * 7.1
  local s = 3.7
  local hw, hh, mx, my = C.extent(name, s)
  ink.push() ink.translate(cx - mx, cy - my)
  C.cat(rng.fork(), name, C.genes(rng, { coat = COATS[i] }), s)
  ink.pop()
  labels[#labels + 1] = { cx, cy - 3.3, name .. " · " .. COATS[i] }
end
write("templates", labels)
-- one pose, many genes: how far the randomness goes
ink.set_transform(ink.page_transform())
labels = {}
local poses = { "curl", "loaf", "stretch", "sit" }
for r = 0, 6 do for c = 0, 3 do
  local name = poses[(r + c) % 4 + 1]
  local s = 2.6
  local _, _, mx, my = C.extent(name, s)
  local cx, cy = 2.8 + c * 5.15, 26.4 - r * 4.05
  ink.push() ink.translate(cx - mx, cy - my)
  C.cat(rng.fork(), name, C.genes(rng), s, { flip = rng.chance(0.5) })
  ink.pop()
end end
write("variety", labels)

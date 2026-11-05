-- frames of the cat gym building itself, as SVG (then tools/cattree/animate.sh -> GIF)
--   lua5.4 tools/cattree/animate.lua SEED NFRAMES [spill]
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local out
tex = { sprint = function() end }
luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) out = n.data end }
local ink, grow, svg = require("florilegium-ink"), require("florilegium-grow"), require("florilegium-svg")
local seed, N, spill = tonumber(arg[1] or 4), tonumber(arg[2] or 60), tonumber(arg[3] or 1)
local g = { pw = 21, ph = 29.7, textleft = 6.8, textright = 18.8, ytop = 25.4, ybot = 3.0 }
g.colright, g.headrule, g.footy = g.textleft - 0.4, g.ytop + 0.7, 1.9
g.seed, g.spill, g.spilly, g.theme, g.marks, g.anim = seed, spill, spill == 1 and 15.0 or 0, "cattree", {}, true
grow.theme("cattree")
local r = grow.page(g)
local CM = 72 / 2.54
os.execute("mkdir -p '" .. root .. "/build/cattree/frames'")
for k = 1, N do
  local t = k >= N and math.huge or r.total * (k - 1) / (N - 1)
  ink.emit(r.rec, function(tag)
    if tag.overlay then return false end
    local e = tag[1]
    local p = (t - e.t0) / e.dur
    return p >= tag[2] and (tag[3] == nil or p < tag[3])
  end)
  local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="420" height="594" viewBox="0 0 %.2f %.2f">', g.pw * CM, g.ph * CM),
    string.format('<rect width="%.2f" height="%.2f" fill="#fefdfb"/>', g.pw * CM, g.ph * CM) }
  -- stand-in text lines, ending where the text ends
  for y = g.ytop - 0.3, (spill == 1 and g.spilly or g.ybot) + 0.3, -0.55 do
    o[#o + 1] = string.format('<rect x="%.1f" y="%.1f" width="%.1f" height="5" fill="#dcdcdc"/>', g.textleft * CM, (g.ph - y) * CM, (g.textright - g.textleft) * CM)
  end
  o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', g.ph * CM)
  svg.translate(out or "", o, "f" .. k .. "-")
  o[#o + 1] = "</g></svg>"
  local f = assert(io.open(string.format("%s/build/cattree/frames/f%03d.svg", root, k), "w"))
  f:write(table.concat(o, "\n")) f:close()
end
print(string.format("%d frames, %.1f s of growth", N, r.total))

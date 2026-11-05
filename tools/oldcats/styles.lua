-- the same cats in the three styles, in blue.  lua5.4 tools/oldcats/styles.lua -> build/oldcats/styles.svg
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
local ink, svg, C = require("florilegium-ink"), require("florilegium-svg"), require("florilegium-theme-oldcats")
local CM, W, H = 72 / 2.54, 21, 29.7
ink.set_transform(ink.page_transform())
local poses = { "curl", "stretch", "loaf", "up", "sit" }
local coats = { "solid", "tabby", "tuxedo", "calico", "smoke" }
local base = ink.rng(5)
local genes = {}
for i = 1, #poses do genes[i] = C.genes(base, { coat = coats[i], inked = true, fat = i % 2 == 1 and 1.3 or 0.9 }) end
genes[1].base = "black"
local styles = { "gesture", "wash", "fur" }
local sizes = {}
for c, st in ipairs(styles) do
  for r, name in ipairs(poses) do
    local s = 5
    local hw, hh, mx, my = C.extent(name, s)
    local k = math.min(3.1 / hw, 2.5 / hh, 1)
    local cx, cy = 3.6 + (c - 1) * 6.9, 26 - (r - 1) * 5.6
    ink.push() ink.translate(cx - mx * k, cy - my * k)
    C.draw(ink.rng(100 + r), name, genes[r], s * k, { style = st })
    ink.pop()
  end
end
ink.flush()
local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fmm" height="%.2fmm" viewBox="0 0 %.2f %.2f"><rect width="100%%" height="100%%" fill="#fefdfb"/>', W * 10, H * 10, W * CM, H * CM) }
o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', H * CM)
for i, s in ipairs(streams) do svg.translate(s, o, "st" .. i) end
o[#o + 1] = "</g></svg>"
local f = assert(io.open(root .. "/build/oldcats/styles.svg", "w")) f:write(table.concat(o, "\n")) f:close()
print("styles", #streams[1] // 1024 .. " KB")

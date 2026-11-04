-- one huge oak, without TeX.
--   lua5.4 tools/trees/oak.lua NAME W H SEED [green|blue]   -> build/trees/NAME.svg (W, H in cm)
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
local ink, svg, O = require("ink"), require("svg"), require("theme-oak")
local name, W, H, seed, col = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4]), arg[5] or "green"
local INK = { green = { 0x2F, 0x6B, 0x4F }, blue = { 0x24, 0x56, 0xC4 } }
ink.set_ink(INK[col][1] / 255, INK[col][2] / 255, INK[col][3] / 255)
ink.set_transform(ink.page_transform())
ink.record(true)
local t0 = os.clock()
local stats = O.tree(ink.rng(seed * 7919 + 13), { w = W, h = H, crown = os.getenv("CROWN"), season = os.getenv("SEASON"), spanishmoss = os.getenv("SPANISH") ~= nil, ink = col, bare = os.getenv("BARE") ~= nil, cats = os.getenv("BARE") and 0 or nil, eyes = os.getenv("BARE") and 0 or nil, nests = os.getenv("BARE") and 0 or nil, sprigs = os.getenv("BARE") and 0 or nil })
for _, n in ipairs(O.last_stumps or {}) do io.stderr:write(string.format("stump at %.1f %.1f w %.2f\n", n.x, n.y, n.stump_w)) end
io.stderr:write("snowman=" .. tostring(stats.snowman) .. " birds=" .. tostring(stats.birds) .. " swing=" .. tostring(stats.swing) .. " heart=" .. tostring(stats.heart) .. "\n")
local rec = ink.take_recording()
local sizes = {}
for _, k in ipairs(rec.keys) do sizes[#sizes + 1] = k .. ":" .. (#table.concat(rec.layers[k], "\n") // 1024) .. "K" end
ink.emit(rec, function() return true end)
io.stderr:write("layers " .. table.concat(sizes, " ") .. "\n")
local CM = 72 / 2.54
local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fcm" height="%.2fcm" viewBox="0 0 %.2f %.2f"><rect width="100%%" height="100%%" fill="#fefdfb"/>', W, H, W * CM, H * CM) }
o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', H * CM)
for i, s in ipairs(streams) do svg.translate(s, o, name .. i) end
o[#o + 1] = "</g></svg>"
local f = assert(io.open(root .. "/build/trees/" .. name .. ".svg", "w")) f:write(table.concat(o, "\n")) f:close()
print(string.format("%s: %d nodes, %d chains, clumps %d/%d/%d, %d KB, %.1f s", name, stats.nodes, stats.chains, stats.clumps.back, stats.clumps.mid, stats.clumps.front, #streams[1] // 1024, os.clock() - t0))

-- the oak's primitives on a sheet, without TeX, in the given ink.
--   lua5.4 tools/trees/specimen.lua        -> build/trees/oak-blue.svg, oak-green.svg
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
local ink, svg, O, C = require("ink"), require("svg"), require("theme-oak"), require("theme-cattree")
local CM, W, H = 72 / 2.54, 21, 29.7

local function sheet(name, hexr, hexg, hexb)
  streams = {}
  ink.set_ink(hexr / 255, hexg / 255, hexb / 255)
  ink.set_transform(ink.page_transform())
  local rng = ink.rng(4242)
  local function at(x, y, fn) ink.push() ink.translate(x, y) fn(rng.fork()) ink.pop() end
  ink.layer(3)
  -- 1. a section of trunk, with knots, a burl and moss
  at(0.6, 17.6, function(r)
    O.limb(r, { { 2.8, 0 }, { 2.95, 3.2 }, { 2.7, 6.2 }, { 2.9, 10.4 } }, function(v) return 5.2 - v * 0.8 end,
      { knots = { { -0.42, 0.72, 0.95 }, { 0.38, 0.32, 0.7 } }, moss = 0.7 })
    ink.push() ink.translate(1.85, 2.9) O.burl(r, 1.05) ink.pop()
    ink.push() ink.translate(4.5, 7.2) O.burl(r, 0.55, { plates = 6 }) ink.pop()
  end)
  -- 2. a limb forking, with collars, a nest in the crotch
  at(6.6, 17.6, function(r)
    O.limb(r, { { 2.6, 6.8 }, { 3.8, 6.5 }, { 6.2, 7.0 }, { 8.2, 8.8 } }, function(v) return 1.25 - 0.75 * v end, { moss = 0.4, collar = 0.14 })
    O.limb(r, { { 3, 8 }, { 3.2, 6.5 }, { 2, 4.5 }, { 0, 3.2 } }, function(v) return 1.25 - 0.6 * v end, { moss = 0.4 })
    O.limb(r, { { 0.5, 0 }, { 1.6, 3 }, { 2.6, 5.8 }, { 3.2, 10.2 } }, function(v) return 2.9 - 1.3 * v end, { moss = 0.6, knots = { { 0.1, 0.42, 0.8 } } })
    ink.push() ink.translate(5.2, 7.4) O.nest(r, 1.9) ink.pop()
    ink.push() ink.translate(7.2, 8.45) ink.rotate(38) O.nest(r, 1.25, { chick = true }) ink.pop()
  end)
  -- 3. leaves and acorns
  for k = 0, 5 do at(1.4 + k * 1.05, 15, function(r) ink.rotate(-30 + k * 12) O.leaf(r, 1.5 - k * 0.14) end) end
  for k = 0, 1 do at(8.3 + k * 1.3, 16.9, function(r) O.sprig(r, 1, { acorns = 2 + k }) end) end
  -- 4. a clump at each depth
  at(13.6, 15.2, function(r) O.clump(r, 1.1, "back") end)
  at(16, 15.2, function(r) O.clump(r, 1.1, "mid") end)
  at(18.6, 15.2, function(r) O.clump(r, 1.1, "front") end)
  -- 5. the test: a limb in the crown, cats in it, leaves over them
  local X, Y = 0.8, 0.8
  ink.layer(1)
  for _, q in ipairs({ { 3, 11, 2.4 }, { 8, 11.2, 2.8 }, { 13.5, 10.8, 2.6 }, { 17.3, 9.8, 2 }, { 1.4, 7.2, 1.9 }, { 16.4, 6, 2 } }) do
    at(X + q[1], Y + q[2], function(r) O.clump(r, q[3], "back") end)
  end
  ink.layer(2)
  at(X, Y, function(r)
    O.limb(r, { { -1, 3.6 }, { 4, 4.7 }, { 10, 4.3 }, { 16, 6.2 }, { 20, 8.3 } }, function(v) return 2.4 - 1.5 * v end, { moss = 0.55, knots = { { -0.1, 0.34, 0.8 } } })
    O.limb(r, { { 8.2, 5 }, { 9, 7.4 }, { 7.6, 9.6 }, { 8, 12 } }, function(v) return 1.15 - 0.7 * v end, { moss = 0.4, collar = 0.1 })
  end)
  ink.layer(3)
  for _, q in ipairs({ { 2.2, 9.6, 2 }, { 11.8, 9.6, 2.2 }, { 6.5, 10.8, 1.9 }, { 16.6, 11, 1.8 } }) do
    at(X + q[1], Y + q[2], function(r) O.clump(r, q[3], "mid") end)
  end
  -- the cats, drawn large enough to read here (1.8x): one lying along the limb with its tail hanging,
  -- one sitting half hidden, one only eyes and ears in the shade
  ink.layer(4)
  if not os.getenv("NOCATS") then
  at(X + 4.6, Y + 5.55, function(r) ink.scale(1.8) C.cat(r, "drape", 1, 1, { coat = "tabby" }) end)
  at(X + 12.6, Y + 5.3, function(r) ink.scale(1.8) ink.rotate(14) C.cat(r, "sit", -1, nil, { coat = "tux" }) end)
  at(X + 6.6, Y + 9.9, function(r) ink.scale(1.5) C.peek(r, { coat = "solid" }) end)
  end
  ink.layer(5)
  for _, q in ipairs({ { 3.2, 11.5, 2.1 }, { 9.6, 12.3, 2 }, { 15.2, 12.2, 2.2 }, { 17.6, 8.8, 1.7 }, { 5.4, 8.75, 1.1 }, { 14.2, 8.7, 1.35 }, { 10.4, 8.6, 1.2 }, { 0.8, 8.2, 1.3 } }) do
    at(X + q[1], Y + q[2], function(r) O.clump(r, q[3], "front") end)
  end
  ink.flush()
  local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fmm" height="%.2fmm" viewBox="0 0 %.2f %.2f"><rect width="100%%" height="100%%" fill="#fefdfb"/>', W * 10, H * 10, W * CM, H * CM) }
  o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', H * CM)
  for i, s in ipairs(streams) do svg.translate(s, o, name .. i) end
  o[#o + 1] = "</g></svg>"
  local f = assert(io.open(root .. "/build/trees/" .. name .. ".svg", "w")) f:write(table.concat(o, "\n")) f:close()
  print(name, math.floor(#streams[1] / 1024) .. " KB")
end
sheet("oak-blue", 0x24, 0x56, 0xC4)
sheet("oak-green", 0x2F, 0x6B, 0x4F)

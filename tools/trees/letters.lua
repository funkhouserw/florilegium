-- seasonal letters, without TeX: lua5.4 tools/trees/letters.lua -> build/trees/letters-*.svg
-- Needs scratch/glyphs.lua (outlines from a system font, see tools/cattree/glyphs.py); LaTeX uses Latin Modern.
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
local gfile = root .. "/scratch/glyphs.lua"
kpse = { find_file = function(n) return n end }
fonts = { handlers = { otf = { readers = { loadshapes = function() return dofile(gfile) end } } } }
local ink, svg, O, initial = require("florilegium-ink"), require("florilegium-svg"), require("florilegium-theme-oak"), require("florilegium-initial")
local OUT = arg[1] or (root .. "/build/trees/")
local CM = 72 / 2.54
local function write(name, w, h, fn)
  streams = {}
  ink.set_transform(ink.page_transform())
  fn()
  ink.flush()
  local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" width="%.2fcm" height="%.2fcm" viewBox="0 0 %.2f %.2f"><rect width="100%%" height="100%%" fill="#fefdfb"/>', w, h, w * CM, h * CM) }
  o[#o + 1] = string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', h * CM)
  for i, s in ipairs(streams) do svg.translate(s, o, name .. i) end
  o[#o + 1] = "</g></svg>"
  local f = assert(io.open(OUT .. name .. ".svg", "w")) f:write(table.concat(o, "\n")) f:close()
end
local function tile(x, y, S, L, season, seed, opt)
  opt = opt or {}
  O.season_ink(season, opt.blue)
  ink.push() ink.translate(x, y)
  local ok, err = initial.draw(ink.rng(seed), S, L, { font = "georgia", decorate = O.initial_for(season, opt) })
  ink.pop()
  if not ok then io.stderr:write(tostring(err) .. "\n") end
end
-- the sheet: a row per season
local SEASONS = { "spring", "summer", "autumn", "winter", "dead" }
write("letters-sheet", 21.59, 27.94, function()
  for r, sn in ipairs(SEASONS) do
    for c, L in ipairs({ "A", "T", "O", "S" }) do
      tile(1.2 + (c - 1) * 4.9, 27.94 - r * 5.25 - 0.3, 4.4, L, sn, r * 100 + c)
    end
  end
end)
-- one big letter per season, and one with moss, for setting beside text
for i, sn in ipairs(SEASONS) do
  write("letter-" .. sn, 6, 6, function() tile(0, 0, 6, ({ "S", "O", "A", "W", "D" })[i], sn, 700 + i) end)
  write("drop-" .. sn, 4, 4, function() tile(0, 0, 4, ({ "S", "S", "A", "W", "D" })[i], sn, 800 + i) end)
end
write("letter-moss", 6, 6, function() tile(0, 0, 6, "H", "dead", 711, { moss = true }) end)
write("letter-blue", 6, 6, function() tile(0, 0, 6, "T", "winter", 712, { blue = true }) end)
print("letters written")

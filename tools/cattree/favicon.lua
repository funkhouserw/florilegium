-- tools/cattree/favicon.lua -- Felilegium's favicon: the cat gym's decorated initial F (seed 3), in Latin Modern Roman Bold.
--   lualatex --output-directory=build/favicon tools/cattree/favicon-glyph.tex   (the F's outline -> build/favicon/glyphF.lua)
--   texlua tools/cattree/favicon.lua                                     (-> build/favicon/favicon.svg)
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
package.path = "./?.lua;" .. package.path
local streams = {}
tex = { sprint = function() end }
luatexbase = { registernumber = function() return 0 end }
node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
kpse = { find_file = function(n) return n end }
fonts = { handlers = { otf = { readers = { loadshapes = function() return dofile("build/favicon/glyphF.lua") end } } } }
local ink, C, svg = require("florilegium-ink"), require("florilegium-theme-cattree"), require("florilegium-svg")
local initial = require("florilegium-initial")
local seed, S = tonumber(arg[1]) or 3, 4
ink.set_ink(0x24 / 255, 0x56 / 255, 0xC4 / 255)
ink.set_transform(ink.page_transform())
ink.layer(5)
ink.push() ink.translate(0.5, 0.5)
local ok, err = initial.draw(ink.rng(seed), S, "F", { font = "lmroman", decorate = C.initial })
ink.pop()
if not ok then io.stderr:write(tostring(err) .. "\n") end
ink.flush()
local CM = 72 / 2.54
local V, P = (S + 1) * CM, 0.5 * CM - 1
local out = { string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="%.2f %.2f %.2f %.2f">', P, P, V - 2 * P, V - 2 * P),
  string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', V) }
for i, st in ipairs(streams) do svg.translate(st, out, "f" .. i) end
out[#out + 1] = "</g></svg>"
io.open("build/favicon/favicon.svg", "w"):write(table.concat(out, "\n"))

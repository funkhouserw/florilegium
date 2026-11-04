-- the drawings for the two showcase PDFs, as SVG.  lua5.4 tools/showcase/gen.lua
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local OUT = root .. "/build/showcase/svg/"
local function write(name, s) local f = assert(io.open(OUT .. name .. ".svg", "w")) f:write(s) f:close() end
local svg = require("svg")
local scene = require("scene")
local W, H = 21.59, 27.94
local function margin(name, o)
  o.paper, o.theme, o.id = "letter", "cattree", name
  write(name, (svg.page(o)))
end
-- margin pages: text from 32 mm down, 30 mm at the foot
margin("full-left", { seed = 4, left = "68mm", right = "22mm" })
margin("full-right", { seed = 12, left = "22mm", right = "68mm" })
margin("short-a", { seed = 6, left = "68mm", right = "22mm", textend = "100mm" })
margin("short-b", { seed = 9, left = "68mm", right = "22mm", textend = "60mm" })
margin("wide", { seed = 3, left = "90mm", right = "20mm" })
for i, sd in ipairs({ 1, 2, 3, 5, 7, 8, 10, 11, 13 }) do
  margin("grid" .. i, { seed = sd, left = "68mm", right = "22mm", textend = i % 3 == 0 and "90mm" or nil })
end
-- whole pages
local function page(name, o)
  o.w, o.h, o.id = o.w or W, o.h or H, name
  o.grows = o.grows or "gym"
  write(name, scene.page(o))
end
-- text boxes, in cm from the top left: the same numbers go into build.py
local function box(x, top, w, h) return { x, H - top - h, x + w, H - top } end
page("cover", { seed = 3, cats = 3, size = 1, keepouts = { box(4, 9.6, 13.6, 5.6) } })
page("gym-full", { seed = 11, cats = 3, size = 1 })
page("gym-full2", { seed = 21, cats = 4, size = 1 })
page("box-mid", { seed = 5, cats = 2, size = 1.2, keepouts = { box(3.2, 8, 15.2, 8.6) } })
page("box-top", { seed = 7, cats = 2, size = 1.3, keepouts = { box(2.4, 1.8, 16.8, 9.6) } })
page("box-two", { seed = 8, cats = 3, size = 1.2, keepouts = { box(1.6, 2, 9.4, 8.6), box(10.2, 17.4, 9.8, 8.6) } })
page("pano", { seed = 5, cats = 6, size = 1, w = 63, h = 26.25 })
page("pano2", { seed = 17, cats = 6, size = 1.25, w = 63, h = 26.25 })
for i = 1, 4 do page("slide" .. i, { seed = 30 + i, cats = 2, size = 1.5, w = 21, h = 26.25, keepouts = { { 3, 15, 18, 23 } } }) end
-- the oak, no cats
local function oak(name, o) o.grows, o.cats, o.ink = "oak", 0, o.ink or "green" page(name, o) end
oak("oak1", { seed = 4 })
oak("oak2", { seed = 2 })
oak("oak3", { seed = 7 })
oak("oak4", { seed = 3, ink = "blue" })
oak("oak5", { seed = 9, ink = "blue" })
oak("oak4o", { seed = 4, crown = "open" })
oak("oak2o", { seed = 2, crown = "open" })
oak("oak7o", { seed = 7, crown = "open" })
for _, sn in ipairs({ "spring", "summer", "autumn", "winter", "dead" }) do
  oak("sn-" .. sn, { seed = 2, season = sn })
end
oak("sn-moss", { seed = 2, spanishmoss = true })
oak("sn-moss-open", { seed = 4, spanishmoss = true, crown = "open" })
oak("sn-moss-winter", { seed = 7, spanishmoss = true, season = "winter" })
oak("sn-moss-dead", { seed = 4, spanishmoss = true, season = "dead" })
oak("sn-autumn-open", { seed = 7, season = "autumn", crown = "open" })
oak("sn-autumn-blue", { seed = 4, season = "autumn", ink = "blue" })
oak("sn-winter-blue", { seed = 3, season = "winter", ink = "blue" })
oak("sn-dead-blue", { seed = 9, season = "dead", ink = "blue" })
-- with text: the same numbers as text_pdf in build.py
local TX = {
  { "tx-left", 4, "summer", nil, { box(8.2, 2.5, 11.4, 22.9) } },
  { "tx-right", 2, "autumn", nil, { box(2, 2.5, 11.4, 22.9) } },
  { "tx-short", 7, "spring", nil, { box(8.2, 2.5, 11.4, 9) } },
  { "tx-title", 2, "winter", nil, { box(3, 1.8, 15.6, 6) } },
  { "tx-center", 5, "summer", "blue", { box(4.5, 8.5, 12.6, 9) } },
  { "tx-cols", 7, "autumn", nil, { box(1.8, 2.5, 8.4, 11), box(11.4, 2.5, 8.4, 11) } },
  { "tx-foot", 3, "summer", nil, { box(2.5, 18.5, 16.6, 7.4) } },
  { "tx-scatter", 9, "dead", nil, { box(1.5, 2, 7.5, 7), box(13, 11, 7, 6.5), box(1.5, 20, 6.5, 6) } },
  { "tx-narrow", 8, "winter", nil, { box(6, 2.5, 9.6, 22.9) } },
  { "tx-bands", 6, "spring", nil, { box(1.8, 1.5, 18, 3), box(1.8, 21.5, 18, 5) } },
  { "tx-moss", 2, "summer", nil, { box(2, 2.5, 8.6, 13) }, true },
  { "tx-mossdead", 4, "dead", nil, { box(11, 15, 8.8, 10.4) }, true },
}
for _, t in ipairs(TX) do
  oak(t[1], { seed = t[2], season = t[3], ink = t[4], keepouts = t[5], spanishmoss = t[6] })
end
-- beside the seasonal letters
oak("lt-spring", { seed = 7, season = "spring", keepouts = { box(8.2, 2.5, 11.4, 11) } })
oak("lt-summer", { seed = 4, season = "summer", keepouts = { box(8.2, 2.5, 11.4, 22.9) } })
oak("lt-autumn", { seed = 2, season = "autumn", keepouts = { box(2, 2.5, 11.4, 22.9) } })
oak("lt-winter", { seed = 2, season = "winter", keepouts = { box(3, 2, 15.6, 8.5) } })
oak("lt-dead", { seed = 4, season = "dead", spanishmoss = true, keepouts = { box(11, 12, 8.8, 13.4) } })
oak("oak-cover", { seed = 1, keepouts = { box(3.6, 2.2, 14.4, 5.6) } })
oak("oak-box", { seed = 5, keepouts = { box(3, 2.2, 15.6, 8.8) } })
oak("oak-two", { seed = 6, keepouts = { box(1.6, 2, 8.4, 7), box(13.2, 15, 7, 8) } })
-- a drop cap: the letter tile with a cat on it (outlines from scratch/glyphs.lua)
do
  local streams = {}
  local saved = { tex, node, luatexbase }
  tex = { sprint = function() end } luatexbase = { registernumber = function() return 0 end }
  node = { new = function() return {} end, write = function(n) streams[#streams + 1] = n.data end }
  local gfile = root .. "/scratch/glyphs.lua"
  kpse = { find_file = function(n) return n end }
  fonts = { handlers = { otf = { readers = { loadshapes = function() return dofile(gfile) end } } } }
  local ink, initial, C = require("ink"), require("initial"), require("theme-cattree")
  ink.set_ink(0x24 / 255, 0x56 / 255, 0xC4 / 255)
  local CM = 72 / 2.54
  for code = 65, 90 do
    local L = string.char(code)
    streams = {}
    ink.set_transform(ink.page_transform())
    initial.draw(ink.rng(ord or L:byte() * 11), 2, L, { font = "georgia", decorate = C.initial })
    ink.flush()
    local o = { string.format('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %.2f %.2f">', 2 * CM, 2 * CM),
      string.format('<g transform="matrix(1 0 0 -1 0 %.2f)" stroke-linecap="round" stroke-linejoin="round">', 2 * CM) }
    for i, s_ in ipairs(streams) do svg.translate(s_, o, "tile" .. L .. i) end
    o[#o + 1] = "</g></svg>"
    write("tile-" .. L, table.concat(o, "\n"))
  end
  tex, node, luatexbase = saved[1], saved[2], saved[3]
end
print("ok")

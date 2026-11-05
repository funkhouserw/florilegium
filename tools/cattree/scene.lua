-- a cat gym on a whole page, from the command line: a title slide, a full fill, a panorama.
--   lua5.4 tools/cattree/scene.lua NAME W H SEED [WORD] [CATS] [SIZE]  -> build/cattree/NAME.svg (W, H in cm)
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local name, W, H, seed, word, ncats, size = arg[1], tonumber(arg[2]), tonumber(arg[3]), tonumber(arg[4]), arg[5], tonumber(arg[6]) or 3, tonumber(arg[7]) or 1
if word == "" then word = nil end
local CM = 72 / 2.54
local keep, fs = {}, 0
if word then
  fs = math.min(1.15, (W * 0.62) / (#word * 0.55))               -- cap height, cm: fits 62% of the width
  local tw = #word * fs * 0.55
  keep[1] = { W / 2 - tw / 2 - 0.8, H * 0.52 - fs * 0.6 - 0.8, W / 2 + tw / 2 + 0.8, H * 0.52 + fs * 0.8 + 0.8 }
end
local s = require("florilegium-scene").page({ w = W, h = H, seed = seed, cats = ncats, size = size, keepouts = keep, background = "fefdfb", id = name })
if word then
  s = s:gsub("</svg>$", string.format('<text x="%.1f" y="%.1f" text-anchor="middle" font-family="Georgia, serif" font-weight="bold" font-size="%.1f" fill="#1b2a6b">%s</text></svg>',
    W / 2 * CM, (H - H * 0.52) * CM + fs * 0.35 * CM, fs * 1.45 * CM, word))
end
local f = assert(io.open(root .. "/build/cattree/" .. name .. ".svg", "w")) f:write(s) f:close()

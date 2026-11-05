-- a page of old cats.  lua5.4 tools/oldcats/page.lua NAME W H SEED [SIZE] -> build/oldcats/NAME.svg
local root = arg[0]:match("^(.*)/tools/") or "."
package.path = root .. "/?.lua;" .. package.path
local t0 = os.clock()
local s = require("florilegium-scene").page({ w = tonumber(arg[2]), h = tonumber(arg[3]), seed = tonumber(arg[4]), grows = "cats", style = arg[5], background = "fefdfb", id = arg[1] })
local f = assert(io.open(root .. "/build/oldcats/" .. arg[1] .. ".svg", "w")) f:write(s) f:close()
print(arg[1], #s // 1024 .. " KB svg", string.format("%.1f s", os.clock() - t0))

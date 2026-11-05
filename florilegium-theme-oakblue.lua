-- florilegium-theme-oakblue.lua -- theme=oakblue: the oak of florilegium-theme-oak.lua, painted in the
-- document's ink even when that is the default Delft blue, which theme=oak replaces with its greens.
-- Copyright (c) 2026 Ilse Funkhouser. MIT License: see LICENSE or florilegium.sty.
local O = require("florilegium-theme-oak")
local M = {}
M.version = "2.0.0"
function M.page(g, grow) return O.page(g, grow, true) end
function M.before_initial(age) return O.before_initial(age, true) end
M.initial = O.initial
return M

-- compose.lua -- a first, faked procedural composition for florilegium-theme-cattree.lua.
-- Not florilegium-grow.lua's free-space loop yet: a grammar in three zones, its choices made
-- by a seed, with a list of boxes so that nothing passes through anything else.
--
--   1. the floor tower: 2-3 posts on a base, of different heights in whole levels
--      (about 50 cm); neighbors share a platform at the lower one's top (the taller
--      post runs on up through it); crossbeams below; a hammock under a high
--      platform; on the platforms a condo or a bowl; on the post tops a ring, a
--      sisal tube, a pad or a cushion; toys hanging under platform ends.
--   2. the wall, above the tower on the side away from its tallest post: a board
--      route (run, riser, run), a shallow rope bridge (never steeper than 15
--      degrees) or floating steps across to a half-moon shelf, hexes on a short
--      post or on the wall, a space bubble.
--   3. the top, sparse: small half-moons zigzagging up, joined by floating steps,
--      pegs or dots, ending in a tapering line of dots.
-- The footer (on the floor, right of the column): a base with a lounger and a short post.
--
-- compose(C, seed, col) draws the gym (ink must be set up) and returns the cats:
-- { { x, y, pose, facing, angle } } for the reference cats. col = { x0, y0, x1, y1 } page cm.

local M = {}
local max, min, abs, floor, sqrt = math.max, math.min, math.abs, math.floor, math.sqrt

function M.compose(C, ink, seed, col)
  local real = C.real
  local rng = ink.rng(seed * 7919 + 17)
  local x0, y0, x1, y1 = col[1], col[2], col[3], col[4]
  local mid = (x0 + x1) / 2
  local pr = real(C.DIM.post_d) / 2
  local st = real(C.DIM.shelf_t)
  local boxes, cats = {}, {}
  local layers = { {}, {}, {}, {}, {} }               -- 1 behind, 2 posts, 3 platforms, 4 on them, 5 front
  local function draw(layer, fn)
    local r = rng.fork()
    layers[layer][#layers[layer] + 1] = function() fn(r) end
  end
  local function at(x, y, fn) return function(r) ink.push() ink.translate(x, y) fn(r) ink.pop() end end
  local function reg(a, b, c, d, tag) boxes[#boxes + 1] = { min(a, c), min(b, d), max(a, c), max(b, d), tag } end
  local function free(a, b, c, d, m, ignore)
    m = m or 0.05
    a, b, c, d = min(a, c), min(b, d), max(a, c), max(b, d)
    if a < x0 - 0.05 or c > x1 + 0.05 then return false end
    for _, q in ipairs(boxes) do
      if q[5] ~= ignore and a < q[3] - m and c > q[1] + m and b < q[4] - m and d > q[2] + m then return false end
    end
    return true
  end
  -- a reference cat: pose sizes (page cm) for the overlap test
  local CAT = { loaf = { 2.2, 1.25 }, sit = { 1.2, 1.95 }, curl = { 1.9, 0.9 }, walk = { 2.4, 1.45 } }
  local function cat(x, y, pose, facing, angle, inside)
    local w, h = CAT[pose][1], CAT[pose][2]
    if not inside and not free(x - w / 2, y + 0.03, x + w / 2, y + h, 0.02) then return false end
    if not inside then reg(x - w / 2, y, x + w / 2, y + h, "cat") end
    cats[#cats + 1] = { x, y, pose, facing or (rng.chance(0.5) and 1 or -1), angle }
    return true
  end
  local spots = {}                                    -- candidate cat places, chosen at the end
  local function spot(x, y, poses, inside, angle) spots[#spots + 1] = { x, y, poses, inside, angle } end

  -- ---------------------------------------------------------------- 1. the floor tower
  local fy = y0
  local top = fy + real(C.DIM.base_t)
  local n = rng.chance(0.6) and 3 or 2
  local xs = {}
  if n == 3 then
    xs = { x0 + 0.55 + rng.range(0, 0.15), mid + rng.sym(0.3), x1 - 0.65 - rng.range(0, 0.2) }
  else
    local a = x0 + 0.6 + rng.range(0, 0.7)
    xs = { a, min(x1 - 0.6, a + rng.range(2.4, 3.6)) }
  end
  local step = real(rng.range(48, 56))
  local spine = rng.int(1, n)
  local lv = {}
  local maxlv = rng.int(4, 5)
  for i = 1, n do lv[i] = i == spine and maxlv or rng.int(1, maxlv - 1) end
  if n == 3 and lv[1] == lv[2] and lv[2] == lv[3] then lv[2] = lv[2] - 1 end
  -- platforms between neighbors, at the lower one's top; neighbors at the same level merge
  local plats = {}
  for i = 1, n - 1 do
    local L = min(lv[i], lv[i + 1])
    local last = plats[#plats]
    if last and last.L == L and last.j == i then
      last.j = i + 1
    else
      plats[#plats + 1] = { L = L, i = i, j = i + 1 }
    end
  end
  local ptop = {}                                     -- which posts end at a platform
  for _, p in ipairs(plats) do
    p.y = top + p.L * step
    p.xa = max(x0 + 0.02, xs[p.i] - rng.range(0.3, 0.5))
    p.xb = min(x1 - 0.02, xs[p.j] + rng.range(0.3, 0.5))
    for k = p.i, p.j do if lv[k] == p.L then ptop[k] = true end end
  end
  -- base and posts
  local bxa, bxb = max(x0, xs[1] - 0.5), min(x1, xs[n] + 0.5)
  draw(2, at((bxa + bxb) / 2, fy, function(r) C.base(r, { w = bxb - bxa }) end))
  reg(bxa, fy, bxb, top, "base")
  spot(xs[1] + (xs[2] - xs[1]) / 2, top, { "sit", "loaf" })
  local kinds = { "banded", "sisal", "banded", "plush" }
  for i = 1, n do
    local h = lv[i] * step
    local kind = kinds[rng.int(1, #kinds)]
    draw(2, at(xs[i], top, function(r) C.post(r, { kind = kind, bands = rng.int(1, 3), h = h }) end))
    reg(xs[i] - pr, top, xs[i] + pr, top + h, "post")
  end
  for _, p in ipairs(plats) do
    draw(3, at((p.xa + p.xb) / 2, p.y, function(r) C.shelf(r, { kind = "plain", w = p.xb - p.xa }) end))
    reg(p.xa, p.y, p.xb, p.y + st, "plat")
  end
  -- crossbeams, below the lowest platform between each pair
  for i = 1, n - 1 do
    if rng.chance(0.75) then
      local y = top + rng.range(0.9, 1.7)
      if free(xs[i] + pr, y - 0.2, xs[i + 1] - pr, y + 0.2) then
        draw(1, function(r) C.beam(r, xs[i], y, xs[i + 1], y) end)
        reg(xs[i], y - 0.18, xs[i + 1], y + 0.18, "beam")
      end
    end
  end
  -- a hammock under a high platform
  for _, p in ipairs(plats) do
    if p.L >= 2 and rng.chance(0.7) then
      local a, b = xs[p.i] + pr, xs[p.i + 1] - pr
      local y = p.y - rng.range(0.9, 1.3)
      if b - a > 1.4 and free(a, y - 1.0, b, y) then
        draw(1, function(r) C.hammock(r, a, y, b, y) end)
        reg(a, y - 1.0, b, y, "hammock")
        spot((a + b) / 2, y - 0.85, { "curl" }, true)
        break
      end
    end
  end
  -- what stands on each platform: the free stretches of its top, between the posts that run on up
  for _, p in ipairs(plats) do
    local cuts = { p.xa }
    for k = p.i, p.j do if not ptop[k] then cuts[#cuts + 1] = xs[k] - pr cuts[#cuts + 1] = xs[k] + pr end end
    cuts[#cuts + 1] = p.xb
    local best, ba, bb = 0, nil, nil
    for k = 1, #cuts - 1, 2 do
      if cuts[k + 1] - cuts[k] > best then best, ba, bb = cuts[k + 1] - cuts[k], cuts[k], cuts[k + 1] end
    end
    local py = p.y + st
    local cw, ch = real(C.DIM.condo_w), real(C.DIM.condo_h) + 0.2
    local placed = false
    if best >= cw + 0.1 and rng.chance(0.65) then
      local cx = rng.chance(0.5) and (ba + cw / 2 + 0.05) or (bb - cw / 2 - 0.05)
      if free(cx - cw / 2, py, cx + cw / 2, py + ch) then
        local holes = ({ { "round" }, { "arch" }, { "oval" } })[rng.int(1, 3)]
        draw(4, at(cx, py, function(r) C.condo(r, { holes = holes }) end))
        reg(cx - cw / 2, py, cx + cw / 2, py + ch, "condo")
        spot(cx, py + ch, { "loaf", "sit" })
        placed = true
        -- a basket on the condo, sometimes
        if rng.chance(0.4) and free(cx - 0.9, py + ch, cx + 0.9, py + ch + 0.9) then
          draw(4, at(cx, py + ch, function(r) C.bowl(r, { kind = "basket", scallop = rng.chance(0.5), r = real(17) }) end))
          reg(cx - 0.9, py + ch, cx + 0.9, py + ch + 0.85, "bowl")
          spot(cx, py + ch + real(9), { "curl" }, true)
        end
      end
    end
    if not placed and best >= 1.4 then
      spot((ba + bb) / 2, py, { "loaf", "sit" })
    end
    -- a toy under one end
    if rng.chance(0.5) then
      local tx = rng.chance(0.5) and p.xa + 0.25 or p.xb - 0.25
      if free(tx - 0.15, p.y - 1.5, tx + 0.15, p.y - 0.05) then
        draw(5, at(tx, p.y, function(r) C.ball(r, { kind = rng.pick({ "pom", "sisal", "dark" }), L = real(rng.range(20, 28)) }) end))
        reg(tx - 0.15, p.y - 1.5, tx + 0.15, p.y, "toy")
      end
    end
  end
  -- the tops of the posts that do not end at a platform
  local tops = {}
  for i = 1, n do
    if not ptop[i] then
      local y = top + lv[i] * step
      local choices = { "ring", "tube", "pad", "cushion" }
      for _ = 1, 4 do
        local c = table.remove(choices, rng.int(1, #choices))
        if c == "ring" then
          local d = real(42)
          if free(xs[i] - d / 2, y, xs[i] + d / 2, y + d) then
            draw(4, at(xs[i], y, function(r) C.ring(r, { d = d }) end))
            reg(xs[i] - d / 2, y, xs[i] + d / 2, y + d, "ring")
            spot(xs[i], y + real(3), { "curl" }, true)
            tops[#tops + 1] = { xs[i], y + d } break
          end
        elseif c == "tube" then
          local w = real(30)
          if free(xs[i] - w / 2 - 0.15, y, xs[i] + w / 2 + 0.15, y + real(22)) then
            draw(4, at(xs[i], y, function(r) C.tube(r, { w = w }) end))
            reg(xs[i] - w / 2 - 0.15, y, xs[i] + w / 2 + 0.15, y + real(22), "tube")
            spot(xs[i], y + real(22), { "sit", "loaf" })
            tops[#tops + 1] = { xs[i], y + real(22) } break
          end
        else
          local w = real(c == "pad" and 34 or 42)
          local cx = min(x1 - w / 2, max(x0 + w / 2, xs[i] + rng.sym(0.3)))
          if free(cx - w / 2, y, cx + w / 2, y + 0.45) then
            if c == "pad" then draw(4, at(cx, y, function(r) C.pad(r, { w = w }) end))
            else draw(4, at(cx, y, function(r) C.shelf(r, { kind = "cushion", w = w }) end)) end
            reg(cx - w / 2, y, cx + w / 2, y + 0.45, c)
            spot(cx, y + (c == "pad" and real(4) or real(10)), { "loaf", "curl", "sit" })
            tops[#tops + 1] = { cx, y + 0.45 } break
          end
        end
      end
    end
  end
  local T = top
  for _, q in ipairs(boxes) do T = max(T, q[4]) end

  -- ---------------------------------------------------------------- 2. the wall
  -- the route goes up on the side away from the tallest post
  local right = xs[spine] < mid
  local sgn = right and -1 or 1                       -- the runs point inward
  local xr = right and (x1 - 0.42) or (x0 + 0.42)     -- the riser
  local rh = rng.range(1.8, 2.5)
  local l1, l2 = rng.range(1.5, 2.3), rng.range(1.3, 2.0)
  local yR1 = top + (lv[spine] - 1) * step + rng.range(0.6, 1.0)
  local wall_top = T
  local function route_free(y)
    return free(min(xr, xr + sgn * l1) - 0.45, y - 0.25, max(xr, xr + sgn * l1) + 0.45, y + 0.1)
      and free(xr - 0.45, y, xr + 0.45, y + rh)
      and free(min(xr, xr + sgn * l2) - 0.45, y + rh - 0.25, max(xr, xr + sgn * l2) + 0.45, y + rh + 0.1)
  end
  for _ = 1, 20 do if route_free(yR1) then break end yR1 = yR1 + 0.3 end
  local yR2 = yR1 + rh
  local pts = { { xr + sgn * l1, yR1 }, { xr, yR1 }, { xr, yR2 }, { xr + sgn * l2, yR2 } }
  draw(3, function(r) C.route(r, pts) end)
  reg(min(xr, xr + sgn * l1) - 0.42, yR1 - 0.25, max(xr, xr + sgn * l1) + 0.42, yR1 + 0.08, "route")
  reg(xr - 0.42, yR1, xr + 0.42, yR2, "route")
  reg(min(xr, xr + sgn * l2) - 0.42, yR2 - 0.25, max(xr, xr + sgn * l2) + 0.42, yR2 + 0.08, "route")
  spot(xr + sgn * l1 * 0.55, yR1, { "sit", "loaf" })
  -- across to a half-moon on the far side: a shallow bridge, or floating steps if short
  local xe = xr + sgn * (l2 + real(16) / 2)            -- the far end of the upper run
  local mw = real(rng.range(34, 42))
  local mx = right and (x0 + mw / 2 + 0.05) or (x1 - mw / 2 - 0.05)
  local mtop = real(3) + real(4.5)
  local mxe = mx - sgn * mw / 2                        -- its edge toward the route
  local span = abs(xe - mxe)
  local my = yR2 + rng.sym(0.25) - mtop
  local crossed = false
  if span >= 1.3 then
    for _ = 1, 16 do
      local bx0, bx1 = min(xe, mxe), max(xe, mxe)
      if free(bx0 + 0.5, min(yR2, my + mtop) - 0.5, bx1 - 0.5, max(yR2, my + mtop) + real(28)) and free(mx - mw / 2, my - 0.3, mx + mw / 2, my + mtop) then
        crossed = true break
      end
      my = my + 0.25
    end
  end
  if crossed then
    local dy = (my + mtop) - yR2
    if abs(dy) > span * 0.27 then my = yR2 + (dy > 0 and 1 or -1) * span * 0.27 - mtop end
    draw(3, at(mx, my, function(r) C.moon(r, { w = mw }) end))
    reg(mx - mw / 2, my - 0.3, mx + mw / 2, my + mtop, "moon")
    spot(mx, my + mtop, { "loaf", "sit" })
    local sag = rng.range(0.15, 0.3)
    draw(5, function(r) C.bridge(r, mxe, my + mtop, xe, yR2, { sag = sag }) end)
    reg(min(xe, mxe) + 0.3, min(yR2, my + mtop) - sag - 0.2, max(xe, mxe) - 0.3, max(yR2, my + mtop) + real(28), "bridge")
    -- the walking cat, on the deck at the middle
    local t = 0.5
    local bx = mxe + (xe - mxe) * t
    local byy = (my + mtop) + (yR2 - my - mtop) * t - sag
    local ang = math.deg(math.atan(yR2 - my - mtop, xe - mxe))
    if ang > 90 or ang < -90 then ang = ang - 180 end
    spot(bx, byy, { "walk" }, true, ang)
    wall_top = max(wall_top, yR2 + real(28), my + mtop)
  end
  -- hexes: on a short post on the upper run, or on the wall above it
  local R = real(C.DIM.hex_w) / 2
  local hx = xr + sgn * min(l2 * 0.55, 1.2)
  local hp = rng.chance(0.5) and rng.range(0.8, 1.5) or 0
  local hy = yR2 + hp + 0.866 * R + (hp == 0 and 0.15 or 0)
  local placed_hex = {}
  local hy0 = hy
  for k = 1, 30 do
    if free(hx - R, hy - 0.866 * R, hx + R, hy + 0.866 * R) then break end
    hy = hy + 0.3
    if k % 10 == 0 then hx, hy = hx + sgn * 0.6, hy0 hp = 0 end
  end
  if free(hx - R, hy - 0.866 * R, hx + R, hy + 0.866 * R) then
    if hp > 0 and hy - 0.866 * R - yR2 > 0.3 then
      local ph = hy - 0.866 * R - yR2
      draw(2, at(hx, yR2, function(r) C.post(r, { kind = "sisal", h = ph }) end))
    end
    draw(3, at(hx, hy, function(r) C.hex(r, {}) end))
    reg(hx - R, hy - 0.866 * R, hx + R, hy + 0.866 * R, "hex")
    placed_hex[#placed_hex + 1] = { hx, hy }
    spot(hx, hy - 0.866 * R + real(3.5), { "sit" }, true)
    -- a second one, up and inward, sharing an edge
    local h2x, h2y = hx + sgn * 1.5 * R, hy + 0.866 * R
    if rng.chance(0.7) and free(h2x - R, h2y - 0.866 * R, h2x + R, h2y + 0.866 * R) then
      draw(3, at(h2x, h2y, function(r) C.hex(r, {}) end))
      reg(h2x - R, h2y - 0.866 * R, h2x + R, h2y + 0.866 * R, "hex")
      placed_hex[#placed_hex + 1] = { h2x, h2y }
      spot(h2x, h2y - 0.866 * R + real(3.5), { "sit" }, true)
    end
  end
  for _, h in ipairs(placed_hex) do wall_top = max(wall_top, h[2] + 0.866 * R) end
  -- a space bubble: on the far side, above the half-moon
  if crossed then
    local br = real(rng.range(17, 21))
    local bw = br + real(12)
    local bx = mx
    local by = my + mtop + rng.range(2.4, 2.9)
    if free(bx - bw, by - real(4) - br - 0.1, bx + bw, by + 0.15) then
      draw(4, at(bx, by, function(r) C.bubble(r, { r = br }) end))
      reg(bx - bw, by - real(4) - br, bx + bw, by + 0.15, "bubble")
      spot(bx, by - real(4) - br * 0.85, { "curl" }, true)
      wall_top = max(wall_top, by + 0.2)
    end
  end

  -- ---------------------------------------------------------------- 3. the top, sparse
  local y = wall_top + rng.range(0.4, 0.8)
  local onright = rng.chance(0.5)
  local px, py = (placed_hex[#placed_hex] or { mid, wall_top })[1], wall_top
  local nm, pw = 0, nil
  local maxm = rng.int(1, 2)
  while y < y1 - 3.5 and nm < maxm do
    local w = real(rng.range(28, 36))
    local x = onright and (x1 - w / 2 - rng.range(0.1, 0.6)) or (x0 + w / 2 + rng.range(0.1, 0.6))
    local yy = y + rng.range(2.2, 3.0)
    if free(x - w / 2, yy - 0.3, x + w / 2, yy + 0.4) then
      local kind = rng.pick({ "steps", "pegs", "dots" })
      local ax, ay = px + (onright and 1 or -1) * (pw or 0) / 2, py + 0.25
      local bx, by = x - (onright and w / 2 + 0.3 or -(w / 2 + 0.3)), yy + 0.1
      draw(5, function(r) C[kind](r, ax, ay, bx, by, {}) end)
      reg(min(ax, bx) - 0.2, ay, max(ax, bx) + 0.2, by, "chain")
      draw(3, at(x, yy, function(r) C.moon(r, { w = w, carpet = rng.chance(0.5) }) end))
      reg(x - w / 2, yy - 0.3, x + w / 2, yy + 0.4, "moon")
      spot(x, yy + real(7.5), { "sit", "loaf" })
      if rng.chance(0.4) then
        local tx = x + (onright and -1 or 1) * (w / 2 - 0.2)
        draw(5, at(tx, yy, function(r) C.ball(r, { kind = "sisal", L = real(20) }) end))
      end
      px, py, y, pw = x, yy + 0.4, yy + 0.4, w
      nm = nm + 1
    else
      y = y + 0.5
    end
    onright = not onright
  end
  -- a tapering line of dots to finish
  local ex = mid + rng.sym(1.5)
  local ey = min(y1, py + rng.range(2.0, 3.0))
  if ey - py > 1.0 then
    local sx = px + ((ex > px) and 1 or -1) * ((pw or 0) / 2 + 0.3)
    draw(5, function(r) C.dots(r, sx, py + 0.3, ex, ey, { taper = true, d = real(10) }) end)
  end

  -- ---------------------------------------------------------------- the footer
  local fx0 = x1 + 0.9
  local fw = rng.range(4.0, 5.4)
  draw(2, at(fx0 + fw / 2, fy, function(r) C.base(r, { w = fw }) end))
  local wx = fx0 + rng.range(1.1, 1.5)
  draw(4, at(wx, top, function(r) C.wave(r, { w = real(46) }) end))
  spot(wx, top + real(8), { "curl" }, true)
  local sx = fx0 + fw - rng.range(0.6, 0.9)
  local sh = real(rng.range(18, 24))
  draw(2, at(sx, top, function(r) C.post(r, { kind = "sisal", h = sh }) end))
  if rng.chance(0.5) then draw(4, at(sx, top + sh, function(r) C.pad(r, { w = real(30) }) end))
  else draw(4, at(sx, top + sh, function(r) C.tube(r, { w = real(28), d = real(18) }) end)) end

  -- draw, back to front
  for _, L in ipairs(layers) do for _, fn in ipairs(L) do fn() end end

  -- cats: about seven, from the candidate spots, none overlapping
  local order = {}
  for i = 1, #spots do order[i] = i end
  for i = #order, 2, -1 do local j = rng.int(1, i) order[i], order[j] = order[j], order[i] end
  local want = rng.int(6, 8)
  for _, i in ipairs(order) do
    if #cats >= want then break end
    local s = spots[i]
    local pose = s[3][rng.int(1, #s[3])]
    if pose == "walk" then
      local f = s[5] and 1 or 1
      cat(s[1], s[2], "walk", f, s[5], true)
    else
      cat(s[1], s[2], pose, nil, nil, s[4])
    end
  end
  return cats
end

return M

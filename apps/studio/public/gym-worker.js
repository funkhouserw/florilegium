// gym-worker.js -- grows a cat gym, an oak or florilegium's flowers off the main thread: the package's Lua (scene.lua and what it
// requires) in wasmoon, Lua 5.4 compiled to WebAssembly, as web/worker.js does for the playground.
const WASMOON = 'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/dist/'
importScripts(WASMOON + 'index.js')
const MODULES = ['florilegium', 'florilegium-ink', 'florilegium-pgfmath', 'florilegium-flora', 'florilegium-grow', 'florilegium-authored', 'florilegium-figures', 'florilegium-theme-geometric', 'florilegium-theme-math', 'florilegium-species', 'florilegium-native', 'florilegium-svg', 'florilegium-theme-cattree', 'florilegium-theme-oak', 'florilegium-theme-kelp', 'florilegium-initial', 'florilegium-scene']

const ready = (async () => {
  const factory = new self.wasmoon.LuaFactory(WASMOON + 'glue.wasm')
  const base = new URL('lua/', self.location.href)
  const sources = await Promise.all(MODULES.map(async (m) => {
    const r = await fetch(new URL(m + '.lua', base))
    if (!r.ok) throw new Error('cannot load ' + m + '.lua')
    return r.text()
  }))
  await Promise.all(MODULES.map((m, i) => factory.mountFile('/gym/' + m + '.lua', sources[i])))
  const lua = await factory.createEngine()
  await lua.doString('package.path = "/gym/?.lua;" .. package.path')
  return lua
})()

const SEASONS = ['spring', 'summer', 'autumn', 'winter', 'dead']
const num = (v) => (Number.isFinite(v) ? String(v) : '0')
function literal(o) {
  const keep = (o.keepouts || []).map((q) => '{ ' + q.map(num).join(', ') + ' }').join(', ')
  return `{ w = ${num(o.w)}, h = ${num(o.h)}, seed = ${num(Math.round(o.seed))}, cats = ${num(Math.round(o.cats))},
    size = ${num(o.size)}, density = ${num(o.density)}, id = "p${num(Math.round(o.index))}-", page = ${num(Math.round(o.page ?? o.index))},
    grows = "${['oak', 'flowers', 'kelp'].includes(o.grows) ? o.grows : 'gym'}", ink = "${o.ink === 'blue' ? 'blue' : 'green'}",
    crown = "${o.crown === 'open' ? 'open' : 'lush'}", season = "${SEASONS.includes(o.season) ? o.season : 'summer'}", spanishmoss = ${o.spanishmoss === true}, heart = ${o.heart === 'always' ? 'true' : o.heart === 'never' ? 'false' : 'nil'}, keepouts = { ${keep} } }`
}

// an initial: the letter's outline from the studio's font, in font units ({x, y, "m"}, {x, y, "l"},
// {x1, y1, x, y, "q"}, {x1, y1, x2, y2, x, y, "c"}, as luaotfload gives it)
function initialLiteral(o) {
  const g = o.glyph || {}
  const segs = (g.segments || []).map((s) => '{ ' + s.slice(0, -1).map(num).join(', ') + ', "' + (['m', 'l', 'q', 'c'].includes(s[s.length - 1]) ? s[s.length - 1] : 'l') + '" }').join(', ')
  const letter = String.fromCodePoint(Number(o.codepoint) || 65)
  return `{ letter = ${JSON.stringify(letter)}, size = ${num(o.size)}, seed = ${num(Math.round(o.seed))}, id = "i${num(Math.round(o.index || 0))}-",
    grows = "${['oak', 'flowers', 'kelp'].includes(o.grows) ? o.grows : 'gym'}", ink = "${o.ink === 'blue' ? 'blue' : 'green'}",
    season = "${SEASONS.includes(o.season) ? o.season : 'summer'}",
    glyph = { units = ${num(g.units)}, boundingbox = { ${(g.bbox || [0, 0, 1, 1]).map(num).join(', ')} }, segments = { ${segs} } } }`
}

self.onmessage = async (e) => {
  const { id, options } = e.data
  let lua
  try {
    lua = await ready
    if (options.initial) {
      const svg = await lua.doString(options.ops
        ? `local S = require("florilegium-scene") S.initial(${initialLiteral(options.initial)}) return table.concat(S.last_streams, "\\n")`
        : `return require("florilegium-scene").initial(${initialLiteral(options.initial)})`)
      self.postMessage({ id, svg })
      return
    }
    // options.ops: the same drawing as PDF operators, in page points, y up
    const svg = await lua.doString(options.ops
      ? `local S = require("florilegium-scene") S.page(${literal(options)}) return table.concat(S.last_streams, "\\n")`
      : `return require("florilegium-scene").page(${literal(options)})`)
    self.postMessage({ id, svg })
  } catch (err) {
    self.postMessage({ id, error: String((err && err.message) || err) })
  } finally {
    // wasmoon keeps what doString returned on the Lua stack: clear it after each page
    if (lua) lua.global.setTop(0)
  }
}

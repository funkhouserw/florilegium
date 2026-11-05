// gym-worker.js -- grows a cat gym off the main thread: the package's Lua (scene.lua and what it
// requires) in wasmoon, Lua 5.4 compiled to WebAssembly, as web/worker.js does for the playground.
const WASMOON = 'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/dist/'
importScripts(WASMOON + 'index.js')
const MODULES = ['florilegium-ink', 'florilegium-pgfmath', 'florilegium-flora', 'florilegium-svg', 'florilegium-theme-cattree', 'florilegium-theme-oak', 'florilegium-theme-oldcats', 'florilegium-grow', 'florilegium-scene']

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

const num = (v) => (Number.isFinite(v) ? String(v) : '0')
function literal(o) {
  const keep = (o.keepouts || []).map((q) => '{ ' + q.map(num).join(', ') + ' }').join(', ')
  return `{ w = ${num(o.w)}, h = ${num(o.h)}, seed = ${num(Math.round(o.seed))}, cats = ${num(Math.round(o.cats))},
    size = ${num(o.size)}, density = ${num(o.density)}, id = "p${num(Math.round(o.index))}-",
    grows = "${o.grows === 'oak' ? 'oak' : o.grows === 'cats' ? 'cats' : 'gym'}", ink = "${o.ink === 'blue' ? 'blue' : 'green'}", keepouts = { ${keep} } }`
}

self.onmessage = async (e) => {
  const { id, options } = e.data
  let lua
  try {
    lua = await ready
    const svg = await lua.doString(`return require("florilegium-scene").page(${literal(options)})`)
    self.postMessage({ id, svg })
  } catch (err) {
    self.postMessage({ id, error: String((err && err.message) || err) })
  } finally {
    // wasmoon keeps what doString returned on the Lua stack: clear it after each page
    if (lua) lua.global.setTop(0)
  }
}

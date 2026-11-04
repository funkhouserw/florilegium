// worker.js -- grows a florilegium page off the main thread: the package's own
// Lua (svg.lua and what it requires) run by wasmoon, Lua 5.4 compiled to
// WebAssembly. The same Lua makes the same garden as LuaLaTeX, byte for byte.
// Copyright (c) 2026 Kevin Raymond. MIT License: see LICENSE or florilegium.sty.

const WASMOON = 'https://cdn.jsdelivr.net/npm/wasmoon@1.16.0/dist/'
importScripts(WASMOON + 'index.js')

const MODULES = ['ink', 'flora', 'grow', 'florilegium', 'authored', 'figures', 'theme-geometric', 'theme-math', 'theme-cattree', 'svg']

// the published site has the .lua files beside this one; the repository has them one up
async function fetchLua(name) {
  for (const base of ['./', '../']) {
    const r = await fetch(base + name + '.lua')
    if (r.ok) return r.text()
  }
  throw new Error('cannot load ' + name + '.lua')
}

const ready = (async () => {
  const factory = new self.wasmoon.LuaFactory(WASMOON + 'glue.wasm')
  const sources = await Promise.all(MODULES.map(fetchLua))
  await Promise.all(MODULES.map((m, i) => factory.mountFile('/florilegium/' + m + '.lua', sources[i])))
  const lua = await factory.createEngine()
  await lua.doString('package.path = "/florilegium/?.lua;" .. package.path')
  return lua
})()

// options as a Lua table literal: only numbers, booleans and plain strings get through
function luaTable(o) {
  const parts = []
  for (const [k, v] of Object.entries(o)) {
    if (!/^[a-z]+$/.test(k) || v === undefined || v === null) continue
    if (typeof v === 'number' && isFinite(v)) parts.push(`${k} = ${v}`)
    else if (typeof v === 'boolean') parts.push(`${k} = ${v}`)
    else if (typeof v === 'string' && /^[\w.#-]*$/.test(v)) parts.push(`${k} = "${v}"`)
  }
  return '{ ' + parts.join(', ') + ' }'
}

self.onmessage = async (e) => {
  const { id, options } = e.data
  const lua = await ready.catch(() => null)
  if (!lua) return
  try {
    const t0 = performance.now()
    const r = await lua.doString(`
      local svg, g, more = require("svg").page(${luaTable(options)})
      return { svg = svg, pw = g.pw, ph = g.ph, textleft = g.textleft, textright = g.textright,
        ytop = g.ytop, ybot = g.ybot, mirror = g.mirror or false, captions = more.captions, stats = more.stats }`)
    self.postMessage({ id, ...r, ms: performance.now() - t0 })
  } catch (err) {
    self.postMessage({ id, error: String(err && err.message || err) })
  } finally {
    // wasmoon leaves what doString returned on the Lua stack, so every page would stay
    // in memory (2.7 MB each) until WebAssembly runs out; clear it after each one
    lua.global.setTop(0)
  }
}

ready.then(() => self.postMessage({ ready: true }), (err) => self.postMessage({ error: String(err) }))

// copies the package's Lua into public/lua, so the app's worker can fetch it
import { copyFileSync, mkdirSync } from 'node:fs'
const dir = new URL('../public/lua/', import.meta.url)
mkdirSync(dir, { recursive: true })
for (const m of ['florilegium-ink', 'florilegium-flora', 'florilegium-svg', 'florilegium-theme-cattree', 'florilegium-theme-oak', 'florilegium-theme-oldcats', 'florilegium-grow', 'florilegium-scene']) {
  copyFileSync(new URL(`../../../${m}.lua`, import.meta.url), new URL(`${m}.lua`, dir))
}

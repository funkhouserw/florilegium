// copies the package's Lua into public/lua, so the app's worker can fetch it, and the
// playground's fonts into public/fonts, so a PDF can embed them
import { copyFileSync, mkdirSync } from 'node:fs'
const fonts = new URL('../public/fonts/', import.meta.url)
mkdirSync(fonts, { recursive: true })
for (const f of ['fell.woff2', 'fell-italic.woff2', 'lmroman.woff2', 'lmroman-italic.woff2', 'lmroman-bold.woff2', 'OFL.txt', 'GUST-FONT-LICENSE.txt']) {
  copyFileSync(new URL(`../../../web/fonts/${f}`, import.meta.url), new URL(f, fonts))
}
// the same subsets as plain TrueType: what pdf-lib's subsetter makes of a WOFF2 or of CFF outlines
// is selectable but draws nothing, or is invalid
for (const f of ['fell.ttf', 'fell-italic.ttf', 'lmroman.ttf', 'lmroman-italic.ttf', 'lmroman-bold.ttf']) copyFileSync(new URL(`../fonts/${f}`, import.meta.url), new URL(f, fonts))
const dir = new URL('../public/lua/', import.meta.url)
mkdirSync(dir, { recursive: true })
for (const m of ['florilegium', 'florilegium-ink', 'florilegium-pgfmath', 'florilegium-flora', 'florilegium-grow', 'florilegium-authored', 'florilegium-figures', 'florilegium-theme-geometric', 'florilegium-theme-math', 'florilegium-species', 'florilegium-native', 'florilegium-svg', 'florilegium-theme-cattree', 'florilegium-theme-oak', 'florilegium-theme-kelp', 'florilegium-scene']) {
  copyFileSync(new URL(`../../../${m}.lua`, import.meta.url), new URL(`${m}.lua`, dir))
}

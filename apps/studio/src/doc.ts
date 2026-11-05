// doc.ts -- what the studio saves: in this browser as you work, and to a file you can keep. Whatever
// comes back is checked, since a file can hold anything and these values reach CSS and Lua.
import type { Box } from './flow'
import { FAMILIES } from './fonts'

export const CM = 72 / 2.54
export const SIZES = {
  insta: { label: 'Instagram 4:5', w: 21, h: 26.25, px: 1080 },
  square: { label: 'Square 1:1', w: 21, h: 21, px: 1080 },
  story: { label: 'Story 9:16', w: 18, h: 32, px: 1080 },
  a4: { label: 'A4 page', w: 21, h: 29.7, px: 1654 },
  letter: { label: 'US Letter', w: 21.59, h: 27.94, px: 1700 },
} as const
export type SizeKey = keyof typeof SIZES
export const SEASONS = ['spring', 'summer', 'autumn', 'winter', 'dead'] as const
export type Season = typeof SEASONS[number]
export type Grows = 'gym' | 'oak' | 'cats'

export type Doc = {
  text: string; sizeKey: SizeKey; family: string; fontSize: number; seed: number; cats: number; pieces: number
  grows: Grows; inkName: 'green' | 'blue'; crown: 'lush' | 'open'; season: Season; spanishmoss: boolean; drawn: Box[][]
}

const SAMPLE = `# Why my cat needs a gym

Cats climb to see, and to be *seen*. A shelf by the window is good; a route from the floor to the top of the room, with somewhere to rest on the way, is better.

## Text boxes

Draw a box anywhere on a page and this text moves into it. Draw another, and it runs on from the first. What does not fit goes to the next page, and the gym grows around whatever you leave clear.

## The route

A cat needs **two things** from a route: a way up, and a reason to stop. So every ladder here leads to a shelf, every shelf has room for a cat.`

let nextBox = 1
export const newBoxId = () => nextBox++
const startBox = (k: SizeKey): Box => {
  const W = SIZES[k].w * CM, H = SIZES[k].h * CM
  return { id: newBoxId(), x: W * 0.14, y: H * 0.1, w: W * 0.72, h: H * 0.36 }
}
export const newDoc = (): Doc => ({
  text: SAMPLE, sizeKey: 'insta', family: FAMILIES[0].css, fontSize: 26, seed: 3, cats: 2, pieces: 1.4,
  grows: 'gym', inkName: 'blue', crown: 'lush', season: 'summer', spanishmoss: false, drawn: [[startBox('insta')]],
})

const num = (v: unknown, lo: number, hi: number, fallback: number) => (typeof v === 'number' && Number.isFinite(v) ? Math.max(lo, Math.min(hi, v)) : fallback)
const oneOf = <T,>(v: unknown, options: readonly T[], fallback: T): T => (options.includes(v as T) ? (v as T) : fallback)

export function checkDoc(raw: unknown): Doc {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>
  const d = newDoc()
  const sizeKey = oneOf(o.sizeKey, Object.keys(SIZES) as SizeKey[], d.sizeKey)
  const W = SIZES[sizeKey].w * CM, H = SIZES[sizeKey].h * CM
  // the boxes get new ids, so they can't collide with any made since
  const drawn = Array.isArray(o.drawn) ? o.drawn.filter(Array.isArray).map((page: unknown[]) => page.flatMap((b): Box[] => {
    const q = (b && typeof b === 'object' ? b : {}) as Record<string, unknown>
    const box = { id: 0, x: num(q.x, 0, W, -1), y: num(q.y, 0, H, -1), w: num(q.w, 1, W, -1), h: num(q.h, 1, H, -1) }
    return box.x < 0 || box.y < 0 || box.w < 0 || box.h < 0 ? [] : [{ ...box, id: newBoxId() }]
  })) : []
  return {
    text: typeof o.text === 'string' ? o.text : d.text,
    sizeKey,
    family: oneOf(o.family, FAMILIES.map((f) => f.css), d.family),
    fontSize: num(o.fontSize, 10, 90, d.fontSize),
    seed: Math.round(num(o.seed, 1, 1e9, d.seed)),
    cats: Math.round(num(o.cats, 0, 6, d.cats)),
    pieces: num(o.pieces, 0.8, 2.5, d.pieces),
    grows: oneOf(o.grows, ['gym', 'oak', 'cats'] as const, d.grows),
    inkName: oneOf(o.inkName, ['green', 'blue'] as const, d.inkName),
    crown: oneOf(o.crown, ['lush', 'open'] as const, d.crown),
    season: oneOf(o.season, SEASONS, d.season),
    spanishmoss: o.spanishmoss === true,
    drawn: drawn.length ? drawn : [[startBox(sizeKey)]],
  }
}

const KEY = 'florilegium-studio'
export function loadDoc(): Doc {
  try {
    const saved = localStorage.getItem(KEY)
    if (saved) return checkDoc(JSON.parse(saved))
  } catch { /* unreadable: start fresh */ }
  return newDoc()
}
export const saveDoc = (d: Doc) => localStorage.setItem(KEY, JSON.stringify(d))
export const docFile = (d: Doc) => new Blob([JSON.stringify({ studio: 1, ...d }, null, 1)], { type: 'application/json' })
export function readDocFile(text: string): Doc {
  const raw = JSON.parse(text)
  if (!raw || raw.studio !== 1) throw new Error('that is not a studio file')
  return checkDoc(raw)
}

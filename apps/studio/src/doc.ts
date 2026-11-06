// doc.ts -- what the studio saves: in this browser as you work, and to a file you can keep. Whatever
// comes back is checked, since a file can hold anything and these values reach CSS and Lua. A work
// saved before stories existed comes back as one story through all its boxes.
import type { Node } from 'prosemirror-model'
import { schema, fromMarkdown } from './schema'
import type { Box, Layer } from './flow'
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
export type Margins = { top: number; right: number; bottom: number; left: number }   // in cm
export const SEASONS = ['spring', 'summer', 'autumn', 'winter', 'dead'] as const
export type Season = typeof SEASONS[number]
export type Grows = 'gym' | 'oak' | 'flowers' | 'kelp'
// each page grows its own drawing, or pages laid out alike (where their text ends included) get the same one
export type PerPage = 'new' | 'match'
export type Heart = 'sometimes' | 'never' | 'always'    // the oak's carved I + C
export const TEXT_COLOR = '#1b2a6b'
export type SavedStory = { id: number; doc: Node; auto: boolean }
export type Doc = {
  stories: SavedStory[]; sizeKey: SizeKey; family: string; fontSize: number; seed: number; cats: number; pieces: number
  grows: Grows; inkName: 'green' | 'blue'; crown: 'lush' | 'open'; season: Season; spanishmoss: boolean; heart: Heart; perPage: PerPage; textColor: string; margins: Margins; drawn: Box[][]
}

const SAMPLE = `# Why my cat needs a gym

Cats climb to see, and to be *seen*. A shelf by the window is good; a route from the floor to the top of the room, with somewhere to rest on the way, is better.

## Click anywhere in this text

Type here. What doesn't fit moves on to the next box, or the next page, and the arrow keys follow it.

## The route

A cat needs **two things** from a route: a way up, and a reason to stop. So every ladder here leads to a shelf, every shelf has room for a cat.`

let nextBox = 1
let nextStory = 1
export const newBoxId = () => nextBox++
export const newStoryId = () => nextStory++
export const newStoryDoc = () => schema.node('doc', null, [schema.nodes.paragraph.create()])
const MARGINS: Margins = { top: 2.5, right: 3, bottom: 2.5, left: 3 }
const MIN_TEXT = 2       // cm the margins always leave between them
const startBox = (k: SizeKey, story: number): Box => {
  const W = SIZES[k].w * CM, H = SIZES[k].h * CM
  const x = MARGINS.left * CM, y = MARGINS.top * CM
  return { id: newBoxId(), x, y, w: W - x - MARGINS.right * CM, h: H * 0.36, story, layer: 'clear' }
}
// margins that leave room on a page of this size
export function fitMargins(m: Margins, k: SizeKey): Margins {
  const across = Math.min(1, (SIZES[k].w - MIN_TEXT) / Math.max(m.left + m.right, 1e-6))
  const down = Math.min(1, (SIZES[k].h - MIN_TEXT) / Math.max(m.top + m.bottom, 1e-6))
  return { top: m.top * down, right: m.right * across, bottom: m.bottom * down, left: m.left * across }
}
export const marginLimit = (m: Margins, k: SizeKey, side: keyof Margins) => {
  const across = side === 'left' || side === 'right'
  const other = m[side === 'left' ? 'right' : side === 'right' ? 'left' : side === 'top' ? 'bottom' : 'top']
  return Math.max(0, +((across ? SIZES[k].w : SIZES[k].h) - MIN_TEXT - other).toFixed(2))
}
const EDGE = 0.5        // pt: a box this close to a margin is touching it
const MIN_W = 30, MIN_H = 20
// One axis of a margin change. An edge touching a margin follows it, an edge the new margin crosses is
// pushed in, and an edge you placed out in the margin stays where you put it.
function follow(lo: number, hi: number, size: number, from: [number, number], to: [number, number], least: number): [number, number] {
  const a = lo < from[0] - EDGE ? lo : Math.abs(lo - from[0]) <= EDGE ? to[0] : Math.max(lo, to[0])
  const b = hi > from[1] + EDGE ? hi : Math.abs(hi - from[1]) <= EDGE ? to[1] : Math.min(hi, to[1])
  const w = Math.max(least, b - a)
  return [Math.max(0, Math.min(a, size - w)), w]
}
export function followMargins(pages: Box[][], k: SizeKey, from: Margins, to: Margins): Box[][] {
  const W = SIZES[k].w * CM, H = SIZES[k].h * CM
  return pages.map((p) => p.map((b) => {
    const [x, w] = follow(b.x, b.x + b.w, W, [from.left * CM, W - from.right * CM], [to.left * CM, W - to.right * CM], MIN_W)
    const [y, h] = follow(b.y, b.y + b.h, H, [from.top * CM, H - from.bottom * CM], [to.top * CM, H - to.bottom * CM], MIN_H)
    return { ...b, x, y, w, h }
  }))
}
// a new paper size: what sat between the margins sits between them on the new page
export function resizeBoxes(pages: Box[][], a: SizeKey, m: Margins, b: SizeKey, n: Margins): Box[][] {
  const across = (SIZES[b].w - n.left - n.right) / (SIZES[a].w - m.left - m.right)
  const down = (SIZES[b].h - n.top - n.bottom) / (SIZES[a].h - m.top - m.bottom)
  const W = SIZES[b].w * CM, H = SIZES[b].h * CM
  return pages.map((p) => p.map((q) => {
    const w = Math.min(W, q.w * across), h = Math.min(H, q.h * down)
    const x = n.left * CM + (q.x - m.left * CM) * across, y = n.top * CM + (q.y - m.top * CM) * down
    return { ...q, x: Math.max(0, Math.min(W - w, x)), y: Math.max(0, Math.min(H - h, y)), w, h }
  }))
}
// a work saved before margins existed: read them off its boxes, so the boxes touch them
function marginsOf(pages: Box[][], W: number, H: number): Margins {
  const gap = (v: number) => +(Math.min(3, Math.max(0, v) / CM)).toFixed(2)
  const all = pages.flat()
  return {
    top: gap(Math.min(...all.map((b) => b.y))), right: gap(W - Math.max(...all.map((b) => b.x + b.w))),
    bottom: gap(H - Math.max(...all.map((b) => b.y + b.h))), left: gap(Math.min(...all.map((b) => b.x))),
  }
}
export const newDoc = (): Doc => {
  const id = newStoryId()
  return {
    stories: [{ id, doc: fromMarkdown(SAMPLE), auto: true }], sizeKey: 'insta', family: FAMILIES[0].css, fontSize: 26, seed: 3, cats: 2, pieces: 1.4,
    grows: 'gym', inkName: 'blue', crown: 'lush', season: 'summer', spanishmoss: false, heart: 'sometimes', perPage: 'new', textColor: TEXT_COLOR, margins: { ...MARGINS }, drawn: [[startBox('insta', id)]],
  }
}

const num = (v: unknown, lo: number, hi: number, fallback: number) => (typeof v === 'number' && Number.isFinite(v) ? Math.max(lo, Math.min(hi, v)) : fallback)
const oneOf = <T,>(v: unknown, options: readonly T[], fallback: T): T => (options.includes(v as T) ? (v as T) : fallback)
const LAYERS: readonly Layer[] = ['clear', 'over', 'behind']

export function checkDoc(raw: unknown): Doc {
  const o = (raw && typeof raw === 'object' ? raw : {}) as Record<string, unknown>
  const d = newDoc()
  const sizeKey = oneOf(o.sizeKey, Object.keys(SIZES) as SizeKey[], d.sizeKey)
  const W = SIZES[sizeKey].w * CM, H = SIZES[sizeKey].h * CM

  // stories get new ids, as boxes do, so neither can collide with any made since
  const stories: SavedStory[] = []
  const storyIds = new Map<unknown, number>()
  if (Array.isArray(o.stories)) for (const s of o.stories as Record<string, unknown>[]) {
    try {
      const doc = schema.nodeFromJSON(s.doc)
      doc.check()
      const id = newStoryId()
      storyIds.set(s.id, id)
      stories.push({ id, doc, auto: s.auto === true })
    } catch { /* a story that won't read is left out */ }
  } else if (typeof o.text === 'string') {
    // the first studio files: one text through every box
    const id = newStoryId()
    storyIds.set(undefined, id)
    stories.push({ id, doc: fromMarkdown(o.text), auto: true })
  }
  const drawn = Array.isArray(o.drawn) ? o.drawn.filter(Array.isArray).map((page: unknown[]) => page.flatMap((b): Box[] => {
    const q = (b && typeof b === 'object' ? b : {}) as Record<string, unknown>
    const box = { x: num(q.x, 0, W, -1), y: num(q.y, 0, H, -1), w: num(q.w, 1, W, -1), h: num(q.h, 1, H, -1) }
    if (box.x < 0 || box.y < 0 || box.w < 0 || box.h < 0) return []
    let story = storyIds.get(q.story)
    if (story === undefined) {
      story = newStoryId()
      storyIds.set(q.story ?? {}, story)
      stories.push({ id: story, doc: newStoryDoc(), auto: true })
    }
    return [{ ...box, id: newBoxId(), story, layer: oneOf(q.layer, LAYERS, 'clear') }]
  })) : []
  const anyBox = drawn.some((p) => p.length)
  const m = (o.margins && typeof o.margins === 'object' ? o.margins : null) as Record<string, unknown> | null
  const margins = !anyBox ? d.margins : m
    ? fitMargins({ top: num(m.top, 0, 50, 0), right: num(m.right, 0, 50, 0), bottom: num(m.bottom, 0, 50, 0), left: num(m.left, 0, 50, 0) }, sizeKey)
    : marginsOf(drawn, W, H)
  return {
    stories: anyBox ? stories : d.stories,
    sizeKey,
    family: oneOf(o.family, FAMILIES.map((f) => f.css), d.family),
    fontSize: num(o.fontSize, 10, 90, d.fontSize),
    seed: Math.round(num(o.seed, 1, 1e9, d.seed)),
    cats: Math.round(num(o.cats, 0, 6, d.cats)),
    pieces: num(o.pieces, 0.8, 2.5, d.pieces),
    grows: oneOf(o.grows, ['gym', 'oak', 'flowers', 'kelp'] as const, d.grows),   // a file with the old cats opens as a cat gym
    inkName: oneOf(o.inkName, ['green', 'blue'] as const, d.inkName),
    crown: oneOf(o.crown, ['lush', 'open'] as const, d.crown),
    season: oneOf(o.season, SEASONS, d.season),
    spanishmoss: o.spanishmoss === true,
    perPage: oneOf(o.perPage, ['new', 'match'] as const, d.perPage),
    heart: oneOf(o.heart, ['sometimes', 'never', 'always'] as const, d.heart),
    textColor: typeof o.textColor === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.textColor) ? o.textColor : d.textColor,
    margins,
    drawn: anyBox ? drawn : d.drawn,
  }
}

const KEY = 'florilegium-studio'
const toJson = (d: Doc) => ({ ...d, stories: d.stories.map((s) => ({ id: s.id, auto: s.auto, doc: s.doc.toJSON() })) })
export function loadDoc(): Doc {
  try {
    const saved = localStorage.getItem(KEY)
    if (saved) return checkDoc(JSON.parse(saved))
  } catch { /* unreadable: start fresh */ }
  return newDoc()
}
export const saveDoc = (d: Doc) => localStorage.setItem(KEY, JSON.stringify(toJson(d)))
export const docFile = (d: Doc) => new Blob([JSON.stringify({ studio: 2, ...toJson(d) }, null, 1)], { type: 'application/json' })
export function readDocFile(text: string): Doc {
  const raw = JSON.parse(text)
  if (!raw || (raw.studio !== 1 && raw.studio !== 2)) throw new Error('that is not a studio file')
  return checkDoc(raw)
}

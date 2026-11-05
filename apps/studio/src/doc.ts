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
export const SEASONS = ['spring', 'summer', 'autumn', 'winter', 'dead'] as const
export type Season = typeof SEASONS[number]
export type Grows = 'gym' | 'oak' | 'cats'
export const TEXT_COLOR = '#1b2a6b'
export type SavedStory = { id: number; doc: Node; auto: boolean }
export type Doc = {
  stories: SavedStory[]; sizeKey: SizeKey; family: string; fontSize: number; seed: number; cats: number; pieces: number
  grows: Grows; inkName: 'green' | 'blue'; crown: 'lush' | 'open'; season: Season; spanishmoss: boolean; textColor: string; drawn: Box[][]
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
const startBox = (k: SizeKey, story: number): Box => {
  const W = SIZES[k].w * CM, H = SIZES[k].h * CM
  return { id: newBoxId(), x: W * 0.14, y: H * 0.1, w: W * 0.72, h: H * 0.36, story, layer: 'clear' }
}
export const newDoc = (): Doc => {
  const id = newStoryId()
  return {
    stories: [{ id, doc: fromMarkdown(SAMPLE), auto: true }], sizeKey: 'insta', family: FAMILIES[0].css, fontSize: 26, seed: 3, cats: 2, pieces: 1.4,
    grows: 'gym', inkName: 'blue', crown: 'lush', season: 'summer', spanishmoss: false, textColor: TEXT_COLOR, drawn: [[startBox('insta', id)]],
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
      stories.push({ id: story, doc: newStoryDoc(), auto: false })
    }
    return [{ ...box, id: newBoxId(), story, layer: oneOf(q.layer, LAYERS, 'clear') }]
  })) : []
  const anyBox = drawn.some((p) => p.length)
  return {
    stories: anyBox ? stories : d.stories,
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
    textColor: typeof o.textColor === 'string' && /^#[0-9a-fA-F]{6}$/.test(o.textColor) ? o.textColor : d.textColor,
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

// flow.ts -- every story through its boxes with Pretext. A story's boxes are read in page order, each
// line asked for at its box's width; what outgrows the last box goes on to new pages if the story
// asks for that, and otherwise runs past the box's foot, marked, so no text is ever lost. Each piece
// of a line knows its place in the story, which is what the cursor stands on.
import { clearCache } from '@chenglou/pretext'
import { layoutNextRichInlineLineRange, materializeRichInlineLineRange, prepareRichInline, type PreparedRichInline, type RichInlineCursor } from '@chenglou/pretext/rich-inline'
import type { Node } from 'prosemirror-model'
import { schema, type Align, type ListKind } from './schema'

export type Layer = 'clear' | 'over' | 'behind'
export type Box = { id: number; x: number; y: number; w: number; h: number; story: number; layer: Layer }   // bp, y down
export type Tag = 'h1' | 'h2' | 'h3' | 'p'
export type Look = { bold: boolean; italic: boolean }
// from, to: the run's text in the story; -1 for a list's bullet or number, which is not in the text
export type Run = Look & { text: string; x: number; w: number; gap: boolean; from: number; to: number }
export type Line = {
  x: number; y: number; top: number; lh: number; size: number; tag: Tag; block: number; runs: Run[]
  story: number; box: number; page: number; layer: Layer; list: ListKind; from: number; to: number; originX: number; wordSpacing: number; lastOfBlock: boolean
}
export type FlowPage = { boxes: Box[]; lines: Line[]; used: Map<number, number>; auto: boolean; over: Set<number> }
export type TextStyle = { family: string; size: number; leading: number; color: string; headingBold: boolean }
export type StoryText = { id: number; doc: Node; auto: boolean }
export type Flowed = { pages: FlowPage[]; overflow: boolean; byStory: Map<number, Line[]> }

export const SCALE: Record<Tag, number> = { h1: 1.7, h2: 1.3, h3: 1.1, p: 1 }
export const fontOf = (s: Look, size: number, family: string) =>
  `${s.italic ? 'italic ' : ''}${s.bold ? 'bold ' : ''}${size}px ${family}`
const MAX_PAGES = 40
const INDENT = 1.3                                     // a list's indent, in ems

const ctx = document.createElement('canvas').getContext('2d')!
export function measure(text: string, look: Look, size: number, family: string): number {
  ctx.font = fontOf(look, size, family)
  return ctx.measureText(text).width
}

type Item = Look & { text: string }
type Prepared = { prep: PreparedRichInline | null; items: Item[]; text: string }
let cache = new WeakMap<Node, Map<string, Prepared>>()
export function remeasure() {                          // the web fonts have arrived
  clearCache()
  cache = new WeakMap()
}
const tagOf = (b: Node): Tag => (b.type === schema.nodes.heading ? (`h${b.attrs.level}` as Tag) : 'p')
function prepared(b: Node, style: TextStyle): Prepared {
  const key = `${style.size}|${style.family}|${style.headingBold}`
  let forNode = cache.get(b)
  if (!forNode) cache.set(b, (forNode = new Map()))
  let p = forNode.get(key)
  if (!p) {
    const size = style.size * SCALE[tagOf(b)]
    const heading = tagOf(b) !== 'p' && style.headingBold
    const items: Item[] = []
    b.forEach((t) => items.push({ text: t.text ?? '', bold: heading || !!schema.marks.bold.isInSet(t.marks), italic: !!schema.marks.italic.isInSet(t.marks) }))
    p = {
      items, text: b.textContent,
      prep: items.length ? prepareRichInline(items.map((s) => ({ text: s.text, font: fontOf(s, size, style.family) })), { whiteSpace: 'pre-wrap' }) : null,
    }
    forNode.set(key, p)
  }
  return p
}

// a chain's boxes on the pages that follow, so a long post keeps going
const cloneId = (page: number, id: number) => -(page * 100000 + Math.abs(id) % 100000)

export function flow(stories: StoryText[], drawn: Box[][], style: TextStyle): Flowed {
  const pages: FlowPage[] = drawn.map((boxes) => ({ boxes, lines: [], used: new Map(), auto: false, over: new Set() }))
  const pageAt = (i: number) => {
    while (pages.length <= i) pages.push({ boxes: [], lines: [], used: new Map(), auto: true, over: new Set() })
    return pages[i]
  }
  const bodyLh = style.size * style.leading
  const byStory = new Map<number, Line[]>()
  let overflow = false
  for (const story of stories) {
    const lines: Line[] = []
    byStory.set(story.id, lines)
    const chain: { page: number; box: Box }[] = []
    // a box still being drawn takes no text until it could hold some, or it would chop a line of the story into letters
    drawn.forEach((boxes, page) => boxes.forEach((box) => { if (box.story === story.id && box.w >= 30 && box.h >= 20) chain.push({ page, box }) }))
    if (!chain.length) continue
    const blocks: { node: Node; start: number; number: number }[] = []
    let number = 0
    story.doc.forEach((node, offset) => {
      number = node.attrs.list === 'ordered' ? number + 1 : 0
      blocks.push({ node, start: offset + 1, number })
    })
    let at = 0
    let cursor: RichInlineCursor | undefined
    let off = 0                                        // how far into the block's text
    const lhOf = (b: Node) => style.size * SCALE[tagOf(b)] * style.leading
    let extra = drawn.length
    for (let c = 0; c < chain.length && at < blocks.length; c++) {
      const { page, box: b } = chain[c]
      let last = c === chain.length - 1
      // the last box of a chain that may add pages hands on when it is full
      const addsPages = last && story.auto && extra < MAX_PAGES && b.h >= lhOf(blocks[at].node)
      if (addsPages) last = false
      const fp = pageAt(page)
      let y = 0
      while (at < blocks.length) {
        const { node, start, number: num } = blocks[at]
        const tag = tagOf(node)
        const size = style.size * SCALE[tag]
        const lh = lhOf(node)
        const list = (node.attrs.list ?? null) as ListKind
        const indent = list ? size * INDENT : 0
        const width = Math.max(b.w - indent, size)
        const fresh = cursor === undefined
        const before = at > 0 ? blocks[at - 1].node : null
        const gap = !fresh || y === 0 || !before ? 0
          : tag !== 'p' ? 0.6 * bodyLh
          : tagOf(before) !== 'p' ? 0.15 * bodyLh
          : list && before.attrs.list ? 0.1 * bodyLh
          : 0.5 * bodyLh
        const P = prepared(node, style)
        if (!last && fresh && tag !== 'p' && y > 0 && P.prep) {
          // a heading stays with the line after it
          let count = 0
          for (let q: RichInlineCursor | undefined, l; (l = layoutNextRichInlineLineRange(P.prep, width, q)); q = l.end) count++
          const next = blocks[at + 1]?.node
          if (y + gap + count * lh + (next ? lhOf(next) : 0) > b.h + 0.01) break
        }
        if (!last && y + gap + lh > b.h + 0.01 && !(addsPages && y === 0)) break
        y += gap
        const line = placeLine(P, node, start, cursor, width, b, page, y, size, lh, tag, list, num, indent, at, story.id, style, off)
        lines.push(line.line)
        fp.lines.push(line.line)
        off = line.off
        cursor = line.end
        y += lh
        if (line.done) { at++; cursor = undefined; off = 0 }
      }
      fp.used.set(b.id, y)
      if (y > b.h + 0.01 && at >= blocks.length) { fp.over.add(b.id); overflow = true }
      if (addsPages && at < blocks.length) {
        const pg = extra++
        const clone = { ...b, id: cloneId(pg, chain[0].box.id) }
        pageAt(pg).boxes.push(clone)
        chain.push({ page: pg, box: clone })
      }
    }
  }
  return { pages, overflow, byStory }
}

function placeLine(P: Prepared, node: Node, start: number, cursor: RichInlineCursor | undefined, width: number, b: Box, page: number, y: number, size: number, lh: number, tag: Tag, list: ListKind, num: number, indent: number, block: number, story: number, style: TextStyle, off0: number) {
  const align = node.attrs.align as Align
  const left = b.x + indent
  const base = { top: b.y + y, lh, size, tag, block, story, box: b.id, page, layer: b.layer, list, x: b.x, y: b.y + y + size }
  const marker = (): Run[] => {
    if (!list || cursor !== undefined) return []    // only a list item's first line
    const text = list === 'bullet' ? '•' : `${num}.`
    const w = measure(text, { bold: false, italic: false }, size, style.family)
    return [{ text, bold: false, italic: false, x: left - w - size * 0.35, w, gap: false, from: -1, to: -1 }]
  }
  if (!P.prep) {
    const originX = align === 'center' ? left + width / 2 : align === 'right' ? left + width : left
    return { line: { ...base, runs: marker(), from: start, to: start, originX, wordSpacing: 0, lastOfBlock: true } as Line, off: 0, end: undefined, done: true }
  }
  const range = layoutNextRichInlineLineRange(P.prep, width, cursor)!
  const line = materializeRichInlineLineRange(P.prep, range)
  const done = layoutNextRichInlineLineRange(P.prep, width, range.end) === null
  let off = off0
  let x = left
  let runs: Run[] = line.fragments.map((f) => {
    x += f.gapBefore
    const item = P.items[f.itemIndex]
    let idx = P.text.indexOf(f.text, off)
    if (idx < 0) idx = off
    const run: Run = { text: f.text, bold: item.bold, italic: item.italic, x, w: f.occupiedWidth, gap: f.gapBefore > 0, from: start + idx, to: start + idx + f.text.length }
    off = idx + f.text.length
    x += f.occupiedWidth
    return run
  })
  // what's taken up, leaving out the spaces a wrapped line hangs past its edge
  const measureRun = (r: Run, t: string) => measure(t, r, size, style.family)
  const lastRun = runs[runs.length - 1]
  let used = 0
  if (lastRun) {
    const trimmed = lastRun.text.replace(/\s+$/, '')
    used = lastRun.x + measureRun(lastRun, trimmed) - left
  }
  let wordSpacing = 0
  let originX = left
  if (align === 'center' || align === 'right') {
    const shift = Math.max(0, (width - used) / (align === 'center' ? 2 : 1))
    originX += shift
    runs = runs.map((r) => ({ ...r, x: r.x + shift }))
  } else if (align === 'justify' && !done && lastRun) {
    type Tok = Look & { text: string; from: number; space: boolean }
    const toks: Tok[] = []
    let pendingSpace = false
    for (const r of runs) {
      const re = /\S+/g
      let m: RegExpExecArray | null
      let cur = 0
      while ((m = re.exec(r.text))) {
        toks.push({ text: m[0], bold: r.bold, italic: r.italic, from: r.from + m.index, space: pendingSpace || m.index > cur })
        pendingSpace = false
        cur = m.index + m[0].length
      }
      if (cur < r.text.length) pendingSpace = true
    }
    const gaps = toks.filter((t, i) => i > 0 && t.space).length
    if (gaps > 0) {
      const widths = toks.map((t) => measure(t.text, t, size, style.family))
      const total = widths.reduce((a, c) => a + c, 0)
      const g = (width - total) / gaps
      wordSpacing = g - measure(' ', { bold: false, italic: false }, size, style.family)
      let cx = left
      runs = toks.map((t, i) => {
        if (i > 0 && t.space) cx += g
        const r: Run = { text: t.text, bold: t.bold, italic: t.italic, x: cx, w: widths[i], gap: i > 0 && t.space, from: t.from, to: t.from + t.text.length }
        cx += widths[i]
        return r
      })
    }
  }
  const from = runs.length ? runs[0].from : start
  const to = done ? start + P.text.length : start + off
  return { line: { ...base, runs: [...marker(), ...runs], from, to, originX, wordSpacing, lastOfBlock: done } as Line, off, end: range.end as RichInlineCursor | undefined, done }
}

// where a position in the story stands: its line and the x on it
export function lineOfPos(lines: Line[], pos: number): Line | null {
  let found: Line | null = null
  for (const l of lines) { if (l.from <= pos) found = l; else break }
  return found ?? lines[0] ?? null
}
export function xOfPos(l: Line, pos: number, style: TextStyle): number {
  const runs = l.runs.filter((r) => r.from >= 0)
  if (!runs.length) return l.originX
  for (const r of runs) {
    if (pos <= r.from) return r.x
    if (pos <= r.to) return r.x + measure(r.text.slice(0, pos - r.from), r, l.size, style.family)
  }
  const e = runs[runs.length - 1]
  return e.x + measure(e.text, e, l.size, style.family)
}
const segmenter = new Intl.Segmenter(undefined, { granularity: 'grapheme' })
// the position nearest an x on a line
export function posOfX(l: Line, x: number, style: TextStyle): number {
  const runs = l.runs.filter((r) => r.from >= 0)
  if (!runs.length) return l.from
  let best = runs[0].from
  let bestD = Infinity
  for (const r of runs) {
    const cuts = [0, ...[...segmenter.segment(r.text)].map((s) => s.index + s.segment.length)]
    for (const c of cuts) {
      const d = Math.abs(r.x + measure(r.text.slice(0, c), r, l.size, style.family) - x)
      if (d < bestD) { bestD = d; best = r.from + c }
    }
  }
  // past a wrapped line's end stays on this line, before the space it hangs
  if (!l.lastOfBlock && best >= l.to) {
    const e = runs[runs.length - 1]
    best = /\s$/.test(e.text) ? e.to - 1 : e.to - 1
  }
  return best
}

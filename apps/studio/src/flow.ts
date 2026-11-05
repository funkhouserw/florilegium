// flow.ts -- the post through the text boxes, page after page, with Pretext. The post is a little
// Markdown: "# " and "## " start a heading, **bold**, *italic*, a backslash keeps an asterisk.
import { layoutNextRichInlineLineRange, materializeRichInlineLineRange, prepareRichInline, type PreparedRichInline, type RichInlineCursor } from '@chenglou/pretext/rich-inline'

export type Box = { id: number; x: number; y: number; w: number; h: number }   // bp, y down
export type Tag = 'h1' | 'h2' | 'p'
export type Span = { text: string; bold: boolean; italic: boolean }
export type Run = Span & { x: number; w: number; gap: boolean }                // gap: a space before it
export type Line = { x: number; y: number; size: number; tag: Tag; block: number; runs: Run[] }
export type FlowPage = { boxes: Box[]; lines: Line[]; used: Map<number, number>; auto: boolean }
export type TextStyle = { family: string; size: number; leading: number; color: string; headingBold: boolean }
export type Block = { tag: Tag; spans: Span[]; blanks: number }

export const SCALE: Record<Tag, number> = { h1: 1.7, h2: 1.3, p: 1 }
export const fontOf = (s: Pick<Span, 'bold' | 'italic'>, size: number, family: string) =>
  `${s.italic ? 'italic ' : ''}${s.bold ? 'bold ' : ''}${size}px ${family}`
const MAX_PAGES = 40
const STAR = ''                                  // an escaped asterisk, while the markers are read
const MARK = /(\*\*\*|\*\*|\*)(?=\S)(.+?)(?<=\S)\1/

function spansOf(text: string, bold: boolean, italic: boolean): Span[] {
  const out: Span[] = []
  let rest = text
  while (rest) {
    const m = MARK.exec(rest)
    if (!m) { out.push({ text: rest, bold, italic }); break }
    if (m.index > 0) out.push({ text: rest.slice(0, m.index), bold, italic })
    const n = m[1].length
    out.push(...spansOf(m[2], bold || n >= 2, italic || n !== 2))
    rest = rest.slice(m.index + m[0].length)
  }
  return out
}

export function parse(text: string, headingBold: boolean): Block[] {
  const blocks: Block[] = []
  let blanks = 0
  for (const raw of text.split(/\r?\n/)) {
    const source = raw.replace(/\\\*/g, STAR).trim()
    if (!source) { blanks++; continue }
    const h = /^(#{1,2})\s+(?=\S)/.exec(source)
    const tag: Tag = h ? (h[1].length === 1 ? 'h1' : 'h2') : 'p'
    const spans = spansOf(h ? source.slice(h[0].length) : source, !!h && headingBold, false)
      .map((s) => ({ ...s, text: s.text.split(STAR).join('*') }))
    blocks.push({ tag, spans, blanks })
    blanks = 0
  }
  return blocks
}

export const plainText = (b: Block) => b.spans.map((s) => s.text).join('')
const atStart = (c: RichInlineCursor | undefined) => c === undefined

// Fill each box in order; what does not fit goes to the next box, then the next page. When the
// drawn pages run out, more follow with the last page's boxes. lost: text that found no room.
export function flow(blocks: Block[], drawn: Box[][], style: TextStyle): { pages: FlowPage[]; lost: boolean } {
  const prepared: PreparedRichInline[] = blocks.map((b) => prepareRichInline(
    b.spans.map((s) => ({ text: s.text, font: fontOf(s, style.size * SCALE[b.tag], style.family) })),
    { whiteSpace: 'normal' },
  ))
  const lhOf = (b: Block) => style.size * SCALE[b.tag] * style.leading
  const bodyLh = style.size * style.leading
  let at = 0
  let cursor: RichInlineCursor | undefined
  const pages: FlowPage[] = []
  for (let i = 0; i < MAX_PAGES; i++) {
    if (i >= drawn.length && at >= blocks.length) break
    const auto = i >= drawn.length
    const boxes = auto ? drawn[drawn.length - 1] ?? [] : drawn[i]
    if (auto && boxes.every((b) => b.h < lhOf(blocks[at]))) break   // nowhere to put the rest
    const page: FlowPage = { boxes, lines: [], used: new Map(), auto }
    for (const b of boxes) {
      const width = (size: number) => Math.max(b.w, size)
      let y = 0
      while (at < blocks.length) {
        const block = blocks[at]
        const size = style.size * SCALE[block.tag]
        const lh = lhOf(block)
        const fresh = atStart(cursor)
        // the space above a block: nothing at the top of a box
        const gap = fresh && y > 0 ? Math.max(block.blanks * 0.6, block.tag === 'p' ? 0 : 0.5) * bodyLh : 0
        if (fresh && block.tag !== 'p' && y > 0) {
          // a heading stays with the line after it
          let count = 0
          for (let c: RichInlineCursor | undefined, l; (l = layoutNextRichInlineLineRange(prepared[at], width(size), c)); c = l.end) count++
          const next = blocks[at + 1]
          if (y + gap + count * lh + (next ? lhOf(next) : 0) > b.h + 0.01) break
        }
        if (y + gap + lh > b.h + 0.01) break
        const range = layoutNextRichInlineLineRange(prepared[at], width(size), cursor)
        if (range === null) { at++; cursor = undefined; continue }
        y += gap
        const line = materializeRichInlineLineRange(prepared[at], range)
        let x = b.x
        const runs: Run[] = line.fragments.map((f) => {
          x += f.gapBefore
          const s = block.spans[f.itemIndex]
          const run = { text: f.text, bold: s.bold, italic: s.italic, x, w: f.occupiedWidth, gap: f.gapBefore > 0 }
          x += f.occupiedWidth
          return run
        })
        page.lines.push({ x: b.x, y: b.y + y + size, size, tag: block.tag, block: at, runs })
        cursor = line.end
        y += lh
        if (layoutNextRichInlineLineRange(prepared[at], width(size), cursor) === null) { at++; cursor = undefined }
      }
      page.used.set(b.id, y)
    }
    pages.push(page)
  }
  return { pages, lost: at < blocks.length }
}

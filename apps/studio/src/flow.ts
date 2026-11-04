// flow.ts -- the post through the text boxes, page after page, with Pretext.
import { layoutNextLine, prepareWithSegments, type LayoutCursor } from '@chenglou/pretext'

export type Box = { id: number; x: number; y: number; w: number; h: number }   // bp, y down
export type Line = { text: string; x: number; y: number }
export type FlowPage = { boxes: Box[]; lines: Line[]; used: Map<number, number>; auto: boolean }
export type TextStyle = { family: string; size: number; leading: number; color: string }

export const fontOf = (s: TextStyle) => `${s.size}px ${s.family}`
const MAX_PAGES = 40

// Fill each box in order; what does not fit goes to the next box, then the next page. When
// the drawn pages run out, more follow with the last page's boxes.
export function flow(text: string, drawn: Box[][], style: TextStyle): FlowPage[] {
  const prepared = prepareWithSegments(text, fontOf(style), { whiteSpace: 'pre-wrap' })
  const lh = style.size * style.leading
  let cursor: LayoutCursor = { segmentIndex: 0, graphemeIndex: 0 }
  let done = text.trim() === ''
  const pages: FlowPage[] = []
  for (let i = 0; i < MAX_PAGES; i++) {
    if (i >= drawn.length && done) break
    const auto = i >= drawn.length
    const boxes = auto ? drawn[drawn.length - 1] ?? [] : drawn[i]
    if (auto && boxes.every((b) => b.h < lh)) break            // nowhere to put the rest
    const page: FlowPage = { boxes, lines: [], used: new Map(), auto }
    for (const b of boxes) {
      let y = 0
      while (!done && y + lh <= b.h + 0.01) {
        const line = layoutNextLine(prepared, Math.max(b.w, style.size), cursor)
        if (line === null) { done = true; break }
        page.lines.push({ text: line.text, x: b.x, y: b.y + y + style.size })
        cursor = line.end
        y += lh
      }
      page.used.set(b.id, y)
    }
    if (!done && layoutNextLine(prepared, style.size * 2, cursor) === null) done = true   // it ended exactly at a box's foot
    pages.push(page)
  }
  return pages
}

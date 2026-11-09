// exporter.ts -- finished pages: a PNG; a PDF, the drawing as vector operators and the text as real
// text in embedded fonts, so it can be selected and printed; and one self-contained HTML file.
import fontkit from '@pdf-lib/fontkit'
import { PDFDocument, PDFName, popGraphicsState, pushGraphicsState, rgb, setLineWidth, setStrokingColor, setTextRenderingMode, TextRenderingMode, type PDFFont, type PDFImage } from 'pdf-lib'
import { fontOf, measure, type Cap, type FlowPage, type Line, type Run, type TextStyle } from './flow'
import { faceOf, type Family } from './fonts'

// a page's initials: each its tile as an SVG (or, for the PDF, as PDF operators in its own bp, y up)
export type CapArt = { cap: Cap; svg?: string }
async function svgImage(svg: string, width: number, height: number): Promise<HTMLImageElement> {
  const sized = svg.replace(/<svg\b[^>]*>/, (tag) => tag.replace(/\swidth="[^"]*"/, ` width="${width}"`).replace(/\sheight="[^"]*"/, ` height="${height}"`))
  const url = URL.createObjectURL(new Blob([sized], { type: 'image/svg+xml' }))
  try {
    const img = new Image(width, height)
    img.src = url
    await img.decode()
    return img
  } finally { URL.revokeObjectURL(url) }
}

// The gym as an image, the text on the canvas: an SVG in an <img> can't see the page's web fonts.
export async function pagePng(gym: string, page: FlowPage, style: TextStyle, pixelWidth: number, W: number, H: number, paper: string, caps: CapArt[] = []): Promise<Blob> {
  const width = pixelWidth, height = Math.round(pixelWidth * H / W)
  // the drawing's own size set to the canvas's: Safari rasterizes an SVG image at its stated size, then scales it
  const sized = gym.replace(/<svg\b[^>]*>/, (tag) => tag.replace(/\swidth="[^"]*"/, ` width="${width}"`).replace(/\sheight="[^"]*"/, ` height="${height}"`))
  const url = URL.createObjectURL(new Blob([sized], { type: 'image/svg+xml' }))
  try {
    const img = new Image(width, height)
    img.src = url
    await img.decode()
    const canvas = document.createElement('canvas')
    canvas.width = width
    canvas.height = height
    const c = canvas.getContext('2d')!
    c.fillStyle = paper
    c.fillRect(0, 0, canvas.width, canvas.height)
    const write = (lines: Line[]) => {
      c.save()
      c.scale(canvas.width / W, canvas.height / H)
      c.fillStyle = style.color
      for (const l of lines) for (const r of l.runs) {
        c.font = fontOf(r, l.size, style.family)
        c.fillText(r.text, r.x, l.y)
      }
      c.restore()
    }
    write(page.lines.filter((l) => l.layer === 'behind'))
    c.drawImage(img, 0, 0, canvas.width, canvas.height)
    const k = canvas.width / W
    for (const { cap, svg } of caps) {
      if (!svg) continue
      const side = Math.max(1, Math.round(cap.side * k))
      c.drawImage(await svgImage(svg, side, side), cap.x * k, cap.y * k, side, side)
    }
    write(page.lines.filter((l) => l.layer !== 'behind'))
    return await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('no PNG'))), 'image/png'))
  } finally { URL.revokeObjectURL(url) }
}

// A PDF can't hold color emoji as text and these fonts have none, so each is drawn by the browser
// and placed as a small image at the position it has on the page.
const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' })
const EMOJI = /\p{Extended_Pictographic}|\p{Regional_Indicator}|\u20E3/u
function emojiPng(g: string): Promise<ArrayBuffer> {
  const canvas = document.createElement('canvas')
  canvas.width = canvas.height = EMOJI_PX * 2
  const c = canvas.getContext('2d')!
  c.font = `${EMOJI_PX}px serif`
  c.textBaseline = 'alphabetic'
  c.fillText(g, EMOJI_PX * 0.5, EMOJI_PX * 1.25)
  return new Promise((res, rej) => canvas.toBlob((b) => (b ? res(b.arrayBuffer()) : rej(new Error('no emoji'))), 'image/png'))
}
const EMOJI_PX = 128
// a run's text cut where emoji start and stop, each piece with its x
function pieces(r: Run, size: number, family: string): { text: string; x: number; emoji: boolean }[] {
  const out: { text: string; x: number; emoji: boolean }[] = []
  let at = 0
  for (const s of graphemes.segment(r.text)) {
    const emoji = EMOJI.test(s.segment)
    const last = out[out.length - 1]
    if (last && !last.emoji && !emoji) last.text += s.segment
    else out.push({ text: s.segment, x: r.x + measure(r.text.slice(0, at), r, size, family), emoji })
    at = s.index + s.segment.length
  }
  return out
}

const hexColor = (h: string) => rgb(parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255)

// ops: one page's drawing from florilegium-ink.lua, which names its opacity and multiply states
// /floaNN and /flomNN (NN percent); TeX declares them for LuaLaTeX, this does here.
export async function pagesToPdf(pages: FlowPage[], ops: string[], style: TextStyle, family: Family, W: number, H: number, title: string, caps: CapArt[][] = []): Promise<{ pdf: Blob; missing: string[] }> {
  if (!family.files) throw new Error(`${family.label} can't be embedded`)
  const files = family.files
  const pdf = await PDFDocument.create()
  pdf.registerFontkit(fontkit)
  const fonts = new Map<string, { font: PDFFont; known: Set<number> }>()
  for (const l of pages.flatMap((p) => p.lines)) for (const r of l.runs) {
    const { file } = faceOf(files, r.bold, r.italic)
    if (fonts.has(file)) continue
    const bytes = await (await fetch(`fonts/${file}.ttf`)).arrayBuffer()
    const font = await pdf.embedFont(bytes, { subset: true })
    fonts.set(file, { font, known: new Set(font.getCharacterSet()) })
  }
  const missing = new Set<string>()
  const emojiImages = new Map<string, PDFImage>()
  for (const l of pages.flatMap((p) => p.lines)) for (const r of l.runs) for (const q of pieces(r, l.size, style.family)) {
    if (q.emoji && !emojiImages.has(q.text)) emojiImages.set(q.text, await pdf.embedPng(await emojiPng(q.text)))
  }
  if (title) pdf.setTitle(title)
  const color = hexColor(style.color)
  pages.forEach((p, i) => {
    const page = pdf.addPage([W, H])
    // the initials, each a tile `side` bp square, its operators moved to where the tile's foot is
    const drawing = [ops[i], ...(caps[i] ?? []).filter((c) => c.svg).map(({ cap, svg }) =>
      `q 1 0 0 1 ${cap.x.toFixed(2)} ${(H - cap.y - cap.side).toFixed(2)} cm\n${svg}\nQ`)].join('\n')
    const states: Record<string, unknown> = {}
    for (const m of drawing.matchAll(/\/flo([am])(\d+) gs/g)) {
      const op = +m[2] / 100
      states[`flo${m[1]}${m[2]}`] = { Type: 'ExtGState', ca: op, CA: op, ...(m[1] === 'm' ? { BM: 'Multiply' } : {}) }
    }
    page.node.normalizedEntries().Resources.set(PDFName.of('ExtGState'), pdf.context.obj(states as never))
    const write = (lines: Line[]) => {
      for (const l of lines) for (const r of l.runs) {
        const face = faceOf(files, r.bold, r.italic)
        const { font, known } = fonts.get(face.file)!
        for (const q of pieces(r, l.size, style.family)) {
          if (q.emoji) {
            // the image is twice the emoji's size, with its baseline 1.25 emoji down from the top
            const side = l.size * 2
            page.drawImage(emojiImages.get(q.text)!, { x: q.x - l.size * 0.5, y: H - l.y - l.size * 0.75, width: side, height: side })
            continue
          }
          for (const ch of q.text) if (ch.trim() && !known.has(ch.codePointAt(0)!)) missing.add(ch)
          if (!q.text.trim()) continue
          // text state set outside the text object carries into it: fill and outline, a face made heavier
          if (face.heavier) page.pushOperators(pushGraphicsState(), setTextRenderingMode(TextRenderingMode.FillAndOutline), setLineWidth(l.size * 0.02), setStrokingColor(color))
          page.drawText(q.text, { x: q.x, y: H - l.y, size: l.size, font, color })
          if (face.heavier) page.pushOperators(popGraphicsState())
        }
      }
    }
    write(p.lines.filter((l) => l.layer === 'behind'))
    page.node.addContentStream(pdf.context.register(pdf.context.flateStream(drawing)))
    // pdf-lib writes into the stream it last made: without this the rest would land under the drawing
    ;(page as unknown as { contentStream?: unknown }).contentStream = undefined
    write(p.lines.filter((l) => l.layer !== 'behind'))
  })
  return { pdf: new Blob([await pdf.save()], { type: 'application/pdf' }), missing: [...missing] }
}

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;')
const dataUrl = (blob: Blob) => new Promise<string>((res, rej) => {
  const r = new FileReader()
  r.onload = () => res(r.result as string)
  r.onerror = () => rej(r.error)
  r.readAsDataURL(blob)
})

// How far the top of a line's box (line-height 1) sits above its baseline, in em: CSS has no way to
// place text by its baseline, and the pages must keep the lines where the studio put them.
function baselineOf(family: string): number {
  const c = document.createElement('canvas').getContext('2d')!
  c.font = `100px ${family}`
  const m = c.measureText('x')
  const a = m.fontBoundingBoxAscent / 100, d = m.fontBoundingBoxDescent / 100
  return (1 - (a + d)) / 2 + a
}

// One file with everything in it: the pages' drawings as SVG images, the fonts, and the text as
// headings and paragraphs a reader can select, search, translate or hear. Each line stays where the
// studio broke it, in units of the page's width, so a page keeps its layout at any size; it prints a
// page to a sheet.
export async function pagesToHtml(pages: FlowPage[], gyms: string[], style: TextStyle, family: Family, W: number, H: number, title: string, paper: string, caps: CapArt[][] = []): Promise<Blob> {
  const cq = (v: number) => `${+(v / W * 100).toFixed(3)}cqw`
  const top = baselineOf(style.family)
  const faces = new Map<string, ReturnType<typeof faceOf>>()
  if (family.files) for (const l of pages.flatMap((p) => p.lines)) for (const r of l.runs) {
    const f = faceOf(family.files, r.bold, r.italic)
    faces.set(f.file, f)
  }
  const familyName = style.family.split(',')[0].replace(/"/g, '')
  const fontCss: string[] = []
  for (const f of faces.values()) {
    const blob = await (await fetch(`fonts/${f.file}.woff2`)).blob()
    fontCss.push(`@font-face{font-family:"${familyName}";font-weight:${f.weight};font-style:${f.style};src:url("${(await dataUrl(blob)).replace(/^data:[^;]*/, 'data:font/woff2')}") format("woff2")}`)
  }
  const lineHtml = (l: Line) => {
    const first = l.runs.find((r) => r.from >= 0)
    const leftOf = first ? first.x : l.originX
    const runs = l.runs.map((r) => {
      let t = (r.gap ? ' ' : '') + esc(r.text)
      if (r.from < 0) return `<i class="m" aria-hidden="true" style="left:${cq(r.x - leftOf)}">${t}</i>`
      if (r.italic) t = `<em>${t}</em>`
      if (r.bold) t = `<strong>${t}</strong>`
      return t
    }).join('')
    const spacing = l.wordSpacing ? `;word-spacing:${cq(l.wordSpacing)}` : ''
    return `<span style="left:${cq(leftOf)};top:${cq(l.y - l.size * top)};font-size:${cq(l.size)}${spacing}">${runs}</span>`
  }
  const blocksOf = (lines: Line[]) => {
    const out: string[] = []
    let open = ''
    let tag = ''
    let list: string | null = null
    const closeBlock = () => { if (tag) out.push(`</${tag}>`); tag = '' }
    const closeList = () => { if (list) out.push(`</${list}>`); list = null }
    for (const l of lines) {
      const key = `${l.story}.${l.block}`
      if (key !== open) {
        closeBlock()
        const want = l.list === 'bullet' ? 'ul' : l.list === 'ordered' ? 'ol' : null
        if (want !== list) { closeList(); if (want) { list = want; out.push(`<${want}>`) } }
        open = key
        tag = l.list ? 'li' : l.tag
        out.push(`<${tag}>`)
      }
      out.push(lineHtml(l))
    }
    closeBlock()
    closeList()
    return out.join('\n')
  }
  const body: string[] = []
  for (let i = 0; i < pages.length; i++) {
    const image = await dataUrl(new Blob([gyms[i]], { type: 'image/svg+xml' }))
    // later in the file paints on top: text behind the drawing comes before its image
    const under = blocksOf(pages[i].lines.filter((l) => l.layer === 'behind'))
    const above = blocksOf(pages[i].lines.filter((l) => l.layer !== 'behind'))
    const initials: string[] = []
    for (const { cap, svg } of caps[i] ?? []) {
      if (!svg) continue
      const src = await dataUrl(new Blob([svg], { type: 'image/svg+xml' }))
      initials.push(`<img class="initial" src="${src}" alt="${esc(cap.letter)}" style="left:${cq(cap.x)};top:${cq(cap.y)};width:${cq(cap.side)};height:${cq(cap.side)}">`)
    }
    body.push(`<section class="page" aria-label="Page ${i + 1}">\n${under}\n<img src="${image}" alt="" decoding="async">\n${initials.join('\n')}\n${above}\n</section>`)
  }
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(title)}</title>
${family.credit ? `<!-- Font: ${esc(family.credit)} -->\n` : ''}<style>
${fontCss.join('\n')}
*{box-sizing:border-box}
body{margin:0;padding:1rem;background:#eceef4}
.page{position:relative;container-type:inline-size;width:min(100%,${+(W * 4 / 3).toFixed(1)}px);aspect-ratio:${+W.toFixed(2)}/${+H.toFixed(2)};margin:0 auto 1.5rem;overflow:hidden;background:${paper};box-shadow:0 1px 6px rgba(27,42,107,.25);font-family:${style.family};color:${style.color}}
.page img{position:absolute;inset:0;width:100%;height:100%}
.page img.initial{inset:auto}
.page h1,.page h2,.page h3,.page p,.page ul,.page ol,.page li{margin:0;padding:0;font:inherit;list-style:none}
.page i.m{position:absolute;font-style:normal;white-space:pre}
.page span{position:absolute;white-space:pre;line-height:1}
.page strong{font-weight:700}
@page{size:${+W.toFixed(2)}pt ${+H.toFixed(2)}pt;margin:0}
@media print{body{padding:0;background:none}.page{width:${+W.toFixed(2)}pt;margin:0;box-shadow:none;break-after:page;print-color-adjust:exact;-webkit-print-color-adjust:exact}.page:last-child{break-after:auto}}
</style>
</head>
<body>
${body.join('\n')}
</body>
</html>
`
  return new Blob([html], { type: 'text/html' })
}

export function download(blob: Blob, name: string) {
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(a.href), 10000)
}

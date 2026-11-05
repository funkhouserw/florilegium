// exporter.ts -- finished pages: a PNG; a PDF, the drawing as vector operators and the text as real
// text in embedded fonts, so it can be selected and printed; and one self-contained HTML file.
import fontkit from '@pdf-lib/fontkit'
import { PDFDocument, PDFName, popGraphicsState, pushGraphicsState, rgb, setLineWidth, setStrokingColor, setTextRenderingMode, TextRenderingMode, type PDFFont } from 'pdf-lib'
import { fontOf, type FlowPage, type Line, type TextStyle } from './flow'
import { faceOf, type Family } from './fonts'

// The gym as an image, the text on the canvas: an SVG in an <img> can't see the page's web fonts.
export async function pagePng(gym: string, page: FlowPage, style: TextStyle, pixelWidth: number, W: number, H: number, paper: string): Promise<Blob> {
  const url = URL.createObjectURL(new Blob([gym], { type: 'image/svg+xml' }))
  try {
    const img = new Image()
    img.src = url
    await img.decode()
    const canvas = document.createElement('canvas')
    canvas.width = pixelWidth
    canvas.height = Math.round(pixelWidth * H / W)
    const c = canvas.getContext('2d')!
    c.fillStyle = paper
    c.fillRect(0, 0, canvas.width, canvas.height)
    c.drawImage(img, 0, 0, canvas.width, canvas.height)
    c.scale(canvas.width / W, canvas.height / H)
    c.fillStyle = style.color
    for (const l of page.lines) for (const r of l.runs) {
      c.font = fontOf(r, l.size, style.family)
      c.fillText(r.text, r.x, l.y)
    }
    return await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('no PNG'))), 'image/png'))
  } finally { URL.revokeObjectURL(url) }
}

const hexColor = (h: string) => rgb(parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255)

// ops: one page's drawing from florilegium-ink.lua, which names its opacity and multiply states
// /floaNN and /flomNN (NN percent); TeX declares them for LuaLaTeX, this does here.
export async function pagesToPdf(pages: FlowPage[], ops: string[], style: TextStyle, family: Family, W: number, H: number, title: string): Promise<{ pdf: Blob; missing: string[] }> {
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
  if (title) pdf.setTitle(title)
  const color = hexColor(style.color)
  pages.forEach((p, i) => {
    const page = pdf.addPage([W, H])
    const states: Record<string, unknown> = {}
    for (const m of ops[i].matchAll(/\/flo([am])(\d+) gs/g)) {
      const op = +m[2] / 100
      states[`flo${m[1]}${m[2]}`] = { Type: 'ExtGState', ca: op, CA: op, ...(m[1] === 'm' ? { BM: 'Multiply' } : {}) }
    }
    page.node.normalizedEntries().Resources.set(PDFName.of('ExtGState'), pdf.context.obj(states as never))
    page.node.addContentStream(pdf.context.register(pdf.context.flateStream(ops[i])))
    for (const l of p.lines) for (const r of l.runs) {
      const face = faceOf(files, r.bold, r.italic)
      const { font, known } = fonts.get(face.file)!
      for (const ch of r.text) if (ch.trim() && !known.has(ch.codePointAt(0)!)) missing.add(ch)
      if (!r.text.trim()) continue
      // text state set outside the text object carries into it: fill and outline, a face made heavier
      if (face.heavier) page.pushOperators(pushGraphicsState(), setTextRenderingMode(TextRenderingMode.FillAndOutline), setLineWidth(l.size * 0.02), setStrokingColor(color))
      page.drawText(r.text, { x: r.x, y: H - l.y, size: l.size, font, color })
      if (face.heavier) page.pushOperators(popGraphicsState())
    }
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
export async function pagesToHtml(pages: FlowPage[], gyms: string[], style: TextStyle, family: Family, W: number, H: number, title: string, paper: string): Promise<Blob> {
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
    const runs = l.runs.map((r) => {
      let t = (r.gap ? ' ' : '') + esc(r.text)
      if (r.italic) t = `<em>${t}</em>`
      if (r.bold) t = `<strong>${t}</strong>`
      return t
    }).join('')
    return `<span style="left:${cq(l.x)};top:${cq(l.y - l.size * top)};font-size:${cq(l.size)}">${runs}</span>`
  }
  const body: string[] = []
  for (let i = 0; i < pages.length; i++) {
    const image = await dataUrl(new Blob([gyms[i]], { type: 'image/svg+xml' }))
    const blocks: string[] = []
    let open = -1
    let tag = ''
    for (const l of pages[i].lines) {
      if (l.block !== open) {
        if (tag) blocks.push(`</${tag}>`)
        open = l.block
        tag = l.tag
        blocks.push(`<${tag}>`)
      }
      blocks.push(lineHtml(l))
    }
    if (tag) blocks.push(`</${tag}>`)
    body.push(`<section class="page" aria-label="Page ${i + 1}">\n<img src="${image}" alt="" decoding="async">\n${blocks.join('\n')}\n</section>`)
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
.page h1,.page h2,.page p{margin:0;font:inherit}
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

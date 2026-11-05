// exporter.ts -- a finished page as a PNG, and all pages as a PDF: the drawing as vector
// operators, the text as real text in an embedded font, so it can be selected and printed.
import fontkit from '@pdf-lib/fontkit'
import { PDFDocument, PDFName, rgb } from 'pdf-lib'
import type { FlowPage, TextStyle } from './flow'

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
    c.font = `${style.size}px ${style.family}`
    c.fillStyle = style.color
    for (const l of page.lines) c.fillText(l.text.replace(/\n$/, ''), l.x, l.y)
    return await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('no PNG'))), 'image/png'))
  } finally { URL.revokeObjectURL(url) }
}

const hexColor = (h: string) => rgb(parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255)

// ops: one page's drawing from florilegium-ink.lua, which names its opacity and multiply states
// /floaNN and /flomNN (NN percent); TeX declares them for LuaLaTeX, this does here.
export async function pagesToPdf(pages: FlowPage[], ops: string[], style: TextStyle, fontUrl: string, W: number, H: number, title: string): Promise<{ pdf: Blob; missing: string[] }> {
  const pdf = await PDFDocument.create()
  pdf.registerFontkit(fontkit)
  const bytes = await (await fetch(fontUrl)).arrayBuffer()
  const font = await pdf.embedFont(bytes, { subset: true })
  const known = new Set(font.getCharacterSet())
  const missing = new Set<string>()
  if (title) pdf.setTitle(title)
  pages.forEach((p, i) => {
    const page = pdf.addPage([W, H])
    const states: Record<string, unknown> = {}
    for (const m of ops[i].matchAll(/\/flo([am])(\d+) gs/g)) {
      const op = +m[2] / 100
      states[`flo${m[1]}${m[2]}`] = { Type: 'ExtGState', ca: op, CA: op, ...(m[1] === 'm' ? { BM: 'Multiply' } : {}) }
    }
    page.node.normalizedEntries().Resources.set(PDFName.of('ExtGState'), pdf.context.obj(states as never))
    page.node.addContentStream(pdf.context.register(pdf.context.flateStream(ops[i])))
    const color = hexColor(style.color)
    for (const l of p.lines) {
      const text = l.text.replace(/\n$/, '')
      for (const ch of text) if (ch.trim() && !known.has(ch.codePointAt(0)!)) missing.add(ch)
      if (text.trim()) page.drawText(text, { x: l.x, y: H - l.y, size: style.size, font, color })
    }
  })
  return { pdf: new Blob([await pdf.save()], { type: 'application/pdf' }), missing: [...missing] }
}

export function download(blob: Blob, name: string) {
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(a.href), 10000)
}

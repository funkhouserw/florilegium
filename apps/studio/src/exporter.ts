// exporter.ts -- a finished page as one SVG (gym + text), as a PNG, and all pages as a PDF.
import { PDFDocument } from 'pdf-lib'
import type { FlowPage, TextStyle } from './flow'

const esc = (s: string) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')

export function pageSvg(gym: string, page: FlowPage, style: TextStyle, W: number, H: number, paper: string): string {
  const inner = gym.replace(/^<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')
  const text = page.lines.map((l) =>
    `<text x="${l.x.toFixed(2)}" y="${l.y.toFixed(2)}" xml:space="preserve">${esc(l.text.replace(/\n$/, ''))}</text>`).join('\n')
  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">
<rect width="100%" height="100%" fill="${paper}"/>${inner}
<g font-family='${style.family.replace(/'/g, '"')}' font-size="${style.size}" fill="${style.color}">${text}</g></svg>`
}

export async function svgToPng(svg: string, pixelWidth: number, W: number, H: number): Promise<Blob> {
  const url = URL.createObjectURL(new Blob([svg], { type: 'image/svg+xml' }))
  try {
    const img = new Image()
    img.src = url
    await img.decode()
    const canvas = document.createElement('canvas')
    canvas.width = pixelWidth
    canvas.height = Math.round(pixelWidth * H / W)
    canvas.getContext('2d')!.drawImage(img, 0, 0, canvas.width, canvas.height)
    return await new Promise<Blob>((res, rej) => canvas.toBlob((b) => (b ? res(b) : rej(new Error('no PNG'))), 'image/png'))
  } finally { URL.revokeObjectURL(url) }
}

// images of the pages, so the text is not selectable: the gym's blend modes do not all survive in PDF
export async function pngsToPdf(pngs: Blob[], W: number, H: number): Promise<Blob> {
  const pdf = await PDFDocument.create()
  for (const b of pngs) {
    const img = await pdf.embedPng(await b.arrayBuffer())
    pdf.addPage([W, H]).drawImage(img, { x: 0, y: 0, width: W, height: H })
  }
  return new Blob([await pdf.save()], { type: 'application/pdf' })
}

export function download(blob: Blob, name: string) {
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = name
  a.click()
  setTimeout(() => URL.revokeObjectURL(a.href), 10000)
}

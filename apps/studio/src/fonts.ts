// fonts.ts -- the typefaces. Those with `files` come with the app, so a PDF or an HTML file can embed
// them; a page can't read a system font's file. A face a typeface lacks (IM Fell has no bold, neither
// has a bold italic) is made heavier from the one it has: the browser does that itself, the PDF with
// an outline.
export type Faces = { regular: string; italic: string; bold?: string }
export type Family = { css: string; label: string; files?: Faces; headingBold: boolean; credit?: string }

export const FAMILIES: Family[] = [
  { css: '"Studio Fell", serif', label: 'IM Fell', headingBold: false, files: { regular: 'fell', italic: 'fell-italic' },
    credit: 'IM FELL DW Pica, Igino Marini, SIL Open Font License 1.1, https://openfontlicense.org' },
  { css: '"Florilegium Roman", serif', label: 'Florilegium Roman', headingBold: true, files: { regular: 'lmroman', italic: 'lmroman-italic', bold: 'lmroman-bold' },
    credit: 'Florilegium Roman, a subset of Latin Modern Roman (GUST e-foundry), GUST Font License, https://www.gust.org.pl/projects/e-foundry/latin-modern' },
  { css: 'Georgia, serif', label: 'Georgia', headingBold: true },
  { css: '"Times New Roman", serif', label: 'Times New Roman', headingBold: true },
  { css: '"Helvetica Neue", Helvetica, Arial, sans-serif', label: 'Helvetica Neue', headingBold: true },
]
export const familyOf = (css: string) => FAMILIES.find((f) => f.css === css) ?? FAMILIES[0]

// which file draws a run, and whether it has to be made heavier
export function faceOf(files: Faces, bold: boolean, italic: boolean): { file: string; weight: number; style: string; heavier: boolean } {
  if (italic) return { file: files.italic, weight: 400, style: 'italic', heavier: bold }
  if (bold && files.bold) return { file: files.bold, weight: 700, style: 'normal', heavier: false }
  return { file: files.regular, weight: 400, style: 'normal', heavier: bold }
}

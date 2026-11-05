// schema.ts -- what a story is made of: a flat list of paragraphs and headings holding text with bold
// and italic. A list item is a paragraph with a `list` mark on it, so every position in a story is in
// some line of text. Also the little Markdown a pasted post or the plain text view is written in.
import { DOMParser as PMDOMParser, Fragment, Node, Schema, Slice, type Mark } from 'prosemirror-model'

export type Align = 'left' | 'center' | 'right' | 'justify'
export type ListKind = 'bullet' | 'ordered' | null
export const ALIGNS: Align[] = ['left', 'center', 'right', 'justify']

const alignOf = (d: HTMLElement) => {
  const a = d.style.textAlign
  return ALIGNS.includes(a as Align) ? a : 'left'
}
export const schema = new Schema({
  nodes: {
    doc: { content: 'block+' },
    paragraph: {
      group: 'block', content: 'text*', marks: '_', attrs: { align: { default: 'left' }, list: { default: null } },
      parseDOM: [
        { tag: 'li', getAttrs: (d) => ({ align: alignOf(d), list: d.parentElement?.tagName === 'OL' ? 'ordered' : 'bullet' }) },
        { tag: 'p', getAttrs: (d) => ({ align: alignOf(d) }) },
        { tag: 'blockquote' }, { tag: 'pre' }, { tag: 'div', getAttrs: (d) => (d.querySelector('p,div,ul,ol,h1,h2,h3,h4,h5,h6,li,blockquote') ? false : { align: alignOf(d) }) },
      ],
      toDOM: (n) => [n.attrs.list ? 'li' : 'p', 0],
    },
    heading: {
      group: 'block', content: 'text*', marks: '_', attrs: { level: { default: 1 }, align: { default: 'left' } },
      parseDOM: [1, 2, 3, 4, 5, 6].map((l) => ({ tag: `h${l}`, getAttrs: (d: HTMLElement) => ({ level: Math.min(l, 3), align: alignOf(d) }) })),
      toDOM: (n) => [`h${n.attrs.level}`, 0],
    },
    text: {},
  },
  marks: {
    bold: {
      parseDOM: [{ tag: 'strong' }, { tag: 'b', getAttrs: (d) => (d.style.fontWeight === 'normal' ? false : null) }, { style: 'font-weight', getAttrs: (v) => (/^(bold(er)?|[6-9]\d\d)$/.test(v) ? null : false) }],
      toDOM: () => ['strong', 0],
    },
    italic: {
      parseDOM: [{ tag: 'em' }, { tag: 'i' }, { style: 'font-style=italic' }],
      toDOM: () => ['em', 0],
    },
  },
})
const { paragraph, heading } = schema.nodes
const { bold, italic } = schema.marks

const STAR = ''                                  // an escaped asterisk, while the markers are read
const MARK = /(\*\*\*|\*\*|\*)(?=\S)(.+?)(?<=\S)\1/
function inline(text: string, marks: readonly Mark[]): Node[] {
  const out: Node[] = []
  const add = (t: string) => { if (t) out.push(schema.text(t.split(STAR).join('*'), marks)) }
  let rest = text
  while (rest) {
    const m = MARK.exec(rest)
    if (!m) { add(rest); break }
    add(rest.slice(0, m.index))
    const n = m[1].length
    let next = marks
    if (n >= 2) next = bold.create().addToSet(next)
    if (n !== 2) next = italic.create().addToSet(next)
    out.push(...inline(m[2], next))
    rest = rest.slice(m.index + m[0].length)
  }
  return out
}

export function fromMarkdown(text: string): Node {
  const blocks: Node[] = []
  for (const raw of text.split(/\r?\n/)) {
    const source = raw.replace(/\\\*/g, STAR).trim()
    if (!source) continue
    let m: RegExpExecArray | null
    if ((m = /^(#{1,3})\s+(?=\S)/.exec(source))) blocks.push(heading.create({ level: m[1].length }, inline(source.slice(m[0].length), [])))
    else if ((m = /^[-*+]\s+(?=\S)/.exec(source))) blocks.push(paragraph.create({ list: 'bullet' }, inline(source.slice(m[0].length), [])))
    else if ((m = /^\d+[.)]\s+(?=\S)/.exec(source))) blocks.push(paragraph.create({ list: 'ordered' }, inline(source.slice(m[0].length), [])))
    else blocks.push(paragraph.create(null, inline(source, [])))
  }
  return schema.node('doc', null, blocks.length ? blocks : [paragraph.create()])
}

export function toMarkdown(doc: Node): string {
  const out: string[] = []
  let number = 0
  doc.forEach((b) => {
    let text = ''
    b.forEach((t) => {
      const s = (t.text ?? '').replace(/\*/g, '\\*')
      const k = (bold.isInSet(t.marks) ? 2 : 0) + (italic.isInSet(t.marks) ? 1 : 0)
      // markers hug the words, as the parser asks
      const m = /^(\s*)(.*?)(\s*)$/s.exec(s)!
      text += k && m[2] ? `${m[1]}${'*'.repeat(k)}${m[2]}${'*'.repeat(k)}${m[3]}` : s
    })
    number = b.attrs.list === 'ordered' ? number + 1 : 0
    if (b.type === heading) out.push(`${'#'.repeat(b.attrs.level)} ${text}`)
    else if (b.attrs.list === 'bullet') out.push(`- ${text}`)
    else if (b.attrs.list === 'ordered') out.push(`${number}. ${text}`)
    else out.push(text)
  })
  // a blank line between paragraphs, none inside a list
  return out.reduce((all, line, i) => {
    if (i === 0) return line
    const a = doc.child(i - 1), b = doc.child(i)
    return all + (a.attrs.list && b.attrs.list ? '\n' : '\n\n') + line
  }, '')
}

export function sliceFromHtml(html: string): Slice {
  const dom = new DOMParser().parseFromString(html, 'text/html').body
  for (const p of [...dom.querySelectorAll('li > p')]) p.replaceWith(...p.childNodes, ' ')
  return PMDOMParser.fromSchema(schema).parseSlice(dom)
}
export const sliceFromMarkdown = (text: string): Slice => {
  // one line of plain words goes into the line you're on
  const doc = fromMarkdown(text)
  return new Slice(Fragment.from(doc.content), 1, 1)
}
export function sliceToHtml(slice: Slice): string {
  const parts: string[] = []
  slice.content.forEach((b) => {
    const tag = b.type === heading ? `h${b.attrs.level}` : b.attrs.list ? 'li' : 'p'
    let inner = ''
    b.forEach((t) => {
      let s = (t.text ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
      if (italic.isInSet(t.marks)) s = `<em>${s}</em>`
      if (bold.isInSet(t.marks)) s = `<strong>${s}</strong>`
      inner += s
    })
    parts.push(`<${tag}>${inner}</${tag}>`)
  })
  return parts.join('')
}
export const sliceToText = (slice: Slice) => {
  const lines: string[] = []
  slice.content.forEach((b) => lines.push(b.textContent))
  return lines.join('\n')
}

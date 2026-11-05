// editor.ts -- what the keys and buttons do to a story, on ProseMirror's document, selection and undo.
// The drawing of the text is ours (flow.ts), since a browser's editor can't run across boxes.
import { toggleMark } from 'prosemirror-commands'
import { history, redo, undo } from 'prosemirror-history'
import type { Node } from 'prosemirror-model'
import { EditorState, TextSelection, type Transaction } from 'prosemirror-state'
import { schema, type Align, type ListKind } from './schema'

export const newState = (doc: Node) => EditorState.create({ doc, plugins: [history()] })
export const replaceDoc = (state: EditorState, doc: Node) => state.tr.replaceWith(0, state.doc.content.size, doc.content)
export const selectTo = (state: EditorState, head: number, extend: boolean) => {
  const clamp = (p: number) => Math.max(1, Math.min(state.doc.content.size - 1, p))
  return state.tr.setSelection(TextSelection.create(state.doc, extend ? state.selection.anchor : clamp(head), clamp(head)))
}
export const selectRange = (state: EditorState, anchor: number, head: number) => state.tr.setSelection(TextSelection.create(state.doc, anchor, head))
export const selectAll = (state: EditorState) => selectRange(state, 1, state.doc.content.size - 1)

const graphemes = new Intl.Segmenter(undefined, { granularity: 'grapheme' })
const words = new Intl.Segmenter(undefined, { granularity: 'word' })

// a step left or right: by a character or a word, crossing from one block into the next
export function step(doc: Node, pos: number, dir: -1 | 1, word: boolean): number {
  const $p = doc.resolve(pos)
  const text = $p.parent.textContent
  const off = $p.parentOffset
  if (dir < 0 && off === 0) return $p.before() === 0 ? pos : $p.before() - 1
  if (dir > 0 && off === text.length) return $p.after() >= doc.content.size ? pos : $p.after() + 1
  if (word) {
    const segs = [...words.segment(text)].filter((s) => s.isWordLike)
    if (dir < 0) {
      for (let i = segs.length - 1; i >= 0; i--) if (segs[i].index < off) return pos - off + segs[i].index
      return pos - off
    }
    for (const s of segs) if (s.index + s.segment.length > off) return pos - off + s.index + s.segment.length
    return pos - off + text.length
  }
  let target = dir < 0 ? 0 : text.length
  for (const s of graphemes.segment(text)) {
    const end = s.index + s.segment.length
    if (dir < 0) { if (s.index < off) target = s.index } else if (end > off) { target = end; break }
  }
  return pos - off + target
}
export function wordAt(doc: Node, pos: number): [number, number] {
  const $p = doc.resolve(pos)
  const base = pos - $p.parentOffset
  for (const s of words.segment($p.parent.textContent)) {
    if (s.isWordLike && s.index <= $p.parentOffset && $p.parentOffset <= s.index + s.segment.length) return [base + s.index, base + s.index + s.segment.length]
  }
  return [pos, pos]
}
export function blockAt(doc: Node, pos: number): [number, number] {
  const $p = doc.resolve(pos)
  return [$p.start(), $p.end()]
}

export function insertText(state: EditorState, text: string): Transaction {
  const tr = state.tr.insertText(text)
  return shortcuts(tr, text)
}

// what the invisible field says changed: an accent picker replaces the letter just typed
export function replaceBefore(state: EditorState, removed: number, text: string): Transaction {
  const { head, empty, $head } = state.selection
  const tr = state.tr
  if (removed > 0 && empty) tr.delete(Math.max($head.start(), head - removed), head)
  if (!text) return tr
  tr.insertText(text)
  return shortcuts(tr, text)
}

// Markdown typed as you go: "# " at a line's start, "**word**"
function shortcuts(tr: Transaction, typed: string): Transaction {
  const $h = tr.selection.$head
  if (!tr.selection.empty) return tr
  const before = $h.parent.textBetween(0, $h.parentOffset)
  const start = $h.start()
  if (typed === ' ') {
    const m = /^(#{1,3}|[-*+]|\d+[.)]) $/.exec(before)
    if (m) {
      tr.delete(start, $h.pos)
      const pos = tr.mapping.map(start)
      const align = $h.parent.attrs.align
      if (m[1].startsWith('#')) tr.setNodeMarkup(pos - 1, schema.nodes.heading, { level: m[1].length, align })
      else tr.setNodeMarkup(pos - 1, schema.nodes.paragraph, { align, list: /\d/.test(m[1]) ? 'ordered' : 'bullet' })
      return tr
    }
  }
  if (typed === '*') {
    const m = /\*\*([^*\s](?:[^*]*[^*\s])?)\*\*$/.exec(before) ?? /(?<!\*)\*([^*\s](?:[^*]*[^*\s])?)\*$/.exec(before)
    if (m) {
      const from = start + m.index!, to = $h.pos
      const mark = m[0].startsWith('**') ? schema.marks.bold : schema.marks.italic
      const inner = from + m[0].indexOf(m[1])
      tr.addMark(inner, inner + m[1].length, mark.create())
      tr.delete(inner + m[1].length, to)
      tr.delete(from, inner)
      tr.removeStoredMark(mark)
    }
  }
  return tr
}

export function deleteBack(state: EditorState, word: boolean, line: number | null): Transaction | null {
  const { selection: s, doc } = state
  if (!s.empty) return state.tr.delete(s.from, s.to)
  const $p = s.$head
  if (line !== null && line < s.head) return state.tr.delete(line, s.head)
  if ($p.parentOffset > 0) return state.tr.delete(step(doc, s.head, -1, word), s.head)
  // at the start of a block: a list item stops being one, a heading a heading, then the blocks join
  if ($p.parent.attrs.list) return state.tr.setNodeMarkup($p.before(), undefined, { ...$p.parent.attrs, list: null })
  if ($p.parent.type === schema.nodes.heading) return state.tr.setNodeMarkup($p.before(), schema.nodes.paragraph, { align: $p.parent.attrs.align, list: null })
  const before = $p.before()
  if (before === 0) return null
  const prev = doc.resolve(before).nodeBefore!
  if (prev.content.size === 0) return state.tr.delete(before - prev.nodeSize, before)
  return state.tr.join(before)
}
export function deleteForward(state: EditorState, word: boolean, line: number | null): Transaction | null {
  const { selection: s, doc } = state
  if (!s.empty) return state.tr.delete(s.from, s.to)
  const $p = s.$head
  if (line !== null && line > s.head) return state.tr.delete(s.head, line)
  if ($p.parentOffset < $p.parent.content.size) return state.tr.delete(s.head, step(doc, s.head, 1, word))
  const after = $p.after()
  if (after >= doc.content.size) return null
  if ($p.parent.content.size === 0) return state.tr.delete($p.before(), after)
  return state.tr.join(after)
}
export function enter(state: EditorState): Transaction {
  const tr = state.tr
  const { from, to } = state.selection
  if (from !== to) tr.delete(from, to)
  const $p = tr.doc.resolve(tr.mapping.map(from))
  const node = $p.parent
  if (node.attrs.list && node.content.size === 0) return tr.setNodeMarkup($p.before(), undefined, { ...node.attrs, list: null })
  const atEnd = $p.parentOffset === node.content.size
  const heading = node.type === schema.nodes.heading
  const next = heading && atEnd
    ? { type: schema.nodes.paragraph, attrs: { align: node.attrs.align, list: null } }
    : { type: node.type, attrs: node.attrs }
  tr.split($p.pos, 1, [next])
  return tr.setSelection(TextSelection.create(tr.doc, $p.pos + 2))
}

function forBlocks(state: EditorState, fn: (node: Node) => { type?: Node['type']; attrs: Record<string, unknown> }): Transaction {
  const tr = state.tr
  const { from, to } = state.selection
  state.doc.nodesBetween(from, to, (n, pos) => {
    if (!n.isTextblock) return true
    const { type, attrs } = fn(n)
    tr.setNodeMarkup(pos, type ?? n.type, attrs)
    return false
  })
  return tr
}
export const setBlock = (state: EditorState, kind: 'p' | 1 | 2 | 3) => forBlocks(state, (n) => (kind === 'p'
  ? { type: schema.nodes.paragraph, attrs: { align: n.attrs.align, list: null } }
  : { type: schema.nodes.heading, attrs: { align: n.attrs.align, level: kind } }))
export const setAlign = (state: EditorState, align: Align) => forBlocks(state, (n) => ({ attrs: { ...n.attrs, align } }))
export const toggleList = (state: EditorState, list: ListKind) => {
  const on = state.selection.$from.parent.attrs.list === list
  return forBlocks(state, (n) => ({ type: schema.nodes.paragraph, attrs: { align: n.attrs.align, list: on ? null : list } }))
}
export function toggle(state: EditorState, mark: 'bold' | 'italic'): Transaction | null {
  let out: Transaction | null = null
  toggleMark(schema.marks[mark])(state, (tr) => { out = tr })
  return out
}
export function marksHere(state: EditorState) {
  const { from, to, empty, $from } = state.selection
  const has = (m: 'bold' | 'italic') => {
    const t = schema.marks[m]
    if (empty) return !!t.isInSet(state.storedMarks ?? $from.marks())
    return state.doc.rangeHasMark(from, to, t)
  }
  return { bold: has('bold'), italic: has('italic') }
}
export function run(state: EditorState, cmd: typeof undo): Transaction | null {
  let out: Transaction | null = null
  cmd(state, (tr) => { out = tr })
  return out
}
export { redo, undo }

// The studio: draw boxes on a page and type in them. Each box holds a story of its own or carries on
// one that started in another box; the text flows as you type, and the drawing grows around the boxes
// when you ask. Your work is kept in this browser as you go, and in a file when you ask.
import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { EditorState, type Transaction } from 'prosemirror-state'
import { blockAt, deleteBack, deleteForward, enter, marksHere, newState, redo, replaceBefore, replaceDoc, run, selectAll, selectRange, selectTo, setAlign, setBlock, step, toggle, toggleList, undo, wordAt } from './editor'
import { flow, fontOf, lineOfPos, posOfX, remeasure, xOfPos, type Box, type FlowPage, type Layer, type Line, type TextStyle } from './flow'
import { growGym } from './gym'
import { download, pagePng, pagesToHtml, pagesToPdf } from './exporter'
import { CM, docFile, fitMargins, followMargins, loadDoc, marginLimit, newBoxId, newDoc, newStoryDoc, newStoryId, readDocFile, resizeBoxes, saveDoc, SEASONS, SIZES, type Doc, type Grows, type Margins, type Season, type SizeKey } from './doc'
import { familyOf, FAMILIES } from './fonts'
import { fromMarkdown, sliceFromHtml, sliceFromMarkdown, sliceToHtml, sliceToText, toMarkdown, type Align } from './schema'

const PAPER = '#fefdfb'
type Story = { id: number; state: EditorState; auto: boolean }
const storiesOf = (d: Doc): Story[] => d.stories.map((s) => ({ id: s.id, state: newState(s.doc), auto: s.auto }))
const initial = loadDoc()
const mac = /Mac|iPhone|iPad/.test(navigator.platform)

type Drag =
  | { kind: 'draw'; page: number; x0: number; y0: number; id: number }
  | { kind: 'move' | 'size'; page: number; id: number; dx: number; dy: number }
type Caret = { x: number; y0: number; y1: number; base: number; size: number }
type TextDrag = { story: number; anchor: number; unit: 'char' | 'word' | 'block'; lo: number; hi: number }

export function App() {
  const [stories, setStories] = useState<Story[]>(() => storiesOf(initial))
  const [sizeKey, setSizeKey] = useState<SizeKey>(initial.sizeKey)
  const [family, setFamily] = useState(initial.family)
  const [fontSize, setFontSize] = useState(initial.fontSize)
  const [seed, setSeed] = useState(initial.seed)
  const [cats, setCats] = useState(initial.cats)
  const [pieces, setPieces] = useState(initial.pieces)
  const [grows, setGrows] = useState<Grows>(initial.grows)
  const [inkName, setInkName] = useState(initial.inkName)
  const [crown, setCrown] = useState(initial.crown)
  const [season, setSeason] = useState<Season>(initial.season)
  const [spanishmoss, setSpanishmoss] = useState(initial.spanishmoss)
  const [textColor, setTextColor] = useState(initial.textColor)
  const [margins, setMargins] = useState<Margins>(initial.margins)
  const [drawn, setDrawn] = useState<Box[][]>(initial.drawn)
  const S = SIZES[sizeKey]
  const W = S.w * CM, H = S.h * CM
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [noted, setNoted] = useState<{ text: string; doc: unknown } | null>(null)
  const [unsaved, setUnsaved] = useState(false)
  const setNote = (text: string) => setNoted(text ? { text, doc: docNow.current } : null)
  const docNow = useRef<unknown>(null)
  const opener = useRef<HTMLInputElement>(null)
  const typing = useRef<HTMLTextAreaElement>(null)
  const svgs = useRef<(SVGSVGElement | null)[]>([])
  const caretEl = useRef<SVGLineElement | null>(null)
  const followed = useRef('')
  const goalX = useRef<number | null>(null)                  // where up and down are aiming
  const [activeId, setActiveId] = useState<number | null>(null)
  const [focused, setFocused] = useState(false)
  const [composition, setComposition] = useState<string | null>(null)   // an accent or other text still being composed
  const lastTyped = useRef('')
  const [selected, setSelected] = useState<{ page: number; id: number } | null>(null)
  const [linking, setLinking] = useState<number | null>(null)
  const [plain, setPlain] = useState<string | null>(null)

  const face = familyOf(family)
  const style: TextStyle = useMemo(() => ({ family, size: fontSize, leading: 1.35, color: textColor, headingBold: face.headingBold }), [family, fontSize, face, textColor])
  // Pretext and the cursor measure with the browser's font: measure again once the web fonts have arrived
  const [fontsReady, setFontsReady] = useState(0)
  useEffect(() => {
    let live = true
    const looks = [{ bold: false, italic: false }, { bold: false, italic: true }, { bold: true, italic: false }]
    Promise.all(looks.map((l) => document.fonts.load(fontOf(l, 40, family)))).then(() => {
      if (live) { remeasure(); setFontsReady((n) => n + 1) }
    })
    return () => { live = false }
  }, [family])
  const texts = useMemo(() => stories.map((s) => ({ id: s.id, doc: s.state.doc, auto: s.auto })), [stories])
  const { pages, overflow, byStory } = useMemo(() => flow(texts, drawn, style), [texts, drawn, style, fontsReady])
  const active = stories.find((s) => s.id === activeId) ?? null
  const activeLines = (activeId !== null && byStory.get(activeId)) || []
  const titleBlock = texts.flatMap((t) => { const out: string[] = []; t.doc.forEach((b) => { if (b.textContent.trim()) out.push(b.textContent) }); return out })[0] ?? ''
  const title = titleBlock.slice(0, 120)
  const fileBase = title.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'studio'
  const boxCount = (story: number) => drawn.reduce((n, p) => n + p.filter((b) => b.story === story).length, 0)

  // kept in this browser as you work; a full disk must not stop the work
  const doc: Doc = useMemo(() => ({ stories: texts, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, textColor, margins, drawn }),
    [texts, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, textColor, margins, drawn])
  docNow.current = doc
  const note = noted && noted.doc === doc ? noted.text : ''      // a note lasts until the work changes
  useEffect(() => {
    if (dragging) return
    const timer = setTimeout(() => {
      try { saveDoc(doc); setUnsaved(false) } catch { setUnsaved(true) }
    }, 300)
    return () => clearTimeout(timer)
  }, [doc, dragging])
  function applyDoc(d: Doc) {
    setStories(storiesOf(d)); setSizeKey(d.sizeKey); setFamily(d.family); setFontSize(d.fontSize); setSeed(d.seed); setCats(d.cats); setPieces(d.pieces)
    setGrows(d.grows); setInkName(d.inkName); setCrown(d.crown); setSeason(d.season); setSpanishmoss(d.spanishmoss); setTextColor(d.textColor); setMargins(d.margins); setDrawn(d.drawn)
    setError(''); setNote(''); setActiveId(null); setSelected(null); setLinking(null); setPlain(null)
    setGrowTick((t) => t + 1)
    growOnFonts.current = d.family !== family
  }
  async function openFile(file?: File) {
    if (!file) return
    try { applyDoc(readDocFile(await file.text())) } catch (e) { setError(`Could not open ${file.name}: ${e instanceof Error ? e.message : String(e)}`) }
  }

  // ---- the text ----
  function update(id: number, fn: (s: EditorState) => Transaction | null) {
    setStories((all) => all.map((st) => {
      if (st.id !== id) return st
      const tr = fn(st.state)
      return tr ? { ...st, state: st.state.apply(tr) } : st
    }))
  }
  const edit = (fn: (s: EditorState) => Transaction | null) => { if (activeId !== null) update(activeId, fn) }
  function focusTyping() { typing.current?.focus({ preventScroll: true }) }
  const textDrag = useRef<TextDrag | null>(null)
  const lastClick = useRef({ t: -1e9, x: 0, y: 0, n: 0 })

  // which line of a story is nearest a point on a page; a box you clicked with no text of its own means the story's end
  function nearest(lines: Line[], page: number, x: number, y: number, boxId?: number): Line | null {
    const onBox = boxId === undefined ? [] : lines.filter((l) => l.page === page && l.box === boxId)
    let pool = onBox.length ? onBox : lines.filter((l) => l.page === page)
    if (!pool.length) {
      if (boxId !== undefined) return lines[lines.length - 1] ?? null
      pool = lines
    }
    let best: Line | null = null
    let d = Infinity
    for (const l of pool) {
      const dy = y < l.top ? l.top - y : y > l.top + l.lh ? y - l.top - l.lh : 0
      const c = dy * 10 + (l.page === page ? Math.abs(l.x - x) * 0.001 : 1e6)
      if (c < d) { d = c; best = l }
    }
    return best
  }
  const pagePoint = (page: number, cx: number, cy: number) => {
    const r = svgs.current[page]!.getBoundingClientRect()
    return { x: (cx - r.left) * W / r.width, y: (cy - r.top) * H / r.height }
  }
  function pointAt(cx: number, cy: number) {
    let bestPage = -1
    let d = Infinity
    svgs.current.forEach((svg, i) => {
      if (!svg) return
      const r = svg.getBoundingClientRect()
      const dx = cx < r.left ? r.left - cx : cx > r.right ? cx - r.right : 0
      const dy = cy < r.top ? r.top - cy : cy > r.bottom ? cy - r.bottom : 0
      const c = dx + dy
      if (c < d) { d = c; bestPage = i }
    })
    return bestPage < 0 ? null : { page: bestPage, ...pagePoint(bestPage, cx, cy) }
  }

  function startText(e: React.PointerEvent, page: number, box: Box) {
    e.preventDefault()
    e.stopPropagation()
    if (linking !== null) { linkTo(box); return }
    const lines = byStory.get(box.story) ?? []
    const p = pagePoint(page, e.clientX, e.clientY)
    const l = nearest(lines, page, p.x, p.y, box.id)
    if (!l) return
    const pos = posOfX(l, p.x, style)
    forgetTyped()
    setActiveId(box.story)
    setSelected({ page, id: box.id })
    goalX.current = null
    focusTyping()
    // a pointer event doesn't count its clicks, so these are counted here
    const was = lastClick.current
    const clicks = e.timeStamp - was.t < 450 && Math.abs(e.clientX - was.x) < 4 && Math.abs(e.clientY - was.y) < 4 ? was.n + 1 : 1
    lastClick.current = { t: e.timeStamp, x: e.clientX, y: e.clientY, n: clicks }
    const unit: TextDrag['unit'] = clicks === 2 ? 'word' : clicks >= 3 ? 'block' : 'char'
    update(box.story, (st) => {
      const [lo, hi] = unit === 'word' ? wordAt(st.doc, pos) : unit === 'block' ? blockAt(st.doc, pos) : [pos, pos]
      textDrag.current = { story: box.story, anchor: pos, unit, lo, hi }
      if (unit !== 'char') return selectRange(st, lo, hi)
      if (e.shiftKey && activeId === box.story) { textDrag.current.anchor = st.selection.anchor; return selectTo(st, pos, true) }
      return selectTo(st, pos, false)
    })
    window.addEventListener('pointermove', dragText)
    window.addEventListener('pointerup', endText, { once: true })
  }
  // read fresh on every move: a listener added once outlives the render that made it
  const latest = useRef({ byStory, style, stories })
  latest.current = { byStory, style, stories }
  function dragText(e: PointerEvent) {
    const d = textDrag.current
    if (!d) return
    const at = pointAt(e.clientX, e.clientY)
    if (!at) return
    const lines = latest.current.byStory.get(d.story) ?? []
    const l = nearest(lines, at.page, at.x, at.y)
    if (!l) return
    const pos = posOfX(l, at.x, latest.current.style)
    update(d.story, (st) => {
      if (d.unit === 'word') {
        const [a, b] = wordAt(st.doc, pos)
        return pos < d.lo ? selectRange(st, d.hi, a) : selectRange(st, d.lo, Math.max(b, d.hi))
      }
      if (d.unit === 'block') {
        const [a, b] = blockAt(st.doc, pos)
        return pos < d.lo ? selectRange(st, d.hi, a) : selectRange(st, d.lo, Math.max(b, d.hi))
      }
      return selectRange(st, d.anchor, pos)
    })
  }
  function endText() {
    textDrag.current = null
    window.removeEventListener('pointermove', dragText)
  }

  function lineEdge(head: number, end: boolean): number {
    const l = lineOfPos(activeLines, head)
    if (!l) return head
    if (!end) return l.from
    if (l.lastOfBlock) return l.to
    const e = l.runs[l.runs.length - 1]
    return e && e.from >= 0 ? e.to - 1 : l.to
  }
  function vertical(state: EditorState, dir: -1 | 1, extend: boolean) {
    const head = state.selection.head
    const l = lineOfPos(activeLines, head)
    if (!l) return
    const i = activeLines.indexOf(l)
    const x = goalX.current ?? xOfPos(l, head, style)
    goalX.current = x
    const n = activeLines[i + dir]
    edit((st) => selectTo(st, n ? posOfX(n, x, style) : dir < 0 ? 1 : st.doc.content.size - 1, extend))
  }
  function onKey(e: React.KeyboardEvent<HTMLTextAreaElement>) {
    if (e.nativeEvent.isComposing || e.keyCode === 229 || !active) return
    const st = active.state
    const mod = mac ? e.metaKey : e.ctrlKey
    const alt = e.altKey
    const shift = e.shiftKey
    const stop = () => { e.preventDefault(); forgetTyped() }   // the cursor moves or the text changes some other way
    const k = e.key
    const keepsGoal = k === 'ArrowUp' || k === 'ArrowDown'
    if (!keepsGoal) goalX.current = null
    const head = st.selection.head
    if (k === 'ArrowLeft' || k === 'ArrowRight') {
      stop()
      const dir = k === 'ArrowLeft' ? -1 : 1
      if (mod) edit((s) => selectTo(s, lineEdge(head, dir > 0), shift))
      else if (!shift && !st.selection.empty && !alt) edit((s) => selectTo(s, dir < 0 ? s.selection.from : s.selection.to, false))
      else edit((s) => selectTo(s, step(s.doc, head, dir, alt), shift))
    } else if (keepsGoal) {
      stop()
      const dir = k === 'ArrowUp' ? -1 : 1
      if (mod) edit((s) => selectTo(s, dir < 0 ? 1 : s.doc.content.size - 1, shift))
      else vertical(st, dir, shift)
    } else if (k === 'Home' || k === 'End') {
      stop()
      if (mod) edit((s) => selectTo(s, k === 'Home' ? 1 : s.doc.content.size - 1, shift))
      else edit((s) => selectTo(s, lineEdge(head, k === 'End'), shift))
    } else if (k === 'Backspace') {
      stop()
      edit((s) => deleteBack(s, alt, mod ? lineEdge(s.selection.head, false) : null))
    } else if (k === 'Delete') {
      stop()
      edit((s) => deleteForward(s, alt, mod ? lineEdge(s.selection.head, true) : null))
    } else if (k === 'Enter') {
      stop()
      edit(enter)
    } else if (k === 'Escape') {
      stop()
      setActiveId(null)
      setLinking(null)
      typing.current?.blur()
    } else if (mod && !alt) {
      const l = k.toLowerCase()
      if (l === 'b') { stop(); edit((s) => toggle(s, 'bold')) }
      else if (l === 'i') { stop(); edit((s) => toggle(s, 'italic')) }
      else if (l === 'a') { stop(); edit(selectAll) }
      else if (l === 'z') { stop(); edit((s) => run(s, shift ? redo : undo)) }
      else if (l === 'y') { stop(); edit((s) => run(s, redo)) }
    }
  }
  // The invisible field keeps the last few characters typed, because the Mac's accent picker (hold a
  // key) replaces the letter before the cursor in it: what changed there is what changes in the story.
  function syncTyping() {
    const ta = typing.current
    if (!ta) return
    const old = lastTyped.current, now = ta.value
    if (old === now) return
    let i = 0
    while (i < old.length && i < now.length && old[i] === now[i]) i++
    if (i > 0 && /[\uD800-\uDBFF]/.test(old[i - 1])) i--          // never halfway through an emoji
    const removed = old.length - i, added = now.slice(i)
    const kept = now.slice(-8)
    ta.value = kept
    lastTyped.current = kept
    goalX.current = null
    edit((s) => replaceBefore(s, removed, added))
  }
  const forgetTyped = () => {
    if (typing.current) typing.current.value = ''
    lastTyped.current = ''
  }
  function onCopy(e: React.ClipboardEvent, cut: boolean) {
    if (!active || active.state.selection.empty) return
    e.preventDefault()
    const slice = active.state.selection.content()
    e.clipboardData.setData('text/plain', sliceToText(slice))
    e.clipboardData.setData('text/html', sliceToHtml(slice))
    if (cut) edit((s) => s.tr.deleteSelection())
  }
  function onPaste(e: React.ClipboardEvent) {
    if (!active) return
    e.preventDefault()
    const html = e.clipboardData.getData('text/html')
    const text = e.clipboardData.getData('text/plain')
    const slice = html ? sliceFromHtml(html) : text ? sliceFromMarkdown(text) : null
    forgetTyped()
    if (slice) edit((s) => s.tr.replaceSelection(slice))
  }

  // the cursor and the highlight, page by page
  const marks = useMemo(() => {
    const out = new Map<number, { rects: { x: number; y: number; w: number; h: number }[]; caret?: Caret }>()
    if (!active) return out
    const sel = active.state.selection
    const at = (page: number) => { let m = out.get(page); if (!m) out.set(page, (m = { rects: [] })); return m }
    if (sel.empty) {
      const l = lineOfPos(activeLines, sel.head)
      if (l) at(l.page).caret = { x: xOfPos(l, sel.head, style), y0: l.y - l.size * 0.85, y1: l.y + l.size * 0.25, base: l.y, size: l.size }
    } else {
      for (const l of activeLines) {
        if (l.to < sel.from || l.from > sel.to) continue
        const a = xOfPos(l, Math.max(sel.from, l.from), style)
        const b = l.to <= sel.to && !l.lastOfBlock ? Math.max(xOfPos(l, l.to, style), a) : xOfPos(l, Math.min(sel.to, l.to), style)
        // a selection running on past the line's end shows it, even on an empty line
        const w = Math.max(b - a, sel.to > l.to ? l.size * 0.25 : 0)
        if (w > 0) at(l.page).rects.push({ x: a, y: l.top, w, h: l.lh })
      }
    }
    return out
  }, [active, activeLines, style])
  // the invisible field stands at the cursor, so an accent or emoji picker opens beside it, and the page follows the cursor
  useLayoutEffect(() => {
    const c = caretEl.current
    const t = typing.current
    if (!c || !t) return
    const r = c.getBoundingClientRect()
    t.style.left = `${r.left}px`
    t.style.top = `${r.top}px`
    const key = `${activeId}:${active?.state.selection.head}:${active?.state.doc.content.size}`
    if (focused && key !== followed.current) c.scrollIntoView({ block: 'nearest', inline: 'nearest' })   // not when you scroll away yourself
    followed.current = key
  })

  // ---- the boxes ----
  useEffect(() => {
    if (linking === null) return
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') setLinking(null) }
    window.addEventListener('keydown', esc)
    return () => window.removeEventListener('keydown', esc)
  }, [linking])
  function changeSize(k: SizeKey) {
    const fitted = fitMargins(margins, k)
    setSizeKey(k)
    setMargins(fitted)
    setDrawn((d) => resizeBoxes(d, sizeKey, margins, k, fitted))
    setGrowTick((t) => t + 1)      // a drawing grown for the old paper can't stand in for the new one
  }
  // Each keystroke starts again from where the field was entered, so a slip like 12 for 1.2 can be taken back.
  const marginStart = useRef<{ margins: Margins; drawn: Box[][] } | null>(null)
  function changeMargin(side: keyof Margins, v: number) {
    const start = marginStart.current ?? { margins, drawn }
    const next = { ...margins, [side]: v }
    setMargins(next)
    setDrawn(followMargins(start.drawn, sizeKey, start.margins, next))
  }
  // a change to a page that only follows the last one makes it a page of its own
  function editPage(page: number, fn: (boxes: Box[]) => Box[]) {
    setDrawn((d) => {
      const copy = d.slice()
      while (copy.length <= page) copy.push(pages[copy.length]?.boxes ?? [])
      copy[page] = fn(copy[page])
      return copy
    })
  }
  function drawBox(page: number, x: number, y: number) {
    const id = newBoxId()
    let story = linking
    if (story === null) {
      story = newStoryId()
      const made = story
      setStories((all) => [...all, { id: made, state: newState(newStoryDoc()), auto: false }])
    }
    editPage(page, (bs) => [...bs, { id, x, y, w: 1, h: 1, story: story!, layer: 'clear' }])
    setLinking(null)
    setActiveId(story)
    setSelected({ page, id })
    return id
  }
  function afterDraw(page: number, id: number, ok: boolean) {
    if (!ok) {
      const box = pages[page]?.boxes.find((b) => b.id === id)
      editPage(page, (bs) => bs.filter((b) => b.id !== id))
      if (box && boxCount(box.story) <= 1) setStories((all) => all.filter((s) => s.id !== box.story || s.state.doc.textContent))
      setActiveId(null)
      setSelected(null)
    } else focusTyping()
  }
  function removeBox(page: number, box: Box) {
    const story = stories.find((s) => s.id === box.story)
    const alone = boxCount(box.story) <= 1
    if (alone && story?.state.doc.textContent.trim() && !window.confirm('Delete this box and its text?')) return
    editPage(page, (bs) => bs.filter((b) => b.id !== box.id))
    if (alone) setStories((all) => all.filter((s) => s.id !== box.story))
    if (alone && activeId === box.story) setActiveId(null)
    setSelected(null)
  }
  function removePage(page: number) {
    const gone = pages[page].boxes
    const orphans = gone.filter((b) => {
      const others = drawn.flatMap((p, i) => (i === page ? [] : p)).filter((o) => o.story === b.story)
      return !others.length && stories.find((s) => s.id === b.story)?.state.doc.textContent.trim()
    })
    if (orphans.length && !window.confirm('Delete this page and the text only it holds?')) return
    const ids = new Set(gone.map((b) => b.story))
    setDrawn((d) => {
      const rest = d.filter((_, i) => i !== page)
      return rest.length ? rest : [[]]
    })
    setStories((all) => all.filter((s) => !ids.has(s.id) || drawn.some((p, i) => i !== page && p.some((b) => b.story === s.id))))
    setSelected(null)
    if (activeId !== null && ids.has(activeId) && !drawn.some((p, i) => i !== page && p.some((b) => b.story === activeId))) setActiveId(null)
  }
  // Linking two boxes makes them one chain, whichever you started from. Text in both joins up in
  // reading order; an empty box just takes its place in the other's chain.
  function linkTo(box: Box) {
    const from = linking!
    setLinking(null)
    if (box.story === from) return
    const pageOf = (id: number) => pages.findIndex((p) => p.boxes.some((b) => b.story === id))
    const a = stories.find((s) => s.id === from), b = stories.find((s) => s.id === box.story)
    if (!a || !b) return
    const aEmpty = !a.state.doc.textContent.trim(), bEmpty = !b.state.doc.textContent.trim()
    const first = aEmpty ? b : bEmpty ? a : pageOf(a.id) <= pageOf(b.id) ? a : b
    const second = first === a ? b : a
    setStories((all) => all.filter((s) => s.id !== second.id).map((s) => {
      if (s.id !== first.id) return s
      const has = second.state.doc.textContent.trim()
      const state = has ? s.state.apply(s.state.tr.insert(s.state.doc.content.size, second.state.doc.content)) : s.state
      return { ...s, state, auto: a.auto || b.auto }
    }))
    setDrawn((d) => d.map((p) => p.map((q) => (q.story === second.id ? { ...q, story: first.id } : q))))
    setActiveId(first.id)
  }
  function unlink(page: number, box: Box) {
    const id = newStoryId()
    setStories((all) => [...all, { id, state: newState(newStoryDoc()), auto: false }])
    editPage(page, (bs) => bs.map((b) => (b.id === box.id ? { ...b, story: id } : b)))
    setActiveId(id)
    focusTyping()
  }
  const selectedBox = selected ? pages[selected.page]?.boxes.find((b) => b.id === selected.id) ?? null : null
  const setLayer = (layer: Layer) => { if (selected) editPage(selected.page, (bs) => bs.map((b) => (b.id === selected.id ? { ...b, layer } : b))) }
  const chainOf = (story: number) => pages.flatMap((p, i) => p.boxes.filter((b) => b.story === story).map((b) => ({ page: i, id: b.id })))

  // ---- the drawing: it changes only when you ask ----
  const requests = useMemo(() => pages.map((p, index) => ({
    grows, ink: inkName, crown, season, spanishmoss, w: S.w, h: S.h, seed: seed + index * 101, cats, size: grows === 'gym' ? pieces : 1, density: 1, index,
    keepouts: p.boxes.filter((b) => b.layer === 'clear').map((b) => {
      const empty = !texts.find((t) => t.id === b.story)?.doc.textContent.trim()
      const h = empty ? b.h : p.used.get(b.id) ?? 0
      if (h <= 0) return null
      const pad = fontSize * 0.5                       // a little air around the text, and its descenders
      return [b.x - pad, H - (b.y + h + pad), b.x + b.w + pad, H - b.y + pad].map((v) => +(v / CM).toFixed(2))
    }).filter((q): q is number[] => q !== null),
  })), [pages, S, seed, cats, pieces, H, texts, fontSize, grows, inkName, crown, season, spanishmoss])
  const [grown, setGrown] = useState(requests)
  const [growTick, setGrowTick] = useState(0)
  // the first drawing, or an opened file's, waits for its fonts, since they decide where the text ends
  const growOnFonts = useRef(true)
  useEffect(() => { if (fontsReady && growOnFonts.current) { growOnFonts.current = false; setGrown(requests) } }, [fontsReady])  // eslint-disable-line react-hooks/exhaustive-deps
  useEffect(() => { if (growTick) setGrown(requests) }, [growTick])            // eslint-disable-line react-hooks/exhaustive-deps
  const [gyms, setGyms] = useState<Record<number, string>>({})
  const grownKey = JSON.stringify(grown)
  const stale = grownKey !== JSON.stringify(requests)
  const [growing, setGrowing] = useState(true)
  useEffect(() => {
    let live = true
    setGrowing(true)
    setError('')
    const timer = setTimeout(async () => {
      for (const r of grown) {
        try {
          const svg = await growGym(r)
          if (!live) return
          setGyms((g) => ({ ...g, [r.index]: svg }))
        } catch (e) { if (live) setError('It did not grow: ' + String(e)) }
      }
      if (live) setGrowing(false)
    }, 50)
    return () => { live = false; clearTimeout(timer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [grownKey])

  // an export is of the page as it stands: if the drawing is behind, it catches up on screen too
  const catchUp = () => { if (stale) setGrown(requests) }
  async function exportPngs() {
    setNote('')
    catchUp()
    try {
      for (let i = 0; i < pages.length; i++) {
        setBusy(`Page ${i + 1} of ${pages.length}`)
        download(await pagePng(await growGym(requests[i]), pages[i], style, S.px, W, H, PAPER), `${fileBase}-${i + 1}.png`)
      }
    } catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }
  async function grownPages(ops: boolean) {
    const out: string[] = []
    for (let i = 0; i < pages.length; i++) {
      setBusy(`Page ${i + 1} of ${pages.length}`)
      out.push(await growGym(ops ? { ...requests[i], ops: true } : requests[i]))
    }
    return out
  }
  const told = (b: Blob) => setNote(`Saved, ${(b.size / 1048576).toFixed(1)} MB.`)
  async function exportPdf() {
    setNote('')
    catchUp()
    try {
      const ops = await grownPages(true)
      setBusy('Writing the PDF')
      const { pdf, missing } = await pagesToPdf(pages, ops, style, face, W, H, title)
      if (missing.length) setError(`This typeface has no ${missing.slice(0, 12).join(' ')}: those characters will be missing from the PDF.`)
      download(pdf, `${fileBase}.pdf`)
      told(pdf)
    } catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }
  async function exportHtml() {
    setNote('')
    catchUp()
    try {
      const svgs = await grownPages(false)
      setBusy('Writing the HTML')
      const html = await pagesToHtml(pages, svgs, style, face, W, H, title, PAPER)
      download(html, `${fileBase}.html`)
      told(html)
    } catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }

  // ---- the toolbar: a button must not take the cursor away ----
  const keep = (e: React.MouseEvent) => e.preventDefault()
  const here = active ? active.state.selection.$head.parent : null
  const on = active ? marksHere(active.state) : { bold: false, italic: false }
  const kind = here ? (here.type.name === 'heading' ? here.attrs.level as number : 'p') : null
  const tool = (label: React.ReactNode, t: string, pressed: boolean, act: () => void) => (
    <button key={t} className={'tool' + (pressed ? ' on' : '')} title={t} aria-label={t} aria-pressed={pressed} disabled={!active} onMouseDown={keep} onClick={act}>{label}</button>
  )

  return (
    <div className="app">
      <aside className="panel">
        <h1>Studio</h1>
        <div className="toolbar" role="toolbar" aria-label="Text formatting">
          {tool('H1', 'Large heading', kind === 1, () => edit((s) => setBlock(s, 1)))}
          {tool('H2', 'Heading', kind === 2, () => edit((s) => setBlock(s, 2)))}
          {tool('H3', 'Small heading', kind === 3, () => edit((s) => setBlock(s, 3)))}
          {tool('¶', 'Plain paragraph', kind === 'p' && !here?.attrs.list, () => edit((s) => setBlock(s, 'p')))}
          {tool(<b>B</b>, 'Bold', on.bold, () => edit((s) => toggle(s, 'bold')))}
          {tool(<i>I</i>, 'Italic', on.italic, () => edit((s) => toggle(s, 'italic')))}
          {tool('•', 'Bulleted list', here?.attrs.list === 'bullet', () => edit((s) => toggleList(s, 'bullet')))}
          {tool('1.', 'Numbered list', here?.attrs.list === 'ordered', () => edit((s) => toggleList(s, 'ordered')))}
          {(['left', 'center', 'right', 'justify'] as Align[]).map((a) => tool(<AlignIcon align={a} />, `Align ${a}`, here?.attrs.align === a, () => edit((s) => setAlign(s, a))))}
        </div>
        <p className="hint">{active ? 'Markdown works as you type: # heading, - list, **bold**, *italic*.' : 'Click into a box to type. Drag on an empty part of a page to draw a new one.'}</p>

        {selectedBox && active && (
          <div className="boxpanel">
            <label>This box and the drawing
              <select value={selectedBox.layer} onMouseDown={(e) => e.stopPropagation()} onChange={(e) => setLayer(e.target.value as Layer)}>
                <option value="clear">Keep the drawing clear of it</option>
                <option value="over">Text over the drawing</option>
                <option value="behind">Text behind the drawing</option>
              </select>
            </label>
            <div className="row">
              <button onMouseDown={keep} className={linking !== null ? 'on' : ''} onClick={() => setLinking(linking === null ? active.id : null)}>{linking !== null ? 'Cancel link' : 'Link to a box…'}</button>
              <button onMouseDown={keep} disabled={boxCount(active.id) < 2} onClick={() => unlink(selected!.page, selectedBox)}>Unlink box</button>
            </div>
            <label className="check"><input type="checkbox" checked={active.auto} onChange={(e) => { const v = e.target.checked; setStories((all) => all.map((s) => (s.id === active.id ? { ...s, auto: v } : s))) }} /> Add pages when the text runs over</label>
          </div>
        )}
        <button onMouseDown={keep} disabled={!active} onClick={() => setPlain(plain === null && active ? toMarkdown(active.state.doc) : null)}>{plain === null ? 'Plain text and spellcheck' : 'Close plain text'}</button>
        {plain !== null && active && (
          <label>This story as plain text
            <textarea aria-label="This story as plain text" spellCheck value={plain} onChange={(e) => {
              const v = e.target.value
              setPlain(v)
              edit((s) => replaceDoc(s, fromMarkdown(v)))
            }} />
          </label>
        )}

        <button className={'primary generate' + (stale ? ' stale' : '')} onClick={() => setGrown(requests)}>{growing ? 'Generating…' : stale ? 'Generate' : 'Up to date'}</button>
        <p className="hint">{stale ? 'The drawing is behind your changes. It only changes when you click.' : 'The drawing stays put until you ask for a new one.'}</p>
        <button onClick={() => { setSeed((s) => s + 1); setGrowTick((t) => t + 1) }}>Grow a different one</button>
        <div className="row">
          <label>What grows
            <select value={grows} onChange={(e) => { const g = e.target.value as Grows; setGrows(g); setInkName(g === 'oak' ? 'green' : 'blue') }}>
              <option value="gym">Cat gym</option>
              <option value="oak">One huge oak</option>
              <option value="cats">Old cats</option>
            </select>
          </label>
          <label>Ink
            <select value={inkName} onChange={(e) => setInkName(e.target.value as 'green' | 'blue')}>
              <option value="green">Green</option>
              <option value="blue">Delft blue</option>
            </select>
          </label>
        </div>
        {grows === 'oak' && (
          <>
            <label>Crown
              <select value={crown} onChange={(e) => setCrown(e.target.value as 'lush' | 'open')}>
                <option value="lush">Lush</option>
                <option value="open">Open, limbs showing</option>
              </select>
            </label>
            <label>Season
              <select value={season} onChange={(e) => setSeason(e.target.value as Season)}>
                {SEASONS.map((v) => <option key={v} value={v}>{v[0].toUpperCase() + v.slice(1)}</option>)}
              </select>
            </label>
            <label className="check"><input type="checkbox" checked={spanishmoss} onChange={(e) => setSpanishmoss(e.target.checked)} /> Spanish moss</label>
          </>
        )}
        <label>Size
          <select value={sizeKey} onChange={(e) => changeSize(e.target.value as SizeKey)}>
            {Object.entries(SIZES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
        </label>
        <p className="hint">{S.px} × {Math.round(S.px * S.h / S.w)} px as a PNG. Changing it grows a new drawing.</p>
        <div className="margins" onFocus={() => { marginStart.current ??= { margins, drawn } }} onBlur={() => { marginStart.current = null }}>
          <span>Margins, in cm</span>
          <div className="row">
            {(['top', 'bottom', 'left', 'right'] as const).map((side) => (
              <NumberField key={side} label={side[0].toUpperCase() + side.slice(1)} min={0} max={marginLimit(margins, sizeKey, side)} step={0.1}
                value={margins[side]} onChange={(v) => changeMargin(side, v)} />
            ))}
          </div>
          <p className="hint">The dotted line on each page. A box touching it moves with it, and boxes snap to it as you drag. You can still drag a box past it.</p>
        </div>
        <label>Typeface
          <select value={family} onChange={(e) => setFamily(e.target.value)}>
            {FAMILIES.map((f) => <option key={f.css} value={f.css}>{f.label}</option>)}
          </select>
        </label>
        <label>Text color
          <input type="color" value={textColor} onChange={(e) => setTextColor(e.target.value)} />
        </label>
        <div className="row">
          <NumberField label="Type size" min={10} max={90} value={fontSize} onChange={setFontSize} />
          <NumberField label="Cats a page" min={0} max={6} value={cats} onChange={setCats} />
          <NumberField label="Piece size" min={0.8} max={2.5} step={0.1} value={pieces} onChange={setPieces} />
          <NumberField label="Seed" min={1} max={1e9} value={seed} onChange={setSeed} />
        </div>
        <button onClick={() => setDrawn((d) => [...d, []])}>Add a page</button>
        <div className="row three">
          <button className="primary" disabled={!!busy} onClick={exportPngs}>PNGs</button>
          <button className="primary" disabled={!!busy || !face.files} onClick={exportPdf}>PDF</button>
          <button className="primary" disabled={!!busy} onClick={exportHtml}>HTML</button>
        </div>
        <p className="hint">{busy || note || `${pages.length} page${pages.length === 1 ? '' : 's'}. ${face.files ? 'PDF and HTML keep real text you can select.' : `For a PDF, choose IM Fell or Florilegium Roman: a browser can only embed fonts that come with the app. An HTML file shows ${face.label} only to readers who have it.`}`}</p>
        {overflow && <p className="error" role="alert">Some text runs past the bottom of its box (marked in red): make the box bigger, or flow it into another.</p>}
        <div className="row three">
          <button onClick={() => download(docFile(doc), `${fileBase}.studio.json`)}>Save file</button>
          <button onClick={() => opener.current?.click()}>Open file</button>
          <button onClick={() => { if (window.confirm('Start over? This clears the stories and boxes kept in this browser.')) applyDoc(newDoc()) }}>Start over</button>
        </div>
        <input ref={opener} type="file" accept=".json,application/json" hidden aria-label="Open a studio file"
          onChange={(e) => { void openFile(e.target.files?.[0]); e.target.value = '' }} />
        <p className="hint">{unsaved ? 'This browser is out of room, so your latest changes are not kept here: save a file.' : 'Kept in this browser as you work. Save a file to keep it anywhere else.'}</p>
        {error && <p className="error" role="alert">{error}</p>}
      </aside>
      <main className="pages">
        {linking !== null && (
          <div className="banner" role="status">
            <span>Click the box to link, or draw a new one. Text flows through linked boxes in page order.</span>
            <button onClick={() => setLinking(null)}>Cancel</button>
          </div>
        )}
        {pages.map((p, i) => {
          const m = marks.get(i)
          return (
            <PageView key={i} index={i} page={p} W={W} H={H} margins={margins} style={style} gym={gyms[i]} growing={growing}
              svgRef={(el) => { svgs.current[i] = el }} caretRef={caretEl} caret={focused ? m?.caret : undefined} composition={composition} rects={m?.rects ?? []}
              linking={linking !== null} activeStory={activeId} selectedId={selected?.page === i ? selected.id : null}
              chainLabel={(b) => { const ch = chainOf(b.story); return ch.length > 1 ? `${ch.findIndex((c) => c.page === i && c.id === b.id) + 1}/${ch.length}` : '' }}
              setDragging={setDragging} editPage={editPage} drawBox={drawBox} afterDraw={afterDraw} startText={startText} removeBox={removeBox} removePage={drawn.length > 1 && i < drawn.length ? () => removePage(i) : undefined} select={(id) => setSelected({ page: i, id })}
              startLink={(b) => { setSelected({ page: i, id: b.id }); setActiveId(b.story); setLinking(linking === null ? b.story : null) }} />
          )
        })}
      </main>
      <textarea ref={typing} className="typing" aria-label="Text of the box you are editing" autoComplete="off" autoCorrect="off" autoCapitalize="off" spellCheck={false}
        onKeyDown={onKey} onInput={() => { if (composition === null) syncTyping() }} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
        onCompositionStart={() => setComposition('')}
        onCompositionUpdate={(e) => setComposition(e.data)}
        onCompositionEnd={() => { setComposition(null); syncTyping() }}
        onCopy={(e) => onCopy(e, false)} onCut={(e) => onCopy(e, true)} onPaste={onPaste} />
    </div>
  )
}

function AlignIcon({ align }: { align: Align }) {
  const rows = [14, 9, 12, 7].map((w, i) => {
    const width = align === 'justify' ? 14 : w
    const x = align === 'left' || align === 'justify' ? 1 : align === 'right' ? 15 - width : (16 - width) / 2
    return <rect key={i} x={x} y={2 + i * 3.4} width={width} height={1.5} />
  })
  return <svg viewBox="0 0 16 16" width="14" height="14" fill="currentColor" aria-hidden="true">{rows}</svg>
}

// You can clear a field and type: the page follows whenever what's there is a usable number, and
// leaving the field puts back the nearest one. A whole-number field unless it has a step.
function NumberField({ label, value, min, max, step, onChange }: {
  label: string; value: number; min: number; max: number; step?: number; onChange: (v: number) => void
}) {
  const [draft, setDraft] = useState<string | null>(null)
  const usable = (t: string) => {
    const v = t.trim() === '' ? NaN : +t
    return Number.isFinite(v) && v >= min && v <= max && (step !== undefined || Number.isInteger(v)) ? v : null
  }
  return (
    <label>{label}
      <input type="number" min={min} max={max} step={step} value={draft ?? value}
        onChange={(e) => {
          setDraft(e.target.value)
          const v = usable(e.target.value)
          if (v !== null) onChange(v)
        }}
        onBlur={() => {
          if (draft !== null && usable(draft) === null && draft.trim() !== '' && Number.isFinite(+draft)) {
            const near = Math.max(min, Math.min(max, +draft))
            onChange(step === undefined ? Math.round(near) : near)
          }
          setDraft(null)
        }} />
    </label>
  )
}

function LinesOf({ lines, style }: { lines: Line[]; style: TextStyle }) {
  return (
    <g fontFamily={style.family} fill={style.color} style={{ pointerEvents: 'none' }}>
      {lines.flatMap((l, i) => l.runs.map((r, j) => (
        <text key={`${i}.${j}`} x={r.x} y={l.y} fontSize={l.size} fontWeight={r.bold ? 700 : 400} fontStyle={r.italic ? 'italic' : 'normal'}>{r.text}</text>
      )))}
    </g>
  )
}

function PageView({ index, page, W, H, margins, style, gym, growing, svgRef, caretRef, caret, composition, rects, linking, activeStory, selectedId, chainLabel, setDragging, editPage, drawBox, afterDraw, startText, removeBox, removePage, select, startLink }: {
  index: number; page: FlowPage; W: number; H: number; margins: Margins; style: TextStyle; gym?: string; growing: boolean
  svgRef: (el: SVGSVGElement | null) => void; caretRef: React.RefObject<SVGLineElement | null>
  caret?: Caret; composition: string | null; rects: { x: number; y: number; w: number; h: number }[]
  linking: boolean; activeStory: number | null; selectedId: number | null; chainLabel: (b: Box) => string
  setDragging: (b: boolean) => void; editPage: (page: number, fn: (b: Box[]) => Box[]) => void
  drawBox: (page: number, x: number, y: number) => number; afterDraw: (page: number, id: number, ok: boolean) => void
  startText: (e: React.PointerEvent, page: number, box: Box) => void; removeBox: (page: number, box: Box) => void
  removePage?: () => void; select: (id: number) => void; startLink: (b: Box) => void
}) {
  const ref = useRef<SVGSVGElement | null>(null)
  const drag = useRef<Drag | null>(null)
  const scale = 420 / W
  const left = margins.left * CM, right = W - margins.right * CM, top = margins.top * CM, bottom = H - margins.bottom * CM
  const pull = 6 / scale      // how near a margin a dragged edge snaps to it
  const snap = (v: number, ...lines: number[]) => lines.find((l) => Math.abs(v - l) < pull) ?? v
  const url = useMemo(() => (gym ? URL.createObjectURL(new Blob([gym], { type: 'image/svg+xml' })) : ''), [gym])
  useEffect(() => () => { if (url) URL.revokeObjectURL(url) }, [url])
  const at = (e: React.PointerEvent) => {
    const r = ref.current!.getBoundingClientRect()
    return { x: (e.clientX - r.left) * W / r.width, y: (e.clientY - r.top) * H / r.height }
  }
  const begin = (e: React.PointerEvent, d: Drag) => {
    e.preventDefault()
    e.stopPropagation()
    ref.current!.setPointerCapture(e.pointerId)
    drag.current = d
    setDragging(true)
  }
  const onDown = (e: React.PointerEvent) => {
    const p = at(e)
    const x0 = snap(p.x, left, right), y0 = snap(p.y, top, bottom)
    const id = drawBox(index, x0, y0)
    begin(e, { kind: 'draw', page: index, x0, y0, id })
  }
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d) return
    const p = at(e)
    const clampX = (v: number) => Math.max(0, Math.min(W, v)), clampY = (v: number) => Math.max(0, Math.min(H, v))
    editPage(d.page, (bs) => bs.map((b) => {
      if (b.id !== d.id) return b
      if (d.kind === 'draw') {
        const x = snap(clampX(p.x), left, right), y = snap(clampY(p.y), top, bottom)
        return { ...b, x: Math.min(d.x0, x), y: Math.min(d.y0, y), w: Math.abs(x - d.x0), h: Math.abs(y - d.y0) }
      }
      if (d.kind === 'move') {
        const x = clampX(p.x - d.dx), y = clampY(p.y - d.dy)
        return {
          ...b,
          x: Math.abs(x + b.w - right) < pull ? right - b.w : snap(x, left),
          y: Math.abs(y + b.h - bottom) < pull ? bottom - b.h : snap(y, top),
        }
      }
      return { ...b, w: Math.max(30, snap(clampX(p.x), right) - b.x), h: Math.max(20, snap(clampY(p.y), bottom) - b.y) }
    }))
  }
  const onUp = () => {
    const d = drag.current
    if (!d) return
    drag.current = null
    if (d.kind === 'draw') {
      const b = page.boxes.find((x) => x.id === d.id)
      afterDraw(d.page, d.id, !!b && b.w > 30 && b.h > 20)
    }
    setDragging(false)
  }
  return (
    <div className="pagewrap">
      <div className="pagelabel"><span>Page {index + 1}{page.auto ? ' (text ran on)' : ''}</span>
        {removePage && <button className="link" onClick={removePage}>Delete page</button>}
      </div>
      <div className={'stage' + (growing ? ' growing' : '')} style={{ width: W * scale, height: H * scale }}>
        <svg className="under" viewBox={`0 0 ${W} ${H}`} aria-hidden="true"><LinesOf lines={page.lines.filter((l) => l.layer === 'behind')} style={style} /></svg>
        {url && <img src={url} alt="" />}
        <svg ref={(el) => { ref.current = el; svgRef(el) }} className={'ink' + (linking ? ' linking' : '')} viewBox={`0 0 ${W} ${H}`} role="application" aria-label={`Page ${index + 1}`}
          onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
          <rect className="guide" x={left} y={top} width={right - left} height={bottom - top} />
          {rects.map((r, i) => <rect key={i} className="selection" x={r.x} y={r.y} width={r.w} height={r.h} />)}
          <LinesOf lines={page.lines.filter((l) => l.layer !== 'behind')} style={style} />
          {page.boxes.map((b) => {
            const handle = 10 / scale, dr = 9 / scale
            const label = chainLabel(b)
            const over = page.over.has(b.id)
            const shown = over ? Math.max(b.h, page.used.get(b.id) ?? 0) : b.h
            const cls = 'box' + (b.story === activeStory ? ' live' : '') + (b.id === selectedId ? ' picked' : '') + (over ? ' overflow' : '')
            return (
              <g key={b.id}>
                <rect className={cls} x={b.x} y={b.y} width={b.w} height={shown}
                  onPointerDown={(e) => startText(e, index, b)} />
                <rect className="edge" x={b.x - 3 / scale} y={b.y - 3 / scale} width={b.w + 6 / scale} height={b.h + 6 / scale}
                  onPointerDown={(e) => { const p = at(e); select(b.id); begin(e, { kind: 'move', page: index, id: b.id, dx: p.x - b.x, dy: p.y - b.y }) }} />
                <rect className="handle" x={b.x + b.w - handle / 2} y={b.y + b.h - handle / 2} width={handle} height={handle}
                  onPointerDown={(e) => { select(b.id); begin(e, { kind: 'size', page: index, id: b.id, dx: 0, dy: 0 }) }} />
                <circle className="del" cx={b.x + b.w} cy={b.y} r={dr} role="button" aria-label="Delete this text box"
                  onPointerDown={(e) => { e.preventDefault(); e.stopPropagation(); removeBox(index, b) }} />
                <path className="delx" d={`M${b.x + b.w - dr / 2} ${b.y - dr / 2}l${dr} ${dr}m0 ${-dr}l${-dr} ${dr}`} />
                <g className="linker" role="button" aria-label="Link this box to another" onPointerDown={(e) => { e.preventDefault(); e.stopPropagation(); startLink(b) }}>
                  <title>Link this box to another, so text flows between them</title>
                  <circle cx={b.x + b.w} cy={b.y + b.h / 2} r={dr} />
                  <path d={`M${b.x + b.w - dr * 0.5} ${b.y + b.h / 2}h${dr}m${-dr * 0.4} ${-dr * 0.4}l${dr * 0.4} ${dr * 0.4}l${-dr * 0.4} ${dr * 0.4}`} />
                </g>
                {label && <text className="chain" x={b.x} y={b.y - 5 / scale} fontSize={11 / scale}>{label}</text>}
              </g>
            )
          })}
          {caret && composition && <text className="composition" x={caret.x} y={caret.base} fontSize={caret.size} fontFamily={style.family} fill={style.color}>{composition}</text>}
          {caret && <line ref={caretRef} className="caret" x1={caret.x} x2={caret.x} y1={caret.y0} y2={caret.y1} />}
        </svg>
      </div>
    </div>
  )
}

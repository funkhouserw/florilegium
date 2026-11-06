// Felilegium: draw boxes on a page and type in them. A new box carries on the text you were writing, or
// is unlinked to hold a story of its own; the text flows as you type, and the drawing grows around the boxes
// when you ask. Your work is kept in this browser as you go, and in a file when you ask.
import { memo, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react'
import { EditorState, type Transaction } from 'prosemirror-state'
import { blockAt, deleteBack, deleteForward, enter, marksHere, newState, redo, replaceBefore, replaceDoc, run, selectAll, selectRange, selectTo, setAlign, setBlock, step, toggle, toggleList, undo, wordAt } from './editor'
import { flow, fontOf, lineOfPos, posOfX, remeasure, xOfPos, type Box, type FlowPage, type Layer, type Line, type TextStyle } from './flow'
import { growGym } from './gym'
import { download, pagePng, pagesToHtml, pagesToPdf } from './exporter'
import { CM, docFile, fitMargins, followMargins, loadDoc, marginLimit, newBoxId, newDoc, newStoryDoc, newStoryId, readDocFile, resizeBoxes, saveDoc, SEASONS, SIZES, type Doc, type Grows, type Margins, type PerPage, type Season, type SizeKey } from './doc'
import { familyOf, FAMILIES } from './fonts'
import { fromMarkdown, sliceFromHtml, sliceFromMarkdown, sliceToHtml, sliceToText, toMarkdown, type Align } from './schema'

const PAPER = '#fefdfb'
const FLOWER_SEASONS: Season[] = ['spring', 'summer', 'autumn']   // the flowers have no winter: it shows as autumn
type Story = { id: number; state: EditorState; auto: boolean }
const storiesOf = (d: Doc): Story[] => d.stories.map((s) => ({ id: s.id, state: newState(s.doc), auto: s.auto }))
const initial = loadDoc()
const mac = /Mac|iPhone|iPad/.test(navigator.platform)

type Drag =
  | { kind: 'draw'; page: number; x0: number; y0: number; id: number; pid?: number }
  | { kind: 'move' | 'size'; page: number; id: number; dx: number; dy: number; pid?: number; orig?: Box }
type Caret = { x: number; y0: number; y1: number; base: number; size: number }
type TextDrag = { story: number; anchor: number; unit: 'char' | 'word' | 'block'; lo: number; hi: number }

// The pages' zoom is the canvas's own, kept apart from the panel and from the browser's zoom
const ZOOMS = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 3, 4]
const ZOOM_KEY = 'felilegium-zoom'
const clampZoom = (z: number) => Math.max(ZOOMS[0], Math.min(ZOOMS[ZOOMS.length - 1], +z.toFixed(3)))
const PAGE_PX = 420             // a page's width on screen at 100%
const NARROW = '(max-width: 760px), (pointer: coarse) and (max-height: 500px)'   // a phone, either way up (style.css too)
type Tab = 'text' | 'drawing' | 'page' | 'export'
const TABS: [Tab, string][] = [['text', 'Text'], ['drawing', 'Drawing'], ['page', 'Page'], ['export', 'Export']]
function useMedia(query: string) {
  const [on, setOn] = useState(() => window.matchMedia(query).matches)
  useEffect(() => {
    const m = window.matchMedia(query), f = () => setOn(m.matches)
    m.addEventListener('change', f)
    return () => m.removeEventListener('change', f)
  }, [query])
  return on
}

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
  const [perPage, setPerPage] = useState<PerPage>(initial.perPage)
  // phones: the panel is a sheet over the pages, one tab at a time (null: closed)
  const narrow = useMedia(NARROW)
  const coarse = useMedia('(pointer: coarse)')          // a finger: taps type, a drag scrolls, a box is drawn in draw mode
  const [tab, setTab] = useState<Tab | null>(null)
  const [drawArm, setDrawArm] = useState(false)
  // a sheet shows when there's more below (a fade) and, scrolled down the Drawing sheet, keeps Generate at its top
  const sheet = useRef<HTMLElement | null>(null)
  const [sheetScroll, setSheetScroll] = useState({ down: false, more: false })
  const readSheet = () => {
    const el = sheet.current
    if (!el) return
    const next = { down: el.scrollTop > 70, more: el.scrollTop + el.clientHeight < el.scrollHeight - 4 }
    setSheetScroll((o) => (o.down === next.down && o.more === next.more ? o : next))
  }
  useLayoutEffect(readSheet)
  const [shareFiles, setShareFiles] = useState<File[] | null>(null)
  const [readyPage, setReadyPage] = useState<{ index: number; file: File } | null>(null)
  const [savingPage, setSavingPage] = useState<number | null>(null)
  const [scale2x, setScale2x] = useState(2)                  // PNGs at 1, 2 or 3 times the size's pixels
  const [textColor, setTextColor] = useState(initial.textColor)
  const [margins, setMargins] = useState<Margins>(initial.margins)
  const [drawn, setDrawn] = useState<Box[][]>(initial.drawn)
  const S = SIZES[sizeKey]
  const W = S.w * CM, H = S.h * CM
  // a drag in progress holds off saving; a flag, not state, so picking up a box doesn't redraw every page
  const dragging = useRef(false)
  const setDragging = (b: boolean) => { dragging.current = b }
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
  const [zoom, setZoom] = useState(() => { const z = Number(localStorage.getItem(ZOOM_KEY)); return z > 0 ? clampZoom(z) : 1 })
  const pagesEl = useRef<HTMLElement | null>(null)
  const anchor = useRef<{ page: number; fx: number; fy: number; cx: number; cy: number } | null>(null)
  // zoom about a point on screen, so what is under it stays under it
  function zoomTo(next: number | ((z: number) => number), cx?: number, cy?: number) {
    const el = pagesEl.current
    if (el) {
      const r = el.getBoundingClientRect()
      const x = cx ?? r.left + r.width / 2, y = cy ?? r.top + r.height / 2
      const stage = (document.elementFromPoint(x, y) as Element | null)?.closest<HTMLElement>('.stage')
      if (stage) {
        const s = stage.getBoundingClientRect()
        anchor.current = { page: Number(stage.dataset.page), fx: (x - s.left) / s.width, fy: (y - s.top) / s.height, cx: x, cy: y }
      }
    }
    setZoom((z) => clampZoom(typeof next === 'function' ? next(z) : next))
  }
  useLayoutEffect(() => {
    try { localStorage.setItem(ZOOM_KEY, String(zoom)) } catch { /* not kept */ }
    const a = anchor.current, el = pagesEl.current
    anchor.current = null
    const stage = a && el?.querySelector<HTMLElement>(`.stage[data-page="${a.page}"]`)
    if (!a || !el || !stage) return
    const s = stage.getBoundingClientRect()
    el.scrollBy(s.left + a.fx * s.width - a.cx, s.top + a.fy * s.height - a.cy)
  }, [zoom])
  const zoomStep = (dir: 1 | -1) => zoomTo((z) => (dir > 0 ? ZOOMS.find((v) => v > z + 1e-3) : [...ZOOMS].reverse().find((v) => v < z - 1e-3)) ?? z)
  const stepRef = useRef(zoomStep)
  stepRef.current = zoomStep
  useEffect(() => {
    const el = pagesEl.current
    if (!el) return
    // a pinch on a trackpad arrives as a wheel with ctrl held
    const wheel = (e: WheelEvent) => {
      if (!e.ctrlKey && !e.metaKey) return
      e.preventDefault()
      zoomTo((z) => z * Math.exp(-e.deltaY * 0.01), e.clientX, e.clientY)
    }
    const keys = (e: KeyboardEvent) => {
      if (!(e.metaKey || e.ctrlKey) || e.altKey) return
      if (e.key === '=' || e.key === '+') stepRef.current(1)
      else if (e.key === '-') stepRef.current(-1)
      else if (e.key === '0') zoomTo(1)
      else return
      e.preventDefault()
    }
    el.addEventListener('wheel', wheel, { passive: false })
    window.addEventListener('keydown', keys)
    return () => { el.removeEventListener('wheel', wheel); window.removeEventListener('keydown', keys) }
  }, [])   // eslint-disable-line react-hooks/exhaustive-deps
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
  const fileBase = title.normalize('NFD').replace(/\p{M}/gu, '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'felilegium'
  const boxCount = (story: number) => drawn.reduce((n, p) => n + p.filter((b) => b.story === story).length, 0)

  // kept in this browser as you work; a full disk must not stop the work
  const doc: Doc = useMemo(() => ({ stories: texts, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, perPage, textColor, margins, drawn }),
    [texts, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, perPage, textColor, margins, drawn])
  // PNGs made ready to save or share are of the work as it was: a change puts them away
  useEffect(() => { setShareFiles(null); setReadyPage(null) }, [doc, scale2x])
  docNow.current = doc
  const note = noted && noted.doc === doc ? noted.text : ''      // a note lasts until the work changes
  useEffect(() => {
    const timer = setTimeout(() => {
      if (dragging.current) return                                   // the drop changes the work, and saves it
      try { saveDoc(doc); setUnsaved(false) } catch { setUnsaved(true) }
    }, 300)
    return () => clearTimeout(timer)
  }, [doc])
  function applyDoc(d: Doc) {
    setStories(storiesOf(d)); setSizeKey(d.sizeKey); setFamily(d.family); setFontSize(d.fontSize); setSeed(d.seed); setCats(d.cats); setPieces(d.pieces)
    setGrows(d.grows); setInkName(d.inkName); setCrown(d.crown); setSeason(d.season); setSpanishmoss(d.spanishmoss); setPerPage(d.perPage); setTextColor(d.textColor); setMargins(d.margins); setDrawn(d.drawn)
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
  // the strip shows while typing; a tap on it blurs the field for a moment, so it outlasts the blur a little
  const [editing, setEditing] = useState(false)
  useEffect(() => {
    if (focused) { setEditing(true); return }
    const t = setTimeout(() => setEditing(false), 300)
    return () => clearTimeout(t)
  }, [focused])
  // how far the keyboard covers the page (iOS leaves the layout its full height under it)
  const [kb, setKb] = useState(0)
  useEffect(() => {
    const vv = window.visualViewport
    if (!vv) return
    const f = () => setKb(Math.max(0, window.innerHeight - vv.height - vv.offsetTop))
    vv.addEventListener('resize', f)
    vv.addEventListener('scroll', f)
    return () => { vv.removeEventListener('resize', f); vv.removeEventListener('scroll', f) }
  }, [])
  // a phone fits a page to the screen's width, again whenever the width changes (not the height: the keyboard);
  // held sideways, the whole page
  const aspect = useRef(1)
  aspect.current = H / W
  useEffect(() => {
    const el = pagesEl.current
    if (!narrow || !el) return
    let w = 0
    const ro = new ResizeObserver(() => {
      if (Math.abs(el.clientWidth - w) < 2) return
      w = el.clientWidth
      const byWidth = (w - 24) / PAGE_PX, byHeight = (el.clientHeight - 48) / (PAGE_PX * aspect.current)
      setZoom(clampZoom(w > window.innerHeight ? Math.min(byWidth, byHeight) : byWidth))
    })
    ro.observe(el)
    return () => ro.disconnect()
  }, [narrow])
  // two fingers zoom the pages about the point between them (the browser's own pinch is off, so one finger scrolls)
  const zoomAt = useRef(zoomTo)
  zoomAt.current = zoomTo
  const zoomNow = useRef(zoom)
  zoomNow.current = zoom
  useEffect(() => {
    const el = pagesEl.current
    if (!el) return
    let start: { d: number; z: number } | null = null
    const dist = (t: TouchList) => Math.hypot(t[0].clientX - t[1].clientX, t[0].clientY - t[1].clientY)
    const down = (e: TouchEvent) => { if (e.touches.length === 2) { start = { d: dist(e.touches), z: zoomNow.current }; e.preventDefault() } }
    const move = (e: TouchEvent) => {
      if (!start || e.touches.length !== 2) return
      e.preventDefault()
      const [a, b] = [e.touches[0], e.touches[1]]
      zoomAt.current(start.z * dist(e.touches) / start.d, (a.clientX + b.clientX) / 2, (a.clientY + b.clientY) / 2)
    }
    const up = (e: TouchEvent) => { if (e.touches.length < 2) start = null }
    el.addEventListener('touchstart', down, { passive: false })
    el.addEventListener('touchmove', move, { passive: false })
    el.addEventListener('touchend', up)
    el.addEventListener('touchcancel', up)
    return () => { el.removeEventListener('touchstart', down); el.removeEventListener('touchmove', move); el.removeEventListener('touchend', up); el.removeEventListener('touchcancel', up) }
  }, [])
  useEffect(() => {
    if (!tab || !narrow) return
    const away = (e: PointerEvent) => {
      const t = e.target as Element
      if (t.closest?.('#sheet, .tabs')) return
      setTab(null)
      if (!t.closest?.('.pages')) return                       // a button elsewhere still does its job
      e.stopPropagation()
      const eat = (c: Event) => { c.stopPropagation(); c.preventDefault() }
      window.addEventListener('click', eat, { capture: true, once: true })
      setTimeout(() => window.removeEventListener('click', eat, { capture: true }), 600)
    }
    window.addEventListener('pointerdown', away, { capture: true })
    return () => window.removeEventListener('pointerdown', away, { capture: true })
  }, [tab, narrow])
  useEffect(() => {
    if (!tab) return
    const esc = (e: KeyboardEvent) => { if (e.key === 'Escape') setTab(null) }
    window.addEventListener('keydown', esc)
    return () => window.removeEventListener('keydown', esc)
  }, [tab])
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

  function startText(e: React.PointerEvent | React.MouseEvent, page: number, box: Box, drag = true) {
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
    if (!drag) return
    window.addEventListener('pointermove', dragText)
    window.addEventListener('pointerup', endText, { once: true })
    window.addEventListener('pointercancel', endText, { once: true })
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
  // composing: a phone's keyboard keeps the word in progress open, and may reopen one the story already has, so the
  // story follows the field as it changes; the field itself is left alone until the word is done
  function syncTyping(composing = false) {
    const ta = typing.current
    if (!ta) return
    const old = lastTyped.current, now = ta.value
    if (old === now) return
    let i = 0
    while (i < old.length && i < now.length && old[i] === now[i]) i++
    if (i > 0 && /[\uD800-\uDBFF]/.test(old[i - 1])) i--          // never halfway through an emoji
    const removed = old.length - i, added = now.slice(i)
    if (composing) lastTyped.current = now
    else {
      const kept = now.slice(-8)
      ta.value = kept
      lastTyped.current = kept
    }
    goalX.current = null
    // a selection seeded into the field (touch) is what `removed` takes away
    edit((s) => (s.selection.empty ? replaceBefore(s, removed, added) : added ? s.tr.insertText(added) : s.tr.deleteSelection()))
  }
  // on a touch screen the field holds the text just before the cursor (and the selection, selected), so a keyboard's
  // backspace, autocorrect and predictions work on real text; never while a word is being composed
  useLayoutEffect(() => {
    const ta = typing.current
    if (!coarse || !ta || !active || composition !== null) return
    const { $from, $to, empty } = active.state.selection
    const before = $from.parent.textBetween(Math.max(0, $from.parentOffset - 16), $from.parentOffset)
    const v = before + (!empty && $from.sameParent($to) ? $from.parent.textBetween($from.parentOffset, $to.parentOffset) : '')
    if (ta.value !== v || ta.selectionStart !== before.length || ta.selectionEnd !== v.length) {
      ta.value = v
      ta.setSelectionRange(before.length, v.length)
      lastTyped.current = v
    }
  })
  // what a keyboard asks for without a key code (Android sends 229): a backspace with nothing in the field to take,
  // or one across paragraphs, and a new paragraph
  const beforeInput = useRef<(e: InputEvent) => void>(() => {})
  beforeInput.current = (e: InputEvent) => {
    const ta = typing.current
    if (e.isComposing || !ta || !active) return
    const sel = active.state.selection
    if (e.inputType === 'deleteContentBackward' && ((ta.selectionStart === 0 && ta.selectionEnd === 0) || (!sel.empty && !sel.$from.sameParent(sel.$to)))) {
      e.preventDefault(); forgetTyped(); edit((s) => deleteBack(s, false, null))
    } else if (e.inputType === 'insertParagraph' || e.inputType === 'insertLineBreak') {
      e.preventDefault(); forgetTyped(); edit(enter)
    }
  }
  useEffect(() => {
    const ta = typing.current
    if (!ta) return
    const f = (e: Event) => beforeInput.current(e as InputEvent)
    ta.addEventListener('beforeinput', f)
    return () => ta.removeEventListener('beforeinput', f)
  }, [])
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
    const key = `${activeId}:${active?.state.selection.head}:${active?.state.doc.content.size}`
    const follow = focused && key !== followed.current                                    // not when you scroll away yourself
    followed.current = key
    if (coarse) {
      // a field near the keyboard makes iOS scroll the whole window to it, so it stays at the top
      t.style.left = '0px'
      t.style.top = '0px'
      const el = pagesEl.current, vv = window.visualViewport
      if (!follow || !el) return
      const bottom = (vv ? vv.offsetTop + vv.height : window.innerHeight) - 64, top = el.getBoundingClientRect().top + 8
      if (r.bottom > bottom) el.scrollTop += r.bottom - bottom
      else if (r.top < top) el.scrollTop -= top - r.top
      return
    }
    t.style.left = `${r.left}px`
    t.style.top = `${r.top}px`
    if (follow) c.scrollIntoView({ block: 'nearest', inline: 'nearest' })
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
  // A new box carries on the text you're in, or else the nearest text before it. Unlinking is one click.
  function storyToContinue(page: number) {
    if (activeId !== null && boxCount(activeId) > 0) return activeId
    const lastOn = (i: number) => pages[i]?.boxes[pages[i].boxes.length - 1]?.story
    for (let i = page; i >= 0; i--) { const s = lastOn(i); if (s !== undefined) return s }
    for (let i = page + 1; i < pages.length; i++) { const s = pages[i].boxes[0]?.story; if (s !== undefined) return s }
    return null
  }
  function drawBox(page: number, x: number, y: number) {
    const id = newBoxId()
    let story = linking ?? storyToContinue(page)
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
    } else {
      // the cursor goes to what the new box now holds, or to the end of the text if it reaches no further
      const box = pages[page]?.boxes.find((b) => b.id === id)
      if (box) {
        const first = (byStory.get(box.story) ?? []).find((l) => l.page === page && l.box === id)
        forgetTyped()
        goalX.current = null
        update(box.story, (st) => selectTo(st, first ? first.from : st.doc.content.size - 1, false))
      }
      focusTyping()
    }
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
    setSelected({ page, id: box.id })
    forgetTyped()
    focusTyping()
  }
  const selectedBox = selected ? pages[selected.page]?.boxes.find((b) => b.id === selected.id) ?? null : null
  const setLayer = (layer: Layer) => { if (selected) editPage(selected.page, (bs) => bs.map((b) => (b.id === selected.id ? { ...b, layer } : b))) }
  const chainOf = (story: number) => pages.flatMap((p, i) => p.boxes.filter((b) => b.story === story).map((b) => ({ page: i, id: b.id })))

  // ---- the drawing: it changes only when you ask ----
  const requests = useMemo(() => pages.map((p, index) => ({
    // page: whose drawing a page grows, its own or (perPage 'match') every page's, so pages laid out alike match;
    // flowers: the work's seed picks its plants, the page its garden
    grows, ink: inkName, crown, season, spanishmoss, w: S.w, h: S.h, page: perPage === 'match' ? 0 : index,
    seed: grows === 'flowers' || perPage === 'match' ? seed : seed + index * 101, cats,
    size: grows === 'gym' || grows === 'flowers' ? pieces : 1, density: 1, index,
    keepouts: p.boxes.filter((b) => b.layer === 'clear').map((b) => {
      const empty = !texts.find((t) => t.id === b.story)?.doc.textContent.trim()
      const h = empty ? b.h : p.used.get(b.id) ?? 0
      if (h <= 0) return null
      const pad = fontSize * 0.5                       // a little air around the text, and its descenders
      return [b.x - pad, H - (b.y + h + pad), b.x + b.w + pad, H - b.y + pad].map((v) => +(v / CM).toFixed(2))
    }).filter((q): q is number[] => q !== null),
  })), [pages, S, seed, cats, pieces, H, texts, fontSize, grows, inkName, crown, season, spanishmoss, perPage])
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
  // a PNG's width: the size's pixels times 1, 2 or 3, within what a phone's canvas holds (about 16 million pixels)
  const pngWidth = Math.round(Math.min(S.px * scale2x, Math.sqrt(16e6 * W / H)))
  const shareOut = (files: File[]) => {
    navigator.share({ files }).catch((e: Error) => { if (e.name !== 'AbortError') { setError('Sharing failed: ' + e.message); files.forEach((f) => download(f, f.name)) } })
  }
  async function savePage(i: number) {
    setError('')
    catchUp()
    setSavingPage(i)
    try {
      const png = await pagePng(await growGym(requests[i]), pages[i], style, pngWidth, W, H, PAPER)
      const file = new File([png], `${fileBase}-${i + 1}.png`, { type: 'image/png' })
      if (coarse && typeof navigator.canShare === 'function' && navigator.canShare({ files: [file] })) setReadyPage({ index: i, file })
      else download(file, file.name)
    } catch (e) { setError('Saving the page failed: ' + String(e)) } finally { setSavingPage(null) }
  }
  async function exportPngs() {
    setNote('')
    catchUp()
    try {
      const files: File[] = []
      const sharing = coarse && typeof navigator.canShare === 'function'
      for (let i = 0; i < pages.length; i++) {
        setBusy(`Page ${i + 1} of ${pages.length}`)
        const png = await pagePng(await growGym(requests[i]), pages[i], style, pngWidth, W, H, PAPER)
        if (sharing) files.push(new File([png], `${fileBase}-${i + 1}.png`, { type: 'image/png' }))
        else download(png, `${fileBase}-${i + 1}.png`)
      }
      if (sharing && navigator.canShare({ files })) setShareFiles(files)        // Save and Share, both a fresh tap away
      else files.forEach((f) => download(f, f.name))
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

  // the strip above a phone's keyboard: each tap acts and gives the keyboard straight back (still inside the tap)
  const stripTool = (label: React.ReactNode, t: string, pressed: boolean, fn: (s: EditorState) => Transaction | null) => (
    <button key={t} className={pressed ? 'on' : ''} title={t} aria-label={t} aria-pressed={pressed} onMouseDown={keep} onClick={() => { edit(fn); focusTyping() }}>{label}</button>
  )
  function copyText() {
    if (!active || active.state.selection.empty) return
    void navigator.clipboard?.writeText(sliceToText(active.state.selection.content())).catch(() => {})
  }
  async function pasteText() {
    try {
      const text = await navigator.clipboard.readText()
      forgetTyped()
      if (text) edit((s) => s.tr.replaceSelection(sliceFromMarkdown(text)))
    } catch { setNote('Paste was not allowed: long-press in the box, or allow pasting.') }
  }

  // the copyright and credits: the page's footer, or on a phone the foot of the Export tab
  const credits = (
    <>
      <span>© 2026 Ilse Funkhouser.</span>
      <span>Grown with love from Kevin Raymond's <a href="https://github.com/kevinraymond/florilegium" target="_blank" rel="noreferrer">florilegium</a> (<a href="https://github.com/kevinraymond/florilegium/blob/main/LICENSE" target="_blank" rel="noreferrer">MIT License</a>). Fonts: IM Fell (SIL Open Font License), Latin Modern (GUST Font License).</span>
    </>
  )

  return (
    <div className={'shell' + (narrow ? ' narrow' : '')}>
    <header className="top">
      <h1>Felilegium</h1>
      <button className={'regen' + (stale ? ' stale' : '')} onClick={() => setGrown(requests)} disabled={growing}>{growing ? 'Generating…' : 'Regenerate'}</button>
      <a className="repo" href="https://github.com/funkhouserw/florilegium" target="_blank" rel="noreferrer"><span className="long">funkhouserw/florilegium on </span>GitHub</a>
    </header>
    <div className="app">
      <aside id="sheet" ref={sheet} onScroll={readSheet} className={'panel' + (tab ? ' open tab-' + tab : '') + (sheetScroll.down ? ' down' : '')} aria-label="Settings" role={narrow ? 'tabpanel' : undefined}>
        {narrow && tab && (
          <div className="sheethead">
            {tab === 'drawing' && sheetScroll.down && (
              <button className={'primary mini' + (stale ? ' stale' : '')} onClick={() => setGrown(requests)}>{growing ? 'Generating…' : stale ? 'Generate' : 'Up to date'}</button>
            )}
            <button className="close" aria-label="Close" onClick={() => setTab(null)}>Close</button>
          </div>
        )}
        <section className="sec sec-text" aria-label="Text">
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
        <p className="hint">{active ? 'Markdown works as you type: # heading, - list, **bold**, *italic*.' : 'Click into a box to type. Drag on an empty part of a page to draw a new box: it carries on your text, or click Unlink on it to give it its own.'}</p>

        {coarse && !narrow && <button className={drawArm ? 'on' : ''} onClick={() => { setLinking(null); setDrawArm(!drawArm) }}>{drawArm ? 'Cancel drawing' : 'Draw a box'}</button>}
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

        </section>
        <section className="sec sec-drawing" aria-label="Drawing">
        <button className={'primary generate' + (stale ? ' stale' : '')} onClick={() => setGrown(requests)}>{growing ? 'Generating…' : stale ? 'Generate' : 'Up to date'}</button>
        <p className="hint">{stale ? 'The drawing is behind your changes. It only changes when you click.' : 'The drawing stays put until you ask for a new one.'}</p>
        <button onClick={() => { setSeed((s) => s + 1); setGrowTick((t) => t + 1) }}>Grow a different one</button>
        <div className="row">
          <label>What grows
            <select value={grows} onChange={(e) => { const g = e.target.value as Grows; setGrows(g); setInkName(g === 'oak' ? 'green' : 'blue') }}>
              <option value="gym">Cat gym</option>
              <option value="oak">One huge oak</option>
              <option value="flowers">Kevin's flowers</option>
            </select>
          </label>
          <label>Ink
            <select value={inkName} onChange={(e) => setInkName(e.target.value as 'green' | 'blue')}>
              <option value="green">Green</option>
              <option value="blue">Delft blue</option>
            </select>
          </label>
        </div>
        <label>Drawing on each page
          <select value={perPage} onChange={(e) => setPerPage(e.target.value as PerPage)}>
            <option value="new">A new one on every page</option>
            <option value="match">The same one wherever the pages match</option>
          </select>
        </label>
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
        {grows === 'flowers' && (
          <>
            <label>Season
              <select value={FLOWER_SEASONS.includes(season) ? season : 'autumn'} onChange={(e) => setSeason(e.target.value as Season)}>
                {FLOWER_SEASONS.map((v) => <option key={v} value={v}>{v[0].toUpperCase() + v.slice(1)}</option>)}
              </select>
            </label>
            <p className="hint">Kevin Raymond's florilegium garden: plants sampled from genomes, with the insects, snails and birds they bring. It grows beside your text, on the wider side, and under where the text ends. Each seed is a different set of plants. A full page can take a few seconds.</p>
          </>
        )}
        <div className="row">
          {grows !== 'flowers' && <NumberField label="Cats a page" min={0} max={6} value={cats} onChange={setCats} />}
          <NumberField label={grows === 'flowers' ? 'Flower size' : 'Piece size'} unit="×" min={0.8} max={2.5} step={0.1} value={pieces} onChange={setPieces} />
          <NumberField label="Seed" min={1} max={1e9} value={seed} onChange={setSeed} />
        </div>
        </section>
        <section className="sec sec-page" aria-label="Page">
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
              <NumberField key={side} label={side[0].toUpperCase() + side.slice(1)} unit="cm" min={0} max={marginLimit(margins, sizeKey, side)} step={0.1}
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
        <NumberField label="Type size" unit="pt" min={10} max={90} value={fontSize} onChange={setFontSize} />
        <p className="hint">Points on the page: {fontSize} pt is about {Math.round(fontSize * S.px / W)} px in a {S.px} px wide image.</p>
        <button onClick={() => setDrawn((d) => [...d, []])}>Add a page</button>
        </section>
        <section className="sec sec-export" aria-label="Export and files">
        <label>PNG size
          <select value={scale2x} onChange={(e) => setScale2x(+e.target.value)}>
            {[1, 2, 3].map((k) => <option key={k} value={k}>{Math.round(Math.min(S.px * k, Math.sqrt(16e6 * W / H)))} px wide{k === 1 ? ` (${sizeKey === 'a4' || sizeKey === 'letter' ? 'about 200 dpi' : 'Instagram\'s own'})` : k === 2 ? ' (sharp on a phone)' : ''}</option>)}
          </select>
        </label>
        {shareFiles && (
          <div className="row">
            <button className="primary share" onClick={() => shareFiles.forEach((f) => download(f, f.name))}>Save {shareFiles.length} image{shareFiles.length === 1 ? '' : 's'}</button>
            <button className="primary share" onClick={() => shareOut(shareFiles)}>Share… (Instagram, Photos)</button>
          </div>
        )}
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
        {narrow && <p className="credits">{credits}</p>}
        </section>
        {error && <p className="error" role="alert">{error}</p>}
        {narrow && tab && sheetScroll.more && <div className="fade" aria-hidden="true">more below ▾</div>}
      </aside>
      <section className="canvas">
      <div className="zoombar" role="toolbar" aria-label="Zoom the pages">
        <button onClick={() => zoomStep(-1)} aria-label="Zoom out" disabled={zoom <= ZOOMS[0]}>−</button>
        <select aria-label="Zoom" value={String(zoom)} onChange={(e) => zoomTo(+e.target.value)}>
          {(ZOOMS.includes(zoom) ? ZOOMS : [...ZOOMS, zoom].sort((a, b) => a - b)).map((z) => <option key={z} value={String(z)}>{Math.round(z * 100)}%</option>)}
        </select>
        <button onClick={() => zoomStep(1)} aria-label="Zoom in" disabled={zoom >= ZOOMS[ZOOMS.length - 1]}>+</button>
        <button onClick={() => {
          const el = pagesEl.current
          if (el) zoomTo(Math.min((el.clientHeight - 80) / (PAGE_PX * H / W), (el.clientWidth - 64) / PAGE_PX))
        }}>Fit a page</button>
        <span className="hint">⌘ and + or −, ⌘ and scroll, or pinch</span>
      </div>
      <main className="pages" ref={pagesEl}>
        {drawArm && (
          <div className="banner" role="status">
            <span>Drag on a page to draw a box.</span>
            <button onClick={() => setDrawArm(false)}>Cancel</button>
          </div>
        )}
        {linking !== null && (
          <div className="banner" role="status">
            <span>{coarse ? 'Tap the box to link. Text flows through linked boxes in page order.' : 'Click the box to link, or draw a new one. Text flows through linked boxes in page order.'}</span>
            <button onClick={() => setLinking(null)}>Cancel</button>
          </div>
        )}
        {pages.map((p, i) => {
          const m = marks.get(i)
          return (
            <PageView key={i} index={i} page={p} W={W} H={H} zoom={zoom} margins={margins} style={style} gym={gyms[i]} growing={growing}
              svgRef={(el) => { svgs.current[i] = el }} caretRef={caretEl} caret={focused ? m?.caret : undefined} composition={coarse ? null : composition} rects={m?.rects ?? []}
              linking={linking !== null} activeStory={activeId} selectedId={selected?.page === i ? selected.id : null}
              chainLabel={(b) => { const ch = chainOf(b.story); return ch.length > 1 ? `${ch.findIndex((c) => c.page === i && c.id === b.id) + 1}/${ch.length}` : '' }}
              setDragging={setDragging} editPage={editPage} drawBox={drawBox} afterDraw={afterDraw} startText={startText} removeBox={removeBox} removePage={drawn.length > 1 && i < drawn.length ? () => removePage(i) : undefined} select={(id) => setSelected((s) => (s?.page === i && s.id === id ? s : { page: i, id }))}
              unlink={(b) => unlink(i, b)} touch={coarse} armed={drawArm} disarm={() => setDrawArm(false)} count={pages.length}
              save={savingPage === i ? <span className="hint">Making page {i + 1}…</span>
                : readyPage?.index === i ? (
                  <>
                    <button className="link" onClick={() => download(readyPage.file, readyPage.file.name)}>Save</button>
                    <button className="link" onClick={() => shareOut([readyPage.file])}>Share…</button>
                    <button className="link" onClick={() => setReadyPage(null)}>Done</button>
                  </>
                ) : <button className="link" disabled={savingPage !== null || !!busy} onClick={() => void savePage(i)}>Save page {i + 1} as PNG</button>}
              startLink={(b) => { setSelected({ page: i, id: b.id }); setActiveId(b.story); setLinking(linking === null ? b.story : null) }} />
          )
        })}
      </main>
      </section>
      {narrow && (editing ? (
        // while typing, the formatting sits above the keyboard (iOS keeps the page its full height under it)
        <div className="strip" role="toolbar" aria-label="Text formatting" style={{ transform: `translateY(${-kb}px)` }}>
          <div className="tools">
            {stripTool(<b>B</b>, 'Bold', on.bold, (s) => toggle(s, 'bold'))}
            {stripTool(<i>I</i>, 'Italic', on.italic, (s) => toggle(s, 'italic'))}
            {stripTool('H1', 'Large heading', kind === 1, (s) => setBlock(s, 1))}
            {stripTool('H2', 'Heading', kind === 2, (s) => setBlock(s, 2))}
            {stripTool('¶', 'Plain paragraph', kind === 'p' && !here?.attrs.list, (s) => setBlock(s, 'p'))}
            {stripTool('•', 'Bulleted list', here?.attrs.list === 'bullet', (s) => toggleList(s, 'bullet'))}
            {stripTool('1.', 'Numbered list', here?.attrs.list === 'ordered', (s) => toggleList(s, 'ordered'))}
            {stripTool('↶', 'Undo', false, (s) => run(s, undo))}
            {stripTool('All', 'Select all', false, selectAll)}
            <button onMouseDown={keep} onClick={() => { copyText(); focusTyping() }}>Copy</button>
            <button onMouseDown={keep} onClick={() => { void pasteText(); focusTyping() }}>Paste</button>
            <button onMouseDown={keep} onClick={() => { typing.current?.blur(); setTab('text') }}>Box…</button>
          </div>
          <button className="done" onMouseDown={keep} onClick={() => typing.current?.blur()}>Done</button>
        </div>
      ) : (
        <nav className="tabs" role="tablist" aria-label="Settings">
          <button className={drawArm ? 'on' : ''} aria-pressed={drawArm} onClick={() => { setTab(null); setLinking(null); setDrawArm(!drawArm) }}>{drawArm ? 'Cancel' : 'Draw a box'}</button>
          {TABS.filter(([t]) => t !== 'text').map(([t, label]) => (
            <button key={t} role="tab" aria-selected={tab === t} aria-controls="sheet" className={tab === t ? 'on' : ''} onClick={() => { setDrawArm(false); setTab(tab === t ? null : t) }}>{label}</button>
          ))}
        </nav>
      ))}
      <textarea ref={typing} className="typing" aria-label="Text of the box you are editing" autoComplete="off" autoCorrect="off" autoCapitalize="off" spellCheck={false}
        onKeyDown={onKey} onInput={() => { if (composition === null) syncTyping(); else if (coarse) syncTyping(true) }} onFocus={() => setFocused(true)} onBlur={() => setFocused(false)}
        onCompositionStart={() => setComposition('')}
        onCompositionUpdate={(e) => setComposition(e.data)}
        onCompositionEnd={() => { setComposition(null); syncTyping() }}
        onCopy={(e) => onCopy(e, false)} onCut={(e) => onCopy(e, true)} onPaste={onPaste} />
    </div>
    {!narrow && <footer className="bottom">{credits}</footer>}
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
function NumberField({ label, value, min, max, step, unit, onChange }: {
  label: string; value: number; min: number; max: number; step?: number; unit?: string; onChange: (v: number) => void
}) {
  const [draft, setDraft] = useState<string | null>(null)
  const usable = (t: string) => {
    const v = t.trim() === '' ? NaN : +t
    return Number.isFinite(v) && v >= min && v <= max && (step !== undefined || Number.isInteger(v)) ? v : null
  }
  return (
    <label>{label}
      <span className="num">
      {unit === '×' && <span className="unit">×</span>}
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
      {unit && unit !== '×' && <span className="unit">{unit}</span>}
      </span>
    </label>
  )
}

const LinesOf = memo(function LinesOf({ lines, style }: { lines: Line[]; style: TextStyle }) {
  return (
    <g fontFamily={style.family} fill={style.color} style={{ pointerEvents: 'none' }}>
      {lines.flatMap((l, i) => l.runs.map((r, j) => (
        <text key={`${i}.${j}`} x={r.x} y={l.y} fontSize={l.size} fontWeight={r.bold ? 700 : 400} fontStyle={r.italic ? 'italic' : 'normal'}>{r.text}</text>
      )))}
    </g>
  )
})

function PageView({ index, page, W, H, zoom, margins, style, gym, growing, svgRef, caretRef, caret, composition, rects, linking, activeStory, selectedId, chainLabel, setDragging, editPage, drawBox, afterDraw, startText, removeBox, removePage, select, startLink, unlink, touch, armed, disarm, count, save }: {
  index: number; page: FlowPage; W: number; H: number; zoom: number; margins: Margins; style: TextStyle; gym?: string; growing: boolean
  svgRef: (el: SVGSVGElement | null) => void; caretRef: React.RefObject<SVGLineElement | null>
  caret?: Caret; composition: string | null; rects: { x: number; y: number; w: number; h: number }[]
  linking: boolean; activeStory: number | null; selectedId: number | null; chainLabel: (b: Box) => string
  setDragging: (b: boolean) => void; editPage: (page: number, fn: (b: Box[]) => Box[]) => void
  drawBox: (page: number, x: number, y: number) => number; afterDraw: (page: number, id: number, ok: boolean) => void
  startText: (e: React.PointerEvent | React.MouseEvent, page: number, box: Box, drag?: boolean) => void; removeBox: (page: number, box: Box) => void
  removePage?: () => void; select: (id: number) => void; startLink: (b: Box) => void; unlink: (b: Box) => void
  touch: boolean; armed: boolean; disarm: () => void; count: number; save: React.ReactNode
}) {
  const ref = useRef<SVGSVGElement | null>(null)
  const drag = useRef<Drag | null>(null)
  // touch: a finger on a box's control or in draw mode mustn't scroll the pages (only a native listener can stop that)
  const stageRef = useRef<HTMLDivElement | null>(null)
  const armedNow = useRef(armed)
  armedNow.current = armed
  useEffect(() => {
    const el = stageRef.current
    if (!el) return
    const f = (e: TouchEvent) => { if (e.touches.length === 1 && (armedNow.current || (e.target as Element).closest?.('.ctl'))) e.preventDefault() }
    el.addEventListener('touchstart', f, { passive: false })
    return () => el.removeEventListener('touchstart', f)
  }, [])
  // a second finger anywhere means a pinch: a move or a draw in progress is undone
  const undoDrag = useRef(() => {})
  undoDrag.current = () => {
    const d = drag.current
    if (!d) return
    frame.current.fn = null
    clearTimeout(reflow.current)
    setGhost(null)
    drag.current = null
    if (d.kind === 'draw') afterDraw(d.page, d.id, false)
    else if (d.orig) { const o = d.orig; editPage(d.page, (bs) => bs.map((b) => (b.id === o.id ? o : b))) }
    setDragging(false)
  }
  useEffect(() => {
    const f = (e: TouchEvent) => { if (e.touches.length > 1) undoDrag.current() }
    window.addEventListener('touchstart', f, { capture: true, passive: true })
    return () => window.removeEventListener('touchstart', f, { capture: true })
  }, [])
  // a box being moved or resized is drawn from here, so a drag redraws this page alone; the work's layout (and the
  // text's flow) catches up when the finger lifts, and every so often while resizing
  const [ghost, setGhostState] = useState<Box | null>(null)
  const ghostNow = useRef<Box | null>(null)
  const setGhost = (b: Box | null) => { ghostNow.current = b; setGhostState(b) }
  const frame = useRef<{ raf: number; fn: (() => void) | null }>({ raf: 0, fn: null })
  const perFrame = (fn: () => void) => {          // the latest of a frame's moves, once
    frame.current.fn = fn
    if (!frame.current.raf) frame.current.raf = requestAnimationFrame(() => { const f = frame.current.fn; frame.current = { raf: 0, fn: null }; f?.() })
  }
  const flushFrame = () => { const f = frame.current.fn; cancelAnimationFrame(frame.current.raf); frame.current = { raf: 0, fn: null }; f?.() }
  const reflow = useRef(0)
  const commitGhost = () => { const g = ghostNow.current; const d = drag.current; if (g && d) editPage(d.page, (bs) => bs.map((b) => (b.id === g.id ? g : b))) }
  const kind = useRef('mouse')             // the last pointer's kind: a mouse types on pointerdown, a finger on click
  const downOn = useRef<number | null>(null)
  const scale = PAGE_PX * zoom / W
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
    drag.current = { ...d, pid: e.pointerId, ...(d.kind !== 'draw' ? { orig: page.boxes.find((b) => b.id === d.id) } : {}) }
    setDragging(true)
  }
  // a box's buttons: a mouse acts on press; a finger on a tap, so a swipe that starts on one still scrolls
  const tapOrPress = (act: () => void) => ({
    onPointerDown: (e: React.PointerEvent) => { e.stopPropagation(); if (e.pointerType === 'mouse') { e.preventDefault(); act() } },
    onClick: (e: React.MouseEvent) => { e.stopPropagation(); if (kind.current !== 'mouse') act() },
  })
  const onDown = (e: React.PointerEvent) => {
    if (e.pointerType !== 'mouse' && !armed) return            // a finger scrolls, unless drawing is armed
    const p = at(e)
    const x0 = snap(p.x, left, right), y0 = snap(p.y, top, bottom)
    const id = drawBox(index, x0, y0)
    begin(e, { kind: 'draw', page: index, x0, y0, id })
  }
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d || (d.pid !== undefined && e.pointerId !== d.pid)) return     // a second finger
    const p = at(e)
    const clampX = (v: number) => Math.max(0, Math.min(W, v)), clampY = (v: number) => Math.max(0, Math.min(H, v))
    if (d.kind === 'draw') {
      // a new box: the text flows into it as it grows, once a frame
      perFrame(() => editPage(d.page, (bs) => bs.map((b) => {
        if (b.id !== d.id) return b
        const x = snap(clampX(p.x), left, right), y = snap(clampY(p.y), top, bottom)
        return { ...b, x: Math.min(d.x0, x), y: Math.min(d.y0, y), w: Math.abs(x - d.x0), h: Math.abs(y - d.y0) }
      })))
      return
    }
    const b = d.orig
    if (!b) return
    if (d.kind === 'move') {
      const x = clampX(p.x - d.dx), y = clampY(p.y - d.dy)
      perFrame(() => setGhost({
        ...b,
        x: Math.abs(x + b.w - right) < pull ? right - b.w : snap(x, left),
        y: Math.abs(y + b.h - bottom) < pull ? bottom - b.h : snap(y, top),
      }))
      return
    }
    perFrame(() => setGhost({ ...b, w: Math.max(30, snap(clampX(p.x), right) - b.x), h: Math.max(20, snap(clampY(p.y), bottom) - b.y) }))
    // resizing: the text reflows now and then while the box changes, not on every move
    if (!reflow.current) reflow.current = window.setTimeout(() => { reflow.current = 0; commitGhost() }, 150)
  }
  const onUp = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d || (d.pid !== undefined && e.pointerId !== d.pid)) return
    flushFrame()
    clearTimeout(reflow.current)
    reflow.current = 0
    commitGhost()
    setGhost(null)
    drag.current = null
    if (d.kind === 'draw') {
      const b = page.boxes.find((x) => x.id === d.id)
      afterDraw(d.page, d.id, e.type !== 'pointercancel' && !!b && b.w > 30 && b.h > 20)    // a cancelled draw leaves no box
      if (armed) disarm()
    }
    setDragging(false)
  }
  // the page's text, split into what stays and what rides along with a box being moved (stable arrays, so the
  // memoized lines don't redraw while a box moves)
  const ghostId = ghost && drag.current?.kind === 'move' ? ghost.id : null
  const split = (layer: (l: Line) => boolean) => {
    const all = page.lines.filter(layer)
    return ghostId === null ? { still: all, moving: [] as Line[] } : { still: all.filter((l) => l.box !== ghostId), moving: all.filter((l) => l.box === ghostId) }
  }
  const behind = useMemo(() => split((l) => l.layer === 'behind'), [page.lines, ghostId])    // eslint-disable-line react-hooks/exhaustive-deps
  const front = useMemo(() => split((l) => l.layer !== 'behind'), [page.lines, ghostId])     // eslint-disable-line react-hooks/exhaustive-deps
  const orig = ghostId !== null ? page.boxes.find((b) => b.id === ghostId) : undefined
  const moved = ghost && orig ? { x: ghost.x - orig.x, y: ghost.y - orig.y } : { x: 0, y: 0 }
  return (
    <div className="pagewrap">
      <div className="pagelabel"><span>Page {index + 1} of {count}{page.auto ? ' (text ran on)' : ''}</span>
        {removePage && <button className="link" onClick={removePage}>Delete page</button>}
      </div>
      <div ref={stageRef} className={'stage' + (growing ? ' growing' : '') + (touch ? ' touch' : '') + (armed ? ' armed' : '')} data-page={index} style={{ width: W * scale, height: H * scale }}
        onContextMenu={touch ? (e) => e.preventDefault() : undefined}>
        <svg className="under" viewBox={`0 0 ${W} ${H}`} aria-hidden="true">
          <LinesOf lines={behind.still} style={style} />
          {ghost && <g transform={`translate(${moved.x} ${moved.y})`}><LinesOf lines={behind.moving} style={style} /></g>}
        </svg>
        {url && <img src={url} alt="" />}
        <svg ref={(el) => { ref.current = el; svgRef(el) }} className={'ink' + (linking ? ' linking' : '')} viewBox={`0 0 ${W} ${H}`} role="application" aria-label={`Page ${index + 1}`}
          onPointerDownCapture={(e) => { kind.current = e.pointerType }} onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
          <rect className="guide" x={left} y={top} width={right - left} height={bottom - top} />
          {rects.map((r, i) => <rect key={i} className="selection" x={r.x} y={r.y} width={r.w} height={r.h} />)}
          <LinesOf lines={front.still} style={style} />
          {ghost && <g transform={`translate(${moved.x} ${moved.y})`}><LinesOf lines={front.moving} style={style} /></g>}
          {page.boxes.map((b0) => {
            const b = ghost?.id === b0.id ? ghost : b0
            const handle = (touch ? 18 : 10) / scale, dr = (touch ? 12 : 9) / scale, hit = 22 / scale
            const controls = !touch || b.id === selectedId           // a finger gets a box's controls once it's chosen
            const label = chainLabel(b)
            const over = page.over.has(b.id)
            const shown = over ? Math.max(b.h, page.used.get(b.id) ?? 0) : b.h
            const cls = 'box' + (b.story === activeStory ? ' live' : '') + (b.id === selectedId ? ' picked' : '') + (over ? ' overflow' : '')
            return (
              <g key={b.id}>
                <rect className={cls} x={b.x} y={b.y} width={b.w} height={shown}
                  onPointerDown={(e) => { downOn.current = b.id; if (e.pointerType === 'mouse') startText(e, index, b) }}
                  onClick={(e) => { if (kind.current !== 'mouse' && !armed && downOn.current === b.id) startText(e, index, b, false) }} />
                {controls && <>
                <rect className="edge ctl" x={b.x - (touch ? 13 : 3) / scale} y={b.y - (touch ? 13 : 3) / scale} width={b.w + (touch ? 26 : 6) / scale} height={b.h + (touch ? 26 : 6) / scale}
                  onPointerDown={(e) => { const p = at(e); select(b.id); begin(e, { kind: 'move', page: index, id: b.id, dx: p.x - b.x, dy: p.y - b.y }) }} />
                {touch && (() => {
                  // a finger moves a box by its grip, where none of its other controls are (the label is above it, ⊗ →
                  // and the handle on its right edge): left of the box at its middle; else right of it, past ⊗ and →;
                  // else below it; else (a box filling the page's foot) just inside its foot
                  const left = b.x * scale >= 40, right = !left && (W - b.x - b.w) * scale >= 64
                  const below = !left && !right && (H - b.y - b.h) * scale >= 64
                  const side = left || right
                  const cx = left ? b.x - 20 / scale : right ? b.x + b.w + 42 / scale : b.x + b.w / 2
                  const cy = side ? b.y + Math.max(b.h / 2, 14 / scale) : below ? b.y + b.h + 38 / scale : b.y + b.h - 20 / scale
                  const pw = (side ? 28 : 44) / scale, ph = (side ? 44 : 28) / scale
                  const X = (x: number) => cx + x / scale, Y = (y: number) => cy + y / scale
                  return (
                    <g className="ctl grip" role="button" aria-label="Move this box"
                      onPointerDown={(e) => { const p = at(e); select(b.id); begin(e, { kind: 'move', page: index, id: b.id, dx: p.x - b.x, dy: p.y - b.y }) }}>
                      <circle className="hit" cx={cx} cy={cy} r={hit} />
                      <rect x={cx - pw / 2} y={cy - ph / 2} width={pw} height={ph} rx={Math.min(pw, ph) / 2} />
                      <path className="hand" d={                     // an open hand: grab here and drag
                        `M${X(-4.5)} ${Y(1)}V${Y(-4)}M${X(-1.5)} ${Y(-1)}V${Y(-7)}M${X(1.5)} ${Y(-1)}V${Y(-7)}M${X(4.5)} ${Y(0)}V${Y(-5)}` +   // fingers
                        `M${X(-4.5)} ${Y(1)}V${Y(3)}Q${X(-4.5)} ${Y(8)} ${X(0)} ${Y(8)}Q${X(5)} ${Y(8)} ${X(5.5)} ${Y(3)}L${X(4.5)} ${Y(0)}` +   // palm
                        `M${X(-4.5)} ${Y(3)}L${X(-7.5)} ${Y(-0.5)}`} />                                                                // thumb
                    </g>
                  )
                })()}
                <g className="ctl" onPointerDown={(e) => { select(b.id); begin(e, { kind: 'size', page: index, id: b.id, dx: 0, dy: 0 }) }}>
                  {touch && <circle className="hit" cx={b.x + b.w} cy={b.y + b.h} r={hit} />}
                  <rect className="handle" x={b.x + b.w - handle / 2} y={b.y + b.h - handle / 2} width={handle} height={handle} />
                </g>
                <g role="button" aria-label="Delete this text box" {...tapOrPress(() => removeBox(index, b))}>
                  {touch && <circle className="hit" cx={b.x + b.w} cy={b.y} r={hit} />}
                  <circle className="del" cx={b.x + b.w} cy={b.y} r={dr} />
                  <path className="delx" d={`M${b.x + b.w - dr / 2} ${b.y - dr / 2}l${dr} ${dr}m0 ${-dr}l${-dr} ${dr}`} />
                </g>
                <g className="linker" role="button" aria-label="Link this box to another" {...tapOrPress(() => startLink(b))}>
                  <title>Link this box to another, so text flows between them</title>
                  {touch && <circle className="hit" cx={b.x + b.w} cy={b.y + b.h / 2} r={hit} />}
                  <circle cx={b.x + b.w} cy={b.y + b.h / 2} r={dr} />
                  <path d={`M${b.x + b.w - dr * 0.5} ${b.y + b.h / 2}h${dr}m${-dr * 0.4} ${-dr * 0.4}l${dr * 0.4} ${dr * 0.4}l${-dr * 0.4} ${dr * 0.4}`} />
                </g>
                </>}
                {label && <text className="chain" x={b.x} y={b.y - (touch ? 16 : 5) / scale} fontSize={(touch ? 15 : 11) / scale}>{label}
                  {controls && <>{' · '}<tspan className="unlink" role="button" aria-label="Unlink this box, so it holds its own text" {...tapOrPress(() => unlink(b))}>Unlink</tspan></>}
                </text>}
              </g>
            )
          })}
          {caret && composition && <text className="composition" x={caret.x} y={caret.base} fontSize={caret.size} fontFamily={style.family} fill={style.color}>{composition}</text>}
          {caret && <line ref={caretRef} className="caret" x1={caret.x} x2={caret.x} y1={caret.y0} y2={caret.y1} />}
        </svg>
      </div>
      <div className="pagesave">{save}</div>
    </div>
  )
}

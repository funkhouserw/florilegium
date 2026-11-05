// The studio: paste a post, draw boxes for the text on each page; Pretext lays the text out in
// them, what does not fit goes to the next page, and a cat gym grows around the boxes. Your work is
// kept in this browser as you go, and in a file when you ask.
import { useEffect, useMemo, useRef, useState } from 'react'
import { clearCache } from '@chenglou/pretext'
import { flow, fontOf, parse, plainText, type Box, type FlowPage, type TextStyle } from './flow'
import { growGym } from './gym'
import { download, pagePng, pagesToHtml, pagesToPdf } from './exporter'
import { CM, docFile, loadDoc, newBoxId, newDoc, readDocFile, saveDoc, SEASONS, SIZES, type Doc, type Grows, type Season, type SizeKey } from './doc'
import { familyOf, FAMILIES } from './fonts'

const PAPER = '#fefdfb'
const initial = loadDoc()
type Drag =
  | { kind: 'draw'; page: number; x0: number; y0: number; id: number }
  | { kind: 'move' | 'size'; page: number; id: number; dx: number; dy: number }

export function App() {
  const [text, setText] = useState(initial.text)
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
  const [drawn, setDrawn] = useState<Box[][]>(initial.drawn)
  const S = SIZES[sizeKey]
  const W = S.w * CM, H = S.h * CM
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [note, setNote] = useState('')
  const [unsaved, setUnsaved] = useState(false)
  const opener = useRef<HTMLInputElement>(null)
  const face = familyOf(family)
  const style: TextStyle = useMemo(() => ({ family, size: fontSize, leading: 1.35, color: '#1b2a6b', headingBold: face.headingBold }), [family, fontSize, face])
  // Pretext measures with the browser's font and remembers: measure again once the web fonts have arrived
  const [fontsReady, setFontsReady] = useState(0)
  useEffect(() => {
    let live = true
    const looks = [{ bold: false, italic: false }, { bold: false, italic: true }, { bold: true, italic: false }]
    Promise.all(looks.map((l) => document.fonts.load(fontOf(l, 40, family)))).then(() => {
      if (live) { clearCache(); setFontsReady((n) => n + 1) }
    })
    return () => { live = false }
  }, [family])
  const blocks = useMemo(() => parse(text, face.headingBold), [text, face])
  const { pages, lost } = useMemo(() => flow(blocks, drawn, style), [blocks, drawn, style, fontsReady])
  const title = blocks.length ? plainText(blocks[0]).slice(0, 120) : ''
  const fileBase = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 60) || 'studio'

  // kept in this browser as you work; not during a drag, and a full disk must not stop the work
  const doc: Doc = useMemo(() => ({ text, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, drawn }),
    [text, sizeKey, family, fontSize, seed, cats, pieces, grows, inkName, crown, season, spanishmoss, drawn])
  useEffect(() => {
    if (dragging) return
    const timer = setTimeout(() => {
      try { saveDoc(doc); setUnsaved(false) } catch { setUnsaved(true) }
    }, 300)
    return () => clearTimeout(timer)
  }, [doc, dragging])
  useEffect(() => setNote(''), [doc])
  function applyDoc(d: Doc) {
    setText(d.text); setSizeKey(d.sizeKey); setFamily(d.family); setFontSize(d.fontSize); setSeed(d.seed); setCats(d.cats); setPieces(d.pieces)
    setGrows(d.grows); setInkName(d.inkName); setCrown(d.crown); setSeason(d.season); setSpanishmoss(d.spanishmoss); setDrawn(d.drawn)
    setError(''); setNote('')
  }
  async function openFile(file?: File) {
    if (!file) return
    try { applyDoc(readDocFile(await file.text())) } catch (e) { setError(`Could not open ${file.name}: ${e instanceof Error ? e.message : String(e)}`) }
  }

  function changeSize(k: SizeKey) {
    const old = SIZES[sizeKey], next = SIZES[k]
    const sx = next.w / old.w, sy = next.h / old.h
    setSizeKey(k)
    setDrawn((d) => d.map((p) => p.map((b) => ({ ...b, x: b.x * sx, y: b.y * sy, w: b.w * sx, h: b.h * sy }))))
  }
  // a change to a page that only follows the last one makes it a page of its own
  function edit(page: number, fn: (boxes: Box[]) => Box[]) {
    setDrawn((d) => {
      const copy = d.slice()
      while (copy.length <= page) copy.push((copy[copy.length - 1] ?? []).map((b) => ({ ...b, id: newBoxId() })))
      copy[page] = fn(copy[page])
      return copy
    })
  }

  // the gym's keep-outs: each box as far down as its text reaches, in cm, y up
  const requests = useMemo(() => pages.map((p, index) => ({
    grows, ink: inkName, crown, season, spanishmoss, w: S.w, h: S.h, seed: seed + index * 101, cats, size: grows === 'gym' ? pieces : 1, density: 1, index,
    keepouts: p.boxes.map((b) => {
      const used = dragging ? b.h : p.lines.length ? (p.used.get(b.id) ?? 0) : b.h
      const h = used > 0 ? used : text.trim() === '' ? b.h : 0
      if (h <= 0) return null
      const pad = fontSize * 0.5                       // a little air around the text, and its descenders
      return [b.x - pad, H - (b.y + h + pad), b.x + b.w + pad, H - b.y + pad].map((v) => +(v / CM).toFixed(2))
    }).filter((q): q is number[] => q !== null),
  })), [pages, S, seed, cats, pieces, H, text, dragging, fontSize, grows, inkName, crown, season, spanishmoss])

  const latest = useRef(requests)
  if (!dragging) latest.current = requests             // the gym regrows on release, not during a drag
  const stable = latest.current
  const [gyms, setGyms] = useState<Record<number, string>>({})
  const stableKey = JSON.stringify(stable)
  const [growing, setGrowing] = useState(true)
  useEffect(() => {
    let live = true
    setGrowing(true)
    setError('')
    const timer = setTimeout(async () => {
      for (const r of stable) {
        try {
          const svg = await growGym(r)
          if (!live) return
          setGyms((g) => ({ ...g, [r.index]: svg }))
        } catch (e) { if (live) setError('It did not grow: ' + String(e)) }
      }
      if (live) setGrowing(false)
    }, 250)
    return () => { live = false; clearTimeout(timer) }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stableKey])

  async function exportPngs() {
    setNote('')
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
    try {
      const svgs = await grownPages(false)
      setBusy('Writing the HTML')
      const html = await pagesToHtml(pages, svgs, style, face, W, H, title, PAPER)
      download(html, `${fileBase}.html`)
      told(html)
    } catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }

  return (
    <div className="app">
      <aside className="panel">
        <h1>Studio</h1>
        <label>Your post<textarea aria-label="Your post" value={text} onChange={(e) => setText(e.target.value)} /></label>
        <p className="hint"><code># Heading</code>, <code>## Smaller</code>, <code>**bold**</code>, <code>*italic*</code>; a blank line opens a space.</p>
        <p className="hint">Drag on a page to draw a text box. Drag a box to move it, its corner to resize. It regrows when you let go.</p>
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
            <label><input type="checkbox" checked={spanishmoss} onChange={(e) => setSpanishmoss(e.target.checked)} /> Spanish moss</label>
          </>
        )}
        <label>Size
          <select value={sizeKey} onChange={(e) => changeSize(e.target.value as SizeKey)}>
            {Object.entries(SIZES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
        </label>
        <label>Typeface
          <select value={family} onChange={(e) => setFamily(e.target.value)}>
            {FAMILIES.map((f) => <option key={f.css} value={f.css}>{f.label}</option>)}
          </select>
        </label>
        <div className="row">
          <NumberField label="Type size" min={10} max={90} value={fontSize} onChange={setFontSize} />
          <NumberField label="Cats a page" min={0} max={6} value={cats} onChange={setCats} />
          <NumberField label="Piece size" min={0.8} max={2.5} step={0.1} value={pieces} onChange={setPieces} />
          <NumberField label="Seed" min={1} max={1e9} value={seed} onChange={setSeed} />
        </div>
        <button onClick={() => setSeed((s) => s + 1)}>Grow another</button>
        <div className="row three">
          <button className="primary" disabled={!!busy} onClick={exportPngs}>PNGs</button>
          <button className="primary" disabled={!!busy || !face.files} onClick={exportPdf}>PDF</button>
          <button className="primary" disabled={!!busy} onClick={exportHtml}>HTML</button>
        </div>
        <p className="hint">{busy || note || `${pages.length} page${pages.length === 1 ? '' : 's'}. ${face.files ? 'PDF and HTML keep real text you can select.' : `For a PDF, choose IM Fell or Florilegium Roman: a browser can only embed fonts that come with the app. An HTML file shows ${face.label} only to readers who have it.`}`}</p>
        {lost && <p className="error" role="alert">Some of your text has nowhere to go: draw a bigger box, or one on the last page.</p>}
        <div className="row three">
          <button onClick={() => download(docFile(doc), `${fileBase}.studio.json`)}>Save file</button>
          <button onClick={() => opener.current?.click()}>Open file</button>
          <button onClick={() => { if (window.confirm('Start over? This clears the post and boxes kept in this browser.')) applyDoc(newDoc()) }}>Start over</button>
        </div>
        <input ref={opener} type="file" accept=".json,application/json" hidden aria-label="Open a studio file"
          onChange={(e) => { void openFile(e.target.files?.[0]); e.target.value = '' }} />
        <p className="hint">{unsaved ? 'This browser is out of room, so your latest changes are not kept here: save a file.' : 'Kept in this browser as you work. Save a file to keep it anywhere else.'}</p>
        {error && <p className="error" role="alert">{error}</p>}
      </aside>
      <main className="pages">
        {pages.map((p, i) => (
          <PageView key={i} index={i} page={p} W={W} H={H} style={style} gym={gyms[i]} growing={growing}
            setDragging={setDragging} edit={edit} />
        ))}
      </main>
    </div>
  )
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

function PageView({ index, page, W, H, style, gym, growing, setDragging, edit }: {
  index: number; page: FlowPage; W: number; H: number; style: TextStyle; gym?: string; growing: boolean
  setDragging: (b: boolean) => void; edit: (page: number, fn: (b: Box[]) => Box[]) => void
}) {
  const ref = useRef<SVGSVGElement>(null)
  const drag = useRef<Drag | null>(null)
  const url = useMemo(() => (gym ? URL.createObjectURL(new Blob([gym], { type: 'image/svg+xml' })) : ''), [gym])
  useEffect(() => () => { if (url) URL.revokeObjectURL(url) }, [url])
  const at = (e: React.PointerEvent) => {
    const r = ref.current!.getBoundingClientRect()
    return { x: (e.clientX - r.left) * W / r.width, y: (e.clientY - r.top) * H / r.height }
  }
  const begin = (e: React.PointerEvent, d: Drag) => {
    e.stopPropagation()
    ref.current!.setPointerCapture(e.pointerId)
    drag.current = d
    setDragging(true)
  }
  const onDown = (e: React.PointerEvent) => {
    const p = at(e)
    const id = newBoxId()
    edit(index, (bs) => [...bs, { id, x: p.x, y: p.y, w: 1, h: 1 }])
    begin(e, { kind: 'draw', page: index, x0: p.x, y0: p.y, id })
  }
  const onMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d) return
    const p = at(e)
    const clampX = (v: number) => Math.max(0, Math.min(W, v)), clampY = (v: number) => Math.max(0, Math.min(H, v))
    edit(d.page, (bs) => bs.map((b) => {
      if (b.id !== d.id) return b
      if (d.kind === 'draw') {
        const x = clampX(p.x), y = clampY(p.y)
        return { ...b, x: Math.min(d.x0, x), y: Math.min(d.y0, y), w: Math.abs(x - d.x0), h: Math.abs(y - d.y0) }
      }
      if (d.kind === 'move') return { ...b, x: clampX(p.x - d.dx), y: clampY(p.y - d.dy) }
      return { ...b, w: Math.max(30, clampX(p.x) - b.x), h: Math.max(20, clampY(p.y) - b.y) }
    }))
  }
  const onUp = () => {
    const d = drag.current
    if (!d) return
    drag.current = null
    if (d.kind === 'draw') edit(d.page, (bs) => bs.filter((b) => b.id !== d.id || (b.w > 30 && b.h > 20)))
    setDragging(false)
  }
  const scale = 420 / W
  return (
    <div className="pagewrap">
      <div className="pagelabel"><span>Page {index + 1}{page.auto ? ' (text ran on)' : ''}</span></div>
      <div className={'stage' + (growing ? ' growing' : '')} style={{ width: W * scale, height: H * scale }}>
        {url && <img src={url} alt="" />}
        <svg ref={ref} className="ink" viewBox={`0 0 ${W} ${H}`} role="application" aria-label={`Page ${index + 1}`}
          onPointerDown={onDown} onPointerMove={onMove} onPointerUp={onUp} onPointerCancel={onUp}>
          <g fontFamily={style.family} fill={style.color} style={{ pointerEvents: 'none', whiteSpace: 'pre' }}>
            {page.lines.flatMap((l, i) => l.runs.map((r, j) => (
              <text key={`${i}.${j}`} x={r.x} y={l.y} fontSize={l.size} fontWeight={r.bold ? 700 : 400} fontStyle={r.italic ? 'italic' : 'normal'}>{r.text}</text>
            )))}
          </g>
          {page.boxes.map((b) => {
            const handle = 10 / scale, dr = 9 / scale
            return (
              <g key={b.id}>
                <rect className="box" x={b.x} y={b.y} width={b.w} height={b.h}
                  onPointerDown={(e) => { const p = at(e); begin(e, { kind: 'move', page: index, id: b.id, dx: p.x - b.x, dy: p.y - b.y }) }} />
                <rect className="handle" x={b.x + b.w - handle / 2} y={b.y + b.h - handle / 2} width={handle} height={handle}
                  onPointerDown={(e) => begin(e, { kind: 'size', page: index, id: b.id, dx: 0, dy: 0 })} />
                <circle className="del" cx={b.x + b.w} cy={b.y} r={dr} role="button" aria-label="Delete this text box"
                  onPointerDown={(e) => { e.stopPropagation(); edit(index, (bs) => bs.filter((x) => x.id !== b.id)) }} />
                <path className="delx" d={`M${b.x + b.w - dr / 2} ${b.y - dr / 2}l${dr} ${dr}m0 ${-dr}l${-dr} ${dr}`} />
              </g>
            )
          })}
        </svg>
      </div>
    </div>
  )
}

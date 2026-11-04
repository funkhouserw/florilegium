// The studio: paste a post, draw boxes for the text on each page; Pretext lays the text out in
// them, what does not fit goes to the next page, and a cat gym grows around the boxes.
import { useEffect, useMemo, useRef, useState } from 'react'
import { flow, type Box, type FlowPage, type TextStyle } from './flow'
import { growGym } from './gym'
import { download, pageSvg, pngsToPdf, svgToPng } from './exporter'

const CM = 72 / 2.54
const SIZES = {
  insta: { label: 'Instagram 4:5', w: 21, h: 26.25, px: 1080 },
  square: { label: 'Square 1:1', w: 21, h: 21, px: 1080 },
  story: { label: 'Story 9:16', w: 18, h: 32, px: 1080 },
  a4: { label: 'A4 page', w: 21, h: 29.7, px: 1654 },
  letter: { label: 'US Letter', w: 21.59, h: 27.94, px: 1700 },
} as const
type SizeKey = keyof typeof SIZES
const FAMILIES = ['Georgia, serif', '"Times New Roman", serif', '"Helvetica Neue", Helvetica, Arial, sans-serif']
const PAPER = '#fefdfb'
const SAMPLE = `Why my cat needs a gym

Cats climb to see, and to be seen. A shelf by the window is good; a route from the floor to the top of the room, with somewhere to rest on the way, is better.

Draw a box anywhere on a page and this text moves into it. Draw another, and it runs on from the first. What does not fit goes to the next page, and the gym grows around whatever you leave clear.

A cat needs two things from a route: a way up, and a reason to stop. So every ladder here leads to a shelf, every shelf has room for a cat, and the highest perch ends the climb.`

let nextBox = 1
const box = (x: number, y: number, w: number, h: number): Box => ({ id: nextBox++, x, y, w, h })
const startBox = (W: number, H: number) => box(W * 0.14, H * 0.1, W * 0.72, H * 0.36)
type Drag =
  | { kind: 'draw'; page: number; x0: number; y0: number; id: number }
  | { kind: 'move' | 'size'; page: number; id: number; dx: number; dy: number }

export function App() {
  const [text, setText] = useState(SAMPLE)
  const [sizeKey, setSizeKey] = useState<SizeKey>('insta')
  const [family, setFamily] = useState(FAMILIES[0])
  const [fontSize, setFontSize] = useState(26)
  const [seed, setSeed] = useState(3)
  const [cats, setCats] = useState(2)
  const [pieces, setPieces] = useState(1.4)
  const [grows, setGrows] = useState<'gym' | 'oak' | 'cats'>('gym')
  const [inkName, setInkName] = useState<'green' | 'blue'>('blue')
  const S = SIZES[sizeKey]
  const W = S.w * CM, H = S.h * CM
  const [drawn, setDrawn] = useState<Box[][]>(() => [[startBox(W, H)]])
  const [dragging, setDragging] = useState(false)
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const style: TextStyle = useMemo(() => ({ family, size: fontSize, leading: 1.35, color: '#1b2a6b' }), [family, fontSize])
  const pages = useMemo(() => flow(text, drawn, style), [text, drawn, style])

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
      while (copy.length <= page) copy.push((copy[copy.length - 1] ?? []).map((b) => ({ ...b, id: nextBox++ })))
      copy[page] = fn(copy[page])
      return copy
    })
  }

  // the gym's keep-outs: each box as far down as its text reaches, in cm, y up
  const requests = useMemo(() => pages.map((p, index) => ({
    grows, ink: inkName, w: S.w, h: S.h, seed: seed + index * 101, cats, size: grows === 'gym' ? pieces : 1, density: 1, index,
    keepouts: p.boxes.map((b) => {
      const used = dragging ? b.h : p.lines.length ? (p.used.get(b.id) ?? 0) : b.h
      const h = used > 0 ? used : text.trim() === '' ? b.h : 0
      if (h <= 0) return null
      const pad = fontSize * 0.5                       // a little air around the text, and its descenders
      return [b.x - pad, H - (b.y + h + pad), b.x + b.w + pad, H - b.y + pad].map((v) => +(v / CM).toFixed(2))
    }).filter((q): q is number[] => q !== null),
  })), [pages, S, seed, cats, pieces, H, text, dragging, fontSize, grows, inkName])

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

  async function renderAll(): Promise<Blob[]> {
    const out: Blob[] = []
    for (let i = 0; i < pages.length; i++) {
      setBusy(`Page ${i + 1} of ${pages.length}`)
      const gym = await growGym(requests[i])
      out.push(await svgToPng(pageSvg(gym, pages[i], style, W, H, PAPER), S.px, W, H))
    }
    return out
  }
  async function exportPngs() {
    try { (await renderAll()).forEach((b, i) => download(b, `cat-gym-${i + 1}.png`)) }
    catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }
  async function exportPdf() {
    try { download(await pngsToPdf(await renderAll(), W, H), 'cat-gym.pdf') }
    catch (e) { setError('Export failed: ' + String(e)) } finally { setBusy('') }
  }

  return (
    <div className="app">
      <aside className="panel">
        <h1>Studio</h1>
        <label>Your post<textarea aria-label="Your post" value={text} onChange={(e) => setText(e.target.value)} /></label>
        <p className="hint">Drag on a page to draw a text box. Drag a box to move it, its corner to resize. It regrows when you let go.</p>
        <div className="row">
          <label>What grows
            <select value={grows} onChange={(e) => { const g = e.target.value as 'gym' | 'oak' | 'cats'; setGrows(g); setInkName(g === 'oak' ? 'green' : 'blue') }}>
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
        <label>Size
          <select value={sizeKey} onChange={(e) => changeSize(e.target.value as SizeKey)}>
            {Object.entries(SIZES).map(([k, v]) => <option key={k} value={k}>{v.label}</option>)}
          </select>
        </label>
        <label>Typeface
          <select value={family} onChange={(e) => setFamily(e.target.value)}>
            {FAMILIES.map((f) => <option key={f} value={f}>{f.split(',')[0].replace(/"/g, '')}</option>)}
          </select>
        </label>
        <div className="row">
          <label>Type size<input type="number" min={10} max={90} value={fontSize} onChange={(e) => setFontSize(Math.max(10, Math.min(90, +e.target.value || 10)))} /></label>
          <label>Cats a page<input type="number" min={0} max={6} value={cats} onChange={(e) => setCats(Math.max(0, Math.min(6, +e.target.value || 0)))} /></label>
          <label>Piece size<input type="number" min={0.8} max={2.5} step={0.1} value={pieces} onChange={(e) => setPieces(Math.max(0.8, Math.min(2.5, +e.target.value || 1)))} /></label>
          <label>Seed<input type="number" min={1} value={seed} onChange={(e) => setSeed(Math.max(1, Math.round(+e.target.value) || 1))} /></label>
        </div>
        <button onClick={() => setSeed((s) => s + 1)}>Grow another</button>
        <button className="primary" disabled={!!busy} onClick={exportPngs}>Download PNGs</button>
        <button disabled={!!busy} onClick={exportPdf}>Download PDF</button>
        <p className="hint">{busy || `${pages.length} page${pages.length === 1 ? '' : 's'}. In the PDF the pages are images, so the text can't be selected.`}</p>
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
    const id = nextBox++
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
          <g fontFamily={style.family} fontSize={style.size} fill={style.color} style={{ pointerEvents: 'none', whiteSpace: 'pre' }}>
            {page.lines.map((l, i) => <text key={i} x={l.x} y={l.y}>{l.text.replace(/\n$/, '')}</text>)}
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

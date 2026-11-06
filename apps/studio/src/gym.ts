// gym.ts -- asks the worker for a page's drawing (a cat gym, an oak, flowers); one page at a time, the same request only once.
export type GymRequest = {
  grows: 'gym' | 'oak' | 'flowers' | 'kelp'; ink: 'green' | 'blue'; crown: 'lush' | 'open'; season: string; spanishmoss: boolean; heart?: 'sometimes' | 'never' | 'always'
  w: number; h: number; seed: number; cats: number; size: number; density: number; index: number
  keepouts: number[][]; ops?: boolean
  page: number                                        // which page's drawing: the index, or 0 for every page alike                 // ops: PDF operators instead of an SVG
}
const worker = new Worker(new URL('gym-worker.js', document.baseURI))
const cache = new Map<string, Promise<string>>()
const pending = new Map<number, { resolve: (s: string) => void; reject: (e: Error) => void }>()
let nextId = 1

worker.onmessage = (e: MessageEvent<{ id: number; svg?: string; error?: string }>) => {
  const p = pending.get(e.data.id)
  if (!p) return
  pending.delete(e.data.id)
  if (e.data.error || !e.data.svg) p.reject(new Error(e.data.error ?? 'no drawing came back'))
  else p.resolve(e.data.svg)
}

export function growGym(options: GymRequest): Promise<string> {
  const key = JSON.stringify(options)
  let hit = cache.get(key)
  if (!hit) {
    hit = new Promise<string>((resolve, reject) => {
      const id = nextId++
      pending.set(id, { resolve, reject })
      worker.postMessage({ id, options })
    })
    hit.catch(() => cache.delete(key))
    if (cache.size > 200) cache.clear()
    cache.set(key, hit)
  }
  return hit
}

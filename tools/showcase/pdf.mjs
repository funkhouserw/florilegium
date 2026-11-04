// prints the showcase HTML to PDF with headless Chrome, and reports text that does not fit its box
import { createRequire } from 'node:module'
import path from 'node:path'
const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), '../..')
const require = createRequire(root + '/tools/playcheck/')
const puppeteer = require('puppeteer-core')
const b = await puppeteer.launch({ executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', headless: 'new', args: ['--no-sandbox'], protocolTimeout: 600000 })
for (const name of process.argv.slice(2)) {
  const p = await b.newPage()
  await p.goto('file://' + root + '/build/showcase/' + name + '.html', { waitUntil: 'load', timeout: 300000 })
  const over = await p.evaluate(() => [...document.querySelectorAll('[data-check]')].map((d, i) => d.scrollHeight > d.clientHeight + 1 ? `box ${i}: ${d.scrollHeight} > ${d.clientHeight}` : null).filter(Boolean))
  console.log(name, 'text overflow:', over.length ? over.join('; ') : 'none')
  await p.pdf({ path: root + '/build/showcase/' + name + '.pdf', preferCSSPageSize: true, printBackground: true, timeout: 600000 })
  await p.close()
}
await b.close()

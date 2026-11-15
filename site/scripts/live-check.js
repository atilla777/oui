// Read-back check for a deployed site. It never starts a local server: the
// caller supplies the live origin, and failing assertions exit non-zero.
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { pages, mediaSection, expectedMediaCount, mediaStates } from './site-pages.js'
import { parseOrigin } from './live-origin.js'

const usage = 'Usage: node scripts/live-check.js <origin> (for example https://atilla777.github.io)'
const origin = parseOrigin(process.argv[2])
if (!origin) {
  console.error(usage)
  process.exit(1)
}
const media = JSON.parse(await readFile('data/media.json', 'utf8'))
const get = path => fetch(origin + path, { signal: AbortSignal.timeout(15000) })
const checkPng = async (image, record) => {
  const response = await get(image)
  assert.equal(response.status, 200, image)
  assert.match(response.headers.get('content-type'), /^image\/png/, image)
  const bytes = Buffer.from(await response.arrayBuffer())
  assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a', image)
  assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256, image)
}
console.log(`live origin ${origin}`)
for (const [path, lang, title, other] of pages) {
  const response = await get('/oui/' + path)
  assert.equal(response.status, 200, path)
  assert.match(response.headers.get('content-type'), /^text\/html/, path)
  const html = await response.text()
  assert.match(html, new RegExp(`<html lang="${lang}"`), path)
  assert.ok(html.includes(title), path)
  assert.ok(html.includes(`href="${other}"`), path)
  const markup = html.split('<script>window.__VP_HASH_MAP__')[0]
  const section = mediaSection(path)
  if (section) {
    const records = media.records.filter(item => item.section === section && item.uiLocale === lang)
    assert.equal(records.length, expectedMediaCount(section), path)
    for (const record of records) {
      const image = `/oui/${record.path}`
      assert.ok(markup.includes(`src="${image}"`), `missing no-JS image ${path}`)
      assert.ok(markup.includes(`alt="${record.alt[lang]}"`), `${image} alt`)
      await checkPng(image, record)
    }
  }
  for (const [id, states] of mediaStates) if (path.includes(`capabilities/${id}`)) {
    for (const state of states) {
      const record = media.records.find(item => item.id === `${id}-${lang}-${state}`)
      assert.ok(record, `${id}-${lang}-${state}: manifest record`)
      const image = `/oui/${record.path}`
      assert.ok(markup.includes(`src="${image}"`), `${image} reference`)
      assert.ok(markup.includes(`alt="${record.alt[lang]}"`), `${image} alt`)
      await checkPng(image, record)
    }
  }
  const asset = html.match(/(?:src|href)="(\/oui\/assets\/[^" ]+\.(?:js|css))"/)
  assert.ok(asset, `missing asset in ${path}`)
  const resource = await get(asset[1])
  assert.equal(resource.status, 200, asset[1])
  assert.match(resource.headers.get('content-type'), /^(text\/css|text\/javascript)/, asset[1])
  console.log(`OK ${path || '/'} lang=${lang} asset=${asset[1]}`)
}
assert.equal((await get('/oui/en/guide/using-oui')).status, 200, 'clean URL')
assert.notEqual((await get('/oui/missing.html')).status, 200, 'missing page')
console.log(`live read-back verified: ${pages.length} pages, clean URL and missing-page boundary at ${origin}`)
// Compact live-URL browser check. It observes a deployed origin only: one own
// headless Chromium with a fresh profile, all requests outside the origin
// blocked. Local-preview-only behaviours (404/405, traversal, preview route
// boundaries) are covered by check:browser and check:http instead.
import assert from 'node:assert/strict'
import { mkdtemp, mkdir } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { chromium } from 'playwright-core'
import { parseOrigin } from './live-origin.js'

const usage = 'Usage: node scripts/live-browser-check.js <origin> (for example https://atilla777.github.io)'
const origin = parseOrigin(process.argv[2])
if (!origin) {
  console.error(usage)
  process.exit(1)
}
const artifacts = await mkdtemp(join(process.env.OUI_BROWSER_ARTIFACT_ROOT || tmpdir(), 'oui-live-browser-'))
const profile = join(artifacts, 'profile')
await mkdir(profile)
console.log(`artifacts=${artifacts}`)
const environment = { ...process.env }
for (const key of ['DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XAUTHORITY', 'DBUS_SESSION_BUS_ADDRESS']) delete environment[key]
const pageErrors = []
const forbidden = []
let browser
try {
  browser = await chromium.launchPersistentContext(profile, {
    executablePath: '/usr/bin/chromium', headless: true, chromiumSandbox: true,
    env: environment, timeout: 20000
  })
  browser.setDefaultTimeout(7000)
  browser.setDefaultNavigationTimeout(12000)
  console.log(`browser=${browser.browser()?.version()} executable=/usr/bin/chromium profile=${profile} origin=${origin}`)
  await browser.route('**/*', route => {
    const url = route.request().url()
    if (url === origin || url.startsWith(origin + '/')) return route.continue()
    forbidden.push(url)
    return route.abort('blockedbyclient')
  })
  const page = browser.pages()[0] || await browser.newPage()
  page.on('pageerror', error => { pageErrors.push(error.message); console.error('pageerror:', error) })
  const go = async path => {
    await page.goto('about:blank')
    const response = await page.goto(origin + path)
    assert.equal(response.status(), 200, path)
    // The theme switch only gets its localized title after hydration; pressing a
    // global hotkey before that point is a race, not a site failure.
    await page.waitForFunction(() => [...document.querySelectorAll('.VPSwitchAppearance')].some(x => x.title))
  }
  const checkPage = async (lang, title) => {
    await page.waitForFunction(expected => document.querySelector('h1')?.innerText.replace(/\u200b/g, '').trim() === expected, title)
    assert.equal(await page.locator('html').getAttribute('lang'), lang)
    assert.equal((await page.locator('h1').first().innerText()).replace(/\u200b/g, '').trim(), title)
  }
  const search = async (lang, term, screenshot) => {
    await page.keyboard.press('Control+k')
    const input = page.locator('#localsearch-input')
    await input.waitFor({ state: 'visible' })
    await input.fill(term)
    const results = page.locator('.results .result')
    await results.first().waitFor({ state: 'visible' })
    assert.ok(await results.count() > 0, `${term}: no results`)
    const urls = await results.evaluateAll(nodes => nodes.map(node => node.getAttribute('href')))
    assert.ok(urls.every(url => url.startsWith(`/oui/${lang}/`)), `${term}: ${JSON.stringify(urls)}`)
    if (screenshot) await page.screenshot({ path: join(artifacts, screenshot), fullPage: true })
    await page.keyboard.press('Escape')
    await input.waitFor({ state: 'hidden' })
    console.log(`PASS search ${lang} "${term}": ${urls.length} localized results, Escape closes`)
  }
  await go('/oui/en/catalogue.html')
  await checkPage('en', 'Capability catalogue')
  await page.screenshot({ path: join(artifacts, 'en-catalogue.png'), fullPage: true })
  await search('en', 'Atlas', 'en-search.png')

  await go('/oui/ru/catalogue.html')
  await checkPage('ru', 'Каталог возможностей')
  await page.screenshot({ path: join(artifacts, 'ru-catalogue.png'), fullPage: true })
  await search('ru', 'Атлас')

  await page.locator('.content-container a[lang="en"]').click()
  await page.waitForURL('**/oui/en/catalogue.html')
  await checkPage('en', 'Capability catalogue')
  await page.screenshot({ path: join(artifacts, 'en-catalogue-switched.png'), fullPage: true })
  console.log('PASS language link: RU catalogue retained the page key in English')

  await go('/oui/en/capabilities/atlas.html')
  await checkPage('en', 'Atlas')
  const images = page.locator('main p > img')
  const count = await images.count()
  assert.ok(count > 0, 'atlas page has no images')
  await page.waitForFunction(() => [...document.querySelectorAll('main p > img')].every(image => image.complete && image.naturalWidth > 0))
  assert.ok(await images.evaluateAll(nodes => nodes.every(image => image.naturalWidth > 0)), 'image did not load')
  await page.screenshot({ path: join(artifacts, 'en-atlas.png'), fullPage: true })
  console.log(`PASS images: ${count} Atlas images loaded`)

  assert.deepEqual(forbidden, [], 'unexpected requests outside the live origin')
  assert.deepEqual(pageErrors, [], 'browser page errors')
  console.log(`live browser check verified at ${origin}`)
} finally {
  try { if (browser) await browser.close() }
  finally { console.log(`cleanup browser closed; artifacts=${artifacts}`) }
}
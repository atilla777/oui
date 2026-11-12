import assert from 'node:assert/strict'
import { mkdtemp, mkdir, readFile, readdir } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { chromium } from 'playwright-core'
import { startPreview } from './preview.js'

const artifacts = await mkdtemp(join(process.env.OUI_BROWSER_ARTIFACT_ROOT || tmpdir(), 'oui-browser-'))
const profile = join(artifacts, 'profile')
await mkdir(profile)
console.log(`artifacts=${artifacts}`)
const server = await startPreview(0)
const address = server.address()
const origin = `http://${address.address}:${address.port}`
let browser
let ownerPid
let forbidden = []
const pageErrors = []
const environment = { ...process.env }
for (const key of ['DISPLAY', 'WAYLAND_DISPLAY', 'WAYLAND_SOCKET', 'XAUTHORITY', 'DBUS_SESSION_BUS_ADDRESS']) delete environment[key]
try {
  assert.equal(address.address, '127.0.0.1')
  browser = await chromium.launchPersistentContext(profile, {
    executablePath: '/usr/bin/chromium', headless: true, chromiumSandbox: true,
    env: environment, timeout: 20000
  })
  browser.setDefaultTimeout(7000)
  browser.setDefaultNavigationTimeout(12000)
  console.log(`browser=${browser.browser()?.version()} executable=/usr/bin/chromium profile=${profile} preview=${origin}`)
  await browser.route('**/*', route => {
    const url = route.request().url()
    if (url.startsWith(origin + '/oui/')) return route.continue()
    forbidden.push(url)
    return route.abort('blockedbyclient')
  })
  const page = browser.pages()[0] || await browser.newPage()
  page.on('pageerror', error => { pageErrors.push(error.message); console.error('pageerror:', error) })
  const assetResponses = new Set()
  page.on('response', response => {
    if (response.url().startsWith(origin + '/oui/assets/') && response.status() === 200) assetResponses.add(response.url())
  })
  const go = async path => {
    await page.goto('about:blank')
    const response = await page.goto(origin + path, { waitUntil: 'networkidle' })
    assert.equal(response.status(), 200, path)
    await page.waitForFunction(() => [...document.querySelectorAll('.VPSwitchAppearance')].some(x => x.title))
  }
  const focusByTab = async (selector, activePage = page) => {
    // Count a conservative superset of sequential focus candidates, including
    // hidden/disabled/negative-tabindex nodes. Allow a complete wrap from the
    // current focus, including the browser's document boundary.
    const candidates = await activePage.locator('a[href], area[href], button, input, select, textarea, iframe, object, embed, summary, [contenteditable], [tabindex]').count()
    const limit = 2 * (candidates + 1)
    for (let i = 0; i <= limit; i++) {
      if (await activePage.locator(selector).evaluateAll(nodes => nodes.includes(document.activeElement))) return
      if (i === limit) break
      await activePage.keyboard.press('Tab')
    }
    throw new Error(`keyboard could not reach ${selector} after ${limit} tabs (${candidates} candidates)`)
  }
  const fixture = await browser.newPage()
  try {
    await fixture.setContent(`<main>${'<button>Step</button>'.repeat(65)}<a href="#reached" id="reachable">Target</a><button id="unreachable" tabindex="-1">Not tabbable</button></main>`)
    await focusByTab('#reachable', fixture)
    assert.equal(await fixture.evaluate(() => document.activeElement.id), 'reachable')
    await fixture.keyboard.press('Enter')
    await fixture.waitForURL(url => url.hash === '#reached')
    assert.equal(new URL(fixture.url()).hash, '#reached')
    await assert.rejects(focusByTab('#unreachable', fixture), /keyboard could not reach #unreachable after \d+ tabs/)
    console.log('PASS keyboard traversal fixture: >50 tabs, Enter, and finite unreachable failure')
  } finally { await fixture.close() }
  const checkPage = async (lang, title) => {
    await page.waitForFunction(expected => document.querySelector('h1')?.innerText.replace(/\u200b/g, '').trim() === expected, title)
    assert.equal(await page.locator('html').getAttribute('lang'), lang)
    assert.equal((await page.locator('h1').first().innerText()).replace(/\u200b/g, '').trim(), title)
    assert.ok((await page.title()).includes(title))
    assert.ok(await page.locator('main').innerText())
  }
  await go('/oui/')
  // Identify only our own browser by its unique profile, then examine its descendants.
  const pids = (await readdir('/proc')).filter(x => /^\d+$/.test(x))
  const candidates = await Promise.all(pids.map(async pid => {
    try { return [pid, (await readFile(`/proc/${pid}/cmdline`)).toString().split('\0')] } catch { return [pid, []] }
  }))
  const owner = candidates.find(([, args]) => args.includes(`--user-data-dir=${profile}`) && !args.some(x => x.startsWith('--type=')))
  assert.ok(owner, 'could not identify own Chromium process')
  ownerPid = owner[0]
  assert.ok(!owner[1].includes('--no-sandbox') && !owner[1].includes('--disable-setuid-sandbox'), 'sandbox disabled')
  assert.ok(owner[1].includes('--disable-background-networking'), 'background networking not disabled')
  const descendants = async pid => {
    let children = ''
    try { children = await readFile(`/proc/${pid}/task/${pid}/children`, 'utf8') } catch { return [] }
    const direct = children.trim().split(/\s+/).filter(Boolean)
    return [...direct, ...(await Promise.all(direct.map(descendants))).flat()]
  }
  const childArgs = await Promise.all((await descendants(owner[0])).map(async pid => {
    try { return [pid, (await readFile(`/proc/${pid}/cmdline`)).toString().split('\0')] } catch { return [pid, []] }
  }))
  const flag = (args, name) => new RegExp(`(?:^|\\s)${name}(?:\\s|$)`).test(args.join(' '))
  assert.ok(childArgs.every(([, args]) => !flag(args, '--no-sandbox') && !flag(args, '--disable-setuid-sandbox')), 'child disabled sandbox')
  const renderer = childArgs.find(([, args]) => flag(args, '--type=renderer'))
  assert.ok(renderer, 'no own renderer process')
  const status = await readFile(`/proc/${renderer[0]}/status`, 'utf8')
  assert.match(status, /^Seccomp:\s+2$/m)
  console.log(`sandbox browser-pid=${owner[0]} renderer-pid=${renderer[0]} renderer-seccomp=2 no-sandbox-flags=absent`)
  await checkPage('en', 'oui: an experimental Odin UI kit')
  assert.equal(await page.locator('a[href="/oui/en/"]').count() > 0, true)
  assert.equal(await page.locator('a[href="/oui/ru/"]').count() > 0, true)

  for (const width of [360, 1280]) {
    await page.setViewportSize({ width, height: 900 })
    for (const [lang, title, other] of [['en', 'Using oui', 'ru'], ['ru', 'Использование oui', 'en']]) {
      await go(`/oui/${lang}/guide/using-oui.html`)
      await checkPage(lang, title)
      await page.waitForFunction(() => [...document.querySelectorAll('.VPSwitchAppearance')].some(x => x.title))
      const titleExpected = lang === 'ru' ? 'Включить тёмную тему' : 'Switch to dark theme'
      assert.equal(await page.locator('.VPSwitchAppearance').first().getAttribute('title'), titleExpected)
      const measurements = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth, font: parseFloat(getComputedStyle(document.querySelector('main p')).fontSize) }))
      assert.ok(measurements.scroll <= measurements.client, `${lang} ${width} overflow ${JSON.stringify(measurements)}`)
      assert.ok(measurements.font >= 14, `${lang} ${width} unreadable font`)
      assert.ok(await page.locator('main p').first().isVisible())
      await page.screenshot({ path: join(artifacts, `${lang}-${width}.png`), fullPage: true })
      await page.keyboard.press('Tab')
      assert.equal(await page.evaluate(() => document.activeElement.classList.contains('VPSkipLink')), true)
      assert.equal((await page.locator('.VPSkipLink').innerText()).trim(), lang === 'ru' ? 'Перейти к содержимому' : 'Skip to content')
      await page.keyboard.press('Enter')
      assert.equal(new URL(page.url()).hash, '#VPContent')
      assert.notEqual(await page.evaluate(() => document.activeElement.tagName), 'BODY')
      if (width === 360) {
        await page.reload({ waitUntil: 'networkidle' })
        await focusByTab('.VPLocalNav .menu')
        await page.keyboard.press('Enter')
        assert.equal(await page.locator('.VPLocalNav .menu').getAttribute('aria-expanded'), 'true')
        assert.ok(await page.locator('#VPSidebarNav').isVisible())
        await page.keyboard.press('Escape')
        assert.equal(await page.locator('.VPLocalNav .menu').getAttribute('aria-expanded'), 'false')
        await focusByTab('.VPLocalNav .menu')
        await page.keyboard.press('Enter')
        await focusByTab(`#VPSidebarNav a[href="/oui/${lang}/"]`)
        await page.keyboard.press('Enter')
        await page.waitForURL(`**/oui/${lang}/`)
        await checkPage(lang, lang === 'en' ? 'Introducing oui' : 'Знакомство с oui')
      }
      await go(`/oui/${lang}/guide/using-oui.html#choose-a-boundary`)
      await focusByTab(`.content-container a[lang="${other}"]`)
      await page.keyboard.press('Enter')
      try { await page.waitForURL(`**/oui/${other}/guide/using-oui.html#choose-a-boundary`) }
      catch (error) { console.error('switch actual URL:', page.url()); throw error }
      await checkPage(other, other === 'en' ? 'Using oui' : 'Использование oui')
      assert.equal(new URL(page.url()).hash, '#choose-a-boundary')
      await focusByTab(`.content-container a[lang="${lang}"]`)
      await page.keyboard.press('Enter')
      await page.waitForURL(`**/oui/${lang}/guide/using-oui.html#choose-a-boundary`)
      await checkPage(lang, title)
      await go(`/oui/${lang}/guide/using-oui.html#missing-anchor`)
      await focusByTab(`.content-container a[lang="${other}"]`)
      await page.keyboard.press('Enter')
      await page.waitForURL(`**/oui/${other}/guide/using-oui.html`)
      assert.equal(new URL(page.url()).hash, '')
      await checkPage(other, other === 'en' ? 'Using oui' : 'Использование oui')
      console.log(`PASS ${lang} ${width}: hydrated chrome, width, keyboard, switching valid/missing hashes`)
    }
  }
  const samplePages = [
    ['catalogue.html', 'Capability catalogue', 'Каталог возможностей', 'layout'],
    ['capabilities/layout.html', 'Layout', 'Компоновка', 'boundaries'],
    ['capabilities/controls.html', 'Controls', 'Элементы управления', 'boundaries'],
    ['capabilities/styling.html', 'Styling', 'Оформление', 'boundaries'],
    ['capabilities/profiles.html', 'Profiles', 'Профили', 'workflow'],
    ['capabilities/text-input.html', 'Text input', 'Ввод текста', 'boundaries']
  ]
  const imagePaths = (path, lang) => ['capabilities/layout.html', 'capabilities/text-input.html'].includes(path)
    ? [`/oui/media/${path.split('/')[1].replace('.html', '')}-${lang}.png`]
    : path === 'capabilities/profiles.html'
      ? [`/oui/media/profiles-${lang}-initial.png`, `/oui/media/profiles-${lang}-dialog.png`, `/oui/media/profiles-${lang}-applied.png`]
      : ['controls', 'styling'].includes(path.split('/')[1]?.replace('.html', ''))
        ? ['initial', 'changed'].map(state => `/oui/media/${path.split('/')[1].replace('.html', '')}-${lang}-${state}.png`)
        : []
  const sampleName = path => path.startsWith('capabilities/') ? path.split('/')[1].replace('.html', '') : 'catalogue'
  const checkImages = async (activePage, path, lang) => {
    for (const src of imagePaths(path, lang)) {
      const image = activePage.locator(`main img[src="${src}"]`).first()
      assert.ok(await image.isVisible(), `missing image ${src}`)
      assert.ok(await image.evaluate(el => el.complete && el.naturalWidth === 1280 && el.naturalHeight === 960 && !!el.alt), `invalid image ${src}`)
    }
  }
  for (const width of [360, 1280]) {
    await page.setViewportSize({ width, height: 900 })
    for (const [lang, term, expected, empty, reset, category] of [
      ['en', 'clipping', 'Layout', 'No results found.', 'Reset filters', 'Category'],
      ['ru', 'обрезание', 'Компоновка', 'Ничего не найдено.', 'Сбросить фильтры', 'Категория']
    ]) {
      await go(`/oui/${lang}/catalogue.html`)
      const query = page.getByLabel(lang === 'en' ? 'Search catalogue' : 'Поиск в каталоге')
      const select = page.getByLabel(category)
      await focusByTab('.catalogue-controls input')
      await page.keyboard.insertText(term)
      assert.ok(await page.locator('#layout').isVisible())
      assert.equal(await page.locator('#controls').isVisible(), false)
      assert.equal(await page.locator('#styling').isVisible(), false)
      assert.equal(await page.locator('#profiles').isVisible(), false)
      await select.selectOption('geometry')
      assert.equal(await select.locator('option:checked').innerText(), lang === 'en' ? 'Geometry' : 'Геометрия')
      assert.ok(await page.locator('#layout').isVisible())
      await query.fill(lang === 'en' ? 'slider' : 'ползунок')
      assert.equal(await page.locator('#layout').isVisible(), false)
      assert.equal(await page.locator('#controls').isVisible(), false)
      assert.equal(await page.locator('#styling').isVisible(), false)
      await select.selectOption('controls')
      assert.ok(await page.locator('#controls').isVisible())
      assert.equal(await page.locator('#styling').isVisible(), false)
      await query.fill(lang === 'en' ? 'cascade' : 'каскад')
      assert.equal(await page.locator('#controls').isVisible(), false)
      await select.selectOption('styling')
      assert.ok(await page.locator('#styling').isVisible())
      assert.equal(await page.locator('#layout').isVisible(), false)
      assert.equal(await page.locator('#text-input').isVisible(), false)
      await query.fill('ui_editor')
      assert.equal(await select.locator('option[value="text"]').innerText(), lang === 'en' ? 'Text' : 'Текст')
      assert.equal(await select.locator('option[value="input"]').innerText(), lang === 'en' ? 'Input' : 'Ввод')
      await select.selectOption('input')
      assert.equal(await select.locator('option:checked').innerText(), lang === 'en' ? 'Input' : 'Ввод')
      assert.ok(await page.locator('#text-input').isVisible())
      assert.equal(await page.locator('#layout').isVisible(), false)
      assert.equal(await page.locator('#controls').isVisible(), false)
      assert.equal(await page.locator('#styling').isVisible(), false)
      await page.screenshot({ path: join(artifacts, `filter-text-input-${lang}-${width}.png`), fullPage: true })
      await focusByTab('.catalogue-filter a[href="./capabilities/text-input.html"]')
      await page.keyboard.press('Enter')
      await page.waitForURL(`**/oui/${lang}/capabilities/text-input.html`)
      await go(`/oui/${lang}/catalogue.html`)
      await query.fill(lang === 'en' ? 'draft' : 'черновик')
      await select.selectOption('state')
      assert.equal(await select.locator('option:checked').innerText(), lang === 'en' ? 'State' : 'Состояние')
      assert.ok(await page.locator('#profiles').isVisible())
      assert.equal(await page.locator('#controls').isVisible(), false)
      await query.fill('zzznomatch')
      assert.equal(await page.locator('#layout').isVisible(), false)
      assert.equal(await page.locator('.catalogue-filter [role=status]').innerText(), empty)
      await page.screenshot({ path: join(artifacts, `filter-empty-${lang}-${width}.png`), fullPage: true })
      await focusByTab('.catalogue-controls button')
      await page.keyboard.press('Enter')
      assert.equal(await query.inputValue(), '')
      assert.equal(await select.inputValue(), '')
      assert.ok(await page.locator('#layout').isVisible())
      assert.ok(await page.locator('#controls').isVisible())
      assert.ok(await page.locator('#styling').isVisible())
      assert.ok(await page.locator('#text-input').isVisible())
      assert.ok(await page.locator('#profiles').isVisible())
      await select.selectOption('layout')
      await query.fill('ui_layout')
      assert.ok(await page.locator('#layout').isVisible())
      assert.equal(await page.getByRole('button', { name: reset }).count(), 1)
      await page.screenshot({ path: join(artifacts, `filter-${lang}-${width}.png`), fullPage: true })
      await focusByTab('.catalogue-filter a[href="./capabilities/layout.html"]')
      await page.keyboard.press('Enter')
      await page.waitForURL(`**/oui/${lang}/capabilities/layout.html`)
      assert.equal(new URL(page.url()).pathname, `/oui/${lang}/capabilities/layout.html`)
      await go(`/oui/${lang}/guide/using-oui.html`)
      await page.keyboard.press('Control+k')
      const input = page.locator('#localsearch-input')
      await input.waitFor({ state: 'visible' })
      await input.fill('zzznomatch987654')
      await page.locator('.no-results').waitFor({ state: 'visible' })
      assert.ok((await page.locator('.no-results').innerText()).includes(lang === 'en' ? 'No results for' : 'Нет результатов для'))
      await page.screenshot({ path: join(artifacts, `search-empty-${lang}-${width}.png`), fullPage: true })
      assert.equal(await page.locator('.clear-button').getAttribute('title'), lang === 'en' ? 'Reset search' : 'Очистить поиск')
      await focusByTab('.clear-button')
      await page.keyboard.press('Enter')
      assert.equal(await input.inputValue(), '')
      await input.fill(expected)
      await page.locator('.results .result').first().waitFor({ state: 'visible' })
      const urls = await page.locator('.results .result').evaluateAll(nodes => nodes.map(node => node.getAttribute('href')))
      assert.ok(urls.every(url => url.startsWith(`/oui/${lang}/`)), JSON.stringify(urls))
      await page.screenshot({ path: join(artifacts, `search-results-${lang}-${width}.png`), fullPage: true })
      await input.focus()
      await page.keyboard.press('ArrowDown')
      const selectedHref = await page.locator('.results [aria-selected="true"] a').getAttribute('href')
      await page.keyboard.press('Enter')
      await page.waitForURL(url => url.pathname + url.hash === selectedHref)
      assert.notEqual(new URL(page.url()).pathname, `/oui/${lang}/guide/using-oui.html`)
      assert.ok(!await input.isVisible())
      console.log(`PASS search/filter ${lang} ${width}: localized query, empty, reset and keyboard selection`)
    }
  }
  for (const width of [360, 1280]) {
    await page.setViewportSize({ width, height: 900 })
    for (const [path, en, ru, anchor] of samplePages) {
      for (const [lang, title, other, otherTitle] of [['en', en, 'ru', ru], ['ru', ru, 'en', en]]) {
        await go(`/oui/${lang}/${path}`)
        await checkPage(lang, title)
        const dimensions = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, client: document.documentElement.clientWidth }))
        assert.ok(dimensions.scroll <= dimensions.client, `${path} ${lang} ${width} overflow ${JSON.stringify(dimensions)}`)
        assert.ok(await page.locator('main p').first().isVisible())
        await checkImages(page, path, lang)
        await page.screenshot({ path: join(artifacts, `${lang}-${sampleName(path)}-${width}.png`), fullPage: true })
        await page.keyboard.press('Tab')
        assert.equal(await page.evaluate(() => document.activeElement.classList.contains('VPSkipLink')), true)
        await page.keyboard.press('Enter')
        assert.equal(new URL(page.url()).hash, '#VPContent')
        await go(`/oui/${lang}/${path}#${anchor}`)
        await focusByTab(`.content-container a[lang="${other}"]`)
        await page.keyboard.press('Enter')
        await page.waitForURL(`**/oui/${other}/${path}#${anchor}`)
        await checkPage(other, otherTitle)
        await go(`/oui/${lang}/${path}#missing-anchor`)
        await focusByTab(`.content-container a[lang="${other}"]`)
        await page.keyboard.press('Enter')
        await page.waitForURL(`**/oui/${other}/${path}`)
        assert.equal(new URL(page.url()).hash, '')
        await checkPage(other, otherTitle)
        console.log(`PASS sample ${path} ${lang} ${width}: keyboard, width, locale valid/missing anchors`)
      }
    }
  }
  for (const width of [360, 1280]) {
    await page.setViewportSize({ width, height: 900 })
    for (const lang of ['en', 'ru']) {
      await go(`/oui/${lang}/capabilities/layout.html`)
      const open = page.locator('.viewer-open')
      const dialog = page.locator('.layout-viewer dialog')
      const close = dialog.locator('button')
      const select = dialog.locator('select')
      await focusByTab('.viewer-open')
      await page.keyboard.press('Enter')
      assert.ok(await dialog.evaluate(el => el.open))
      assert.ok(await close.evaluate(el => el === document.activeElement))
      assert.equal(await select.inputValue(), 'large')
      assert.ok(await dialog.locator('img').evaluate((el, locale) => el.src.endsWith(`/layout-${locale}.png`) && el.naturalWidth === 1280, lang))
      await select.selectOption('small')
      assert.ok(await dialog.locator('img').evaluate((el, locale) => el.src.endsWith(`/layout-small-${locale}.png`) && el.naturalWidth === 960 && el.naturalHeight === 720, lang))
      assert.ok((await dialog.locator('figcaption').innerText()).includes('960×720'))
      await select.focus()
      await page.keyboard.press('Tab')
      assert.ok(await close.evaluate(el => el === document.activeElement), 'forward focus escaped dialog')
      await page.keyboard.press('Shift+Tab')
      assert.ok(await select.evaluate(el => el === document.activeElement), 'reverse focus escaped dialog')
      await page.evaluate(() => document.querySelector('main a')?.focus())
      assert.ok(await dialog.evaluate(el => el.contains(document.activeElement)), 'programmatic focus escaped dialog')
      await page.screenshot({ path: join(artifacts, `viewer-${lang}-${width}.png`) })
      await page.keyboard.press('Escape')
      assert.ok(!(await dialog.evaluate(el => el.open)))
      assert.ok(await open.evaluate(el => el === document.activeElement), 'Escape did not restore focus')
      await open.click()
      await close.click()
      assert.ok(await open.evaluate(el => el === document.activeElement), 'close did not restore focus')
      console.log(`PASS viewer ${lang} ${width}: keyboard and pointer, state, focus containment, Escape and close`)
    }
  }
  assert.ok(assetResponses.size > 0, 'no static assets loaded')
  await page.emulateMedia({ reducedMotion: 'reduce' })
  assert.equal(await page.evaluate(() => matchMedia('(prefers-reduced-motion: reduce)').matches), true)
  await go('/oui/en/guide/using-oui.html')
  assert.ok(await page.locator('main p').first().isVisible())
  assert.equal(await page.locator('main a').first().evaluate(el => getComputedStyle(el).transitionDuration), '0s')
  assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior), 'auto')
  for (const [path, en, ru] of samplePages) {
    for (const [lang, title] of [['en', en], ['ru', ru]]) {
      await go(`/oui/${lang}/${path}`)
      await checkPage(lang, title)
      assert.ok(await page.locator('main p').first().isVisible())
      assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior), 'auto')
      await checkImages(page, path, lang)
    }
  }
  for (const width of [360, 1280]) {
    await page.setViewportSize({ width, height: 900 })
    for (const lang of ['en', 'ru']) {
      await go(`/oui/${lang}/capabilities/layout.html`)
      await page.locator('.viewer-open').click()
      assert.ok(await page.locator('.layout-viewer dialog').evaluate(el => el.open && getComputedStyle(el).animationName === 'none'))
      await page.keyboard.press('Escape')
    }
  }
  console.log('PASS reduced motion: preference, transition duration, scrolling and prose visibility')

  const nojs = await chromium.launchPersistentContext(join(artifacts, 'profile-nojs'), {
    executablePath: '/usr/bin/chromium', headless: true, chromiumSandbox: true,
    env: environment, timeout: 20000, javaScriptEnabled: false, viewport: { width: 360, height: 900 }
  })
  try {
    await nojs.route('**/*', route => {
      const url = route.request().url()
      if (url.startsWith(origin + '/oui/')) return route.continue()
      forbidden.push(url); return route.abort('blockedbyclient')
    })
    const p = await nojs.newPage()
    p.setDefaultTimeout(7000)
    for (const [path, lang, heading] of [['/oui/', 'en', 'oui: an experimental Odin UI kit'], ['/oui/en/', 'en', 'Introducing oui'], ['/oui/ru/', 'ru', 'Знакомство с oui'], ['/oui/en/guide/using-oui.html', 'en', 'Using oui'], ['/oui/ru/guide/using-oui.html', 'ru', 'Использование oui']]) {
      assert.equal((await p.goto(origin + path)).status(), 200)
      assert.equal(await p.locator('html').getAttribute('lang'), lang)
      assert.equal((await p.locator('h1').first().innerText()).replace(/\u200b/g, '').trim(), heading)
      assert.ok(await p.locator('main p').first().isVisible())
      assert.ok(await p.locator('main a').first().isVisible())
      assert.equal(await p.evaluate(() => typeof window.__VP_SITE_DATA__), 'undefined')
      await p.keyboard.press('Tab')
      assert.equal(await p.evaluate(() => document.activeElement.tagName), 'A')
      if (path.startsWith('/oui/en/') || path.startsWith('/oui/ru/')) {
        const other = lang === 'en' ? 'ru' : 'en'
        await focusByTab(`.content-container a[lang="${other}"]`, p)
        await p.keyboard.press('Enter')
        await p.waitForURL(path.includes('/guide/') ? `**/oui/${other}/guide/using-oui.html` : `**/oui/${other}/`)
        assert.equal(await p.locator('html').getAttribute('lang'), other)
        assert.ok(await p.locator('main p').first().isVisible())
      }
    }
    for (const width of [360, 1280]) {
      await p.setViewportSize({ width, height: 900 })
      for (const [path, en, ru] of samplePages) {
        for (const [lang, heading, other] of [['en', en, 'ru'], ['ru', ru, 'en']]) {
          assert.equal((await p.goto(`${origin}/oui/${lang}/${path}`)).status(), 200)
          assert.equal(await p.locator('html').getAttribute('lang'), lang)
          assert.equal((await p.locator('h1').first().innerText()).replace(/\u200b/g, '').trim(), heading)
          assert.ok(await p.locator('main p').first().isVisible())
          if (path === 'catalogue.html') {
            for (const id of ['layout', 'controls', 'styling', 'profiles', 'text-input']) {
              const link = p.locator(`main a[href="./capabilities/${id}.html"]`)
              assert.ok(await link.isVisible())
              assert.equal(await link.evaluate(el => new URL(el.href).pathname), `/oui/${lang}/capabilities/${id}.html`)
            }
          }
          assert.equal(await p.evaluate(() => typeof window.__VP_SITE_DATA__), 'undefined')
          await checkImages(p, path, lang)
          if (path === 'capabilities/layout.html') {
              const small = p.locator(`main img[src="/oui/media/layout-small-${lang}.png"]`)
              assert.ok(await small.isVisible())
              assert.ok(await small.evaluate(el => el.complete && el.naturalWidth === 960 && el.naturalHeight === 720 && !!el.alt))
              assert.equal(await p.locator(`main a[href="/oui/media/layout-small-${lang}.png"]`).count(), 1)
              assert.equal(await p.locator(`main a[href="/oui/media/layout-${lang}.png"]`).count(), 1)
              assert.equal(await p.locator('.viewer-open').count(), 0)
          }
          await p.screenshot({ path: join(artifacts, `nojs-${lang}-${sampleName(path)}-${width}.png`), fullPage: true })
          await focusByTab(`.content-container a[lang="${other}"]`, p)
          await p.keyboard.press('Enter')
          await p.waitForURL(`**/oui/${other}/${path}`)
          assert.equal(await p.locator('html').getAttribute('lang'), other)
          console.log(`PASS no-JS sample ${path} ${lang} ${width}: prose, image where present, keyboard locale`)
        }
      }
    }
    console.log('PASS no-JS: root, introductions, nested prose, links and keyboard focus')
  } finally { await nojs.close() }
  assert.deepEqual(forbidden, [], 'unexpected external network requests')
  assert.deepEqual(pageErrors, [], 'browser page errors')
} finally {
  try { if (browser) await browser.close() }
  finally {
    server.closeAllConnections()
    await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  }
  if (ownerPid) {
    let cmd = ''
    try { cmd = (await readFile(`/proc/${ownerPid}/cmdline`)).toString() } catch (error) { if (error.code !== 'ENOENT') throw error }
    assert.ok(!cmd.includes(profile), 'owned Chromium process still running')
  }
  console.log(`cleanup browser closed; preview listening=${server.listening}; artifacts=${artifacts}`)
}

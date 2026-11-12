import assert from 'node:assert/strict'
import { request } from 'node:http'
import { readFile } from 'node:fs/promises'
import { createHash } from 'node:crypto'
import { startPreview } from './preview.js'

const media = JSON.parse(await readFile('data/media.json', 'utf8'))
const server = await startPreview(0)
const address = server.address()
const origin = `http://127.0.0.1:${address.port}`
const get = (path, options = {}) => fetch(origin + path, { ...options, signal: AbortSignal.timeout(5000) })
try {
  assert.equal(address.address, '127.0.0.1')
  assert.equal(address.family, 'IPv4')
  assert.ok(address.port > 0)
  console.log(`owned listener ${address.address}:${address.port}`)
  for (const [path, lang, title, other] of [
    ['', 'en', 'experimental Odin UI kit', '/oui/ru/'],
    ['en/', 'en', 'Introducing oui', '/oui/ru/'],
    ['ru/', 'ru', 'Знакомство с oui', '/oui/en/'],
    ['en/guide/using-oui.html', 'en', 'Using oui', '/oui/ru/guide/using-oui.html'],
    ['ru/guide/using-oui.html', 'ru', 'Использование oui', '/oui/en/guide/using-oui.html'],
    ['en/catalogue.html', 'en', 'Capability catalogue', '/oui/ru/catalogue.html'],
    ['ru/catalogue.html', 'ru', 'Каталог возможностей', '/oui/en/catalogue.html'],
    ['en/capabilities/layout.html', 'en', 'Layout', '/oui/ru/capabilities/layout.html'],
    ['ru/capabilities/layout.html', 'ru', 'Компоновка', '/oui/en/capabilities/layout.html'],
    ['en/capabilities/layers.html', 'en', 'Layers', '/oui/ru/capabilities/layers.html'],
    ['ru/capabilities/layers.html', 'ru', 'Слои', '/oui/en/capabilities/layers.html'],
    ['en/capabilities/hud.html', 'en', 'HUD hold', '/oui/ru/capabilities/hud.html'],
    ['ru/capabilities/hud.html', 'ru', 'HUD и удержание', '/oui/en/capabilities/hud.html'],
    ['en/capabilities/text-input.html', 'en', 'Text input', '/oui/ru/capabilities/text-input.html'],
    ['ru/capabilities/text-input.html', 'ru', 'Ввод текста', '/oui/en/capabilities/text-input.html'],
    ['en/capabilities/controls.html', 'en', 'Controls', '/oui/ru/capabilities/controls.html'],
    ['ru/capabilities/controls.html', 'ru', 'Элементы управления', '/oui/en/capabilities/controls.html'],
    ['en/capabilities/styling.html', 'en', 'Styling', '/oui/ru/capabilities/styling.html'],
    ['ru/capabilities/styling.html', 'ru', 'Оформление', '/oui/en/capabilities/styling.html'],
    ['en/capabilities/profiles.html', 'en', 'Profiles', '/oui/ru/capabilities/profiles.html'],
    ['ru/capabilities/profiles.html', 'ru', 'Профили', '/oui/en/capabilities/profiles.html']
  ]) {
    const response = await get('/oui/' + path)
    assert.equal(response.status, 200, path)
    assert.match(response.headers.get('content-type'), /^text\/html/)
    const html = await response.text()
    assert.match(html, new RegExp(`<html lang="${lang}"`))
    assert.ok(html.includes(title), path)
    assert.ok(html.includes(`href="${other}"`), path)
    if (path.includes('guide/')) assert.ok(html.includes('id="choose-a-boundary"'))
    const markup = html.split('<script>window.__VP_HASH_MAP__')[0]
    const section = path.match(/capabilities\/(layout|layers|hud|text-input)\.html/)?.[1]
    if (section) {
      const records = media.records.filter(item => item.section === section && item.uiLocale === lang)
      assert.equal(records.length, section === 'text-input' ? 1 : 2)
      for (const record of records) {
        const image = `/oui/${record.path}`
        assert.ok(markup.includes(`src="${image}"`), `missing no-JS image ${path}`)
        assert.ok(markup.includes(`alt="${record.alt[lang]}"`))
        const response = await get(image)
        assert.equal(response.status, 200)
        assert.match(response.headers.get('content-type'), /^image\/png/)
        const bytes = Buffer.from(await response.arrayBuffer())
        assert.equal(bytes.subarray(0, 8).toString('hex'), '89504e470d0a1a0a')
        assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256)
      }
    }
    for (const [id, states] of [['profiles', ['initial', 'dialog', 'applied']], ['controls', ['initial', 'changed']], ['styling', ['initial', 'changed']]]) if (path.includes(`capabilities/${id}`)) {
      for (const state of states) {
        const record = media.records.find(item => item.id === `${id}-${lang}-${state}`)
        const image = `/oui/${record.path}`
        assert.ok(markup.includes(`src="${image}"`))
        assert.ok(markup.includes(`alt="${record.alt[lang]}"`))
        const response = await get(image)
        assert.equal(response.status, 200)
        assert.match(response.headers.get('content-type'), /^image\/png/)
        const bytes = Buffer.from(await response.arrayBuffer())
        assert.equal(createHash('sha256').update(bytes).digest('hex'), record.sha256)
      }
    }
    const serialized = html.match(/window\.__VP_SITE_DATA__=JSON\.parse\(("(?:\\.|[^"\\])*")\)/)
    assert.ok(serialized, 'missing serialized site configuration')
    const site = JSON.parse(JSON.parse(serialized[1]))
    if (lang === 'ru') {
      for (const label of ['Перейти к содержимому', '>Оформление<']) assert.ok(markup.includes(label), `${path}: ${label}`)
      for (const label of ['Skip to content', '>Appearance<']) assert.ok(!markup.includes(label), `${path}: ${label}`)
      // The theme sets switch titles on hydration; SSR serializes their locale values.
      assert.equal(site.locales.ru.themeConfig.darkModeSwitchTitle, 'Включить тёмную тему')
      assert.equal(site.locales.ru.themeConfig.lightModeSwitchTitle, 'Включить светлую тему')
    } else {
      for (const label of ['Skip to content', '>Appearance<']) assert.ok(markup.includes(label), `${path}: ${label}`)
      assert.equal(site.themeConfig.darkModeSwitchTitle, 'Switch to dark theme')
      assert.equal(site.themeConfig.lightModeSwitchTitle, 'Switch to light theme')
    }
    const asset = html.match(/(?:src|href)="(\/oui\/assets\/[^" ]+\.(?:js|css))"/)
    assert.ok(asset, `missing asset in ${path}`)
    const resource = await get(asset[1])
    assert.equal(resource.status, 200)
    assert.match(resource.headers.get('content-type'), /^(text\/css|text\/javascript)/)
    console.log(`OK ${path || '/'} lang=${lang} asset=${asset[1]}`)
  }
  assert.equal((await get('/oui/en/guide/using-oui')).status, 200)
  assert.equal((await get('/oui/en', { redirect: 'manual' })).headers.get('location'), '/oui/en/')
  assert.equal((await get('/outside')).status, 404)
  assert.equal((await get('/oui/missing.html')).status, 404)
  assert.equal((await get('/oui/en/', { method: 'POST' })).status, 405)
  // A raw HTTP request avoids URL normalization before the server sees traversal.
  const status = await new Promise((resolve, reject) => {
    const req = request({ host: address.address, port: address.port, path: '/oui/%2e%2e/package.json', timeout: 5000 }, res => { res.resume(); resolve(res.statusCode) })
    req.on('timeout', () => req.destroy(new Error('request timed out')))
    req.on('error', reject)
    req.end()
  })
  assert.equal(status, 400)
  console.log('OK clean URLs, base boundary, method and traversal rejection')
} finally {
  server.closeAllConnections()
  await new Promise((resolve, reject) => server.close(error => error ? reject(error) : resolve()))
  assert.equal(server.listening, false)
  console.log('owned listener stopped')
}

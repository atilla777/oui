import { test } from 'node:test'
import assert from 'node:assert/strict'
import { createHash } from 'node:crypto'
import { mkdtemp, mkdir, readFile, writeFile, rm } from 'node:fs/promises'
import { join } from 'node:path'
import { tmpdir } from 'node:os'
import { sourceIds, validateCatalogue } from './catalogue.js'

test('native source owns 19 gallery and four lab IDs', async () => {
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  const ids = sourceIds(source)
  assert.equal(ids.gallery.length, 19)
  assert.equal(ids.lab.length, 4)
  assert.ok(ids.gallery.includes('layout'))
  assert.ok(ids.lab.includes('lab-inventory'))
})

test('published sample binds localized prose, media and selected resource hashes', async () => {
  const catalogue = JSON.parse(await readFile('data/catalogue.json', 'utf8'))
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  await validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: catalogue.coverage })
  assert.deepEqual(catalogue.coverage.ids, ['layout', 'controls', 'styling', 'profiles', 'layers', 'hud', 'text-input', 'atlas', 'scroll-table', 'collections', 'text', 'rich-text', 'transitions', 'lab-menu', 'gestures', 'lab-hud', 'diagnostics-performance', 'composition', 'custom', 'world'])
  for (const locale of ['en', 'ru']) {
    for (const section of catalogue.coverage.ids) {
      const pagePath = section.startsWith('lab-') ? `${locale}/lab/${section.slice(4)}.md` : `${locale}/capabilities/${section}.md`
      const page = await readFile(pagePath, 'utf8')
      const images = media.records.filter(record => record.section === section && record.uiLocale === locale)
      assert.equal(images.length, ['profiles', 'atlas', 'gestures'].includes(section) ? 3 : section === 'custom' ? 4 : ['text-input', 'scroll-table', 'collections'].includes(section) ? 1 : section.startsWith('lab-') ? 4 : 2)
      for (const image of images) {
        assert.ok(page.includes(`![${image.alt[locale]}](/${image.path})`))
        if (section !== 'profiles') assert.ok(page.includes(image.caption[locale]))
        for (const [path, expected] of Object.entries(image.resources)) {
          assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
        }
      }
    }
  }
  for (const locale of ['en', 'ru']) {
    const atlas = await readFile(`${locale}/capabilities/atlas.md`, 'utf8')
    for (const state of ['initial', 'alternate', 'reload']) {
      const capture = media.records.find(record => record.id === `atlas-${locale}-${state}`)
      assert.ok(capture, `missing ${locale} ${state}`)
      assert.ok(atlas.includes(`![${capture.alt[locale]}](/${capture.path})`))
      assert.ok(atlas.includes(capture.caption[locale]))
      for (const [path, expected] of Object.entries(capture.resources)) assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
    }
    const profiles = await readFile(`${locale}/capabilities/profiles.md`, 'utf8')
    for (const state of ['initial', 'dialog', 'applied']) {
      const capture = media.records.find(record => record.id === `profiles-${locale}-${state}`)
      assert.ok(profiles.includes(`![${capture.alt[locale]}](/${capture.path})`))
      for (const [path, expected] of Object.entries(capture.resources)) {
        assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
      }
    }
  }
})

test('controls and styling bind both locale pages and genuine state records', async () => {
  const catalogue = JSON.parse(await readFile('data/catalogue.json', 'utf8'))
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  assert.deepEqual(catalogue.coverage.ids, ['layout', 'controls', 'styling', 'profiles', 'layers', 'hud', 'text-input', 'atlas', 'scroll-table', 'collections', 'text', 'rich-text', 'transitions', 'lab-menu', 'gestures', 'lab-hud', 'diagnostics-performance', 'composition', 'custom', 'world'])
  await validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: catalogue.coverage })
  for (const id of ['controls', 'styling']) {
    assert.ok(sourceIds(source).gallery.includes(id))
    const record = catalogue.records.find(item => item.id === id)
    assert.equal(record.media.length, 4)
    for (const locale of ['en', 'ru']) {
      const page = await readFile(`${locale}/capabilities/${id}.md`, 'utf8')
      assert.ok(page.includes(`--section ${id} --locale ${locale}`))
      for (const state of ['initial', 'changed']) {
        const image = media.records.find(item => item.id === `${id}-${locale}-${state}`)
        assert.equal(image.uiLocale, locale)
        assert.equal(image.section, id)
        assert.ok(page.includes(`![${image.alt[locale]}](/${image.path})`))
        assert.ok(page.includes(image.caption[locale]))
        for (const [path, expected] of Object.entries(image.resources)) {
          assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
        }
      }
    }
  }
})

test('diagnostics-performance binds both locales, both genuine states and explicit opt-in boundaries', async () => {
  const catalogue = JSON.parse(await readFile('data/catalogue.json', 'utf8'))
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  assert.ok(sourceIds(source).gallery.includes('diagnostics-performance'))
  assert.ok(catalogue.coverage.ids.includes('diagnostics-performance'))
  await validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: catalogue.coverage })
  const record = catalogue.records.find(item => item.id === 'diagnostics-performance')
  assert.equal(record.media.length, 4)
  const digests = new Set()
  for (const locale of ['en', 'ru']) {
    const page = await readFile(`${locale}/capabilities/diagnostics-performance.md`, 'utf8')
    assert.ok(page.includes('{#diagnostics-performance}'))
    assert.ok(page.includes(`--section diagnostics-performance --locale ${locale}`))
    assert.ok(page.includes('4da8d7a57bd2453227a4c37df6b0b4d171401681'))
    for (const phrase of locale === 'en' ? ['no debugger transport', 'no GPU timing', 'no numerical SLA'] : ['нет транспорта отладчика', 'измерения времени GPU', 'числовых SLA']) assert.ok(page.includes(phrase), `${locale}: ${phrase}`)
    for (const state of ['initial', 'diagnostic']) {
      const image = media.records.find(item => item.id === `diagnostics-performance-${locale}-${state}`)
      assert.equal(image.uiLocale, locale)
      assert.equal(image.section, 'diagnostics-performance')
      assert.ok(page.includes(`![${image.alt[locale]}](/${image.path})`))
      assert.ok(page.includes(image.caption[locale]))
      digests.add(image.sha256)
      for (const [path, expected] of Object.entries(image.resources)) {
        assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
      }
    }
  }
  assert.equal(digests.size, 4)
  assert.notEqual(media.records.find(item => item.id === 'diagnostics-performance-en-initial').state, media.records.find(item => item.id === 'diagnostics-performance-en-diagnostic').state)
})

test('lab-menu sample binds four states per locale and its native command', async () => {
  const catalogue = JSON.parse(await readFile('data/catalogue.json', 'utf8'))
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  await validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: catalogue.coverage })
  const record = catalogue.records.find(item => item.id === 'lab-menu')
  assert.equal(record.group, 'lab')
  assert.equal(record.media.length, 8)
  for (const locale of ['en', 'ru']) {
    const page = await readFile(`${locale}/lab/menu.md`, 'utf8')
    assert.ok(page.includes(`--section lab-menu --locale ${locale}`))
    for (const state of ['initial', 'submenu', 'settings', 'confirm']) {
      const image = media.records.find(item => item.id === `lab-menu-${state}-${locale}`)
      assert.equal(image.uiLocale, locale)
      assert.equal(image.section, 'lab-menu')
      assert.ok(page.includes(`![${image.alt[locale]}](/${image.path})`))
      assert.ok(page.includes(image.caption[locale]))
    }
  }
})

test('sample validation rejects digest, provenance, locale and strict coverage failures', async () => {
  const root = await mkdtemp(join(tmpdir(), 'oui-catalogue-'))
  try {
    await mkdir(join(root, 'media'))
    // A test-only PNG header; production images require independent inspection.
    const png = Buffer.from('89504e470d0a1a0a0000000d4948445200000500000003c0', 'hex')
    await writeFile(join(root, 'media', 'fixture.png'), png)
    const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
    const l = { en: 'Example', ru: 'Пример' }
    const catalogue = { schemaVersion: 1, records: [{ id: 'layout', group: 'gallery', categories: ['layout'], packages: ['ui_layout'], source: 'consumer/ui_showcase/model/catalogue.odin', runnable: 'example command', title: l, summary: l, limitations: l, media: ['en', 'ru', 'small-en', 'small-ru'], viewerStates: [{ id: 'large', width: 1280, height: 960, media: { en: 'en', ru: 'ru' } }, { id: 'small', width: 960, height: 720, media: { en: 'small-en', ru: 'small-ru' } }] }] }
    const resources = Object.fromEntries(['resources/font.ttf', 'resources/fallback.ttf', 'resources/atlas/a/manifest.json', 'resources/atlas/a/geometry.png', 'resources/atlas/b/manifest.json', 'resources/atlas/b/geometry.png'].map(path => [path, 'c'.repeat(64)]))
    const smallPng = Buffer.from('89504e470d0a1a0a0000000d49484452000003c0000002d0', 'hex')
    await writeFile(join(root, 'media', 'small.png'), smallPng)
    const image = { section: 'layout', state: 'initial layout geometry', sourceState: 'clean', isdIdentity: 'a'.repeat(40), options: 'default', revision: 'b'.repeat(40), sourcePaths: ['consumer/ui_showcase'], window: { width: 1280, height: 960 }, drawable: { width: 1280, height: 960 }, scale: 1, resources, path: 'media/fixture.png', sha256: createHash('sha256').update(png).digest('hex'), caption: l, alt: l }
    const small = { ...image, state: 'initial layout geometry at 960x720', window: { width: 960, height: 720 }, drawable: { width: 960, height: 720 }, path: 'media/small.png', sha256: createHash('sha256').update(smallPng).digest('hex') }
    const media = { schemaVersion: 1, records: [{ ...image, id: 'en', uiLocale: 'en' }, { ...image, id: 'ru', uiLocale: 'ru' }, { ...small, id: 'small-en', uiLocale: 'en' }, { ...small, id: 'small-ru', uiLocale: 'ru' }] }
    const input = { catalogue, media, source, publicRoot: root, coverage: { mode: 'sample', ids: ['layout'] } }
    await validateCatalogue(input)
    const invalid = structuredClone(input)
    invalid.media.records[0].sha256 = '0'.repeat(64)
    await assert.rejects(validateCatalogue(invalid), /digest mismatch/)
    const noProvenance = structuredClone(input)
    delete noProvenance.media.records[0].revision
    await assert.rejects(validateCatalogue(noProvenance), /revision/)
    const noLocale = structuredClone(input)
    noLocale.media.records[1].uiLocale = 'en'
    await assert.rejects(validateCatalogue(noLocale), /Viewer state media mismatch/)
    const mismatch = structuredClone(input)
    mismatch.catalogue.records[0].viewerStates[1].media.en = 'en'
    await assert.rejects(validateCatalogue(mismatch), /Viewer state media mismatch/)
    const wrongDescription = structuredClone(input)
    wrongDescription.media.records[2].state = 'initial layout geometry'
    await assert.rejects(validateCatalogue(wrongDescription), /Viewer state media mismatch/)
    const wrongSize = structuredClone(input)
    wrongSize.catalogue.records[0].viewerStates[1].width = 1280
    await assert.rejects(validateCatalogue(wrongSize), /Viewer state mismatch/)
    await assert.rejects(validateCatalogue({ ...input, coverage: { mode: 'strict' } }), /Coverage mismatch/)
    await assert.rejects(validateCatalogue({ ...input, coverage: undefined }), /Explicit coverage/)
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('gestures bind distinct initial, proposal and applied captures per locale', async () => {
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const captures = media.records.filter(record => record.section === 'gestures')
  assert.equal(captures.length, 6)
  assert.equal(new Set(captures.map(record => `${record.revision} ${record.isdIdentity}`)).size, 1)
  for (const locale of ['en', 'ru']) {
    const states = captures.filter(record => record.uiLocale === locale)
    assert.deepEqual(states.map(record => record.id), [`gestures-${locale}-initial`, `gestures-${locale}-proposal`, `gestures-${locale}-applied`])
    assert.equal(new Set(states.map(record => record.sha256)).size, 3)
    assert.ok(states[1].state.includes('mouse button is down'))
    assert.ok(states[2].state.includes('after release'))
    const page = await readFile(`${locale}/capabilities/gestures.md`, 'utf8')
    assert.ok(page.includes(locale === 'en' ? 'Drop: accepted' : 'Перенос: разрешён'))
    assert.ok(page.includes(`--section gestures --locale ${locale}`))
  }
})

test('atlas sample rejects a missing reload capture even when locale coverage remains', async () => {
  const catalogue = JSON.parse(await readFile('data/catalogue.json', 'utf8'))
  const media = JSON.parse(await readFile('data/media.json', 'utf8'))
  const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
  const id = 'atlas-ru-reload'
  catalogue.records.find(record => record.id === 'atlas').media = catalogue.records.find(record => record.id === 'atlas').media.filter(value => value !== id)
  media.records = media.records.filter(record => record.id !== id)
  await assert.rejects(validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: catalogue.coverage }), /Missing atlas ru reload media/)
})

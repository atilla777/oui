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
  assert.deepEqual(catalogue.coverage.ids, ['layout', 'text', 'rich-text'])
  for (const section of catalogue.coverage.ids) {
    for (const locale of ['en', 'ru']) {
      const page = await readFile(`${locale}/capabilities/${section}.md`, 'utf8')
      const images = media.records.filter(record => record.section === section && record.uiLocale === locale)
      assert.equal(images.length, section === 'layout' ? 1 : 2)
      for (const image of images) {
        assert.ok(page.includes(`![${image.alt[locale]}](/${image.path})`))
        assert.ok(page.includes(image.caption[locale]))
        for (const [path, expected] of Object.entries(image.resources)) {
          assert.equal(createHash('sha256').update(await readFile(`../${path}`)).digest('hex'), expected, path)
        }
      }
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
    const catalogue = { schemaVersion: 1, records: [{ id: 'layout', group: 'gallery', categories: ['layout'], packages: ['ui_layout'], source: 'consumer/ui_showcase/model/catalogue.odin', runnable: 'example command', title: l, summary: l, limitations: l, media: ['en', 'ru'] }] }
    const resources = Object.fromEntries(['resources/font.ttf', 'resources/fallback.ttf', 'resources/atlas/a/manifest.json', 'resources/atlas/a/geometry.png', 'resources/atlas/b/manifest.json', 'resources/atlas/b/geometry.png'].map(path => [path, 'c'.repeat(64)]))
    const image = { section: 'layout', state: 'initial', sourceState: 'clean', isdIdentity: 'a'.repeat(40), options: 'default', revision: 'b'.repeat(40), sourcePaths: ['consumer/ui_showcase'], window: { width: 1280, height: 960 }, drawable: { width: 1280, height: 960 }, scale: 1, resources, path: 'media/fixture.png', sha256: createHash('sha256').update(png).digest('hex'), caption: l, alt: l }
    const media = { schemaVersion: 1, records: [{ ...image, id: 'en', uiLocale: 'en' }, { ...image, id: 'ru', uiLocale: 'ru' }] }
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
    await assert.rejects(validateCatalogue(noLocale), /Missing ru media/)
    await assert.rejects(validateCatalogue({ ...input, coverage: { mode: 'strict' } }), /Coverage mismatch/)
    await assert.rejects(validateCatalogue({ ...input, coverage: undefined }), /Explicit coverage/)
  } finally { await rm(root, { recursive: true, force: true }) }
})

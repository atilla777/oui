import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { validateLinks } from './links.js'

async function fixture(markdown) {
  const root = await mkdtemp(join(tmpdir(), 'oui-links-'))
  await mkdir(join(root, 'en', 'guide'), { recursive: true })
  await mkdir(join(root, 'ru'), { recursive: true })
  await mkdir(join(root, 'public', 'media'), { recursive: true })
  await writeFile(join(root, 'en', 'index.md'), markdown)
  await writeFile(join(root, 'ru', 'index.md'), '# Главная')
  return root
}

test('real pages have existing internal pages and /media assets', async () => {
  const { pages, links } = await validateLinks(process.cwd())
  assert.equal(pages, 34)
  assert.ok(links > 80)
})

test('clean URLs, trailing-slash indexes and anchors resolve', async () => {
  const root = await fixture('# Home\n\n[Guide](guide/using-oui#start)\n\n[Directory](guide/)\n\n![Picture](/media/picture.png)\n')
  try {
    await writeFile(join(root, 'en', 'guide', 'using-oui.md'), '# Using oui {#start}')
    await writeFile(join(root, 'en', 'guide', 'index.md'), '# Guide')
    await writeFile(join(root, 'public', 'media', 'picture.png'), 'png')
    const result = await validateLinks(root)
    assert.deepEqual(result, { pages: 4, links: 3 })
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('a missing internal page names the page and target', async () => {
  const root = await fixture('# Home\n\n[Missing](missing-page)\n')
  try {
    await assert.rejects(validateLinks(root), /en\/index\.md -> missing-page: missing page/)
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('a missing /media asset names the page and target', async () => {
  const root = await fixture('# Home\n\n![Missing](/media/missing.png)\n')
  try {
    await assert.rejects(validateLinks(root), /en\/index\.md -> \/media\/missing\.png: missing asset under public\//)
  } finally { await rm(root, { recursive: true, force: true }) }
})

test('external URLs and bare anchors are not fetched or resolved locally', async () => {
  const root = await fixture('# Home\n\n[External](https://example.com/missing)\n\n[Top](#home)\n\n[Mail](mailto:site@example.com)\n')
  try {
    assert.deepEqual(await validateLinks(root), { pages: 2, links: 0 })
  } finally { await rm(root, { recursive: true, force: true }) }
})

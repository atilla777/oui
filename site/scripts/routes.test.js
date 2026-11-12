import { test } from 'node:test'
import assert from 'node:assert/strict'
import { mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { validateParity } from './routes.js'

test('real routes have locale and explicit anchor parity', async () => {
  assert.deepEqual(await validateParity(process.cwd()), ['capabilities/atlas.md', 'capabilities/controls.md', 'capabilities/layout.md', 'capabilities/profiles.md', 'capabilities/styling.md', 'capabilities/text-input.md', 'catalogue.md', 'guide/using-oui.md', 'index.md'])
})
test('a missing counterpart is an error, not a home fallback', async () => {
  const root = await mkdtemp(join(tmpdir(), 'oui-parity-'))
  try {
    await mkdir(join(root, 'en'))
    await mkdir(join(root, 'ru'))
    await writeFile(join(root, 'en', 'missing.md'), '# Missing')
    await assert.rejects(validateParity(root), /Missing locale counterparts: ru\/missing.md/)
  } finally { await rm(root, { recursive: true, force: true }) }
})

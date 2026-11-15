import { test } from 'node:test'
import assert from 'node:assert/strict'
import { chmod, mkdtemp, mkdir, writeFile, rm } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { checkNativeSnippets, collectSnippets, PINNED_ODIN, probeOdinVersion, runShell } from './snippets.js'

const source = `
SECTIONS :: [?]Section {
	{"layout", .Layout},
	{"controls", .Controls},
}
LAB_SECTIONS :: [?]Section {
	{"lab-menu", .LabMenu},
}
`

async function fixture(markdown) {
  const site = await mkdtemp(join(tmpdir(), 'oui-snippets-site-'))
  const repo = await mkdtemp(join(tmpdir(), 'oui-snippets-repo-'))
  await mkdir(join(site, 'en', 'recipes'), { recursive: true })
  await mkdir(join(site, 'ru'), { recursive: true })
  await writeFile(join(site, 'en', 'recipes', 'menu.md'), markdown)
  return { site, repo }
}

const ok = { code: 0, stdout: '', stderr: '', timedOut: false }
const pinned = async () => PINNED_ODIN

test('real pages deduplicate commands and keep every source page', async () => {
  const { commands, launches, skipped } = await collectSnippets(process.cwd())
  const showcase = 'odin build consumer/ui_showcase -collection:ui=kit -extra-linker-flags:"$(pkg-config --libs libpng zlib)" -out:build/showcase'
  assert.ok(commands.has(showcase))
  assert.equal(commands.get(showcase).length, 44)
  assert.deepEqual(commands.get('odin test kit/ui_sdl -define:ODIN_TEST_THREADS=1 -out:build/ui-sdl-tests'), ['en/recipes/menu.md', 'ru/recipes/menu.md'])
  assert.deepEqual(commands.get('odin build tests/ui_recipes/hud/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/hud-recipe'), ['en/recipes/hud.md', 'ru/recipes/hud.md'])
  assert.deepEqual(launches.get('build/hud-recipe-headless'), ['en/recipes/hud.md', 'ru/recipes/hud.md'])
  assert.deepEqual(commands.get('odin build tests/ui_recipes/inventory/native -collection:ui=kit -vet -vet-style -vet-tabs -vet-semicolon -out:build/inventory-native'), ['en/recipes/inventory.md', 'ru/recipes/inventory.md'])
  assert.deepEqual(launches.get('./build/inventory-recipe'), ['en/recipes/inventory.md', 'ru/recipes/inventory.md'])
  assert.ok([...commands.keys()].every(command => !command.includes('vendor/odin-ui')), 'guide vendored-root commands must not execute')
  assert.deepEqual(launches.get('build/showcase --font resources/font.ttf --fallback-font resources/fallback.ttf --assets resources/atlas/a/manifest.json --alternate-assets resources/atlas/b/manifest.json --section lab-menu --locale en --size 1280x960 --scale 1'), ['en/lab/menu.md', 'ru/lab/menu.md'])
  assert.ok(skipped.some(block => block.page === 'en/guide/using-oui.md' && /non-snippet shell lines not executed \(cd\)/.test(block.reason)))
})

test('a failing command names the page, the command and its output', async () => {
  const { site, repo } = await fixture('# Build\n\n```sh\nmkdir -p build\nodin build consumer/ui_showcase -out:build/showcase\n```\n')
  const calls = []
  try {
    await assert.rejects(checkNativeSnippets({
      siteRoot: site,
      repoRoot: repo,
      source,
      probe: pinned,
      run: async (command) => {
        calls.push(command)
        return command.startsWith('odin build') ? { code: 2, stdout: '', stderr: 'undefined: Missing', timedOut: false } : ok
      },
    }), error => {
      assert.match(error.message, /en\/recipes\/menu\.md/)
      assert.match(error.message, /odin build consumer\/ui_showcase -out:build\/showcase/)
      assert.match(error.message, /undefined: Missing/)
      return true
    })
    assert.deepEqual(calls, ['mkdir -p build', 'odin build consumer/ui_showcase -out:build/showcase'])
  } finally { await rm(site, { recursive: true, force: true }); await rm(repo, { recursive: true, force: true }) }
})

test('a timed-out command is a loud failure', async () => {
  const { site, repo } = await fixture('# Build\n\n```sh\nodin test kit/ui_sdl -out:build/ui-sdl-tests\n```\n')
  try {
    await assert.rejects(checkNativeSnippets({
      siteRoot: site,
      repoRoot: repo,
      source,
      probe: pinned,
      timeoutMs: 10,
      run: async () => ({ code: null, stdout: '', stderr: '', timedOut: true }),
    }), /Native snippet timed out after 10 ms on en\/recipes\/menu\.md/)
  } finally { await rm(site, { recursive: true, force: true }); await rm(repo, { recursive: true, force: true }) }
})

test('runShell bounds the whole process group even when a grandchild holds the pipes', async () => {
  const started = Date.now()
  const result = await runShell('sleep 8 & wait', { timeoutMs: 300 })
  const elapsed = Date.now() - started
  assert.equal(result.timedOut, true)
  assert.ok(elapsed < 4000, `runShell resolved after ${elapsed} ms; a background grandchild must not defer the timeout`)
})

test('launch lines reject a missing binary, a missing resource and an unknown section', async () => {
  const { site, repo } = await fixture('# Run\n\n```sh\nbuild/menu --font resources/font.ttf --locale en --size 800x600 --scale 1\n```\n')
  try {
    const run = async () => ok
    await assert.rejects(checkNativeSnippets({ siteRoot: site, repoRoot: repo, source, probe: pinned, run }),
      /en\/recipes\/menu\.md: binary build\/menu is missing or not executable/)
    await mkdir(join(repo, 'build'))
    await writeFile(join(repo, 'build', 'menu'), '#!/bin/sh\n')
    await chmod(join(repo, 'build', 'menu'), 0o755)
    await assert.rejects(checkNativeSnippets({ siteRoot: site, repoRoot: repo, source, probe: pinned, run }),
      /en\/recipes\/menu\.md: --font resource resources\/font\.ttf is missing/)
    await mkdir(join(repo, 'resources'))
    await writeFile(join(repo, 'resources', 'font.ttf'), 'font')
    await writeFile(join(site, 'en', 'recipes', 'menu.md'), '# Run\n\n```sh\nbuild/menu --font resources/font.ttf --section not-a-section --size 800x600 --scale 1\n```\n')
    await assert.rejects(checkNativeSnippets({ siteRoot: site, repoRoot: repo, source, probe: pinned, run }),
      /en\/recipes\/menu\.md: --section not-a-section is not a native section id/)
  } finally { await rm(site, { recursive: true, force: true }); await rm(repo, { recursive: true, force: true }) }
})

test('the real odin banner normalizes to the bare pinned version', async () => {
  assert.equal(await probeOdinVersion({ run: async () => ({ code: 0, stdout: `odin version ${PINNED_ODIN}\n`, stderr: '', timedOut: false }) }), PINNED_ODIN)
  await assert.rejects(probeOdinVersion({ run: async () => ({ code: 127, stdout: '', stderr: 'sh: odin: not found', timedOut: false }) }), /exited 127: sh: odin: not found/)
})

test('a mismatched pinned Odin version rejects before any command runs', async () => {
  const { site, repo } = await fixture('# Build\n\n```sh\nodin build consumer/ui_showcase -out:build/showcase\n```\n')
  const calls = []
  try {
    await assert.rejects(checkNativeSnippets({
      siteRoot: site,
      repoRoot: repo,
      source,
      probe: async () => 'dev-2026-10-nightly:deadbeef',
      run: async (command) => { calls.push(command); return ok },
    }), /Odin version mismatch: the site pins `dev-2026-10-nightly:84bc3fc` .* got `dev-2026-10-nightly:deadbeef`/)
    assert.deepEqual(calls, [])
  } finally { await rm(site, { recursive: true, force: true }); await rm(repo, { recursive: true, force: true }) }
})

test('an unavailable odin binary rejects with the pinned requirement', async () => {
  const { site, repo } = await fixture('# Build\n\n```sh\nodin build consumer/ui_showcase -out:build/showcase\n```\n')
  try {
    await assert.rejects(checkNativeSnippets({
      siteRoot: site,
      repoRoot: repo,
      source,
      probe: async () => { throw new Error('spawn odin ENOENT') },
      run: async () => ok,
    }), /Odin is not usable.*spawn odin ENOENT.*`dev-2026-10-nightly:84bc3fc`.*docs\/resources\.md/)
  } finally { await rm(site, { recursive: true, force: true }); await rm(repo, { recursive: true, force: true }) }
})

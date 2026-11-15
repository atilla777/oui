// Reusable checks for the native build/test snippets published in the bilingual
// guide, recipe and capability pages. This module imports only Node builtins
// (plus the catalogue source parser); the native lane therefore needs no
// `npm ci`. It builds and tests from the page text itself; launch lines are
// verified structurally because they open a native window and require a
// verified isolated display, not this check.
import { spawn } from 'node:child_process'
import { readdir, readFile, stat } from 'node:fs/promises'
import { join, resolve } from 'node:path'
import { sourceIds } from './catalogue.js'

export const PINNED_ODIN = 'dev-2026-10-nightly:84bc3fc'
export const PINNED_ODIN_SOURCES = 'docs/resources.md and the site recipe pages'
export const DEFAULT_TIMEOUT_MS = 600_000
const launchFlags = ['--font', '--fallback-font', '--assets', '--alternate-assets']
// Launch lines run the binaries the preceding build snippets produce under
// build/ (menu, showcase, and per-recipe fixtures like hud-recipe). They are
// verified structurally, never executed by this check.
const isLaunchBinary = first => first.startsWith('build/') && !first.slice(6).includes('/')
const ignoredDirectories = new Set(['node_modules', '.vitepress', '.git'])

// Fenced ```sh blocks only. Line numbers are 1-based page line numbers.
export function snippetBlocks(markdown) {
  const lines = markdown.split('\n')
  const blocks = []
  for (let index = 0; index < lines.length; index++) {
    if (lines[index].trim() !== '```sh') continue
    const line = index + 2
    const body = []
    for (index++; index < lines.length && lines[index].trim() !== '```'; index++) body.push(lines[index])
    if (index >= lines.length) throw new Error(`Unterminated \`\`\`sh block at line ${line}`)
    blocks.push({ line, lines: body })
  }
  return blocks
}

// Split a block into runnable lines and launch lines. Comments and blank lines
// carry no command. Any other shell line makes the block a non-recipe block.
export function classifySnippetBlock(block) {
  const commands = []
  const launches = []
  const other = []
  for (const raw of block.lines) {
    const line = raw.trim()
    if (!line || line.startsWith('#')) continue
    const first = line.split(/\s+/)[0]
    if (first === 'odin' || (first === 'mkdir' && line.split(/\s+/)[1] === '-p')) commands.push(line)
    else if (isLaunchBinary(first)) launches.push(line)
    else other.push(line)
  }
  return { commands, launches, other }
}

async function markdownPages(directory, prefix = '') {
  const pages = []
  for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
    if (ignoredDirectories.has(entry.name)) continue
    const path = join(directory, entry.name)
    const name = prefix ? `${prefix}/${entry.name}` : entry.name
    if (entry.isDirectory()) pages.push(...await markdownPages(path, name))
    else if (entry.isFile() && entry.name.endsWith('.md')) pages.push({ page: name, path })
  }
  return pages
}

function collect(map, key, page) {
  map.set(key, [...(map.get(key) || []), page])
}

// Read both locale trees, deduplicate identical command text and retain every
// source page. Blocks containing other shell commands (acquisition steps,
// portable-root placeholders) are never executed; their launch lines are still
// verified structurally.
export async function collectSnippets(siteRoot) {
  const commands = new Map()
  const launches = new Map()
  const skipped = []
  for (const locale of ['en', 'ru']) {
    for (const { page, path } of await markdownPages(join(siteRoot, locale), locale)) {
      for (const block of snippetBlocks(await readFile(path, 'utf8'))) {
        const classified = classifySnippetBlock(block)
        if (!classified.other.length) for (const command of classified.commands) collect(commands, command, page)
        for (const launch of classified.launches) collect(launches, launch, page)
        if (classified.other.length) {
          const first = classified.other.map(line => line.split(/\s+/)[0])
          skipped.push({ page, line: block.line, reason: `non-recipe shell block (${[...new Set(first)].join(', ')})` })
        }
      }
    }
  }
  return { commands, launches, skipped }
}

const tail = (value, limit = 2000) => value.length > limit ? value.slice(-limit) : value

// Run one shell line through /bin/sh so page-documented substitutions such as
// `"$(pkg-config --libs libpng zlib)"` behave as published. Failures, timeouts
// and missing tools are returned or thrown loudly, never skipped.
//
// The child leads its own process group (`detached: true`), so a timeout kills
// the whole group: a grandchild holding the inherited stdout/stderr pipes would
// otherwise outlive a direct-child kill and defer `close`, making the loud
// timeout arrive late or never instead of at `timeoutMs`.
export function runShell(command, { cwd, timeoutMs = DEFAULT_TIMEOUT_MS } = {}) {
  return new Promise((resolvePromise, reject) => {
    const child = spawn('/bin/sh', ['-c', command], { cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] })
    let stdout = ''
    let stderr = ''
    let timedOut = false
    const timer = setTimeout(() => {
      timedOut = true
      try {
        process.kill(-child.pid, 'SIGKILL')
      } catch {
        try { child.kill('SIGKILL') } catch {}
      }
    }, timeoutMs)
    child.stdout.on('data', chunk => { stdout += chunk })
    child.stderr.on('data', chunk => { stderr += chunk })
    child.on('error', error => {
      clearTimeout(timer)
      reject(new Error(`Cannot run \`${command}\`: ${error.message}`))
    })
    child.on('close', code => {
      clearTimeout(timer)
      resolvePromise({ code, stdout, stderr, timedOut })
    })
  })
}

export async function probeOdinVersion({ run = runShell, cwd } = {}) {
  const result = await run('odin version', { cwd, timeoutMs: 60_000 })
  if (result.timedOut) throw new Error('`odin version` timed out')
  if (result.code !== 0) throw new Error(`\`odin version\` exited ${result.code}: ${tail(result.stderr) || tail(result.stdout) || 'no output'}`)
  const output = result.stdout.trim()
  const prefix = 'odin version '
  return (output.startsWith(prefix) ? output.slice(prefix.length) : output).trim()
}

// The launch line must point at a binary the preceding snippet builds and at
// supplied files that exist in the repository; --section must be a native id.
export async function verifyLaunch({ command, pages, repoRoot, ids, statFile = stat }) {
  const where = pages.join(', ')
  const tokens = command.split(/\s+/)
  const binary = resolve(repoRoot, tokens[0])
  const binaryStat = await statFile(binary).catch(() => undefined)
  if (!binaryStat?.isFile() || !(binaryStat.mode & 0o111)) {
    throw new Error(`Launch snippet on ${where}: binary ${tokens[0]} is missing or not executable; the preceding build snippet must produce it`)
  }
  for (let index = 1; index < tokens.length; index++) {
    const token = tokens[index]
    if (!launchFlags.includes(token)) continue
    const value = tokens[index + 1]
    if (!value || value.startsWith('--')) throw new Error(`Launch snippet on ${where}: ${token} has no value`)
    const target = resolve(repoRoot, value)
    const targetStat = await statFile(target).catch(() => undefined)
    if (!targetStat?.isFile()) throw new Error(`Launch snippet on ${where}: ${token} resource ${value} is missing`)
    index++
  }
  const sections = []
  for (let index = 0; index < tokens.length; index++) {
    if (tokens[index] !== '--section') continue
    const value = tokens[index + 1]
    if (!value || value.startsWith('--')) throw new Error(`Launch snippet on ${where}: --section has no value`)
    sections.push(value)
  }
  for (const section of sections) {
    if (![...ids.gallery, ...ids.lab].includes(section)) {
      throw new Error(`Launch snippet on ${where}: --section ${section} is not a native section id (see consumer/ui_showcase/model/catalogue.odin)`)
    }
  }
}

// Version guard first, then every deduplicated odin/mkdir command from the
// self-contained recipe blocks, then structural launch verification.
export async function checkNativeSnippets({
  siteRoot,
  repoRoot = resolve(siteRoot, '..'),
  run = runShell,
  probe,
  source,
  timeoutMs = DEFAULT_TIMEOUT_MS,
  statFile = stat,
  log = () => {},
} = {}) {
  const probeVersion = probe || (() => probeOdinVersion({ run, cwd: repoRoot }))
  let version
  try {
    version = await probeVersion()
  } catch (error) {
    throw new Error(`Odin is not usable for the native lane: ${error.message}. The site pins \`${PINNED_ODIN}\`; see ${PINNED_ODIN_SOURCES}.`)
  }
  if (version !== PINNED_ODIN) {
    throw new Error(`Odin version mismatch: the site pins \`${PINNED_ODIN}\` (see ${PINNED_ODIN_SOURCES}), got \`${version}\``)
  }
  const { commands, launches, skipped } = await collectSnippets(siteRoot)
  for (const [command, pages] of commands) {
    log(`Running (${pages.join(', ')}): ${command}`)
    const result = await run(command, { cwd: repoRoot, timeoutMs })
    if (result.timedOut) throw new Error(`Native snippet timed out after ${timeoutMs} ms on ${pages.join(', ')}: ${command}`)
    if (result.code !== 0) {
      const output = [result.stderr, result.stdout].map(value => tail(value?.trim() || '')).filter(Boolean).join('\n')
      throw new Error(`Native snippet failed on ${pages.join(', ')} (exit ${result.code}): ${command}\n${output || 'no output'}`)
    }
  }
  const ids = sourceIds(source === undefined ? await readFile(resolve(repoRoot, 'consumer/ui_showcase/model/catalogue.odin'), 'utf8') : source)
  for (const [command, pages] of launches) await verifyLaunch({ command, pages, repoRoot, ids, statFile })
  return { commands: commands.size, launches: launches.size, skipped }
}

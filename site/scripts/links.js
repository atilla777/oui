// Reusable static check for internal page links and /media/ assets published by
// the site. Markdown pages are the source of truth; VitePress clean URLs map
// `../recipes/menu` to `recipes/menu.md`. External URLs are not fetched.
import { readdir, readFile, stat } from 'node:fs/promises'
import { dirname, extname, join, relative, resolve } from 'node:path'

const external = /^(?:[a-z][a-z0-9+.-]*:|\/\/)/i
const ignoredDirectories = new Set(['node_modules', '.vitepress', '.git'])

async function markdownPages(localeRoot) {
  const pages = []
  async function walk(directory) {
    for (const entry of (await readdir(directory, { withFileTypes: true })).sort((a, b) => a.name.localeCompare(b.name))) {
      if (ignoredDirectories.has(entry.name)) continue
      const path = join(directory, entry.name)
      if (entry.isDirectory()) await walk(path)
      else if (entry.isFile() && entry.name.endsWith('.md')) pages.push(path)
    }
  }
  await walk(localeRoot)
  return pages.sort()
}

// Fenced code blocks may illustrate shell or prose without publishing links.
function withoutFences(markdown) {
  return markdown.replace(/^```[^\n]*\n[\s\S]*?^```[ \t]*$/gm, '')
}

// Both inline links and images use the `](target)` form; reference-style links
// are not used by this site.
export function pageLinks(markdown) {
  return [...withoutFences(markdown).matchAll(/!?\[[^\]\n]*\]\(([^)\s]+)(?:\s+"[^"]*")?\)/g)].map(match => match[1])
}

async function isFile(path) {
  try {
    return (await stat(path)).isFile()
  } catch {
    return false
  }
}

// Resolve one target to an existing file, or return the reason it does not.
async function resolveTarget(siteRoot, pagePath, target) {
  const bare = target.split('#')[0]
  if (!bare) return { reason: undefined, file: undefined }
  if (bare.startsWith('/')) {
    if (!bare.startsWith('/media/')) return { reason: 'only /media/ root-absolute targets are published from public/' }
    const file = resolve(siteRoot, 'public', bare.slice(1))
    return { file, reason: await isFile(file) ? undefined : 'missing asset under public/' }
  }
  const file = resolve(dirname(pagePath), bare)
  if (await isFile(file)) return { file, reason: undefined }
  if (!extname(bare)) {
    if (await isFile(`${file}.md`)) return { file: `${file}.md`, reason: undefined }
    if (bare.endsWith('/') && await isFile(join(file, 'index.md'))) return { file: join(file, 'index.md'), reason: undefined }
    return { file, reason: 'missing page (no file, clean-URL .md or index.md)' }
  }
  return { file, reason: 'missing file' }
}

// Check every locale page. The thrown message names each page and target so the
// static lane fails loudly instead of publishing a broken link or asset.
export async function validateLinks(siteRoot) {
  const failures = []
  let pages = 0
  let links = 0
  for (const locale of ['en', 'ru']) {
    for (const pagePath of await markdownPages(join(siteRoot, locale))) {
      pages++
      const page = relative(siteRoot, pagePath)
      for (const target of pageLinks(await readFile(pagePath, 'utf8'))) {
        if (external.test(target) || target.startsWith('#')) continue
        links++
        const { file, reason } = await resolveTarget(siteRoot, pagePath, target)
        if (!reason) continue
        const expected = relative(siteRoot, file)
        failures.push(expected.startsWith('..') ? `${page} -> ${target}: ${reason}` : `${page} -> ${target}: ${reason} (expected ${expected})`)
      }
    }
  }
  if (failures.length) throw new Error(`Broken internal links/assets:\n${failures.map(failure => `- ${failure}`).join('\n')}`)
  return { pages, links }
}

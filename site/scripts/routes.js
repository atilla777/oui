import { readdir, readFile } from 'node:fs/promises'
import { join, relative } from 'node:path'

async function pages(root, directory = root) {
  const result = []
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = join(directory, entry.name)
    if (entry.isDirectory()) result.push(...await pages(root, path))
    else if (entry.isFile() && path.endsWith('.md')) result.push(relative(root, path))
  }
  return result.sort()
}
export async function validateParity(root) {
  const en = await pages(join(root, 'en'))
  const ru = await pages(join(root, 'ru'))
  const missing = [...en.filter(x => !ru.includes(x)).map(x => `ru/${x}`), ...ru.filter(x => !en.includes(x)).map(x => `en/${x}`)]
  if (missing.length) throw new Error(`Missing locale counterparts: ${missing.join(', ')}`)
  if (!en.includes('index.md') || !en.some(x => x.includes('/'))) throw new Error('Expected introduction and nested page')
  for (const page of en) {
    const anchors = text => [...text.matchAll(/\{#([^}]+)\}/g)].map(x => x[1]).sort()
    const a = anchors(await readFile(join(root, 'en', page), 'utf8'))
    const b = anchors(await readFile(join(root, 'ru', page), 'utf8'))
    if (JSON.stringify(a) !== JSON.stringify(b)) throw new Error(`Anchor mismatch: ${page}`)
  }
  return en
}

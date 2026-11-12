// Reusable validation for the versioned static catalogue and capture manifest.
// The caller selects sample or strict coverage explicitly; neither captures media.
import { createHash } from 'node:crypto'
import { readFile } from 'node:fs/promises'
import { resolve, sep } from 'node:path'

const locales = ['en', 'ru']
const sha = /^[a-f0-9]{64}$/
const commit = /^[a-f0-9]{40}$/
const text = value => typeof value === 'string' && value.trim().length > 0
const fail = message => { throw new Error(message) }
const requireText = (value, name) => { if (!text(value)) fail(`Missing ${name}`) }
const localized = (value, name) => {
  for (const locale of locales) requireText(value?.[locale], `${name}.${locale}`)
}
const relativePath = value => text(value) && !value.startsWith('/') && !value.includes('\\') && value.split('/').every(x => x && x !== '.' && x !== '..') && !value.includes(':')
const list = (value, name) => {
  if (!Array.isArray(value) || !value.length || value.some(x => !text(x))) fail(`Invalid ${name}`)
}

// Parse the native owner, not a separately maintained imitation of its IDs.
export function sourceIds(source) {
  const groups = {}
  for (const [group, name] of [['gallery', 'SECTIONS'], ['lab', 'LAB_SECTIONS']]) {
    const match = source.match(new RegExp(`(?:^|\\n)${name} :: \\[\\?\\]Section \\{([\\s\\S]*?)\\n\\}`, 'm'))
    if (!match) fail(`Missing source ${name}`)
    groups[group] = [...match[1].matchAll(/\{\s*"([a-z0-9-]+)"\s*,\s*\.[A-Za-z_]+/g)].map(x => x[1])
    if (!groups[group].length || new Set(groups[group]).size !== groups[group].length) fail(`Invalid source ${name}`)
  }
  return groups
}

export async function validateCatalogue({ catalogue, media, source, publicRoot, coverage }) {
  if (catalogue?.schemaVersion !== 1 || media?.schemaVersion !== 1) fail('Unsupported schema version')
  if (!Array.isArray(catalogue.records) || !Array.isArray(media.records)) fail('Missing records')
  if (!coverage || !['sample', 'strict'].includes(coverage.mode)) fail('Explicit coverage mode required')
  const native = sourceIds(source)
  const expected = coverage.mode === 'strict' ? [...native.gallery, ...native.lab] : coverage.ids
  list(expected, 'coverage ids')
  if (new Set(expected).size !== expected.length) fail('Duplicate coverage id')
  const records = new Map()
  for (const record of catalogue.records) {
    if (!record || records.has(record.id) || !native[record.group]?.includes(record.id)) fail('Unknown or duplicate section')
    records.set(record.id, record)
    list(record.categories, 'categories'); list(record.packages, 'packages')
    if (!relativePath(record.source)) fail('Invalid source path')
    requireText(record.runnable, 'runnable')
    for (const key of ['title', 'summary', 'limitations']) localized(record[key], key)
    list(record.media, 'media references')
  }
  if (records.size !== expected.length || expected.some(id => !records.has(id))) fail('Coverage mismatch')
  const images = new Map()
  for (const image of media.records) {
    if (!image || !text(image.id) || images.has(image.id) || !records.has(image.section)) fail('Unknown or duplicate media')
    images.set(image.id, image)
    for (const key of ['state', 'sourceState', 'isdIdentity', 'options']) requireText(image[key], key)
    if (!commit.test(image.isdIdentity || '')) fail('Invalid ISD identity')
    if ([image.state, image.options, image.neutralReason].some(value => text(value) && /(?:^|\s)\/(?:home|tmp|run|var|Users)\/|(?:socket|display)=|unix:/i.test(value))) fail('Private capture details')
    if (image.sourceState !== 'clean') fail('Capture source must be clean')
    if (!commit.test(image.revision || '')) fail('Invalid revision')
    list(image.sourcePaths, 'source paths')
    if (image.sourcePaths.some(path => !relativePath(path))) fail('Invalid source path')
    if (!['en', 'ru', 'neutral'].includes(image.uiLocale)) fail('Invalid UI locale')
    if (image.uiLocale === 'neutral') requireText(image.neutralReason, 'neutral reason')
    for (const size of [image.window, image.drawable]) if (!Number.isInteger(size?.width) || size.width <= 0 || !Number.isInteger(size?.height) || size.height <= 0) fail('Invalid capture size')
    if (!(Number.isFinite(image.scale) && image.scale > 0)) fail('Invalid scale')
    if (!image.resources || !Object.keys(image.resources).length || Object.entries(image.resources).some(([path, hash]) => !relativePath(path) || !sha.test(hash))) fail('Invalid resource hashes')
    for (const path of ['resources/font.ttf', 'resources/fallback.ttf', 'resources/atlas/a/manifest.json', 'resources/atlas/a/geometry.png', 'resources/atlas/b/manifest.json', 'resources/atlas/b/geometry.png']) if (!sha.test(image.resources[path] || '')) fail(`Missing resource hash: ${path}`)
    if (!relativePath(image.path) || !image.path.startsWith('media/') || !image.path.endsWith('.png')) fail('Invalid media path')
    if (!sha.test(image.sha256 || '')) fail('Invalid image digest')
    localized(image.caption, 'caption'); localized(image.alt, 'alt')
    const root = resolve(publicRoot), path = resolve(root, image.path)
    if (!path.startsWith(root + sep)) fail('Invalid media path')
    const bytes = await readFile(path)
    if (bytes.length < 24 || !bytes.subarray(0, 8).equals(Buffer.from('89504e470d0a1a0a', 'hex')) || bytes.readUInt32BE(8) !== 13 || bytes.toString('ascii', 12, 16) !== 'IHDR') fail('Invalid PNG')
    if (bytes.readUInt32BE(16) !== image.drawable.width || bytes.readUInt32BE(20) !== image.drawable.height) fail('PNG drawable mismatch')
    if (createHash('sha256').update(bytes).digest('hex') !== image.sha256) fail('Image digest mismatch')
  }
  for (const record of records.values()) {
    if (new Set(record.media).size !== record.media.length) fail('Duplicate media reference')
    const selected = record.media.map(id => images.get(id))
    if (selected.some(image => !image || image.section !== record.id)) fail('Invalid media reference')
    for (const locale of locales) if (!selected.some(image => image.uiLocale === locale || image.uiLocale === 'neutral')) fail(`Missing ${locale} media`)
  }
  if ([...images.keys()].some(id => ![...records.values()].some(record => record.media.includes(id)))) fail('Unreferenced media')
}

// Static lane: verify internal page links and published /media/ assets.
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { validateLinks } from './links.js'

const siteRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const { pages, links } = await validateLinks(siteRoot)
console.log(`Internal links and /media/ assets verified: ${links} links in ${pages} pages.`)

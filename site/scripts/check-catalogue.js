import { readFile } from 'node:fs/promises'
import { validateCatalogue } from './catalogue.js'

const readJSON = async path => JSON.parse(await readFile(path, 'utf8'))
const catalogue = await readJSON('data/catalogue.json')
const media = await readJSON('data/media.json')
const source = await readFile('../consumer/ui_showcase/model/catalogue.odin', 'utf8')
const strict = process.argv.includes('--strict')
await validateCatalogue({ catalogue, media, source, publicRoot: 'public', coverage: strict ? { mode: 'strict' } : catalogue.coverage })
console.log(strict ? 'Strict catalogue coverage verified' : `Declared sample coverage verified: ${catalogue.coverage.ids.join(', ')}`)

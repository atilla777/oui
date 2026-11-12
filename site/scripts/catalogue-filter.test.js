import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { matchesRecord } from '../.vitepress/theme/catalogue-filter.js'

const { records: [record] } = JSON.parse(await readFile(new URL('../data/catalogue.json', import.meta.url)))
test('localized metadata query and category intersection', () => {
  assert.equal(matchesRecord(record, 'en', '  ROWS   ui_layout ', 'geometry'), true)
  assert.equal(matchesRecord(record, 'ru', 'СТРОКИ', 'layout'), true)
  assert.equal(matchesRecord(record, 'en', 'строки', ''), false)
  assert.equal(matchesRecord(record, 'ru', 'rows', ''), false)
  assert.equal(matchesRecord(record, 'en', 'rows missing', ''), false)
  assert.equal(matchesRecord(record, 'en', '', 'missing'), false)
  assert.equal(matchesRecord(record, 'en', '   ', ''), true)
  assert.equal(matchesRecord(record, 'en', 'pages.odin', ''), true)
})

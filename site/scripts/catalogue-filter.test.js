import { test } from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import { matchesRecord } from '../.vitepress/theme/catalogue-filter.js'

const { records } = JSON.parse(await readFile(new URL('../data/catalogue.json', import.meta.url)))
const record = records.find(item => item.id === 'layout')
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
test('five sample records filter independently and share categories', () => {
  const ids = (locale, query, category = '') => records.filter(item => matchesRecord(item, locale, query, category)).map(item => item.id)
  assert.deepEqual(ids('en', 'slider'), ['controls'])
  assert.deepEqual(ids('ru', 'каскад'), ['styling'])
  assert.deepEqual(ids('en', '', 'geometry'), ['layout'])
  assert.deepEqual(ids('ru', '', 'controls'), ['profiles', 'controls'])
  assert.deepEqual(ids('en', '', 'styling'), ['styling'])
  assert.deepEqual(ids('en', 'slider', 'styling'), [])
  assert.deepEqual(ids('en', 'ui_editor', 'input'), ['text-input'])
  assert.deepEqual(ids('ru', 'однострочного', 'input'), ['text-input'])
  assert.deepEqual(ids('en', 'ui_editor', 'styling'), [])
  assert.deepEqual(ids('en', ''), ['layout', 'profiles', 'controls', 'styling', 'text-input'])
  assert.deepEqual(ids('en', 'draft', 'state'), ['profiles'])
  assert.deepEqual(ids('ru', 'черновик', 'state'), ['profiles'])
})

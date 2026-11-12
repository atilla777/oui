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
test('sample records filter independently and share categories', () => {
  const ids = (locale, query, category = '') => records.filter(item => matchesRecord(item, locale, query, category)).map(item => item.id)
  assert.deepEqual(ids('en', 'slider'), ['controls'])
  assert.deepEqual(ids('ru', 'каскад'), ['styling'])
  assert.deepEqual(ids('en', '', 'geometry'), ['layout'])
  assert.deepEqual(ids('ru', '', 'controls'), ['profiles', 'controls'])
  assert.deepEqual(ids('en', '', 'styling'), ['styling'])
  assert.deepEqual(ids('en', 'slider', 'styling'), [])
  assert.deepEqual(ids('en', ''), ['layout', 'profiles', 'controls', 'styling', 'layers', 'hud', 'text-input', 'atlas', 'scroll-table', 'collections'])
  assert.deepEqual(ids('en', 'tooltip', 'layers'), ['layers'])
  assert.deepEqual(ids('ru', 'удержание', 'hud'), ['hud'])
  assert.deepEqual(ids('en', 'ui_editor', 'input'), ['text-input'])
  assert.deepEqual(ids('ru', 'однострочного', 'input'), ['text-input'])
  assert.deepEqual(ids('en', 'ui_editor', 'styling'), [])
  assert.deepEqual(ids('en', '', 'scrolling'), ['scroll-table', 'collections'])
  assert.deepEqual(ids('en', 'uniform', 'scrolling'), ['collections'])
  assert.deepEqual(ids('en', 'draft', 'state'), ['profiles'])
  assert.deepEqual(ids('ru', 'черновик', 'state'), ['profiles'])
  for (const locale of ['en', 'ru']) {
    for (const category of ['resources', 'images']) {
      assert.deepEqual(ids(locale, '', category), ['atlas'])
      assert.deepEqual(ids(locale, 'atlas', category), ['atlas'])
      assert.deepEqual(ids(locale, 'zzznomatch', category), [])
    }
  }
})

import assert from 'node:assert/strict'
import test from 'node:test'
import { parseOrigin } from './live-origin.js'

test('accepts bare http(s) origins with an optional trailing slash or port', () => {
  assert.equal(parseOrigin('https://atilla777.github.io'), 'https://atilla777.github.io')
  assert.equal(parseOrigin('https://atilla777.github.io/'), 'https://atilla777.github.io')
  assert.equal(parseOrigin('http://127.0.0.1:4173'), 'http://127.0.0.1:4173')
  assert.equal(parseOrigin('http://127.0.0.1:4173/'), 'http://127.0.0.1:4173')
})

test('rejects a missing, non-http(s) or path-bearing argument', () => {
  for (const argument of [undefined, '', 'atilla777.github.io', 'ftp://atilla777.github.io', 'https://atilla777.github.io/oui/', 'https://atilla777.github.io/oui', 'https://atilla777.github.io?x=1', 'https://atilla777.github.io/#x', 'https://user:pass@atilla777.github.io']) {
    assert.equal(parseOrigin(argument), undefined, String(argument))
  }
})
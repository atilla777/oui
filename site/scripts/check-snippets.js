// Native lane: execute the published odin build/test snippets from the
// repository root and verify their launch lines structurally. Requires the
// pinned native toolchain; it never soft-skips a missing tool or a failure.
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { checkNativeSnippets, PINNED_ODIN, PINNED_ODIN_SOURCES } from './snippets.js'

const siteRoot = resolve(dirname(fileURLToPath(import.meta.url)), '..')
const result = await checkNativeSnippets({ siteRoot, log: console.log })
for (const block of result.skipped) {
  console.log(`Not executed: ${block.page}:${block.line} ${block.reason}`)
}
console.log(`Native snippets verified with Odin ${PINNED_ODIN} (${PINNED_ODIN_SOURCES}): ${result.commands} deduplicated commands executed, ${result.launches} launch lines checked structurally.`)

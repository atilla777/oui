import { createServer } from 'node:http'
import { readFile, realpath, stat } from 'node:fs/promises'
import { dirname, extname, join, resolve, sep } from 'node:path'
import { fileURLToPath, pathToFileURL } from 'node:url'

const dist = resolve(dirname(fileURLToPath(import.meta.url)), '../.vitepress/dist')
const types = { '.html': 'text/html; charset=utf-8', '.css': 'text/css; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.json': 'application/json; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.webp': 'image/webp', '.woff2': 'font/woff2', '.woff': 'font/woff', '.ico': 'image/x-icon' }

export async function startPreview(port = 4173) {
  const root = await realpath(dist)
  const server = createServer(async (req, res) => {
    try {
      if (!['GET', 'HEAD'].includes(req.method)) { res.writeHead(405, { Allow: 'GET, HEAD' }).end(); return }
      const raw = req.url.split('?')[0]
      if (!raw.startsWith('/oui/')) { res.writeHead(404).end('Not found'); return }
      const decoded = decodeURIComponent(raw.slice(5))
      if (decoded.includes('\\') || decoded.includes('\0') || decoded.split('/').some(s => s === '.' || s === '..')) {
        res.writeHead(400).end('Bad path'); return
      }
      let path = join(root, decoded)
      if (decoded.endsWith('/') || !decoded) path = join(path, 'index.html')
      else if (!extname(decoded)) {
        try {
          if ((await stat(path)).isDirectory()) {
            res.writeHead(308, { Location: `${raw}/${req.url.includes('?') ? '?' + req.url.split('?').slice(1).join('?') : ''}` }).end()
            return
          }
        } catch (error) { if (error.code !== 'ENOENT') throw error }
        path += '.html'
      }
      const actual = await realpath(path)
      if (!actual.startsWith(root + sep) || !(await stat(actual)).isFile()) { res.writeHead(404).end('Not found'); return }
      const data = await readFile(actual)
      res.writeHead(200, { 'Content-Type': types[extname(actual)] || 'application/octet-stream', 'Content-Length': data.length, 'X-Content-Type-Options': 'nosniff' })
      res.end(req.method === 'HEAD' ? undefined : data)
    } catch (error) {
      if (error instanceof URIError) res.writeHead(400).end('Bad path')
      else if (['ENOENT', 'ENOTDIR'].includes(error.code)) res.writeHead(404).end('Not found')
      else { console.error(error); res.writeHead(500).end('Preview error') }
    }
  })
  await new Promise((resolve, reject) => {
    server.once('error', reject)
    server.listen(port, '127.0.0.1', () => { server.off('error', reject); resolve() })
  })
  return server
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const args = process.argv.slice(2)
  if (args.length && (args.length !== 2 || args[0] !== '--port' || !/^\d+$/.test(args[1]) || Number(args[1]) > 65535)) {
    console.error('Usage: npm run preview -- [--port 0..65535]')
    process.exitCode = 1
  } else {
    const server = await startPreview(args.length ? Number(args[1]) : 4173)
    console.log(`Preview: http://${server.address().address}:${server.address().port}/oui/`)
    const stop = () => server.close(() => process.exit(0))
    process.once('SIGINT', stop)
    process.once('SIGTERM', stop)
  }
}

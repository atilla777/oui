// Shared validation for the required <origin> argument of the live checks.
// Only a bare http(s) origin is accepted; paths belong to the checks themselves.
export function parseOrigin(argument) {
  if (!argument) return undefined
  let url
  try { url = new URL(argument) } catch { return undefined }
  if (!['http:', 'https:'].includes(url.protocol)) return undefined
  if (url.username || url.password || url.pathname !== '/' || url.search || url.hash) return undefined
  return url.origin
}
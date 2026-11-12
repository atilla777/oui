// Search only published metadata for the active locale, not the other translation.
export function matchesRecord(record, locale, query, category) {
  if (category && !record.categories.includes(category)) return false
  const text = [record.id, record.group, ...record.categories, ...record.packages,
    record.source, record.runnable, record.title[locale], record.summary[locale],
    record.limitations[locale]].join(' ').toLocaleLowerCase(locale)
  return query.trim().toLocaleLowerCase(locale).split(/\s+/).filter(Boolean)
    .every(term => text.includes(term))
}

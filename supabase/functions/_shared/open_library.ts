export const olHeaders = { "User-Agent": "Bookmarkd/1.0 (support@bookmarkd.app)" };

// Open Library groups editions into works; the work id is what makes two ISBNs one book.
// Returns null when no ISBN is known there or the lookup fails: the book is
// then saved on its own, and supabase/scripts/backfill_work_ids.ts retries it.
export async function workIdForIsbn(...isbns: (string | null | undefined)[]): Promise<string | null> {
  for (const isbn of isbns) {
    if (!isbn) continue;
    try {
      const res = await fetch(`https://openlibrary.org/isbn/${isbn}.json`, {
        headers: olHeaders,
        signal: AbortSignal.timeout(5000),
      });
      if (!res.ok) continue;
      const key = (await res.json()).works?.[0]?.key;
      const id = typeof key === "string" ? key.split("/").pop() : null;
      if (id && /^OL\d+W$/.test(id)) return id;
    } catch {
      // timeout or bad JSON: try the next ISBN
    }
  }
  return null;
}

// Gives each book that has no Open Library work id one, looked up from its
// editions' ISBNs, and merges books that turn out to be the same work.
// Safe to rerun: books that stay unmatched are retried next time.
//
// SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
//   deno run --allow-net --allow-env supabase/scripts/backfill_work_ids.ts
import { createClient } from "jsr:@supabase/supabase-js@2";
import { workIdForIsbn } from "../functions/_shared/open_library.ts";

const db = createClient(Deno.env.get("SUPABASE_URL")!, Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!);
const counts = { matched: 0, merged: 0, unmatched: 0 };
let after = "00000000-0000-0000-0000-000000000000";

while (true) {
  const { data: books, error } = await db
    .from("books")
    .select("id, title, editions:book_editions!book_editions_book_id_fkey(isbn_13, isbn_10)")
    .is("open_library_work_id", null)
    .gt("id", after)
    .order("id")
    .limit(200);
  if (error) throw error;
  if (!books.length) break;

  for (const book of books) {
    after = book.id;
    const isbns = book.editions.flatMap((e) => [e.isbn_13, e.isbn_10]);
    const workId = await workIdForIsbn(...isbns);
    if (!workId) {
      counts.unmatched++;
      continue;
    }
    const { data: owner, error: ownerError } = await db
      .from("books").select("id").eq("open_library_work_id", workId).maybeSingle();
    if (ownerError) throw ownerError;
    if (owner) {
      const { error } = await db.rpc("merge_books", { p_from: book.id, p_into: owner.id });
      if (error) throw error;
      console.log(`merged "${book.title}" ${book.id} -> ${owner.id} (${workId})`);
      counts.merged++;
    } else {
      const { error } = await db.from("books").update({ open_library_work_id: workId }).eq("id", book.id);
      if (error) throw error;
      counts.matched++;
    }
  }
}

console.log(counts);

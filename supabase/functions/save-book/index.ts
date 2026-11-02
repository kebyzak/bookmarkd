// Saves a catalog book from its external id. Metadata is fetched here, on the
// server, so clients cannot write made-up titles or covers into the shared
// `books` table. Mirrors lib/features/books/data/catalog_parsers.dart.
import { createClient } from "jsr:@supabase/supabase-js@2";

const url = Deno.env.get("SUPABASE_URL")!;
const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const googleKey = Deno.env.get("GOOGLE_BOOKS_API_KEY") ?? "";

type Payload = Record<string, unknown>;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });

const clean = (v: unknown) => (typeof v === "string" && v.trim() ? v.trim() : null);
const strings = (v: unknown) => (Array.isArray(v) ? v.filter((s) => typeof s === "string" && s.trim()) : []);
const positive = (v: unknown) => (typeof v === "number" && v > 0 ? Math.floor(v) : null);
// Must satisfy the check constraints on book_editions.
const isbn10 = (v: unknown) => (typeof v === "string" && /^[0-9]{9}[0-9X]$/.test(v.toUpperCase()) ? v.toUpperCase() : null);
const isbn13 = (v: unknown) => (typeof v === "string" && /^[0-9]{13}$/.test(v) ? v : null);

function category(raw: string): string {
  const parts = raw.split("/").map((p) => p.trim()).filter((p) => p && p !== "General");
  return parts.length ? parts[parts.length - 1] : raw.trim();
}

async function fromGoogle(id: string): Promise<Payload | null> {
  const key = googleKey ? `?key=${googleKey}` : "";
  const res = await fetch(`https://www.googleapis.com/books/v1/volumes/${encodeURIComponent(id)}${key}`);
  if (!res.ok) return null;
  const body = await res.json();
  const info = body.volumeInfo ?? {};
  const ids: { type?: string; identifier?: string }[] = info.industryIdentifiers ?? [];
  const isbn = (type: string) => ids.find((i) => i.type === type)?.identifier;
  const cover = clean(info.imageLinks?.thumbnail ?? info.imageLinks?.smallThumbnail);
  const title = clean(info.title);
  if (!title) return null;
  return {
    google_books_id: body.id,
    isbn_10: isbn10(isbn("ISBN_10")),
    isbn_13: isbn13(isbn("ISBN_13")),
    title,
    subtitle: clean(info.subtitle),
    authors: strings(info.authors),
    description: clean(info.description)?.replace(/<br\s*\/?>/g, "\n").replace(/<[^>]+>/g, "") ?? null,
    cover_url: cover?.startsWith("http://books.google.com/") || cover?.startsWith("https://books.google.com/")
      ? cover.replace("http://", "https://").replace("&edge=curl", "")
      : null,
    publisher: clean(info.publisher),
    published_date: clean(info.publishedDate),
    page_count: positive(info.pageCount),
    categories: [...new Set(strings(info.categories).map(category))],
    language: clean(info.language),
  };
}

async function fromOpenLibrary(workId: string): Promise<Payload | null> {
  const fields = "key,title,subtitle,author_name,first_publish_year,isbn,number_of_pages_median,cover_i,publisher,subject,language";
  const res = await fetch(
    `https://openlibrary.org/search.json?q=${encodeURIComponent(`key:/works/${workId}`)}&fields=${fields}&limit=1`,
    { headers: { "User-Agent": "Bookmarkd/1.0 (support@bookmarkd.app)" } },
  );
  if (!res.ok) return null;
  const doc = (await res.json()).docs?.[0];
  const title = clean(doc?.title);
  if (!doc || !title) return null;
  const isbns = strings(doc.isbn) as string[];
  return {
    open_library_id: workId,
    isbn_13: isbn13(isbns.find((i) => i.length === 13)),
    isbn_10: isbn10(isbns.find((i) => i.length === 10)),
    title,
    subtitle: clean(doc.subtitle),
    authors: strings(doc.author_name),
    cover_url: typeof doc.cover_i === "number" ? `https://covers.openlibrary.org/b/id/${doc.cover_i}-L.jpg?default=false` : null,
    publisher: strings(doc.publisher)[0] ?? null,
    published_date: typeof doc.first_publish_year === "number" ? `${doc.first_publish_year}` : null,
    page_count: positive(doc.number_of_pages_median),
    categories: strings(doc.subject).slice(0, 3),
    language: strings(doc.language)[0] ?? null,
  };
}

Deno.serve(async (req) => {
  const userClient = createClient(url, anonKey, {
    global: { headers: { Authorization: req.headers.get("Authorization") ?? "" } },
  });
  const { data: { user } } = await userClient.auth.getUser();
  if (!user) return json({ error: "not authenticated" }, 401);

  const body = await req.json().catch(() => ({}));
  const googleId = clean(body.google_books_id);
  const olId = clean(body.open_library_id);
  let payload: Payload | null;
  if (googleId && /^[\w-]{1,40}$/.test(googleId)) payload = await fromGoogle(googleId);
  else if (olId && /^OL\d+W$/.test(olId)) payload = await fromOpenLibrary(olId);
  else return json({ error: "google_books_id or open_library_id required" }, 400);
  if (!payload) return json({ error: "book not found in catalog" }, 404);

  const admin = createClient(url, serviceKey);
  const { data, error } = await admin.rpc("upsert_catalog_book", { payload });
  if (error) return json({ error: error.message }, 500);
  return json(data);
});

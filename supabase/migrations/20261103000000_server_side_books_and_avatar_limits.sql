-- 1. Only the save-book Edge Function (service role) may write catalog books,
--    and two concurrent saves of the same edition no longer fail.
--    It fetches metadata from Google Books / Open Library itself, so clients
--    can no longer put made-up titles or covers into the shared tables.
create or replace function public.upsert_catalog_book(payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_google   text := nullif(payload->>'google_books_id', '');
  v_ol       text := nullif(payload->>'open_library_id', '');
  v_isbn13   text := nullif(payload->>'isbn_13', '');
  v_isbn10   text := nullif(payload->>'isbn_10', '');
  v_title    text := btrim(payload->>'title');
  v_authors  text[] := coalesce(array(select jsonb_array_elements_text(payload->'authors')), '{}');
  v_key      text;
  v_book     uuid;
  v_edition  uuid;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'service role only' using errcode = '42501'; end if;
  if v_title is null or v_title = '' then raise exception 'title required' using errcode = '22023'; end if;

  select e.id, e.book_id into v_edition, v_book from public.book_editions e
   where (v_google is not null and e.google_books_id = v_google)
      or (v_ol is not null and e.open_library_id = v_ol)
      or (v_isbn13 is not null and e.isbn_13 = v_isbn13)
      or (v_isbn10 is not null and e.isbn_10 = v_isbn10)
   order by (e.google_books_id = v_google) desc nulls last,
            (e.open_library_id = v_ol) desc nulls last
   limit 1;

  if v_edition is not null then
    return jsonb_build_object('book_id', v_book, 'edition_id', v_edition);
  end if;

  v_key := lower(v_title) || '|' || lower(coalesce(v_authors[1], ''));
  select b.id into v_book from public.books b where b.work_key = v_key limit 1;

  if v_book is null then
    insert into public.books (title, subtitle, authors, description, categories,
                              first_published, cover_url, work_key)
    values (v_title, payload->>'subtitle', v_authors, payload->>'description',
            coalesce(array(select jsonb_array_elements_text(payload->'categories')), '{}'),
            payload->>'published_date', payload->>'cover_url', v_key)
    returning id into v_book;
  end if;

  insert into public.book_editions (book_id, google_books_id, open_library_id, isbn_10, isbn_13,
                                    publisher, published_date, page_count, cover_url, language)
  values (v_book, v_google, v_ol, v_isbn10, v_isbn13, payload->>'publisher',
          payload->>'published_date', nullif((payload->>'page_count')::int, 0),
          payload->>'cover_url', payload->>'language')
  -- Another save of the same edition may have won the race since the lookup
  -- above; take its row instead of failing on either unique id.
  on conflict do nothing
  returning id, book_id into v_edition, v_book;

  if v_edition is null then
    select e.id, e.book_id into v_edition, v_book from public.book_editions e
     where (v_google is not null and e.google_books_id = v_google)
        or (v_ol is not null and e.open_library_id = v_ol)
     limit 1;
  end if;

  return jsonb_build_object('book_id', v_book, 'edition_id', v_edition);
end $$;

revoke execute on function public.upsert_catalog_book(jsonb) from authenticated, anon, public;
grant execute on function public.upsert_catalog_book(jsonb) to service_role;

-- 2. Avatars: small images only.
update storage.buckets
   set file_size_limit = 2097152,  -- 2 MB; the app uploads ~512px JPEG/PNG
       allowed_mime_types = '{image/jpeg,image/png}'
 where id = 'avatars';

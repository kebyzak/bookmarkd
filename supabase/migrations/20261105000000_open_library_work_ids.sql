-- Editions are grouped into one book only by Open Library work id, never by
-- title/author: an id match cannot merge two different books. A book with no
-- work id stays on its own, and duplicates are fixed with merge_books().

-- 1. The work id lives on the work.
alter table public.books
  add column open_library_work_id text unique check (open_library_work_id ~ '^OL[0-9]+W$');

-- Editions saved from Open Library search already hold their work id.
update public.books b set open_library_work_id = e.work_id
  from (select distinct on (book_id) book_id, open_library_id as work_id
          from public.book_editions
         where open_library_id ~ '^OL[0-9]+W$'
         order by book_id, created_at) e
 where e.book_id = b.id;

drop index public.books_work_key;
alter table public.books drop column work_key;

-- 2. Moving an edition to another book carries its readers' entries along.
alter table public.user_books
  drop constraint user_books_edition_id_book_id_fkey,
  add constraint user_books_edition_id_book_id_fkey
    foreign key (edition_id, book_id) references public.book_editions (id, book_id) on update cascade;

-- 3. Merge a duplicate book into the one that stays. Everything users made
--    moves over; when a reader has both, the entry or review they touched
--    last wins and the other entry's reading sessions move to it.
create function public.merge_books(p_from uuid, p_into uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare
  r      record;
  v_work text;
begin
  if coalesce(auth.role(), '') <> 'service_role' then raise exception 'service role only' using errcode = '42501'; end if;
  if p_from = p_into then raise exception 'cannot merge a book into itself' using errcode = '22023'; end if;
  perform 1 from public.books where id in (p_from, p_into) for update;
  if (select count(*) from public.books where id in (p_from, p_into)) <> 2 then
    raise exception 'book not found' using errcode = 'P0002';
  end if;

  for r in
    select case when a.updated_at > b.updated_at then a.id else b.id end as keep_id,
           case when a.updated_at > b.updated_at then b.id else a.id end as drop_id
      from public.user_books a
      join public.user_books b on b.user_id = a.user_id and b.book_id = p_into
     where a.book_id = p_from
  loop
    update public.reading_sessions set user_book_id = r.keep_id where user_book_id = r.drop_id;
    delete from public.user_books where id = r.drop_id;
  end loop;

  delete from public.reviews x using public.reviews y
   where x.user_id = y.user_id and x.book_id <> y.book_id
     and x.book_id in (p_from, p_into) and y.book_id in (p_from, p_into)
     and (x.updated_at, x.id) < (y.updated_at, y.id);

  update public.reviews set book_id = p_into where book_id = p_from;
  update public.activities set book_id = p_into where book_id = p_from;
  update public.book_editions set book_id = p_into where book_id = p_from;  -- cascades to user_books

  select open_library_work_id into v_work from public.books where id = p_from;
  delete from public.books where id = p_from;
  update public.books set open_library_work_id = coalesce(open_library_work_id, v_work) where id = p_into;
end $$;

revoke execute on function public.merge_books(uuid, uuid) from authenticated, anon, public;
grant execute on function public.merge_books(uuid, uuid) to service_role;

-- 4. Saving: a known edition returns its book; a new edition joins the book
--    with the same work id, or starts its own book when it has none.
create or replace function public.upsert_catalog_book(payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_google   text := nullif(payload->>'google_books_id', '');
  v_ol       text := nullif(payload->>'open_library_id', '');
  v_work     text := nullif(payload->>'open_library_work_id', '');
  v_isbn13   text := nullif(payload->>'isbn_13', '');
  v_isbn10   text := nullif(payload->>'isbn_10', '');
  v_title    text := btrim(payload->>'title');
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

  -- A null work id never conflicts, so a book without one is always new.
  insert into public.books (title, subtitle, authors, description, categories,
                            first_published, cover_url, open_library_work_id)
  values (v_title, payload->>'subtitle',
          coalesce(array(select jsonb_array_elements_text(payload->'authors')), '{}'),
          payload->>'description',
          coalesce(array(select jsonb_array_elements_text(payload->'categories')), '{}'),
          payload->>'published_date', payload->>'cover_url', v_work)
  on conflict (open_library_work_id) do nothing
  returning id into v_book;

  if v_book is null then
    select b.id into v_book from public.books b where b.open_library_work_id = v_work;
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

-- Run with: supabase test db
-- Editions join one book only by Open Library work id, and merge_books()
-- moves readers' data without losing or duplicating it. Rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'a@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'b@test.local');

-- Merge fixture: book m1 is a duplicate of m2. Reader a has both, and their m1
-- entry is newer; reader b has only m1.
insert into public.books (id, title) values
  ('00000000-0000-0000-0000-0000000000a1', 'Dune'),
  ('00000000-0000-0000-0000-0000000000a2', 'Dune');
update public.books set open_library_work_id = 'OL9W' where id = '00000000-0000-0000-0000-0000000000a1';
insert into public.book_editions (id, book_id, isbn_13) values
  ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000a1', '9780000000101'),
  ('00000000-0000-0000-0000-0000000000e2', '00000000-0000-0000-0000-0000000000a2', '9780000000102');
insert into public.user_books (id, user_id, book_id, edition_id, status, updated_at) values
  ('00000000-0000-0000-0000-0000000000c1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', 'finished', now()),
  ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000000a2', '00000000-0000-0000-0000-0000000000e2', 'reading', now() - interval '1 day'),
  ('00000000-0000-0000-0000-0000000000c3', '00000000-0000-0000-0000-00000000000b',
   '00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000e1', 'reading', now());
insert into public.reading_sessions (user_book_id, user_id, progress_percent)
  values ('00000000-0000-0000-0000-0000000000c2', '00000000-0000-0000-0000-00000000000a', 40);
insert into public.reviews (user_id, book_id, body, updated_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a1', 'new take', now()),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000a2', 'old take', now() - interval '1 day');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select throws_ok(
  $$ select public.merge_books('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2') $$,
  '42501', null, 'clients cannot merge books');

set local role service_role;
select set_config('request.jwt.claims', '{"role":"service_role"}', true);

-- Two different editions of one work, even under different titles, are one book.
select is(
  (select public.upsert_catalog_book('{"google_books_id":"g1","open_library_work_id":"OL1W","isbn_13":"9780000000011","title":"Harry Potter and the Philosopher''s Stone","authors":["J.K. Rowling"]}'::jsonb)->>'book_id'),
  (select public.upsert_catalog_book('{"google_books_id":"g2","open_library_work_id":"OL1W","isbn_13":"9780000000012","title":"Harry Potter and the Sorcerer''s Stone","authors":["J. K. Rowling"]}'::jsonb)->>'book_id'),
  'editions with the same work id share a book');

-- Same title and author but no work id: never guessed to be the same book.
select isnt(
  (select public.upsert_catalog_book('{"google_books_id":"g3","title":"Poems","authors":["Anon"]}'::jsonb)->>'book_id'),
  (select public.upsert_catalog_book('{"google_books_id":"g4","title":"Poems","authors":["Anon"]}'::jsonb)->>'book_id'),
  'matching title and author alone do not merge books');

select public.merge_books('00000000-0000-0000-0000-0000000000a1', '00000000-0000-0000-0000-0000000000a2');

select is((select count(*)::int from public.books where id = '00000000-0000-0000-0000-0000000000a1'), 0,
  'the duplicate book is gone');
select is((select open_library_work_id from public.books where id = '00000000-0000-0000-0000-0000000000a2'), 'OL9W',
  'the kept book takes over the work id');
select is((select count(*)::int from public.book_editions where book_id = '00000000-0000-0000-0000-0000000000a2'), 2,
  'editions move to the kept book');
select is(
  (select array_agg(id::text) from public.user_books where user_id = '00000000-0000-0000-0000-00000000000a'),
  array['00000000-0000-0000-0000-0000000000c1'],
  'a reader with both entries keeps the newer one');
select is((select book_id::text from public.user_books where id = '00000000-0000-0000-0000-0000000000c1'),
  '00000000-0000-0000-0000-0000000000a2', 'the kept entry points at the kept book');
select is((select user_book_id::text from public.reading_sessions where progress_percent = 40),
  '00000000-0000-0000-0000-0000000000c1', 'reading sessions of the dropped entry move to the kept one');
select is((select book_id::text from public.user_books where id = '00000000-0000-0000-0000-0000000000c3'),
  '00000000-0000-0000-0000-0000000000a2', 'other readers move to the kept book');
select is(
  (select array_agg(body) from public.reviews where user_id = '00000000-0000-0000-0000-00000000000a'),
  array['new take'], 'a reader with two reviews keeps the newer one');

select * from finish(true);
rollback;

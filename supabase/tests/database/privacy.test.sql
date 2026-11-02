-- Run with: supabase test db
-- A private reader's library, reviews and activity must be invisible and
-- unwritable for everyone else. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

-- Two users; the on_auth_user_created trigger makes their profiles.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'private@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'other@test.local');
update public.profiles set is_private = true where id = '00000000-0000-0000-0000-00000000000a';

insert into public.books (id, title, work_key)
  values ('00000000-0000-0000-0000-0000000000b1', 'Secret Book', 'secret book|');
insert into public.book_editions (id, book_id, isbn_13)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000b1', '9780000000001');
-- Inserting the entry also emits an activity through the trigger.
insert into public.user_books (user_id, book_id, edition_id, status)
  values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
          '00000000-0000-0000-0000-0000000000e1', 'reading');
insert into public.reviews (user_id, book_id, body)
  values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1', 'private thoughts');

-- Act as the other user.
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);

select is((select count(*)::int from public.user_books), 0, 'others cannot see a private library');
select is((select count(*)::int from public.reviews), 0, 'others cannot see private reviews');
select is((select count(*)::int from public.activities), 0, 'others cannot see private activity');
select throws_ok(
  $$ insert into public.user_books (user_id, book_id, edition_id, status)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
             '00000000-0000-0000-0000-0000000000e1', 'finished') $$,
  '42501', null, 'others cannot write into a private library');
select throws_ok(
  $$ select public.upsert_catalog_book('{"title":"Fake","google_books_id":"x"}'::jsonb) $$,
  '42501', null, 'clients cannot write catalog books directly');

-- Act as the owner.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.user_books), 1, 'the owner still sees their own library');

select * from finish();
rollback;

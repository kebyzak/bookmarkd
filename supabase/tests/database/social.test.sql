-- Run with: supabase test db
-- Follow notifications reach only the followee, and past-year reads stay out
-- of the feed. Everything is rolled back at the end.
begin;
create extension if not exists pgtap with schema extensions;
select plan(7);

insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-00000000000a', 'reader@test.local'),
  ('00000000-0000-0000-0000-00000000000b', 'fan@test.local'),
  ('00000000-0000-0000-0000-00000000000c', 'bystander@test.local');

insert into public.books (id, title, work_key)
  values ('00000000-0000-0000-0000-0000000000b1', 'Old Book', 'old book|');
insert into public.book_editions (id, book_id, isbn_13)
  values ('00000000-0000-0000-0000-0000000000e1', '00000000-0000-0000-0000-0000000000b1', '9780000000002');

set local role authenticated;

-- The fan follows the reader.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
insert into public.follows (follower_id, followee_id)
  values ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-00000000000a');
select is((select count(*)::int from public.notifications), 0, 'the follower does not see the notice');
select throws_ok(
  $$ insert into public.notifications (user_id, actor_id, type)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-00000000000b', 'follow') $$,
  '42501', null, 'clients cannot forge notifications');

-- The reader logs a book finished two years ago.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.notifications where actor_id = '00000000-0000-0000-0000-00000000000b'),
          1, 'the followee is notified');
update public.notifications set read_at = now();
select is((select count(*)::int from public.notifications where read_at is null), 0, 'the followee can mark it read');
insert into public.user_books (user_id, book_id, edition_id, status, finished_at)
  values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000000b1',
          '00000000-0000-0000-0000-0000000000e1', 'finished', current_date - interval '2 years');
select is((select count(*)::int from public.activities), 0, 'a past-year finish is not posted to the feed');

-- A bystander sees nothing; an unfollow takes the notice back.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000c","role":"authenticated"}', true);
select is((select count(*)::int from public.notifications), 0, 'others cannot see the notice');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000b","role":"authenticated"}', true);
delete from public.follows where follower_id = '00000000-0000-0000-0000-00000000000b';
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', true);
select is((select count(*)::int from public.notifications), 0, 'unfollowing removes the notice');

select * from finish();
rollback;

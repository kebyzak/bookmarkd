-- 1. Reading history: a book logged as finished in an earlier year is history,
--    not news, so it no longer posts a "finished" activity to followers' feeds.
--    (The yearly goal already counts only finished_at in the current year.)
create or replace function public.emit_user_book_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  kind public.activity_type;
begin
  if (tg_op = 'INSERT' or new.status is distinct from old.status)
     and not (new.status = 'finished' and new.finished_at < date_trunc('year', current_date)::date) then
    kind := case new.status
      when 'want_to_read' then 'want_to_read'
      when 'reading' then 'started'
      when 'finished' then 'finished'
      when 'dnf' then 'dnf'
    end::public.activity_type;
    insert into public.activities (actor_id, type, book_id, edition_id, rating)
    values (new.user_id, kind, new.book_id, new.edition_id, new.rating);
  end if;
  if new.rating is not null
     and (tg_op = 'INSERT' and new.status <> 'finished'
          or tg_op = 'UPDATE' and new.rating is distinct from old.rating) then
    insert into public.activities (actor_id, type, book_id, edition_id, rating)
    values (new.user_id, 'rated', new.book_id, new.edition_id, new.rating);
  end if;
  return new;
end $$;

-- 2. Notifications. Written only by triggers; the recipient may read them and
--    mark them read, nothing else.
create type public.notification_type as enum ('follow');

create table public.notifications (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,  -- recipient
  actor_id    uuid not null references public.profiles (id) on delete cascade,
  type        public.notification_type not null,
  created_at  timestamptz not null default now(),
  read_at     timestamptz,
  unique (user_id, actor_id, type)
);
create index notifications_user_created on public.notifications (user_id, created_at desc);

alter table public.notifications enable row level security;

create policy notifications_select on public.notifications for select to authenticated
  using (user_id = auth.uid());
create policy notifications_update on public.notifications for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

revoke insert, update, delete on public.notifications from anon, authenticated;
grant update (read_at) on public.notifications to authenticated;

-- A follow notifies the followee; an unfollow takes the notice back, so it
-- never claims a follow that no longer exists.
create function public.notify_follow() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (user_id, actor_id, type)
    values (new.followee_id, new.follower_id, 'follow')
    on conflict (user_id, actor_id, type) do update set created_at = now(), read_at = null;
    return new;
  end if;
  delete from public.notifications
   where user_id = old.followee_id and actor_id = old.follower_id and type = 'follow';
  return old;
end $$;

create trigger follows_notify after insert or delete on public.follows
  for each row execute function public.notify_follow();

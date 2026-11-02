-- Bookmarkd initial schema.
-- Shared book metadata (books, book_editions) is separate from per-user data.
-- Every exposed table has RLS enabled. Clients never write books/editions
-- directly; they go through upsert_catalog_book().

create extension if not exists pg_trgm;

-- ───────────────────────── types ─────────────────────────
create type public.reading_status as enum ('want_to_read', 'reading', 'finished', 'dnf');
create type public.activity_type as enum ('want_to_read', 'started', 'finished', 'dnf', 'rated', 'reviewed');

-- ───────────────────────── profiles ─────────────────────────
create table public.profiles (
  id            uuid primary key references auth.users (id) on delete cascade,
  username      text unique
                check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name  text check (char_length(display_name) <= 60),
  bio           text check (char_length(bio) <= 280),
  avatar_url    text,
  reading_goal  integer check (reading_goal between 1 and 1000),
  is_private    boolean not null default false,
  onboarded     boolean not null default false,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index profiles_username_trgm on public.profiles using gin (username gin_trgm_ops);

-- A profile row is created for every new auth user.
create function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end $$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- True when the current user may see `owner`'s library, reviews and activity.
create function public.can_view_user(owner uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select owner = auth.uid()
      or exists (select 1 from public.profiles p where p.id = owner and not p.is_private);
$$;

-- ───────────────────────── books ─────────────────────────
create table public.books (
  id                uuid primary key default gen_random_uuid(),
  title             text not null check (char_length(title) between 1 and 500),
  subtitle          text,
  authors           text[] not null default '{}',
  description       text,
  categories        text[] not null default '{}',
  first_published   text,
  cover_url         text,
  work_key          text not null,          -- lower(title) || '|' || lower(first author)
  created_at        timestamptz not null default now()
);
create index books_work_key on public.books (work_key);
create index books_categories on public.books using gin (categories);

create table public.book_editions (
  id                uuid primary key default gen_random_uuid(),
  book_id           uuid not null references public.books (id) on delete cascade,
  google_books_id   text unique,
  open_library_id   text unique,
  isbn_10           text check (isbn_10 ~ '^[0-9]{9}[0-9X]$'),
  isbn_13           text check (isbn_13 ~ '^[0-9]{13}$'),
  publisher         text,
  published_date    text,
  page_count        integer check (page_count > 0),
  cover_url         text,
  language          text,
  created_at        timestamptz not null default now(),
  check (google_books_id is not null or open_library_id is not null
         or isbn_13 is not null or isbn_10 is not null)
);
create index book_editions_book on public.book_editions (book_id);
create index book_editions_isbn13 on public.book_editions (isbn_13);
create index book_editions_isbn10 on public.book_editions (isbn_10);

-- ───────────────────────── user_books ─────────────────────────
create table public.user_books (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references public.profiles (id) on delete cascade,
  book_id           uuid not null references public.books (id) on delete restrict,
  edition_id        uuid not null references public.book_editions (id) on delete restrict,
  status            public.reading_status not null,
  current_page      integer check (current_page >= 0),
  progress_percent  smallint check (progress_percent between 0 and 100),
  rating            smallint check (rating between 1 and 10),  -- half stars
  is_favorite       boolean not null default false,
  started_at        date,
  finished_at       date,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now(),
  unique (user_id, book_id),
  check (finished_at is null or started_at is null or finished_at >= started_at)
);
create index user_books_user_created on public.user_books (user_id, created_at desc);
create index user_books_book on public.user_books (book_id);

-- ───────────────────────── reading_sessions ─────────────────────────
create table public.reading_sessions (
  id                uuid primary key default gen_random_uuid(),
  user_book_id      uuid not null references public.user_books (id) on delete cascade,
  user_id           uuid not null references public.profiles (id) on delete cascade,
  from_page         integer check (from_page >= 0),
  to_page           integer check (to_page >= 0),
  progress_percent  smallint not null check (progress_percent between 0 and 100),
  read_on           date not null default current_date,
  created_at        timestamptz not null default now()
);
create index reading_sessions_entry on public.reading_sessions (user_book_id, created_at desc);

-- ───────────────────────── reviews ─────────────────────────
create table public.reviews (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  book_id     uuid not null references public.books (id) on delete cascade,
  body        text not null check (char_length(body) between 1 and 5000),
  contains_spoilers boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  unique (user_id, book_id)
);
create index reviews_book_created on public.reviews (book_id, created_at desc);

-- ───────────────────────── follows ─────────────────────────
create table public.follows (
  follower_id uuid not null references public.profiles (id) on delete cascade,
  followee_id uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (follower_id, followee_id),
  check (follower_id <> followee_id)
);
create index follows_followee on public.follows (followee_id);

-- ───────────────────────── activities ─────────────────────────
create table public.activities (
  id          uuid primary key default gen_random_uuid(),
  actor_id    uuid not null references public.profiles (id) on delete cascade,
  type        public.activity_type not null,
  book_id     uuid not null references public.books (id) on delete cascade,
  edition_id  uuid references public.book_editions (id) on delete set null,
  rating      smallint check (rating between 1 and 10),
  review_id   uuid references public.reviews (id) on delete cascade,
  created_at  timestamptz not null default now()
);
-- Keyset pagination: (created_at, id) descending per actor.
create index activities_actor_created on public.activities (actor_id, created_at desc, id desc);
create index activities_created on public.activities (created_at desc, id desc);

create table public.activity_likes (
  activity_id uuid not null references public.activities (id) on delete cascade,
  user_id     uuid not null references public.profiles (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (activity_id, user_id)
);
create index activity_likes_user on public.activity_likes (user_id);

-- ───────────────────────── updated_at ─────────────────────────
create function public.touch_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger user_books_touch before update on public.user_books
  for each row execute function public.touch_updated_at();
create trigger reviews_touch before update on public.reviews
  for each row execute function public.touch_updated_at();

-- ───────────────────────── activity triggers ─────────────────────────
create function public.emit_user_book_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
declare
  kind public.activity_type;
begin
  if tg_op = 'INSERT' or new.status is distinct from old.status then
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

create trigger user_books_activity after insert or update on public.user_books
  for each row execute function public.emit_user_book_activity();

create function public.emit_review_activity() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.activities (actor_id, type, book_id, review_id, rating)
  values (new.user_id, 'reviewed', new.book_id, new.id,
          (select ub.rating from public.user_books ub
            where ub.user_id = new.user_id and ub.book_id = new.book_id));
  return new;
end $$;

create trigger reviews_activity after insert on public.reviews
  for each row execute function public.emit_review_activity();

-- ───────────────────────── RLS ─────────────────────────
alter table public.profiles         enable row level security;
alter table public.books            enable row level security;
alter table public.book_editions    enable row level security;
alter table public.user_books       enable row level security;
alter table public.reading_sessions enable row level security;
alter table public.reviews          enable row level security;
alter table public.follows          enable row level security;
alter table public.activities       enable row level security;
alter table public.activity_likes   enable row level security;

-- profiles: discoverable by signed-in users; only the owner edits.
create policy profiles_select on public.profiles for select to authenticated using (true);
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- books / editions: readable; written only via upsert_catalog_book().
create policy books_select on public.books for select to authenticated using (true);
create policy editions_select on public.book_editions for select to authenticated using (true);

-- user_books
create policy user_books_select on public.user_books for select to authenticated
  using (public.can_view_user(user_id));
create policy user_books_insert on public.user_books for insert to authenticated
  with check (user_id = auth.uid());
create policy user_books_update on public.user_books for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy user_books_delete on public.user_books for delete to authenticated
  using (user_id = auth.uid());

-- reading_sessions: private to the owner; written via log_reading_progress().
create policy sessions_select on public.reading_sessions for select to authenticated
  using (user_id = auth.uid());
create policy sessions_insert on public.reading_sessions for insert to authenticated
  with check (user_id = auth.uid()
              and exists (select 1 from public.user_books ub
                          where ub.id = user_book_id and ub.user_id = auth.uid()));
create policy sessions_delete on public.reading_sessions for delete to authenticated
  using (user_id = auth.uid());

-- reviews
create policy reviews_select on public.reviews for select to authenticated
  using (public.can_view_user(user_id));
create policy reviews_insert on public.reviews for insert to authenticated
  with check (user_id = auth.uid());
create policy reviews_update on public.reviews for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy reviews_delete on public.reviews for delete to authenticated
  using (user_id = auth.uid());

-- follows
create policy follows_select on public.follows for select to authenticated using (true);
create policy follows_insert on public.follows for insert to authenticated
  with check (follower_id = auth.uid());
create policy follows_delete on public.follows for delete to authenticated
  using (follower_id = auth.uid());

-- activities: inserted only by triggers (security definer); never by clients.
create policy activities_select on public.activities for select to authenticated
  using (public.can_view_user(actor_id));

-- likes
create policy likes_select on public.activity_likes for select to authenticated using (true);
create policy likes_insert on public.activity_likes for insert to authenticated
  with check (user_id = auth.uid()
              and exists (select 1 from public.activities a
                          where a.id = activity_id and public.can_view_user(a.actor_id)));
create policy likes_delete on public.activity_likes for delete to authenticated
  using (user_id = auth.uid());

-- ───────────────────────── storage: avatars ─────────────────────────
insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

create policy avatars_read on storage.objects for select
  using (bucket_id = 'avatars');
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_update on storage.objects for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- ───────────────────────── functions ─────────────────────────

-- Saves normalized catalog metadata, deduplicating editions and works.
-- Returns {book_id, edition_id}. Idempotent: same payload → same ids.
create function public.upsert_catalog_book(payload jsonb) returns jsonb
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
  if auth.uid() is null then raise exception 'not authenticated' using errcode = '42501'; end if;
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
  on conflict (google_books_id) do update set google_books_id = excluded.google_books_id
  returning id, book_id into v_edition, v_book;

  return jsonb_build_object('book_id', v_book, 'edition_id', v_edition);
end $$;

-- Updates progress and records a session atomically. Validates the page
-- against the edition's page count.
create function public.log_reading_progress(
  p_user_book_id uuid, p_current_page integer, p_progress_percent integer
) returns public.user_books
language plpgsql security invoker set search_path = '' as $$
declare
  v_entry public.user_books;
  v_pages integer;
  v_percent integer;
begin
  select * into v_entry from public.user_books
   where id = p_user_book_id and user_id = auth.uid() for update;
  if not found then raise exception 'entry not found' using errcode = 'P0002'; end if;

  select page_count into v_pages from public.book_editions where id = v_entry.edition_id;

  if p_current_page is not null then
    if p_current_page < 0 or (v_pages is not null and p_current_page > v_pages) then
      raise exception 'page out of range' using errcode = '22023';
    end if;
    v_percent := case when v_pages is null then coalesce(p_progress_percent, 0)
                      else round(p_current_page * 100.0 / v_pages) end;
  else
    if p_progress_percent is null or p_progress_percent not between 0 and 100 then
      raise exception 'percent out of range' using errcode = '22023';
    end if;
    v_percent := p_progress_percent;
  end if;

  insert into public.reading_sessions (user_book_id, user_id, from_page, to_page, progress_percent)
  values (v_entry.id, v_entry.user_id, v_entry.current_page, p_current_page, v_percent);

  update public.user_books
     set current_page = p_current_page,
         progress_percent = v_percent,
         started_at = coalesce(started_at, current_date),
         status = case when status = 'want_to_read' then 'reading'::public.reading_status else status end
   where id = v_entry.id
  returning * into v_entry;
  return v_entry;
end $$;

-- Feed of the caller and the people they follow, newest first, keyset paginated.
create function public.get_feed(
  p_before_ts timestamptz default null, p_before_id uuid default null, p_limit integer default 20
) returns table (
  id uuid, type public.activity_type, created_at timestamptz, rating smallint,
  actor_id uuid, actor_username text, actor_display_name text, actor_avatar_url text,
  book_id uuid, book_title text, book_authors text[], cover_url text,
  review_excerpt text, like_count bigint, liked_by_me boolean
)
language sql stable security invoker set search_path = '' as $$
  select a.id, a.type, a.created_at, a.rating,
         p.id, p.username, p.display_name, p.avatar_url,
         b.id, b.title, b.authors, coalesce(e.cover_url, b.cover_url),
         left(r.body, 280),
         (select count(*) from public.activity_likes l where l.activity_id = a.id),
         exists (select 1 from public.activity_likes l where l.activity_id = a.id and l.user_id = auth.uid())
    from public.activities a
    join public.profiles p on p.id = a.actor_id
    join public.books b on b.id = a.book_id
    left join public.book_editions e on e.id = a.edition_id
    left join public.reviews r on r.id = a.review_id
   where (a.actor_id = auth.uid()
          or a.actor_id in (select f.followee_id from public.follows f where f.follower_id = auth.uid()))
     and (p_before_ts is null or (a.created_at, a.id) < (p_before_ts, p_before_id))
   order by a.created_at desc, a.id desc
   limit least(greatest(p_limit, 1), 50);
$$;

-- Community stats for one work (visible entries only, via RLS).
create function public.get_book_stats(p_book_id uuid)
returns table (average_rating numeric, rating_count bigint, reader_count bigint)
language sql stable security invoker set search_path = '' as $$
  select round(avg(rating) / 2.0, 2), count(rating), count(*)
    from public.user_books where book_id = p_book_id;
$$;

-- Most-added works, optionally restricted to a category.
create function public.get_popular_books(p_limit integer default 20, p_category text default null)
returns table (book_id uuid, reader_count bigint)
language sql stable security invoker set search_path = '' as $$
  select ub.book_id, count(*) as reader_count
    from public.user_books ub join public.books b on b.id = ub.book_id
   where p_category is null or p_category = any (b.categories)
   group by ub.book_id
   order by reader_count desc, ub.book_id
   limit least(greatest(p_limit, 1), 50);
$$;

-- Works with the most activity in the last p_days days.
create function public.get_trending_books(p_days integer default 7, p_limit integer default 20)
returns table (book_id uuid, activity_count bigint)
language sql stable security invoker set search_path = '' as $$
  select a.book_id, count(*) as activity_count
    from public.activities a
   where a.created_at > now() - make_interval(days => greatest(p_days, 1))
   group by a.book_id
   order by activity_count desc, a.book_id
   limit least(greatest(p_limit, 1), 50);
$$;

grant execute on function public.upsert_catalog_book(jsonb) to authenticated;
grant execute on function public.log_reading_progress(uuid, integer, integer) to authenticated;
grant execute on function public.get_feed(timestamptz, uuid, integer) to authenticated;
grant execute on function public.get_book_stats(uuid) to authenticated;
grant execute on function public.get_popular_books(integer, text) to authenticated;
grant execute on function public.get_trending_books(integer, integer) to authenticated;
revoke execute on function public.upsert_catalog_book(jsonb) from anon, public;

-- Progress dates come from the reader's device, not the server clock (UTC).
-- Before: logging at 20:00 in Los Angeles stored tomorrow's date.

drop function public.log_reading_progress(uuid, integer, integer);

create function public.log_reading_progress(
  p_user_book_id uuid, p_current_page integer, p_progress_percent integer, p_today date
) returns public.user_books
language plpgsql security invoker set search_path = '' as $$
declare
  v_entry public.user_books;
  v_pages integer;
  v_percent integer;
begin
  -- A device date can be off by a time zone, never by more.
  if p_today is null or p_today not between current_date - 1 and current_date + 1 then
    raise exception 'invalid date' using errcode = '22023';
  end if;

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

  insert into public.reading_sessions (user_book_id, user_id, from_page, to_page, progress_percent, read_on)
  values (v_entry.id, v_entry.user_id, v_entry.current_page, p_current_page, v_percent, p_today);

  update public.user_books
     set current_page = p_current_page,
         progress_percent = v_percent,
         started_at = coalesce(started_at, p_today),
         status = case when status = 'want_to_read' then 'reading'::public.reading_status else status end
   where id = v_entry.id
  returning * into v_entry;
  return v_entry;
end $$;

grant execute on function public.log_reading_progress(uuid, integer, integer, date) to authenticated;

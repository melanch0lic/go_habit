-- Communities no longer link personal habits.
--
-- Membership is independent of the user's habits: joining or leaving never reads,
-- creates or changes a habit, and creating a habit from a template never joins its
-- community. Without a link there is no data a weekly ranking could be computed
-- from, so the ranking functions are removed until a dedicated source of community
-- activity exists. Existing memberships are kept; only the link column goes away.

drop function if exists public.community_leaderboard(text, date, integer);
drop function if exists public._community_scores(text, date);
drop function if exists public.join_community(text, uuid, date);

drop policy if exists "community_membership: owner can relink" on public.community_membership;
revoke update on table public.community_membership from authenticated;

alter table public.community_membership drop constraint if exists community_membership_habit_owner_fkey;
drop index if exists public.community_membership_habit_idx;
alter table public.community_membership drop column if exists habit_id;

comment on table public.community_membership is
  'Community participation, independent of personal habits. Leaving deletes the row.';

-- Same checks as before, without the habit link.
create or replace function public.community_membership_guard()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  utc_today constant date := (now() at time zone 'utc')::date;
begin
  if tg_op = 'INSERT' then
    if not exists (select 1 from public.habit_template t where t.id = new.template_id and t.is_active) then
      raise exception 'community % is not open for joining', new.template_id using errcode = '23514';
    end if;
    -- The client sends its local date; time zones keep it within a day of UTC.
    if new.joined_on is null or new.joined_on not between utc_today - 1 and utc_today + 1 then
      new.joined_on := utc_today;
    end if;
  else
    if new.template_id is distinct from old.template_id then
      raise exception 'template_id is immutable' using errcode = '42501';
    end if;
    new.joined_on := old.joined_on;
  end if;
  return new;
end;
$$;

revoke execute on function public.community_membership_guard() from public, anon, authenticated;

-- Idempotent join: a retry or a concurrent request returns the existing membership.
-- Runs with the caller's rights, so RLS, column grants and the guard trigger apply.
create or replace function public.join_community(p_template_id text, p_joined_on date default null)
returns public.community_membership
language plpgsql
security invoker
set search_path = ''
as $$
declare
  result public.community_membership;
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  insert into public.community_membership (template_id, joined_on)
  values (p_template_id, p_joined_on)
  on conflict (user_id, template_id) do nothing
  returning * into result;

  if result.id is null then
    select * into result
      from public.community_membership m
     where m.user_id = auth.uid() and m.template_id = p_template_id;
  end if;
  return result;
end;
$$;

revoke execute on function public.join_community(text, date) from public, anon;
grant execute on function public.join_community(text, date) to authenticated;

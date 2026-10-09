-- Ranked habits for communities.
--
-- A member may take part in the weekly ranking with one personal habit created from
-- the community's template (the app never links an arbitrary existing habit). Joining
-- without such a habit is allowed; it can be created at any time later. Leaving
-- deletes the membership only: the habit and its history stay with the user.

-- ---------------------------------------------------------------------------
-- The link
-- ---------------------------------------------------------------------------

alter table public.community_membership add column if not exists habit_id uuid;

-- The habit must belong to the same user. Hard-deleting it (only via account
-- deletion) unlinks it instead of removing the membership.
alter table public.community_membership
  add constraint community_membership_habit_owner_fkey foreign key (habit_id, user_id)
  references public.habit (id, user_id) on delete set null (habit_id);

-- A habit ranks in one community at most.
create unique index community_membership_habit_key
  on public.community_membership (habit_id) where habit_id is not null;

comment on column public.community_membership.habit_id is
  'The member''s ranked habit, created from the template. Null: member without ranking.';

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

  if new.habit_id is not null
     and (tg_op = 'INSERT' or new.habit_id is distinct from old.habit_id)
     and exists (select 1 from public.habit h where h.id = new.habit_id and h.deleted_at is not null) then
    raise exception 'cannot rank with a deleted habit' using errcode = '23514';
  end if;
  return new;
end;
$$;

revoke execute on function public.community_membership_guard() from public, anon, authenticated;

-- Only the ranked habit can be set later; the community and join day stay fixed.
grant insert (habit_id) on table public.community_membership to authenticated;
grant update (habit_id) on table public.community_membership to authenticated;

create policy "community_membership: owner can set the ranked habit"
  on public.community_membership for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- join_community: idempotent join, optionally with a ranked habit
-- ---------------------------------------------------------------------------

drop function if exists public.join_community(text, date);

-- Runs with the caller's rights, so RLS, column grants and the guard trigger apply.
-- Repeating the call returns the existing membership; a given habit becomes the
-- ranked habit, a null habit keeps the current one.
create or replace function public.join_community(p_template_id text, p_habit_id uuid default null, p_joined_on date default null)
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

  insert into public.community_membership as m (template_id, habit_id, joined_on)
  values (p_template_id, p_habit_id, p_joined_on)
  on conflict (user_id, template_id) do update
    set habit_id = coalesce(excluded.habit_id, m.habit_id)
  returning * into result;
  return result;
end;
$$;

-- ---------------------------------------------------------------------------
-- Weekly ranking (weekly_consistency_v1), computed on the server only
-- ---------------------------------------------------------------------------

-- Internal; not callable by clients. For every member with a ranked habit:
--   week        = Monday .. p_today (the viewer's current local date)
--   start day   = latest of: week start, join day, the habit's creation day (UTC)
--   eligible    = days from start day to p_today (every day is scheduled: habits are daily)
--   completed   = distinct completed days in that range (tombstones excluded)
--   consistency = completed / eligible * 100, full precision
-- A deleted or paused ranked habit is not scored (there is no history of pauses).
create or replace function public._community_scores(p_template_id text, p_today date)
returns table (user_id uuid, completed_days integer, eligible_days integer, consistency numeric)
language sql
stable
set search_path = ''
as $$
  with members as (
    select m.user_id,
           m.habit_id,
           greatest(
             p_today - (extract(isodow from p_today)::integer - 1),
             m.joined_on,
             (h.created_at at time zone 'utc')::date
           ) as start_day
      from public.community_membership m
      join public.habit h on h.id = m.habit_id and h.user_id = m.user_id
     where m.template_id = p_template_id
       and h.deleted_at is null
       and h.is_active
  ),
  counted as (
    select mb.user_id,
           (select count(distinct c.completed_on)
              from public.habit_completion c
             where c.habit_id = mb.habit_id
               and c.deleted_at is null
               and c.completed_on between mb.start_day and p_today)::integer as completed_days,
           greatest(0, p_today - mb.start_day + 1)::integer as eligible_days
      from members mb
  )
  select c.user_id,
         c.completed_days,
         c.eligible_days,
         case when c.eligible_days > 0 then c.completed_days::numeric * 100 / c.eligible_days end
    from counted c;
$$;

-- Ranked members of a community for the current week: the top p_limit plus the
-- caller's own row. Exposes only rank, the public display name (or null), whether the
-- row is the caller's, and the computed numbers; never user ids, emails or habits.
-- Ties: higher consistency, then more completed days, then a stable internal order.
create or replace function public.community_leaderboard(p_template_id text, p_today date, p_limit integer default 20)
returns table (
  rank           integer,
  display_name   text,
  is_me          boolean,
  completed_days integer,
  eligible_days  integer,
  consistency    numeric,
  ranked_count   integer
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller    constant uuid := auth.uid();
  utc_today constant date := (now() at time zone 'utc')::date;
  row_limit constant integer := least(greatest(coalesce(p_limit, 20), 1), 100);
begin
  if caller is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  -- Only the current week can be requested (the caller's local date).
  if p_today is null or p_today not between utc_today - 1 and utc_today + 1 then
    raise exception 'p_today must be the current local date' using errcode = '22023';
  end if;
  if not exists (select 1 from public.habit_template t where t.id = p_template_id) then
    raise exception 'unknown community %', p_template_id using errcode = 'P0002';
  end if;

  return query
  with scores as (
    select * from public._community_scores(p_template_id, p_today)
  ),
  ranked as (
    select s.user_id,
           s.completed_days,
           s.eligible_days,
           s.consistency,
           (row_number() over (order by s.consistency desc, s.completed_days desc, s.user_id))::integer as position,
           (count(*) over ())::integer as total
      from scores s
     where s.eligible_days > 0
  )
  select r.position,
         nullif(btrim(p.display_name), ''),
         r.user_id = caller,
         r.completed_days,
         r.eligible_days,
         r.consistency,
         r.total
    from ranked r
    left join public.profile p on p.id = r.user_id
   where r.position <= row_limit or r.user_id = caller
  union all
  -- The caller is a member but not ranked yet (no ranked habit or no eligible day).
  select null::integer,
         null::text,
         true,
         coalesce(s.completed_days, 0),
         coalesce(s.eligible_days, 0),
         null::numeric,
         (select count(*)::integer from ranked)
    from public.community_membership m
    left join scores s on s.user_id = m.user_id
   where m.template_id = p_template_id
     and m.user_id = caller
     and not exists (select 1 from ranked r where r.user_id = caller)
   order by 1 nulls last;
end;
$$;

revoke execute on function public._community_scores(text, date) from public, anon, authenticated;
revoke execute on function public.join_community(text, uuid, date) from public, anon;
revoke execute on function public.community_leaderboard(text, date, integer) from public, anon;
grant execute on function public.join_community(text, uuid, date) to authenticated;
grant execute on function public.community_leaderboard(text, date, integer) to authenticated;

-- Habit schedules: daily, a weekly target, or selected weekdays; and the streak reset
-- day. See docs/SCHEDULES.md.
--
-- Existing habits become daily, which is what they were. Completions are untouched.
-- Streaks stay derived from the completion history on the client; the server only
-- stores the reset day so every device starts the new streak on the same day.

alter table public.habit
  add column schedule_type   text not null default 'daily',
  -- Completions per week for 'weekly_target'.
  add column weekly_target   smallint,
  -- Bit (ISO weekday - 1) per selected day for 'weekdays' (Monday = 1, Sunday = 64).
  add column schedule_days   smallint,
  -- Completions before this day do not count for the streak (set when the user
  -- confirms a change of schedule type).
  add column streak_reset_on date;

alter table public.habit
  add constraint habit_schedule_type check (schedule_type in ('daily', 'weekly_target', 'weekdays')),
  add constraint habit_weekly_target_range check (weekly_target is null or weekly_target between 1 and 7),
  add constraint habit_schedule_days_range check (schedule_days is null or schedule_days between 1 and 127),
  -- Exactly the parameters of the chosen type are set.
  add constraint habit_schedule_consistent check (
    (schedule_type = 'weekly_target') = (weekly_target is not null)
    and (schedule_type = 'weekdays') = (schedule_days is not null)
  ),
  add constraint habit_streak_reset_on_range check (streak_reset_on is null or streak_reset_on >= date '2000-01-01');

-- Weekly consistency of one habit over p_start .. p_today (rule weekly_consistency_v1
-- with schedules):
--   daily          every day is scheduled; each marked day counts once
--   weekdays       only the selected days are scheduled
--   weekly_target  the target is what is asked; marks beyond it do not count
-- Nothing is eligible when p_start is after p_today.
create or replace function public._habit_period_counts(
  p_habit_id uuid,
  p_type     text,
  p_target   integer,
  p_days     integer,
  p_start    date,
  p_today    date
)
returns table (completed_days integer, eligible_days integer)
language sql
stable
set search_path = ''
as $$
  with scheduled as (
    select d::date as day
      from generate_series(p_start, p_today, interval '1 day') d
     where p_type <> 'weekdays' or (p_days & (1 << (extract(isodow from d)::integer - 1))) <> 0
  ),
  done as (
    select count(distinct c.completed_on)::integer as n
      from public.habit_completion c
     where c.habit_id = p_habit_id
       and c.deleted_at is null
       and c.completed_on in (select day from scheduled)
  )
  select case
           when p_start > p_today then 0
           when p_type = 'weekly_target' then least((select n from done), p_target)
           else (select n from done)
         end,
         case
           when p_start > p_today then 0
           when p_type = 'weekly_target' then p_target
           else (select count(*)::integer from scheduled)
         end;
$$;

-- Community ranking scores, now schedule-aware (same signature and output).
create or replace function public._community_scores(p_template_id text, p_today date)
returns table (user_id uuid, completed_days integer, eligible_days integer, consistency numeric)
language sql
stable
set search_path = ''
as $$
  with members as (
    select m.user_id,
           h.id as habit_id,
           h.schedule_type,
           h.weekly_target::integer as weekly_target,
           h.schedule_days::integer as schedule_days,
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
  )
  select mb.user_id,
         x.completed_days,
         x.eligible_days,
         case when x.eligible_days > 0 then x.completed_days::numeric * 100 / x.eligible_days end
    from members mb
    cross join lateral public._habit_period_counts(
      mb.habit_id, mb.schedule_type, mb.weekly_target, mb.schedule_days, mb.start_day, p_today
    ) x;
$$;

-- Friends ranking totals over all active habits, now schedule-aware.
create or replace function public._weekly_totals(p_user uuid, p_today date)
returns table (completed_days integer, eligible_days integer)
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(x.completed_days), 0)::integer, coalesce(sum(x.eligible_days), 0)::integer
    from public.habit h
    cross join lateral public._habit_period_counts(
      h.id,
      h.schedule_type,
      h.weekly_target::integer,
      h.schedule_days::integer,
      greatest(p_today - (extract(isodow from p_today)::integer - 1), (h.created_at at time zone 'utc')::date),
      p_today
    ) x
   where h.user_id = p_user and h.deleted_at is null and h.is_active;
$$;

revoke execute on function public._habit_period_counts(uuid, text, integer, integer, date, date)
  from public, anon, authenticated;
revoke execute on function public._community_scores(text, date) from public, anon, authenticated;
revoke execute on function public._weekly_totals(uuid, date) from public, anon, authenticated;

-- Habit catalog and communities (phase 1).
--
-- A community is identified by its catalog template: there is one persistent
-- community per template, so no separate community table is needed. Membership links
-- a user to a template and, optionally, to one of the user's own habits; scores are
-- computed on the server from the existing habit_completion rows and are never
-- written by clients. See docs/COMMUNITIES.md.

-- ---------------------------------------------------------------------------
-- habit_template: read-only catalog, managed via migrations
-- ---------------------------------------------------------------------------

create table public.habit_template (
  id              text primary key check (id ~ '^[a-z0-9-]{1,64}$'),
  category_id     text not null references public.category (id) on update cascade on delete restrict,
  -- Localized texts: {"ru": "...", "en": "..."}; both languages are required.
  title           jsonb not null check (title ? 'ru' and title ? 'en'),
  description     jsonb not null check (description ? 'ru' and description ? 'en'),
  icon            text not null check (char_length(icon) between 1 and 16),
  -- Recommended daily target, e.g. 20 pages. Personal habits may use their own.
  target_value    integer check (target_value is null or target_value > 0),
  target_unit     text check (target_unit is null or target_unit in ('pages', 'minutes', 'steps', 'glasses', 'hours')),
  -- The app tracks habits per calendar day; other schedules are not supported yet.
  schedule        text not null default 'daily' check (schedule = 'daily'),
  -- Identifies the ranking rule; a new rule gets a new identifier instead of
  -- silently changing the meaning of existing rankings.
  scoring_policy  text not null default 'weekly_consistency_v1' check (scoring_policy = 'weekly_consistency_v1'),
  sort_order      integer not null default 0,
  -- Retired templates stay readable for their members but cannot be joined.
  is_active       boolean not null default true,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  check ((target_value is null) = (target_unit is null))
);

comment on table public.habit_template is
  'Habit catalog; one persistent community per template. Managed via migrations only: never delete a template, set is_active = false.';

create trigger habit_template_set_updated_at
  before insert or update on public.habit_template
  for each row execute function public.set_updated_at();

-- Stable ids; re-running the seed never duplicates or overwrites entries.
insert into public.habit_template (id, category_id, title, description, icon, target_value, target_unit, sort_order) values
  ('reading', 'education',
   '{"ru": "Чтение", "en": "Reading"}',
   '{"ru": "Читать каждый день, хотя бы несколько страниц.", "en": "Read every day, even just a few pages."}',
   '📚', 20, 'pages', 10),
  ('english-practice', 'education',
   '{"ru": "Практика английского", "en": "English practice"}',
   '{"ru": "Слова, аудио или разговор — ежедневная практика языка.", "en": "Words, listening or conversation — daily language practice."}',
   '🇬🇧', 15, 'minutes', 20),
  ('learning', 'education',
   '{"ru": "Учёба", "en": "Learning"}',
   '{"ru": "Курс, лекция или учебник — время на новые знания.", "en": "A course, a lecture or a textbook — time for new skills."}',
   '🎓', 30, 'minutes', 30),
  ('morning-exercise', 'sport',
   '{"ru": "Утренняя зарядка", "en": "Morning exercise"}',
   '{"ru": "Короткая разминка, чтобы проснуться и зарядиться энергией.", "en": "A short workout to wake up and get going."}',
   '🤸', 10, 'minutes', 40),
  ('running', 'sport',
   '{"ru": "Бег", "en": "Running"}',
   '{"ru": "Пробежка в комфортном темпе.", "en": "A run at a comfortable pace."}',
   '🏃', 20, 'minutes', 50),
  ('stretching', 'sport',
   '{"ru": "Растяжка", "en": "Stretching"}',
   '{"ru": "Мягкая растяжка для гибкости и спины.", "en": "Gentle stretching for flexibility and your back."}',
   '🙆', 10, 'minutes', 60),
  ('walking', 'health',
   '{"ru": "Прогулка", "en": "Walking"}',
   '{"ru": "Больше шагов в течение дня.", "en": "More steps throughout the day."}',
   '🚶', 8000, 'steps', 70),
  ('drinking-water', 'health',
   '{"ru": "Пить воду", "en": "Drinking water"}',
   '{"ru": "Достаточно воды в течение дня.", "en": "Enough water throughout the day."}',
   '💧', 8, 'glasses', 80),
  ('consistent-sleep', 'health',
   '{"ru": "Режим сна", "en": "Consistent sleep"}',
   '{"ru": "Ложиться и вставать в одно и то же время.", "en": "Go to bed and wake up at the same time."}',
   '😴', 8, 'hours', 90),
  ('no-sugar', 'health',
   '{"ru": "Без сладкого", "en": "No sugar"}',
   '{"ru": "День без сладостей и сладких напитков.", "en": "A day without sweets and sugary drinks."}',
   '🍏', null, null, 100),
  ('meditation', 'selv-development',
   '{"ru": "Медитация", "en": "Meditation"}',
   '{"ru": "Несколько минут тишины и внимания к дыханию.", "en": "A few quiet minutes focusing on your breath."}',
   '🧘', 10, 'minutes', 110),
  ('journaling', 'selv-development',
   '{"ru": "Дневник", "en": "Journaling"}',
   '{"ru": "Записать мысли и итоги дня.", "en": "Write down your thoughts and the day''s results."}',
   '✍️', 5, 'minutes', 120),
  ('drawing', 'art',
   '{"ru": "Рисование", "en": "Drawing"}',
   '{"ru": "Скетч, этюд или рисунок — каждый день.", "en": "A sketch, a study or a drawing — every day."}',
   '🎨', 15, 'minutes', 130),
  ('music-practice', 'art',
   '{"ru": "Музыкальная практика", "en": "Music practice"}',
   '{"ru": "Занятие на инструменте или вокал.", "en": "Practice an instrument or singing."}',
   '🎸', 20, 'minutes', 140),
  ('deep-work', 'work',
   '{"ru": "Фокус-сессия", "en": "Deep work"}',
   '{"ru": "Время без отвлечений на самую важную задачу.", "en": "Distraction-free time for your most important task."}',
   '💻', 60, 'minutes', 150),
  ('expense-tracking', 'money',
   '{"ru": "Учёт расходов", "en": "Expense tracking"}',
   '{"ru": "Записать траты за день.", "en": "Log the day''s expenses."}',
   '💰', null, null, 160)
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- community_membership: one row per user and community
-- ---------------------------------------------------------------------------

create table public.community_membership (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  template_id  text not null references public.habit_template (id) on update cascade on delete restrict,
  -- Optional link to one of the user's own habits; its completions count for the
  -- ranking. A deleted habit simply stops counting; the link never deletes data.
  habit_id     uuid,
  -- Calendar day the user joined, in the user's time zone; days before it are not
  -- scored. Set on insert, immutable afterwards.
  joined_on    date not null default ((now() at time zone 'utc')::date),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  -- Retries and concurrent requests cannot create a second membership.
  constraint community_membership_user_template_key unique (user_id, template_id),
  -- The linked habit must belong to the same user. Hard-deleting the habit (only via
  -- account deletion) unlinks it instead of removing the membership.
  constraint community_membership_habit_owner_fkey foreign key (habit_id, user_id)
    references public.habit (id, user_id) on delete set null (habit_id)
);

comment on table public.community_membership is
  'Community participation. Leaving deletes the row; the linked habit and its completions are never touched.';

create index community_membership_template_idx on public.community_membership (template_id);
create index community_membership_habit_idx on public.community_membership (habit_id);

create trigger community_membership_prevent_owner_change
  before update on public.community_membership
  for each row execute function public.prevent_owner_change();

create trigger community_membership_set_updated_at
  before insert or update on public.community_membership
  for each row execute function public.set_updated_at();

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
    -- Anything else (or nothing) falls back to the server's date.
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
    raise exception 'cannot link a deleted habit' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger community_membership_guard
  before insert or update on public.community_membership
  for each row execute function public.community_membership_guard();

-- ---------------------------------------------------------------------------
-- Privileges and RLS
-- ---------------------------------------------------------------------------

alter table public.habit_template enable row level security;
alter table public.community_membership enable row level security;

revoke all on table public.habit_template, public.community_membership from anon, authenticated;

grant select on table public.habit_template to authenticated;

create policy "habit_template: signed-in users can read"
  on public.habit_template for select
  to authenticated
  using (true);

-- user_id is not insertable: it always comes from auth.uid(). Only the habit link
-- can be changed afterwards.
grant select, delete on table public.community_membership to authenticated;
grant insert (template_id, habit_id, joined_on) on table public.community_membership to authenticated;
grant update (habit_id) on table public.community_membership to authenticated;

create policy "community_membership: owner can read"
  on public.community_membership for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "community_membership: owner can join"
  on public.community_membership for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "community_membership: owner can relink"
  on public.community_membership for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "community_membership: owner can leave"
  on public.community_membership for delete
  to authenticated
  using ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- join_community: idempotent join (and optional link) in one statement
-- ---------------------------------------------------------------------------

-- Runs with the caller's rights, so RLS, column grants and the guard trigger apply.
-- Repeating the call returns the existing membership; a given habit replaces the link,
-- a null habit keeps the current one.
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
-- Scoring: weekly consistency (weekly_consistency_v1)
-- ---------------------------------------------------------------------------

-- Internal; not callable by clients. For every scored member of a community:
--   week        = Monday .. p_today (the viewer's current local date)
--   start day   = latest of: week start, join day, the habit's creation day (UTC)
--   eligible    = days from start day to p_today (every day is scheduled: habits are daily)
--   completed   = distinct completed days in that range (tombstones excluded)
--   consistency = completed / eligible * 100, full precision
-- Members without a linked, existing, active habit are not scored: there is no
-- history of activation changes, so a paused habit cannot be scored fairly.
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
  -- The caller is a member but not ranked yet (no linked habit or no eligible day).
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

-- Real participant counts per community (all members, linked or not).
create or replace function public.community_member_counts()
returns table (template_id text, member_count integer)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return query
    select m.template_id, count(*)::integer
      from public.community_membership m
     group by m.template_id;
end;
$$;

revoke execute on function public.community_membership_guard() from public, anon, authenticated;
revoke execute on function public._community_scores(text, date) from public, anon, authenticated;
revoke execute on function public.join_community(text, uuid, date) from public, anon;
revoke execute on function public.community_leaderboard(text, date, integer) from public, anon;
revoke execute on function public.community_member_counts() from public, anon;
grant execute on function public.join_community(text, uuid, date) to authenticated;
grant execute on function public.community_leaderboard(text, date, integer) to authenticated;
grant execute on function public.community_member_counts() to authenticated;

-- Expanded habit catalog with recommended schedules, and the weekly community ranking
-- over the last completed week (rule weekly_consistency_v2). See docs/COMMUNITIES.md.
--
-- Nothing is deleted: templates keep their ids, memberships, habits and completions are
-- untouched. The catalog seed is an upsert, so re-running it neither duplicates nor
-- drops entries.

-- ---------------------------------------------------------------------------
-- habit_template: structured recommended schedule
-- ---------------------------------------------------------------------------

-- `schedule` was limited to 'daily'; it now holds the recommended schedule type with
-- the same parameters and rules as public.habit. A recommendation only prefills a new
-- personal habit; it never changes an existing one.
alter table public.habit_template
  drop constraint habit_template_schedule_check,
  drop constraint habit_template_scoring_policy_check;

alter table public.habit_template
  add column weekly_target smallint,
  add column schedule_days smallint,
  add constraint habit_template_schedule_type check (schedule in ('daily', 'weekly_target', 'weekdays')),
  add constraint habit_template_weekly_target_range check (weekly_target is null or weekly_target between 1 and 7),
  add constraint habit_template_schedule_days_range check (schedule_days is null or schedule_days between 1 and 127),
  add constraint habit_template_schedule_consistent check (
    (schedule = 'weekly_target') = (weekly_target is not null)
    and (schedule = 'weekdays') = (schedule_days is not null)
  ),
  -- v1: current week to date; v2: the last completed week (see community_leaderboard).
  add constraint habit_template_scoring_policy check (scoring_policy in ('weekly_consistency_v1', 'weekly_consistency_v2'));

alter table public.habit_template alter column scoring_policy set default 'weekly_consistency_v2';

comment on column public.habit_template.schedule is 'Recommended schedule type: daily, weekly_target or weekdays.';
comment on column public.habit_template.weekly_target is 'Recommended completions per week for weekly_target.';
comment on column public.habit_template.schedule_days is 'Recommended weekdays for weekdays: bit (ISO weekday - 1), Monday = 1 .. Sunday = 64.';

-- The catalog. Stable ids; existing entries are updated in place (texts, icon,
-- recommendations, order), new ones are added. is_active is left as it is, so a
-- retired template stays retired.
insert into public.habit_template
  (id, category_id, title, description, icon, target_value, target_unit, schedule, weekly_target, schedule_days, scoring_policy, sort_order)
values
  -- Learning
  ('reading', 'education',
   '{"ru": "Чтение", "en": "Reading"}',
   '{"ru": "Регулярно читать книги, хотя бы несколько страниц.", "en": "Read books regularly, even just a few pages."}',
   '📚', 20, 'pages', 'daily', null, null, 'weekly_consistency_v2', 10),
  ('english-practice', 'education',
   '{"ru": "Практика английского", "en": "English practice"}',
   '{"ru": "Слова, аудио или разговор — практика английского языка.", "en": "Words, listening or conversation — English language practice."}',
   '🇬🇧', 15, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 20),
  ('foreign-language', 'education',
   '{"ru": "Иностранный язык", "en": "Foreign language"}',
   '{"ru": "Занятия любым другим языком: грамматика, лексика, приложения.", "en": "Study any other language: grammar, vocabulary, apps."}',
   '🗣️', 20, 'minutes', 'weekly_target', 4, null, 'weekly_consistency_v2', 25),
  ('learning', 'education',
   '{"ru": "Учёба", "en": "Learning"}',
   '{"ru": "Онлайн-курс, лекция или учебник — время на новые знания.", "en": "An online course, a lecture or a textbook — time for new knowledge."}',
   '🎓', 30, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 30),
  ('programming-practice', 'education',
   '{"ru": "Программирование", "en": "Programming practice"}',
   '{"ru": "Задачи, пет-проект или новая технология — практика кода.", "en": "Exercises, a side project or a new technology — coding practice."}',
   '⌨️', 30, 'minutes', 'weekly_target', 5, null, 'weekly_consistency_v2', 35),
  ('review-material', 'education',
   '{"ru": "Повторение", "en": "Review"}',
   '{"ru": "Вернуться к пройденному: карточки, конспекты, интервальное повторение.", "en": "Go back to what you learned: flashcards, notes, spaced repetition."}',
   '🔁', 15, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 37),
  -- Fitness
  ('morning-exercise', 'sport',
   '{"ru": "Утренняя зарядка", "en": "Morning exercise"}',
   '{"ru": "Короткая разминка, чтобы проснуться и зарядиться энергией.", "en": "A short workout to wake up and get going."}',
   '🤸', 10, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 40),
  ('running', 'sport',
   '{"ru": "Бег", "en": "Running"}',
   '{"ru": "Пробежка в комфортном темпе — кардионагрузка для сердца и выносливости.", "en": "A run at a comfortable pace — cardio for your heart and endurance."}',
   '🏃', 20, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 50),
  ('strength-training', 'sport',
   '{"ru": "Силовая тренировка", "en": "Strength training"}',
   '{"ru": "Тренировка с весом или собственным телом, с отдыхом между занятиями.", "en": "Weights or bodyweight training, with rest days in between."}',
   '🏋️', 45, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 52),
  ('cycling', 'sport',
   '{"ru": "Велосипед", "en": "Cycling"}',
   '{"ru": "Поездка на велосипеде или велотренажёре.", "en": "A bike ride outdoors or on a stationary bike."}',
   '🚴', 30, 'minutes', 'weekly_target', 2, null, 'weekly_consistency_v2', 55),
  ('stretching', 'sport',
   '{"ru": "Растяжка", "en": "Stretching"}',
   '{"ru": "Мягкая растяжка для гибкости и спины.", "en": "Gentle stretching for flexibility and your back."}',
   '🙆', 10, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 60),
  ('yoga', 'sport',
   '{"ru": "Йога", "en": "Yoga"}',
   '{"ru": "Практика асан для силы, баланса и спокойствия.", "en": "A yoga session for strength, balance and calm."}',
   '🧘‍♀️', 30, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 65),
  -- Health and routine
  ('walking', 'health',
   '{"ru": "Прогулка", "en": "Walking"}',
   '{"ru": "Больше шагов в течение дня.", "en": "More steps throughout the day."}',
   '🚶', 8000, 'steps', 'daily', null, null, 'weekly_consistency_v2', 70),
  ('drinking-water', 'health',
   '{"ru": "Пить воду", "en": "Drinking water"}',
   '{"ru": "Достаточно воды в течение дня.", "en": "Enough water throughout the day."}',
   '💧', 8, 'glasses', 'daily', null, null, 'weekly_consistency_v2', 80),
  ('consistent-sleep', 'health',
   '{"ru": "Режим сна", "en": "Consistent sleep"}',
   '{"ru": "Ложиться и вставать в одно и то же время.", "en": "Go to bed and wake up at the same time."}',
   '😴', 8, 'hours', 'daily', null, null, 'weekly_consistency_v2', 90),
  ('no-sugar', 'health',
   '{"ru": "Без сладкого", "en": "No sugar"}',
   '{"ru": "День без сладостей и сладких напитков.", "en": "A day without sweets and sugary drinks."}',
   '🍏', null, null, 'daily', null, null, 'weekly_consistency_v2', 100),
  ('balanced-meals', 'health',
   '{"ru": "Сбалансированное питание", "en": "Balanced meals"}',
   '{"ru": "Овощи, белок и полноценные приёмы пищи вместо перекусов на бегу.", "en": "Vegetables, protein and proper meals instead of snacking on the go."}',
   '🥗', null, null, 'daily', null, null, 'weekly_consistency_v2', 102),
  ('time-outdoors', 'health',
   '{"ru": "Время на свежем воздухе", "en": "Time outdoors"}',
   '{"ru": "Выбраться на улицу: парк, двор, дорога пешком вместо транспорта.", "en": "Get outside: a park, a yard, walking instead of riding."}',
   '🌳', 30, 'minutes', 'weekly_target', 4, null, 'weekly_consistency_v2', 104),
  ('morning-routine', 'health',
   '{"ru": "Утренний ритуал", "en": "Morning routine"}',
   '{"ru": "Один и тот же спокойный порядок утра перед рабочим днём.", "en": "The same calm morning routine before the working day."}',
   '🌅', 20, 'minutes', 'weekdays', null, 31, 'weekly_consistency_v2', 106),
  -- Mental well-being and personal organization
  ('meditation', 'selv-development',
   '{"ru": "Медитация", "en": "Meditation"}',
   '{"ru": "Несколько минут тишины и внимания к дыханию.", "en": "A few quiet minutes focusing on your breath."}',
   '🧘', 10, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 110),
  ('journaling', 'selv-development',
   '{"ru": "Дневник", "en": "Journaling"}',
   '{"ru": "Записать мысли и итоги дня.", "en": "Write down your thoughts and the day''s results."}',
   '✍️', 5, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 120),
  ('breathing-practice', 'selv-development',
   '{"ru": "Дыхательные упражнения", "en": "Breathing exercises"}',
   '{"ru": "Короткая дыхательная практика, чтобы снять напряжение.", "en": "A short breathing practice to release tension."}',
   '🌬️', 5, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 122),
  ('screen-free-time', 'selv-development',
   '{"ru": "Время без экранов", "en": "Screen-free time"}',
   '{"ru": "Отложить телефон и ноутбук: прогулка, книга, общение вживую.", "en": "Put away the phone and laptop: a walk, a book, time with people."}',
   '📵', 60, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 124),
  ('tidy-home', 'selv-development',
   '{"ru": "Порядок дома", "en": "Tidy home"}',
   '{"ru": "Короткая уборка, чтобы дома было спокойно и чисто.", "en": "A short tidy-up for a calm, clean home."}',
   '🧹', 15, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 126),
  ('prepare-tomorrow', 'selv-development',
   '{"ru": "Подготовка к завтра", "en": "Prepare for tomorrow"}',
   '{"ru": "Вечером собрать вещи и наметить план на следующий день.", "en": "In the evening, pack your things and sketch tomorrow''s plan."}',
   '🎒', 10, 'minutes', 'weekdays', null, 79, 'weekly_consistency_v2', 128),
  ('declutter', 'selv-development',
   '{"ru": "Расхламление", "en": "Declutter"}',
   '{"ru": "Разобрать одну полку или ящик и избавиться от лишнего.", "en": "Sort out one shelf or drawer and let go of what you do not need."}',
   '📦', 15, 'minutes', 'weekly_target', 1, null, 'weekly_consistency_v2', 129),
  -- Creativity
  ('drawing', 'art',
   '{"ru": "Рисование", "en": "Drawing"}',
   '{"ru": "Скетч, этюд или рисунок.", "en": "A sketch, a study or a drawing."}',
   '🎨', 15, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 130),
  ('music-practice', 'art',
   '{"ru": "Музыкальная практика", "en": "Music practice"}',
   '{"ru": "Занятие на инструменте или вокал.", "en": "Practice an instrument or singing."}',
   '🎸', 20, 'minutes', 'daily', null, null, 'weekly_consistency_v2', 140),
  ('writing', 'art',
   '{"ru": "Письмо", "en": "Writing"}',
   '{"ru": "Рассказ, статья, стихи или черновик — время на свой текст.", "en": "A story, an article, poems or a draft — time for your own writing."}',
   '📝', 20, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 142),
  ('photography', 'art',
   '{"ru": "Фотография", "en": "Photography"}',
   '{"ru": "Снимать, разбирать кадры или осваивать обработку.", "en": "Shoot, review your photos or learn editing."}',
   '📷', 30, 'minutes', 'weekly_target', 2, null, 'weekly_consistency_v2', 144),
  ('personal-project', 'art',
   '{"ru": "Личный проект", "en": "Personal project"}',
   '{"ru": "Шаг вперёд в собственном проекте: хобби, мастерская, идея.", "en": "A step forward in your own project: a hobby, a craft, an idea."}',
   '🛠️', 60, 'minutes', 'weekly_target', 2, null, 'weekly_consistency_v2', 146),
  -- Productivity
  ('deep-work', 'work',
   '{"ru": "Фокус-сессия", "en": "Deep work"}',
   '{"ru": "Время без отвлечений на самую важную задачу.", "en": "Distraction-free time for your most important task."}',
   '💻', 60, 'minutes', 'weekdays', null, 31, 'weekly_consistency_v2', 150),
  ('daily-priorities', 'work',
   '{"ru": "Приоритеты дня", "en": "Daily priorities"}',
   '{"ru": "С утра выбрать две-три главные задачи на день.", "en": "Pick the two or three tasks that matter most today."}',
   '🎯', 5, 'minutes', 'weekdays', null, 31, 'weekly_consistency_v2', 152),
  ('professional-skill', 'work',
   '{"ru": "Профессиональный навык", "en": "Professional skill"}',
   '{"ru": "Прокачать навык для работы: статья, курс, практика.", "en": "Grow a skill for work: an article, a course, practice."}',
   '📈', 30, 'minutes', 'weekly_target', 3, null, 'weekly_consistency_v2', 154),
  ('plan-week', 'work',
   '{"ru": "План на неделю", "en": "Plan the week"}',
   '{"ru": "Расписать цели и встречи на неделю вперёд.", "en": "Lay out goals and appointments for the week ahead."}',
   '🗓️', 15, 'minutes', 'weekly_target', 1, null, 'weekly_consistency_v2', 156),
  ('weekly-review', 'work',
   '{"ru": "Итоги недели", "en": "Weekly review"}',
   '{"ru": "Оглянуться на неделю: что получилось и что поменять.", "en": "Look back at the week: what worked and what to change."}',
   '📊', 20, 'minutes', 'weekdays', null, 16, 'weekly_consistency_v2', 157),
  ('workspace-tidy', 'work',
   '{"ru": "Порядок на рабочем месте", "en": "Tidy workspace"}',
   '{"ru": "Разобрать стол, файлы и рабочий стол компьютера.", "en": "Clear your desk, files and computer desktop."}',
   '🗂️', 10, 'minutes', 'weekly_target', 2, null, 'weekly_consistency_v2', 158),
  -- Finances
  ('expense-tracking', 'money',
   '{"ru": "Учёт расходов", "en": "Expense tracking"}',
   '{"ru": "Записать траты за день.", "en": "Log the day''s expenses."}',
   '💰', null, null, 'daily', null, null, 'weekly_consistency_v2', 160),
  ('finance-review', 'money',
   '{"ru": "Обзор финансов", "en": "Finance review"}',
   '{"ru": "Проверить бюджет, счета и накопления.", "en": "Check your budget, accounts and savings."}',
   '💳', 20, 'minutes', 'weekdays', null, 64, 'weekly_consistency_v2', 162)
on conflict (id) do update set
  category_id    = excluded.category_id,
  title          = excluded.title,
  description    = excluded.description,
  icon           = excluded.icon,
  target_value   = excluded.target_value,
  target_unit    = excluded.target_unit,
  schedule       = excluded.schedule,
  weekly_target  = excluded.weekly_target,
  schedule_days  = excluded.schedule_days,
  scoring_policy = excluded.scoring_policy,
  sort_order     = excluded.sort_order;

-- ---------------------------------------------------------------------------
-- habit_schedule_version: what a habit asked for, and when
-- ---------------------------------------------------------------------------

-- A finished week is scored with the schedule (and paused state) that was in effect
-- at its end, so a later change never rewrites an already finished result. Rows are
-- written only by the trigger below; clients can neither read nor write them.
create table public.habit_schedule_version (
  id             bigint generated always as identity primary key,
  habit_id       uuid not null,
  user_id        uuid not null,
  -- The habit's creation time for the first version; the server time of the change
  -- for later ones (client clocks are not trusted).
  valid_from     timestamptz not null,
  schedule_type  text not null,
  weekly_target  smallint,
  schedule_days  smallint,
  is_active      boolean not null,
  constraint habit_schedule_version_habit_fkey foreign key (habit_id, user_id)
    references public.habit (id, user_id) on delete cascade
);

create index habit_schedule_version_habit_idx on public.habit_schedule_version (habit_id, valid_from desc, id desc);

alter table public.habit_schedule_version enable row level security;
revoke all on table public.habit_schedule_version from anon, authenticated;

comment on table public.habit_schedule_version is
  'History of a habit''s schedule and paused state, for scoring finished weeks. Written by trigger only.';

create or replace function public.record_habit_schedule_version()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if tg_op = 'UPDATE'
     and new.schedule_type is not distinct from old.schedule_type
     and new.weekly_target is not distinct from old.weekly_target
     and new.schedule_days is not distinct from old.schedule_days
     and new.is_active is not distinct from old.is_active then
    return new;
  end if;
  insert into public.habit_schedule_version
    (habit_id, user_id, valid_from, schedule_type, weekly_target, schedule_days, is_active)
  values
    (new.id, new.user_id, case when tg_op = 'INSERT' then least(new.created_at, clock_timestamp()) else clock_timestamp() end,
     new.schedule_type, new.weekly_target, new.schedule_days, new.is_active);
  return new;
end;
$$;

revoke execute on function public.record_habit_schedule_version() from public, anon, authenticated;

create trigger habit_record_schedule_version
  after insert or update of schedule_type, weekly_target, schedule_days, is_active on public.habit
  for each row execute function public.record_habit_schedule_version();

-- Existing habits: their current state, valid since creation (there is no earlier
-- history to recover).
insert into public.habit_schedule_version (habit_id, user_id, valid_from, schedule_type, weekly_target, schedule_days, is_active)
select h.id, h.user_id, h.created_at, h.schedule_type, h.weekly_target, h.schedule_days, h.is_active
  from public.habit h
 where not exists (select 1 from public.habit_schedule_version v where v.habit_id = h.id);

-- ---------------------------------------------------------------------------
-- Scoring helpers (internal; not callable by clients)
-- ---------------------------------------------------------------------------

-- Scheduled and completed actions of one habit over p_start .. p_today, a range within
-- one Monday–Sunday week:
--   daily          every day is one action
--   weekdays       only the selected days are actions
--   weekly_target  the target, prorated when the range starts after Monday:
--                  ceil(target × days from p_start to Sunday / 7); marks beyond it do
--                  not count
-- Nothing is expected when p_start is after p_today. Distinct days only; tombstones
-- excluded, so a reverted completion does not count.
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
  with bounds as (
    select p_today + (7 - extract(isodow from p_today)::integer) as week_end
  ),
  scheduled as (
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
  ),
  expected as (
    select case
             when p_start > p_today then 0
             when p_type = 'weekly_target'
               then ceil(p_target * ((select week_end from bounds) - p_start + 1) / 7.0)::integer
             else (select count(*)::integer from scheduled)
           end as n
  )
  select least((select n from done), (select n from expected)),
         (select n from expected);
$$;

-- The version of a habit in effect at p_at; null if the habit did not exist yet.
create or replace function public._habit_version_at(p_habit_id uuid, p_at timestamptz)
returns public.habit_schedule_version
language sql
stable
set search_path = ''
as $$
  select v.*
    from public.habit_schedule_version v
   where v.habit_id = p_habit_id and v.valid_from < p_at
   order by v.valid_from desc, v.id desc
   limit 1;
$$;

-- One member's result for the finished week starting p_week_start (a Monday).
-- Eligible days run from the latest of week start, join day and the habit's creation
-- day (UTC) to Sunday. The schedule is the one in effect at the end of that Sunday
-- (UTC). status: 'scored', or why the member is not scored.
create or replace function public._member_week(
  p_habit_id   uuid,
  p_joined_on  date,
  p_created_on date,
  p_week_start date
)
returns table (completed_actions integer, expected_actions integer, status text)
language plpgsql
stable
set search_path = ''
as $$
declare
  week_end constant date := p_week_start + 6;
  start_day constant date := greatest(p_week_start, p_joined_on, p_created_on);
  version public.habit_schedule_version;
  counts record;
begin
  if start_day > week_end then
    return query select 0, 0, 'joined_recently'::text;
    return;
  end if;
  version := public._habit_version_at(p_habit_id, (p_week_start + 7)::timestamp at time zone 'utc');
  if version.id is null then
    return query select 0, 0, 'joined_recently'::text;
    return;
  end if;
  if not version.is_active then
    return query select 0, 0, 'paused'::text;
    return;
  end if;
  select * into counts
    from public._habit_period_counts(p_habit_id, version.schedule_type, version.weekly_target,
                                     version.schedule_days, start_day, week_end);
  return query select counts.completed_days, counts.eligible_days,
                      case when counts.eligible_days > 0 then 'scored' else 'no_scheduled_actions' end;
end;
$$;

-- Consecutive successful finished weeks (every expected action done) ending with the
-- week starting p_week_start, counted within the membership. At most two years back.
create or replace function public._member_success_weeks(
  p_habit_id   uuid,
  p_joined_on  date,
  p_created_on date,
  p_week_start date
)
returns integer
language plpgsql
stable
set search_path = ''
as $$
declare
  first_day constant date := greatest(p_joined_on, p_created_on);
  week_start date := p_week_start;
  result integer := 0;
  week record;
begin
  for i in 1..104 loop
    exit when week_start + 6 < first_day;
    select * into week from public._member_week(p_habit_id, p_joined_on, p_created_on, week_start);
    exit when week.status <> 'scored' or week.completed_actions < week.expected_actions;
    result := result + 1;
    week_start := week_start - 7;
  end loop;
  return result;
end;
$$;

-- Results of every current member of a community for the finished week starting
-- p_week_start. Members without a ranked habit, or whose ranked habit was deleted,
-- get status 'no_habit'. Former members are not included: leaving removes the
-- membership, and with it any visibility of their results.
create or replace function public._community_week_scores(p_template_id text, p_week_start date)
returns table (
  user_id           uuid,
  completed_actions integer,
  expected_actions  integer,
  consistency       numeric,
  success_weeks     integer,
  status            text
)
language sql
stable
set search_path = ''
as $$
  select m.user_id,
         coalesce(w.completed_actions, 0),
         coalesce(w.expected_actions, 0),
         case when w.status = 'scored' then w.completed_actions::numeric * 100 / w.expected_actions end,
         case when w.status = 'scored'
              then public._member_success_weeks(h.id, m.joined_on, (h.created_at at time zone 'utc')::date, p_week_start)
              else 0 end,
         coalesce(w.status, 'no_habit')
    from public.community_membership m
    left join public.habit h on h.id = m.habit_id and h.user_id = m.user_id and h.deleted_at is null
    left join lateral public._member_week(h.id, m.joined_on, (h.created_at at time zone 'utc')::date, p_week_start) w
           on h.id is not null
   where m.template_id = p_template_id;
$$;

-- The current-week scorer is replaced by the finished-week one above.
drop function if exists public._community_scores(text, date);

revoke execute on function
  public._habit_period_counts(uuid, text, integer, integer, date, date),
  public._habit_version_at(uuid, timestamptz),
  public._member_week(uuid, date, date, date),
  public._member_success_weeks(uuid, date, date, date),
  public._community_week_scores(text, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- community_leaderboard: the last finished week (weekly_consistency_v2)
-- ---------------------------------------------------------------------------

drop function if exists public.community_leaderboard(text, date, integer);

-- Ranked members for the last finished Monday–Sunday week before p_today (the
-- caller's local date): the top p_limit plus the caller's own row. Order: consistency,
-- completed actions, consecutive successful weeks (all descending), then a stable
-- internal order. Members are shown by nickname and avatar only if their
-- stats_visibility allows it for the caller. Never exposes user ids, emails or habits.
create function public.community_leaderboard(p_template_id text, p_today date, p_limit integer default 20)
returns table (
  rank              integer,
  display_name      text,
  is_me             boolean,
  completed_actions integer,
  expected_actions  integer,
  consistency       numeric,
  ranked_count      integer,
  public_id         uuid,
  avatar            text,
  success_weeks     integer,
  week_start        date,
  status            text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller     constant uuid := public._caller();
  row_limit  constant integer := least(greatest(coalesce(p_limit, 20), 1), 100);
  last_week  date;
begin
  perform public._check_today(p_today);
  if not exists (select 1 from public.habit_template t where t.id = p_template_id) then
    raise exception 'unknown community %', p_template_id using errcode = 'P0002';
  end if;
  last_week := p_today - (extract(isodow from p_today)::integer - 1) - 7;

  return query
  with scores as (
    select * from public._community_week_scores(p_template_id, last_week)
  ),
  ranked as (
    select s.*,
           (row_number() over (
              order by s.consistency desc, s.completed_actions desc, s.success_weeks desc, s.user_id
           ))::integer as position,
           (count(*) over ())::integer as total
      from scores s
     where s.status = 'scored'
  )
  select r.position,
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.nickname end,
         r.user_id = caller,
         r.completed_actions,
         r.expected_actions,
         r.consistency,
         r.total,
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.public_id end,
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.avatar end,
         r.success_weeks,
         last_week,
         r.status
    from ranked r
    left join public.profile p on p.id = r.user_id
   where r.position <= row_limit or r.user_id = caller
  union all
  -- The caller is a member but not ranked for that week, with the reason.
  select null::integer, null::text, true, s.completed_actions, s.expected_actions, null::numeric,
         (select count(*)::integer from ranked), null::uuid, null::text, 0, last_week, s.status
    from scores s
   where s.user_id = caller and s.status <> 'scored'
   order by 1 nulls last;
end;
$$;

revoke execute on function public.community_leaderboard(text, date, integer) from public, anon;
grant execute on function public.community_leaderboard(text, date, integer) to authenticated;

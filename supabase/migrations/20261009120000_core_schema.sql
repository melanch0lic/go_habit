-- GoHabit core schema.
--
-- Ownership model: every user-owned row carries `user_id` referencing auth.users.
-- Sync model: rows are never hard-deleted by clients; `deleted_at` is a tombstone that
-- propagates deletions to other devices. `updated_at` is assigned by the server and
-- serves as the incremental pull cursor (see docs/SYNC.md).

-- ---------------------------------------------------------------------------
-- Helper trigger functions
-- ---------------------------------------------------------------------------

-- Server-assigned modification time. clock_timestamp() (not now()) so that rows written
-- late in a long transaction do not get a timestamp older than rows already pulled.
create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := clock_timestamp();
  if tg_op = 'UPDATE' then
    -- Identity and provenance columns are immutable.
    if new.id is distinct from old.id then
      raise exception 'id is immutable' using errcode = '42501';
    end if;
    new.created_at := old.created_at;
  end if;
  return new;
end;
$$;

-- Prevents moving a row to another owner, regardless of the caller's role.
create or replace function public.prevent_owner_change()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'user_id is immutable' using errcode = '42501';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- category: global, read-only reference data
-- ---------------------------------------------------------------------------

create table public.category (
  id          text primary key check (id ~ '^[a-z0-9-]{1,64}$'),
  name        text not null check (char_length(btrim(name)) between 1 and 100),
  color       text not null check (color ~ '^#[0-9A-Fa-f]{6}$'),
  sort_order  integer not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on table public.category is 'Habit categories. Reference data shared by all users; managed via migrations only.';

create trigger category_set_updated_at
  before insert or update on public.category
  for each row execute function public.set_updated_at();

-- The ids must match the ids the app ships with (including the historical
-- "selv-development" spelling) so that existing local data stays valid.
insert into public.category (id, name, color, sort_order) values
  ('health',           'Здоровье',     '#FF6B6B', 10),
  ('sport',            'Спорт',        '#4ECDC4', 20),
  ('education',        'Обучение',     '#FB8C00', 30),
  ('selv-development', 'Саморазвитие', '#FDD835', 40),
  ('art',              'Творчество',   '#8E24AA', 50),
  ('work',             'Работа',       '#556270', 60),
  ('money',            'Финансы',      '#00ACC1', 70);

-- ---------------------------------------------------------------------------
-- profile: one row per auth user, created automatically
-- ---------------------------------------------------------------------------

create table public.profile (
  id            uuid primary key references auth.users (id) on delete cascade,
  display_name  text check (display_name is null or char_length(display_name) <= 100),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

comment on table public.profile is 'Application profile for an auth user. Created by trigger on auth.users insert.';

create trigger profile_set_updated_at
  before insert or update on public.profile
  for each row execute function public.set_updated_at();

-- Runs as the table owner so it can write into public.profile while being invoked
-- from the auth schema. search_path is pinned to avoid hijacking.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profile (id) values (new.id) on conflict (id) do nothing;
  return new;
end;
$$;

revoke execute on function public.handle_new_user() from public, anon, authenticated;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- habit: habit definition owned by a user
-- ---------------------------------------------------------------------------

create table public.habit (
  -- Generated on the client (UUIDv4) so records can be created offline.
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users (id) on delete cascade,
  category_id  text not null references public.category (id) on update cascade on delete restrict,
  title        text not null check (char_length(btrim(title)) between 1 and 200),
  description  text check (description is null or char_length(description) <= 2000),
  icon         text not null default '🎯' check (char_length(icon) between 1 and 16),
  steps        integer not null default 0 check (steps >= 0),
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,
  -- Target of the composite FK from habit_completion (enforces same-owner relations).
  unique (id, user_id)
);

comment on column public.habit.deleted_at is 'Tombstone. Once set it cannot be cleared (delete wins over concurrent edits).';

create index habit_user_updated_idx on public.habit (user_id, updated_at);
create index habit_category_idx on public.habit (category_id);

-- Delete wins: a tombstoned habit cannot be resurrected by a stale offline edit.
create or replace function public.habit_keep_tombstone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.deleted_at is not null then
    new.deleted_at := old.deleted_at;
  end if;
  return new;
end;
$$;

create trigger habit_prevent_owner_change
  before update on public.habit
  for each row execute function public.prevent_owner_change();

create trigger habit_keep_tombstone
  before update on public.habit
  for each row execute function public.habit_keep_tombstone();

create trigger habit_set_updated_at
  before insert or update on public.habit
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- habit_completion: one row per habit per calendar day
-- ---------------------------------------------------------------------------

create table public.habit_completion (
  -- The client derives the id deterministically (UUIDv5 of habit id + day), so every
  -- device produces the same id for the same logical completion.
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null default auth.uid() references auth.users (id) on delete cascade,
  habit_id      uuid not null,
  -- Calendar day in the user's local time zone at the moment of completion.
  completed_on  date not null check (completed_on >= date '2000-01-01'),
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- Set when the user un-marks the day; cleared again if the day is re-completed.
  deleted_at    timestamptz,
  -- Idempotency: retries and concurrent devices cannot create duplicates.
  constraint habit_completion_habit_day_key unique (habit_id, completed_on),
  -- A completion can only reference a habit of the same owner.
  constraint habit_completion_habit_owner_fkey foreign key (habit_id, user_id)
    references public.habit (id, user_id) on delete cascade
);

create index habit_completion_user_updated_idx on public.habit_completion (user_id, updated_at);

create trigger habit_completion_prevent_owner_change
  before update on public.habit_completion
  for each row execute function public.prevent_owner_change();

create trigger habit_completion_set_updated_at
  before insert or update on public.habit_completion
  for each row execute function public.set_updated_at();

-- ---------------------------------------------------------------------------
-- Tombstone cascade: deleting a habit tombstones its completions, so other devices
-- receive the deletions through the normal incremental pull.
-- ---------------------------------------------------------------------------

create or replace function public.habit_cascade_tombstone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  update public.habit_completion
     set deleted_at = new.deleted_at
   where habit_id = new.id
     and deleted_at is null;
  return null;
end;
$$;

create trigger habit_cascade_tombstone
  after update of deleted_at on public.habit
  for each row
  when (old.deleted_at is null and new.deleted_at is not null)
  execute function public.habit_cascade_tombstone();

-- A completion written for an already deleted habit (e.g. by a device that was
-- offline) is stored as a tombstone instead of resurrecting data.
create or replace function public.habit_completion_follow_habit_tombstone()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.deleted_at is null and exists (
    select 1 from public.habit h where h.id = new.habit_id and h.deleted_at is not null
  ) then
    new.deleted_at := clock_timestamp();
  end if;
  return new;
end;
$$;

create trigger habit_completion_follow_habit_tombstone
  before insert or update on public.habit_completion
  for each row execute function public.habit_completion_follow_habit_tombstone();

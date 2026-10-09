-- Privileges and Row Level Security.
--
-- Principle: table privileges define *which operations* a role may attempt at all;
-- RLS policies define *which rows*. Both are explicit. The anon key is only a
-- client identifier, so `anon` gets read access to reference data and nothing else.
--
-- Clients never hard-delete: deletions are tombstones (`deleted_at`) so they can be
-- synchronised. DELETE is therefore not granted to `authenticated` on synced tables;
-- rows disappear only through `on delete cascade` when the auth user is removed.

alter table public.category         enable row level security;
alter table public.profile          enable row level security;
alter table public.habit            enable row level security;
alter table public.habit_completion enable row level security;

-- Reset Supabase's broad default grants to a known minimum.
revoke all on table public.category, public.profile, public.habit, public.habit_completion
  from anon, authenticated;

-- ---------------------------------------------------------------------------
-- category: readable by everyone, writable by nobody (migrations only)
-- ---------------------------------------------------------------------------

grant select on table public.category to anon, authenticated;

create policy "category: anyone can read"
  on public.category for select
  to anon, authenticated
  using (true);

-- ---------------------------------------------------------------------------
-- profile: owner can read and update; row is created by trigger
-- ---------------------------------------------------------------------------

grant select on table public.profile to authenticated;
grant update (display_name) on table public.profile to authenticated;

create policy "profile: owner can read"
  on public.profile for select
  to authenticated
  using ((select auth.uid()) = id);

create policy "profile: owner can update"
  on public.profile for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- ---------------------------------------------------------------------------
-- habit
-- ---------------------------------------------------------------------------

grant select, insert, update on table public.habit to authenticated;

create policy "habit: owner can read"
  on public.habit for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "habit: owner can insert"
  on public.habit for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "habit: owner can update"
  on public.habit for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- habit_completion
-- ---------------------------------------------------------------------------

grant select, insert, update on table public.habit_completion to authenticated;

create policy "habit_completion: owner can read"
  on public.habit_completion for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- The composite FK (habit_id, user_id) -> habit(id, user_id) additionally guarantees
-- that the referenced habit belongs to the same user.
create policy "habit_completion: owner can insert"
  on public.habit_completion for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "habit_completion: owner can update"
  on public.habit_completion for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------------------------
-- Functions: only triggers use them; nobody needs to call them directly.
-- ---------------------------------------------------------------------------

revoke execute on function public.set_updated_at()       from public, anon, authenticated;
revoke execute on function public.prevent_owner_change() from public, anon, authenticated;
revoke execute on function public.habit_keep_tombstone() from public, anon, authenticated;
revoke execute on function public.habit_cascade_tombstone() from public, anon, authenticated;
revoke execute on function public.habit_completion_follow_habit_tombstone() from public, anon, authenticated;

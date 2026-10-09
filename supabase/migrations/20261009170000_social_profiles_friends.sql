-- Social layer: public profiles with unique nicknames, friends, blocking, privacy and
-- a friends ranking. See docs/SOCIAL.md.
--
-- Identity stays the auth user id. Other users only ever see `profile.public_id`, an
-- opaque random handle, never auth ids or emails. Relationship tables are not readable
-- by clients at all: every read and write goes through the functions below, which
-- validate the caller and return only approved public fields.

-- ---------------------------------------------------------------------------
-- profile: public fields and privacy settings
-- ---------------------------------------------------------------------------

alter table public.profile
  add column nickname text,
  add column bio text,
  add column avatar text,
  add column public_id uuid not null default gen_random_uuid(),
  -- Who sees the profile statistics, and the user's name in community rankings.
  add column stats_visibility text not null default 'friends',
  -- Who sees which communities the user belongs to.
  add column communities_visibility text not null default 'friends';

alter table public.profile
  -- Starts with a letter; letters, digits and underscores; 3–20 characters.
  add constraint profile_nickname_format check (
    nickname is null or (
      nickname ~ '^[A-Za-z][A-Za-z0-9_]{2,19}$'
      and lower(nickname) not in ('admin', 'administrator', 'moderator', 'support', 'system', 'gohabit', 'go_habit')
    )
  ),
  add constraint profile_bio_length check (bio is null or char_length(bio) <= 160),
  -- A preset key known to the app; null means the generated default avatar.
  add constraint profile_avatar_format check (avatar is null or avatar ~ '^[a-z]{1,16}$'),
  add constraint profile_stats_visibility check (stats_visibility in ('everyone', 'friends', 'nobody')),
  add constraint profile_communities_visibility check (communities_visibility in ('everyone', 'friends', 'nobody')),
  add constraint profile_public_id_key unique (public_id);

-- Case-insensitive uniqueness; concurrent claims of one nickname fail with 23505.
create unique index profile_nickname_key on public.profile (lower(nickname));

comment on column public.profile.public_id is 'Opaque public handle shown to other users instead of the auth id.';

-- The owner edits their own public fields (RLS: own row only). public_id is immutable.
grant update (nickname, bio, avatar, stats_visibility, communities_visibility) on table public.profile to authenticated;

create or replace function public.profile_keep_public_id()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.public_id := old.public_id;
  return new;
end;
$$;

revoke execute on function public.profile_keep_public_id() from public, anon, authenticated;

create trigger profile_keep_public_id
  before update on public.profile
  for each row execute function public.profile_keep_public_id();

-- ---------------------------------------------------------------------------
-- friendship: one row per unordered pair
-- ---------------------------------------------------------------------------

-- A pending row is a request from requester_id; an accepted row is a friendship.
-- Rejecting, cancelling, removing and blocking delete the row, so the pair can start
-- over later. The normalized pair (user_low < user_high) is the primary key: there can
-- never be two rows, or a request and a reversed request, for the same two users.
create table public.friendship (
  user_low      uuid not null references auth.users (id) on delete cascade,
  user_high     uuid not null references auth.users (id) on delete cascade,
  requester_id  uuid not null,
  status        text not null default 'pending' check (status in ('pending', 'accepted')),
  created_at    timestamptz not null default now(),
  responded_at  timestamptz,
  primary key (user_low, user_high),
  check (user_low < user_high),
  check (requester_id in (user_low, user_high)),
  check ((status = 'accepted') = (responded_at is not null))
);

create index friendship_user_high_idx on public.friendship (user_high);

-- ---------------------------------------------------------------------------
-- user_block
-- ---------------------------------------------------------------------------

-- Blocking removes any friendship or pending request between the two users and
-- prevents new ones in either direction. The blocked user is never told: to them the
-- blocker looks like a user that does not exist.
create table public.user_block (
  blocker_id  uuid not null references auth.users (id) on delete cascade,
  blocked_id  uuid not null references auth.users (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);

create index user_block_blocked_idx on public.user_block (blocked_id);

-- No client access: the tables hold auth ids of other users.
alter table public.friendship enable row level security;
alter table public.user_block enable row level security;
revoke all on table public.friendship, public.user_block from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Internal helpers (not callable by clients)
-- ---------------------------------------------------------------------------

create or replace function public._are_friends(p_a uuid, p_b uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (
    select 1 from public.friendship f
     where f.user_low = least(p_a, p_b) and f.user_high = greatest(p_a, p_b) and f.status = 'accepted'
  );
$$;

create or replace function public._has_blocked(p_blocker uuid, p_blocked uuid)
returns boolean
language sql
stable
set search_path = ''
as $$
  select exists (select 1 from public.user_block b where b.blocker_id = p_blocker and b.blocked_id = p_blocked);
$$;

-- Whether p_viewer may see data of p_owner protected by p_visibility.
create or replace function public._can_see(p_viewer uuid, p_owner uuid, p_visibility text)
returns boolean
language sql
stable
set search_path = ''
as $$
  select p_viewer = p_owner
      or (not public._has_blocked(p_owner, p_viewer) and not public._has_blocked(p_viewer, p_owner)
          and (p_visibility = 'everyone' or (p_visibility = 'friends' and public._are_friends(p_viewer, p_owner))));
$$;

-- The relationship as seen by p_viewer.
create or replace function public._relationship(p_viewer uuid, p_other uuid)
returns text
language sql
stable
set search_path = ''
as $$
  select case
    when p_viewer = p_other then 'self'
    when public._has_blocked(p_viewer, p_other) then 'blocked'
    else coalesce((
      select case
               when f.status = 'accepted' then 'friends'
               when f.requester_id = p_viewer then 'outgoing'
               else 'incoming'
             end
        from public.friendship f
       where f.user_low = least(p_viewer, p_other) and f.user_high = greatest(p_viewer, p_other)
    ), 'none')
  end;
$$;

-- The caller, or 42501.
create or replace function public._caller()
returns uuid
language plpgsql
stable
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;
  return auth.uid();
end;
$$;

-- Resolves a public handle for p_viewer. Users who blocked the viewer look like they
-- do not exist (P0002), exactly like unknown handles.
create or replace function public._resolve_public_id(p_viewer uuid, p_public_id uuid)
returns uuid
language plpgsql
stable
set search_path = ''
as $$
declare
  target uuid;
begin
  select p.id into target from public.profile p where p.public_id = p_public_id;
  if target is null or public._has_blocked(target, p_viewer) then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  return target;
end;
$$;

-- The client's local date may be at most one day from the UTC date.
create or replace function public._check_today(p_today date)
returns void
language plpgsql
stable
set search_path = ''
as $$
declare
  utc_today constant date := (now() at time zone 'utc')::date;
begin
  if p_today is null or p_today not between utc_today - 1 and utc_today + 1 then
    raise exception 'p_today must be the current local date' using errcode = '22023';
  end if;
end;
$$;

-- Weekly consistency over all of a user's active habits (rule weekly_consistency_v1,
-- the same as the community ranking): per habit, days from max(week start, creation
-- day) to p_today are eligible; completed days are distinct marked days in that range.
create or replace function public._weekly_totals(p_user uuid, p_today date)
returns table (completed_days integer, eligible_days integer)
language sql
stable
set search_path = ''
as $$
  select coalesce(sum(x.completed), 0)::integer, coalesce(sum(x.eligible), 0)::integer
    from (
      select (select count(distinct c.completed_on)
                from public.habit_completion c
               where c.habit_id = h.id
                 and c.deleted_at is null
                 and c.completed_on between s.start_day and p_today) as completed,
             greatest(0, p_today - s.start_day + 1) as eligible
        from public.habit h
        cross join lateral (
          select greatest(p_today - (extract(isodow from p_today)::integer - 1),
                          (h.created_at at time zone 'utc')::date) as start_day
        ) s
       where h.user_id = p_user and h.deleted_at is null and h.is_active
    ) x;
$$;

revoke execute on function
  public._are_friends(uuid, uuid), public._has_blocked(uuid, uuid), public._can_see(uuid, uuid, text),
  public._relationship(uuid, uuid), public._caller(), public._resolve_public_id(uuid, uuid),
  public._check_today(date), public._weekly_totals(uuid, date)
  from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- Profile and search
-- ---------------------------------------------------------------------------

-- 'available', 'taken' or 'invalid'. The unique index is the real guarantee; this is
-- for feedback while typing.
create or replace function public.nickname_status(p_nickname text)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  candidate constant text := btrim(coalesce(p_nickname, ''));
begin
  if candidate !~ '^[A-Za-z][A-Za-z0-9_]{2,19}$'
     or lower(candidate) in ('admin', 'administrator', 'moderator', 'support', 'system', 'gohabit', 'go_habit') then
    return 'invalid';
  end if;
  if exists (select 1 from public.profile p where lower(p.nickname) = lower(candidate) and p.id <> caller) then
    return 'taken';
  end if;
  return 'available';
end;
$$;

-- Exact, case-insensitive nickname search. Returns at most one row with the minimum
-- public fields and the caller's relationship to that user.
create or replace function public.search_profiles(p_nickname text)
returns table (public_id uuid, nickname text, avatar text, relationship text)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller constant uuid := public._caller();
begin
  return query
    select p.public_id, p.nickname, p.avatar, public._relationship(caller, p.id)
      from public.profile p
     where p.nickname is not null
       and lower(p.nickname) = lower(btrim(coalesce(p_nickname, '')))
       and not public._has_blocked(p.id, caller);
end;
$$;

-- Another user's public profile (or the caller's own). Statistics and communities are
-- returned only if the owner's privacy settings allow it for the caller.
create or replace function public.get_public_profile(p_public_id uuid, p_today date)
returns table (
  public_id           uuid,
  nickname            text,
  avatar              text,
  bio                 text,
  relationship        text,
  stats_visible       boolean,
  active_habits       integer,
  week_completed_days integer,
  week_eligible_days  integer,
  friends_count       integer,
  communities_visible boolean,
  communities         text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller constant uuid := public._caller();
  target uuid;
  owner public.profile;
  relation text;
  show_stats boolean;
  show_communities boolean;
  week_completed integer;
  week_eligible integer;
begin
  perform public._check_today(p_today);
  target := public._resolve_public_id(caller, p_public_id);
  select * into owner from public.profile p where p.id = target;
  relation := public._relationship(caller, target);
  show_stats := public._can_see(caller, target, owner.stats_visibility);
  show_communities := public._can_see(caller, target, owner.communities_visibility);
  if show_stats then
    select t.completed_days, t.eligible_days into week_completed, week_eligible
      from public._weekly_totals(target, p_today) t;
  end if;

  return query select
    owner.public_id,
    owner.nickname,
    owner.avatar,
    owner.bio,
    relation,
    show_stats,
    case when show_stats then
      (select count(*)::integer from public.habit h where h.user_id = target and h.deleted_at is null and h.is_active)
    end,
    week_completed,
    week_eligible,
    case when show_stats then
      (select count(*)::integer from public.friendship f
        where f.status = 'accepted' and target in (f.user_low, f.user_high))
    end,
    show_communities,
    case when show_communities then
      -- Own profile: all communities; otherwise only the ones both users share.
      (select coalesce(array_agg(m.template_id order by m.template_id), '{}')
         from public.community_membership m
        where m.user_id = target
          and (target = caller or exists (
                select 1 from public.community_membership mine
                 where mine.user_id = caller and mine.template_id = m.template_id)))
    end;
end;
$$;

-- ---------------------------------------------------------------------------
-- Relationship actions (all idempotent; each returns the resulting relationship)
-- ---------------------------------------------------------------------------

-- Sends a request. If the other user has already asked the caller, this accepts it,
-- so crossing requests become a friendship instead of two requests.
create or replace function public.send_friend_request(p_public_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
  row_ public.friendship;
begin
  target := public._resolve_public_id(caller, p_public_id);
  if target = caller then
    raise exception 'cannot befriend yourself' using errcode = '22023';
  end if;
  if public._has_blocked(caller, target) then
    raise exception 'unblock the user first' using errcode = 'P0004';
  end if;

  insert into public.friendship (user_low, user_high, requester_id)
  values (least(caller, target), greatest(caller, target), caller)
  on conflict (user_low, user_high) do nothing;
  if found then
    return 'outgoing';
  end if;

  select * into row_ from public.friendship f
   where f.user_low = least(caller, target) and f.user_high = greatest(caller, target)
   for update;
  if row_.status = 'accepted' then
    return 'friends';
  end if;
  if row_.requester_id = caller then
    return 'outgoing';
  end if;
  update public.friendship f
     set status = 'accepted', responded_at = now()
   where f.user_low = row_.user_low and f.user_high = row_.user_high;
  return 'friends';
end;
$$;

-- Only the recipient of a pending request can answer it.
create or replace function public.respond_friend_request(p_public_id uuid, p_accept boolean)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
  row_ public.friendship;
begin
  target := public._resolve_public_id(caller, p_public_id);
  select * into row_ from public.friendship f
   where f.user_low = least(caller, target) and f.user_high = greatest(caller, target)
   for update;
  if row_.status = 'accepted' then
    return 'friends';
  end if;
  if row_.user_low is null or row_.requester_id <> target then
    raise exception 'no incoming request' using errcode = 'P0002';
  end if;
  if p_accept then
    update public.friendship f set status = 'accepted', responded_at = now()
     where f.user_low = row_.user_low and f.user_high = row_.user_high;
    return 'friends';
  end if;
  delete from public.friendship f where f.user_low = row_.user_low and f.user_high = row_.user_high;
  return 'none';
end;
$$;

-- Only the sender can cancel; a request that was accepted meanwhile stays a friendship.
create or replace function public.cancel_friend_request(p_public_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
begin
  target := public._resolve_public_id(caller, p_public_id);
  delete from public.friendship f
   where f.user_low = least(caller, target) and f.user_high = greatest(caller, target)
     and f.status = 'pending' and f.requester_id = caller;
  return public._relationship(caller, target);
end;
$$;

create or replace function public.remove_friend(p_public_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
begin
  target := public._resolve_public_id(caller, p_public_id);
  delete from public.friendship f
   where f.user_low = least(caller, target) and f.user_high = greatest(caller, target) and f.status = 'accepted';
  return public._relationship(caller, target);
end;
$$;

-- Blocking ends any friendship or request between the two users.
create or replace function public.block_user(p_public_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
begin
  -- Blocking works even if the other user blocked the caller first.
  select p.id into target from public.profile p where p.public_id = p_public_id;
  if target is null then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  if target = caller then
    raise exception 'cannot block yourself' using errcode = '22023';
  end if;
  insert into public.user_block (blocker_id, blocked_id) values (caller, target) on conflict do nothing;
  delete from public.friendship f where f.user_low = least(caller, target) and f.user_high = greatest(caller, target);
  return 'blocked';
end;
$$;

create or replace function public.unblock_user(p_public_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  caller constant uuid := public._caller();
  target uuid;
begin
  select p.id into target from public.profile p where p.public_id = p_public_id;
  if target is null then
    raise exception 'user not found' using errcode = 'P0002';
  end if;
  delete from public.user_block b where b.blocker_id = caller and b.blocked_id = target;
  return public._relationship(caller, target);
end;
$$;

-- The caller's friends, requests and blocked users.
--   kind: 'friend', 'incoming', 'outgoing' or 'blocked'
--   since: when the friendship started or the request/block was made
--   requested_by_me: for friends — the caller sent the original request (so the
--   other user accepted it; the app shows recent acceptances as notices)
create or replace function public.my_social_graph()
returns table (public_id uuid, nickname text, avatar text, kind text, since timestamptz, requested_by_me boolean)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller constant uuid := public._caller();
begin
  return query
    select p.public_id,
           p.nickname,
           p.avatar,
           case when f.status = 'accepted' then 'friend' when f.requester_id = caller then 'outgoing' else 'incoming' end,
           coalesce(f.responded_at, f.created_at),
           f.requester_id = caller
      from public.friendship f
      join public.profile p on p.id = case when f.user_low = caller then f.user_high else f.user_low end
     where caller in (f.user_low, f.user_high)
    union all
    select p.public_id, p.nickname, p.avatar, 'blocked', b.created_at, false
      from public.user_block b
      join public.profile p on p.id = b.blocked_id
     where b.blocker_id = caller;
end;
$$;

-- ---------------------------------------------------------------------------
-- Friends ranking
-- ---------------------------------------------------------------------------

-- The caller and their friends this week, ranked by weekly consistency over all active
-- habits (rule weekly_consistency_v1). Friends who hide their statistics
-- (stats_visibility = 'nobody') are left out. Ties: more completed days, then nickname.
create or replace function public.friends_leaderboard(p_today date)
returns table (
  rank           integer,
  public_id      uuid,
  nickname       text,
  avatar         text,
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
  caller constant uuid := public._caller();
begin
  perform public._check_today(p_today);
  return query
  with people as (
    select caller as user_id
    union
    select case when f.user_low = caller then f.user_high else f.user_low end
      from public.friendship f
     where f.status = 'accepted' and caller in (f.user_low, f.user_high)
  ),
  visible as (
    select p.id, p.public_id, p.nickname, p.avatar
      from people x
      join public.profile p on p.id = x.user_id
     where p.id = caller or public._can_see(caller, p.id, p.stats_visibility)
  ),
  scored as (
    select v.*, t.completed_days, t.eligible_days,
           case when t.eligible_days > 0 then t.completed_days::numeric * 100 / t.eligible_days end as consistency
      from visible v
      cross join lateral public._weekly_totals(v.id, p_today) t
  ),
  ranked as (
    select s.*,
           (row_number() over (order by s.consistency desc, s.completed_days desc, lower(s.nickname) nulls last, s.public_id))::integer as position,
           (count(*) over ())::integer as total
      from scored s
     where s.eligible_days > 0
  )
  select r.position, r.public_id, r.nickname, r.avatar, r.id = caller, r.completed_days, r.eligible_days, r.consistency, r.total
    from ranked r
  union all
  select null::integer, s.public_id, s.nickname, s.avatar, true, s.completed_days, s.eligible_days, null::numeric,
         (select count(*)::integer from ranked)
    from scored s
   where s.id = caller and s.eligible_days = 0
   order by 1 nulls last;
end;
$$;

-- ---------------------------------------------------------------------------
-- Community ranking: nicknames and avatars, respecting privacy
-- ---------------------------------------------------------------------------

drop function if exists public.community_leaderboard(text, date, integer);

-- As before, but members are shown by nickname and avatar only if their
-- stats_visibility allows it for the caller; otherwise anonymously.
create function public.community_leaderboard(p_template_id text, p_today date, p_limit integer default 20)
returns table (
  rank           integer,
  display_name   text,
  is_me          boolean,
  completed_days integer,
  eligible_days  integer,
  consistency    numeric,
  ranked_count   integer,
  public_id      uuid,
  avatar         text
)
language plpgsql
stable
security definer
set search_path = ''
as $$
#variable_conflict use_column
declare
  caller    constant uuid := public._caller();
  row_limit constant integer := least(greatest(coalesce(p_limit, 20), 1), 100);
begin
  perform public._check_today(p_today);
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
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.nickname end,
         r.user_id = caller,
         r.completed_days,
         r.eligible_days,
         r.consistency,
         r.total,
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.public_id end,
         case when public._can_see(caller, r.user_id, p.stats_visibility) then p.avatar end
    from ranked r
    left join public.profile p on p.id = r.user_id
   where r.position <= row_limit or r.user_id = caller
  union all
  select null::integer, null::text, true, coalesce(s.completed_days, 0), coalesce(s.eligible_days, 0), null::numeric,
         (select count(*)::integer from ranked), null::uuid, null::text
    from public.community_membership m
    left join scores s on s.user_id = m.user_id
   where m.template_id = p_template_id
     and m.user_id = caller
     and not exists (select 1 from ranked r where r.user_id = caller)
   order by 1 nulls last;
end;
$$;

-- ---------------------------------------------------------------------------
-- Execution rights
-- ---------------------------------------------------------------------------

revoke execute on function
  public.nickname_status(text), public.search_profiles(text), public.get_public_profile(uuid, date),
  public.send_friend_request(uuid), public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid), public.remove_friend(uuid), public.block_user(uuid),
  public.unblock_user(uuid), public.my_social_graph(), public.friends_leaderboard(date),
  public.community_leaderboard(text, date, integer)
  from public, anon;

grant execute on function
  public.nickname_status(text), public.search_profiles(text), public.get_public_profile(uuid, date),
  public.send_friend_request(uuid), public.respond_friend_request(uuid, boolean),
  public.cancel_friend_request(uuid), public.remove_friend(uuid), public.block_user(uuid),
  public.unblock_user(uuid), public.my_social_graph(), public.friends_leaderboard(date),
  public.community_leaderboard(text, date, integer)
  to authenticated;

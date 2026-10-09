-- Habit catalog and communities: seed, ranked habits, scoring rules, ranking, authorization.
begin;
create extension if not exists pgtap with schema extensions;
set local timezone = 'UTC';

select plan(44);

-- ===== Catalog ======================================================================
select has_table('public', 'habit_template', 'habit_template exists');
select has_table('public', 'community_membership', 'community_membership exists');
select is((select count(*)::int from public.habit_template), 16, '16 templates are seeded');
select is((select count(*)::int from public.habit_template
            where is_active and scoring_policy = 'weekly_consistency_v1' and schedule = 'daily'), 16,
          'seeded templates are active, daily and use the v1 scoring policy');
select ok((select bool_and(c.relrowsecurity) from pg_class c
            where c.oid in ('public.habit_template'::regclass, 'public.community_membership'::regclass)),
          'RLS is enabled on both tables');
select ok(not exists (select 1 from pg_proc p
                       where p.proname = 'community_leaderboard'
                         and ('user_id' = any(p.proargnames) or 'email' = any(p.proargnames))),
          'the leaderboard exposes neither user ids nor emails');
select ok(not exists (select 1 from pg_trigger t
                       where t.tgrelid = 'public.habit'::regclass
                         and t.tgfoid in (select oid from pg_proc where proname ilike '%community%')),
          'creating or changing a habit never joins a community');

-- ===== Fixtures (as the migration owner) ============================================
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'dave@example.test'),
  ('55555555-5555-5555-5555-555555555555', 'erin@example.test');
-- Alice shows her name to everyone; the others keep the default (friends only).
update public.profile set nickname = 'Alice', stats_visibility = 'everyone' where id = '11111111-1111-1111-1111-111111111111';

insert into public.habit (id, user_id, category_id, title, is_active, created_at) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'health', 'Walk', true, '2000-01-01'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'health', 'Walk', true, '2000-01-01'),
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'health', 'Walk', false, '2000-01-01'),
  ('e0000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', 'health', 'Walk', true, '2026-10-09 10:00+00'),
  ('a0000000-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'selv-development', 'Meditate', true, '2000-01-01'),
  ('b0000000-0000-0000-0000-000000000002', '22222222-2222-2222-2222-222222222222', 'selv-development', 'Meditate', true, '2000-01-01'),
  ('c0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'selv-development', 'Meditate', true, '2000-01-01'),
  ('a0000000-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'education', 'Read', true, '2000-01-01'),
  ('a0000000-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'education', 'Read more', true, '2000-01-01'),
  ('a0000000-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'sport', 'Old run', true, '2000-01-01'),
  ('b0000000-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'sport', 'Stretch', true, '2000-01-01');

-- Fixed past dates need the guard (which pins joined_on to "today") out of the way.
alter table public.community_membership disable trigger community_membership_guard;
insert into public.community_membership (user_id, template_id, habit_id, joined_on) values
  ('11111111-1111-1111-1111-111111111111', 'walking', 'a0000000-0000-0000-0000-000000000001', '2026-10-01'),
  ('22222222-2222-2222-2222-222222222222', 'walking', 'b0000000-0000-0000-0000-000000000001', '2026-10-08'),
  ('33333333-3333-3333-3333-333333333333', 'walking', 'c0000000-0000-0000-0000-000000000001', '2026-10-01'),
  ('44444444-4444-4444-4444-444444444444', 'walking', null, '2026-10-01'),
  ('55555555-5555-5555-5555-555555555555', 'walking', 'e0000000-0000-0000-0000-000000000001', '2026-10-01');
alter table public.community_membership enable trigger community_membership_guard;

-- Week of Monday 2026-10-05 .. Sunday 2026-10-11.
insert into public.habit_completion (habit_id, user_id, completed_on, deleted_at) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-04', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-05', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-06', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-07', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-08', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-09', null),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-10', now()),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-07', null),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-08', null),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-09', null),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-10', null),
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '2026-10-08', null),
  ('e0000000-0000-0000-0000-000000000001', '55555555-5555-5555-5555-555555555555', '2026-10-09', null);

-- ===== Scoring rules (weekly_consistency_v1) ========================================
select is((select (completed_days, eligible_days, round(consistency, 2))::text
             from public._community_scores('walking', '2026-10-11')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(5,7,71.43)', '5 of 7 scheduled days = 71.43%; other weeks and un-marked days do not count');
select is((select (completed_days, eligible_days, round(consistency, 2))::text
             from public._community_scores('walking', '2026-10-11')
            where user_id = '22222222-2222-2222-2222-222222222222'),
          '(3,4,75.00)', 'days before joining are neither eligible nor completed');
select is((select (completed_days, eligible_days)::text
             from public._community_scores('walking', '2026-10-11')
            where user_id = '55555555-5555-5555-5555-555555555555'),
          '(1,3)', 'days before the habit was created are not eligible');
select is((select (completed_days, eligible_days, round(consistency, 2))::text
             from public._community_scores('walking', '2026-10-07')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(3,3,100.00)', 'future days of the week are not counted');
select is((select (completed_days, eligible_days)::text
             from public._community_scores('walking', '2026-10-07')
            where user_id = '22222222-2222-2222-2222-222222222222'),
          '(0,0)', 'a member who joined later this week has no eligible days yet');
select ok(not exists (select 1 from public._community_scores('walking', '2026-10-11')
                       where user_id in ('33333333-3333-3333-3333-333333333333',
                                         '44444444-4444-4444-4444-444444444444')),
          'members with a paused or no ranked habit are not scored');
select is((select (completed_days, eligible_days)::text
             from public._community_scores('walking', '2026-10-12')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(0,1)', 'a new week starts on Monday');

-- Current week, relative to today: Alice and Bob complete every day so far (a tie),
-- Carol completes nothing, Dave has no ranked habit.
alter table public.community_membership disable trigger community_membership_guard;
insert into public.community_membership (user_id, template_id, habit_id, joined_on)
select u, 'meditation', h, current_date - (extract(isodow from current_date)::int - 1)
  from (values ('11111111-1111-1111-1111-111111111111'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid),
               ('22222222-2222-2222-2222-222222222222'::uuid, 'b0000000-0000-0000-0000-000000000002'::uuid),
               ('33333333-3333-3333-3333-333333333333'::uuid, 'c0000000-0000-0000-0000-000000000002'::uuid))
       as v(u, h);
insert into public.community_membership (user_id, template_id, habit_id, joined_on)
values ('44444444-4444-4444-4444-444444444444', 'meditation', null, current_date);
alter table public.community_membership enable trigger community_membership_guard;

insert into public.habit_completion (habit_id, user_id, completed_on)
select h, u, d::date
  from (values ('11111111-1111-1111-1111-111111111111'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid),
               ('22222222-2222-2222-2222-222222222222'::uuid, 'b0000000-0000-0000-0000-000000000002'::uuid))
       as v(u, h)
 cross join generate_series(current_date - (extract(isodow from current_date)::int - 1), current_date, interval '1 day') d;

-- ===== Leaderboard ==================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is((select array_agg(rank order by rank) from public.community_leaderboard('meditation', current_date)),
          array[1, 2, 3], 'members with a ranked habit are ranked; others are not');
select is((select display_name from public.community_leaderboard('meditation', current_date) where rank = 1),
          'Alice', 'ties go to more completed days, then a stable order; public nicknames are shown');
select is((select (rank, is_me, display_name is null)::text
             from public.community_leaderboard('meditation', current_date) where is_me),
          '(2,t,t)', 'the caller sees their own rank; members who do not share their name stay anonymous');
select is((select round(consistency) from public.community_leaderboard('meditation', current_date) where rank = 3),
          0::numeric, 'a member with no completions is ranked last with 0%');
select is((select max(ranked_count) from public.community_leaderboard('meditation', current_date)),
          3, 'the number of ranked members is reported');
select throws_ok($$ select * from public.community_leaderboard('meditation', current_date - 7) $$,
                 '22023', null, 'only the current week can be requested');
select throws_ok($$ select * from public._community_scores('meditation', current_date) $$,
                 '42501', null, 'clients cannot call the internal scoring function');
select is((select member_count from public.community_member_counts() where template_id = 'meditation'),
          4, 'participant counts include members without ranking');

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is((select array_agg(rank order by rank) from public.community_leaderboard('meditation', current_date, 1)),
          array[1, 3], 'the caller''s row is added below the requested top');

select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select is((select (rank is null, eligible_days)::text
             from public.community_leaderboard('meditation', current_date) where is_me),
          '(t,0)', 'a member without a ranked habit sees an unranked row of their own');

-- ===== Membership as Alice ==========================================================
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select (user_id, habit_id is null)::text from public.join_community('reading')),
          '(11111111-1111-1111-1111-111111111111,t)', 'joining without ranking needs no habit');
select is((select habit_id from public.join_community('reading', 'a0000000-0000-0000-0000-000000000003')),
          'a0000000-0000-0000-0000-000000000003'::uuid, 'a ranked habit can be added later');
select lives_ok($$ select public.join_community('reading') $$, 'joining again is harmless');
select is((select (count(*), max(habit_id::text))::text from public.community_membership where template_id = 'reading'),
          '(1,a0000000-0000-0000-0000-000000000003)', 'a repeated join neither duplicates nor drops the ranked habit');
select is((select habit_id from public.join_community('running', 'a0000000-0000-0000-0000-000000000005')),
          'a0000000-0000-0000-0000-000000000005'::uuid, 'joining with a ranked habit in one step');
select throws_ok($$ select public.join_community('drawing', 'a0000000-0000-0000-0000-000000000003') $$,
                 '23505', null, 'a habit ranks in one community at most');
select is((select joined_on from public.join_community('drawing', null, '2020-01-01')),
          current_date, 'a backdated join day is replaced by today');
select throws_ok($$
  insert into public.community_membership (user_id, template_id)
  values ('22222222-2222-2222-2222-222222222222', 'stretching')
$$, '42501', null, 'cannot join on behalf of another user');
select throws_ok($$ select public.join_community('stretching', 'b0000000-0000-0000-0000-000000000003') $$,
                 '23503', null, 'cannot rank with another user''s habit');
select is((select count(*)::int from public.community_membership
            where user_id <> '11111111-1111-1111-1111-111111111111'), 0,
          'other users'' memberships are invisible');

update public.community_membership set habit_id = null where user_id = '22222222-2222-2222-2222-222222222222';
select throws_ok($$ update public.community_membership set template_id = 'stretching' where template_id = 'reading' $$,
                 '42501', null, 'the community of a membership cannot be changed');
select throws_ok($$ update public.community_membership set joined_on = '2020-01-01' where template_id = 'reading' $$,
                 '42501', null, 'the join day cannot be changed');
delete from public.community_membership where user_id = '22222222-2222-2222-2222-222222222222';
select is((select count(*)::int from public.habit_completion
            where user_id <> '11111111-1111-1111-1111-111111111111'), 0,
          'membership grants no access to other members'' completions');

select lives_ok($$ delete from public.community_membership where template_id = 'walking' $$, 'a member can leave');
select is((select count(*)::int from public.habit_completion where habit_id = 'a0000000-0000-0000-0000-000000000001'),
          7, 'leaving keeps the ranked habit and its completions');

-- ===== Owner checks (as the migration owner) ========================================
reset role;
select is((select count(*)::int from public.community_membership
            where user_id = '22222222-2222-2222-2222-222222222222' and habit_id is not null), 2,
          'another user''s memberships were neither changed nor deleted');

update public.habit_template set is_active = false where id = 'no-sugar';
update public.habit set deleted_at = now() where id = 'a0000000-0000-0000-0000-000000000004';
set local role authenticated;
select throws_ok($$ select public.join_community('no-sugar') $$, '23514', null, 'a retired community cannot be joined');
select throws_ok($$ select public.join_community('deep-work', 'a0000000-0000-0000-0000-000000000004') $$,
                 '23514', null, 'a deleted habit cannot be ranked');

-- ===== Anonymous ====================================================================
set local role anon;
select throws_ok($$ select * from public.habit_template $$, '42501', null, 'anon cannot read the catalog');
select throws_ok($$ select * from public.community_leaderboard('meditation', current_date) $$,
                 '42501', null, 'anon cannot read rankings');

select * from finish();
rollback;

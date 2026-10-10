-- Habit catalog and communities: seed, ranked habits, scoring rules, ranking, authorization.
begin;
create extension if not exists pgtap with schema extensions;
set local timezone = 'UTC';

select plan(54);

-- ===== Catalog ======================================================================
select has_table('public', 'habit_template', 'habit_template exists');
select has_table('public', 'community_membership', 'community_membership exists');
select is((select count(*)::int from public.habit_template), 39, '39 templates are seeded');
select ok((select bool_and(id in (select id from public.habit_template))
             from unnest(array['reading', 'english-practice', 'learning', 'morning-exercise', 'running', 'stretching',
                               'walking', 'drinking-water', 'consistent-sleep', 'no-sugar', 'meditation', 'journaling',
                               'drawing', 'music-practice', 'deep-work', 'expense-tracking']) as id),
          'the original 16 template ids are kept');
select is((select count(*)::int from public.habit_template
            where is_active and scoring_policy = 'weekly_consistency_v2'), 39,
          'all templates are active and use the v2 scoring policy');
select is((select array_agg(distinct schedule order by schedule) from public.habit_template),
          array['daily', 'weekdays', 'weekly_target'], 'all three schedule types are recommended');
select is((select (schedule, weekly_target, schedule_days)::text from public.habit_template where id = 'strength-training'),
          '(weekly_target,3,)', 'a recommended schedule is structured data, e.g. strength training 3 times a week');
select is((select (schedule, weekly_target, schedule_days)::text from public.habit_template where id = 'deep-work'),
          '(weekdays,,31)', 'selected weekdays are a bit mask (Monday to Friday = 31)');
select is((select count(distinct lower(title->>'ru'))::int + count(distinct lower(title->>'en'))::int
             from public.habit_template), 78, 'template names are distinct in both languages');
select ok(not exists (select 1 from public.habit_template t
                       where not exists (select 1 from public.category c where c.id = t.category_id)),
          'every template belongs to an existing category');
select throws_ok($$ insert into public.habit_template (id, category_id, title, description, icon, schedule)
                    values ('x', 'health', '{"ru":"x","en":"x"}', '{"ru":"x","en":"x"}', 'x', 'weekly_target') $$,
                 '23514', null, 'a weekly-target recommendation needs its target');
-- Re-running the seed updates entries in place.
insert into public.habit_template (id, category_id, title, description, icon, schedule, weekly_target, sort_order)
values ('running', 'sport', '{"ru": "Бег", "en": "Running"}', '{"ru": "x", "en": "x"}', '🏃', 'weekly_target', 3, 50)
on conflict (id) do update set description = excluded.description;
select is((select count(*)::int from public.habit_template), 39, 're-running the seed creates no duplicates');
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

-- ===== Finished-week scoring (weekly_consistency_v2) ===============================
select is((select (completed_actions, expected_actions, round(consistency, 2), status)::text
             from public._community_week_scores('walking', '2026-10-05')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(5,7,71.43,scored)', '5 of 7 scheduled days = 71.43%; other weeks and a reverted mark do not count');
select is((select (completed_actions, expected_actions, round(consistency, 2))::text
             from public._community_week_scores('walking', '2026-10-05')
            where user_id = '22222222-2222-2222-2222-222222222222'),
          '(3,4,75.00)', 'joining mid-week: days before joining are neither expected nor completed');
select is((select (completed_actions, expected_actions)::text
             from public._community_week_scores('walking', '2026-10-05')
            where user_id = '55555555-5555-5555-5555-555555555555'),
          '(1,3)', 'days before the habit was created are not expected');
select is((select (completed_actions, expected_actions)::text
             from public._community_week_scores('walking', '2026-09-28')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(1,4)', 'weeks run Monday to Sunday: Sunday 2026-10-04 belongs to the week before');
select is((select status from public._community_week_scores('walking', '2026-09-28')
            where user_id = '22222222-2222-2222-2222-222222222222'),
          'joined_recently', 'a member who joined after the week is not scored for it');
select is((select array_agg(status order by user_id) from public._community_week_scores('walking', '2026-10-05')
            where user_id in ('33333333-3333-3333-3333-333333333333', '44444444-4444-4444-4444-444444444444')),
          array['paused', 'no_habit'], 'a paused or missing ranked habit is not scored, with the reason');
select is((select consistency from public._community_week_scores('walking', '2026-10-05')
            where user_id = '33333333-3333-3333-3333-333333333333'),
          null::numeric, 'no score is invented for a member who is not scored');

-- Last finished week, relative to today. Bob completes it and the week before
-- (successful-week streak 2); Alice and Erin complete it (streak 1, a full tie);
-- Carol completes nothing; Dave has no ranked habit.
insert into public.habit (id, user_id, category_id, title, created_at) values
  ('e0000000-0000-0000-0000-000000000002', '55555555-5555-5555-5555-555555555555', 'selv-development', 'Meditate', '2000-01-01');
alter table public.community_membership disable trigger community_membership_guard;
insert into public.community_membership (user_id, template_id, habit_id, joined_on)
select u, 'meditation', h, current_date - (extract(isodow from current_date)::int - 1) - w
  from (values ('11111111-1111-1111-1111-111111111111'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid, 7),
               ('22222222-2222-2222-2222-222222222222'::uuid, 'b0000000-0000-0000-0000-000000000002'::uuid, 14),
               ('33333333-3333-3333-3333-333333333333'::uuid, 'c0000000-0000-0000-0000-000000000002'::uuid, 7),
               ('55555555-5555-5555-5555-555555555555'::uuid, 'e0000000-0000-0000-0000-000000000002'::uuid, 7))
       as v(u, h, w);
insert into public.community_membership (user_id, template_id, habit_id, joined_on)
values ('44444444-4444-4444-4444-444444444444', 'meditation', null, current_date);
alter table public.community_membership enable trigger community_membership_guard;

insert into public.habit_completion (habit_id, user_id, completed_on)
select h, u, d::date
  from (values ('11111111-1111-1111-1111-111111111111'::uuid, 'a0000000-0000-0000-0000-000000000002'::uuid, 7),
               ('22222222-2222-2222-2222-222222222222'::uuid, 'b0000000-0000-0000-0000-000000000002'::uuid, 14),
               ('55555555-5555-5555-5555-555555555555'::uuid, 'e0000000-0000-0000-0000-000000000002'::uuid, 7))
       as v(u, h, w)
 cross join generate_series(current_date - (extract(isodow from current_date)::int - 1) - w,
                            current_date - extract(isodow from current_date)::int, interval '1 day') d;
-- Marks of the current week do not change the finished week's ranking.
insert into public.habit_completion (habit_id, user_id, completed_on)
values ('c0000000-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', current_date);
-- A schedule change after the week does not rewrite its result.
update public.habit set schedule_type = 'weekly_target', weekly_target = 1
 where id = 'b0000000-0000-0000-0000-000000000002';

-- ===== Leaderboard ==================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is((select array_agg(rank order by rank) from public.community_leaderboard('meditation', current_date)),
          array[1, 2, 3, 4], 'members with a ranked habit are ranked; others are not');
select is((select (rank, completed_actions, expected_actions, success_weeks)::text
             from public.community_leaderboard('meditation', current_date) where is_me),
          '(1,7,7,2)', 'equal scores: more consecutive successful weeks rank higher; a later schedule change is ignored');
select is((select array_agg(display_name order by rank) from public.community_leaderboard('meditation', current_date)
            where rank in (2, 3)),
          array['Alice', null], 'a full tie keeps a stable order; only public nicknames are shown');
select is((select (round(consistency), completed_actions, expected_actions)::text
             from public.community_leaderboard('meditation', current_date) where rank = 4),
          '(0,0,7)', 'a member with no completions is ranked last with 0%, current-week marks do not count');
select is((select (max(ranked_count), min(week_start))::text from public.community_leaderboard('meditation', current_date)),
          format('(4,%s)', current_date - (extract(isodow from current_date)::int - 1) - 7),
          'the ranked count and the finished week (from Monday) are reported');
select throws_ok($$ select * from public.community_leaderboard('meditation', current_date - 7) $$,
                 '22023', null, 'only the current local date is accepted');
select throws_ok($$ select * from public._community_week_scores('meditation', current_date) $$,
                 '42501', null, 'clients cannot call the internal scoring function');
select throws_ok($$ select * from public.habit_schedule_version $$,
                 '42501', null, 'clients cannot read schedule history');
select is((select member_count from public.community_member_counts() where template_id = 'meditation'),
          5, 'participant counts include members without ranking');

select set_config('request.jwt.claims',
  '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is((select array_agg(rank order by rank) from public.community_leaderboard('meditation', current_date, 1)),
          array[1, 4], 'the caller''s row is added below the requested top');

select set_config('request.jwt.claims',
  '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select is((select (rank is null, expected_actions, status)::text
             from public.community_leaderboard('meditation', current_date) where is_me),
          '(t,0,no_habit)', 'a member without a ranked habit sees an unranked row with the reason');

select set_config('request.jwt.claims',
  '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
delete from public.community_membership where template_id = 'meditation';
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select (count(*), max(ranked_count))::text from public.community_leaderboard('meditation', current_date)),
          '(3,3)', 'a member who left is no longer ranked or shown');

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

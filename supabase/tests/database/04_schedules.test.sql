-- Habit schedules: integrity rules and schedule-aware rankings.
begin;
create extension if not exists pgtap with schema extensions;
set local timezone = 'UTC';

select plan(21);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.test');

-- ===== Integrity ====================================================================
insert into public.habit (id, user_id, category_id, title, created_at) values
  ('a0000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111', 'health', 'Old habit', '2000-01-01');
select is((select (schedule_type, weekly_target, schedule_days, streak_reset_on)::text from public.habit
            where id = 'a0000000-0000-0000-0000-000000000000'),
          '(daily,,,)', 'existing and new habits default to daily');

select throws_ok($$ insert into public.habit (user_id, category_id, title, schedule_type)
                    values ('11111111-1111-1111-1111-111111111111', 'health', 'x', 'weekly_target') $$,
                 '23514', null, 'a weekly target needs its number');
select throws_ok($$ insert into public.habit (user_id, category_id, title, schedule_type, weekly_target)
                    values ('11111111-1111-1111-1111-111111111111', 'health', 'x', 'weekly_target', 8) $$,
                 '23514', null, 'the weekly target is 1–7');
select throws_ok($$ insert into public.habit (user_id, category_id, title, schedule_type, schedule_days)
                    values ('11111111-1111-1111-1111-111111111111', 'health', 'x', 'weekdays', 0) $$,
                 '23514', null, 'selected weekdays need at least one day');
select throws_ok($$ insert into public.habit (user_id, category_id, title, schedule_type, weekly_target)
                    values ('11111111-1111-1111-1111-111111111111', 'health', 'x', 'daily', 3) $$,
                 '23514', null, 'parameters of another type are refused');
select throws_ok($$ insert into public.habit (user_id, category_id, title, schedule_type)
                    values ('11111111-1111-1111-1111-111111111111', 'health', 'x', 'monthly') $$,
                 '23514', null, 'only the three schedule types exist');

-- ===== Fixtures: week of Monday 2026-10-05 .. Sunday 2026-10-11 =====================
insert into public.habit (id, user_id, category_id, title, schedule_type, weekly_target, schedule_days, created_at) values
  -- Alice: Monday, Wednesday, Friday (1 + 4 + 16).
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'health', 'MWF', 'weekdays', null, 21, '2000-01-01'),
  -- Bob: three times a week.
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'health', '3x', 'weekly_target', 3, null, '2000-01-01'),
  -- Carol: three times a week as well.
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'health', '3x', 'weekly_target', 3, null, '2000-01-01');

insert into public.habit_completion (habit_id, user_id, completed_on) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-05'),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-06'),
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', '2026-10-07'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-05'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-06'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-07'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-08'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', '2026-10-09'),
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', '2026-10-06');

alter table public.community_membership disable trigger community_membership_guard;
insert into public.community_membership (user_id, template_id, habit_id, joined_on) values
  ('11111111-1111-1111-1111-111111111111', 'walking', 'a0000000-0000-0000-0000-000000000001', '2026-10-01'),
  ('22222222-2222-2222-2222-222222222222', 'walking', 'b0000000-0000-0000-0000-000000000001', '2026-10-01'),
  ('33333333-3333-3333-3333-333333333333', 'walking', 'c0000000-0000-0000-0000-000000000001', '2026-10-01');
alter table public.community_membership enable trigger community_membership_guard;

-- ===== Schedule-aware scores (finished week 2026-10-05 .. 2026-10-11) ==============
select is((select (completed_actions, expected_actions)::text from public._community_week_scores('walking', '2026-10-05')
            where user_id = '11111111-1111-1111-1111-111111111111'),
          '(2,3)', 'weekdays: only Mon/Wed/Fri are scheduled; a Tuesday mark does not count');
select is((select (completed_days, eligible_days)::text
             from public._habit_period_counts('a0000000-0000-0000-0000-000000000001', 'weekdays', null, 21, '2026-10-05', '2026-10-06')),
          '(1,1)', 'weekdays: future selected days are not counted as missed');
select is((select (completed_actions, expected_actions, round(consistency))::text from public._community_week_scores('walking', '2026-10-05')
            where user_id = '22222222-2222-2222-2222-222222222222'),
          '(3,3,100)', 'weekly target: marks beyond the target do not count');
select is((select (completed_actions, expected_actions, round(consistency, 1))::text from public._community_week_scores('walking', '2026-10-05')
            where user_id = '33333333-3333-3333-3333-333333333333'),
          '(1,3,33.3)', 'weekly target: progress towards the target');
select is((select (completed_days, eligible_days)::text
             from public._habit_period_counts('b0000000-0000-0000-0000-000000000001', 'weekly_target', 3, null, '2026-10-12', '2026-10-12')),
          '(0,3)', 'weekly target: a new week starts on Monday');
select is((select (completed_days, eligible_days)::text
             from public._habit_period_counts('b0000000-0000-0000-0000-000000000001', 'weekly_target', 3, null, '2026-10-08', '2026-10-11')),
          '(2,2)', 'weekly target: joining on Thursday prorates the target to ceil(3 × 4 / 7) = 2');

select is((select (completed_days, eligible_days)::text from public._weekly_totals('11111111-1111-1111-1111-111111111111', '2026-10-11')),
          '(2,10)', 'friends totals add a daily habit (7 days, none marked) and a weekdays habit (2 of 3)');
select is((select (completed_days, eligible_days)::text
             from public._habit_period_counts('b0000000-0000-0000-0000-000000000001', 'weekly_target', 3, null, '2026-10-12', '2026-10-11')),
          '(0,0)', 'nothing is expected before the period starts, even for a weekly target');

-- ===== Owner edits ==================================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$ update public.habit
                      set schedule_type = 'weekly_target', weekly_target = 2, schedule_days = null, streak_reset_on = current_date
                    where id = 'a0000000-0000-0000-0000-000000000001' $$,
                'the owner changes the schedule and the streak reset day together');
select is((select count(*)::int from public.habit_completion where habit_id = 'a0000000-0000-0000-0000-000000000001'),
          3, 'changing the schedule keeps the completion history');
select throws_ok($$ update public.habit set schedule_days = 3 where id = 'a0000000-0000-0000-0000-000000000001' $$,
                 '23514', null, 'an inconsistent schedule is refused');
update public.habit set schedule_type = 'daily', weekly_target = null where user_id = '22222222-2222-2222-2222-222222222222';
reset role;
-- Schedule history is server-only, so it is checked as the owner of the schema.
select is((select array_agg(schedule_type order by valid_from, id) from public.habit_schedule_version
            where habit_id = 'a0000000-0000-0000-0000-000000000001'),
          array['weekdays', 'weekly_target'], 'a schedule change is recorded as a new version');
select is((select valid_from from public.habit_schedule_version
            where habit_id = 'a0000000-0000-0000-0000-000000000001' order by valid_from, id limit 1),
          '2000-01-01 00:00+00'::timestamptz, 'the first version is valid from the habit''s creation');
update public.habit set title = 'Renamed', weekly_target = 2 where id = 'a0000000-0000-0000-0000-000000000001';
select is((select count(*)::int from public.habit_schedule_version where habit_id = 'a0000000-0000-0000-0000-000000000001'),
          2, 'a repeated upload or an unrelated edit records no version');
select is((select schedule_type from public.habit where id = 'b0000000-0000-0000-0000-000000000001'),
          'weekly_target', 'another user''s schedule cannot be changed');

select * from finish();
rollback;

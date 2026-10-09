-- Social layer: nicknames, friend requests, blocking, privacy, friends ranking.
-- Follows the end-to-end flow: A sets a nickname, B finds and adds A, A accepts, both
-- see each other, the ranking works, then removal and blocking.
begin;
create extension if not exists pgtap with schema extensions;
set local timezone = 'UTC';

select plan(55);

-- ===== Fixtures (as the migration owner) ============================================
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test'),
  ('33333333-3333-3333-3333-333333333333', 'carol@example.test'),
  ('44444444-4444-4444-4444-444444444444', 'mallory@example.test');

-- Fixed public handles keep the test readable.
alter table public.profile disable trigger profile_keep_public_id;
update public.profile set public_id = ('aaaaaaaa-0000-0000-0000-00000000000' || left(id::text, 1))::uuid;
alter table public.profile enable trigger profile_keep_public_id;
update public.profile set nickname = 'Carol' where id = '33333333-3333-3333-3333-333333333333';
update public.profile set nickname = 'Mallory' where id = '44444444-4444-4444-4444-444444444444';

insert into public.habit (id, user_id, category_id, title, created_at) values
  ('a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'education', 'Private reading', '2000-01-01'),
  ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'education', 'Read', '2000-01-01'),
  ('c0000000-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'education', 'Read', '2000-01-01');
-- This week: Alice every day so far, Bob only today, Carol nothing.
insert into public.habit_completion (habit_id, user_id, completed_on)
select 'a0000000-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', d::date
  from generate_series(current_date - (extract(isodow from current_date)::int - 1), current_date, interval '1 day') d;
insert into public.habit_completion (habit_id, user_id, completed_on)
values ('b0000000-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', current_date);
-- Alice ranks in a community; Mallory is a member there too.
insert into public.community_membership (user_id, template_id, habit_id) values
  ('11111111-1111-1111-1111-111111111111', 'reading', 'a0000000-0000-0000-0000-000000000001'),
  ('44444444-4444-4444-4444-444444444444', 'reading', null),
  ('22222222-2222-2222-2222-222222222222', 'reading', null);

-- ===== Structure ====================================================================
select ok(not exists (select 1 from pg_proc p
                       where p.proname in ('search_profiles', 'get_public_profile', 'my_social_graph',
                                           'friends_leaderboard', 'community_leaderboard')
                         and (p.proargnames && array['email', 'user_id', 'id', 'title', 'display_name_private'])),
          'social functions return neither emails, auth ids nor habit names');
select ok((select bool_and(c.relrowsecurity) from pg_class c
            where c.oid in ('public.friendship'::regclass, 'public.user_block'::regclass)),
          'RLS is enabled on relationship tables');

-- ===== 1. Alice sets a nickname =====================================================
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok($$ update public.profile set nickname = 'Alice_1' where id = auth.uid() $$, 'a user sets a nickname');
select is(public.nickname_status('alice_1'), 'available', 'the own nickname counts as available');
select throws_ok($$ update public.profile set public_id = gen_random_uuid() where id = auth.uid() $$,
                 '42501', null, 'the public handle cannot be changed');

-- ===== Nickname rules (as Bob) ======================================================
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is(public.nickname_status('ALICE_1'), 'taken', 'nicknames are unique regardless of case');
select is(public.nickname_status('1abc'), 'invalid', 'a nickname starts with a letter');
select is(public.nickname_status('ab'), 'invalid', 'a nickname has at least 3 characters');
select is(public.nickname_status('Admin'), 'invalid', 'reserved nicknames are refused');
select is(public.nickname_status('bob smith'), 'invalid', 'spaces are not allowed');
select throws_ok($$ update public.profile set nickname = 'alice_1' where id = auth.uid() $$,
                 '23505', null, 'the database refuses a nickname taken in another case');
select lives_ok($$ update public.profile set nickname = 'Bob' where id = auth.uid() $$, 'Bob sets his nickname');
select is((select count(*)::int from public.profile), 1, 'other users'' private profile rows stay invisible');
update public.profile set nickname = 'Hacked', bio = 'x' where id = '11111111-1111-1111-1111-111111111111';

-- ===== 2–3. Bob finds Alice and sends a request =====================================
select is((select (nickname, relationship)::text from public.search_profiles('  aLiCe_1 ')),
          '(Alice_1,none)', 'exact case-insensitive search returns the public fields');
select is((select count(*)::int from public.search_profiles('Alice')), 0, 'search is exact, not prefix');
select is(public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000001'), 'outgoing', 'Bob sends a request');
select is(public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000001'), 'outgoing', 'a repeated request is harmless');
select throws_ok($$ select public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000002') $$,
                 '22023', null, 'nobody can befriend themselves');
select throws_ok($$ select public.respond_friend_request('aaaaaaaa-0000-0000-0000-000000000001', true) $$,
                 'P0002', null, 'the sender cannot accept their own request');
select throws_ok($$ select public.send_friend_request('aaaaaaaa-0000-0000-0000-00000000000f') $$,
                 'P0002', null, 'unknown handles are not found');

-- ===== 4. Alice sees and accepts ====================================================
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select kind from public.my_social_graph() where nickname = 'Bob'), 'incoming', 'Alice sees the incoming request');
select is(public.cancel_friend_request('aaaaaaaa-0000-0000-0000-000000000002'), 'incoming',
          'only the sender can cancel a request');
select is(public.respond_friend_request('aaaaaaaa-0000-0000-0000-000000000002', true), 'friends', 'Alice accepts');
select is((select nickname from public.profile where id = auth.uid()), 'Alice_1', 'nobody else changed Alice''s profile');

-- ===== 5–6. Both see each other =====================================================
select is((select (kind, requested_by_me)::text from public.my_social_graph() where nickname = 'Bob'),
          '(friend,f)', 'Alice sees Bob as a friend');
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select (kind, requested_by_me)::text from public.my_social_graph() where nickname = 'Alice_1'),
          '(friend,t)', 'Bob sees Alice as a friend and that she accepted his request');
select is((select (relationship, stats_visible, active_habits, communities_visible, communities)::text
             from public.get_public_profile('aaaaaaaa-0000-0000-0000-000000000001', current_date)),
          '(friends,t,1,t,{reading})', 'a friend sees statistics and shared communities (default: friends)');

select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select is((select (relationship, stats_visible, active_habits is null, week_completed_days is null, communities is null)::text
             from public.get_public_profile('aaaaaaaa-0000-0000-0000-000000000001', current_date)),
          '(none,f,t,t,t)', 'a stranger sees only the public fields');

-- ===== Crossing requests become one friendship ======================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select is(public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000002'), 'outgoing', 'Carol asks Bob');
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is(public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000003'), 'friends',
          'Bob asking Carol back accepts her request instead of creating a reversed one');

-- ===== 7. Friends ranking ===========================================================
select is((select array_agg(nickname order by rank) from public.friends_leaderboard(current_date)),
          array['Alice_1', 'Bob', 'Carol'], 'friends are ranked by weekly consistency, ties by completed days and nickname');
select is((select (rank, completed_days, round(consistency))::text from public.friends_leaderboard(current_date) where nickname = 'Alice_1'),
          (select format('(1,%s,100)', extract(isodow from current_date)::int)),
          'every eligible day of the week so far counts once');
select is((select max(ranked_count) from public.friends_leaderboard(current_date)), 3, 'the ranked count is reported');
select throws_ok($$ select * from public.friends_leaderboard(current_date - 7) $$, '22023', null,
                 'only the current week can be ranked');

select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
update public.profile set stats_visibility = 'nobody' where id = auth.uid();
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select array_agg(nickname order by rank) from public.friends_leaderboard(current_date)),
          array['Alice_1', 'Bob'], 'friends who hide their statistics are left out');

-- ===== Community ranking respects privacy ===========================================
select is((select display_name from public.community_leaderboard('reading', current_date) where rank = 1),
          'Alice_1', 'a friend sees Alice by nickname in a community ranking');
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select is((select (display_name is null, public_id is null, avatar is null)::text
             from public.community_leaderboard('reading', current_date) where rank = 1),
          '(t,t,t)', 'a stranger sees Alice anonymously (her statistics are for friends only)');

-- ===== 8. Removing and blocking =====================================================
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select is(public.remove_friend('aaaaaaaa-0000-0000-0000-000000000002'), 'none', 'Alice removes Bob');
select is((select count(*)::int from public.my_social_graph() where nickname = 'Bob'), 0, 'Bob is gone from Alice''s list');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select count(*)::int from public.my_social_graph() where nickname = 'Alice_1'), 0, 'and Alice from Bob''s');
select is(public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000001'), 'outgoing', 'Bob asks again');

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select is(public.block_user('aaaaaaaa-0000-0000-0000-000000000002'), 'blocked', 'Alice blocks Bob');
select is((select kind from public.my_social_graph() where nickname = 'Bob'), 'blocked',
          'blocking removes the pending request; Bob is listed as blocked for Alice');
select throws_ok($$ select public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000002') $$,
                 'P0004', null, 'Alice must unblock before asking Bob');
select is((select (relationship, stats_visible)::text
             from public.get_public_profile('aaaaaaaa-0000-0000-0000-000000000002', current_date)),
          '(blocked,f)', 'Alice sees Bob as blocked, without statistics');

select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is((select count(*)::int from public.search_profiles('Alice_1')), 0, 'a blocked user cannot find the blocker');
select throws_ok($$ select * from public.get_public_profile('aaaaaaaa-0000-0000-0000-000000000001', current_date) $$,
                 'P0002', null, 'the blocker''s profile looks like it does not exist');
select throws_ok($$ select public.send_friend_request('aaaaaaaa-0000-0000-0000-000000000001') $$,
                 'P0002', null, 'a blocked user gets the same answer as for an unknown user');

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select is(public.unblock_user('aaaaaaaa-0000-0000-0000-000000000002'), 'none', 'Alice unblocks Bob');

-- ===== Direct table access ==========================================================
select throws_ok($$ select * from public.friendship $$, '42501', null, 'friendships are not readable directly');
select throws_ok($$ select * from public.user_block $$, '42501', null, 'blocks are not readable directly');
select throws_ok($$ insert into public.friendship (user_low, user_high, requester_id)
                    values ('11111111-1111-1111-1111-111111111111', '33333333-3333-3333-3333-333333333333',
                            '11111111-1111-1111-1111-111111111111') $$,
                 '42501', null, 'friendships cannot be written directly');
select throws_ok($$ select public._are_friends('11111111-1111-1111-1111-111111111111', '22222222-2222-2222-2222-222222222222') $$,
                 '42501', null, 'internal helpers are not callable');

set local role anon;
select throws_ok($$ select * from public.search_profiles('Alice_1') $$, '42501', null, 'anon cannot search');

reset role;
select is((select count(*)::int from public.friendship
            where user_low = '22222222-2222-2222-2222-222222222222' and user_high = '33333333-3333-3333-3333-333333333333'),
          1, 'there is exactly one row for the Bob–Carol pair');

select * from finish();
rollback;

-- Authorization checks: user isolation, ownership immutability, idempotent writes,
-- anonymous access and cascade behaviour.
begin;
create extension if not exists pgtap with schema extensions;

select plan(32);

-- Fixtures (as the migration owner) --------------------------------------------------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@example.test'),
  ('22222222-2222-2222-2222-222222222222', 'bob@example.test');

select is((select count(*)::int from public.profile), 2, 'profile row is created for each new auth user');

-- ===== Alice ========================================================================
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select lives_ok($$
  insert into public.habit (id, category_id, title, updated_at)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'health', 'Drink water', '2000-01-01')
$$, 'owner can insert a habit without sending user_id');

select is((select user_id from public.habit where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
          '11111111-1111-1111-1111-111111111111'::uuid, 'user_id defaults to auth.uid()');

select ok((select updated_at > '2001-01-01' from public.habit
           where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
          'client-supplied updated_at is overridden by the server');

select lives_ok($$
  insert into public.habit_completion (id, habit_id, completed_on)
  values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-01')
$$, 'owner can complete own habit');

select throws_ok($$
  insert into public.habit_completion (id, habit_id, completed_on)
  values ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-01')
$$, '23505', null, 'a second completion for the same day is rejected');

select lives_ok($$
  insert into public.habit_completion (id, habit_id, completed_on)
  values ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', '2026-10-01')
  on conflict (habit_id, completed_on) do update set deleted_at = excluded.deleted_at
$$, 'retrying the same completion as an upsert succeeds');

select is((select count(*)::int from public.habit_completion), 1, 'retries do not create duplicates');

select lives_ok($$
  insert into public.habit (id, category_id, title)
  values ('aaaaaaaa-0000-0000-0000-000000000001', 'sport', 'Drink more water')
  on conflict (id) do update set title = excluded.title, category_id = excluded.category_id
$$, 'owner can upsert own habit');

select throws_ok($$
  insert into public.habit (category_id, title, user_id)
  values ('health', 'Forged', '22222222-2222-2222-2222-222222222222')
$$, '42501', null, 'cannot insert a habit on behalf of another user');

select throws_ok($$
  update public.habit set user_id = '22222222-2222-2222-2222-222222222222'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001'
$$, '42501', null, 'cannot transfer a habit to another user');

select throws_ok($$
  update public.habit_completion set user_id = '22222222-2222-2222-2222-222222222222'
$$, '42501', null, 'cannot transfer a completion to another user');

select throws_ok($$ delete from public.habit $$, '42501', null,
                 'clients cannot hard-delete habits (tombstones only)');

select throws_ok($$ delete from public.habit_completion $$, '42501', null,
                 'clients cannot hard-delete completions (tombstones only)');

select throws_ok($$
  insert into public.habit (category_id, title) values ('no-such-category', 'Bad category')
$$, '23503', null, 'unknown category is rejected');

select throws_ok($$
  insert into public.habit (category_id, title) values ('health', '   ')
$$, '23514', null, 'blank title is rejected');

-- ===== Bob ==========================================================================
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is((select count(*)::int from public.habit), 0, 'other users'' habits are invisible');
select is((select count(*)::int from public.habit_completion), 0, 'other users'' completions are invisible');
select is((select count(*)::int from public.profile), 1, 'only own profile is visible');

select lives_ok($$
  update public.habit set title = 'hacked' where id = 'aaaaaaaa-0000-0000-0000-000000000001'
$$, 'updating another user''s habit is a silent no-op');

select throws_ok($$
  insert into public.habit_completion (habit_id, completed_on)
  values ('aaaaaaaa-0000-0000-0000-000000000001', '2026-10-02')
$$, '23503', null, 'cannot complete another user''s habit under own user_id');

select throws_ok($$
  insert into public.habit_completion (habit_id, completed_on, user_id)
  values ('aaaaaaaa-0000-0000-0000-000000000001', '2026-10-02', '11111111-1111-1111-1111-111111111111')
$$, '42501', null, 'cannot complete another user''s habit under their user_id');

select throws_ok($$ insert into public.profile (id) values ('22222222-2222-2222-2222-222222222222') $$,
                 '42501', null, 'profiles cannot be created by clients');

select throws_ok($$ update public.category set name = 'x' $$, '42501', null,
                 'categories are read-only');

-- ===== Anonymous ====================================================================
reset role;
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select throws_ok($$ select * from public.habit $$, '42501', null, 'anon cannot read habits');
select throws_ok($$ select * from public.habit_completion $$, '42501', null, 'anon cannot read completions');
select is((select count(*)::int from public.category), 7, 'anon can read categories');

-- ===== Alice again: Bob's update had no effect; tombstones are sticky ===============
reset role;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select is((select title from public.habit where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
          'Drink more water', 'habit was not modified by another user');

update public.habit set deleted_at = now() where id = 'aaaaaaaa-0000-0000-0000-000000000001';
update public.habit set deleted_at = null, title = 'Stale offline edit'
  where id = 'aaaaaaaa-0000-0000-0000-000000000001';

select isnt((select deleted_at from public.habit where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
            null, 'a deleted habit cannot be resurrected by a stale edit');

select is((select count(*)::int from public.habit_completion
           where habit_id = 'aaaaaaaa-0000-0000-0000-000000000001' and deleted_at is null),
          0, 'deleting a habit tombstones its completions');

insert into public.habit_completion (habit_id, completed_on)
values ('aaaaaaaa-0000-0000-0000-000000000001', '2026-10-05');

select isnt((select deleted_at from public.habit_completion
             where habit_id = 'aaaaaaaa-0000-0000-0000-000000000001' and completed_on = '2026-10-05'),
            null, 'a late completion of a deleted habit is stored as a tombstone');

-- ===== Account removal cascades =====================================================
reset role;
delete from auth.users where id = '11111111-1111-1111-1111-111111111111';

select is((select count(*)::int from public.habit
           where user_id = '11111111-1111-1111-1111-111111111111'),
          0, 'deleting the auth user removes their data');

select * from finish();
rollback;

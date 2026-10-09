-- Structural checks: RLS is on, constraints and triggers exist.
begin;
create extension if not exists pgtap with schema extensions;

select plan(16);

select ok(relrowsecurity, format('RLS enabled on %s', relname))
from pg_class
where oid in ('public.category'::regclass, 'public.profile'::regclass,
              'public.habit'::regclass, 'public.habit_completion'::regclass)
order by relname;

-- Every table in the exposed schema must have RLS enabled (guards future migrations).
select is(
  (select count(*)::int from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind = 'r' and not c.relrowsecurity),
  0,
  'no table in public schema without RLS'
);

select has_pk('public', 'habit', 'habit has a primary key');
select has_pk('public', 'habit_completion', 'habit_completion has a primary key');
select col_is_unique('public', 'habit_completion', array['habit_id', 'completed_on']::name[],
                     'one completion per habit per day');
select fk_ok('public', 'habit_completion', array['habit_id', 'user_id']::name[],
             'public', 'habit', array['id', 'user_id']::name[],
             'completion references habit of the same owner');
select fk_ok('public', 'habit', 'category_id', 'public', 'category', 'id', 'habit references category');

select has_trigger('public', 'habit', 'habit_set_updated_at', 'habit maintains updated_at');
select has_trigger('public', 'habit_completion', 'habit_completion_set_updated_at',
                   'habit_completion maintains updated_at');
select has_trigger('auth', 'users', 'on_auth_user_created', 'profile is created on sign-up');

select has_index('public', 'habit', 'habit_user_updated_idx', 'habit pull-cursor index');
select has_index('public', 'habit_completion', 'habit_completion_user_updated_idx',
                 'habit_completion pull-cursor index');

select results_eq(
  'select id from public.category order by sort_order',
  array['health', 'sport', 'education', 'selv-development', 'art', 'work', 'money'],
  'reference categories are present'
);

select * from finish();
rollback;

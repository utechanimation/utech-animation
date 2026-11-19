-- Test: the "Before User Created" hook allows UTech student emails and invited
-- staff, and rejects everyone else. The sign-up trigger gives invited staff
-- their role and uses up the invite.
--
-- Supabase Auth runs the hook as the role supabase_auth_admin. The local test
-- user may not switch to that role, so we check its privileges instead, and
-- call the function directly.
begin;
select plan(12);

insert into public.staff_invites (email, role) values
  ('lecturer@utech.edu.jm', 'moderator');

-- ---------- Who may run the hook ----------
select ok(
  has_function_privilege('supabase_auth_admin', 'public.hook_before_user_created(jsonb)', 'execute'),
  'the auth system may run the hook');

select ok(
  has_table_privilege('supabase_auth_admin', 'public.staff_invites', 'select'),
  'the auth system may read staff_invites');

select ok(
  not has_function_privilege('authenticated', 'public.hook_before_user_created(jsonb)', 'execute')
  and not has_function_privilege('anon', 'public.hook_before_user_created(jsonb)', 'execute'),
  'signed-in users and visitors may not run the hook');

-- ---------- What the hook decides ----------
select is(
  public.hook_before_user_created('{"user":{"email":"Student@STUDENTS.utech.edu.jm"}}'),
  '{}'::jsonb,
  'a UTech student email is allowed (case does not matter)');

select is(
  public.hook_before_user_created('{"user":{"email":"lecturer@utech.edu.jm"}}'),
  '{}'::jsonb,
  'an invited staff email is allowed');

select is(
  public.hook_before_user_created('{"user":{"email":"someone@gmail.com"}}')->'error'->>'http_code',
  '403',
  'a non-student email without an invite is rejected with 403');

select is(
  public.hook_before_user_created('{"user":{"email":"someone@gmail.com"}}')->'error'->>'message',
  'Please sign in with your UTech student Microsoft account.',
  'the rejection explains what to do');

select is(
  public.hook_before_user_created('{"user":{"email":"x@students.utech.edu.jm.evil.com"}}')->'error'->>'http_code',
  '403',
  'a look-alike domain is rejected');

select is(
  public.hook_before_user_created('{"user":{}}')->'error'->>'http_code',
  '403',
  'a sign-up with no email is rejected');

-- ---------- Sign-up trigger: the invited lecturer signs up ----------
insert into auth.users (id, email) values
  ('77777777-7777-7777-7777-777777777777', 'Lecturer@utech.edu.jm');

select is(
  (select role from public.profiles where id = '77777777-7777-7777-7777-777777777777'),
  'moderator',
  'the invited lecturer gets the role from the invite');

select isnt(
  (select used_at from public.staff_invites where email = 'lecturer@utech.edu.jm'),
  null,
  'the invite is marked as used');

select is(
  public.hook_before_user_created('{"user":{"email":"lecturer@utech.edu.jm"}}')->'error'->>'http_code',
  '403',
  'a used invite cannot be used again');

select * from finish();
rollback;

-- Test (review follow-up round 2, item 5): who can read which profile.
-- TEMPORARY RULE: a profile is readable only if the person owns an active public
-- portfolio or has an accepted credit on one. Users always read their own
-- profile; moderators read all. Checked as anon and as another student (Bob).
begin;
select plan(28);

-- ---------- Fixtures ----------
-- user1..user11 are the profiles being looked at; Bob looks; the moderator looks.
insert into auth.users (id, email) values
  ('00000000-0000-0000-0000-000000000001', 'user1@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000002', 'user2@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000003', 'user3@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000004', 'user4@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000005', 'user5@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000006', 'user6@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000007', 'user7@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000008', 'user8@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000009', 'user9@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000010', 'user10@students.utech.edu.jm'),
  ('00000000-0000-0000-0000-000000000011', 'user11@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm'),
  ('55555555-5555-5555-5555-555555555555', 'mod@students.utech.edu.jm');
update public.profiles set role = 'moderator' where id = '55555555-5555-5555-5555-555555555555';

insert into public.portfolios (id, user_id, slug, title, status, visibility) values
  ('aaaaaaaa-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000002', 'work-2-a1b2c3d4e5', 'Work 2', 'pending_review', 'public'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000003', 'work-3-a1b2c3d4e5', 'Work 3', 'rejected', 'public'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000004', 'work-4-a1b2c3d4e5', 'Work 4', 'active', 'private'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '00000000-0000-0000-0000-000000000005', 'work-5-a1b2c3d4e5', 'Work 5', 'active', 'unlisted'),
  ('aaaaaaaa-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000006', 'work-6-a1b2c3d4e5', 'Work 6', 'active', 'public'),
  ('aaaaaaaa-0000-0000-0000-000000000007', '00000000-0000-0000-0000-000000000007', 'work-7-a1b2c3d4e5', 'Work 7', 'active', 'public');

-- Credits: user8 accepted, user9 invited, user10 declined (all on user6's live
-- work); user11 accepted on user2's pending work. New credits start as 'invited'
-- (trigger), so the status is set afterwards.
insert into public.portfolio_credits (portfolio_id, profile_id, role) values
  ('aaaaaaaa-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000008',  'Sound'),
  ('aaaaaaaa-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000009',  'Sound'),
  ('aaaaaaaa-0000-0000-0000-000000000006', '00000000-0000-0000-0000-000000000010', 'Sound'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000011', 'Sound');
update public.portfolio_credits set status = 'accepted' where profile_id in ('00000000-0000-0000-0000-000000000008', '00000000-0000-0000-0000-000000000011');
update public.portfolio_credits set status = 'declined' where profile_id = '00000000-0000-0000-0000-000000000010';

-- ---------- As an anonymous visitor ----------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000001' $$,
  'anon: a profile with no portfolio is not readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000002' $$,
  'anon: a pending_review portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000003' $$,
  'anon: a rejected portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000004' $$,
  'anon: a private portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000005' $$,
  'anon: an unlisted-only portfolio does not make the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000006' $$,
  'anon: an active public portfolio makes the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000007' $$,
  'anon: an active public portfolio (before takedown) makes the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000008' $$,
  'anon: an accepted credit on an active public portfolio makes the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000009' $$,
  'anon: an invited credit does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000010' $$,
  'anon: a declined credit does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000011' $$,
  'anon: an accepted credit on a pending portfolio does not make the profile readable');

-- ---------- As another student (Bob) ----------
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000001' $$,
  'student: a profile with no portfolio is not readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000002' $$,
  'student: a pending_review portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000003' $$,
  'student: a rejected portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000004' $$,
  'student: a private portfolio does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000005' $$,
  'student: an unlisted-only portfolio does not make the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000006' $$,
  'student: an active public portfolio makes the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000007' $$,
  'student: an active public portfolio (before takedown) makes the profile readable');

select isnt_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000008' $$,
  'student: an accepted credit on an active public portfolio makes the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000009' $$,
  'student: an invited credit does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000010' $$,
  'student: a declined credit does not make the profile readable');

select is_empty($$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000011' $$,
  'student: an accepted credit on a pending portfolio does not make the profile readable');

select isnt_empty(
  $$ select id from public.profiles where id = '22222222-2222-2222-2222-222222222222' $$,
  'a user always reads their own profile, even with no published work');

-- ---------- After a takedown the profile is hidden again ----------
reset role;
update public.portfolios set status = 'taken_down' where id = 'aaaaaaaa-0000-0000-0000-000000000007';

set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is_empty(
  $$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000007' $$,
  'anon: after a takedown the profile is hidden again');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select is_empty(
  $$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000007' $$,
  'student: after a takedown the profile is hidden again');

-- user7 still reads their own profile.
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000000007","role":"authenticated"}', true);
select isnt_empty(
  $$ select id from public.profiles where id = '00000000-0000-0000-0000-000000000007' $$,
  'the owner still reads their own profile after a takedown');

-- ---------- Moderators read every profile ----------
reset role;
select set_config('test.profile_count', (select count(*)::text from public.profiles), true);
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select is(
  (select count(*) from public.profiles),
  current_setting('test.profile_count')::bigint,
  'a moderator reads every profile');

-- ---------- get_portfolio_by_slug is unchanged ----------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);
select is(
  public.get_portfolio_by_slug('work-5-a1b2c3d4e5')->'owner'->>'id', '00000000-0000-0000-0000-000000000005',
  'an unlisted portfolio opened by its link still shows the owner card');

select * from finish();
rollback;

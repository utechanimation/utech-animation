-- Test (review follow-up round 2):
--   1. decide_appeal refuses (42501) a moderator or admin who owns the portfolio,
--      for approve, deny and the admin override. A different moderator can decide.
--   2. take_down records takedowns.status_before; an approved appeal restores
--      exactly that status (reject -> resubmit -> takedown -> approve ends in
--      pending_review, never active).
--   3. restore_comment and resolve_report refuse the caller's own content.
begin;
select plan(31);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('33333333-3333-3333-3333-333333333333', 'rep@students.utech.edu.jm'),
  ('44444444-4444-4444-4444-444444444444', 'admin-a@students.utech.edu.jm'),
  ('55555555-5555-5555-5555-555555555555', 'mod2@students.utech.edu.jm'),
  ('66666666-6666-6666-6666-666666666666', 'admin-b@students.utech.edu.jm');
update public.profiles set role = 'moderator' where id in ('33333333-3333-3333-3333-333333333333', '55555555-5555-5555-5555-555555555555');
update public.profiles set role = 'admin'     where id in ('44444444-4444-4444-4444-444444444444', '66666666-6666-6666-6666-666666666666');

insert into public.portfolios (id, user_id, slug, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'rep-work-a1b2c3d4e5',      'Rep work',      'active'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '44444444-4444-4444-4444-444444444444', 'admin-work-a1b2c3d4e5',    'Admin work',    'active'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'alice-live-a1b2c3d4e5',    'Alice live',    'active'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'resubmitted-a1b2c3d4e5',   'Resubmitted',   'pending_review'),
  ('aaaaaaaa-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'alice-rejected-a1b2c3d4e5','Alice rejected','rejected');

insert into public.comments (id, portfolio_id, user_id, content, hidden) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'Rep comment',   true),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'Alice comment', true);

insert into public.reports (id, reporter_id, portfolio_id, comment_id, category) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'aaaaaaaa-0000-0000-0000-000000000001', null, 'other'),
  ('dddddddd-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', null, 'cccccccc-0000-0000-0000-000000000001', 'other'),
  ('dddddddd-0000-0000-0000-000000000003', '33333333-3333-3333-3333-333333333333', 'aaaaaaaa-0000-0000-0000-000000000003', null, 'other');

set local role authenticated;

-- mod2 takes down the rep's and admin A's work; both owners appeal.
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select set_config('test.td_rep',   public.take_down('aaaaaaaa-0000-0000-0000-000000000001', 'Check rights')::text, true);
select set_config('test.td_admin', public.take_down('aaaaaaaa-0000-0000-0000-000000000002', 'Check rights')::text, true);

select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select public.submit_appeal(current_setting('test.td_rep')::uuid, 'Licensed');
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select public.submit_appeal(current_setting('test.td_admin')::uuid, 'Licensed');

-- =====================================================================
-- 1. Nobody decides the appeal on their own work
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select throws_ok(
  $$ select public.decide_appeal(current_setting('test.td_rep')::uuid, true) $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot approve the appeal on their own portfolio');
select throws_ok(
  $$ select public.decide_appeal(current_setting('test.td_rep')::uuid, false) $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot deny the appeal on their own portfolio');

select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select throws_ok(
  $$ select public.decide_appeal(current_setting('test.td_admin')::uuid, true) $$,
  '42501', 'You cannot moderate your own work',
  'an admin cannot approve the appeal on their own portfolio');

-- A different moderator decides both: approve the rep's, deny admin A's.
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select lives_ok(
  $$ select public.decide_appeal(current_setting('test.td_rep')::uuid, true) $$,
  'a different moderator can approve the rep''s appeal');
select lives_ok(
  $$ select public.decide_appeal(current_setting('test.td_admin')::uuid, false) $$,
  'a different moderator can deny admin A''s appeal');

-- Admin override of a denied appeal: not on your own work.
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select throws_ok(
  $$ select public.decide_appeal(current_setting('test.td_admin')::uuid, true) $$,
  '42501', 'You cannot moderate your own work',
  'an admin cannot override the denied appeal on their own portfolio');

reset role;
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  'denied_appeal', 'admin A''s portfolio stays locked');
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);
select lives_ok(
  $$ select public.decide_appeal(current_setting('test.td_admin')::uuid, true) $$,
  'a different admin can override the denied appeal');

reset role;
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'active', 'the rep''s portfolio is active again');
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000002'),
  'active', 'admin A''s portfolio is active after the override');
set local role authenticated;

-- =====================================================================
-- 2. status_before is recorded and restored exactly
-- =====================================================================
-- Path: pending_review -> rejected -> resubmitted -> taken down -> appeal approved.
-- reviewed_at is set by the rejection, so the old reviewed_at rule would have
-- made this 'active'. It must end in 'pending_review'.
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select lives_ok($$ select public.reject_portfolio('aaaaaaaa-0000-0000-0000-000000000004', 'Add a description') $$,
  'moderator rejects the portfolio');

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$ select public.resubmit_portfolio('aaaaaaaa-0000-0000-0000-000000000004') $$,
  'owner resubmits it');

select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select set_config('test.td_resub',    public.take_down('aaaaaaaa-0000-0000-0000-000000000004', 'Check rights')::text, true);
select set_config('test.td_active',   public.take_down('aaaaaaaa-0000-0000-0000-000000000003', 'Check rights')::text, true);
select set_config('test.td_rejected', public.take_down('aaaaaaaa-0000-0000-0000-000000000005', 'Check rights')::text, true);

reset role;
select is(
  (select status_before from public.takedowns where id = current_setting('test.td_resub')::uuid),
  'pending_review', 'takedown of resubmitted work records status_before = pending_review');
select is(
  (select status_before from public.takedowns where id = current_setting('test.td_active')::uuid),
  'active', 'takedown of live work records status_before = active');
select is(
  (select status_before from public.takedowns where id = current_setting('test.td_rejected')::uuid),
  'rejected', 'takedown of rejected work records status_before = rejected');
set local role authenticated;

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select public.submit_appeal(current_setting('test.td_resub')::uuid,    'Please review');
select public.submit_appeal(current_setting('test.td_active')::uuid,   'Please review');
select public.submit_appeal(current_setting('test.td_rejected')::uuid, 'Please review');

select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select lives_ok($$ select public.decide_appeal(current_setting('test.td_resub')::uuid,    true) $$, 'appeal approved (resubmitted)');
select lives_ok($$ select public.decide_appeal(current_setting('test.td_active')::uuid,   true) $$, 'appeal approved (active)');
select lives_ok($$ select public.decide_appeal(current_setting('test.td_rejected')::uuid, true) $$, 'appeal approved (rejected)');

reset role;
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  'pending_review', 'reject -> resubmit -> takedown -> appeal approved ends in pending_review, not active');
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'active', 'active -> takedown -> appeal approved -> active');
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000005'),
  'rejected', 'rejected -> takedown -> appeal approved -> rejected');

-- The table only accepts the three normal states.
select throws_ok(
  $$ insert into public.takedowns (portfolio_id, reason, status_before)
     values ('aaaaaaaa-0000-0000-0000-000000000003', 'x', 'taken_down') $$,
  '23514', null, 'status_before cannot be taken_down');
select throws_ok(
  $$ insert into public.takedowns (portfolio_id, reason)
     values ('aaaaaaaa-0000-0000-0000-000000000003', 'x') $$,
  '23502', null, 'status_before is required');
set local role authenticated;

-- =====================================================================
-- 3. No restoring your own comment, no closing reports on your own work
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select throws_ok(
  $$ select public.restore_comment('cccccccc-0000-0000-0000-000000000001') $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot restore their own hidden comment');
select throws_ok(
  $$ select public.resolve_report('dddddddd-0000-0000-0000-000000000001', 'dismissed') $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot close a report about their own portfolio');
select throws_ok(
  $$ select public.resolve_report('dddddddd-0000-0000-0000-000000000002', 'dismissed') $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot close a report about their own comment');
select lives_ok(
  $$ select public.restore_comment('cccccccc-0000-0000-0000-000000000002') $$,
  'a moderator can restore someone else''s comment');
select lives_ok(
  $$ select public.resolve_report('dddddddd-0000-0000-0000-000000000003', 'reviewed') $$,
  'a moderator can close a report they filed about someone else''s work');

select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
select lives_ok(
  $$ select public.restore_comment('cccccccc-0000-0000-0000-000000000001') $$,
  'a different moderator can restore the rep''s comment');
select lives_ok(
  $$ select public.resolve_report('dddddddd-0000-0000-0000-000000000001', 'dismissed') $$,
  'a different moderator can close the report on the rep''s portfolio');

reset role;
select is(
  (select hidden from public.comments where id = 'cccccccc-0000-0000-0000-000000000001'),
  false, 'the rep''s comment was restored by the other moderator');

select * from finish();
rollback;

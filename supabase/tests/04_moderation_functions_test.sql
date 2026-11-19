-- Test: a student cannot call the moderator functions; a moderator can, each
-- call writes audit_log, and the student-side functions (counter-statement,
-- appeal, resubmit) work only for the owner and only in the right state.
begin;
select plan(38);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm'),
  ('33333333-3333-3333-3333-333333333333', 'mod@students.utech.edu.jm'),
  ('44444444-4444-4444-4444-444444444444', 'admin@students.utech.edu.jm');
update public.profiles set role = 'moderator' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set role = 'admin'     where id = '44444444-4444-4444-4444-444444444444';

-- P1: new portfolio waiting for review (with one pending image)
-- P2: another new portfolio, to be rejected
-- P3: live portfolio with a pending replacement image
insert into public.portfolios (id, user_id, slug, title, status, has_pending_media) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'p1', 'P1', 'pending_review', false),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'p2', 'P2', 'pending_review', false),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'p3', 'P3', 'active',         true);

insert into public.portfolio_items (id, portfolio_id, type, storage_key, review_state, replaces_item_id) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'image', 'p1img', 'pending', null),
  ('bbbbbbbb-0000-0000-0000-000000000030', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'old',   'live',    null),
  ('bbbbbbbb-0000-0000-0000-000000000031', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'new',   'pending', 'bbbbbbbb-0000-0000-0000-000000000030');

insert into public.comments (id, portfolio_id, user_id, content, hidden) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'Hidden one', true),
  ('cccccccc-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000003', '22222222-2222-2222-2222-222222222222', 'To delete', false);

insert into public.reports (id, reporter_id, portfolio_id, category) values
  ('dddddddd-0000-0000-0000-000000000001', '22222222-2222-2222-2222-222222222222', 'aaaaaaaa-0000-0000-0000-000000000003', 'copyright');

set local role authenticated;

-- =====================================================================
-- 1. A student (Alice) cannot call any moderator function (42501)
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

select throws_ok($$ select public.approve_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$, '42501', null, 'student cannot approve_portfolio');
select throws_ok($$ select public.reject_portfolio('aaaaaaaa-0000-0000-0000-000000000001', 'no') $$, '42501', null, 'student cannot reject_portfolio');
select throws_ok($$ select public.approve_item('bbbbbbbb-0000-0000-0000-000000000031') $$, '42501', null, 'student cannot approve_item');
select throws_ok($$ select public.issue_warning('aaaaaaaa-0000-0000-0000-000000000003', 'x', 3) $$, '42501', null, 'student cannot issue_warning');
select throws_ok($$ select public.take_down('aaaaaaaa-0000-0000-0000-000000000003', 'x') $$, '42501', null, 'student cannot take_down');
select throws_ok($$ select public.decide_appeal(gen_random_uuid(), true) $$, '42501', null, 'student cannot decide_appeal');
select throws_ok($$ select public.resolve_report('dddddddd-0000-0000-0000-000000000001', 'dismissed') $$, '42501', null, 'student cannot resolve_report');
select throws_ok($$ select public.restore_comment('cccccccc-0000-0000-0000-000000000001') $$, '42501', null, 'student cannot restore_comment');
select throws_ok($$ select public.delete_comment('cccccccc-0000-0000-0000-000000000002') $$, '42501', null, 'student cannot delete_comment');
select throws_ok($$ select public.set_user_role('11111111-1111-1111-1111-111111111111', 'admin') $$, '42501', null, 'student cannot set_user_role');

-- =====================================================================
-- 2. A moderator can review work
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select lives_ok($$ select public.approve_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$, 'moderator approves P1');
select is((select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'), 'active', 'P1 is now active');
select is((select review_state from public.portfolio_items where id = 'bbbbbbbb-0000-0000-0000-000000000001'), 'live', 'P1''s media went live with it');
select throws_ok($$ select public.approve_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$, 'P0001', null, 'approving twice is refused');

select throws_ok($$ select public.reject_portfolio('aaaaaaaa-0000-0000-0000-000000000002', '  ') $$, 'P0001', 'A reason is required', 'reject needs a reason');
select lives_ok($$ select public.reject_portfolio('aaaaaaaa-0000-0000-0000-000000000002', 'Please credit your team') $$, 'moderator rejects P2 with a reason');
select is((select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000002'), 'rejected', 'P2 is now rejected');

select lives_ok($$ select public.approve_item('bbbbbbbb-0000-0000-0000-000000000031') $$, 'moderator approves the replacement image on P3');
select is((select count(*)::int from public.portfolio_items where id = 'bbbbbbbb-0000-0000-0000-000000000030'), 0, 'the replaced image is deleted');
select is((select has_pending_media from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000003'), false, 'P3 has no pending media left');

-- =====================================================================
-- 3. Warnings, takedowns and appeals
-- =====================================================================
select lives_ok($$ select public.issue_warning('aaaaaaaa-0000-0000-0000-000000000003', 'Missing credits', 7) $$, 'moderator warns P3');
select lives_ok($$ select public.take_down('aaaaaaaa-0000-0000-0000-000000000003', 'Copyright music') $$, 'moderator takes P3 down');

-- Remember the new ids (the moderator can read them) so other users can refer to them.
select set_config('test.warning_id',  (select id::text from public.warnings  limit 1), true);
select set_config('test.takedown_id', (select id::text from public.takedowns limit 1), true);

-- Alice (the owner) answers the warning and appeals the takedown, once.
select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$ select public.submit_counter_statement(current_setting('test.warning_id')::uuid, 'I credited them') $$, 'owner submits a counter-statement');
select lives_ok($$ select public.submit_appeal(current_setting('test.takedown_id')::uuid, 'The music is licensed') $$, 'owner appeals the takedown');
select throws_ok($$ select public.submit_appeal(current_setting('test.takedown_id')::uuid, 'Again') $$, 'P0001', null, 'only one appeal per takedown');
select is((select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000003'), 'pending_appeal', 'P3 is pending appeal');

-- Bob (not the owner) cannot appeal.
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
select throws_ok($$ select public.submit_counter_statement(current_setting('test.warning_id')::uuid, 'x') $$, '42501', null, 'non-owner cannot answer a warning');

-- The moderator denies; only an admin can override that.
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select lives_ok($$ select public.decide_appeal(current_setting('test.takedown_id')::uuid, false) $$, 'moderator denies the appeal');
select throws_ok($$ select public.decide_appeal(current_setting('test.takedown_id')::uuid, true) $$, 'P0001', null, 'a moderator cannot override a denied appeal');

select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select lives_ok($$ select public.decide_appeal(current_setting('test.takedown_id')::uuid, true) $$, 'an admin overrides and approves');

-- =====================================================================
-- 4. Reports, comments, roles, resubmit
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select lives_ok($$ select public.resolve_report('dddddddd-0000-0000-0000-000000000001', 'actioned') $$, 'moderator resolves a report');
select lives_ok($$ select public.restore_comment('cccccccc-0000-0000-0000-000000000001') $$, 'moderator restores a hidden comment');
select lives_ok($$ select public.delete_comment('cccccccc-0000-0000-0000-000000000002') $$, 'moderator deletes a comment');
select throws_ok($$ select public.set_user_role('22222222-2222-2222-2222-222222222222', 'moderator') $$, '42501', null, 'a moderator cannot change roles');

select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select lives_ok($$ select public.set_user_role('22222222-2222-2222-2222-222222222222', 'moderator') $$, 'an admin promotes the student rep');

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$ select public.resubmit_portfolio('aaaaaaaa-0000-0000-0000-000000000002') $$, 'owner resubmits the rejected P2');

-- =====================================================================
-- 5. Every call above wrote exactly one audit_log row, with who did it
-- =====================================================================
reset role;
select results_eq(
  $$ select action from public.audit_log order by action $$,
  array['approve_appeal', 'approve_item', 'approve_portfolio', 'delete_comment', 'deny_appeal',
        'issue_warning', 'reject_portfolio', 'resolve_report', 'restore_comment',
        'resubmit_portfolio', 'set_user_role', 'submit_appeal', 'submit_counter_statement',
        'take_down'],
  'each successful call wrote one audit_log row (and refused calls wrote none)');

select is_empty(
  $$ select id from public.audit_log where actor_id is null $$,
  'every audit_log row records who did it');

select * from finish();
rollback;

-- Test (review follow-up):
--   1. A moderator cannot approve their own portfolio or their own media (42501).
--   2. When an approved item replaces the cover, the new item becomes the cover.
--   3. An approved appeal restores the status the portfolio had before the
--      takedown (takedowns.status_before). More cases in 10_appeal_rules_test.sql.
begin;
select plan(18);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('33333333-3333-3333-3333-333333333333', 'rep@students.utech.edu.jm'),
  ('44444444-4444-4444-4444-444444444444', 'admin@students.utech.edu.jm');
-- The student rep is a moderator who also posts work.
update public.profiles set role = 'moderator' where id = '33333333-3333-3333-3333-333333333333';
update public.profiles set role = 'admin'     where id = '44444444-4444-4444-4444-444444444444';

insert into public.portfolios (id, user_id, slug, title, status, reviewed_at) values
  -- the moderator's own work: one new, one live with a pending edit
  ('aaaaaaaa-0000-0000-0000-000000000001', '33333333-3333-3333-3333-333333333333', 'rep-new-a1b2c3d4e5',     'Rep new',     'pending_review', null),
  ('aaaaaaaa-0000-0000-0000-000000000002', '33333333-3333-3333-3333-333333333333', 'rep-live-a1b2c3d4e5',    'Rep live',    'active',         now()),
  -- Alice's live portfolio whose cover is being replaced
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'cover-swap-a1b2c3d4e5',  'Cover swap',  'active',         now()),
  -- Alice's portfolios for the appeal cases
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'was-live-a1b2c3d4e5',    'Was live',    'active',         now()),
  ('aaaaaaaa-0000-0000-0000-000000000005', '11111111-1111-1111-1111-111111111111', 'never-live-a1b2c3d4e5',  'Never live',  'pending_review', null);

insert into public.portfolio_items (id, portfolio_id, type, storage_key, review_state, replaces_item_id) values
  ('bbbbbbbb-0000-0000-0000-000000000021', 'aaaaaaaa-0000-0000-0000-000000000002', 'image', 'rep-edit',  'pending', null),
  ('bbbbbbbb-0000-0000-0000-000000000030', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'old-cover', 'live',    null),
  ('bbbbbbbb-0000-0000-0000-000000000031', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'new-cover', 'pending', 'bbbbbbbb-0000-0000-0000-000000000030'),
  ('bbbbbbbb-0000-0000-0000-000000000032', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'old-other', 'live',    null),
  ('bbbbbbbb-0000-0000-0000-000000000033', 'aaaaaaaa-0000-0000-0000-000000000003', 'image', 'new-other', 'pending', 'bbbbbbbb-0000-0000-0000-000000000032');

update public.portfolios set cover_item_id = 'bbbbbbbb-0000-0000-0000-000000000030'
 where id = 'aaaaaaaa-0000-0000-0000-000000000003';

set local role authenticated;

-- =====================================================================
-- 1. No self-approval
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select throws_ok(
  $$ select public.approve_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot approve their own portfolio');

select throws_ok(
  $$ select public.approve_item('bbbbbbbb-0000-0000-0000-000000000021') $$,
  '42501', 'You cannot moderate your own work',
  'a moderator cannot approve their own media');

select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'pending_review', 'their portfolio is still waiting for review');

select is(
  (select review_state from public.portfolio_items where id = 'bbbbbbbb-0000-0000-0000-000000000021'),
  'pending', 'their media is still pending');

-- Another moderator (here the admin) may approve it.
select set_config('request.jwt.claims', '{"sub":"44444444-4444-4444-4444-444444444444","role":"authenticated"}', true);
select lives_ok(
  $$ select public.approve_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$,
  'a different moderator can approve the rep''s portfolio');

-- =====================================================================
-- 2. Replacing the cover moves the cover to the new item
-- =====================================================================
select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);

select lives_ok(
  $$ select public.approve_item('bbbbbbbb-0000-0000-0000-000000000031') $$,
  'moderator approves the new cover image');

select is(
  (select cover_item_id from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'bbbbbbbb-0000-0000-0000-000000000031'::uuid,
  'the new item is now the cover');

select is_empty(
  $$ select id from public.portfolio_items where id = 'bbbbbbbb-0000-0000-0000-000000000030' $$,
  'the old cover item is deleted');

select lives_ok(
  $$ select public.approve_item('bbbbbbbb-0000-0000-0000-000000000033') $$,
  'moderator approves a replacement that is not the cover');

select is(
  (select cover_item_id from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000003'),
  'bbbbbbbb-0000-0000-0000-000000000031'::uuid,
  'replacing a non-cover item leaves the cover alone');

-- =====================================================================
-- 3. An approved appeal restores the status from before the takedown
-- =====================================================================
select lives_ok($$ select public.take_down('aaaaaaaa-0000-0000-0000-000000000004', 'Check music rights') $$, 'take down an active portfolio');
select lives_ok($$ select public.take_down('aaaaaaaa-0000-0000-0000-000000000005', 'Check music rights') $$, 'take down a pending_review portfolio');
select set_config('test.td_was_live',
  (select id::text from public.takedowns where portfolio_id = 'aaaaaaaa-0000-0000-0000-000000000004'), true);
select set_config('test.td_never_live',
  (select id::text from public.takedowns where portfolio_id = 'aaaaaaaa-0000-0000-0000-000000000005'), true);

select set_config('request.jwt.claims', '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
select lives_ok($$ select public.submit_appeal(current_setting('test.td_was_live')::uuid,   'Licensed') $$, 'owner appeals (was active)');
select lives_ok($$ select public.submit_appeal(current_setting('test.td_never_live')::uuid, 'Licensed') $$, 'owner appeals (was pending_review)');

select set_config('request.jwt.claims', '{"sub":"33333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
select lives_ok($$ select public.decide_appeal(current_setting('test.td_was_live')::uuid,   true) $$, 'appeal approved (was active)');
select lives_ok($$ select public.decide_appeal(current_setting('test.td_never_live')::uuid, true) $$, 'appeal approved (was pending_review)');

select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000004'),
  'active', 'active -> takedown -> appeal approved -> active');

select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000005'),
  'pending_review', 'pending_review -> takedown -> appeal approved -> pending_review (not live)');

select * from finish();
rollback;

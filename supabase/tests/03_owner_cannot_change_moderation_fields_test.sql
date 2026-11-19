-- Test: a student cannot set status, review_state, role, storage_used or hidden
-- on their own rows, and cannot write moderation tables - directly or via update.
-- They CAN still edit their own text fields - but not while the portfolio is
-- taken down.
begin;
select plan(26);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm');

insert into public.portfolios (id, user_id, slug, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'taken-a1b2c3d4e5', 'Taken down', 'taken_down'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111',
   'live-a1b2c3d4e5', 'Live', 'active');

insert into public.portfolio_items (id, portfolio_id, type, storage_key, review_state) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002', 'image', 'k1', 'pending'),
  ('bbbbbbbb-0000-0000-0000-000000000002', 'aaaaaaaa-0000-0000-0000-000000000001', 'image', 'k2', 'live');

insert into public.comments (id, portfolio_id, user_id, content, hidden) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002',
   '11111111-1111-1111-1111-111111111111', 'Hidden by moderators', true);

insert into public.reports (id, reporter_id, portfolio_id, category) values
  ('dddddddd-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'aaaaaaaa-0000-0000-0000-000000000002', 'other');

-- ---------- Act as Alice, the owner ----------
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

-- 42501 = permission denied (no column grant), so the update is refused outright.
select throws_ok(
  $$ update public.portfolios set status = 'active' where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  '42501', null, 'owner cannot set portfolios.status (e.g. undo a takedown)');

select throws_ok(
  $$ update public.portfolios set reviewed_by = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'owner cannot set portfolios.reviewed_by');

select throws_ok(
  $$ update public.portfolios set cover_item_id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  '42501', null, 'owner cannot change the cover without review');

select throws_ok(
  $$ update public.portfolio_items set review_state = 'live' where id = 'bbbbbbbb-0000-0000-0000-000000000001' $$,
  '42501', null, 'owner cannot set portfolio_items.review_state');

select throws_ok(
  $$ insert into public.portfolio_items (portfolio_id, type, storage_key, review_state)
     values ('aaaaaaaa-0000-0000-0000-000000000002', 'image', 'k9', 'live') $$,
  '42501', null, 'owner cannot insert an already-live item');

select throws_ok(
  $$ update public.profiles set role = 'admin' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'owner cannot set profiles.role');

select throws_ok(
  $$ update public.profiles set storage_used = 0 where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'owner cannot set profiles.storage_used');

select throws_ok(
  $$ update public.profiles set status = 'alumni' where id = '11111111-1111-1111-1111-111111111111' $$,
  '42501', null, 'owner cannot set profiles.status');

select throws_ok(
  $$ update public.comments set hidden = false where id = 'cccccccc-0000-0000-0000-000000000001' $$,
  '42501', null, 'author cannot un-hide their own hidden comment');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title, status)
     values ('11111111-1111-1111-1111-111111111111', 'sneaky-a1b2c3d4e5', 'Sneaky', 'active') $$,
  '42501', null, 'owner cannot create a portfolio that is already active');

select throws_ok(
  $$ update public.reports set status = 'dismissed' where id = 'dddddddd-0000-0000-0000-000000000001' $$,
  '42501', null, 'reporter cannot change a report status');

select throws_ok(
  $$ insert into public.takedowns (portfolio_id, reason) values ('aaaaaaaa-0000-0000-0000-000000000002', 'x') $$,
  '42501', null, 'student cannot write takedowns directly');

select throws_ok(
  $$ update public.takedowns set appeal_status = 'approved' $$,
  '42501', null, 'student cannot approve their own appeal directly');

select throws_ok(
  $$ insert into public.audit_log (action, target_type) values ('fake', 'portfolio') $$,
  '42501', null, 'student cannot write the audit log');

-- Allowed: text edits on their own portfolio go live at once.
select results_eq(
  $$ update public.portfolios set title = 'New title', visibility = 'unlisted'
     where id = 'aaaaaaaa-0000-0000-0000-000000000002' returning title $$,
  array['New title'],
  'owner CAN edit title and visibility of their own portfolio');

select lives_ok(
  $$ insert into public.portfolio_tags (portfolio_id, tag_id)
     select 'aaaaaaaa-0000-0000-0000-000000000002', id from public.tags where name = 'Illustration' $$,
  'owner CAN tag their own live portfolio');

select lives_ok(
  $$ insert into public.portfolio_credits (portfolio_id, external_name, role)
     values ('aaaaaaaa-0000-0000-0000-000000000002', 'Sam (sound design)', 'Sound') $$,
  'owner CAN credit someone on their own live portfolio');

select results_eq(
  $$ update public.portfolio_items set position = 5
     where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning position $$,
  array[5],
  'owner CAN reorder items on their own live portfolio');

-- Not allowed: any owner edit while the portfolio is taken down (review item 4).
select is_empty(
  $$ update public.portfolios set title = 'Swapped'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' returning id $$,
  'owner cannot edit a taken-down portfolio');

select is_empty(
  $$ delete from public.portfolios
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' returning id $$,
  'owner cannot delete a taken-down portfolio');

select throws_ok(
  $$ insert into public.portfolio_tags (portfolio_id, tag_id)
     select 'aaaaaaaa-0000-0000-0000-000000000001', id from public.tags where name = 'Illustration' $$,
  '42501', null,
  'owner cannot change tags on a taken-down portfolio');

select throws_ok(
  $$ insert into public.portfolio_credits (portfolio_id, external_name, role)
     values ('aaaaaaaa-0000-0000-0000-000000000001', 'Someone', 'Art') $$,
  '42501', null,
  'owner cannot change credits on a taken-down portfolio');

select is_empty(
  $$ update public.portfolio_items set position = 9
     where id = 'bbbbbbbb-0000-0000-0000-000000000002' returning id $$,
  'owner cannot reorder items on a taken-down portfolio');

reset role;
select is(
  (select status from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'taken_down',
  'the taken-down portfolio is still taken down');

select is(
  (select title from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'Taken down',
  'the taken-down portfolio''s title is unchanged');

select isnt(
  (select position from public.portfolio_items where id = 'bbbbbbbb-0000-0000-0000-000000000002'),
  9,
  'the taken-down portfolio''s item order is unchanged');

select * from finish();
rollback;

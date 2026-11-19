-- Test: a different student cannot read or edit another student's pending
-- portfolio, its items, its tags or its private files.
begin;
select plan(10);

-- ---------- Fixtures ----------
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm');

insert into public.portfolios (id, user_id, slug, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111',
   'alice-pending-a1b2c3d4e5', 'Alice pending', 'pending_review');

insert into public.portfolio_items (id, portfolio_id, type, storage_key, review_state) values
  ('bbbbbbbb-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001', 'image', 'k1', 'pending');

insert into storage.objects (bucket_id, name) values
  ('media-private', '11111111-1111-1111-1111-111111111111/pending.webp');

-- ---------- Act as Bob (a different student) ----------
select set_config('request.jwt.claims',
  '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
set local role authenticated;

select is_empty(
  $$ select id from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'another student cannot read a pending portfolio');

select is_empty(
  $$ select id from public.portfolio_items where portfolio_id = 'aaaaaaaa-0000-0000-0000-000000000001' $$,
  'another student cannot read items of a pending portfolio');

select is_empty(
  $$ select name from storage.objects where bucket_id = 'media-private' $$,
  'another student cannot read someone else''s private files');

select is_empty(
  $$ update public.portfolios set title = 'Hacked'
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' returning id $$,
  'another student cannot edit the title of someone else''s portfolio');

select is_empty(
  $$ update public.portfolio_items set position = 9
     where id = 'bbbbbbbb-0000-0000-0000-000000000001' returning id $$,
  'another student cannot reorder someone else''s items');

select is_empty(
  $$ delete from public.portfolios
     where id = 'aaaaaaaa-0000-0000-0000-000000000001' returning id $$,
  'another student cannot delete someone else''s portfolio');

select throws_ok(
  $$ insert into public.portfolio_tags (portfolio_id, tag_id)
     select 'aaaaaaaa-0000-0000-0000-000000000001', id from public.tags limit 1 $$,
  '42501', null,
  'another student cannot add tags to someone else''s portfolio');

select throws_ok(
  $$ insert into public.portfolios (user_id, slug, title)
     values ('11111111-1111-1111-1111-111111111111', 'fake-a1b2c3d4e5', 'Posing as Alice') $$,
  '42501', null,
  'a student cannot create a portfolio in someone else''s name');

select throws_ok(
  $$ select public.resubmit_portfolio('aaaaaaaa-0000-0000-0000-000000000001') $$,
  '42501', null,
  'another student cannot resubmit someone else''s portfolio');

-- ---------- Check, as the database owner, that nothing changed ----------
reset role;
select is(
  (select title from public.portfolios where id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  'Alice pending',
  'the pending portfolio is unchanged');

select * from finish();
rollback;

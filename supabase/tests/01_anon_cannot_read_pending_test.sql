-- Test: an anonymous visitor cannot read pending or rejected work, its items,
-- or private storage objects - but can read approved public work.
-- Run with: supabase test db   (everything is rolled back at the end)
-- (The pgtap extension is already installed in the local Supabase database.)
begin;
select plan(11);

-- ---------- Fixtures (created as the database owner, bypassing RLS) ----------
-- Inserting into auth.users runs the sign-up trigger, which creates the profile.
insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm');

insert into public.portfolios (id, user_id, slug, title, status, visibility) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'pending-work',  'Pending',  'pending_review', 'public'),
  ('aaaaaaaa-0000-0000-0000-000000000002', '11111111-1111-1111-1111-111111111111', 'rejected-work', 'Rejected', 'rejected',       'public'),
  ('aaaaaaaa-0000-0000-0000-000000000003', '11111111-1111-1111-1111-111111111111', 'live-work',     'Live',     'active',         'public'),
  ('aaaaaaaa-0000-0000-0000-000000000004', '11111111-1111-1111-1111-111111111111', 'unlisted-work', 'Unlisted', 'active',         'unlisted');

insert into public.portfolio_items (portfolio_id, type, storage_key, review_state) values
  ('aaaaaaaa-0000-0000-0000-000000000001', 'image', 'k1', 'pending'),
  ('aaaaaaaa-0000-0000-0000-000000000002', 'image', 'k2', 'pending'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'image', 'k3', 'live'),
  ('aaaaaaaa-0000-0000-0000-000000000003', 'image', 'k4', 'pending');  -- pending edit on live work

insert into storage.objects (bucket_id, name) values
  ('media-private', '11111111-1111-1111-1111-111111111111/pending.webp');

-- ---------- Act as an anonymous visitor ----------
set local role anon;
select set_config('request.jwt.claims', '{"role":"anon"}', true);

select is_empty(
  $$ select id from public.portfolios where status in ('pending_review', 'rejected') $$,
  'anon cannot read pending_review or rejected portfolios');

select results_eq(
  $$ select slug from public.portfolios order by slug $$,
  array['live-work'],
  'anon sees only the active public portfolio (unlisted is not listed)');

select is_empty(
  $$ select id from public.portfolio_items
     where portfolio_id in ('aaaaaaaa-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000002') $$,
  'anon cannot read items of pending or rejected portfolios');

select results_eq(
  $$ select storage_key from public.portfolio_items $$,
  array['k3'],
  'anon sees only live items of the live portfolio, not its pending edit');

select is_empty(
  $$ select name from storage.objects where bucket_id = 'media-private' $$,
  'anon cannot read private storage objects');

select is(
  public.get_portfolio_by_slug('pending-work'), null,
  'get_portfolio_by_slug returns nothing for pending work');

select is(
  public.get_portfolio_by_slug('rejected-work'), null,
  'get_portfolio_by_slug returns nothing for rejected work');

select is(
  public.get_portfolio_by_slug('unlisted-work')->'portfolio'->>'title', 'Unlisted',
  'get_portfolio_by_slug opens an unlisted portfolio by its exact slug');

select is(
  jsonb_array_length(public.get_portfolio_by_slug('live-work')->'items'), 1,
  'get_portfolio_by_slug returns only live items');

select throws_ok(
  $$ select storage_used from public.profiles $$,
  '42501', null,
  'anon cannot read storage_used');

select throws_ok(
  $$ select * from public.audit_log $$,
  '42501', null,
  'anon cannot read the audit log');

select * from finish();
rollback;

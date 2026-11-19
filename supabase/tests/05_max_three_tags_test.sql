-- Test: a portfolio can have at most 3 tags; a fourth is rejected.
begin;
select plan(3);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm');
insert into public.portfolios (id, user_id, slug, title) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'tagged', 'Tagged');

-- Act as the owner, who is allowed to tag their own portfolio.
select set_config('request.jwt.claims',
  '{"sub":"11111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
set local role authenticated;

select lives_ok(
  $$ insert into public.portfolio_tags (portfolio_id, tag_id)
     select 'aaaaaaaa-0000-0000-0000-000000000001', id from public.tags
     where name in ('3D Modelling', 'Character Design', 'Illustration') $$,
  'three tags are accepted');

select throws_ok(
  $$ insert into public.portfolio_tags (portfolio_id, tag_id)
     select 'aaaaaaaa-0000-0000-0000-000000000001', id from public.tags
     where name = 'Video Editing' $$,
  'P0001', 'A portfolio can have at most 3 tags',
  'a fourth tag is rejected');

select is(
  (select count(*)::int from public.portfolio_tags
   where portfolio_id = 'aaaaaaaa-0000-0000-0000-000000000001'),
  3, 'the portfolio still has exactly 3 tags');

select * from finish();
rollback;

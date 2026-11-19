-- Test: three reports from three different users hide a comment; two do not;
-- the same user reporting twice does not count twice.
begin;
select plan(6);

insert into auth.users (id, email) values
  ('11111111-1111-1111-1111-111111111111', 'alice@students.utech.edu.jm'),
  ('22222222-2222-2222-2222-222222222222', 'bob@students.utech.edu.jm'),
  ('55555555-5555-5555-5555-555555555555', 'carol@students.utech.edu.jm'),
  ('66666666-6666-6666-6666-666666666666', 'dan@students.utech.edu.jm');

insert into public.portfolios (id, user_id, slug, title, status) values
  ('aaaaaaaa-0000-0000-0000-000000000001', '11111111-1111-1111-1111-111111111111', 'live-a1b2c3d4e5', 'Live', 'active');
insert into public.comments (id, portfolio_id, user_id, content) values
  ('cccccccc-0000-0000-0000-000000000001', 'aaaaaaaa-0000-0000-0000-000000000001',
   '11111111-1111-1111-1111-111111111111', 'A comment');

set local role authenticated;

-- Report 1: Bob
select set_config('request.jwt.claims', '{"sub":"22222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
insert into public.reports (reporter_id, comment_id, category)
values ('22222222-2222-2222-2222-222222222222', 'cccccccc-0000-0000-0000-000000000001', 'harassment');

-- Bob tries again: refused by unique (reporter_id, comment_id).
select throws_ok(
  $$ insert into public.reports (reporter_id, comment_id, category)
     values ('22222222-2222-2222-2222-222222222222', 'cccccccc-0000-0000-0000-000000000001', 'other') $$,
  '23505', null,
  'the same user cannot report the same comment twice');

-- Report 2: Carol
select set_config('request.jwt.claims', '{"sub":"55555555-5555-5555-5555-555555555555","role":"authenticated"}', true);
insert into public.reports (reporter_id, comment_id, category)
values ('55555555-5555-5555-5555-555555555555', 'cccccccc-0000-0000-0000-000000000001', 'harassment');

reset role;
select is((select hidden from public.comments where id = 'cccccccc-0000-0000-0000-000000000001'),
  false, 'two reports (one user tried twice) do not hide the comment');

-- Visitors still see it.
set local role anon;
select isnt_empty($$ select id from public.comments $$, 'visitors still see the comment');

-- Report 3: Dan
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"66666666-6666-6666-6666-666666666666","role":"authenticated"}', true);
select lives_ok(
  $$ insert into public.reports (reporter_id, comment_id, category)
     values ('66666666-6666-6666-6666-666666666666', 'cccccccc-0000-0000-0000-000000000001', 'harassment') $$,
  'a third user reports the comment');

reset role;
select is((select hidden from public.comments where id = 'cccccccc-0000-0000-0000-000000000001'),
  true, 'three reports from three different users hide the comment');

set local role anon;
select is_empty($$ select id from public.comments $$, 'visitors no longer see the hidden comment');

select * from finish();
rollback;
